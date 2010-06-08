require SGN::Controller::Organism;

SGN::Controller::Organism
    ->new( schema => $c->dbic_schema('Bio::Chado::Schema','sgn_chado') )
    ->search( $c );
