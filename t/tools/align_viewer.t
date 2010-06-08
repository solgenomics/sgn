=head1 NAME

bulk.t - a website-level test of the align_viewer

=head1 DESCRIPTION

Tests the align_viewer.

=head1 AUTHORS

Jonathan "Duke" Leto

=cut

use strict;
use Test::More tests => 4;
use Test::WWW::Mechanize;
die "Need to set the SGN_TEST_SERVER environment variable" unless defined($ENV{SGN_TEST_SERVER});

my $base_url = $ENV{SGN_TEST_SERVER};

{
    my $mech = Test::WWW::Mechanize->new;

    $mech->get_ok("$base_url/tools/align_viewer/index.pl");
    $mech->content_contains("Alignment Analyzer");
    $mech->get_ok("$base_url/tools/align_viewer/show_align.pl");
    $mech->content_contains("No sequence data provided!");
}

