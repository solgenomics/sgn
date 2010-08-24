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

my $sol100 = $controller->organism_sets->{sol100}{resultset};
isa_ok( $sol100, 'DBIx::Class::ResultSet', 'got sol100 organism resultset' );

# find an organism that is in the solanaceae but not part of sol100
my $solanaceae = $controller->organism_sets->{Solanaceae}{resultset};
isa_ok( $sol100, 'DBIx::Class::ResultSet', 'got solanaceae resultset' );

my $test_organism = $solanaceae
    ->search({ 'organism.organism_id' => { -not_in => $sol100->get_column('organism_id')->as_query }},
             { rows => 1, }
            )
    ->single;

SKIP: {
    skip 'could not find an organism to test with', 0 unless $test_organism;

    diag "using test organism ".$test_organism->species;
}

done_testing;

