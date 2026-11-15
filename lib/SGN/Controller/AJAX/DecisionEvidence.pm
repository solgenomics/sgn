
=head1 NAME

SGN::Controller::AJAX::DecisionEvidence - the evidence of a decision meeting

=head1 DESCRIPTION

A decision meeting (/breeders/meeting) decides on the accessions of one or
more analyses, its evidence. An evidence source is either

  - a run of the Analysis Pipeline (the runs listed on the user's personal
    page): key run:<run_id>. Run files are temporary, so a copy of the
    evidence is kept with the meeting (projectprop decision_meeting_evidence).
    A run that was stored as an analysis is linked as that analysis.
  - a stored analysis (/analyses): key analysis:<project_id>. Analysis
    Pipeline analyses give genotype values, ranks, selection index and zones;
    other analyses give their stored values per accession.

The sources are kept in the meeting's meeting_json, related_analyses:
[{source, analysis_id | run_id, name, kind, accessions, selected, linked_by,
linked_at, after_save}] (older entries have only analysis_id and name). The
accessions of the meeting are the accessions of its sources. Once the
decisions are saved, sources can still be added but not removed, and a linked
analysis cannot be deleted (ScriptFactory::meetings_using_analysis).

Endpoints (login needed):

  GET  /ajax/decision_evidence/sources    meeting_id: meeting, sources, accessions, permissions
  GET  /ajax/decision_evidence/available  pipeline runs of the user and stored analyses to add
  POST /ajax/decision_evidence/link       meeting_id, keys (comma list), action link|unlink
  GET  /ajax/decision_evidence/evidence   meeting_id, key: values per accession of one source
  POST /ajax/decision_evidence/draft      meeting_id, rows (JSON): decisions not saved yet

=head1 AUTHOR

Chris Simoes <ccs263@cornell.edu>

=cut

package SGN::Controller::AJAX::DecisionEvidence;

use Moose;
use JSON;
use DateTime;
use Try::Tiny;
use File::Slurp qw | read_file |;
use File::Basename qw | basename |;
use SGN::Model::Cvterm;
use CXGN::JSONUtils qw(decode_stored_json);
use CXGN::Phenotypes::PhenotypeMatrix;
use SGN::Controller::AJAX::ScriptFactory;
use SGN::Controller::AJAX::DecisionMeeting;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
);

my $SNAPSHOT_TYPE = 'decision_meeting_evidence';
my $MAX_RUNS = 200;

sub _fail {
    my ($c, $msg) = @_;
    $c->stash->{rest} = { error => $msg };
    return;
}

sub _login {
    my $c = shift;
    return 1 if $c->user();
    _fail($c, 'You must be logged in to use decision meetings.');
    return 0;
}

sub _schema { return (SGN::Controller::AJAX::ScriptFactory::_schemas(shift))[0]; }

sub _user_id { return SGN::Controller::AJAX::ScriptFactory::_user_id(shift); }

sub _arr { my $x = shift; return ref($x) eq 'ARRAY' ? $x : []; }

# roles allowed to save decisions (decision_role in the configuration)
sub can_decide {
    my $c = shift;
    my $roles = SGN::Controller::AJAX::DecisionMeeting->_configured_meeting_roles($c->config->{decision_role});
    my %ok = map { $_ => 1 } @$roles;
    return (grep { $ok{lc($_ // '')} } $c->user()->roles()) ? 1 : 0;
}

# key of a source entry of meeting_json related_analyses
sub source_key {
    my $s = shift;
    return if ref($s) ne 'HASH';
    return "run:$s->{run_id}" if ($s->{run_id} // '') =~ /^sf_run_[A-Za-z0-9_]+$/;
    return "analysis:$1" if ($s->{analysis_id} // '') =~ /^(\d+)$/;
    return;
}

sub _sources_of { return [ grep { defined source_key($_) } @{ _arr(shift->{related_analyses}) } ]; }

sub _meeting {
    my ($schema, $meeting_id) = @_;
    return if ($meeting_id // '') !~ /^\d+$/;
    my ($m) = @{ SGN::Controller::AJAX::ScriptFactory::_meetings($schema, $meeting_id) };
    return $m;
}

# ---------------------------------------------------------------------------
# evidence of one source
# ---------------------------------------------------------------------------

# a stored analysis: {analysis_id, name, description, is_pipeline, owner_id} or undef
sub _analysis_info {
    my ($schema, $analysis_id) = @_;
    return if ($analysis_id // '') !~ /^\d+$/;
    my ($name, $description, $meta, $owner) = $schema->storage->dbh()->selectrow_array(
        "SELECT p.name, p.description, pp.value,
                coalesce((SELECT po.sp_person_id::text FROM phenome.project_owner po WHERE po.project_id = p.project_id ORDER BY po.project_owner_id LIMIT 1),
                         (SELECT u.value FROM projectprop u JOIN cvterm ut ON ut.cvterm_id = u.type_id AND ut.name = 'project_sp_person_id'
                           WHERE u.project_id = p.project_id LIMIT 1))
           FROM project p
           JOIN projectprop pp ON pp.project_id = p.project_id
           JOIN cvterm t ON t.cvterm_id = pp.type_id AND t.name = 'analysis_metadata_json'
          WHERE p.project_id = ? LIMIT 1", undef, $analysis_id);
    return if !defined $name;
    return { analysis_id => $analysis_id + 0, name => $name, description => $description,
             is_pipeline => ($meta // '') =~ /Breedbase (?:Analysis Pipeline|Script Factory)/ ? 1 : 0, owner_id => $owner };
}

# values stored by an analysis made with another tool: one value per accession
# and trait (the mean when an accession has several), ranked high to low
sub _generic_evidence {
    my ($c, $info) = @_;
    my $schema = _schema($c);
    my @data = try {
        CXGN::Phenotypes::PhenotypeMatrix->new(bcs_schema => $schema, search_type => 'Native', data_level => 'analysis_instance',
            experiment_type => 'analysis_experiment', trial_list => [ $info->{analysis_id} ])->get_phenotype_matrix();
    } catch { () };
    return { error => 'The values of this analysis cannot be read.' } if !@data;
    my $header = shift @data;
    my %col = map { ($header->[$_] // '') => $_ } 0 .. $#$header;
    my $acc_col = $col{germplasmName};
    my $first = defined $col{plantNumber} ? $col{plantNumber} + 1 : undef;
    return { error => 'The values of this analysis cannot be read.' } if !defined($acc_col) || !defined($first);
    my @tcols = grep { ($header->[$_] // '') ne '' && $header->[$_] ne 'notes' } $first .. $#$header;
    my (%sum, %n, %stock);
    foreach my $row (@data) {
        my $a = $row->[$acc_col] // next;
        $stock{$a} //= defined $col{germplasmDbId} ? $row->[ $col{germplasmDbId} ] : undef;
        foreach my $i (@tcols) {
            my $v = $row->[$i];
            next if !defined($v) || $v !~ /^\s*-?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?\s*$/;
            $sum{$a}{ $header->[$i] } += $v;
            $n{$a}{ $header->[$i] }++;
        }
    }
    my @traits = grep { my $t = $_; grep { $n{$_}{$t} } keys %n } map { $header->[$_] } @tcols;
    my %rows = map { my $a = $_; ($a => { accession => $a, stock_id => ($stock{$a} ? $stock{$a} + 0 : undef),
        values => { map { $_ => ($n{$a}{$_} ? { v => $sum{$a}{$_} / $n{$a}{$_} } : undef) } @traits } }) } keys %stock;
    foreach my $t (@traits) {
        my @a = sort { $rows{$b}{values}{$t}{v} <=> $rows{$a}{values}{$t}{v} } grep { $rows{$_}{values}{$t} } keys %rows;
        $rows{ $a[$_] }{values}{$t}{rank} = $_ + 1 for 0 .. $#a;
    }
    return {
        analysis_id => $info->{analysis_id}, name => $info->{name}, description => $info->{description},
        dashboard => "/analyses/$info->{analysis_id}", value_label => 'Value',
        traits => [ map { +{ trait => $_, label => (s/\|.*$//r), direction => '' } } @traits ],
        index => undef, zone_targets => [],
        rows => [ map { $rows{$_} } sort keys %rows ],
    };
}

# evidence of an analysis as it is now (pipeline or other tool)
sub analysis_evidence {
    my ($c, $analysis_id) = @_;
    my $info = _analysis_info(_schema($c), $analysis_id);
    return { error => 'This analysis does not exist.' } if !$info;
    return SGN::Controller::AJAX::ScriptFactory::evidence_data($c, $analysis_id) if $info->{is_pipeline};
    return _generic_evidence($c, $info);
}

# a run of the Analysis Pipeline that the user may use: {meta} or {error}
sub _run_access {
    my ($c, $run_id) = @_;
    return { error => 'Invalid analysis run.' } if ($run_id // '') !~ /^sf_run_[A-Za-z0-9_]+$/;
    my $meta = SGN::Controller::AJAX::ScriptFactory::_run_meta($c, $run_id);
    return { error => 'This pipeline run is no longer available (temporary files are cleaned regularly).' } if !$meta;
    return { error => 'This pipeline run belongs to another user.' }
        if ($meta->{sp_person_id} // -1) != _user_id($c) && !$c->user()->check_roles('curator');
    return { meta => $meta };
}

sub _snapshot_type {
    my ($schema, $create) = @_;
    my $t = SGN::Model::Cvterm->get_cvterm_row($schema, $SNAPSHOT_TYPE, 'project_property');
    return $t if $t || !$create;
    return $schema->resultset('Cv::Cvterm')->create_with({ name => $SNAPSHOT_TYPE, cv => 'project_property' });
}

# the copy of the evidence of a run kept with a meeting
sub _snapshot {
    my ($schema, $meeting_id, $run_id) = @_;
    my $t = _snapshot_type($schema) or return;
    my $rs = $schema->resultset('Project::Projectprop')->search({ project_id => $meeting_id, type_id => $t->cvterm_id() });
    while (my $p = $rs->next()) {
        my $d = try { decode_stored_json($p->value()) } catch { undef };
        return { prop => $p, evidence => $d->{evidence} } if ref($d) eq 'HASH' && ($d->{run_id} // '') eq $run_id;
    }
    return;
}

# evidence of a source of a meeting
sub source_evidence {
    my ($c, $meeting_id, $key) = @_;
    my $schema = _schema($c);
    if (($key // '') =~ /^run:(sf_run_[A-Za-z0-9_]+)$/) {
        my $run_id = $1;
        my $s = _snapshot($schema, $meeting_id, $run_id);
        # copies made before the trait summaries were kept: the run itself while its files exist
        if ($s && ref($s->{evidence}) eq 'HASH' && !exists $s->{evidence}->{genotype_effect}) {
            my $a = _run_access($c, $run_id);
            my $live = $a->{error} ? undef : SGN::Controller::AJAX::ScriptFactory::run_evidence($c, $run_id);
            return $live if $live && !$live->{error};
        }
        return $s->{evidence} if $s && ref($s->{evidence}) eq 'HASH';
        my $a = _run_access($c, $run_id);
        return { error => $a->{error} } if $a->{error};
        return SGN::Controller::AJAX::ScriptFactory::run_evidence($c, $run_id);
    }
    return analysis_evidence($c, $1) if ($key // '') =~ /^analysis:(\d+)$/;
    return { error => 'Unknown evidence source.' };
}

# accessions and index-selected accessions of an evidence
sub _accessions_of {
    my $e = shift;
    my @rows = grep { ref($_) eq 'HASH' && defined $_->{accession} } @{ _arr($e->{rows}) };
    return ([ sort map { $_->{accession} } @rows ], [ sort map { $_->{accession} } grep { $_->{selected} } @rows ]);
}

# accession names of a meeting: those of its sources (kept when they were
# linked; older links are read from the analysis)
sub meeting_accessions {
    my ($c, $meeting_id, $data) = @_;
    my (%seen, @out);
    foreach my $s (@{ _sources_of($data) }) {
        my $acc = $s->{accessions};
        if (ref($acc) ne 'ARRAY') {
            my $e = source_evidence($c, $meeting_id, source_key($s));
            ($acc) = $e->{error} ? ([]) : _accessions_of($e);
        }
        push @out, grep { defined && $_ ne '' && !$seen{$_}++ } @$acc;
    }
    return [ sort @out ];
}

# ---------------------------------------------------------------------------
# endpoints
# ---------------------------------------------------------------------------

sub sources : Path('/ajax/decision_evidence/sources') Args(0) {
    my $self = shift;
    my $c = shift;
    return if !_login($c);
    my $schema = _schema($c);
    my $m = _meeting($schema, $c->req->param('meeting_id'));
    return _fail($c, 'This decision meeting does not exist.') if !$m;
    my $d = $m->{data};

    my (%in, %sel, @sources);
    foreach my $s (@{ _sources_of($d) }) {
        my $key = source_key($s);
        my ($acc, $selected) = ($s->{accessions}, $s->{selected});
        my $error;
        if (ref($acc) ne 'ARRAY') {
            my $e = source_evidence($c, $m->{meeting_id}, $key);
            $error = $e->{error};
            ($acc, $selected) = $error ? ([], []) : _accessions_of($e);
        }
        push @{ $in{$_} }, $key for @$acc;
        push @{ $sel{$_} }, $key for @{ _arr($selected) };
        my $is_run = $key =~ /^run:/;
        my $id = $is_run ? $s->{run_id} : $s->{analysis_id} + 0;
        push @sources, {
            key => $key, source => $is_run ? 'run' : 'analysis', id => $id,
            name => $s->{name} // ($is_run ? "Pipeline run $id" : "Analysis $id"),
            kind => $s->{kind} // 'pipeline',
            n_accessions => scalar(@$acc), n_selected => scalar(@{ _arr($selected) }),
            traits => _arr($s->{traits}),
            linked_by => $s->{linked_by}, linked_at => $s->{linked_at}, after_save => $s->{after_save} ? 1 : 0,
            link => $is_run ? "/tools/script_factory/results/$id"
                  : ($s->{kind} // 'pipeline') eq 'pipeline' ? "/tools/script_factory/analysis/$id" : "/analyses/$id",
            ($error ? (error => $error) : ()),
        };
    }
    my $attendees = ref($d->{attendees_list}) eq 'ARRAY' ? $d->{attendees_list} : ref($d->{attendees}) eq 'ARRAY' ? $d->{attendees} : [ grep { defined && $_ ne '' } ($d->{attendees}) ];
    my $drafts = ref($d->{draft_decisions}) eq 'HASH' ? $d->{draft_decisions} : {};
    $c->stash->{rest} = {
        meeting => {
            (map { $_ => $m->{$_} } qw(meeting_id name date year location programs saved)),
            attendees => $attendees,
            notes => $d->{meeting_notes} // $d->{notes} // $d->{data} // '',
            saved_at => $d->{saved_at},
            legacy_list => (!@sources && $d->{list_id}) ? 1 : 0,
        },
        can_link => SGN::Controller::AJAX::ScriptFactory::_can_link_meetings($c),
        can_decide => can_decide($c),
        sources => \@sources,
        accessions => [ map { +{ accession => $_, sources => $in{$_}, selected_in => $sel{$_} || [] } } sort keys %in ],
        drafts => $m->{saved} ? {} : $drafts,
        n_drafts => $m->{saved} ? 0 : scalar(grep { ($drafts->{$_}->{decision} // '') ne '' } keys %$drafts),
        history => [ grep { ref($_) eq 'HASH' } @{ _arr($d->{analyses_history}) } ],
    };
}

sub available : Path('/ajax/decision_evidence/available') Args(0) {
    my $self = shift;
    my $c = shift;
    return if !_login($c);
    my $schema = _schema($c);
    my $me = _user_id($c);

    # the user's pipeline runs with results (the runs of the personal page)
    my $dir = SGN::Controller::AJAX::ScriptFactory::_work_dir($c);
    my @runs;
    foreach my $file (glob("$dir/sf_run_*.meta.json")) {
        (my $run_id = basename($file)) =~ s/\.meta\.json$//;
        next if !-s "$dir/$run_id.results.json";
        my $m = try { decode_json(read_file($file)) } catch { undef };
        next if !$m || ($m->{sp_person_id} // -1) != $me || ($m->{mode} // 'full') eq 'preview';
        push @runs, {
            key => "run:$run_id", run_id => $run_id,
            name => ($m->{script_name} // '') ne '' ? $m->{script_name} : 'Run of ' . ($m->{dataset_name} // 'a dataset'),
            dataset_name => $m->{dataset_name}, created => $m->{created} // '',
            ($m->{stored} && ($m->{stored}->{analysis_id} // '') =~ /^\d+$/
                ? (stored_key => "analysis:$m->{stored}->{analysis_id}", stored_name => $m->{stored}->{name}) : ()),
        };
    }
    @runs = (sort { $b->{created} cmp $a->{created} } @runs)[0 .. ($#runs < $MAX_RUNS - 1 ? $#runs : $MAX_RUNS - 1)];

    # stored analyses: Analysis Pipeline ones the user can open, and the user's own other analyses
    my @analyses = map { +{ key => "analysis:$_->{analysis_id}", analysis_id => $_->{analysis_id}, name => $_->{name}, created => $_->{created} // '',
                            owner => $_->{owner}, is_owner => $_->{is_owner}, kind => 'pipeline' } }
                   @{ SGN::Controller::AJAX::ScriptFactory::_pipeline_analyses($c) };
    my %have = map { $_->{analysis_id} => 1 } @analyses;
    my $rows = $schema->storage->dbh()->selectall_arrayref(
        "SELECT p.project_id, p.name, pp.value
           FROM projectprop u
           JOIN cvterm ut ON ut.cvterm_id = u.type_id AND ut.name = 'project_sp_person_id'
           JOIN projectprop pp ON pp.project_id = u.project_id
           JOIN cvterm t ON t.cvterm_id = pp.type_id AND t.name = 'analysis_metadata_json'
           JOIN project p ON p.project_id = u.project_id
          WHERE u.value = ?", undef, "$me");
    foreach my $r (@$rows) {
        my ($id, $name, $meta) = @$r;
        next if $have{$id}++ || ($meta // '') =~ /Breedbase (?:Analysis Pipeline|Script Factory)/;
        my ($created) = ($meta // '') =~ /"create_timestamp"\s*:\s*"([^"]*)"/;
        my ($type) = ($meta // '') =~ /"analysis_model_type"\s*:\s*"([^"]*)"/;
        push @analyses, { key => "analysis:$id", analysis_id => $id + 0, name => $name, created => $created // '', is_owner => 1,
                          kind => 'analysis', model_type => $type // '' };
    }
    @analyses = sort { ($b->{created} // '') cmp ($a->{created} // '') } @analyses;
    $c->stash->{rest} = { runs => \@runs, analyses => \@analyses };
}

sub link_sources : Path('/ajax/decision_evidence/link') Args(0) {
    my $self = shift;
    my $c = shift;
    return if !_login($c);
    return _fail($c, 'Use POST.') if $c->req->method() ne 'POST';
    return _fail($c, 'Only participants of decision meetings (the roles set in the site configuration) can change the evidence of a meeting.')
        if !SGN::Controller::AJAX::ScriptFactory::_can_link_meetings($c);
    my $meeting_id = $c->req->param('meeting_id') // '';
    my $action = ($c->req->param('action') // 'link') eq 'unlink' ? 'unlink' : 'link';
    my @keys = do { my %s; grep { !$s{$_}++ } grep { /^(?:run:sf_run_[A-Za-z0-9_]+|analysis:\d+)$/ } map { s/^\s+|\s+$//gr } split /,/, ($c->req->param('keys') // '') };
    return _fail($c, 'Choose at least one analysis.') if !@keys;
    my $schema = _schema($c);
    my $m = _meeting($schema, $meeting_id);
    return _fail($c, 'This decision meeting does not exist.') if !$m;

    # what is added: read before the transaction (reading results can take a while)
    my (%entry, %snap, @notes);
    if ($action eq 'link') {
        foreach my $key (@keys) {
            my ($e, $kind, $id, $name);
            if ($key =~ /^run:(.+)$/) {
                my $run_id = $1;
                my $a = _run_access($c, $run_id);
                return _fail($c, $a->{error}) if $a->{error};
                if ($a->{meta}->{stored} && ($a->{meta}->{stored}->{analysis_id} // '') =~ /^(\d+)$/) {
                    # stored since: the analysis is the permanent record
                    my $aid = $1;
                    push @notes, "\"$a->{meta}->{stored}->{name}\" is stored as an analysis: the stored analysis was added.";
                    $key = "analysis:$aid";
                    next if $entry{$key};
                    $e = analysis_evidence($c, $aid);
                    ($kind, $id, $name) = ('pipeline', $aid, $e->{name});
                } else {
                    $e = SGN::Controller::AJAX::ScriptFactory::run_evidence($c, $run_id);
                    ($kind, $id) = ('run', $run_id);
                    $name = ($a->{meta}->{script_name} // '') ne '' ? $a->{meta}->{script_name} : 'Run of ' . ($a->{meta}->{dataset_name} // 'a dataset');
                    $name .= ' (' . substr($a->{meta}->{created} // '', 0, 10) . ')' if $a->{meta}->{created};
                    $snap{$key} = { run_id => $run_id, name => $name, evidence => $e };
                }
            } else {
                ($id) = $key =~ /(\d+)$/;
                my $info = _analysis_info($schema, $id);
                return _fail($c, "Analysis $id does not exist.") if !$info;
                $e = analysis_evidence($c, $id);
                ($kind, $name) = ($info->{is_pipeline} ? 'pipeline' : 'analysis', $info->{name});
            }
            return _fail($c, ($name // $key) . ': ' . $e->{error}) if $e->{error};
            my ($acc, $selected) = _accessions_of($e);
            return _fail($c, ($name // $key) . ': this analysis has no accession values.') if !@$acc;
            $entry{$key} = {
                ($kind eq 'run' ? (source => 'run', run_id => $id) : (source => 'analysis', analysis_id => $id + 0)),
                kind => $kind eq 'run' ? 'pipeline' : $kind, name => $name, accessions => $acc, selected => $selected,
                traits => [ map { $_->{label} // $_->{trait} } @{ _arr($e->{traits}) } ],
            };
        }
        @keys = keys %entry;
    }

    my $person = $c->user()->get_object();
    my $who = join(' ', grep { $_ } ($person->get_first_name(), $person->get_last_name()));
    my $today = DateTime->now()->ymd();
    my ($err, $n) = (undef, 0);
    try {
        $schema->txn_do(sub {
            # locked and read again: no concurrent change of the meeting is lost
            my $prop = $schema->resultset('Project::Projectprop')->search({ projectprop_id => $m->{prop}->projectprop_id() }, { for => 'update' })->single();
            my $d = SGN::Controller::AJAX::ScriptFactory::_decode_meeting($prop->value());
            my $saved = SGN::Controller::AJAX::ScriptFactory::_meeting_is_saved($d);
            my @list = grep { ref($_) eq 'HASH' } @{ _arr($d->{related_analyses}) };
            my %have = map { (source_key($_) // '') => $_ } @list;
            my @history = grep { ref($_) eq 'HASH' } @{ _arr($d->{analyses_history}) };
            my $stype = %snap ? _snapshot_type($schema, 1) : undef;
            foreach my $key (@keys) {
                my $item;
                if ($action eq 'link') {
                    next if $have{$key};
                    $item = { %{ $entry{$key} }, linked_by => $who, linked_at => $today, ($saved ? (after_save => 1) : ()) };
                    push @list, $item;
                    if ($snap{$key} && !_snapshot($schema, $m->{meeting_id}, $snap{$key}->{run_id})) {
                        my ($rank) = $schema->storage->dbh()->selectrow_array('SELECT coalesce(max(rank), -1) + 1 FROM projectprop WHERE project_id = ? AND type_id = ?',
                            undef, $m->{meeting_id}, $stype->cvterm_id());
                        $schema->resultset('Project::Projectprop')->create({ project_id => $m->{meeting_id}, type_id => $stype->cvterm_id(), rank => $rank,
                            value => JSON->new->canonical(1)->encode($snap{$key}) });
                    }
                } else {
                    $item = $have{$key} or next;
                    die "The decisions of this meeting are saved: its evidence is a permanent record and cannot be removed.\n" if $saved;
                    @list = grep { (source_key($_) // '') ne $key } @list;
                    if ($key =~ /^run:(.+)$/) {
                        my $s = _snapshot($schema, $m->{meeting_id}, $1);
                        $s->{prop}->delete() if $s;
                    }
                }
                push @history, { action => ($action eq 'link' ? 'added' : 'removed'), name => $item->{name},
                                 ($item->{run_id} ? (run_id => $item->{run_id}) : (analysis_id => $item->{analysis_id} + 0)),
                                 by => $who, on => $today, ($saved ? (after_save => 1) : ()) };
                $n++;
            }
            return if !$n;
            $d->{related_analyses} = \@list;
            $d->{analyses_history} = \@history;
            $prop->update({ value => JSON->new->canonical(1)->encode($d) });
        });
    } catch { $err = "$_"; $err =~ s/\s+$//; $err =~ s/ at \S+ line \d+\.?$//; $err =~ s/^\{UNKNOWN\}:\s*//; };
    $c->stash->{rest} = $err ? { error => $err } : { success => 1, action => $action, changed => $n, notes => \@notes };
}

sub evidence : Path('/ajax/decision_evidence/evidence') Args(0) {
    my $self = shift;
    my $c = shift;
    return if !_login($c);
    my $schema = _schema($c);
    my $m = _meeting($schema, $c->req->param('meeting_id'));
    return _fail($c, 'This decision meeting does not exist.') if !$m;
    my $key = $c->req->param('key') // '';
    return _fail($c, 'This analysis is not part of the meeting.') if !grep { (source_key($_) // '') eq $key } @{ _sources_of($m->{data}) };
    my $e = source_evidence($c, $m->{meeting_id}, $key);
    $c->stash->{rest} = $e->{error} ? { error => $e->{error} } : { %$e, key => $key };
}

# decisions not saved yet, kept with the meeting so nothing is lost when the
# page is closed: rows [{accession, breeding_program, decision, new_stage, save_comment}]
sub draft : Path('/ajax/decision_evidence/draft') Args(0) {
    my $self = shift;
    my $c = shift;
    return if !_login($c);
    return _fail($c, 'Use POST.') if $c->req->method() ne 'POST';
    return _fail($c, 'Only the roles that save decisions can change them.') if !can_decide($c);
    my $rows = try { decode_json($c->req->param('rows') // '[]') } catch { undef };
    return _fail($c, 'Invalid decisions.') if ref($rows) ne 'ARRAY';
    my $schema = _schema($c);
    my $m = _meeting($schema, $c->req->param('meeting_id'));
    return _fail($c, 'This decision meeting does not exist.') if !$m;
    my $err;
    try {
        $schema->txn_do(sub {
            my $prop = $schema->resultset('Project::Projectprop')->search({ projectprop_id => $m->{prop}->projectprop_id() }, { for => 'update' })->single();
            my $d = SGN::Controller::AJAX::ScriptFactory::_decode_meeting($prop->value());
            die "The decisions of this meeting are saved and cannot be changed.\n" if SGN::Controller::AJAX::ScriptFactory::_meeting_is_saved($d);
            my $drafts = ref($d->{draft_decisions}) eq 'HASH' ? $d->{draft_decisions} : {};
            foreach my $r (grep { ref($_) eq 'HASH' } @$rows) {
                my $k = join("\t", map { my $x = $_ // ''; $x =~ s/^\s+|\s+$//g; substr($x, 0, 255) } @$r{qw(accession breeding_program)});
                next if $k =~ /^\t|\t$/;
                my %v = map { my $x = $r->{$_} // ''; ($_ => (ref($x) ? '' : substr("$x", 0, $_ eq 'save_comment' ? 4000 : 255))) } qw(decision new_stage save_comment);
                if (join('', values %v) eq '') { delete $drafts->{$k}; } else { $drafts->{$k} = \%v; }
            }
            $d->{draft_decisions} = $drafts;
            $prop->update({ value => JSON->new->canonical(1)->encode($d) });
        });
    } catch { $err = "$_"; $err =~ s/\s+$//; $err =~ s/ at \S+ line \d+\.?$//; };
    $c->stash->{rest} = $err ? { error => $err } : { success => 1 };
}

1;
