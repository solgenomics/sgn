
=head1 NAME

qtl.t - tests for cgi-bin/qtl.pl

=head1 DESCRIPTION

Tests for cgi-bin/qtl.pl

=head1 AUTHORS

Jonathan "Duke" Leto

=cut

use strict;
use Test::More tests => 2;
use Test::WWW::Mechanize;
BAIL_OUT "Need to set the SGN_TEST_SERVER environment variable" unless $ENV{SGN_TEST_SERVER};

my $base_url = $ENV{SGN_TEST_SERVER};

{
    my $mech = Test::WWW::Mechanize->new;

    $mech->get_ok("$base_url/cgi-bin/phenome/qtl.pl");
    $mech->content_contains("A required argument is missing");
}
