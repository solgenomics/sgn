#!/usr/bin/perl
use Test::More tests => 6;

use strict;
use warnings;
use Carp;
use lib 't/lib';
use SGN::Test::WWW::Mechanize;
use CXGN::Phenome::GenericGenePage;

$SIG{__DIE__} = \&Carp::confess;


my $mech = SGN::Test::WWW::Mechanize->new;

my $dbh = $mech->context->dbc->dbh();

my $ggp = CXGN::Phenome::GenericGenePage
    ->new( -id => 428,
	   -dbh => $dbh,
	 );

test_xml( $ggp->render_xml );

# now test it on the site
my $url = '/phenome/generic_gene_page.pl';
$mech->get( "$url?locus_id=428" );
test_xml( $mech->content );

sub test_xml {
    my ($content) = @_;
    like( $content, qr/dwarf/, 'result looks OK');
    like( $content, qr/<gene/, 'result looks OK');
    like( $content, qr/<data_provider>/, 'result looks OK');
}
