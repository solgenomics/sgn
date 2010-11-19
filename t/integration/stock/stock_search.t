=head1 NAME

stock_search.t - tests for /stock/search/

=head1 DESCRIPTION

Tests for stock search page

=head1 AUTHORS

Naama Menda  <nm249@cornell.edu>

=cut

use Modern::Perl;
use Test::More tests => 7;
use lib 't/lib';
use SGN::Test;
use SGN::Test::Data qw/create_test/;
use SGN::Test::WWW::Mechanize;

{
    my $mech = SGN::Test::WWW::Mechanize->new;

    $mech->get_ok("/stock/search/");

    $mech->with_test_level( local => sub {
        my $stock = create_test('Stock::Stock', {
            description => "LALALALA3475",
        });
        $mech->content_contains("Stock name");
        $mech->content_contains("Stock type");
        $mech->content_contains("Organism");

        #search a stock
        $mech->get_ok("/stock/search/?stock_name=" . $stock->name);
        # This doesn't mean it actually finds the correct stock
        $mech->content_contains($stock->name);

        # Still need more tests, stocks are not found correctly

        $mech->get_ok("/stock/search/?stock_uniquename=" . $stock->uniquename);
        # Need proper tests for above request
    }, 6);
}
