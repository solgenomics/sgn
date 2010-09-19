use strict;
use warnings;


use CXGN::People::Person;

use CGI qw / param /;

use Bio::Chado::Schema;
use CXGN::Login;


use CatalystX::GlobalContext qw( $c );

my $q = CGI->new();


my $schema   = $c->dbic_schema( 'Bio::Chado::Schema', 'sgn_chado' );
my $dbh = $c->dbc->dbh;

my $login = CXGN::Login->new($dbh);

my $person_id = $login->has_session();

my $user = CXGN::People::Person->new($dbh, $person_id);

my $stock_id = $q->param("stock_id") ;
my $action =  $q->param("action");


$c->forward_to_mason_view('/stock/index.mas',  action=> $action,  stock_id => $stock_id , user=>$user, schema=>$schema);



#############

