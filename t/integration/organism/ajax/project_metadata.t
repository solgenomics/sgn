## a simple test for the organism ajax functions 
## Lukas Mueller, Jan 2011

use lib 't/lib';
use Test::Most;
use Modern::Perl;
use SGN::Test::Data qw/create_test/;
use SGN::Test::WWW::Mechanize;

my $mech = SGN::Test::WWW::Mechanize->new();

$mech->with_test_level( local => sub {

    my $organism = create_test('Organism::Organism', { });
    my $o_id = $organism->organism_id;

    # diag("created temp organism $o_id");

    $mech->get_ok("/organism/$o_id/metadata/?action=view");

    $mech->content_contains('html');

    $mech->while_logged_in( { user_type=>'submitter' }, sub {
        $mech->get_ok("/organism/$o_id/metadata/?action=store&genome_project_funding_agencies=NSF&object_id=-$o_id") or diag $mech->content();
        $mech->content_contains('success');
        $mech->get_ok("/organism/$o_id/metadata/?action=view");
        $mech->content_contains('NSF');
        $mech->get_ok("/organism/$o_id/metadata/?action=store&genome_project_funding_agencies=USDA&object_id=-$o_id");
        $mech->content_contains('success');
        $mech->get_ok("/organism/$o_id/metadata/?action=view");
        $mech->content_contains('USDA');
    });
});


done_testing;
