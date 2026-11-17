use strict;
use warnings;

use Test::More;
use SGN::Controller::solGS::Utils;

# clean_traits takes the ontology id off a trait name, whatever the accession looks like.
my @cases = (
    [ 'Plant height - cm|CO_322:0000996',         'Plant height - cm' ],
    [ 'Leaf curvature - score|MYONT:LEAF_6',      'Leaf curvature - score' ],
    [ 'Root depth - cm|CO_999:0001.2',            'Root depth - cm' ],
    [ 'fresh root weight|day 10|COMP:0000001',    'fresh root weight day 10' ],
    [ "plot_name\tPlant height - cm|CO_322:0000996\tLeaf curvature - score|MYONT:LEAF_6",
      "plot_name\tPlant height - cm\tLeaf curvature - score" ],
);

for my $case (@cases) {
    my ($name, $expected) = @$case;
    is(SGN::Controller::solGS::Utils->clean_traits($name), $expected, "id removed from '$name'");
}

done_testing();
