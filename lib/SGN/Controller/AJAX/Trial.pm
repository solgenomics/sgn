
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
use File::Temp 'tempfile';
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
use CXGN::TrialStatus;
use CXGN::Calendar;
use CXGN::BreedersToolbox::SoilData;
use CXGN::Contact;
use CXGN::File::Parse;
use CXGN::People::Person;
use CXGN::Tools::Run;
use CXGN::Job;
use Cwd;
use CXGN::Phenotypes::StorePhenotypes;

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

    my $plot_numbering_scheme = $c->req->param('plot_numbering_scheme') || 'block_based';
    print STDERR "Setting plot_numbering_scheme to $plot_numbering_scheme\n";
    $trial_design->set_plot_numbering_scheme($plot_numbering_scheme);

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

    my $json = JSON::XS->new();

    my $block_size =  $c->req->param('block_size');
    my $max_block_size =  $c->req->param('max_block_size');
    my $plot_prefix =  $c->req->param('plot_prefix');
    my $start_number =  $c->req->param('start_number');
    my $plot_numbering_scheme = $c->req->param('plot_numbering_scheme');
    my $increment =  $c->req->param('increment') ? $c->req->param('increment') : 1;
    my $trial_location = $c->req->param('trial_location');
    my $fieldmap_col_number = $c->req->param('fieldmap_col_number');
    my $fieldmap_row_number = $c->req->param('fieldmap_row_number');
    my $plot_layout_format = $c->req->param('plot_layout_format');
    my $treatments = $c->req->param('treatments') ? $c->req->param('treatments') : "";
    if ($treatments) {
        $treatments = $json->decode($treatments);
    }
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
        if (scalar(keys(%{$treatments}))<1){
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

    if ($design_type eq 'RRC'){
        if (!$fieldmap_row_number){
            $c->stash->{rest} = { error => "You need to provide number of rows for a resolvable row-column design."};
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

    if ($design_type eq 'URDD'){
        if (!$row_in_design_number || !$col_in_design_number){
            $c->stash->{rest} = { error => "You need to provide number of rows and cols for a unreplicated diagonal design."};
            return;
        }
    }

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
    my $num_rows_per_plot = $c->req->param('num_rows_per_plot');
    my $num_cols_per_plot = $c->req->param('num_cols_per_plot');
    my $use_same_layout = $c->req->param('use_same_layout');
    my $number_of_checks = scalar(@control_names_crbd);

    if ($design_type eq "RCBD" || $design_type eq "RRC" || $design_type eq "DRRC" || $design_type eq "URDD" ||$design_type eq "Alpha" || $design_type eq "CRD" || $design_type eq "Lattice") {
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

        my $dir = $c->tempfiles_subdir('trial_designs');
        my ($FH, $filename) = $c->tempfile(TEMPLATE=>"trial_designs/$design_type-XXXXX");
        my $design_tempfile = $c->config->{basepath}.$filename;
        # my $design_tempfile = "".$filename;
        $trial_design->set_tempfile($design_tempfile);
        $trial_design->set_backend($c->config->{backend});
        $trial_design->set_submit_host($c->config->{cluster_host});
        $trial_design->set_temp_base($c->config->{cluster_shared_tempdir});
	    $trial_design->set_plot_numbering_scheme($plot_numbering_scheme);

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
        if ($num_rows_per_plot && $num_cols_per_plot) {
            $trial_design->set_num_rows_per_plot($num_rows_per_plot);
            $trial_design->set_num_cols_per_plot($num_cols_per_plot);
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

        if ($treatments && scalar(keys(%{$treatments}))>0) {
            $trial_design->set_treatments($treatments);
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

sub save_experimental_design : Path('/ajax/trial/save_experimental_design') : ActionClass('REST') { print STDERR "went into save_experimental_design \n"; }

sub save_experimental_design_POST : Args(0) {
    #$| = 1;
    print STDERR "This message means it is printing from the subroutine save_experimental_design_POST \n";
    my ($self, $c) = @_;

    my $user_id = $c->user()->get_object()->get_sp_person_id();
    print STDERR "this is sp_person_id from saving trial details: ".$user_id."\n";
   # open my $file(STDERR "This is getting read to file: user id: ".$user_id);

    my $chado_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $user_id);
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $user_id);
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


    my $user_name = $c->user()->get_object()->get_username();
    my $error;

    my $design = _parse_design_from_json($c->req->param('design_json'));

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
            planting_date => $c->req->param('planting_date'),
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

    if ($save->{'trial_id'}) {
        my $trial_id = $save->{'trial_id'};
        my $time = DateTime->now();
        my $timestamp = $time->ymd();
        my $pheno_timestamp = $time->ymd()."_".$time->hms();
        my $calendar_funcs = CXGN::Calendar->new({});
        my $formatted_date = $calendar_funcs->check_value_format($timestamp);
        my $create_date = $calendar_funcs->display_start_date($formatted_date);

        my %trial_activity;
        $trial_activity{'Trial Created'}{'user_id'} = $user_id;
        $trial_activity{'Trial Created'}{'activity_date'} = $create_date;

        my $trial_activity_obj = CXGN::TrialStatus->new({ bcs_schema => $schema });
        $trial_activity_obj->trial_activities(\%trial_activity);
        $trial_activity_obj->parent_id($trial_id);
        my $activity_prop_id = $trial_activity_obj->store();
        if (!$activity_prop_id) {
            $c->stash->{rest} = {error => "Error saving trial activity info" };
            return;
        }

        if ($c->req->param('design_type') eq "splitplot") {

            my $temp_basedir = $c->config->{tempfiles_subdir};
            my $site_basedir = getcwd();
            if (! -d "$site_basedir/$temp_basedir/delete_nd_experiment_ids/"){
                mkdir("$site_basedir/$temp_basedir/delete_nd_experiment_ids/");
            }
            my (undef, $tempfile) = tempfile("$site_basedir/$temp_basedir/delete_nd_experiment_ids/fileXXXX");

            my $phenostore_data_hash = {};
            my %phenostore_stocks = ();
            my %phenostore_treatments = ();

            my $treatment_design;
            foreach my $design_json (@{$design}) {
                my $design = $json->decode($design_json);
                $treatment_design = $design->{'treatments'};
                foreach my $unique_treatment (keys(%{$treatment_design->{'treatments'}})) {
                    my @treatment_pairs = ($unique_treatment =~ m/\{([^{}]+)\}/g);
                    my $treatments = [];
                    foreach my $pair (@treatment_pairs) {
                        my ($treatment, $value) = $pair =~ m/([^=]+)=(.*)/;
                        $phenostore_treatments{$treatment} = 1;
                        push @{$treatments}, {
                            'treatment' => $treatment,
                            'value' => $value
                        };
                    }
                    my $subplots = $treatment_design->{'treatments'}->{$unique_treatment};
                    foreach my $treatment (@{$treatments}) {
                        foreach my $subplot (@{$subplots}) {
                            $phenostore_stocks{$subplot} = 1;
                            my $plants = $treatment_design->{'plants'}->{$subplot};
                            $phenostore_data_hash->{$subplot}->{$treatment->{'treatment'}} = [
                                $treatment->{'value'},
                                $pheno_timestamp,
                                $user_name,
                                '',
                                ''
                            ];
                            foreach my $plant (@{$plants}) {
                                $phenostore_stocks{$plant} = 1;
                                $phenostore_data_hash->{$plant}->{$treatment->{'treatment'}} = [
                                    $treatment->{'value'},
                                    $pheno_timestamp,
                                    $user_name,
                                    '',
                                    ''
                                ];
                            }
                        }
                    }
                }
            }

            my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new({
                basepath => $temp_basedir,
                dbhost => $c->config->{dbhost},
                dbuser => $c->config->{dbuser},
                dbname => $c->config->{dbname},
                dbpass => $c->config->{dbpass},
                temp_file_nd_experiment_id => $tempfile,
                bcs_schema => $chado_schema,
                metadata_schema => $metadata_schema,
                phenome_schema => $phenome_schema,
                user_id => $user_id,
                stock_list => [keys(%phenostore_stocks)],
                trait_list => [keys(%phenostore_treatments)],
                values_hash => $phenostore_data_hash,
                metadata_hash =>{
                    archived_file => 'none',
                    archived_file_type => 'new trial design with treatments',
                    operator => $user_name,
                    date => $pheno_timestamp
                }
            });

            my ($verified_warning, $verified_error) = $store_phenotypes->verify();

            if ($verified_warning) {
                warn $verified_warning;
            }
            if ($verified_error) {
                print STDERR "$verified_error\n";
                $c->stash->{rest} = {error => "The trial was saved, but there was an issue applying treatments: $verified_error\n" };
                return;
            }

            my ($stored_phenotype_error, $stored_phenotype_success) = $store_phenotypes->store();

            if ($stored_phenotype_error) {
                print STDERR "$stored_phenotype_error\n";
                $c->stash->{rest} = {error => "The trial was saved, but there was an issue applying treatments: $stored_phenotype_error\n" };
                return;
            }
        }
    }

    my $bs = CXGN::BreederSearch->new( { dbh=>$dbh, dbname=>$c->config->{dbname}, } );
    my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'all_but_genoview', 'concurrent', $c->config->{basepath});

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
    my $ignore_warnings = $c->req->param('upload_trial_ignore_warnings');

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
    $parser = CXGN::Trial::ParseUpload->new(chado_schema => $chado_schema, filename => $archived_filename_with_path, trial_stock_type => $trial_stock_type, trial_name => $trial_name);
    $parser->load_plugin('TrialGeneric');
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
                $return_error=$return_error.$error_string."<br>";
            }
        }

        $c->stash->{rest} = {error_string => $return_error, missing_accessions => $parse_errors->{'missing_stocks'}, missing_seedlots => $parse_errors->{'missing_seedlots'}};
        return;
    }

    if ($parser->has_parse_warnings()) {
        unless ($ignore_warnings) {
            my $warnings = $parser->get_parse_warnings();
            $c->stash->{rest} = {warnings => $warnings->{'warning_messages'}};
            return;
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
            design => $parsed_data->{'design'},
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
        my $entry_numbers = $parsed_data->{'entry_numbers'};

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

        # save entry numbers, if provided
        if ( $entry_numbers && scalar(keys %$entry_numbers) > 0 && $save->{'trial_id'} ) {
            my %entry_numbers_prop;
            my @stock_names = keys %$entry_numbers;

            # Convert stock names from parsed trial template to stock ids for data storage
            my $stocks = $chado_schema->resultset('Stock::Stock')->search({ uniquename=>{-in=>\@stock_names} });
            while (my $s = $stocks->next()) {
                $entry_numbers_prop{$s->stock_id} = $entry_numbers->{$s->uniquename};
            }

            # Lookup synonyms of accession names
            my $synonym_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'stock_synonym', 'stock_property')->cvterm_id();
            my $acc_synonym_rs = $chado_schema->resultset("Stock::Stock")->search({
                'me.is_obsolete' => { '!=' => 't' },
                'stockprops.value' => { -in => \@stock_names},
                'stockprops.type_id' => $synonym_cvterm_id
            },{join => 'stockprops', '+select'=>['stockprops.value'], '+as'=>['synonym']});
            while (my $r=$acc_synonym_rs->next) {
                if ( exists($entry_numbers->{$r->get_column('synonym')}) ) {
                    $entry_numbers_prop{$r->stock_id} = $entry_numbers->{$r->get_column('synonym')};
                }
            }

            # store entry numbers
            my $trial = CXGN::Trial->new({ bcs_schema => $chado_schema, trial_id => $save->{'trial_id'} });
            $trial->set_entry_numbers(\%entry_numbers_prop);
        }
    };

    try {
        $chado_schema->txn_do($coderef);
    } catch {
        print STDERR "Transaction Error: $_\n";
        $save->{'error'} = $_;
    };

    if ($save->{'trial_id'}) {
        my $trial_id = $save->{'trial_id'};
        my $timestamp = $time->ymd();
        my $calendar_funcs = CXGN::Calendar->new({});
        my $formatted_date = $calendar_funcs->check_value_format($timestamp);
        my $upload_date = $calendar_funcs->display_start_date($formatted_date);

        my %trial_activity;
        $trial_activity{'Trial Uploaded'}{'user_id'} = $user_id;
        $trial_activity{'Trial Uploaded'}{'activity_date'} = $upload_date;

        my $trial_activity_obj = CXGN::TrialStatus->new({ bcs_schema => $chado_schema });
        $trial_activity_obj->trial_activities(\%trial_activity);
        $trial_activity_obj->parent_id($trial_id);
        my $activity_prop_id = $trial_activity_obj->store();

        # save treatments if any
        if ($parsed_data->{'treatment_design'}) {
            my $temp_basedir = $c->config->{tempfiles_subdir};
            my $site_basedir = getcwd();
            if (! -d "$site_basedir/$temp_basedir/delete_nd_experiment_ids/"){
                mkdir("$site_basedir/$temp_basedir/delete_nd_experiment_ids/");
            }
            my (undef, $tempfile) = tempfile("$site_basedir/$temp_basedir/delete_nd_experiment_ids/fileXXXX");

            my $phenostore_data_hash = {};
            my %phenostore_stocks = ();
            my %phenostore_treatments = ();

            my $time = DateTime->now();
            my $pheno_timestamp = $time->ymd()."_".$time->hms();

            my $treatment_design = $parsed_data->{'treatment_design'};
            foreach my $plot (keys(%{$treatment_design})) {
                $phenostore_stocks{$plot} = 1;
                foreach my $treatment (keys(%{$treatment_design->{$plot}})) {
                    $phenostore_treatments{$treatment} = 1;
                    $phenostore_data_hash->{$plot}->{$treatment} = [
                        $treatment_design->{$plot}->{$treatment},
                        $pheno_timestamp,
                        $user_name,
                        '',''
                    ];
                }
            }

            my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new({
                basepath => $temp_basedir,
                dbhost => $c->config->{dbhost},
                dbuser => $c->config->{dbuser},
                dbname => $c->config->{dbname},
                dbpass => $c->config->{dbpass},
                temp_file_nd_experiment_id => $tempfile,
                bcs_schema => $chado_schema,
                metadata_schema => $metadata_schema,
                phenome_schema => $phenome_schema,
                user_id => $user_id,
                stock_list => [keys(%phenostore_stocks)],
                trait_list => [keys(%phenostore_treatments)],
                values_hash => $phenostore_data_hash,
                metadata_hash =>{
                    archived_file => 'none',
                    archived_file_type => 'new trial upload with treatments',
                    operator => $user_name,
                    date => $pheno_timestamp
                }
            });

            my ($verified_warning, $verified_error) = $store_phenotypes->verify();

            if ($verified_warning) {
                warn $verified_warning;
            }
            if ($verified_error) {
                print STDERR "$verified_error\n";
                $c->stash->{rest} = {error => "The trial was saved, but there was an issue applying treatments: $verified_error\n" };
                return;
            }

            my ($stored_phenotype_error, $stored_phenotype_success) = $store_phenotypes->store();

            if ($stored_phenotype_error) {
                print STDERR "$stored_phenotype_error\n";
                $c->stash->{rest} = {error => "The trial was saved, but there was an issue applying treatments: $stored_phenotype_error\n" };
                return;
            }
        }
    }

    #print STDERR "Check 5: ".localtime()."\n";
    if ($save->{'error'}) {
        print STDERR "Error saving trial: ".$save->{'error'};
        $c->stash->{rest} = {error => $save->{'error'}};
        return;
    } elsif ($save->{'trial_id'}) {

        my $dbh = $c->dbc->dbh();
        my $bs = CXGN::BreederSearch->new( { dbh=>$dbh, dbname=>$c->config->{dbname}, } );
        my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'all_but_genoview', 'concurrent', $c->config->{basepath});

        $c->stash->{rest} = {success => "1", trial_id => $save->{'trial_id'}};
        return;
    }

}

sub upload_multiple_trial_designs_file : Path('/ajax/trial/upload_multiple_trial_designs_file') : ActionClass('REST') { }

sub upload_multiple_trial_designs_file_POST : Args(0) {
    my ($self, $c) = @_;
    my $upload                     = $c->req->upload('multiple_trial_designs_upload_file');
    my $ignore_warnings            = $c->req->param('upload_multiple_trials_ignore_warnings') eq 'on';
    my $email_address              = $c->req->param('trial_email_address_upload');
    my $email_option_enabled       = $c->req->param('email_option_to_recieve_trial_upload_status') eq 'on';

    my $dbhost                     = $c->config->{dbhost};
    my $dbname                     = $c->config->{dbname};
    my $dbpass                     = $c->config->{dbpass};
    my $basepath                   = $c->config->{basepath};
    my $dbuser                     = $c->config->{dbuser};
    my $time                       = DateTime->now();
    my $timestamp                  = $time->ymd()."_".$time->hms();
    my $upload_original_name       = $upload->filename();
    my $upload_tempfile            = $upload->tempname;
    my $subdirectory               = "trial_upload";
    my $archive_filename           = $timestamp . "_" . $upload_original_name;

    # Check if user is logged in and has curator or submitter privileges
    if (!$c->user()) {
        print STDERR "User not logged in... not uploading a trial.\n";
        $c->stash->{rest} = {errors => "You need to be logged in to upload a trial." };
        return;
    }
    if (!any { $_ eq "curator" || $_ eq "submitter" } ($c->user()->roles)) {
        $c->stash->{rest} = {errors =>  "You have insufficient privileges to upload a trial." };
        return;
    }
    my $user_id = $c->user()->get_object()->get_sp_person_id();
    my $username = $c->user()->get_object()->get_username();

    # Check filename for spaces and/or slashes
    if ($upload_original_name =~ /\s/ || $upload_original_name =~ /\// || $upload_original_name =~ /\\/ ) {
        print STDERR "File name must not have spaces or slashes.\n";
        $c->stash->{rest} = {errors => "Uploaded file name must not contain spaces or slashes." };
        return;
    }

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
    my $archived_filename_with_path = $uploader->archive();
    if (!$archived_filename_with_path) {
        $c->stash->{rest} = {errors => "Could not save file $archive_filename in archive",};
        return;
    }
    unlink $upload_tempfile;

    # Build the backend script command to parse, validate, and upload the trials
    my $cmd = "perl \"$basepath/bin/upload_multiple_trial_design.pl\" -H \"$dbhost\" -D \"$dbname\" -U \"$dbuser\" -P \"$dbpass\" -w \"$basepath\" -i \"$archived_filename_with_path\" -un \"$username\"";
    $cmd .= " -e \"$email_address\"" if $email_option_enabled && $email_address;
    $cmd .= " -iw" if $ignore_warnings;

    # Run asynchronously if email option is enabled
    # my $runner = CXGN::Tools::Run->new();
    my $job = CXGN::Job->new({
        sp_person_id => $user_id,
        schema => $c->dbic_schema("Bio::Chado::Schema"),
        people_schema => $c->dbic_schema("CXGN::People::Schema"),
        cmd => $cmd,
        name => "$upload_original_name multiple trial designs upload",
        results_page => '/breeders/trials',
        job_type => 'upload',
        finish_logfile => $c->config->{job_finish_log}
    });
    if ( $email_option_enabled && $email_address ) {
        #$runner->run_async($cmd);
        $job->submit();
        #my $err = $runner->err();
        #my $out = $runner->out();

        #print STDERR "Upload Trials Output (async):\n";
        #print STDERR "$err\n";
        #print STDERR "$out\n";

        $c->stash->{rest} = {background => 1};
        return;
    }

    # Otherwise run synchronously
    else {
        #$runner->run($cmd.$job->generate_finish_timestamp_cmd());
        #$job->update_status("submitted");
        #my $err = $runner->err();
        #my $out = $runner->out();

        $job->submit();

        while($job->alive()) {
            sleep(1);
        }

        my $err_file = $job->cxgn_tools_run_config->{err};
        my $out_file = $job->cxgn_tools_run_config->{out};

        print STDERR "Upload Trials Output (sync):\n";
        print STDERR "$err_file\n";
        print STDERR "$out_file\n";

        open my $err, "<", $err_file or die "No error file found!\n";
        open my $out, "<", $out_file or die "No out file found!\n";

        # Collect errors and warnings from STDERR
        my @errors;
        my @warnings;
        while (<$err>) {
            chomp;
            if ($_ =~ /^ERROR/) {
                $_ =~ s/ERROR:? ?//;
                push @errors, $_;
            }
            elsif ($_ =~ /^WARNING/) {
                $_ =~ s/WARNING:? ?//;
                push @warnings, $_;
            }
        }
        # foreach (split(/\n/, $err)) {
        #     if ($_ =~ /^ERROR/) {
        #         $_ =~ s/ERROR:? ?//;
        #         push @errors, $_;
        #     }
        #     elsif ($_ =~ /^WARNING/) {
        #         $_ =~ s/WARNING:? ?//;
        #         push @warnings, $_;
        #     }
        # }

        if ( scalar(@errors) > 0 ) {
            $c->stash->{rest} = {errors => \@errors};
            $job->update_status("failed");
            return;
        }
        if ( scalar(@warnings) > 0 ) {
            $c->stash->{rest} = {warnings => \@warnings};
            $job->update_status("failed");
            return;
        }
    }


    # Return success
    $c->stash->{rest} = {success => "1"};
    return;

}


sub upload_trial_metadata_file : Path('/ajax/trial/upload_trial_metadata_file') : ActionClass('REST') { }

sub upload_trial_metadata_file_POST : Args(0) {
    my ($self, $c)                 = @_;
    my $upload                     = $c->req->upload('trial_metadata_upload_file');
    my $ignore_warnings            = $c->req->param('trial_metadata_upload_ignore_warnings');

    my $chado_schema               = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $dbhost                     = $c->config->{dbhost};
    my $dbname                     = $c->config->{dbname};
    my $dbpass                     = $c->config->{dbpass};
    my $basepath                   = $c->config->{basepath};
    my $dbuser                     = $c->config->{dbuser};
    my $time                       = DateTime->now();
    my $timestamp                  = $time->ymd()."_".$time->hms();
    my $upload_original_name       = $upload->filename();
    my $upload_tempfile            = $upload->tempname;
    my $subdirectory               = "trial_metadata";
    my $archive_filename           = $timestamp . "_" . $upload_original_name;

    # Check if user is logged in and has curator or submitter privileges
    if (!$c->user()) {
        $c->stash->{rest} = {errors => "You need to be logged in to update a trial." };
        return;
    }
    my $user_id = $c->user()->get_object()->get_sp_person_id();
    my $username = $c->user()->get_object()->get_username();
    my @user_roles = $c->user()->roles();
    my %has_roles = ();
    map { $has_roles{$_} = 1; } @user_roles;

    # User must be a curator or submitter
    if ( !(exists($has_roles{'submitter'}) || exists($has_roles{'curator'}) ) ) {
        $c->stash->{rest} = {errors =>  "You must be a curator or submitter to update a trial." };
        return;
    }

    # Check filename for spaces and/or slashes
    if ($upload_original_name =~ /\s/ || $upload_original_name =~ /\// || $upload_original_name =~ /\\/ ) {
        print STDERR "File name must not have spaces or slashes.\n";
        $c->stash->{rest} = {errors => "Uploaded file name must not contain spaces or slashes." };
        return;
    }

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
    my $archived_filename_with_path = $uploader->archive();
    if (!$archived_filename_with_path) {
        $c->stash->{rest} = {errors => "Could not save file $archive_filename in archive",};
        return;
    }
    unlink $upload_tempfile;

    # parse uploaded file with trial metadata plugin
    my $parser = CXGN::Trial::ParseUpload->new(chado_schema => $chado_schema, filename => $archived_filename_with_path);
    $parser->load_plugin('TrialMetadataGeneric');
    my $parsed_data = $parser->parse();

    my @errors;
    my @warnings;
    if (!$parsed_data) {
        my $parse_errors = $parser->get_parse_errors();
        $c->stash->{rest} = { errors => $parse_errors ? $parse_errors->{'error_messages'} : ['No data returned'] };
        return;
    }

    if ($parser->has_parse_warnings()) {
        unless ($ignore_warnings) {
            my $warnings = $parser->get_parse_warnings();
            $c->stash->{rest} = { warnings => $warnings->{'warning_messages'} };
            return;
        }
    }

    # Check breeding program permissions, if not a curator
    if ( ! exists($has_roles{'curator'}) ) {
        my $breeding_programs = $parsed_data->{'breeding_programs'};
        my @missing_breeding_programs;
        foreach my $breeding_program (@$breeding_programs) {
            if ( ! exists($has_roles{$breeding_program}) ) {
                push @missing_breeding_programs, $breeding_program;
            }
        }
        if ( scalar(@missing_breeding_programs) > 0 ) {
            $c->stash->{rest} = { errors => "You need to be either a curator, or a submitter associated with the breeding program(s) " . join(', ', @missing_breeding_programs) . " to change the details of trial(s) associated with these program(s)." };
            return;
        }
    }

    # Create missing folders
    my %created_folders;
    foreach my $trial_id (keys %{$parsed_data->{trial_data}} ) {
        my $details = $parsed_data->{trial_data}->{$trial_id};
        if ( $details->{folder} ) {
            if ( $details->{folder}->{type} eq 'missing' ) {
                my $folder_id;

                if ( exists $created_folders{$details->{folder}->{name}} ) {
                    $folder_id = $created_folders{$details->{folder}->{name}};
                }
                else {
                    my $f = CXGN::Trial::Folder->create({
                        bcs_schema => $chado_schema,
                        name => $details->{folder}->{name},
                        breeding_program_id => $details->{folder}->{breeding_program_id},
                        folder_for_trials => 1
                    });
                    $folder_id = $f->folder_id();
                    $created_folders{$details->{folder}->{name}} = $folder_id;
                }

                $parsed_data->{trial_data}->{$trial_id}->{folder}->{type} = "exists";
                $parsed_data->{trial_data}->{$trial_id}->{folder}->{id} = $folder_id;
            }
        }
    }

    # Update each trial
    eval {
        my $trial_data = $parsed_data->{'trial_data'};
        foreach my $trial_id (keys %$trial_data) {
            my $details = $trial_data->{$trial_id};
            my $trial = CXGN::Project->new({ bcs_schema => $chado_schema, trial_id => $trial_id });
            my $error = $trial->update_metadata($details);
            die $error if $error;
        }
    };
    if ($@) {
        $c->stash->{rest} = { errors => "There was an error updating one or more trials: $@" };
        return;
    };

    # All Done
    $c->stash->{rest} = { success => 1 };
    return;
}


sub upload_soil_data : Path('/ajax/trial/upload_soil_data') : ActionClass('REST') { }

sub upload_soil_data_POST : Args(0) {
    my ($self, $c) = @_;
    my $chado_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $dbh = $c->dbc->dbh;
    my $trial_id = $c->req->param('soil_data_trial_id');
    my $description = $c->req->param('soil_data_description');
    my $soil_data_date = $c->req->param('changed');
    my $soil_data_gps = $c->req->param('soil_data_gps');
    my $type_of_sampling = $c->req->param('type_of_sampling');

    my $upload = $c->req->upload('soil_data_upload_file');
    my $parser;
    my $parsed_data;
    my $upload_original_name = $upload->filename();
    my $upload_tempfile = $upload->tempname;
    my $subdirectory = "soil_data_upload";
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
    my $user_role;
    my $session_id = $c->req->param("sgn_session_id");

    if ($upload_original_name =~ /\s/ || $upload_original_name =~ /\// || $upload_original_name =~ /\\/ ) {
        print STDERR "File name must not have spaces or slashes.\n";
        $c->stash->{rest} = {errors => "Uploaded file name must not contain spaces or slashes." };
        return;
    }

    if ($session_id){
        my $dbh = $c->dbc->dbh;
        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);
        if (!$user_info[0]){
            $c->stash->{rest} = {error=>'You must be logged in to upload soil data!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else{
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to upload soil data!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }

    if (($user_role ne 'curator') && ($user_role ne 'submitter')) {
        $c->stash->{rest} = {error=>'Only a submitter or a curator can upload soil data'};
        $c->detach();
    }

    ## Store uploaded temporary file in archive
    my $uploader = CXGN::UploadFile->new({
        tempfile => $upload_tempfile,
        subdirectory => $subdirectory,
        archive_path => $c->config->{archive_path},
        archive_filename => $upload_original_name,
        timestamp => $timestamp,
        user_id => $user_id,
        user_role => $user_role
    });
    $archived_filename_with_path = $uploader->archive();
    $md5 = $uploader->get_md5($archived_filename_with_path);
    if (!$archived_filename_with_path) {
        $c->stash->{rest} = {errors => "Could not save file $upload_original_name in archive",};
        return;
    }
    unlink $upload_tempfile;

    $upload_metadata{'archived_file'} = $archived_filename_with_path;
    $upload_metadata{'archived_file_type'}="soil data upload file";
    $upload_metadata{'user_id'}=$user_id;
    $upload_metadata{'date'}="$timestamp";


    #parse uploaded file with appropriate plugin
    $parser = CXGN::Trial::ParseUpload->new(chado_schema => $chado_schema, filename => $archived_filename_with_path);
    $parser->load_plugin('SoilDataXLS');
    $parsed_data = $parser->parse();
    print STDERR "PARSED DATA =".Dumper($parsed_data)."\n";

    if (!$parsed_data){
        my $return_error = '';
        my $parse_errors;
        if (!$parser->has_parse_errors() ){
            $c->stash->{rest} = {error_string => "Could not get parsing errors"};
        } else {
            $parse_errors = $parser->get_parse_errors();
            #print STDERR Dumper $parse_errors;

            foreach my $error_string (@{$parse_errors->{'error_messages'}}){
                $return_error .= $error_string."<br>";
            }
        }
        $c->stash->{rest} = {error_string => $return_error};
        $c->detach();
    } else {
        my $soil_data_details = $parsed_data->{'soil_data_details'};
        my $data_type_order = $parsed_data->{'data_type_order'};

        my $soil_data = CXGN::BreedersToolbox::SoilData->new({ bcs_schema => $chado_schema });
        $soil_data->parent_id($trial_id);
        $soil_data->description($description);
        $soil_data->date($soil_data_date);
        $soil_data->gps($soil_data_gps);
        $soil_data->type_of_sampling($type_of_sampling);
        $soil_data->data_type_order($data_type_order);
        $soil_data->soil_data_details($soil_data_details);

        my $soil_data_prop_id = $soil_data->store();
        print STDERR "PROJECTPROP ID =".Dumper($soil_data_prop_id)."\n";
    }

    $c->stash->{rest} = {success => "1"};

}


1;
