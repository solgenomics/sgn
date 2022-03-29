
use strict;

use Test::More qw | no_plan |;

use CXGN::MixedModels;

my $mm = CXGN::MixedModels->new();

$mm->dependent_variables( [ "yield" ] );

$mm->fixed_factors( [ "locations", "years" ] );

$mm->random_factors(["genotypes", "blocks" ]);

$mm->random_factors_interaction(["locations", "genotypes"]);

my $ff = $mm->generate_model_sommer();

#is($ff, "yield ~ locations + years", "fixed factor test");

done_testing();
