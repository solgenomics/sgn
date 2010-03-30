use strict;
use warnings;

use Test::More;
use SGN::Context;

my $c = SGN::Context->new;

my $gb2 = $c->feature('gbrowse2')
    or plan skip_all => 'gbrowse2 feature not available';

eval { $gb2->setup }; #< may fail if web server has done it already

my @sources = $gb2->data_sources;

can_ok( $_, 'url', 'name', 'description') for @sources;

#use Data::Dumper;
#diag Dumper(\@xrefs);
#diag Dumper [$gb2->data_sources];

done_testing;
