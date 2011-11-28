use strict;
use warnings;

use CGI;
use CXGN::Phenome::Individual;
use CXGN::DB::Connection;
use CatalystX::GlobalContext qw( $c );

my $cgi = CGI->new;
my $individual_id = $cgi->param("individual_id");

my $dbh = $c->dbc->dbh;

unless ($individual_id =~m /^\d+$/) {
    $c->throw( is_error=>0,
               message => "No individual exists for identifier $individual_id",
        );
}
my $individual = CXGN::Phenome::Individual->new($dbh, $individual_id) ;
#redirecting to the stock page
my $stock_id = $individual->get_stock_id;
$c->throw(is_error=>1,
          message=>"No individual exists for identifier  $individual_id)",
        ) if !$stock_id;
print $cgi->redirect("/stock/$stock_id/view", 301);
