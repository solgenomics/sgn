# The evidence of decision meetings (SGN::Controller::AJAX::DecisionEvidence):
# a meeting decides on the accessions of the analyses linked to it. An
# Analysis Pipeline run that is not stored is kept as a copy with the meeting.
# Decisions are kept as drafts until they are saved, then the meeting is closed.

use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use File::Path qw(make_path);
use File::Slurp qw(write_file);
use JSON;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema();
my $base = 'http://localhost:3010';
my $mech = Test::WWW::Mechanize->new;

sub json_get { my $u = shift; $mech->get_ok($base . $u); return decode_json($mech->content); }
sub json_post { my ($u, $d) = @_; $mech->post_ok($base . $u, $d); return decode_json($mech->content); }

# a meeting of the test program; the stage of its accessions is the stock property test_Stage
my $stage_term = $schema->resultset('Cv::Cvterm')->create_with({ name => 'test_Stage', cv => 'stock_property' });
# a meeting of the test program
my $design = $schema->resultset('Cv::Cvterm')->find({ name => 'design', 'cv.name' => 'project_property' }, { join => 'cv' });
my $mj = $schema->resultset('Cv::Cvterm')->find({ name => 'meeting_json', 'cv.name' => 'project_property' }, { join => 'cv' });
my $meeting = $schema->resultset('Project::Project')->create({ name => 'evidence test meeting', description => 'test' });
my $meeting_id = $meeting->project_id();
$meeting->create_related('projectprops', { type_id => $design->cvterm_id(), value => 'Meeting' });
$meeting->create_related('projectprops', { type_id => $mj->cvterm_id(),
    value => encode_json({ meeting_name => 'evidence test meeting', date => '2026-08-04', year => '2026', breeding_program_names => [ 'test' ], attendees => [ 'Jane Doe' ] }) });

my $r = json_get("/ajax/decision_evidence/sources?meeting_id=$meeting_id");
like($r->{error}, qr/logged in/, 'login needed');

$mech->post_ok("$base/brapi/v1/token", [ username => 'janedoe', password => 'secretpw', grant_type => 'password' ], 'login');

# a pipeline run of janedoe (sp_person_id 41), with results, not stored
my $dir = $f->config->{cluster_shared_tempdir} . '/script_factory_files';
make_path($dir);
my $run_id = 'sf_run_dmTest' . $$;
write_file("$dir/$run_id.meta.json", encode_json({ sp_person_id => 41, mode => 'full', script_name => 'Evidence test model', dataset_name => 'test dataset', created => '2026-08-01T10:00:00' }));
write_file("$dir/$run_id.results.json", encode_json({
    summary => { traits => [ 'yield', 'height' ], n_trials => 2 },
    genotype_values => [ map { +{ accession => "test_accession$_", yield => 10 - $_, height => $_ } } 1 .. 4 ],
    genotype_values_long => [],
    stage2 => [ { trait => 'yield', h2 => 0.5, n_trials => 2 } ],
    recipe => { index => { traits => { yield => { direction => 'increase' } } } },
    index => { method => 'smith-hazel', selection_pct => 50, n_selected => 2, n_ranked => 4,
               table => [ map { +{ accession => "test_accession$_", index => 5 - $_, rank => $_, selected => ($_ <= 2 ? 1 : 0) } } 1 .. 4 ] },
    zones => [],
}));

$r = json_get('/ajax/decision_evidence/available');
my ($run) = grep { $_->{run_id} eq $run_id } @{ $r->{runs} };
ok($run, 'the run is offered as evidence') or diag explain $r;
is($run->{key}, "run:$run_id", 'run key');
ok(ref($r->{analyses}) eq 'ARRAY', 'stored analyses are offered');

$r = json_get("/ajax/decision_evidence/sources?meeting_id=$meeting_id");
is_deeply($r->{sources}, [], 'no evidence yet');
ok($r->{can_link} && $r->{can_decide}, 'curator can add evidence and decide');

$r = json_post('/ajax/decision_evidence/link', { meeting_id => $meeting_id, keys => 'run:sf_run_doesNotExist', action => 'link' });
ok($r->{error}, 'unknown run refused');

$r = json_post('/ajax/decision_evidence/link', { meeting_id => $meeting_id, keys => "run:$run_id", action => 'link' });
ok($r->{success}, 'run linked') or diag explain $r;
is($r->{changed}, 1, 'one source added');

$r = json_get("/ajax/decision_evidence/sources?meeting_id=$meeting_id");
is(scalar(@{ $r->{sources} }), 1, 'one source');
is($r->{sources}->[0]->{n_accessions}, 4, 'four accessions in the run');
is($r->{sources}->[0]->{n_selected}, 2, 'two selected by the index');
is_deeply([ map { $_->{accession} } @{ $r->{accessions} } ], [ map { "test_accession$_" } 1 .. 4 ], 'meeting accessions come from the evidence');
is_deeply($r->{accessions}->[0]->{selected_in}, [ "run:$run_id" ], 'selected by the run');

# the copy is used once the temporary files are gone
unlink "$dir/$run_id.results.json", "$dir/$run_id.meta.json";
$r = json_get("/ajax/decision_evidence/evidence?meeting_id=$meeting_id&key=run:$run_id");
is(scalar(@{ $r->{rows} }), 4, 'evidence read from the copy kept with the meeting') or diag explain $r;
my ($a1) = grep { $_->{accession} eq 'test_accession1' } @{ $r->{rows} };
is($a1->{index_rank}, 1, 'index rank');
is($a1->{values}->{yield}->{rank}, 1, 'trait rank');
$r = json_get("/ajax/decision_evidence/evidence?meeting_id=$meeting_id&key=analysis:1");
like($r->{error}, qr/not part/, 'only sources of the meeting');

# decisions: the meeting's accessions x programs, no list needed
$r = json_get("/ajax/decisionmeeting/decisions?meeting_id=$meeting_id");
is(scalar(@{ $r->{rows} }), 4, 'one decision row per accession and program') or diag explain $r;
is($r->{rows}->[0]->{breeding_program}, 'test', 'program of the meeting');

$r = json_post('/ajax/decision_evidence/draft', { meeting_id => $meeting_id, rows => encode_json([
    { accession => 'test_accession1', breeding_program => 'test', decision => 'hold', new_stage => '', save_comment => 'one more year' },
    { accession => 'test_accession4', breeding_program => 'test', decision => 'drop', new_stage => '', save_comment => '' } ]) });
ok($r->{success}, 'draft saved') or diag explain $r;
$r = json_get("/ajax/decision_evidence/sources?meeting_id=$meeting_id");
is($r->{n_drafts}, 2, 'two draft decisions');
$r = json_get("/ajax/decisionmeeting/decisions?meeting_id=$meeting_id");
my %dec = map { $_->{accession} => $_ } @{ $r->{rows} };
is($dec{test_accession1}->{decision}, 'hold', 'draft decision on the row');
is($dec{test_accession1}->{save_comment}, 'one more year', 'draft comment on the row');
$r = json_post('/ajax/decision_evidence/draft', { meeting_id => $meeting_id, rows => encode_json([ { accession => 'test_accession4', breeding_program => 'test', decision => '' } ]) });
$r = json_get("/ajax/decision_evidence/sources?meeting_id=$meeting_id");
is($r->{n_drafts}, 1, 'a cleared decision leaves the draft');

# save for good
$mech->post("$base/ajax/decisionmeeting/save_all_decisions", 'Content-Type' => 'application/json', Content => encode_json({
    meeting_id => $meeting_id, meeting_notes => 'notes',
    accessions => [ { accession => 'test_accession1', breeding_program => 'test', decision => 'hold', save_comment => 'one more year' },
                    { accession => 'no_such_accession', breeding_program => 'test', decision => 'drop' } ] }));
like($mech->content, qr/not in the accessions of this meeting/, 'only accessions of the meeting can be decided');
# the page computes the new stage of each decision before saving
$r = json_post('/ajax/decisionmeeting/compute_new_stage', { current_stage => '', decision => 'hold', year => '2026', meeting_date => '2026-08-04', stock_id => $dec{test_accession1}->{stock_id} });
ok(defined $r->{new_stage}, 'new stage of the decision') or diag explain $r;
$mech->post("$base/ajax/decisionmeeting/save_all_decisions", 'Content-Type' => 'application/json', Content => encode_json({
    meeting_id => $meeting_id, meeting_notes => 'notes',
    accessions => [ { accession => 'test_accession1', breeding_program => 'test', decision => 'hold', new_stage => $r->{new_stage}, save_comment => 'one more year' } ] }));
ok($mech->success, 'decisions saved') or diag $mech->content;
$r = json_get("/ajax/decision_evidence/sources?meeting_id=$meeting_id");
ok($r->{meeting}->{saved}, 'meeting is saved');
is($r->{n_drafts}, 0, 'no draft after saving');
$r = json_get("/ajax/decisionmeeting/decisions?meeting_id=$meeting_id");
%dec = map { $_->{accession} => $_ } @{ $r->{rows} };
is($dec{test_accession1}->{decision}, 'hold', 'saved decision shown');
is($dec{test_accession1}->{saved}, 1, 'rows are marked saved');
$r = json_post('/ajax/decision_evidence/draft', { meeting_id => $meeting_id, rows => encode_json([ { accession => 'test_accession2', breeding_program => 'test', decision => 'drop' } ]) });
like($r->{error}, qr/saved/, 'no draft once saved');
$r = json_post('/ajax/decision_evidence/link', { meeting_id => $meeting_id, keys => "run:$run_id", action => 'unlink' });
like($r->{error}, qr/permanent record/, 'evidence of a saved meeting cannot be removed');

# clean up
$schema->resultset('Project::Project')->find({ project_id => $meeting_id })->delete();
$schema->resultset('Stock::Stockprop')->search({ type_id => $stage_term->cvterm_id() })->delete();
$stage_term->delete();
$f->clean_up_db();
done_testing();
