use strict;

use CXGN::Page;

use CXGN::Chado::Organism;
use CXGN::DB::DBICFactory;

my $page   =  CXGN::Page->new("SOL100 sequencing project","Naama");

my $schema =  
    CXGN::DB::DBICFactory
    ->open_schema( 'Bio::Chado::Schema' );

my @species= ('Solanum lycopersicum', 'Solanum pennellii', 'Solanum pimpinellifolium',  'Solanum galapagense');

my $sol=();

foreach my $s (@species) {
    my $organism= CXGN::Chado::Organism->new_with_species($schema, $s);
    my $organism_id = $organism->get_organism_id();
    $sol->{$s}= $organism_id ;
}

##########

$c->forward_to_mason_view("/sequencing/sol100.mas" , schema=>$schema, sol=>$sol );



