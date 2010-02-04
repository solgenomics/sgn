#!/usr/bin/perl
use strict;
use warnings;
use English;

use CXGN::VHost::Test;

use Test::More tests => 1;

my $homepage = get('/');
like( $homepage, qr/Toolbar.js/, 'homepage includes Toolbar.js');

