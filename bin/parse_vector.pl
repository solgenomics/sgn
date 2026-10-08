
use strict;

use Data::Dumper;
use CXGN::VectorViewer;

my $file = shift;

my $vv = CXGN::VectorViewer->new();

my $s = "";
open(my $F,"<", $file) || die "Can't open file $file\n";
while (<$F>) {
    $s .= $_;
}
    

my $vector = $vv->parse_genbank($s);

#my $ra = $vv->restriction_analysis('popular6bp');

print STDERR "\n\n\nPARSED OUTPUT: \n\n";
#print STDERR Dumper($vv->sequence());
print STDERR Dumper($vv->features());
print STDERR Dumper($vv->re_sites());
print STDERR Dumper($vv->metadata());
print STDERR "Sequence length: ".length($vv->sequence)."\n";

print STDERR "DONE.\n";





