=head1 NAME

bulk.t - a website-level test of the align_viewer

=head1 DESCRIPTION

Tests the align_viewer.

=head1 AUTHORS

Jonathan "Duke" Leto

=cut

use strict;
use Test::More tests => 6;
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
{
    my $mech = Test::WWW::Mechanize->new;
    $mech->get("$base_url/tools/align_viewer/index.pl");
    my $params = {
               form_name => "aligninput",
               fields    => {
                    seq_data => ">SL1.00sc00001\nAAAGTTCAGAGAATGGATTTTCA"
               },
    };
    $mech->submit_form_ok($params, "Submit align form");
    $mech->content_contains("FASTA must have at least two valid sequences","Form requires at least 2 valid sequences");
}

