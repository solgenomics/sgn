
use strict;

use Data::Dumper;
use CXGN::VectorViewer;

my $file = shift;

my $vv = CXGN::VectorViewer->new();

#open(my $F,"<", $file) || die "Can't open file $file\n";

my $vector = $vv->parse_genbank($file);

my $ra = $vv->restriction_analysis('popular6bp');

print STDERR Dumper($vector);






