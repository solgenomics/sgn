=head1 NAME

t/validate/locus_display.t - validation tests for locus_display.pl

=head1 DESCRIPTION

Validation tests for locus_display.pl

=head1 AUTHORS

Jonathan "Duke" Leto

=cut

use strict;
use warnings;
use Test::More tests => 10;

use lib 't/lib';
use SGN::Test::WWW::Mechanize;

my $url = "/phenome/locus_display.pl?locus_id=428";

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
SUBSECTIONS


my $mech = SGN::Test::WWW::Mechanize->new;
$mech->get( $url );

for my $subsection (@subsections) {
    $mech->content_contains($subsection, "$url contains $subsection");
}
