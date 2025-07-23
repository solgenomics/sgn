
use strict;

use Data::Dumper;
use CXGN::Cview::VectorViewer;

my $file = shift;

my $vv = CXGN::Cview::VectorViewer->new("test", 100, 100);

open(my $F,"<", $file) || die "Can't open file $file\n";

$vv->parse_genbank($F);

my $commands = $vv->get_commands_ref();

my $ra = $vv->restriction_analysis('popular6bp');

print STDERR Dumper($commands);






