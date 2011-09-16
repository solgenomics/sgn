use strict;
use CatalystX::GlobalContext qw( $c );

#pending until a controller for the help documents is written
$c->forward_to_mason_view('/help/faq.mas');
