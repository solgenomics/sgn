
use strict;

use Test::More qw | no_plan |;
use Data::Dumper;
use CXGN::MixedModels;

my $mm = CXGN::MixedModels->new();

$mm->dependent_variables( [ "yield" ] );

$mm->fixed_factors( [ "locations", "years" ] );

$mm->random_factors(["genotypes", "blocks" ]);

### INTERACTION NOT YET IMPLEMENTED!
$mm->random_factors_interaction(["locations", "genotypes"]);

my ($ff, $error) = $mm->generate_model_sommer();

print STDERR "MODEL: ".Dumper($ff);

is($ff->[0], "yield ~ locations + years", "sommer fixed factors test");
is($ff->[1], " ~ vsr(genotypes) + vsr(blocks)", "sommer random factors test");
#is($ff->[1], " ~ genotypes+blocks+locations:genotypes", "sommer random factors test");

done_testing();
