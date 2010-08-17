use SGN::Controller::Organism;
use CatalystX::GlobalContext qw( $c );
SGN::Controller::Organism->new( $c, {} )->sgn_data( $c );
