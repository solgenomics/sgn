use CatalystX::GlobalContext qw( $c );

$c->res->redirect('/search/qtl', 301);
$c->detach();
