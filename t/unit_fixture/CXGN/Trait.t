
use strict;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;

use CXGN::Trait;

my $f = SGN::Test::Fixture->new();

my $trait = CXGN::Trait->new( { bcs_schema => $f->bcs_schema(), cvterm_id => 70666 });

is($trait->name(), "fresh root weight", "check trait name");

is($trait->format(), "numeric", "check trait format");

is($trait->db(), "CO", "check db property");

is($trait->accession(), "0000012", "check accession property");

is($trait->term(), "CO:0000012", "check term property");

#is($trait->display_name(), "CO:fresh root weight", "check display name property");
is($trait->display_name(), "fresh root weight|CO:0000012", "check display name property");

done_testing();

