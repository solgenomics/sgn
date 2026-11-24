# Satellite page models (step 5) and results (step 6): /ajax/satellite/crops,
# trial_info, run, status, results, file, save_indices. Checks and permissions
# run always; a real run (Sentinel-2 images read by R on the server) only with
# SATELLITE_NETWORK_TESTS=1.

use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use JSON;
use SGN::Model::Cvterm;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;
my $base = 'http://localhost:3010';
my $trial_id = $schema->resultset('Project::Project')->find({ name => 'test_trial' })->project_id;
my $pheno_trial_id = $schema->resultset('Project::Project')->find({ name => 'Kasese solgs trial' })->project_id;    # has phenotypes

my @added;
END {
    local $?;
    eval { $_->delete for @added; 1 } or diag("could not remove the test plot coordinates: $@");
    eval { $f->clean_up_db(); 1 } or diag("clean_up_db failed: $@");
}

sub login {
    my ($user, $pw) = @_;
    my $m = Test::WWW::Mechanize->new(autocheck => 0);
    $m->post("$base/brapi/v1/token", [ username => $user, password => $pw, grant_type => 'password' ]);
    is($m->status, 200, "$user logged in");
    return $m;
}
sub answer { my $m = shift; return decode_json($m->content) }
sub run_req { my ($m, $req) = @_; $m->post("$base/ajax/satellite/run", [ request => encode_json($req) ]); return answer($m) }

# a square around Ithaca (test_location) and small boxes in it
my ($lon, $lat) = (-76.4697, 42.4503);
my $box = sub { my ($x, $y, $d) = @_; [ [$x, $y], [$x + $d, $y], [$x + $d, $y + $d], [$x, $y + $d] ] };
my $site = sub { my %a = @_; return { id => 1, name => 'Ithaca', center => [ $lon, $lat ], size_m => 500, %a } };

# ------------------------------------------------------------ logged out
my $anon = Test::WWW::Mechanize->new(autocheck => 0);
$anon->post("$base/ajax/satellite/run", [ request => '{}' ]);
is($anon->status, 401, 'run needs login');
$anon->get("$base/ajax/satellite/status?run_id=sat_1_000001");
is($anon->status, 401, 'status needs login');

my $jane = login('janedoe', 'secretpw');

# ------------------------------------------------------------ crops, trial info
$jane->get_ok("$base/ajax/satellite/crops");
my $crops = answer($jane)->{crops};
ok(@$crops >= 1 && $crops->[0]{species} && $crops->[0]{accessions} > 0, 'crops: species of the accessions') or diag(explain($crops));

$jane->get_ok("$base/ajax/satellite/trial_info?trial_ids=$trial_id,$pheno_trial_id");
my ($info) = grep { $_->{trial_id} == $trial_id } @{ answer($jane)->{trials} };
my ($pinfo) = grep { $_->{trial_id} == $pheno_trial_id } @{ answer($jane)->{trials} };
is($info->{trial_id}, $trial_id, 'trial info');
ok($info->{species}, 'trial species');
is($info->{planting}, '2017-07-04', 'planting date');
is($info->{plots_with_coordinates}, 0, 'no plot coordinates in the fixture');
ok(@{ $pinfo->{traits} } > 0 && defined $pinfo->{traits}[0]{mean} && $pinfo->{traits}[0]{n} > 0, 'numeric traits with means') or diag(explain($pinfo));
$jane->get("$base/ajax/satellite/trial_info");
like(answer($jane)->{error}, qr/No trial/, 'trial info needs trials');

# ------------------------------------------------------------ run: what is refused before starting
$jane->get("$base/ajax/satellite/run?request={}");
like(answer($jane)->{error}, qr/Use POST/, 'run needs POST');
my $dates = { start => '2025-07-01', end => '2025-08-31' };
like(run_req($jane, { dates => $dates, models => {}, sites => [ $site->() ] })->{error}, qr/at least one model/, 'no model');
like(run_req($jane, { dates => { start => '2025-09-01', end => '2025-08-01' }, models => { crop_map => 1 }, sites => [ $site->() ] })->{error}, qr/dates are not valid/, 'bad dates');
like(run_req($jane, { dates => $dates, models => { crop_map => 1 }, classes => [ { id => 'crop', name => 'Maize' } ], sites => [ $site->() ] })->{error}, qr/at least 2 classes/, 'one class');
like(run_req($jane, { dates => $dates, models => { crop_map => 1 }, classes => [ { id => 'crop', name => 'Maize' }, { id => 'c_forest', name => 'Forest' } ],
    sites => [ $site->(labels => [ { class => 'crop', ring => $box->($lon, $lat, 0.0005) } ]) ] })->{error}, qr/examples of every class.*Forest/, 'a class without examples');
like(run_req($jane, { dates => $dates, models => { crop_map => 1 }, classes => [ { id => 'crop', name => 'Maize' }, { id => 'c_forest', name => 'Forest' } ],
    sites => [ $site->(labels => [ { class => 'nope', ring => $box->($lon, $lat, 0.0005) } ]) ] })->{error}, qr/unknown class/, 'an example of an unknown class');
like(run_req($jane, { dates => $dates, models => { indices => 1 }, sites => [ $site->(plots_trial_id => $trial_id) ] })->{error}, qr/trial with plot coordinates/, 'indices without plot coordinates');
like(run_req($jane, { dates => $dates, models => { yield => 1 }, sites => [ $site->(targets => [ { name => 'F', ring => $box->($lon, $lat, 0.001) } ]) ],
    calibration => [ map { { name => "C$_", ring => $box->($lon + $_ * 0.001, $lat, 0.0008), yield => 5000 + $_, start => '2025-05-01', end => '2025-09-30' } } 1 .. 3 ] })->{error},
    qr/at least 8 calibration fields.*there are 3/, 'too few calibration fields');
like(run_req($jane, { dates => $dates, models => { yield => 1 }, sites => [ $site->() ], calibration => [], calibration_trials => [ $trial_id ], yield => {} })->{error},
    qr/yield trait/, 'calibration trials need the yield trait');
like(run_req($jane, { dates => $dates, models => { yield => 1 }, sites => [ $site->() ], calibration_trials => [ $pheno_trial_id ], yield => { trait_id => $pinfo->{traits}[0]{id} } })->{error},
    qr/needs at least 8.*Kasese solgs trial: no (field|planting date)/, 'a trial that cannot be used is left out, and says why');
like(run_req($jane, { dates => $dates, models => { crop_map => 1 }, classes => [ { id => 'crop', name => 'A' }, { id => 'c_b', name => 'B' } ], sites => [ $site->(size_m => 50000) ] })->{error}, qr/no area/, 'area too large');

# ------------------------------------------------------------ status / results of runs
$jane->get("$base/ajax/satellite/status?run_id=../../etc/passwd");
like(answer($jane)->{error}, qr/Invalid run/, 'run ids are checked');
$jane->get("$base/ajax/satellite/results?run_id=sat_1_000001");
like(answer($jane)->{error}, qr/does not exist/, 'unknown run');

SKIP: {
    skip 'set SATELLITE_NETWORK_TESTS=1 for a real run (Sentinel-2 images)', 17 if !$ENV{SATELLITE_NETWORK_TESTS};

    # plots of test_trial in a field near Ithaca
    my $geo_type = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot_geo_json', 'stock_property');
    my $plot_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id;
    my @plots = map { $_->[0] } @{ $schema->storage->dbh->selectall_arrayref(
        "SELECT DISTINCT s.stock_id FROM stock s JOIN nd_experiment_stock nes ON (nes.stock_id = s.stock_id)
         JOIN nd_experiment_project nep ON (nep.nd_experiment_id = nes.nd_experiment_id)
         WHERE s.type_id = ? AND nep.project_id = ? ORDER BY s.stock_id LIMIT 4", undef, $plot_type_id, $trial_id) };
    my $k = 0;
    foreach my $id (@plots) {
        my $ring = $box->($lon - 0.0006 + $k++ * 0.0003, $lat - 0.0003, 0.00025);
        push @added, $schema->resultset('Stock::Stockprop')->create({ stock_id => $id, type_id => $geo_type->cvterm_id, rank => 0,
            value => encode_json({ type => 'Feature', geometry => { type => 'Polygon', coordinates => [ [ @$ring, $ring->[0] ] ] } }) });
    }
    my $r = run_req($jane, { dates => $dates, models => { crop_map => 1, indices => 1 },
        classes => [ { id => 'crop', name => 'Field' }, { id => 'c_other', name => 'Other' } ],
        sites => [ $site->(plots_trial_id => $trial_id, labels => [
            { class => 'crop', ring => $box->($lon - 0.0015, $lat - 0.0015, 0.0006) }, { class => 'crop', ring => $box->($lon + 0.0008, $lat - 0.0015, 0.0006) },
            { class => 'c_other', ring => $box->($lon - 0.0015, $lat + 0.0008, 0.0006) }, { class => 'c_other', ring => $box->($lon + 0.0008, $lat + 0.0008, 0.0006) } ]) ] });
    ok(!$r->{error} && $r->{run_id}, 'run started') or diag($r->{error});
    my $run = $r->{run_id};

    my $fred = login('freddy', 'atgc');
    $fred->get("$base/ajax/satellite/status?run_id=$run");
    like(answer($fred)->{error}, qr/another user/, 'a run is only for its user');

    my $st = {};
    for (1 .. 160) {
        $jane->get("$base/ajax/satellite/status?run_id=$run");
        $st = answer($jane);
        last if ($st->{status} // '') ne 'running';
        sleep 3;
    }
    is($st->{status}, 'done', 'run done') or diag(explain($st));
    $jane->get_ok("$base/ajax/satellite/results?run_id=$run");
    my $res = answer($jane);
    my $s = $res->{sites}[0];
    ok($s->{dates_used} > 0, 'images used');
    ok($res->{crop_map} && $s->{map} && $s->{map}{ncol} == 51, 'crop map of the 500 m square (51 pixels of 10 m)') or diag(explain($s->{map} && { %{ $s->{map} }, rle => undef }));
    ok($s->{indices} && $s->{indices}{values} > 0, 'plot indices computed') or diag(explain($s->{indices}));

    $jane->get("$base/ajax/satellite/file?run_id=$run&name=site1.map.tif");
    is($jane->status, 200, 'map GeoTIFF downloads');
    is(substr($jane->content, 0, 2), 'II', 'it is a TIFF');
    $jane->get("$base/ajax/satellite/file?run_id=$run&name=../../etc/passwd");
    like(answer($jane)->{error}, qr/Unknown file/, 'file names are checked');

    $fred->post("$base/ajax/satellite/save_indices", [ run_id => $run, trial_id => $trial_id ]);
    like(answer($fred)->{error}, qr/another user/, 'another user cannot store them');
    $jane->post("$base/ajax/satellite/save_indices", [ run_id => $run, trial_id => $trial_id ]);
    my $sv = answer($jane);
    ok($sv->{success} && $sv->{values} > 0, 'indices stored as phenotypes') or diag(explain($sv));
    my ($n) = $schema->storage->dbh->selectrow_array("SELECT count(*) FROM phenotype ph JOIN cvterm c ON (c.cvterm_id = ph.cvalue_id)
        JOIN public.dbxref x ON (x.dbxref_id = c.dbxref_id) JOIN db ON (db.db_id = x.db_id) WHERE db.name = 'SATIDX'");
    is($n, $sv->{values}, 'one phenotype per plot, index and date');
    my ($dated) = $schema->storage->dbh->selectrow_array("SELECT count(*) FROM phenotype ph JOIN cvterm c ON (c.cvterm_id = ph.cvalue_id)
        JOIN public.dbxref x ON (x.dbxref_id = c.dbxref_id) JOIN db ON (db.db_id = x.db_id) WHERE db.name = 'SATIDX' AND ph.collect_date IS NOT NULL");
    is($dated, $n, 'each with its image date');
    $jane->get_ok("$base/ajax/satellite/results?run_id=$run");
    ok(answer($jane)->{saved_indices}{$trial_id}, 'the run remembers it was stored');
}

done_testing();
