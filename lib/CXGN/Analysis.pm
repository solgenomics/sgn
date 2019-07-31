
package CXGN::Analysis;

use Moose;
use Data::Dumper;
use CXGN::Trial::TrialDesign;
use CXGN::Trial::TrialDesignStore;
use CXGN::Phenotypes::StorePhenotypes;
use CXGN::Dataset;
use DateTime;

BEGIN { extends 'CXGN::Project' };

#has 'bcs_schema' => (is => 'rw', isa => 'Ref' );

has 'people_schema' => (is => 'rw', isa => 'CXGN::People::Schema');

has 'name' => (is => 'rw', isa => 'Str');

has 'description' => (is => 'rw', isa => 'Str', default => "No description");

has 'dataset_id' => (is => 'rw', isa => 'Int');

has 'dataset_info' => (is => 'rw', isa => 'ArrayRef');

has 'accessions' => (is => 'rw', isa => 'ArrayRef');

has 'data_hash' => (is => 'rw', isa => 'HashRef');

has 'design' => (is => 'rw', isa => 'Ref');

has 'nd_geolocation_id' => (is => 'rw', isa=> 'Int');

has 'sp_person_id' => (is => 'rw', isa => 'Int');

has 'user_id' => (is => 'rw', isa => 'Int');

sub BUILD {
    my $self = shift;
    my $args = shift;

    if ($args->{project_id}) {
	# load analysis from db

    }
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
    my $schema = shift;
    my $user_id = shift;

    my $project_sp_person_term = SGN::Model::Cvterm->get_cvterm_row($schema, 'project_sp_person_id', 'project_property');
    my $user_info_type_id = $project_sp_person_term->cvterm_id();

    my $project_analysis_term = SGN::Model::Cvterm->get_cvterm_row($schema, 'analysis_project', 'project_property');
    my $analysis_info_type_id = $project_analysis_term ->cvterm_id();
    
    my $q = "SELECT userinfo.project_id FROM projectprop AS userinfo JOIN projectprop AS analysisinfo on (userinfo.project_id=analysisinfo.project_id) WHERE userinfo.type_id=? AND analysisinfo.type_id=? AND userinfo.value=?";

    my $h = $schema->dbc->dbh->prepare($q);
    $h->execute($user_info_type_id, $analysis_info_type_id, $user_id);

    my @analyses = ();
    while (my ($project_id) = $h->fetchrow_array()) {
	push @analyses, CXGN::Analysis->new( { bcs_schema => $schema, trial_id=> $project_id });
    }

    return @analyses;
}    

sub create_and_store_analysis_design {
    my $self = shift;

    if (!$self->sp_person_id()) {
	die "Need an sp_person_id to store an analysis.";
    }
    if (!$self->description()) {
	die "Need a description to store an analysis.";
    }

    if (!$self->name()) {
	die "Need a name to store an analysis.";
    }
    
    print STDERR "Create analysis entry in project table...\n";
    my $analysis = $self->bcs_schema()
	->resultset("Project::Project")
	->create( 
	{ 
	    name => $self->name(),
	    description => $self->description(),
	});
    
    my $analysis_id = $analysis->project_id();

    print STDERR "Create a new analysis design...\n";
    my $td = CXGN::Trial::TrialDesign->new();

    $td->set_trial_name($self->name());
    $td->set_stock_list($self->accessions());
    $td->set_design_type("Analysis");

    print STDERR "Calculate design...\n";
    my $design;
    if ($td->calculate_design()) {
	$design = $td->get_design();
	$self->design($design);
    }
    else {
	die "An error occurred creating the analysis design.";
    }

    print STDERR "Store design...\n";
    my $design_store = CXGN::Trial::TrialDesignStore->new(
	{ 
	    bcs_schema => $self->bcs_schema(),
	    trial_id => $analysis_id,
	    trial_name => $self->name(),
	    nd_geolocation_id => $self->nd_geolocation_id(),
	    design_type => 'Analysis', 
	    design => $design,
	    is_genotyping => 0, 
	    operator => "janedoe",
	}); 
    
    my $validate_error = $design_store->validate_design(); 
    my $store_error; 
    if ($validate_error) {
	print STDERR "VALIDATE ERROR: $validate_error\n"; } 
    else { 
	try { $store_error = $design_store->store(); } 
	catch { $store_error = $_; }; } 
    if ($store_error) { 
	die "ERROR SAVING TRIAL!: $store_error\n"; 
    }

    # store user info
    #
    my $project_sp_person_term = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema(), 'project_sp_person_id', 'project_property');
    my $row = $self->bcs_schema()->resultset("Project::Projectprop")->create( 
	{
	    project_id => $analysis_id, 
	    type_id=>$project_sp_person_term->cvterm_id(), 
	    value=>$self->user_id(), 
	});


    # store project type info as projectprop, store metadata in value
    #
    my $analysis_project_term = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema(), 'analysis_project', 'project_property');
    
    # store dataset info. Copy the actual dataset json, so that dataset 
    # info is frozen and does not reflect future changes.
    #
    my $ds = CXGN::Dataset->new( { people_schema => $self->people_schema(), dataset_id=> $self->dataset_id() });

    $row = $self->bcs_schema()->resultset("Project::Projectprop")->create( 
	{
	    project_id => $analysis_id, 
	    type_id => $analysis_project_term->cvterm_id(), 
	    value => { 
		original_dataset_id => $self->dataset_id(), 
		dataset_json => $ds->data(), 
	    },
	});

    
    print STDERR Dumper($design);
    print STDERR "Done with design create & store.\n";
}

sub store_analysis_values {
    my $self = shift;
    my $metadata_schema = shift;
    my $phenome_schema = shift;
    my $values = shift;
    my $plots = shift;
    my $traits = shift;
    my $traits = shift;
    my $operator = shift;
    my $basepath = shift;
    my $dbhost = shift;
    my $dbname = shift;
    my $dbuser = shift;
    my $dbpass = shift;
    my $tempfile_path = shift;

    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();
    my %phenotype_metadata;
    $phenotype_metadata{'archived_file'} = 'none';
    $phenotype_metadata{'archived_file_type'} = 'analysis_values';
    $phenotype_metadata{'operator'} = $operator;
    $phenotype_metadata{'date'} = $timestamp;
    
    my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new(
	{
        basepath=>$basepath,
        dbhost=>$dbhost,
        dbname=>$dbname,
        dbuser=>$dbuser,
        dbpass=>$dbpass,
        temp_file_nd_experiment_id=>$tempfile_path,
	    bcs_schema => $self->bcs_schema(),
	    metadata_schema => $metadata_schema,
	    phenome_schema => $phenome_schema,
	    user_id => $self->user_id(),
	    stock_list => $plots,
	    trait_list => $traits, 
	    values_hash => $values,
	    has_timestamps => 0,
	    overwrite_values => 0,
	    metadata_hash => \%phenotype_metadata
	});
    
    my ($verified_warning, $verified_error) = $store_phenotypes->verify();
    
    if ($verified_warning) {
	warn $verified_warning;
    }
    if ($verified_error) {
	die $verified_error;
    }
    
    my ($stored_phenotype_error, $stored_phenotype_success) = $store_phenotypes->store();
    
}

1;
