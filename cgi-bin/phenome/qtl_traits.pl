use strict;
use warnings;


use CatalystX::GlobalContext qw( $c );


my $index = $c->req->param('index');
$c->res->redirect("/qtl/traits/$index");
$c->detach();    



