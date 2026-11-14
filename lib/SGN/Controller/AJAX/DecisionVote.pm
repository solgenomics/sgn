
=head1 NAME

SGN::Controller::AJAX::DecisionVote - variety votes of decision meetings

=head1 DESCRIPTION

People who are not Breedbase users (farmers, field workers, ...) can vote on
the candidate varieties (accessions) of a decision meeting. A breeder opens a
vote on the decision meeting page (/breeders/meeting): candidate accessions
(by default the accessions selected by the index of an analysis linked to the
meeting) and a start and an end date; the other accessions can be only for
notes. Only invited people vote (there is no public link): Breedbase users,
or people without an account (name and e-mail). Each one is registered when
the invitation is sent and receives a personal ballot link by e-mail, where
they give each candidate a place (1 = best); notes are never required.
Sending the ballot again replaces the previous vote. The vote is anonymous:
everyone sees only how many people are registered and how many voted. After the end date the
results (Borda count) are shown on every link, with the trait values and the
selection index of the candidates, copied from the analysis when the vote was
opened (the evidence stays as it was even if the analysis changes).

Endpoints for the meeting roles (decision_role, meeting_role; login needed):

  GET  /ajax/decision_vote/list           meeting_id: votes of a meeting
  GET  /ajax/decision_vote/detail         vote_id: vote, progress (totals only), invitations, results once closed
  POST /ajax/decision_vote/create         open a vote
  POST /ajax/decision_vote/update         change name, description, dates
  POST /ajax/decision_vote/delete         delete a vote and its ballots
  POST /ajax/decision_vote/resend_invite  e-mail an invited person their voting link again
  POST /ajax/decision_vote/invite         invite people by name and e-mail (in batches)
  GET  /ajax/decision_vote/users          q: Breedbase users (to invite them)
  POST /ajax/decision_vote/invite_users   invite Breedbase users (registered, ballot link sent)
  POST /ajax/decision_vote/send_pending   send the invitations saved but not sent yet (in batches)

Endpoints of the voters (no login; the token of the personal ballot link
identifies the voter):

  GET  /ajax/decision_vote/public/info      token: vote, progress, own ballot, results once closed
  POST /ajax/decision_vote/public/ballot    ballot token + order (+ notes): records the vote (replaces
                                            the previous one of the voter)

Pages: SGN::Controller::DecisionVote. Tables: db patch AddDecisionVoteTables.

=head1 AUTHOR

Chris Simoes <ccs263@cornell.edu>

=cut

package SGN::Controller::AJAX::DecisionVote;

use Moose;
use JSON;
use Try::Tiny;
use CXGN::JSONUtils qw(decode_stored_json);
use SGN::Controller::AJAX::ScriptFactory;
use CXGN::RespectfulWords;
use CXGN::Contact;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
);

my $MAX_ACCESSIONS = 100;
my $MAX_NOTE_ACCESSIONS = 500;
# minutes before a link can be e-mailed again to the same person
my $RESEND_MINUTES = 2;
# e-mails sent by one request (the page sends a long list in batches: the web
# server stops requests after some seconds)
my $INVITE_BATCH = 5;
my $MAX_INVITES = 2000;
my $MAX_COMMENT = 2000;

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

sub _dbh { return shift->dbc->dbh(); }

sub _tables_exist {
    my $dbh = shift;
    my ($ok) = $dbh->selectrow_array("SELECT to_regclass('sgn_people.sp_decision_vote_ballot') IS NOT NULL");
    return $ok;
}

sub _fail {
    my ($c, $msg) = @_;
    $c->stash->{rest} = { error => $msg };
    return 0;
}

sub _check_tables {
    my $c = shift;
    return 1 if _tables_exist(_dbh($c));
    return _fail($c, 'Variety votes require the database patch AddDecisionVoteTables. Please ask your administrator to run it.');
}

# login and one of the decision meeting roles
sub _check_manager {
    my $c = shift;
    return _fail($c, 'You must be logged in.') if !$c->user();
    return _fail($c, 'Only participants of decision meetings (the roles set in the site configuration) can manage variety votes.')
        if !SGN::Controller::AJAX::ScriptFactory::_can_link_meetings($c);
    return _check_tables($c);
}

sub _token {
    my $bytes = '';
    if (open(my $fh, '<:raw', '/dev/urandom')) {
        read($fh, $bytes, 24);
        close($fh);
    }
    # fallback (never expected on Linux)
    $bytes = join('', map { chr(int(rand(256))) } 1 .. 24) if length($bytes) != 24;
    return unpack('H*', $bytes);
}

sub _trim {
    my ($v, $max) = @_;
    $v = '' if !defined $v || ref $v;
    $v =~ s/^\s+|\s+$//g;
    $v =~ s/[\x00-\x08\x0B\x0C\x0E-\x1F]//g;
    return $max && length($v) > $max ? substr($v, 0, $max) : $v;
}

# tries a voter has to replace disrespectful words in the notes; after them
# the vote is saved without those notes
my $NOTES_TRIES = 3;

sub _config_words {
    my ($c, $key) = @_;
    my $v = $c->config->{$key};
    return [ grep { $_ ne '' } map { s/^\s+|\s+$//gr } map { split /,/ } grep { defined && !ref } (ref($v) eq 'ARRAY' ? @$v : ($v)) ];
}

# Disrespectful words come from open word lists that CXGN::RespectfulWords
# fetches when it checks (nothing is stored), plus vote_blocked_words;
# vote_allowed_words are never refused; vote_word_list_languages chooses the
# lists (comma separated, in the site configuration). One checker per request.
sub _word_checker {
    my $c = shift;
    my $langs = _config_words($c, 'vote_word_list_languages');
    return CXGN::RespectfulWords->new((@$langs ? (languages => $langs) : ()),
        allowed => _config_words($c, 'vote_allowed_words'), blocked => _config_words($c, 'vote_blocked_words'));
}

# words found in each text: [{field, label, words}] for the texts that have some
sub _find_words {
    my ($checker, @fields) = @_;
    my @found;
    while (my ($field, $label, $text) = splice(@fields, 0, 3)) {
        my @w = $checker->find($text);
        push @found, { field => $field, label => $label, words => \@w } if @w;
    }
    return \@found;
}

# "We noticed you used the word "x" in your name. Could you consider ..."
sub _polite_message {
    my $found = shift;
    my @parts = map { my $w = $_->{words}; (@$w == 1 ? 'the word "' . $w->[0] . '"' : 'the words ' . join(', ', map { "\"$_\"" } @$w)) . ' in ' . $_->{label} } @$found;
    my $last = pop @parts;
    return 'We noticed you used ' . (@parts ? join('; ', @parts) . ' and ' : '') . $last
        . '. Could you consider replacing ' . ((@$found > 1 || @{ $found->[0]->{words} } > 1) ? 'them' : 'it') . ' with a different word? Thank you!';
}

sub _valid_date {
    my $d = shift // '';
    return 0 if $d !~ /^(\d{4})-(\d{2})-(\d{2})$/;
    my ($y, $m, $day) = ($1, $2, $3);
    return 0 if $m < 1 || $m > 12 || $day < 1;
    my @len = (31, ($y % 4 == 0 && ($y % 100 != 0 || $y % 400 == 0)) ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31);
    return $day <= $len[$m - 1] ? 1 : 0;
}

sub _json { return JSON->new->canonical(1)->encode(shift); }

# a JSON request parameter (the parameters arrive as characters, accents
# included; as UTF-8 octets on some setups), or undef
sub _json_param {
    my ($c, $name, $default) = @_;
    my $text = scalar $c->req->param($name);
    $text = $default if !defined $text || $text eq '';
    foreach my $utf8 (utf8::is_utf8($text) ? (0, 1) : (1, 0)) {
        my $d = eval { JSON->new->utf8($utf8)->decode($text) };
        return $d if !$@;
    }
    return;
}

sub _decode {
    my $t = shift;
    return if !defined $t;
    return try { decode_stored_json($t) } catch { undef };
}

my $VOTE_COLUMNS = "v.sp_decision_vote_id, v.meeting_id, v.name, v.description, to_char(v.start_date, 'YYYY-MM-DD'),
    to_char(v.end_date, 'YYYY-MM-DD'), v.analysis_id, v.accessions, v.note_accessions, v.evidence,
    to_char(v.create_date, 'YYYY-MM-DD'), coalesce(p.first_name || ' ' || p.last_name, ''),
    CASE WHEN current_date < v.start_date THEN 'upcoming' WHEN current_date > v.end_date THEN 'closed' ELSE 'open' END,
    to_char(current_date, 'YYYY-MM-DD'), coalesce(m.name, '')";

# a vote (hash) found by a where clause on v, or undef
sub _load_vote {
    my ($dbh, $where, @bind) = @_;
    my $r = $dbh->selectrow_arrayref(
        "SELECT $VOTE_COLUMNS FROM sgn_people.sp_decision_vote v
           LEFT JOIN sgn_people.sp_person p ON p.sp_person_id = v.sp_person_id
           LEFT JOIN public.project m ON m.project_id = v.meeting_id
          WHERE $where", undef, @bind);
    return $r ? _vote_hash($r) : undef;
}

sub _vote_hash {
    my $r = shift;
    my %v;
    @v{qw(vote_id meeting_id name description start_date end_date analysis_id accessions note_accessions evidence created created_by state today meeting_name)} = @$r;
    $v{$_} += 0 for grep { defined $v{$_} } qw(vote_id meeting_id analysis_id);
    $v{accessions} = _decode($v{accessions}) || [];
    $v{note_accessions} = _decode($v{note_accessions}) || [];
    $v{evidence} = _decode($v{evidence});
    return \%v;
}

# progress of a vote: registered, voted, invited (e-mails invited that did not
# register yet), expected (registered + invited not registered) and missing
# (expected that did not vote). Totals only.
sub _progress {
    my ($dbh, $v) = @_;
    my ($registered, $voted) = $dbh->selectrow_array(
        'SELECT count(*), count(voted_date) FROM sgn_people.sp_decision_vote_voter WHERE sp_decision_vote_id = ?', undef, $v->{vote_id});
    my ($waiting) = $dbh->selectrow_array(
        'SELECT count(*) FROM sgn_people.sp_decision_vote_invite i WHERE i.sp_decision_vote_id = ?
            AND NOT EXISTS (SELECT 1 FROM sgn_people.sp_decision_vote_voter w WHERE w.sp_decision_vote_id = i.sp_decision_vote_id AND lower(w.email) = lower(i.email))',
        undef, $v->{vote_id});
    my $expected = $registered + $waiting;
    return { registered => $registered + 0, voted => $voted + 0, invited_not_registered => $waiting + 0, expected => $expected + 0, missing => $expected - $voted + 0 };
}

# Borda count: with n accessions to vote, rank 1 gives n points and rank n gives 1.
# candidates: [{accession, stock_id, place, points, n_votes, first, mean_rank, comments, evidence}];
# other_notes: [{accession, stock_id, comments}] of the accessions only for notes that have some
# (all notes anonymous)
sub _results {
    my ($dbh, $v) = @_;
    my $n = scalar(@{ $v->{accessions} });
    my $rows = $dbh->selectall_arrayref(
        'SELECT b.accession, b.rank, b.comment FROM sgn_people.sp_decision_vote_ballot b
           JOIN sgn_people.sp_decision_vote_voter w USING (sp_decision_vote_voter_id)
          WHERE w.sp_decision_vote_id = ? AND w.voted_date IS NOT NULL
          ORDER BY w.voted_date', undef, $v->{vote_id});
    my %r = map { $_->{accession} => { accession => $_->{accession}, stock_id => $_->{stock_id}, points => 0, n_votes => 0, first => 0, rank_sum => 0, comments => [] } } @{ $v->{accessions} };
    my %o = map { $_->{accession} => { accession => $_->{accession}, stock_id => $_->{stock_id}, comments => [] } } @{ $v->{note_accessions} };
    foreach my $b (@$rows) {
        my ($acc, $rank, $comment) = @$b;
        if (!defined $rank) {
            push @{ $o{$acc}->{comments} }, $comment if $o{$acc} && defined($comment) && $comment ne '';
            next;
        }
        my $x = $r{$acc} or next;
        $x->{points} += $n - $rank + 1;
        $x->{n_votes}++;
        $x->{first}++ if $rank == 1;
        $x->{rank_sum} += $rank;
        push @{ $x->{comments} }, $comment if defined($comment) && $comment ne '';
    }
    my $ev = ($v->{evidence} || {})->{rows} || {};
    my @out = sort { $b->{points} <=> $a->{points} || $b->{first} <=> $a->{first} || $a->{accession} cmp $b->{accession} } values %r;
    my ($place, $prev) = (0, '');
    foreach my $i (0 .. $#out) {
        my $x = $out[$i];
        my $key = "$x->{points}/$x->{first}";
        $place = $i + 1 if $key ne $prev;
        $prev = $key;
        $x->{place} = $place;
        $x->{mean_rank} = $x->{n_votes} ? sprintf('%.2f', delete($x->{rank_sum}) / $x->{n_votes}) + 0 : do { delete $x->{rank_sum}; undef };
        $x->{evidence} = $ev->{ $x->{accession} };
        # anonymous: sorted, so the order of voting does not tell who wrote a note
        $x->{comments} = [ sort @{ $x->{comments} } ];
    }
    my $general = $dbh->selectcol_arrayref(
        "SELECT general_comment FROM sgn_people.sp_decision_vote_voter
          WHERE sp_decision_vote_id = ? AND voted_date IS NOT NULL AND coalesce(general_comment, '') <> '' ORDER BY general_comment", undef, $v->{vote_id});
    my @other = map { +{ %$_, comments => [ sort @{ $_->{comments} } ] } } sort { $a->{accession} cmp $b->{accession} } grep { @{ $_->{comments} } } values %o;
    return { candidates => \@out, other_notes => \@other, general_comments => $general, max_points => $n };
}

# what the public pages show of a vote (no tokens, no evidence before the end)
sub _public_vote {
    my ($dbh, $v) = @_;
    my $closed = $v->{state} eq 'closed';
    my $ev = $v->{evidence};
    return {
        name => $v->{name},
        description => $v->{description},
        meeting_name => $v->{meeting_name},
        start_date => $v->{start_date},
        end_date => $v->{end_date},
        today => $v->{today},
        state => $v->{state},
        accessions => [ map { $_->{accession} } @{ $v->{accessions} } ],
        note_accessions => [ map { $_->{accession} } @{ $v->{note_accessions} } ],
        progress => _progress($dbh, $v),
        ($closed ? (results => _results($dbh, $v), evidence => $ev ? { map { $_ => $ev->{$_} } qw(analysis_name value_label traits index) } : undef) : ()),
    };
}

# meeting roles see the vote with its links and its voters
sub _manager_vote {
    my ($dbh, $v, $with_voters) = @_;
    my %out = (%$v, progress => _progress($dbh, $v));
    my ($n_inv, $n_not_sent) = $dbh->selectrow_array('SELECT count(*), count(*) - count(invited_date) FROM sgn_people.sp_decision_vote_invite WHERE sp_decision_vote_id = ?',
        undef, $v->{vote_id});
    $out{invitations} = { invited => $n_inv + 0, not_sent => $n_not_sent + 0 };
    $out{accessions} = $v->{accessions};
    $out{evidence} = $v->{evidence} ? { map { $_ => $v->{evidence}->{$_} } qw(analysis_name value_label traits index) } : undef;
    if ($with_voters) {
        # Anonymous: nobody sees who registered or who voted, only the totals
        # (progress). The results are shown after the end of the vote.
        $out{results} = _results($dbh, $v) if $v->{state} eq 'closed';
        $out{invites} = [ map { +{ invite_id => $_->[0] + 0, email => $_->[1], sent => $_->[2], times_sent => $_->[3] + 0, name => $_->[4], breedbase_user => $_->[5] ? 1 : 0 } }
            @{ $dbh->selectall_arrayref("SELECT sp_decision_vote_invite_id, email, to_char(invited_date, 'YYYY-MM-DD HH24:MI'), times_sent, name, invited_sp_person_id IS NOT NULL
                                           FROM sgn_people.sp_decision_vote_invite WHERE sp_decision_vote_id = ?
                                          ORDER BY invited_date IS NOT NULL, lower(coalesce(name, email))", undef, $v->{vote_id}) } ];
        my $ev = $v->{evidence} ? $v->{evidence}->{rows} : undef;
        $out{evidence}->{rows} = $ev if $ev && $out{results};
    }
    return \%out;
}

sub _vote_param {
    my $c = shift;
    my $id = $c->req->param('vote_id') // '';
    return if $id !~ /^\d+$/;
    return _load_vote(_dbh($c), 'v.sp_decision_vote_id = ?', $id);
}

# name, description and dates from the request, or an error text
sub _vote_fields {
    my ($c, $today) = @_;
    my %f = (
        name => _trim(scalar $c->req->param('name'), 255),
        description => _trim(scalar $c->req->param('description'), 4000),
        start_date => _trim(scalar $c->req->param('start_date')),
        end_date => _trim(scalar $c->req->param('end_date')),
    );
    return 'Give the vote a name.' if $f{name} eq '';
    return 'The start date must be a date (YYYY-MM-DD).' if !_valid_date($f{start_date});
    return 'The end date must be a date (YYYY-MM-DD).' if !_valid_date($f{end_date});
    return 'The end date cannot be before the start date.' if $f{end_date} lt $f{start_date};
    return 'The end date has passed: the vote would already be closed.' if $today && $f{end_date} lt $today;
    $f{description} = undef if $f{description} eq '';
    return \%f;
}

# ---------------------------------------------------------------------------
# meeting roles
# ---------------------------------------------------------------------------

sub list_votes : Path('/ajax/decision_vote/list') Args(0) {
    my $self = shift;
    my $c = shift;
    return if !_check_manager($c);
    my $meeting_id = $c->req->param('meeting_id') // '';
    return _fail($c, 'Choose a meeting.') if $meeting_id !~ /^\d+$/;
    my $dbh = _dbh($c);
    my $rows = $dbh->selectall_arrayref(
        "SELECT $VOTE_COLUMNS FROM sgn_people.sp_decision_vote v
           LEFT JOIN sgn_people.sp_person p ON p.sp_person_id = v.sp_person_id
           LEFT JOIN public.project m ON m.project_id = v.meeting_id
          WHERE v.meeting_id = ? ORDER BY v.create_date DESC", undef, $meeting_id);
    $c->stash->{rest} = { votes => [ map { _manager_vote($dbh, _vote_hash($_), 0) } @$rows ] };
}

sub vote_detail : Path('/ajax/decision_vote/detail') Args(0) {
    my $self = shift;
    my $c = shift;
    return if !_check_manager($c);
    my $v = _vote_param($c) or return _fail($c, 'This vote does not exist.');
    $c->stash->{rest} = { vote => _manager_vote(_dbh($c), $v, 1) };
}

# POST meeting_id, name, description, start_date, end_date,
# analysis_id (optional), accessions (JSON array of accession names, in order)
sub create_vote : Path('/ajax/decision_vote/create') Args(0) {
    my $self = shift;
    my $c = shift;
    return if !_check_manager($c);
    return _fail($c, 'Use POST.') if $c->req->method() ne 'POST';
    my $dbh = _dbh($c);
    my ($today) = $dbh->selectrow_array("SELECT to_char(current_date, 'YYYY-MM-DD')");
    my $f = _vote_fields($c, $today);
    return _fail($c, $f) if !ref $f;

    my $meeting_id = $c->req->param('meeting_id') // '';
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my ($meeting) = $meeting_id =~ /^\d+$/ ? @{ SGN::Controller::AJAX::ScriptFactory::_meetings($schema, $meeting_id) } : ();
    return _fail($c, 'This decision meeting does not exist.') if !$meeting;

    # accessions to vote (put in order) and accessions only for notes
    my $names = _json_param($c, 'accessions', '[]');
    my $note_names = _json_param($c, 'note_accessions', '[]');
    return _fail($c, 'Invalid list of accessions.') if ref($names) ne 'ARRAY' || ref($note_names) ne 'ARRAY';
    my %seen;
    my @names = grep { $_ ne '' && !$seen{$_}++ } map { _trim($_, 255) } @$names;
    my @note_names = grep { $_ ne '' && !$seen{$_}++ } map { _trim($_, 255) } @$note_names;
    return _fail($c, 'Choose at least two candidates to vote on.') if @names < 2;
    return _fail($c, "A vote can have at most $MAX_ACCESSIONS candidates to vote on.") if @names > $MAX_ACCESSIONS;
    return _fail($c, "A vote can have at most $MAX_NOTE_ACCESSIONS accessions only for notes.") if @note_names > $MAX_NOTE_ACCESSIONS;
    my %stock = map { $_->[0] => $_->[1] + 0 } @{ $dbh->selectall_arrayref(
        "SELECT s.uniquename, s.stock_id FROM public.stock s JOIN public.cvterm t ON t.cvterm_id = s.type_id AND t.name = 'accession'
          WHERE s.uniquename = ANY(?)", undef, [ @names, @note_names ]) };
    my @unknown = grep { !$stock{$_} } (@names, @note_names);
    return _fail($c, 'These are not accessions of the database: ' . join(', ', @unknown)) if @unknown;

    # evidence of the analysis, kept with the vote: only its candidates
    my ($analysis_id, $evidence) = ($c->req->param('analysis_id') // '', undef);
    if ($analysis_id ne '') {
        return _fail($c, 'Invalid analysis.') if $analysis_id !~ /^\d+$/;
        my $e = SGN::Controller::AJAX::ScriptFactory::evidence_data($c, $analysis_id);
        return _fail($c, 'Analysis evidence: ' . $e->{error}) if $e->{error};
        my %want = map { $_ => 1 } @names;
        $evidence = {
            analysis_id => $analysis_id + 0,
            analysis_name => $e->{name},
            value_label => $e->{value_label},
            traits => [ map { +{ trait => $_->{trait}, direction => $_->{direction}, h2 => $_->{h2} } } @{ $e->{traits} || [] } ],
            index => $e->{index} ? { method => $e->{index}->{method}, selection_pct => $e->{index}->{selection_pct}, n_ranked => $e->{index}->{n_ranked} } : undef,
            rows => {},
        };
        # per candidate: value and rank of each trait, index, index rank, selected
        foreach my $row (grep { $want{ $_->{accession} // '' } } @{ $e->{rows} || [] }) {
            my $vals = $row->{values} || {};
            $evidence->{rows}->{ $row->{accession} } = {
                values => { map { $_ => (ref($vals->{$_}) eq 'HASH' ? $vals->{$_}->{v} : undef) } keys %$vals },
                ranks => { map { $_ => (ref($vals->{$_}) eq 'HASH' ? $vals->{$_}->{rank} : undef) } keys %$vals },
                index => $row->{index}, index_rank => $row->{index_rank}, selected => $row->{selected},
            };
        }
    } else {
        $analysis_id = undef;
    }

    my $id;
    my $err;
    try {
        ($id) = $dbh->selectrow_array(
            'INSERT INTO sgn_people.sp_decision_vote (meeting_id, name, description, start_date, end_date, analysis_id,
                    accessions, note_accessions, evidence, sp_person_id)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?) RETURNING sp_decision_vote_id', undef,
            $meeting_id, $f->{name}, $f->{description}, $f->{start_date}, $f->{end_date}, $analysis_id,
            _json([ map { +{ accession => $_, stock_id => $stock{$_} } } @names ]),
            _json([ map { +{ accession => $_, stock_id => $stock{$_} } } @note_names ]), ($evidence ? _json($evidence) : undef),
            $c->user()->get_object()->get_sp_person_id());
    } catch { $err = "$_"; };
    return _fail($c, 'The vote could not be saved: ' . ($err =~ s/ at \S+ line \d+.*//sr)) if $err;
    $c->stash->{rest} = { success => 1, vote_id => $id + 0 };
}

# POST vote_id, name, description, start_date, end_date
sub update_vote : Path('/ajax/decision_vote/update') Args(0) {
    my $self = shift;
    my $c = shift;
    return if !_check_manager($c);
    return _fail($c, 'Use POST.') if $c->req->method() ne 'POST';
    my $v = _vote_param($c) or return _fail($c, 'This vote does not exist.');
    my $f = _vote_fields($c);
    return _fail($c, $f) if !ref $f;
    my $dbh = _dbh($c);
    my $p = _progress($dbh, $v);
    return _fail($c, 'Some people have already voted: the start date cannot move after today.')
        if $p->{voted} && $f->{start_date} gt $v->{today};
    $dbh->do('UPDATE sgn_people.sp_decision_vote SET name = ?, description = ?, start_date = ?, end_date = ?
               WHERE sp_decision_vote_id = ?', undef, @$f{qw(name description start_date end_date)}, $v->{vote_id});
    $c->stash->{rest} = { success => 1 };
}

sub delete_vote : Path('/ajax/decision_vote/delete') Args(0) {
    my $self = shift;
    my $c = shift;
    return if !_check_manager($c);
    return _fail($c, 'Use POST.') if $c->req->method() ne 'POST';
    my $v = _vote_param($c) or return _fail($c, 'This vote does not exist.');
    _dbh($c)->do('DELETE FROM sgn_people.sp_decision_vote WHERE sp_decision_vote_id = ?', undef, $v->{vote_id});
    $c->stash->{rest} = { success => 1 };
}

my $USER_EMAIL = "coalesce(nullif(trim(p.private_email), ''), nullif(trim(p.contact_email), ''))";

# Invitations (sgn_people.sp_decision_vote_invite). A person is saved first
# and the invitation sent now or later (invited_date is empty until then).
# When it is sent the person is registered (no registration step: the name
# and e-mail of the invitation, or of the Breedbase account for a user,
# invited_sp_person_id) and receives the ballot link.
# Returns the id of the invitation; an invitation already there keeps its
# history (dates, times sent).
sub _save_invite {
    my ($dbh, $v, $email, $name, $inviter, $user_id) = @_;
    my ($id) = $dbh->selectrow_array('SELECT sp_decision_vote_invite_id FROM sgn_people.sp_decision_vote_invite WHERE sp_decision_vote_id = ? AND lower(email) = lower(?)',
        undef, $v->{vote_id}, $email);
    if ($id) {
        $dbh->do('UPDATE sgn_people.sp_decision_vote_invite SET name = coalesce(?, name), invited_sp_person_id = coalesce(?, invited_sp_person_id) WHERE sp_decision_vote_invite_id = ?',
            undef, ($name ne '' ? $name : undef), $user_id, $id);
        return $id;
    }
    ($id) = $dbh->selectrow_array('INSERT INTO sgn_people.sp_decision_vote_invite (sp_decision_vote_id, email, name, invited_sp_person_id, sp_person_id)
        VALUES (?, ?, ?, ?, ?) RETURNING sp_decision_vote_invite_id', undef, $v->{vote_id}, $email, ($name ne '' ? $name : undef), $user_id, $inviter);
    return $id;
}

# sends one invitation (id); returns 'sent' or 'recent' (sent less than
# $RESEND_MINUTES minutes ago)
sub _send_invite {
    my ($c, $dbh, $v, $id, $message) = @_;
    my $x = $dbh->selectrow_hashref(
        "SELECT email, name, invited_sp_person_id, invited_date > now() - interval '$RESEND_MINUTES minutes' AS recent
           FROM sgn_people.sp_decision_vote_invite WHERE sp_decision_vote_invite_id = ?", undef, $id);
    return 'recent' if $x->{recent};
    my $name = $x->{name} // '';
    my $user = $x->{invited_sp_person_id};
    # an invited person is registered now (no registration step) and receives
    # the ballot link: the same registration is used if it is already there
    my $w = $dbh->selectrow_hashref(
        'SELECT sp_decision_vote_voter_id AS voter_id, name, email, token FROM sgn_people.sp_decision_vote_voter
          WHERE sp_decision_vote_id = ? AND ((sp_person_id IS NOT NULL AND sp_person_id = ?)
                OR (lower(email) = lower(?) AND (? = \'\' OR lower(name) = lower(?))))
          ORDER BY sp_person_id IS NULL, registered_date LIMIT 1', undef, $v->{vote_id}, $user, $x->{email}, $name, $name);
    if (!$w) {
        my $token = _token();
        my $voter_name = $name ne '' ? $name : $x->{email};
        my ($voter_id) = $dbh->selectrow_array(
            'INSERT INTO sgn_people.sp_decision_vote_voter (sp_decision_vote_id, name, role, email, sp_person_id, token)
             VALUES (?, ?, ?, ?, ?, ?) RETURNING sp_decision_vote_voter_id', undef,
            $v->{vote_id}, $voter_name, ($user ? 'Breedbase user' : 'Invited'), $x->{email}, $user, $token);
        $w = { voter_id => $voter_id, name => $voter_name, email => $x->{email}, token => $token };
    }
    _send_link($c, $dbh, $v, $w, $message);
    $dbh->do('UPDATE sgn_people.sp_decision_vote_invite SET invited_date = now(), times_sent = times_sent + 1 WHERE sp_decision_vote_invite_id = ?', undef, $id);
    return 'sent';
}

sub _invite_checks {
    my ($c, $v, $send) = @_;
    return _fail($c, 'The vote is closed: nobody can vote any more.') if $v->{state} eq 'closed';
    return _fail($c, 'E-mails are disabled on this site (disable_emails): copy the links and send them yourself.') if $send && $c->config->{disable_emails};
    return 1;
}

# POST vote_id, people (JSON array of {name, email}, name optional, at most
# $INVITE_BATCH), send (1: send now, 0: only save the list), message (optional).
# Status of each person: sent, saved (not sent), invalid, recent, limit
sub invite : Path('/ajax/decision_vote/invite') Args(0) {
    my $self = shift;
    my $c = shift;
    return if !_check_manager($c);
    return _fail($c, 'Use POST.') if $c->req->method() ne 'POST';
    my $v = _vote_param($c) or return _fail($c, 'This vote does not exist.');
    my $send = ($c->req->param('send') // '1') eq '0' ? 0 : 1;
    return if !_invite_checks($c, $v, $send);
    my $people = _json_param($c, 'people', '');
    $people = [ map { +{ email => $_ } } @{ _json_param($c, 'emails', '[]') || [] } ] if ref($people) ne 'ARRAY';
    return _fail($c, 'Invalid list of people.') if ref($people) ne 'ARRAY' || grep { ref($_) ne 'HASH' } @$people;
    my %seen;
    my @people = grep { $_->{email} ne '' && !$seen{ lc $_->{email} }++ }
                 map { +{ email => _trim($_->{email}, 255), name => _trim($_->{name}, 255) } } @$people;
    return _fail($c, 'Write at least one e-mail.') if !@people;
    return _fail($c, "Send at most $INVITE_BATCH e-mails per request.") if @people > $INVITE_BATCH;
    my $message = _trim(scalar $c->req->param('message'), 2000);
    my $dbh = _dbh($c);
    my ($n) = $dbh->selectrow_array('SELECT count(*) FROM sgn_people.sp_decision_vote_invite WHERE sp_decision_vote_id = ?', undef, $v->{vote_id});
    my $inviter = $c->user()->get_object()->get_sp_person_id();
    my @status;
    foreach my $person (@people) {
        my ($e, $name) = ($person->{email}, $person->{name});
        if (!_valid_email($e)) { push @status, { email => $e, name => $name, status => 'invalid' }; next; }
        my ($old) = $dbh->selectrow_array('SELECT 1 FROM sgn_people.sp_decision_vote_invite WHERE sp_decision_vote_id = ? AND lower(email) = lower(?)', undef, $v->{vote_id}, $e);
        if (!$old && $n >= $MAX_INVITES) { push @status, { email => $e, name => $name, status => 'limit' }; next; }
        my $id = _save_invite($dbh, $v, $e, $name, $inviter, undef);
        $n++ if !$old;
        push @status, { email => $e, name => $name, status => $send ? _send_invite($c, $dbh, $v, $id, $message) : 'saved' };
    }
    $c->stash->{rest} = { success => 1, results => \@status };
}

# GET q (2 letters at least): Breedbase users to invite (enabled accounts)
sub users : Path('/ajax/decision_vote/users') Args(0) {
    my $self = shift;
    my $c = shift;
    return if !_check_manager($c);
    my $q = _trim(scalar $c->req->param('q'), 100);
    if (length($q) < 2) { $c->stash->{rest} = { users => [] }; return; }
    my $like = '%' . ($q =~ s/([%_\\])/\\$1/gr) . '%';
    my $rows = _dbh($c)->selectall_arrayref(
        "SELECT p.sp_person_id, trim(coalesce(p.first_name, '') || ' ' || coalesce(p.last_name, '')), p.username, $USER_EMAIL IS NOT NULL
           FROM sgn_people.sp_person p
          WHERE coalesce(p.disabled, '') = ''
            AND (p.first_name ILIKE ? OR p.last_name ILIKE ? OR p.username ILIKE ? OR (coalesce(p.first_name, '') || ' ' || coalesce(p.last_name, '')) ILIKE ?)
          ORDER BY p.last_name, p.first_name LIMIT 20", undef, ($like) x 4);
    $c->stash->{rest} = { users => [ map { +{ sp_person_id => $_->[0] + 0, name => $_->[1], username => $_->[2], has_email => $_->[3] ? 1 : 0 } } @$rows ] };
}

# POST vote_id, sp_person_ids (JSON array, at most $INVITE_BATCH), send (1/0):
# Breedbase users are invited with the name and e-mail of their account; when
# the invitation is sent they are registered and receive their ballot link (no
# registration step). Status of each user: sent, saved, recent, no_email, unknown
sub invite_users : Path('/ajax/decision_vote/invite_users') Args(0) {
    my $self = shift;
    my $c = shift;
    return if !_check_manager($c);
    return _fail($c, 'Use POST.') if $c->req->method() ne 'POST';
    my $v = _vote_param($c) or return _fail($c, 'This vote does not exist.');
    my $send = ($c->req->param('send') // '1') eq '0' ? 0 : 1;
    return if !_invite_checks($c, $v, $send);
    my $ids = _json_param($c, 'sp_person_ids', '[]');
    return _fail($c, 'Invalid list of users.') if ref($ids) ne 'ARRAY';
    my %seen;
    my @ids = grep { /^\d+$/ && !$seen{$_}++ } map { $_ // '' } @$ids;
    return _fail($c, 'Choose at least one user.') if !@ids;
    return _fail($c, "Send at most $INVITE_BATCH users per request.") if @ids > $INVITE_BATCH;
    my $dbh = _dbh($c);
    my $inviter = $c->user()->get_object()->get_sp_person_id();
    my @status;
    foreach my $id (@ids) {
        my ($name, $username, $email) = $dbh->selectrow_array(
            "SELECT trim(coalesce(p.first_name, '') || ' ' || coalesce(p.last_name, '')), p.username, $USER_EMAIL
               FROM sgn_people.sp_person p WHERE p.sp_person_id = ? AND coalesce(p.disabled, '') = ''", undef, $id);
        if (!defined $username) { push @status, { sp_person_id => $id + 0, status => 'unknown' }; next; }
        $name = $username if $name eq '';
        if (!$email || !_valid_email($email)) { push @status, { sp_person_id => $id + 0, name => $name, status => 'no_email' }; next; }
        my $invite_id = _save_invite($dbh, $v, $email, $name, $inviter, $id);
        push @status, { sp_person_id => $id + 0, name => $name, status => $send ? _send_invite($c, $dbh, $v, $invite_id, '') : 'saved' };
    }
    $c->stash->{rest} = { success => 1, results => \@status };
}

# POST vote_id, invite_id: sends an invitation again (a lost voting link: the
# same registration, the same link)
sub resend_invite : Path('/ajax/decision_vote/resend_invite') Args(0) {
    my $self = shift;
    my $c = shift;
    return if !_check_manager($c);
    return _fail($c, 'Use POST.') if $c->req->method() ne 'POST';
    my $v = _vote_param($c) or return _fail($c, 'This vote does not exist.');
    return if !_invite_checks($c, $v, 1);
    my $id = $c->req->param('invite_id') // '';
    my $dbh = _dbh($c);
    my ($email) = $id =~ /^\d+$/ ? $dbh->selectrow_array('SELECT email FROM sgn_people.sp_decision_vote_invite WHERE sp_decision_vote_invite_id = ? AND sp_decision_vote_id = ?',
        undef, $id, $v->{vote_id}) : ();
    return _fail($c, 'This person is not invited to this vote.') if !$email;
    my $status = _send_invite($c, $dbh, $v, $id, '');
    return _fail($c, "The voting link was e-mailed to $email less than $RESEND_MINUTES minutes ago.") if $status eq 'recent';
    $c->stash->{rest} = { success => 1, email => $email };
}

# POST vote_id, message (optional): sends at most $INVITE_BATCH of the
# invitations not sent yet; returns {sent, remaining} (the page calls it again
# until nothing remains)
sub send_pending : Path('/ajax/decision_vote/send_pending') Args(0) {
    my $self = shift;
    my $c = shift;
    return if !_check_manager($c);
    return _fail($c, 'Use POST.') if $c->req->method() ne 'POST';
    my $v = _vote_param($c) or return _fail($c, 'This vote does not exist.');
    return if !_invite_checks($c, $v, 1);
    my $dbh = _dbh($c);
    my $message = _trim(scalar $c->req->param('message'), 2000);
    my $ids = $dbh->selectcol_arrayref('SELECT sp_decision_vote_invite_id FROM sgn_people.sp_decision_vote_invite
        WHERE sp_decision_vote_id = ? AND invited_date IS NULL ORDER BY sp_decision_vote_invite_id LIMIT ?', undef, $v->{vote_id}, $INVITE_BATCH);
    my $sent = 0;
    foreach my $id (@$ids) { $sent++ if _send_invite($c, $dbh, $v, $id, $message) eq 'sent'; }
    my ($remaining) = $dbh->selectrow_array('SELECT count(*) FROM sgn_people.sp_decision_vote_invite WHERE sp_decision_vote_id = ? AND invited_date IS NULL',
        undef, $v->{vote_id});
    $c->stash->{rest} = { success => 1, sent => $sent, remaining => $remaining + 0 };
}

# ---------------------------------------------------------------------------
# public (token)
# ---------------------------------------------------------------------------

sub _valid_email {
    my $e = shift // '';
    return length($e) <= 255 && $e =~ /^[^\s@,;<>()"']+@[^\s@,;<>()"']+\.[A-Za-z]{2,}$/ ? 1 : 0;
}

# e-mails the personal ballot link of a voter ({voter_id, name, email, token}); returns the link
sub _send_link {
    my ($c, $dbh, $v, $w, $message) = @_;
    my $base = $c->req->base() . '';
    $base =~ s{/+$}{};
    my $link = "$base/decision_vote/ballot/$w->{token}";
    my $meeting = $v->{meeting_name} ? " (decision meeting $v->{meeting_name})" : '';
    my $who = '';
    if ($c->user()) {
        my $person = $c->user()->get_object();
        $who = join(' ', grep { $_ } ($person->get_first_name(), $person->get_last_name()));
    }
    my $note = ($message // '') ne '' ? "\n$message\n" : '';
    my @candidates = map { $_->{accession} } @{ $v->{accessions} };
    my $n_other = scalar(@{ $v->{note_accessions} || [] });
    my $list = join("\n", map { "  - $_" } @candidates);
    my $others = $n_other ? "\n2. NOTES (optional): you can also write what you think of the other $n_other varieties.\n   They are not voted on.\n" : '';
    my $body = <<"END_BODY";
Hello $w->{name},

You are invited to vote in "$v->{name}"$meeting.@{[ $who ne '' ? "\nInvited by $who." : '' ]}
$note
Open your personal voting link (no account or password needed):

  $link

1. VOTE: give each candidate variety a place, 1 = the variety you like best.
   You can also write a note on each one (optional).
$list
$others
Voting is open from $v->{start_date} to $v->{end_date}. You can open the link again and change
your vote until then: the new vote replaces the previous one. After $v->{end_date}, the results
are shown at the same link.

Please do not share this link: whoever has it can vote in your name.

This message was sent automatically; please do not reply to it.
END_BODY
    CXGN::Contact::send_email("Your voting link: $v->{name}", $body, $w->{email});
    $dbh->do('UPDATE sgn_people.sp_decision_vote_voter SET link_sent_date = now() WHERE sp_decision_vote_voter_id = ?', undef, $w->{voter_id});
    return $link;
}

sub _valid_token { return (shift // '') =~ /^[0-9a-f]{48}$/ ? 1 : 0; }

# the vote and the voter of a ballot token
sub _by_token {
    my ($dbh, $token) = @_;
    return () if !_valid_token($token);
    my $w = $dbh->selectrow_hashref(
        "SELECT sp_decision_vote_voter_id AS voter_id, sp_decision_vote_id AS vote_id, name, role, organization, location, general_comment,
                to_char(registered_date, 'YYYY-MM-DD') AS registered, to_char(voted_date, 'YYYY-MM-DD HH24:MI') AS voted
           FROM sgn_people.sp_decision_vote_voter WHERE token = ?", undef, $token);
    return () if !$w;
    return (_load_vote($dbh, 'v.sp_decision_vote_id = ?', $w->{vote_id}), $w);
}

sub public_info : Path('/ajax/decision_vote/public/info') Args(0) {
    my $self = shift;
    my $c = shift;
    return if !_check_tables($c);
    my $dbh = _dbh($c);
    my ($v, $w) = _by_token($dbh, scalar $c->req->param('token'));
    return _fail($c, 'This link is not valid. Please check it with the organizer of the vote.') if !$v || !$w;
    my $out = { vote => _public_vote($dbh, $v), kind => 'ballot' };
    {
        my $b = $dbh->selectall_arrayref('SELECT accession, rank, comment FROM sgn_people.sp_decision_vote_ballot WHERE sp_decision_vote_voter_id = ? ORDER BY rank, accession',
            undef, $w->{voter_id});
        $out->{voter} = {
            name => $w->{name}, role => $w->{role}, organization => $w->{organization}, location => $w->{location},
            registered => $w->{registered}, voted => $w->{voted}, general_comment => $w->{general_comment},
            ballot => [ map { +{ accession => $_->[0], rank => (defined $_->[1] ? $_->[1] + 0 : undef), comment => $_->[2] } } @$b ],
        };
    }
    $c->stash->{rest} = $out;
}

# POST token (ballot), order (JSON array of every accession to vote, best first),
# comments (JSON object accession => notes, optional: accessions to vote and
# accessions only for notes), general_comment (optional).
# A voter can change their vote until the end date: the new vote replaces the
# previous one (one ballot per voter).
sub public_ballot : Path('/ajax/decision_vote/public/ballot') Args(0) {
    my $self = shift;
    my $c = shift;
    return if !_check_tables($c);
    return _fail($c, 'Use POST.') if $c->req->method() ne 'POST';
    my $dbh = _dbh($c);
    my ($v, $w) = _by_token($dbh, scalar $c->req->param('token'));
    return _fail($c, 'This voting link is not valid. Please check it with the organizer of the vote.') if !$v;
    return _fail($c, 'The vote has not started: it opens on ' . $v->{start_date} . '.') if $v->{state} eq 'upcoming';
    return _fail($c, 'The vote is closed: it ended on ' . $v->{end_date} . '.') if $v->{state} eq 'closed';

    my $order = _json_param($c, 'order', '');
    my $comments = _json_param($c, 'comments', '{}');
    return _fail($c, 'Invalid vote.') if ref($order) ne 'ARRAY' || ref($comments) ne 'HASH';
    my @candidates = map { $_->{accession} } @{ $v->{accessions} };
    my %is = map { $_ => 1 } @candidates;
    my %seen;
    my @order = grep { !$seen{$_}++ } map { _trim($_) } @$order;
    return _fail($c, 'Please put every candidate variety in order.')
        if @order != @candidates || grep { !$is{$_} } @order;
    my $general = _trim(scalar $c->req->param('general_comment'), $MAX_COMMENT);
    my @note_only = map { $_->{accession} } @{ $v->{note_accessions} };
    my %notes = map { $_ => _trim($comments->{$_}, $MAX_COMMENT) } (@order, @note_only);

    # disrespectful words: the voter is asked to replace them; on the last try
    # the vote is saved without the notes that still have them
    my $found = _find_words(_word_checker($c), (map { ("note:$_", "your notes on $_", $notes{$_}) } (@order, @note_only)), general => 'your general notes', $general);
    my @removed;
    if (@$found) {
        my ($refused) = $dbh->selectrow_array('UPDATE sgn_people.sp_decision_vote_voter SET notes_refused = notes_refused + 1
            WHERE sp_decision_vote_voter_id = ? RETURNING notes_refused', undef, $w->{voter_id});
        if ($refused < $NOTES_TRIES) {
            my $left = $NOTES_TRIES - $refused;
            $c->stash->{rest} = {
                error => _polite_message($found) . ' Your vote was not sent yet. '
                    . ($left == 1 ? 'If the word is still there next time, your vote will be saved without those notes.'
                                  : "You can try $left more times; after that your vote is saved without those notes."),
                blocked => $found, tries_left => $left,
            };
            return;
        }
        foreach my $f (@$found) {
            if ($f->{field} eq 'general') { $general = ''; push @removed, 'general'; }
            else { my $acc = $f->{field} =~ s/^note://r; $notes{$acc} = ''; push @removed, $acc; }
        }
    }
    my $err;
    try {
        $dbh->begin_work();
        # locked: two submissions of the same ballot do not mix
        $dbh->selectrow_array('SELECT 1 FROM sgn_people.sp_decision_vote_voter WHERE sp_decision_vote_voter_id = ? FOR UPDATE', undef, $w->{voter_id});
        $dbh->do('DELETE FROM sgn_people.sp_decision_vote_ballot WHERE sp_decision_vote_voter_id = ?', undef, $w->{voter_id});
        my $sth = $dbh->prepare('INSERT INTO sgn_people.sp_decision_vote_ballot (sp_decision_vote_voter_id, accession, rank, comment) VALUES (?, ?, ?, ?)');
        foreach my $i (0 .. $#order) {
            my $txt = $notes{ $order[$i] };
            $sth->execute($w->{voter_id}, $order[$i], $i + 1, $txt eq '' ? undef : $txt);
        }
        # accessions only for notes: no rank, kept only when there are notes
        $sth->execute($w->{voter_id}, $_, undef, $notes{$_}) for grep { $notes{$_} ne '' } @note_only;
        $dbh->do('UPDATE sgn_people.sp_decision_vote_voter SET voted_date = now(), general_comment = ?, notes_refused = 0 WHERE sp_decision_vote_voter_id = ?',
            undef, ($general eq '' ? undef : $general), $w->{voter_id});
        $dbh->commit();
    } catch {
        $err = "$_";
        try { $dbh->rollback() };
    };
    return _fail($c, 'Your vote could not be saved. Please try again.') if $err;
    $c->stash->{rest} = { success => 1, changed => $w->{voted} ? 1 : 0, progress => _progress($dbh, $v), (@removed ? (notes_removed => \@removed) : ()) };
}

1;
