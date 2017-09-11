
package SGN::Controller::BreedersToolbox::Trial;

use Moose;

use File::Basename;
use File::Slurp qw | read_file |;
use URI::FromHash 'uri';

use CXGN::Trial::TrialLayout;
use CXGN::BreedersToolbox::Projects;
use SGN::View::Trial qw/design_layout_view design_info_view trial_detail_design_view/;
use CXGN::Trial::Download;

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
    my $self = shift;
    my $c = shift;
    my $format = $c->req->param("format");
    #print STDERR $format;
    my $user = $c->user();
    if (!$user) {
	$c->res->redirect( uri( path => '/solpeople/login.pl', query => { goto_url => $c->req->uri->path_query } ) );
	return;
    }

    $c->stash->{user_can_modify} = ($user->check_roles("submitter") || $user->check_roles("curator")) ;

    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $trial = $c->stash->{trial};
    my $program_object = CXGN::BreedersToolbox::Projects->new( { schema => $schema });

    if (!$program_object->trial_exists($c->stash->{trial_id})) {
	$c->stash->{message} = "The requested trial does not exist or has been deleted.";
	$c->stash->{template} = 'generic_message.mas';
	return;
    }

    $c->stash->{trial_name} = $trial->get_name();

    my $trial_type_data = $trial->get_project_type();
    $c->stash->{trial_type} = $trial_type_data->[1];

    $c->stash->{planting_date} = $trial->get_planting_date();

    $c->stash->{harvest_date} = $trial->get_harvest_date();

    $c->stash->{trial_description} = $trial->get_description();
    $c->stash->{trial_phenotype_files} = $trial->get_phenotype_metadata();

    my $location_data = $trial->get_location();
    $c->stash->{location_id} = $location_data->[0];
    $c->stash->{location_name} = $location_data->[1];

    my $breeding_program_data = $program_object->get_breeding_programs_by_trial($c->stash->{trial_id});
    $c->stash->{breeding_program_id} = $breeding_program_data->[0]->[0];
    $c->stash->{breeding_program_name} = $breeding_program_data->[0]->[1];

    $c->stash->{year} = $trial->get_year();

    $c->stash->{trial_id} = $c->stash->{trial_id};

    $c->stash->{has_plant_entries} = $trial->has_plant_entries();
    $c->stash->{has_subplot_entries} = $trial->has_subplot_entries();
    $c->stash->{phenotypes_fully_uploaded} = $trial->get_phenotypes_fully_uploaded();

    $c->stash->{hidap_enabled} = $c->config->{hidap_enabled};
    $c->stash->{has_expression_atlas} = $c->config->{has_expression_atlas};
    $c->stash->{expression_atlas_url} = $c->config->{expression_atlas_url};
    $c->stash->{site_project_name} = $c->config->{project_name};
    $c->stash->{sgn_session_id} = $c->req->cookie('sgn_session_id');
    $c->stash->{user_name} = $c->user->get_object->get_username;

    if ($trial->get_folder) {
      $c->stash->{folder_id} = $trial->get_folder()->project_id();
      $c->stash->{folder_name} = $trial->get_folder()->name();
    }

    my $design_type = $trial->get_design_type();
    $c->stash->{design_name} = $design_type;

    if ($design_type eq "genotyping_plate") {
	if ($format eq "as_table") {
	    $c->stash->{template} = '/breeders_toolbox/genotyping_trials/format/as_table.mas';
	}
	else {
	    $c->stash->{template} = '/breeders_toolbox/genotyping_trials/detail.mas';
	}

    }
    elsif ($design_type eq "treatment"){
        $c->stash->{template} = '/breeders_toolbox/treatment.mas';
    }
    else {
        $c->stash->{template} = '/breeders_toolbox/trial.mas';
    }

    print STDERR "End Load Trial Detail Page: ".localtime()."\n";

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


sub trial_tree : Path('/breeders/trialtree') Args(0) {
    my $self = shift;
    my $c = shift;


    $c->stash->{template} = '/breeders_toolbox/trialtree.mas';

}

#For downloading trial layout in CSV and Excel, for downloading trial phenotypes in CSV and Excel, and for downloading trial phenotyping spreadsheets in Excel.
#For phenotype download, better to use SGN::Controller::BreedersToolbox::Download->download_phenotypes_action and provide a single trial_id in the trial_list argument. This is how the phenotype download works from the wizard page, the trial tree page, and the trial detail page for phenotype download.
sub trial_download : Chained('trial_init') PathPart('download') Args(1) {
    my $self = shift;
    my $c = shift;
    my $what = shift;


    my $user = $c->user();
    if (!$user) {
        $c->res->redirect( uri( path => '/solpeople/login.pl', query => { goto_url => $c->req->uri->path_query } ) );
        return;
    }

    my $format = $c->req->param("format") || "xls";
    my $data_level = $c->req->param("dataLevel") || "plot";
    my $timestamp_option = $c->req->param("timestamp") || 0;
    my $trait_list = $c->req->param("trait_list");
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

    my @trait_list;
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

    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $trial_name = $trial->get_name();
    my $trial_id = $trial->get_trial_id();
    my $dir = $c->tempfiles_subdir('download');
    my $temp_file_name = $trial_id . "_" . "$what" . "XXXX";
    my $rel_file = $c->tempfile( TEMPLATE => "download/$temp_file_name");
    $rel_file = $rel_file . ".$format";
    my $tempfile = $c->config->{basepath}."/".$rel_file;

    print STDERR "TEMPFILE : $tempfile\n";

    my $download = CXGN::Trial::Download->new({
        bcs_schema => $c->stash->{schema},
        trial_id => $c->stash->{trial_id},
        trait_list => \@trait_list,
        filename => $tempfile,
        format => $plugin,
        data_level => $data_level,
        search_type => $search_type,
        include_timestamp => $timestamp_option,
    });

    my $error = $download->download();

    my $file_name = $trial_id . "_" . "$what" . ".$format";
    $c->res->content_type('Application/'.$format);
    $c->res->header('Content-Disposition', qq[attachment; filename="$file_name"]);

    my $output = read_file($tempfile);

    $c->res->body($output);

}

sub _parse_list_from_json {
    my $list_json = shift;
    my $json = new JSON;
    if ($list_json) {
	my $decoded_list = $json->allow_nonref->utf8->relaxed->escape_slash->loose->allow_singlequote->allow_barekey->decode($list_json);
	#my $decoded_list = decode_json($list_json);
	my @array_of_list_items = @{$decoded_list};
	return \@array_of_list_items;
    }
    else {
	return;
    }
}


1;
