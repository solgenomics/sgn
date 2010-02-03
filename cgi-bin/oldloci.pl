
use strict;
use CXGN::MasonFactory;

my $m = CXGN::MasonFactory->new();

$m->exec('/homepage/oldloci.mas');

# use strict;
# use CXGN::Tools::File;
# use CXGN::Page;
# use CXGN::VHost;
# my $vhost_conf=CXGN::VHost->new();
# my $documents_folder=$vhost_conf->get_conf('basepath').$vhost_conf->get_conf('documents_subdir');
# my $page=CXGN::Page->new('SOL Loci','Naama');
# my $LOCI=CXGN::Tools::File::file_contents("$documents_folder/loci.txt")||'';
# $page->header('SOL Loci','SOL Loci');
# print $LOCI;
# $page->footer();
