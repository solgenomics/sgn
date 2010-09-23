use CatalystX::GlobalContext qw($c);

use strict;

use CXGN::DB::Connection;

my $dbh = CXGN::DB::Connection->new();

$c->forward_to_mason_view(
    '/genomes/Solanum_lycopersicum.mas',
    dbh      => $dbh,
    basepath => $c->get_conf('basepath'),
    cview_tempfiles_subdir => $c->tempfiles_subdir('cview'),
   );
