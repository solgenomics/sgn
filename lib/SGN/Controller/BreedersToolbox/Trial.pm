
package SGN::Controller::BreedersToolbox::Trial;

use Moose;

use File::Basename;
use File::Slurp qw | read_file |;
use URI::FromHash 'uri';

use CXGN::Trial::TrialLayout;
use CXGN::BreedersToolbox::Projects;
use SGN::View::Trial qw/design_layout_view design_info_view trial_detail_design_view/;
use CXGN::Trial::Download;
use CXGN::List::Transform;
use CXGN::List::Validate;
use CXGN::List;
use JSON::XS;
use Data::Dumper;

BEGIN { extends 'Catalyst::Controller'; }


sub trial_init : Chained('/') PathPart('breeders/trial') CaptureArgs(1) {
    my $self = shift;
    my $c = shift;
    my $trial_id = shift;

    $c->stash->{trial_id} = $trial_id;
    print STDERR "TRIAL ID = $trial_id\n";

    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    $c->stash->{schema} = $schema;
    my $trial;
    eval {
	$trial = CXGN::Trial->new( { bcs_schema => $schema, trial_id => $trial_id });
    };
    if ($@) {
	$c->stash->{template} = 'system_message.txt';
	$c->stash->{message} = "The requested trial ($trial_id) does not exist";
	return;
    }
    $c->stash->{trial} = $trial;
}

sub old_trial_url : Path('/breeders_toolbox/trial') Args(1) {
    my $self = shift;
    my $c = shift;
    my @args = @_;
    my $format = $c->req->param("format");
    $c->res->redirect('/breeders/trial/'.$args[0].'?format='.$format);
}

sub trial_info : Chained('trial_init') PathPart('') Args(0) {
    #print STDERR "Check 1: ".localtime()."\n";
    print STDERR "TRIAL INIT...\n\n";
    my $self = shift;
    my $c = shift;
    my $format = $c->req->param("format");
    #print STDERR $format;
    my $user = $c->user();
    if (!$user) {
	$c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
	return;
    }

    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $trial = $c->stash->{trial};
    my $program_object = CXGN::BreedersToolbox::Projects->new( { schema => $schema });

    if (!$program_object->trial_exists($c->stash->{trial_id})) {
	$c->stash->{message} = "The requested trial does not exist or has been deleted.";
	$c->stash->{template} = 'generic_message.mas';
	return;
    }

    $c->stash->{trial_name} = $trial->get_name();
    $c->stash->{trial_owner} = $trial->get_owner_link();
        
    my $trial_type_data = $trial->get_project_type();
    my $trial_type_name = $trial_type_data ? $trial_type_data->[1] : '';
    $c->stash->{trial_type} = $trial_type_name;
    $c->stash->{trial_type_id} = $trial_type_data->[0];

    $c->stash->{planting_date} = $trial->get_planting_date();
    $c->stash->{harvest_date} = $trial->get_harvest_date();

    $c->stash->{plot_width} = $trial->get_plot_width();
    $c->stash->{plot_length} = $trial->get_plot_length();
    $c->stash->{field_size} = $trial->get_field_size();

    $c->stash->{field_trial_is_planned_to_be_genotyped} = $trial->get_field_trial_is_planned_to_be_genotyped();
    $c->stash->{field_trial_is_planned_to_cross} = $trial->get_field_trial_is_planned_to_cross();

    $c->stash->{trial_description} = $trial->get_description();

    my $location_data = $trial->get_location();
    $c->stash->{location_id} = $location_data->[0];
    $c->stash->{location_name} = $location_data->[1];
    $c->stash->{country_name} = $trial->get_location_country_name();

    my $breeding_program_data = $program_object->get_breeding_programs_by_trial($c->stash->{trial_id});
    $c->stash->{breeding_program_id} = $breeding_program_data->[0]->[0];
    $c->stash->{breeding_program_name} = $breeding_program_data->[0]->[1];

    $c->stash->{user_can_modify} = ($user->check_roles("submitter") && $user->check_roles($c->stash->{breeding_program_name})) || $user->check_roles("curator") ;


    
    $c->stash->{year} = $trial->get_year();

    $c->stash->{trial_id} = $c->stash->{trial_id};

    $c->stash->{has_col_and_row_numbers} = $trial->has_col_and_row_numbers();
    $c->stash->{has_plant_entries} = $trial->has_plant_entries();
    $c->stash->{has_subplot_entries} = $trial->has_subplot_entries();
    $c->stash->{has_tissue_sample_entries} = $trial->has_tissue_sample_entries();
    $c->stash->{phenotypes_fully_uploaded} = $trial->get_phenotypes_fully_uploaded();

    $c->stash->{hidap_enabled} = $c->config->{hidap_enabled};
    $c->stash->{has_expression_atlas} = $c->config->{has_expression_atlas};
    $c->stash->{expression_atlas_url} = $c->config->{expression_atlas_url};
    $c->stash->{main_production_site_url} = $c->config->{main_production_site_url};
    $c->stash->{site_project_name} = $c->config->{project_name};
    $c->stash->{sgn_session_id} = $c->req->cookie('sgn_session_id');
    $c->stash->{user_name} = $c->user->get_object->get_username;

    if ($trial->get_folder) {
      $c->stash->{folder_id} = $trial->get_folder()->project_id();
      $c->stash->{folder_name} = $trial->get_folder()->name();
    }

    my $design_type = $trial->get_design_type();
    $c->stash->{design_name} = $design_type;
    $c->stash->{genotyping_facility} = $trial->get_genotyping_facility;

    #  print STDERR "TRIAL TYPE DATA = $trial_type_data->[1]\n\n";

    if ($design_type eq "genotyping_plate") {
        $c->stash->{plate_id} = $c->stash->{trial_id};
        $c->stash->{raw_data_link} = $trial->get_raw_data_link;
        $c->stash->{genotyping_facility} = $trial->get_genotyping_facility;
        $c->stash->{genotyping_facility_submitted} = $trial->get_genotyping_facility_submitted;
        $c->stash->{genotyping_facility_status} = $trial->get_genotyping_facility_status;
        $c->stash->{genotyping_vendor_order_id} = $trial->get_genotyping_vendor_order_id;
        $c->stash->{genotyping_vendor_submission_id} = $trial->get_genotyping_vendor_submission_id;
        $c->stash->{genotyping_plate_sample_type} = $trial->get_genotyping_plate_sample_type;
        if ($trial->get_genotyping_plate_format){
            $c->stash->{genotyping_plate_format} = $trial->get_genotyping_plate_format;
        }
        if ($format eq "as_table") {
            $c->stash->{template} = '/breeders_toolbox/genotyping_trials/format/as_table.mas';
        }
        else {
            $c->stash->{template} = '/breeders_toolbox/genotyping_trials/detail.mas';
        }
    }
    elsif ($design_type eq "sampling_trial"){
        $c->stash->{template} = '/breeders_toolbox/sampling_trials/detail.mas';
    }
    elsif ($design_type eq "treatment"){
        $c->stash->{management_factor_type} = $trial->get_management_factor_type;
        $c->stash->{management_factor_date} = $trial->get_management_factor_date;
        $c->stash->{template} = '/breeders_toolbox/management_factor.mas';
    }
    elsif ($design_type eq "genotype_data_project"){
        $c->stash->{template} = '/breeders_toolbox/genotype_data_project.mas';
    }
    elsif ($design_type eq "drone_run"){
        $c->stash->{drone_run_date} = $trial->get_drone_run_date;
        $c->stash->{template} = '/breeders_toolbox/drone_run_project.mas';
    }
    elsif ($trial_type_name eq "crossing_trial"){
        print STDERR "It's a crossing trial!\n\n";
        my $program_name = $breeding_program_data->[0]->[1];
        my $locations = JSON::XS->new->decode($program_object->get_all_locations_by_breeding_program());
        my @locations_by_program;
        foreach my $location_hashref (@$locations) {
            my $properties = $location_hashref->{'properties'};
            my $program = $properties->{'Program'};
            my $name = $properties->{'Name'};
            if ($program eq $program_name) {
                push @locations_by_program, $name;
            }
        }
        my $locations_by_program_json = encode_json(\@locations_by_program);
        $c->stash->{locations_by_program_json} = $locations_by_program_json;
        $c->stash->{template} = '/breeders_toolbox/cross/crossing_trial.mas';
    }
    else {
        my $field_management_factors = $c->config->{management_factor_types};
        my @management_factor_types = split ',',$field_management_factors;
        $c->stash->{management_factor_types} = \@management_factor_types;
        $c->stash->{trial_stock_type} = $trial->get_trial_stock_type();
	$c->stash->{trial_stock_count} = $trial->get_trial_stock_count();
        $c->stash->{template} = '/breeders_toolbox/trial.mas';
    }

    print STDERR "End Load Trial Detail Page: ".localtime()."\n";

}


=head2 view_by_name 

Public Path: /breeders/trial/view_by_name/$name
Path Params:
    name = trial unique name

Search for the trial that matches the provided trial name.
If 1 match is found, display the trial detail page.  Display an 
error message if no matches are found.

=cut

sub view_trial_by_name :Path('/breeders/trial/view_by_name') CaptureArgs(1) {
    my ($self, $c, $trial_query) = @_;
    $self->search_trial($c, $trial_query);
}


sub trait_info :Path('/breeders/trial') Args(3) {
    my ($self, $c, $trial_id, $trait_txt, $trait_id) = @_;

    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    my $trial_name = $schema->resultset("Project::Project")
        ->search( {'me.project_id' => $trial_id})
        ->single
        ->name;

    $c->stash->{trial_name} = $trial_name;

    my $trait_name = $schema->resultset("Cv::Cvterm")
        ->search({'me.cvterm_id' => $trait_id})
        ->single
        ->name;

    $c->stash->{trial_id}   = $trial_id;
    $c->stash->{trial_name} = $trial_name;

    $c->stash->{trait_id}   = $trait_id;
    $c->stash->{trait_name} = $trait_name;

    $c->stash->{template}   = '/breeders_toolbox/trial_trait.mas';
}

##DEPRECATED by /breeders/trials
sub trial_tree : Path('/breeders/trialtree') Args(0) {
    my $self = shift;
    my $c = shift;


    $c->stash->{template} = '/breeders_toolbox/trialtree.mas';

}

#For downloading trial layout in CSV and Excel, for downloading trial phenotypes in CSV and Excel, and for downloading trial phenotyping spreadsheets in Excel.
#For phenotype download, better to use SGN::Controller::BreedersToolbox::Download->download_phenotypes_action and provide a single trial_id in the trial_list argument, as that is how the phenotype download works from the wizard page, the trial tree page, and the trial detail page for phenotype download.
sub trial_download : Chained('trial_init') PathPart('download') Args(1) {
    my $self = shift;
    my $c = shift;
    my $what = shift;
    print STDERR Dumper $c->req->params();
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    my $user = $c->user();
    if (!$user) {
        $c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
        return;
    }

    my $format = $c->req->param("format") || "xls";
    my $data_level = $c->req->param("dataLevel") || "plot";
    my $timestamp_option = $c->req->param("timestamp") || 0;
    my $trait_list = $c->req->param("trait_list");
    my $include_measured = $c->req->param('include_measured') || '';
    my $search_type = $c->req->param("search_type") || 'fast';

    my $trial = $c->stash->{trial};
    if ($data_level eq 'plants') {
        if (!$trial->has_plant_entries()) {
            $c->stash->{template} = 'generic_message.mas';
            $c->stash->{message} = "The requested trial (".$trial->get_name().") does not have plant entries. Please create the plant entries first.";
            return;
        }
    }
    if ($data_level eq 'subplots' || $data_level eq 'plants_subplots') {
        if (!$trial->has_subplot_entries()) {
            $c->stash->{template} = 'generic_message.mas';
            $c->stash->{message} = "The requested trial (".$trial->get_name().") does not have subplot entries.";
            return;
        }
    }

    my $selected_cols = $c->req->param('selected_columns') ? JSON::XS->new()->decode( $c->req->param('selected_columns') ) : {};
    if ($data_level eq 'plate'){
        $selected_cols = {'trial_name'=>1, 'acquisition_date'=>1, 'plot_name'=>1, 'plot_number'=>1, 'row_number'=>1, 'col_number'=>1, 'source_observation_unit_name'=>1, 'accession_name'=>1, 'synonyms'=>1, 'dna_person'=>1, 'notes'=>1, 'tissue_type'=>1, 'extraction'=>1, 'concentration'=>1, 'volume'=>1, 'is_blank'=>1};
    }
    if ($data_level eq 'samplingtrial'){
        $selected_cols = {'trial_name'=>1, 'year'=>1, 'location'=>1, 'sampling_facility'=>1, 'sampling_trial_sample_type'=>1, 'acquisition_date'=>1, 'tissue_sample_name'=>1, 'plot_number'=>1, 'rep_number'=>1, 'source_observation_unit_name'=>1, 'accession_name'=>1, 'synonyms'=>1, 'dna_person'=>1, 'notes'=>1, 'tissue_type'=>1, 'extraction'=>1, 'concentration'=>1, 'volume'=>1 };
    }
    my $selected_trait_list_id = $c->req->param('trait_list_id');
    my @trait_list;
    if ($selected_trait_list_id){
        my $list = CXGN::List->new({ dbh => $c->dbc->dbh, list_id => $selected_trait_list_id });
        my @selected_trait_names = @{$list->elements()};
        my $validator = CXGN::List::Validate->new();
        my @absent_traits = @{$validator->validate($schema, 'traits', \@selected_trait_names)->{'missing'}};
        if (scalar(@absent_traits)>0){
            $c->stash->{template} = 'generic_message.mas';
            $c->stash->{message} = "Trait list is not valid because of these terms: ".join ',',@absent_traits;
            return;
        }
        my $lt = CXGN::List::Transform->new();
        @trait_list = @{$lt->transform($schema, "traits_2_trait_ids", \@selected_trait_names)->{transform}};
    }

    my @treatment_project_ids;
    my $treatments = $trial->get_treatments();
    foreach (@$treatments){
        push @treatment_project_ids, $_->[0];
    }

    if ($trait_list && $trait_list ne 'null') {
        @trait_list = @{_parse_list_from_json($trait_list)};
    }

    my $plugin = "";
    if ( ($format eq "xls") && ($what eq "layout")) {
        $plugin = "TrialLayoutExcel";
    }
    if (($format eq "csv") && ($what eq "layout")) {
        $plugin = "TrialLayoutCSV";
    }
    if (($format eq "xls") && ($what =~ /phenotype/)) {
        $plugin = "TrialPhenotypeExcel";
    }
    if (($format eq "csv") && ($what =~ /phenotype/)) {
        $plugin = "TrialPhenotypeCSV";
    }
    if (($format eq "xls") && ($what eq "basic_trial_excel")) {
        $plugin = "BasicExcel";
    }
    if ( ($format eq "intertekxls") && ($what eq "layout")) {
        $plugin = "GenotypingTrialLayoutIntertekXLS";
    }
    if ( ($format eq "dartseqcsv") && ($what eq "layout")) {
        $plugin = "GenotypingTrialLayoutDartSeqCSV";
    }

    my $trial_name = $trial->get_name();
    my $trial_id = $trial->get_trial_id();
    my $dir = $c->tempfiles_subdir('download');
    my $temp_file_name = $trial_id . "_" . "$what" . "XXXX";
    my $rel_file = $c->tempfile( TEMPLATE => "download/$temp_file_name");
    $rel_file = $rel_file . ".$format";
    my $tempfile = $c->config->{basepath}."/".$rel_file;

    print STDERR "TEMPFILE : $tempfile\n";

    my $download = CXGN::Trial::Download->new({
        bcs_schema => $schema,
        trial_id => $c->stash->{trial_id},
        trait_list => \@trait_list,
        filename => $tempfile,
        format => $plugin,
        data_level => $data_level,
        search_type => $search_type,
        include_timestamp => $timestamp_option,
        treatment_project_ids => \@treatment_project_ids,
        selected_columns => $selected_cols,
        include_measured => $include_measured
    });

    my $error = $download->download();

    if ($format eq 'intertekxls'){
        $format = 'xls';
    }
    if ($format eq 'dartseqcsv'){
        $format = 'csv';
    }

    my $file_name = $trial_id . "_" . "$what" . ".$format";
    $c->res->content_type('Application/'.$format);
    $c->res->header('Content-Disposition', qq[attachment; filename="$file_name"]);

    my $output = read_file($tempfile);

    $c->res->body($output);
}

sub trials_download_layouts : Path('/breeders/trials/download/layout') Args(0) {
    my $self = shift;
    my $c = shift;
    print STDERR Dumper $c->req->params();
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $user = $c->user();
    if (!$user) {
        $c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
        return;
    }

    my $format = $c->req->param("format") || "xls";
    my $data_level = $c->req->param("dataLevel") || "plot";
    my $genotyping_trial_id = $c->req->param("genotyping_trial_id");
    my @genotyping_trial_id_list = $c->req->param("genotyping_trial_id_list") ? split ',', $c->req->param("genotyping_trial_id_list") : ();

    my $selected_cols = $c->req->param('selected_columns') ? JSON::XS->new()->decode( $c->req->param('selected_columns') ) : {};
    if ($data_level eq 'plate'){
        $selected_cols = {'trial_name'=>1, 'acquisition_date'=>1, 'plot_name'=>1, 'plot_number'=>1, 'row_number'=>1, 'col_number'=>1, 'source_observation_unit_name'=>1,
        'accession_name'=>1, 'synonyms'=>1, 'dna_person'=>1, 'notes'=>1, 'tissue_type'=>1, 'extraction'=>1, 'concentration'=>1, 'volume'=>1, 'is_blank'=>1};
    }

    my $plugin = "";
    if ($format eq "intertekxls") {
        $plugin = "GenotypingTrialLayoutIntertekXLS";
    }
    if ($format eq "dartseqcsv") {
        $plugin = "GenotypingTrialLayoutDartSeqCSV";
    }
    if ($format eq "csv") {
        $plugin = "TrialLayoutCSV";
    }

    my $dir = $c->tempfiles_subdir('download');
    my $temp_file_name = "genotyping_plate_layouts"."XXXX";
    my $rel_file = $c->tempfile( TEMPLATE => "download/$temp_file_name");
    $rel_file = $rel_file . ".$format";
    my $tempfile = $c->config->{basepath}."/".$rel_file;

    print STDERR "TEMPFILE : $tempfile\n";

    my $trial_download_args = {
        bcs_schema => $schema,
        trial_list => \@genotyping_trial_id_list,
        filename => $tempfile,
        format => $plugin,
        data_level => $data_level,
        selected_columns => $selected_cols
    };
    if ($genotyping_trial_id) {
        $trial_download_args->{trial_id} = $genotyping_trial_id;
    }
    my $download = CXGN::Trial::Download->new($trial_download_args);
    my $error = $download->download();

    if ($format eq 'intertekxls'){
        $format = 'xls';
    }
    if ($format eq 'dartseqcsv'){
        $format = 'csv';
    }

    my $file_name = "genotyping_plate_layouts.$format";
    $c->res->content_type('Application/'.$format);
    $c->res->header('Content-Disposition', qq[attachment; filename="$file_name"]);
    my $output = read_file($tempfile);
    $c->res->body($output);
}

sub _parse_list_from_json {
    my $list_json = shift;

    if ($list_json) {
	#my $decoded_list = $json->allow_nonref->relaxed->escape_slash->loose->allow_singlequote->allow_barekey->decode($list_json);
	my $decoded_list = JSON::XS->new()->decode($list_json);
	my @array_of_list_items = @{$decoded_list};
	return \@array_of_list_items;
    }
    else {
	return;
    }
}


# Search for trial by trial name
# Display trial detail page for 1 match, error messages for no matches
sub search_trial : Private {
    my ( $self, $c, $trial_query ) = @_;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $rs = $schema->resultset('Project::Project');
    
    my $matches;
    my $count = 0;

    # Search by name
    if ( defined($trial_query) ) {
        $matches = $rs->search({
                'UPPER(name)' => uc($trial_query)
            }
        );
        $count = $matches->count;
    }

    # NO MATCH FOUND
    if ( $count != 1 ) {
        $c->stash->{template} = "generic_message.mas";
        $c->stash->{message} = "<strong>No Matching Trial Found</strong> ($trial_query)<br />You can view and search for trials from the <a href='/search/trials'>Trial Search Page</a>";
    }

    # 1 MATCH FOUND - FORWARD TO VIEW TRIAL
    else {
        my $trial_id = $matches->first->project_id;
        $c->stash->{trial_id} = $trial_id;

        my $schema = $c->dbic_schema("Bio::Chado::Schema");
        $c->stash->{schema} = $schema;
        
        my $trial = CXGN::Trial->new( { bcs_schema => $schema, trial_id => $trial_id });
        $c->stash->{trial} = $trial;

        $c->forward('trial_info');
    }
}


1;
