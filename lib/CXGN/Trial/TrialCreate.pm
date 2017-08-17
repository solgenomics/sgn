package CXGN::Trial::TrialCreate;

=head1 NAME

CXGN::Trial::TrialCreate - Module to create an entirely new trial based on a specified design. For field_layout experiments and genotyping_layout experiments. 

Will do the following:
1) Create a new project entry in Project table based on trial and description supplied to object. If there is a project with the name already saved, it will return an error and do nothing.
2) Create a single new experiment entry in nd_experiment. If is_genotyping is supplied, this will be type = genotyping_layout. Otherwise, this will be type = field_layout.
3) Will associate the location to the project through the nd_experiment as well as through a projectprop. Location lookup happens based on location name that is provided. Assumes locations already stored in database.
4) Will associate the trial to its breeding program. Lookup is by breeding program name that is provided and assumes bp already exists in database. Will return an error if breeding program name not found.
5) Creates a single nd_experiment_project entry, linking project to nd_experiment.
6) Creates a year and design projectprop. Also a project_type projectprop if provided.
7) Calls the CXGN::Trial::TrialDesignStore object to handle storing stocks (plots and plants) and stockprops (rep, block, etc)

=head1 USAGE

 FOR FIELD PHENOTYPING TRIALS:
 my $trial_create = CXGN::Trial::TrialCreate->new({
	chado_schema => $c->dbic_schema("Bio::Chado::Schema"),
	dbh => $c->dbc->dbh(),
	user_name => $user_name, #not implemented,
	design_type => 'CRD',
	design => $design_hash,
	program => $breeding_program->name(),
	trial_year => $year,
	trial_description => $project_description,
	trial_location => $location->name(),
	trial_name => $trial_name,
	trial_type => $trialtype
 });
 try {
   $trial_create->save_trial();
 } catch {
   print STDERR "ERROR SAVING TRIAL!\n";
 };

 FOR GENOTYPING TRIALS:
 my $ct = CXGN::Trial::TrialCreate->new( {
	chado_schema => $c->dbic_schema("Bio::Chado::Schema"),
	dbh => $c->dbc->dbh(),
	user_name => $c->user()->get_object()->get_username(), #not implemented
	trial_year => $year,
	trial_location => $location->name(),
	program => $breeding_program->name(),
	trial_description => $description,
	design_type => 'genotyping_plate',
	design => $design_hash,
	trial_name => $trial_name,
	is_genotyping => 1,
	genotyping_user_id => $user_id,
	genotyping_project_name => $project_name
 });
 try {
   $ct->save_trial();
 } catch {
   print STDERR "ERROR SAVING TRIAL!\n";
 };


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
has 'program' => (isa =>'Str', is => 'rw', predicate => 'has_program', required => 1,);
has 'trial_year' => (isa => 'Str', is => 'rw', predicate => 'has_trial_year', required => 1,);
has 'trial_description' => (isa => 'Str', is => 'rw', predicate => 'has_trial_description', required => 1,);
has 'trial_location' => (isa => 'Str', is => 'rw', predicate => 'has_trial_location', required => 1,);
has 'design_type' => (isa => 'Str', is => 'rw', predicate => 'has_design_type', required => 1);
has 'design' => (isa => 'HashRef[HashRef[Str|ArrayRef]]|Undef', is => 'rw', predicate => 'has_design', required => 1);
has 'trial_name' => (isa => 'Str', is => 'rw', predicate => 'has_trial_name', required => 1);
has 'trial_type' => (isa => 'Str', is => 'rw', predicate => 'has_trial_type', required => 0);

has 'is_genotyping' => (isa => 'Bool', is => 'rw', required => 0, default => 0, );
has 'genotyping_user_id' => (isa => 'Str', is => 'rw');
has 'genotyping_project_name' => (isa => 'Str', is => 'rw');


sub trial_name_already_exists {
  my $self = shift;
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

	if ($self->trial_name_already_exists()) {
		print STDERR "Can't create trial: Trial name already exists\n";
		return ( error => "Trial not saved: Trial name already exists" );
	}

	if (!$self->get_breeding_program_id()) {
		print STDERR "Can't create trial: Breeding program does not exist\n";
		return ( error => "Trial not saved: breeding program does not exist" );
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

	my $geolocation;
	my $geolocation_lookup = CXGN::Location::LocationLookup->new(schema => $chado_schema);
	$geolocation_lookup->set_location_name($self->get_trial_location());
	$geolocation = $geolocation_lookup->get_geolocation();
	if (!$geolocation) {
		print STDERR "Can't create trial: Location not found\n";
		return ( error => "Trial not saved: location not found" );
	}

	my $project_year_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'project year', 'project_property');
	my $project_design_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'design', 'project_property');
	my $genotyping_user_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'genotyping_user_id', 'nd_experiment_property');
	my $genotyping_project_name_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'genotyping_project_name', 'nd_experiment_property');

	my $project = $chado_schema->resultset('Project::Project')
	->create({
		name => $self->get_trial_name(),
		description => $self->get_trial_description(),
	});

	my $nd_experiment_type_id;
	if (!$self->get_is_genotyping) {
		$nd_experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'field_layout', 'experiment_type')->cvterm_id();
	} else {
		$nd_experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'genotyping_layout', 'experiment_type')->cvterm_id();
	}

	my $nd_experiment = $chado_schema->resultset('NaturalDiversity::NdExperiment')
	->create({
		nd_geolocation_id => $geolocation->nd_geolocation_id(),
		type_id => $nd_experiment_type_id,
	});

	if ($self->get_is_genotyping()){
		#print STDERR "Storing user_id and project_name provided by the IGD spreadksheet for later recovery in the spreadsheet download... ".(join ",", ($self->get_genotyping_user_id(), $self->get_genotyping_project_name()))."\n";
		$nd_experiment->create_nd_experimentprops({
			$genotyping_user_cvterm->name() => $self->get_genotyping_user_id(),
			$genotyping_project_name_cvterm->name() => $self->get_genotyping_project_name(),
		});
	}

	my $t = CXGN::Trial->new({
		bcs_schema => $chado_schema,
		trial_id => $project->project_id()
	});
	$t->set_location($geolocation->nd_geolocation_id()); # set location also as a project prop
	$t->set_breeding_program($self->get_breeding_program_id);
	if ($self->get_trial_type){
		$t->set_project_type($self->get_trial_type);
	}

	#link to the project
	$nd_experiment->find_or_create_related('nd_experiment_projects',{project_id => $project->project_id()});

	$project->create_projectprops({
		$project_year_cvterm->name() => $self->get_trial_year(),
		$project_design_cvterm->name() => $self->get_design_type()
	});

	my $design_type = $self->get_design_type();
	if ($design_type eq 'greenhouse') {
		my $has_plants_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'project_has_plant_entries', 'project_property');
		$project->create_projectprops({ $has_plants_cvterm->name() => 'varies' });
	}

	my $trial_design_store = CXGN::Trial::TrialDesignStore->new({
		bcs_schema => $chado_schema,
		trial_id => $project->project_id(),
        trial_name => $self->get_trial_name(),
		nd_geolocation_id => $geolocation->nd_geolocation_id(),
        nd_experiment_id => $nd_experiment->nd_experiment_id(),
		design_type => $design_type,
		design => \%design,
		is_genotyping => $self->get_is_genotyping
	});
	my $error;
	my $validate_design_error => $trial_design_store->validate_design();
	if ($validate_design_error) {
		print STDERR "ERROR: $validate_design_error\n";
		return ( error => "Error validating trial design: $validate_design_error." );
	} else {
		try {
			$error = $trial_design_store->store();
		} catch {
			print STDERR "ERROR store: $_\n";
			$error = $_;
		};
	}
	if ($error) {
		return ( error => $error );
	}
	return ( trial_id => $project->project_id );
}





#######
1;
#######
