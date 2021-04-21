package CXGN::Trial::TrialCreate;

=head1 NAME

CXGN::Trial::TrialCreate - Module to create an entirely new trial based on a specified design. For field_layout experiments and genotyping_layout experiments.

Will do the following:
1) Create a new project entry in Project table based on trial and description supplied to object. If there is a project with the name already saved, it will return an error and do nothing.
2) Create a single new experiment entry in nd_experiment. If is_genotyping is supplied, this will be type = genotyping_layout. Otherwise, this will be type = field_layout.
3) Will associate the location to the project through the nd_experiment as well as through a projectprop. Location lookup happens based on location name that is provided. Assumes locations already stored in database.
4) Will associate the trial to its breeding program. Lookup is by breeding program name that is provided and assumes bp already exists in database. Will return an error if breeding program name not found.
5) Creates a single nd_experiment_project entry, linking project to nd_experiment.
6) Creates a year and design projectprop. Also a project_type projectprop if provided. For genotyping plates also creates others like, genotyping_facility and plate_format projectprops
7) Calls the CXGN::Trial::TrialDesignStore object to handle storing stocks (tissue_samples, or plots and plants and subplots) and stockprops (rep, block, well, etc)

=head1 USAGE

    FOR FIELD PHENOTYPING TRIALS:
    my $trial_create = CXGN::Trial::TrialCreate->new({
        chado_schema => $c->dbic_schema("Bio::Chado::Schema"),
        dbh => $c->dbc->dbh(),
		owner_id => $c->user()->get_object()->get_sp_person_id(),
        operator => $c->user()->get_object()->get_username(),
        design_type => 'CRD',
        design => $design_hash,
        program => $breeding_program->name(),
        trial_year => $year,
        trial_description => $project_description,
        trial_location => $location->name(),
        trial_name => $trial_name,
        trial_type => $trialtype,
        field_size => $field_size, #(ha)
        plot_width => $plot_width, #(m)
        plot_length => $plot_length, #(m)
        field_trial_is_planned_to_cross => 'yes', #yes or no
        field_trial_is_planned_to_be_genotyped => 'no', #yes or no
        field_trial_from_field_trial => ['source_trial_id1', 'source_trial_id2'],
        genotyping_trial_from_field_trial => ['genotyping_trial_id1'],
        crossing_trial_from_field_trial => ['crossing_trial_id1']
    });
    try {
        $trial_create->save_trial();
    } catch {
        print STDERR "ERROR SAVING TRIAL!\n";
    };

    FOR GENOTYPING PLATES:
    my $ct = CXGN::Trial::TrialCreate->new( {
        chado_schema => $c->dbic_schema("Bio::Chado::Schema"),
        dbh => $c->dbc->dbh(),
		owner_id => $c->user()->get_object()->get_sp_person_id(),
        operator => $c->user()->get_object()->get_username(),
        trial_year => $year,
        trial_location => $location->name(),
        program => $breeding_program->name(),
        trial_description => $description,
        design_type => 'genotyping_plate',
        design => $design_hash,
        trial_name => $trial_name,
        is_genotyping => 1,
        genotyping_user_id => $user_id,
        genotyping_project_name => $project_name,
        genotyping_facility_submit => $plate_info->{genotyping_facility_submit},
        genotyping_facility => $plate_info->{genotyping_facility},
        genotyping_plate_format => $plate_info->{plate_format},
        genotyping_plate_sample_type => $plate_info->{sample_type},
        genotyping_trial_from_field_trial => ['field_trial_id1'],
    });
    try {
        $ct->save_trial();
    } catch {
        print STDERR "ERROR SAVING TRIAL!\n";
    };

---------------------------------------------------------------------------------

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

=head1 DESCRIPTION


=head1 AUTHORS

 Jeremy D. Edwards (jde22@cornell.edu)

=cut


use Moose;
use MooseX::FollowPBP;
use Moose::Util::TypeConstraints;
use Try::Tiny;
use CXGN::Stock::StockLookup;
use CXGN::Location::LocationLookup;
use CXGN::People::Person;
use CXGN::Trial;
use SGN::Model::Cvterm;
use CXGN::Trial::TrialDesignStore;
use Data::Dumper;

has 'chado_schema' => (
		 is       => 'rw',
		 isa      => 'DBIx::Class::Schema',
		 predicate => 'has_chado_schema',
		 required => 1,
		);

has 'dbh' => (is  => 'rw',predicate => 'has_dbh', required => 1,);
#has 'user_name' => (isa => 'Str', is => 'rw', predicate => 'has_user_name', required => 1,);
has 'trial_id' => (isa => 'Maybe[Int]', is => 'rw', predicate => 'has_trial_id');
has 'program' => (isa =>'Str', is => 'rw', predicate => 'has_program', required => 1,);
has 'trial_year' => (isa => 'Str', is => 'rw', predicate => 'has_trial_year', required => 1,);
has 'trial_description' => (isa => 'Str', is => 'rw', predicate => 'has_trial_description', required => 1,);
has 'trial_location' => (isa => 'Str', is => 'rw', predicate => 'has_trial_location', required => 1,);
has 'design_type' => (isa => 'Str', is => 'rw', predicate => 'has_design_type', required => 1);
has 'design' => (isa => 'HashRef[HashRef]|Undef', is => 'rw', predicate => 'has_design', required => 1);
has 'trial_name' => (isa => 'Str', is => 'rw', predicate => 'has_trial_name', required => 1);
has 'trial_type' => (isa => 'Str', is => 'rw', predicate => 'has_trial_type', required => 0);
has 'trial_has_plant_entries' => (isa => 'Int', is => 'rw', predicate => 'has_trial_has_plant_entries', required => 0);
has 'trial_has_subplot_entries' => (isa => 'Int', is => 'rw', predicate => 'has_trial_has_subplot_entries', required => 0);
has 'field_size' => (isa => 'Num', is => 'rw', predicate => 'has_field_size', required => 0);
has 'plot_width' => (isa => 'Num', is => 'rw', predicate => 'has_plot_width', required => 0);
has 'plot_length' => (isa => 'Num', is => 'rw', predicate => 'has_plot_length', required => 0);
has 'planting_date' => (isa => 'Str', is => 'rw', predicate => 'has_planting_date', required => 0);
has 'harvest_date' => (isa => 'Str', is => 'rw', predicate => 'has_harvest_date', required => 0);
has 'operator' => (isa => 'Str', is => 'rw', predicate => 'has_operator', required => 1);
has 'trial_stock_type' => (isa => 'Str', is => 'rw', predicate => 'has_trial_stock_type', required => 0, default => 'accession');

# Trial linkage when saving a field trial
#
has 'field_trial_is_planned_to_cross' => (isa => 'Str', is => 'rw', predicate => 'has_field_trial_is_planned_to_cross', required => 0);
has 'field_trial_is_planned_to_be_genotyped' => (isa => 'Str', is => 'rw', predicate => 'has_field_trial_is_planned_to_be_genotyped', required => 0);
has 'field_trial_from_field_trial' => (isa => 'ArrayRef', is => 'rw', predicate => 'has_field_trial_from_field_trial', required => 0);
has 'crossing_trial_from_field_trial' => (isa => 'ArrayRef', is => 'rw', predicate => 'has_crossing_trial_from_field_trial', required => 0);

# Trial linkage when saving either a field trial or genotyping plate
#
has 'genotyping_trial_from_field_trial' => (isa => 'ArrayRef', is => 'rw', predicate => 'has_genotyping_trial_from_field_trial', required => 0);

# Properties for genotyping plates
#
has 'is_genotyping' => (isa => 'Bool', is => 'rw', required => 0, default => 0, );
has 'genotyping_user_id' => (isa => 'Str', is => 'rw');
has 'genotyping_project_name' => (isa => 'Str', is => 'rw');
has 'genotyping_facility_submitted' => (isa => 'Str', is => 'rw');
has 'genotyping_facility' => (isa => 'Str', is => 'rw');
has 'genotyping_plate_format' => (isa => 'Str', is => 'rw');
has 'genotyping_plate_sample_type' => (isa => 'Str', is => 'rw');

# properties for analyses
#
has 'is_analysis' => (isa => 'Bool', is => 'rw', required => 0, default => 0, );
has 'analysis_model_protocol_id' => (isa => 'Int|Undef', is => 'rw', required => 0 );

# Trial linkage when saving either a sampling trial
#
has 'sampling_trial_from_field_trial' => (isa => 'ArrayRef', is => 'rw', predicate => 'has_sampling_trial_from_field_trial', required => 0);

# Properties for sampling trials
#
has 'is_sampling_trial' => (isa => 'Bool', is => 'rw', required => 0, default => 0, );
has 'sampling_trial_facility' => (isa => 'Str', is => 'rw');
has 'sampling_trial_sample_type' => (isa => 'Str', is => 'rw');

has 'owner_id' => (isa => 'Int' , is => 'rw');

sub trial_name_already_exists {
    my $self = shift;

    if ($self->get_is_analysis()) { return; }
    my $trial_name = $self->get_trial_name();
    my $schema = $self->get_chado_schema();
    if($schema->resultset('Project::Project')->find({name => $trial_name})){
	return 1;
    }
    else {
	return;
    }
}

sub get_breeding_program_id {
  my $self = shift;
  my $breeding_program_ref = $self->get_chado_schema->resultset('Project::Project')->find({name=>$self->get_program});
  if (!$breeding_program_ref ) {
      print STDERR "UNDEF breeding program " . $self->get_program . "\n\n";
      return ;
  }
  my $breeding_program_id = $breeding_program_ref->project_id();
  #print STDERR "get_breeding_program _id returning $breeding_program_id";
  return $breeding_program_id;
}


sub save_trial {
    print STDERR "Check 4.1: ".localtime();
    my $self = shift;
    my $chado_schema = $self->get_chado_schema();
    my %design = %{$self->get_design()};
    my $trial_name = $self->get_trial_name();
    $trial_name =~ s/^\s+|\s+$//g; #trim whitespace from both ends

    # if a trial id is provided, the project row has already been
    # created by other means, so use that trial_id

    if (! $self->has_trial_id()) {

	if (!$trial_name) {
		print STDERR "Trial not saved: Can't create trial without a trial name\n";
		return { error => "Trial not saved: Can't create trial without a trial name" };
	}

    if ($self->trial_name_already_exists()) {
		print STDERR "Can't create trial: Trial name already exists\n";
		return { error => "Trial not saved: Trial name already exists" };
	}

	if (!$self->get_breeding_program_id()) {
		print STDERR "Can't create trial: Breeding program does not exist\n";
		return { error => "Trial not saved: breeding program does not exist" };
	}

	#lookup user by name
	#my $user_name = $self->get_user_name();
	#my $dbh = $self->get_dbh();
	#my $owner_sp_person_id;
	#$owner_sp_person_id = CXGN::People::Person->get_person_by_username($dbh, $user_name); #add person id as an option.
	#if (!$owner_sp_person_id) {
	#	print STDERR "Can't create trial: User/owner not found\n";
	#	die "no owner $user_name" ;
	#}
    }
	my $geolocation;
	my $geolocation_lookup = CXGN::Location::LocationLookup->new(schema => $chado_schema);
	$geolocation_lookup->set_location_name($self->get_trial_location());
	$geolocation = $geolocation_lookup->get_geolocation();
	if (!$geolocation) {
		print STDERR "Can't create trial: Location not found: ".$self->get_trial_location()."\n";
		return { error => "Trial not saved: location not found" };
	}

    my $project_year_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'project year', 'project_property');
    my $project_design_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'design', 'project_property');
    my $field_size_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'field_size', 'project_property');
    my $plot_width_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plot_width', 'project_property');
    my $plot_length_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plot_length', 'project_property');
    my $field_trial_is_planned_to_be_genotyped_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'field_trial_is_planned_to_be_genotyped', 'project_property');
    my $field_trial_is_planned_to_cross_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'field_trial_is_planned_to_cross', 'project_property');
    my $has_plant_entries_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'project_has_plant_entries', 'project_property');
    my $has_subplot_entries_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'project_has_subplot_entries', 'project_property');
    my $genotyping_facility_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'genotyping_facility', 'project_property');
    my $genotyping_facility_submitted_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'genotyping_facility_submitted', 'project_property');
    my $genotyping_plate_format_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'genotyping_plate_format', 'project_property');
    my $genotyping_plate_sample_type_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'genotyping_plate_sample_type', 'project_property');
    my $genotyping_user_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'genotyping_user_id', 'nd_experiment_property');
    my $genotyping_project_name_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'genotyping_project_name', 'nd_experiment_property');
    my $trial_stock_type_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'trial_stock_type', 'project_property');
    my $sampling_facility_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'sampling_facility', 'project_property');
    my $sampling_trial_sample_type_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'sampling_trial_sample_type', 'project_property');

    my $project;
    if ($self->has_trial_id()) {
        $project = $chado_schema->resultset('Project::Project')->find( { project_id => $self->get_trial_id() });
        if (! $project) {  die "The specified project id ".$self->get_trial_id()." does not exit in the database\n"; }
    }
    else {
        $project = $chado_schema->resultset('Project::Project')
        ->create({
            name => $trial_name,
            description => $self->get_trial_description(),
        });
    }

    my $t = CXGN::Trial->new({
        bcs_schema => $chado_schema,
        trial_id => $project->project_id()
    });

    $t->set_trial_owner($self->get_owner_id);
    #print STDERR "TRIAL TYPE = ".ref($t)."!!!!\n";
    my $nd_experiment_type_id;
    if ($self->get_is_genotyping()) {
        print STDERR "Generating a genotyping trial...\n";
        $nd_experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'genotyping_layout', 'experiment_type')->cvterm_id();
    }
    elsif ($self->get_is_analysis()) {
        print STDERR "Generating an analysis trial...\n";
        $nd_experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, , 'analysis_experiment', 'experiment_type')->cvterm_id();
    }
    elsif ($self->get_is_sampling_trial()) {
        print STDERR "Generating a sampling trial...\n";
        $nd_experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, , 'sampling_layout', 'experiment_type')->cvterm_id();
    }
    else {
        print STDERR "Generating a phenotyping trial...\n";
        $nd_experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, , 'field_layout', 'experiment_type')->cvterm_id();
    }
    my $nd_experiment = $chado_schema->resultset('NaturalDiversity::NdExperiment')
    ->create({
        nd_geolocation_id => $geolocation->nd_geolocation_id(),
        type_id => $nd_experiment_type_id,
    });


    if ($self->get_is_genotyping()) {
        #print STDERR "Storing user_id and project_name provided by the IGD spreadksheet for later recovery in the spreadsheet download... ".(join ",", ($self->get_genotyping_user_id(), $self->get_genotyping_project_name()))."\n";
        $nd_experiment->create_nd_experimentprops({
            $genotyping_user_cvterm->name() => $self->get_genotyping_user_id(),
            $genotyping_project_name_cvterm->name() => $self->get_genotyping_project_name(),
        });

        $project->create_projectprops({
            $genotyping_facility_cvterm->name() => $self->get_genotyping_facility(),
            $genotyping_facility_submitted_cvterm->name() => $self->get_genotyping_facility_submitted(),
            $genotyping_plate_format_cvterm->name() => $self->get_genotyping_plate_format(),
            $genotyping_plate_sample_type_cvterm->name() => $self->get_genotyping_plate_sample_type()
        });

        my $source_field_trial_ids = $t->set_source_field_trials_for_genotyping_trial($self->get_genotyping_trial_from_field_trial);
    }
    elsif ($self->get_is_analysis()) {
        if ($self->get_analysis_model_protocol_id) {
            #link to the saved analysis model
            $nd_experiment->find_or_create_related('nd_experiment_protocols', {nd_protocol_id => $self->get_analysis_model_protocol_id() });
        }
    }
    elsif ($self->get_is_sampling_trial()) {
        $project->create_projectprops({
            $sampling_facility_cvterm->name() => $self->get_sampling_trial_facility(),
            $sampling_trial_sample_type_cvterm->name() => $self->get_sampling_trial_sample_type()
        });

        my $source_field_trial_ids = $t->set_source_field_trials_for_sampling_trial($self->get_sampling_trial_from_field_trial);
    }
    else {
        my $source_field_trial_ids = $t->set_field_trials_source_field_trials($self->get_field_trial_from_field_trial);
        my $genotyping_trial_ids = $t->set_genotyping_trials_from_field_trial($self->get_genotyping_trial_from_field_trial);
        my $crossing_trial_ids = $t->set_crossing_trials_from_field_trial($self->get_crossing_trial_from_field_trial);
    }

    $t->set_location($geolocation->nd_geolocation_id()); # set location also as a project prop
    $t->set_breeding_program($self->get_breeding_program_id);
    if ($self->get_trial_type){
        $t->set_project_type($self->get_trial_type);
    }
    if ($self->get_planting_date){
        $t->set_planting_date($self->get_planting_date);
    }
    if ($self->get_harvest_date){
        $t->set_harvest_date($self->get_harvest_date);
    }

    #link to the project
    $nd_experiment->find_or_create_related('nd_experiment_projects',{project_id => $project->project_id()});

    $project->create_projectprops({
        $project_year_cvterm->name() => $self->get_trial_year(),
        $project_design_cvterm->name() => $self->get_design_type()
    });
    if ($self->has_field_size && $self->get_field_size){
        $project->create_projectprops({
            $field_size_cvterm->name() => $self->get_field_size
        });
    }
    if ($self->has_plot_width && $self->get_plot_width){
        $project->create_projectprops({
            $plot_width_cvterm->name() => $self->get_plot_width
        });
    }
    if ($self->has_plot_length && $self->get_plot_length){
        $project->create_projectprops({
            $plot_length_cvterm->name() => $self->get_plot_length
        });
    }
    if ($self->has_trial_has_plant_entries && $self->get_trial_has_plant_entries){
        $project->create_projectprops({
            $has_plant_entries_cvterm->name() => $self->get_trial_has_plant_entries
        });
    }
    if ($self->has_trial_has_subplot_entries && $self->get_trial_has_subplot_entries){
        $project->create_projectprops({
            $has_subplot_entries_cvterm->name() => $self->get_trial_has_subplot_entries
        });
    }
    if ($self->has_field_trial_is_planned_to_cross && $self->get_field_trial_is_planned_to_cross){
        $project->create_projectprops({
            $field_trial_is_planned_to_cross_cvterm->name() => $self->get_field_trial_is_planned_to_cross
        });
    }
    if ($self->has_field_trial_is_planned_to_be_genotyped && $self->get_field_trial_is_planned_to_be_genotyped){
        $project->create_projectprops({
            $field_trial_is_planned_to_be_genotyped_cvterm->name() => $self->get_field_trial_is_planned_to_be_genotyped
        });
    }

    if (!$self->get_is_genotyping) {
        if ($self->has_trial_stock_type && $self->get_trial_stock_type){
            $project->create_projectprops({
                $trial_stock_type_cvterm->name() => $self->get_trial_stock_type()
            });
        }
    }

    my $design_type = $self->get_design_type();
    if ($design_type eq 'greenhouse') {
        my $has_plants_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'project_has_plant_entries', 'project_property');
        $project->create_projectprops({ $has_plants_cvterm->name() => 'varies' });
    }

    print STDERR "NOW CALLING TRIAl DESIGN STORE...\n";
    my $trial_design_store = CXGN::Trial::TrialDesignStore->new({
        bcs_schema => $chado_schema,
        trial_id => $project->project_id(),
        trial_name => $trial_name,
        nd_geolocation_id => $geolocation->nd_geolocation_id(),
        nd_experiment_id => $nd_experiment->nd_experiment_id(),
        design_type => $design_type,
        design => \%design,
        is_genotyping => $self->get_is_genotyping(),
        is_analysis => $self->get_is_analysis(),
        is_sampling_trial => $self->get_is_sampling_trial(),
        new_treatment_has_plant_entries => $self->get_trial_has_plant_entries,
        new_treatment_has_subplot_entries => $self->get_trial_has_subplot_entries,
        operator => $self->get_operator,
        trial_stock_type => $self->get_trial_stock_type(),
    });
    my $error;
    my $validate_design_error = $trial_design_store->validate_design();
    if ($validate_design_error) {
        print STDERR "ERROR: $validate_design_error\n";
        return { error => "Error validating trial design: $validate_design_error." };
    } else {
	try {
	    $error = $trial_design_store->store();
	} catch {
	    print STDERR "ERROR store: $_\n";
	    $error = $_;
	};
    }
    if ($error) {
	return { error => $error };
    }
    return { trial_id => $project->project_id };
}





#######
1;
#######
