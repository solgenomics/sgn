=head1 NAME

t/integration/phenome.t - tests for Phenome URLs

=head1 DESCRIPTION

Tests for Phenome URLs

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

$mech->while_logged_in_all( sub {
    my ($user_info) = @_;
    $mech->get_ok('/phenome/qtl_form.pl');
    $mech->submit_form_ok( {
        form_number => 2,
        fields => {
        },
    },
    );
    $mech->content_contains('Submit Population Details');
    $mech->content_contains('Select Organism');
    $mech->content_contains('Population Details');
});

done_testing;
