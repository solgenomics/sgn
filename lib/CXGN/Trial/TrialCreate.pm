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
has 'trial_year' => (isa => 'Str', is => 'rw', predicate => 'has_trial_year', clearer => 'clear_trial_year');
has 'trial_description' => (isa => 'Str', is => 'rw', predicate => 'has_trial_description', clearer => 'clear_trial_description');
has 'trial_location' => (isa => 'Str', is => 'rw', predicate => 'has_trial_location', clearer => 'clear_trial_location');
has 'user' => (isa => 'Str', is => 'rw', predicate => 'has_user', clearer => 'clear_user'); #not implemented
has 'design_type' => (isa => 'Str', is => 'rw', predicate => 'has_design_type', clearer => 'clear_design_type');
has 'stock_list' => (isa => 'ArrayRef[Str]', is => 'rw', predicate => 'has_stock_list', clearer => 'clear_stock_list'); #remove?
has 'control_list' => (isa => 'ArrayRef[Str]', is => 'rw', predicate => 'has_control_list', clearer => 'clear_control_list'); #remove?
has 'design' => (isa => 'HashRef[HashRef[Str]]', is => 'rw', predicate => 'has_design', clearer => 'clear_design');
has 'breeding_program_id' => (isa => 'Int', is => 'rw', predicate => 'has_breeding_program_id', clearer => 'clear_breeding_program_id');

sub get_trial_name {
  my $self = shift;
  my $trial_name;
  if ($self->has_trial_year() && $self->has_trial_location()) {
    $trial_name = "Trial ".$self->get_trial_location()." ".$self->get_trial_year();
  }
  return $trial_name;
}

sub trial_name_already_exists {
  my $self = shift;
  my $trial_name = $self->get_trial_name();
  my $schema = $self->get_schema();
  if($schema->resultset('Project::Project')->find({name => $trial_name})){
    return 1;
  }
  else {
    return;
  }
}

sub save_trial {
  my $self = shift;
  my $schema = $self->get_schema();
  my %design = %{$self->get_design()};

  if ($self->trial_name_already_exists()) {
    return;
  }

  my $geolocation;
  my $geolocation_lookup = CXGN::Location::LocationLookup->new(schema => $schema);
  $geolocation_lookup->set_location_name($self->get_trial_location());
  $geolocation = $geolocation_lookup->get_geolocation();
  if (!$geolocation) {
    return;
  }

  my $program = CXGN::BreedersToolbox::Projects->new( { schema=> $schema } );

  my $field_layout_cvterm = $schema->resultset('Cv::Cvterm')
    ->create_with({
		   name   => 'field layout',
		   cv     => 'experiment type',
		   db     => 'null',
		   dbxref => 'field layout',
		  });
  my $accession_cvterm = $schema->resultset("Cv::Cvterm")
    ->create_with({
		   name   => 'accession',
		   cv     => 'stock type',
		   db     => 'null',
		   dbxref => 'accession',
		  });
  my $plot_cvterm = $schema->resultset("Cv::Cvterm")
    ->create_with({
		   name   => 'plot',
		   cv     => 'stock type',
		   db     => 'null',
		   dbxref => 'plot',
		  });
  my $plot_of = $schema->resultset("Cv::Cvterm")
    ->create_with({
		   name   => 'plot_of',
		   cv     => 'stock relationship',
		   db     => 'null',
		   dbxref => 'plot_of',
		  });

  my $project = $schema->resultset('Project::Project')
    ->create({
	      name => $self->get_trial_name(),
	      description => $self->get_trial_description(),
	     });

  my $field_layout_experiment = $schema->resultset('NaturalDiversity::NdExperiment')
      ->create({
		nd_geolocation_id => $geolocation->nd_geolocation_id(),
		type_id => $field_layout_cvterm->cvterm_id(),
		});

  #link to the project
  $field_layout_experiment->find_or_create_related('nd_experiment_projects',{project_id => $project->project_id()});



  $project->create_projectprops( { 'project year' => $self->get_trial_year(),'design' => $self->get_design_type()}, {autocreate=>1});

  foreach my $key (sort { $a <=> $b} keys %design) {
    my $plot_name = $design{$key}->{plot_name};
    my $plot_number = $design{$key}->{plot_number};
    my $stock_name = $design{$key}->{stock_name};
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
    my $is_a_control = $design{$key}->{is_a_control};
    my $plot_unique_name = $stock_name."_replicate:".$rep_number."_block:".$block_number."_plot:".$plot_name."_".$self->get_trial_year()."_".$self->get_trial_location;
    my $plot;
    my $parent_stock;
    my $stock_lookup = CXGN::Stock::StockLookup->new(schema => $schema);
    $stock_lookup->set_stock_name($stock_name);
    $parent_stock = $stock_lookup->get_stock();
    if (!$parent_stock) {
      die ("Error while saving trial layout: no stocks found matching $stock_name");
    }

    #create the plot
    $plot = $schema->resultset("Stock::Stock")
      ->find_or_create({
			organism_id => $parent_stock->organism_id(),
			name       => $plot_unique_name,
			uniquename => $plot_unique_name,
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

    #create the stock_relationship with the accession
    $parent_stock
      ->find_or_create_related('stock_relationship_objects',{
							     type_id => $plot_of->cvterm_id(),
							     subject_id => $plot->stock_id(),
							    } );

    #link the experiment to the stock
    $field_layout_experiment
      ->find_or_create_related('nd_experiment_stocks' , {
							 type_id => $field_layout_cvterm->cvterm_id(),
							 stock_id => $plot->stock_id(),
							});
  }



  $program->associate_breeding_program_with_trial($self->get_breeding_program_id, $project->project_id);

}





#######
1;
#######
