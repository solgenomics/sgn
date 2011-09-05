
use CatalystX::GlobalContext qw( $c );

$c->res->redirect('/search/qtl/help', 301);
$c->detach();
