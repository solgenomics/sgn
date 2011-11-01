use strict;
use warnings;


use CatalystX::GlobalContext qw( $c );

my $sp_person_id = CXGN::Login->new($c->dbc->dbh)->verify_session();


if ($sp_person_id)
{
    $c->res->redirect('/qtl/form');
    $c->detach();    
}
