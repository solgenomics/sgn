use Test::Most;

use lib 't/lib';

use SGN::Test::WWW::Mechanize skip_cgi => 1;

my $mech = SGN::Test::WWW::Mechanize->new;

$mech->get_ok('/search/organisms');
$mech->content_contains('Organism/Taxon Search');
$mech->submit_form_ok({
    form_name => 'organism_search_form',
    fields => {
        common_name => 'tomato',
        species => 'lyco',
    },
});

$mech->content_contains('Solanum lycopersicum');

done_testing;
