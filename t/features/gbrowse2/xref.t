use strict;
use warnings;

use Test::More;
use SGN::Context;

my $c = SGN::Context->new;

my $gb2 = $c->feature('gbrowse2')
    or plan skip_all => 'gbrowse2 feature not available';

eval { $gb2->setup }; #< may fail if web server has done it already

my @xrefs = $gb2->xrefs('Serine');

can_ok( $_, 'preview_image_url', 'is_empty', 'text', 'url') for @xrefs;

done_testing;
