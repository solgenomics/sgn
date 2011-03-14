use Modern::Perl;
use CatalystX::GlobalContext qw( $c );
use CXGN::DB::Connection;

my $dbh = CXGN::DB::Connection->new();

$c->forward_to_mason_view('/cview/index.mas', dbh=>$dbh);
