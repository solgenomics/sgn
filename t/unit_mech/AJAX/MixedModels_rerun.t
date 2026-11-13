
# Tests that a rerun of the Mixed Models tool on the same page (same
# tempfile) shows only its own results, and that a failed rerun shows an
# error instead of the results of the previous run.

use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use JSON::Any;
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
my $trait = "dry matter content percentage|CO_334:0000092";

sub run_model {
    my ($fixed_factors, $random_factors) = @_;
    my @params = (
	tempfile => $tempfile,
	engine => 'lme4',
	'dependent_variables[]' => $trait,
	);
    push @params, map { ('fixed_factors[]' => $_) } @$fixed_factors;
    push @params, map { ('random_factors[]' => $_) } @$random_factors;

    # post() keeps repeated keys (post_ok() would keep only the last value)
    $mech->post('http://localhost:3010/ajax/mixedmodels/run', \@params);
    ok($mech->success(), "run model with fixed (@$fixed_factors) and random (@$random_factors) factors");
    return JSON::Any->decode($mech->content());
}

# run 1: germplasm as random factor gives BLUPs
#
my $run1 = run_model( [ 'replicate' ], [ 'germplasmName' ]);
is($run1->{error}, undef, 'run 1 has no error');
is($run1->{method}, 'random', 'run 1 computed BLUPs');
ok($run1->{adjusted_blups_data} && %{$run1->{adjusted_blups_data}}, 'run 1 returned adjusted BLUPs');

# run 2: germplasm as fixed factor must not show the BLUPs of run 1
#
my $run2 = run_model( [ 'germplasmName' ], [ 'replicate' ]);
ok(!$run2->{adjusted_blups_data}, 'run 2 does not return the adjusted BLUPs of run 1');
ok(!$run2->{blups_data}, 'run 2 does not return the BLUPs of run 1');
if (!$run2->{error}) {
    is($run2->{method}, 'fixed', 'run 2 computed BLUEs');
    ok($run2->{adjusted_blues_data}, 'run 2 returned adjusted BLUEs');
}
else {
    diag("run 2 returned an error: $run2->{error}");
}

# run 3: a model without a random factor fails in lme4; it must show an error, not old results
#
my $run3 = run_model( [ 'germplasmName', 'replicate' ], []);
ok($run3->{error}, 'failed run 3 returns an error');
ok(!$run3->{adjusted_blups_data}, 'failed run 3 does not return old adjusted BLUPs');
ok(!$run3->{adjusted_blues_data}, 'failed run 3 does not return old adjusted BLUEs');

$ds->delete();

done_testing();
