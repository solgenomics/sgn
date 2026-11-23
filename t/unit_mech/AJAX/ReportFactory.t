
# Report Factory endpoints (/ajax/report/*): catalog, list checks, input validation, access to runs.
# Report runs themselves are not started here (they need the job backend).

use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use JSON;
use CXGN::List;
use CXGN::People::Person;

my $f = SGN::Test::Fixture->new();
my $dbh = $f->dbh();
my $base = 'http://localhost:3010';

# not logged in
my $anon = Test::WWW::Mechanize->new;
$anon->get_ok("$base/ajax/report/catalog");
like(decode_json($anon->content)->{error}, qr/logged in/, 'catalog needs a login');

my $mech = Test::WWW::Mechanize->new;
$mech->post_ok("$base/brapi/v1/token", [ username => 'janedoe', password => 'secretpw', grant_type => 'password' ]);

# catalog: the configured scripts with the inputs detected from their source
$mech->get_ok("$base/ajax/report/catalog");
my $catalog = decode_json($mech->content);
is(ref($catalog->{reports}), 'ARRAY', 'catalog lists reports');
ok($catalog->{is_curator}, 'janedoe is a curator');
foreach my $r (@{ $catalog->{reports} }) {
    ok($r->{name} =~ /^[A-Za-z0-9_]+$/, "report name $r->{name}");
    is_deeply([ sort keys %{ $r->{inputs} } ], [qw(accessions dates traits trials)], "inputs of $r->{name}");
}

# lists
my $janedoe_id = CXGN::People::Person->get_person_by_username($dbh, 'janedoe');
my $trial_list_id = CXGN::List::create_list($dbh, 'report_factory_trials', 'test', $janedoe_id);
my $trial_list = CXGN::List->new({ dbh => $dbh, list_id => $trial_list_id });
$trial_list->type('trials');
$trial_list->add_bulk([ 'test_trial', 'no_such_trial_xyz' ]);

my $acc_list_id = CXGN::List::create_list($dbh, 'report_factory_accessions', 'test', $janedoe_id);
my $acc_list = CXGN::List->new({ dbh => $dbh, list_id => $acc_list_id });
$acc_list->type('accessions');
$acc_list->add_bulk([ 'test_accession1', 'test_accession2' ]);

$mech->get_ok("$base/ajax/report/list_info?kind=trials&list_id=$trial_list_id");
my $info = decode_json($mech->content);
is($info->{error}, undef, 'trial list accepted');
is($info->{n_items}, 2, 'two items');
is($info->{n_found}, 1, 'one trial found');
is($info->{n_missing}, 1, 'one item missing');
is_deeply($info->{missing}, [ 'no_such_trial_xyz' ], 'missing item named');
is(ref($info->{facts}), 'HASH', 'facts about the trials');
ok(!exists $info->{ids}, 'ids are not sent to the page');

$mech->get_ok("$base/ajax/report/list_info?kind=accessions&list_id=$acc_list_id");
$info = decode_json($mech->content);
is($info->{n_found}, 2, 'two accessions found');

$mech->get_ok("$base/ajax/report/list_info?kind=trials&list_id=$acc_list_id");
like(decode_json($mech->content)->{error}, qr/list of accessions; a list of trials is needed/, 'wrong list type refused');

$mech->get_ok("$base/ajax/report/list_info?kind=plots&list_id=$acc_list_id");
like(decode_json($mech->content)->{error}, qr/Unknown list kind/, 'unknown kind refused');

$mech->get_ok("$base/ajax/report/list_info?kind=trials&list_id=999999999");
like(decode_json($mech->content)->{error}, qr/does not exist/, 'missing list');

# run: validation (nothing is started)
$mech->get_ok("$base/ajax/report/run");
like(decode_json($mech->content)->{error}, qr/POST/, 'run needs POST');

$mech->post_ok("$base/ajax/report/run", [ reportData => encode_json({ reports => [ 'no_such_report' ] }) ]);
like(decode_json($mech->content)->{error}, qr/Choose at least one report/, 'unknown report refused');

$mech->post_ok("$base/ajax/report/run", [ reportData => 'not json' ]);
like(decode_json($mech->content)->{error}, qr/Invalid request/, 'invalid request refused');

my ($with_inputs) = grep { $_->{installed} && grep { $_ } values %{ $_->{inputs} } } @{ $catalog->{reports} };
SKIP: {
    skip 'no installed report that takes inputs', 4 if !$with_inputs;
    $mech->post_ok("$base/ajax/report/run", [ reportData => encode_json({ reports => [ $with_inputs->{name} ] }) ]);
    like(decode_json($mech->content)->{error}, qr/needs/, "$with_inputs->{name} without inputs refused");

    $mech->post_ok("$base/ajax/report/run", [ reportData => encode_json({ reports => [ $with_inputs->{name} ], start_date => '2025-05-01', end_date => '2025-01-01', trial_list_id => $trial_list_id }) ]);
    like(decode_json($mech->content)->{error}, qr/start date is after the end date/, 'dates in the wrong order refused');
}

# runs: only the user's own
$mech->get_ok("$base/ajax/report/runs");
is(ref(decode_json($mech->content)->{runs}), 'ARRAY', 'runs listed');

$mech->get_ok("$base/ajax/report/results?run_id=../../etc");
like(decode_json($mech->content)->{error}, qr/Invalid report run/, 'invalid run id refused');

$mech->get_ok("$base/ajax/report/results?run_id=rf_20000101_000000_abcdef");
like(decode_json($mech->content)->{error}, qr/no longer exists/, 'unknown run');

$mech->get_ok("$base/ajax/report/download?run_id=rf_20000101_000000_abcdef&file=meta.json");
like(decode_json($mech->content)->{error}, qr/no longer exists/, 'download of an unknown run refused');

$mech->get_ok("$base/tools/report");
$mech->content_contains('Report Factory', 'page loads');

CXGN::List::delete_list($dbh, $_) for ($trial_list_id, $acc_list_id);

done_testing();
