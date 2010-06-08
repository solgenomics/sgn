use strict;
use warnings;

use Test::More;
use Test::WWW::Mechanize;

use_ok('SGN::Controller::Organism');

plan skip_all => 'SGN_TEST_SERVER env var not set'
    unless $ENV{SGN_TEST_SERVER};

my $urlbase = "$ENV{SGN_TEST_SERVER}/search/organism.pl";
my $mech = Test::WWW::Mechanize->new;

$mech->get_ok($urlbase);
$mech->content_contains('Organism Search');
$mech->submit_form_ok({
    form_name => 'organism_search_form',
    fields => {
        common_name => 'tomato',
        species => 'lyco',
    },
});

$mech->content_contains('Solanum lycopersicum');

done_testing;
