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
use Test::JSON;
use lib 't/lib';
use SGN::Test::WWW::Mechanize skip_cgi => 1;

my $mech = SGN::Test::WWW::Mechanize->new;

$mech->get_ok("/search/features");
$mech->content_like(qr/search/i);
$mech->content_contains('<script', 'yep, there is some javascript in there, hah');
$mech->html_lint_ok;

my @urls = qw(

    /search/features/feature_types_service?page=1&start=0&limit=25
    /search/features/featureprop_types_service?page=1&start=0&limit=25
    /search/features/srcfeatures_service?page=1&start=0&limit=25
    /search/features/search_service?page=1&start=0&limit=100&sort=feature_id&dir=ASC
    /search/features/search_service?organism=lycoper&type_id=22627&srcfeature_id=&srcfeature_start=&srcfeature_end=&proptype_id=&page=1&start=0&limit=100&sort=feature_id&dir=ASC
    /search/features/search_service?_dc=1321036511068&organism=lycoper&type_id=&srcfeature_id=&srcfeature_start=&srcfeature_end=&proptype_id=24269&prop_value=1&page=1&start=0&limit=100&sort=feature_id&dir=ASC
);

for my $url ( @urls ) {
    $mech->get_ok( $url );
    is_valid_json $mech->content;
}

$mech->get_ok('/search/features/export_csv?organism=lycop&type_id=22157&srcfeature_id=17638255&srcfeature_start=1&srcfeature_end=1000000');

done_testing;
