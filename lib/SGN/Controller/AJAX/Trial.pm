
=head1 NAME

SGN::Controller::AJAX::Trial - a REST controller class to provide the
backend for adding trials and viewing trials

=head1 DESCRIPTION

Creating, viewing and deleting trials

=head1 AUTHOR

Jeremy Edwards <jde22@cornell.edu>


=cut

package SGN::Controller::AJAX::Trial;

use Moose;
use utf8;
use Try::Tiny;
use Scalar::Util qw(looks_like_number);
use DateTime;
use File::Basename qw | basename dirname|;
use File::Copy;
use File::Slurp;
use File::Spec::Functions;
use Digest::MD5;
use List::MoreUtils qw /any /;
use Data::Dumper;
use CXGN::Trial;
use CXGN::Trial::TrialDesign;
use CXGN::Trial::TrialCreate;
use SGN::View::Trial qw/design_layout_view design_info_view design_layout_map_view/;
use CXGN::Location::LocationLookup;
use CXGN::Stock::StockLookup;
use CXGN::Trial::TrialLayout;
use CXGN::BreedersToolbox::Projects;
use CXGN::BreedersToolbox::Delete;
use CXGN::UploadFile;
use CXGN::Trial::ParseUpload;
use CXGN::List::Transform;
use CXGN::List::Validate;
use SGN::Model::Cvterm;
use JSON::XS;
use CXGN::BreedersToolbox::Accessions;
use CXGN::BreederSearch;
use YAML;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON'  },
   );

has 'schema' => (
		 is       => 'rw',
		 isa      => 'DBIx::Class::Schema',
		 lazy_build => 1,
		);


sub generate_experimental_design : Path('/ajax/trial/generate_experimental_design') : ActionClass('REST') { }

sub generate_experimental_design_POST : Args(0) {
    my ($self, $c) = @_;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $trial_design = CXGN::Trial::TrialDesign->new();
    my %design;
    my %design_info;
    my $error;
    my $project_name = $c->req->param('project_name');
    my $project_description = $c->req->param('project_description');
    my $year = $c->req->param('year');
    my $trial_stock_type = $c->req->param('trial_stock_type');
    my @stock_names;
    my $design_layout_view_html;
    my $design_info_view_html;
    my $design_map_view;
    if ($c->req->param('stock_list')) {
	@stock_names = @{_parse_list_from_json($c->req->param('stock_list'))};
    }
    my $seedlot_hash_json = $c->req->param('seedlot_hash');
    my @control_names;
    if ($c->req->param('control_list')) {
        @control_names = @{_parse_list_from_json($c->req->param('control_list'))};
    }

    my @control_names_crbd;
    if ($c->req->param('control_list_crbd')) {
        @control_names_crbd = @{_parse_list_from_json($c->req->param('control_list_crbd'))};
    }

    my $design_type =  $c->req->param('design_type');
    my $rep_count =  $c->req->param('rep_count');
    my $block_number =  $c->req->param('block_number');

    my $row_number = $c->req->param('row_number');
    my $block_row_number=$c->req->param('row_number_per_block');
    my $block_col_number=$c->req->param('col_number_per_block');
    my $col_number =$c->req->param('col_number');

    my $block_size =  $c->req->param('block_size');
    my $max_block_size =  $c->req->param('max_block_size');
    my $plot_prefix =  $c->req->param('plot_prefix');
    my $start_number =  $c->req->param('start_number');
    my $increment =  $c->req->param('increment') ? $c->req->param('increment') : 1;
    my $trial_location = $c->req->param('trial_location');
    my $fieldmap_col_number = $c->req->param('fieldmap_col_number');
    my $fieldmap_row_number = $c->req->param('fieldmap_row_number');
    my $plot_layout_format = $c->req->param('plot_layout_format');
    my @treatments = $c->req->param('treatments[]');
    my $num_plants_per_plot = $c->req->param('num_plants_per_plot');
    my $num_seed_per_plot = $c->req->param('num_seed_per_plot');
    my $westcott_check_1 = $c->req->param('westcott_check_1');
    my $westcott_check_2 = $c->req->param('westcott_check_2');
    my $westcott_col = $c->req->param('westcott_col');
    my $westcott_col_between_check = $c->req->param('westcott_col_between_check');
    my $field_size = $c->req->param('field_size');
    my $plot_width = $c->req->param('plot_width');
    my $plot_length = $c->req->param('plot_length');

    if ( !$start_number ) {
        $c->stash->{rest} = { error => "You need to select the starting plot number."};
        return;
    }

    if ($design_type eq 'Westcott'){
        if (!$westcott_check_1){
            $c->stash->{rest} = { error => "You need to provide name of check 1 for westcott design."};
            return;
        }
        if (!$westcott_check_2){
            $c->stash->{rest} = { error => "You need to provide name of check 2 for westcott design."};
            return;
        }
        if (!$westcott_col){
            $c->stash->{rest} = { error => "You need to provide number of columns for westcott design."};
            return;
        }
        push @control_names_crbd, $westcott_check_1;
        push @control_names_crbd, $westcott_check_2;
    }

    if ($design_type eq 'splitplot'){
        if (scalar(@treatments)<1){
            $c->stash->{rest} = { error => "You need to provide at least one treatment for a splitplot design."};
            return;
        }
        if (!$num_plants_per_plot){
            $c->stash->{rest} = { error => "You need to provide number of plants per treatment for a splitplot design."};
            return;
        }
        if ($num_plants_per_plot <1){
            $c->stash->{rest} = { error => "You need to provide number of plants per treatment for a splitplot design."};
            return;
        }
    }

    my $row_in_design_number = $c->req->param('row_in_design_number');
    my $col_in_design_number = $c->req->param('col_in_design_number');
    my $no_of_rep_times = $c->req->param('no_of_rep_times');
    my $no_of_block_sequence = $c->req->param('no_of_block_sequence');
    my $unreplicated_stock_list = $c->req->param('unreplicated_stock_list');
    my $replicated_stock_list = $c->req->param('replicated_stock_list');
    my $no_of_sub_block_sequence = $c->req->param('no_of_sub_block_sequence');

    my @replicated_stocks;
    if ($c->req->param('replicated_stock_list')) {
        @replicated_stocks = @{_parse_list_from_json($c->req->param('replicated_stock_list'))};
    }
    my $number_of_replicated_stocks = scalar(@replicated_stocks);

    my @unreplicated_stocks;
    if ($c->req->param('unreplicated_stock_list')) {
        @unreplicated_stocks = @{_parse_list_from_json($c->req->param('unreplicated_stock_list'))};
    }
    my $number_of_unreplicated_stocks = scalar(@unreplicated_stocks);

    my $greenhouse_num_plants = $c->req->param('greenhouse_num_plants');
    my $use_same_layout = $c->req->param('use_same_layout');
    my $number_of_checks = scalar(@control_names_crbd);

    if ($design_type eq "RCBD" || $design_type eq "Alpha" || $design_type eq "CRD" || $design_type eq "Lattice") {
        if (@control_names_crbd) {
            @stock_names = (@stock_names, @control_names_crbd);
        }
    }

    my $number_of_prep_stocks = scalar(@stock_names);
    my $p_rep_total_plots;
    my $replicated_plots;
    my $unreplicated_plots;
    my $calculated_total_plot;

    if($design_type eq "p-rep"){
        @stock_names = (@replicated_stocks, @unreplicated_stocks);
    #}

        $number_of_prep_stocks = scalar(@stock_names);
        $p_rep_total_plots = $row_in_design_number * $col_in_design_number;
        $replicated_plots = $no_of_rep_times * $number_of_replicated_stocks;
        $unreplicated_plots = scalar(@unreplicated_stocks);
        $calculated_total_plot = $replicated_plots + $unreplicated_plots;
    }

    my @locations;

    try {
	my $json = JSON::XS->new();
        my $multi_location = $json->decode($trial_location);
        foreach my $loc (@$multi_location) {
            push @locations, $loc;
        }
    }
    catch {
        push @locations, $trial_location;
    };

    my $location_number = scalar(@locations);

    if (!$c->user()) {
        $c->stash->{rest} = {error => "You need to be logged in to add a trial" };
        return;
    }

    if (!any { $_ eq "curator" || $_ eq "submitter" } ($c->user()->roles)  ) {  #user must have privileges to add a trial
        $c->stash->{rest} = {error =>  "You have insufficient privileges to add a trial." };
        return;
    }
    #print "TOTAL PLOTS $p_rep_total_plots AND CALCULATED PLOTS $calculated_total_plot\n";
    if($p_rep_total_plots != $calculated_total_plot){
        $c->stash->{rest} = {error => "Treatment repeats do not equal number of plots in design" };
        return;
    }

    my @design_array;
    my @design_layout_view_html_array;
    my $json = JSON::XS->new();

    foreach my $location (@locations) {
        my $trial_name = $c->req->param('project_name');
        my $geolocation_lookup = CXGN::Location::LocationLookup->new(schema => $schema);

        $geolocation_lookup->set_location_name($location);
        if (!$geolocation_lookup->get_geolocation()){
            $c->stash->{rest} = { error => "Trial location not found" };
            return;
        }

        if ($location_number > 1) {

            # Add location abbreviation or name to trial name
            my $location_id = $geolocation_lookup->get_geolocation()->nd_geolocation_id();
            my $location_object = CXGN::Location->new( {
                bcs_schema => $schema,
                nd_geolocation_id => $location_id,
            });

            my $abbreviation = $location_object->abbreviation();

            if ($abbreviation) {
                $trial_name = $trial_name.$abbreviation;
            } else {
                $trial_name = $trial_name.$location;
            }
        }

        #strip name of any invalid filename characters
        $trial_name =~ s/[\\\/\s:,"*?<>|]+//;
        $trial_design->set_trial_name($trial_name);

        my $design_created = 0;
        if ($use_same_layout) {
            $design_created = 1;
        }

        if ($design_created) {
            $trial_design->set_randomization_seed($design_created);
        }

        if (@stock_names) {
            $trial_design->set_stock_list(\@stock_names);
            $design_info{'number_of_stocks'} = scalar(@stock_names);
        } else {
            $c->stash->{rest} = {error => "No list of stocks supplied." };
            return;
        }
        if ($seedlot_hash_json){
            $trial_design->set_seedlot_hash($json->decode($seedlot_hash_json));
        }
        if ($num_seed_per_plot){
            $trial_design->set_num_seed_per_plot($num_seed_per_plot);
        }
        if (@control_names) {
            $trial_design->set_control_list(\@control_names);
            $design_info{'number_of_controls'} = scalar(@control_names);
        }
        if (@control_names_crbd) {
            $trial_design->set_control_list_crbd(\@control_names_crbd);
            $design_info{'number_of_controls_crbd'} = scalar(@control_names_crbd);
        }
        if ($start_number) {
            $trial_design->set_plot_start_number($start_number);
        } else {
            $trial_design->clear_plot_start_number();
        }
        if ($increment) {
            $trial_design->set_plot_number_increment($increment);
        } else {
            $trial_design->clear_plot_number_increment();
        }
        if ($plot_prefix) {
            $trial_design->set_plot_name_prefix($plot_prefix);
        }
        if ($rep_count) {
            $trial_design->set_number_of_reps($rep_count);
        }
        if ($block_number) {
            $trial_design->set_number_of_blocks($block_number);
        }
        if($row_number){
            $trial_design->set_number_of_rows($row_number);
        }
        if($block_row_number){
            $trial_design->set_block_row_numbers($block_row_number);
        }
        if($block_col_number){
            $trial_design->set_block_col_numbers($block_col_number);
        }
        if($col_number){
            $trial_design->set_number_of_cols($col_number);
        }
        if ($block_size) {
            $trial_design->set_block_size($block_size);
        }
        if ($max_block_size) {
            $trial_design->set_maximum_block_size($max_block_size);
        }
        if ($greenhouse_num_plants) {
            my $json = JSON::XS->new();
            $trial_design->set_greenhouse_num_plants($json->decode($greenhouse_num_plants));
        }
        if ($westcott_check_1){
            $trial_design->set_westcott_check_1($westcott_check_1);
        }
        if ($westcott_check_2){
            $trial_design->set_westcott_check_2($westcott_check_2);
        }
        if ($westcott_col){
            $trial_design->set_westcott_col($westcott_col);
        }
        if ($westcott_col_between_check){
            $trial_design->set_westcott_col_between_check($westcott_col_between_check);
        }
        if ($location_number) {
            $design_info{'number_of_locations'} = $location_number;
        }
        if($number_of_checks){
            $design_info{'number_of_checks'} = $number_of_checks;
        }
        if ($design_type) {
            $trial_design->set_design_type($design_type);
            $design_info{'design_type'} = $design_type;
        } else {
            $c->stash->{rest} = {error => "No design type supplied." };
            return;
        }
        if (!$trial_design->has_design_type()) {
            $c->stash->{rest} = {error => "Design type not supported." };
            return;
        }
        if ($fieldmap_col_number) {
            $trial_design->set_fieldmap_col_number($fieldmap_col_number);
        }
        if ($fieldmap_row_number) {
            $trial_design->set_fieldmap_row_number($fieldmap_row_number);
        }
        if ($plot_layout_format) {
            $trial_design->set_plot_layout_format($plot_layout_format);
        }
        if ($number_of_replicated_stocks) {
            $trial_design->set_replicated_stock_no($number_of_replicated_stocks);
        }
        if ($number_of_unreplicated_stocks) {
            $trial_design->set_unreplicated_stock_no($number_of_unreplicated_stocks);
        }
        if ($row_in_design_number) {
            $trial_design->set_row_in_design_number($row_in_design_number);
        }
        if ($col_in_design_number) {
            $trial_design->set_col_in_design_number($col_in_design_number);
        }
        if ($no_of_rep_times) {
            $trial_design->set_num_of_replicated_times($no_of_rep_times);
        }
        if ($no_of_block_sequence) {
            $trial_design->set_block_sequence($no_of_block_sequence);
        }
        if ($no_of_sub_block_sequence) {
            $trial_design->set_sub_block_sequence($no_of_sub_block_sequence);
        }

        if (scalar(@treatments)>0) {
            $trial_design->set_treatments(\@treatments);
        }
        if($num_plants_per_plot){
            $trial_design->set_num_plants_per_plot($num_plants_per_plot);
        }

        try {
            $trial_design->calculate_design();
        } catch {
            $c->stash->{rest} = {error => "Could not calculate design: $_"};
            $error=1;
        };
        if ($error) {
            return;
        }
        if ($trial_design->get_design()) {
            %design = %{$trial_design->get_design()};
        } else {
            $c->stash->{rest} = {error => "Could not generate design" };
            return;
        }

        #For printing the table view of the generated design there are two designs that are different from the others:
        # 1. the greenhouse can use accessions or crosses, so the table should reflect that. the greenhouse generates plant and plot entries so the table should reflect that.
        # 2. the splitplot generates plots, subplots, and plant entries, so the table should reflect that.
        $design_layout_view_html = design_layout_view(\%design, \%design_info, $design_type, $trial_stock_type);
        $design_map_view = design_layout_map_view(\%design, $design_type);
        $design_info_view_html = design_info_view(\%design, \%design_info, $trial_stock_type);
        my $design_json = $json->encode(\%design);
        push @design_array,  $design_json;
        push @design_layout_view_html_array, $design_layout_view_html;
    }

    my $warning_message;
    #check if field size can fit the design_json
    if ($field_size && $plot_width && $plot_length){
        my $num_plots = scalar( keys %{$json->decode($design_array[0])} );
        my $total_area = $plot_width * $plot_length * $num_plots; #sq meters. 1 ha = 10000m2
        my $field_size_m = $field_size * 10000;
        if ($field_size_m < $total_area){
            $warning_message = "The generated design would require atleast $total_area square meters, which is larger than the $field_size hectare ($field_size_m square meters) field size you indicated.";
        } else {
            $warning_message = "The generated design would require atleast $total_area square meters and your field size is $field_size hectare ($field_size_m square meters).";
        }
    }

    $c->stash->{rest} = {
        success => "1",
        design_layout_view_html => $json->encode(\@design_layout_view_html_array),
        design_info_view_html => $design_info_view_html,
        design_map_view => $design_map_view,
        design_json =>  $json->encode(\@design_array),
        warning_message => $warning_message
    };
}

sub test_controller : Path('ajax/trial/test_controller/') : ActionClass('REST') {
    my $self = shift;
    my $c = shift;
    $c->stash->{rest} = {success => $c};
    $c->stash->{rest} = {error => $c};
    return $c;
}

sub save_experimental_design : Path('/ajax/trial/save_experimental_design') : ActionClass('REST') { }

sub save_experimental_design_POST : Args(0) {
    my ($self, $c) = @_;
    my $chado_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $dbh = $c->dbc->dbh;
    my $save;

    print STDERR "Saving trial... :-)\n";

    if (!$c->user()) {
        $c->stash->{rest} = {error => "You need to be logged in to add a trial" };
        return;
    }
    if (!any { $_ eq "curator" || $_ eq "submitter" } ($c->user()->roles)  ) {
        $c->stash->{rest} = {error =>  "You have insufficient privileges to add a trial." };
        return;
    }
    my $user_id = $c->user()->get_object()->get_sp_person_id();

    my $user_name = $c->user()->get_object()->get_username();
    my $error;

    my $design = _parse_design_from_json($c->req->param('design_json'));
    #print STDERR "\nDesign: " . Dumper $design;

    my @locations;
    my $multi_location;
    #print STDERR Dumper $c->req->params();
    my $locations = $c->req->param('trial_location');
    my $trial_name = $c->req->param('project_name');
    my $trial_type = $c->req->param('trial_type');
    my $breeding_program = $c->req->param('breeding_program_name');
    my $trial_stock_type = $c->req->param('trial_stock_type');
    my $field_size = $c->req->param('field_size');
    my $plot_width = $c->req->param('plot_width');
    my $plot_length = $c->req->param('plot_length');
    my $field_trial_is_planned_to_be_genotyped = $c->req->param('field_trial_is_planned_to_be_genotyped') || 'No';
    my $field_trial_is_planned_to_cross = $c->req->param('field_trial_is_planned_to_cross') || 'No';
    my @add_project_trial_source = $c->req->param('add_project_trial_source[]');
    my $add_project_trial_genotype_trial;
    my $add_project_trial_crossing_trial;
    my $add_project_trial_genotype_trial_select = [$add_project_trial_genotype_trial];
    my $add_project_trial_crossing_trial_select = [$add_project_trial_crossing_trial];

    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $breeding_program_id = $schema->resultset("Project::Project")->find({name=>$breeding_program})->project_id();
    my $folder;
    my $new_trial_id;

    my $json = JSON::XS->new();
    try {
        $multi_location = $json->decode($locations);
        foreach my $loc (@$multi_location) {
            push @locations, $loc;
        }
    }
    catch {
        push @locations, $locations;
    };
    my $folder_id;
    my $parent_folder_id = 0;
    if (scalar(@locations) > 1) {

        my $existing = $schema->resultset("Project::Project")->find( { name => $trial_name });
        if ($existing) {
            $c->stash->{rest} = { error => "A folder or trial with that name already exists in the database. Please select another name." };
            return;
        }

        $folder = CXGN::Trial::Folder->create({
            bcs_schema => $schema,
            parent_folder_id => $parent_folder_id,
            name => $trial_name,
            breeding_program_id => $breeding_program_id,
            folder_for_trials => 1
        });
        $folder_id = $folder->folder_id();
    }

    my $design_index = 0;

    foreach my $trial_location (@locations) {
        my $trial_name = $c->req->param('project_name');

        if (scalar(@locations) > 1) {
            my $geolocation_lookup = CXGN::Location::LocationLookup->new(schema => $schema);

            $geolocation_lookup->set_location_name($trial_location);
            my $location_id = $geolocation_lookup->get_geolocation()->nd_geolocation_id();
            my $location_object = CXGN::Location->new( {
                bcs_schema => $schema,
                nd_geolocation_id => $location_id,
            });
            my $abbreviation = $location_object->abbreviation();

            if ($abbreviation) {
                $trial_name = $trial_name.$abbreviation;
            } else {
                $trial_name = $trial_name.$trial_location;
            }
        }

        #strip name of any invalid filename characters
        $trial_name =~ s/[\\\/\s:,"*?<>|]+//;

        my $trial_location_design = $json->decode($design->[$design_index]);

        my %trial_info_hash = (
            chado_schema => $chado_schema,
            dbh => $dbh,
            design => $trial_location_design,
            program => $breeding_program,
            trial_year => $c->req->param('year'),
            trial_description => $c->req->param('project_description'),
            trial_location => $trial_location,
            trial_name => $trial_name,
            design_type => $c->req->param('design_type'),
            trial_type => $trial_type,
            trial_has_plant_entries => $c->req->param('has_plant_entries'),
            trial_has_subplot_entries => $c->req->param('has_subplot_entries'),
            operator => $user_name,
            owner_id => $user_id,
            field_trial_is_planned_to_cross => $field_trial_is_planned_to_cross,
            field_trial_is_planned_to_be_genotyped => $field_trial_is_planned_to_be_genotyped,
            field_trial_from_field_trial => \@add_project_trial_source,
            genotyping_trial_from_field_trial => $add_project_trial_genotype_trial_select,
            crossing_trial_from_field_trial => $add_project_trial_crossing_trial_select,
            trial_stock_type => $trial_stock_type,
        );

        if ($field_size){
            $trial_info_hash{field_size} = $field_size;
        }
        if ($plot_width){
            $trial_info_hash{plot_width} = $plot_width;
        }
        if ($plot_length){
            $trial_info_hash{plot_length} = $plot_length;
        }
        my $trial_create = CXGN::Trial::TrialCreate->new(\%trial_info_hash);

        if ($trial_create->trial_name_already_exists()) {
            $c->stash->{rest} = {error => "Trial name \"".$trial_create->get_trial_name()."\" already exists" };
            return;
        }

        try {
            $save = $trial_create->save_trial();
        } catch {
            $save->{'error'} = $_;
        };

        if ($save->{'error'}) {
            if (scalar(@locations) > 1){
                my $folder = CXGN::Trial::Folder->new({
                    bcs_schema => $chado_schema,
                    folder_id => $folder_id,
                });
                my $delete_folder = $folder->delete_folder();
            }
            print STDERR "Error saving trial: ".$save->{'error'};
            $c->stash->{rest} = {error => $save->{'error'}};
            return;
        } elsif ($save->{'trial_id'}) {

            $design_index++;

            if ($folder_id) {
                my $folder1 = CXGN::Trial::Folder->new({
                    bcs_schema => $chado_schema,
                    folder_id => $save->{'trial_id'},
                });
                $folder1->associate_parent($folder_id);
            }
        }
    }
    
    my $bs = CXGN::BreederSearch->new( { dbh=>$dbh, dbname=>$c->config->{dbname}, } );
    my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'fullview', 'concurrent', $c->config->{basepath});

    $c->stash->{rest} = {success => "1", trial_id => $save->{'trial_id'}};
    return;
}


sub verify_trial_name : Path('/ajax/trial/verify_trial_name') : ActionClass('REST') { }

sub verify_trial_name_GET : Args(0) {
    my ($self, $c) = @_;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $trial_name = $c->req->param('trial_name');
    my $error;
    my %errors;

    if (!$trial_name) {
        $c->stash->{rest} = {error => "No trial name supplied"};
        $c->detach;
    }

    my $project_rs = $schema->resultset('Project::Project')->find({name=>$trial_name});

    if ($project_rs){
        my $error = 'The following trial name has aready been used. Please use a unique name';
        $c->stash->{rest} = {error => $error};
    } else {
        $c->stash->{rest} = {
            success => "1",
        };
    }
}

sub verify_stock_list : Path('/ajax/trial/verify_stock_list') : ActionClass('REST') { }

sub verify_stock_list_POST : Args(0) {
    my ($self, $c) = @_;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my @stock_names;
    my $error;
    my %errors;
    if ($c->req->param('stock_list')) {
        @stock_names = @{_parse_list_from_json($c->req->param('stock_list'))};
    }

    if (!@stock_names) {
        $c->stash->{rest} = {error => "No stock names supplied"};
        $c->detach;
    }

    my $lv = CXGN::List::Validate->new();
    my @accessions_missing = @{$lv->validate($schema,'accessions',\@stock_names)->{'missing'}};

    if (scalar(@accessions_missing) > 0){
        my $error = 'The following accessions are not valid in the database, so you must add them first: '.join ',', @accessions_missing;
        $c->stash->{rest} = {error => $error};
    } else {
        $c->stash->{rest} = {
            success => "1",
        };
    }
}

sub verify_cross_list : Path('/ajax/trial/verify_cross_list') : ActionClass('REST') { }

sub verify_cross_list_POST : Args(0) {
    my ($self, $c) = @_;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my @stock_names;
    my $error;
    my %errors;
    if ($c->req->param('cross_list')) {
        @stock_names = @{_parse_list_from_json($c->req->param('cross_list'))};
    }

    if (!@stock_names) {
        $c->stash->{rest} = {error => "No stock names supplied"};
        $c->detach;
    }

    my $lv = CXGN::List::Validate->new();
    my @crosses_missing = @{$lv->validate($schema,'crosses',\@stock_names)->{'missing'}};
    if (scalar(@crosses_missing) > 0){
        my $error = 'The following crosses are not valid in the database, so you must add them first: '.join ',', @crosses_missing;
        $c->stash->{rest} = {error => $error};
    } else {
        $c->stash->{rest} = {
            success => "1",
        };
    }
}

sub verify_family_name_list : Path('/ajax/trial/verify_family_name_list') : ActionClass('REST') { }

sub verify_family_name_list_POST : Args(0) {
    my ($self, $c) = @_;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my @stock_names;
    my $error;
    my %errors;
    if ($c->req->param('family_name_list')) {
        @stock_names = @{_parse_list_from_json($c->req->param('family_name_list'))};
    }

    if (!@stock_names) {
        $c->stash->{rest} = {error => "No stock names supplied"};
        $c->detach;
    }

    my $lv = CXGN::List::Validate->new();
    my @family_names_missing = @{$lv->validate($schema,'family_names',\@stock_names)->{'missing'}};
    if (scalar(@family_names_missing) > 0){
        my $error = 'The following family names are not valid in the database, so you must add them first: '.join ',', @family_names_missing;
        $c->stash->{rest} = {error => $error};
    } else {
        $c->stash->{rest} = {
            success => "1",
        };
    }
}

sub verify_seedlot_list : Path('/ajax/trial/verify_seedlot_list') : ActionClass('REST') { }

sub verify_seedlot_list_POST : Args(0) {
    my ($self, $c) = @_;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $people_schema = $c->dbic_schema('CXGN::People::Schema');
    my $phenome_schema = $c->dbic_schema('CXGN::Phenome::Schema');
    my @stock_names;
    my @seedlot_names;
    if ($c->req->param('stock_list')) {
        @stock_names = @{_parse_list_from_json($c->req->param('stock_list'))};
    }
    if ($c->req->param('seedlot_list')) {
        @seedlot_names = @{_parse_list_from_json($c->req->param('seedlot_list'))};
    }
    my $return = CXGN::Stock::Seedlot->verify_seedlot_stock_lists($schema, $people_schema, $phenome_schema, \@stock_names, \@seedlot_names);

    if (exists($return->{error})){
        $c->stash->{rest} = { error => $return->{error} };
        $c->detach();
    }
    if (exists($return->{success})){
        $c->stash->{rest} = {
            success => "1",
            seedlot_hash => $return->{seedlot_hash}
        };
    }
}

sub _parse_list_from_json {
    my $list_json = shift;
    my $json = JSON::XS->new();
    if ($list_json) {
        #my $decoded_list = $json->allow_nonref->relaxed->escape_slash->loose->allow_singlequote->allow_barekey->decode($list_json);
        my $decoded_list = $json->decode($list_json);
        my @array_of_list_items = @{$decoded_list};
        return \@array_of_list_items;
    }
    else {
        return;
    }
}

sub _parse_design_from_json {
    my $design_json = shift;
    my $json = JSON::XS->new();
    if ($design_json) {
        #my $decoded_json = $json->allow_nonref->utf8->relaxed->escape_slash->loose->allow_singlequote->allow_barekey->decode($design_json);
        my $decoded_json = $json->decode($design_json);
        #my %design = %{$decoded_json};
        return $decoded_json;
    }
    else {
        return;
    }
}

###################################################################################

sub upload_trial_file : Path('/ajax/trial/upload_trial_file') : ActionClass('REST') { }

sub upload_trial_file_POST : Args(0) {
    my ($self, $c) = @_;

    select(STDERR);
    $| = 1;

    print STDERR "Check 1: ".localtime()."\n";


    #print STDERR Dumper $c->req->params();
    my $chado_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $dbh = $c->dbc->dbh;
    my $program = $c->req->param('trial_upload_breeding_program');
    my $trial_location = $c->req->param('trial_upload_location');
    my $trial_name = $c->req->param('trial_upload_name');
    my $trial_year = $c->req->param('trial_upload_year');
    my $trial_type = $c->req->param('trial_upload_trial_type');
    my $trial_description = $c->req->param('trial_upload_description');
    my $trial_design_method = $c->req->param('trial_upload_design_method');
    my $field_size = $c->req->param('trial_upload_field_size');
    my $plot_width = $c->req->param('trial_upload_plot_width');
    my $plot_length = $c->req->param('trial_upload_plot_length');
    my $field_trial_is_planned_to_be_genotyped = $c->req->param('upload_trial_trial_will_be_genotyped');
    my $field_trial_is_planned_to_cross = $c->req->param('upload_trial_trial_will_be_crossed');
    my @add_project_trial_source = $c->req->param('upload_trial_trial_source_select');
    my $add_project_trial_genotype_trial;
    my $add_project_trial_crossing_trial;
    my $add_project_trial_genotype_trial_select = [$add_project_trial_genotype_trial];
    my $add_project_trial_crossing_trial_select = [$add_project_trial_crossing_trial];
    my $trial_stock_type = $c->req->param('trial_upload_trial_stock_type');

    my $upload = $c->req->upload('trial_uploaded_file');
    my $parser;
    my $parsed_data;
    my $upload_original_name = $upload->filename();
    my $upload_tempfile = $upload->tempname;
    my $subdirectory = "trial_upload";
    my $archived_filename_with_path;
    my $md5;
    my $validate_file;
    my $parsed_file;
    my $parse_errors;
    my %parsed_data;
    my %upload_metadata;
    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();
    my $user_id;
    my $user_name;
    my $error;
    my $save;

    print STDERR "Check 2: ".localtime()."\n";

    if ($upload_original_name =~ /\s/ || $upload_original_name =~ /\// || $upload_original_name =~ /\\/ ) {
        print STDERR "File name must not have spaces or slashes.\n";
        $c->stash->{rest} = {error => "Uploaded file name must not contain spaces or slashes." };
        return;
    }

    if (!$c->user()) {
        print STDERR "User not logged in... not uploading a trial.\n";
        $c->stash->{rest} = {error => "You need to be logged in to upload a trial." };
        return;
    }
    if (!any { $_ eq "curator" || $_ eq "submitter" } ($c->user()->roles)  ) {
        $c->stash->{rest} = {error =>  "You have insufficient privileges to upload a trial." };
        return;
    }

    $user_id = $c->user()->get_object()->get_sp_person_id();
    $user_name = $c->user()->get_object()->get_username();

    ## Store uploaded temporary file in archive
    my $uploader = CXGN::UploadFile->new({
        tempfile => $upload_tempfile,
        subdirectory => $subdirectory,
        archive_path => $c->config->{archive_path},
        archive_filename => $upload_original_name,
        timestamp => $timestamp,
        user_id => $user_id,
        user_role => $c->user->get_object->get_user_type()
    });
    $archived_filename_with_path = $uploader->archive();
    $md5 = $uploader->get_md5($archived_filename_with_path);
    if (!$archived_filename_with_path) {
        $c->stash->{rest} = {error => "Could not save file $upload_original_name in archive",};
        return;
    }
    unlink $upload_tempfile;

    print STDERR "Check 3: ".localtime()."\n";

    $upload_metadata{'archived_file'} = $archived_filename_with_path;
    $upload_metadata{'archived_file_type'}="trial upload file";
    $upload_metadata{'user_id'}=$user_id;
    $upload_metadata{'date'}="$timestamp";

    #parse uploaded file with appropriate plugin
    $parser = CXGN::Trial::ParseUpload->new(chado_schema => $chado_schema, filename => $archived_filename_with_path, trial_stock_type => $trial_stock_type);
    $parser->load_plugin('TrialExcelFormat');
    $parsed_data = $parser->parse();

    if (!$parsed_data) {
        my $return_error = '';

        if (! $parser->has_parse_errors() ){
            $return_error = "Could not get parsing errors";
            $c->stash->{rest} = {error_string => $return_error,};
        }
        else {
            $parse_errors = $parser->get_parse_errors();
            #print STDERR Dumper $parse_errors;

            foreach my $error_string (@{$parse_errors->{'error_messages'}}){
                $return_error .= $error_string."<br>";
            }
        }

        $c->stash->{rest} = {error_string => $return_error, missing_accessions => $parse_errors->{'missing_stocks'}, missing_seedlots => $parse_errors->{'missing_seedlots'}};
        return;
    }

    my $return_warnings;
    if ($parser->has_parse_warnings()) {
        my $warnings = $parser->get_parse_warnings();
        foreach my $warning_string (@{$warnings->{'warning_messages'}}){
            $return_warnings=$return_warnings.$warning_string."<br>";
        }
    }

    print STDERR "Check 4: ".localtime()."\n";

    #print STDERR Dumper $parsed_data;

    my $coderef = sub {

        my %trial_info_hash = (
            chado_schema => $chado_schema,
            dbh => $dbh,
            owner_id => $user_id,
            trial_year => $trial_year,
            trial_description => $trial_description,
            trial_location => $trial_location,
            trial_type => $trial_type,
            trial_name => $trial_name,
            design_type => $trial_design_method,
            design => $parsed_data,
            program => $program,
            upload_trial_file => $upload,
            operator => $user_name,
            owner_id => $user_id,
            field_trial_is_planned_to_cross => $field_trial_is_planned_to_cross,
            field_trial_is_planned_to_be_genotyped => $field_trial_is_planned_to_be_genotyped,
            field_trial_from_field_trial => \@add_project_trial_source,
            genotyping_trial_from_field_trial => $add_project_trial_genotype_trial_select,
            crossing_trial_from_field_trial => $add_project_trial_crossing_trial_select,
            trial_stock_type => $trial_stock_type
        );

        print STDERR "Trial type is ".$trial_info_hash{'trial_type'}."\n";

        if ($field_size){
            $trial_info_hash{field_size} = $field_size;
        }
        if ($plot_width){
            $trial_info_hash{plot_width} = $plot_width;
        }
        if ($plot_length){
            $trial_info_hash{plot_length} = $plot_length;
        }
        my $trial_create = CXGN::Trial::TrialCreate->new(\%trial_info_hash);
        $save = $trial_create->save_trial();

        if ($save->{error}){
            $chado_schema->txn_rollback();
        }

    };

    try {
        $chado_schema->txn_do($coderef);
    } catch {
        print STDERR "Transaction Error: $_\n";
        $save->{'error'} = $_;
    };

    #print STDERR "Check 5: ".localtime()."\n";
    if ($save->{'error'}) {
        print STDERR "Error saving trial: ".$save->{'error'};
        $c->stash->{rest} = {warnings => $return_warnings, error => $save->{'error'}};
        return;
    } elsif ($save->{'trial_id'}) {

        my $dbh = $c->dbc->dbh();
        my $bs = CXGN::BreederSearch->new( { dbh=>$dbh, dbname=>$c->config->{dbname}, } );
        my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'stockprop', 'concurrent', $c->config->{basepath});

        $c->stash->{rest} = {warnings => $return_warnings, success => "1", trial_id => $save->{'trial_id'}};
        return;
    }

}

sub upload_multiple_trial_designs_file : Path('/ajax/trial/upload_multiple_trial_designs_file') : ActionClass('REST') { }

sub upload_multiple_trial_designs_file_POST : Args(0) {
    my ($self, $c) = @_;

    # print STDERR "Check 1: ".localtime()."\n";

    # print STDERR Dumper $c->req->params();
    my $chado_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $dbh = $c->dbc->dbh;
    my $upload = $c->req->upload('multiple_trial_designs_upload_file');
    my $ignore_warnings = $c->req->param('upload_multiple_trials_ignore_warnings');
    my $parser;
    my $parsed_data;
    my $upload_original_name = $upload->filename();
    my $upload_tempfile = $upload->tempname;
    my $subdirectory = "trial_upload";
    my $archived_filename_with_path;
    my $md5;
    my $validate_file;
    my $parsed_file;
    my $parse_errors;
    my %parsed_data;
    my %upload_metadata;
    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();
    my $user_id;
    my $user_name;
    my $error;

    # print STDERR "Check 2: ".localtime()."\n";
    print STDERR "Ignore warnings is $ignore_warnings\n";
    if ($upload_original_name =~ /\s/ || $upload_original_name =~ /\// || $upload_original_name =~ /\\/ ) {
        print STDERR "File name must not have spaces or slashes.\n";
        $c->stash->{rest} = {errors => "Uploaded file name must not contain spaces or slashes." };
        return;
    }

    if (!$c->user()) {
        print STDERR "User not logged in... not uploading a trial.\n";
        $c->stash->{rest} = {errors => "You need to be logged in to upload a trial." };
        return;
    }
    if (!any { $_ eq "curator" || $_ eq "submitter" } ($c->user()->roles)  ) {
        $c->stash->{rest} = {errors =>  "You have insufficient privileges to upload a trial." };
        return;
    }

    $user_id = $c->user()->get_object()->get_sp_person_id();
    $user_name = $c->user()->get_object()->get_username();

    ## Store uploaded temporary file in archive
    my $uploader = CXGN::UploadFile->new({
        tempfile => $upload_tempfile,
        subdirectory => $subdirectory,
        archive_path => $c->config->{archive_path},
        archive_filename => $upload_original_name,
        timestamp => $timestamp,
        user_id => $user_id,
        user_role => $c->user->get_object->get_user_type()
    });
    $archived_filename_with_path = $uploader->archive();
    $md5 = $uploader->get_md5($archived_filename_with_path);
    if (!$archived_filename_with_path) {
        $c->stash->{rest} = {errors => "Could not save file $upload_original_name in archive",};
        return;
    }
    unlink $upload_tempfile;

    # print STDERR "Check 3: ".localtime()."\n";
    $upload_metadata{'archived_file'} = $archived_filename_with_path;
    $upload_metadata{'archived_file_type'}="trial upload file";
    $upload_metadata{'user_id'}=$user_id;
    $upload_metadata{'date'}="$timestamp";


    #parse uploaded file with appropriate plugin
    $parser = CXGN::Trial::ParseUpload->new(chado_schema => $chado_schema, filename => $archived_filename_with_path);
    $parser->load_plugin('MultipleTrialDesignExcelFormat');
    $parsed_data = $parser->parse();

    if (!$parsed_data) {
        my $return_error = '';

        if (! $parser->has_parse_errors() ){
            $c->stash->{rest} = {errors => "Could not get parsing errors"};
            return;
        }
        else {
            print STDERR "Parse errors are:\n";
            print STDERR Dumper $parse_errors;
            $parse_errors = $parser->get_parse_errors();
            $c->stash->{rest} = {errors => $parse_errors->{'error_messages'}};
            return;
        }
    }

    if ($parser->has_parse_warnings()) {
        unless ($ignore_warnings) {
            my $warnings = $parser->get_parse_warnings();
            $c->stash->{rest} = {warnings => $warnings->{'warning_messages'}};
            return;
        }
    }

    # print STDERR "Check 4: ".localtime()."\n";
    my %all_designs = %{$parsed_data};
    my %save;
    $save{'errors'} = [];

    my $coderef = sub {

      for my $trial_name ( keys %all_designs ) {
        my $trial_design = $all_designs{$trial_name};
        # print STDERR "\nSaving trial $trial_name:\n";
        my %trial_info_hash = (
            chado_schema => $chado_schema,
            dbh => $dbh,
            owner_id => $user_id,
            trial_year => $trial_design->{'year'},
            trial_description => $trial_design->{'description'},
            trial_location => $trial_design->{'location'},
            trial_name => $trial_name,
            design_type => $trial_design->{'design_type'},
            design => $trial_design->{'design_details'},
            program => $trial_design->{'breeding_program'},
            upload_trial_file => $upload,
            operator => $user_name,
            owner_id => $user_id
        );

        if ($trial_design->{'trial_type'}){
            $trial_info_hash{trial_type} = $trial_design->{'trial_type'};
        }
        if ($trial_design->{'plot_width'}){
            $trial_info_hash{plot_width} = $trial_design->{'plot_width'};
        }
        if ($trial_design->{'plot_length'}){
            $trial_info_hash{plot_length} = $trial_design->{'plot_length'};
        }
        if ($trial_design->{'field_size'}){
            $trial_info_hash{field_size} = $trial_design->{'field_size'};
        }
        if ($trial_design->{'planting_date'}){
            $trial_info_hash{planting_date} = $trial_design->{'planting_date'};
        }
        if ($trial_design->{'harvest_date'}){
            $trial_info_hash{harvest_date} = $trial_design->{'harvest_date'};
        }

        my $trial_create = CXGN::Trial::TrialCreate->new(\%trial_info_hash);
        my $current_save = $trial_create->save_trial();

        if ($current_save->{error}){
            $chado_schema->txn_rollback();
            push @{$save{'errors'}}, $current_save->{'error'};
        }

      }

    };

    try {
        $chado_schema->txn_do($coderef);
    } catch {
        print STDERR "Transaction Error: $_\n";
        push @{$save{'errors'}}, $_;
    };

    #print STDERR "Check 5: ".localtime()."\n";
    if (scalar @{$save{'errors'}} > 0) {
        print STDERR "Errors saving trials: ".@{$save{'errors'}};
        $c->stash->{rest} = {errors => $save{'errors'}};
        return;
    # } elsif ($save->{'trial_id'}) {
    } else {
        my $dbh = $c->dbc->dbh();
        my $bs = CXGN::BreederSearch->new( { dbh=>$dbh, dbname=>$c->config->{dbname}, } );
        my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'stockprop', 'concurrent', $c->config->{basepath});

        $c->stash->{rest} = {success => "1",};
        return;
    }

}

1;
