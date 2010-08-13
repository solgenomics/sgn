use strict;
use warnings;
use CXGN::Login;
use CXGN::Chado::Organism;

our $c;

my $dbh = $c->dbc->dbh;
my ($person_id, $user_type) = CXGN::Login->new($dbh)->has_session();

my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

my $sol100_organisms =
    $schema->resultset( "Cv::Cvterm" )
           ->search({ name => 'sol100' })
           ->search_related( 'organismprops' )
           ->search_related( 'organism' );

$c->forward_to_mason_view(
    "/sequencing/sol100.mas",
    user_type => $user_type,
    schema    => $schema,
    sol       => { map { $_->species => $_->organism_id } $sol100_organisms->all },
   );
