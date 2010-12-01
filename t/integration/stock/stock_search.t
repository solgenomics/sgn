=head1 NAME

stock_search.t - tests for /stock/search/

=head1 DESCRIPTION

Tests for stock search page

=head1 AUTHORS

Naama Menda  <nm249@cornell.edu>

=cut

use Modern::Perl;
use Test::More;

use lib 't/lib';

BEGIN { $ENV{SGN_SKIP_CGI} = 1 } #< can skip compiling cgis, not using them here
use SGN::Test::Data qw/create_test/;
use SGN::Test::WWW::Mechanize;

{
    my $mech = SGN::Test::WWW::Mechanize->new;

    $mech->get_ok("/stock/search/");
    $mech->dbh_leak_ok;
    $mech->content_contains("Stock name");
    $mech->content_contains("Stock type");
    $mech->content_contains("Organism");
    $mech->html_lint_ok('empty stock search valid html');

    $mech->with_test_level( local => sub {
        my $stock = create_test('Stock::Stock', {
            description => "LALALALA3475",
        });

        $mech->submit_form_ok({
            with_fields => {
                stock_name => $stock->name,
            },

        },'try a test search');

        $mech->html_lint_ok('valid html after stock search');

        $mech->content_contains( $stock->name );
        $mech->content_contains( $stock->stock_id );

        #go to the stock detail page
        $mech->follow_link_ok( { url => '/stock/view/id/'.$stock->stock_id }, 'go to the stock detail page' );
        $mech->dbh_leak_ok;
        $mech->html_lint_ok( 'stock detail page html ok' );
    });
}


done_testing;
