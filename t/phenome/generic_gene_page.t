#!/usr/bin/perl
use strict;
use warnings;
use English;

use CXGN::VHost::Test;

use Test::More tests => 1;

my $url = '/phenome/generic_gene_page.pl';

my $result = get( "$url?locus_id=428" );
like( $result, qr/dwarf/, 'result looks OK');
like( $result, qr/<xml/, 'result looks OK');
like( $result, qr/<data_provider>/, 'result looks OK');





