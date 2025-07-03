package CXGN::Trial::TrialDesignStore;

=head1 NAME

CXGN::Trial::TrialDesignStore - Module to validate and store a trial's design (for genotyping, phenotyping and analysis trials)

=head1 USAGE

 my $design_store = CXGN::Trial::TrialDesignStore->new({
    bcs_schema => $c->dbic_schema("Bio::Chado::Schema"),
    trial_id => $trial_id,
    trial_name => $trial_name,
    design_type => 'CRD',
    design => $design_hash,
    is_genotyping => 0,
    is_analysis => 0,
    operator = "janedoe"
 });

 my $validate_error = $design_store->validate_design();
 my $store_error;

 if ($validate_error) {
    print STDERR "VALIDATE ERROR: $validate_error\n";
 }
 else {
    try {
        $store error = $design_store->store();
    } catch {
        $store_error = $_;
    };
 }

 if ($store_error) {
    print STDERR "ERROR SAVING TRIAL!: $store_error\n";
 }

If a genotyping experiment is stored, is_genotyping has to be set to true (1). If an analysis is stored, is_analysis has to be set to true. For a phenotyping experiment, both are set to false (0).

=head1 DESCRIPTION

This class is used for storing a completely new design (plots and possibly plants and possibly subplots).

=over 4

=item -

Used from CXGN::Trial::TrialCreate for saving newly designed field trials in SGN::Controller::AJAX::Trial->save_experimental_design_POST

=item -

Used from CXGN::Trial::TrialCreate for saving uploaded field trials in SGN::Controller::AJAX::Trial->upload_trial_file_POST

=item -

Used from CXGN::Trial::TrialCreate for saving newly designed genotyping plate OR saving uploaded genotyping plate in SGN::Controller::AJAX::GenotypingTrial->store_genotype_trial

=back

This is used for storing new treatment trials.

=over 4

=item -

Used from CXGN::Trial::TrialCreate for saving or uploading field trials with treatments in SGN::Controller::AJAX::Trial->save_experimental_design_POST and SGN::Controller::AJAX::Trial->upload_trial_file_POST

=item -

Used from CXGN::Trial::TrialMetadata->trial_add_treatment for adding a new treatment to a trial

=item -

To add new treatments, There should be a key in the design called "treatments" specifying which stocks to include in the treatment like:

    {
        "treatments" =>
            {
                "fertilizer_10ml" => ["plot1", "plot2", "plot1_plant1", "plot2_plant1"],
                "water" => ["plot1", "plot2"]
            }
    }

=back

This is NOT used for adding plants or tissue_samples to existing trials.

=over 5

=item -

Note: For adding plants to a design already saved, use CXGN::Trial->create_plant_entities to auto-generate plant names or CXGN::Trial->save_plant_entries to save user defined plant names.

=item -

For adding tissue samples to a design already saved, use CXGN::Trial->create_tissue_samples to auto-generate sample names.

=back

For field_layout trials, the design should be a HasfRef of HashRefs like:

 {
   '1001' => {
       "plot_name" => "plot1",
       "plot_number" => 1001,
       "accession_name" => "accession1",
       "block_number" => 1,
       "row_number" => 2,
       "col_number" => 3,
       "rep_number" => 1,
       "is_a_control" => 1,
       "seedlot_name" => "seedlot1",
       "num_seed_per_plot" => 12,
       "plot_geo_json" => {},
       "plant_names" => ["plant1", "plant2"],
   }
 }

 For genotyping_layout trials, the design should be a HashRef of HashRefs like:
 {
   'A01' => {
       "plot_name" => "mytissuesample_A01",
       "stock_name" => "accession1",
       "plot_number" => "A01",
       "row_number" => "A",
       "col_number" => "1",
       "is_blank" => 0,
       "concentration" => "5",
       "volume" => "2",
       "tissue_type" => "leaf",
       "dna_person" => "nmorales",
       "extraction" => "ctab",
       "acquisition_date" => "2018/02/16",
       "notes" => "test notes",
   }
 }


store() will do the following for FIELD LAYOUT trials:

=over 5

=item 1)

Search for a trial's associated nd_experiment. There should only be one nd_experiment of type = field_layout.

=item 2)

Foreach plot in the design hash, searches for the accession's stock_name.
# TO BE IMPLEMENTED: A boolean option to allow stock_names to be added to the database on the fly. Normally this would be set to 0, but for certain loading scripts this could be set to 1.

=item 3)

Finds or creates a stock entry for each plot_name in the design hash.
#TO BE IMPLEMENTED: Associate an owner to the plot

=item 4)

Creates stockprops (block, rep, plot_number, etc) for plots.

=item 5)

For each plot, creates a stock relationship between the plot and accession if not already present.

=item 6)

If seedlot given: for each plot, creates a seed transaction stock relationship between the plot and seedlot

=item 7)

For each plot, creates an nd_experiment_stock entry if not already present. They are all linked to the same nd_experiment entry found in step 1.

=item 8)

Finds or creates a stock entry for each plant_names in the design hash.
#TO BE IMPLEMENTED: Associate an owner to the plant

=item 9)

Creates stockprops (block, rep, plot_number, plant_index_number, etc) for plants.
=item 10)

For each plant, creates a stock_relationship between the plant and accession if not already present.

=item 11)

For each plant, creates a stock_relationship between the plant and plot if not already present.

=item 12)

For each plant creates an nd_experiment_stock entry if not already present. They are all linked to the same nd_experiment entry found in step 1.

If there are subplot entries (currently for splitplot design)

=item 13)

Finds or creates a stock entry for each subplot_names in the design hash.
#TO BE IMPLEMENTED: Associate an owner to the subplot

=item 14)

Creates stockprops (block, rep, plot_number, plant_index_number, etc) for subplots.

=item 15)

For each subplot, creates a stock_relationship between the subplot and accession if not already present.

=item 16)

For each subplot, creates a stock_relationship between the subplot and plot if not already present.

=item 17)

For each subplot, creates a stock_relationship between the subplot and plant if not already present.

=item 18)

For each subplot creates an nd_experiment_stock entry if not already present. They are all linked to the same nd_experiment entry found in step 1.

store() will do the following for GENOTYPING LAYOUT trials:

=back

=over 5


=item 1)

Search for a trial's associated nd_experiment. There should only be one nd_experiment of type = genotyping_layout.
=item 2)


Foreach tissue_sample in the design hash, searches for the source_observation_unit's stock_name. The source_observation_unit can be in order of descending desireability: tissue_sample, plant, plot, or accession

=item 3)

Finds or creates a stock entry for each tissue in the design hash.

=item 4)

Creates stockprops (col_number, row_number, plot_number, notes, dna_person, etc) for tissue_sample.

=item 5)

For each tissue_sample, creates a stock relationship between the tissue_sample and source_observation_unit if not already present.

=item 6)

If the source_observation_unit is a tissue_sample, it will create stock relationships to the tissue_sample's parent plant, plot, and accession if they exist.

=item 7)

If the source_observation_unit is a plant, it will create stock relationships to the plant's parent plot and accession if they exist.

=item 8)

If the source_observation_unit is a plot, it will create stock relationships to the plot's parent accession if it exists.

=item 9)

For each tissue_sample, creates an nd_experiment_stock entry if not already present. They are all linked to the same nd_experiment entry found in step 1.

=back


=head1 AUTHORS

 Nicolas Morales (nm529@cornell.edu)
 refactoring by Lukas Mueller (lam87@cornell.edu), Nov 2019

=cut

use Data::Dumper;
use CXGN::Trial::TrialDesignStore::PhenotypingTrial;
use CXGN::Trial::TrialDesignStore::GenotypingTrial;
use CXGN::Trial::TrialDesignStore::Analysis;
use CXGN::Trial::TrialDesignStore::CrossingTrial;
use CXGN::Trial::TrialDesignStore::SamplingTrial;

sub new {
    my $class = shift;
    my $args = shift;

    my $type;

    if (($args->{is_genotyping} == 1) && ($args->{is_analysis} == 1)) {
        die "Trial design can't have is_genotyping and is_analysis set at the same time.\n";
    }

    if ($args->{is_genotyping} == 1) {
        $type = "genotyping_trial";
    }

    if ($args->{is_analysis} == 1) {
        $type = "analysis";
    }

    if ($args->{is_sampling_trial} == 1) {
        $type = "sampling_trial";
    }

    if( (! $args->{is_genotyping}) && (! $args->{is_analysis}) && (! $args->{is_sampling_trial}) ) {
        $type = "phenotyping_trial";
    }

    my $object;
    if ($type eq "genotyping_trial") {
        print STDERR "Generating GENOTYPING TRIAL\n";
        $object = CXGN::Trial::TrialDesignStore::GenotypingTrial->new($args);
    }
    if ($type eq "phenotyping_trial") {
        print STDERR "Generating PHENOTYPING TRIAL OBJECT...\n";
        $object = CXGN::Trial::TrialDesignStore::PhenotypingTrial->new($args);
    }
    if ($type eq "analysis") {
        print STDERR "Generating ANALYSIS TRIAL...\n";
        $object = CXGN::Trial::TrialDesignStore::Analysis->new($args);
    }
    if ($type eq "cross") {
        print STDERR "Generating CROSSING TRIAL...\n";
        $object = CXGN::Trial::TrialDesignStore::CrossingTrial->new($args);
    }
    if ($type eq "sampling_trial") {
        print STDERR "Generating SAMPLING TRIAL...\n";
        $object = CXGN::Trial::TrialDesignStore::SamplingTrial->new($args);
    }

    return $object;
}

1;
