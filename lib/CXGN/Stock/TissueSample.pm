
=head1 NAME

CXGN::Stock::TissueSample - a class to represent tissue samples and samples in general (e.g. samples in wells) in the database

=head1 DESCRIPTION

CXGN::Stock::TissueSample inherits from CXGN::Stock.


=head1 AUTHOR


=head1 ACCESSORS & METHODS

=cut

package CXGN::Stock::TissueSample;

use Moose;

extends 'CXGN::Stock';

use Data::Dumper;
use CXGN::BreedersToolbox::Projects;
use SGN::Model::Cvterm;
use CXGN::List::Validate;
use Try::Tiny;
use CXGN::Trial;

=head2 Accessor tissue_sample_id()

the database id of the tissue_sample. Is equivalent to stock_id.

=cut

has 'tissue_sample_id' => (
    isa => 'Maybe[Int]',
    is => 'rw',
);


=head2 Accessor acquisition_date()

A string specifiying the acquisition date of the tissue sample

=cut

has 'acquisition_date' => (
    isa => 'Str|Undef',
    is => 'rw',
);


=head2 Accessor well()

A string specifying the well that the tissue sample is in e.g. A12

=cut

has 'well' => (
    isa => 'Str|Undef',
    is => 'rw',
);

=head2 Accessor row_number()

A string specifying the row that the tissue sample is in e.g. A

=cut

has 'row_number' => (
    isa => 'Str|Undef',
    is => 'rw',
);


=head2 Accessor col_number()

A string specifying the column that the tissue sample is in e.g. 12

=cut

has 'col_number' => (
    isa => 'Str|Undef',
    is => 'rw',
);


=head2 Accessor dna_person()

A string specifying the person who plated the tissue_sample

=cut

has 'dna_person' => (
    isa => 'Str|Undef',
    is => 'rw',
);

=head2 Accessor notes()

A string specifying additional notes

=cut

has 'notes' => (
    isa => 'Str|Undef',
    is => 'rw',
);

=head2 Accessor tissue_type()

A string specifying tissue_type

=cut

has 'tissue_type' => (
    isa => 'Str|Undef',
    is => 'rw',
);

=head2 Accessor extraction()

A string specifying extraction

=cut

has 'extraction' => (
    isa => 'Str|Undef',
    is => 'rw',
);

=head2 Accessor concentration()

A string specifying concentration

=cut

has 'concentration' => (
    isa => 'Str|Undef',
    is => 'rw',
);

=head2 Accessor volume()

A string specifying volume

=cut

has 'volume' => (
    isa => 'Str|Undef',
    is => 'rw',
);

=head2 Accessor is_blank()

A string specifying is_blank. Used in genotyping plate well tissue samples

=cut

has 'is_blank' => (
    isa => 'Str|Undef',
    is => 'rw',
);

=head2 Accessor source_observation_unit()

A tissue sample can be linked to, in descreasing order of desireability: another tissue_sample, a plant, a plot, an accession.
This accessor will return the most desireable stock that this tissue sample is linked to as an arrayref of [$stock_id, $uniquename, $type]

# for setter, use source_observation_unit_stock_id

=cut

has 'source_observation_unit' => (
    isa => 'ArrayRef|Undef',
    is => 'rw',
);

has 'source_observation_unit_stock_id' => (
    isa => 'Int|Undef',
    is => 'rw',
);

=head2 Accessor get_accession()

Even though the setter for source_observation_unit_stock_id can be, in descreasing order of desireability: another tissue_sample, a plant, a plot, an accession, a tissue_sample will always be linked to an accession.
Returns an ArrayRef of [$stock_id, $uniquename]

=cut

has 'get_accession' => (
    isa => 'ArrayRef|Undef',
    is => 'rw',
    lazy     => 1,
    builder  => '_retrieve_accession',
);

=head2 Accessor get_trial()

A tissue_sample will be linked to either a field_trial experiment or a genotyping_trial experiment. This returns the project name
Returns an ArrayRef of [$project_id, $name]

=cut

has 'get_trial' => (
    isa => 'ArrayRef|Undef',
    is => 'rw',
    lazy     => 1,
    builder  => '_retrieve_trial',
);

=head2 Accessor get_plate()

A tissue_sample will be linked to either a field_trial experiment or a genotyping_trial experiment. If it is a genotyping_trial, the genotyping_trial represents the plate.
Returns an ArrayRef of [$project_id, $name]

=cut

has 'get_plate' => (
    isa => 'ArrayRef|Undef',
    is => 'rw',
    lazy     => 1,
    builder  => '_retrieve_plate',
);

=head2 Accessor get_source_plot()

If the tissue sample is linked to a plot (meaning the setter source_observation_unit_stock_id was either a plot,plant,or tissue_sample) this 
Returns an ArrayRef of [$stock_id, $uniquename] for the plot

=cut

has 'get_source_plot' => (
    isa => 'ArrayRef|Undef',
    is => 'rw',
    lazy     => 1,
    builder  => '_retrieve_source_plot',
);

=head2 Accessor get_source_plant()

If the tissue sample is linked to a plant (meaning the setter source_observation_unit_stock_id was either a plant or tissue_sample) this 
Returns an ArrayRef of [$stock_id, $uniquename] for the plant

=cut

has 'get_source_plant' => (
    isa => 'ArrayRef|Undef',
    is => 'rw',
    lazy     => 1,
    builder  => '_retrieve_source_plant',
);


=head2 Accessor get_source_tissue_sample()

If the tissue sample is linked to another tissue_sample (meaning the setter source_observation_unit_stock_id was a tissue_sample) this 
Returns an ArrayRef of [$stock_id, $uniquename] for the source tissue_sample

=cut

has 'get_source_tissue_sample' => (
    isa => 'ArrayRef|Undef',
    is => 'rw',
    lazy     => 1,
    builder  => '_retrieve_source_tissue_sample',
);

=head2 Accessor get_plate_sample_type()

Tissue samples in genotyping_layout trials have a projectprop called sample_type on them

=cut

has 'get_plate_sample_type' => (
    isa => 'Str|Undef',
    is => 'rw',
    lazy     => 1,
    builder  => '_retrieve_plate_sample_type',
);


after 'stock_id' => sub {
    my $self = shift;
    my $id = shift;
    return $self->tissue_sample_id($id);
};

sub BUILDARGS {
    my $orig = shift;
    my %args = @_;
    $args{stock_id} = $args{tissue_sample_id};
    return \%args;
}

sub BUILD {
    my $self = shift;
    if ($self->stock_id()) {
        $self->tissue_sample_id($self->stock_id);
        $self->notes($self->_retrieve_stockprop('notes'));
        $self->volume($self->_retrieve_stockprop('volume'));
        $self->concentration($self->_retrieve_stockprop('concentration'));
        $self->tissue_type($self->_retrieve_stockprop('tissue_type'));
        $self->extraction($self->_retrieve_stockprop('extraction'));
        $self->is_blank($self->_retrieve_stockprop('is_blank'));
        $self->dna_person($self->_retrieve_stockprop('dna_person'));
        $self->row_number($self->_retrieve_stockprop('row_number'));
        $self->col_number($self->_retrieve_stockprop('col_number'));
        $self->well($self->_retrieve_stockprop('well'));
        $self->acquisition_date($self->_retrieve_stockprop('acquisition date'));
    }
}

sub _retrieve_accession {
    my $self = shift;
    my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->schema, "accession", "stock_type")->cvterm_id();
    my $tissue_sample_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->schema, "tissue_sample_of", "stock_relationship")->cvterm_id();

    my $accession_rs = $self->stock->search_related('stock_relationship_subjects')->search(
        { 'me.type_id' => { -in => [ $tissue_sample_of_cvterm_id ] }, 'object.type_id' => $accession_cvterm_id },
        { 'join' => 'object' }
    )->search_related('object');
    if ($accession_rs->count != 1){
        print "There is more than one or no (".$accession_rs->count.") (".$self->uniquename.") accession linked here!\n";
    }
    if ($accession_rs->count == 1){
        $self->get_accession([$accession_rs->first->stock_id, $accession_rs->first->uniquename]);
        $self->source_observation_unit([$accession_rs->first->stock_id, $accession_rs->first->uniquename, 'accession']);
    } else {
        $self->get_accession(undef)
    }
}

sub _retrieve_trial {
    my $self = shift;
    my $genotyping_experiment_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->schema, 'genotyping_layout', 'experiment_type')->cvterm_id();
    my $field_experiment_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->schema, 'field_layout', 'experiment_type')->cvterm_id();
    my $p_rs = $self->stock->search_related('nd_experiment_stocks')->search_related('nd_experiment', {'nd_experiment.type_id'=>[$field_experiment_cvterm_id, $genotyping_experiment_cvterm_id] })->search_related('nd_experiment_projects')->search_related('project');
    if ($p_rs->count != 1){
        die "There is not one project linked to this stock!";
    }
    $self->get_trial([$p_rs->first->project_id, $p_rs->first->name]);
}

sub _retrieve_plate {
    my $self = shift;
    my $genotyping_experiment_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->schema, 'genotyping_layout', 'experiment_type')->cvterm_id();
    my $p_rs = $self->stock->search_related('nd_experiment_stocks')->search_related('nd_experiment', {'nd_experiment.type_id'=>$genotyping_experiment_cvterm_id})->search_related('nd_experiment_projects')->search_related('project');
    if ($p_rs->count != 1){
        die "There is not one project linked to this stock!";
    }
    $self->get_plate([$p_rs->first->project_id, $p_rs->first->name]);
}

sub _retrieve_source_plot {
    my $self = shift;
    my $plot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->schema, "plot", "stock_type")->cvterm_id();
    my $tissue_sample_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->schema, "tissue_sample_of", "stock_relationship")->cvterm_id();

    my $source_plot_rs = $self->stock->search_related('stock_relationship_subjects')->search(
        { 'me.type_id' => { -in => [ $tissue_sample_of_cvterm_id ] }, 'object.type_id' => { -in => [$plot_cvterm_id] } },
        { 'join' => 'object' }
    )->search_related('object');
    if ($source_plot_rs->count > 1){
        die "More than one source plot!";
    }
    if ($source_plot_rs->count == 1){
        $self->get_source_plot([$source_plot_rs->first->stock_id, $source_plot_rs->first->uniquename]);
        $self->source_observation_unit([$source_plot_rs->first->stock_id, $source_plot_rs->first->uniquename, 'plot']);
        return;
    }
    return;
}

sub _retrieve_source_plant {
    my $self = shift;
    my $plant_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->schema, "plant", "stock_type")->cvterm_id();
    my $tissue_sample_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->schema, "tissue_sample_of", "stock_relationship")->cvterm_id();

    my $source_plant_rs = $self->stock->search_related('stock_relationship_subjects')->search(
        { 'me.type_id' => { -in => [ $tissue_sample_of_cvterm_id ] }, 'object.type_id' => { -in => [$plant_cvterm_id] } },
        { 'join' => 'object' }
    )->search_related('object');
    if ($source_plant_rs->count > 1){
        die "More than one source plant!";
    }
    if ($source_plant_rs->count == 1){
        $self->get_source_plant([$source_plant_rs->first->stock_id, $source_plant_rs->first->uniquename]);
        $self->source_observation_unit([$source_plant_rs->first->stock_id, $source_plant_rs->first->uniquename, 'plant']);
        return;
    }
    return;
}

sub _retrieve_source_tissue_sample {
    my $self = shift;
    my $tissue_sample_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->schema, "tissue_sample", "stock_type")->cvterm_id();
    my $tissue_sample_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->schema, "tissue_sample_of", "stock_relationship")->cvterm_id();

    my $source_tissue_rs = $self->stock->search_related('stock_relationship_subjects')->search(
        { 'me.type_id' => { -in => [ $tissue_sample_of_cvterm_id ] }, 'object.type_id' => { -in => [$tissue_sample_cvterm_id] } },
        { 'join' => 'object' }
    )->search_related('object');
    if ($source_tissue_rs->count > 1){
        die "More than one source tissue sample!";
    }
    if ($source_tissue_rs->count == 1){
        $self->get_source_tissue_sample([$source_tissue_rs->first->stock_id, $source_tissue_rs->first->uniquename]);
        $self->source_observation_unit([$source_tissue_rs->first->stock_id, $source_tissue_rs->first->uniquename, 'tissue_sample']);
        return;
    }
    return;
}

sub _retrieve_plate_sample_type {
    my $self = shift;
    if ($self->get_plate){
        my $trial = CXGN::Trial->new({bcs_schema=>$self->schema, trial_id=>$self->get_plate->[0]});
        $self->get_plate_sample_type($trial->get_genotyping_plate_sample_type);
    }
}

# sub _store_tissue_sample_relationships {
#     my $self = shift;
#     if (!$self->source_observation_unit_stock_id){
#         return "To save a new tissue_sample, you must provide a source stock_id. this stock id can be in order of descresing desireability: tissue_sample, plant, plot, accession";
#     }
#     my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->schema, "accession", "stock_type")->cvterm_id();
#     my $tissue_sample_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->schema, "tissue_sample", "stock_type")->cvterm_id();
#     my $plant_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->schema, "plant", "stock_type")->cvterm_id();
#     my $plot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->schema, "plot", "stock_type")->cvterm_id();
#     my $source_unit_stock = $self->schema->resultset("Stock::Stock")->find({stock_id=>$self->source_observation_unit_stock_id});
#     
# }

=head2 store()

# Store currently handled when creating or uploading genotyping plate in CXGN::Trial::TrialDesignStore
# AND when creating tissue_samples in existing trial in CXGN::Trial->create_tissue_samples

 Usage:        my $tissue_sample_id = $t->store();
 Desc:         stores the current state of the object to the db. uses CXGN::Stock store as well.
 Ret:          the tissue_sample id.
 Args:         none
 Side Effects: accesses the db. Creates a new tissue sample id
               already existing. If tissue_sample_id set in object, will do an update/edit.
 Example:

=cut

# sub store {
#     my $self = shift;
#     my $error;
# 
#     my $coderef = sub {
#         #Creating new seedlot
#         if(!$self->stock){
#             $self->name($self->uniquename());
#             my $type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema, 'tissue_sample', 'stock_type')->cvterm_id();
#             $self->type_id($type_id);
#             my $id = $self->SUPER::store();
#             print STDERR "Saving seedlot returned ID $id.".localtime."\n";
#             $self->tissue_sample_id($id);
#             #$error = $self->_store_tissue_sample_relationships();
#             #if ($error){
#             #    die $error;
#             #}
# 
#         } else { #Updating tissue_sample
# 
#             my $id = $self->SUPER::store();
#             print STDERR "Updating tissue_sample returned ID $id.".localtime."\n";
#             $self->tissue_sample_id($id);
#         }
# 
#         if ($self->acquisition_date){
#             $self->_update_stockprop('acquisition date', $self->acquisition_date());
#         }
#         if ($self->notes){
#             $self->_update_stockprop('notes', $self->notes());
#         }
#         if ($self->concentration){
#             $self->_update_stockprop('concentration', $self->concentration());
#         }
#         if ($self->volume){
#             $self->_update_stockprop('volume', $self->volume());
#         }
#         if ($self->extraction){
#             $self->_update_stockprop('extraction', $self->extraction());
#         }
#         if ($self->tissue_type){
#             $self->_update_stockprop('tissue_type', $self->tissue_type());
#         }
#         if ($self->dna_person){
#             $self->_update_stockprop('dna_person', $self->dna_person());
#         }
#         if ($self->well){
#             $self->_update_stockprop('well', $self->well());
#         }
#         if ($self->row_number){
#             $self->_update_stockprop('row_number', $self->row_number());
#         }
#         if ($self->col_number){
#             $self->_update_stockprop('col_number', $self->col_number());
#         }
#         if ($self->is_blank){
#             $self->_update_stockprop('is_blank', $self->is_blank());
#         }
#     };
# 
#     my $transaction_error;
#     try {
#         $self->schema->txn_do($coderef);
#     } catch {
#         print STDERR "Transaction Error: $_\n";
#         $transaction_error =  $_;
#     };
#     if ($transaction_error){
#         return { error=>$transaction_error };
#     } else {
#         return { success=>1, tissue_sample_id=>$self->tissue_sample_id() };
#     }
# }

1;

no Moose;
__PACKAGE__->meta->make_immutable;
