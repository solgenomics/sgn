package CXGN::Stock::TissueSample::Search;

=head1 NAME
CXGN::Stock::TissueSample::Search - an object to handle searching for tissue samples
=head1 USAGE
my $sample_search = CXGN::Stock::TissueSample::Search->new({
    bcs_schema=>$schema,
    tissue_sample_db_id_list => \@tissue_ids,
    tissue_sample_name_list => \@tissue_names,
    plate_db_id_list => \@geno_trial_ids,
    plate_name_list => \@geno_trial_names,
    germplasm_db_id_list => \@accession_ids,
    germplasm_name_list => \@accession_names,
    observation_unit_db_id_list => \@plot_ids,
    observation_unit_name_list => \@plot_names,
    order_by => '',
    limit => 10,
    offset => 0
});
my $result = $sample_search->search();

Modeled after brapi samples search call.
observation_unit_db_id_list is for a list of source plot_ids, plant_ids, or tissue_sample_ids
plate_db_id_list is for a list of genotyping_trial_ids
germplasm_db_id_list is for a list of accession_ids

=head1 DESCRIPTION
=head1 AUTHORS

=cut

use strict;
use warnings;
use Moose;
use Try::Tiny;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Stock::TissueSample;

has 'bcs_schema' => (
    isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1,
);

has 'tissue_sample_db_id_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw'
);

has 'tissue_sample_name_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'rw'
);

has 'plate_db_id_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw'
);

has 'plate_name_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'rw'
);

has 'germplasm_db_id_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw'
);

has 'germplasm_name_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'rw'
);

has 'observation_unit_db_id_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw'
);

has 'observation_unit_name_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'rw'
);

has 'order_by' => (
    isa => 'Str|Undef',
    is => 'rw'
);

has 'limit' => (
    isa => 'Int|Undef',
    is => 'rw',
);

has 'offset' => (
    isa => 'Int|Undef',
    is => 'rw',
);

sub search {
    my $self = shift;
    my $schema = $self->bcs_schema();

    my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $plant_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plant', 'stock_type')->cvterm_id();
    my $plot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id();
    my $tissue_sample_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'tissue_sample', 'stock_type')->cvterm_id();
    my $tissue_relationship_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'tissue_sample_of', 'stock_relationship')->cvterm_id();
    my $genotyping_experiment_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'genotyping_layout', 'experiment_type')->cvterm_id();

    my %and_conditions;
    $and_conditions{'me.type_id'} = $tissue_sample_cvterm_id;

    my $order_by = $self->order_by || 'me.uniquename';

    my %join_clause = ('stock_relationship_subjects' => 'object');
    $and_conditions{'stock_relationship_subjects.type_id'} = $tissue_relationship_cvterm_id;

    if ($self->tissue_sample_db_id_list() && scalar(@{$self->tissue_sample_db_id_list}) > 0){
        $and_conditions{'me.stock_id'} = {'-in' => $self->tissue_sample_db_id_list};
    }
    if ($self->tissue_sample_name_list() && scalar(@{$self->tissue_sample_name_list}) > 0){
        foreach (@{$self->tissue_sample_name_list}){
            push @{$and_conditions{'me.uniquename'}}, {'ilike' => '%'.$_.'%'};
        }
    }

    if (($self->plate_db_id_list() && scalar(@{$self->plate_db_id_list}) > 0) || ($self->plate_name_list() && scalar(@{$self->plate_name_list}) > 0)){
        $join_clause{nd_experiment_stocks} = {nd_experiment => {nd_experiment_projects => 'project'} };
        $and_conditions{'nd_experiment.type_id'} = $genotyping_experiment_cvterm_id;

        if ($self->plate_db_id_list() && scalar(@{$self->plate_db_id_list}) > 0){
            $and_conditions{'project.project_id'} = {'-in' => $self->plate_db_id_list};
        }
        if ($self->plate_name_list() && scalar(@{$self->plate_name_list}) > 0){
            $and_conditions{'project.name'} = {'-in' => $self->plate_name_list};
        }
    }

    if (($self->germplasm_db_id_list() && scalar(@{$self->germplasm_db_id_list}) > 0) || ($self->germplasm_name_list() && scalar(@{$self->germplasm_name_list}) > 0)){
        $and_conditions{'object.type_id'} = $accession_cvterm_id;

        if ($self->germplasm_db_id_list() && scalar(@{$self->germplasm_db_id_list}) > 0){
            $and_conditions{'object.stock_id'} = {'-in' => $self->germplasm_db_id_list};
        }
        if ($self->germplasm_name_list() && scalar(@{$self->germplasm_name_list}) > 0){
            foreach (@{$self->germplasm_name_list}){
                push @{$and_conditions{'object.uniquename'}}, {'ilike' => '%'.$_.'%'};
            }
        }
    }

    if (($self->observation_unit_db_id_list() && scalar(@{$self->observation_unit_db_id_list}) > 0) || ($self->observation_unit_name_list() && scalar(@{$self->observation_unit_name_list}) > 0)){
        $and_conditions{'object.type_id'} = [$plot_cvterm_id, $plant_cvterm_id, $tissue_sample_cvterm_id];

        if ($self->observation_unit_db_id_list() && scalar(@{$self->observation_unit_db_id_list}) > 0){
            $and_conditions{'object.stock_id'} = {'-in' => $self->observation_unit_db_id_list};
        }
        if ($self->observation_unit_name_list() && scalar(@{$self->observation_unit_name_list}) > 0){
            foreach (@{$self->observation_unit_name_list}){
                push @{$and_conditions{'object.uniquename'}}, {'ilike' => '%'.$_.'%'};
            }
        }
    }

    #$schema->storage->debug(1);
    my $sample_rs = $schema->resultset("Stock::Stock")->search(
        \%and_conditions,
        {
            join => \%join_clause,
            order_by => { '-asc' => $order_by },
            distinct => 1
        }
    );

    my @result;

    my $limit = $self->limit;
    my $offset = $self->offset;
    my $records_total = $sample_rs->count();
    if (defined($limit) && defined($offset)){
        $sample_rs = $sample_rs->slice($offset, $limit);
    }

    while ( my $t = $sample_rs->next() ) {
        my $s = CXGN::Stock::TissueSample->new(schema=>$self->bcs_schema, tissue_sample_id=>$t->stock_id);
        my $accession_id = $s->get_accession ? $s->get_accession->[0] : undef;
        my $accession_name = $s->get_accession ? $s->get_accession->[1] : undef;
        my $source_plot_id = $s->get_source_plot ? $s->get_source_plot->[0] : undef;
        my $source_plot_name = $s->get_source_plot ? $s->get_source_plot->[1] : undef;
        my $source_plant_id = $s->get_source_plant ? $s->get_source_plant->[0] : undef;
        my $source_plant_name = $s->get_source_plant ? $s->get_source_plant->[1] : undef;
        my $source_sample_id = $s->get_source_tissue_sample ? $s->get_source_tissue_sample->[0] : undef;
        my $source_sample_name = $s->get_source_tissue_sample ? $s->get_source_tissue_sample->[1] : undef;
        my $source_obs_id = $s->source_observation_unit ? $s->source_observation_unit->[0] : undef;
        my $source_obs_name = $s->source_observation_unit ? $s->source_observation_unit->[1] : undef;
        my $source_obs_type = $s->source_observation_unit ? $s->source_observation_unit->[2] : undef;
        my $plate_id = $s->get_plate ? $s->get_plate->[0] : undef;
        my $plate_name = $s->get_plate ? $s->get_plate->[1] : undef;
        my $trial_id = $s->get_trial ? $s->get_trial->[0] : undef;
        my $trial_name = $s->get_trial ? $s->get_trial->[1] : undef;

        push @result, {
            sampleDbId => $t->stock_id,
            sampleName => $t->uniquename,
            observationUnitDbId => $source_obs_id,
            observationUnitName => $source_obs_name,
            observationUnitType => $source_obs_type,
            germplasmDbId => $accession_id,
            germplasmName => $accession_name,
            studyDbId => $trial_id,
            studyName => $trial_name,
            plotDbId => $source_plot_id,
            plotName => $source_plot_name,
            plantDbId => $source_plant_id,
            plantName => $source_plant_name,
            sourceSampleDbId => $source_sample_id,
            sourceSampleName => $source_sample_name,
            plateDbId => $plate_id,
            plateName => $plate_name,
            plateIndex => 0,
            dna_person => $s->dna_person,
            acquisition_date => $s->acquisition_date,
            tissue_type => $s->tissue_type,
            extraction => $s->extraction,
            notes => $s->notes,
            well => $s->well,
            concentration => $s->concentration,
            volume => $s->volume,
            is_blank => $s->is_blank,
            col_number => $s->col_number,
            row_number => $s->row_number
        };
    }
    #print STDERR Dumper \@result;

    return (\@result, $records_total);
}


sub get_sample_data {
    my $self = shift;
    my $schema = $self->bcs_schema();
    my $plate_list = $self->plate_db_id_list();
    my $plate_id = $plate_list->[0];
    my %sample_info;

    my $plate_layout = CXGN::Trial::TrialLayout->new({schema => $schema, trial_id => $plate_id, experiment_type => 'genotyping_layout'});
    my $sample_names = $plate_layout->get_plot_names() || [];
    my $number_of_samples = scalar(@{$sample_names});
    $sample_info{'number_of_samples'} = $number_of_samples;

    # If there are no sample names, we can return early
    if ( !$number_of_samples ) {
        $sample_info{sample_list} = [];
	$sample_info{number_of_samples_with_data} = 0;
	$sample_info{samples_with_data} = [];
	return \%sample_info;
    }
    my @sample_id_list;
    foreach my $sample(@$sample_names) {
        my $sample_id = $schema->resultset("Stock::Stock")->find({ name => $sample })->stock_id();
        push @sample_id_list, $sample_id;
    }

    # If no IDs resolved, there can be no data
    if (!@sample_id_list) {
	$sample_info{sample_list} = [];
        $sample_info{number_of_samples_with_data} = 0;
	$sample_info{samples_with_data} = [];
	return \%sample_info;
    }

    $sample_info{'sample_list'} = \@sample_id_list;
    my $where_clause;
    my $query = join ("," , @sample_id_list);
    $where_clause = "nd_experiment_stock.stock_id in ($query)";
    my $q = "SELECT DISTINCT nd_experiment_stock.stock_id
        FROM nd_experiment_stock
        JOIN nd_experiment_genotype ON (nd_experiment_stock.nd_experiment_id = nd_experiment_genotype.nd_experiment_id)
        JOIN genotypeprop ON (nd_experiment_genotype.genotype_id = genotypeprop.genotype_id)
        WHERE $where_clause";

    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute() or die "Query failed: " . $h->errstr;

    my @samples_with_data = ();
    while(my ($stock_id) = $h->fetchrow_array()){
        push @samples_with_data, $stock_id;
    }

    my $number_of_samples_with_data = scalar(@samples_with_data);
    $sample_info{'number_of_samples_with_data'} = $number_of_samples_with_data;

    return \%sample_info;

}



1;
