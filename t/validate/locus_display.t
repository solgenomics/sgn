=head1 NAME

t/validate/locus_display.t - validation tests for locus_display.pl

=head1 DESCRIPTION

Validation tests for locus_display.pl

=head1 AUTHORS

Jonathan "Duke" Leto

=cut

use strict;
use warnings;
use Test::More tests => 11;
use Test::WWW::Mechanize;
BAIL_OUT "Need to set the SGN_TEST_SERVER environment variable" unless $ENV{SGN_TEST_SERVER};

my $base_url = $ENV{SGN_TEST_SERVER};
my $url      = "/phenome/locus_display.pl?locus_id=428";

my @subsections = split /\n/,<<SUBSECTIONS;
Locus details
Notes and figures
Accessions and images
Alleles
Associated loci
Associated loci - graphical view
SolCyc links
Sequence annotations
Literature annotation
Ontology annotations
User comments
SUBSECTIONS

my $mech = Test::WWW::Mechanize->new;
$mech->get("$base_url/$url");

test_subsections();

sub test_subsections {
    for my $subsection (@subsections) {
        $mech->content_contains($subsection);
    }
}
