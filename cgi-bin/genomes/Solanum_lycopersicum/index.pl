use strict;
use warnings;

use List::Util qw/ sum min /;

use CatalystX::GlobalContext qw($c);
use CXGN::People::BACStatusLog;
use CXGN::DB::Connection;

my $dbh = CXGN::DB::Connection->new();
my $log = CXGN::People::BACStatusLog->new($dbh);

$c->forward_to_mason_view(
    '/genomes/Solanum_lycopersicum.mas',
    dbh      => $dbh,
    basepath => $c->get_conf('basepath'),
    cview_tempfiles_subdir => $c->tempfiles_subdir('cview'),
    bac_by_bac_progress => $log->bac_by_bac_progress_statistics,
   );
