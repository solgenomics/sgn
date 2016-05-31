package CXGN::Trial::TrialCreate;

=head1 NAME

CXGN::Trial::TrialCreate - Module to create a trial based on a specified design.


=head1 USAGE

 my $trial_create = CXGN::Trial::TrialCreate->new({schema => $schema} );


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
use CXGN::BreedersToolbox::Projects;
use CXGN::People::Person;
use CXGN::Trial;
use SGN::Model::Cvterm;

has 'chado_schema' => (
		 is       => 'rw',
		 isa      => 'DBIx::Class::Schema',
		 predicate => 'has_chado_schema',
		 required => 1,
		);
has 'phenome_schema' => (
		 is       => 'rw',
		 isa      => 'DBIx::Class::Schema',
		 predicate => 'has_phenome_schema',
		 required => 1,
		);
has 'metadata_schema' => (
		 is       => 'rw',
		 isa      => 'DBIx::Class::Schema',
		 predicate => 'has_metadata_schema',
		 required => 0,
			 );

has 'dbh' => (is  => 'rw',predicate => 'has_dbh', required => 1,);
has 'user_name' => (isa => 'Str', is => 'rw', predicate => 'has_user_name', required => 1,);
#has 'location' => (isa =>'Str', is => 'rw', predicate => 'has_location', required => 1,);
has 'program' => (isa =>'Str', is => 'rw', predicate => 'has_program', required => 1,);
has 'trial_year' => (isa => 'Str', is => 'rw', predicate => 'has_trial_year', required => 1,);
has 'trial_description' => (isa => 'Str', is => 'rw', predicate => 'has_trial_description', required => 1,);
has 'trial_location' => (isa => 'Str', is => 'rw', predicate => 'has_trial_location', required => 1,);
has 'design_type' => (isa => 'Str', is => 'rw', predicate => 'has_design_type', required => 1);
has 'design' => (isa => 'HashRef[HashRef[Str]]', is => 'rw', predicate => 'has_design', required => 1);
#has 'breeding_program_id' => (isa => 'Int', is => 'rw', predicate => 'has_breeding_program_id', required => 1);
has 'trial_name' => (isa => 'Str', is => 'rw', predicate => 'has_trial_name', required => 0,);
has 'is_genotyping' => (isa => 'Bool', is => 'rw', required => 0, default => 0, );
has 'genotyping_user_id' => (isa => 'Str', is => 'rw');

has 'genotyping_project_name' => (isa => 'Str', is => 'rw');

# sub get_trial_name {
#   my $self = shift;
#   my $trial_name;
#   if ($self->has_trial_year() && $self->has_trial_location()) {
#     $trial_name = "Trial ".$self->get_trial_location()." ".$self->get_trial_year();
#   }
#   return $trial_name;
# }

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
  my $project_lookup =  CXGN::BreedersToolbox::Projects->new(schema => $self->get_chado_schema);
  my $breeding_program_ref = $project_lookup->get_breeding_program_by_name($self->get_program());
  if (!$breeding_program_ref ) {
      print STDERR "UNDEF breeding program " . $self->get_program . "\n\n";
      return ;
  }
  my $breeding_program_id = $breeding_program_ref->project_id();
  print STDERR "get_breeding_program _id returning $breeding_program_id";
  return $breeding_program_id;
}


sub save_trial {
    print STDERR "Check 4.1: ".localtime();
    print STDERR "**trying to save trial \n\n";
    my $self = shift;
  my $chado_schema = $self->get_chado_schema();
  my %design = %{$self->get_design()};

  if ($self->trial_name_already_exists()) {
      print STDERR "Can't create trial: Trial name already exists\n";
      die "trial name already exists" ;
  }
    
  if (!$self->get_breeding_program_id()) {
      print STDERR "Can't create trial: Breeding program does not exist\n"; 
      die "No breeding program id";
      #return ( error => "no breeding program id" );
  }

    print STDERR "Check 4.2: ".localtime();

  #lookup user by name
  my $user_name = $self->get_user_name();
  my $dbh = $self->get_dbh();
  my $owner_sp_person_id;
  $owner_sp_person_id = CXGN::People::Person->get_person_by_username($dbh, $user_name); #add person id as an option.
  if (!$owner_sp_person_id) {
      print STDERR "Can't create trial: User/owner not found\n";
      die "no owner $user_name" ;
  }

    print STDERR "Check 4.3: ".localtime();

  my $geolocation;
  my $geolocation_lookup = CXGN::Location::LocationLookup->new(schema => $chado_schema);
  $geolocation_lookup->set_location_name($self->get_trial_location());
  $geolocation = $geolocation_lookup->get_geolocation();
  if (!$geolocation) {
      print STDERR "Can't create trial: Location not found\n";
      die "no geolocation" ;
  }

    print STDERR "Check 4.4: ".localtime();

  my $program = CXGN::BreedersToolbox::Projects->new( { schema=> $chado_schema } );

  my $field_layout_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'field_layout', 'experiment_type');
  my $accession_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'accession', 'stock_type');
  my $plot_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plot', 'stock_type');
  my $plot_of = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'plot_of', 'stock_relationship');
  my $sample_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'tissue_sample', 'stock_type');
  my $sample_of = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'tissue_sample_of', 'stock_relationship');
  my $genotyping_layout_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'genotyping_layout', 'experiment_type');

  my $project = $chado_schema->resultset('Project::Project')
    ->create({
	      name => $self->get_trial_name(),
	      description => $self->get_trial_description(),
	     });

  my $field_layout_experiment = $chado_schema->resultset('NaturalDiversity::NdExperiment')
      ->create({
		nd_geolocation_id => $geolocation->nd_geolocation_id(),
		type_id => $field_layout_cvterm->cvterm_id(),
		});

  my $genotyping_layout_experiment = $chado_schema->resultset('NaturalDiversity::NdExperiment')
      ->create({
		nd_geolocation_id => $geolocation->nd_geolocation_id(),
		type_id => $genotyping_layout_cvterm->cvterm_id(),
		});

    print STDERR "Check 4.5: ".localtime();

  #modify cvterms used to create the trial when it is a genotyping trial
  if ($self->get_is_genotyping()){
      $field_layout_cvterm = $genotyping_layout_cvterm;
      $field_layout_experiment = $genotyping_layout_experiment;
      $plot_cvterm = $sample_cvterm;
      $plot_of = $sample_of;

      #print STDERR "Storing user_id and project_name provided by the IGD spreadksheet for later recovery in the spreadsheet download... ".(join ",", ($self->get_genotyping_user_id(), $self->get_genotyping_project_name()))."\n";

      $genotyping_layout_experiment->create_nd_experimentprops( 
	  { 
	      'genotyping_user_id' => $self->get_genotyping_user_id(),
	      'genotyping_project_name' => $self->get_genotyping_project_name(),
	  },
	  { autocreate => 1});
  }
 
    print STDERR "Check 4.6: ".localtime();

  my $t = CXGN::Trial->new( { bcs_schema => $chado_schema, trial_id => $project->project_id() } );
  $t->add_location($geolocation->nd_geolocation_id()); # set location also as a project prop

  #link to the project
  $field_layout_experiment->find_or_create_related('nd_experiment_projects',{project_id => $project->project_id()});

    print STDERR "Check 4.7: ".localtime();

  $project->create_projectprops( { 'project year' => $self->get_trial_year(),'design' => $self->get_design_type()}, {autocreate=>1});

  # instead of 
  my $rs = $chado_schema->resultset('Stock::Stock')->search(
	{ 'me.is_obsolete' => { '!=' => 't' } },
        { join => [ 'stock_relationship_objects', 'nd_experiment_stocks' ],
	 '+select'=> ['me.stock_id', 'me.uniquename', 'me.organism_id', 'stock_relationship_objects.type_id', 'stock_relationship_objects.subject_id', 'nd_experiment_stocks.nd_experiment_id', 'nd_experiment_stocks.type_id'], 
	 '+as'=> ['stock_id', 'uniquename', 'organism_id', 'stock_relationship_type_id', 'stock_relationship_subject_id', 'stock_experiment_id', 'stock_experiment_type_id']
	}
  );

  my %stock_data;
  my %stock_relationship_data;
  my %stock_experiment_data;
  while (my $s = $rs->next()) { 
     $stock_data{$s->get_column('uniquename')} = [$s->get_column('stock_id'), $s->get_column('organism_id') ];
     if ($s->get_column('stock_relationship_type_id') && $s->get_column('stock_relationship_subject_id') ) {
	 $stock_relationship_data{$s->get_column('stock_id'), $s->get_column('stock_relationship_type_id'), $s->get_column('stock_relationship_subject_id') } = 1;
     }
     if ($s->get_column('stock_experiment_id') && $s->get_column('stock_experiment_type_id') ) {
	 $stock_experiment_data{$s->get_column('stock_id'), $s->get_column('stock_experiment_id'), $s->get_column('stock_experiment_type_id')} = 1;
     }
  }
  
    my $stock_id_checked;
    my $organism_id_checked;

  foreach my $key (sort { $a cmp $b} keys %design) {
      
      print STDERR "Check 01: ".localtime();

    my $plot_name = $design{$key}->{plot_name};
    my $plot_number = $design{$key}->{plot_number};
    my $stock_name = $design{$key}->{stock_name};
    my $block_number;
    my $well;
    my $plate;

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

    if ($design{$key}->{well}) {
	$well = $design{$key}->{well};
    }
    if ($design{$key}->{plate}) {
	$plate = $design{$key}->{plate};
    }

    my $is_a_control = $design{$key}->{is_a_control};
    my $plot;

    #check if stock_name exists in database by checking if stock_name is key in %stock_data. if it is not, then check if it exists as a synonym in the database. 
    if ($stock_data{$stock_name}) {
	$stock_id_checked = $stock_data{$stock_name}[0];
	$organism_id_checked = $stock_data{$stock_name}[1];
    } else {
	my $parent_stock;
	my $stock_lookup = CXGN::Stock::StockLookup->new(schema => $chado_schema);
	$stock_lookup->set_stock_name($stock_name);
	$parent_stock = $stock_lookup->get_stock();

	if (!$parent_stock) {
	    die ("Error while saving trial layout: no stocks found matching $stock_name");
	}

	$stock_id_checked = $parent_stock->stock_id();
	$organism_id_checked = $parent_stock->organism_id();
    }

      print STDERR "Check 02: ".localtime();

    #create the plot
    $plot = $chado_schema->resultset("Stock::Stock")
      ->find_or_create({
			organism_id => $organism_id_checked,
			name       => $plot_name,
			uniquename => $plot_name,
			type_id => $plot_cvterm->cvterm_id,
		       } );
    if ($rep_number) {
      $plot->create_stockprops({'replicate' => $rep_number}, {autocreate => 1} );
    }
    if ($block_number) {
      $plot->create_stockprops({'block' => $block_number}, {autocreate => 1} );
    }
    if ($plot_number) {
      $plot->create_stockprops({'plot number' => $plot_number}, {autocreate => 1});
    }
    else {
      $plot->create_stockprops({'plot number' => $key}, {autocreate => 1});
    }

    if ($is_a_control) {
      $plot->create_stockprops({'is a control' => $is_a_control}, {autocreate => 1} );
    }

    if ($design{$key}->{'range_number'}) {
      $plot->create_stockprops({'range' => $key}, {autocreate => 1});
    }

    if ($well) {
	$plot->create_stockprops({'well' => $well}, {autocreate => 1});
    }

    if ($plate) {
	$plot->create_stockprops({'plate' => $plate}, {autocreate => 1});
    }

      print STDERR "Check 03: ".localtime();


    #create the stock_relationship of the accession with the plot, if it does not exist already
    if (!$stock_relationship_data{$stock_id_checked, $plot_of->cvterm_id(), $plot->stock_id()} ) {
	my $parent_stock = $chado_schema->resultset("Stock::StockRelationship")->create({  
	    object_id => $stock_id_checked,
	    type_id => $plot_of->cvterm_id(),
	    subject_id => $plot->stock_id()
	});
    }

    #link the experiment to the plot, if it is not already
    if (!$stock_experiment_data{$plot->stock_id(), $field_layout_experiment->nd_experiment_id(), $field_layout_cvterm->cvterm_id()} ) {
	my $stock_experiment_link = $chado_schema->resultset("NaturalDiversity::NdExperimentStock")->create({ 
	    nd_experiment_id => $field_layout_experiment->nd_experiment_id(),
	    type_id => $field_layout_cvterm->cvterm_id(),
	    stock_id => $plot->stock_id(),
        });
    }

      print STDERR "Check 04: ".localtime();
  }

    print STDERR "Check 4.8: ".localtime();

  $program->associate_breeding_program_with_trial($self->get_breeding_program_id, $project->project_id);

    print STDERR "Check 4.9: ".localtime();

  return ( trial_id => $project->project_id );

}





#######
1;
#######
