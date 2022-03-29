
use strict;

use Test::More qw | no_plan |;

use CXGN::MixedModels;

my $mm = CXGN::MixedModels->new();

$mm->dependent_variables( [ "yield" ] );

$mm->fixed_factors( [ "locations", "years" ] );

$mm->random_factors(["genotypes", "blocks" ]);

$mm->random_factors_interaction(["locations", "genotypes"]);

my ($ff, $error) = $mm->generate_model_sommer();

is($ff, "mmer( yield ~ locations + years, random= ~ genotypes+blocks+locations:genotypes", "sommer expression test");

done_testing();
