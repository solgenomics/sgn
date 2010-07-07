
use strict;

use CXGN::DB::Connection;

my $dbh = CXGN::DB::Connection->new();

if ($dbh->isa('CXGN::DB::Connection')) { print STDERR "marker 1. yes.\n"; }
$c->forward_to_mason_view('/genomes/Solanum_lycopersicum.mas', dbh=>$dbh, basepath=>$c->get_conf('basepath') );
