package CXGN::Trial::TrialDesignStore;

=head1 NAME

CXGN::Trial::TrialDesignStore - Module to validate and store a trial's design (both genotyping and phenotyping trials)

This is used when storing a new design completely (plots and possibly plants and possibly subplots).
- Used from CXGN::Trial::TrialCreate for saving newly designed field trials in SGN::Controller::AJAX::Trial->save_experimental_design_POST
- Used from CXGN::Trial::TrialCreate for saving uploaded field trials in SGN::Controller::AJAX::Trial->upload_trial_file_POST
- Used from CXGN::Trial::TrialCreate for saving newly designed genotyping plate OR saving uploaded genotyping plate in SGN::Controller::AJAX::GenotypingTrial->store_genotype_trial

This is used for storing new treatment (field management factor) trials.
- Used from CXGN::Trial::TrialCreate for saving or uploading field trials with treatments in SGN::Controller::AJAX::Trial->save_experimental_design_POST and SGN::Controller::AJAX::Trial->upload_trial_file_POST
- Used from CXGN::Trial::TrialMetadata->trial_add_treatment for adding a new treatment to a trial
- To add new treatments, There should be a key in the design called "treatments" specifying which stocks to include in the treatment like:
    {
        "treatments" =>
            {
                "fertilizer_10ml" => ["plot1", "plot2", "plot1_plant1", "plot2_plant1"],
                "water" => ["plot1", "plot2"]
            }
    }

This is NOT used for adding plants or tissue_samples to existing trials.
- Note: For adding plants to a design already saved, use CXGN::Trial->create_plant_entities to auto-generate plant names or CXGN::Trial->save_plant_entries to save user defined plant names.
- For adding tissue samples to a design already saved, use CXGN::Trial->create_tissue_samples to auto-generate sample names.

--------------------------------------------------------------------------------------------------------

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

----------------------------------------------------------------------------------------------------------

Store() will do the following for FIELD LAYOUT trials:
1) Search for a trial's associated nd_experiment. There should only be one nd_experiment of type = field_layout.
2) Foreach plot in the design hash, searches for the accession's stock_name.
# TO BE IMPLEMENTED: A boolean option to allow stock_names to be added to the database on the fly. Normally this would be set to 0, but for certain loading scripts this could be set to 1.
3) Finds or creates a stock entry for each plot_name in the design hash.
#TO BE IMPLEMENTED: Associate an owner to the plot
4) Creates stockprops (block, rep, plot_number, etc) for plots.
5) For each plot, creates a stock relationship between the plot and accession if not already present.
6) If seedlot given: for each plot, creates a seed transaction stock relationship between the plot and seedlot
7) For each plot, creates an nd_experiment_stock entry if not already present. They are all linked to the same nd_experiment entry found in step 1.
8) Finds or creates a stock entry for each plant_names in the design hash.
#TO BE IMPLEMENTED: Associate an owner to the plant
9) Creates stockprops (block, rep, plot_number, plant_index_number, etc) for plants.
10) For each plant, creates a stock_relationship between the plant and accession if not already present.
11) For each plant, creates a stock_relationship between the plant and plot if not already present.
12) For each plant creates an nd_experiment_stock entry if not already present. They are all linked to the same nd_experiment entry found in step 1.

If there are subplot entries (currently for splitplot design)
13) Finds or creates a stock entry for each subplot_names in the design hash.
#TO BE IMPLEMENTED: Associate an owner to the subplot
9) Creates stockprops (block, rep, plot_number, plant_index_number, etc) for subplots.
10) For each subplot, creates a stock_relationship between the subplot and accession if not already present.
11) For each subplot, creates a stock_relationship between the subplot and plot if not already present.
11) For each subplot, creates a stock_relationship between the subplot and plant if not already present.
12) For each subplot creates an nd_experiment_stock entry if not already present. They are all linked to the same nd_experiment entry found in step 1.

----------------------------------------------------------------------------------------------------------

Store() will do the following for GENOTYPING LAYOUT trials:
1) Search for a trial's associated nd_experiment. There should only be one nd_experiment of type = genotyping_layout.
2) Foreach tissue_sample in the design hash, searches for the source_observation_unit's stock_name. The source_observation_unit can be in order of descending desireability: tissue_sample, plant, plot, or accession
3) Finds or creates a stock entry for each tissue in the design hash.
4) Creates stockprops (col_number, row_number, plot_number, notes, dna_person, etc) for tissue_sample.
5) For each tissue_sample, creates a stock relationship between the tissue_sample and source_observation_unit if not already present.
6) If the source_observation_unit is a tissue_sample, it will create stock relationships to the tissue_sample's parent plant, plot, and accession if they exist.
6) If the source_observation_unit is a plant, it will create stock relationships to the plant's parent plot and accession if they exist.
6) If the source_observation_unit is a plot, it will create stock relationships to the plot's parent accession if it exists.
7) For each tissue_sample, creates an nd_experiment_stock entry if not already present. They are all linked to the same nd_experiment entry found in step 1.


=head1 USAGE

my $design_store = CXGN::Trial::TrialDesignStore->new({
    bcs_schema => $c->dbic_schema("Bio::Chado::Schema"),
    trial_id => $trial_id,
    trial_name => $trial_name,
    design_type => 'CRD',
    design => $design_hash,
    is_genotyping => 0,
    operator = "janedoe"
});
my $validate_error = $design_store->validate_design();
my $store_error;
if ($validate_error) {
    print STDERR "VALIDATE ERROR: $validate_error\n";
} else {
    try {
        $store error = $design_store->store();
    } catch {
        $store_error = $_;
    };
}
if ($store_error) {
    print STDERR "ERROR SAVING TRIAL!: $store_error\n";
}


=head1 DESCRIPTION


=head1 AUTHORS

 Nicolas Morales (nm529@cornell.edu)

=cut


use Moose;
use MooseX::FollowPBP;
use Moose::Util::TypeConstraints;
use Try::Tiny;
use CXGN::Stock::StockLookup;
use CXGN::Trial;
use SGN::Model::Cvterm;
use Data::Dumper;
use CXGN::List::Validate;
use CXGN::Stock::Seedlot;
use CXGN::Stock::Seedlot::Transaction;

has 'bcs_schema' => (
    is       => 'rw',
    isa      => 'DBIx::Class::Schema',
    predicate => 'has_chado_schema',
    required => 1,
);
has 'trial_id' => (isa => 'Int', is => 'rw', predicate => 'has_trial_id', required => 1);
has 'trial_name' => (isa => 'Str', is => 'rw', predicate => 'has_trial_name', required => 0);
has 'nd_experiment_id' => (isa => 'Int', is => 'rw', predicate => 'has_nd_experiment_id', required => 0);
has 'nd_geolocation_id' => (isa => 'Int', is => 'rw', predicate => 'has_nd_geolocation_id', required => 1);
has 'design_type' => (isa => 'Str', is => 'rw', predicate => 'has_design_type', required => 1);
has 'design' => (isa => 'HashRef[HashRef]|Undef', is => 'rw', predicate => 'has_design', required => 1);
has 'is_genotyping' => (isa => 'Bool', is => 'rw', required => 0, default => 0);
has 'stocks_exist' => (isa => 'Bool', is => 'rw', required => 0, default => 0);
has 'new_treatment_has_plant_entries' => (isa => 'Maybe[Int]', is => 'rw', required => 0, default => 0);
has 'new_treatment_has_subplot_entries' => (isa => 'Maybe[Int]', is => 'rw', required => 0, default => 0);
has 'new_treatment_has_tissue_sample_entries' => (isa => 'Maybe[Int]', is => 'rw', required => 0, default => 0);
has 'new_treatment_date' => (isa => 'Maybe[Str]', is => 'rw', required => 0, default => 0);
has 'new_treatment_year' => (isa => 'Maybe[Str]', is => 'rw', required => 0, default => 0);
has 'new_treatment_type' => (isa => 'Maybe[Str]', is => 'rw', required => 0, default => 0);
has 'operator' => (isa => 'Str', is => 'rw', required => 1);

sub validate_design {
    print STDERR "validating design\n";
    my $self = shift;
    my $chado_schema = $self->get_bcs_schema;
    my $design_type = $self->get_design_type;
    my %design = %{$self->get_design}; 
    my $error = '';

    if ($self->get_is_genotyping && $design_type ne 'genotyping_plate') {
        $error .= "is_genotyping is true; however design_type not equal to 'genotyping_plate'";
        return $error;
    }
    if (!$self->get_is_genotyping && $design_type eq 'genotyping_plate') {
        $error .= "The design_type 'genotyping_plate' requires is_genotyping to be true";
        return $error;
    }
    if ($design_type ne 'genotyping_plate' && $design_type ne 'CRD' && $design_type ne 'Alpha' && $design_type ne 'MAD' && $design_type ne 'Lattice' && $design_type ne 'Augmented' && $design_type ne 'RCBD' && $design_type ne 'p-rep' && $design_type ne 'splitplot' && $design_type ne 'greenhouse' && $design_type ne 'westcott'){
        $error .= "Design $design_type type must be either: genotyping_plate, CRD, Alpha, Augmented, Lattice, RCBD, MAD, p-rep, greenhouse, or splitplot";
        return $error;
    }
    my @valid_properties;
    if ($design_type eq 'genotyping_plate'){
        @valid_properties = (
            'stock_name',
            'plot_name',
            'row_number',
            'col_number',
            'is_blank',
            'plot_number',
            'extraction',
            'dna_person',
            'concentration',
            'volume',
            'tissue_type',
            'notes',
            'acquisition_date',
            'ncbi_taxonomy_id'
        );
        #plot_name is tissue sample name in well. during store, the stock is saved as stock_type 'tissue_sample' with uniquename = plot_name
    } elsif ($design_type eq 'CRD' || $design_type eq 'Alpha' || $design_type eq 'Augmented' || $design_type eq 'RCBD' || $design_type eq 'p-rep' || $design_type eq 'splitplot' || $design_type eq 'Lattice' || $design_type eq 'MAD' || $design_type eq 'greenhouse' || $design_type eq 'westcott'){
        # valid plot's properties
        @valid_properties = (
            'seedlot_name',
            'num_seed_per_plot',
            'weight_gram_seed_per_plot',
            'stock_name',
            'plot_name',
            'plot_number',
            'block_number',
            'rep_number',
            'is_a_control',
            'range_number',
            'row_number',
            'col_number',
            'plant_names',
            'plot_num_per_block',
            'subplots_names', #For splotplot
            'treatments', #For splitplot
            'subplots_plant_names', #For splitplot
        );
    }
    my %allowed_properties = map {$_ => 1} @valid_properties;

    my %seen_stock_names;
    my %seen_source_names;
    my %seen_accession_names;
    foreach my $stock (keys %design){
        if ($stock eq 'treatments'){
            next;
        }
        foreach my $property (keys %{$design{$stock}}){
            if (!exists($allowed_properties{$property})) {
                $error .= "Property: $property not allowed! ";
            }
            if ($property eq 'stock_name') {
                my $stock_name = $design{$stock}->{$property};
                $seen_accession_names{$stock_name}++;
            }
            if ($property eq 'seedlot_name') {
                my $stock_name = $design{$stock}->{$property};
                if ($stock_name){
                    $seen_source_names{$stock_name}++;
                }
            }
            if ($property eq 'plot_name') {
                my $plot_name = $design{$stock}->{$property};
                $seen_stock_names{$plot_name}++;
            }
            if ($property eq 'plant_names') {
                my $plant_names = $design{$stock}->{$property};
                foreach (@$plant_names) {
                    $seen_stock_names{$_}++;
                }
            }
            if ($property eq 'subplots_names') {
                my $subplot_names = $design{$stock}->{$property};
                foreach (@$subplot_names) {
                    $seen_stock_names{$_}++;
                }
            }
        }
    }

    my @stock_names = keys %seen_stock_names;
    my @source_names = keys %seen_source_names;
    my @accession_names = keys %seen_accession_names;
    if(scalar(@stock_names)<1){
        $error .= "You cannot create a trial with less than one plot.";
    }
    #if(scalar(@source_names)<1){
    #	$error .= "You cannot create a trial with less than one seedlot.";
    #}
    if(scalar(@accession_names)<1){
        $error .= "You cannot create a trial with less than one accession.";
    }
    my $subplot_type_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'subplot', 'stock_type')->cvterm_id();
    my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'accession', 'stock_type')->cvterm_id();
    my $plot_type_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plot', 'stock_type')->cvterm_id();
    my $plant_type_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plant', 'stock_type')->cvterm_id();
    my $tissue_type_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'tissue_sample', 'stock_type')->cvterm_id();
    my $stocks = $chado_schema->resultset('Stock::Stock')->search({
        type_id=>[$subplot_type_id, $plot_type_id, $plant_type_id, $tissue_type_id],
        uniquename=>{-in=>\@stock_names}
    });
    while (my $s = $stocks->next()) {
        $error .= "Name $s->uniquename already exists in the database.";
    }

    my $seedlot_validator = CXGN::List::Validate->new();
    my @seedlots_missing = @{$seedlot_validator->validate($chado_schema,'seedlots',\@source_names)->{'missing'}};
    if (scalar(@seedlots_missing) > 0) {
        $error .=  "The following seedlots are not in the database as uniquenames or synonyms: ".join(',',@seedlots_missing);
    }

    my @source_stock_types;
    if ($self->get_is_genotyping) {
        @source_stock_types = ($accession_type_id, $plot_type_id, $plant_type_id, $tissue_type_id);
    } else {
        @source_stock_types = ($accession_type_id);
    }
    my $rs = $chado_schema->resultset('Stock::Stock')->search({
        'is_obsolete' => { '!=' => 't' },
        'type_id' => {-in=>\@source_stock_types},
        'uniquename' => {-in=>\@accession_names}
    });
    my %found_data;
    while (my $s = $rs->next()) {
        $found_data{$s->uniquename} = 1;
    }
    foreach (@accession_names){
        if (!$found_data{$_}){
            $error .= "The following name is not in the database: $_ .";
        }
    }

    return $error;
}

sub store {
    print STDERR "Saving design ".localtime()."\n";
    my $self = shift;
    my $chado_schema = $self->get_bcs_schema;
    my $design_type = $self->get_design_type;
    my %design = %{$self->get_design};
    my $trial_id = $self->get_trial_id;
    my $nd_geolocation_id = $self->get_nd_geolocation_id;

    my $seedlot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'seedlot', 'stock_type')->cvterm_id();
    my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'accession', 'stock_type')->cvterm_id();
    my $tissue_sample_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'tissue_sample', 'stock_type')->cvterm_id();
    my $tissue_sample_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'tissue_sample_of', 'stock_relationship')->cvterm_id();
    my $plot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plot', 'stock_type')->cvterm_id();
    my $plot_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plot_of', 'stock_relationship')->cvterm_id();
    my $plant_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plant', 'stock_type')->cvterm_id();
    my $subplot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'subplot', 'stock_type')->cvterm_id();
    my $subplot_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'subplot_of', 'stock_relationship')->cvterm_id();
    my $plant_of_subplot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plant_of_subplot', 'stock_relationship')->cvterm_id();
    my $subplot_index_number_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'subplot_index_number', 'stock_property')->cvterm_id();
    my $plant_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plant_of', 'stock_relationship')->cvterm_id();
    my $plant_index_number_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plant_index_number', 'stock_property')->cvterm_id();
    my $replicate_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'replicate', 'stock_property')->cvterm_id;
    my $block_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'block', 'stock_property')->cvterm_id();
    my $plot_number_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plot number', 'stock_property')->cvterm_id();
    my $is_control_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'is a control', 'stock_property')->cvterm_id();
    my $range_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'range', 'stock_property')->cvterm_id();
    my $row_number_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'row_number', 'stock_property')->cvterm_id();
    my $col_number_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'col_number', 'stock_property')->cvterm_id();
    my $is_blank_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'is_blank', 'stock_property')->cvterm_id();
    my $concentration_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'concentration', 'stock_property')->cvterm_id();
    my $volume_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'volume', 'stock_property')->cvterm_id();
    my $dna_person_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'dna_person', 'stock_property')->cvterm_id();
    my $extraction_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'extraction', 'stock_property')->cvterm_id();
    my $tissue_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'tissue_type', 'stock_property')->cvterm_id();
    my $acquisition_date_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'acquisition date', 'stock_property')->cvterm_id();
    my $ncbi_taxonomy_id_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'ncbi_taxonomy_id', 'stock_property')->cvterm_id();
    my $notes_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'notes', 'stock_property')->cvterm_id();
    my $treatment_nd_experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'treatment_experiment', 'experiment_type')->cvterm_id();
    my $project_design_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'design', 'project_property')->cvterm_id();
    my $management_factor_year_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'project year', 'project_property')->cvterm_id();
    my $management_factor_date_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'management_factor_date', 'project_property')->cvterm_id();
    my $management_factor_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'management_factor_type', 'project_property')->cvterm_id();
    my $trial_treatment_relationship_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'trial_treatment_relationship', 'project_relationship')->cvterm_id();
    my $has_plants_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'project_has_plant_entries', 'project_property')->cvterm_id();
    my $has_subplots_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'project_has_subplot_entries', 'project_property')->cvterm_id();
    my $has_tissues_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'project_has_tissue_sample_entries', 'project_property')->cvterm_id();

    my $nd_experiment_type_id;
    my $stock_type_id;
    my $stock_rel_type_id;
    my @source_stock_types;
    if (!$self->get_is_genotyping) {
        $nd_experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'field_layout', 'experiment_type')->cvterm_id();
        $stock_type_id = $plot_cvterm_id;
        $stock_rel_type_id = $plot_of_cvterm_id;
        @source_stock_types = ($accession_cvterm_id);
    } else {
        $nd_experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'genotyping_layout', 'experiment_type')->cvterm_id();
        $stock_type_id = $tissue_sample_cvterm_id;
        $stock_rel_type_id = $tissue_sample_of_cvterm_id;
        @source_stock_types = ($accession_cvterm_id, $plot_cvterm_id, $plant_cvterm_id, $tissue_sample_cvterm_id);
    }

    #$chado_schema->storage->debug(1);
    my $nd_experiment_id;
    if ($self->has_nd_experiment_id){
        $nd_experiment_id = $self->get_nd_experiment_id();
    } else {
        my $nd_experiment_project;
        my $nd_experiment_project_rs = $chado_schema->resultset('NaturalDiversity::NdExperimentProject')->search(
            {
                'me.project_id'=>$trial_id,
                'nd_experiment.type_id'=>$nd_experiment_type_id,
                'nd_experiment.nd_geolocation_id'=>$nd_geolocation_id
            },
            { join => 'nd_experiment'}
        );

        if ($nd_experiment_project_rs->count < 1) {
            my $nd_experiment = $chado_schema->resultset('NaturalDiversity::NdExperiment')
            ->create({
                nd_geolocation_id => $self->get_nd_geolocation_id,
                type_id => $nd_experiment_type_id,
            });
            $nd_experiment_project = $nd_experiment->find_or_create_related('nd_experiment_projects', {project_id => $trial_id} );
        } elsif ($nd_experiment_project_rs->count > 1) {
            print STDERR "ERROR: More than one nd_experiment of type=$nd_experiment_type_id for project=$trial_id\n";
            $nd_experiment_project = $nd_experiment_project_rs->first;
        } elsif ($nd_experiment_project_rs->count == 1) {
            print STDERR "OKAY: NdExperimentProject type=$nd_experiment_type_id for project$trial_id\n";
            $nd_experiment_project = $nd_experiment_project_rs->first;
        }
        if ($nd_experiment_project){
            $nd_experiment_id = $nd_experiment_project->nd_experiment_id();
        }
    }

    my %seen_accessions_hash;
    my %seen_seedlots_hash;
    foreach my $key (keys %design) {
        if ($design{$key}->{stock_name}) {
            my $stock_name = $design{$key}->{stock_name};
            $seen_accessions_hash{$stock_name}++;
        }
        if ($design{$key}->{seedlot_name}) {
            my $stock_name = $design{$key}->{seedlot_name};
            $seen_seedlots_hash{$stock_name}++;
        }
    }
    my @seen_accessions = keys %seen_accessions_hash;
    my @seen_seedlots = keys %seen_seedlots_hash;

    my $seedlot_rs = $chado_schema->resultset('Stock::Stock')->search({
        'is_obsolete' => { '!=' => 't' },
        'type_id' => $seedlot_cvterm_id,
        'uniquename' => {-in=>\@seen_seedlots}
    });
    my %seedlot_data;
    while (my $s = $seedlot_rs->next()) {
        $seedlot_data{$s->uniquename} = $s->stock_id;
    }

    my $rs = $chado_schema->resultset('Stock::Stock')->search({
        'is_obsolete' => { '!=' => 't' },
        'type_id' => {-in=>\@source_stock_types},
        'uniquename' => {-in=>\@seen_accessions}
    });
    my %stock_data;
    while (my $s = $rs->next()) {
        $stock_data{$s->uniquename} = [$s->stock_id, $s->organism_id, $s->type_id];
    }

    my $stock_id_checked;
    my $stock_name_checked;
    my $organism_id_checked;
    my $stock_type_checked;
    my $timestamp = localtime();

    my $coderef = sub {

        #print STDERR Dumper \%design;
        my %new_stock_ids_hash;
        my $stock_rs = $chado_schema->resultset("Stock::Stock");

        foreach my $key (keys %design) {

            if ($key eq 'treatments'){
                next;
            }

            my $plot_name;
            if ($design{$key}->{plot_name}) {
                $plot_name = $design{$key}->{plot_name};
            }
            my $plot_number;
            if ($design{$key}->{plot_number}) {
                $plot_number = $design{$key}->{plot_number};
            } else {
                $plot_number = $key;
            }
            my $plant_names;
            if ($design{$key}->{plant_names}) {
                $plant_names = $design{$key}->{plant_names};
            }
            my $subplot_names;
            if ($design{$key}->{subplots_names}) {
                $subplot_names = $design{$key}->{subplots_names};
            }
            my $subplots_plant_names;
            if ($design{$key}->{subplots_plant_names}) {
                $subplots_plant_names = $design{$key}->{subplots_plant_names};
            }
            my $stock_name;
            if ($design{$key}->{stock_name}) {
                $stock_name = $design{$key}->{stock_name};
            }
            my $seedlot_name;
            my $seedlot_stock_id;
            if ($design{$key}->{seedlot_name}) {
                $seedlot_name = $design{$key}->{seedlot_name};
                $seedlot_stock_id = $seedlot_data{$seedlot_name};
            }
            my $num_seed_per_plot;
            if($design{$key}->{num_seed_per_plot}){
                $num_seed_per_plot = $design{$key}->{num_seed_per_plot};
            }
            my $weight_gram_seed_per_plot;
            if($design{$key}->{weight_gram_seed_per_plot}){
                $weight_gram_seed_per_plot = $design{$key}->{weight_gram_seed_per_plot};
            }
            my $block_number;
            if ($design{$key}->{block_number}) { #set block number to 1 if no blocks are specified
                $block_number = $design{$key}->{block_number};
            } else {
                $block_number = 1;
            }
            my $rep_number;
            if ($design{$key}->{rep_number}) { #set rep number to 1 if no reps are specified
                $rep_number = $design{$key}->{rep_number};
            } else {
                $rep_number = 1;
            }
            my $is_a_control;
            if ($design{$key}->{is_a_control}) {
                $is_a_control = $design{$key}->{is_a_control};
            }
            my $row_number;
            if ($design{$key}->{row_number}) {
                $row_number = $design{$key}->{row_number};
            }
            my $col_number;
            if ($design{$key}->{col_number}) {
                $col_number = $design{$key}->{col_number};
            }
            my $range_number;
            if ($design{$key}->{range_number}) {
                $range_number = $design{$key}->{range_number};
            }
            my $well_is_blank;
            if ($design{$key}->{is_blank}) {
                $well_is_blank = $design{$key}->{is_blank};
            }
            my $well_concentration;
            if ($design{$key}->{concentration}) {
                $well_concentration = $design{$key}->{concentration};
            }
            my $well_volume;
            if ($design{$key}->{volume}) {
                $well_volume = $design{$key}->{volume};
            }
            my $well_dna_person;
            if ($design{$key}->{dna_person}) {
                $well_dna_person = $design{$key}->{dna_person};
            }
            my $well_extraction;
            if ($design{$key}->{extraction}) {
                $well_extraction = $design{$key}->{extraction};
            }
            my $well_tissue_type;
            if ($design{$key}->{tissue_type}) {
                $well_tissue_type = $design{$key}->{tissue_type};
            }
            my $acquisition_date;
            if ($design{$key}->{acquisition_date}) {
                $acquisition_date = $design{$key}->{acquisition_date};
            }
            my $notes;
            if ($design{$key}->{notes}) {
                $notes = $design{$key}->{notes};
            }
            my $ncbi_taxonomy_id;
            if ($design{$key}->{ncbi_taxonomy_id}) {
                $ncbi_taxonomy_id = $design{$key}->{ncbi_taxonomy_id};
            }

            #check if stock_name exists in database by checking if stock_name is key in %stock_data. if it is not, then check if it exists as a synonym in the database.
            if ($stock_data{$stock_name}) {
                $stock_id_checked = $stock_data{$stock_name}[0];
                $organism_id_checked = $stock_data{$stock_name}[1];
                $stock_type_checked = $stock_data{$stock_name}[2];
                $stock_name_checked = $stock_name;
            } else {
                my $parent_stock;
                my $stock_lookup = CXGN::Stock::StockLookup->new(schema => $chado_schema);
                $stock_lookup->set_stock_name($stock_name);
                $parent_stock = $stock_lookup->get_stock($accession_cvterm_id);

                if (!$parent_stock) {
                    die ("Error while saving trial layout: no stocks found matching $stock_name");
                }

                $stock_id_checked = $parent_stock->stock_id();
                $stock_name_checked = $parent_stock->uniquename;
                $stock_type_checked = $parent_stock->type_id;
                $organism_id_checked = $parent_stock->organism_id();
            }

            #create the plot, if plot given
            my $new_plot_id;
            if ($plot_name) {
                my @plot_stock_props = (
                    { type_id => $replicate_cvterm_id, value => $rep_number },
                    { type_id => $block_cvterm_id, value => $block_number },
                    { type_id => $plot_number_cvterm_id, value => $plot_number }
                );
                if ($is_a_control) {
                    push @plot_stock_props, { type_id => $is_control_cvterm_id, value => $is_a_control };
                }
                if ($range_number) {
                    push @plot_stock_props, { type_id => $range_cvterm_id, value => $range_number };
                }
                if ($row_number) {
                    push @plot_stock_props, { type_id => $row_number_cvterm_id, value => $row_number };
                }
                if ($col_number) {
                    push @plot_stock_props, { type_id => $col_number_cvterm_id, value => $col_number };
                }
                if ($well_is_blank) {
                    push @plot_stock_props, { type_id => $is_blank_cvterm_id, value => $well_is_blank };
                }
                if ($well_concentration) {
                    push @plot_stock_props, { type_id => $concentration_cvterm_id, value => $well_concentration };
                }
                if ($well_volume) {
                    push @plot_stock_props, { type_id => $volume_cvterm_id, value => $well_volume };
                }
                if ($well_extraction) {
                    push @plot_stock_props, { type_id => $extraction_cvterm_id, value => $well_extraction };
                }
                if ($well_tissue_type) {
                    push @plot_stock_props, { type_id => $tissue_type_cvterm_id, value => $well_tissue_type };
                }
                if ($well_dna_person) {
                    push @plot_stock_props, { type_id => $dna_person_cvterm_id, value => $well_dna_person };
                }
                if ($acquisition_date) {
                    push @plot_stock_props, { type_id => $acquisition_date_cvterm_id, value => $acquisition_date };
                }
                if ($notes) {
                    push @plot_stock_props, { type_id => $notes_cvterm_id, value => $notes };
                }
                if ($ncbi_taxonomy_id) {
                    push @plot_stock_props, { type_id => $ncbi_taxonomy_id_cvterm_id, value => $ncbi_taxonomy_id };
                }

                my @plot_subjects;
                my @plot_objects;

                my $parent_stock;
                push @plot_subjects, { type_id => $stock_rel_type_id, object_id => $stock_id_checked };

                # For genotyping plate, if the well tissue_sample is sourced from a plot, then we store relationships between the tissue_sample and the plot, and the tissue sample and the plot's accession if it exists.
                if ($stock_type_checked == $plot_cvterm_id){
                    my $parent_plot_accession_rs = $chado_schema->resultset("Stock::StockRelationship")->search({
                        'me.subject_id'=>$stock_id_checked,
                        'me.type_id'=>$plot_of_cvterm_id,
                        'object.type_id'=>$accession_cvterm_id
                    }, {join => 'object'});
                    if ($parent_plot_accession_rs->count > 1){
                        die "Plot $stock_id_checked is linked to more than one accession!\n"
                    }
                    if ($parent_plot_accession_rs->count == 1){
                        push @plot_subjects, { type_id => $stock_rel_type_id, object_id => $parent_plot_accession_rs->first->object_id };
                    }
                }
                # For genotyping plate, if the well tissue_sample is sourced from a plant, then we store relationships between the tissue_sample and the plant, and the tissue_sample and the plant's plot if it exists, and the tissue sample and the plant's accession if it exists.
                if ($stock_type_checked == $plant_cvterm_id){
                    my $parent_plant_accession_rs = $chado_schema->resultset("Stock::StockRelationship")->search({
                        'me.subject_id'=>$stock_id_checked,
                        'me.type_id'=>$plant_of_cvterm_id,
                        'object.type_id'=>$accession_cvterm_id
                    }, {join => "object"});
                    if ($parent_plant_accession_rs->count > 1){
                        die "Plant $stock_id_checked is linked to more than one accession!\n"
                    }
                    if ($parent_plant_accession_rs->count == 1){
                        push @plot_subjects, { type_id => $stock_rel_type_id, object_id => $parent_plant_accession_rs->first->object_id };
                    }
                    my $parent_plot_of_plant_rs = $chado_schema->resultset("Stock::StockRelationship")->search({
                        'me.subject_id'=>$stock_id_checked,
                        'me.type_id'=>$plant_of_cvterm_id,
                        'object.type_id'=>$plot_cvterm_id
                    }, {join => "object"});
                    if ($parent_plot_of_plant_rs->count > 1){
                        die "Plant $stock_id_checked is linked to more than one plot!\n"
                    }
                    if ($parent_plot_of_plant_rs->count == 1){
                        push @plot_subjects, { type_id => $stock_rel_type_id, object_id => $parent_plot_of_plant_rs->first->object_id };
                    }
                }
                # For genotyping plate, if the well tissue_sample is sourced from another tissue_sample, then we store relationships between the new tissue_sample and the source tissue_sample, and the new tissue_sample and the tissue_sample's plant if it exists, and the new tissue_sample and the tissue_sample's plot if it exists, and the new tissue sample and the tissue_sample's accession if it exists.
                if ($stock_type_checked == $tissue_sample_cvterm_id){
                    my $parent_tissue_sample_accession_rs = $chado_schema->resultset("Stock::StockRelationship")->search({
                        'me.subject_id'=>$stock_id_checked,
                        'me.type_id'=>$tissue_sample_of_cvterm_id,
                        'object.type_id'=>$accession_cvterm_id
                    }, {join => "object"});
                    if ($parent_tissue_sample_accession_rs->count > 1){
                        die "Tissue_sample $stock_id_checked is linked to more than one accession!\n"
                    }
                    if ($parent_tissue_sample_accession_rs->count == 1){
                        push @plot_subjects, { type_id => $stock_rel_type_id, object_id => $parent_tissue_sample_accession_rs->first->object_id };
                    }
                    my $parent_plot_of_tissue_sample_rs = $chado_schema->resultset("Stock::StockRelationship")->search({
                        'me.subject_id'=>$stock_id_checked,
                        'me.type_id'=>$tissue_sample_of_cvterm_id,
                        'object.type_id'=>$plot_cvterm_id
                    }, {join => "object"});
                    if ($parent_plot_of_tissue_sample_rs->count > 1){
                        die "Tissue_sample $stock_id_checked is linked to more than one plot!\n"
                    }
                    if ($parent_plot_of_tissue_sample_rs->count == 1){
                        push @plot_subjects, { type_id => $stock_rel_type_id, object_id => $parent_plot_of_tissue_sample_rs->first->object_id };
                    }
                    my $parent_plant_of_tissue_sample_rs = $chado_schema->resultset("Stock::StockRelationship")->search({
                        'me.subject_id'=>$stock_id_checked,
                        'me.type_id'=>$tissue_sample_of_cvterm_id,
                        'object.type_id'=>$plant_cvterm_id
                    }, {join => "object"});
                    if ($parent_plant_of_tissue_sample_rs->count > 1){
                        die "Tissue_sample $stock_id_checked is linked to more than one plant!\n"
                    }
                    if ($parent_plant_of_tissue_sample_rs->count == 1){
                        push @plot_subjects, { type_id => $stock_rel_type_id, object_id => $parent_plant_of_tissue_sample_rs->first->object_id };
                    }
                }

                my @plot_nd_experiment_stocks = (
                    { nd_experiment_id => $nd_experiment_id, type_id => $nd_experiment_type_id }
                );

                my $plot = $stock_rs->create({
                    organism_id => $organism_id_checked,
                    name       => $plot_name,
                    uniquename => $plot_name,
                    type_id => $stock_type_id,
                    stockprops => \@plot_stock_props,
                    stock_relationship_subjects => \@plot_subjects,
                    stock_relationship_objects => \@plot_objects,
                    nd_experiment_stocks => \@plot_nd_experiment_stocks,
                });
                $new_plot_id = $plot->stock_id();
                $new_stock_ids_hash{$plot_name} = $new_plot_id;

                if ($seedlot_stock_id && $seedlot_name){
                    my $transaction = CXGN::Stock::Seedlot::Transaction->new(schema => $chado_schema);
                    $transaction->from_stock([$seedlot_stock_id, $seedlot_name]);
                    $transaction->to_stock([$plot->stock_id(), $plot->uniquename()]);
                    if ($num_seed_per_plot){
                        $transaction->amount($num_seed_per_plot);
                    }
                    if ($weight_gram_seed_per_plot){
                        $transaction->weight_gram($weight_gram_seed_per_plot);
                    }
                    $transaction->timestamp($timestamp);
                    my $description = "Created Trial: ".$self->get_trial_name." Plot: ".$plot->uniquename;
                    $transaction->description($description);
                    $transaction->operator($self->get_operator);
                    my $transaction_id = $transaction->store();
                    my $sl = CXGN::Stock::Seedlot->new(schema=>$chado_schema, seedlot_id=>$seedlot_stock_id);
                    $sl->set_current_count_property();
                    $sl->set_current_weight_property();
                }
            }

            #Create plant entry if given. Currently this is for the greenhouse trial creation and splitplot trial creation.
            if ($plant_names) {
                my $plant_index_number = 1;
                foreach my $plant_name (@$plant_names) {

                    my @plant_stock_props = (
                        { type_id => $plant_index_number_cvterm_id, value => $plant_index_number },
                        { type_id => $replicate_cvterm_id, value => $rep_number },
                        { type_id => $block_cvterm_id, value => $block_number },
                        { type_id => $plot_number_cvterm_id, value => $plot_number }
                    );
                    if ($is_a_control) {
                        push @plant_stock_props, { type_id => $is_control_cvterm_id, value => $is_a_control };
                    }
                    if ($range_number) {
                        push @plant_stock_props, { type_id => $range_cvterm_id, value => $range_number };
                    }
                    if ($row_number) {
                        push @plant_stock_props, { type_id => $row_number_cvterm_id, value => $row_number };
                    }
                    if ($col_number) {
                        push @plant_stock_props, { type_id => $col_number_cvterm_id, value => $col_number };
                    }

                    my @plant_objects = (
                        { type_id => $plant_of_cvterm_id, subject_id => $new_plot_id }
                    );
                    my @plant_subjects = (
                        { type_id => $plant_of_cvterm_id, object_id => $stock_id_checked }
                    );
                    my @plant_nd_experiment_stocks = (
                        { type_id => $nd_experiment_type_id, nd_experiment_id => $nd_experiment_id }
                    );

                    my $plant = $stock_rs->create({
                        organism_id => $organism_id_checked,
                        name       => $plant_name,
                        uniquename => $plant_name,
                        type_id => $plant_cvterm_id,
                        stockprops => \@plant_stock_props,
                        stock_relationship_subjects => \@plant_subjects,
                        stock_relationship_objects => \@plant_objects,
                        nd_experiment_stocks => \@plant_nd_experiment_stocks,
                    });
                    $new_stock_ids_hash{$plant_name} = $plant->stock_id();
                    $plant_index_number++;
                }
            }
            #Create subplot entry if given. Currently this is for the splitplot trial creation.
            if ($subplot_names) {
                my $subplot_index_number = 1;
                foreach my $subplot_name (@$subplot_names) {
                    my @subplot_stockprops = (
                        { type_id => $subplot_index_number_cvterm_id, value => $subplot_index_number },
                        { type_id => $replicate_cvterm_id, value => $rep_number },
                        { type_id => $block_cvterm_id, value => $block_number },
                        { type_id => $plot_number_cvterm_id, value => $plot_number }
                    );
                    if ($is_a_control) {
                        push @subplot_stockprops, { type_id => $is_control_cvterm_id, value => $is_a_control };
                    }
                    if ($range_number) {
                        push @subplot_stockprops, { type_id => $range_cvterm_id, value => $range_number };
                    }
                    if ($row_number) {
                        push @subplot_stockprops, { type_id => $row_number_cvterm_id, value => $row_number };
                    }
                    if ($col_number) {
                        push @subplot_stockprops, { type_id => $col_number_cvterm_id, value => $col_number };
                    }

                    my @subplot_objects = (
                        { type_id => $subplot_of_cvterm_id, subject_id => $new_plot_id }
                    );
                    my @subplot_subjects = (
                        { type_id => $subplot_of_cvterm_id, object_id => $stock_id_checked }
                    );
                    my @subplot_nd_experiment_stocks = (
                        { type_id => $nd_experiment_type_id, nd_experiment_id => $nd_experiment_id }
                    );

                    if ($subplots_plant_names){
                        my $subplot_plants = $subplots_plant_names->{$subplot_name};
                        foreach (@$subplot_plants) {
                            my $plant_stock_id = $new_stock_ids_hash{$_};
                            push @subplot_objects, { type_id => $plant_of_subplot_cvterm_id, subject_id => $plant_stock_id };
                        }
                    }

                    my $subplot = $stock_rs->create({
                        organism_id => $organism_id_checked,
                        name       => $subplot_name,
                        uniquename => $subplot_name,
                        type_id => $subplot_cvterm_id,
                        stockprops => \@subplot_stockprops,
                        stock_relationship_subjects => \@subplot_subjects,
                        stock_relationship_objects => \@subplot_objects,
                        nd_experiment_stocks => \@subplot_nd_experiment_stocks,
                    });
                    $new_stock_ids_hash{$subplot_name} = $subplot->stock_id();
                    $subplot_index_number++;

                }
            }
        }

        if (exists($design{treatments})){
            print STDERR "Saving treatments\n";
            while(my($treatment_name, $stock_names) = each(%{$design{treatments}})){

                my @treatment_nd_experiment_stocks;
                foreach (@$stock_names){
                    my $stock_id;
                    if (exists($new_stock_ids_hash{$_})){
                        $stock_id = $new_stock_ids_hash{$_};
                    } else {
                        $stock_id = $chado_schema->resultset("Stock::Stock")->find({uniquename=>$_})->stock_id();
                    }
                    push @treatment_nd_experiment_stocks, { type_id => $treatment_nd_experiment_type_id, stock_id => $stock_id };
                }

                my $nd_experiment = $chado_schema->resultset('NaturalDiversity::NdExperiment')->create({
                    nd_geolocation_id => $nd_geolocation_id,
                    type_id => $treatment_nd_experiment_type_id,
                    nd_experiment_stocks => \@treatment_nd_experiment_stocks
                });

                my @treatment_project_props = (
                    { type_id => $project_design_cvterm_id, value => 'treatment' }
                );

                if ($self->get_new_treatment_has_plant_entries){
                    push @treatment_project_props, { type_id => $has_plants_cvterm, value => $self->get_new_treatment_has_plant_entries };
                }
                if ($self->get_new_treatment_has_subplot_entries){
                    push @treatment_project_props, { type_id => $has_subplots_cvterm, value => $self->get_new_treatment_has_subplot_entries };
                }
                if ($self->get_new_treatment_has_tissue_sample_entries){
                    push @treatment_project_props, { type_id => $has_tissues_cvterm, value => $self->get_new_treatment_has_tissue_sample_entries };
                }
                if ($self->get_new_treatment_type){
                    push @treatment_project_props, { type_id => $management_factor_type_cvterm_id, value => $self->get_new_treatment_type };
                }
                if ($self->get_new_treatment_year){
                    push @treatment_project_props, { type_id => $management_factor_year_cvterm_id, value => $self->get_new_treatment_year };
                } else {
                    my $t = CXGN::Trial->new({
                        bcs_schema => $chado_schema,
                        trial_id => $self->get_trial_id
                    });
                    push @treatment_project_props, { type_id => $management_factor_year_cvterm_id, value => $t->get_year() };
                }

                my @treatment_nd_experiment_project = (
                    { nd_experiment_id => $nd_experiment->nd_experiment_id }
                );

                my @treatment_relationships = (
                    { type_id => $trial_treatment_relationship_cvterm_id, object_project_id => $self->get_trial_id }
                );

                #Create a project for each treatment_name
                my $project_treatment_name = $self->get_trial_name()."_".$treatment_name;
                my $treatment_project = $chado_schema->resultset('Project::Project')->create({
                    name => $project_treatment_name,
                    description => '',
                    projectprops => \@treatment_project_props,
                    project_relationship_subject_projects => \@treatment_relationships,
                    nd_experiment_projects => \@treatment_nd_experiment_project
                });

                if ($self->get_new_treatment_date()) {
                    my $management_factor_t = CXGN::Trial->new({
                        bcs_schema => $chado_schema,
                        trial_id => $treatment_project->project_id()
                    });
                    $management_factor_t->set_management_factor_date($self->get_new_treatment_date() );
                }
            }
        }

        print STDERR "Design Stored ".localtime."\n";
    };

    my $transaction_error;
    try {
        $chado_schema->txn_do($coderef);
    } catch {
        print STDERR "Transaction Error: $_\n";
        $transaction_error =  $_;
    };
    return $transaction_error;
}

1;
