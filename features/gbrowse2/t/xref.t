use strict;
use warnings;

use Test::More;
use SGN::Context;

my $c = SGN::Context->new;

my $gb2 = $c->feature('gbrowse2');
eval { $gb2->setup }; #< may fail if web server has done it already

my @xrefs = $gb2->xrefs('Serine');

can_ok( $_, 'is_empty', 'text', 'url') for @xrefs;

#use Data::Dumper;
#diag Dumper(\@xrefs);
#diag Dumper [$gb2->data_sources];

done_testing;
