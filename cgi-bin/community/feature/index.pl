use strict;
use warnings;

use CXGN::Page;
use CatalystX::GlobalContext '$c';
use File::Slurp qw/slurp/;

my $documents_folder = $c->get_conf('basepath') . $c->get_conf('documents_subdir');
my $page = CXGN::Page->new('Featured SOL Community Labs','john');
my $LABS = slurp("$documents_folder/labs.txt")||'';
$page->header();
print $LABS;
$page->footer();
