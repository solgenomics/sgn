
use strict;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;

use CXGN::Trait;

my $f = SGN::Test::Fixture->new();

my $trait = CXGN::Trait->new( { bcs_schema => $f->bcs_schema(), cvterm_id => 70666 });

is($trait->name(), "fresh root weight", "check trait name");

is($trait->format(), "numeric", "check trait format");

done_testing();

