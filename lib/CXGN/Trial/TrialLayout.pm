package CXGN::Trial::TrialLayout;

=head1 NAME

CXGN::Trial::TrialLayout - Module to get layout information about a trial (i.e. a project with a "design" projectprop)

=head1 USAGE

 my $trial_layout = CXGN::Trial::TrialLayout->new({schema => $schema, trial_id => $trial_id} );


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

has 'schema' => (
		 is       => 'rw',
		 isa      => 'DBIx::Class::Schema',
		 lazy_build => 1,
		 required => 1,
		);
has 'trial_id' => (isa => 'Int', is => 'rw', predicate => 'has_trial_id', trigger => \&_lookup_trial_id, required => 1);
has 'project' => (
		  is       => 'ro',
		  isa      => 'Bio::Chado::Schema::Result::Project::Project',
		  reader   => 'get_project',
		  writer   =>  '_set_project',
		  predicate => 'has_project',
		 );
has 'design_type' => (isa => 'Str', is => 'ro', predicate => 'has_design_type', reader => 'get_design_type', writer => '_set_design_type');
has 'trial_year' => (isa => 'Str', is => 'ro', predicate => 'has_trial_year', reader => 'get_trial_year', writer => '_set_trial_year');
has 'trial_name' => (isa => 'Str', is => 'ro', predicate => 'has_trial_name', reader => 'get_trial_name', writer => '_set_trial_name');
has 'trial_description' => (isa => 'Str', is => 'ro', predicate => 'has_trial_description', reader => 'get_trial_description', writer => '_set_trial_description');
has 'trial_location' => (isa => 'Str', is => 'ro', predicate => 'has_trial_location', reader => 'get_trial_location', writer => '_set_trial_location');
has 'design' => (isa => 'HashRef[HashRef[Str]]', is => 'ro', predicate => 'has_design', reader => 'get_design', writer => '_set_design');
has 'plot_names' => (isa => 'ArrayRef', is => 'ro', predicate => 'has_plot_names', reader => 'get_plot_names', writer => '_set_plot_names', default => sub { [] } );
has 'block_numbers' => (isa => 'ArrayRef', is => 'ro', predicate => 'has_block_numbers', reader => 'get_block_numbers', writer => '_set_block_numbers');
has 'replicate_numbers' => (isa => 'ArrayRef', is => 'ro', predicate => 'has_replicate_numbers', reader => 'get_replicate_numbers', writer => '_set_replicate_numbers');
has 'accession_names' => (isa => 'ArrayRef', is => 'ro', predicate => 'has_accession_names', reader => 'get_accession_names', writer => '_set_accession_names');
has 'control_names' => (isa => 'ArrayRef', is => 'ro', predicate => 'has_control_names', reader => 'get_control_names', writer => '_set_control_names');


sub _lookup_trial_id {
  my $self = shift;
  $self->_set_project_from_id();
  if (!$self->has_project()) {
      print STDERR "Trial id not found\n";
    return;
  }
  my $accession_names_ref;
  my $control_names_ref;
  my $design_type_from_project;
  if (!$self->_get_trial_year_from_project()) {return;}
  $self->_set_trial_year($self->_get_trial_year_from_project());
  $self->_set_trial_name($self->get_project->name());
  $self->_set_trial_description($self->get_project->description());
  $design_type_from_project =  $self->_get_design_type_from_project();
  if (! $design_type_from_project) {
    return;
  }
  if (!$self->_get_location_from_field_layout_experiment()) {return;}
  $self->_set_trial_location($self->_get_location_from_field_layout_experiment());
  if (!$self->has_trial_location) {return;}
  $self->_set_design_type($self->_get_design_type_from_project());
  $self->_set_design($self->_get_design_from_trial());
  $self->_set_plot_names($self->_get_plot_info_fields_from_trial("plot_name") || []);
  $self->_set_block_numbers($self->_get_plot_info_fields_from_trial("block_number") || []);
  $self->_set_replicate_numbers($self->_get_plot_info_fields_from_trial("rep_number") || []);
  #$self->_set_is_a_control($self->_get_plot_info_fields_from_trial("is_a_control"));
  ($accession_names_ref, $control_names_ref) = $self->_get_trial_accession_names_and_control_names();
  if ($accession_names_ref) {
    $self->_set_accession_names($accession_names_ref);
  }
  if ($control_names_ref) {
    $self->_set_control_names($control_names_ref);
  }


}

sub _get_control_plot_names_from_trial {
  my $self = shift;
  my %design = %{$self->get_design()};
  my @control_names;
  foreach my $key (sort { $a <=> $b} keys %design) {
    my %design_info = %{$design{$key}};
    my $is_a_control;
    $is_a_control = $design_info{"is_a_control"};
    if ($is_a_control) {
      push(@control_names, $design_info{"plot_name"});
    }
  }
  if (! scalar(@control_names) >= 1){
    return;
  }
  return \@control_names;
}


sub _get_plot_info_fields_from_trial {
  my $self = shift;
  my $field_name = shift;
  my %design = %{$self->get_design()};
  my @field_values;
  my %unique_field_values;
  foreach my $key (sort { $a <=> $b} keys %design) {
    my %design_info = %{$design{$key}};
    if (! $unique_field_values{$design_info{$field_name}}) {
      push(@field_values, $design_info{$field_name});
    }
    $unique_field_values{$design_info{$field_name}} = 1;
  }

  if (! scalar(@field_values) >= 1){
    return;
  }
  return \@field_values;
}


sub _get_design_from_trial {
  my $self = shift;
  my $schema = $self->get_schema();
  my $plots_ref;
  my @plots;
  my %design;
  $plots_ref = $self->_get_plots();
  if (!$plots_ref) {
    return;
  }
  @plots = @{$plots_ref};
  foreach my $plot (@plots) {
    my %design_info;
    my $plot_of_cv = $schema->resultset("Cv::Cvterm")->find({name => 'plot_of'});
    my $tissue_sample_of_cv = $schema->resultset("Cv::Cvterm")->find({ name=>'tissue_sample_of' });
    my $plot_name = $plot->uniquename;
    my $plot_number_prop = $plot->stockprops->find( { 'type.name' => 'plot number' }, { join => 'type'} );
    my $block_number_prop = $plot->stockprops->find( { 'type.name' => 'block' }, { join => 'type'} );
    my $replicate_number_prop = $plot->stockprops->find( { 'type.name' => 'replicate' }, { join => 'type'} );
    my $range_number_prop = $plot->stockprops->find( { 'type.name' => 'range' }, { join => 'type'} );
    my $is_a_control_prop = $plot->stockprops->find( { 'type.name' => 'is a control' }, { join => 'type'} );
    my $accession = $plot->search_related('stock_relationship_subjects')->find({ 'type_id' => {  -in => [ $plot_of_cv->cvterm_id(), $tissue_sample_of_cv->cvterm_id() ] } })->object;
    my $accession_name = $accession->uniquename;
    $design_info{"plot_name"}=$plot->uniquename;
    $design_info{"plot_id"}=$plot->stock_id;
    #print STDERR "stock id of plot: ". $plot->stock_id."\n";
    #print STDERR "plotprop: $plot_number_prop\n";
    if ($plot_number_prop) {
      $design_info{"plot_number"}=$plot_number_prop->value();
      #print STDERR "plot# value: ".$plot_number_prop->value()."\n"
    }
    else {die "no plot number stockprop found for plot $plot_name";}
    if ($block_number_prop) {
      $design_info{"block_number"}=$block_number_prop->value();
      #print STDERR "block# value: ".$block_number_prop->value()."\n"
    }
    if ($replicate_number_prop) {
      $design_info{"rep_number"}=$replicate_number_prop->value();
      #print STDERR "rep# value: ".$replicate_number_prop->value()."\n"
    }
    if ($range_number_prop) {
      $design_info{"range_number"}=$replicate_number_prop->value();
      #print STDERR "range# value: ".$range_number_prop->value()."\n"
    }
    if ($is_a_control_prop) {
      $design_info{"is_a_control"}=$is_a_control_prop->value();
    }
    if ($accession_name) {
      $design_info{"accession_name"}=$accession_name;
    }
    #print STDERR "accession name in plot: $accession_name\n";
    $design{$plot_number_prop->value}=\%design_info;
  }
  return \%design;

}


sub _get_field_layout_experiment_from_project {
  my $self = shift;
  my $project;
  my $field_layout_experiment;
  $project = $self->get_project();
  if (!$project) {
    return;
  }
  $field_layout_experiment = $project
     ->search_related("nd_experiment_projects")
       ->search_related("nd_experiment")
   	->find({ 'type.name' => ['field layout', 'genotyping layout']}, {join => 'type' });
  return $field_layout_experiment;
}


sub _get_location_from_field_layout_experiment {
  my $self = shift;
  my $field_layout_experiment;
  my $location_name;
  $field_layout_experiment = $self -> _get_field_layout_experiment_from_project();
  if (!$field_layout_experiment) {
    return;
  }
  $location_name = $field_layout_experiment -> nd_geolocation -> description();
  #print STDERR "Location: $location_name\n";
  return $location_name;
}




sub _set_project_from_id {
  my $self = shift;
  my $schema = $self->get_schema();
  my $project;
  if (!$self->has_trial_id()) {
    return;
  }
  $project = $schema->resultset('Project::Project')->find({project_id => $self->get_trial_id()});
  if (!$project) {
    return;
  }
  $self->_set_project($project);
}

sub _get_design_type_from_project {
  my $self = shift;
  my $design_prop;
  my $design_type;
  my $project;

  if (!$self->has_trial_id()) {
    return;
  }
  $project = $self->get_project();
  if (!$project) {
    return;
  }
  $design_prop =  $project->projectprops->find(
        { 'type.name' => 'design' },
        { join => 'type'}
        ); #there should be only one design prop.
  if (!$design_prop) {
    return;
  }
  $design_type = $design_prop->value;
  if (!$design_type) {
    return;
  }
  return $design_type;
}

sub _get_trial_year_from_project {
  my $self = shift;
  my $project;
  my $year_prop;
  my $year;

  if (!$self->has_trial_id()) {
    return;
  }
  $project = $self->get_project();
  if (!$project) {
    return;
  }
  $year_prop =  $project->projectprops->find(
        { 'type.name' => 'project year' },
        { join => 'type'}
        ); #there should be only one project year prop.
  if (!$year_prop) {
    return;
  }
  $year = $year_prop->value;
  return $year;
}



sub _get_plots {
  my $self = shift;
  my $project;
  my $field_layout_experiment;
  my @plots;
  $project = $self->get_project();
  if (!$project) {
    return;
  }
  $field_layout_experiment = $self->_get_field_layout_experiment_from_project();
  if (!$field_layout_experiment) {
    return;
  }
  @plots = $field_layout_experiment->nd_experiment_stocks->search_related('stock');
  return \@plots;
}

sub oldget_plot_names {
  my $self = shift;
  my $plots_ref;
  my @plots;
  my @plot_names;
  my $plot;
  $plots_ref = $self->_get_plots();
  if (!$plots_ref) {
    return;
  }
  @plots = @{$plots_ref};
  foreach $plot (@plots) {
    push(@plot_names,$plot->uniquename);
#    print "plot: ".$plot->uniquename."\n";
  }
  if (!scalar(@plot_names) >= 1) {
    return;
  }
  return \@plot_names;
}

sub get_plot_ids {
  my $self = shift;
  my $plots_ref;
  my @plots;
  my @plot_names;
  my $plot;
  $plots_ref = $self->_get_plots();
  if (!$plots_ref) {
    return;
  }
  @plots = @{$plots_ref};
  foreach $plot (@plots) {
    push(@plot_names,$plot->stock_id);
  }
  if (!scalar(@plot_names) >= 1) {
    return;
  }
  return \@plot_names;
}

sub _get_trial_accession_names_and_control_names {
  my $self = shift;
  my $schema = shift;
  $schema = $self->get_schema();
  my $plots_ref;
  my @plots;
  my $plot;
  my $plot_of_cv;
  my $sample_of_cv;
  my %unique_accessions;
  my %unique_controls;
  my @accession_names;
  my @control_names;
  $plots_ref = $self->_get_plots();
  if (!$plots_ref) {
    return;
  }
  @plots = @{$plots_ref};
  $plot_of_cv = $schema->resultset("Cv::Cvterm")->find({name => 'plot_of'});
  $sample_of_cv = $schema->resultset("Cv::Cvterm")->find({name => 'tissue_sample_of'});
  foreach $plot (@plots) {
    my $accession = $plot->search_related('stock_relationship_subjects')->find({ 'type_id' => [$plot_of_cv->cvterm_id(),$sample_of_cv->cvterm_id()]})->object;
    my $is_a_control_prop = $plot->stockprops->find( { 'type.name' => 'is a control' }, { join => 'type'} );
    my $is_a_control;
    if ($is_a_control_prop) {
      $is_a_control = $is_a_control_prop->value();
    }
    if ($is_a_control) {
      $unique_controls{$accession->uniquename}=1;
    }
    else {
      $unique_accessions{$accession->uniquename}=1;
    }
  }
  foreach my $accession_name (sort { lc($a) cmp lc($b)} keys %unique_accessions) {
    push(@accession_names, $accession_name);
    #print STDERR "Accession: $accession_name \n";
  }
  if (!scalar(@accession_names) >= 1) {
    return;
  }
  foreach my $control_name (sort { lc($a) cmp lc($b)} keys %unique_controls) {
    push(@control_names, $control_name);
    #print STDERR "Control: $control_name \n";
  }
  return (\@accession_names, \@control_names);
}


#######
1;
#######
