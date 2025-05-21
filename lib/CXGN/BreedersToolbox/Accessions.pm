
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

has 'schema' => (
    isa => 'Bio::Chado::Schema',
    is => 'rw'
);

has 'people_schema' => (
    isa => 'CXGN::People::Schema',
    is => 'rw'
);

has 'phenome_schema' => (
    isa => 'CXGN::Phenome::Schema',
    is => 'rw'
);

sub get_all_accessions {
    my $self = shift;
    my $schema = $self->schema();

    my $accession_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type');

    my $rs = $self->schema->resultset('Stock::Stock')->search({'me.is_obsolete' => { '!=' => 't' }, type_id => $accession_cvterm->cvterm_id});
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
    my $member_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'member_type', 'stock_property')->cvterm_id();

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

    my $member_type;
    my $member_type_row = $schema->resultset("Stock::Stockprop")->find({ stock_id => $population_row->stock_id(), type_id => $member_type_cvterm_id });
    if($member_type_row) {
        $member_type = $member_type_row->value();
    } else {
        $member_type = 'accessions';
    }
    $population_info{'member_type'} = $member_type;

	push @accessions_by_population, \%population_info;
    }

    return \@accessions_by_population;
}

sub get_population_members {
    my $self = shift;
    my $population_stock_id = shift;
    my $schema = $self->schema();
    my $population_member_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'member_of', 'stock_relationship');

    my @members_in_population;
    my $population_members = $schema->resultset("Stock::Stock")->search(
    {
        'object.stock_id'=> $population_stock_id,
        'stock_relationship_subjects.type_id' => $population_member_cvterm->cvterm_id()
    },
    {join => {'stock_relationship_subjects' => 'object'}, order_by => { -asc => 'stock_id'}, '+select'=>['stock_relationship_subjects.stock_relationship_id'], '+as'=>['stock_relationship_id']}
    );

    while (my $population_member_row = $population_members->next()) {
        my %member_info;
        $member_info{'stock_relationship_id'}=$population_member_row->get_column('stock_relationship_id');
        $member_info{'name'}=$population_member_row->name();
        $member_info{'description'}=$population_member_row->description();
        $member_info{'stock_id'}=$population_member_row->stock_id();

        my $stock_type = $schema->resultset('Cv::Cvterm')->find({ cvterm_id => $population_member_row->type_id()})->name();
        $member_info{'stock_type'}=$stock_type;
        my $synonyms_rs;
        $synonyms_rs = $population_member_row->search_related('stockprops', {'type.name' => {ilike => '%synonym%' } }, { join => 'type' });
        my @synonyms;
        if ($synonyms_rs) {
            while (my $synonym_row = $synonyms_rs->next()) {
                push @synonyms, $synonym_row->value();
            }
        }
        $member_info{'synonyms'}=\@synonyms;
        push @members_in_population, \%member_info;
    }
    return \@members_in_population;
}

sub get_population_seedlots {
    my $self = shift;
    my $population_stock_id = shift;
    my $schema = $self->schema();
    my $member_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'member_of', 'stock_relationship')->cvterm_id();
    my $collection_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'collection_of', 'stock_relationship')->cvterm_id();
    my $current_count_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'current_count', 'stock_property')->cvterm_id();
    my $current_weight_gram_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'current_weight_gram', 'stock_property')->cvterm_id();
    my $experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema(), "seedlot_experiment", "experiment_type")->cvterm_id();
    my $box_name_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'location_code', 'stock_property')->cvterm_id();

    my $q = "SELECT member.stock_id, member.uniquename, seedlot.stock_id, seedlot.uniquename, current_count.value, current_weight_gram.value, box_name.value, nd_geolocation.description
        FROM stock
        JOIN stock_relationship AS member_relationship ON (stock.stock_id = member_relationship.object_id) AND member_relationship.type_id = ?
        JOIN stock AS member ON (member_relationship.subject_id = member.stock_id)
        LEFT JOIN stock_relationship AS seedlot_relationship ON (member.stock_id = seedlot_relationship.subject_id) AND seedlot_relationship.type_id = ?
        LEFT JOIN stock as seedlot ON (seedlot_relationship.object_id = seedlot.stock_id)
        LEFT JOIN stockprop AS current_count ON (current_count.stock_id = seedlot.stock_id) AND current_count.type_id = ?
        LEFT JOIN stockprop AS current_weight_gram ON (current_weight_gram.stock_id = seedlot.stock_id) AND current_weight_gram.type_id = ?
        LEFT JOIN stockprop AS box_name ON (box_name.stock_id = seedlot.stock_id) AND box_name.type_id = ?
        LEFT JOIN nd_experiment_stock ON (nd_experiment_stock.stock_id = seedlot.stock_id) AND nd_experiment_stock.type_id = ?
        LEFT JOIN nd_experiment ON (nd_experiment.nd_experiment_id = nd_experiment_stock.nd_experiment_id)
        LEFT JOIN nd_geolocation ON (nd_geolocation.nd_geolocation_id = nd_experiment.nd_geolocation_id)
        where member_relationship.object_id = ?";

    my $h = $schema->storage->dbh()->prepare($q);

    $h->execute($member_of_type_id, $collection_of_type_id, $current_count_type_id, $current_weight_gram_type_id, $box_name_type_id, $experiment_type_id, $population_stock_id);

    my @population_seedlots = ();
    while(my($member_id, $member_name, $seedlot_id, $seedlot_uniquename, $current_count, $current_weight_gram, $box_name, $location) = $h->fetchrow_array()){
        push @population_seedlots, [$member_id, $member_name, $seedlot_id, $seedlot_uniquename, $current_count, $current_weight_gram, $box_name, $location]
    }

    return \@population_seedlots;
}

sub get_possible_seedlots {
    my $self = shift;
    my $uniquenames = shift; #array ref to list of accession unique names
    my $type = shift;
    my $schema = $self->schema();
    my $phenome_schema = $self->phenome_schema();
    my $people_schema = $self->people_schema();

    my $accessions;
    my $crosses;
    if ($type eq 'accessions'){
        $accessions = $uniquenames;
    }
    if ($type eq 'crosses'){
        $crosses = $uniquenames;
    }

    my ($list, $records_total) = CXGN::Stock::Seedlot->list_seedlots(
        $schema,
        $people_schema,
        $phenome_schema,
        undef,
        undef,
        undef,
        undef,
        undef,
        undef,
        undef,
        $accessions,
        $crosses,
        1,
        undef
    );

    my %seedlot_hash;
    foreach my $sl (@$list) {
        push @{$seedlot_hash{$sl->{source_stocks}->[0]->[1]}}, {
            breeding_program_id => $sl->{breeding_program_id},
            program => $sl->{breeding_program_name},
            seedlot => [$sl->{seedlot_stock_uniquename}, $sl->{seedlot_stock_id}],
            contents => [$sl->{source_stocks}->[0]->[1], $sl->{source_stocks}->[0]->[0]],
            location => $sl->{location},
            count => $sl->{current_count},
            weight_gram => $sl->{current_weight_gram}
        };
    }
    return \%seedlot_hash;
}

1;
