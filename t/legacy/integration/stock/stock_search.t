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
    $mech->content_contains("Stock Id");
    $mech->content_contains("Stock name");
    $mech->content_contains("Stock type");
    $mech->content_contains("Organism");
    $mech->html_lint_ok('empty stock search valid html');

    $mech->with_test_level( local => sub {
        my $stock = create_test('Stock::Stock', {
            description => "LALALALA3475",
                                });
        my $person = $mech->create_test_user(
            first_name => 'testfirstname',
            last_name  => 'testlastname',
            user_name  => 'testusername',
            password   => 'testpassword',
            user_type  => 'submitter',
            );
        my $sp_person_id = $person->{id};
        # stock owner is now stored in phenome.stock_owner, and not in stockprop
        ### $stock->create_stockprops( {'sp_person_id' => $sp_person_id} , {cv_name => 'local'} );
        #######
        $mech->submit_form_ok({
            form_name => 'stock_search_form',
            fields    => {
                stock_name => $stock->name,
                #person =>  $person->{first_name} . ', ' . $person->{last_name},
            },
                              }, 'submitted stock search form');
        $mech->html_lint_ok('valid html after stock search');

        $mech->content_contains( $stock->name );
        $mech->content_contains("results");

        #go to the stock detail page
        $mech->follow_link_ok(
            { url => '/stock/'.$stock->stock_id.'/view' },
            "go to the stock detail page at /stock/" . $stock->stock_id . "/view"
        );
        $mech->dbh_leak_ok;
        $mech->html_lint_ok( 'stock detail page html ok' );
    });
}

{
    my $mech = SGN::Test::WWW::Mechanize->new;

    $mech->get_ok("/stock/search?advanced=1&stock_name=&stock_type=0&organism=0&search_submitted=1&page=1&page_size=20&description=&person=SolCAP+project&onto=&trait=&min_limit=&max_limit=&submit=Search");
    $mech->dbh_leak_ok;
    $mech->html_lint_ok('advanced stock search page html ok');
}


done_testing;
