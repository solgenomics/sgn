
# Tests that a run of the Mixed Models tool fits the model that the model
# string (the preview on the page) shows, including interaction and
# variable slope terms, for the lme4, sommer and spl2D engines.

use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use JSON::Any;
use File::Slurp;
use CXGN::Dataset;

my $f = SGN::Test::Fixture->new();

my $mech = Test::WWW::Mechanize->new;

$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ], 'login with brapi call');

my $ds = CXGN::Dataset->new( { people_schema => $f->people_schema(), schema => $f->bcs_schema() });
$ds->years( [ "2014", "2015" ]);
$ds->store();

$mech->get_ok('http://localhost:3010/ajax/mixedmodels/prepare?dataset_id='.$ds->sp_dataset_id(), 'prepare the dataset');
my $prepare = JSON::Any->decode($mech->content());
ok($prepare->{tempfile}, 'tempfile returned');

my $tempfile = $prepare->{tempfile};
my $params_file = $tempfile.".params";
$params_file =~ s{^/}{};   # tempfile is relative to the site basepath, the working directory of the test
(my $r_output_file = $params_file) =~ s/\.params$/.out/;

my $trait = "dry matter content percentage|CO_334:0000092";

# the request parameters as jQuery sends them from js/source/entries/mixedmodels.js
#
sub request_params {
    my $model = shift;
    my @params = (
	engine => $model->{engine},
	tempfile => $tempfile,
	'dependent_variables[]' => $trait,
	);
    push @params, map { ('fixed_factors[]' => $_) } @{$model->{fixed} || []};
    push @params, map { ('random_factors[]' => $_) } @{$model->{random} || []};
    foreach my $key ('fixed_factors_interaction', 'variable_slope_intersects') {
	my $terms = $model->{$key} || [];
	for (my $n = 0; $n < @$terms; $n++) {
	    push @params, map { ($key."[$n][]" => $_) } @{$terms->[$n]};
	}
    }
    return \@params;
}

sub model_string {
    my $model = shift;
    # post() keeps repeated keys (post_ok() would keep only the last value)
    $mech->post('http://localhost:3010/ajax/mixedmodels/modelstring', request_params($model));
    ok($mech->success(), "get the $model->{engine} model string");
    my $r = JSON::Any->decode($mech->content());
    is($r->{error}, undef, "no error for the $model->{engine} model string");
    return $r->{model};
}

sub run {
    my $model = shift;
    unlink($params_file, $r_output_file);
    $mech->post('http://localhost:3010/ajax/mixedmodels/run', request_params($model));
    ok($mech->success(), "run the $model->{engine} model");
    my $r = JSON::Any->decode($mech->content());
    my $params = -e $params_file ? read_file($params_file) : "";
    my %params = $params =~ m/^(\w+) <- "(.*)"$/mg;
    return ($r, \%params);
}

# lme4
#
my $lme4 = { engine => 'lme4', fixed => [ 'studyName', 'replicate' ], random => [ 'germplasmName' ], fixed_factors_interaction => [ [ 'studyName', 'replicate' ] ] };
my $model = model_string($lme4);
is($model, 'studyName + replicate + studyName*replicate + (1|germplasmName)', 'lme4 model string with interaction');

my ($run, $params) = run($lme4);
is($params->{model}, $model, 'lme4 run fits the model of the model string, with the interaction');
ok($run->{adjusted_blups_data}, 'lme4 run with interaction returned adjusted BLUPs');

my $r_output = -e $r_output_file ? read_file($r_output_file) : "";
like($r_output, qr/Formula:.*?studyName \* replicate/s, 'lme4 fitted the interaction');

$lme4 = { engine => 'lme4', fixed => [ 'studyName' ], random => [ 'germplasmName' ], variable_slope_intersects => [ [ 'replicate', 'studyName' ], [ 'replicate', 'locationName' ] ] };
$model = model_string($lme4);
is($model, 'studyName +  (1+replicate | studyName)  +  (1+replicate | locationName)  + (1|germplasmName)', 'lme4 model string with two variable slope terms, each once');

(undef, $params) = run($lme4);
is($params->{model}, $model, 'lme4 run fits the model of the model string, with the variable slope terms');

# sommer and spl2D (the results depend on the sommer version, so only the
# model given to R is checked here)
#
foreach my $engine ('sommer', 'spl2D') {
    my $sommer = { engine => $engine, fixed => [ 'replicate' ], random => [ 'germplasmName' ], fixed_factors_interaction => [ [ 'studyName', 'replicate' ] ], variable_slope_intersects => [ [ 'replicate', 'studyName' ] ] };
    my $model = model_string($sommer);
    like($model->[0], qr/ \+ studyName:replicate$/, "$engine model string has the fixed interaction in the fixed model");
    unlike($model->[1], qr/studyName:replicate/, "$engine model string does not have the fixed interaction in the random model");
    # vsr() before sommer 4.4, vsm(ism()) with sommer 4.4
    like($model->[1], qr/vsr\(replicate,studyName\)|vsm\(ism\(replicate\), ism\(studyName\)\)/, "$engine model string has the variable slope term");

    my (undef, $params) = run($sommer);
    is($params->{fixed_model}, $model->[0], "$engine run uses the fixed model of the model string, with the interaction");
    is($params->{random_model}, $model->[1], "$engine run uses the random model of the model string, with the variable slope term");
}

$ds->delete();

done_testing();
