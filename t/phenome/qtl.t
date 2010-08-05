
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

    $mech->get_ok("$base_url/cgi-bin/phenome/qtl.pl?population_id=12&term_id=47515&chr=7&l_marker=SSR286&p_marker=SSR286&r_marker=CD57&lod=3.9&qtl=/documents/tempfiles/temp_images/1a1a5391641c653884fbc9d6d8be5c90.png");
    $mech->content_contains("genotype significance");
}
