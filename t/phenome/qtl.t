
=head1 NAME

qtl.t - tests for cgi-bin/qtl.pl

=head1 DESCRIPTION

Tests for cgi-bin/qtl.pl

=head1 AUTHORS

Jonathan "Duke" Leto

=cut

use strict;
use Test::More tests => 2;
use lib 't/lib';
use SGN::Test::WWW::Mechanize;

{
    my $mech = SGN::Test::WWW::Mechanize->new;

    $mech->get_ok("/phenome/qtl.pl?population_id=12&term_id=47515&chr=6&peak_marker=CT206&lod=3.8&qtl=/static/documents/tempfiles/temp_images/32f275542a55732aaee2a79ac081d37c.png");
    $mech->content_contains("genotype significance");
}
