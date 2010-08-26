use CatalystX::GlobalContext qw($c);
$c->forward_to_mason_view( '/index.mas',
                           schema => $c->dbic_schema('SGN::Schema'),
                          );
