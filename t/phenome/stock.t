
=head1 NAME

stock_search.t - tests for /stock/search/

=head1 DESCRIPTION

Tests for stock search page

=head1 AUTHORS

Naama Menda  <nm249@cornell.edu>

=cut

use strict;
use warnings;
use Test::More tests => qw / no plan /;
use lib 't/lib';
use SGN::Test;
use SGN::Test::WWW::Mechanize;


{
    my $mech = SGN::Test::WWW::Mechanize->new;
    $mech->get_ok("/stock/search/");

    $mech->with_test_level( local => sub {
	my $schema = $mech->context->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
        $mech->content_contains("Stock name");
        $mech->content_contains("Stock type");
        $mech->content_contains("Organism");

	#search a stock
	#my $test_stock = $schema->resultset("Stock::Stock")->search()->first;
	#my $test_id;
	#$test_id = $test_stock->stock_id if $test_stock;
	#$mech->get_ok("/cgi-bin/phenome/stock.pl?stock_id=$test_id");#

#	$mech->content_contains("Images");
#	$mech->content_contains("User comments");
#			    }, 4 );
}
