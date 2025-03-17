
###NOTE: This controller points to CXGN::Trial::Download for the phenotype download.

package SGN::Controller::BreedersToolbox::Download;

use Moose;

BEGIN { extends 'Catalyst::Controller'; }

use strict;
use warnings;
use utf8;
use JSON::XS;
use Data::Dumper;
use CGI;
use CXGN::Trial;
use CXGN::Trial::TrialLayout;
use File::Slurp qw | read_file |;
use File::Temp qw(tempfile tempdir);
use File::Basename;
use File::Copy;
use URI::FromHash 'uri';
use CXGN::List;
use CXGN::List::Transform;
use Excel::Writer::XLSX;
use CXGN::Trial::Download;
use POSIX qw(strftime);
use Sort::Maker;
use DateTime;
use SGN::Model::Cvterm;
use CXGN::Trial::TrialLookup;
use CXGN::Location::LocationLookup;
use CXGN::Stock::StockLookup;
use CXGN::Phenotypes::PhenotypeMatrix;
use CXGN::Phenotypes::MetaDataMatrix;
use CXGN::Genotype::Search;
use CXGN::Login;
use CXGN::Genotype::DownloadFactory;
use CXGN::Genotype::GRM;
use CXGN::Genotype::GWAS;
use CXGN::Accession;
use CXGN::Stock::Seedlot::Maintenance;
use CXGN::Dataset;
use CXGN::Stock;
use CXGN::Project;
use IO::Compress::Gzip qw(gzip $GzipError);
use Catalyst::Utils;
use SGN::Image;
use Archive::Tar;

sub breeder_download : Path('/breeders/download/') Args(0) {
    my $self = shift;
    my $c = shift;

    if (!$c->user()) {
	    # redirect to login page
	    $c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
	    return;
    }

    $c->stash->{seedlot_maintenance_enabled} = defined $c->config->{seedlot_maintenance_event_ontology_root} && $c->config->{seedlot_maintenance_event_ontology_root} ne '';
    $c->stash->{template} = '/breeders_toolbox/download.mas';
}

#Deprecated. Look t0 SGN::Controller::BreedersToolbox::Trial->trial_download
#sub download_trial_layout_action : Path('/breeders/trial/layout/download') Args(1) {
#    my $self = shift;
#    my $c = shift;
#    my $trial_id = shift;
#    my $format = $c->req->param("format");

#    my $trial = CXGN::Trial::TrialLayout -> new({ schema => $c->dbic_schema("Bio::Chado::Schema"), trial_id => $trial_id, experiment_type => 'field_layout' });

#    my $design = $trial->get_design();

#    $self->trial_download_log($c, $trial_id, "trial layout");

#    if ($format eq "csv") {
#       $self->download_layout_csv($c, $trial_id, $design);
#    }
#    else {
#       $self->download_layout_excel($c, $trial_id, $design);
#    }
#}

#Deprecated by deprecation of download_trial_layout_action
#sub download_layout_csv {
#    my $self = shift;
#    my $c = shift;
#    my $trial_id = shift;

#    $c->tempfiles_subdir("downloads"); # make sure the dir exists
#    my ($fh, $tempfile) = $c->tempfile(TEMPLATE=>"download/trial_layout_".$trial_id."_XXXXX");

#    close($fh);

#    my $file_path = $c->config->{basepath}."/".$tempfile.".csv"; # need xls extension to avoid trouble

#    move($tempfile, $file_path);

#    my $td = CXGN::Trial::Download->new(
#   	{
#   	    bcs_schema => $c->dbic_schema("Bio::Chado::Schema"),
#   	    trial_id => $trial_id,
#   	    filename => $file_path,
#   	    format => "TrialLayoutCSV",
#       },
#	);

#    $td->download();
#     my $file_name = basename($file_path);
#     $c->res->content_type('Application/csv');
#     $c->res->header('Content-Disposition', qq[attachment; filename="$file_name"]);

#    my $output = read_file($file_path);

#    $c->res->body($output);
#}

#Deprecated by deprecation of download_trial_layout_action
#sub download_layout_excel {
#    my $self = shift;
#    my $c = shift;
#    my $trial_id = shift;

#    $c->tempfiles_subdir("downloads"); # make sure the dir exists
#    my ($fh, $tempfile) = $c->tempfile(TEMPLATE=>"downloads/trial_layout_".$trial_id."_XXXXX");

#    close($fh);

#    my $file_path = $c->config->{basepath}."/".$tempfile.".xls"; # need xls extension to avoid trouble

#    move($tempfile, $file_path);

#    my $td = CXGN::Trial::Download->new(
#   	{
#   	    bcs_schema => $c->dbic_schema("Bio::Chado::Schema"),
#   	    trial_id => $trial_id,
#   	    filename => $file_path,
#   	    format => "TrialLayoutExcel",
#   	},
#	);

#    $td->download();
#      my $file_name = basename($file_path);
#     $c->res->content_type('Application/xls');
#     $c->res->header('Content-Disposition', qq[attachment; filename="$file_name"]);

#    my $output = read_file($file_path);

#    $c->res->body($output);

#}



#sub download_datacollector_excel {
#    my $self = shift;
#    my $c = shift;
#    my $trial_id = shift;

#    $c->tempfiles_subdir("downloads"); # make sure the dir exists
#    my ($fh, $tempfile) = $c->tempfile(TEMPLATE=>"downloads/DataCollector_".$trial_id."_XXXXX");

#    close($fh);

#    my $file_path = $c->config->{basepath}."/".$tempfile.".xls"; # need xls extension to avoid trouble

#    move($tempfile, $file_path);

#    my $td = CXGN::Trial::Download->new(
#	{
#	    bcs_schema => $c->dbic_schema("Bio::Chado::Schema"),
#	    trial_id => $trial_id,
#	    filename => $file_path,
#	    format => "DataCollectorExcel",
#	},
#	);

#    $td->download();
#      my $file_name = basename($file_path);
#     $c->res->content_type('Application/xls');
#     $c->res->header('Content-Disposition', qq[attachment; filename="$file_name"]);

#    my $output = read_file($file_path);

#    $c->res->body($output);

#}

sub _parse_list_from_json {
    my $list_json = shift;
#    print STDERR "LIST JSON: ". Dumper $list_json;
    my $json = new JSON;
    if ($list_json) {
       # my $decoded_list = $json->allow_nonref->relaxed->escape_slash->loose->allow_singlequote->allow_barekey->decode($list_json);
        my $decoded_list = decode_json($list_json);
        my @array_of_list_items = @{$decoded_list};
        return \@array_of_list_items;
    } else {
        return;
    }
}

#used from wizard page, trial detail page, and manage trials page for downloading phenotypes
sub download_phenotypes_action : Path('/breeders/trials/phenotype/download') Args(0) {
    my $self = shift;
    my $c = shift;

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $sp_person_id);
    my $sgn_session_id = $c->req->param("sgn_session_id");

    my $user = $c->user();
    if (!$user && !$sgn_session_id) {
        $c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
        return;
    } elsif (!$user && $sgn_session_id) {
        my $login = CXGN::Login->new($schema->storage->dbh);
        my $logged_in = $login->query_from_cookie($sgn_session_id);
        if (!$logged_in){
            $c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
            return;
        }
    }

    my $has_header = defined($c->req->param('has_header')) ? $c->req->param('has_header') : 1;
    my $search_type = $c->req->param("speed") && $c->req->param("speed") ne 'null' ? $c->req->param("speed") : "Native";
    my $format = $c->req->param("format") && $c->req->param("format") ne 'null' ? $c->req->param("format") : "xlsx";
    my $data_level = $c->req->param("dataLevel") && $c->req->param("dataLevel") ne 'null' ? $c->req->param("dataLevel") : "plot";
    my $timestamp_option = $c->req->param("timestamp") && $c->req->param("timestamp") ne 'null' ? $c->req->param("timestamp") : 0;
    my $entry_numbers_option = $c->req->param("entry_numbers") && $c->req->param("entry_numbers") ne 'null' ? $c->req->param("entry_numbers") : 0;
    my $exclude_phenotype_outlier = $c->req->param("exclude_phenotype_outlier") && $c->req->param("exclude_phenotype_outlier") ne 'null' && $c->req->param("exclude_phenotype_outlier") ne 'undefined' ? $c->req->param("exclude_phenotype_outlier") : 0;
    my $include_pedigree_parents = $c->req->param('include_pedigree_parents');
    my $trait_list = $c->req->param("trait_list");
    my $trait_component_list = $c->req->param("trait_component_list");
    my $year_list = $c->req->param("year_list");
    my $location_list = $c->req->param("location_list");
    my $trial_list = $c->req->param("trial_list");
    my $accession_list = $c->req->param("accession_list");
    my $plot_list = $c->req->param("plot_list");
    my $plant_list = $c->req->param("plant_list");
    my $trait_contains = $c->req->param("trait_contains");
    my $phenotype_min_value = $c->req->param("phenotype_min_value") && $c->req->param("phenotype_min_value") ne 'null' ? $c->req->param("phenotype_min_value") : "";
    my $phenotype_max_value = $c->req->param("phenotype_max_value") && $c->req->param("phenotype_max_value") ne 'null' ? $c->req->param("phenotype_max_value") : "";

    my @trait_list;
    if ($trait_list && $trait_list ne 'null') {
	print STDERR "trait_list: ".Dumper $trait_list."\n";
	@trait_list = @{_parse_list_from_json($trait_list)};
    }
    my @trait_component_list;
    if ($trait_component_list && $trait_component_list ne 'null') {
	print STDERR "trait_component_list: ".Dumper $trait_component_list."\n";
	@trait_component_list = @{_parse_list_from_json($trait_component_list)};
    }
    my @trait_contains_list;
    if ($trait_contains && $trait_contains ne 'null') {
	print STDERR "trait_contains: ".Dumper $trait_contains."\n";
	@trait_contains_list = @{_parse_list_from_json($trait_contains)};
    }
    my @year_list;
    if ($year_list && $year_list ne 'null') {
	print STDERR "year list: ".Dumper $year_list."\n";
	@year_list = @{_parse_list_from_json($year_list)};
    }
    my @location_list;
    if ($location_list && $location_list ne 'null') {
	print STDERR "location list: ".Dumper $location_list."\n";
	@location_list = @{_parse_list_from_json($location_list)};
    }
    my @trial_list;
    if ($trial_list && $trial_list ne 'null') {
	print STDERR "trial list: ".Dumper $trial_list."\n";
	@trial_list = @{_parse_list_from_json($trial_list)};
    }
    my @accession_list;
    if ($accession_list && $accession_list ne 'null') {
	print STDERR "accession list: ".Dumper $accession_list."\n";
	@accession_list = @{_parse_list_from_json($accession_list)};
    }
    my @plot_list;
    if ($plot_list && $plot_list ne 'null') {
	print STDERR "plot list: ".Dumper $plot_list."\n";
	@plot_list = @{_parse_list_from_json($plot_list)};
    }
    my @plant_list;
    if ($plant_list && $plant_list ne 'null') {
	print STDERR "plant list: ".Dumper $plant_list."\n";
	@plant_list = @{_parse_list_from_json($plant_list)};
    }

    #Input list arguments can be arrays of integer ids or strings; however, when fed to CXGN::Trial::Download, they must be arrayrefs of integer ids
    my @trait_list_int;
    foreach (@trait_list) {
        if ($_ =~ m/^\d+$/) {
            push @trait_list_int, $_;
        } else {
            my $cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, $_)->cvterm_id();
            push @trait_list_int, $cvterm_id;
        }
    }

    if (scalar(@trait_component_list)>0){
        if ($trait_component_list[0] =~ m/^\d+$/) {
            my $trait_cvterm_ids = SGN::Model::Cvterm->get_traits_from_components($schema, \@trait_component_list);
            foreach (@$trait_cvterm_ids) {
              push @trait_list_int, $_;
            }
        } else {
            my @trait_component_ids;
            foreach (@trait_component_list) {
                my $cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, $_)->cvterm_id();
                push @trait_component_ids, $cvterm_id;
            }
            my $trait_cvterm_ids = SGN::Model::Cvterm->get_traits_from_components($schema, \@trait_component_ids);
            foreach (@$trait_cvterm_ids) {
              push @trait_list_int, $_;
            }
        }
    }

    my @plot_list_int;
    foreach (@plot_list) {
        if ($_ =~ m/^\d+$/) {
            push @plot_list_int, $_;
        } else {
            my $stock_lookup = CXGN::Stock::StockLookup->new({ schema => $schema, stock_name=>$_ });
            my $stock_id = $stock_lookup->get_stock_exact()->stock_id();
            push @plot_list_int, $stock_id;
        }
    }
    my @accession_list_int;
    foreach (@accession_list) {
        if ($_ =~ m/^\d+$/) {
            push @accession_list_int, $_;
        } else {
            my $stock_lookup = CXGN::Stock::StockLookup->new({ schema => $schema, stock_name=>$_ });
            my $stock_id = $stock_lookup->get_stock_exact()->stock_id();
            push @accession_list_int, $stock_id;
        }
    }
    my @plant_list_int;
    foreach (@plant_list) {
        if ($_ =~ m/^\d+$/) {
            push @plant_list_int, $_;
        } else {
            my $stock_lookup = CXGN::Stock::StockLookup->new({ schema => $schema, stock_name=>$_ });
            my $stock_id = $stock_lookup->get_stock_exact()->stock_id();
            push @plant_list_int, $stock_id;
        }
    }
    my @trial_list_int;
    my $trial_name = "";
    foreach (@trial_list) {
        if ($_ =~ m/^\d+$/) {
            push @trial_list_int, $_;
	    my $trial = CXGN::Trial->new( { bcs_schema => $schema, trial_id => $_ });
	    $trial_name = $trial->get_name();
	    $trial_name =~ s/ /\_/g;
        } else {
	    $trial_name = $_;
            my $trial_lookup = CXGN::Trial::TrialLookup->new({ schema => $schema, trial_name=>$_ });
            my $trial_id = $trial_lookup->get_trial()->project_id();
            push @trial_list_int, $trial_id;
        }
    }
    my @location_list_int;
    foreach (@location_list) {
        if ($_ =~ m/^\d+$/) {
            push @location_list_int, $_;
        } else {
            my $location_lookup = CXGN::Location::LocationLookup->new({ schema => $schema, location_name=>$_ });
            my $location_id = $location_lookup->get_geolocation()->nd_geolocation_id();
            push @location_list_int, $location_id;
        }
    }

    my $plugin = "";
    if ($format eq "xlsx") {
        $plugin = $entry_numbers_option ? "TrialPhenotypeExcelEntryNumbers" : "TrialPhenotypeExcel";
    }
    if ($format eq "csv") {
        $plugin = $entry_numbers_option ? "TrialPhenotypeCSVEntryNumbers" : "TrialPhenotypeCSV";
    }

    my $temp_file_name;
    my $download_file_name;
    my $dir = $c->tempfiles_subdir('download');

    if ($data_level eq 'metadata'){
        $temp_file_name = "metadata" . "XXXX";
        $download_file_name = "metadata.$format";
    }else{
        $temp_file_name = "phenotype" . "XXXX";
        $download_file_name = $trial_name."_phenotypes.$format";
    }
    my $rel_file = $c->tempfile( TEMPLATE => "download/$temp_file_name");
    $rel_file = $rel_file . ".$format";
    my $tempfile = $c->config->{basepath}."/".$rel_file;

    print STDERR "TEMPFILE : $tempfile\n";
    print STDERR "Plugin is $plugin\n";
    #List arguments should be arrayrefs of integer ids
    my $download = CXGN::Trial::Download->new({
        bcs_schema => $schema,
        trait_list => \@trait_list_int,
        year_list => \@year_list,
        location_list => \@location_list_int,
        trial_list => \@trial_list_int,
        accession_list => \@accession_list_int,
        plot_list => \@plot_list_int,
        plant_list => \@plant_list_int,
        filename => $tempfile,
        format => $plugin,
        data_level => $data_level,
        include_timestamp => $timestamp_option,
        include_pedigree_parents=>$include_pedigree_parents,
        exclude_phenotype_outlier => $exclude_phenotype_outlier,
        trait_contains => \@trait_contains_list,
        phenotype_min_value => $phenotype_min_value,
        phenotype_max_value => $phenotype_max_value,
        has_header => $has_header,
        search_type => $search_type
    });

    my $error = $download->download();

    $c->res->content_type('Application/'.$format);
    $c->res->header('Content-Disposition', qq[attachment; filename="$download_file_name"]);

    my $output = read_file($tempfile);  ## works for xls format

    $c->res->body($output);
}


#Deprecated. Look to download_phenotypes_action
#sub download_trial_phenotype_action : Path('/breeders/trial/phenotype/download') Args(1) {
#    my $self = shift;
#    my $c = shift;
#    my $trial_id = shift;
#    my $format = $c->req->param("format");

#    my $schema = $c->dbic_schema("Bio::Chado::Schema");
#    my $plugin = "TrialPhenotypeExcel";
#    if ($format eq "csv") { $plugin = "TrialPhenotypeCSV"; }

#    my $t = CXGN::Trial->new( { bcs_schema => $schema, trial_id => $trial_id });

#    $c->tempfiles_subdir("download");
#    my $trial_name = $t->get_name();
#    $trial_name =~ s/ /\_/g;
#    my $location = $t->get_location()->[1];
#    $location =~ s/ /\_/g;
#    my ($fh, $tempfile) = $c->tempfile(TEMPLATE=>"download/trial_".$trial_name."_phenotypes_".$location."_".$trial_id."_XXXXX");

#    close($fh);
#    my $file_path = $c->config->{basepath}."/".$tempfile.".".$format;
#    move($tempfile, $file_path);


#    my $td = CXGN::Trial::Download->new( {
#	bcs_schema => $schema,
#	trial_id => $trial_id,
#	format => $plugin,
#        filename => $file_path,
#	user_id => $c->user->get_object()->get_sp_person_id(),
#	trial_download_logfile => $c->config->{trial_download_logfile},
#    }
#    );

#    $td->download();

#	     my $file_name = basename($file_path);

#     $c->res->content_type('Application/'.$format);
#     $c->res->header('Content-Disposition', qq[attachment; filename="$file_name"]);

#    my $output = read_file($file_path);

#    $c->res->body($output);
#}


#used from manage download page for downloading phenotypes and from dataset with outliers to download phenotypes table
sub download_action : Path('/breeders/download_action') Args(0) {
    my $self = shift;
    my $c = shift;

    my $accession_list_id = $c->req->param("accession_list_list_select");
    my $trait_list_id     = $c->req->param("trait_list_list_select");
    my $trial_list_id     = $c->req->param("trial_list_list_select");
    my $dl_token = $c->req->param("phenotype_download_token") || "no_token";
    if (!$trial_list_id && !$accession_list_id && !$trait_list_id){
        $trial_list_id     = $c->req->param("trial_metadata_list_list_select");
        $dl_token = $c->req->param("metadata_download_token") || "no_token";
    }
    my $format            = $c->req->param("format");
    if (!$format){
        $format            = $c->req->param("metadata_format");
    }
    my $datalevel         = $c->req->param("phenotype_datalevel");
    if (!$datalevel){
        $datalevel         = $c->req->param("metadata_datalevel");
    }
    my $exclude_phenotype_outlier = $c->req->param("exclude_phenotype_outlier") || 0;
    my $timestamp_included = $c->req->param("timestamp") || 0;

    # parameters for outliers download
    my @trait_ids     = split(',', $c->req->param("trait_ids_list"));
    my $dataset_id   = $c->req->param("dataset_id");

    my $dl_cookie = "download".$dl_token;
    print STDERR "Token is: $dl_token\n";

    my $accession_data;
    if ($accession_list_id) {
	    $accession_data = SGN::Controller::AJAX::List->retrieve_list($c, $accession_list_id);
    }

    my $trial_data;
    if ($trial_list_id) {
	    $trial_data = SGN::Controller::AJAX::List->retrieve_list($c, $trial_list_id);
    }

    my $trait_data;
    if ($trait_list_id) {
	    $trait_data = SGN::Controller::AJAX::List->retrieve_list($c, $trait_list_id);
    }

    my $outliers;
    if (defined $dataset_id) {
        my $people_schema = $c->dbic_schema("CXGN::People::Schema");
        my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");
        my $dataset = CXGN::Dataset->new(people_schema => $people_schema, schema => $schema, sp_dataset_id => int($dataset_id), exclude_dataset_outliers => 1);
        $outliers = $dataset->outliers();
    }


    my @accession_list = map { $_->[1] } @$accession_data;
    my @trial_list = map { $_->[1] } @$trial_data;
    my @trait_list = map { $_->[1] } @$trait_data;

    my $tf = CXGN::List::Transform->new();

    my $unique_transform = $tf->can_transform("accession_synonyms", "accession_names");

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $unique_list = $tf->transform($c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id), $unique_transform, \@accession_list);

    # get array ref out of hash ref so Transform/Plugins can use it
    my %unique_hash = %$unique_list;
    my $unique_accessions = $unique_hash{transform};

    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado", $sp_person_id);
    my $t = CXGN::List::Transform->new();

    my $acc_t = $t->can_transform("accessions", "accession_ids");
    my $accession_id_data = $t->transform($schema, $acc_t, $unique_accessions);

    my $trial_t = $t->can_transform("trials", "trial_ids");
    my $trial_id_data = $t->transform($schema, $trial_t, \@trial_list);

    my $trait_t = $t->can_transform("traits", "trait_ids");
    my $trait_id_data = $t->transform($schema, $trait_t, \@trait_list);

    my $output = "";

    # if we work with dataset then @trait_ids we have directly from http request but we need reference/pointer to it
    # if we work with lists than we need to use result of transform method from class Transform - reference type to list
    my $trait_list_ref = defined $dataset_id ? \@trait_ids : $trait_id_data->{transform},

    my @data;
    if ($datalevel eq 'metadata'){
        my $metadata_search = CXGN::Phenotypes::MetaDataMatrix->new(
    		bcs_schema=>$schema,
    		search_type=>'MetaData',
    		data_level=>$datalevel,
    		trial_list=>$trial_id_data->{transform},
    	);
    	@data = $metadata_search->get_metadata_matrix();
    }
    else {
    	my $phenotypes_search = CXGN::Phenotypes::PhenotypeMatrix->new(
    		bcs_schema=>$schema,
    		search_type=>'MaterializedViewTable',
            trait_list=>$trait_list_ref,
    		trial_list=>$trial_id_data->{transform},
    		accession_list=>$accession_id_data->{transform},
    		include_timestamp=>$timestamp_included,
            exclude_phenotype_outlier=>$exclude_phenotype_outlier,
            dataset_exluded_outliers=>$outliers,
    		data_level=>$datalevel,
    	);
    	@data = $phenotypes_search->get_phenotype_matrix();
    }

    if ($format eq "html") { #dump html in browser
        $output = "";
        my @header = @{$data[0]};
        my $num_col = scalar(@header);
        for (my $line =0; $line< @data; $line++) {
            my @columns = @{$data[$line]};
            my $step = 1;
            for(my $i=0; $i<$num_col; $i++) {
                if ($columns[$i]) {
                    $output .= "\"$columns[$i]\"";
                } else {
                    $output .= "\"\"";
                }
                if ($step < $num_col) {
                    $output .= ",";
                }
                $step++;
            }
            $output .= "\n";
        }
        $c->res->content_type("text/plain");
        $c->res->body($output);

    } else {
        # if xls or csv, create tempfile name and place to save it

        my $what;
        if ($datalevel eq 'metadata'){$what = "metadata_download";}
        else{$what = "phenotype_download"; }
        my $time_stamp = strftime "%Y-%m-%dT%H%M%S", localtime();
        my $dir = $c->tempfiles_subdir('download');
        my $temp_file_name = $time_stamp . "$what" . "XXXX";
        my $rel_file = $c->tempfile( TEMPLATE => "download/$temp_file_name");
        my $tempfile = $c->config->{basepath}."/".$rel_file;
        if ($format eq ".csv") {

            #build csv with column names
            open(my $csv_fh, "> :encoding(UTF-8)", $tempfile) || die "Can't open file $tempfile\n";
                my @header = @{$data[0]};
                my $num_col = scalar(@header);
                for (my $line =0; $line< @data; $line++) {
                    my @columns = @{$data[$line]};
                    my $step = 1;
                    for(my $i=0; $i<$num_col; $i++) {
                        if (defined($columns[$i])) {
                            print $csv_fh "\"$columns[$i]\"";
                        } else {
                            print $csv_fh "\"\"";
                        }
                        if ($step < $num_col) {
                            print $csv_fh ",";
                        }
                        $step++;
                    }
                    print $csv_fh "\n";
                }
            close $csv_fh;

        } else {
            my $ss = Excel::Writer::XLSX->new($tempfile);
            my $ws = $ss->add_worksheet();

            for (my $line =0; $line< @data; $line++) {
                my @columns = @{$data[$line]};
                for(my $col = 0; $col<@columns; $col++) {
                    $ws->write($line, $col, $columns[$col]);
                }
            }
            #$ws->write(0, 0, "$program_name, $location ($year)");
            $ss ->close();

            $format = ".xlsx";
        }

        #Using tempfile and new filename,send file to client
        my $file_name = $time_stamp . "$what" . "$format";
        $c->res->content_type('Application/'.$format);
        $c->res->cookies->{$dl_cookie} = {
            value => $dl_token,
            expires => '+1m',
        };
        $c->res->header('Content-Disposition', qq[attachment; filename="$file_name"]);

	my $output = "";
	open(my $F, "< :raw", $tempfile) || die "Can't open file $tempfile for reading.";
	while (<$F>) {
	    $output .= $_;
	}
	close($F);

	#$output = read_file($tempfile, binmode=>':raw:utf8');  ## works for xls format

        $c->res->body($output);
    }
}



# accession properties download -- begin

#
# Download a file of accession properties (in the same format as the accession upload template)
#
# POST Params:
#   accession_properties_accession_list_list_select = list id of an accession list
#   file_format: format of the file output (.xls or .csv)
#
sub download_accession_properties_action : Path('/breeders/download_accession_properties_action') {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado", $sp_person_id);
    my $dbh = $schema->storage->dbh;

    # Get request params
    my $accession_list_id = $c->req->param("accession_properties_accession_list_list_select");
    my $file_format = $c->req->param("file_format") || ".xlsx";
    my $dl_token = $c->req->param("accession_properties_download_token") || "no_token";
    my $dl_cookie = "download".$dl_token;
    if ( !$accession_list_id ) {
        print STDERR "ERROR: No accession list id provided to download accession properties action";
        return;
    }

    # Get accession IDs from list
    my $accession_data = SGN::Controller::AJAX::List->retrieve_list($c, $accession_list_id);
    my @accession_list = map { $_->[1] } @$accession_data;

    my $t = CXGN::List::Transform->new();
    my $acc_t = $t->can_transform("accessions", "accession_ids");
    my $accession_id_hash = $t->transform($schema, $acc_t, \@accession_list);
    my @accession_ids = @{$accession_id_hash->{transform}};

    # Create tempfile
    my ($tempfile, $uri) = $c->tempfile(TEMPLATE => "download_accessions_XXXXX", UNLINK=> 0);

    # Build Accession Info
    my @editable_stock_props = split ',', $c->config->{editable_stock_props};

    my $rows = $self->build_accession_properties_info($dbh, \@accession_ids, \@editable_stock_props);

    # Create and Return XLS and XLSX  file
    if ( $file_format eq ".xlsx" ) {
        my $file_path = $tempfile . ".xlsx";
        my $file_name = basename($file_path);

        # Write to the xls file
        my $workbook = Excel::Writer::XLSX->new($file_path);
        my $worksheet = $workbook->add_worksheet();
        for ( my $i = 0; $i <= $#$rows; $i++ ) {
            $worksheet->write_row($i, 0, $rows->[$i]);
        }
        $workbook->close();

        # Return the xls file
        $c->res->content_type('application/application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        $c->res->cookies->{$dl_cookie} = {
            value => $dl_token,
            expires => '+1m',
        };
        $c->res->header('Content-Disposition', qq[attachment; filename="$file_name"]);

        my $output = read_file($file_path);  ### works here because it is xls, otherwise does not work with utf8
        $c->res->body($output);
    }

    # Create and Return CSV file
    elsif ( $file_format eq ".csv" ) {
        my $file_path = $tempfile . ".csv";
        my $file_name = basename($file_path);

        # Write to csv file
        open(my $csv_fh, "> :encoding(UTF-8)", $file_path) || die "Can't open file $file_path\n";
        my @header =  @{$rows->[0]};
        my $num_col = scalar(@header);

        for ( my $line = 0; $line <= $#$rows; $line++ ) {
            my $columns = $rows->[$line];
            my $step = 1;
            for ( my $i = 0; $i < $num_col; $i++ ) {
                if ($columns->[$i]) {
                    print $csv_fh "\"$columns->[$i]\"";
                } else {
                    print $csv_fh "\"\"";
                }
                if ($step < $num_col) {
                    print $csv_fh ",";
                }
                $step++;
            }
            print $csv_fh "\n";
        }
        close $csv_fh;

        # Return the csv file
        $c->res->content_type('text/csv');
        $c->res->cookies->{$dl_cookie} = {
            value => $dl_token,
            expires => '+1m',
        };
        $c->res->header('Content-Disposition', qq[attachment; filename="$file_name"]);

        my $output = "";
        open(my $F, "< :encoding(UTF-8)", $file_path) || die "Can't open file $file_path for reading.";
        while (<$F>) {
            $output .= $_;
        }
        close($F);
        $c->res->body($output);
    }

}

#
# Build Accession Properties Info
#
# Generate the rows in the accession info table for the specified Accessions
#
# Usage: my $rows = $self->build_accession_properties_info($dbh, \@accession_ids, \@editable_stock_props);
# Returns: an arrayref where each array item is an array of accession properties
#          the first item is an array of the header values
#
sub build_accession_properties_info {
    my $self = shift;
    my $dbh = shift;
    my $accession_ids = shift;
    my $editable_stock_props = shift;

    # Setup Stock Props
    my @stock_props = ("organization", "stock_synonym", "PUI");
    foreach my $esp (@$editable_stock_props) {
        if ( !grep(/^$esp$/, @stock_props) ) {
            push(@stock_props, $esp)
        }
    }

    # Build Header
    my @accession_headers = ("accession_name", "species_name", "population_name");
    push(@accession_headers, @stock_props);

    # Add Header to Rows
    my @accession_rows = ();
    push(@accession_rows, \@accession_headers);

    # Start query blocks
    my $select = "SELECT stock.uniquename AS accession_name, organism.species AS species_name, string_agg(distinct(rs.uniquename), ', ') AS population_name";
    my $from = "FROM public.stock";
    my $joins = "LEFT JOIN public.organism USING (organism_id)";
    $joins .= " LEFT JOIN public.stock_relationship ON (stock.stock_id = stock_relationship.subject_id AND stock_relationship.type_id = (SELECT cvterm_id FROM cvterm WHERE name = 'member_of' AND cv_id = (SELECT cv_id FROM cv WHERE name = 'stock_relationship')))";
    $joins .= " LEFT JOIN public.stock AS rs ON (stock_relationship.object_id = rs.stock_id)";
    my $group = "GROUP BY stock.stock_id, organism.species";
    my $order = "ORDER BY stock.uniquename ASC;";
    my @params;

    # Add each of the stock props
    my $count = 0;
    foreach my $sp (@stock_props) {
        $count++;
        my $table = "sp" . $count;
        $select .= ", string_agg(distinct($table.value), ', ') AS \"$sp\"";
        $joins .= " LEFT JOIN public.stockprop AS $table ON (stock.stock_id = $table.stock_id AND $table.type_id = (SELECT cvterm_id FROM cvterm WHERE name = '$sp' AND cv_id = (SELECT cv_id FROM cv WHERE name = 'stock_property')))";
    }

    # Build where block using accession ids
    my $where = "WHERE stock.stock_id IN (" . join(',', ('?') x @$accession_ids) . ")";
    push(@params, @$accession_ids);

    # Put query together
    my $q = "$select $from $joins $where $group $order";

    #print STDERR "QUERY = $q\n";

    # Execute the query and add results to accession rows
    my $h = $dbh->prepare($q);
    $h->execute(@params);
    while (my @results = $h->fetchrow_array()) {
        # print STDERR "RETRIEVED: ".join(",", @results)."\n";
        push(@accession_rows, \@results);
    }

    return \@accession_rows;
}

# accession properties download -- end



# pedigree download -- begin

sub download_pedigree_action : Path('/breeders/download_pedigree_action') {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado", $sp_person_id);
    my $dbh = $schema->storage->dbh;

    my $input_format = $c->req->param("input_format") || 'list_id';
    my @accession_ids = [];
    my $source_description;         # used as a comment in the helium output file
    if ($input_format eq 'accession_ids') {       #use accession ids supplied directly
        my $id_string = $c->req->param("ids");
        @accession_ids = split(',',$id_string);
        $source_description = "Pedigrees of provided Accession IDs: $id_string";
    }
    elsif ($input_format eq 'list_id') {        #get accession names from list and tranform them to ids
        my $accession_list_id = $c->req->param("pedigree_accession_list_list_select");
        my $accession_data = SGN::Controller::AJAX::List->retrieve_list($c, $accession_list_id);
        my @accession_list = map { $_->[1] } @$accession_data;

        my $t = CXGN::List::Transform->new();
        my $acc_t = $t->can_transform("accessions", "accession_ids");
        my $accession_id_hash = $t->transform($schema, $acc_t, \@accession_list);
        @accession_ids = @{$accession_id_hash->{transform}};

        my $list = CXGN::List->new({ dbh => $dbh, list_id => $accession_list_id });
        my $list_name = $list->name();
        $source_description = "Pedigrees of Accessions in List: $list_name";
    }

    my $ped_format = $c->req->param("ped_format") || "parents_only";
    my $ped_include = $c->req->param("ped_include") || "ancestors";
    my $file_format = $c->req->param("file_format") || ".txt";
    my $dl_token = $c->req->param("pedigree_download_token") || "no_token";
    my $dl_cookie = "download".$dl_token;

    my ($tempfile, $uri) = $c->tempfile(TEMPLATE => "pedigree_download_XXXXX", UNLINK=> 0);
    open(my $FILE, '> :encoding(UTF-8)', $tempfile) or die "Cannot open tempfile $tempfile: $!";
    my $filename;

    # Get the pedigrees
    my $stock = CXGN::Stock->new ( schema => $schema);
    my $pedigree_rows = $stock->get_pedigree_rows(\@accession_ids, $ped_format, $ped_include);

    # HELIUM FORMAT
    if ( $file_format eq ".helium" ) {
        print $FILE "# $source_description\n";
        print $FILE "# Pedigree Format: $ped_format\n";
        print $FILE "# Include: " . join(' and ', split(/_/, $ped_include))  . "\n";
        if (scalar(@$pedigree_rows) == 0) {
            print $FILE "# No pedigrees found for the provided source\n";
        }

        print $FILE "# heliumInput = PEDIGREE\n";
        print $FILE "LineName\tFemaleParent\tMaleParent\n";
        foreach my $row (@$pedigree_rows) {
            my ($progeny, $female_parent, $male_parent, $cross_type) = split "\t", $row;
            my $string = join ("\t", $progeny, $female_parent ? $female_parent : '', $male_parent ? $male_parent : '');
            print $FILE "$string\n";
        }

        close $FILE;
        $filename = "pedigree.helium";
    }

    # GENERAL TEXT FORMAT
    else {
        print $FILE "Accession\tFemale_Parent\tMale_Parent\tCross_Type\n";
        my $pedigrees_found = 0;
        foreach my $row (@$pedigree_rows) {
            print $FILE $row;
            $pedigrees_found++;
        }

        unless ($pedigrees_found > 0) {
            print $FILE "$pedigrees_found pedigrees found in the database for the accessions searched. \n";
        }
        close $FILE;

        $filename = "pedigree.txt";
    }

    $c->res->content_type("application/text");
    $c->res->cookies->{$dl_cookie} = {
      value => $dl_token,
      expires => '+1m',
    };
    $c->res->header("Filename", $filename);
    $c->res->header("Content-Disposition", qq[attachment; filename="$filename"]);


    #my $output = read_file($tempfile, binmode => ':utf8' );

    ### read_file does not read UTF-8 correctly, even with binmode :raw
    my $output = "";
    open(my $F, "< :encoding(UTF-8)", $tempfile) || die "Can't open file $tempfile for reading.";
    while (<$F>) {
        $output .= $_;
    }
    close($F);

    $c->res->body($output);
}

# pedigree download -- end

#=pod


# seedlot maintenance events download -- start

#
# Download a file of seedlot maintenance events
#
# POST Params:
#   seedlot_maintenance_events_list_list_select = list id of a seedlot list
#   file_format: format of the file output (.xls)
#
sub download_seedlot_maintenance_events_action : Path('/breeders/download_seedlot_maintenance_events_action') {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado", $sp_person_id);

    # Get request params
    my $seedlot_list_id = $c->req->param("seedlot_maintenance_events_list_list_select");
    my $file_format = $c->req->param("file_format") || ".xlsx";
    my $dl_token = $c->req->param("seedlot_maintenance_events_download_token") || "no_token";
    my $dl_cookie = "download".$dl_token;
    if ( !$seedlot_list_id ) {
        print STDERR "ERROR: No seedlot list id provided to download seedlot maintenance events action";
        return;
    }

    # Get seedlots from list
    my $seedlot_data = SGN::Controller::AJAX::List->retrieve_list($c, $seedlot_list_id);
    my @seedlot_names = map { $_->[1] } @$seedlot_data;

    # Get Maintenance Events
    my $m = CXGN::Stock::Seedlot::Maintenance->new({ bcs_schema => $schema });
    my $results = $m->filter_events({ names => \@seedlot_names }, 1, 65000);
    my $events = $results->{results};

    # Create tempfile
    my ($tempfile, $uri) = $c->tempfile(TEMPLATE => "download_seedlot_maintenance_events_XXXXX", UNLINK => 0);

    # Create and Return XLSX file
    if ( $file_format eq ".xlsx" ) {
        my $file_path = $tempfile . ".xlsx";
        my $file_name = basename($file_path);

        # Get Excel worksheet
        my $workbook = Excel::Writer::XLSX->new($file_path);
        my $worksheet = $workbook->add_worksheet();

        # Write header
        my @header = ("seedlot", "type", "value", "notes", "operator", "timestamp");
        $worksheet->write_row(0, 0, \@header);

        # Write each event
        my $row_count = 1;
        foreach my $event (@$events) {
            my @row = (
                $event->{uniquename},
                $event->{cvterm_name},
                $event->{value},
                $event->{notes},
                $event->{operator},
                $event->{timestamp}
            );
            $worksheet->write_row($row_count, 0, \@row);
            $row_count++;
        }
        $workbook->close();

        # Return the xls file
        $c->res->content_type('application/application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        $c->res->cookies->{$dl_cookie} = {
          value => $dl_token,
          expires => '+1m',
        };
        $c->res->header('Content-Disposition', qq[attachment; filename="$file_name"]);

        my $output = read_file($file_path);  ### works here because it is xls, otherwise does not work with utf8

        $c->res->body($output);
    }

}

# seedlot maintenanve events download -- end


#Used from wizard page and manage download page for downloading gbs from accessions
sub download_gbs_action : Path('/breeders/download_gbs_action') {
    my ($self, $c) = @_;
    # print STDERR Dumper $c->req->params();
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado", $sp_person_id);
    my $people_schema = $c->dbic_schema("CXGN::People::Schema", undef, $sp_person_id);
    my $format = $c->req->param("format") || "list_id";
    my $download_format = $c->req->param("download_format") || 'VCF';
    my $chromosome_numbers = $c->req->param("chromosome_number") ? [$c->req->param("chromosome_number")] : [];
    my $start_position = $c->req->param("start_position") || undef;
    my $end_position = $c->req->param("end_position") || undef;
    my $return_only_first_genotypeprop_for_stock = defined($c->req->param('return_only_first_genotypeprop_for_stock')) ? $c->req->param('return_only_first_genotypeprop_for_stock') : 1;
    my $forbid_cache = defined($c->req->param('forbid_cache')) ? $c->req->param('forbid_cache') : 0;
    my $dl_token = $c->req->param("gbs_download_token") || "no_token";
    my $dl_cookie = "download".$dl_token;
    my $genotyping_project_id = $c->req->param("genotyping_project_id");
    my (@accession_ids, @accession_list, @accession_genotypes, @unsorted_markers, $accession_data, $id_string, $protocol_id, $project_id, $trial_id_string, @trial_ids);
    my $associated_protocol;

    $trial_id_string = $c->req->param("trial_ids");
    if ($trial_id_string){
        @trial_ids = split(',', $trial_id_string);
    }

    if ($format eq 'accession_ids') {       #use protocol id and accession ids supplied directly
        $id_string = $c->req->param("ids");
        @accession_ids = split(',',$id_string);
        $protocol_id = $c->req->param("protocol_id");
	$project_id = $c->req->param("project_id");
        if ($protocol_id =~ /\d/) {
	    print STDERR "found protocol_id $protocol_id\n";
        } elsif ($project_id =~ /\d/) {
	    my $protocol_info = CXGN::Genotype::GenotypingProject->new({
	        bcs_schema => $schema,
	        project_id => $project_id
            });
            $associated_protocol = $protocol_info->get_associated_protocol();
	    $protocol_id = $associated_protocol->[0]->[0];
	    print STDERR "using protocol_id from project = $protocol_id\n";
        } elsif (!defined $genotyping_project_id) {
            my $default_genotyping_protocol = $c->config->{default_genotyping_protocol};
            $protocol_id = $schema->resultset('NaturalDiversity::NdProtocol')->find({name=>$default_genotyping_protocol})->nd_protocol_id();
	    print STDERR "using default protocol_id = $protocol_id\n";
        }
    }

    elsif ($format eq 'list_id') {        #get accession names from list and tranform them to ids
        my $accession_list_id = $c->req->param("genotype_accession_list_list_select");
        $protocol_id = $c->req->param("genotyping_protocol_select");

        if ($accession_list_id) {
            $accession_data = SGN::Controller::AJAX::List->retrieve_list($c, $accession_list_id);
        }

        @accession_list = map { $_->[1] } @$accession_data;

        my $t = CXGN::List::Transform->new();
        my $acc_t = $t->can_transform("accessions", "accession_ids");
        my $accession_id_hash = $t->transform($schema, $acc_t, \@accession_list);
        @accession_ids = @{$accession_id_hash->{transform}};
    }

    my $filename = '';
    if ($download_format eq 'VCF') {
        $filename = 'BreedBaseGenotypesDownload.vcf';
    }
    else {
        $filename = 'BreedBaseGenotypesDownload.tsv';
    }

    my $compute_from_parents = $c->req->param('compute_from_parents') eq 'true' ? 1 : 0;
    $return_only_first_genotypeprop_for_stock = $c->req->param('include_duplicate_genotypes') eq 'true' ? 0 : 1;
    my $marker_set_list_id = $c->req->param('marker_set_list_id');

    my $o;
    my @marker_name_list;
    if ($marker_set_list_id) {
        my $list = CXGN::List->new({ dbh => $schema->storage->dbh, list_id => $marker_set_list_id });
        my $elements = $list->elements();

        foreach my $e (@$elements) {
            eval {
                $o = decode_json($e);
            };
            if ($@) {    #simple list
                push @marker_name_list, $e;
            } else {    #json list
                if (exists($o->{marker_name})) {
                    push @marker_name_list, $o->{marker_name};
                }
            }
        }
    }

    my @protocol_list;
    if (defined $protocol_id) {
        push @protocol_list, $protocol_id;
    }

    my @genotyping_project_list;
    if (defined $genotyping_project_id) {
        push @genotyping_project_list, $genotyping_project_id;
    }

    my $geno = CXGN::Genotype::DownloadFactory->instantiate(
        $download_format,    #can be either 'VCF' or 'DosageMatrix'
        {
            bcs_schema=>$schema,
            people_schema=>$people_schema,
            cache_root_dir=>$c->config->{cache_file_path},
            accession_list=>\@accession_ids,
            #tissue_sample_list=>$tissue_sample_list,
            trial_list=>\@trial_ids,
            protocol_id_list=>\@protocol_list,
            chromosome_list=>$chromosome_numbers,
            start_position=>$start_position,
            end_position=>$end_position,
            compute_from_parents=>$compute_from_parents,
            forbid_cache=>$forbid_cache,
            marker_name_list=>\@marker_name_list,
            return_only_first_genotypeprop_for_stock=>$return_only_first_genotypeprop_for_stock,
            #markerprofile_id_list=>$markerprofile_id_list,
            genotype_data_project_list=>\@genotyping_project_list,
            #limit=>$limit,
            #offset=>$offset
        }
    );
    my $file_handle = $geno->download(
        $c->config->{cluster_shared_tempdir},
        $c->config->{backend},
        $c->config->{cluster_host},
        $c->config->{'web_cluster_queue'},
        $c->config->{basepath}
    );

    $c->res->content_type("application/text");
    $c->res->cookies->{$dl_cookie} = {
        value => $dl_token,
        expires => '+1m',
    };

    $c->res->header('Content-Disposition', qq[attachment; filename="$filename"]);
    $c->res->body($file_handle);
}

#Used from wizard page for downloading genetic relationship matrix (GRM)
sub download_grm_action : Path('/breeders/download_grm_action') {
    my ($self, $c) = @_;
    # print STDERR Dumper $c->req->params();
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado", $sp_person_id);
    my $people_schema = $c->dbic_schema("CXGN::People::Schema", undef, $sp_person_id);
    my $download_format = $c->req->param("download_format") || 'matrix';
    my $minor_allele_frequency = $c->req->param("minor_allele_frequency") ? $c->req->param("minor_allele_frequency") + 0 : 0.05;
    my $marker_filter = $c->req->param("marker_filter") ? $c->req->param("marker_filter") + 0 : 0.60;
    my $individuals_filter = $c->req->param("individuals_filter") ? $c->req->param("individuals_filter") + 0 : 0.80;
    my $return_only_first_genotypeprop_for_stock = defined($c->req->param('return_only_first_genotypeprop_for_stock')) ? $c->req->param('return_only_first_genotypeprop_for_stock') : 1;
    my $dl_token = $c->req->param("gbs_download_token") || "no_token";
    my $dl_cookie = "download".$dl_token;

    my (@accession_ids, @accession_list, @accession_genotypes, @unsorted_markers, $accession_data, $id_string, $protocol_id, $project_id, $trial_id_string, @trial_ids);
    my $associated_protocol;

    $trial_id_string = $c->req->param("trial_ids");
    if ($trial_id_string){
        @trial_ids = split(',', $trial_id_string);
    }

    $id_string = $c->req->param("ids");
    @accession_ids = split(',',$id_string);
    $protocol_id = $c->req->param("protocol_id");
    $project_id = $c->req->param("project_id");
    if ($protocol_id =~ /\d/) {
        print STDERR "found protocol_id $protocol_id\n";
    } elsif ($project_id =~ /\d/) {
        my $protocol_info = CXGN::Genotype::GenotypingProject->new({
           bcs_schema => $schema,
           project_id => $project_id
        });
        $associated_protocol = $protocol_info->get_associated_protocol();
        $protocol_id = $associated_protocol->[0]->[0];
        print STDERR "using protocol_id from project = $protocol_id\n";
    } else {
        my $default_genotyping_protocol = $c->config->{default_genotyping_protocol};
        $protocol_id = $schema->resultset('NaturalDiversity::NdProtocol')->find({name=>$default_genotyping_protocol})->nd_protocol_id();
        print STDERR "using default protocol_id = $protocol_id\n";
    }

    my $filename;
    if ($download_format eq 'heatmap') {
        $filename = 'BreedBaseGeneticRelationshipMatrixDownload.pdf';
    }
    else {
        $filename = 'BreedBaseGeneticRelationshipMatrixDownload.tsv';
    }

    my $compute_from_parents = $c->req->param('compute_from_parents') eq 'true' ? 1 : 0;

    my $shared_cluster_dir_config = $c->config->{cluster_shared_tempdir};
    my $tmp_grm_dir = $shared_cluster_dir_config."/tmp_genotype_download_grm";
    mkdir $tmp_grm_dir if ! -d $tmp_grm_dir;
    my ($grm_tempfile_fh, $grm_tempfile) = tempfile("wizard_download_grm_XXXXX", DIR=> $tmp_grm_dir);

    my $geno = CXGN::Genotype::GRM->new({
        bcs_schema=>$schema,
        grm_temp_file=>$grm_tempfile,
        people_schema=>$people_schema,
        cache_root=>$c->config->{cache_file_path},
        accession_id_list=>\@accession_ids,
        protocol_id=>$protocol_id,
        get_grm_for_parental_accessions=>$compute_from_parents,
        download_format=>$download_format,
        minor_allele_frequency=>$minor_allele_frequency,
        marker_filter=>$marker_filter,
        individuals_filter=>$individuals_filter
    });
    my $file_handle = $geno->download_grm(
        'filehandle',
        $shared_cluster_dir_config,
        $c->config->{backend},
        $c->config->{cluster_host},
        $c->config->{'web_cluster_queue'},
        $c->config->{basepath}
    );

    $c->res->content_type("application/text");
    $c->res->cookies->{$dl_cookie} = {
        value => $dl_token,
        expires => '+1m',
    };

    $c->res->header('Content-Disposition', qq[attachment; filename="$filename"]);
    $c->res->body($file_handle);
}

#Used from wizard page for downloading genome wide association study (GWAS) results and plots
sub download_gwas_action : Path('/breeders/download_gwas_action') {
    my ($self, $c) = @_;
    # print STDERR Dumper $c->req->params();
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado", $sp_person_id);
    my $people_schema = $c->dbic_schema("CXGN::People::Schema", undef, $sp_person_id);
    my $minor_allele_frequency = $c->req->param("minor_allele_frequency") ? $c->req->param("minor_allele_frequency") + 0 : 0.05;
    my $download_format = $c->req->param("download_format") ? $c->req->param("download_format") : 'results_tsv';
    my $marker_filter = $c->req->param("marker_filter") ? $c->req->param("marker_filter") + 0 : 0.60;
    my $individuals_filter = $c->req->param("individuals_filter") ? $c->req->param("individuals_filter") + 0 : 0.80;
    my $traits_are_repeated_measurements = $c->req->param('traits_are_repeated_measurements') eq 'yes' ? 1 : 0;
    my $return_only_first_genotypeprop_for_stock = defined($c->req->param('return_only_first_genotypeprop_for_stock')) ? $c->req->param('return_only_first_genotypeprop_for_stock') : 1;
    my $dl_token = $c->req->param("gbs_download_token") || "no_token";
    my $dl_cookie = "download".$dl_token;

    my (@accession_ids, @accession_list, @accession_genotypes, @unsorted_markers, $accession_data, $id_string, $protocol_id, $trait_id_string, @trait_ids);

    $trait_id_string = $c->req->param("trait_ids");
    if ($trait_id_string){
        @trait_ids = split(',', $trait_id_string);
    }

    $id_string = $c->req->param("ids");
    @accession_ids = split(',',$id_string);
    $protocol_id = $c->req->param("protocol_id");
    if (!$protocol_id){
        my $default_genotyping_protocol = $c->config->{default_genotyping_protocol};
        $protocol_id = $schema->resultset('NaturalDiversity::NdProtocol')->find({name=>$default_genotyping_protocol})->nd_protocol_id();
    }

    my $filename;
    if ($download_format eq 'results_tsv') {
        $filename = 'BreedBaseGWASDownloadResults.tsv';
    }
    elsif ($download_format eq 'manhattan_qq_plots') {
        $filename = 'BreedBaseGWASDownloadManhattanAndQQPlots.pdf';
    }

    my $compute_from_parents = $c->req->param('compute_from_parents') eq 'true' ? 1 : 0;

    my $shared_cluster_dir_config = $c->config->{cluster_shared_tempdir};
    my $tmp_gwas_dir = $shared_cluster_dir_config."/tmp_genotype_download_gwas";
    mkdir $tmp_gwas_dir if ! -d $tmp_gwas_dir;
    my ($gwas_tempfile_fh, $gwas_tempfile) = tempfile("wizard_download_gwas_XXXXX", DIR=> $tmp_gwas_dir);
    my ($grm_tempfile_fh, $grm_tempfile) = tempfile("wizard_download_gwas_grm_XXXXX", DIR=> $tmp_gwas_dir);
    my ($pheno_tempfile_fh, $pheno_tempfile) = tempfile("wizard_download_gwas_pheno_XXXXX", DIR=> $tmp_gwas_dir);

    my $geno = CXGN::Genotype::GWAS->new({
        bcs_schema=>$schema,
        grm_temp_file=>$grm_tempfile,
        gwas_temp_file=>$gwas_tempfile,
        pheno_temp_file=>$pheno_tempfile,
        people_schema=>$people_schema,
        cache_root=>$c->config->{cache_file_path},
        download_format=>$download_format,
        accession_id_list=>\@accession_ids,
        trait_id_list=>\@trait_ids,
        traits_are_repeated_measurements=>$traits_are_repeated_measurements,
        protocol_id=>$protocol_id,
        get_grm_for_parental_accessions=>$compute_from_parents,
        minor_allele_frequency=>$minor_allele_frequency,
        marker_filter=>$marker_filter,
        individuals_filter=>$individuals_filter
    });
    my $file_handle = $geno->download_gwas(
        $shared_cluster_dir_config,
        $c->config->{backend},
        $c->config->{cluster_host},
        $c->config->{'web_cluster_queue'},
        $c->config->{basepath}
    );

    $c->res->content_type("application/text");
    $c->res->cookies->{$dl_cookie} = {
        value => $dl_token,
        expires => '+1m',
    };

    $c->res->header('Content-Disposition', qq[attachment; filename="$filename"]);
    $c->res->body($file_handle);
}

#=pod

#Used from manage download GBS Genotype QC

#=cut

sub gbs_qc_action : Path('/breeders/gbs_qc_action') Args(0) {
    my $self = shift;
    my $c = shift;

    my $accession_list_id = $c->req->param("genotype_qc_accession_list_list_select");
    my $trial_list_id     = $c->req->param("genotype_trial_list_list_select");
    my $protocol_id     = $c->req->param("protocol_list2_select");
    my $data_type         = $c->req->param("data_type") || "genotype";
    my $format            = $c->req->param("format");
    my $dl_token = $c->req->param("qc_download_token") || "no_token";
    my $dl_cookie = "download".$dl_token;

    my $accession_data = SGN::Controller::AJAX::List->retrieve_list($c, $accession_list_id);
    my $trial_data = SGN::Controller::AJAX::List->retrieve_list($c, $trial_list_id);

    my @accession_list = map { $_->[1] } @$accession_data;
    my @trial_list = map { $_->[1] } @$trial_data;

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado", $sp_person_id);
    my $people_schema = $c->dbic_schema("CXGN::People::Schema", undef, $sp_person_id);
    my $t = CXGN::List::Transform->new();


    my $acc_t = $t->can_transform("accessions", "accession_ids");
    my $accession_id_data = $t->transform($schema, $acc_t, \@accession_list);

    my $trial_t = $t->can_transform("trials", "trial_ids");
    my $trial_id_data = $t->transform($schema, $trial_t, \@trial_list);

    my $data;
    my $output = "";

    my ($tempfile, $uri) = $c->tempfile(TEMPLATE => "download_XXXXX", UNLINK=> 0);


    open my $TEMP, '> :encoding(UTF-8)', $tempfile or die "Cannot open output_test00.txt: $!";


    $tempfile = File::Spec->catfile($tempfile);


    if ($data_type eq "genotype") {

        print "Download genotype data\n";

    my $genotypes_search = CXGN::Genotype::Search->new({
        bcs_schema=>$schema,
        people_schema=>$people_schema,
        accession_list=>$accession_id_data->{transform},
        trial_list=>$trial_id_data->{transform},
        protocol_id_list=>[$protocol_id]
    });
    my ($total_count, $genotypes) = $genotypes_search->get_genotype_info();
    my $data = $genotypes;
	$output = "";



       my @AoH = ();

     for (my $i=0; $i < scalar(@$data) ; $i++)
     {
      my $decoded = $genotypes->[$i]->{genotype_hash};
      push(@AoH, $decoded);
     }


        my @k=();
	for my $i ( 0 .. $#AoH ){
	   @k = keys   %{ $AoH[$i] }
	}


        for my $j (0 .. $#k){

	    print $TEMP "$k[$j]\t";
	    for my $i ( 0 .. $#AoH ) {

            if($i == $#AoH ){
            print $TEMP "$AoH[$i]{$k[$j]}";
            }else{
	    print $TEMP "$AoH[$i]{$k[$j]}\t";
	    }

            }

            print $TEMP "\n";

	}
    }


    my ($tempfile_out, $uri_out) = $c->tempfile(TEMPLATE => "output_XXXXX", UNLINK=> 0);


     system("R --slave --args $tempfile $tempfile_out < R/GBS_QC.R");


    my $contents = $tempfile_out;

    $c->res->content_type("text/plain");
    $c->res->cookies->{$dl_cookie} = {
      value => $dl_token,
      expires => '+1m',
    };
    $c->res->body($contents);


}

sub trial_download_log {
    my $self = shift;
    my $c = shift;
    my $trial_id = shift;
    my $message = shift;
    my $now = DateTime->now();

    if (! $c->user) {
      return;
      print STDERR "Can't find user id, skipping download logging\n";
    }
    if ($c->config->{trial_download_logfile}) {
      my $logfile = $c->config->{trial_download_logfile};
      open (my $F, ">> :encoding(UTF-8)", $logfile) || die "Can't open logfile $logfile\n";
      print $F join("\t", (
            $c->user->get_object->get_username(),
            $trial_id,
            $message,
            $now->year()."-".$now->month()."-".$now->day()." ".$now->hour().":".$now->minute()));
      print $F "\n";
      close($F);
      print STDERR "Download logged in $logfile\n";
    }
    else {
      print STDERR "Note: set config variable trial_download_logfile to obtain a log of downloaded trials.\n";
    }
}


sub download_sequencing_facility_spreadsheet : Path( '/breeders/genotyping/spreadsheet') Args(1) {
    my $self = shift;
    my $c = shift;
    my $trial_id = shift;

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $t = CXGN::Trial->new( { bcs_schema => $schema, trial_id => $trial_id });

    #my $layout = $t->get_layout()->get_design();

    $c->tempfiles_subdir("data_export"); # make sure the dir exists
    my ($fh, $tempfile) = $c->tempfile(TEMPLATE=>"data_export/trial_".$trial_id."_XXXXX");

    my $file_path = $c->config->{basepath}."/".$tempfile.".xlsx";
    move($tempfile, $file_path);

    my $td = CXGN::Trial::Download->new( {
	bcs_schema => $schema,
	trial_id => $trial_id,
	format => "IGDFacilitySpreadsheet",
        filename => $file_path,
	user_id => $c->user->get_object()->get_sp_person_id(),
	trial_download_logfile => $c->config->{trial_download_logfile},
    }
    );

    $td->download();


    # my $ss = Spreadsheet::WriteExcel->new($c->config->{basepath}."/".$file_path);
    # my $ws = $ss->add_worksheet();

    # # write primary headers
    # #
    # $ws->write(0, 0, "Project Details");
    # $ws->write(0, 2, "Sample Details");
    # $ws->write(0, 12, "Organism Details");
    # $ws->write(0, 21, "Origin Details");

    # # write secondary headers
    # #
    # my @headers = (
    # 	"Project Name",
    # 	"User ID",
    # 	"Plate Name",
    # 	"Well",
    # 	"Sample Name",
    # 	"Pedigree",
    # 	"Population",
    # 	"Stock Number",
    # 	"Sample DNA Concentration (ng/ul)",
    # 	"Sample Volume (ul)",
    # 	"Sample DNA Mass(ng)",
    # 	"Kingdom",
    # 	"Genus",
    # 	"Species",
    # 	"Common Name",
    # 	"Subspecies",
    # 	"Variety",
    # 	"Seed Lot"
    # 	);

    # for(my $i=0; $i<@headers; $i++) {
    # 	$ws->write(1, $i, $headers[$i]);
    # }

    # # replace accession names with igd_synonyms
    # #
    # print STDERR "Converting accession names to igd_synonyms...\n";
    # foreach my $k (sort wellsort (keys %{$layout})) {
    # 	my $q = "SELECT value FROM stock JOIN stockprop using(stock_id) JOIN cvterm ON (stockprop.type_id=cvterm.cvterm_id) WHERE cvterm.name='igd_synonym' AND stock.uniquename = ?";
    # 	my $h = $c->dbc->dbh()->prepare($q);
    # 	$h->execute($layout->{$k}->{accession_name});
    # 	my ($igd_synonym) = $h->fetchrow_array();
    # 	$layout->{$k}->{igd_synonym} = $igd_synonym;
    # 	if ($layout->{$k}->{accession_name}=~/BLANK/i) {
    # 	    $layout->{$k}->{igd_synonym} = "BLANK";
    # 	}
    # }
    # # write plate info
    # #
    # my $line = 0;

    # foreach my $k (sort wellsort (keys %{$layout})) {
    # 	$ws->write(2 + $line, 0, "NextGen Cassava");
    # 	my $breeding_program_data = $t->get_breeding_programs();
    # 	my $breeding_program_name = "";
    # 	if ($breeding_program_data->[0]) {
    # 	    $breeding_program_name = $breeding_program_data->[0]->[1];
    # 	}
    # 	$ws->write(2 + $line, 0, $layout->{$k}->{genotyping_project_name});
    # 	$ws->write(2 + $line, 1, $layout->{$k}->{genotyping_user_id});
    # 	$ws->write(2 + $line, 2, $t->get_name());
    # 	$ws->write(2 + $line, 3, $k);
    # 	$ws->write(2 + $line, 4, $layout->{$k}->{igd_synonym});
    # 	$ws->write(2 + $line, 16, "Manihot");
    # 	$ws->write(2 + $line, 17, "esculenta");
    # 	$ws->write(2 + $line, 20, $t->get_location());
    # 	$line++;
    # }

    # $ss ->close();

    # prepare file for download
    #
    my $file_name = basename($file_path);
    $c->res->content_type('application/application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    $c->res->header('Content-Disposition', qq[attachment; filename="$file_name"]);



    ####my $output = read_file($file_path, binmode=>':raw');
    my $output = "";
    open(my $F, "< :encoding(UTF-8)", $file_path) || die "Can't open file $file_path for reading.";
    while (<$F>) {
	$output .= $_;
    }
    close($F);


    close($fh);
    $c->res->body($output);
}

sub wellsort {
    my $row_a = substr($a, 0, 1);
    my $row_b = substr($b, 0, 1);

    my $col_a;
    my $col_b;
    if ($a =~ m/(\d+)/) {
	$col_a = $1;
    }
    if ($b =~ m/(\d+)/) {
	$col_b = $1;
    }

    if ($row_a ne $row_b) {
	return $row_a cmp $row_b;
    }
    else {
	return $col_a <=> $col_b;
    }
}

sub download_protocol_marker_info : Path('/breeders/download_protocol_marker_info') {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado", $sp_person_id);
    my $protocol_id = $c->req->param("protocol_id");

    my $dir = $c->tempfiles_subdir('download');
    my $temp_file_name = $protocol_id . "_" . "marker_info" . "XXXX";
    my $rel_file = $c->tempfile( TEMPLATE => "download/$temp_file_name");
    $rel_file = $rel_file . ".csv";
    my $tempfile = $c->config->{basepath}."/".$rel_file;

    my $dl_token = $c->req->param("gbs_download_token") || "no_token";
    my $dl_cookie = "download".$dl_token;

    my $marker_info_download = CXGN::Genotype::DownloadFactory->instantiate(
        'MarkerInfo',
        {
            bcs_schema=>$schema,
            protocol_id_list=>[$protocol_id],
            filename => $tempfile,
        }
    );

    my $download = $marker_info_download->download();

    my $format = 'csv';
    my $download_file_name = 'BreedbaseMarkerInfo'.$format;

    $c->res->content_type('Application/'.$format);
    $c->res->header('Content-Disposition', qq[attachment; filename="$download_file_name"]);

    my $output = read_file($tempfile);

    $c->res->body($output);

}


sub download_kasp_genotyping_data_csv : Path('/breeders/download_kasp_genotyping_data_csv') {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado", $sp_person_id);
    my $people_schema = $c->dbic_schema("CXGN::People::Schema", undef, $sp_person_id);
    my $protocol_id = $c->req->param("protocol_id");
    my $genotyping_project_id = $c->req->param("genotyping_project_id");

    my @protocol_list;
    if (defined $protocol_id) {
        push @protocol_list, $protocol_id;
    }

    my @genotyping_project_list;
    if (defined $genotyping_project_id) {
        push @genotyping_project_list, $genotyping_project_id;
    }


    my $dir = $c->tempfiles_subdir('download');
    my $temp_file_name = $protocol_id . "_" . "KASP_data" . "XXXX";
    my $rel_file = $c->tempfile( TEMPLATE => "download/$temp_file_name");
    $rel_file = $rel_file . ".csv";
    my $tempfile = $c->config->{basepath}."/".$rel_file;

    my $dl_token = $c->req->param("gbs_download_token") || "no_token";
    my $dl_cookie = "download".$dl_token;

    my $kasp_genotyping_data_download = CXGN::Genotype::DownloadFactory->instantiate(
        'KASPdata',
        {
            bcs_schema=>$schema,
            people_schema=>$people_schema,
            protocol_id_list=>\@protocol_list,
            genotype_data_project_list=>\@genotyping_project_list,
            filename => $tempfile,
        }
    );

    my $download = $kasp_genotyping_data_download->download();

    my $format = 'csv';
    my $download_file_name = 'BreedbaseKASPdata'.'.'.$format;

    $c->res->content_type('Application/'.$format);
    $c->res->header('Content-Disposition', qq[attachment; filename="$download_file_name"]);

    my $output = read_file($tempfile);

    $c->res->body($output);

}

sub download_images : Path('/breeders/download_images') : ActionClass('REST') { }

sub download_images_POST : Args(0) {
    my ($self, $c) = @_;
    my $trial_id = $c->req->param('trial_id');
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    my $trial = CXGN::Trial->new({ 
        bcs_schema => $schema, 
        trial_id => $trial_id, 
        }
    );

    my $plots = $trial->get_plots();
    my @image_ids;

    foreach my $plot (@$plots) {
        my ($plot_id, $plot_name) = @$plot;

        my $stock = CXGN::Stock->new({ schema => $schema, stock_id => $plot_id });
        my @plot_image_ids = $stock->get_image_ids();

        foreach my $id (@plot_image_ids) {
            my ($image_id, $stock_type) = @$id;
            push @image_ids, $image_id;
        }
    }

    my $tempdir = tempdir(CLEANUP => 1);
    my $temp_images_dir = "$tempdir/images";
    mkdir $temp_images_dir or die "Failed to create temp images directory: $!";

    foreach my $image_id (@image_ids) {
        my $image = SGN::Image->new($schema->storage->dbh, $image_id, $c);
        my $original_filename = $image->get_original_filename;
        my $image_path = $image->get_filename('original');

        my $file_extension = ($image_path =~ /\.([^.]+)$/) ? $1 : '';
        if ($file_extension) {
            $original_filename .= ".$file_extension";
        }

        copy($image_path, $temp_images_dir . '/' . $original_filename) or die "Failed to copy $image_path to $temp_images_dir: $!";

    }

    my $tar = Archive::Tar->new;
    $tar->add_files(glob("$temp_images_dir/*"));
    my $tar_filename = "trial_${trial_id}_images.tar.gz";
    my $tar_file = "$tempdir/$tar_filename";

    $tar->write($tar_file, COMPRESS_GZIP);

    $c->response->header('Content-Type' => 'application/gzip');
    $c->response->header('Content-Disposition' => "attachment; filename=$tar_filename");
    $c->serve_static_file($tar_file);

    return;
}


#=pod
1;
