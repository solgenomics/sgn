use strict;
use warnings;


use CXGN::People::Person;

use CGI qw / param /;
use CXGN::DB::Connection;
use CXGN::Login;


our $c;
my $q = CGI->new();
my $dbh = CXGN::DB::Connection->new();
my $login = CXGN::Login->new($dbh);

my $person_id = $login->has_session();

my $user = CXGN::People::Person->new($dbh, $person_id);

my $locus_id = $q->param("locus_id") ;
my $action =  $q->param("action");


$c->forward_to_mason_view('/locus/index.mas',  action=> $action,  locus_id => $locus_id , user=>$user, dbh=>$dbh);



#############

