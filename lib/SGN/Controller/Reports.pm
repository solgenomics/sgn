
package SGN::Controller::Reports;

use Moose;
use Data::Dumper;
use SGN::Model::Cvterm;

BEGIN { extends 'Catalyst::Controller' };

sub reports : Path('/reports') Args(0) {
    my $self = shift;
    my $c = shift;

    $c->stash->{template} = '/reports/index.mas';
}

sub overview : Path('/reports/overview') Args(0) {
    my $self = shift;
    my $c = shift;

    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $people_schema = $c->dbic_schema("CXGN::People::Schema");
    
    my %stats;
    
     	# Number of Germplasms
 	# Number of Germplasm with Pedigree
 	# Number of Germplasms with phenotyping information
 	# Number of Germplasm with Genotyping information
 	# Number of Locations
  	# Number of users
 	# Number of traits
 	# Number of trails
  	# Number of images
  	# Number of Spectra data
 	# Number of plots
  	# Number of plants
        # Number of tissue samples
 	# Number of genotyping plates
 	# Number of genotyping protocols
 	# Number of Crosses
    # Number of seeds
  	# Number of Markers
 	# Number of Breeding programs
  	# Number of years
 	# Number of Phenotypes

    # number of accessions
    #
    my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_property')->cvterm_id();
    my $rs = $schema->resultset("Stock::Stock")->search( { type_id => $accession_type_id });
    $stats{accession_count} = $rs->count();

    my $female_parent_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'female_parent', 'stock_relationship');
    my $accession_with_pedigrees = $schema->resultset("Stock::Stock")->search( { type_id => $accession_type_id }, { join => 'object', '+select' => 'object.type_id', '+as' => 'relationship_type_id' });
    
    
    $c->stash->{template} = '/reports/overview.mas';
}



1;
