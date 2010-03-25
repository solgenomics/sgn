#!/usr/bin/perl
use Test::More tests => 6;

use strict;
use warnings;
use Carp;

use CXGN::VHost::Test;
use CXGN::Phenome::GenericGenePage;
use CXGN::DB::Connection;

$SIG{__DIE__} = \&Carp::confess;

my $dbh = CXGN::DB::Connection->new({ dbargs => {AutoCommit => 1} });

my $ggp = CXGN::Phenome::GenericGenePage
    ->new( -id => 428,
	   -dbh => $dbh,
	 );

test_xml( $ggp->render_xml );

# now test it on the site
my $url = '/phenome/generic_gene_page.pl';
my $result = get( "$url?locus_id=428" );
test_xml( $result );

sub test_xml {
    my $x = shift;
    like( $x, qr/dwarf/, 'result looks OK');
    like( $x, qr/<gene/, 'result looks OK');
    like( $x, qr/<data_provider>/, 'result looks OK');
}
