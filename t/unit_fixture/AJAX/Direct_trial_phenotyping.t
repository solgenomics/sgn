use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;

my $mech = Test::WWW::Mechanize->new;
my $response;
$mech->post_ok('http://localhost:3010/breeders/trial_phenotyping?trial_id=137',["plot_name" => "test_trial21", "select_traits_for_trait_file" => "76664", "select_pheno_value" => "20"]);
ok($mech->success);

done_testing();
