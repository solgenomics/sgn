# Decision meetings: adding or fixing the breeding stage of an accession
# (/ajax/decisionmeeting/set_stage, only for the people who can create decision
# meetings) and the accessions whose stage is already a DROP stage when the
# decisions are saved: dropping again is a warning, and an accession tested
# again (advance or hold) needs a comment saying why.

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
sub json_post { my ($u, $d) = @_; $mech->post($base . $u, $d); return decode_json($mech->content); }
sub save { my $d = shift; $mech->post("$base/ajax/decisionmeeting/save_all_decisions", 'Content-Type' => 'application/json', Content => encode_json($d)); return eval { decode_json($mech->content) } || {}; }

# a meeting of the test program; the stage of its accessions is the stock property test_Stage
my $stage_term = $schema->resultset('Cv::Cvterm')->create_with({ name => 'test_Stage', cv => 'stock_property' });
my $design = $schema->resultset('Cv::Cvterm')->find({ name => 'design', 'cv.name' => 'project_property' }, { join => 'cv' });
my $mj = $schema->resultset('Cv::Cvterm')->find({ name => 'meeting_json', 'cv.name' => 'project_property' }, { join => 'cv' });
my $meeting = $schema->resultset('Project::Project')->create({ name => 'stage test meeting', description => 'test' });
my $meeting_id = $meeting->project_id();
$meeting->create_related('projectprops', { type_id => $design->cvterm_id(), value => 'Meeting' });
$meeting->create_related('projectprops', { type_id => $mj->cvterm_id(),
    value => encode_json({ meeting_name => 'stage test meeting', date => '2026-08-04', year => '2026', breeding_program_names => [ 'test' ], attendees => [ 'Jane Doe' ] }) });

my $r = json_post('/ajax/decisionmeeting/set_stage', { meeting_id => $meeting_id, stock_id => 1, breeding_program => 'test', stage => 'Y1' });
like($r->{error} // $r->{message} // '', qr/Login/i, 'login needed to change a stage');

$mech->post_ok("$base/brapi/v1/token", [ username => 'janedoe', password => 'secretpw', grant_type => 'password' ], 'login');

# the accessions of the meeting come from a pipeline run linked to it
my $dir = $f->config->{cluster_shared_tempdir} . '/script_factory_files';
make_path($dir);
my $run_id = 'sf_run_dmStage' . $$;
write_file("$dir/$run_id.meta.json", encode_json({ sp_person_id => 41, mode => 'full', script_name => 'Stage test model', dataset_name => 'test dataset', created => '2026-08-01T10:00:00' }));
write_file("$dir/$run_id.results.json", encode_json({
    summary => { traits => [ 'yield' ], n_trials => 2 },
    genotype_values => [ map { +{ accession => "test_accession$_", yield => 10 - $_ } } 1 .. 4 ],
    genotype_values_long => [],
    stage2 => [ { trait => 'yield', h2 => 0.5, n_trials => 2 } ],
    recipe => { index => { traits => { yield => { direction => 'increase' } } } },
    index => { method => 'smith-hazel', selection_pct => 50, n_selected => 2, n_ranked => 4,
               table => [ map { +{ accession => "test_accession$_", index => 5 - $_, rank => $_, selected => ($_ <= 2 ? 1 : 0) } } 1 .. 4 ] },
    zones => [],
}));
$r = json_post('/ajax/decision_evidence/link', { meeting_id => $meeting_id, keys => "run:$run_id", action => 'link' });
ok($r->{success}, 'run linked') or diag explain $r;
$r = json_get("/ajax/decision_evidence/sources?meeting_id=$meeting_id");
ok($r->{can_set_stage}, 'the people who create meetings can change stages');

# the stages of the configuration
$r = json_get('/ajax/decisionmeeting/set_stage');
my @stages = @{ $r->{stages} || [] };
ok(scalar(@stages) >= 2, 'breeding stages of the configuration') or diag explain $r;
like($r->{year_format}, qr/^(yy|yyyy)$/, 'how the stage values write the year');

$r = json_get("/ajax/decisionmeeting/decisions?meeting_id=$meeting_id");
my %row = map { $_->{accession} => $_ } @{ $r->{rows} };
is($row{test_accession2}->{stage}, '', 'no stage yet');
my $sid2 = $row{test_accession2}->{stock_id};
my $sid3 = $row{test_accession3}->{stock_id};

$r = json_post('/ajax/decisionmeeting/set_stage', { meeting_id => $meeting_id, stock_id => $sid2, breeding_program => 'test', stage => 'NOT_A_STAGE' });
like($r->{message} // $r->{error} // '', qr/not a breeding stage/, 'only the stages of the configuration');
$r = json_post('/ajax/decisionmeeting/set_stage', { meeting_id => $meeting_id, stock_id => $sid2, breeding_program => 'test', stage => $stages[0] });
ok($r->{success}, 'stage added') or diag explain $r;
ok($r->{draft}, 'a draft of the meeting');
ok(!$schema->resultset('Stock::Stockprop')->search({ stock_id => $sid2, type_id => $stage_term->cvterm_id() })->count, 'nothing written on the accession before the meeting is saved');
is($r->{stage}, "ON-26-$stages[0]", 'stored like the decisions: state, year of the meeting, stage');
$r = json_get("/ajax/decisionmeeting/decisions?meeting_id=$meeting_id");
%row = map { $_->{accession} => $_ } @{ $r->{rows} };
is($row{test_accession2}->{stage}, "ON-26-$stages[0]", 'the row shows the new stage');
$r = json_post('/ajax/decisionmeeting/set_stage', { meeting_id => $meeting_id, stock_id => $sid2, breeding_program => 'test', stage => $stages[1] });
is($r->{stage}, "ON-26-$stages[1]", 'a stage can be fixed');
$r = json_post('/ajax/decisionmeeting/set_stage', { meeting_id => $meeting_id, stock_id => $sid2, breeding_program => 'test', stage => $stages[1], year => 1800 });
like($r->{message} // $r->{error} // '', qr/year must be/, 'only a sensible year');
$r = json_post('/ajax/decisionmeeting/set_stage', { meeting_id => $meeting_id, stock_id => $sid2, breeding_program => 'test', stage => $stages[1], year => 2024 });
is($r->{stage}, "ON-24-$stages[1]", 'the year chosen in the dialog');
$r = json_post('/ajax/decisionmeeting/set_stage', { meeting_id => $meeting_id, stock_id => $sid2, breeding_program => 'test', stage => $stages[1] });
is($r->{stage}, "ON-26-$stages[1]", 'without a year: the year of the meeting');

# Clear cache on the page clears every draft decision of the meeting
$r = json_post('/ajax/decision_evidence/draft', { meeting_id => $meeting_id, rows => encode_json([
    { accession => 'test_accession1', breeding_program => 'test', decision => 'drop' },
    { accession => 'test_accession2', breeding_program => 'test', decision => 'hold' } ]) });
ok($r->{success}, 'two draft decisions');
$r = json_get("/ajax/decision_evidence/sources?meeting_id=$meeting_id");
is($r->{n_drafts}, 2, 'drafts kept with the meeting');
is($r->{n_stage_changes}, 1, 'the stage set during the meeting is a draft too');
$r = json_post('/ajax/decision_evidence/draft', { meeting_id => $meeting_id, rows => '[]', clear_all => 1 });
ok($r->{success}, 'all drafts cleared') or diag explain $r;
$r = json_get("/ajax/decision_evidence/sources?meeting_id=$meeting_id");
is($r->{n_drafts}, 0, 'no draft decision left');
is($r->{n_stage_changes}, 0, 'the draft stage is dropped too');
$r = json_get("/ajax/decisionmeeting/decisions?meeting_id=$meeting_id");
%row = map { $_->{accession} => $_ } @{ $r->{rows} };
is($row{test_accession2}->{stage}, '', 'the accession is back to its stored stage (none)');
$r = json_post('/ajax/decisionmeeting/set_stage', { meeting_id => $meeting_id, stock_id => $sid2, breeding_program => 'test', stage => $stages[1] });
is($r->{stage}, "ON-26-$stages[1]", 'stage set again (draft)');

# advance: the next stage; from the last stage, the same stage with the new year
$r = json_post('/ajax/decisionmeeting/compute_new_stage', { current_stage => "ON-25-$stages[0]", decision => 'advance', year => '2026', meeting_date => '2026-08-04', stock_id => $sid2, selected_stage => $stages[1] });
is($r->{new_stage}, "ON-26-$stages[1]", 'advance to the next stage, always ON');
$r = json_post('/ajax/decisionmeeting/compute_new_stage', { current_stage => "ON-24-$stages[-1]", decision => 'advance', year => '2026', meeting_date => '2026-08-04', stock_id => $sid2 });
is_deeply($r->{allowed_stages}, [ $stages[-1] ], 'the last stage can be advanced: it is repeated');
$r = json_post('/ajax/decisionmeeting/compute_new_stage', { current_stage => "ON-24-$stages[-1]", decision => 'advance', year => '2026', meeting_date => '2026-08-04', stock_id => $sid2, selected_stage => $stages[-1] });
is($r->{new_stage}, "ON-26-$stages[-1]", 'advance from the last stage: same stage, year of the meeting');
$r = json_post('/ajax/decisionmeeting/compute_new_stage', { current_stage => "OFF-25-$stages[0]", decision => 'advance', year => '2026', meeting_date => '2026-08-04', stock_id => $sid2, selected_stage => $stages[1] });
is($r->{new_stage}, "ON-26-$stages[1]", 'advancing an OFF accession puts it ON');
$r = json_post('/ajax/decisionmeeting/compute_new_stage', { current_stage => "OFF-25-$stages[0]", decision => 'hold', year => '2026', meeting_date => '2026-08-04', stock_id => $sid2 });
is($r->{new_stage}, "OFF-26-$stages[0]", 'hold keeps the state of the current stage');

# test_accession3 and test_accession4 were dropped before
my $sid4 = $row{test_accession4}->{stock_id};
$schema->resultset('Stock::Stockprop')->create({ stock_id => $_, type_id => $stage_term->cvterm_id(), value => "DROP-23-$stages[1]", rank => 0 }) for $sid3, $sid4;

$r = save({ meeting_id => $meeting_id, meeting_notes => 'notes',
            accessions => [ { accession => 'test_accession3', breeding_program => 'test', decision => 'drop', new_stage => '' } ] });
ok($r->{needs_confirm}, 'dropping an accession already dropped is a warning, not an error') or diag explain $r;
is($r->{already_dropped}->[0]->{reason}, 'already_dropped', 'reason: already dropped');
$r = save({ meeting_id => $meeting_id, meeting_notes => 'notes',
            accessions => [ { accession => 'test_accession3', breeding_program => 'test', decision => 'hold', new_stage => '' } ] });
ok($r->{needs_confirm}, 'tested again without a comment: a warning');
is($r->{already_dropped}->[0]->{reason}, 'needs_comment', 'reason: a comment is needed');
like($r->{message}, qr/comment/i, 'the warning asks for a comment');
# state OFF = commercial checks of other companies: not in the decision table, no decision on them
my $sid1 = $row{test_accession1}->{stock_id};
$schema->resultset('Stock::Stockprop')->create({ stock_id => $sid1, type_id => $stage_term->cvterm_id(), value => "OFF-25-$stages[0]", rank => 0 });
$r = json_get("/ajax/decisionmeeting/decisions?meeting_id=$meeting_id");
ok(!grep({ $_->{accession} eq 'test_accession1' } @{ $r->{rows} }), 'an OFF accession (commercial check) is not a decision row');
is_deeply([ map { $_->{accession} } @{ $r->{off_checks} } ], [ 'test_accession1' ], 'it is listed among the commercial checks');
$r = save({ meeting_id => $meeting_id, meeting_notes => 'notes',
            accessions => [ { accession => 'test_accession1', breeding_program => 'test', decision => 'advance', new_stage => "ON-26-$stages[1]", save_comment => 'x' } ] });
like($r->{error} // $r->{message} // '', qr/not in the accessions of this meeting/, 'no decision on a commercial check');
# OFF-25-X back to ON-25-X: a draft, written when the meeting is saved
$r = json_post('/ajax/decisionmeeting/set_stage', { meeting_id => $meeting_id, stock_id => $sid1, breeding_program => 'test', stage => $stages[0], year => 2025 });
is($r->{stage}, "ON-25-$stages[0]", 'OFF put back ON, same stage and year');
is($r->{stage_before}, "OFF-25-$stages[0]", 'the stored value is kept as the one before');
$r = json_get("/ajax/decision_evidence/sources?meeting_id=$meeting_id");
ok(!$r->{meeting}->{saved}, 'nothing saved after a warning');

# saving again: the accession dropped again is left out; test_accession3, tested again, comes back
# with a comment; the others are saved
$r = json_post('/ajax/decisionmeeting/compute_new_stage', { current_stage => "ON-26-$stages[1]", decision => 'hold', year => '2026', meeting_date => '2026-08-04', stock_id => $sid2 });
my $hold2 = $r->{new_stage};
$r = json_post('/ajax/decisionmeeting/compute_new_stage', { current_stage => "DROP-23-$stages[1]", decision => 'hold', year => '2026', meeting_date => '2026-08-04', stock_id => $sid3 });
my $hold3 = $r->{new_stage};
ok($hold3 && $hold3 !~ /^DROP/, 'holding a dropped accession tested again brings it back') or diag explain $r;
$r = save({ meeting_id => $meeting_id, meeting_notes => 'notes', skip_dropped => 1,
            accessions => [ { accession => 'test_accession2', breeding_program => 'test', decision => 'hold', new_stage => $hold2 },
                            { accession => 'test_accession3', breeding_program => 'test', decision => 'hold', new_stage => $hold3, save_comment => 'tested again: good yield in 2026' },
                            { accession => 'test_accession4', breeding_program => 'test', decision => 'drop', new_stage => '' } ] });
ok($mech->success, 'saved, leaving out the accession already dropped') or diag $mech->content;
my $stage_of = sub { my $p = $schema->resultset('Stock::Stockprop')->search({ stock_id => shift, type_id => $stage_term->cvterm_id() }, { order_by => { -desc => 'stockprop_id' } })->first; $p ? $p->value : '' };
is($stage_of->($sid4), "DROP-23-$stages[1]", 'the accession dropped again is unchanged');
is($stage_of->($sid3), $hold3, 'the accession tested again, with a comment, is saved');
is($stage_of->($sid2), $hold2, 'the other decisions are saved');
is($stage_of->($sid1), "ON-25-$stages[0]", 'the draft stage (OFF back to ON) is written when the meeting is saved');

# the charts of the Decisions tab: the program's accessions by stage, active and dropped apart
$r = json_get('/ajax/decisionmeeting/program_stages?programs=test');
my ($pt) = @{ $r->{programs} || [] };
is($pt->{property}, 'test_Stage', 'stage property of the program');
is($pt->{active}, 3, 'three active accessions');
is($pt->{on}, 3, 'three ON: the held ones and the one put back ON (the funnel counts ON only)');
is($pt->{dropped}, 1, 'one dropped accession');
is_deeply($pt->{drops}, [ { year => 2023, stage => $stages[1], n => 1 } ], 'drops by year of the drop and stage');
is_deeply($r->{config_stages}, \@stages, 'stages of the configuration, in order');
is(ref($r->{stage_rates}), 'HASH', 'target rates of the ideal funnel (breeding_stage_rates; empty: smooth decrease)');

# the meeting report lists the selected varieties (here none advanced) with the variety profile link
$mech->get_ok("$base/ajax/decisionmeeting/meeting_report_html?meeting_id=$meeting_id");
$mech->content_contains('Selected varieties', 'the report has the selected varieties');

# a saved meeting: its stages cannot change any more
$r = json_post('/ajax/decisionmeeting/set_stage', { meeting_id => $meeting_id, stock_id => $sid1, breeding_program => 'test', stage => $stages[0], year => 2025 });
like($r->{message} // $r->{error} // '', qr/saved/, 'no stage change once the meeting is saved');

# set_stage needs the role that creates meetings
$mech = Test::WWW::Mechanize->new;
$mech->post_ok("$base/brapi/v1/token", [ username => 'johndoe', password => 'secretpw', grant_type => 'password' ], 'login as a user who cannot create meetings');
$r = json_post('/ajax/decisionmeeting/set_stage', { meeting_id => $meeting_id, stock_id => $sid2, breeding_program => 'test', stage => $stages[0] });
like($r->{message} // $r->{error} // '', qr/create decision meetings/, 'other users cannot change a stage');

# clean up
unlink "$dir/$run_id.results.json", "$dir/$run_id.meta.json";
$schema->resultset('Project::Project')->find({ project_id => $meeting_id })->delete();
$schema->resultset('Stock::Stockprop')->search({ type_id => $stage_term->cvterm_id() })->delete();
$stage_term->delete();
$f->clean_up_db();
done_testing();
