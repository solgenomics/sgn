
package CXGN::Trial::TrialLayout::AbstractLayout;

use Moose;
use namespace::autoclean;
use MooseX::FollowPBP;
use Moose::Util::TypeConstraints;
use Try::Tiny;
use JSON;
use Data::Dumper;

use CXGN::Stock::StockLookup;
use CXGN::Location::LocationLookup;
use SGN::Model::Cvterm;
use CXGN::Chado::Stock;


has 'schema' => (
    is       => 'rw',
    isa      => 'DBIx::Class::Schema',
    required => 1,
);

has 'trial_id' => (
    isa => 'Int',
    is => 'rw',
    predicate => 'has_trial_id',
    #trigger => \&_lookup_trial_id,
    required => 1
);

has 'experiment_type' => (
    is       => 'rw',
    isa     => 'Str', #field_layout or genotyping_layout or analysis_experiment
    required => 1,
);

has 'source_stock_types' => (isa => 'ArrayRef[Str]', is=> 'rw', default =>sub {  [ 'accession' ]  });  # what is being placed on the layout

has 'source_stock_type_ids' => (isa => 'ArrayRef[Int]', is => 'rw' );

has 'source_primary_stock_types' => (isa => 'ArrayRef[Str]', is=> 'rw', default =>sub {  [ 'accession' ]  });

has 'source_primary_stock_type_ids' => (isa => 'ArrayRef[Int]', is => 'rw' );

has 'target_stock_types' => (isa => 'ArrayRef[Str]', is => 'rw', default => sub { [ 'plot' ] }); # the object things are placed on, such as plot

has 'target_stock_type_ids' => (isa => 'ArrayRef[Int]', is => 'rw');

has 'relationship_types' => (isa => 'ArrayRef[Str]', is => 'rw', default => sub { [ 'plot_of' ] }); # relationship between source and target

has 'relationship_type_ids' => (isa => 'ArrayRef[Int]', is => 'rw');

# To verify that all plots in the trial have valid props and relationships. This means that the plots have plot_number and block_number properties. All plots have an accession associated. The plot's accession is in sync with any plant's accession, subplot's accession, and seedlot's containing accession. If verify_relationships is set to 1, then get_design will not return the design anymore, but will instead indicate any errors in the stored layout.
has 'verify_layout' => (isa => 'Bool', is => 'rw', predicate => 'has_verify_layout', reader => 'get_verify_layout');
# verify_physical_map checks that all plot's in the trial have row and column props.
has 'verify_physical_map' => (isa => 'Bool', is => 'rw', predicate => 'has_verify_physical_map', reader => 'get_verify_physical_map');


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


has 'design' => (isa => 'HashRef', is => 'ro', predicate => 'has_design', reader => 'get_design', writer => '_set_design');

has 'plot_names' => (isa => 'ArrayRef', is => 'ro', predicate => 'has_plot_names', reader => 'get_plot_names', writer => '_set_plot_names', default => sub { [] } );


has 'replicate_numbers' => (isa => 'ArrayRef', is => 'ro', predicate => 'has_replicate_numbers', reader => 'get_replicate_numbers', writer => '_set_replicate_numbers');

has 'accession_names' => (isa => 'ArrayRef', is => 'ro', predicate => 'has_accession_names', reader => 'get_accession_names', writer => '_set_accession_names');
has 'analysis_result_stock_names' => (isa => 'ArrayRef', is => 'ro', predicate => 'has_analysis_result_stock_names', reader => 'get_analysis_result_stock_names', writer => '_set_analysis_result_stock_names');

has 'control_names' => (isa => 'ArrayRef', is => 'ro', predicate => 'has_control_names', reader => 'get_control_names', writer => '_set_control_names');

has 'row_numbers' => (isa => 'ArrayRef', is => 'rw', predicate => 'has_row_numbers', reader => 'get_row_numbers', writer => '_set_row_numbers');

has 'col_numbers' => (isa => 'ArrayRef', is => 'rw', predicate => 'has_col_numbers', reader => 'get_col_numbers', writer => '_set_col_numbers');

has 'cvterm_hash' => (isa => 'HashRef', is => 'rw');

sub BUILD {
    my $self = shift;
    my $args = shift;

    # print STDERR "Build CXGN::Trial::TrialLayout::AbstractLayout... ($args->{trial_id})\n";

    $self->_build_cvterm_hash();
}


sub cvterm_id {
    my $self = shift;
    my $term = shift;
    my $id =  $self->get_cvterm_hash->{$term};
    if (! $id) { die "The cvterm '$term' does not exist in the database!"; }
    return $id;
}

sub convert_source_stock_types_to_ids {
    my $self = shift;

    my @source_cvterm_ids;
    my @source_stocks = @{$self->get_source_stock_types()};

    foreach my $source_stock (@source_stocks) {
        push @source_cvterm_ids, $self->cvterm_id($source_stock);
    }

    $self->set_source_stock_type_ids(\@source_cvterm_ids);

    my @source_primary_cvterm_ids;
    my @primary_source_stocks = @{$self->get_source_primary_stock_types()};

    foreach my $source_stock (@primary_source_stocks) {
        push @source_primary_cvterm_ids, $self->cvterm_id($source_stock);
    }

    $self->set_source_primary_stock_type_ids(\@source_primary_cvterm_ids);

    my @target_cvterm_ids;
    foreach my $target_stock (@{$self->get_target_stock_types()}) {
        push @target_cvterm_ids, $self->cvterm_id($target_stock);
    }

    $self->set_target_stock_type_ids(\@target_cvterm_ids);

    my @rel_type_cvterm_ids;
    foreach my $rel_type (@{$self->get_relationship_types()}) {
        push @rel_type_cvterm_ids, $self->cvterm_id($rel_type);
    }

    $self->set_relationship_type_ids(\@rel_type_cvterm_ids);
}


sub _lookup_trial_id {
    my $self = shift;
    print STDERR "CXGN::Trial::TrialLayout AbstractLayout _lookup_trial_id() ".localtime."\n";
    $self->get_schema->storage->dbh->do('SET search_path TO public,sgn');

    #print STDERR "Check 2.1: ".localtime()."\n";
    $self->_set_project_from_id();
    if (!$self->has_project()) {
        print STDERR "Trial id not found\n";
        return;
    }

    if (!$self->_get_trial_year_from_project()) {
        print STDERR "Trial has no associated trial year... quitting!\n";
    #return;
    } else {
            $self->_set_trial_year($self->_get_trial_year_from_project());
    }

    $self->_set_trial_name($self->get_project->name());
    $self->_set_trial_description($self->get_project->description());

    if (!$self->_get_design_type_from_project()) {
        print STDERR "Trial has no design type... not creating layout object.\n";
        return;
    }

    $self->_set_design_type($self->_get_design_type_from_project());
    $self->_set_design($self->_get_design_from_trial());
    # print STDERR "DESIGN: ".Dumper($design)."\n";

    $self->_set_plot_names($self->_get_plot_info_fields_from_trial("plot_name") || []);
    # moved to subclass  $self->_set_block_numbers($self->_get_plot_info_fields_from_trial("block_number") || []);
    $self->_set_replicate_numbers($self->_get_plot_info_fields_from_trial("rep_number") || []);
    $self->_set_row_numbers($self->_get_plot_info_fields_from_trial("row_number") || [] );
    $self->_set_col_numbers($self->_get_plot_info_fields_from_trial("col_number") || [] );
    $self->_set_accession_names($self->_get_unique_accession_names_from_trial() || []);        
    $self->_set_control_names($self->_get_unique_control_accession_names_from_trial() || []);
    $self->set_analysis_result_stock_names();
    
    print STDERR "CXGN::Trial::TrialLayout End Build".localtime."\n";
}

sub set_analysis_result_stock_names {
    my $self = shift;
    my %design = %{$self->get_design()};
    my $design_key = (keys %design)[0];
    my $sample_entry = $design{$design_key};
    if ($sample_entry->{'analysis_result_stock_id'}) {
        print STDERR "SETTING ANALYSIS RESULT STOCK NAMES\n";
        $self->_set_analysis_result_stock_names($self->_get_unique_analysis_result_stock_names_from_trial() || []);
        $self->_set_accession_names([]);        
        $self->_set_control_names([]);
    } 

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

sub _get_unique_accession_names_from_trial {
    my $self = shift;
    my %design = %{$self->get_design()};
    my @acc_names;
    my %unique_acc;
    no warnings 'numeric'; #for genotyping plate so that wells don't give warning

    # print STDERR "DESIGN (AbstractTrial): ".Dumper(\%design);
    foreach my $key (sort { $a <=> $b} keys %design) {
        my %design_info = %{$design{$key}};
        $unique_acc{$design_info{"accession_name"}} = $design_info{"accession_id"};
    }

    foreach (sort keys %unique_acc){
        push @acc_names, {accession_name=>$_, stock_id=>$unique_acc{$_}};
    }

    if (!scalar(@acc_names) >= 1){
        return;
    }

    return \@acc_names;
}

sub _get_unique_analysis_result_stock_names_from_trial {
    my $self = shift;
    my %design = %{$self->get_design()};
    my @analysis_result_stock_names;
    my %unique_analysis_result_stock_names;
    no warnings 'numeric'; #for genotyping plate so that wells don't give warning

    foreach my $key (sort { $a <=> $b} keys %design) {
        my %design_info = %{$design{$key}};    
        $unique_analysis_result_stock_names{$design_info{"analysis_result_stock_name"}} = $design_info{"analysis_result_stock_id"}
    }

    foreach (sort keys %unique_analysis_result_stock_names){
        push @analysis_result_stock_names, {analysis_result_stock_name=>$_, stock_id=>$unique_analysis_result_stock_names{$_}};
    }

    if (!scalar(@analysis_result_stock_names) >= 1){
        return;
    }

    return \@analysis_result_stock_names;
}

sub _get_unique_control_accession_names_from_trial {
    my $self = shift;
    my %design = %{$self->get_design()};
    my @control_names;
    my %unique_controls;
    no warnings 'numeric'; #for genotyping plate so that wells don't give warning

    foreach my $key (sort { $a <=> $b} keys %design) {
        my %design_info = %{$design{$key}};
        my $is_a_control = $design_info{"is_a_control"};
        if ($is_a_control) {
            $unique_controls{$design_info{"accession_name"}} = $design_info{"accession_id"}
        }
    }

    foreach (sort keys %unique_controls){
        push @control_names, {accession_name=>$_, stock_id=>$unique_controls{$_}};
    }

    if (!scalar(@control_names) >= 1){
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
    print STDERR "Check 2.3.4.1: ".localtime()."\n";
    my $self = shift;
    my $schema = $self->get_schema();
    my $project = $self->get_project();

    #Try to retrieve layout from cached json
    #my $trial_layout_json_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'trial_layout_json', 'project_property')->cvterm_id;
    #my $trial_has_plants_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project_has_plant_entries', 'project_property')->cvterm_id;
    my $trial_layout_json = $project->projectprops->find({ 'type_id' => $self->cvterm_id('trial_layout_json') });
    my $trial_has_plants = $project->projectprops->find({ 'type_id' => $self->cvterm_id('project_has_plant_entries') });

    my $design;

    if ($trial_layout_json) {
        $design = decode_json $trial_layout_json->value;
    }
    # print STDERR "\n_get_design_from_trial design: ".Dumper($design)."\n";
    if (keys(%$design)) {
        # print STDERR "WE HAVE TRIAL LAYOUT JSON!\n";
	    # print STDERR "TRIAL LAYOUT JSON IS: ".$trial_layout_json->value()."\n";

	    #Plant index number needs to be in the cached layout of trials that have plants. this serves a check to assure this.
	    if ($trial_has_plants){
		my @plot_values = values %$design;
		if (!exists($plot_values[0]->{plant_index_numbers})) {
		    print STDERR "Regenerating cache to include plants...\n";
		    $self->generate_and_cache_layout();
		} else {
		    print STDERR "TrialLayout from cache ".localtime."\n";
		    return $design;
		}
	    } else {
            print STDERR "TrialLayout from cache ".localtime."\n";
            return $design;
	    }
	} else {
	print STDERR "Regenerating cache...\n";
        my $design = $self->generate_and_cache_layout();
	    # print STDERR "_get_design_from_trial Generated DESIGN (and cached) : ".Dumper($design);
	return $design;
    }
}

sub generate_and_cache_layout {
    my $self = shift;
    print STDERR "TrialLayout generate layout ".localtime."\n";
    my $schema = $self->get_schema();
    my $plots_ref;
    my @plots;
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

    # my $genotyping_user_id;
    # my $genotyping_project_name;
    # if ($self->get_experiment_type eq 'genotyping_trial'){
    #     my $genotyping_user_id_row = $project
    #         ->search_related("nd_experiment_projects")
    #         ->search_related("nd_experiment")
    #         ->search_related("nd_experimentprops")
    #         ->find({ 'type.name' => 'genotyping_user_id' }, {join => 'type' });
    #     $genotyping_user_id = $genotyping_user_id_row->get_column("value") || "unknown";

    #     my $genotyping_project_name_row = $project
    #         ->search_related("nd_experiment_projects")
    #         ->search_related("nd_experiment")
    #         ->search_related("nd_experimentprops")
    #         ->find({ 'type.name' => 'genotyping_project_name' }, {join => 'type' });
    #     $genotyping_project_name = $genotyping_project_name_row->get_column("value") || "unknown";
    # }

    @plots = @{$plots_ref};

    my %design;

    #print STDERR "PLOTS: ".Dumper(\@plots);
    foreach my $plot (@plots) {
	$self->retrieve_plot_info($plot, \%design);
    }

    #print STDERR "DESIGN IN generate_and_cache_layout: ".Dumper(\%design);

    my $trial_layout_json_rs = $project->search_related('projectprops',{ 'type_id' => $self->cvterm_id('trial_layout_json') });
    while (my $t = $trial_layout_json_rs->next) {
        $t->delete();
    }

    $project->create_projectprops({
        'trial_layout_json' => encode_json(\%design)
				  });

    if ($self->get_verify_layout || $self->get_verify_physical_map){
        return \%verify_errors;
    }

    #print STDERR "DESIGN AS READ : ".Dumper(\%design);

    return \%design;
}


sub retrieve_plot_info {
    my $self = shift;
    my $plot = shift;
    my $design = shift;

    #print STDERR "retrieve_plot_info()... Working on plot ".$plot->uniquename()."\n";
    my %design_info;

    my $json = JSON->new();

    # if ($self->get_experiment_type eq 'genotyping_trial'){
    #     $design_info{genotyping_user_id} = $genotyping_user_id;
    #     #print STDERR "RETRIEVED: genotyping_user_id: $design{genotyping_user_id}\n";
    #     $design_info{genotyping_project_name} = $genotyping_project_name;
    #     #print STDERR "RETRIEVED: genotyping_project_name: $design{genotyping_project_name}\n";
    # }
    my $plot_name = $plot->uniquename;
    my $plot_id = $plot->stock_id;
    my $plot_properties = $plot->search_related('stockprops');
    my %stockprop_hash;
    while (my $r = $plot_properties->next){
	push @{$stockprop_hash{$r->type_id}}, $r->value;
    }
    my $plot_number_prop = $stockprop_hash{$self->cvterm_id('plot number')} ? join ',', @{$stockprop_hash{$self->cvterm_id('plot number')}} : undef;
    my $block_number_prop = $stockprop_hash{$self->cvterm_id('block')} ? join ',', @{$stockprop_hash{$self->cvterm_id('block')}} : undef;
    my $replicate_number_prop = $stockprop_hash{$self->cvterm_id('replicate')} ? join ',', @{$stockprop_hash{$self->cvterm_id('replicate')}} : undef;
    my $range_number_prop = $stockprop_hash{$self->cvterm_id('range')} ? join ',', @{$stockprop_hash{$self->cvterm_id('range')}} : undef;
    my $is_a_control_prop = $stockprop_hash{$self->cvterm_id('is a control')} ? join ',', @{$stockprop_hash{$self->cvterm_id('is a control')}} : undef;
    my $row_number_prop = $stockprop_hash{$self->cvterm_id('row_number')} ? join ',', @{$stockprop_hash{$self->cvterm_id('row_number')}} : undef;
    my $col_number_prop = $stockprop_hash{$self->cvterm_id('col_number')} ? join ',', @{$stockprop_hash{$self->cvterm_id('col_number')}} : undef;
    my $is_blank_prop = $stockprop_hash{$self->cvterm_id('is_blank')} ? join ',', @{$stockprop_hash{$self->cvterm_id('is_blank')}} : undef;
    my $well_concentration_prop = $stockprop_hash{$self->cvterm_id('concentration')} ? join ',', @{$stockprop_hash{$self->cvterm_id('concentration')}} : undef;
    my $well_volume_prop = $stockprop_hash{$self->cvterm_id('volume')} ? join ',', @{$stockprop_hash{$self->cvterm_id('volume')}} : undef;
    my $well_dna_person_prop = $stockprop_hash{$self->cvterm_id('dna_person')} ? join ',', @{$stockprop_hash{$self->cvterm_id('dna_person')}} : undef;
    my $well_extraction_prop = $stockprop_hash{$self->cvterm_id('extraction')} ? join ',', @{$stockprop_hash{$self->cvterm_id('extraction')}} : undef;
    my $well_tissue_type_prop = $stockprop_hash{$self->cvterm_id('tissue_type')} ? join ',', @{$stockprop_hash{$self->cvterm_id('tissue_type')}} : undef;
    my $well_acquisition_date_prop = $stockprop_hash{$self->cvterm_id('acquisition date')} ? join ',', @{$stockprop_hash{$self->cvterm_id('acquisition date')}} : undef;
    my $well_notes_prop = $stockprop_hash{$self->cvterm_id('notes')} ? join ',', @{$stockprop_hash{$self->cvterm_id('notes')}} : undef;
    my $well_ncbi_taxonomy_id_prop = $stockprop_hash{$self->cvterm_id('ncbi_taxonomy_id')} ? join ',', @{$stockprop_hash{$self->cvterm_id('ncbi_taxonomy_id')}} : undef;
    my $well_facility_identifier_prop = $stockprop_hash{$self->cvterm_id('facility_identifier')} ? join ',', @{$stockprop_hash{$self->cvterm_id('facility_identifier')}} : undef;
    my $plot_geo_json_prop = $stockprop_hash{$self->cvterm_id('plot_geo_json')} ? $stockprop_hash{$self->cvterm_id('plot_geo_json')}->[0] : undef;

    #print  STDERR "SORUCE STOCK TYPES: ".Dumper($self->get_source_stock_type_ids())."\n".Dumper($self->get_source_stock_types());
    #print STDERR "REL TYEPS = ".Dumper($self->get_relationship_types());
    my $source_primary_stock_type_ids = $self->get_source_primary_stock_type_ids();

    my $accession_rs = $plot->search_related('stock_relationship_subjects')->search(
	{ 'me.type_id' => { -in => $self->get_relationship_type_ids() }, 'object.type_id' => { -in => $self->get_source_primary_stock_type_ids() } },
	{ 'join' => 'object' }
	);

    # was: $plot_of_cvterm_id, $tissue_sample_of_cvterm_id, $analysis_of_cvterm_id
    if ($accession_rs->count != 1){
	die "There is more than one or no (".$accession_rs->count.") accession/cross/family_name linked  here!\n";
    }
    # if ($self->get_experiment_type eq 'genotyping_layout'){
    # 	my $source_rs = $plot->search_related('stock_relationship_subjects')->search(
    # 	    { 'me.type_id' => { -in => $self->get_relationship_type_ids() }, 'object.type_id' => { -in => $self->get_relationship_type_ids() } },
    # 	    # was $accession_cvterm_id, $plot_cvterm_id, $plant_cvterm_id, $tissue_cvterm_id, $subplot_cvterm_id
    # 	    { 'join' => 'object' }
    # 	    )->search_related('object');
    # 	while (my $r=$source_rs->next){
    # 	    if ($r->type_id == $self->cvterm_id('accession')){
    # 		$design_info{"source_accession_id"} = $r->stock_id;
    # 		$design_info{"source_accession_name"} = $r->uniquename;
    # 		$design_info{"source_observation_unit_name"} = $r->uniquename;
    # 		$design_info{"source_observation_unit_id"} = $r->stock_id;
    # 	    }
    # 	    if ($r->type_id == $self->cvterm_id('plot')){
    # 		$design_info{"source_plot_id"} = $r->stock_id;
    # 		$design_info{"source_plot_name"} = $r->uniquename;
    # 		$design_info{"source_observation_unit_name"} = $r->uniquename;
    # 		$design_info{"source_observation_unit_id"} = $r->stock_id;
    # 	    }
    # 	    if ($r->type_id == $self->cvterm_id('plant')){
    # 		$design_info{"source_plant_id"} = $r->stock_id;
    # 		$design_info{"source_plant_name"} = $r->uniquename;
    # 		$design_info{"source_observation_unit_name"} = $r->uniquename;
    # 		$design_info{"source_observation_unit_id"} = $r->stock_id;
    # 	    }
    # 	    if ($r->type_id == $self->cvterm_id('tissue')){
    # 		$design_info{"source_tissue_id"} = $r->stock_id;
    # 		$design_info{"source_tissue_name"} = $r->uniquename;
    # 		$design_info{"source_observation_unit_name"} = $r->uniquename;
    # 		$design_info{"source_observation_unit_id"} = $r->stock_id;
    # 	    }
    # 	}
    # 	my $organism_q = "SELECT species, genus FROM organism WHERE organism_id = ?;";
    # 	my $h = $self->get_schema->storage->dbh()->prepare($organism_q);
    # 	$h->execute($plot->organism_id);
    # 	my ($species, $genus) = $h->fetchrow_array;
    # 	$design_info{"species"} = $species;
    # 	$design_info{"genus"} = $genus;
    # }
    my $accession = $accession_rs->first->object;
    
    my $plants = $plot->search_related('stock_relationship_subjects', { 'me.type_id' => $self->cvterm_id('plant_of')})->search_related('object', {'object.type_id' => $self->cvterm_id('plant') }, {order_by=>"object.stock_id"});

    my $subplots = $plot->search_related('stock_relationship_subjects', { 'me.type_id' => $self->cvterm_id('subplot_of')})->search_related('object', {'object.type_id' => $self->cvterm_id('subplot')}, {order_by=>"object.stock_id"});
    my $tissues = $plot->search_related('stock_relationship_objects', { 'me.type_id' => $self->cvterm_id('tissue_sample_of') })->search_related('subject', {'subject.type_id' => $self->cvterm_id('tissue_sample')}, {order_by=>"subject.stock_id"});
    my $seedlot_transaction = $plot->search_related('stock_relationship_subjects', { 'me.type_id' => $self->cvterm_id('seed transaction'), 'object.type_id' => $self->cvterm_id('seedlot') }, {'join'=>'object', order_by=>"object.stock_id"});
    
    if ($seedlot_transaction->count > 0 && $seedlot_transaction->count != 1){
	    die "There is more than one seedlot linked here!\n";
	}


    my $accession_name = $accession->uniquename;
    my $accession_id = $accession->stock_id;

    $design_info{"plot_name"}=$plot_name;
    $design_info{"plot_id"}=$plot_id;

    my %unique_controls;
    my %unique_accessions;
    my %verify_errors;

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
    if ($self->get_experiment_type eq 'genotyping_layout'){
	if ($is_blank_prop) {
	    $design_info{"is_blank"}=1;
	} else {
	    $design_info{"is_blank"}=0;
	}
    }
    if ($well_concentration_prop){
	$design_info{"concentration"} = $well_concentration_prop;
    }
    if ($well_volume_prop){
	$design_info{"volume"} = $well_volume_prop;
    }
    if ($well_dna_person_prop){
	$design_info{"dna_person"} = $well_dna_person_prop;
    }
    if ($well_extraction_prop){
	$design_info{"extraction"} = $well_extraction_prop;
    }
    if ($well_tissue_type_prop){
	$design_info{"tissue_type"} = $well_tissue_type_prop;
    }
	if ($well_acquisition_date_prop){
	    $design_info{"acquisition_date"} = $well_acquisition_date_prop;
	}
    if ($well_notes_prop){
	$design_info{"notes"} = $well_notes_prop;
	}
    if ($well_ncbi_taxonomy_id_prop){
	$design_info{"ncbi_taxonomy_id"} = $well_ncbi_taxonomy_id_prop;
    }
    if ($well_facility_identifier_prop){
	$design_info{"facility_identifier"} = $well_facility_identifier_prop;
    }
    if ($replicate_number_prop) {
	$design_info{"rep_number"}=$replicate_number_prop;
    }
    if ($range_number_prop) {
	$design_info{"range_number"}=$range_number_prop;
    }
	if ($plot_geo_json_prop) {
	    $design_info{"plot_geo_json"} = decode_json $plot_geo_json_prop;
	}
    if ($is_a_control_prop) {
	    $design_info{"is_a_control"}=$is_a_control_prop;
	    $unique_controls{$accession_name}=$accession_id;
    }
    else {
	    $unique_accessions{$accession_name}=$accession_id;
    }

    my $type = $accession->type;
    # print STDERR "ABSTRACTLayout stock TYPE: ".$type->name."\n";
    # print STDERR "ABSTRACTLayout stock name: ".$accession_name."\n";
    if ($type->name eq 'analysis_result'){
        if ($accession_name) {
            $design_info{"analysis_result_stock_name"} = $accession_name;
        }

        if ($accession_id) {
            $design_info{"analysis_result_stock_id"} = $accession_id;
        }
    } else {
        if ($accession_name) {
            $design_info{"accession_name"} = $accession_name;
        }

        if ($accession_id) {
            $design_info{"accession_id"} = $accession_id;
        }
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
	    my $seedlot_accession_check = $seedlot->search_related('stock_relationship_objects', {'stock_relationship_objects.type_id'=>$self->cvterm_id('collection_of')})->search_related('subject', {'subject.stock_id'=>$accession_id, 'subject.type_id'=>$self->cvterm_id('accession')});
	    if (!$seedlot_accession_check->first){
		push @{$verify_errors{errors}->{layout_errors}}, "Seedlot: ".$seedlot->first->uniquename." does not have the same accession: $accession_name as the plot: $plot_name.";
	    }
	}
	$design_info{"seedlot_name"} = $seedlot->first->uniquename;
	$design_info{"seedlot_stock_id"} = $seedlot->first->stock_id;
	$design_info{"num_seed_per_plot"} = $val->{amount};
	$design_info{"weight_gram_seed_per_plot"} = $val->{weight_gram};
	$design_info{"seed_transaction_operator"} = $val->{operator};
    }
    if ($plants) {
	my @plant_names;
	my @plant_ids;
	my @plant_index_numbers;
	my %plants_tissue_hash;
	while (my $p = $plants->next()) {
	    if ($self->get_verify_layout){
		my $plant_accession_check = $p->search_related('stock_relationship_subjects', {'me.type_id'=>$self->cvterm_id('plant_of')})->search_related('object', {'object.stock_id'=>$accession_id, 'object.type_id'=>$self->cvterm_id('accession')});
		if (!$plant_accession_check->first){
		    push @{$verify_errors{errors}->{layout_errors}}, "Plant: ".$p->uniquename." does not have the same accession: $accession_name as the plot: $plot_name.";
		}
	    }
	    my $plant_name = $p->uniquename();
	    my $plant_id = $p->stock_id();
	    push @plant_names, $plant_name;
	    push @plant_ids, $plant_id;

	    my $plant_number_rs = $p->search_related('stockprops', {'me.type_id' => $self->cvterm_id('plant_index_number') });
	    if ($plant_number_rs->count != 1){
		print STDERR "Problem with plant_index_number stockprop for plant: $plant_name\n";
	    }
	    my $plant_index_number = $plant_number_rs->first->value;
	    push @plant_index_numbers, $plant_index_number;

	    my $tissues_of_plant = $p->search_related('stock_relationship_objects', { 'me.type_id' => $self->cvterm_id('tissue_sample_of') })->search_related('subject', {'subject.type_id'=>$self->cvterm_id('tissue_sample')});
	    while (my $t = $tissues_of_plant->next()){
		push @{$plants_tissue_hash{$plant_name}}, $t->uniquename();
	    }

	}
	$design_info{"plant_names"}=\@plant_names;
	$design_info{"plant_ids"}=\@plant_ids;
	$design_info{"plant_index_numbers"}=\@plant_index_numbers;
	$design_info{"plants_tissue_sample_names"}=\%plants_tissue_hash;
    }
    if ($tissues) {
	my @tissue_sample_names;
	my @tissue_sample_ids;
	my @tissue_sample_index_numbers;
	while (my $t = $tissues->next()) {
	    if ($self->get_verify_layout){
		my $tissue_accession_check = $t->search_related('stock_relationship_subjects', {'me.type_id'=>$self->cvterm_id('tissue_sample_of') })->search_related('object', {'object.stock_id'=>$accession_id, 'object.type_id'=>$self->cvterm_id('accession')});
		if (!$tissue_accession_check->first){
		    push @{$verify_errors{errors}->{layout_errors}}, "Tissue Sample: ".$t->uniquename." does not have the same accession: $accession_name as the plot: $plot_name.";
		}
	    }
	    my $tissue_name = $t->uniquename();
	    my $tissue_id = $t->stock_id();
	    push @tissue_sample_names, $tissue_name;
	    push @tissue_sample_ids, $tissue_id;

	    my $tissue_number_rs = $t->search_related('stockprops', {'me.type_id' => $self->cvterm_id('tissue_sample_index_number') });
	    if ($tissue_number_rs->count > 0) {
		if ($tissue_number_rs->count != 1){
		    print STDERR "Problem with tissue_sample_index_number stockprop for tissue_sample: $tissue_name\n";
		}
		my $tissue_sample_index_number = $tissue_number_rs->first->value;
		push @tissue_sample_index_numbers, $tissue_sample_index_number;
	    }
	}
	$design_info{"tissue_sample_names"}=\@tissue_sample_names;
	$design_info{"tissue_sample_ids"}=\@tissue_sample_ids;
	$design_info{"tissue_sample_index_numbers"}=\@tissue_sample_index_numbers;
    }
    if ($subplots) {
	my @subplot_names;
	my @subplot_ids;
	my @subplot_index_numbers;
	my %subplots_plants_hash;
	my %subplots_tissues_hash;
	while (my $p = $subplots->next()) {
	    if ($self->get_verify_layout){
		my $subplot_accession_check = $p->search_related('stock_relationship_subjects', {'me.type_id'=>$self->cvterm_id('subplot_of') })->search_related('object', {'object.stock_id'=>$accession_id, 'object.type_id'=>$self->cvterm_id('accession')});
		if (!$subplot_accession_check->first){
		    push @{$verify_errors{errors}->{layout_errors}}, "Subplot: ".$p->uniquename." does not have the same accession: $accession_name as the plot: $plot_name.";
		}
	    }
	    my $subplot_name = $p->uniquename();
	    my $subplot_id = $p->stock_id();
	    push @subplot_names, $subplot_name;
	    push @subplot_ids, $subplot_id;

	    my $subplot_number_rs = $p->search_related('stockprops', {'me.type_id' => $self->cvterm_id('subplot_index_number') });
	    if ($subplot_number_rs->count != 1){
		print STDERR "Problem with subplot_index_number stockprop for subplot: $subplot_name\n";
	    }
	    my $subplot_index_number = $subplot_number_rs->first->value;
	    push @subplot_index_numbers, $subplot_index_number;

	    my $plants_of_subplot = $p->search_related('stock_relationship_objects', { 'me.type_id' => $self->cvterm_id('plant_of_subplot') })->search_related('subject', {'subject.type_id'=>$self->cvterm_id('plant')});
	    while (my $pp = $plants_of_subplot->next()){
		push @{$subplots_plants_hash{$subplot_name}}, $pp->uniquename();
	    }

	    my $tissues_of_subplot = $p->search_related('stock_relationship_objects', { 'me.type_id' => $self->cvterm_id('tissue_sample_of') })->search_related('subject', {'subject.type_id'=>$self->cvterm_id('tissue_sample')});
	    while (my $t = $tissues_of_subplot->next()){
		push @{$subplots_tissues_hash{$subplot_name}}, $t->uniquename();
	    }
	}
	if (scalar(@subplot_names)>0){
	    $design_info{"subplot_names"}=\@subplot_names;
	    $design_info{"subplot_ids"}=\@subplot_ids;
	    $design_info{"subplot_index_numbers"}=\@subplot_index_numbers;
	    $design_info{"subplots_plant_names"}=\%subplots_plants_hash;
	    $design_info{"subplots_tissue_sample_names"}=\%subplots_tissues_hash;
	}
    }
    $design->{$plot_number_prop}=\%design_info;

}


sub _get_field_layout_experiment_from_project {
    my $self = shift;
    my $project;
    my $field_layout_experiment;
    $project = $self->get_project();
    if (!$project) {
	die "No project found for this instance!!!!\n";
	return;
    }
    $field_layout_experiment = $project
	->search_related("nd_experiment_projects")
	->search_related("nd_experiment")
   	->find({ 'type.name' => { in => ['field_layout', 'genotyping_layout', 'genotyping_experiment', 'treatment_experiment', 'analysis_experiment', 'sampling_layout']} }, {join => 'type' } );
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
	print STDERR "Have no trial_id, aborting...\n";
	return;
    }
    $project = $self->get_project();
    if (!$project) {
	print STDERR "Have no project row, aborting...\n";
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

    # get source stock types
    my $source_cvterm_ids = $self->get_source_stock_type_ids();
    print STDERR "EXP TYPE =".$self->get_experiment_type()."\n";

     # if ($self->get_experiment_type eq 'field_layout'){
     # 	$unit_type_id = $plot_cvterm_id;
     # }
     # if ($self->get_experiment_type eq 'genotyping_layout'){
     # 	$unit_type_id = $tissue_cvterm_id;
     # }
     # if ($self->get_experiment_type eq 'analysis_experiment') {
     # 	print STDERR "EXP TYPE = analysis_experiment ($analysis_instance_cvterm_id)... \n";
     # 	$unit_type_id = $analysis_instance_cvterm_id;
     # }
    @plots = $field_layout_experiment->nd_experiment_stocks->search_related('stock', {'stock.type_id' => {-in => $self->get_target_stock_type_ids()  } });

    #debug...
    # print STDERR "PLOT LIST: \n";
    # print STDERR  join( "\n", map { $_->name() } @plots)."\n";

    return \@plots;
}

sub _build_cvterm_hash {
    my $self = shift;

    print STDERR "Building cvterm has...\n";
    my %hash;

    my $stockprop_rs = $self->get_schema->resultset("Cv::Cvterm")->search( { 'cv.name' => { -in => [ 'stock_property', 'stock_type', 'experiment_property', 'experiment_type', 'stock_relationship', 'project_property', 'project_relationship' ] } }, { join => 'cv' });

    while (my $sp = $stockprop_rs->next()) {
	#print STDERR "Adding ".$sp->name()."...\n";
	if (exists($hash{ $sp->name() })) {
	    die "Duplicate term detected (".$sp->name()."). Sorry, but you cannot continue.";
	}
	$hash{ $sp->name() } = $sp->cvterm_id();
    }

    $self->set_cvterm_hash(\%hash);
}



    # $hash{accession} = SGN::Model::Cvterm->get_cvterm_row($self->get_schema(), "accession", "stock_type")->cvterm_id();
    # $hash{cross} = SGN::Model::Cvterm->get_cvterm_row($self->get_schema(), "cross", "stock_type")->cvterm_id();
    # $hash{family_name} = SGN::Model::Cvterm->get_cvterm_row($self->get_schema(), "family_name", "stock_type")->cvterm_id();
    # $hash{plot} = SGN::Model::Cvterm->get_cvterm_row($self->get_schema(), "plot", "stock_type")->cvterm_id();
    # $hash{plant} = SGN::Model::Cvterm->get_cvterm_row($self->get_schema(), "plant", "stock_type")->cvterm_id();
    # $hash{subplot} = SGN::Model::Cvterm->get_cvterm_row($self->get_schema(), "subplot", "stock_type")->cvterm_id();
    # $hash{seedlot} = SGN::Model::Cvterm->get_cvterm_row($self->get_schema(), "seedlot", "stock_type")->cvterm_id();
    # $hash{tissue_sample} = SGN::Model::Cvterm->get_cvterm_row($self->get_schema(), "tissue_sample", "stock_type")->cvterm_id();
    # $hash{plot_of} = SGN::Model::Cvterm->get_cvterm_row($self->get_schema(), "plot_of", "stock_relationship")->cvterm_id();
    # $hash{analysis_of} = SGN::Model::Cvterm->get_cvterm_row($self->get_schema(), "analysis_of", "stock_relationship");
    # $hash{tissue_sample_of} = SGN::Model::Cvterm->get_cvterm_row($self->get_schema(), "tissue_sample_of", "stock_relationship")->cvterm_id();
    # $hash{$plant_of} = SGN::Model::Cvterm->get_cvterm_row($self->get_schema, 'plant_of', 'stock_relationship' );
    # my $subplot_rel_cvterm = SGN::Model::Cvterm->get_cvterm_row($self->get_schema, 'subplot_of', 'stock_relationship' );
    # my $subplot_rel_cvterm_id = $subplot_rel_cvterm->cvterm_id();
    # my $plant_rel_cvterm_id = $plant_rel_cvterm->cvterm_id();
    # my $analysis_of_cvterm_id = $analysis_of_cv->cvterm_id();


    # my $plant_of_subplot_rel_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->get_schema, 'plant_of_subplot', 'stock_relationship' )->cvterm_id();
    # my $seed_transaction_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->get_schema, 'seed transaction', 'stock_relationship' )->cvterm_id();
    # my $collection_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->get_schema, 'collection_of', 'stock_relationship' )->cvterm_id();
    # my $plot_number_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->get_schema, 'plot number', 'stock_property' )->cvterm_id();
    # my $plant_number_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->get_schema, 'plant_index_number', 'stock_property' )->cvterm_id();
    # my $tissue_number_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->get_schema, 'tissue_sample_index_number', 'stock_property' )->cvterm_id();
    # my $subplot_number_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->get_schema, 'subplot_index_number', 'stock_property' )->cvterm_id();
    # my $block_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->get_schema, 'block', 'stock_property' )->cvterm_id();
    # my $replicate_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->get_schema, 'replicate', 'stock_property' )->cvterm_id();
    # my $range_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->get_schema, 'range', 'stock_property' )->cvterm_id();
    # my $is_a_control_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->get_schema, 'is a control', 'stock_property' )->cvterm_id();
    # my $row_number_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->get_schema, 'row_number', 'stock_property' )->cvterm_id();
    # my $col_number_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->get_schema, 'col_number', 'stock_property' )->cvterm_id();
    # my $is_blank_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->get_schema, 'is_blank', 'stock_property' )->cvterm_id();
    # my $concentration_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->get_schema, 'concentration', 'stock_property')->cvterm_id();
    # my $volume_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->get_schema, 'volume', 'stock_property')->cvterm_id();
    # my $dna_person_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->get_schema, 'dna_person', 'stock_property')->cvterm_id();
    # my $extraction_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->get_schema, 'extraction', 'stock_property')->cvterm_id();
    # my $tissue_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->get_schema, 'tissue_type', 'stock_property')->cvterm_id();
    # my $acquisition_date_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->get_schema, 'acquisition date', 'stock_property')->cvterm_id();
    # my $notes_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->get_schema, 'notes', 'stock_property')->cvterm_id();
    # my $ncbi_taxonomy_id_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->get_schema, 'ncbi_taxonomy_id', 'stock_property')->cvterm_id();
    # my $plot_geo_json_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->get_schema, 'plot_geo_json', 'stock_property' )->cvterm_id();
#    print STDERR "Done.\n";
#}


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

__PACKAGE__->meta->make_immutable;

#######
1;
#######
