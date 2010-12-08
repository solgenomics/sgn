=head1 NAME

t/integration/feature_search.t - integration tests for feature search URLs

=head1 DESCRIPTION

Tests for feature search URLs

=head1 AUTHORS

Jonathan "Duke" Leto

=cut

use strict;
use warnings;
use Test::More;
use lib 't/lib';
use SGN::Test;
use SGN::Test::WWW::Mechanize;

my $mech = SGN::Test::WWW::Mechanize->new;

$mech->get_ok("/feature/search");
$mech->content_contains('Feature Search');
$mech->content_contains('Feature Name');
$mech->content_contains('Feature Type');
$mech->submit_form_ok({
    form_name => 'feature_search_form',
    fields => {
        feature_name => '',
        feature_type => 1,
        organism     => 'Solanum lycopersicum',
        submit       => 'Submit',
    }
});
$mech->content_contains('Search results');
$mech->content_like(qr/results \d+-\d+ of \d+(,\d+)?/);


$mech->get("/feature/search");
$mech->submit_form_ok({
    form_name => 'feature_search_form',
    fields => {
        feature_name => 'rbuels_is_3leet',
        feature_type => '',
        organism     => 'Solanum lycopersicum',
        submit       => 'Submit',
    }
});
$mech->content_contains('Search results');
$mech->content_contains('no matching results found');

done_testing;
