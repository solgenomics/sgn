use strict;
use warnings;
use Test::More;
use Data::Dumper;

BEGIN {
    $ENV{SGN_SKIP_CGI} = 1; #< don't need to compile all the CGIs
    use_ok 'Catalyst::Test', 'SGN';
    use_ok 'SGN::Controller::Organism';
}


my $controller = SGN->controller('Organism');

my $schema = SGN->dbic_schema('Bio::Chado::Schema','sgn_chado');

SKIP: {

    my $organism = $schema->resultset('Organism::Organism')
                          ->search({ species => 'Solanum lycopersicum' },
                                   { rows => 1 }
                                  )
                          ->single;

    skip 'no organism to test on', 3 unless $organism;

    my $summary = $controller->species_data_summary_cache->thaw( $organism->organism_id );

    is( lc( $summary->{'Common Name'}), 'tomato', 'got common name from summary cache' );

}


isa_ok( $controller->organism_sets->{sol100}{resultset}, 'DBIx::Class::ResultSet', 'got sol100 organism resultset' );

done_testing;

