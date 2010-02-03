
use strict;

use CXGN::MasonFactory;

my $m = CXGN::MasonFactory->new();

$m->exec('/homepage/oldevents.mas');


# use strict;
# use CXGN::Tools::File;
# use CXGN::Page;
# use CXGN::VHost;
# my $vhost_conf=CXGN::VHost->new();
# my $documents_folder=$vhost_conf->get_conf('basepath').$vhost_conf->get_conf('documents_subdir');
# my $page=CXGN::Page->new('SOL Events','john');
# my $NEWS=CXGN::Tools::File::file_contents("$documents_folder/events.txt")||'';
# $page->header('SOL Events','SOL Events');
# print $NEWS;
# $page->footer();
