#!/usr/bin/perl
use strict;
use warnings;
use English;

use CXGN::VHost::Test;

use Test::More;

my $homepage = get('/');
like( $homepage, qr/News/, 'homepage includes News');
like( $homepage, qr/Events/, 'homepage includes Events');

done_testing;
