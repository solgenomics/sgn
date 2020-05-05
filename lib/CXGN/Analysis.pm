
=encoding utf-8

=head1 NAME

CXGN::Analysis - manage analyses on Breedbase

=head1 DESCRIPTION

Analyses are stored much like trials, starting out in the project table, and linking through to nd_experiment and stock through linking tables, as well phentoype to store the analysis results. Additional metadata is stored in in a projectprop with the type_id 'analysis_metadata_json'. The type of the project is 'analysis_project' (stored in a projectprop as well). Each analysis is assigned to a user, using and sp_person_id assigned in a projectprop.

=head2 TYPES

The data structure is built using type ids that are different from a regular field trial.

=over 4

=item nd_experiment.type_id

The nd_experiment.type_id links to 'analysis_experiment' (nd_experiment_property) (equivalent to 'field_experiment' in a trial), 

=item stock.type_id 

The stock.type_id links to 'analysis_instance' (stock_property) (equivalent to 'plot' in a trial)

=item stock_relationship.type_id

The stock_relationship.type_id links to 'analysis_of' (equivalent to 'plot_of' in field trials)

=back

This is summarized in the following table:

 ┌──────────────────┬───────────────────────┬───────────────────┬────────────────┐
 │ project type     │ nd_experiment.type_id │ stock.type_id     │ stock_relation │
 │                  │                       │                   │ ship.type_id   │
 ├──────────────────┼───────────────────────┼───────────────────┼────────────────┤
 │ trial            │ field_experiment      │ plot              │ plot_of        │
 ├──────────────────┼───────────────────────┼───────────────────┼────────────────┤
 │ genotyping_plate │ genotyping_experiment │ tissue_sample     │ sample_of      │
 ├──────────────────┼───────────────────────┼───────────────────┼────────────────┤
 │ analysis         │ analysis_experiment   │ analysis_instance │ analysis_of    │
 └──────────────────┴───────────────────────┴───────────────────┴────────────────┘


=back

The data in  analysis_metdata_json is managed by the CXGN::Analysis::AnalysisMetadata class and contains the dataset_id used to generate the analysis, the actual analysis protocol that was run, and the traits relevant to the analysis.

=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>

=head1 METHODS

=cut
    
package CXGN::Analysis;

use Moose;

extends 'CXGN::Project';

use Try::Tiny;
use DateTime;
use Data::Dumper;
use CXGN::Trial::TrialCreate;
use CXGN::Trial::TrialDesign;
use CXGN::Trial::TrialDesignStore;
use CXGN::Trial::TrialLayout;
use CXGN::Phenotypes::StorePhenotypes;
use CXGN::Analysis::AnalysisMetadata;
use CXGN::List::Transform;
use CXGN::Dataset;



=head2 bcs_schema()

=cut
    
# has 'bcs_schema' => (is => 'rw', isa => 'Ref', required => 1 );

=head2 people_schema()

=cut
    
has 'people_schema' => (is => 'rw', isa => 'CXGN::People::Schema', required=>1);

=head2 project_id()

=cut

#has 'project_id' => (is => 'rw', isa => 'Int');

=head2 name()

=cut

#has 'name' => (is => 'rw', isa => 'Str');

=head2 description()

=cut

##has 'description' => (is => 'rw', isa => 'Str', default => "No description");

#=head2 accession_ids()
#
#=cut
#has 'accession_ids' => (is => 'rw', isa => 'Maybe[ArrayRef]', lazy => 1, builder => '_load_accession_ids');

=head2 accession_names()

=cut

has 'accession_names' => (is => 'rw', isa => 'Maybe[ArrayRef]', lazy => 1, builder => '_load_accession_names'); #maybe for debugging only

=head2 data_hash()

=cut

has 'data_hash' => (is => 'rw', isa => 'HashRef');

=head2 design()

=cut

has 'design' => (is => 'rw', isa => 'Ref', lazy => 1, builder => '_load_design');

=head2 traits()

=cut

has 'traits' => (is => 'rw', isa => 'ArrayRef', builder => '_load_traits');

=head2 nd_geolocation_id()

=cut

has 'nd_geolocation_id' => (is => 'rw', isa=> 'Maybe[Int]');

=head2 user_id()

=cut

has 'user_id' => (is => 'rw', isa => 'Int');

=head2 metadata()

CXGN::Analysis::AnalysisMetadata object.

=cut

has 'metadata' => (isa => 'Maybe[CXGN::Analysis::AnalysisMetadata]', is => 'rw');

#sub BUILDARGS {
#    my $self = shift;
#    my $args = shift;
#    $args->{trial_id} = $args->{project_id};
#}

#has 'project' => (isa => 'CXGN::Project', is => 'rw');

=head2 year()

year the analysis was done.

=cut

#has 'year' => (isa => 'Str', is => 'rw');




sub BUILD {
    my $self = shift;
    my $args = shift;

    print STDERR "BUILD CXGN::Analysis...\n";
    my $metadata;

    if ($self->get_trial_id()) {
	
	# with a project ID, we load all associated metadata
	# first, get project row and retrieve name
	#

#	my $project = CXGN::Project->new( { bcs_schema => $args->{bcs_schema}, trial_id => $args->{project_id}});
	
#	if (! $project) { die "No analysis with this project_id ($args->{project_id}) exists"; }

#	$self->project($project);
	
#	$self->name($project->get_name());
#	$self->description($project->get_description());

	print STDERR "LOcation id retrieved : = ".$self->get_location()->[0]."\n";
	$self->nd_geolocation_id($self->get_location()->[0]);

#	$self->year($project->get_year());
	
	# retrieve associated metadata from projectprop
	#
	my $metadata_json_id = SGN::Model::Cvterm->get_cvterm_row($args->{bcs_schema}, 'analysis_metadata_json', 'project_property')->cvterm_id();
	
	my $rs = $self->bcs_schema()->resultset("Project::Projectprop")->search( { project_id => $self->get_trial_id(), type_id => $metadata_json_id });

	#  create the  metadata object
	#
	my $stockprop_id;
	if ($rs->count() > 0) { 
	    $stockprop_id = $rs->first()->projectprop_id();
	}

	print STDERR "Create AnalysisMetadata object...\n";
	$metadata = CXGN::Analysis::AnalysisMetadata->new( { bcs_schema => $args->{bcs_schema}, prop_id => $stockprop_id });

	$self->metadata($metadata);

	$stockprop_id = $metadata->prop_id();

	# Note: lazy load the design (too slow)...
	
	print STDERR "prop_id is $stockprop_id...\n";
	
	# if object doesn't have metadata in the database, create an 
	# empty object
	#
	if (! defined($stockprop_id)) {
	    print STDERR "project_id = ".$self->get_trial_id()." with stockprop_id = undefined...storing metadata...\n";
	    $metadata->parent_id($self->get_trial_id());
	    $metadata->store();
	}
    }
    else {

	# otherwise create an empty project object with an empty metadata object...
	#
	# print STDERR "Create an empty metadata object with parent_id ".$self->project_id()."...\n";
	# $metadata = CXGN::Analysis::AnalysisMetadata->new ( { bcs_schema => $args->{bcs_schema} });
	# $metadata->parent_id($self->project_id());
	die "need a project id...";
    }
    $self->metadata($metadata);
}

=head2 retrieve_analyses_by_user

 Usage:        my @analyses = CXGN::Analysis->retrieve_analyses_by_user($schema, $user_id);
 Desc:         Class function to retrieve all analyses by user_id
 Ret:          a list of listrefs with analysis data
 Args:         $schema - a BCS schema object, $user_id - the numeric id of a user
 Side Effects:
 Example:

=cut

sub retrieve_analyses_by_user {
    my $class = shift;
    my $bcs_schema = shift;
    my $people_schema = shift;
    my $user_id = shift;

    my $project_sp_person_term = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'project_sp_person_id', 'project_property');
    my $user_info_type_id = $project_sp_person_term->cvterm_id();

    my $project_analysis_term = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'analysis_metadata_json', 'project_property');
    my $analysis_info_type_id = $project_analysis_term ->cvterm_id();
    
    my $q = "SELECT userinfo.project_id FROM projectprop AS userinfo JOIN projectprop AS analysisinfo on (userinfo.project_id=analysisinfo.project_id) WHERE userinfo.type_id=? AND analysisinfo.type_id=? AND userinfo.value=?";

    my $h = $bcs_schema->storage()->dbh()->prepare($q);
    $h->execute($user_info_type_id, $analysis_info_type_id, $user_id);

    my @analyses = ();
    while (my ($project_id) = $h->fetchrow_array()) {
	print STDERR "Instantiating analysis project for project ID $project_id...\n";
	push @analyses, CXGN::Analysis->new( { bcs_schema => $bcs_schema, people_schema => $people_schema, trial_id=> $project_id });
    }

    return @analyses;
}    

sub create_and_store_analysis_design {
    my $self = shift;

    print STDERR "CREATE AND STORE ANALYSIS DESIGN...\n";
    
    if (!$self->user_id()) {
	die "Need an sp_person_id to store an analysis.";
    }
    if (!$self->get_description()) {
	die "Need a description to store an analysis.";
    }

    if (!$self->get_name()) {
	die "Need a name to store an analysis.";
    }

    print STDERR "Year is : ".$self->year()."\n";
    if (!$self->year()) {
	my $dt = DateTime->now();
	my $year = $dt->year();
	print STDERR "Year: $year\n";
	print STDERR "No year provided. Using current year ($year).\n";
	$self->year($year);
    }

    print STDERR "Retrieving geolocation entry...\n";
    my $calculation_location_id = $self->bcs_schema()->resultset("NaturalDiversity::NdGeolocation")->find( { description => "[Computation]" } )->nd_geolocation_id();

    $self->nd_geolocation_id($calculation_location_id);
    print STDERR "Using nd_geolocation with id $calculation_location_id...\n";
    print STDERR "Create analysis entry in project table...\n";

    my $check_name = $self->bcs_schema()
	->resultset("Project::Project")
	->find( { name => $self->name() });

#    if ($check_name) {
#	die "An analysis with name ".$self->name()." already exists in the database. Please choose another name.";
#	return;
#    }

    # create project row
    #
    #  my $analysis = $self->bcs_schema()
    # 	->resultset("Project::Project")
    # 	->create(
    # 	{
    # 	    name => $self->name(),
    # 	    description => $self->description(),
    # 	});

    # my $analysis_id = $analysis->project_id();

#    print STDERR "Created analysis id $analysis_id.\n";

    # store nd_location_id
    #
    $self->set_location($calculation_location_id);
    
    # store user info
    #
    print STDERR "Storing user info...\n";
    my $project_sp_person_term = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema(), 'project_sp_person_id', 'project_property');
    my $row = $self->bcs_schema()->resultset("Project::Projectprop")->create( 
	{
	    project_id => $self->get_trial_id(), 
	    type_id=>$project_sp_person_term->cvterm_id(), 
	    value=>$self->user_id(), 
	});

    print STDERR "Created projectprop ".$row->projectprop_id()." for user info.\n";
    
    # store project type info as projectprop, store metadata in value
    #
    print STDERR "Store analysis type...\n";
    my $analysis_project_term = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema(), 'analysis_project', 'project_property');


    # Store metadata
    #
    my $time = DateTime->now();
    if (!$self->metadata()) {
	print STDERR "Storing metadata...\n";
	my $metadata = CXGN::Analysis::AnalysisMetadata->new({ bcs_schema => $self->bcs_schema() });
	print STDERR "Analysis ID = ".$self->get_trial_id()."\n";
	$metadata->parent_id($self->get_trial_id());
	$self->metadata( $metadata );
	$self->metadata()->create_timestamp($time->ymd()." ".$time->hms());
    }

    # store dataset info, if available. Copy the actual dataset json, 
    # so that dataset  info is frozen and does not reflect future 
    # changes.
    #
    if ($self->metadata()->dataset_id()) {
	print STDERR "Retrieving data for dataset_id ".$self->metadata->dataset_id()."\n";
	my $ds = CXGN::Dataset->new( { schema => $self->bcs_schema(), people_schema => $self->people_schema(), sp_dataset_id => $self->metadata()->dataset_id() });
	my $data = $ds->to_hashref();
	#print STDERR "DATA: $data\n";
	$self->metadata()->dataset_data(JSON::Any->encode($data));
	
    }
    else {
	print STDERR "No dataset_id provided...\n";
    }

    $self->metadata()->parent_id($self->get_trial_id());
    $self->metadata()->modified_timestamp($time->ymd()." ".$time->hms());
    $self->metadata()->store();
    
    # Create `trial design` for analysis...
    #
    print STDERR "Create a new analysis design...\n";
    my $td = CXGN::Trial::TrialDesign->new();

#    my $accession_names;
    # print STDERR "Retrieving accession names...\n";
    # print STDERR "Using ids ".join(", ",@{$self->accession_ids()})."\n";
    # my $tf = CXGN::List::Transform->new();
    # my $transform_name = $tf->can_transform("accession_ids, "accessions");
    # print STDERR "Transform name = $transform_name\n";
    # if ($transform_name) {
    # 	$accession_names = $tf->transform($self->bcs_schema(), $transform_name, $self->accession_ids());
    # 	print STDERR "Accession names now: ".join(", ", $accession_names)."\n";
    # 	if ($accession_names->{missing}) {
    # 	    die "There are accessions in the analysis that cannot be found in the database.";
    # 	}
    # 	$self->accession_names($accession_names->{transform});
    # }
    
    
    $td->set_trial_name($self->name());
    $td->set_stock_list($self->accession_names());
    $td->set_design_type("Analysis");
    
    my $design;
    if ($td->calculate_design()) {
  	print STDERR "Design calculated :-) ...\n";
	$design = $td->get_design();
	$self->design($design);
    }
    else {
	die "An error occurred creating the analysis design.";
    }

    print STDERR "Store design...\n";
    # my $design_store = CXGN::Trial::TrialDesignStore->new(
    # 	{ 
    # 	    bcs_schema => $self->bcs_schema(),
    # 	    trial_id => $analysis_id,
    # 	    trial_name => $self->name(),
    # 	    nd_geolocation_id => $self->nd_geolocation_id(),
    # 	    design_type => 'Analysis', 
    # 	    design => $design,
    # 	    is_genotyping => 0,
    # 	    is_analysis => 1,
    # 	    operator => "janedoe",
    # 	}); 

    my $analysis_experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'analysis_experiment', 'experiment_type')->cvterm_id(); 
    
    my $trial_create = CXGN::Trial::TrialCreate->new({
	trial_id => $self->get_trial_id(),
        chado_schema => $self->bcs_schema(),
        dbh => $self->bcs_schema()->storage->dbh(),
        operator => "computer",
        design => $design,
	design_type => $analysis_experiment_type_id,
	program => 'test',
	trial_year => $self->year(),
	trial_description => $self->description(),
	trial_location => '[Computation]',
        trial_name => $self->name(),
	trial_type => $analysis_experiment_type_id,
	is_analysis => 1,
#        field_size => $field_size, #(ha)
#        plot_width => $plot_width, #(m)
#        plot_length => $plot_length, #(m)
#        field_trial_is_planned_to_cross => 'yes', #yes or no
#        field_trial_is_planned_to_be_genotyped => 'no', #yes or no
#        field_trial_from_field_trial => ['source_trial_id1', 'source_trial_id2'],
#        genotyping_trial_from_field_trial => ['genotyping_trial_id1'],
#        crossing_trial_from_field_trial => ['crossing_trial_id1']
    });

    
#    my $validate_error = $trial_create->validate_design(); 
#    my $store_error; 
#    if ($validate_error) {
#	print STDERR "VALIDATE ERROR! "; #.Dumper($validate_error)."\n";
#    } 
#    else {
##	print STDERR "Valiation successful. Storing...\n";
#	try { $store_error = $design_store->store() }
#	catch { $store_error = $_ };
#    } 
#    if ($store_error) { 
#	die "ERROR SAVING TRIAL!: $store_error\n"; 
#    }

    try { 
	$trial_create->save_trial();
    }
    catch {
	die "Error saving trial: $_";
    };
    
    
    print STDERR "Done with design create & store.\n";

    return $self->get_trial_id();
}


# store analysis values is a separate call and has to be called after
# storing the design

sub store_analysis_values {
    my $self = shift;
    my $metadata_schema = shift;
    my $phenome_schema = shift;


             my $values = shift;
    my $plots = shift;
    my $traits = shift;
    my $operator = shift;
    my $basepath = shift;
    my $dbhost = shift;
    my $dbname = shift;
    my $dbuser = shift;
    my $dbpass = shift;
    my $tempfile_path = shift;

    print STDERR "Storing analysis values...\n";
    
    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();
    my %phenotype_metadata;
    $phenotype_metadata{'archived_file'} = 'none';
    $phenotype_metadata{'archived_file_type'} = 'analysis_values';
    $phenotype_metadata{'operator'} = $operator;
    $phenotype_metadata{'date'} = $timestamp;
    
    my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new(
	{
	    bcs_schema => $self->bcs_schema(),
	    basepath => $tempfile_path,
	    dbhost => $dbhost,
	    dbname => $dbname,
	    dbuser => $dbuser,
	    dbpass => $dbpass,
	    temp_file_nd_experiment_id => '/tmp/temp_file_nd_experiment_id',
	    metadata_schema => $metadata_schema,
	    phenome_schema => $phenome_schema,
	    user_id => $self->user_id(),
	    stock_list => $plots,
	    trait_list => $traits, 
	    values_hash => $values,
	    has_timestamps => 0,
	    overwrite_values => 0,
	    metadata_hash => \%phenotype_metadata,
	});
    
    my ($verified_warning, $verified_error) = $store_phenotypes->verify();
    
    if ($verified_warning) {
	warn $verified_warning;
    }
    if ($verified_error) {
	die $verified_error;
    }
    
    my ($stored_phenotype_error, $stored_phenotype_success) = $store_phenotypes->store();

    if ($stored_phenotype_error) {
	die "An error occurred storing the phenotypes: $stored_phenotype_error\n";
    }
    
}

sub _load_design {
    my $self = shift;

    # Load the design
    #
    my $design = CXGN::Trial::TrialLayout->new( { schema => $self->bcs_schema(), trial_id => $self->get_trial_id(), experiment_type=> 'analysis_experiment'} );

    print STDERR "_load_design: design = ".Dumper($design->get_design);

    #print STDERR "ERROR IN LAYOUT: ".Dumper($error)."\n";
    #print STDERR "READ DESIGN: ".Dumper($design->get_design());
    return $design;
    
 
}

sub get_phenotype_matrix {
    my $self = shift;
    
    my $phenotypes_search = CXGN::Phenotypes::PhenotypeMatrix->new(
	bcs_schema=>$self->bcs_schema(),
	search_type => "Native",
	data_level => "analysis_instance",
	experiment_type => "analysis_experiment",
	trial_list=> [ $self->get_trial_id() ],
	); 
    
    my @data = $phenotypes_search->get_phenotype_matrix();
    return \@data;
}

sub _load_accession_names {
    my $self = shift;

    my $design = $self->design();
    #print STDERR "Design = ".Dumper($design);
    
    my @accessions = $design->get_accession_names();
    print STDERR "ACCESSIONS: ". Dumper(\@accessions);
    # get the accessions from the design (not the dataset!)
    #
    return $self->design()->get_accession_names();
}

sub _load_traits {
    my $self = shift;

    my $phenotypes = $self->get_phenotype_matrix();

    my $header = $phenotypes->[0];

    my $traits = [ @$header[30..scalar(@$header)-1] ];

    $self->traits($traits);
    return $traits;
}
	

    

#sub _load_accession_ids {
#    my $self = shift;
#    my $design = $self->design();

#    return $self->design()->get_accession_ids();

#}

1;

#__PACKAGE__->meta->make_immutable;
