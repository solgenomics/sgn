=head1 NAME

t/integration/feature.t - integration tests for feature URLs

=head1 DESCRIPTION

Tests for feature URLs

=head1 AUTHORS

Jonathan "Duke" Leto

=cut

use strict;
use warnings;
use Test::More;
use Test::JSON;
use lib 't/lib';
use SGN::Test;
use SGN::Test::WWW::Mechanize;

my $base_url = $ENV{SGN_TEST_SERVER};
my $mech = SGN::Test::WWW::Mechanize->new;

$mech->get_ok("$base_url/feature/search");
$mech->content_contains('Feature Search');
$mech->content_contains('Feature Name');
$mech->content_contains('Feature Type');
$mech->submit_form_ok({
    form_name => 'feature_search_form',
    fields => {
        feature_name => '',
        feature_type => 'gene',
        organism     => 'Solanum lycopersicum',
        submit       => 'Submit',
    }
});
$mech->content_contains('Search Results');
$mech->content_like(qr/results 1-\d+ of \d+(,\d+)?/);

done_testing;
