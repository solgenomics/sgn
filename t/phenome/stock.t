
=head1 NAME

stock.t - tests for cgi-bin/stock.pl

=head1 DESCRIPTION

Tests for cgi-bin/phenome/stock.pl

=head1 AUTHORS

Naama Menda  <nm249@cornell.edu>

=cut

use strict;
use warnings;
use Test::More tests => 5;
use lib 't/lib';
use SGN::Test;
use SGN::Test::WWW::Mechanize;

use CXGN::Chado::Stock;


{
    my $mech = SGN::Test::WWW::Mechanize->new;
    
    $mech->get_ok("/cgi-bin/phenome/stock.pl");
    
    $mech->with_test_level( local => sub {
	my $schema = $mech->context->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
	
	#find a stock  
	my $test_stock = $schema->resultset("Stock::Stock")->search()->first;
	my $test_id;
	$test_id = $test_stock->stock_id if $test_stock;
	$mech->get_ok("/cgi-bin/phenome/stock.pl?stock_id=$test_id");
	
	$mech->content_contains("Stock details");
	$mech->content_contains("Images");
	$mech->content_contains("User comments");
			    }, 4 );
}
