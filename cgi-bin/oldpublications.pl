
use strict;

use CXGN::MasonFactory;

my $m = CXGN::MasonFactory->new();

$m->exec("/homepage/oldpublications.mas");

# use strict;
# use File::Spec;
# use CXGN::Tools::File;
# use CXGN::Page;
# use CXGN::VHost;
# my $vhost_conf=CXGN::VHost->new();
# my $documents_folder=File::Spec->catfile($vhost_conf->get_conf('homepage_files_dir'), 'publications.txt');
# my $page=CXGN::Page->new('SOL Publications','john');
# my $PUBLICATIONS=CXGN::Tools::File::file_contents("$documents_folder/publications.txt")||'';
# $page->header('SOL Publications','SOL Publications');
# print $PUBLICATIONS;
# $page->footer();
