package CXGN::Trial::TrialLayout;

=head1 NAME

CXGN::Trial::TrialLayout - Module to get layout information about a trial

=head1 SYNOPSIS

 my $trial_layout = CXGN::Trial::TrialLayout->new({
    schema => $schema,
    trial_id => $trial_id
 });
 my $tl = $trial_layout->get_design();
 the return is a HashRef of HashRef where the keys are the plot_number such as:
 
 {
    '1001' => {
        "plot_name" => "plot1",
        "plot_number" => 1001,
        "plot_id" => 1234,
        "accession_name" => "accession1",
        "accession_id" => 2345,
        "block_number" => 1,
        "row_number" => 2,
        "col_number" => 3,
        "rep_number" => 1,
        "is_a_control" => 1,
        "seedlot_name" => "seedlot1",
        "seedlot_stock_id" => 3456,
        "num_seed_per_plot" => 12,
        "seed_transaction_operator" => "janedoe",
        "plant_names" => ["plant1", "plant2"],
        "plant_ids" => [3456, 3457]
    }
 }
 
 By using get_design(), this module attempts to get the design from a
 projectprop called 'trial_layout_json', but if it cannot be found it calls
 generate_and_cache_layout() to generate the design, return it, and store it
 using that projectprop.
 
--------------------------------------------------------------------------

This can also be used the verify that a layout has a physical map covering all
plots, as well as verifying that the relationships between entities are valid
by doing:

my $trial_layout = CXGN::Trial::TrialLayout->new({
    schema => $schema,
    trial_id => $c->stash->{trial_id},
    verify_layout=>1,
    verify_physical_map=>1
});
my $trial_errors = $trial_layout->_get_design_from_trial();

If there are errors, $trial_errors is a HashRef like:

{
    "errors" => 
        {
            "layout_errors" => [ "the accession between plot 1 and seedlot 1 is out of sync", "the accession between plot 1 and plant 1 is out of sync" ],
            "seedlot_errors" => [ "plot1 does not have a seedlot linked" ],
            "physical_map_errors" => [ "plot 1 does not have a row_number", "plot 1 does not have a col_number"]
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
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Chado::Stock;
use JSON;

has 'schema' => (
    is       => 'rw',
    isa      => 'DBIx::Class::Schema',
    required => 1,
);
has 'trial_id' => (
    isa => 'Int',
    is => 'rw',
    predicate => 'has_trial_id',
    trigger => \&_lookup_trial_id,
    required => 1
);
has 'project' => ( is => 'ro', isa => 'Bio::Chado::Schema::Result::Project::Project', reader => 'get_project', writer => '_set_project', predicate => 'has_project');
has 'design_type' => (isa => 'Str', is => 'ro', predicate => 'has_design_type', reader => 'get_design_type', writer => '_set_design_type');
has 'trial_year' => (isa => 'Str', is => 'ro', predicate => 'has_trial_year', reader => 'get_trial_year', writer => '_set_trial_year');
has 'trial_name' => (isa => 'Str', is => 'ro', predicate => 'has_trial_name', reader => 'get_trial_name', writer => '_set_trial_name');
has 'trial_description' => (isa => 'Str', is => 'ro', predicate => 'has_trial_description', reader => 'get_trial_description', writer => '_set_trial_description');

has 'trial_location' => (
    isa => 'Str',
    is => 'ro',
    predicate => 'has_trial_location', reader => 'get_trial_location', writer => '_set_trial_location',
    lazy     => 1,
    builder  => '_retrieve_trial_location',
);
has 'plot_dimensions' => (
    isa => 'ArrayRef',
    is => 'ro',
    predicate => 'has_plot_dimensions', reader => 'get_plot_dimensions', writer => '_set_plot_dimensions',
    lazy     => 1,
    builder  => '_retrieve_plot_dimensions',
);
has 'design' => (isa => 'HashRef', is => 'ro', predicate => 'has_design', reader => 'get_design', writer => '_set_design');
has 'plot_names' => (isa => 'ArrayRef', is => 'ro', predicate => 'has_plot_names', reader => 'get_plot_names', writer => '_set_plot_names', default => sub { [] } );
has 'block_numbers' => (isa => 'ArrayRef', is => 'ro', predicate => 'has_block_numbers', reader => 'get_block_numbers', writer => '_set_block_numbers');
has 'replicate_numbers' => (isa => 'ArrayRef', is => 'ro', predicate => 'has_replicate_numbers', reader => 'get_replicate_numbers', writer => '_set_replicate_numbers');
has 'accession_names' => (isa => 'ArrayRef', is => 'ro', predicate => 'has_accession_names', reader => 'get_accession_names', writer => '_set_accession_names');
has 'control_names' => (isa => 'ArrayRef', is => 'ro', predicate => 'has_control_names', reader => 'get_control_names', writer => '_set_control_names');
has 'row_numbers' => (isa => 'ArrayRef', is => 'rw', predicate => 'has_row_numbers', reader => 'get_row_numbers', writer => '_set_row_numbers');
has 'col_numbers' => (isa => 'ArrayRef', is => 'rw', predicate => 'has_col_numbers', reader => 'get_col_numbers', writer => '_set_col_numbers');

# To verify that all plots in the trial have valid props and relationships. This means that the plots have plot_number and block_number properties. All plots have an accession associated. The plot's accession is in sync with any plant's accession, subplot's accession, and seedlot's containing accession. If verify_relationships is set to 1, then get_design will not return the design anymore, but will instead indicate any errors in the stored layout.
has 'verify_layout' => (isa => 'Bool', is => 'rw', predicate => 'has_verify_layout', reader => 'get_verify_layout');
# verify_physical_map checks that all plot's in the trial have row and column props.
has 'verify_physical_map' => (isa => 'Bool', is => 'rw', predicate => 'has_verify_physical_map', reader => 'get_verify_physical_map');

sub _lookup_trial_id {
    my $self = shift;
    print STDERR "CXGN::Trial::TrialLayout ".localtime."\n";

  #print STDERR "Check 2.1: ".localtime()."\n";
  $self->_set_project_from_id();
  if (!$self->has_project()) {
      print STDERR "Trial id not found\n";
    return;
  }

  #print STDERR "Check 2.2: ".localtime()."\n";
  if (!$self->_get_trial_year_from_project()) {return;}

  $self->_set_trial_year($self->_get_trial_year_from_project());
  $self->_set_trial_name($self->get_project->name());
  $self->_set_trial_description($self->get_project->description());
  #print STDERR "Check 2.3: ".localtime()."\n";

  if (!$self->_get_design_type_from_project()) {
      print STDERR "Trial has no design type... not creating layout object.\n";
      return;
  }
  $self->_set_design_type($self->_get_design_type_from_project());
  #print STDERR "Check 2.3.4: ".localtime()."\n";
  $self->_set_design($self->_get_design_from_trial());
  #print STDERR "Check 2.4: ".localtime()."\n";
  $self->_set_plot_names($self->_get_plot_info_fields_from_trial("plot_name") || []);
  $self->_set_block_numbers($self->_get_plot_info_fields_from_trial("block_number") || []);
  $self->_set_replicate_numbers($self->_get_plot_info_fields_from_trial("rep_number") || []);
  $self->_set_row_numbers($self->_get_plot_info_fields_from_trial("row_number") || [] );
  $self->_set_col_numbers($self->_get_plot_info_fields_from_trial("col_number") || [] );
  #$self->_set_is_a_control($self->_get_plot_info_fields_from_trial("is_a_control"));
  #print STDERR "CXGN::Trial::TrialLayout End Build".localtime."\n";
}

sub _retrieve_trial_location {
    my $self = shift;
    if (!$self->_get_location_from_field_layout_experiment()) {
        print STDERR "Trial has no location.\n";
        return;
    } else {
        $self->_set_trial_location($self->_get_location_from_field_layout_experiment());
    }
}

sub _retrieve_plot_dimensions {
    my $self = shift;
    $self->_set_plot_dimensions($self->_get_plot_dimensions_from_trial());
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
  foreach my $key (sort { $a cmp $b} keys %design) {
    my %design_info = %{$design{$key}};
    if (exists($design_info{$field_name})) { 
	if (! exists($unique_field_values{$design_info{$field_name}})) {
	    #print STDERR "pushing $design_info{$field_name}...\n";
	    push(@field_values, $design_info{$field_name});
	}
	$unique_field_values{$design_info{$field_name}} = 1;
    }
  }

  if (! scalar(@field_values) >= 1){
    return;
  }
  return \@field_values;
}


sub _get_design_from_trial {
    #print STDERR "Check 2.3.4.1: ".localtime()."\n";
    my $self = shift;
    my $schema = $self->get_schema();
    my $project = $self->get_project();

    #Try to retrieve layout from cached json
    my $trial_layout_json_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'trial_layout_json', 'project_property')->cvterm_id;
    my $trial_layout_json = $project->projectprops->find({ 'type_id' => $trial_layout_json_cvterm_id });
    if ($trial_layout_json) {
        print STDERR "TrialLayout from cache ".localtime."\n";
        return decode_json $trial_layout_json->value;
    } else {
        $self->generate_and_cache_layout();
    }
}

sub generate_and_cache_layout {
    my $self = shift;
    print STDERR "TrialLayout generate layout ".localtime."\n";
    my $schema = $self->get_schema();
    my $plots_ref;
    my @plots;
    my %design;
    my %verify_errors;
    my %unique_accessions;
    my %unique_controls;
    my $project = $self->get_project();

  $plots_ref = $self->_get_plots();
  if (!$plots_ref) {
      print STDERR "_get_design_from_trial: not plots provided... returning.\n";
      return { error => "Something went wrong retrieving plots for this trial. This should not happen, so please contact us." };
  }
#print STDERR "Check 2.3.4.2: ".localtime()."\n";

  my $genotyping_user_id_row = $project
      ->search_related("nd_experiment_projects")
      ->search_related("nd_experiment")
      ->search_related("nd_experimentprops")
      ->find({ 'type.name' => 'genotyping_user_id' }, {join => 'type' });

  my $genotyping_project_name_row = $project
      ->search_related("nd_experiment_projects")
      ->search_related("nd_experiment")
      ->search_related("nd_experimentprops")
      ->find({ 'type.name' => 'genotyping_project_name' }, {join => 'type' });
#print STDERR "Check 2.3.4.3: ".localtime()."\n";

  my $plot_of_cv = $schema->resultset("Cv::Cvterm")->find({name => 'plot_of'});
  my $tissue_sample_of_cv = $schema->resultset("Cv::Cvterm")->find({ name=>'tissue_sample_of' });
  my $plant_rel_cvterm = SGN::Model::Cvterm->get_cvterm_row($self->get_schema, 'plant_of', 'stock_relationship' );
  my $subplot_rel_cvterm = SGN::Model::Cvterm->get_cvterm_row($self->get_schema, 'subplot_of', 'stock_relationship' );
  my $plant_rel_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->get_schema, 'plant_of', 'stock_relationship' )->cvterm_id();
  my $subplot_rel_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->get_schema, 'subplot_of', 'stock_relationship' )->cvterm_id();
  my $plant_of_subplot_rel_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->get_schema, 'plant_of_subplot', 'stock_relationship' )->cvterm_id();
  my $seed_transaction_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->get_schema, 'seed transaction', 'stock_relationship' )->cvterm_id();
  my $collection_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->get_schema, 'collection_of', 'stock_relationship' )->cvterm_id();
  my $plot_number_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->get_schema, 'plot number', 'stock_property' )->cvterm_id();
  my $block_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->get_schema, 'block', 'stock_property' )->cvterm_id();
  my $replicate_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->get_schema, 'replicate', 'stock_property' )->cvterm_id();
  my $range_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->get_schema, 'range', 'stock_property' )->cvterm_id();
  my $is_a_control_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->get_schema, 'is a control', 'stock_property' )->cvterm_id();
  my $row_number_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->get_schema, 'row_number', 'stock_property' )->cvterm_id();
  my $col_number_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->get_schema, 'col_number', 'stock_property' )->cvterm_id();
  my $json = JSON->new();

  @plots = @{$plots_ref};
  foreach my $plot (@plots) {
      #print STDERR "_get_design_from_trial. Working on plot ".$plot->uniquename()."\n";
    my %design_info;

    if ($genotyping_user_id_row) {       
	$design_info{genotyping_user_id} = $genotyping_user_id_row->get_column("value") || "unknown";
	#print STDERR "RETRIEVED: genotyping_user_id: $design{genotyping_user_id}\n";
    }
    if ($genotyping_project_name_row) { 
	$design_info{genotyping_project_name} = $genotyping_project_name_row->get_column("value") || "unknown";
	#print STDERR "RETRIEVED: genotyping_project_name: $design{genotyping_project_name}\n";
    }
    my $plot_name = $plot->uniquename;
    my $plot_id = $plot->stock_id;
    my $plot_properties = $plot->search_related('stockprops');
    my %stockprop_hash;
    while (my $r = $plot_properties->next){
        push @{$stockprop_hash{$r->type_id}}, $r->value;
    }
    my $plot_number_prop = $stockprop_hash{$plot_number_cvterm_id} ? join ',', @{$stockprop_hash{$plot_number_cvterm_id}} : undef;
    my $block_number_prop = $stockprop_hash{$block_cvterm_id} ? join ',', @{$stockprop_hash{$block_cvterm_id}} : undef;
    my $replicate_number_prop = $stockprop_hash{$replicate_cvterm_id} ? join ',', @{$stockprop_hash{$replicate_cvterm_id}} : undef;
    my $range_number_prop = $stockprop_hash{$range_cvterm_id} ? join ',', @{$stockprop_hash{$range_cvterm_id}} : undef;
    my $is_a_control_prop = $stockprop_hash{$is_a_control_cvterm_id} ? join ',', @{$stockprop_hash{$is_a_control_cvterm_id}} : undef;
    my $row_number_prop = $stockprop_hash{$row_number_cvterm_id} ? join ',', @{$stockprop_hash{$row_number_cvterm_id}} : undef;
    my $col_number_prop = $stockprop_hash{$col_number_cvterm_id} ? join ',', @{$stockprop_hash{$col_number_cvterm_id}} : undef;
    my $accession = $plot->search_related('stock_relationship_subjects')->find({ 'type_id' => {  -in => [ $plot_of_cv->cvterm_id(), $tissue_sample_of_cv->cvterm_id() ] } })->object;
    my $plants = $plot->search_related('stock_relationship_subjects', { 'me.type_id' => $plant_rel_cvterm_id })->search_related('object', {}, {order_by=>"object.stock_id"});
	my $subplots = $plot->search_related('stock_relationship_subjects', { 'me.type_id' => $subplot_rel_cvterm_id })->search_related('object', {}, {order_by=>"object.stock_id"});
	my $seedlot_transaction = $plot->search_related('stock_relationship_subjects', { 'me.type_id' => $seed_transaction_cvterm_id });

    my $accession_name = $accession->uniquename;
    my $accession_id = $accession->stock_id;

    $design_info{"plot_name"}=$plot_name;
    $design_info{"plot_id"}=$plot_id;

      if ($plot_number_prop) {
	  $design_info{"plot_number"}=$plot_number_prop;
      }
      else { 
	  die "no plot number stockprop found for plot $plot_name"; 
      }

    if ($block_number_prop) {
      $design_info{"block_number"}=$block_number_prop;
    }
	if ($row_number_prop) {
      $design_info{"row_number"}=$row_number_prop;
    }
	if ($col_number_prop) {
      $design_info{"col_number"}=$col_number_prop;
    }
    if ($replicate_number_prop) {
      $design_info{"rep_number"}=$replicate_number_prop;
    }
    if ($range_number_prop) {
      $design_info{"range_number"}=$replicate_number_prop;
    }
    if ($is_a_control_prop) {
      $design_info{"is_a_control"}=$is_a_control_prop;
      $unique_controls{$accession_name}=$accession_id;
    }
    else {
      $unique_accessions{$accession_name}=$accession_id;
    }
    if ($accession_name) {
      $design_info{"accession_name"}=$accession_name;
    }
    if ($accession_id) {
      $design_info{"accession_id"}=$accession_id;
    }
    if ($self->get_verify_layout){
        if (!$accession_name || !$accession_id || !$plot_name || !$plot_id){
            push @{$verify_errors{errors}->{layout_errors}}, "Plot: $plot_name does not have an accession!";
        }
        if (!$block_number_prop || !$plot_number_prop){
            push @{$verify_errors{errors}->{layout_errors}}, "Plot: $plot_name does not have a block_number and/or plot_number!";
        }
        if (!$seedlot_transaction->first){
            push @{$verify_errors{errors}->{seedlot_errors}}, "Plot: $plot_name does not have a seedlot linked.";
        }
    }
    if ($self->get_verify_physical_map){
        if (!$row_number_prop || !$col_number_prop){
            push @{$verify_errors{errors}->{physical_map_errors}}, "Plot: $plot_name does not have a row_number and/or col_number!";
        }
    }

	if ($seedlot_transaction->first()){
        my $val = $json->decode($seedlot_transaction->first()->value());
        my $seedlot = $seedlot_transaction->search_related('object');
        if ($self->get_verify_layout){
            my $seedlot_accession_check = $seedlot->search_related('stock_relationship_objects', {'stock_relationship_objects.type_id'=>$collection_of_cvterm_id})->search_related('subject', {'subject.stock_id'=>$accession_id});
            if (!$seedlot_accession_check->first){
                push @{$verify_errors{errors}->{layout_errors}}, "Seedlot: ".$seedlot->first->uniquename." does not have the same accession: $accession_name as the plot: $plot_name.";
            }
        }
		$design_info{"seedlot_name"} = $seedlot->first->uniquename;
		$design_info{"seedlot_stock_id"} = $seedlot->first->stock_id;
		$design_info{"num_seed_per_plot"} = $val->{amount};
		$design_info{"seed_transaction_operator"} = $val->{operator};
	}
	if ($plants) {
		my @plant_names;
		my @plant_ids;
		while (my $p = $plants->next()) {
            if ($self->get_verify_layout){
                my $plant_accession_check = $p->search_related('stock_relationship_subjects', {'me.type_id'=>$plant_rel_cvterm_id})->search_related('object', {'object.stock_id'=>$accession_id});
                if (!$plant_accession_check->first){
                    push @{$verify_errors{errors}->{layout_errors}}, "Plant: ".$p->uniquename." does not have the same accession: $accession_name as the plot: $plot_name.";
                }
            }
			my $plant_name = $p->uniquename();
			my $plant_id = $p->stock_id();
			push @plant_names, $plant_name;
			push @plant_ids, $plant_id;
		}
		$design_info{"plant_names"}=\@plant_names;
		$design_info{"plant_ids"}=\@plant_ids;
	}
	if ($subplots) {
		my @subplot_names;
		my @subplot_ids;
		my %subplots_plants_hash;
		while (my $p = $subplots->next()) {
            if ($self->get_verify_layout){
                my $subplot_accession_check = $p->search_related('stock_relationship_subjects', {'me.type_id'=>$subplot_rel_cvterm_id})->search_related('object', {'object.stock_id'=>$accession_id});
                if (!$subplot_accession_check->first){
                    push @{$verify_errors{errors}->{layout_errors}}, "Subplot: ".$p->uniquename." does not have the same accession: $accession_name as the plot: $plot_name.";
                }
            }
			my $subplot_name = $p->uniquename();
			my $subplot_id = $p->stock_id();
			my $plants_of_subplot = $p->search_related('stock_relationship_objects', { 'me.type_id' => $plant_of_subplot_rel_cvterm_id })->search_related('subject');
			while (my $pp = $plants_of_subplot->next()){
				push @{$subplots_plants_hash{$subplot_name}}, $pp->uniquename();
			}
			push @subplot_names, $subplot_name;
			push @subplot_ids, $subplot_id;
		}
		if (scalar(@subplot_names)>0){
			$design_info{"subplot_names"}=\@subplot_names;
			$design_info{"subplot_ids"}=\@subplot_ids;
			$design_info{"subplots_plant_names"}=\%subplots_plants_hash;
		}
	}
    $design{$plot_number_prop}=\%design_info;
  }

    if ($self->get_verify_layout || $self->get_verify_physical_map){
        return \%verify_errors;
    }

    my @accession_names;
    foreach my $accession_name (sort { lc($a) cmp lc($b)} keys %unique_accessions) {
        push @accession_names, {accession_name=>$accession_name, stock_id=>$unique_accessions{$accession_name} };
    }
    my @control_names;
    foreach my $control_name (sort { lc($a) cmp lc($b)} keys %unique_controls) {
        push @control_names, {accession_name=>$control_name, stock_id=>$unique_controls{$control_name} };
    }

    if (scalar(@accession_names)>0) {
        $self->_set_accession_names(\@accession_names);
    }
    if (scalar(@control_names)>0) {
        $self->_set_control_names(\@control_names);
    }

    my $trial_layout_json_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'trial_layout_json', 'project_property');
    my $trial_layout_json = $project->projectprops->find({ 'type_id' => $trial_layout_json_cvterm->cvterm_id });
    if ($trial_layout_json) {
        $trial_layout_json->delete();
    }
    $project->create_projectprops({
        $trial_layout_json_cvterm->name() => encode_json(\%design)
    });

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
   	->find({ 'type.name' => ['field_layout', 'genotyping_layout']}, {join => 'type' });
  return $field_layout_experiment;
}


sub _get_location_from_field_layout_experiment {
  my $self = shift;
  my $field_layout_experiment;
  my $location_name;
  $field_layout_experiment = $self -> _get_field_layout_experiment_from_project();
  if (!$field_layout_experiment) {
      print STDERR "No field layout detected for this trial.\n";
      return;
  }
  $location_name = $field_layout_experiment -> nd_geolocation -> description();
  #print STDERR "Location: $location_name\n";
  return $location_name;
}

sub _get_plot_dimensions_from_trial {
  my $self = shift;
  if (!$self->has_trial_id()) {
    return;
  }
  my $project = $self->get_project();
  if (!$project) {
    return;
  }
  my $schema = $self->get_schema();
  my $plot_width = '';
  my $plot_width_cvterm_id = $schema->resultset("Cv::Cvterm")->find({name => 'plot_width'});
  my $plot_width_type_id = '';
  if ($plot_width_cvterm_id) {
      $plot_width_type_id = $plot_width_cvterm_id->cvterm_id;

      my $plot_width_row = $schema->resultset('Project::Projectprop')->find({project_id => $self->get_trial_id(), type_id => $plot_width_type_id});      
      if ($plot_width_row) {
	  $plot_width = $plot_width_row->value();
      }
  }
  
    my $plot_length = '';
  my $plot_length_cvterm_id = $schema->resultset("Cv::Cvterm")->find({name => 'plot_length'});
  my $plot_length_type_id = '';
  if ($plot_length_cvterm_id) {
      $plot_length_type_id = $plot_length_cvterm_id->cvterm_id;

      my $plot_length_row = $schema->resultset('Project::Projectprop')->find({project_id => $self->get_trial_id(), type_id => $plot_length_type_id});      
      if ($plot_length_row) {
	  $plot_length = $plot_length_row->value();
      }
  }
  
      my $plants_per_plot = '';
  my $plants_per_plot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project_has_plant_entries', 'project_property');
  my $plants_per_plot_type_id = '';
  if ($plants_per_plot_cvterm_id) {
      $plants_per_plot_type_id = $plants_per_plot_cvterm_id->cvterm_id;

      my $plants_per_plot_row = $schema->resultset('Project::Projectprop')->find({project_id => $self->get_trial_id(), type_id => $plants_per_plot_type_id});      
      if ($plants_per_plot_row) {
	  $plants_per_plot = $plants_per_plot_row->value();
      }
  }
  return [$plot_length, $plot_width, $plants_per_plot];
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
      print STDERR "No field layout experiment found!\n";
      return;
  }
  my $plot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->get_schema(), "plot", "stock_type")->cvterm_id();
  my $tissue_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->get_schema(), "tissue_sample", "stock_type")->cvterm_id();
  @plots = $field_layout_experiment->nd_experiment_stocks->search_related('stock', {'stock.type_id' => [$plot_cvterm_id, $tissue_cvterm_id] });

  #debug...
  #print STDERR "PLOT LIST: \n";
  #print STDERR  join "\n", map { $_->name() } @plots;

  return \@plots;
}


sub get_plant_names {
	my $class = shift;
	my $args = shift;
	my @plants;

	my $schema = $args->{bcs_schema};
	my $plots = $args->{plot_rs};
	my $plant_rel_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'plant_of', 'stock_relationship' );
	foreach (@$plots) {
		my $plot_id = $_->stock_id();
		#print STDERR $plot_id;
		my $stock_relationships =$schema->resultset("Stock::StockRelationship")->search({
			subject_id => $plot_id,
			#object_id => $plant->stock_id(),
			'me.type_id' => $plant_rel_cvterm->cvterm_id(),
		})->search_related('object');
		if (!$stock_relationships) {
			print STDERR "Plot ".$_->name()." does not have plants associated with it.\n";
			return;
		}
		while (my $plant = $stock_relationships->next()){
			push @plants, $plant->name();
		}
	}
	#print STDERR Dumper \@plants;
	return \@plants;
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
    my $accession = $plot->search_related('stock_relationship_subjects')->find({ 'type_id' => [$plot_of_cv->cvterm_id(),$sample_of_cv->cvterm_id() ]})->object;
    my $is_a_control_prop = $plot->stockprops->find( { 'type.name' => 'is a control' }, { join => 'type'} );
    my $is_a_control;
    if ($is_a_control_prop) {
      $is_a_control = $is_a_control_prop->value();
    }
    if ($is_a_control) {
      $unique_controls{$accession->uniquename}=$accession->stock_id;
    }
    else {
      $unique_accessions{$accession->uniquename}=$accession->stock_id;
    }
  }
  foreach my $accession_name (sort { lc($a) cmp lc($b)} keys %unique_accessions) {
    push(@accession_names, {accession_name=>$accession_name, stock_id=>$unique_accessions{$accession_name} } );
    #print STDERR "Accession: $accession_name \n";
  }
  if (!scalar(@accession_names) >= 1) {
    return;
  }
  foreach my $control_name (sort { lc($a) cmp lc($b)} keys %unique_controls) {
    push(@control_names, {accession_name=>$control_name, stock_id=>$unique_controls{$control_name} } );
    #print STDERR "Control: $control_name \n";
  }
  return (\@accession_names, \@control_names);
}


# sub _get_genotyping_experiment_metadata { 
#     my $self = shift;

#     my $project = $self->get_project();
#     if (!$project) {
# 	return;
#     }
#     my $metadata = $project
# 	->search_related("nd_experiment_projects")
# 	->search_related("nd_experiment")
# 	->search_related("nd_experimentprop")
#    	->search({ 'type.name' => ['genotyping_user_id', 'genotyping_project_name']}, {join => 'type' });
#     return $metadata_rs;
    
# }


#######
1;
#######
