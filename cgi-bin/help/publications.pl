use strict;
use warnings;
use CXGN::Page;
use File::Slurp qw/slurp/;
use CatalystX::GlobalContext '$c';

my $documents_folder= $c->config->{'basepath'} . $c->config->{'documents_subdir'};
my $page=CXGN::Page->new('SOL Publications','john');
my $PUBLICATIONS=slurp("$documents_folder/SGNpublications.txt")||'';
$page->header('SGN Publications','SGN Publications');
print $PUBLICATIONS;
$page->footer();
