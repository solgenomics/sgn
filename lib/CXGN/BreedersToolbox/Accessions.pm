
package CXGN::BreedersToolbox::Accessions;

=head1 NAME

CXGN::BreedersToolbox::Accessions - functions for managing accessions

=head1 USAGE

 my $accession_manager = CXGN::BreedersToolbox::Accessons->new(schema=>$schema);

=head1 DESCRIPTION


=head1 AUTHORS

 Jeremy D. Edwards (jde22@cornell.edu)

=cut

use strict;
use warnings;
use Data::Dumper;
use Moose;
use SGN::Model::Cvterm;

has 'schema' => ( isa => 'Bio::Chado::Schema',
                  is => 'rw');

sub get_all_accessions { 
    my $self = shift;
    my $schema = $self->schema();

    my $accession_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type');
    
    my $rs = $self->schema->resultset('Stock::Stock')->search({type_id => $accession_cvterm->cvterm_id});
    #my $rs = $self->schema->resultset('Stock::Stock')->search( { 'projectprops.type_id'=>$breeding_program_cvterm_id }, { join => 'projectprops' }  );
    my @accessions = ();



    while (my $row = $rs->next()) { 
	push @accessions, [ $row->stock_id, $row->name, $row->description ];
    }

    return \@accessions;
}

sub get_all_populations { 
    my $self = shift;
    my $schema = $self->schema();

    my $accession_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession','stock_type');

    my $population_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'population', 'stock_type');

    my $population_member_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'member_of', 'stock_relationship');
    
    my $populations_rs = $schema->resultset("Stock::Stock")->search({
        'type_id' => $population_cvterm->cvterm_id(),
        'is_obsolete' => 'f'
    });

    my @accessions_by_population;

    while (my $population_row = $populations_rs->next()) {
	my %population_info;
	$population_info{'name'}=$population_row->name();
	$population_info{'description'}=$population_row->description();
	$population_info{'stock_id'}=$population_row->stock_id();

	push @accessions_by_population, \%population_info;
    }

    return \@accessions_by_population;
}

sub get_population_members {
    my $self = shift;
    my $population_stock_id = shift;
    my $schema = $self->schema();
    my $population_member_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'member_of', 'stock_relationship');

    my @accessions_in_population;
    my $population_members = $schema->resultset("Stock::Stock")->search(
    {
        'object.stock_id'=> $population_stock_id,
        'stock_relationship_subjects.type_id' => $population_member_cvterm->cvterm_id()
    },
    {join => {'stock_relationship_subjects' => 'object'}, order_by => { -asc => 'stock_id'}, '+select'=>['stock_relationship_subjects.stock_relationship_id'], '+as'=>['stock_relationship_id']}
    );

    while (my $population_member_row = $population_members->next()) {
        my %accession_info;
        $accession_info{'stock_relationship_id'}=$population_member_row->get_column('stock_relationship_id');
        $accession_info{'name'}=$population_member_row->name();
        $accession_info{'description'}=$population_member_row->description();
        $accession_info{'stock_id'}=$population_member_row->stock_id();
        my $synonyms_rs;
        $synonyms_rs = $population_member_row->search_related('stockprops', {'type.name' => {ilike => '%synonym%' } }, { join => 'type' });
        my @synonyms;
        if ($synonyms_rs) {
            while (my $synonym_row = $synonyms_rs->next()) {
                push @synonyms, $synonym_row->value();
            }
        }
        $accession_info{'synonyms'}=\@synonyms;
        push @accessions_in_population, \%accession_info;
    }
    return \@accessions_in_population;
}

sub get_possible_seedlots {
    my $self = shift;
    my $accessions = shift; #array ref to list of accession unique names
    my $schema = $self->schema();

    my $collection_id = SGN::Model::Cvterm->get_cvterm_row($schema,'collection_of','stock_relationship')->cvterm_id;
    my $current_count_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, "current_count", "stock_property")->cvterm_id();

    my $table_joins = {
        join => { 
          'stock_relationship_subjects' => {
            'object' => [
              {
                'nd_experiment_stocks' => {
                  'nd_experiment' => [ 
                    {'nd_experiment_projects' => 'project' }, 
                    'nd_geolocation' 
                  ]
                }
            },
            'stockprops'
            ]
          }
        },
        '+select' => ['me.uniquename','me.stock_id','stock_relationship_subjects.object_id','object.name','project.name', 'project.project_id', 'nd_geolocation.description', 'nd_geolocation.nd_geolocation_id', 'stockprops.value'],
        '+as' => ['accession_name','accession_id','seedlot_id','seedlot_name','breeding_program_name', 'breeding_program_id', 'location', 'location_id', 'current_count']
    };
    my $query = {
        'me.is_obsolete' => { '!=' => 't' },
        'stockprops.type_id' => { '=' => $current_count_cvterm_id},
        'stock_relationship_subjects.type_id' => {'=' => $collection_id},
        'me.uniquename' => {-in=>$accessions}
    };
    my $stock_rs = $schema->resultset("Stock::Stock")
        ->search($query,$table_joins);
    my $seedlot_hash = {};
    while( my $row = $stock_rs->next) {
        my $uname = $row->get_column('accession_name');
        if (not defined $seedlot_hash->{$uname}){
            $seedlot_hash->{$uname} = [];
        }
        my $seedlot_name = $row->get_column('seedlot_name');
        my $seedlot_id = $row->get_column('seedlot_id');
        if ($seedlot_id && $seedlot_name){
            push @{$seedlot_hash->{$uname}}, {
                'program'  => $row->get_column('breeding_program_name'),
                'seedlot'  => [$seedlot_name, $seedlot_id],
                'contents' => [$uname, $row->get_column('accession_id')],
                'location' => $row->get_column('location'),
                'count'    => $row->get_column('current_count')
            };
        }
    }
    return $seedlot_hash;
}

1;
