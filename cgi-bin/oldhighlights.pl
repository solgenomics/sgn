
use strict;

use CXGN::MasonFactory;

my $m = CXGN::MasonFactory->new();

$m->exec("/homepage/oldhighlights.mas");



# use strict;
# use File::Spec;
# use CXGN::Tools::File;
# use CXGN::Page;
# use CXGN::VHost;
# my $vhost_conf=CXGN::VHost->new();
# my $file=File::Spec->catfile($vhost_conf->get_conf('basepath'), 'news.txt');
# my $page=CXGN::Page->new('SOL Highlights','john');
# my $NEWS=CXGN::Tools::File::file_contents("$file")||'';
# $page->header('SOL Highlights','SOL Highlights');
# print $NEWS;
# $page->footer();

