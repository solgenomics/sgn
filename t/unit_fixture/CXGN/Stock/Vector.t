#test all functions in CXGN::Stock::Vector

use strict;

use lib 't/lib';

use Test::More;
use Data::Dumper;
use SGN::Test::Fixture;
use CXGN::Stock::Vector;
use CXGN::Stock::SearchVector;
use SGN::Model::Cvterm;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema();
my $people_schema = $f->people_schema();
my $phenome_schema = $f->phenome_schema();


my $type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'vector_construct', 'stock_type')->cvterm_id();

my $schema= $schema;
my $check_name_exists= 0;
my $type= 'vector_construct';
my $type_id= $type_id;
my $sp_person_id = '41';
my $user_name = 'janedoe';
my $species = 'Solanum lycopersicum';
my $name = 'tomato10';
my $uniquename = 'tomato10';
my $strain = 'strain1';
my $backbone = 'backbone1';
my $cloning_organism = 'tomato';
my $inherent_marker = 'marker1';
my $selection_marker = 'marker2';
my $cassette_name = 'cassette1';
my $vector_type = 'no_nitab';
my $gene = 'gene1';
my $promotors = 'promotors1';
my $terminators = 'terminators1';
my $bacterial_resistant_marker = 'BR Marker';
my $plant_antibiotic_resistant_marker = 'PAR Marker';

my $stock = CXGN::Stock::Vector->new({
                    schema=>$schema,
                    check_name_exists=>0,
                    type=>$type,
                    type_id=>$type_id,
                    sp_person_id => $sp_person_id,
                    user_name => $user_name,
                    species=>$species,
                    name=>$name,
                    uniquename=>$uniquename,
                    Strain=>$strain,
                    Backbone=>$backbone,
                    CloningOrganism=>$cloning_organism,
                    InherentMarker=>$inherent_marker,
                    SelectionMarker=>$selection_marker,
                    CassetteName=>$cassette_name,
                    VectorType=>$vector_type,
                    Gene=>$gene,
                    Promotors=>$promotors,
                    Terminators=>$terminators,
                    PlantAntibioticResistantMarker=>$plant_antibiotic_resistant_marker,
                    BacterialResistantMarker=>$bacterial_resistant_marker
});

my $stock_id = $stock->store();
my $s = CXGN::Stock::Vector->new(schema=>$schema, stock_id=>$stock_id);

is_deeply($s->name,$name);
is_deeply($s->uniquename,$uniquename);
is_deeply($s->Strain,$strain);
is_deeply($s->Backbone,$backbone);
is_deeply($s->CloningOrganism,$cloning_organism);
is_deeply($s->InherentMarker,$inherent_marker);
is_deeply($s->SelectionMarker,$selection_marker);
is_deeply($s->CassetteName,$cassette_name);
is_deeply($s->VectorType,$vector_type);
is_deeply($s->Gene,$gene);
is_deeply($s->Promotors,$promotors);
is_deeply($s->Terminators,$terminators);
is_deeply($s->PlantAntibioticResistantMarker,$plant_antibiotic_resistant_marker);
is_deeply($s->BacterialResistantMarker,$bacterial_resistant_marker);

$f->clean_up_db();

done_testing();
