
# Variety votes of decision meetings (SGN::Controller::AJAX::DecisionVote):
# a curator opens a vote for a meeting and invites people, who are registered
# and vote with their personal links (no login; there is no public link). The
# vote is anonymous; the results appear on every link after the end date.

use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use JSON;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema();
my $dbh = $f->dbh();
my $base = 'http://localhost:3010';

my $mech = Test::WWW::Mechanize->new;   # janedoe (curator)
my $anon = Test::WWW::Mechanize->new;   # a farmer, not logged in

sub json_get {
    my ($m, $url) = @_;
    $m->get_ok($base . $url);
    return decode_json($m->content);
}
sub json_post {
    my ($m, $url, $data) = @_;
    $m->post_ok($base . $url, $data);
    return decode_json($m->content);
}

# a decision meeting
my $design = $schema->resultset('Cv::Cvterm')->find({ name => 'design', 'cv.name' => 'project_property' }, { join => 'cv' });
my $mj = $schema->resultset('Cv::Cvterm')->find({ name => 'meeting_json', 'cv.name' => 'project_property' }, { join => 'cv' });
my $meeting = $schema->resultset('Project::Project')->create({ name => 'variety vote test meeting', description => 'test' });
my $meeting_id = $meeting->project_id();
$meeting->create_related('projectprops', { type_id => $design->cvterm_id(), value => 'Meeting' });
$meeting->create_related('projectprops', { type_id => $mj->cvterm_id(), value => encode_json({ date => '2026-01-01', accessions => [ { accession => 'test_accession1' } ] }) });

my ($today, $in_week) = $dbh->selectrow_array("SELECT to_char(current_date, 'YYYY-MM-DD'), to_char(current_date + 7, 'YYYY-MM-DD')");

my $r = json_get($anon, "/ajax/decision_vote/list?meeting_id=$meeting_id");
ok($r->{error}, 'votes cannot be managed without login');

$mech->post_ok("$base/brapi/v1/token", [ username => 'janedoe', password => 'secretpw', grant_type => 'password' ], 'login');

$r = json_get($mech, "/ajax/decision_vote/list?meeting_id=$meeting_id");
is_deeply($r->{votes}, [], 'no vote yet');

my %vote = (meeting_id => $meeting_id, name => 'Farmer vote', description => 'Choose the best', start_date => $today, end_date => $in_week);
$r = json_post($mech, '/ajax/decision_vote/create', { %vote, end_date => '2020-01-01', accessions => encode_json([ 'test_accession1', 'test_accession2' ]) });
like($r->{error}, qr/end date/, 'end date before start date');
$r = json_post($mech, '/ajax/decision_vote/create', { %vote, accessions => encode_json([ 'test_accession1' ]) });
like($r->{error}, qr/at least two/, 'at least two candidates');
$r = json_post($mech, '/ajax/decision_vote/create', { %vote, accessions => encode_json([ 'test_accession1', 'no_such_accession' ]) });
like($r->{error}, qr/no_such_accession/, 'unknown accession');
$r = json_post($mech, '/ajax/decision_vote/create', { %vote, accessions => encode_json([ map { "test_accession$_" } 1 .. 4 ]),
    note_accessions => encode_json([ 'test_accession5', 'test_accession1' ]) });
ok($r->{success}, 'vote created') or diag explain $r;
my $vote_id = $r->{vote_id};
ok(!exists $r->{registration_token}, 'no public link: only invited people vote');

$r = json_get($mech, "/ajax/decision_vote/list?meeting_id=$meeting_id");
is(scalar(@{ $r->{votes} }), 1, 'one vote');
is($r->{votes}->[0]->{state}, 'open', 'vote is open');
is_deeply($r->{votes}->[0]->{progress}, { registered => 0, voted => 0, invited_not_registered => 0, expected => 0, missing => 0 }, 'progress before registrations');

# the ballot link is e-mailed, never returned: the tests read it from the database
sub token_of {
    my ($email, $name) = @_;
    my ($t) = $dbh->selectrow_array('SELECT token FROM sgn_people.sp_decision_vote_voter WHERE lower(email) = lower(?) AND lower(name) = lower(?)', undef, $email, $name);
    return $t;
}

# voters: only invited people, registered when the invitation is sent
$r = json_post($mech, '/ajax/decision_vote/invite', { vote_id => $vote_id, people => encode_json([
    { name => 'Maria Silva', email => 'maria@example.org' }, { name => 'Joao Souza', email => 'joao@example.org' }, { name => 'Ana Lima', email => 'ana@example.org' } ]) });
is_deeply([ map { $_->{status} } @{ $r->{results} } ], [ 'sent', 'sent', 'sent' ], 'three people invited');
my $t1 = token_of('maria@example.org', 'Maria Silva');
my $t2 = token_of('joao@example.org', 'Joao Souza');
my $t3 = token_of('ana@example.org', 'Ana Lima');
like($t1, qr/^[0-9a-f]{48}$/, 'ballot token');
ok($t2 && $t3 && $t2 ne $t1, 'each one has a personal link');
$r = json_post($mech, '/ajax/decision_vote/invite', { vote_id => $vote_id, people => encode_json([ { name => 'No E-mail', email => 'maria at example' } ]) });
is($r->{results}->[0]->{status}, 'invalid', 'a valid e-mail is needed');
$r = json_get($anon, "/ajax/decision_vote/public/info?token=$t1");
is(scalar(@{ $r->{vote}->{accessions} }), 4, 'four accessions to vote');
is_deeply($r->{vote}->{note_accessions}, [ 'test_accession5' ], 'one accession only for notes (an accession to vote is not repeated)');
ok(!exists $r->{vote}->{results}, 'no results while open');
is_deeply([ @{ $r->{vote}->{progress} }{qw(registered voted)} ], [ 3, 0 ], 'totals only');
$anon->get("$base/decision_vote/" . ('0' x 48));
is($anon->status(), 404, 'there is no registration page');
$r = json_get($anon, '/ajax/decision_vote/public/info?token=' . ('a' x 48));
ok($r->{error}, 'an unknown link does not open anything');
ok(!$anon->get("$base/ajax/decision_vote/public/register")->is_success() || decode_json($anon->content)->{error}, 'nobody can register without an invitation');

# public: ballots
$r = json_get($anon, "/ajax/decision_vote/public/info?token=$t1");
is($r->{kind}, 'ballot', 'ballot link');
is($r->{voter}->{name}, 'Maria Silva', 'voter name');
is_deeply($r->{voter}->{ballot}, [], 'not voted yet');

$r = json_post($anon, '/ajax/decision_vote/public/ballot', { token => $t1, order => encode_json([ 'test_accession1', 'test_accession2' ]) });
like($r->{error}, qr/every candidate variety/, 'every candidate must be ranked');
$r = json_post($anon, '/ajax/decision_vote/public/ballot', { token => $t1, order => encode_json([ map { "test_accession$_" } 1 .. 5 ]) });
like($r->{error}, qr/every candidate variety/, 'an accession only for notes cannot be ranked');
$r = json_post($anon, '/ajax/decision_vote/public/ballot', { token => ('b' x 48), order => encode_json([ map { "test_accession$_" } 1 .. 4 ]) });
ok($r->{error}, 'an unknown link cannot vote');

# disrespectful words: asked politely to replace them, three tries, then the vote is kept without those notes
my %bad = (token => $t1, order => encode_json([ map { "test_accession$_" } 1 .. 4 ]),
    comments => encode_json({ test_accession1 => 'good taste', test_accession2 => "what a shit variety, n\x{e3}o \x{e9} boa" }));
$r = json_post($anon, '/ajax/decision_vote/public/ballot', \%bad);
like($r->{error}, qr/We noticed you used the word "shit" in your notes on test_accession2\. Could you consider replacing it with a different word\?/, 'polite message naming the word');
is($r->{tries_left}, 2, 'two more tries');
is($r->{blocked}->[0]->{field}, 'note:test_accession2', 'the note with the word');
$r = json_post($anon, '/ajax/decision_vote/public/ballot', \%bad);
is($r->{tries_left}, 1, 'one more try');
$r = json_post($anon, '/ajax/decision_vote/public/ballot', \%bad);
ok($r->{success}, 'third try: the vote is saved');
is_deeply($r->{notes_removed}, [ 'test_accession2' ], '... without the note with the word');
$r = json_get($anon, "/ajax/decision_vote/public/info?token=$t1");
my %note = map { $_->{accession} => $_->{comment} } @{ $r->{voter}->{ballot} };
is($note{test_accession1}, 'good taste', 'the other notes are kept');
ok(!defined $note{test_accession2}, 'the note with the word is not stored');

$r = json_post($anon, '/ajax/decision_vote/public/ballot', { token => $t1, order => encode_json([ map { "test_accession$_" } 1 .. 4 ]),
    comments => encode_json({ test_accession1 => 'good taste' }), general_comment => 'nice trial' });
ok($r->{success}, 'first vote') or diag explain $r;
is_deeply($r->{progress}, { registered => 3, voted => 1, invited_not_registered => 0, expected => 3, missing => 2 }, 'progress after one vote');
# changed vote
$r = json_post($anon, '/ajax/decision_vote/public/ballot', { token => $t1, order => encode_json([ map { "test_accession$_" } 2, 1, 3, 4 ]),
    comments => encode_json({ test_accession1 => 'good taste' }) });
ok($r->{success} && $r->{changed}, 'vote changed');
$r = json_post($anon, '/ajax/decision_vote/public/ballot', { token => $t2, order => encode_json([ map { "test_accession$_" } 1, 2, 4, 3 ]),
    comments => encode_json({ test_accession1 => 'a bit late', test_accession5 => 'nice color' }) });
ok($r->{success}, 'second vote, with notes on an accession only for notes');
$r = json_get($anon, "/ajax/decision_vote/public/info?token=$t2");
my ($n5) = grep { $_->{accession} eq 'test_accession5' } @{ $r->{voter}->{ballot} };
ok($n5 && !defined($n5->{rank}) && $n5->{comment} eq 'nice color', 'the accession only for notes has notes and no rank');
is($r->{vote}->{progress}->{missing}, 1, 'one vote missing');

$r = json_get($anon, "/ajax/decision_vote/public/info?token=$t1");
is_deeply([ map { $_->{accession} } @{ $r->{voter}->{ballot} } ], [ map { "test_accession$_" } 2, 1, 3, 4 ], 'stored ballot');
ok(!exists $r->{vote}->{results}, 'voters see no results while open');

# anonymous: the meeting roles see only totals, and no results while the vote is open
$r = json_get($mech, "/ajax/decision_vote/detail?vote_id=$vote_id");
is_deeply([ @{ $r->{vote}->{progress} }{qw(registered voted)} ], [ 3, 2 ], 'totals: registered people and completed votes');
ok(!exists $r->{vote}->{voters}, 'nobody sees who registered or who voted');
ok(!exists $r->{vote}->{results}, 'no results before the end of the vote');
unlike($mech->content, qr/"voted_date"|"registered_date"|"token"/, 'no registration or vote of anyone (the invitations are the organizer\'s own list)');

# invitations: the registration link e-mailed to a list of people
$r = json_post($anon, '/ajax/decision_vote/invite', { vote_id => $vote_id, emails => encode_json([ 'x@example.org' ]) });
ok($r->{error}, 'only the meeting roles invite');
$r = json_post($mech, '/ajax/decision_vote/invite', { vote_id => $vote_id, emails => encode_json([ map { "p$_\@example.org" } 1 .. 6 ]) });
like($r->{error}, qr/at most 5/, 'invitations are sent in batches');
$r = json_post($mech, '/ajax/decision_vote/invite', { vote_id => $vote_id, message => 'Please come!',
    emails => encode_json([ 'maria@example.org', 'new.farmer@example.org', 'not an e-mail', 'NEW.farmer@example.org' ]) });
is_deeply({ map { $_->{email} => $_->{status} } @{ $r->{results} } },
    { 'maria@example.org' => 'recent', 'new.farmer@example.org' => 'sent', 'not an e-mail' => 'invalid' }, 'invitation status of each e-mail');
$r = json_post($mech, '/ajax/decision_vote/invite', { vote_id => $vote_id, emails => encode_json([ 'new.farmer@example.org' ]) });
is($r->{results}->[0]->{status}, 'recent', 'not invited again right away');
$r = json_post($mech, '/ajax/decision_vote/invite', { vote_id => $vote_id, people => encode_json([ { name => 'Pedro Alves', email => 'pedro@example.org' } ]) });
is($r->{results}->[0]->{status}, 'sent', 'invitation with a name');
$r = json_get($mech, "/ajax/decision_vote/detail?vote_id=$vote_id");
ok(!grep({ exists $_->{registered} || exists $_->{voted} } @{ $r->{vote}->{invites} }), 'the invitations do not tell who registered or voted');
my %by_mail = map { ($_->[0] . '/' . $_->[1]) => 1 } @{ $dbh->selectall_arrayref('SELECT email, name FROM sgn_people.sp_decision_vote_voter WHERE sp_decision_vote_id = ?', undef, $vote_id) };
ok($by_mail{'pedro@example.org/Pedro Alves'}, 'invited people are registered when the invitation is sent, with the name of the invitation');
ok($by_mail{'new.farmer@example.org/new.farmer@example.org'}, 'an invitation without a name: the e-mail is the name');
is(scalar(grep { m{^maria\@example.org/} } keys %by_mail), 1, 'an e-mail already registered is not registered again');
is_deeply([ map { $_->{name} } grep { $_->{email} eq 'pedro@example.org' } @{ $r->{vote}->{invites} } ], [ 'Pedro Alves' ], 'the name of the invited person');
# expected voters: the registered people and the invited e-mails that did not register yet
is_deeply([ @{ $r->{vote}->{progress} }{qw(registered voted invited_not_registered expected missing)} ], [ 5, 2, 0, 5, 3 ], 'invited people count as expected voters');

# Breedbase users: registered with their account and sent their voting link (no registration)
my %old_email = map { $_->[0] => [ $_->[1], $_->[2] ] } @{ $dbh->selectall_arrayref('SELECT sp_person_id, private_email, contact_email FROM sgn_people.sp_person WHERE sp_person_id IN (40, 42)') };
$dbh->do("UPDATE sgn_people.sp_person SET private_email = 'john.doe\@example.org' WHERE sp_person_id = 40");
$dbh->do('UPDATE sgn_people.sp_person SET private_email = NULL, contact_email = NULL WHERE sp_person_id = 42');
$r = json_get($mech, '/ajax/decision_vote/users?q=johnd');
my ($john) = grep { $_->{sp_person_id} == 40 } @{ $r->{users} };
ok($john && $john->{has_email}, 'search Breedbase users');
$r = json_get($anon, '/ajax/decision_vote/users?q=johnd');
ok($r->{error}, 'only the meeting roles search users');
$r = json_post($mech, '/ajax/decision_vote/invite_users', { vote_id => $vote_id, sp_person_ids => encode_json([ 40, 42 ]) });
is_deeply({ map { $_->{sp_person_id} => $_->{status} } @{ $r->{results} } }, { 40 => 'sent', 42 => 'no_email' }, 'voting link sent to the users with an e-mail');
my ($john_voter) = $dbh->selectrow_array(q{SELECT count(*) FROM sgn_people.sp_decision_vote_voter WHERE sp_person_id = 40 AND email = 'john.doe@example.org' AND token IS NOT NULL});
is($john_voter, 1, 'the user is registered with the e-mail of the account');
$r = json_post($mech, '/ajax/decision_vote/invite_users', { vote_id => $vote_id, sp_person_ids => encode_json([ 40 ]) });
is($r->{results}->[0]->{status}, 'recent', 'not sent again right away');
$dbh->do('UPDATE sgn_people.sp_person SET private_email = ?, contact_email = ? WHERE sp_person_id = ?', undef, @{ $old_email{$_} }, $_) for keys %old_email;

# invitations saved now and sent later
$r = json_post($mech, '/ajax/decision_vote/invite', { vote_id => $vote_id, send => 0, people => encode_json([ { name => 'Later Person', email => 'later@example.org' } ]) });
is($r->{results}->[0]->{status}, 'saved', 'invitation saved, not sent');
$r = json_get($mech, "/ajax/decision_vote/list?meeting_id=$meeting_id");
is($r->{votes}->[0]->{invitations}->{not_sent}, 1, 'the vote shows the invitations not sent yet');
$r = json_get($mech, "/ajax/decision_vote/detail?vote_id=$vote_id");
my ($later) = grep { $_->{email} eq 'later@example.org' } @{ $r->{vote}->{invites} };
ok($later && !$later->{sent} && $later->{times_sent} == 0, 'listed as not sent yet');
is($r->{vote}->{progress}->{invited_not_registered}, 1, 'an invitation not sent yet counts as an expected voter');
my ($john_invite) = grep { $_->{email} eq 'john.doe@example.org' } @{ $r->{vote}->{invites} };
ok($john_invite && $john_invite->{breedbase_user} && $john_invite->{sent}, 'Breedbase users are in the list of invitations');
$r = json_post($mech, '/ajax/decision_vote/send_pending', { vote_id => $vote_id });
is_deeply([ @$r{qw(sent remaining)} ], [ 1, 0 ], 'the invitations not sent yet are sent');
$r = json_get($mech, "/ajax/decision_vote/detail?vote_id=$vote_id");
($later) = grep { $_->{email} eq 'later@example.org' } @{ $r->{vote}->{invites} };
ok($later->{sent} && $later->{times_sent} == 1, 'now sent');
my ($later_voter) = $dbh->selectrow_array(q{SELECT count(*) FROM sgn_people.sp_decision_vote_voter WHERE email = 'later@example.org'});
is($later_voter, 1, '... and registered');
# a lost voting link: sent again from the invitation
my ($later_id) = map { $_->{invite_id} } grep { $_->{email} eq 'later@example.org' } @{ $r->{vote}->{invites} };
$r = json_post($mech, '/ajax/decision_vote/resend_invite', { vote_id => $vote_id, invite_id => $later_id });
like($r->{error}, qr/less than 2 minutes ago/, 'the link is not e-mailed again right away');
$dbh->do("UPDATE sgn_people.sp_decision_vote_invite SET invited_date = now() - interval '1 hour' WHERE sp_decision_vote_invite_id = ?", undef, $later_id);
$r = json_post($mech, '/ajax/decision_vote/resend_invite', { vote_id => $vote_id, invite_id => $later_id });
ok($r->{success}, 'voting link e-mailed again');
($later_voter) = $dbh->selectrow_array(q{SELECT count(*) FROM sgn_people.sp_decision_vote_voter WHERE email = 'later@example.org'});
is($later_voter, 1, '... the same registration');
$r = json_get($anon, "/ajax/decision_vote/public/info?token=$t3");
is($r->{voter}->{name}, 'Ana Lima', 'each voter sees only their own ballot');

$r = json_post($mech, '/ajax/decision_vote/update', { %vote, vote_id => $vote_id, start_date => $in_week, end_date => $in_week });
like($r->{error}, qr/already voted/, 'the start cannot move after today once people voted');

# closed: the results are on every link
$dbh->do('UPDATE sgn_people.sp_decision_vote SET start_date = current_date - 10, end_date = current_date - 1 WHERE sp_decision_vote_id = ?', undef, $vote_id);
$r = json_get($anon, "/ajax/decision_vote/public/info?token=$t2");
is($r->{vote}->{state}, 'closed', 'vote closed');
my %pts = map { $_->{accession} => $_ } @{ $r->{vote}->{results}->{candidates} };
# Maria: 2,1,3,4  Joao: 1,2,4,3  (4 points for place 1 ... 1 for place 4)
is($pts{test_accession1}->{points}, 7, 'points of test_accession1');
is($pts{test_accession2}->{points}, 7, 'points of test_accession2');
is($pts{test_accession3}->{points}, 3, 'points of test_accession3');
is($pts{test_accession4}->{points}, 3, 'points of test_accession4');
is($pts{test_accession1}->{place}, 1, 'tie: same place');
is($pts{test_accession2}->{place}, 1, 'tie: same place (2)');
is($pts{test_accession3}->{place}, 3, 'place after a tie');
is_deeply($pts{test_accession1}->{comments}, [ 'a bit late', 'good taste' ], 'the notes of all voters together, sorted (not in the order of voting)');
ok(!grep({ ref($_) } @{ $pts{test_accession1}->{comments} }), 'the notes carry no voter name');
is_deeply($r->{vote}->{results}->{general_comments}, [], 'the changed vote has no general comment');
is_deeply($r->{vote}->{results}->{other_notes}, [ { accession => 'test_accession5', stock_id => $r->{vote}->{results}->{other_notes}->[0]->{stock_id}, comments => [ 'nice color' ] } ],
    'notes on the accessions only for notes, in the results');
ok(!grep({ $_->{accession} eq 'test_accession5' } @{ $r->{vote}->{results}->{candidates} }), 'an accession only for notes is not ranked');
$r = json_get($anon, "/ajax/decision_vote/public/info?token=$t3");
ok($r->{vote}->{results}, 'results on every voting link, also of people who did not vote');

$r = json_post($anon, '/ajax/decision_vote/public/ballot', { token => $t1, order => encode_json([ map { "test_accession$_" } 1 .. 4 ]) });
like($r->{error}, qr/closed/, 'no vote after the end');
$r = json_post($mech, '/ajax/decision_vote/invite', { vote_id => $vote_id, people => encode_json([ { name => 'Late Person', email => 'late2@example.org' } ]) });
like($r->{error}, qr/closed/, 'no invitation after the end');

$anon->get_ok("$base/decision_vote/ballot/$t1", 'ballot page without login');

$r = json_post($mech, '/ajax/decision_vote/delete', { vote_id => $vote_id });
ok($r->{success}, 'vote deleted');
$r = json_get($anon, "/ajax/decision_vote/public/info?token=$t1");
ok($r->{error}, 'links of a deleted vote stop working');

$meeting->delete();
done_testing();
