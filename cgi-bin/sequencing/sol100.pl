use SGN::Controller::Organism;
use CatalystX::GlobalContext qw( $c );
SGN::Controller::Organism->new( $c, {} )->sol100( $c );
