
=head1 NAME

SGN::Controller::AJAX::DroneImagery::DroneImagery - a REST controller class to provide the
functions for uploading and analyzing drone imagery

=head1 DESCRIPTION

=head1 AUTHOR

=cut

package SGN::Controller::AJAX::DroneImagery::DroneImagery;

use Moose;
use Data::Dumper;
use LWP::UserAgent;
use JSON;
use SGN::Model::Cvterm;
use DateTime;
use CXGN::UploadFile;
use SGN::Image;
use CXGN::DroneImagery::ImagesSearch;
use URI::Encode qw(uri_encode uri_decode);
use File::Basename qw | basename dirname|;
use File::Slurp qw(write_file);
use File::Temp 'tempfile';
use CXGN::Calendar;
use Image::Size;
use Text::CSV;
use CXGN::Phenotypes::StorePhenotypes;
use CXGN::Phenotypes::PhenotypeMatrix;
use CXGN::BrAPI::FileResponse;
use CXGN::Onto;
use R::YapRI::Base;
use R::YapRI::Data::Matrix;
use CXGN::Tag;
use CXGN::DroneImagery::ImageTypes;
use Time::Piece;
use POSIX;
use Math::Round;
use Parallel::ForkManager;
use CXGN::NOAANCDC;
use CXGN::BreederSearch;
use CXGN::Phenotypes::SearchFactory;
use CXGN::BreedersToolbox::Accessions;
use CXGN::Genotype::GRM;
use CXGN::Pedigree::ARM;
use CXGN::AnalysisModel::SaveModel;
use CXGN::AnalysisModel::GetModel;
use Math::Polygon;
use Math::Trig;
use List::MoreUtils qw(first_index);
use List::Util qw(sum);
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use Spreadsheet::WriteExcel;
use CXGN::Location;
#use Inline::Python;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON'  },
);

sub raw_drone_imagery_plot_image_count : Path('/api/drone_imagery/raw_drone_imagery_plot_image_count') : ActionClass('REST') { }
sub raw_drone_imagery_plot_image_count_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    my $drone_run_band_drone_run_relationship_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_on_drone_run', 'project_relationship')->cvterm_id();

    my $project_image_type_id_hash = CXGN::DroneImagery::ImageTypes::get_all_project_md_image_observation_unit_plot_polygon_types($schema);
    my $sql = join ("," , (keys %$project_image_type_id_hash));
    my $q = "SELECT drone_run.project_id, project_image_type.name, project_image_type.cvterm_id
        FROM project AS drone_run_band
        JOIN project_relationship AS drone_run_band_rel ON(drone_run_band.project_id=drone_run_band_rel.subject_project_id AND drone_run_band_rel.type_id=$drone_run_band_drone_run_relationship_id)
        JOIN project AS drone_run ON(drone_run.project_id=drone_run_band_rel.object_project_id)
        JOIN phenome.project_md_image AS project_image ON(drone_run_band.project_id=project_image.project_id)
        JOIN cvterm AS project_image_type ON(project_image_type.cvterm_id=project_image.type_id)
        JOIN metadata.md_image AS image ON(image.image_id=project_image.image_id)
        WHERE project_image.type_id in ($sql) AND image.obsolete='f';";

    #print STDERR Dumper $q;
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute();

    my %unique_drone_runs;
    while (my ($drone_run_project_id, $project_image_type_name, $project_image_type_id) = $h->fetchrow_array()) {
        $unique_drone_runs{$drone_run_project_id}->{$project_image_type_id_hash->{$project_image_type_id}->{display_name}}++;
        $unique_drone_runs{$drone_run_project_id}->{total_plot_image_count}++;
    }
    #print STDERR Dumper \%unique_drone_runs;

    $c->stash->{rest} = { data => \%unique_drone_runs };
}

sub drone_imagery_analysis_query : Path('/api/drone_imagery/analysis_query') : ActionClass('REST') { }
sub drone_imagery_analysis_query_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my ($user_id, $user_name, $user_role) = _check_user_login($c);
    my $main_production_site = $c->config->{main_production_site_url};

    my $project_image_type_id_list_all = CXGN::DroneImagery::ImageTypes::get_all_project_md_image_observation_unit_plot_polygon_types($schema);
    my @project_image_type_id_list_array = keys %$project_image_type_id_list_all;

    my $trait_id_list = $c->req->param('observation_variable_id_list') ? decode_json $c->req->param('observation_variable_id_list') : [];
    my $return_format = $c->req->param('format') || 'csv';
    my $trial_name_list = $c->req->param('trial_name_list');
    my $trial_id_list = $c->req->param('field_trial_id_list') ? decode_json $c->req->param('field_trial_id_list') : [];
    my $project_image_type_id_list = $c->req->param('project_image_type_id_list') ? decode_json $c->req->param('project_image_type_id_list') : \@project_image_type_id_list_array;

    my %return;

    if ($trial_name_list) {
        my @trial_names = split ',', $trial_name_list;
        my $trial_search = CXGN::Trial::Search->new({
            bcs_schema=>$schema,
            trial_name_list=>\@trial_names
        });
        my ($result, $total_count) = $trial_search->search();
        foreach (@$result) {
            push @$trial_id_list, $_->{trial_id};
        }
    }

    my @drone_run_band_project_id_list;
    foreach (@$trial_id_list) {
        my $trial = CXGN::Trial->new({bcs_schema => $schema, trial_id => $_});
        my $drone_run_bands = $trial->get_drone_run_bands_from_field_trial();
        foreach my $d (@$drone_run_bands) {
            push @drone_run_band_project_id_list, $d->[0];
        }
    }

    print STDERR Dumper \@drone_run_band_project_id_list;
    my $images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        drone_run_band_project_id_list=>\@drone_run_band_project_id_list,
        project_image_type_id_list=>$project_image_type_id_list
    });
    my ($result, $total_count) = $images_search->search();
    print STDERR "Query found ".scalar(@$result)." Images\n";

    my %image_data_hash;
    my %project_image_type_names;
    foreach (@$result) {
        my $image_id = $_->{image_id};
        my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
        my $image_url = $image->get_image_url("original");
        my $image_fullpath = $image->get_filename('original_converted', 'full');
        push @{$image_data_hash{$_->{stock_id}}->{$_->{drone_run_band_project_name}.$_->{project_image_type_name}}}, $main_production_site.$image_url;
        $project_image_type_names{$_->{drone_run_band_project_name}.$_->{project_image_type_name}}++;
    }
    my @project_image_names_list = sort keys %project_image_type_names;

    my %data_hash;
    my $phenotypes_search = CXGN::Phenotypes::PhenotypeMatrix->new(
        bcs_schema=>$schema,
        search_type=>'MaterializedViewTable',
        data_level=>'plot',
        trait_list=>$trait_id_list,
        trial_list=>$trial_id_list,
        include_timestamp=>0,
        exclude_phenotype_outlier=>0,
    );
    my @data = $phenotypes_search->get_phenotype_matrix();

    my $phenotype_header = shift @data;
    my @total_phenotype_header = (@$phenotype_header, @project_image_names_list);
    foreach (@data) {
        $data_hash{$_->[21]} = $_;
    }

    while (my($stock_id, $image_info_hash) = each %image_data_hash) {
        foreach (@project_image_names_list) {
            my $image_string = $image_info_hash->{$_} ? join ',', @{$image_info_hash->{$_}} : '';
            push @{$data_hash{$stock_id}}, $image_string;
        }
    }
    #print STDERR Dumper \%data_hash;
    my @data_array = values %data_hash;
    my @data_total = (\@total_phenotype_header, @data_array);

    if ($return_format eq 'csv') {
        my $dir = $c->tempfiles_subdir('download');
        my ($download_file_path, $download_uri) = $c->tempfile( TEMPLATE => 'download/drone_imagery_analysis_csv_'.'XXXXX', SUFFIX => ".csv");
        my $file_response = CXGN::BrAPI::FileResponse->new({
            absolute_file_path => $download_file_path,
            absolute_file_uri => $main_production_site.$download_uri,
            format => $return_format,
            data => \@data_total
        });
        my @data_files = $file_response->get_datafiles();
        $return{file} = $data_files[0];
    } elsif ($return_format eq 'xls') {
        my $dir = $c->tempfiles_subdir('download');
        my ($download_file_path, $download_uri) = $c->tempfile( TEMPLATE => 'download/drone_imagery_analysis_xls_'.'XXXXX', SUFFIX => ".xls");
        my $file_response = CXGN::BrAPI::FileResponse->new({
            absolute_file_path => $download_file_path,
            absolute_file_uri => $main_production_site.$download_uri,
            format => $return_format,
            data => \@data_total
        });
        my @data_files = $file_response->get_datafiles();
        $return{file} = $data_files[0];
    } elsif ($return_format eq 'json') {
        $return{header} = \@total_phenotype_header;
        $return{data} = \@data_array;
    }

    $c->stash->{rest} = \%return;
}

sub drone_imagery_calculate_statistics : Path('/api/drone_imagery/calculate_statistics') : ActionClass('REST') { }
sub drone_imagery_calculate_statistics_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $people_schema = $c->dbic_schema("CXGN::People::Schema", undef, $sp_person_id);
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $statistics_select = $c->req->param('statistics_select');
    my $field_trial_id_list = $c->req->param('field_trial_id_list') ? decode_json $c->req->param('field_trial_id_list') : [];
    my $field_trial_id_list_string = join ',', @$field_trial_id_list;

    if (scalar(@$field_trial_id_list) != 1) {
        $c->stash->{rest} = { error => "Please select one field trial!"};
        return;
    }

    my $trait_id_list = $c->req->param('observation_variable_id_list') ? decode_json $c->req->param('observation_variable_id_list') : [];
    my $compute_relationship_matrix_from_htp_phenotypes = $c->req->param('relationship_matrix_type') || 'genotypes';
    my $compute_relationship_matrix_from_htp_phenotypes_type = $c->req->param('htp_pheno_rel_matrix_type');
    my $compute_relationship_matrix_from_htp_phenotypes_time_points = $c->req->param('htp_pheno_rel_matrix_time_points');
    my $compute_relationship_matrix_from_htp_phenotypes_blues_inversion = $c->req->param('htp_pheno_rel_matrix_blues_inversion');
    my $compute_from_parents = $c->req->param('compute_from_parents') eq 'yes' ? 1 : 0;
    my $include_pedgiree_info_if_compute_from_parents = $c->req->param('include_pedgiree_info_if_compute_from_parents') eq 'yes' ? 1 : 0;
    my $use_parental_grms_if_compute_from_parents = $c->req->param('use_parental_grms_if_compute_from_parents') eq 'yes' ? 1 : 0;
    my $use_area_under_curve = $c->req->param('use_area_under_curve') eq 'yes' ? 1 : 0;
    my $protocol_id = $c->req->param('protocol_id');
    my $tolparinv = $c->req->param('tolparinv');
    my $legendre_order_number = $c->req->param('legendre_order_number');
    my $permanent_environment_structure = $c->req->param('permanent_environment_structure');
    my $permanent_environment_structure_phenotype_correlation_traits = $c->req->param('permanent_environment_structure_phenotype_correlation_traits') ? decode_json $c->req->param('permanent_environment_structure_phenotype_correlation_traits') : [];

    my $shared_cluster_dir_config = $c->config->{cluster_shared_tempdir};
    my $tmp_stats_dir = $shared_cluster_dir_config."/tmp_drone_statistics";
    mkdir $tmp_stats_dir if ! -d $tmp_stats_dir;
    my ($grm_rename_tempfile_fh, $grm_rename_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    $grm_rename_tempfile .= '.grm';
    my ($permanent_environment_structure_tempfile_fh, $permanent_environment_structure_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    my ($stats_tempfile_fh, $stats_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    my ($stats_tempfile_rename_fh, $stats_tempfile_rename) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    my ($stats_tempfile_2_fh, $stats_tempfile_2) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    $stats_tempfile_2 .= '.dat';
    my ($stats_prep_tempfile_fh, $stats_prep_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    my ($stats_prep_factor_tempfile_fh, $stats_prep_factor_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    my ($stats_prep2_tempfile_fh, $stats_prep2_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    my ($parameter_tempfile_fh, $parameter_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    $parameter_tempfile .= '.f90';
    my ($coeff_genetic_tempfile_fh, $coeff_genetic_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    $coeff_genetic_tempfile .= '_genetic_coefficients.csv';
    my ($coeff_pe_tempfile_fh, $coeff_pe_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    $coeff_pe_tempfile .= '_permanent_environment_coefficients.csv';

    my $dir = $c->tempfiles_subdir('/tmp_drone_statistics');
    my $stats_out_tempfile_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/drone_stats_XXXXX');
    my $stats_out_tempfile = $c->config->{basepath}."/".$stats_out_tempfile_string;

    my ($stats_out_htp_rel_tempfile_input_fh, $stats_out_htp_rel_tempfile_input) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    my ($stats_out_htp_rel_tempfile_fh, $stats_out_htp_rel_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);

    my $stats_out_htp_rel_tempfile_out_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/drone_stats_XXXXX');
    my $stats_out_htp_rel_tempfile_out = $c->config->{basepath}."/".$stats_out_htp_rel_tempfile_out_string;

    my ($stats_out_pe_pheno_rel_tempfile_fh, $stats_out_pe_pheno_rel_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    my ($stats_out_pe_pheno_rel_tempfile2_fh, $stats_out_pe_pheno_rel_tempfile2) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);

    my ($stats_out_param_tempfile_fh, $stats_out_param_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    my ($stats_out_tempfile_row_fh, $stats_out_tempfile_row) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    my ($stats_out_tempfile_col_fh, $stats_out_tempfile_col) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    my ($stats_out_tempfile_2dspl_fh, $stats_out_tempfile_2dspl) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    my ($stats_out_tempfile_residual_fh, $stats_out_tempfile_residual) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    my ($stats_out_tempfile_genetic_fh, $stats_out_tempfile_genetic) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    my ($stats_out_tempfile_permanent_environment_fh, $stats_out_tempfile_permanent_environment) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    my $blupf90_solutions_tempfile;
    my $yhat_residual_tempfile;
    my $grm_file;

    my @results;
    my $result_blup_data;
    my $result_blup_data_delta;
    my $result_blup_spatial_data;
    my $result_blup_pe_data;
    my $result_blup_pe_data_delta;
    my $result_residual_data;
    my $result_fitted_data;
    my @sorted_trait_names;
    my @sorted_trait_names_original;
    my @sorted_residual_trait_names;
    my %seen_trait_names;
    my %trait_to_time_map;
    my @sorted_scaled_ln_times;
    my @rep_time_factors;
    my @ind_rep_factors;
    my %accession_id_factor_map;
    my %accession_id_factor_map_reverse;
    my %plot_id_factor_map_reverse;
    my %plot_id_count_map_reverse;
    my %time_count_map_reverse;
    my @unique_accession_names;
    my @unique_plot_names;
    my $statistical_ontology_term;
    my $analysis_result_values_type;
    my $analysis_model_language = "R";
    my $analysis_model_training_data_file_type;
    my $field_trial_design;
    my $model_sum_square_residual;
    my %trait_composing_info;
    my $time_max;
    my $time_min;
    my $min_row = 10000000000;
    my $max_row = 0;
    my $min_col = 10000000000;
    my $max_col = 0;

    my @legendre_coeff_exec = (
        '1 * $b',
        '$time * $b',
        '(1/2*(3*$time**2 - 1)*$b)',
        '1/2*(5*$time**3 - 3*$time)*$b',
        '1/8*(35*$time**4 - 30*$time**2 + 3)*$b',
        '1/16*(63*$time**5 - 70*$time**2 + 15*$time)*$b',
        '1/16*(231*$time**6 - 315*$time**4 + 105*$time**2 - 5)*$b'
    );

    foreach my $field_trial_id (@$field_trial_id_list) {
        my $field_trial_design_full = CXGN::Trial->new({bcs_schema => $schema, trial_id=>$field_trial_id})->get_layout()->get_design();
        while (my($plot_number, $plot_obj) = each %$field_trial_design_full) {
            my $plot_number_unique = $field_trial_id."_".$plot_number;
            $field_trial_design->{$plot_number_unique} = {
                stock_name => $plot_obj->{accession_name},
                block_number => $plot_obj->{block_number},
                col_number => $plot_obj->{col_number},
                row_number => $plot_obj->{row_number},
                plot_name => $plot_obj->{plot_name},
                plot_number => $plot_number_unique,
                rep_number => $plot_obj->{rep_number},
                is_a_control => $plot_obj->{is_a_control}
            };
        }
    }

    my $drone_run_related_time_cvterms_json_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_related_time_cvterms_json', 'project_property')->cvterm_id();
    my $drone_run_field_trial_project_relationship_type_id_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_on_field_trial', 'project_relationship')->cvterm_id();
    my $drone_run_band_drone_run_project_relationship_type_id_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_on_drone_run', 'project_relationship')->cvterm_id();
    my $drone_run_time_q = "SELECT drone_run_project.project_id, project_relationship.object_project_id, projectprop.value
        FROM project AS drone_run_band_project
        JOIN project_relationship AS drone_run_band_rel ON (drone_run_band_rel.subject_project_id = drone_run_band_project.project_id AND drone_run_band_rel.type_id = $drone_run_band_drone_run_project_relationship_type_id_cvterm_id)
        JOIN project AS drone_run_project ON (drone_run_project.project_id = drone_run_band_rel.object_project_id)
        JOIN project_relationship ON (drone_run_project.project_id = project_relationship.subject_project_id AND project_relationship.type_id=$drone_run_field_trial_project_relationship_type_id_cvterm_id)
        LEFT JOIN projectprop ON (drone_run_band_project.project_id = projectprop.project_id AND projectprop.type_id=$drone_run_related_time_cvterms_json_cvterm_id)
        WHERE project_relationship.object_project_id IN ($field_trial_id_list_string) ;";
    my $h = $schema->storage->dbh()->prepare($drone_run_time_q);
    $h->execute();
    my $refresh_mat_views = 0;
    while( my ($drone_run_project_id, $field_trial_project_id, $related_time_terms_json) = $h->fetchrow_array()) {
        my $related_time_terms;
        if (!$related_time_terms_json) {
            $related_time_terms = _perform_gdd_calculation_and_drone_run_time_saving($c, $schema, $field_trial_project_id, $drone_run_project_id, $c->config->{noaa_ncdc_access_token}, 50, 'average_daily_temp_sum');
            $refresh_mat_views = 1;
        }
        else {
            $related_time_terms = decode_json $related_time_terms_json;
        }
        if (!exists($related_time_terms->{gdd_average_temp})) {
            $related_time_terms = _perform_gdd_calculation_and_drone_run_time_saving($c, $schema, $field_trial_project_id, $drone_run_project_id, $c->config->{noaa_ncdc_access_token}, 50, 'average_daily_temp_sum');
            $refresh_mat_views = 1;
        }
    }
    if ($refresh_mat_views) {
        my $bs = CXGN::BreederSearch->new( { dbh=>$c->dbc->dbh, dbname=>$c->config->{dbname}, } );
        my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'fullview', 'nonconcurrent', $c->config->{basepath});
        sleep(10);
    }

    my %trait_name_encoder;
    my %trait_name_encoder_rev;
    my $trait_name_encoded = 1;
    my %phenotype_data;
    my %stock_info;
    my %stock_name_row_col;
    my %unique_accessions;
    my %seen_days_after_plantings;
    my %seen_times;
    my @data_matrix;
    my %obsunit_row_col;
    my %seen_plot_names;
    my %plot_id_map;

    if ($statistics_select eq 'lmer_germplasmname_replicate' || $statistics_select eq 'sommer_grm_spatial_genetic_blups' || $statistics_select eq 'sommer_grm_temporal_random_regression_dap_genetic_blups' || $statistics_select eq 'sommer_grm_temporal_random_regression_gdd_genetic_blups' || $statistics_select eq 'sommer_grm_genetic_only_random_regression_dap_genetic_blups' || $statistics_select eq 'sommer_grm_genetic_only_random_regression_gdd_genetic_blups' || $statistics_select eq 'blupf90_grm_random_regression_dap_blups' || $statistics_select eq 'blupf90_grm_random_regression_gdd_blups' || $statistics_select eq 'airemlf90_grm_random_regression_dap_blups' || $statistics_select eq 'airemlf90_grm_random_regression_gdd_blups' || $statistics_select eq 'sommer_grm_genetic_blups') {

        if ($statistics_select eq 'lmer_germplasmname_replicate' || $statistics_select eq 'sommer_grm_spatial_genetic_blups' || $statistics_select eq 'sommer_grm_genetic_blups') {

            my $phenotypes_search = CXGN::Phenotypes::SearchFactory->instantiate(
                'MaterializedViewTable',
                {
                    bcs_schema=>$schema,
                    data_level=>'plot',
                    trait_list=>$trait_id_list,
                    trial_list=>$field_trial_id_list,
                    include_timestamp=>0,
                    exclude_phenotype_outlier=>0
                }
            );
            my ($data, $unique_traits) = $phenotypes_search->search();
            @sorted_trait_names = sort keys %$unique_traits;
            @sorted_trait_names_original = sort keys %$unique_traits;

            if (scalar(@$data) == 0) {
                $c->stash->{rest} = { error => "There are no phenotypes for the trials and traits you have selected!"};
                return;
            }

            my %seen_trait_names;
            foreach my $obs_unit (@$data){
                my $germplasm_name = $obs_unit->{germplasm_uniquename};
                my $germplasm_stock_id = $obs_unit->{germplasm_stock_id};
                my $replicate_number = $obs_unit->{obsunit_rep} || '';
                my $block_number = $obs_unit->{obsunit_block} || '';
                my $obsunit_stock_id = $obs_unit->{observationunit_stock_id};
                my $obsunit_stock_uniquename = $obs_unit->{observationunit_uniquename};
                my $row_number = $obs_unit->{obsunit_row_number} || '';
                my $col_number = $obs_unit->{obsunit_col_number} || '';
                $unique_accessions{$germplasm_name}++;
                $stock_info{"S".$germplasm_stock_id} = {
                    uniquename => $germplasm_name
                };
                $stock_name_row_col{$obsunit_stock_uniquename} = {
                    row_number => $row_number,
                    col_number => $col_number,
                    obsunit_stock_id => $obsunit_stock_id,
                    obsunit_name => $obsunit_stock_uniquename,
                    rep => $replicate_number,
                    block => $block_number,
                    germplasm_stock_id => $germplasm_stock_id,
                    germplasm_name => $germplasm_name
                };

                if ($row_number < $min_row) {
                    $min_row = $row_number;
                }
                elsif ($row_number >= $max_row) {
                    $max_row = $row_number;
                }
                if ($col_number < $min_col) {
                    $min_col = $col_number;
                }
                elsif ($col_number >= $max_col) {
                    $max_col = $col_number;
                }

                my $observations = $obs_unit->{observations};
                foreach (@$observations){
                    my $trait_name = $_->{trait_name};
                    $phenotype_data{$obsunit_stock_uniquename}->{$trait_name} = $_->{value};
                    $seen_trait_names{$trait_name}++;

                    if ($_->{associated_image_project_time_json}) {
                        my $related_time_terms_json = decode_json $_->{associated_image_project_time_json};
                        my $time_days_cvterm = $related_time_terms_json->{day};
                        my $time_term_string = $time_days_cvterm;
                        my $time_days = (split '\|', $time_days_cvterm)[0];
                        my $time_value = (split ' ', $time_days)[1];
                        $seen_days_after_plantings{$time_value}++;
                        $trait_to_time_map{$trait_name} = $time_value;
                    }
                }
            }
            @unique_accession_names = sort keys %unique_accessions;

            foreach my $trait_name (@sorted_trait_names) {
                if (!exists($trait_name_encoder{$trait_name})) {
                    my $trait_name_e = 't'.$trait_name_encoded;
                    $trait_name_encoder{$trait_name} = $trait_name_e;
                    $trait_name_encoder_rev{$trait_name_e} = $trait_name;
                    $trait_name_encoded++;
                }
            }

            my %seen_trial_ids;
            foreach (@$data) {
                my $germplasm_name = $_->{germplasm_uniquename};
                my $germplasm_stock_id = $_->{germplasm_stock_id};
                my $obsunit_stock_id = $_->{observationunit_stock_id};
                my $obsunit_stock_uniquename = $_->{observationunit_uniquename};
                my $row_number = $_->{obsunit_row_number} || '';
                my $col_number = $_->{obsunit_col_number} || '';
                my @row = ($_->{obsunit_rep}, $_->{obsunit_block}, "S".$germplasm_stock_id, $obsunit_stock_id, $row_number, $col_number, $row_number, $col_number);
                $obsunit_row_col{$row_number}->{$col_number} = {
                    stock_id => $obsunit_stock_id,
                    stock_uniquename => $obsunit_stock_uniquename
                };
                $plot_id_map{$obsunit_stock_id} = $obsunit_stock_uniquename;
                $seen_plot_names{$obsunit_stock_uniquename}++;
                $seen_trial_ids{$_->{trial_id}}++;
                foreach my $t (@sorted_trait_names) {
                    if (defined($phenotype_data{$obsunit_stock_uniquename}->{$t})) {
                        push @row, $phenotype_data{$obsunit_stock_uniquename}->{$t} + 0;
                    } else {
                        print STDERR $obsunit_stock_uniquename." : $t : $germplasm_name : NA \n";
                        push @row, 'NA';
                    }
                }
                push @data_matrix, \@row;
            }

            my %unique_traits_ids;
            foreach (keys %seen_trial_ids){
                my $trial = CXGN::Trial->new({bcs_schema=>$schema, trial_id=>$_});
                my $traits_assayed = $trial->get_traits_assayed('plot', undef, 'time_ontology');
                foreach (@$traits_assayed) {
                    $unique_traits_ids{$_->[0]} = $_;
                }
            }
            foreach (values %unique_traits_ids) {
                foreach my $component (@{$_->[2]}) {
                    if (exists($seen_trait_names{$_->[1]}) && $component->{cv_type} && $component->{cv_type} eq 'time_ontology') {
                        my $time_term_string = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $component->{cvterm_id}, 'extended');
                        push @{$trait_composing_info{$_->[1]}}, $time_term_string;
                    }
                }
            }

            my @phenotype_header = ("replicate", "block", "id", "plot_id", "rowNumber", "colNumber", "rowNumberFactor", "colNumberFactor");
            my $num_col_before_traits = scalar(@phenotype_header);
            foreach (@sorted_trait_names) {
                push @phenotype_header, $trait_name_encoder{$_};
            }
            my $header_string = join ',', @phenotype_header;

            open(my $F, ">", $stats_tempfile) || die "Can't open file ".$stats_tempfile;
                print $F $header_string."\n";
                foreach (@data_matrix) {
                    my $line = join ',', @$_;
                    print $F "$line\n";
                }
            close($F);
        }
        elsif ($statistics_select eq 'sommer_grm_temporal_random_regression_dap_genetic_blups' || $statistics_select eq 'sommer_grm_temporal_random_regression_gdd_genetic_blups' || $statistics_select eq 'sommer_grm_genetic_only_random_regression_dap_genetic_blups' || $statistics_select eq 'sommer_grm_genetic_only_random_regression_gdd_genetic_blups') {

            my $phenotypes_search = CXGN::Phenotypes::SearchFactory->instantiate(
                'MaterializedViewTable',
                {
                    bcs_schema=>$schema,
                    data_level=>'plot',
                    trait_list=>$trait_id_list,
                    trial_list=>$field_trial_id_list,
                    include_timestamp=>0,
                    exclude_phenotype_outlier=>0
                }
            );
            my ($data, $unique_traits) = $phenotypes_search->search();
            @sorted_trait_names = sort keys %$unique_traits;

            if (scalar(@$data) == 0) {
                $c->stash->{rest} = { error => "There are no phenotypes for the trials and traits you have selected!"};
                return;
            }

            my $q_time = "SELECT t.cvterm_id FROM cvterm as t JOIN cv ON(t.cv_id=cv.cv_id) WHERE t.name=? and cv.name=?;";
            my $h_time = $schema->storage->dbh()->prepare($q_time);

            my %seen_plot_names;
            foreach my $obs_unit (@$data){
                my $germplasm_name = $obs_unit->{germplasm_uniquename};
                my $germplasm_stock_id = $obs_unit->{germplasm_stock_id};
                my $replicate_number = $obs_unit->{obsunit_rep} || '';
                my $block_number = $obs_unit->{obsunit_block} || '';
                my $obsunit_stock_id = $obs_unit->{observationunit_stock_id};
                my $obsunit_stock_uniquename = $obs_unit->{observationunit_uniquename};
                my $row_number = $obs_unit->{obsunit_row_number} || '';
                my $col_number = $obs_unit->{obsunit_col_number} || '';
                $seen_plot_names{$obsunit_stock_uniquename}++;
                $unique_accessions{$germplasm_name}++;
                $stock_info{"S".$germplasm_stock_id} = {
                    uniquename => $germplasm_name
                };
                $stock_name_row_col{$obsunit_stock_uniquename} = {
                    row_number => $row_number,
                    col_number => $col_number,
                    obsunit_stock_id => $obsunit_stock_id,
                    obsunit_name => $obsunit_stock_uniquename,
                    rep => $replicate_number,
                    block => $block_number,
                    germplasm_stock_id => $germplasm_stock_id,
                    germplasm_name => $germplasm_name
                };

                if ($row_number < $min_row) {
                    $min_row = $row_number;
                }
                elsif ($row_number >= $max_row) {
                    $max_row = $row_number;
                }
                if ($col_number < $min_col) {
                    $min_col = $col_number;
                }
                elsif ($col_number >= $max_col) {
                    $max_col = $col_number;
                }

                my $observations = $obs_unit->{observations};
                foreach (@$observations){
                    if ($_->{associated_image_project_time_json}) {
                        my $related_time_terms_json = decode_json $_->{associated_image_project_time_json};

                        my $time_value;
                        my $time_term_string;
                        if ($statistics_select eq 'sommer_grm_temporal_random_regression_dap_genetic_blups' || $statistics_select eq 'sommer_grm_genetic_only_random_regression_dap_genetic_blups') {
                            my $time_days_cvterm = $related_time_terms_json->{day};
                            $time_term_string = $time_days_cvterm;
                            my $time_days = (split '\|', $time_days_cvterm)[0];
                            $time_value = (split ' ', $time_days)[1];

                            $seen_days_after_plantings{$time_value}++;
                        }
                        elsif ($statistics_select eq 'sommer_grm_temporal_random_regression_gdd_genetic_blups' || $statistics_select eq 'sommer_grm_genetic_only_random_regression_gdd_genetic_blups') {
                            $time_value = $related_time_terms_json->{gdd_average_temp} + 0;

                            my $gdd_term_string = "GDD $time_value";
                            $h_time->execute($gdd_term_string, 'cxgn_time_ontology');
                            my ($gdd_cvterm_id) = $h_time->fetchrow_array();

                            if (!$gdd_cvterm_id) {
                                my $new_gdd_term = $schema->resultset("Cv::Cvterm")->create_with({
                                   name => $gdd_term_string,
                                   cv => 'cxgn_time_ontology'
                                });
                                $gdd_cvterm_id = $new_gdd_term->cvterm_id();
                            }
                            $time_term_string = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $gdd_cvterm_id, 'extended');
                        }
                        my $trait_name = $_->{trait_name};
                        $phenotype_data{$obsunit_stock_uniquename}->{$time_value} = $_->{value};
                        $seen_times{$time_value} = $trait_name;
                        $seen_trait_names{$trait_name} = $time_term_string;
                        $trait_to_time_map{$trait_name} = $time_value;
                    }
                }
            }
            if (scalar(keys %seen_times) == 0) {
                $c->stash->{rest} = { error => "There are no phenotypes with associated days after planting time associated to the traits you have selected!"};
                return;
            }

            @unique_accession_names = sort keys %unique_accessions;
            @sorted_trait_names = sort {$a <=> $b} keys %seen_times;
            @unique_plot_names = sort keys %seen_plot_names;
            @sorted_trait_names_original = sort {$a <=> $b} keys %seen_times;

            my $trait_name_encoded = 1;
            foreach my $trait_name (@sorted_trait_names) {
                if (!exists($trait_name_encoder{$trait_name})) {
                    my $trait_name_e = 't'.$trait_name_encoded;
                    $trait_name_encoder{$trait_name} = $trait_name_e;
                    $trait_name_encoder_rev{$trait_name_e} = $trait_name;
                    $trait_name_encoded++;
                }
            }

            while ( my ($trait_name, $time_term) = each %seen_trait_names) {
                push @{$trait_composing_info{$trait_name}}, $time_term;
            }

            foreach (@$data) {
                my $germplasm_name = $_->{germplasm_uniquename};
                my $germplasm_stock_id = $_->{germplasm_stock_id};
                my $obsunit_stock_id = $_->{observationunit_stock_id};
                my $obsunit_stock_uniquename = $_->{observationunit_uniquename};
                my $row_number = $_->{obsunit_row_number};
                my $col_number = $_->{obsunit_col_number};
                my @row = ($_->{obsunit_rep}, $_->{obsunit_block}, "S".$germplasm_stock_id, "P".$obsunit_stock_id, $row_number, $col_number, $row_number, $col_number);
                $obsunit_row_col{$row_number}->{$col_number} = {
                    stock_id => $obsunit_stock_id,
                    stock_uniquename => $obsunit_stock_uniquename
                };
                $plot_id_map{"P".$obsunit_stock_id} = $obsunit_stock_uniquename;
                $seen_plot_names{$obsunit_stock_uniquename}++;
                my $current_trait_index = 0;
                foreach my $t (@sorted_trait_names) {
                    if (defined($phenotype_data{$obsunit_stock_uniquename}->{$t})) {
                        if ($use_area_under_curve) {
                            my $val = 0;
                            foreach my $counter (0..$current_trait_index) {
                                if ($counter == 0) {
                                    $val = $val + $phenotype_data{$obsunit_stock_uniquename}->{$sorted_trait_names[$counter]} + 0;
                                }
                                else {
                                    my $t1 = $sorted_trait_names[$counter-1];
                                    my $t2 = $sorted_trait_names[$counter];
                                    my $p1 = $phenotype_data{$obsunit_stock_uniquename}->{$t1} + 0;
                                    my $p2 = $phenotype_data{$obsunit_stock_uniquename}->{$t2} + 0;
                                    my $neg = 1;
                                    my $min_val = $p1;
                                    if ($p2 < $p1) {
                                        $neg = -1;
                                        $min_val = $p2;
                                    }
                                    my $area = (($neg*($p2-$p1)*($t2-$t1))/2)+($t2-$t1)*$min_val;
                                    $val = $val + $area;
                                }
                            }
                            push @row, $val;
                        }
                        else {
                            push @row, $phenotype_data{$obsunit_stock_uniquename}->{$t} + 0;
                        }
                    } else {
                        print STDERR $obsunit_stock_uniquename." : $t : $germplasm_name : NA \n";
                        push @row, 'NA';
                    }
                    $current_trait_index++;
                }
                push @data_matrix, \@row;
            }

            my @phenotype_header = ("replicate", "block", "id", "plot_id", "rowNumber", "colNumber", "rowNumberFactor", "colNumberFactor");
            my $num_col_before_traits = scalar(@phenotype_header);
            push @phenotype_header, @sorted_trait_names;
            my $header_string = join ',', @phenotype_header;

            open(my $F, ">", $stats_tempfile) || die "Can't open file ".$stats_tempfile;
                print $F $header_string."\n";
                foreach (@data_matrix) {
                    my $line = join ',', @$_;
                    print $F "$line\n";
                }
            close($F);
        }
        elsif ($statistics_select eq 'blupf90_grm_random_regression_dap_blups' || $statistics_select eq 'blupf90_grm_random_regression_gdd_blups' || $statistics_select eq 'airemlf90_grm_random_regression_dap_blups' || $statistics_select eq 'airemlf90_grm_random_regression_gdd_blups') {

            $analysis_model_language = "F90";

            my $phenotypes_search = CXGN::Phenotypes::SearchFactory->instantiate(
                'MaterializedViewTable',
                {
                    bcs_schema=>$schema,
                    data_level=>'plot',
                    trait_list=>$trait_id_list,
                    trial_list=>$field_trial_id_list,
                    include_timestamp=>0,
                    exclude_phenotype_outlier=>0
                }
            );
            my ($data, $unique_traits) = $phenotypes_search->search();
            @sorted_trait_names = sort keys %$unique_traits;

            if (scalar(@$trait_id_list) < 2) {
                $c->stash->{rest} = { error => "Select more than 2 time points!"};
                return;
            }

            if (scalar(@$data) == 0) {
                $c->stash->{rest} = { error => "There are no phenotypes for the trials and traits you have selected!"};
                return;
            }

            my $q_time = "SELECT t.cvterm_id FROM cvterm as t JOIN cv ON(t.cv_id=cv.cv_id) WHERE t.name=? and cv.name=?;";
            my $h_time = $schema->storage->dbh()->prepare($q_time);

            my %seen_plots;
            my %seen_plot_names;
            foreach my $obs_unit (@$data){
                my $germplasm_name = $obs_unit->{germplasm_uniquename};
                my $germplasm_stock_id = $obs_unit->{germplasm_stock_id};
                my $replicate_number = $obs_unit->{obsunit_rep} || '';
                my $block_number = $obs_unit->{obsunit_block} || '';
                my $obsunit_stock_id = $obs_unit->{observationunit_stock_id};
                my $obsunit_stock_uniquename = $obs_unit->{observationunit_uniquename};
                my $row_number = $obs_unit->{obsunit_row_number} || '';
                my $col_number = $obs_unit->{obsunit_col_number} || '';
                $unique_accessions{$germplasm_name}++;
                $stock_info{$germplasm_stock_id} = {
                    uniquename => $germplasm_name
                };
                $stock_name_row_col{$obsunit_stock_uniquename} = {
                    row_number => $row_number,
                    col_number => $col_number,
                    obsunit_stock_id => $obsunit_stock_id,
                    obsunit_name => $obsunit_stock_uniquename,
                    rep => $replicate_number,
                    block => $block_number,
                    germplasm_stock_id => $germplasm_stock_id,
                    germplasm_name => $germplasm_name
                };

                if ($row_number < $min_row) {
                    $min_row = $row_number;
                }
                elsif ($row_number >= $max_row) {
                    $max_row = $row_number;
                }
                if ($col_number < $min_col) {
                    $min_col = $col_number;
                }
                elsif ($col_number >= $max_col) {
                    $max_col = $col_number;
                }

                $seen_plots{$obsunit_stock_id} = $obsunit_stock_uniquename;
                $seen_plot_names{$obsunit_stock_uniquename}++;
                my $observations = $obs_unit->{observations};
                foreach (@$observations){
                    if ($_->{associated_image_project_time_json}) {
                        my $related_time_terms_json = decode_json $_->{associated_image_project_time_json};
                        my $time;
                        my $time_term_string = '';
                        if ($statistics_select eq 'blupf90_grm_random_regression_gdd_blups' || $statistics_select eq 'airemlf90_grm_random_regression_gdd_blups') {
                            $time = $related_time_terms_json->{gdd_average_temp} + 0;

                            my $gdd_term_string = "GDD $time";
                            $h_time->execute($gdd_term_string, 'cxgn_time_ontology');
                            my ($gdd_cvterm_id) = $h_time->fetchrow_array();

                            if (!$gdd_cvterm_id) {
                                my $new_gdd_term = $schema->resultset("Cv::Cvterm")->create_with({
                                   name => $gdd_term_string,
                                   cv => 'cxgn_time_ontology'
                                });
                                $gdd_cvterm_id = $new_gdd_term->cvterm_id();
                            }
                            $time_term_string = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $gdd_cvterm_id, 'extended');
                        }
                        elsif ($statistics_select eq 'blupf90_grm_random_regression_dap_blups' || $statistics_select eq 'airemlf90_grm_random_regression_dap_blups') {
                            my $time_days_cvterm = $related_time_terms_json->{day};
                            $time_term_string = $time_days_cvterm;
                            my $time_days = (split '\|', $time_days_cvterm)[0];
                            $time = (split ' ', $time_days)[1] + 0;

                            $seen_days_after_plantings{$time}++;
                        }
                        my $trait_name = $_->{trait_name};
                        $phenotype_data{$obsunit_stock_uniquename}->{$time} = $_->{value};
                        $seen_times{$time} = $trait_name;
                        $seen_trait_names{$trait_name} = $time_term_string;
                        $trait_to_time_map{$trait_name} = $time;
                    }
                }
            }
            if (scalar(keys %seen_times) == 0) {
                $c->stash->{rest} = { error => "There are no phenotypes with associated days after planting time associated to the traits you have selected!"};
                return;
            }

            @unique_accession_names = sort keys %unique_accessions;
            @sorted_trait_names = sort {$a <=> $b} keys %seen_times;
            @unique_plot_names = sort keys %seen_plot_names;
            @sorted_trait_names_original = sort {$a <=> $b} keys %seen_times;
            # print STDERR Dumper \@sorted_trait_names;

            my $trait_name_encoded = 1;
            foreach my $trait_name (@sorted_trait_names) {
                if (!exists($trait_name_encoder{$trait_name})) {
                    my $trait_name_e = 't'.$trait_name_encoded;
                    $trait_name_encoder{$trait_name} = $trait_name_e;
                    $trait_name_encoder_rev{$trait_name_e} = $trait_name;
                    $trait_name_encoded++;
                }
            }

            while ( my ($trait_name, $time_term) = each %seen_trait_names) {
                push @{$trait_composing_info{$trait_name}}, $time_term;
            }

            $time_min = 100000000;
            $time_max = 0;
            foreach (@sorted_trait_names) {
                if ($_ < $time_min) {
                    $time_min = $_;
                }
                if ($_ > $time_max) {
                    $time_max = $_;
                }
            }
            print STDERR Dumper [$time_min, $time_max];

            if ($legendre_order_number >= scalar(@sorted_trait_names)) {
                $legendre_order_number = scalar(@sorted_trait_names) - 1;
            }

            my @sorted_trait_names_scaled;
            my $leg_pos_counter = 0;
            foreach (@sorted_trait_names) {
                # my $scaled_time = 2*(($_ - $time_min)/($time_max - $time_min)) - 1;
                my $scaled_time = ($_ - $time_min)/($time_max - $time_min);
                print STDERR Dumper $scaled_time;
                push @sorted_trait_names_scaled, $scaled_time;
                if ($leg_pos_counter < $legendre_order_number+1) {
                    push @sorted_scaled_ln_times, log($scaled_time+0.0001);
                }
                $leg_pos_counter++;
            }
            my $sorted_trait_names_scaled_string = join ',', @sorted_trait_names_scaled;

            my $cmd = 'R -e "library(sommer); library(orthopolynom);
            polynomials <- leg(c('.$sorted_trait_names_scaled_string.'), n='.$legendre_order_number.', intercept=TRUE);
            write.table(polynomials, file=\''.$stats_out_tempfile.'\', row.names=FALSE, col.names=TRUE, sep=\'\t\');"';
            my $status = system("$cmd > /tmp/Rout");

            my %polynomial_map;
            my $csv = Text::CSV->new({ sep_char => "\t" });
            open(my $fh, '<', $stats_out_tempfile)
                or die "Could not open file '$stats_out_tempfile' $!";

                print STDERR "Opened $stats_out_tempfile\n";
                my $header = <$fh>;
                my @header_cols;
                if ($csv->parse($header)) {
                    @header_cols = $csv->fields();
                }

                my $p_counter = 0;
                while (my $row = <$fh>) {
                    my @columns;
                    if ($csv->parse($row)) {
                        @columns = $csv->fields();
                    }
                    my $time = $sorted_trait_names[$p_counter];
                    $polynomial_map{$time} = \@columns;
                    $p_counter++;
                }
            close($fh);

            open(my $F_prep, ">", $stats_prep_tempfile) || die "Can't open file ".$stats_prep_tempfile;
                print $F_prep "accession_id,accession_id_factor,plot_id,plot_id_factor,replicate,time,replicate_time,ind_replicate\n";
                foreach (@$data) {
                    my $obsunit_stock_id = $_->{observationunit_stock_id};
                    my $replicate = $_->{obsunit_rep};
                    my $germplasm_stock_id = $_->{germplasm_stock_id};
                    foreach my $t (@sorted_trait_names) {
                        print $F_prep "$germplasm_stock_id,,$obsunit_stock_id,,$replicate,$t,$replicate"."_"."$t,$germplasm_stock_id"."_"."$replicate\n";
                    }
                }
            close($F_prep);

            my $cmd_factor = 'R -e "library(data.table);
            mat <- fread(\''.$stats_prep_tempfile.'\', header=TRUE, sep=\',\');
            mat\$replicate_time <- as.numeric(as.factor(mat\$replicate_time));
            mat\$ind_replicate <- as.numeric(as.factor(mat\$ind_replicate));
            mat\$accession_id_factor <- as.numeric(as.factor(mat\$accession_id));
            mat\$plot_id_factor <- as.numeric(as.factor(mat\$plot_id));
            write.table(mat, file=\''.$stats_prep_factor_tempfile.'\', row.names=FALSE, col.names=TRUE, sep=\'\t\');"';
            print STDERR Dumper $cmd_factor;
            my $status_factor = system("$cmd_factor > /dev/null");

            my %plot_factor_map;
            my %plot_rep_time_factor_map;
            my %plot_ind_rep_factor_map;
            my %seen_rep_times;
            my %seen_ind_reps;
            $csv = Text::CSV->new({ sep_char => "\t" });
            open(my $fh_factor, '<', $stats_prep_factor_tempfile)
                or die "Could not open file '$stats_prep_factor_tempfile' $!";

                print STDERR "Opened $stats_prep_factor_tempfile\n";
                $header = <$fh_factor>;
                if ($csv->parse($header)) {
                    @header_cols = $csv->fields();
                }

                my $line_factor_count = 0;
                while (my $row = <$fh_factor>) {
                    my @columns;
                    if ($csv->parse($row)) {
                        @columns = $csv->fields();
                    }
                    my $accession_id = $columns[0];
                    my $accession_id_factor = $columns[1];
                    my $plot_id = $columns[2];
                    my $plot_id_factor = $columns[3];
                    my $rep = $columns[4];
                    my $time = $columns[5];
                    my $rep_time = $columns[6];
                    my $ind_rep = $columns[7];
                    $plot_factor_map{$plot_id} = {
                        plot_id => $plot_id,
                        plot_id_factor => $plot_id_factor,
                        accession_id => $accession_id,
                        accession_id_factor => $accession_id_factor,
                        replicate => $rep,
                        time => $time,
                        replicate_time => $rep_time,
                        ind_replicate => $ind_rep
                    };
                    $plot_rep_time_factor_map{$plot_id}->{$rep}->{$time} = $rep_time;
                    $plot_ind_rep_factor_map{$plot_id}->{$accession_id}->{$rep} = $ind_rep;
                    $seen_rep_times{$rep_time}++;
                    # $seen_ind_reps{$ind_rep}++;
                    $seen_ind_reps{$plot_id_factor}++;
                    $accession_id_factor_map{$accession_id} = $accession_id_factor;
                    $accession_id_factor_map_reverse{$accession_id_factor} = $stock_info{$accession_id}->{uniquename};
                    # $plot_id_factor_map_reverse{$ind_rep} = $seen_plots{$plot_id};
                    $plot_id_factor_map_reverse{$plot_id_factor} = $seen_plots{$plot_id};
                    $plot_id_count_map_reverse{$line_factor_count} = $seen_plots{$plot_id};
                    $time_count_map_reverse{$line_factor_count} = $time;
                    $line_factor_count++;
                }
            close($fh_factor);
            # print STDERR Dumper \%plot_factor_map;
            @rep_time_factors = sort keys %seen_rep_times;
            @ind_rep_factors = sort keys %seen_ind_reps;

            my @data_matrix_phenotypes;
            my %stock_row_col;
            my @stocks_ordered;
            foreach (@$data) {
                my $germplasm_name = $_->{germplasm_uniquename};
                my $germplasm_stock_id = $_->{germplasm_stock_id};
                my $obsunit_stock_id = $_->{observationunit_stock_id};
                my $obsunit_stock_uniquename = $_->{observationunit_uniquename};
                my $row_number = $_->{obsunit_row_number};
                my $replicate_number = $_->{obsunit_rep};
                my $col_number = $_->{obsunit_col_number};
                $obsunit_row_col{$row_number}->{$col_number} = {
                    stock_id => $obsunit_stock_id,
                    stock_uniquename => $obsunit_stock_uniquename
                };
                $plot_id_map{$obsunit_stock_id} = $obsunit_stock_uniquename;
                $seen_plot_names{$obsunit_stock_uniquename}++;
                $stock_row_col{$obsunit_stock_id} = {
                    row_number => $row_number,
                    col_number => $col_number
                };
                my @data_matrix_phenotypes_row;
                my $current_trait_index = 0;
                push @stocks_ordered, $obsunit_stock_id;
                foreach my $t (@sorted_trait_names) {
                    my @row = (
                        $accession_id_factor_map{$germplasm_stock_id},
                        $obsunit_stock_id,
                        $replicate_number,
                        $t,
                        $plot_rep_time_factor_map{$obsunit_stock_id}->{$replicate_number}->{$t},
                        #$plot_ind_rep_factor_map{$obsunit_stock_id}->{$germplasm_stock_id}->{$replicate_number},
                        $plot_factor_map{$obsunit_stock_id}->{plot_id_factor}
                    );

                    my $polys = $polynomial_map{$t};
                    push @row, @$polys;

                    if (defined($phenotype_data{$obsunit_stock_uniquename}->{$t})) {
                        if ($use_area_under_curve) {
                            my $val = 0;
                            foreach my $counter (0..$current_trait_index) {
                                if ($counter == 0) {
                                    $val = $val + $phenotype_data{$obsunit_stock_uniquename}->{$sorted_trait_names[$counter]} + 0;
                                }
                                else {
                                    my $t1 = $sorted_trait_names[$counter-1];
                                    my $t2 = $sorted_trait_names[$counter];
                                    my $p1 = $phenotype_data{$obsunit_stock_uniquename}->{$t1} + 0;
                                    my $p2 = $phenotype_data{$obsunit_stock_uniquename}->{$t2} + 0;
                                    my $neg = 1;
                                    my $min_val = $p1;
                                    if ($p2 < $p1) {
                                        $neg = -1;
                                        $min_val = $p2;
                                    }
                                    $val = $val + (($neg*($p2-$p1)*($t2-$t1))/2)+($t2-$t1)*$min_val;
                                }
                            }
                            push @row, $val;
                            push @data_matrix_phenotypes_row, $val;
                        }
                        else {
                            push @row, $phenotype_data{$obsunit_stock_uniquename}->{$t} + 0;
                            push @data_matrix_phenotypes_row, $phenotype_data{$obsunit_stock_uniquename}->{$t} + 0;
                        }
                    } else {
                        print STDERR $obsunit_stock_uniquename." : $t : $germplasm_name : NA \n";
                        push @row, '';
                        push @data_matrix_phenotypes_row, 'NA';
                    }

                    push @data_matrix, \@row;
                    push @data_matrix_phenotypes, \@data_matrix_phenotypes_row;

                    $current_trait_index++;
                }
            }
            # print STDERR Dumper \@data_matrix;
            my @legs_header;
            for (0..$legendre_order_number) {
                push @legs_header, "legendre$_";
            }
            my @phenotype_header = ("id", "plot_id", "replicate", "time", "replicate_time", "ind_replicate", @legs_header, "phenotype");
            open(my $F, ">", $stats_tempfile_2) || die "Can't open file ".$stats_tempfile_2;
                # print $F $header_string."\n";
                foreach (@data_matrix) {
                    my $line = join ' ', @$_;
                    print $F "$line\n";
                }
            close($F);

            open(my $F2, ">", $stats_prep2_tempfile) || die "Can't open file ".$stats_prep2_tempfile;
                # print $F $header_string."\n";
                foreach (@data_matrix_phenotypes) {
                    my $line = join ',', @$_;
                    print $F2 "$line\n";
                }
            close($F2);

            if ($permanent_environment_structure eq 'euclidean_rows_and_columns') {
                my $data = '';
                my %euclidean_distance_hash;
                my $min_euc_dist = 10000000000000000000;
                my $max_euc_dist = 0;
                foreach my $s (sort { $a <=> $b } @stocks_ordered) {
                    foreach my $r (sort { $a <=> $b } @stocks_ordered) {
                        my $s_factor = $plot_factor_map{$s}->{plot_id_factor};
                        my $r_factor = $plot_factor_map{$r}->{plot_id_factor};
                        if (!exists($euclidean_distance_hash{$s_factor}->{$r_factor}) && !exists($euclidean_distance_hash{$r_factor}->{$s_factor})) {
                            my $row_1 = $stock_row_col{$s}->{row_number};
                            my $col_1 = $stock_row_col{$s}->{col_number};
                            my $row_2 = $stock_row_col{$r}->{row_number};
                            my $col_2 = $stock_row_col{$r}->{col_number};
                            my $dist = sqrt( ($row_2 - $row_1)**2 + ($col_2 - $col_1)**2 );
                            if ($dist != 0) {
                                $dist = 1/$dist;
                            }
                            if (defined $dist and length $dist) {
                                $euclidean_distance_hash{$s_factor}->{$r_factor} = $dist;

                                if ($dist < $min_euc_dist) {
                                    $min_euc_dist = $dist;
                                }
                                elsif ($dist > $max_euc_dist) {
                                    $max_euc_dist = $dist;
                                }
                            }
                            else {
                                $c->stash->{rest} = { error => "There are not rows and columns for all of the plots! Do not try to use a Euclidean distance between plots for the permanent environment structure"};
                                return;
                            }
                        }
                    }
                }

                foreach my $r (sort { $a <=> $b } keys %euclidean_distance_hash) {
                    foreach my $s (sort { $a <=> $b } keys %{$euclidean_distance_hash{$r}}) {
                        my $val = $euclidean_distance_hash{$r}->{$s};
                        if (defined $val and length $val) {
                            my $val_scaled = ($val-$min_euc_dist)/($max_euc_dist-$min_euc_dist);
                            $data .= "$r\t$s\t$val_scaled\n";
                        }
                    }
                }

                open(my $F3, ">", $permanent_environment_structure_tempfile) || die "Can't open file ".$permanent_environment_structure_tempfile;
                    print $F3 $data;
                close($F3);
            }
            elsif ($permanent_environment_structure eq 'phenotype_correlation') {
                my $phenotypes_search_permanent_environment_structure = CXGN::Phenotypes::SearchFactory->instantiate(
                    'MaterializedViewTable',
                    {
                        bcs_schema=>$schema,
                        data_level=>'plot',
                        trial_list=>$field_trial_id_list,
                        trait_list=>$permanent_environment_structure_phenotype_correlation_traits,
                        include_timestamp=>0,
                        exclude_phenotype_outlier=>0
                    }
                );
                my ($data_permanent_environment_structure, $unique_traits_permanent_environment_structure) = $phenotypes_search_permanent_environment_structure->search();

                if (scalar(@$data_permanent_environment_structure) == 0) {
                    $c->stash->{rest} = { error => "There are no phenotypes for the permanent environment structure traits you have selected!"};
                    return;
                }

                my %seen_plot_names_pe_rel;
                my %phenotype_data_pe_rel;
                my %seen_traits_pe_rel;
                foreach my $obs_unit (@$data_permanent_environment_structure){
                    my $obsunit_stock_uniquename = $obs_unit->{observationunit_uniquename};
                    my $germplasm_name = $obs_unit->{germplasm_uniquename};
                    my $germplasm_stock_id = $obs_unit->{germplasm_stock_id};
                    my $row_number = $obs_unit->{obsunit_row_number} || '';
                    my $col_number = $obs_unit->{obsunit_col_number} || '';
                    my $rep = $obs_unit->{obsunit_rep};
                    my $block = $obs_unit->{obsunit_block};
                    $seen_plot_names_pe_rel{$obsunit_stock_uniquename} = $obs_unit;
                    my $observations = $obs_unit->{observations};
                    foreach (@$observations){
                        $phenotype_data_pe_rel{$obsunit_stock_uniquename}->{$_->{trait_name}} = $_->{value};
                        $seen_traits_pe_rel{$_->{trait_name}}++;
                    }
                }

                my @seen_plot_names_pe_rel_sorted = sort keys %seen_plot_names_pe_rel;
                my @seen_traits_pe_rel_sorted = sort keys %seen_traits_pe_rel;

                my @header_pe = ('plot_id');

                my %trait_name_encoder_pe;
                my %trait_name_encoder_rev_pe;
                my $trait_name_encoded_pe = 1;
                my @header_traits_pe;
                foreach my $trait_name (@seen_traits_pe_rel_sorted) {
                    if (!exists($trait_name_encoder_pe{$trait_name})) {
                        my $trait_name_e = 't'.$trait_name_encoded_pe;
                        $trait_name_encoder_pe{$trait_name} = $trait_name_e;
                        $trait_name_encoder_rev_pe{$trait_name_e} = $trait_name;
                        push @header_traits_pe, $trait_name_e;
                        $trait_name_encoded_pe++;
                    }
                }

                my @pe_pheno_matrix;
                push @header_pe, @header_traits_pe;
                push @pe_pheno_matrix, \@header_pe;

                foreach my $p (@seen_plot_names_pe_rel_sorted) {
                    my $obj = $seen_plot_names_pe_rel{$p};
                    my @row = ($plot_factor_map{$obj->{observationunit_stock_id}}->{plot_id_factor});
                    foreach my $t (@seen_traits_pe_rel_sorted) {
                        my $val = $phenotype_data_pe_rel{$p}->{$t} + 0;
                        push @row, $val;
                    }
                    push @pe_pheno_matrix, \@row;
                }

                open(my $pe_pheno_f, ">", $stats_out_pe_pheno_rel_tempfile) || die "Can't open file ".$stats_out_pe_pheno_rel_tempfile;
                    foreach (@pe_pheno_matrix) {
                        my $line = join "\t", @$_;
                        print $pe_pheno_f $line."\n";
                    }
                close($pe_pheno_f);

                my %rel_pe_result_hash;
                my $pe_rel_cmd = 'R -e "library(lme4); library(data.table);
                mat_agg <- fread(\''.$stats_out_pe_pheno_rel_tempfile.'\', header=TRUE, sep=\'\t\');
                mat_pheno <- mat_agg[,2:ncol(mat_agg)];
                cor_mat <- cor(t(mat_pheno));
                rownames(cor_mat) <- mat_agg\$plot_id;
                colnames(cor_mat) <- mat_agg\$plot_id;
                range01 <- function(x){(x-min(x))/(max(x)-min(x))};
                cor_mat <- range01(cor_mat);
                write.table(cor_mat, file=\''.$stats_out_pe_pheno_rel_tempfile2.'\', row.names=TRUE, col.names=TRUE, sep=\'\t\');"';
                # print STDERR Dumper $pe_rel_cmd;
                my $status_pe_rel = system("$pe_rel_cmd > /dev/null");

                my $csv = Text::CSV->new({ sep_char => "\t" });

                open(my $pe_rel_res, '<', $stats_out_pe_pheno_rel_tempfile2)
                    or die "Could not open file '$stats_out_pe_pheno_rel_tempfile2' $!";

                    print STDERR "Opened $stats_out_pe_pheno_rel_tempfile2\n";
                    my $header_row = <$pe_rel_res>;
                    my @header;
                    if ($csv->parse($header_row)) {
                        @header = $csv->fields();
                    }

                    while (my $row = <$pe_rel_res>) {
                        my @columns;
                        if ($csv->parse($row)) {
                            @columns = $csv->fields();
                        }
                        my $stock_id1 = $columns[0];
                        my $counter = 1;
                        foreach my $stock_id2 (@header) {
                            my $val = $columns[$counter];
                            $rel_pe_result_hash{$stock_id1}->{$stock_id2} = $val;
                            $counter++;
                        }
                    }
                close($pe_rel_res);

                my $data_rel_pe = '';
                my %result_hash_pe;
                foreach my $s (sort { $a <=> $b } @stocks_ordered) {
                    foreach my $r (sort { $a <=> $b } @stocks_ordered) {
                        my $s_factor = $plot_factor_map{$s}->{plot_id_factor};
                        my $r_factor = $plot_factor_map{$r}->{plot_id_factor};
                        if (!exists($result_hash_pe{$s_factor}->{$r_factor}) && !exists($result_hash_pe{$r_factor}->{$s_factor})) {
                            $result_hash_pe{$s_factor}->{$r_factor} = $rel_pe_result_hash{$s_factor}->{$r_factor};
                        }
                    }
                }
                foreach my $r (sort { $a <=> $b } keys %result_hash_pe) {
                    foreach my $s (sort { $a <=> $b } keys %{$result_hash_pe{$r}}) {
                        my $val = $result_hash_pe{$r}->{$s};
                        if (defined $val and length $val) {
                            $data_rel_pe .= "$r\t$s\t$val\n";
                        }
                    }
                }

                open(my $pe_rel_out, ">", $permanent_environment_structure_tempfile) || die "Can't open file ".$permanent_environment_structure_tempfile;
                    print $pe_rel_out $data_rel_pe;
                close($pe_rel_out);
            }
        }

        if ($statistics_select eq 'sommer_grm_spatial_genetic_blups' || $statistics_select eq 'sommer_grm_temporal_random_regression_dap_genetic_blups' || $statistics_select eq 'sommer_grm_temporal_random_regression_gdd_genetic_blups' || $statistics_select eq 'sommer_grm_genetic_only_random_regression_dap_genetic_blups'
            || $statistics_select eq 'sommer_grm_genetic_only_random_regression_gdd_genetic_blups' || $statistics_select eq 'blupf90_grm_random_regression_gdd_blups' || $statistics_select eq 'blupf90_grm_random_regression_dap_blups' || $statistics_select eq 'airemlf90_grm_random_regression_gdd_blups' || $statistics_select eq 'airemlf90_grm_random_regression_dap_blups'
            || $statistics_select eq 'sommer_grm_genetic_blups') {

            my %seen_accession_stock_ids;
            foreach my $trial_id (@$field_trial_id_list) {
                my $trial = CXGN::Trial->new({ bcs_schema => $schema, trial_id => $trial_id });
                my $accessions = $trial->get_accessions();
                foreach (@$accessions) {
                    $seen_accession_stock_ids{$_->{stock_id}}++;
                }
            }
            my @accession_ids = keys %seen_accession_stock_ids;

            if ($compute_relationship_matrix_from_htp_phenotypes eq 'genotypes') {

                if ($include_pedgiree_info_if_compute_from_parents) {
                    my $shared_cluster_dir_config = $c->config->{cluster_shared_tempdir};
                    my $tmp_arm_dir = $shared_cluster_dir_config."/tmp_download_arm";
                    mkdir $tmp_arm_dir if ! -d $tmp_arm_dir;
                    my ($arm_tempfile_fh, $arm_tempfile) = tempfile("drone_stats_download_arm_XXXXX", DIR=> $tmp_arm_dir);
                    my ($grm1_tempfile_fh, $grm1_tempfile) = tempfile("drone_stats_download_grm1_XXXXX", DIR=> $tmp_arm_dir);
                    my ($grm_out_temp_tempfile_fh, $grm_out_temp_tempfile) = tempfile("drone_stats_download_grm_temp_out_XXXXX", DIR=> $tmp_arm_dir);
                    my ($grm_out_tempfile_fh, $grm_out_tempfile) = tempfile("drone_stats_download_grm_out_XXXXX", DIR=> $tmp_arm_dir);
                    my ($grm_out_posdef_tempfile_fh, $grm_out_posdef_tempfile) = tempfile("drone_stats_download_grm_out_XXXXX", DIR=> $tmp_arm_dir);

                    if (!$protocol_id) {
                        $protocol_id = undef;
                    }

                    my $pedigree_arm = CXGN::Pedigree::ARM->new({
                        bcs_schema=>$schema,
                        arm_temp_file=>$arm_tempfile,
                        people_schema=>$people_schema,
                        accession_id_list=>\@accession_ids,
                        # plot_id_list=>\@plot_id_list,
                        cache_root=>$c->config->{cache_file_path},
                        download_format=>'matrix', #either 'matrix', 'three_column', or 'heatmap'
                    });
                    my ($parent_hash, $stock_ids, $all_accession_stock_ids, $female_stock_ids, $male_stock_ids) = $pedigree_arm->get_arm(
                        $shared_cluster_dir_config,
                        $c->config->{backend},
                        $c->config->{cluster_host},
                        $c->config->{'web_cluster_queue'},
                        $c->config->{basepath}
                    );
                    # print STDERR Dumper $parent_hash;

                    my $female_geno = CXGN::Genotype::GRM->new({
                        bcs_schema=>$schema,
                        grm_temp_file=>$grm1_tempfile,
                        people_schema=>$people_schema,
                        cache_root=>$c->config->{cache_file_path},
                        accession_id_list=>$female_stock_ids,
                        protocol_id=>$protocol_id,
                        get_grm_for_parental_accessions=>0,
                        download_format=>'three_column_reciprocal'
                        # minor_allele_frequency=>$minor_allele_frequency,
                        # marker_filter=>$marker_filter,
                        # individuals_filter=>$individuals_filter
                    });
                    my $female_grm_data = $female_geno->download_grm(
                        'data',
                        $shared_cluster_dir_config,
                        $c->config->{backend},
                        $c->config->{cluster_host},
                        $c->config->{'web_cluster_queue'},
                        $c->config->{basepath}
                    );
                    my @fl = split '\n', $female_grm_data;
                    my %female_parent_grm;
                    foreach (@fl) {
                        my @l = split '\t', $_;
                        $female_parent_grm{$l[0]}->{$l[1]} = $l[2];
                    }
                    # print STDERR Dumper \%female_parent_grm;

                    my $male_geno = CXGN::Genotype::GRM->new({
                        bcs_schema=>$schema,
                        grm_temp_file=>$grm1_tempfile,
                        people_schema=>$people_schema,
                        cache_root=>$c->config->{cache_file_path},
                        accession_id_list=>$male_stock_ids,
                        protocol_id=>$protocol_id,
                        get_grm_for_parental_accessions=>0,
                        download_format=>'three_column_reciprocal'
                        # minor_allele_frequency=>$minor_allele_frequency,
                        # marker_filter=>$marker_filter,
                        # individuals_filter=>$individuals_filter
                    });
                    my $male_grm_data = $male_geno->download_grm(
                        'data',
                        $shared_cluster_dir_config,
                        $c->config->{backend},
                        $c->config->{cluster_host},
                        $c->config->{'web_cluster_queue'},
                        $c->config->{basepath}
                    );
                    my @ml = split '\n', $male_grm_data;
                    my %male_parent_grm;
                    foreach (@ml) {
                        my @l = split '\t', $_;
                        $male_parent_grm{$l[0]}->{$l[1]} = $l[2];
                    }
                    # print STDERR Dumper \%male_parent_grm;

                    my %rel_result_hash;
                    foreach my $a1 (@accession_ids) {
                        foreach my $a2 (@accession_ids) {
                            my $female_parent1 = $parent_hash->{$a1}->{female_stock_id};
                            my $male_parent1 = $parent_hash->{$a1}->{male_stock_id};
                            my $female_parent2 = $parent_hash->{$a2}->{female_stock_id};
                            my $male_parent2 = $parent_hash->{$a2}->{male_stock_id};

                            my $female_rel = 0;
                            if ($female_parent1 && $female_parent2 && $female_parent_grm{'S'.$female_parent1}->{'S'.$female_parent2}) {
                                $female_rel = $female_parent_grm{'S'.$female_parent1}->{'S'.$female_parent2};
                            }
                            elsif ($female_parent1 && $female_parent2 && $female_parent1 == $female_parent2) {
                                $female_rel = 1;
                            }
                            elsif ($a1 == $a2) {
                                $female_rel = 1;
                            }

                            my $male_rel = 0;
                            if ($male_parent1 && $male_parent2 && $male_parent_grm{'S'.$male_parent1}->{'S'.$male_parent2}) {
                                $male_rel = $male_parent_grm{'S'.$male_parent1}->{'S'.$male_parent2};
                            }
                            elsif ($male_parent1 && $male_parent2 && $male_parent1 == $male_parent2) {
                                $male_rel = 1;
                            }
                            elsif ($a1 == $a2) {
                                $male_rel = 1;
                            }
                            # print STDERR "$a1 $a2 $female_rel $male_rel\n";

                            my $rel = 0.5*($female_rel + $male_rel);
                            $rel_result_hash{$a1}->{$a2} = $rel;
                        }
                    }
                    # print STDERR Dumper \%rel_result_hash;

                    my $data = '';
                    my %result_hash;
                    foreach my $s (sort @accession_ids) {
                        foreach my $c (sort @accession_ids) {
                            if (!exists($result_hash{$s}->{$c}) && !exists($result_hash{$c}->{$s})) {
                                my $val = $rel_result_hash{$s}->{$c};
                                if (defined $val and length $val) {
                                    $result_hash{$s}->{$c} = $val;
                                    $data .= "S$s\tS$c\t$val\n";
                                }
                            }
                        }
                    }

                    # print STDERR Dumper $data;
                    open(my $F2, ">", $grm_out_temp_tempfile) || die "Can't open file ".$grm_out_temp_tempfile;
                        print $F2 $data;
                    close($F2);

                    my $cmd = 'R -e "library(data.table); library(scales); library(tidyr); library(reshape2);
                    three_col <- fread(\''.$grm_out_temp_tempfile.'\', header=FALSE, sep=\'\t\');
                    A_wide <- dcast(three_col, V1~V2, value.var=\'V3\');
                    A_1 <- A_wide[,-1];
                    A_1[is.na(A_1)] <- 0;
                    A <- A_1 + t(A_1);
                    diag(A) <- diag(as.matrix(A_1));
                    E = eigen(A);
                    ev = E\$values;
                    U = E\$vectors;
                    no = dim(A)[1];
                    nev = which(ev < 0);
                    wr = 0;
                    k=length(nev);
                    if(k > 0){
                        p = ev[no - k];
                        B = sum(ev[nev])*2.0;
                        wr = (B*B*100.0)+1;
                        val = ev[nev];
                        ev[nev] = p*(B-val)*(B-val)/wr;
                        A = U%*%diag(ev)%*%t(U);
                    }
                    A <- as.data.frame(A);
                    colnames(A) <- A_wide[,1];
                    A\$stock_id <- A_wide[,1];
                    A_threecol <- melt(A, id.vars = c(\'stock_id\'), measure.vars = A_wide[,1]);
                    A_threecol\$stock_id <- substring(A_threecol\$stock_id, 2);
                    A_threecol\$variable <- substring(A_threecol\$variable, 2);
                    write.table(data.frame(variable = A_threecol\$variable, stock_id = A_threecol\$stock_id, value = A_threecol\$value), file=\''.$grm_out_tempfile.'\', row.names=FALSE, col.names=FALSE, sep=\'\t\');"';
                    print STDERR $cmd."\n";
                    my $status = system("$cmd > /dev/null");

                    my $csv = Text::CSV->new({ sep_char => "\t" });

                    my %rel_pos_def_result_hash;
                    open(my $F3, '<', $grm_out_tempfile)
                        or die "Could not open file '$grm_out_tempfile' $!";

                        print STDERR "Opened $grm_out_tempfile\n";

                        while (my $row = <$F3>) {
                            my @columns;
                            if ($csv->parse($row)) {
                                @columns = $csv->fields();
                            }
                            my $stock_id1 = $columns[0];
                            my $stock_id2 = $columns[1];
                            my $val = $columns[2];
                            $rel_pos_def_result_hash{$stock_id1}->{$stock_id2} = $val;
                        }
                    close($F3);

                    my $data_pos_def = '';
                    if ($statistics_select eq 'blupf90_grm_random_regression_gdd_blups' || $statistics_select eq 'blupf90_grm_random_regression_dap_blups' || $statistics_select eq 'airemlf90_grm_random_regression_gdd_blups' || $statistics_select eq 'airemlf90_grm_random_regression_dap_blups') {
                        my %result_hash;
                        foreach my $s (sort @accession_ids) {
                            foreach my $c (sort @accession_ids) {
                                if (!exists($result_hash{$s}->{$c}) && !exists($result_hash{$c}->{$s})) {
                                    my $val = $rel_pos_def_result_hash{$s}->{$c};
                                    if (defined $val and length $val) {
                                        $result_hash{$s}->{$c} = $val;
                                        $data_pos_def .= "$s\t$c\t$val\n";
                                    }
                                }
                            }
                        }
                    }
                    else {
                        my %result_hash;
                        foreach my $s (sort @accession_ids) {
                            foreach my $c (sort @accession_ids) {
                                if (!exists($result_hash{$s}->{$c}) && !exists($result_hash{$c}->{$s})) {
                                    my $val = $rel_pos_def_result_hash{$s}->{$c};
                                    if (defined $val and length $val) {
                                        $result_hash{$s}->{$c} = $val;
                                        $result_hash{$c}->{$s} = $val;
                                        $data_pos_def .= "S$s\tS$c\t$val\n";
                                        if ($s != $c) {
                                            $data_pos_def .= "S$c\tS$s\t$val\n";
                                        }
                                    }
                                }
                            }
                        }
                    }

                    open(my $F4, ">", $grm_out_posdef_tempfile) || die "Can't open file ".$grm_out_posdef_tempfile;
                        print $F4 $data_pos_def;
                    close($F4);

                    $grm_file = $grm_out_posdef_tempfile;
                }
                elsif ($use_parental_grms_if_compute_from_parents) {
                    my $shared_cluster_dir_config = $c->config->{cluster_shared_tempdir};
                    my $tmp_arm_dir = $shared_cluster_dir_config."/tmp_download_arm";
                    mkdir $tmp_arm_dir if ! -d $tmp_arm_dir;
                    my ($arm_tempfile_fh, $arm_tempfile) = tempfile("drone_stats_download_arm_XXXXX", DIR=> $tmp_arm_dir);
                    my ($grm1_tempfile_fh, $grm1_tempfile) = tempfile("drone_stats_download_grm1_XXXXX", DIR=> $tmp_arm_dir);
                    my ($grm_out_temp_tempfile_fh, $grm_out_temp_tempfile) = tempfile("drone_stats_download_grm_temp_out_XXXXX", DIR=> $tmp_arm_dir);
                    my ($grm_out_tempfile_fh, $grm_out_tempfile) = tempfile("drone_stats_download_grm_out_XXXXX", DIR=> $tmp_arm_dir);
                    my ($grm_out_posdef_tempfile_fh, $grm_out_posdef_tempfile) = tempfile("drone_stats_download_grm_out_XXXXX", DIR=> $tmp_arm_dir);

                    if (!$protocol_id) {
                        $protocol_id = undef;
                    }

                    my $pedigree_arm = CXGN::Pedigree::ARM->new({
                        bcs_schema=>$schema,
                        arm_temp_file=>$arm_tempfile,
                        people_schema=>$people_schema,
                        accession_id_list=>\@accession_ids,
                        # plot_id_list=>\@plot_id_list,
                        cache_root=>$c->config->{cache_file_path},
                        download_format=>'matrix', #either 'matrix', 'three_column', or 'heatmap'
                    });
                    my ($parent_hash, $stock_ids, $all_accession_stock_ids, $female_stock_ids, $male_stock_ids) = $pedigree_arm->get_arm(
                        $shared_cluster_dir_config,
                        $c->config->{backend},
                        $c->config->{cluster_host},
                        $c->config->{'web_cluster_queue'},
                        $c->config->{basepath}
                    );
                    # print STDERR Dumper $parent_hash;

                    my $female_geno = CXGN::Genotype::GRM->new({
                        bcs_schema=>$schema,
                        grm_temp_file=>$grm1_tempfile,
                        people_schema=>$people_schema,
                        cache_root=>$c->config->{cache_file_path},
                        accession_id_list=>$female_stock_ids,
                        protocol_id=>$protocol_id,
                        get_grm_for_parental_accessions=>0,
                        download_format=>'three_column_reciprocal'
                        # minor_allele_frequency=>$minor_allele_frequency,
                        # marker_filter=>$marker_filter,
                        # individuals_filter=>$individuals_filter
                    });
                    my $female_grm_data = $female_geno->download_grm(
                        'data',
                        $shared_cluster_dir_config,
                        $c->config->{backend},
                        $c->config->{cluster_host},
                        $c->config->{'web_cluster_queue'},
                        $c->config->{basepath}
                    );
                    my @fl = split '\n', $female_grm_data;
                    my %female_parent_grm;
                    foreach (@fl) {
                        my @l = split '\t', $_;
                        $female_parent_grm{$l[0]}->{$l[1]} = $l[2];
                    }
                    # print STDERR Dumper \%female_parent_grm;

                    my $male_geno = CXGN::Genotype::GRM->new({
                        bcs_schema=>$schema,
                        grm_temp_file=>$grm1_tempfile,
                        people_schema=>$people_schema,
                        cache_root=>$c->config->{cache_file_path},
                        accession_id_list=>$male_stock_ids,
                        protocol_id=>$protocol_id,
                        get_grm_for_parental_accessions=>0,
                        download_format=>'three_column_reciprocal'
                        # minor_allele_frequency=>$minor_allele_frequency,
                        # marker_filter=>$marker_filter,
                        # individuals_filter=>$individuals_filter
                    });
                    my $male_grm_data = $male_geno->download_grm(
                        'data',
                        $shared_cluster_dir_config,
                        $c->config->{backend},
                        $c->config->{cluster_host},
                        $c->config->{'web_cluster_queue'},
                        $c->config->{basepath}
                    );
                    my @ml = split '\n', $male_grm_data;
                    my %male_parent_grm;
                    foreach (@ml) {
                        my @l = split '\t', $_;
                        $male_parent_grm{$l[0]}->{$l[1]} = $l[2];
                    }
                    # print STDERR Dumper \%male_parent_grm;

                    my %rel_result_hash;
                    foreach my $a1 (@accession_ids) {
                        foreach my $a2 (@accession_ids) {
                            my $female_parent1 = $parent_hash->{$a1}->{female_stock_id};
                            my $male_parent1 = $parent_hash->{$a1}->{male_stock_id};
                            my $female_parent2 = $parent_hash->{$a2}->{female_stock_id};
                            my $male_parent2 = $parent_hash->{$a2}->{male_stock_id};

                            my $female_rel = 0;
                            if ($female_parent1 && $female_parent2 && $female_parent_grm{'S'.$female_parent1}->{'S'.$female_parent2}) {
                                $female_rel = $female_parent_grm{'S'.$female_parent1}->{'S'.$female_parent2};
                            }
                            elsif ($a1 == $a2) {
                                $female_rel = 1;
                            }

                            my $male_rel = 0;
                            if ($male_parent1 && $male_parent2 && $male_parent_grm{'S'.$male_parent1}->{'S'.$male_parent2}) {
                                $male_rel = $male_parent_grm{'S'.$male_parent1}->{'S'.$male_parent2};
                            }
                            elsif ($a1 == $a2) {
                                $male_rel = 1;
                            }
                            # print STDERR "$a1 $a2 $female_rel $male_rel\n";

                            my $rel = 0.5*($female_rel + $male_rel);
                            $rel_result_hash{$a1}->{$a2} = $rel;
                        }
                    }
                    # print STDERR Dumper \%rel_result_hash;

                    my $data = '';
                    my %result_hash;
                    foreach my $s (sort @accession_ids) {
                        foreach my $c (sort @accession_ids) {
                            if (!exists($result_hash{$s}->{$c}) && !exists($result_hash{$c}->{$s})) {
                                my $val = $rel_result_hash{$s}->{$c};
                                if (defined $val and length $val) {
                                    $result_hash{$s}->{$c} = $val;
                                    $data .= "S$s\tS$c\t$val\n";
                                }
                            }
                        }
                    }

                    # print STDERR Dumper $data;
                    open(my $F2, ">", $grm_out_temp_tempfile) || die "Can't open file ".$grm_out_temp_tempfile;
                        print $F2 $data;
                    close($F2);

                    my $cmd = 'R -e "library(data.table); library(scales); library(tidyr); library(reshape2);
                    three_col <- fread(\''.$grm_out_temp_tempfile.'\', header=FALSE, sep=\'\t\');
                    A_wide <- dcast(three_col, V1~V2, value.var=\'V3\');
                    A_1 <- A_wide[,-1];
                    A_1[is.na(A_1)] <- 0;
                    A <- A_1 + t(A_1);
                    diag(A) <- diag(as.matrix(A_1));
                    E = eigen(A);
                    ev = E\$values;
                    U = E\$vectors;
                    no = dim(A)[1];
                    nev = which(ev < 0);
                    wr = 0;
                    k=length(nev);
                    if(k > 0){
                        p = ev[no - k];
                        B = sum(ev[nev])*2.0;
                        wr = (B*B*100.0)+1;
                        val = ev[nev];
                        ev[nev] = p*(B-val)*(B-val)/wr;
                        A = U%*%diag(ev)%*%t(U);
                    }
                    A <- as.data.frame(A);
                    colnames(A) <- A_wide[,1];
                    A\$stock_id <- A_wide[,1];
                    A_threecol <- melt(A, id.vars = c(\'stock_id\'), measure.vars = A_wide[,1]);
                    A_threecol\$stock_id <- substring(A_threecol\$stock_id, 2);
                    A_threecol\$variable <- substring(A_threecol\$variable, 2);
                    write.table(data.frame(variable = A_threecol\$variable, stock_id = A_threecol\$stock_id, value = A_threecol\$value), file=\''.$grm_out_tempfile.'\', row.names=FALSE, col.names=FALSE, sep=\'\t\');"';
                    print STDERR $cmd."\n";
                    my $status = system("$cmd > /dev/null");

                    my $csv = Text::CSV->new({ sep_char => "\t" });

                    my %rel_pos_def_result_hash;
                    open(my $F3, '<', $grm_out_tempfile)
                        or die "Could not open file '$grm_out_tempfile' $!";

                        print STDERR "Opened $grm_out_tempfile\n";

                        while (my $row = <$F3>) {
                            my @columns;
                            if ($csv->parse($row)) {
                                @columns = $csv->fields();
                            }
                            my $stock_id1 = $columns[0];
                            my $stock_id2 = $columns[1];
                            my $val = $columns[2];
                            $rel_pos_def_result_hash{$stock_id1}->{$stock_id2} = $val;
                        }
                    close($F3);

                    my $data_pos_def = '';
                    if ($statistics_select eq 'blupf90_grm_random_regression_gdd_blups' || $statistics_select eq 'blupf90_grm_random_regression_dap_blups' || $statistics_select eq 'airemlf90_grm_random_regression_gdd_blups' || $statistics_select eq 'airemlf90_grm_random_regression_dap_blups') {
                        my %result_hash;
                        foreach my $s (sort @accession_ids) {
                            foreach my $c (sort @accession_ids) {
                                if (!exists($result_hash{$s}->{$c}) && !exists($result_hash{$c}->{$s})) {
                                    my $val = $rel_pos_def_result_hash{$s}->{$c};
                                    if (defined $val and length $val) {
                                        $result_hash{$s}->{$c} = $val;
                                        $data_pos_def .= "$s\t$c\t$val\n";
                                    }
                                }
                            }
                        }
                    }
                    else {
                        my %result_hash;
                        foreach my $s (sort @accession_ids) {
                            foreach my $c (sort @accession_ids) {
                                if (!exists($result_hash{$s}->{$c}) && !exists($result_hash{$c}->{$s})) {
                                    my $val = $rel_pos_def_result_hash{$s}->{$c};
                                    if (defined $val and length $val) {
                                        $result_hash{$s}->{$c} = $val;
                                        $result_hash{$c}->{$s} = $val;
                                        $data_pos_def .= "S$s\tS$c\t$val\n";
                                        if ($s != $c) {
                                            $data_pos_def .= "S$c\tS$s\t$val\n";
                                        }
                                    }
                                }
                            }
                        }
                    }

                    open(my $F4, ">", $grm_out_posdef_tempfile) || die "Can't open file ".$grm_out_posdef_tempfile;
                        print $F4 $data_pos_def;
                    close($F4);

                    $grm_file = $grm_out_posdef_tempfile;
                }
                else {
                    my $shared_cluster_dir_config = $c->config->{cluster_shared_tempdir};
                    my $tmp_grm_dir = $shared_cluster_dir_config."/tmp_genotype_download_grm";
                    mkdir $tmp_grm_dir if ! -d $tmp_grm_dir;
                    my ($grm_tempfile_fh, $grm_tempfile) = tempfile("drone_stats_download_grm_XXXXX", DIR=> $tmp_grm_dir);
                    my ($grm_out_tempfile_fh, $grm_out_tempfile) = tempfile("drone_stats_download_grm_XXXXX", DIR=> $tmp_grm_dir);

                    if (!$protocol_id) {
                        $protocol_id = undef;
                    }

                    my $grm_search_params = {
                        bcs_schema=>$schema,
                        grm_temp_file=>$grm_tempfile,
                        people_schema=>$people_schema,
                        cache_root=>$c->config->{cache_file_path},
                        accession_id_list=>\@accession_ids,
                        protocol_id=>$protocol_id,
                        get_grm_for_parental_accessions=>$compute_from_parents,
                        # minor_allele_frequency=>$minor_allele_frequency,
                        # marker_filter=>$marker_filter,
                        # individuals_filter=>$individuals_filter
                    };

                    if ($statistics_select eq 'blupf90_grm_random_regression_gdd_blups' || $statistics_select eq 'blupf90_grm_random_regression_dap_blups' || $statistics_select eq 'airemlf90_grm_random_regression_gdd_blups' || $statistics_select eq 'airemlf90_grm_random_regression_dap_blups') {
                        $grm_search_params->{download_format} = 'three_column_stock_id_integer';
                    }
                    else {
                        $grm_search_params->{download_format} = 'three_column_reciprocal';
                    }

                    my $geno = CXGN::Genotype::GRM->new($grm_search_params);
                    my $grm_data = $geno->download_grm(
                        'data',
                        $shared_cluster_dir_config,
                        $c->config->{backend},
                        $c->config->{cluster_host},
                        $c->config->{'web_cluster_queue'},
                        $c->config->{basepath}
                    );

                    open(my $F2, ">", $grm_out_tempfile) || die "Can't open file ".$grm_out_tempfile;
                        print $F2 $grm_data;
                    close($F2);
                    $grm_file = $grm_out_tempfile;
                }

            }
            elsif ($compute_relationship_matrix_from_htp_phenotypes eq 'htp_phenotypes') {

                my $phenotypes_search = CXGN::Phenotypes::SearchFactory->instantiate(
                    'MaterializedViewTable',
                    {
                        bcs_schema=>$schema,
                        data_level=>'plot',
                        trial_list=>$field_trial_id_list,
                        include_timestamp=>0,
                        exclude_phenotype_outlier=>0
                    }
                );
                my ($data, $unique_traits) = $phenotypes_search->search();

                if (scalar(@$data) == 0) {
                    $c->stash->{rest} = { error => "There are no phenotypes for the trial you have selected!"};
                    return;
                }

                my $q_time = "SELECT t.cvterm_id FROM cvterm as t JOIN cv ON(t.cv_id=cv.cv_id) WHERE t.name=? and cv.name=?;";
                my $h_time = $schema->storage->dbh()->prepare($q_time);

                my %seen_plot_names_htp_rel;
                my %phenotype_data_htp_rel;
                my %seen_times_htp_rel;
                foreach my $obs_unit (@$data){
                    my $germplasm_name = $obs_unit->{germplasm_uniquename};
                    my $germplasm_stock_id = $obs_unit->{germplasm_stock_id};
                    my $row_number = $obs_unit->{obsunit_row_number} || '';
                    my $col_number = $obs_unit->{obsunit_col_number} || '';
                    my $rep = $obs_unit->{obsunit_rep};
                    my $block = $obs_unit->{obsunit_block};
                    $seen_plot_names_htp_rel{$obs_unit->{observationunit_uniquename}} = $obs_unit;
                    my $observations = $obs_unit->{observations};
                    foreach (@$observations){
                        if ($_->{associated_image_project_time_json}) {
                            my $related_time_terms_json = decode_json $_->{associated_image_project_time_json};

                            my $time_days_cvterm = $related_time_terms_json->{day};
                            my $time_days_term_string = $time_days_cvterm;
                            my $time_days = (split '\|', $time_days_cvterm)[0];
                            my $time_days_value = (split ' ', $time_days)[1];

                            my $time_gdd_value = $related_time_terms_json->{gdd_average_temp} + 0;
                            my $gdd_term_string = "GDD $time_gdd_value";
                            $h_time->execute($gdd_term_string, 'cxgn_time_ontology');
                            my ($gdd_cvterm_id) = $h_time->fetchrow_array();
                            if (!$gdd_cvterm_id) {
                                my $new_gdd_term = $schema->resultset("Cv::Cvterm")->create_with({
                                   name => $gdd_term_string,
                                   cv => 'cxgn_time_ontology'
                                });
                                $gdd_cvterm_id = $new_gdd_term->cvterm_id();
                            }
                            my $time_gdd_term_string = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $gdd_cvterm_id, 'extended');

                            $phenotype_data_htp_rel{$obs_unit->{observationunit_uniquename}}->{$_->{trait_name}} = $_->{value};
                            $seen_times_htp_rel{$_->{trait_name}} = [$time_days_value, $time_days_term_string, $time_gdd_value, $time_gdd_term_string];
                        }
                    }
                }

                my @allowed_standard_htp_values = ('Nonzero Pixel Count', 'Total Pixel Sum', 'Mean Pixel Value', 'Harmonic Mean Pixel Value', 'Median Pixel Value', 'Pixel Variance', 'Pixel Standard Deviation', 'Pixel Population Standard Deviation', 'Minimum Pixel Value', 'Maximum Pixel Value', 'Minority Pixel Value', 'Minority Pixel Count', 'Majority Pixel Value', 'Majority Pixel Count', 'Pixel Group Count');
                my %filtered_seen_times_htp_rel;
                while (my ($t, $time) = each %seen_times_htp_rel) {
                    my $allowed = 0;
                    foreach (@allowed_standard_htp_values) {
                        if (index($t, $_) != -1) {
                            $allowed = 1;
                            last;
                        }
                    }
                    if ($allowed) {
                        $filtered_seen_times_htp_rel{$t} = $time;
                    }
                }

                my @seen_plot_names_htp_rel_sorted = sort keys %seen_plot_names_htp_rel;
                my @filtered_seen_times_htp_rel_sorted = sort keys %filtered_seen_times_htp_rel;

                my @header_htp = ('plot_id', 'plot_name', 'accession_id', 'accession_name', 'rep', 'block');

                my %trait_name_encoder_htp;
                my %trait_name_encoder_rev_htp;
                my $trait_name_encoded_htp = 1;
                my @header_traits_htp;
                foreach my $trait_name (@filtered_seen_times_htp_rel_sorted) {
                    if (!exists($trait_name_encoder_htp{$trait_name})) {
                        my $trait_name_e = 't'.$trait_name_encoded_htp;
                        $trait_name_encoder_htp{$trait_name} = $trait_name_e;
                        $trait_name_encoder_rev_htp{$trait_name_e} = $trait_name;
                        push @header_traits_htp, $trait_name_e;
                        $trait_name_encoded_htp++;
                    }
                }

                my @htp_pheno_matrix;
                if ($compute_relationship_matrix_from_htp_phenotypes_time_points eq 'all') {
                    push @header_htp, @header_traits_htp;
                    push @htp_pheno_matrix, \@header_htp;

                    foreach my $p (@seen_plot_names_htp_rel_sorted) {
                        my $obj = $seen_plot_names_htp_rel{$p};
                        my @row = ($obj->{observationunit_stock_id}, $obj->{observationunit_uniquename}, $obj->{germplasm_stock_id}, $obj->{germplasm_uniquename}, $obj->{obsunit_rep}, $obj->{obsunit_block});
                        foreach my $t (@filtered_seen_times_htp_rel_sorted) {
                            my $val = $phenotype_data_htp_rel{$p}->{$t} + 0;
                            push @row, $val;
                        }
                        push @htp_pheno_matrix, \@row;
                    }
                }
                elsif ($compute_relationship_matrix_from_htp_phenotypes_time_points eq 'latest_trait') {
                    my $max_day = 0;
                    foreach (keys %seen_days_after_plantings) {
                        if ($_ + 0 > $max_day) {
                            $max_day = $_;
                        }
                    }

                    foreach my $t (@filtered_seen_times_htp_rel_sorted) {
                        my $day = $filtered_seen_times_htp_rel{$t}->[0];
                        if ($day <= $max_day) {
                            push @header_htp, $t;
                        }
                    }
                    push @htp_pheno_matrix, \@header_htp;

                    foreach my $p (@seen_plot_names_htp_rel_sorted) {
                        my $obj = $seen_plot_names_htp_rel{$p};
                        my @row = ($obj->{observationunit_stock_id}, $obj->{observationunit_uniquename}, $obj->{germplasm_stock_id}, $obj->{germplasm_uniquename}, $obj->{obsunit_rep}, $obj->{obsunit_block});
                        foreach my $t (@filtered_seen_times_htp_rel_sorted) {
                            my $day = $filtered_seen_times_htp_rel{$t}->[0];
                            if ($day <= $max_day) {
                                my $val = $phenotype_data_htp_rel{$p}->{$t} + 0;
                                push @row, $val;
                            }
                        }
                        push @htp_pheno_matrix, \@row;
                    }
                }
                elsif ($compute_relationship_matrix_from_htp_phenotypes_time_points eq 'vegetative') {

                }
                elsif ($compute_relationship_matrix_from_htp_phenotypes_time_points eq 'reproductive') {

                }
                elsif ($compute_relationship_matrix_from_htp_phenotypes_time_points eq 'mature') {

                }
                else {
                    $c->stash->{rest} = { error => "The value of $compute_relationship_matrix_from_htp_phenotypes_time_points htp_pheno_rel_matrix_time_points is not valid!" };
                    return;
                }

                open(my $htp_pheno_f, ">", $stats_out_htp_rel_tempfile_input) || die "Can't open file ".$stats_out_htp_rel_tempfile_input;
                    foreach (@htp_pheno_matrix) {
                        my $line = join "\t", @$_;
                        print $htp_pheno_f $line."\n";
                    }
                close($htp_pheno_f);

                my %rel_htp_result_hash;
                if ($compute_relationship_matrix_from_htp_phenotypes_type eq 'correlations') {
                    my $htp_cmd = 'R -e "library(lme4); library(data.table);
                    mat <- fread(\''.$stats_out_htp_rel_tempfile_input.'\', header=TRUE, sep=\'\t\');
                    mat_agg <- aggregate(mat[, 7:ncol(mat)], list(mat\$accession_id), mean);
                    mat_pheno <- mat_agg[,2:ncol(mat_agg)];
                    cor_mat <- cor(t(mat_pheno));
                    rownames(cor_mat) <- mat_agg[,1];
                    colnames(cor_mat) <- mat_agg[,1];
                    range01 <- function(x){(x-min(x))/(max(x)-min(x))};
                    cor_mat <- range01(cor_mat);
                    write.table(cor_mat, file=\''.$stats_out_htp_rel_tempfile.'\', row.names=TRUE, col.names=TRUE, sep=\'\t\');"';
                    print STDERR Dumper $htp_cmd;
                    my $status = system("$htp_cmd > /dev/null");
                }
                elsif ($compute_relationship_matrix_from_htp_phenotypes_type eq 'blues') {
                    my $htp_cmd = 'R -e "library(lme4); library(data.table);
                    mat <- fread(\''.$stats_out_htp_rel_tempfile_input.'\', header=TRUE, sep=\'\t\');
                    blues <- data.frame(id = seq(1,length(unique(mat\$accession_id))));
                    varlist <- names(mat)[7:ncol(mat)];
                    blues.models <- lapply(varlist, function(x) {
                        tryCatch(
                            lmer(substitute(i ~ 1 + (1|accession_id), list(i = as.name(x))), data = mat, REML = FALSE, control = lmerControl(optimizer =\'Nelder_Mead\', boundary.tol='.$compute_relationship_matrix_from_htp_phenotypes_blues_inversion.' ) ), error=function(e) {}
                        )
                    });
                    counter = 1;
                    for (m in blues.models) {
                        if (!is.null(m)) {
                            blues\$accession_id <- row.names(ranef(m)\$accession_id);
                            blues[,ncol(blues) + 1] <- ranef(m)\$accession_id\$\`(Intercept)\`;
                            colnames(blues)[ncol(blues)] <- varlist[counter];
                        }
                        counter = counter + 1;
                    }
                    blues_vals <- as.matrix(blues[,3:ncol(blues)]);
                    blues_vals <- apply(blues_vals, 2, function(y) (y - mean(y)) / sd(y) ^ as.logical(sd(y)));
                    rel <- (1/ncol(blues_vals)) * (blues_vals %*% t(blues_vals));
                    rownames(rel) <- blues[,2];
                    colnames(rel) <- blues[,2];
                    write.table(rel, file=\''.$stats_out_htp_rel_tempfile.'\', row.names=TRUE, col.names=TRUE, sep=\'\t\');"';
                    print STDERR Dumper $htp_cmd;
                    my $status = system("$htp_cmd > /dev/null");
                }
                else {
                    $c->stash->{rest} = { error => "The value of $compute_relationship_matrix_from_htp_phenotypes_type htp_pheno_rel_matrix_type is not valid!" };
                    return;
                }

                my $csv = Text::CSV->new({ sep_char => "\t" });

                open(my $htp_rel_res, '<', $stats_out_htp_rel_tempfile)
                    or die "Could not open file '$stats_out_htp_rel_tempfile' $!";

                    print STDERR "Opened $stats_out_htp_rel_tempfile\n";
                    my $header_row = <$htp_rel_res>;
                    my @header;
                    if ($csv->parse($header_row)) {
                        @header = $csv->fields();
                    }

                    while (my $row = <$htp_rel_res>) {
                        my @columns;
                        if ($csv->parse($row)) {
                            @columns = $csv->fields();
                        }
                        my $stock_id1 = $columns[0];
                        my $counter = 1;
                        foreach my $stock_id2 (@header) {
                            my $val = $columns[$counter];
                            $rel_htp_result_hash{$stock_id1}->{$stock_id2} = $val;
                            $counter++;
                        }
                    }
                close($htp_rel_res);

                my $data_rel_htp = '';
                my %result_hash;
                if ($statistics_select eq 'blupf90_grm_random_regression_gdd_blups' || $statistics_select eq 'blupf90_grm_random_regression_dap_blups' || $statistics_select eq 'airemlf90_grm_random_regression_gdd_blups' || $statistics_select eq 'airemlf90_grm_random_regression_dap_blups') {
                    foreach my $s (sort @accession_ids) {
                        foreach my $c (sort @accession_ids) {
                            if (!exists($result_hash{$s}->{$c}) && !exists($result_hash{$c}->{$s})) {
                                my $val = $rel_htp_result_hash{$s}->{$c};
                                if (defined $val and length $val) {
                                    $result_hash{$s}->{$c} = $val;
                                    $data_rel_htp .= "$s\t$c\t$val\n";
                                }
                            }
                        }
                    }
                }
                else {
                    foreach my $s (sort @accession_ids) {
                        foreach my $c (sort @accession_ids) {
                            if (!exists($result_hash{$s}->{$c}) && !exists($result_hash{$c}->{$s})) {
                                my $val = $rel_htp_result_hash{$s}->{$c};
                                if (defined $val and length $val) {
                                    $result_hash{$s}->{$c} = $val;
                                    $result_hash{$c}->{$s} = $val;
                                    $data_rel_htp .= "S$s\tS$c\t$val\n";
                                    if ($s != $c) {
                                        $data_rel_htp .= "S$c\tS$s\t$val\n";
                                    }
                                }
                            }
                        }
                    }
                }

                open(my $htp_rel_out, ">", $stats_out_htp_rel_tempfile_out) || die "Can't open file ".$stats_out_htp_rel_tempfile_out;
                    print $htp_rel_out $data_rel_htp;
                close($htp_rel_out);

                $grm_file = $stats_out_htp_rel_tempfile_out;
            }
            else {
                $c->stash->{rest} = { error => "The value of $compute_relationship_matrix_from_htp_phenotypes is not valid!" };
                return;
            }
        }

        my $time = DateTime->now();
        my $timestamp = $time->ymd()."_".$time->hms();

        if ($statistics_select eq 'lmer_germplasmname_replicate') {
            $statistical_ontology_term = "Univariate linear mixed model genetic BLUPs using germplasmName computed using LMER R|SGNSTAT:0000002";
            $analysis_result_values_type = "analysis_result_values_match_accession_names";
            $analysis_model_training_data_file_type = "nicksmixedmodels_v1.01_lmer_germplasmname_replicate_phenotype_file";

            foreach my $t (@sorted_trait_names) {
                my $cmd = 'R -e "library(lme4); library(data.table);
                mat <- fread(\''.$stats_tempfile.'\', header=TRUE, sep=\',\');
                mix <- lmer('.$trait_name_encoder{$t}.' ~ replicate + (1|id), data = mat, na.action = na.omit );
                #mix.summary <- summary(mix);
                #ve <- mix.summary\$varcor\$id[1,1]/(mix.summary\$varcor\$id[1,1] + (mix.summary\$sigma)^2);
                write.table(ranef(mix)\$id, file=\''.$stats_out_tempfile.'\', row.names=TRUE, col.names=TRUE, sep=\'\t\');"';
                my $status = system("$cmd > /dev/null");

                my $csv = Text::CSV->new({ sep_char => "\t" });

                open(my $fh, '<', $stats_out_tempfile)
                    or die "Could not open file '$stats_out_tempfile' $!";

                    print STDERR "Opened $stats_out_tempfile\n";
                    my $header = <$fh>;
                    my @header_cols;
                    if ($csv->parse($header)) {
                        @header_cols = $csv->fields();
                    }

                    while (my $row = <$fh>) {
                        my @columns;
                        if ($csv->parse($row)) {
                            @columns = $csv->fields();
                        }
                        my $stock_id = $columns[0];
                        my $stock_name = $stock_info{$stock_id}->{uniquename};
                        my $value = $columns[1];
                        $result_blup_data->{$stock_name}->{$t} = [$value, $timestamp, $user_name, '', ''];
                    }
                close($fh);
            }
        }
        elsif ($statistics_select eq 'sommer_grm_genetic_blups') {
            $statistical_ontology_term = "Multivariate genetic BLUPs using genetic relationship matrix computed using Sommer R|SGNSTAT:0000024";

            $analysis_result_values_type = "analysis_result_values_match_accession_names";
            $analysis_model_training_data_file_type = "nicksmixedmodels_v1.01_sommer_grm_genetic_blups_phenotype_file";

            @unique_plot_names = sort keys %seen_plot_names;

            my @encoded_traits = values %trait_name_encoder;
            my $encoded_trait_string = join ',', @encoded_traits;
            my $number_traits = scalar(@encoded_traits);
            my $cbind_string = $number_traits > 1 ? "cbind($encoded_trait_string)" : $encoded_trait_string;

            my $cmd = 'R -e "library(sommer); library(data.table); library(reshape2);
            mat <- data.frame(fread(\''.$stats_tempfile.'\', header=TRUE, sep=\',\'));
            geno_mat_3col <- data.frame(fread(\''.$grm_file.'\', header=FALSE, sep=\'\t\'));
            geno_mat <- acast(geno_mat_3col, V1~V2, value.var=\'V3\');
            geno_mat[is.na(geno_mat)] <- 0;
            mix <- mmer('.$cbind_string.'~1 + replicate, random=~vs(id, Gu=geno_mat, Gtc=unsm('.$number_traits.')), rcov=~vs(units, Gtc=unsm('.$number_traits.')), data=mat, tolparinv='.$tolparinv.');
            write.table(mix\$U\$\`u:id\`, file=\''.$stats_out_tempfile.'\', row.names=TRUE, col.names=TRUE, sep=\'\t\');
            "';
            print STDERR Dumper $cmd;
            my $status = system("$cmd > /dev/null");

            my $csv = Text::CSV->new({ sep_char => "\t" });

            my %unique_accessions_seen;
            open(my $fh, '<', $stats_out_tempfile)
                or die "Could not open file '$stats_out_tempfile' $!";

                print STDERR "Opened $stats_out_tempfile\n";
                my $header = <$fh>;
                my @header_cols;
                if ($csv->parse($header)) {
                    @header_cols = $csv->fields();
                }

                while (my $row = <$fh>) {
                    my @columns;
                    if ($csv->parse($row)) {
                        @columns = $csv->fields();
                    }
                    my $col_counter = 0;
                    foreach my $encoded_trait (@header_cols) {
                        my $trait = $trait_name_encoder_rev{$encoded_trait};
                        my $stock_id = $columns[0];

                        my $stock_name = $stock_info{$stock_id}->{uniquename};
                        my $value = $columns[$col_counter+1];
                        $result_blup_data->{$stock_name}->{$trait} = [$value, $timestamp, $user_name, '', ''];
                        $col_counter++;
                        $unique_accessions_seen{$stock_name}++;
                    }
                }
            close($fh);
            @unique_accession_names = keys %unique_accessions_seen;
        }
        elsif ($statistics_select eq 'sommer_grm_spatial_genetic_blups') {
            $statistical_ontology_term = "Multivariate linear mixed model genetic BLUPs using genetic relationship matrix and row and column spatial effects computed using Sommer R|SGNSTAT:0000001"; #In the JS this is set to either the genetic or spatial BLUP term (Multivariate linear mixed model 2D spline spatial BLUPs using genetic relationship matrix and row and column spatial effects computed using Sommer R|SGNSTAT:0000003) when saving analysis results

            $analysis_result_values_type = "analysis_result_values_match_accession_names";
            $analysis_model_training_data_file_type = "nicksmixedmodels_v1.01_sommer_grm_spatial_genetic_blups_phenotype_file";

            @unique_plot_names = sort keys %seen_plot_names;

            my @encoded_traits = values %trait_name_encoder;
            my $encoded_trait_string = join ',', @encoded_traits;
            my $number_traits = scalar(@encoded_traits);
            my $cbind_string = $number_traits > 1 ? "cbind($encoded_trait_string)" : $encoded_trait_string;

            my $cmd = 'R -e "library(sommer); library(data.table); library(reshape2);
            mat <- data.frame(fread(\''.$stats_tempfile.'\', header=TRUE, sep=\',\'));
            geno_mat_3col <- data.frame(fread(\''.$grm_file.'\', header=FALSE, sep=\'\t\'));
            geno_mat <- acast(geno_mat_3col, V1~V2, value.var=\'V3\');
            geno_mat[is.na(geno_mat)] <- 0;
            mat\$rowNumber <- as.numeric(mat\$rowNumber);
            mat\$colNumber <- as.numeric(mat\$colNumber);
            mat\$rowNumberFactor <- as.factor(mat\$rowNumberFactor);
            mat\$colNumberFactor <- as.factor(mat\$colNumberFactor);
            mix <- mmer('.$cbind_string.'~1 + replicate, random=~vs(id, Gu=geno_mat, Gtc=unsm('.$number_traits.')) +vs(rowNumberFactor, Gtc=diag('.$number_traits.')) +vs(colNumberFactor, Gtc=diag('.$number_traits.')) +vs(spl2D(rowNumber, colNumber), Gtc=diag('.$number_traits.')), rcov=~vs(units, Gtc=unsm('.$number_traits.')), data=mat, tolparinv='.$tolparinv.');
            #gen_cor <- cov2cor(mix\$sigma\$\`u:id\`);
            write.table(mix\$U\$\`u:id\`, file=\''.$stats_out_tempfile.'\', row.names=TRUE, col.names=TRUE, sep=\'\t\');
            write.table(mix\$U\$\`u:rowNumberFactor\`, file=\''.$stats_out_tempfile_row.'\', row.names=TRUE, col.names=TRUE, sep=\'\t\');
            write.table(mix\$U\$\`u:colNumberFactor\`, file=\''.$stats_out_tempfile_col.'\', row.names=TRUE, col.names=TRUE, sep=\'\t\');
            X <- with(mat, spl2D(rowNumber, colNumber));
            spatial_blup_results <- data.frame(plot_id = mat\$plot_id);
            ';
            my $trait_index = 1;
            foreach my $enc_trait_name (@encoded_traits) {
                $cmd .= '
            blups'.$trait_index.' <- mix\$U\$\`u:rowNumber\`\$'.$enc_trait_name.';
            spatial_blup_results\$'.$enc_trait_name.' <- data.matrix(X) %*% data.matrix(blups'.$trait_index.');
                ';
                $trait_index++;
            }
            $cmd .= 'write.table(spatial_blup_results, file=\''.$stats_out_tempfile_2dspl.'\', row.names=FALSE, col.names=TRUE, sep=\'\t\');
            "';
            print STDERR Dumper $cmd;
            my $status = system("$cmd > /dev/null");

            my $csv = Text::CSV->new({ sep_char => "\t" });

            my %unique_accessions_seen;
            open(my $fh, '<', $stats_out_tempfile)
                or die "Could not open file '$stats_out_tempfile' $!";

                print STDERR "Opened $stats_out_tempfile\n";
                my $header = <$fh>;
                my @header_cols;
                if ($csv->parse($header)) {
                    @header_cols = $csv->fields();
                }

                while (my $row = <$fh>) {
                    my @columns;
                    if ($csv->parse($row)) {
                        @columns = $csv->fields();
                    }
                    my $col_counter = 0;
                    foreach my $encoded_trait (@header_cols) {
                        my $trait = $trait_name_encoder_rev{$encoded_trait};
                        my $stock_id = $columns[0];

                        my $stock_name = $stock_info{$stock_id}->{uniquename};
                        my $value = $columns[$col_counter+1];
                        $result_blup_data->{$stock_name}->{$trait} = [$value, $timestamp, $user_name, '', ''];
                        $col_counter++;
                        $unique_accessions_seen{$stock_name}++;
                    }
                }
            close($fh);
            @unique_accession_names = keys %unique_accessions_seen;

            my %result_blup_row_data;
            my @row_numbers;
            open(my $fh_row, '<', $stats_out_tempfile_row)
                or die "Could not open file '$stats_out_tempfile_row' $!";

                print STDERR "Opened $stats_out_tempfile_row\n";
                my $header_row = <$fh_row>;
                my @header_cols_row;
                if ($csv->parse($header_row)) {
                    @header_cols_row = $csv->fields();
                }

                while (my $row_row = <$fh_row>) {
                    my @columns_row;
                    if ($csv->parse($row_row)) {
                        @columns_row = $csv->fields();
                    }
                    my $col_counter_row = 0;
                    foreach my $encoded_trait (@header_cols_row) {
                        my $trait = $trait_name_encoder_rev{$encoded_trait};
                        my $row_id = $columns_row[0];
                        push @row_numbers, $row_id;
                        my $value = $columns_row[$col_counter_row+1];
                        $result_blup_row_data{$row_id}->{$trait} = $value;
                        $col_counter_row++;
                    }
                }
            close($fh_row);

            my %result_blup_col_data;
            my @col_numbers;
            open(my $fh_col, '<', $stats_out_tempfile_col)
                or die "Could not open file '$stats_out_tempfile_col' $!";

                print STDERR "Opened $stats_out_tempfile_col\n";
                my $header_col = <$fh_col>;
                my @header_cols_col;
                if ($csv->parse($header_col)) {
                    @header_cols_col = $csv->fields();
                }

                while (my $row_col = <$fh_col>) {
                    my @columns_col;
                    if ($csv->parse($row_col)) {
                        @columns_col = $csv->fields();
                    }
                    my $col_counter_col = 0;
                    foreach my $encoded_trait (@header_cols_col) {
                        my $trait = $trait_name_encoder_rev{$encoded_trait};
                        my $col_id = $columns_col[0];
                        push @col_numbers, $col_id;
                        my $value = $columns_col[$col_counter_col+1];
                        $result_blup_col_data{$col_id}->{$trait} = $value;
                        $col_counter_col++;
                    }
                }
            close($fh_col);

            open(my $fh_2dspl, '<', $stats_out_tempfile_2dspl)
                or die "Could not open file '$stats_out_tempfile_2dspl' $!";

                print STDERR "Opened $stats_out_tempfile_2dspl\n";
                my $header_2dspl = <$fh_2dspl>;
                my @header_cols_2dspl;
                if ($csv->parse($header_2dspl)) {
                    @header_cols_2dspl = $csv->fields();
                }
                shift @header_cols_2dspl;
                while (my $row_2dspl = <$fh_2dspl>) {
                    my @columns;
                    if ($csv->parse($row_2dspl)) {
                        @columns = $csv->fields();
                    }
                    my $col_counter = 0;
                    foreach my $encoded_trait (@header_cols_2dspl) {
                        my $trait = $trait_name_encoder_rev{$encoded_trait};
                        my $plot_id = $columns[0];

                        my $plot_name = $plot_id_map{$plot_id};
                        my $value = $columns[$col_counter+1];
                        $result_blup_spatial_data->{$plot_name}->{$trait} = [$value, $timestamp, $user_name, '', ''];
                        $col_counter++;
                    }
                }
            close($fh_2dspl);

            # foreach my $trait (@sorted_trait_names) {
            #     foreach my $row (@row_numbers) {
            #         foreach my $col (@col_numbers) {
            #             my $uniquename = $obsunit_row_col{$row}->{$col}->{stock_uniquename};
            #             my $stock_id = $obsunit_row_col{$row}->{$col}->{stock_id};
            #
            #             my $row_val = $result_blup_row_data{$row}->{$trait};
            #             my $col_val = $result_blup_col_data{$col}->{$trait};
            #             $result_blup_spatial_data->{$uniquename}->{$trait} = [$row_val*$col_val, $timestamp, $user_name, '', ''];
            #         }
            #     }
            # }
        }
        elsif ($statistics_select eq 'sommer_grm_temporal_random_regression_dap_genetic_blups' || $statistics_select eq 'sommer_grm_temporal_random_regression_gdd_genetic_blups') {
            $statistical_ontology_term = "Multivariate linear mixed model genetic BLUPs using genetic relationship matrix and temporal Legendre polynomial random regression on days after planting computed using Sommer R|SGNSTAT:0000004"; #In the JS this is set to either the genetic of permanent environment BLUP term (Multivariate linear mixed model permanent environment BLUPs using genetic relationship matrix and temporal Legendre polynomial random regression on days after planting computed using Sommer R|SGNSTAT:0000005) when saving results

            $analysis_result_values_type = "analysis_result_values_match_accession_names";

            if ($statistics_select eq 'sommer_grm_temporal_random_regression_dap_genetic_blups') {
                $analysis_model_training_data_file_type = "nicksmixedmodels_v1.01_sommer_grm_temporal_leg_random_regression_DAP_genetic_blups_phenotype_file";
            }
            elsif ($statistics_select eq 'sommer_grm_temporal_random_regression_gdd_genetic_blups') {
                $analysis_model_training_data_file_type = "nicksmixedmodels_v1.01_sommer_grm_temporal_leg_random_regression_GDD_genetic_blups_phenotype_file";
            }

            my $cmd = 'R -e "library(sommer); library(data.table); library(reshape2); library(orthopolynom);
            mat <- fread(\''.$stats_tempfile.'\', header=TRUE, sep=\',\', check.names = FALSE);
            geno_mat_3col <- data.frame(fread(\''.$grm_file.'\', header=FALSE, sep=\'\t\'));
            geno_mat <- acast(geno_mat_3col, V1~V2, value.var=\'V3\');
            geno_mat[is.na(geno_mat)] <- 0;
            mat_long <- melt(mat, id.vars=c(\'replicate\', \'block\', \'id\', \'plot_id\', \'rowNumber\', \'colNumber\', \'rowNumberFactor\', \'colNumberFactor\'), variable.name=\'time\', value.name=\'value\');
            mat_long\$time <- as.numeric(as.character(mat_long\$time));
            mat_long <- mat_long[order(time),];
            mat\$rowNumber <- as.numeric(mat\$rowNumber);
            mat\$colNumber <- as.numeric(mat\$colNumber);
            mat\$rowNumberFactor <- as.factor(mat\$rowNumberFactor);
            mat\$colNumberFactor <- as.factor(mat\$colNumberFactor);
            mix <- mmer(
                value~1 + replicate,
                random=~vs(id, Gu=geno_mat) +vs(leg(time,'.$legendre_order_number.', intercept=TRUE), id) +vs(leg(time,'.$legendre_order_number.', intercept=TRUE), plot_id),
                rcov=~vs(units),
                data=mat_long, tolparinv='.$tolparinv.'
            );
            write.table(data.frame(plot_id = mix\$data\$plot_id, time = mix\$data\$time, residuals = mix\$residuals, fitted = mix\$fitted), file=\''.$stats_out_tempfile_residual.'\', row.names=FALSE, col.names=TRUE, sep=\'\t\');
            write.table(mix\$U\$\`u:id\`, file=\''.$stats_out_tempfile.'\', row.names=TRUE, col.names=TRUE, sep=\'\t\');
            genetic_coeff <- data.frame(id = names(mix\$U\$\`leg0:id\`\$value));
            pe_coeff <- data.frame(plot_id = names(mix\$U\$\`leg0:plot_id\`\$value));';
            for my $leg_num (0..$legendre_order_number) {
                $cmd .= 'genetic_coeff\$leg_'.$leg_num.' <- mix\$U\$\`leg'.$leg_num.':id\`\$value;';
            }
            for my $leg_num (0..$legendre_order_number) {
                $cmd .= 'pe_coeff\$leg_'.$leg_num.' <- mix\$U\$\`leg'.$leg_num.':plot_id\`\$value;';
            }
            $cmd .= 'write.table(genetic_coeff, file=\''.$stats_out_tempfile_genetic.'\', row.names=FALSE, col.names=TRUE, sep=\'\t\');
                write.table(pe_coeff, file=\''.$stats_out_tempfile_permanent_environment.'\', row.names=FALSE, col.names=TRUE, sep=\'\t\');"
            ';
            print STDERR Dumper $cmd;
            my $status = system("$cmd > /dev/null");

            my $csv = Text::CSV->new({ sep_char => "\t" });

            no warnings 'uninitialized';

            my %unique_accessions_seen;
            my %unique_plots_seen;
            my @new_sorted_trait_names;
            my %sommer_rr_genetic_coeff;
            my %sommer_rr_temporal_coeff;
            open(my $fh_genetic, '<', $stats_out_tempfile_genetic)
                or die "Could not open file '$stats_out_tempfile_genetic' $!";

                print STDERR "Opened $stats_out_tempfile_genetic\n";
                my $header = <$fh_genetic>;
                my @header_cols;
                if ($csv->parse($header)) {
                    @header_cols = $csv->fields();
                }

                while (my $row = <$fh_genetic>) {
                    my @columns;
                    if ($csv->parse($row)) {
                        @columns = $csv->fields();
                    }

                    my $accession_id = $columns[0];
                    my $accession_name = $stock_info{$accession_id}->{uniquename};
                    $unique_accessions_seen{$accession_name}++;

                    my $col_counter = 1;
                    foreach (0..$legendre_order_number) {
                        my $value = $columns[$col_counter];
                        push @{$sommer_rr_genetic_coeff{$accession_name}}, $value;
                        $col_counter++;
                    }
                }
            close($fh_genetic);

            open(my $fh, '<', $stats_out_tempfile_permanent_environment)
                or die "Could not open file '$stats_out_tempfile_permanent_environment' $!";

                print STDERR "Opened $stats_out_tempfile_permanent_environment\n";
                $header = <$fh>;
                if ($csv->parse($header)) {
                    @header_cols = $csv->fields();
                }

                my $row_counter = 0;
                while (my $row = <$fh>) {
                    my @columns;
                    if ($csv->parse($row)) {
                        @columns = $csv->fields();
                    }

                    my $plot_id = $columns[0];
                    my $plot_name = $plot_id_map{$plot_id};
                    $unique_plots_seen{$plot_name}++;

                    my $col_counter = 1;
                    foreach (0..$legendre_order_number) {
                        my $value = $columns[$col_counter];
                        push @{$sommer_rr_temporal_coeff{$plot_name}}, $value;
                        $col_counter++;
                    }
                    $row_counter++;
                }
            close($fh);

            # print STDERR Dumper \%sommer_rr_genetic_coeff;
            # print STDERR Dumper \%sommer_rr_temporal_coeff;

            open(my $fh_residual, '<', $stats_out_tempfile_residual)
                or die "Could not open file '$stats_out_tempfile_residual' $!";

                print STDERR "Opened $stats_out_tempfile_residual\n";
                my $header_residual = <$fh_residual>;
                my @header_cols_residual;
                if ($csv->parse($header_residual)) {
                    @header_cols_residual = $csv->fields();
                }

                while (my $row = <$fh_residual>) {
                    my @columns;
                    if ($csv->parse($row)) {
                        @columns = $csv->fields();
                    }

                    my $stock_id = $columns[0];
                    my $time = $columns[1];
                    my $residual = $columns[2];
                    my $fitted = $columns[3];
                    my $stock_name = $plot_id_map{$stock_id};
                    $result_residual_data->{$stock_name}->{$seen_times{$time}} = [$residual, $timestamp, $user_name, '', ''];
                    $result_fitted_data->{$stock_name}->{$seen_times{$time}} = [$fitted, $timestamp, $user_name, '', ''];
                }
            close($fh_residual);

            $time_min = 100000000;
            $time_max = 0;
            foreach (@sorted_trait_names) {
                if ($_ < $time_min) {
                    $time_min = $_;
                }
                if ($_ > $time_max) {
                    $time_max = $_;
                }
            }
            print STDERR Dumper [$time_min, $time_max];

            my $q_time = "SELECT t.cvterm_id FROM cvterm as t JOIN cv ON(t.cv_id=cv.cv_id) WHERE t.name=? and cv.name=?;";
            my $h_time = $schema->storage->dbh()->prepare($q_time);

            my %rr_unique_traits;

            open(my $Fgc, ">", $coeff_genetic_tempfile) || die "Can't open file ".$coeff_genetic_tempfile;

            while ( my ($accession_name, $coeffs) = each %sommer_rr_genetic_coeff) {
                my @line = ($accession_name, @$coeffs);
                my $line_string = join ',', @line;
                print $Fgc "$line_string\n";

                foreach my $t_i (0..20) {
                    my $time = $t_i*5/100;
                    my $time_rescaled = sprintf("%.2f", $time*($time_max - $time_min) + $time_min);

                    my $value = 0;
                    my $coeff_counter = 0;
                    foreach my $b (@$coeffs) {
                        my $eval_string = $legendre_coeff_exec[$coeff_counter];
                        # print STDERR Dumper [$eval_string, $b, $time];
                        $value += eval $eval_string;
                        $coeff_counter++;
                    }

                    my $time_term_string = '';
                    if ($statistics_select eq 'sommer_grm_temporal_random_regression_gdd_genetic_blups') {
                        $time_term_string = "GDD $time_rescaled";
                    }
                    elsif ($statistics_select eq 'sommer_grm_temporal_random_regression_dap_genetic_blups') {
                        $time_term_string = "day $time_rescaled"
                    }
                    $h_time->execute($time_term_string, 'cxgn_time_ontology');
                    my ($time_cvterm_id) = $h_time->fetchrow_array();

                    if (!$time_cvterm_id) {
                        my $new_time_term = $schema->resultset("Cv::Cvterm")->create_with({
                           name => $time_term_string,
                           cv => 'cxgn_time_ontology'
                        });
                        $time_cvterm_id = $new_time_term->cvterm_id();
                    }
                    my $time_term_string_blup = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $time_cvterm_id, 'extended');
                    $rr_unique_traits{$time_term_string_blup}++;

                    $result_blup_data->{$accession_name}->{$time_term_string_blup} = [$value, $timestamp, $user_name, '', ''];
                }
            }
            close($Fgc);

            open(my $Fpc, ">", $coeff_pe_tempfile) || die "Can't open file ".$coeff_pe_tempfile;

            while ( my ($plot_name, $coeffs) = each %sommer_rr_temporal_coeff) {
                my @line = ($plot_name, @$coeffs);
                my $line_string = join ',', @line;
                print $Fpc "$line_string\n";

                foreach my $t_i (0..20) {
                    my $time = $t_i*5/100;
                    my $time_rescaled = sprintf("%.2f", $time*($time_max - $time_min) + $time_min);

                    my $value = 0;
                    my $coeff_counter = 0;
                    foreach my $b (@$coeffs) {
                        my $eval_string = $legendre_coeff_exec[$coeff_counter];
                        # print STDERR Dumper [$eval_string, $b, $time];
                        $value += eval $eval_string;
                        $coeff_counter++;
                    }

                    my $time_term_string = '';
                    if ($statistics_select eq 'sommer_grm_temporal_random_regression_gdd_genetic_blups') {
                        $time_term_string = "GDD $time_rescaled";
                    }
                    elsif ($statistics_select eq 'sommer_grm_temporal_random_regression_dap_genetic_blups') {
                        $time_term_string = "day $time_rescaled"
                    }
                    $h_time->execute($time_term_string, 'cxgn_time_ontology');
                    my ($time_cvterm_id) = $h_time->fetchrow_array();

                    if (!$time_cvterm_id) {
                        my $new_time_term = $schema->resultset("Cv::Cvterm")->create_with({
                           name => $time_term_string,
                           cv => 'cxgn_time_ontology'
                        });
                        $time_cvterm_id = $new_time_term->cvterm_id();
                    }
                    my $time_term_string_pe = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $time_cvterm_id, 'extended');
                    $rr_unique_traits{$time_term_string_pe}++;

                    $result_blup_pe_data->{$plot_name}->{$time_term_string_pe} = [$value, $timestamp, $user_name, '', ''];
                }
            }
            close($Fpc);

            @sorted_trait_names = sort keys %rr_unique_traits;
        }
        elsif ($statistics_select eq 'sommer_grm_genetic_only_random_regression_dap_genetic_blups' || $statistics_select eq 'sommer_grm_genetic_only_random_regression_gdd_genetic_blups') {
            $statistical_ontology_term = "Multivariate linear mixed model genetic BLUPs using genetic relationship matrix and temporal Legendre polynomial random regression on days after planting computed using Sommer R|SGNSTAT:0000004";

            $analysis_result_values_type = "analysis_result_values_match_accession_names";

            if ($statistics_select eq 'sommer_grm_genetic_only_random_regression_dap_genetic_blups') {
                $analysis_model_training_data_file_type = "nicksmixedmodels_v1.01_sommer_grm_genetic_leg_random_regression_DAP_genetic_blups_phenotype_file";
            }
            elsif ($statistics_select eq 'sommer_grm_genetic_only_random_regression_gdd_genetic_blups') {
                $analysis_model_training_data_file_type = "nicksmixedmodels_v1.01_sommer_grm_genetic_leg_random_regression_GDD_genetic_blups_phenotype_file";
            }

            my $cmd = 'R -e "library(sommer); library(data.table); library(reshape2); library(orthopolynom);
            mat <- fread(\''.$stats_tempfile.'\', header=TRUE, sep=\',\', check.names = FALSE);
            geno_mat_3col <- data.frame(fread(\''.$grm_file.'\', header=FALSE, sep=\'\t\'));
            geno_mat <- acast(geno_mat_3col, V1~V2, value.var=\'V3\');
            geno_mat[is.na(geno_mat)] <- 0;
            mat_long <- melt(mat, id.vars=c(\'replicate\', \'block\', \'id\', \'plot_id\', \'rowNumber\', \'colNumber\', \'rowNumberFactor\', \'colNumberFactor\'), variable.name=\'time\', value.name=\'value\');
            mat_long\$time <- as.numeric(as.character(mat_long\$time));
            mat_long <- mat_long[order(time),];
            mat\$rowNumber <- as.numeric(mat\$rowNumber);
            mat\$colNumber <- as.numeric(mat\$colNumber);
            mat\$rowNumberFactor <- as.factor(mat\$rowNumberFactor);
            mat\$colNumberFactor <- as.factor(mat\$colNumberFactor);
            mix <- mmer(
                value~1 + replicate,
                random=~vs(id, Gu=geno_mat) +vs(leg(time,'.$legendre_order_number.', intercept=TRUE), id),
                rcov=~vs(units),
                data=mat_long, tolparinv='.$tolparinv.'
            );
            write.table(data.frame(plot_id = mix\$data\$plot_id, time = mix\$data\$time, residuals = mix\$residuals, fitted = mix\$fitted), file=\''.$stats_out_tempfile_residual.'\', row.names=FALSE, col.names=TRUE, sep=\'\t\');
            write.table(mix\$U\$\`u:id\`, file=\''.$stats_out_tempfile.'\', row.names=TRUE, col.names=TRUE, sep=\'\t\');
            genetic_coeff <- data.frame(id = names(mix\$U\$\`leg0:id\`\$value));';
            for my $leg_num (0..$legendre_order_number) {
                $cmd .= 'genetic_coeff\$leg_'.$leg_num.' <- mix\$U\$\`leg'.$leg_num.':id\`\$value;';
            }
            $cmd .= 'write.table(genetic_coeff, file=\''.$stats_out_tempfile_genetic.'\', row.names=FALSE, col.names=TRUE, sep=\'\t\');"
            ';
            print STDERR Dumper $cmd;
            my $status = system("$cmd > /dev/null/");

            my $csv = Text::CSV->new({ sep_char => "\t" });

            no warnings 'uninitialized';

            my %unique_accessions_seen;
            my %unique_plots_seen;
            my @new_sorted_trait_names;
            my %sommer_rr_genetic_coeff;
            open(my $fh_genetic, '<', $stats_out_tempfile_genetic)
                or die "Could not open file '$stats_out_tempfile_genetic' $!";

                print STDERR "Opened $stats_out_tempfile_genetic\n";
                my $header = <$fh_genetic>;
                my @header_cols;
                if ($csv->parse($header)) {
                    @header_cols = $csv->fields();
                }

                while (my $row = <$fh_genetic>) {
                    my @columns;
                    if ($csv->parse($row)) {
                        @columns = $csv->fields();
                    }

                    my $accession_id = $columns[0];
                    my $accession_name = $stock_info{$accession_id}->{uniquename};
                    $unique_accessions_seen{$accession_name}++;

                    my $col_counter = 1;
                    foreach (0..$legendre_order_number) {
                        my $value = $columns[$col_counter];
                        push @{$sommer_rr_genetic_coeff{$accession_name}}, $value;
                        $col_counter++;
                    }
                }
            close($fh_genetic);

            # print STDERR Dumper \%sommer_rr_genetic_coeff;

            open(my $fh_residual, '<', $stats_out_tempfile_residual)
                or die "Could not open file '$stats_out_tempfile_residual' $!";

                print STDERR "Opened $stats_out_tempfile_residual\n";
                my $header_residual = <$fh_residual>;
                my @header_cols_residual;
                if ($csv->parse($header_residual)) {
                    @header_cols_residual = $csv->fields();
                }

                while (my $row = <$fh_residual>) {
                    my @columns;
                    if ($csv->parse($row)) {
                        @columns = $csv->fields();
                    }

                    my $stock_id = $columns[0];
                    my $time = $columns[1];
                    my $residual = $columns[2];
                    my $fitted = $columns[3];
                    my $stock_name = $plot_id_map{$stock_id};
                    $result_residual_data->{$stock_name}->{$seen_times{$time}} = [$residual, $timestamp, $user_name, '', ''];
                    $result_fitted_data->{$stock_name}->{$seen_times{$time}} = [$fitted, $timestamp, $user_name, '', ''];
                }
            close($fh_residual);

            $time_min = 100000000;
            $time_max = 0;
            foreach (@sorted_trait_names) {
                if ($_ < $time_min) {
                    $time_min = $_;
                }
                if ($_ > $time_max) {
                    $time_max = $_;
                }
            }
            print STDERR Dumper [$time_min, $time_max];

            my $q_time = "SELECT t.cvterm_id FROM cvterm as t JOIN cv ON(t.cv_id=cv.cv_id) WHERE t.name=? and cv.name=?;";
            my $h_time = $schema->storage->dbh()->prepare($q_time);

            my %rr_unique_traits;

            open(my $Fgc, ">", $coeff_genetic_tempfile) || die "Can't open file ".$coeff_genetic_tempfile;

            while ( my ($accession_name, $coeffs) = each %sommer_rr_genetic_coeff) {
                my @line = ($accession_name, @$coeffs);
                my $line_string = join ',', @line;
                print $Fgc "$line_string\n";

                foreach my $t_i (0..20) {
                    my $time = $t_i*5/100;
                    my $time_rescaled = sprintf("%.2f", $time*($time_max - $time_min) + $time_min);

                    my $value = 0;
                    my $coeff_counter = 0;
                    foreach my $b (@$coeffs) {
                        my $eval_string = $legendre_coeff_exec[$coeff_counter];
                        # print STDERR Dumper [$eval_string, $b, $time];
                        $value += eval $eval_string;
                        $coeff_counter++;
                    }

                    my $time_term_string = '';
                    if ($statistics_select eq 'sommer_grm_genetic_only_random_regression_gdd_genetic_blups') {
                        $time_term_string = "GDD $time_rescaled";
                    }
                    elsif ($statistics_select eq 'sommer_grm_genetic_only_random_regression_dap_genetic_blups') {
                        $time_term_string = "day $time_rescaled"
                    }
                    $h_time->execute($time_term_string, 'cxgn_time_ontology');
                    my ($time_cvterm_id) = $h_time->fetchrow_array();

                    if (!$time_cvterm_id) {
                        my $new_time_term = $schema->resultset("Cv::Cvterm")->create_with({
                           name => $time_term_string,
                           cv => 'cxgn_time_ontology'
                        });
                        $time_cvterm_id = $new_time_term->cvterm_id();
                    }
                    my $time_term_string_blup = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $time_cvterm_id, 'extended');
                    $rr_unique_traits{$time_term_string_blup}++;

                    $result_blup_data->{$accession_name}->{$time_term_string_blup} = [$value, $timestamp, $user_name, '', ''];
                }
            }
            close($Fgc);

            @sorted_trait_names = sort keys %rr_unique_traits;
        }
        elsif ($statistics_select eq 'blupf90_grm_random_regression_gdd_blups' || $statistics_select eq 'blupf90_grm_random_regression_dap_blups' || $statistics_select eq 'airemlf90_grm_random_regression_gdd_blups' || $statistics_select eq 'airemlf90_grm_random_regression_dap_blups') {

            $statistical_ontology_term = "Multivariate linear mixed model genetic BLUPs using genetic relationship matrix and temporal Legendre polynomial random regression on days after planting computed using Sommer R|SGNSTAT:0000004"; #In the JS this is set to either the genetic of permanent environment BLUP term (Multivariate linear mixed model permanent environment BLUPs using genetic relationship matrix and temporal Legendre polynomial random regression on days after planting computed using Sommer R|SGNSTAT:0000005) when saving results

            $analysis_result_values_type = "analysis_result_values_match_accession_names";

            if ($statistics_select eq 'blupf90_grm_random_regression_gdd_blups') {
                $analysis_model_training_data_file_type = "nicksmixedmodels_v1.01_blupf90_grm_temporal_leg_random_regression_GDD_genetic_blups_phenotype_file";
            }
            elsif ($statistics_select eq 'blupf90_grm_random_regression_dap_blups') {
                $analysis_model_training_data_file_type = "nicksmixedmodels_v1.01_blupf90_grm_temporal_leg_random_regression_DAP_genetic_blups_phenotype_file";
            }
            elsif ($statistics_select eq 'airemlf90_grm_random_regression_gdd_blups') {
                $analysis_model_training_data_file_type = "nicksmixedmodels_v1.01_airemlf90_grm_temporal_leg_random_regression_GDD_genetic_blups_phenotype_file";
            }
            elsif ($statistics_select eq 'airemlf90_grm_random_regression_dap_blups') {
                $analysis_model_training_data_file_type = "nicksmixedmodels_v1.01_airemlf90_grm_temporal_leg_random_regression_DAP_genetic_blups_phenotype_file";
            }

            my $pheno_var_pos = $legendre_order_number+1;
            my $cmd_r = 'R -e "
                pheno <- read.csv(\''.$stats_prep2_tempfile.'\', header=FALSE, sep=\',\');
                v <- var(pheno);
                v <- v[1:'.$pheno_var_pos.', 1:'.$pheno_var_pos.'];
                #v <- matrix(rep(0.1, '.$pheno_var_pos.'*'.$pheno_var_pos.'), nrow = '.$pheno_var_pos.');
                #diag(v) <- rep(1, '.$pheno_var_pos.');
                write.table(v, file=\''.$stats_out_param_tempfile.'\', row.names=FALSE, col.names=FALSE, sep=\'\t\');
            "';
            print STDERR Dumper $cmd_r;
            my $status_r = system("$cmd_r > /dev/null");

            my $csv = Text::CSV->new({ sep_char => "\t" });

            my @pheno_var;
            open(my $fh_r, '<', $stats_out_param_tempfile)
                or die "Could not open file '$stats_out_param_tempfile' $!";
                print STDERR "Opened $stats_out_param_tempfile\n";

                while (my $row = <$fh_r>) {
                    my @columns;
                    if ($csv->parse($row)) {
                        @columns = $csv->fields();
                    }
                    push @pheno_var, \@columns;
                }
            close($fh_r);
            # print STDERR Dumper \@pheno_var;

            my @grm_old;
            open(my $fh_grm_old, '<', $grm_file)
                or die "Could not open file '$grm_file' $!";
                print STDERR "Opened $grm_file\n";

                while (my $row = <$fh_grm_old>) {
                    my @columns;
                    if ($csv->parse($row)) {
                        @columns = $csv->fields();
                    }
                    push @grm_old, \@columns;
                }
            close($fh_grm_old);

            my %grm_hash_ordered;
            foreach (@grm_old) {
                my $l1 = $accession_id_factor_map{$_->[0]};
                my $l2 = $accession_id_factor_map{$_->[1]};
                my $val = sprintf("%.8f", $_->[2]);
                if ($l1 < $l2) {
                    $grm_hash_ordered{$l1}->{$l2} = $val;
                }
                else {
                    $grm_hash_ordered{$l2}->{$l1} = $val;
                }
            }

            open(my $fh_grm_new, '>', $grm_rename_tempfile)
                or die "Could not open file '$grm_rename_tempfile' $!";
                print STDERR "Opened $grm_rename_tempfile\n";

                foreach my $i (sort keys %grm_hash_ordered) {
                    my $v = $grm_hash_ordered{$i};
                    foreach my $j (sort keys %$v) {
                        my $val = $v->{$j};
                        print $fh_grm_new "$i $j $val\n";
                    }
                }
            close($fh_grm_new);

            my $stats_tempfile_2_basename = basename($stats_tempfile_2);
            my $grm_file_basename = basename($grm_rename_tempfile);
            my $permanent_environment_structure_file_basename = basename($permanent_environment_structure_tempfile);
            #my @phenotype_header = ("id", "plot_id", "replicate", "time", "replicate_time", "ind_replicate", @sorted_trait_names, "phenotype");

            my $effect_1_levels = scalar(@rep_time_factors);
            my $effect_grm_levels = scalar(@unique_accession_names);
            my $effect_pe_levels = scalar(@ind_rep_factors);

            my @param_file_rows = (
                'DATAFILE',
                $stats_tempfile_2_basename,
                'NUMBER_OF_TRAITS',
                '1',
                'NUMBER_OF_EFFECTS',
                ($legendre_order_number + 1)*2 + 1,
                'OBSERVATION(S)',
                $legendre_order_number + 1 + 6 + 1,
                'WEIGHT(S)',
                '',
                'EFFECTS: POSITION_IN_DATAFILE NUMBER_OF_LEVELS TYPE_OF_EFFECT',
                '5 '.$effect_1_levels.' cross',
            );
            my $p_counter = 1;
            foreach (0 .. $legendre_order_number) {
                push @param_file_rows, 6+$p_counter.' '.$effect_grm_levels.' cov 1';
                $p_counter++;
            }
            my $p2_counter = 1;
            my @hetres_group;
            foreach (0 .. $legendre_order_number) {
                push @param_file_rows, 6+$p2_counter.' '.$effect_pe_levels.' cov 6';
                push @hetres_group, 6+$p2_counter;
                $p2_counter++;
            }
            my @random_group1;
            foreach (1..$legendre_order_number+1) {
                push @random_group1, 1+$_;
            }
            my $random_group_string1 = join ' ', @random_group1;
            my @random_group2;
            foreach (1..$legendre_order_number+1) {
                push @random_group2, 1+scalar(@random_group1)+$_;
            }
            my $random_group_string2 = join ' ', @random_group2;
            my $hetres_group_string = join ' ', @hetres_group;
            push @param_file_rows, (
                'RANDOM_RESIDUAL VALUES',
                '1',
                'RANDOM_GROUP',
                $random_group_string1,
                'RANDOM_TYPE'
            );
            if (!$protocol_id) {
                push @param_file_rows, (
                    'diagonal',
                    'FILE',
                    ''
                );
            }
            else {
                push @param_file_rows, (
                    'user_file_inv',
                    'FILE',
                    $grm_file_basename
                );
            }
            push @param_file_rows, (
                '(CO)VARIANCES'
            );
            foreach (@pheno_var) {
                my $s = join ' ', @$_;
                push @param_file_rows, $s;
            }
            push @param_file_rows, (
                'RANDOM_GROUP',
                $random_group_string2,
                'RANDOM_TYPE'
            );

            if ($permanent_environment_structure eq 'identity') {
                push @param_file_rows, (
                    'diagonal',
                    'FILE',
                    ''
                );
            }
            else {
                push @param_file_rows, (
                    'user_file_inv',
                    'FILE',
                    $permanent_environment_structure_file_basename
                );
            }

            push @param_file_rows, (
                '(CO)VARIANCES'
            );
            foreach (@pheno_var) {
                my $s = join ' ', @$_;
                push @param_file_rows, $s;
            }
            my $hetres_pol_string = join ' ', @sorted_scaled_ln_times;
            push @param_file_rows, (
                'OPTION hetres_pos '.$hetres_group_string,
                'OPTION hetres_pol '.$hetres_pol_string,
                'OPTION conv_crit '.$tolparinv,
                'OPTION residual',
            );

            open(my $Fp, ">", $parameter_tempfile) || die "Can't open file ".$parameter_tempfile;
                foreach (@param_file_rows) {
                    print $Fp "$_\n";
                }
            close($Fp);

            my $command_name = '';
            if ($statistics_select eq 'blupf90_grm_random_regression_gdd_blups' || $statistics_select eq 'blupf90_grm_random_regression_dap_blups') {
                $command_name = 'blupf90';
            }
            elsif ($statistics_select eq 'airemlf90_grm_random_regression_gdd_blups' || $statistics_select eq 'airemlf90_grm_random_regression_dap_blups') {
                $command_name = 'airemlf90';
            }

            my $parameter_tempfile_basename = basename($parameter_tempfile);
            $stats_out_tempfile .= '.log';
            my $cmd = 'cd '.$tmp_stats_dir.'; echo '.$parameter_tempfile_basename.' | '.$command_name.' > '.$stats_out_tempfile;
            print STDERR Dumper $cmd;
            my $status = system("$cmd > /dev/null");

            $csv = Text::CSV->new({ sep_char => "\t" });

            open(my $fh_log, '<', $stats_out_tempfile)
                or die "Could not open file '$stats_out_tempfile' $!";

                print STDERR "Opened $stats_out_tempfile\n";
                while (my $row = <$fh_log>) {
                    print STDERR $row;
                }
            close($fh_log);

            my $q_time = "SELECT t.cvterm_id FROM cvterm as t JOIN cv ON(t.cv_id=cv.cv_id) WHERE t.name=? and cv.name=?;";
            my $h_time = $schema->storage->dbh()->prepare($q_time);

            my %rr_unique_traits;
            my %rr_residual_unique_traits;

            my $sum_square_res = 0;
            $yhat_residual_tempfile = $tmp_stats_dir."/yhat_residual";
            open(my $fh_yhat_res, '<', $yhat_residual_tempfile)
                or die "Could not open file '$yhat_residual_tempfile' $!";
                print STDERR "Opened $yhat_residual_tempfile\n";

                my $pred_res_counter = 0;
                my $trait_counter = 0;
                while (my $row = <$fh_yhat_res>) {
                    # print STDERR $row;
                    my @vals = split ' ', $row;
                    my $pred = $vals[0];
                    my $residual = $vals[1];
                    $sum_square_res = $sum_square_res + $residual*$residual;

                    my $plot_name = $plot_id_count_map_reverse{$pred_res_counter};
                    my $time = $time_count_map_reverse{$pred_res_counter};

                    $rr_residual_unique_traits{$seen_times{$time}}++;

                    $result_residual_data->{$plot_name}->{$seen_times{$time}} = [$residual, $timestamp, $user_name, '', ''];
                    $result_fitted_data->{$plot_name}->{$seen_times{$time}} = [$pred, $timestamp, $user_name, '', ''];

                    $pred_res_counter++;
                }
            close($fh_yhat_res);
            $model_sum_square_residual = $sum_square_res;

            my %fixed_effects;
            my %rr_genetic_coefficients;
            my %rr_temporal_coefficients;
            $blupf90_solutions_tempfile = $tmp_stats_dir."/solutions";
            open(my $fh_sol, '<', $blupf90_solutions_tempfile)
                or die "Could not open file '$blupf90_solutions_tempfile' $!";
                print STDERR "Opened $blupf90_solutions_tempfile\n";

                my $head = <$fh_sol>;
                print STDERR $head;

                my $solution_file_counter = 0;
                my $grm_sol_counter = 0;
                my $grm_sol_trait_counter = 0;
                my $pe_sol_counter = 0;
                my $pe_sol_trait_counter = 0;
                while (my $row = <$fh_sol>) {
                    # print STDERR $row;
                    my @vals = split ' ', $row;
                    my $level = $vals[2];
                    my $value = $vals[3];
                    if ($solution_file_counter < $effect_1_levels) {
                        $fixed_effects{$solution_file_counter}->{$level} = $value;
                    }
                    elsif ($solution_file_counter < $effect_1_levels + $effect_grm_levels*($legendre_order_number+1)) {
                        my $accession_name = $accession_id_factor_map_reverse{$level};
                        # my $trait = $seen_times{$sorted_trait_names[$grm_sol_trait_counter]};
                        if ($grm_sol_counter < $effect_grm_levels-1) {
                            $grm_sol_counter++;
                        }
                        else {
                            $grm_sol_counter = 0;
                            $grm_sol_trait_counter++;
                        }
                        # $result_blup_data->{$accession_name}->{$trait} = [$value, $timestamp, $user_name, '', ''];
                        push @{$rr_genetic_coefficients{$accession_name}}, $value;
                    }
                    else {
                        my $plot_name = $plot_id_factor_map_reverse{$level};
                        # my $trait = $seen_times{$sorted_trait_names[$pe_sol_trait_counter]};
                        if ($pe_sol_counter < $effect_pe_levels-1) {
                            $pe_sol_counter++;
                        }
                        else {
                            $pe_sol_counter = 0;
                            $pe_sol_trait_counter++;
                        }
                        # $result_blup_pe_data->{$plot_name}->{$trait} = [$value, $timestamp, $user_name, '', ''];
                        push @{$rr_temporal_coefficients{$plot_name}}, $value;
                    }
                    $solution_file_counter++;
                }
            close($fh_sol);

            # print STDERR Dumper \%rr_genetic_coefficients;
            # print STDERR Dumper \%rr_temporal_coefficients;

            open(my $Fgc, ">", $coeff_genetic_tempfile) || die "Can't open file ".$coeff_genetic_tempfile;
            print STDERR "OPENED $coeff_genetic_tempfile\n";

            while ( my ($accession_name, $coeffs) = each %rr_genetic_coefficients) {
                my @line = ($accession_name, @$coeffs);
                my $line_string = join ',', @line;
                print $Fgc "$line_string\n";

                foreach my $t_i (0..20) {
                    my $time = $t_i*5/100;
                    my $time_rescaled = sprintf("%.2f", $time*($time_max - $time_min) + $time_min);

                    my $value = 0;
                    my $coeff_counter = 0;
                    foreach my $b (@$coeffs) {
                        my $eval_string = $legendre_coeff_exec[$coeff_counter];
                        # print STDERR Dumper [$eval_string, $b, $time];
                        $value += eval $eval_string;
                        $coeff_counter++;
                    }

                    my $time_term_string = '';
                    if ($statistics_select eq 'blupf90_grm_random_regression_gdd_blups' || $statistics_select eq 'airemlf90_grm_random_regression_gdd_blups') {
                        $time_term_string = "GDD $time_rescaled";
                    }
                    elsif ($statistics_select eq 'blupf90_grm_random_regression_dap_blups' || $statistics_select eq 'airemlf90_grm_random_regression_dap_blups') {
                        $time_term_string = "day $time_rescaled"
                    }
                    $h_time->execute($time_term_string, 'cxgn_time_ontology');
                    my ($time_cvterm_id) = $h_time->fetchrow_array();

                    if (!$time_cvterm_id) {
                        my $new_time_term = $schema->resultset("Cv::Cvterm")->create_with({
                           name => $time_term_string,
                           cv => 'cxgn_time_ontology'
                        });
                        $time_cvterm_id = $new_time_term->cvterm_id();
                    }
                    my $time_term_string_blup = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $time_cvterm_id, 'extended');
                    $rr_unique_traits{$time_term_string_blup}++;

                    $result_blup_data->{$accession_name}->{$time_term_string_blup} = [$value, $timestamp, $user_name, '', ''];
                }
            }
            close($Fgc);

            while ( my ($accession_name, $coeffs) = each %rr_genetic_coefficients) {
                foreach my $time_term (@sorted_trait_names) {
                    $time = ($time_term - $time_min)/($time_max - $time_min);
                    my $value = 0;
                    my $coeff_counter = 0;
                    foreach my $b (@$coeffs) {
                        my $eval_string = $legendre_coeff_exec[$coeff_counter];
                        # print STDERR Dumper [$eval_string, $b, $time];
                        $value += eval $eval_string;
                        $coeff_counter++;
                    }

                    $result_blup_data_delta->{$accession_name}->{$time_term} = [$value, $timestamp, $user_name, '', ''];
                }
            }

            open(my $Fpc, ">", $coeff_pe_tempfile) || die "Can't open file ".$coeff_pe_tempfile;
            print STDERR "OPENED $coeff_pe_tempfile\n";

            while ( my ($plot_name, $coeffs) = each %rr_temporal_coefficients) {
                my @line = ($plot_name, @$coeffs);
                my $line_string = join ',', @line;
                print $Fpc "$line_string\n";

                foreach my $t_i (0..20) {
                    my $time = $t_i*5/100;
                    my $time_rescaled = sprintf("%.2f", $time*($time_max - $time_min) + $time_min);

                    my $value = 0;
                    my $coeff_counter = 0;
                    foreach my $b (@$coeffs) {
                        my $eval_string = $legendre_coeff_exec[$coeff_counter];
                        # print STDERR Dumper [$eval_string, $b, $time];
                        $value += eval $eval_string;
                        $coeff_counter++;
                    }

                    my $time_term_string = '';
                    if ($statistics_select eq 'blupf90_grm_random_regression_gdd_blups' || $statistics_select eq 'airemlf90_grm_random_regression_gdd_blups') {
                        $time_term_string = "GDD $time_rescaled";
                    }
                    elsif ($statistics_select eq 'blupf90_grm_random_regression_dap_blups' || $statistics_select eq 'airemlf90_grm_random_regression_dap_blups') {
                        $time_term_string = "day $time_rescaled"
                    }
                    $h_time->execute($time_term_string, 'cxgn_time_ontology');
                    my ($time_cvterm_id) = $h_time->fetchrow_array();

                    if (!$time_cvterm_id) {
                        my $new_time_term = $schema->resultset("Cv::Cvterm")->create_with({
                           name => $time_term_string,
                           cv => 'cxgn_time_ontology'
                        });
                        $time_cvterm_id = $new_time_term->cvterm_id();
                    }
                    my $time_term_string_pe = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $time_cvterm_id, 'extended');
                    $rr_unique_traits{$time_term_string_pe}++;

                    $result_blup_pe_data->{$plot_name}->{$time_term_string_pe} = [$value, $timestamp, $user_name, '', ''];
                }
            }
            close($Fpc);

            while ( my ($plot_name, $coeffs) = each %rr_temporal_coefficients) {
                foreach my $time_term (@sorted_trait_names) {
                    my $time = ($time_term - $time_min)/($time_max - $time_min);
                    my $value = 0;
                    my $coeff_counter = 0;
                    foreach my $b (@$coeffs) {
                        my $eval_string = $legendre_coeff_exec[$coeff_counter];
                        # print STDERR Dumper [$eval_string, $b, $time];
                        $value += eval $eval_string;
                        $coeff_counter++;
                    }

                    $result_blup_pe_data_delta->{$plot_name}->{$time_term} = [$value, $timestamp, $user_name, '', ''];
                }
            }

            # print STDERR Dumper \%fixed_effects;
            # print STDERR Dumper $result_blup_data;
            # print STDERR Dumper $result_blup_pe_data;
            @sorted_trait_names = sort keys %rr_unique_traits;
            @sorted_residual_trait_names = sort keys %rr_residual_unique_traits;
        }
    }
    elsif ($statistics_select eq 'marss_germplasmname_block') {

        my $dbh = $c->dbc->dbh();
        my $bs = CXGN::BreederSearch->new( { dbh=>$dbh } );
        my $status = $bs->test_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass});
        if ($status->{'error'}) {
            $c->stash->{rest} = { error => $status->{'error'}};
            return;
        }
        my $results_ref = $bs->metadata_query(['trials', 'accessions'], {'accessions' => {'trials' => $field_trial_id_list_string}}, {'accessions' => {'trials'=>1}});
        my %unique_accession_ids;
        foreach (@{$results_ref->{results}}) {
            $unique_accession_ids{$_->[0]}++;
        }
        my @unique_accession_ids = keys %unique_accession_ids;
        if (scalar(@unique_accession_ids) == 0) {
            $c->stash->{rest} = { error => "There are no common accessions in the trials you have selected! If that is the case, please just select one at a time."};
            return;
        }
        print STDERR scalar(@unique_accession_ids)." Common Accessions\n";

        my $marss_prediction_selection = $c->req->param('statistics_select_marss_options');

        my $phenotypes_search = CXGN::Phenotypes::SearchFactory->instantiate(
            'MaterializedViewTable',
            {
                bcs_schema=>$schema,
                data_level=>'plot',
                trait_list=>$trait_id_list,
                trial_list=>$field_trial_id_list,
                accession_list=>\@unique_accession_ids,
                include_timestamp=>0,
                exclude_phenotype_outlier=>0
            }
        );
        my ($data, $unique_traits) = $phenotypes_search->search();
        my @sorted_trait_names = sort keys %$unique_traits;

        if (scalar(@$data) == 0) {
            $c->stash->{rest} = { error => "There are no phenotypes for the trials and traits you have selected!"};
            return;
        }

        my %germplasm_name_encoder;
        my $germplasm_name_encoded = 1;
        my %trait_name_encoder;
        my $trait_name_encoded = 1;
        my %phenotype_data;
        my %seen_gdd_times;
        my %seen_germplasm_names;
        foreach my $obs_unit (@$data){
            my $germplasm_name = $obs_unit->{germplasm_uniquename};
            my $observations = $obs_unit->{observations};
            if (!exists($germplasm_name_encoder{$germplasm_name})) {
                $germplasm_name_encoder{$germplasm_name} = $germplasm_name_encoded;
                $germplasm_name_encoded++;
            }
            foreach (@$observations){
                my $related_time_terms_json = decode_json $_->{associated_image_project_time_json};
                my $gdd_time = $related_time_terms_json->{gdd_average_temp} + 0;
                $phenotype_data{$obs_unit->{observationunit_uniquename}}->{$gdd_time} = $_->{value};
                $seen_gdd_times{$gdd_time}++;
            }
            $seen_germplasm_names{$germplasm_name} = $obs_unit->{germplasm_stock_id};
        }
        my @sorted_gdd_time_points = sort {$a <=> $b} keys %seen_gdd_times;

        my %data_matrix;
        my %germplasm_pheno_hash;
        foreach (@$data) {
            my $germplasm_name = $_->{germplasm_uniquename};
            my $obsunit_name = $_->{observationunit_uniquename};
            $germplasm_pheno_hash{$germplasm_name}->{obsunit_rep} = $_->{obsunit_rep};
            $germplasm_pheno_hash{$germplasm_name}->{obsunit_block} = $_->{obsunit_block};
            $germplasm_pheno_hash{$germplasm_name}->{germplasm_encoded} = $germplasm_name_encoder{$germplasm_name};
            foreach my $t (@sorted_gdd_time_points) {
                if (defined($phenotype_data{$obsunit_name}->{$t})) {
                    $germplasm_pheno_hash{$germplasm_name}->{$t} = $phenotype_data{$obsunit_name}->{$t} + 0;
                } else {
                    print STDERR "Using NA for ".$obsunit_name." : $t : $germplasm_name :  \n";
                }
            }
        }
        foreach my $g (keys %seen_germplasm_names) {
            my @row = ($germplasm_pheno_hash{$g}->{obsunit_rep}, $germplasm_pheno_hash{$g}->{obsunit_block}, $germplasm_pheno_hash{$g}->{germplasm_encoded});
            foreach my $t (@sorted_gdd_time_points) {
                push @row, $germplasm_pheno_hash{$g}->{$t};
            }
            push @{$data_matrix{$g}}, @row;
        }

        my @phenotype_header = ("replicate", "block", "germplasmName");
        my $num_col_before_traits = scalar(@phenotype_header);
        foreach (@sorted_gdd_time_points) {
            push @phenotype_header, "$_";
        }

        print STDERR Dumper \%data_matrix;
        print STDERR Dumper \@phenotype_header;

        foreach (keys %seen_germplasm_names) {
            my $germplasm_stock_id = $seen_germplasm_names{$_};
            my $dir = $c->tempfiles_subdir('/drone_imagery_analysis_plot');
            my $temp_plot = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_analysis_plot/imageXXXX');
            $temp_plot .= '.jpg';

            my $germplasm_data = $data_matrix{$_};
            my $num_rows = scalar(@$germplasm_data)/scalar(@phenotype_header);
            my $rmatrix = R::YapRI::Data::Matrix->new({
                name => 'matrix1',
                coln => scalar(@phenotype_header),
                rown => $num_rows,
                colnames => \@phenotype_header,
                data => $germplasm_data
            });

            my $rbase = R::YapRI::Base->new();
            my $r_block = $rbase->create_block('r_block');
            $rmatrix->send_rbase($rbase, 'r_block');
            $r_block->add_command('library(MARSS)');
            $r_block->add_command('library(ggplot2)');
            $r_block->add_command('header <- colnames(matrix1)');
            $r_block->add_command('gdd_times <- header[-c(1:'.$num_col_before_traits.')]');
            $r_block->add_command('matrix_transposed <- t(matrix1)');
            $r_block->add_command('result_matrix <- matrix(NA,nrow = 3*'.$num_rows.', ncol = length(matrix_transposed[ ,1]))');
            $r_block->add_command('jpeg("'.$temp_plot.'")');

            my $row_number = 1;
            foreach my $t (1..$num_rows) {
                $r_block->add_command('row'.$t.' <- matrix_transposed[ , '.$t.']');
                $r_block->add_command('replicate'.$t.' <- row'.$t.'[1]');
                $r_block->add_command('block'.$t.' <- row'.$t.'[2]');
                $r_block->add_command('germplasmName'.$t.' <- row'.$t.'[3]');
                $r_block->add_command('time_series'.$t.' <- row'.$t.'[-c(1:'.$num_col_before_traits.')]');
                $r_block->add_command('for (i in range(1:length(time_series'.$t.'))) { if (time_series'.$t.'[i] == "NA") { time_series'.$t.'[i] <- NA } }');
                $r_block->add_command('time_series_original'.$t.' <- time_series'.$t.'');
                if ($marss_prediction_selection eq 'marss_predict_last_two_time_points') {
                    $r_block->add_command('time_series'.$t.'[c(length(time_series'.$t.')-1, length(time_series'.$t.') )] <- NA');
                }
                elsif ($marss_prediction_selection eq 'marss_predict_last_time_point') {
                    $r_block->add_command('time_series'.$t.'[length(time_series'.$t.')] <- NA');
                }
                else {
                    die "MARSS predict option not selected\n";
                }
                #$r_block->add_command('mars_model'.$t.' <- list(B=matrix("phi"), U=matrix(0), Q=matrix("sig.sq.w"), Z=matrix("a"), A=matrix(0), R=matrix("sig.sq.v"), x0=matrix("mu"), tinitx=0 )');
                $r_block->add_command('mars_model'.$t.' <- list(B="unconstrained", U="zero", Q="unconstrained", Z="identity", A="zero", R="diagonal and unequal", tinitx=1 )');
                $r_block->add_command('mars_fit'.$t.' <- MARSS(time_series'.$t.', model=mars_model'.$t.', method="kem")');
                $r_block->add_command('minimum_y_val'.$t.' <- min( c( min(as.numeric(time_series_original'.$t.'), na.rm=T), min(as.numeric(mars_fit'.$t.'$ytT)), na.rm=T) , na.rm=T)');
                $r_block->add_command('maximum_y_val'.$t.' <- max( c( max(as.numeric(time_series_original'.$t.'), na.rm=T), max(as.numeric(mars_fit'.$t.'$ytT)), na.rm=T) , na.rm=T)');
                $r_block->add_command('maximum_y_std'.$t.' <- max( mars_fit'.$t.'$ytT.se, na.rm=T)');
                $r_block->add_command('result_matrix['.$row_number.',] <- c(replicate'.$t.', block'.$t.', germplasmName'.$t.', time_series_original'.$t.')');
                $row_number++;
                $r_block->add_command('result_matrix['.$row_number.',] <- c(replicate'.$t.', block'.$t.', germplasmName'.$t.', mars_fit'.$t.'$ytT)');
                $row_number++;
                $r_block->add_command('result_matrix['.$row_number.',] <- c(replicate'.$t.', block'.$t.', germplasmName'.$t.', mars_fit'.$t.'$ytT.se)');
                $row_number++;

                if ($t == 1) {
                    $r_block->add_command('plot(gdd_times, time_series_original'.$t.', type="b", col="gray", main="State Space '.$_.'", xlab="Growing Degree Days", ylab="Phenotype", ylim = c(minimum_y_val'.$t.'-maximum_y_std'.$t.'-0.05*maximum_y_val'.$t.', maximum_y_val'.$t.'+maximum_y_std'.$t.'+0.05*maximum_y_val'.$t.') )');
                }
                else {
                    $r_block->add_command('lines(gdd_times, time_series_original'.$t.', type="b", col="gray")');
                }
                $r_block->add_command('points(gdd_times[which(is.na(time_series'.$t.'))], mars_fit'.$t.'$ytT[which(is.na(time_series'.$t.'))], col="blue", lty=2)');
                $r_block->add_command('points(gdd_times[which(is.na(time_series'.$t.'))], c(mars_fit'.$t.'$ytT + qnorm(0.975)*mars_fit'.$t.'$ytT.se)[which(is.na(time_series'.$t.'))], col="red", lty=2)');
                $r_block->add_command('points(gdd_times[which(is.na(time_series'.$t.'))], c(mars_fit'.$t.'$ytT - qnorm(0.975)*mars_fit'.$t.'$ytT.se)[which(is.na(time_series'.$t.'))], col="red", lty=2)');
                # $r_block->add_command('legend("topleft", col=c("blue", "gray", "red"), legend = c("Predicted", "Observed", "SE"), lty=1 )');
            }
            $r_block->add_command('dev.off()');
            $r_block->run_block();
            my $result_matrix = R::YapRI::Data::Matrix->read_rbase($rbase,'r_block','result_matrix');
            #print STDERR Dumper $result_matrix;

            my $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
            my $md5checksum = $image->calculate_md5sum($temp_plot);
            my $q = "SELECT md_image.image_id
                FROM metadata.md_image AS md_image
                JOIN phenome.stock_image AS stock_image USING(image_id)
                WHERE md_image.obsolete = 'f' AND md_image.md5sum = ? AND stock_image.stock_id = ?;";
            my $h = $schema->storage->dbh->prepare($q);
            $h->execute($md5checksum, $germplasm_stock_id);
            my ($saved_image_id) = $h->fetchrow_array();

            my $plot_image_fullpath;
            my $plot_image_url;
            my $plot_image_id;
            if ($saved_image_id) {
                print STDERR Dumper "Image $temp_plot has already been added to the database and will not be added again.";
                $image = SGN::Image->new( $schema->storage->dbh, $saved_image_id, $c );
                $plot_image_fullpath = $image->get_filename('original_converted', 'full');
                $plot_image_url = $image->get_image_url('original');
                $plot_image_id = $image->get_image_id();
            } else {
                $image->set_sp_person_id($user_id);
                my $ret = $image->process_image($temp_plot, 'stock', $germplasm_stock_id);
                $plot_image_fullpath = $image->get_filename('original_converted', 'full');
                $plot_image_url = $image->get_image_url('original');
                $plot_image_id = $image->get_image_id();
            }

            push @results, ["TimeSeries", $result_matrix, $plot_image_url];
        }
    }
    else {
        $c->stash->{rest} = { error => "Not supported $statistics_select!"};
        return;
    }

    my $genetic_effects_figure_tempfile_string;
    if ($statistics_select eq 'sommer_grm_genetic_blups' || $statistics_select eq 'sommer_grm_spatial_genetic_blups' || $statistics_select eq 'sommer_grm_temporal_random_regression_dap_genetic_blups' || $statistics_select eq 'sommer_grm_temporal_random_regression_gdd_genetic_blups' || $statistics_select eq 'sommer_grm_genetic_only_random_regression_dap_genetic_blups' || $statistics_select eq 'sommer_grm_genetic_only_random_regression_gdd_genetic_blups' || $statistics_select eq 'blupf90_grm_random_regression_gdd_blups' || $statistics_select eq 'blupf90_grm_random_regression_dap_blups' || $statistics_select eq 'airemlf90_grm_random_regression_gdd_blups' || $statistics_select eq 'airemlf90_grm_random_regression_dap_blups') {
        my ($effects_original_line_chart_tempfile_fh, $effects_original_line_chart_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
        open(my $F_pheno, ">", $effects_original_line_chart_tempfile) || die "Can't open file ".$effects_original_line_chart_tempfile;
            print $F_pheno "germplasmName,time,value\n";
            foreach my $p (@unique_accession_names) {
                foreach my $t (@sorted_trait_names_original) {
                    my @row;
                    if ($statistics_select eq 'sommer_grm_temporal_random_regression_dap_genetic_blups' || $statistics_select eq 'sommer_grm_temporal_random_regression_gdd_genetic_blups' || $statistics_select eq 'sommer_grm_genetic_only_random_regression_dap_genetic_blups' || $statistics_select eq 'sommer_grm_genetic_only_random_regression_gdd_genetic_blups' || $statistics_select eq 'blupf90_grm_random_regression_gdd_blups' || $statistics_select eq 'blupf90_grm_random_regression_dap_blups' || $statistics_select eq 'airemlf90_grm_random_regression_gdd_blups' || $statistics_select eq 'airemlf90_grm_random_regression_dap_blups') {
                        my $val = $result_blup_data_delta->{$p}->{$t}->[0];
                        @row = ($p, $t, $val);
                    }
                    elsif ($statistics_select eq 'sommer_grm_genetic_blups' || $statistics_select eq 'sommer_grm_spatial_genetic_blups') {
                        my $val = $result_blup_data->{$p}->{$t}->[0];
                        @row = ($p, $trait_to_time_map{$t}, $val);
                    }
                    my $line = join ',', @row;
                    print $F_pheno "$line\n";
                }
            }
        close($F_pheno);

        my @set = ('0' ..'9', 'A' .. 'F');
        my @colors;
        for (1..scalar(@unique_accession_names)) {
            my $str = join '' => map $set[rand @set], 1 .. 6;
            push @colors, '#'.$str;
        }
        my $color_string = join '\',\'', @colors;

        $genetic_effects_figure_tempfile_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
        $genetic_effects_figure_tempfile_string .= '.png';
        my $genetic_effects_figure_tempfile = $c->config->{basepath}."/".$genetic_effects_figure_tempfile_string;

        my $cmd_gen_plot = 'R -e "library(data.table); library(ggplot2);
        mat <- fread(\''.$effects_original_line_chart_tempfile.'\', header=TRUE, sep=\',\');
        mat\$time <- as.numeric(as.character(mat\$time));
        options(device=\'png\');
        par();
        sp <- ggplot(mat, aes(x = time, y = value)) +
            geom_line(aes(color = germplasmName), size = 1) +
            scale_fill_manual(values = c(\''.$color_string.'\')) +
            theme_minimal();
        sp <- sp + guides(shape = guide_legend(override.aes = list(size = 0.5)));
        sp <- sp + guides(color = guide_legend(override.aes = list(size = 0.5)));
        sp <- sp + theme(legend.title = element_text(size = 3), legend.text = element_text(size = 3));';
        if (scalar(@unique_accession_names) > 100) {
            $cmd_gen_plot .= 'sp <- sp + theme(legend.position = \'none\');';
        }
        $cmd_gen_plot .= 'ggsave(\''.$genetic_effects_figure_tempfile.'\', sp, device=\'png\', width=12, height=6, units=\'in\');
        dev.off();"';
        my $status_gen_plot = system("$cmd_gen_plot > /dev/null");
    }

    my $env_effects_figure_tempfile_string;
    if ($statistics_select eq 'sommer_grm_spatial_genetic_blups' || $statistics_select eq 'sommer_grm_temporal_random_regression_dap_genetic_blups' || $statistics_select eq 'sommer_grm_temporal_random_regression_gdd_genetic_blups' || $statistics_select eq 'blupf90_grm_random_regression_gdd_blups' || $statistics_select eq 'blupf90_grm_random_regression_dap_blups' || $statistics_select eq 'airemlf90_grm_random_regression_gdd_blups' || $statistics_select eq 'airemlf90_grm_random_regression_dap_blups') {
        my ($phenotypes_original_heatmap_tempfile_fh, $phenotypes_original_heatmap_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
        open(my $F_pheno, ">", $phenotypes_original_heatmap_tempfile) || die "Can't open file ".$phenotypes_original_heatmap_tempfile;
            print $F_pheno "trait_type,row,col,value\n";
            foreach my $p (@unique_plot_names) {
                foreach my $t (@sorted_trait_names_original) {
                    if ($statistics_select eq 'sommer_grm_spatial_genetic_blups') {
                        my @row = ("phenotype_".$trait_name_encoder{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $phenotype_data{$p}->{$t});
                        my $line = join ',', @row;
                        print $F_pheno "$line\n";
                    }
                    elsif ($statistics_select eq 'sommer_grm_temporal_random_regression_dap_genetic_blups' || $statistics_select eq 'sommer_grm_temporal_random_regression_gdd_genetic_blups' || $statistics_select eq 'blupf90_grm_random_regression_gdd_blups' || $statistics_select eq 'blupf90_grm_random_regression_dap_blups' || $statistics_select eq 'airemlf90_grm_random_regression_gdd_blups' || $statistics_select eq 'airemlf90_grm_random_regression_dap_blups') {
                        my @row = ("phenotype_dap".$t, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $phenotype_data{$p}->{$t});
                        my $line = join ',', @row;
                        print $F_pheno "$line\n";
                    }
                }
            }
        close($F_pheno);

        my ($effects_heatmap_tempfile_fh, $effects_heatmap_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
        open(my $F_eff, ">", $effects_heatmap_tempfile) || die "Can't open file ".$effects_heatmap_tempfile;
            print $F_eff "trait_type,row,col,value\n";
            foreach my $p (@unique_plot_names) {
                foreach my $t (@sorted_trait_names_original) {
                    if ($statistics_select eq 'sommer_grm_spatial_genetic_blups') {
                        my @row = ("effect_".$trait_name_encoder{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $result_blup_spatial_data->{$p}->{$t}->[0]);
                        my $line = join ',', @row;
                        print $F_eff "$line\n";
                    }
                    elsif ($statistics_select eq 'sommer_grm_temporal_random_regression_dap_genetic_blups' || $statistics_select eq 'sommer_grm_temporal_random_regression_gdd_genetic_blups' || $statistics_select eq 'blupf90_grm_random_regression_gdd_blups' || $statistics_select eq 'blupf90_grm_random_regression_dap_blups' || $statistics_select eq 'airemlf90_grm_random_regression_gdd_blups' || $statistics_select eq 'airemlf90_grm_random_regression_dap_blups') {
                        my @row = ("effect_".$t, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $result_blup_pe_data_delta->{$p}->{$t}->[0]);
                        my $line = join ',', @row;
                        print $F_eff "$line\n";
                    }
                }
            }
        close($F_eff);

        $env_effects_figure_tempfile_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
        $env_effects_figure_tempfile_string .= '.png';
        my $env_effects_figure_tempfile = $c->config->{basepath}."/".$env_effects_figure_tempfile_string;

        my $output_plot_row = 'row';
        my $output_plot_col = 'col';
        if ($max_col > $max_row) {
            $output_plot_row = 'col';
            $output_plot_col = 'row';
        }

        my $cmd_spatialfirst_plot = 'R -e "library(data.table); library(ggplot2); library(dplyr); library(viridis); library(GGally); library(gridExtra);
        mat_pheno <- fread(\''.$phenotypes_original_heatmap_tempfile.'\', header=TRUE, sep=\',\');
        mat_eff <- fread(\''.$effects_heatmap_tempfile.'\', header=TRUE, sep=\',\');
        options(device=\'png\');
        par();
        gg <- ggplot(mat_pheno, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
            geom_tile() +
            scale_fill_viridis(discrete=FALSE) +
            coord_equal() +
            facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names).');
        gg_eff <- ggplot(mat_eff, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
            geom_tile() +
            scale_fill_viridis(discrete=FALSE) +
            coord_equal() +
            facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names).');
        ggsave(\''.$env_effects_figure_tempfile.'\', arrangeGrob(gg, gg_eff, nrow=2), device=\'png\', width=20, height=20, units=\'in\');
        "';
        # print STDERR Dumper $cmd;
        my $status_spatialfirst_plot = system("$cmd_spatialfirst_plot > /dev/null");
    }

    $c->stash->{rest} = {
        results => \@results,
        result_blup_genetic_data => $result_blup_data,
        result_blup_spatial_data => $result_blup_spatial_data,
        result_blup_pe_data => $result_blup_pe_data,
        result_residual_data => $result_residual_data,
        result_fitted_data => $result_fitted_data,
        unique_traits => \@sorted_trait_names,
        unique_residual_traits => \@sorted_residual_trait_names,
        unique_accessions => \@unique_accession_names,
        unique_plots => \@unique_plot_names,
        statistics_select => $statistics_select,
        grm_file => $grm_file,
        stats_tempfile => $stats_tempfile,
        blupf90_grm_file => $grm_rename_tempfile,
        blupf90_param_file => $parameter_tempfile,
        blupf90_training_file => $stats_tempfile_2,
        blupf90_permanent_environment_structure_file => $permanent_environment_structure_tempfile,
        yhat_residual_tempfile => $yhat_residual_tempfile,
        rr_genetic_coefficients => $coeff_genetic_tempfile,
        rr_pe_coefficients => $coeff_pe_tempfile,
        blupf90_solutions => $blupf90_solutions_tempfile,
        stats_out_tempfile => $stats_out_tempfile,
        stats_out_tempfile_string => $stats_out_tempfile_string,
        stats_out_htp_rel_tempfile_out_string => $stats_out_htp_rel_tempfile_out_string,
        stats_out_tempfile_col => $stats_out_tempfile_col,
        stats_out_tempfile_row => $stats_out_tempfile_row,
        statistical_ontology_term => $statistical_ontology_term,
        analysis_result_values_type => $analysis_result_values_type,
        analysis_model_type => $statistics_select,
        analysis_model_language => $analysis_model_language,
        application_name => "NickMorales Mixed Models",
        application_version => "V1.01",
        analysis_model_training_data_file_type => $analysis_model_training_data_file_type,
        field_trial_design => $field_trial_design,
        sum_square_residual => $model_sum_square_residual,
        trait_composing_info => \%trait_composing_info,
        genetic_effects_line_plot => $genetic_effects_figure_tempfile_string,
        env_effects_heatmap_plot => $env_effects_figure_tempfile_string
    };
}

sub _drone_imagery_interactive_get_gps {
    my $c = shift;
    my $schema = shift;
    my $drone_run_project_id = shift;
    my $flight_pass_counter = shift;

    my $saved_image_stacks_rotated_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_raw_images_saved_micasense_stacks_rotated', 'project_property')->cvterm_id();
    my $saved_micasense_stacks_rotated_json = $schema->resultset("Project::Projectprop")->find({
        project_id => $drone_run_project_id,
        type_id => $saved_image_stacks_rotated_type_id
    });
    my $saved_micasense_stacks_rotated_full_separated;
    my $saved_micasense_stacks_rotated_full;
    my $saved_micasense_stacks_rotated;
    if ($saved_micasense_stacks_rotated_json) {
        $saved_micasense_stacks_rotated_full = decode_json $saved_micasense_stacks_rotated_json->value();
        $saved_micasense_stacks_rotated_full_separated = $saved_micasense_stacks_rotated_full;
        $saved_micasense_stacks_rotated = $saved_micasense_stacks_rotated_full->{$flight_pass_counter};
    }
    # print STDERR Dumper $saved_micasense_stacks_rotated_full;
    # print STDERR Dumper $saved_micasense_stacks_rotated;

    my $saved_image_stacks_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_raw_images_saved_micasense_stacks_separated', 'project_property')->cvterm_id();
    my $saved_micasense_stacks_json = $schema->resultset("Project::Projectprop")->find({
        project_id => $drone_run_project_id,
        type_id => $saved_image_stacks_type_id
    });
    my $saved_micasense_stacks_full_separated;
    my $saved_micasense_stacks_full;
    my $saved_micasense_stacks;
    if ($saved_micasense_stacks_json) {
        $saved_micasense_stacks_full = decode_json $saved_micasense_stacks_json->value();
        $saved_micasense_stacks_full_separated = $saved_micasense_stacks_full;
        $saved_micasense_stacks = $saved_micasense_stacks_full->{$flight_pass_counter};
    }
    # print STDERR Dumper $saved_micasense_stacks;

    my $is_rotated;
    if ($saved_micasense_stacks_rotated) {
        $saved_micasense_stacks_full = $saved_micasense_stacks_rotated_full;
        $saved_micasense_stacks = $saved_micasense_stacks_rotated;
        $is_rotated = 1;
    }
    my @saved_micasense_stacks_values = values %$saved_micasense_stacks;

    my $max_flight_pass_counter = keys %$saved_micasense_stacks_full_separated;

    my $all_passes_rotated;
    my $all_passes_rotated_one_missing;
    for (1 .. $max_flight_pass_counter) {
        if (!$saved_micasense_stacks_rotated_full_separated->{$_}) {
            $all_passes_rotated_one_missing = 1;
        }
    }
    if (!$all_passes_rotated_one_missing) {
        $all_passes_rotated = 1;
    }

    my $saved_gps_positions_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_raw_images_saved_gps_pixel_positions', 'project_property')->cvterm_id();
    my $saved_gps_positions_json = $schema->resultset("Project::Projectprop")->find({
        project_id => $drone_run_project_id,
        type_id => $saved_gps_positions_type_id
    });
    my $saved_gps_positions;
    if ($saved_gps_positions_json) {
        $saved_gps_positions = decode_json $saved_gps_positions_json->value();
        $saved_gps_positions = $saved_gps_positions->{$flight_pass_counter};
    }

    my $first_image = SGN::Image->new( $schema->storage->dbh, $saved_micasense_stacks_values[0]->[3]->{image_id}, $c );
    my $first_image_url = $first_image->get_image_url('original_converted');
    my $first_image_fullpath = $first_image->get_filename('original_converted', 'full');
    my @size = imgsize($first_image_fullpath);
    my $width = $size[0];
    my $length = $size[1];

    my %gps_images;
    my %gps_images_rounded;
    my %longitudes;
    my %longitudes_rounded;
    my %latitudes;
    my %latitudes_rounded;
    my $max_longitude = -1000000;
    my $min_longitude = 1000000;
    my $max_latitude = -1000000;
    my $min_latitude = 1000000;
    my %latitude_rounded_map;
    my %longitude_rounded_map;

    # print STDERR Dumper $saved_micasense_stacks;

    foreach (sort {$a <=> $b} keys %$saved_micasense_stacks) {
        my $image_ids_array = $saved_micasense_stacks->{$_};
        my $nir_image = $image_ids_array->[3];
        my $latitude_raw = $nir_image->{latitude};
        my $longitude_raw = $nir_image->{longitude};

        if ($latitude_raw > $max_latitude) {
            $max_latitude = $latitude_raw;
        }
        if ($longitude_raw > $max_longitude) {
            $max_longitude = $longitude_raw;
        }
        if ($latitude_raw < $min_latitude) {
            $min_latitude = $latitude_raw;
        }
        if ($longitude_raw < $min_longitude) {
            $min_longitude = $longitude_raw;
        }

        my $latitude_rounded = nearest(0.0001,$latitude_raw);
        my $longitude_rounded = nearest(0.0001,$longitude_raw);

        $longitudes{$longitude_raw}++;
        $longitudes_rounded{$longitude_rounded}++;
        $latitudes{$latitude_raw}++;
        $latitudes_rounded{$latitude_rounded}++;

        $latitude_rounded_map{$latitude_raw} = $latitude_rounded;
        $longitude_rounded_map{$longitude_raw} = $longitude_rounded;

        my @rotated_stack_image_ids;
        foreach (@$image_ids_array) {
            push @rotated_stack_image_ids, $_->{rotated_image_id};
        }

        my $nir_image_id = $nir_image->{image_id};

        my $image = SGN::Image->new( $schema->storage->dbh, $nir_image_id, $c );
        my $image_url = $image->get_image_url('original_converted');
        my $image_fullpath = $image->get_filename('original_converted', 'full');

        $gps_images{$latitude_raw}->{$longitude_raw} = {
            nir_image_id => $nir_image_id,
            d3_rotate_angle => $nir_image->{d3_rotate_angle},
            rotated_bound => $nir_image->{rotated_bound},
            rotated_bound_translated => $nir_image->{rotated_bound_translated},
            rotated_image_ids => \@rotated_stack_image_ids,
            image_url => $image_url,
            image_size => [$width, $length],
            altitude => $nir_image->{altitude},
            x_pos => $nir_image->{x_pos},
            y_pos => $nir_image->{y_pos},
            latitude => $latitude_raw,
            longitude => $longitude_raw
        };

        push @{$gps_images_rounded{$latitude_rounded}->{$longitude_rounded}}, {
            nir_image_id => $nir_image_id,
            d3_rotate_angle => $nir_image->{d3_rotate_angle},
            rotated_bound => $nir_image->{rotated_bound},
            rotated_bound_translated => $nir_image->{rotated_bound_translated},
            rotated_image_ids => \@rotated_stack_image_ids,
            image_url => $image_url,
            image_size => [$width, $length],
            altitude => $nir_image->{altitude},
            x_pos => $nir_image->{x_pos},
            y_pos => $nir_image->{y_pos},
            latitude => $latitude_raw,
            longitude => $longitude_raw
        };
    }
    # print STDERR Dumper \%longitudes;
    # print STDERR Dumper \%latitudes;

    my %latitude_rounded_map_ordinal;
    my %longitude_rounded_map_ordinal;
    my @latitudes_sorted = sort {$a <=> $b} keys %latitudes;
    my @latitudes_rounded_sorted = sort {$a <=> $b} keys %latitudes_rounded;
    my @longitudes_sorted = sort {$a <=> $b} keys %longitudes;
    my @longitudes_rounded_sorted = sort {$a <=> $b} keys %longitudes_rounded;

    my $lat_index = 1;
    foreach (@latitudes_rounded_sorted) {
        $latitude_rounded_map_ordinal{$_} = $lat_index;
        $lat_index++;
    }
    my $long_index = 1;
    foreach (@longitudes_rounded_sorted) {
        $longitude_rounded_map_ordinal{$_} = $long_index;
        $long_index++;
    }

    while (my($latitude_raw, $latitude_rounded) = each %latitude_rounded_map) {
        $latitude_rounded_map{$latitude_raw} = $latitude_rounded_map_ordinal{$latitude_rounded};
    }
    while (my($longitude_raw, $longitude_rounded) = each %longitude_rounded_map) {
        $longitude_rounded_map{$longitude_raw} = $longitude_rounded_map_ordinal{$longitude_rounded};
    }

    my $min_x_val = 100000000;
    my $min_y_val = 100000000;
    my $max_x_val = 0;
    my $max_y_val = 0;
    my $x_range = 0;
    my $y_range = 0;
    my $no_x_pos = 1;
    if ($saved_gps_positions) {
        while (my ($l, $lo) = each %$saved_gps_positions) {
            foreach my $v (values %$lo) {
                if ($v->{x_pos} && $v->{y_pos}) {
                    $no_x_pos = 0;
                    my $x_val = $v->{x_pos};
                    my $y_val = $v->{y_pos};
                    if ($x_val < $min_x_val) {
                        $min_x_val = $x_val;
                    }
                    if ($y_val < $min_y_val) {
                        $min_y_val = $y_val;
                    }
                    if ($x_val > $max_x_val) {
                        $max_x_val = $x_val;
                    }
                    if ($y_val > $max_y_val) {
                        $max_y_val = $y_val;
                    }
                }
            }
        }
        if ($no_x_pos == 0) {
            $x_range = $max_x_val - $min_x_val + $width;
            $y_range = $max_y_val - $min_y_val + $length;
        }
    }

    my $x_factor = 10000000;
    my $y_factor = 16000000;
    if ($x_range != 0) {
        $x_range = $x_range + 1.2*$width;
    } else {
        $x_range = ($max_longitude - $min_longitude)*100*$x_factor + 1.2*$width;
    }
    if ($y_range != 0) {
        $y_range = $y_range + 1.2*$length;
    } else {
        $y_range = ($max_latitude - $min_latitude)*3*$y_factor + 1.2*$length;
    }

    return {
        success => 1,
        longitudes => \@longitudes_sorted,
        longitudes_rounded => \@longitudes_rounded_sorted,
        longitude_rounded_map => \%longitude_rounded_map,
        latitudes => \@latitudes_sorted,
        latitudes_rounded => \@latitudes_rounded_sorted,
        latitude_rounded_map => \%latitude_rounded_map,
        saved_micasense_stacks => $saved_micasense_stacks,
        saved_micasense_stacks_full => $saved_micasense_stacks_full,
        saved_micasense_stacks_rotated_full_separated => $saved_micasense_stacks_rotated_full_separated,
        gps_images => \%gps_images,
        gps_images_rounded => \%gps_images_rounded,
        saved_gps_positions => $saved_gps_positions,
        image_width => $width,
        image_length => $length,
        min_latitude => $min_latitude,
        min_longitude => $min_longitude,
        max_latitude => $max_latitude,
        max_longitude => $max_longitude,
        x_range => $x_range,
        y_range => $y_range,
        x_factor => $x_factor,
        y_factor => $y_factor,
        is_rotated => $is_rotated,
        all_passes_rotated => $all_passes_rotated,
        max_flight_pass_counter => $max_flight_pass_counter
    };
}

sub drone_imagery_separate_gps : Path('/api/drone_imagery/separate_drone_imagery_gps') : ActionClass('REST') { }
sub drone_imagery_separate_gps_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    print STDERR Dumper $c->req->params();
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $sp_person_id);
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema", undef, $sp_person_id);
    my $people_schema = $c->dbic_schema("CXGN::People::Schema", undef, $sp_person_id);
    my $drone_run_project_id = $c->req->param("drone_run_project_id");

    my $saved_image_stacks_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_raw_images_saved_micasense_stacks', 'project_property')->cvterm_id();
    my $saved_image_stacks_separated_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_raw_images_saved_micasense_stacks_separated', 'project_property')->cvterm_id();

    my $saved_micasense_stacks_json = $schema->resultset("Project::Projectprop")->find({
        project_id => $drone_run_project_id,
        type_id => $saved_image_stacks_type_id
    });
    my $saved_micasense_stacks;
    if ($saved_micasense_stacks_json) {
        $saved_micasense_stacks = decode_json $saved_micasense_stacks_json->value();
    }

    my $saved_separated_micasense_stacks_json = $schema->resultset("Project::Projectprop")->find({
        project_id => $drone_run_project_id,
        type_id => $saved_image_stacks_separated_type_id
    });
    my $saved_micasense_stacks_separated;
    if ($saved_separated_micasense_stacks_json) {
        $saved_micasense_stacks_separated = decode_json $saved_separated_micasense_stacks_json->value();
    }

    # print STDERR Dumper $saved_micasense_stacks;
    my %pass_micasense_stacks;
    if (!$saved_micasense_stacks_separated) {

        my $check_change_lat = abs($saved_micasense_stacks->{2}->[3]->{latitude} - $saved_micasense_stacks->{0}->[3]->{latitude});
        my $check_change_long = abs($saved_micasense_stacks->{2}->[3]->{longitude} - $saved_micasense_stacks->{0}->[3]->{longitude});
        my $flight_dir = "latitude";
        if ($check_change_long > $check_change_lat) {
            $flight_dir = "longitude";
        }
        my $flight_dir_sign = 1;
        if ($saved_micasense_stacks->{0}->[3]->{$flight_dir} - $saved_micasense_stacks->{1}->[3]->{$flight_dir} < 0) {
            $flight_dir_sign = -1;
        }

        my $flight_pass_counter = 1;
        foreach (sort {$a <=> $b} keys %$saved_micasense_stacks) {
            my $image_ids_array = $saved_micasense_stacks->{$_};
            my $nir_image = $image_ids_array->[3];
            my $latitude_raw = $nir_image->{latitude};
            my $longitude_raw = $nir_image->{longitude};

            my $flight_dir_pos1 = $saved_micasense_stacks->{$_}->[3]->{$flight_dir};
            my $flight_dir_pos2 = $saved_micasense_stacks->{$_+1}->[3]->{$flight_dir};
            if ($flight_dir_pos2) {
                my $flight_dir_sign_check = 1;
                if ($flight_dir_pos1 - $flight_dir_pos2 < 0) {
                    $flight_dir_sign_check = -1;
                }

                if ($flight_dir_sign_check != $flight_dir_sign) {
                    $flight_pass_counter++;
                    $flight_dir_sign = $flight_dir_sign_check;
                }
            }
            $pass_micasense_stacks{$flight_pass_counter}->{$_} = $image_ids_array;
        }

        my $saved_micasense_stacks_separated_json = $schema->resultset('Project::Projectprop')->update_or_create({
            type_id=>$saved_image_stacks_separated_type_id,
            project_id=>$drone_run_project_id,
            rank=>0,
            value=>encode_json \%pass_micasense_stacks
        },
        {
            key=>'projectprop_c1'
        });
    }
    else {
        %pass_micasense_stacks = %$saved_micasense_stacks_separated;
    }

    my @results;
    foreach my $flight_pass_counter (sort keys %pass_micasense_stacks) {
        push @results, [$flight_pass_counter, scalar(keys %{$pass_micasense_stacks{$flight_pass_counter}})];
    }

    $c->stash->{rest} = { success => 1, results => \@results, pass_micasense_stacks => \%pass_micasense_stacks };
}

sub drone_imagery_get_gps : Path('/api/drone_imagery/get_drone_imagery_gps') : ActionClass('REST') { }
sub drone_imagery_get_gps_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    print STDERR Dumper $c->req->params();
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $sp_person_id);
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema", undef, $sp_person_id);
    my $people_schema = $c->dbic_schema("CXGN::People::Schema", undef, $sp_person_id);
    my $drone_run_project_id = $c->req->param("drone_run_project_id");
    my $flight_pass_counter = $c->req->param("flight_pass_counter");

    my $return = _drone_imagery_interactive_get_gps($c, $schema, $drone_run_project_id, $flight_pass_counter);

    $c->stash->{rest} = $return;
}

sub drone_imagery_check_gps_images_rotation : Path('/api/drone_imagery/check_gps_images_rotation') : ActionClass('REST') { }
sub drone_imagery_check_gps_images_rotation_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $drone_run_project_id = $c->req->param("drone_run_project_id");
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $drone_run_rotate_process_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_raw_images_rotation_occuring', 'project_property')->cvterm_id();
    my $drone_run_rotate_process = $schema->resultset('Project::Projectprop')->find({
        type_id=>$drone_run_rotate_process_type_id,
        project_id=>$drone_run_project_id,
    });

    $c->stash->{rest} = {is_rotating => $drone_run_rotate_process->value};
}

sub drone_imagery_update_gps_images_rotation : Path('/api/drone_imagery/update_gps_images_rotation') : ActionClass('REST') { }
sub drone_imagery_update_gps_images_rotation_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    print STDERR Dumper $c->req->params();
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $sp_person_id);
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema", undef, $sp_person_id);
    my $people_schema = $c->dbic_schema("CXGN::People::Schema", undef, $sp_person_id);
    my $drone_run_project_id = $c->req->param("drone_run_project_id");
    my $rotate_angle = $c->req->param("rotate_angle");
    my $rotate_angle_neg = $rotate_angle*-1;
    my $nir_image_ids = decode_json $c->req->param("nir_image_ids");
    my $flight_pass_counter = $c->req->param("flight_pass_counter");

    my $rotate_radians = $rotate_angle * 0.0174533;
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $return = _drone_imagery_interactive_get_gps($c, $schema, $drone_run_project_id, $flight_pass_counter);
    my $is_rotated = $return->{is_rotated};
    my $max_flight_pass_counter = $return->{max_flight_pass_counter};

    my %rotated_saved_micasense_stacks_full;
    if ($is_rotated) {
        %rotated_saved_micasense_stacks_full = %{$return->{saved_micasense_stacks_full}};
        print STDERR "ALREADY ROTATED\n";
    } else {

        my $drone_run_rotate_process_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_raw_images_rotation_occuring', 'project_property')->cvterm_id();
        my $drone_run_rotate_process = $schema->resultset('Project::Projectprop')->update_or_create({
            type_id=>$drone_run_rotate_process_type_id,
            project_id=>$drone_run_project_id,
            rank=>0,
            value=>1
        },
        {
            key=>'projectprop_c1'
        });

        my %rotated_saved_micasense_stacks;
        my $saved_micasense_stacks = $return->{saved_micasense_stacks};
        # my $saved_micasense_stacks_full = $return->{saved_micasense_stacks_rotated_full_separated};

        foreach my $stack_key (sort {$a <=> $b} keys %$saved_micasense_stacks) {
            if (!$saved_micasense_stacks->{$stack_key}->[0]) {
                delete $saved_micasense_stacks->{$stack_key};
                print STDERR "REMOVING KEY $stack_key\n";
            }
        }

        # print STDERR Dumper $saved_micasense_stacks;
        my @saved_micasense_stacks_values = values %$saved_micasense_stacks;

        my $first_image = SGN::Image->new( $schema->storage->dbh, $saved_micasense_stacks_values[0]->[3]->{image_id}, $c );
        my $first_image_url = $first_image->get_image_url('original_converted');
        my $first_image_fullpath = $first_image->get_filename('original_converted', 'full');
        my @size = imgsize($first_image_fullpath);
        my $width = $size[0];
        my $length = $size[1];
        my $cx = $width/2;
        my $cy = $length/2;

        my $number_system_cores = `getconf _NPROCESSORS_ONLN` or die "Could not get number of system cores!\n";
        chomp($number_system_cores);
        print STDERR "NUMCORES $number_system_cores\n";

        my %gps_images;
        my $dir = $c->tempfiles_subdir('/drone_imagery_rotate');
        my $bulk_input_temp_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_rotate/bulkinputXXXX');

        open(my $F, ">", $bulk_input_temp_file) || die "Can't open file ".$bulk_input_temp_file;

        my %input_bulk_hash;
        foreach my $stack_key (sort {$a <=> $b} keys %$saved_micasense_stacks) {
            my $image_ids_array = $saved_micasense_stacks->{$stack_key};

            my $index_counter = 0;
            foreach my $i (@$image_ids_array) {

                my $latitude_raw = $i->{latitude};
                my $longitude_raw = $i->{longitude};
                my $altitude_raw = $i->{altitude};
                my $image_id = $i->{image_id};

                if ($image_id) {
                    my $archive_rotate_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_rotate/imageXXXX');
                    $archive_rotate_temp_image .= '.png';

                    my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
                    my $image_fullpath = $image->get_filename('original_converted', 'full');

                    print $F "$image_fullpath\t$archive_rotate_temp_image\t$rotate_angle_neg\n";

                    $input_bulk_hash{$image_id} = {
                        stack_key => $stack_key,
                        latitude_raw => $latitude_raw,
                        longitude_raw => $longitude_raw,
                        altitude_raw => $altitude_raw,
                        rotated_temp_image => $archive_rotate_temp_image,
                        index_counter => $index_counter
                    };
                }
                $index_counter++;
            }
        }
        close($F);

        my $cmd = $c->config->{python_executable}.' '.$c->config->{rootpath}.'/DroneImageScripts/ImageProcess/RotateBulk.py --input_path \''.$bulk_input_temp_file.'\'';
        print STDERR Dumper $cmd;
        my $status = system("$cmd > /dev/null");

        my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'rotated_stitched_temporary_drone_imagery', 'project_md_image')->cvterm_id();
        while ( my ($image_id, $i_obj) = each %input_bulk_hash) {
            my $stack_key = $i_obj->{stack_key};
            my $latitude_raw = $i_obj->{latitude_raw};
            my $longitude_raw = $i_obj->{longitude_raw};
            my $altitude_raw = $i_obj->{altitude_raw};
            my $index_counter = $i_obj->{index_counter};
            my $archive_rotate_temp_image = $i_obj->{rotated_temp_image};

            my $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
            my $md5checksum = $image->calculate_md5sum($archive_rotate_temp_image);
            my $q = "SELECT md_image.image_id FROM metadata.md_image AS md_image
                JOIN phenome.project_md_image AS project_md_image ON(project_md_image.image_id = md_image.image_id)
                WHERE md_image.obsolete = 'f' AND md_image.md5sum = ? AND project_md_image.type_id = ? AND project_md_image.project_id = ?;";
            my $h = $schema->storage->dbh->prepare($q);
            $h->execute($md5checksum, $linking_table_type_id, $drone_run_project_id);
            my ($saved_image_id) = $h->fetchrow_array();

            my $rotated_image_fullpath;
            my $rotated_image_id;
            my $rotated_image_url;
            if ($saved_image_id) {
                print STDERR Dumper "Image $archive_rotate_temp_image has already been added to the database and will not be added again.";
                $image = SGN::Image->new( $schema->storage->dbh, $saved_image_id, $c );
                $rotated_image_fullpath = $image->get_filename('original_converted', 'full');
                $rotated_image_url = $image->get_image_url('original');
                $rotated_image_id = $image->get_image_id();
            } else {
                $image->set_sp_person_id($user_id);
                my $ret = $image->process_image($archive_rotate_temp_image, 'project', $drone_run_project_id, $linking_table_type_id);
                $rotated_image_fullpath = $image->get_filename('original_converted', 'full');
                $rotated_image_url = $image->get_image_url('original');
                $rotated_image_id = $image->get_image_id();
            }

            my $temp_x1 = 0 - $cx;
            my $temp_y1 = $length - $cy;
            my $temp_x2 = $width - $cx;
            my $temp_y2 = $length - $cy;
            my $temp_x3 = $width - $cx;
            my $temp_y3 = 0 - $cy;
            my $temp_x4 = 0 - $cx;
            my $temp_y4 = 0 - $cy;

            my $rotated_x1 = $temp_x1*cos($rotate_radians) - $temp_y1*sin($rotate_radians);
            my $rotated_y1 = $temp_x1*sin($rotate_radians) + $temp_y1*cos($rotate_radians);
            my $rotated_x2 = $temp_x2*cos($rotate_radians) - $temp_y2*sin($rotate_radians);
            my $rotated_y2 = $temp_x2*sin($rotate_radians) + $temp_y2*cos($rotate_radians);
            my $rotated_x3 = $temp_x3*cos($rotate_radians) - $temp_y3*sin($rotate_radians);
            my $rotated_y3 = $temp_x3*sin($rotate_radians) + $temp_y3*cos($rotate_radians);
            my $rotated_x4 = $temp_x4*cos($rotate_radians) - $temp_y4*sin($rotate_radians);
            my $rotated_y4 = $temp_x4*sin($rotate_radians) + $temp_y4*cos($rotate_radians);

            $rotated_x1 = $rotated_x1 + $cx;
            $rotated_y1 = $rotated_y1 + $cy;
            $rotated_x2 = $rotated_x2 + $cx;
            $rotated_y2 = $rotated_y2 + $cy;
            $rotated_x3 = $rotated_x3 + $cx;
            $rotated_y3 = $rotated_y3 + $cy;
            $rotated_x4 = $rotated_x4 + $cx;
            $rotated_y4 = $rotated_y4 + $cy;

            my $x_pos = ($longitude_raw - $return->{min_longitude})*$return->{x_factor};
            my $y_pos = $return->{y_range} - ($latitude_raw - $return->{min_latitude})*$return->{y_factor} - $return->{image_length};

            my $rotated_bound = [[$rotated_x1, $rotated_y1], [$rotated_x2, $rotated_y2], [$rotated_x3, $rotated_y3], [$rotated_x4, $rotated_y4]];
            my $rotated_bound_translated = [[$rotated_x1 + $x_pos, $rotated_y1 + $y_pos], [$rotated_x2 + $x_pos, $rotated_y2 + $y_pos], [$rotated_x3 + $x_pos, $rotated_y3 + $y_pos], [$rotated_x4 + $x_pos, $rotated_y4 + $y_pos]];

            $rotated_saved_micasense_stacks{$stack_key}->[$index_counter] = {
                rotated_image_id => $rotated_image_id,
                d3_rotate_angle => $rotate_angle,
                image_id => $image_id,
                longitude => $longitude_raw,
                latitude => $latitude_raw,
                altitude => $altitude_raw,
                rotated_bound => $rotated_bound,
                rotated_bound_translated => $rotated_bound_translated,
                x_pos => $x_pos,
                y_pos => $y_pos
            };
        }

        # print STDERR Dumper \%rotated_saved_micasense_stacks;

        my $saved_image_stacks_rotated_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_raw_images_saved_micasense_stacks_rotated', 'project_property')->cvterm_id();
        my $saved_micasense_stacks_rotated_json = $schema->resultset("Project::Projectprop")->find({
            project_id => $drone_run_project_id,
            type_id => $saved_image_stacks_rotated_type_id
        });
        my $saved_micasense_stacks_full;
        if ($saved_micasense_stacks_rotated_json) {
            $saved_micasense_stacks_full = decode_json $saved_micasense_stacks_rotated_json->value();
        }

        $saved_micasense_stacks_full->{$flight_pass_counter} = \%rotated_saved_micasense_stacks;
        %rotated_saved_micasense_stacks_full = %$saved_micasense_stacks_full;

        my $drone_run_band_rotate_angle = $schema->resultset('Project::Projectprop')->update_or_create({
            type_id=>$saved_image_stacks_rotated_type_id,
            project_id=>$drone_run_project_id,
            rank=>0,
            value=>encode_json \%rotated_saved_micasense_stacks_full
        },
        {
            key=>'projectprop_c1'
        });

        my $return = _perform_match_raw_images_sequential($c, $schema, $metadata_schema, $phenome_schema, $people_schema, $drone_run_project_id, $nir_image_ids, $flight_pass_counter, $user_id, $user_name, $user_role);
        my $saved_gps_positions_full = $return->{saved_gps_positions_full};
        my $message = $return->{message};
    };

    # my $saved_gps_positions_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_raw_images_saved_gps_pixel_positions', 'project_property')->cvterm_id();
    # my $saved_gps_positions_json = $schema->resultset("Project::Projectprop")->find({
    #     project_id => $drone_run_project_id,
    #     type_id => $saved_gps_positions_type_id
    # });
    # if ($saved_gps_positions_json) {
    #     $saved_gps_positions_json->delete();
    # }

    $c->stash->{rest} = {
        success => 1,
        gps_images => \%rotated_saved_micasense_stacks_full
    };
}

sub drone_imagery_match_and_align_two_images : Path('/api/drone_imagery/match_and_align_two_images') : ActionClass('REST') { }
sub drone_imagery_match_and_align_two_images_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    print STDERR Dumper $c->req->params();
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $sp_person_id);
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema", undef, $sp_person_id);
    my $people_schema = $c->dbic_schema("CXGN::People::Schema", undef, $sp_person_id);
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $drone_run_project_id = $c->req->param('drone_run_project_id');
    my $image_id1 = $c->req->param('image_id1');
    my $image_id2 = $c->req->param('image_id2');

    my $image1 = SGN::Image->new( $schema->storage->dbh, $image_id1, $c );
    my $image1_url = $image1->get_image_url("original");
    my $image1_fullpath = $image1->get_filename('original_converted', 'full');
    my $image2 = SGN::Image->new( $schema->storage->dbh, $image_id2, $c );
    my $image2_url = $image2->get_image_url("original");
    my $image2_fullpath = $image2->get_filename('original_converted', 'full');

    my $dir = $c->tempfiles_subdir('/drone_imagery_align');
    my $rotated_temp_image1 = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_align/imageXXXX').'.png';
    my $rotated_temp_image2 = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_align/imageXXXX').'.png';
    my $match_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_align/imageXXXX').'.png';
    my $align_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_align/imageXXXX').'.png';
    my $align_match_temp_results = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_align/imageXXXX');
    my $align_match_temp_results_2 = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_align/imageXXXX');

    my $cmd = $c->config->{python_executable}.' '.$c->config->{rootpath}.'/DroneImageScripts/ImageProcess/MatchAndAlignImages.py --image_path1 \''.$image1_fullpath.'\' --image_path2 \''.$image2_fullpath.'\' --outfile_match_path \''.$match_temp_image.'\' --outfile_path \''.$align_temp_image.'\' --results_outfile_path_src \''.$align_match_temp_results.'\' --results_outfile_path_dst \''.$align_match_temp_results_2.'\' ';
    print STDERR Dumper $cmd;
    my $status = system("$cmd > /dev/null");

    my @match_points_src;
    my $csv = Text::CSV->new({ sep_char => ',' });
    open(my $fh, '<', $align_match_temp_results)
        or die "Could not open file '$align_match_temp_results' $!";

        while ( my $row = <$fh> ){
            my @columns;
            if ($csv->parse($row)) {
                @columns = $csv->fields();
            }
            push @match_points_src, \@columns;
        }
    close($fh);

    my @match_points_dst;
    open(my $fh2, '<', $align_match_temp_results_2)
        or die "Could not open file '$align_match_temp_results_2' $!";

        while ( my $row = <$fh2> ){
            my @columns;
            if ($csv->parse($row)) {
                @columns = $csv->fields();
            }
            push @match_points_dst, \@columns;
        }
    close($fh2);

    my $match_linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'standard_process_interactive_match_temporary_drone_imagery', 'project_md_image')->cvterm_id();
    my $align_linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'standard_process_interactive_align_temporary_drone_imagery', 'project_md_image')->cvterm_id();

    my $match_image = SGN::Image->new( $schema->storage->dbh, undef, $c );
    $match_image->set_sp_person_id($user_id);
    my $ret = $match_image->process_image($match_temp_image, 'project', $drone_run_project_id, $match_linking_table_type_id);
    my $match_image_fullpath = $match_image->get_filename('original_converted', 'full');
    my $match_image_url = $match_image->get_image_url('original');
    my $match_image_id = $match_image->get_image_id();

    # my $align_image = SGN::Image->new( $schema->storage->dbh, undef, $c );
    # $align_image->set_sp_person_id($user_id);
    # my $ret_align = $align_image->process_image($align_temp_image, 'project', $drone_run_project_id, $align_linking_table_type_id);
    # my $align_image_fullpath = $align_image->get_filename('original_converted', 'full');
    # my $align_image_url = $align_image->get_image_url('original');
    # my $align_image_id = $align_image->get_image_id();

    $c->stash->{rest} = {
        success => 1,
        match_image_url => $match_image_url,
        # align_image_url => $align_image_url,
        # align_image_id => $align_image_id,
        match_points_src => \@match_points_src,
        match_points_dst => \@match_points_dst,
        image_id_src => $image_id1,
        image_id_dst => $image_id2,
    };
}

sub _drone_imagery_match_and_align_images {
    my $c = shift;
    my $schema = shift;
    my $image_id1 = shift;
    my $image_id2 = shift;
    my $gps_obj_src = shift;
    my $gps_obj_dst = shift;
    my $max_features = shift;
    my $rotate_radians = shift;
    my $total_image_count = shift;
    my $image_counter = shift;
    my $skipped_counter = shift;

    my $image1 = SGN::Image->new( $schema->storage->dbh, $image_id1, $c );
    my $image1_url = $image1->get_image_url("original");
    my $image1_fullpath = $image1->get_filename('original_converted', 'full');
    my $image2 = SGN::Image->new( $schema->storage->dbh, $image_id2, $c );
    my $image2_url = $image2->get_image_url("original");
    my $image2_fullpath = $image2->get_filename('original_converted', 'full');

    my $rotated_temp_image1 = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_align/imageXXXX').'.png';
    my $rotated_temp_image2 = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_align/imageXXXX').'.png';
    my $match_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_align/imageXXXX').'.png';
    my $align_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_align/imageXXXX').'.png';
    my $align_match_temp_results = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_align/imageXXXX');
    my $align_match_temp_results_2 = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_align/imageXXXX');

    my $cmd = $c->config->{python_executable}.' '.$c->config->{rootpath}.'/DroneImageScripts/ImageProcess/MatchAndAlignImages.py --image_path1 \''.$image1_fullpath.'\' --image_path2 \''.$image2_fullpath.'\' --outfile_match_path \''.$match_temp_image.'\' --outfile_path \''.$align_temp_image.'\' --results_outfile_path_src \''.$align_match_temp_results.'\' --results_outfile_path_dst \''.$align_match_temp_results_2.'\' --max_features \''.$max_features.'\'';
    # print STDERR Dumper $cmd;
    my $status = system("$cmd > /dev/null");

    my @match_points_src;
    my $csv = Text::CSV->new({ sep_char => ',' });
    open(my $fh, '<', $align_match_temp_results)
        or die "Could not open file '$align_match_temp_results' $!";

        while ( my $row = <$fh> ){
            my @columns;
            if ($csv->parse($row)) {
                @columns = $csv->fields();
            }
            push @match_points_src, \@columns;
        }
    close($fh);

    my @match_points_dst;
    open(my $fh2, '<', $align_match_temp_results_2)
        or die "Could not open file '$align_match_temp_results_2' $!";

        while ( my $row = <$fh2> ){
            my @columns;
            if ($csv->parse($row)) {
                @columns = $csv->fields();
            }
            push @match_points_dst, \@columns;
        }
    close($fh2);

    # my $match_image = SGN::Image->new( $schema->storage->dbh, undef, $c );
    # $match_image->set_sp_person_id($user_id);
    # my $ret = $match_image->process_image($match_temp_image, 'project', $drone_run_project_id, $match_linking_table_type_id);
    # my $match_image_fullpath = $match_image->get_filename('original_converted', 'full');
    # my $match_image_url = $match_image->get_image_url('original');
    # my $match_image_id = $match_image->get_image_id();
    # $nir_image_hash{$image_id1}->{match_image_url} = $match_image_url;

    my $x_pos_src = $gps_obj_src->{x_pos};
    my $y_pos_src = $gps_obj_src->{y_pos};
    my $x_pos_dst = $gps_obj_dst->{x_pos};
    my $y_pos_dst = $gps_obj_dst->{y_pos};

    my $src_match = $match_points_src[0];
    my $src_match_x = $src_match->[0];
    my $src_match_y = $src_match->[1];
    my $src_match_x_rotated = $src_match_x*cos($rotate_radians) - $src_match_y*sin($rotate_radians);
    my $src_match_y_rotated = $src_match_x*sin($rotate_radians) + $src_match_y*cos($rotate_radians);
    my $x_pos_match_src = $x_pos_src + $src_match_x_rotated;
    my $y_pos_match_src = $y_pos_src + $src_match_y_rotated;

    my $src_match2 = $match_points_src[1];
    my $src_match2_x = $src_match2->[0];
    my $src_match2_y = $src_match2->[1];
    my $src_match2_x_rotated = $src_match2_x*cos($rotate_radians) - $src_match2_y*sin($rotate_radians);
    my $src_match2_y_rotated = $src_match2_x*sin($rotate_radians) + $src_match2_y*cos($rotate_radians);
    my $x_pos_match2_src = $x_pos_src + $src_match2_x_rotated;
    my $y_pos_match2_src = $y_pos_src + $src_match2_y_rotated;

    my $src_match3 = $match_points_src[2];
    my $src_match3_x = $src_match3->[0];
    my $src_match3_y = $src_match3->[1];
    my $src_match3_x_rotated = $src_match3_x*cos($rotate_radians) - $src_match3_y*sin($rotate_radians);
    my $src_match3_y_rotated = $src_match3_x*sin($rotate_radians) + $src_match3_y*cos($rotate_radians);
    my $x_pos_match3_src = $x_pos_src + $src_match3_x_rotated;
    my $y_pos_match3_src = $y_pos_src + $src_match3_y_rotated;

    my $dst_match = $match_points_dst[0];
    my $dst_match_x = $dst_match->[0];
    my $dst_match_y = $dst_match->[1];
    my $dst_match_x_rotated = $dst_match_x*cos($rotate_radians) - $dst_match_y*sin($rotate_radians);
    my $dst_match_y_rotated = $dst_match_x*sin($rotate_radians) + $dst_match_y*cos($rotate_radians);
    my $x_pos_match_dst = $x_pos_match_src - $dst_match_x_rotated;
    my $y_pos_match_dst = $y_pos_match_src - $dst_match_y_rotated;

    my $dst_match2 = $match_points_dst[1];
    my $dst_match2_x = $dst_match2->[0];
    my $dst_match2_y = $dst_match2->[1];
    my $dst_match2_x_rotated = $dst_match2_x*cos($rotate_radians) - $dst_match2_y*sin($rotate_radians);
    my $dst_match2_y_rotated = $dst_match2_x*sin($rotate_radians) + $dst_match2_y*cos($rotate_radians);
    my $x_pos_match2_dst = $x_pos_match2_src - $dst_match2_x_rotated;
    my $y_pos_match2_dst = $y_pos_match2_src - $dst_match2_y_rotated;

    my $dst_match3 = $match_points_dst[2];
    my $dst_match3_x = $dst_match3->[0];
    my $dst_match3_y = $dst_match3->[1];
    my $dst_match3_x_rotated = $dst_match3_x*cos($rotate_radians) - $dst_match3_y*sin($rotate_radians);
    my $dst_match3_y_rotated = $dst_match3_x*sin($rotate_radians) + $dst_match3_y*cos($rotate_radians);
    my $x_pos_match3_dst = $x_pos_match3_src - $dst_match3_x_rotated;
    my $y_pos_match3_dst = $y_pos_match3_src - $dst_match3_y_rotated;

    my $x_pos_translation = $x_pos_dst - $x_pos_match_dst;
    my $y_pos_translation = $y_pos_dst - $y_pos_match_dst;

    my $x_pos_translation2 = $x_pos_dst - $x_pos_match2_dst;
    my $y_pos_translation2 = $y_pos_dst - $y_pos_match2_dst;

    my $x_pos_translation3 = $x_pos_dst - $x_pos_match3_dst;
    my $y_pos_translation3 = $y_pos_dst - $y_pos_match3_dst;

    my $diffx1 = $x_pos_translation - $x_pos_translation2;
    my $diffy1 = $y_pos_translation - $y_pos_translation2;

    my $diffx2 = $x_pos_translation - $x_pos_translation3;
    my $diffy2 = $y_pos_translation - $y_pos_translation3;

    my $diffx3 = $x_pos_translation3 - $x_pos_translation2;
    my $diffy3 = $y_pos_translation3 - $y_pos_translation2;

    my $p1_diff_sum = abs($diffx1) + abs($diffy1) + abs($diffx2) + abs($diffy2);
    my $p2_diff_sum = abs($diffx1) + abs($diffy1) + abs($diffx3) + abs($diffy3);
    my $p3_diff_sum = abs($diffx2) + abs($diffy2) + abs($diffx3) + abs($diffy3);
    print STDERR "P1: ".$p1_diff_sum." P2: ".$p2_diff_sum." P3: ".$p3_diff_sum."\n";
    my $total_image_count_adjusted = $total_image_count-2;
    print STDERR "Progress: $image_id1 $image_id2 : $image_counter / $total_image_count_adjusted (".$image_counter/$total_image_count_adjusted.") : $skipped_counter\n";

    my $smallest_diff;
    if ($p1_diff_sum <= $p2_diff_sum && $p1_diff_sum <= $p3_diff_sum) {
        $smallest_diff = $p1_diff_sum;
        $x_pos_match_dst = $x_pos_match_dst;
        $y_pos_match_dst = $y_pos_match_dst;
        $x_pos_match_src = $x_pos_match_src;
        $y_pos_match_src = $y_pos_match_src;
        $x_pos_translation = $x_pos_translation;
        $y_pos_translation = $y_pos_translation;
    }
    elsif ($p2_diff_sum <= $p1_diff_sum && $p2_diff_sum <= $p3_diff_sum) {
        $smallest_diff = $p2_diff_sum;
        $x_pos_match_dst = $x_pos_match2_dst;
        $y_pos_match_dst = $y_pos_match2_dst;
        $x_pos_match_src = $x_pos_match2_src;
        $y_pos_match_src = $y_pos_match2_src;
        $x_pos_translation = $x_pos_translation2;
        $y_pos_translation = $y_pos_translation2;
    }
    elsif ($p3_diff_sum <= $p1_diff_sum && $p3_diff_sum <= $p2_diff_sum) {
        $smallest_diff = $p3_diff_sum;
        $x_pos_match_dst = $x_pos_match3_dst;
        $y_pos_match_dst = $y_pos_match3_dst;
        $x_pos_match_src = $x_pos_match3_src;
        $y_pos_match_src = $y_pos_match3_src;
        $x_pos_translation = $x_pos_translation3;
        $y_pos_translation = $y_pos_translation3;
    }
    return {
        smallest_diff => $smallest_diff,
        x_pos_match_dst => $x_pos_match_dst,
        y_pos_match_dst => $y_pos_match_dst,
        x_pos_match_src => $x_pos_match_src,
        y_pos_match_src => $y_pos_match_src,
        x_pos_translation => $x_pos_translation,
        y_pos_translation => $y_pos_translation,
        match_temp_image => $match_temp_image,
        align_temp_image => $align_temp_image
    };
}

sub _perform_match_raw_images_sequential {
    my $c = shift;
    my $schema = shift;
    my $metadata_schema = shift;
    my $phenome_schema = shift;
    my $people_schema = shift;
    my $drone_run_project_id = shift;
    my $nir_image_ids = shift;
    my $flight_pass_counter = shift;
    my $user_id = shift;
    my $user_name = shift;
    my $user_role = shift;

    my $dir = $c->tempfiles_subdir('/drone_imagery_align');

    my $match_linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'standard_process_interactive_match_temporary_drone_imagery', 'project_md_image')->cvterm_id();
    my $align_linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'standard_process_interactive_align_temporary_drone_imagery', 'project_md_image')->cvterm_id();

    my $return = _drone_imagery_interactive_get_gps($c, $schema, $drone_run_project_id, $flight_pass_counter);
    my $gps_images = $return->{gps_images};
    my $gps_images_rounded = $return->{gps_images_rounded};
    my $saved_gps_positions = $return->{saved_gps_positions};
    my $longitudes = $return->{longitudes};
    my $latitudes = $return->{latitudes};
    my $width = $return->{image_width};
    my $length = $return->{image_length};
    my $max_flight_pass_counter = $return->{max_flight_pass_counter};

    my $longitudes_rounded = $return->{longitudes_rounded};
    my $longitude_rounded_map = $return->{longitude_rounded_map};
    my $latitudes_rounded = $return->{latitudes_rounded};
    my $latitude_rounded_map = $return->{latitude_rounded_map};

    # if ($saved_gps_positions && scalar (keys %$saved_gps_positions) > 0) {
    #     $gps_images = $saved_gps_positions;
    # }

    my %nir_image_hash;
    foreach my $lat (@$latitudes) {
        foreach my $long (@$longitudes) {
            if ($lat && $long) {
                my $i = $gps_images->{$lat}->{$long};
                my $nir_image_id = $i->{nir_image_id};
                if ($nir_image_id) {
                    $nir_image_hash{$nir_image_id} = $i;
                }
            }
        }
    }

    my $image_counter = 0;

    my $image_id1 = $nir_image_ids->[$image_counter];
    my $image_id2 = $nir_image_ids->[$image_counter+1];

    my $total_image_count = scalar(@$nir_image_ids);
    my $skipped_counter = 0;
    my $max_features = 1000;

    my $message = "Completed matching";

    while ($image_id1 && $image_id2) {

        my $gps_obj_src = $nir_image_hash{$image_id1};
        my $gps_obj_dst = $nir_image_hash{$image_id2};

        if ($gps_obj_src->{match_src_to} || $gps_obj_dst->{match_dst_to} || $gps_obj_dst->{match_problem} || $gps_obj_dst->{manual_match}) {
            $image_counter++;
            $image_id1 = $nir_image_ids->[$image_counter];
            $image_id2 = $nir_image_ids->[$image_counter+1];
            next;
        }

        my $latitude_src = $gps_obj_src->{latitude};
        my $longitude_src = $gps_obj_src->{longitude};
        my $latitude_dst = $gps_obj_dst->{latitude};
        my $longitude_dst = $gps_obj_dst->{longitude};

        my $rotate_radians = $nir_image_hash{$image_id2}->{d3_rotate_angle} * 0.0174533;

        my $latitude_ordinal_src = $latitude_rounded_map->{$latitude_src};
        my $longitude_ordinal_src = $longitude_rounded_map->{$longitude_src};
        my $latitude_rounded_src = $latitudes_rounded->[$latitude_ordinal_src-1];
        my $longitude_rounded_src = $longitudes_rounded->[$longitude_ordinal_src-1];

        my $latitude_ordinal_dst = $latitude_rounded_map->{$latitude_dst};
        my $longitude_ordinal_dst = $longitude_rounded_map->{$longitude_dst};
        my $latitude_rounded_dst = $latitudes_rounded->[$latitude_ordinal_dst-1];
        my $longitude_rounded_dst = $longitudes_rounded->[$longitude_ordinal_dst-1];

        my $gps_obj_src_lat_up_objects;
        if ($latitudes_rounded->[$latitude_ordinal_src-1+1]) {
            $gps_obj_src_lat_up_objects = $gps_images_rounded->{$latitudes_rounded->[$latitude_ordinal_src-1+1]}->{$longitude_rounded_src};
        }
        my $gps_obj_src_lat_down_objects;
        if ($latitudes_rounded->[$latitude_ordinal_src-1-1]) {
            $gps_obj_src_lat_down_objects = $gps_images_rounded->{$latitudes_rounded->[$latitude_ordinal_src-1-1]}->{$longitude_rounded_src};
        }
        my $gps_obj_src_long_up_objects;
        if ($longitudes_rounded->[$longitude_ordinal_src-1+1]) {
            $gps_obj_src_long_up_objects = $gps_images_rounded->{$latitude_rounded_src}->{$longitudes_rounded->[$longitude_ordinal_src-1+1]};
        }
        my $gps_obj_src_long_down_objects;
        if ($longitudes_rounded->[$longitude_ordinal_src-1-1]) {
            $gps_obj_src_long_down_objects = $gps_images_rounded->{$latitude_rounded_src}->{$longitudes_rounded->[$longitude_ordinal_src-1-1]};
        }

        my $match = _drone_imagery_match_and_align_images($c, $schema, $image_id1, $image_id2, $gps_obj_src, $gps_obj_dst, $max_features, $rotate_radians, $total_image_count, $image_counter, $skipped_counter);
        my $smallest_diff = $match->{smallest_diff};
        my $x_pos_match_dst = $match->{x_pos_match_dst};
        my $y_pos_match_dst = $match->{y_pos_match_dst};
        my $x_pos_match_src = $match->{x_pos_match_src};
        my $y_pos_match_src = $match->{y_pos_match_src};
        my $x_pos_translation = $match->{x_pos_translation};
        my $y_pos_translation = $match->{y_pos_translation};
        my $align_temp_image = $match->{align_temp_image};

        # if ($gps_obj_src_lat_up_objects) {
        #     print STDERR "LAT UP OBJS: ".scalar(@$gps_obj_src_lat_up_objects)."\n";
        #     foreach (@$gps_obj_src_lat_up_objects) {
        #         my $gps_obj_src_lat_up_image_id = $_->{nir_image_id};
        #
        #         if ($gps_obj_src_lat_up_image_id && $nir_image_hash{$gps_obj_src_lat_up_image_id} && $nir_image_hash{$gps_obj_src_lat_up_image_id}->{match_src_to}) {
        #             my $match2 = _drone_imagery_match_and_align_images($c, $schema, $gps_obj_src_lat_up_image_id, $image_id2, $nir_image_hash{$gps_obj_src_lat_up_image_id}, $gps_obj_dst, $max_features, $rotate_radians, $total_image_count, $image_counter, $skipped_counter);
        #             my $smallest_diff2 = $match2->{smallest_diff};
        #             my $x_pos_match_dst2 = $match2->{x_pos_match_dst};
        #             my $y_pos_match_dst2 = $match2->{y_pos_match_dst};
        #             my $x_pos_match_src2 = $match2->{x_pos_match_src};
        #             my $y_pos_match_src2 = $match2->{y_pos_match_src};
        #             my $x_pos_translation2 = $match2->{x_pos_translation};
        #             my $y_pos_translation2 = $match2->{y_pos_translation};
        #             my $align_temp_image2 = $match2->{align_temp_image};
        #
        #             if ($smallest_diff2 <= 50) {
        #                 $smallest_diff = ($smallest_diff + $smallest_diff2) / 2;
        #                 $x_pos_match_dst = ($x_pos_match_dst + $x_pos_match_dst2) / 2;
        #                 $y_pos_match_dst = ($y_pos_match_dst + $y_pos_match_dst2) / 2;
        #                 $x_pos_match_src = ($x_pos_match_src + $x_pos_match_src2) / 2;
        #                 $y_pos_match_src = ($y_pos_match_src + $y_pos_match_src2) / 2;
        #                 $x_pos_translation = ($x_pos_translation + $x_pos_translation2) / 2;
        #                 $y_pos_translation = ($y_pos_translation + $y_pos_translation2) / 2;
        #             }
        #         }
        #     }
        # }

        if ($smallest_diff > 35 && $skipped_counter < 2) {
            $max_features = 50000 * ($skipped_counter + 1);
            $skipped_counter++;
        }
        # elsif ($skipped_counter >= 2) {
        #     $nir_image_hash{$image_id2}->{match_problem} = 1;
        #     $image_id1 = undef;
        #     $image_id2 = undef;
        #     $message = "There was a problem matching up images. Please manually position the image outlined in red";
        # }
        else {
            $nir_image_hash{$image_id1}->{match_problem} = 0;
            $nir_image_hash{$image_id2}->{match_problem} = 0;

            if ($skipped_counter >= 2) {
                $x_pos_match_dst = $x_pos_match_dst + $width + $length;
                $y_pos_match_dst = $y_pos_match_dst + $width + $length;
                $nir_image_hash{$image_id2}->{match_problem} = 1;
            }
            $max_features = 1000;
            $skipped_counter = 0;

            # my $match_image = SGN::Image->new( $schema->storage->dbh, undef, $c );
            # $match_image->set_sp_person_id($user_id);
            # my $ret = $match_image->process_image($align_temp_image, 'project', $drone_run_project_id, $align_linking_table_type_id);
            # my $match_image_fullpath = $match_image->get_filename('original_converted', 'full');
            # my $match_image_url = $match_image->get_image_url('original');
            # my $match_image_id = $match_image->get_image_id();
            # $nir_image_hash{$image_id2}->{image_url} = $match_image_url;
            # $nir_image_hash{$image_id2}->{nir_image_id} = $match_image_id;

            $nir_image_hash{$image_id2}->{x_pos} = $x_pos_match_dst;
            $nir_image_hash{$image_id2}->{y_pos} = $y_pos_match_dst;

            $nir_image_hash{$image_id1}->{match_src_to} = $image_id2;
            $nir_image_hash{$image_id2}->{match_dst_to} = $image_id1;

            my $cx = $width/2;
            my $cy = $length/2;
            my $temp_x1 = 0 - $cx;
            my $temp_y1 = $length - $cy;
            my $temp_x2 = $width - $cx;
            my $temp_y2 = $length - $cy;
            my $temp_x3 = $width - $cx;
            my $temp_y3 = 0 - $cy;
            my $temp_x4 = 0 - $cx;
            my $temp_y4 = 0 - $cy;

            my $rotated_x1 = $temp_x1*cos($rotate_radians) - $temp_y1*sin($rotate_radians);
            my $rotated_y1 = $temp_x1*sin($rotate_radians) + $temp_y1*cos($rotate_radians);
            my $rotated_x2 = $temp_x2*cos($rotate_radians) - $temp_y2*sin($rotate_radians);
            my $rotated_y2 = $temp_x2*sin($rotate_radians) + $temp_y2*cos($rotate_radians);
            my $rotated_x3 = $temp_x3*cos($rotate_radians) - $temp_y3*sin($rotate_radians);
            my $rotated_y3 = $temp_x3*sin($rotate_radians) + $temp_y3*cos($rotate_radians);
            my $rotated_x4 = $temp_x4*cos($rotate_radians) - $temp_y4*sin($rotate_radians);
            my $rotated_y4 = $temp_x4*sin($rotate_radians) + $temp_y4*cos($rotate_radians);

            $rotated_x1 = $rotated_x1 + $cx;
            $rotated_y1 = $rotated_y1 + $cy;
            $rotated_x2 = $rotated_x2 + $cx;
            $rotated_y2 = $rotated_y2 + $cy;
            $rotated_x3 = $rotated_x3 + $cx;
            $rotated_y3 = $rotated_y3 + $cy;
            $rotated_x4 = $rotated_x4 + $cx;
            $rotated_y4 = $rotated_y4 + $cy;

            my $rotated_bound_dst = [[$rotated_x1, $rotated_y1], [$rotated_x2, $rotated_y2], [$rotated_x3, $rotated_y3], [$rotated_x4, $rotated_y4]];
            my $rotated_bound_translated_dst = [[$rotated_x1 + $x_pos_match_dst, $rotated_y1 + $y_pos_match_dst], [$rotated_x2 + $x_pos_match_dst, $rotated_y2 + $y_pos_match_dst], [$rotated_x3 + $x_pos_match_dst, $rotated_y3 + $y_pos_match_dst], [$rotated_x4 + $x_pos_match_dst, $rotated_y4 + $y_pos_match_dst]];
            my $rotated_bound_src = [[$rotated_x1, $rotated_y1], [$rotated_x2, $rotated_y2], [$rotated_x3, $rotated_y3], [$rotated_x4, $rotated_y4]];
            my $rotated_bound_translated_src = [[$rotated_x1 + $x_pos_match_src, $rotated_y1 + $y_pos_match_src], [$rotated_x2 + $x_pos_match_src, $rotated_y2 + $y_pos_match_src], [$rotated_x3 + $x_pos_match_src, $rotated_y3 + $y_pos_match_src], [$rotated_x4 + $x_pos_match_src, $rotated_y4 + $y_pos_match_src]];

            $nir_image_hash{$image_id1}->{rotated_bound} = $rotated_bound_src;
            $nir_image_hash{$image_id1}->{rotated_bound_translated} = $rotated_bound_translated_src;
            $nir_image_hash{$image_id2}->{rotated_bound} = $rotated_bound_dst;
            $nir_image_hash{$image_id2}->{rotated_bound_translated} = $rotated_bound_translated_dst;

            $image_counter++;
            $image_id1 = $nir_image_ids->[$image_counter];
            $image_id2 = $nir_image_ids->[$image_counter+1];
        }
    }

    my %gps_images_matched;
    foreach (values %nir_image_hash) {
        if ($_->{latitude} && $_->{longitude}) {
            $gps_images_matched{$_->{latitude}}->{$_->{longitude}} = $_;
        }
    }

    my $minimum_x_val = 10000000000;
    my $minimum_y_val = 10000000000;
    while (my ($latitude, $lo) = each %gps_images_matched) {
        while (my ($longitude, $i) = each %$lo) {
            my $x_pos = $i->{x_pos} + 0;
            my $y_pos = $i->{y_pos} + 0;
            if ($x_pos < $minimum_x_val) {
                $minimum_x_val = $x_pos;
            }
            if ($y_pos < $minimum_y_val) {
                $minimum_y_val = $y_pos;
            }
        }
    }

    while (my ($latitude, $lo) = each %gps_images_matched) {
        while (my ($longitude, $i) = each %$lo) {
            my $x_pos = $i->{x_pos};
            my $y_pos = $i->{y_pos};
            $gps_images_matched{$latitude}->{$longitude}->{x_pos} = $return->{image_width}/2 + $x_pos - $minimum_x_val;
            $gps_images_matched{$latitude}->{$longitude}->{y_pos} = $return->{image_length}/2 + $y_pos - $minimum_y_val;

            foreach (@{$i->{rotated_bound_translated}}) {
                $_->[0] = $return->{image_width}/2 + $_->[0] - $minimum_x_val;
                $_->[1] = $return->{image_length}/2 + $_->[1] - $minimum_y_val;
            }
        }
    }

    my $saved_gps_positions_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_raw_images_saved_gps_pixel_positions', 'project_property')->cvterm_id();
    my $saved_gps_positions_json = $schema->resultset("Project::Projectprop")->find({
        project_id => $drone_run_project_id,
        type_id => $saved_gps_positions_type_id
    });
    my $saved_gps_positions_full;
    if ($saved_gps_positions_json) {
        $saved_gps_positions_full = decode_json $saved_gps_positions_json->value();
    }

    $saved_gps_positions_full->{$flight_pass_counter} = \%gps_images_matched;

    my $drone_run_band_rotate_angle = $schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$saved_gps_positions_type_id,
        project_id=>$drone_run_project_id,
        rank=>0,
        value=>encode_json $saved_gps_positions_full
    },
    {
        key=>'projectprop_c1'
    });

    if ($flight_pass_counter == $max_flight_pass_counter) {
        my $drone_run_rotate_process_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_raw_images_rotation_occuring', 'project_property')->cvterm_id();
        my $drone_run_rotate_process = $schema->resultset('Project::Projectprop')->update_or_create({
            type_id=>$drone_run_rotate_process_type_id,
            project_id=>$drone_run_project_id,
            rank=>0,
            value=>0
        },
        {
            key=>'projectprop_c1'
        });
    }

    return {
        saved_gps_positions_full => $saved_gps_positions_full,
        message => $message
    }
}

sub drone_imagery_match_and_align_images_sequential : Path('/api/drone_imagery/match_and_align_images_sequential') : ActionClass('REST') { }
sub drone_imagery_match_and_align_images_sequential_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    print STDERR Dumper $c->req->params();
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $sp_person_id);
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema", undef, $sp_person_id);
    my $people_schema = $c->dbic_schema("CXGN::People::Schema", undef, $sp_person_id);
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $drone_run_project_id = $c->req->param('drone_run_project_id');
    my $nir_image_ids = decode_json $c->req->param('nir_image_ids');
    my $flight_pass_counter = $c->req->param("flight_pass_counter");

    my $return = _perform_match_raw_images_sequential($c, $schema, $metadata_schema, $phenome_schema, $people_schema, $drone_run_project_id, $nir_image_ids, $flight_pass_counter, $user_id, $user_name, $user_role);
    my $saved_gps_positions_full = $return->{saved_gps_positions_full};
    my $message = $return->{message};

    $c->stash->{rest} = {
        success => 1,
        gps_images_matched => $saved_gps_positions_full,
        message => $message
    };
}

sub drone_imagery_delete_gps_images : Path('/api/drone_imagery/delete_gps_images') : ActionClass('REST') { }
sub drone_imagery_delete_gps_images_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    print STDERR Dumper $c->req->params();
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $drone_run_project_id = $c->req->param("drone_run_project_id");

    my $saved_gps_positions_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_raw_images_saved_gps_pixel_positions', 'project_property')->cvterm_id();
    my $saved_gps_positions_json = $schema->resultset("Project::Projectprop")->find({
        project_id => $drone_run_project_id,
        type_id => $saved_gps_positions_type_id
    });
    if ($saved_gps_positions_json) {
        $saved_gps_positions_json->delete();
    }

    #Separated RESTART
    my $saved_image_stacks_separated_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_raw_images_saved_micasense_stacks_separated', 'project_property')->cvterm_id();
    my $saved_micasense_stacks_separated_json = $schema->resultset("Project::Projectprop")->find({
        project_id => $drone_run_project_id,
        type_id => $saved_image_stacks_separated_type_id
    });
    if ($saved_micasense_stacks_separated_json) {
        $saved_micasense_stacks_separated_json->delete();
    }

    #ROTATED RESTART
    my $saved_image_stacks_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_raw_images_saved_micasense_stacks_rotated', 'project_property')->cvterm_id();
    my $saved_micasense_stacks_json = $schema->resultset("Project::Projectprop")->find({
        project_id => $drone_run_project_id,
        type_id => $saved_image_stacks_type_id
    });
    if ($saved_micasense_stacks_json) {
        $saved_micasense_stacks_json->delete();
    }

    $c->stash->{rest} = {
        success => 1
    };
}

sub drone_imagery_save_gps_images : Path('/api/drone_imagery/save_gps_images') : ActionClass('REST') { }
sub drone_imagery_save_gps_images_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    # print STDERR Dumper $c->req->params();
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $sp_person_id);
    my $drone_run_project_id = $c->req->param('drone_run_project_id');
    my $flight_pass_counter = $c->req->param('flight_pass_counter');
    my $gps_images = decode_json $c->req->param('gps_images');

    my $saved_gps_positions_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_raw_images_saved_gps_pixel_positions', 'project_property')->cvterm_id();
    my $saved_gps_positions_json = $schema->resultset("Project::Projectprop")->find({
        project_id => $drone_run_project_id,
        type_id => $saved_gps_positions_type_id
    });
    my $saved_gps_positions_full;
    if ($saved_gps_positions_json) {
        $saved_gps_positions_full = decode_json $saved_gps_positions_json->value();
    }

    $saved_gps_positions_full->{$flight_pass_counter} = $gps_images;

    my $drone_run_band_rotate_angle = $schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$saved_gps_positions_type_id,
        project_id=>$drone_run_project_id,
        rank=>0,
        value => encode_json $saved_gps_positions_full
    },
    {
        key=>'projectprop_c1'
    });

    $c->stash->{rest} = {
        success => 1,
        gps_images => $gps_images
    };
}

sub drone_imagery_calculate_statistics_store_analysis : Path('/api/drone_imagery/calculate_statistics_store_analysis') : ActionClass('REST') { }
sub drone_imagery_calculate_statistics_store_analysis_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    print STDERR Dumper $c->req->params();
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $bcs_schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $sp_person_id);
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema", undef, $sp_person_id);
    my $people_schema = $c->dbic_schema("CXGN::People::Schema", undef, $sp_person_id);
    my $analysis_name = $c->req->param('analysis_name');
    my $analysis_description = $c->req->param('analysis_description');
    my $analysis_model_type = $c->req->param('statistics_select');
    my $accession_names = $c->req->param('accession_names');
    my $trait_names = $c->req->param('trait_names');
    my $training_data_file = $c->req->param('training_data_file');
    my $phenotype_data_hash = $c->req->param('phenotype_data_hash');
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $a = CXGN::Analysis->new({
        bcs_schema => $bcs_schema,
        people_schema => $people_schema,
        metadata_schema => $metadata_schema,
        phenome_schema => $phenome_schema,
        name => $analysis_name,
    });

    $a->description($analysis_description);
    $a->user_id($user_id);

    my $model_string = '';

    #print STDERR Dumper("STOCKS HERE: ".$stocks);
    $a->accession_names($accession_names);
    $a->metadata()->traits($trait_names);
    #$a->metadata()->analysis_protocol($params->{analysis_protocol});
    $a->metadata()->model($model_string);

    my ($verified_warning, $verified_error);

    print STDERR "Storing the analysis...\n";
    eval {
        ($verified_warning, $verified_error) = $a->create_and_store_analysis_design();
    };

    my @errors;
    my @warnings;

    if ($@) {
        push @errors, $@;
    }
    elsif ($verified_warning) {
        push @warnings, $verified_warning;
    }
    elsif ($verified_error) {
        push @errors, $verified_error;
    }

    if (@errors) {
        print STDERR "SORRY! Errors: ".join("\n", @errors);
        $c->stash->{rest} = { error => join "; ", @errors };
        return;
    }

    print STDERR "Store analysis values...\n";
    #print STDERR "value hash: ".Dumper($values);
    print STDERR "traits: ".join(",",@$trait_names);

    my $plots;
    my $values;

    eval {
        $a->store_analysis_values(
            $c->dbic_schema("CXGN::Metadata::Schema", undef, $sp_person_id),
            $c->dbic_schema("CXGN::Phenome::Schema", undef, $sp_person_id),
            $values, # value_hash
            $plots,
            $trait_names,
            $user_name,
            $c->config->{basepath},
            $c->config->{dbhost},
            $c->config->{dbname},
            $c->config->{dbuser},
            $c->config->{dbpass}
        );
    };

    if ($@) {
        print STDERR "An error occurred storing analysis values ($@).\n";
        $c->stash->{rest} = {
            error => "An error occurred storing the values ($@).\n"
        };
        return;
    }

    $c->stash->{rest} = { success => 1 };
}

sub drone_imagery_rotate_image : Path('/api/drone_imagery/rotate_image') : ActionClass('REST') { }
sub drone_imagery_rotate_image_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $sp_person_id);
    my $image_id = $c->req->param('image_id');
    my $drone_run_band_project_id = $c->req->param('drone_run_band_project_id');
    my $angle_rotation = $c->req->param('angle');
    my $view_only = $c->req->param('view_only');
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $dir = $c->tempfiles_subdir('/drone_imagery_rotate');
    my $archive_rotate_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_rotate/imageXXXX');
    $archive_rotate_temp_image .= '.png';

    my $return = _perform_image_rotate($c, $schema, $metadata_schema, $drone_run_band_project_id, $image_id, $angle_rotation, $view_only, $user_id, $user_name, $user_role, $archive_rotate_temp_image, 0, 0, 1, 0);

    $c->stash->{rest} = $return;
}

sub _perform_image_rotate {
    my $c = shift;
    my $schema = shift;
    my $metadata_schema = shift;
    my $drone_run_band_project_id = shift;
    my $image_id = shift;
    my $angle_rotation = shift || 0;
    my $view_only = shift;
    my $user_id = shift;
    my $user_name = shift;
    my $user_role = shift;
    my $archive_rotate_temp_image = shift;
    my $centered = shift;
    my $dont_check_for_previous = shift;
    my $check_resize = shift;
    my $keep_original_size_rotate = shift;

    my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
    my $image_url = $image->get_image_url("original");
    my $image_fullpath = $image->get_filename('original_converted', 'full');

    my $center = '';
    if ($centered) {
        $center = ' --centered 1';
    }
    my $original_size = '';
    if ($keep_original_size_rotate) {
        $original_size = ' --original_size 1';
    }
    my $cmd = $c->config->{python_executable}.' '.$c->config->{rootpath}.'/DroneImageScripts/ImageProcess/Rotate.py --image_path \''.$image_fullpath.'\' --outfile_path \''.$archive_rotate_temp_image.'\' --angle '.$angle_rotation.$center.$original_size;
    print STDERR Dumper $cmd;
    my $status = system("$cmd > /dev/null");

    if ($check_resize) {
        my ($check_image_width, $check_image_height) = imgsize($archive_rotate_temp_image);
        if ($check_image_width > 16384) {
            my $cmd_resize = $c->config->{python_executable}.' '.$c->config->{rootpath}.'/DroneImageScripts/ImageProcess/Resize.py --image_path \''.$archive_rotate_temp_image.'\' --outfile_path \''.$archive_rotate_temp_image.'\' --width 16384';
            print STDERR Dumper $cmd_resize;
            my $status_resize = system("$cmd_resize > /dev/null");
        }
        elsif ($check_image_height > 16384) {
            my $cmd_resize = $c->config->{python_executable}.' '.$c->config->{rootpath}.'/DroneImageScripts/ImageProcess/Resize.py --image_path \''.$archive_rotate_temp_image.'\' --outfile_path \''.$archive_rotate_temp_image.'\' --height 16384';
            print STDERR Dumper $cmd_resize;
            my $status_resize = system("$cmd_resize > /dev/null");
        }
    }

    my $linking_table_type_id;
    if ($view_only) {
        $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'rotated_stitched_temporary_drone_imagery', 'project_md_image')->cvterm_id();
    } else {
        my $rotated_stitched_temporary_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'rotated_stitched_temporary_drone_imagery', 'project_md_image')->cvterm_id();
        my $rotated_stitched_temporary_images_search = CXGN::DroneImagery::ImagesSearch->new({
            bcs_schema=>$schema,
            project_image_type_id=>$rotated_stitched_temporary_drone_images_cvterm_id,
            drone_run_band_project_id_list=>[$drone_run_band_project_id]
        });
        my ($rotated_stitched_temporary_result, $rotated_stitched_temporary_total_count) = $rotated_stitched_temporary_images_search->search();
        foreach (@$rotated_stitched_temporary_result){
            my $temp_image = SGN::Image->new( $schema->storage->dbh, $_->{image_id}, $c );
            $temp_image->delete(); #Sets to obsolete
        }
        $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'rotated_stitched_drone_imagery', 'project_md_image')->cvterm_id();

        my $rotated_stitched_images_search = CXGN::DroneImagery::ImagesSearch->new({
            bcs_schema=>$schema,
            project_image_type_id=>$linking_table_type_id,
            drone_run_band_project_id_list=>[$drone_run_band_project_id]
        });
        my ($rotated_stitched_result, $rotated_stitched_total_count) = $rotated_stitched_images_search->search();
        foreach (@$rotated_stitched_result){
            my $previous_image = SGN::Image->new( $schema->storage->dbh, $_->{image_id}, $c );
            $previous_image->delete(); #Sets to obsolete
        }

        my $drone_run_band_rotate_angle_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_rotate_angle', 'project_property')->cvterm_id();
        my $drone_run_band_rotate_angle = $schema->resultset('Project::Projectprop')->update_or_create({
            type_id=>$drone_run_band_rotate_angle_type_id,
            project_id=>$drone_run_band_project_id,
            rank=>0,
            value=>$angle_rotation
        },
        {
            key=>'projectprop_c1'
        });
    }

    my $rotated_image_fullpath;
    my $rotated_image_url;
    my $rotated_image_id;
    if ($dont_check_for_previous) {
        $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
        $image->set_sp_person_id($user_id);
        my $ret = $image->process_image($archive_rotate_temp_image, 'project', $drone_run_band_project_id, $linking_table_type_id);
        $rotated_image_fullpath = $image->get_filename('original_converted', 'full');
        $rotated_image_url = $image->get_image_url('original');
        $rotated_image_id = $image->get_image_id();
    }
    else {
        $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
        my $md5checksum = $image->calculate_md5sum($archive_rotate_temp_image);
        my $q = "SELECT md_image.image_id FROM metadata.md_image AS md_image
            JOIN phenome.project_md_image AS project_md_image ON(project_md_image.image_id = md_image.image_id)
            WHERE md_image.obsolete = 'f' AND md_image.md5sum = ? AND project_md_image.type_id = ? AND project_md_image.project_id = ?;";
        my $h = $schema->storage->dbh->prepare($q);
        $h->execute($md5checksum, $linking_table_type_id, $drone_run_band_project_id);
        my ($saved_image_id) = $h->fetchrow_array();

        if ($saved_image_id) {
            print STDERR Dumper "Image $archive_rotate_temp_image has already been added to the database and will not be added again.";
            $image = SGN::Image->new( $schema->storage->dbh, $saved_image_id, $c );
            $rotated_image_fullpath = $image->get_filename('original_converted', 'full');
            $rotated_image_url = $image->get_image_url('original');
            $rotated_image_id = $image->get_image_id();
        } else {
            $image->set_sp_person_id($user_id);
            my $ret = $image->process_image($archive_rotate_temp_image, 'project', $drone_run_band_project_id, $linking_table_type_id);
            $rotated_image_fullpath = $image->get_filename('original_converted', 'full');
            $rotated_image_url = $image->get_image_url('original');
            $rotated_image_id = $image->get_image_id();
        }
    }

    unlink($archive_rotate_temp_image);
    return {
        rotated_image_id => $rotated_image_id, image_url => $image_url, image_fullpath => $image_fullpath, rotated_image_url => $rotated_image_url, rotated_image_fullpath => $rotated_image_fullpath
    };
}

sub drone_imagery_get_contours : Path('/api/drone_imagery/get_contours') : ActionClass('REST') { }
sub drone_imagery_get_contours_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $sp_person_id);
    my $image_id = $c->req->param('image_id');
    my $drone_run_band_project_id = $c->req->param('drone_run_band_project_id');
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'contours_stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $main_production_site = $c->config->{main_production_site_url};

    my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
    my $image_url = $image->get_image_url("original");
    my $image_fullpath = $image->get_filename('original_converted', 'full');

    my $dir = $c->tempfiles_subdir('/drone_imagery_contours');
    my $archive_contours_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_contours/imageXXXX');
    $archive_contours_temp_image .= '.png';

    my $cmd = $c->config->{python_executable}.' '.$c->config->{rootpath}.'/DroneImageScripts/ImageContours/GetContours.py --image_path \''.$image_fullpath.'\' --outfile_path \''.$archive_contours_temp_image.'\'';
    print STDERR Dumper $cmd;
    my $status = system("$cmd > /dev/null");

    my @size = imgsize($archive_contours_temp_image);

    my $contours_image_fullpath;
    my $contours_image_url;
    my $contours_image_id;

    $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
    my $md5checksum = $image->calculate_md5sum($archive_contours_temp_image);
    my $q = "SELECT md_image.image_id FROM metadata.md_image AS md_image
        JOIN phenome.project_md_image AS project_md_image ON(project_md_image.image_id = md_image.image_id)
        WHERE md_image.obsolete = 'f' AND md_image.md5sum = ? AND project_md_image.type_id = ? AND project_md_image.project_id = ?;";
    my $h = $schema->storage->dbh->prepare($q);
    $h->execute($md5checksum, $linking_table_type_id, $drone_run_band_project_id);
    my ($saved_image_id) = $h->fetchrow_array();

    if ($saved_image_id) {
        print STDERR Dumper "Image $archive_contours_temp_image has already been added to the database and will not be added again.";
        $image = SGN::Image->new( $schema->storage->dbh, $saved_image_id, $c );
        $contours_image_fullpath = $image->get_filename('original_converted', 'full');
        $contours_image_url = $image->get_image_url('original');
        $contours_image_id = $image->get_image_id();
    } else {
        my $previous_contour_images_search = CXGN::DroneImagery::ImagesSearch->new({
            bcs_schema=>$schema,
            project_image_type_id=>$linking_table_type_id,
            drone_run_band_project_id_list=>[$drone_run_band_project_id]
        });
        my ($previous_contour_result, $previous_contour_total_count) = $previous_contour_images_search->search();
        foreach (@$previous_contour_result){
            my $previous_image = SGN::Image->new( $schema->storage->dbh, $_->{image_id}, $c );
            $previous_image->delete(); #Sets to obsolete
        }

        $image->set_sp_person_id($user_id);
        my $ret = $image->process_image($archive_contours_temp_image, 'project', $drone_run_band_project_id, $linking_table_type_id);
        $contours_image_fullpath = $image->get_filename('original_converted', 'full');
        $contours_image_url = $image->get_image_url('original');
        $contours_image_id = $image->get_image_id();
    }

    unlink($archive_contours_temp_image);
    $c->stash->{rest} = { image_url => $image_url, image_fullpath => $image_fullpath, contours_image_id => $contours_image_id, contours_image_url => $contours_image_url, contours_image_fullpath => $contours_image_fullpath, image_width => $size[0], image_height => $size[1] };
}

sub drone_imagery_retrieve_parameter_template : Path('/api/drone_imagery/retrieve_parameter_template') : ActionClass('REST') { }
sub drone_imagery_retrieve_parameter_template_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $template_projectprop_id = $c->req->param('plot_polygons_template_projectprop_id');

    my $rs = $schema->resultset("Project::Projectprop")->find({projectprop_id => $template_projectprop_id});
    my $plot_polygons = decode_json $rs->value;

    $c->stash->{rest} = {
        success => 1,
        parameter => $plot_polygons
    };
}

sub drone_imagery_assign_plot_polygons : Path('/api/drone_imagery/assign_plot_polygons') : ActionClass('REST') { }
sub drone_imagery_assign_plot_polygons_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $sp_person_id);
    my $image_id = $c->req->param('image_id');
    my $drone_run_band_project_id = $c->req->param('drone_run_band_project_id');
    my $stock_polygons = $c->req->param('stock_polygons');
    my $assign_plot_polygons_type = $c->req->param('assign_plot_polygons_type');

    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $return = _perform_plot_polygon_assign($c, $schema, $metadata_schema, $image_id, $drone_run_band_project_id, $stock_polygons, $assign_plot_polygons_type, $user_id, $user_name, $user_role, 1, 0, 1, 1, 'rectangular_square');

    $c->stash->{rest} = $return;
}

sub _perform_plot_polygon_assign {
    my $c = shift;
    my $schema = shift;
    my $metadata_schema = shift;
    my $image_id = shift;
    my $drone_run_band_project_id = shift;
    my $stock_polygons = shift;
    my $assign_plot_polygons_type = shift;
    my $user_id = shift;
    my $user_name = shift;
    my $user_role = shift;
    my $from_web_interface = shift;
    my $ignore_previous_image_check = shift;
    my $width_ratio = shift;
    my $height_ratio = shift;
    my $cropping_type = shift || 'rectangular_square';

    print STDERR "Plot Polygon Assign Type: $assign_plot_polygons_type \n";

    my $number_system_cores = `getconf _NPROCESSORS_ONLN` or die "Could not get number of system cores!\n";
    chomp($number_system_cores);
    print STDERR "NUMCORES $number_system_cores\n";

    my $polygon_objs = decode_json $stock_polygons;
    my %stock_ids;

    # print STDERR Dumper $polygon_objs;

    foreach my $stock_name (keys %$polygon_objs) {
        my $polygon = $polygon_objs->{$stock_name};

        my @p_rescaled;
        foreach my $point (@$polygon) {
            my $x = $point->{x};
            my $y = $point->{y};
            push @p_rescaled, {x=>round($x/$width_ratio), y=>round($y/$height_ratio)};
        }
        $polygon = \@p_rescaled;

        if ($from_web_interface) {
            my $last_point = pop @$polygon;
        }
        if (scalar(@$polygon) != 4){
            # print STDERR Dumper $polygon;
            $c->stash->{rest} = {error=>'Error: Polygon for '.$stock_name.' should be 4 long!'};
            $c->detach();
        }
        $polygon_objs->{$stock_name} = $polygon;

        my $stock = $schema->resultset("Stock::Stock")->find({uniquename => $stock_name});
        if (!$stock) {
            $c->stash->{rest} = {error=>'Error: Stock name '.$stock_name.' does not exist in the database!'};
            $c->detach();
        }
        $stock_ids{$stock_name} = $stock->stock_id;
    }

    my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
    my $image_url = $image->get_image_url("original");
    my $image_fullpath = $image->get_filename('original_converted', 'full');

    my $drone_run_band_plot_polygons_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_plot_polygons', 'project_property')->cvterm_id();
    my $previous_plot_polygons_rs = $schema->resultset('Project::Projectprop')->search({type_id=>$drone_run_band_plot_polygons_type_id, project_id=>$drone_run_band_project_id});
    if ($previous_plot_polygons_rs->count > 1) {
        die "There should not be more than one saved entry for plot polygons for a drone run band";
    }

    my $save_stock_polygons;
    if ($previous_plot_polygons_rs->count > 0) {
        $save_stock_polygons = decode_json $previous_plot_polygons_rs->first->value;
    }
    foreach my $stock_name (keys %$polygon_objs) {
        $save_stock_polygons->{$stock_name} = $polygon_objs->{$stock_name};
    }

    my $drone_run_band_plot_polygons = $schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$drone_run_band_plot_polygons_type_id,
        project_id=>$drone_run_band_project_id,
        rank=>0,
        value=> encode_json($save_stock_polygons)
    },
    {
        key=>'projectprop_c1'
    });

    my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, $assign_plot_polygons_type, 'project_md_image')->cvterm_id();

    my @found_stock_ids = values %stock_ids;
    if (!$ignore_previous_image_check) {
        my $previous_images_search = CXGN::DroneImagery::ImagesSearch->new({
            bcs_schema=>$schema,
            drone_run_band_project_id_list=>[$drone_run_band_project_id],
            project_image_type_id=>$linking_table_type_id,
            stock_id_list=>\@found_stock_ids
        });
        my ($previous_result, $previous_total_count) = $previous_images_search->search();

        if (scalar(@$previous_result) == scalar(@found_stock_ids)) {
            print STDERR "Plot polygon assignment for $assign_plot_polygons_type on project $drone_run_band_project_id has already occured. Skipping \n";
            return {warning => "Plot polygon assignment already occured for $assign_plot_polygons_type on project $drone_run_band_project_id."};
        }
    }

    my $image_tag_id = CXGN::Tag::exists_tag_named($schema->storage->dbh, $assign_plot_polygons_type);
    if (!$image_tag_id) {
        my $image_tag = CXGN::Tag->new($schema->storage->dbh);
        $image_tag->set_name($assign_plot_polygons_type);
        $image_tag->set_description('Drone run band project type for plot polygon assignment: '.$assign_plot_polygons_type);
        $image_tag->set_sp_person_id($user_id);
        $image_tag_id = $image_tag->store();
    }
    my $image_tag = CXGN::Tag->new($schema->storage->dbh, $image_tag_id);

    my $corresponding_channel = CXGN::DroneImagery::ImageTypes::get_all_project_md_image_observation_unit_plot_polygon_types($schema)->{$linking_table_type_id}->{corresponding_channel} || '';

    my @plot_polygon_image_fullpaths;
    my @plot_polygon_image_urls;

    my $dir = $c->tempfiles_subdir('/drone_imagery_plot_polygons');
    my $bulk_input_temp_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_plot_polygons/bulkinputXXXX');

    open(my $F, ">", $bulk_input_temp_file) || die "Can't open file ".$bulk_input_temp_file;

    my @plot_polygons;
    foreach my $stock_name (keys %$polygon_objs) {
        #my $pid = $pm->start and next;

        my $polygon = $polygon_objs->{$stock_name};
        my $polygons = encode_json [$polygon];

        my $stock_id = $stock_ids{$stock_name};

        my $archive_plot_polygons_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_plot_polygons/imageXXXX');
        $archive_plot_polygons_temp_image .= '.png';

        print $F "$image_fullpath\t$archive_plot_polygons_temp_image\t$polygons\t$cropping_type\t$corresponding_channel\n";

        push @plot_polygons, {
            temp_plot_image => $archive_plot_polygons_temp_image,
            stock_id => $stock_id
        };
    }

    my $cmd = $c->config->{python_executable}." ".$c->config->{rootpath}."/DroneImageScripts/ImageCropping/CropToPolygonBulk.py --inputfile_path '$bulk_input_temp_file'";
    print STDERR Dumper $cmd;
    my $status = system("$cmd > /dev/null");

    my $pm = Parallel::ForkManager->new(ceil($number_system_cores/4));
    $pm->run_on_finish( sub {
        my ($pid, $exit_code, $ident, $exit_signal, $core_dump, $data_structure_reference) = @_;
        push @plot_polygon_image_urls, $data_structure_reference->{plot_polygon_image_url};
        push @plot_polygon_image_fullpaths, $data_structure_reference->{plot_polygon_image_fullpath};
    });

    foreach my $obj (@plot_polygons) {
        my $archive_plot_polygons_temp_image = $obj->{temp_plot_image};
        my $stock_id = $obj->{stock_id};

        my $plot_polygon_image_fullpath;
        my $plot_polygon_image_url;
        $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
        my $md5checksum = $image->calculate_md5sum($archive_plot_polygons_temp_image);
        my $q = "SELECT md_image.image_id FROM metadata.md_image AS md_image
            JOIN phenome.project_md_image AS project_md_image ON(project_md_image.image_id = md_image.image_id)
            JOIN phenome.stock_image AS stock_image ON (stock_image.image_id = md_image.image_id)
            WHERE md_image.obsolete = 'f' AND md_image.md5sum = ? AND project_md_image.type_id = ? AND project_md_image.project_id = ? AND stock_image.stock_id = ?;";
        my $h = $schema->storage->dbh->prepare($q);
        $h->execute($md5checksum, $linking_table_type_id, $drone_run_band_project_id, $stock_id);
        my ($image_id) = $h->fetchrow_array();

        if ($image_id) {
            print STDERR Dumper "Image $archive_plot_polygons_temp_image has already been added to the database and will not be added again.";
            $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
            $plot_polygon_image_fullpath = $image->get_filename('original_converted', 'full');
            $plot_polygon_image_url = $image->get_image_url('original');
        } else {
            $image->set_sp_person_id($user_id);
            my $ret = $image->process_image($archive_plot_polygons_temp_image, 'project', $drone_run_band_project_id, $linking_table_type_id);
            my $stock_associate = $image->associate_stock($stock_id, $user_name);
            $plot_polygon_image_fullpath = $image->get_filename('original_converted', 'full');
            $plot_polygon_image_url = $image->get_image_url('original');
            my $added_image_tag_id = $image->add_tag($image_tag);
        }
        unlink($archive_plot_polygons_temp_image);

        $pm->finish(0, { plot_polygon_image_url => $plot_polygon_image_url, plot_polygon_image_fullpath => $plot_polygon_image_fullpath });
    }
    $pm->wait_all_children;

    return {
        image_url => $image_url, image_fullpath => $image_fullpath, success => 1, drone_run_band_template_id => $drone_run_band_plot_polygons->projectprop_id
    };
}

sub drone_imagery_manual_assign_plot_polygon_save_partial_template : Path('/api/drone_imagery/manual_assign_plot_polygon_save_partial_template') : ActionClass('REST') { }
sub drone_imagery_manual_assign_plot_polygon_save_partial_template_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    print STDERR Dumper $c->req->params();
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $sp_person_id);
    my @image_ids = $c->req->param('image_ids[]');
    my $polygon_json = $c->req->param('polygon');
    my $polygon_plot_numbers_json = $c->req->param('polygon_plot_numbers');
    my $field_trial_id = $c->req->param('field_trial_id');
    my $drone_run_project_id = $c->req->param('drone_run_project_id');
    my $angle_rotated = $c->req->param('angle_rotated');
    my $partial_template_name = $c->req->param('partial_template_name');

    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $polygon_hash = decode_json $polygon_json;
    my $polygon_plot_numbers_hash = decode_json $polygon_plot_numbers_json;

    my $plot_number_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot number', 'stock_property')->cvterm_id();
    my $field_experiment_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'field_layout', 'experiment_type')->cvterm_id();

    my $q = "SELECT stock.uniquename FROM stock
        JOIN stockprop USING(stock_id)
        JOIN nd_experiment_stock USING(stock_id)
        JOIN nd_experiment USING(nd_experiment_id)
        JOIN nd_experiment_project USING(nd_experiment_id)
        WHERE project_id = $field_trial_id
        AND nd_experiment.type_id = $field_experiment_cvterm_id
        AND stockprop.type_id = $plot_number_cvterm_id
        AND stockprop.value = ?;";
    my $h = $schema->storage->dbh->prepare($q);

    my %stock_polygon;
    while (my ($generated_index, $plot_number) = each %$polygon_plot_numbers_hash) {
        $h->execute($plot_number);
        my ($uniquename) = $h->fetchrow_array();
        my $plot_polygon = $polygon_hash->{$generated_index};
        my $last_point = pop @$plot_polygon;
        if (scalar(@$plot_polygon) != 4){
            $c->stash->{rest} = {error=>'Error: Polygon for '.$uniquename.' should be 4 long!'};
            $c->detach();
        }
        $stock_polygon{$uniquename} = $plot_polygon;
    }

    my $manual_plot_polygon_template_partial = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_plot_polygons_partial', 'project_property')->cvterm_id();

    my $previous_plot_polygons_rs = $schema->resultset('Project::Projectprop')->search({type_id=>$manual_plot_polygon_template_partial, project_id=>$drone_run_project_id});
    if ($previous_plot_polygons_rs->count > 1) {
        die "There should not be more than one saved entry for partial plot polygon template for a drone run";
    }

    my @save_stock_polygons;
    if ($previous_plot_polygons_rs->count > 0) {
        @save_stock_polygons = @{decode_json $previous_plot_polygons_rs->first->value};
    }
    push @save_stock_polygons, {
        template_name => $partial_template_name,
        image_id => $image_ids[3], #NIR image id
        polygon => $polygon_hash,
        stock_polygon => \%stock_polygon
    };

    my $drone_run_band_plot_polygons = $schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$manual_plot_polygon_template_partial,
        project_id=>$drone_run_project_id,
        rank=>0,
        value=> encode_json(\@save_stock_polygons)
    },
    {
        key=>'projectprop_c1'
    });

    $c->stash->{rest} = {success => 1};
}

sub drone_imagery_manual_assign_plot_polygon : Path('/api/drone_imagery/manual_assign_plot_polygon') : ActionClass('REST') { }
sub drone_imagery_manual_assign_plot_polygon_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    print STDERR Dumper $c->req->params();
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $sp_person_id);
    my @image_ids = $c->req->param('image_ids[]');
    my $polygon_json = $c->req->param('polygon');
    my $polygon_plot_numbers_json = $c->req->param('polygon_plot_numbers');
    my $field_trial_id = $c->req->param('field_trial_id');
    my $drone_run_project_id = $c->req->param('drone_run_project_id');
    my $angle_rotated = $c->req->param('angle_rotated');
    my $partial_template_name = $c->req->param('partial_template_name');

    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $polygon_hash = decode_json $polygon_json;
    my $polygon_plot_numbers_hash = decode_json $polygon_plot_numbers_json;

    my $plot_number_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot number', 'stock_property')->cvterm_id();
    my $field_experiment_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'field_layout', 'experiment_type')->cvterm_id();

    my $q = "SELECT stock.uniquename FROM stock
        JOIN stockprop USING(stock_id)
        JOIN nd_experiment_stock USING(stock_id)
        JOIN nd_experiment USING(nd_experiment_id)
        JOIN nd_experiment_project USING(nd_experiment_id)
        WHERE project_id = $field_trial_id
        AND nd_experiment.type_id = $field_experiment_cvterm_id
        AND stockprop.type_id = $plot_number_cvterm_id
        AND stockprop.value = ?;";
    my $h = $schema->storage->dbh->prepare($q);

    my %stock_polygon;
    while (my ($generated_index, $plot_number) = each %$polygon_plot_numbers_hash) {
        $h->execute($plot_number);
        my ($uniquename) = $h->fetchrow_array();
        my $plot_polygon = $polygon_hash->{$generated_index};
        my $last_point = pop @$plot_polygon;
        if (scalar(@$plot_polygon) != 4){
            $c->stash->{rest} = {error=>'Error: Polygon for '.$uniquename.' should be 4 long!'};
            $c->detach();
        }
        $stock_polygon{$uniquename} = $plot_polygon;
    }

    my $drone_run_band_project_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_project_type', 'project_property')->cvterm_id();
    my $project_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_on_drone_run', 'project_relationship')->cvterm_id();

    my $q_drone_run_bands = "SELECT drone_run_band.project_id, drone_run_band_project_type.value
        FROM project AS drone_run
        JOIN project_relationship ON (drone_run.project_id = project_relationship.object_project_id AND project_relationship.type_id=$project_relationship_type_id)
        JOIN project as drone_run_band ON (drone_run_band.project_id=project_relationship.subject_project_id)
        JOIN projectprop AS drone_run_band_project_type ON (drone_run_band_project_type.project_id=drone_run_band.project_id AND drone_run_band_project_type.type_id=$drone_run_band_project_type_cvterm_id)
        WHERE drone_run.project_id=?;";
    my $h_drone_run_bands = $schema->storage->dbh->prepare($q_drone_run_bands);
    $h_drone_run_bands->execute($drone_run_project_id);
    my %drone_run_bands_all;
    while (my ($drone_run_band_id, $drone_run_band_type) = $h_drone_run_bands->fetchrow_array()) {
        $drone_run_bands_all{$drone_run_band_type} = $drone_run_band_id;
    }
    print STDERR Dumper \%drone_run_bands_all;

    my $drone_image_types = CXGN::DroneImagery::ImageTypes::get_all_project_md_image_observation_unit_plot_polygon_types($schema);
    my @plot_polygon_type_ids = (
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_blue_imagery', 'project_md_image')->cvterm_id(),
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_green_imagery', 'project_md_image')->cvterm_id(),
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_red_imagery', 'project_md_image')->cvterm_id(),
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_nir_imagery', 'project_md_image')->cvterm_id(),
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_red_edge_imagery', 'project_md_image')->cvterm_id()
    );
    my @plot_polygon_type_objects;
    foreach (@plot_polygon_type_ids) {
        push @plot_polygon_type_objects, $drone_image_types->{$_};
    }

    my $stock_polygons = encode_json \%stock_polygon;
    my $dir = $c->tempfiles_subdir('/drone_imagery_rotate');

    foreach my $index (0..scalar(@image_ids)-1) {
        my $drone_run_band_project_type = $plot_polygon_type_objects[$index]->{drone_run_project_types}->[0];
        my $plot_polygon_type = $plot_polygon_type_objects[$index]->{name};
        my $image_id = $image_ids[$index];
        my $drone_run_band_project_id = $drone_run_bands_all{$drone_run_band_project_type};

        my $archive_rotate_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_rotate/imageXXXX');
        $archive_rotate_temp_image .= '.png';

        my $rotate_return = _perform_image_rotate($c, $schema, $metadata_schema, $drone_run_band_project_id, $image_id, $angle_rotated, 0, $user_id, $user_name, $user_role, $archive_rotate_temp_image, 0, 0, 1, 0);
        my $rotated_image_id = $rotate_return->{rotated_image_id};

        my $return = _perform_plot_polygon_assign($c, $schema, $metadata_schema, $rotated_image_id, $drone_run_band_project_id, $stock_polygons, $plot_polygon_type, $user_id, $user_name, $user_role, 0, 1, 1, 1, 'rectangular_square');
    }

    $c->stash->{rest} = {success => 1};
}

sub drone_imagery_save_plot_polygons_template : Path('/api/drone_imagery/save_plot_polygons_template') : ActionClass('REST') { }
sub drone_imagery_save_plot_polygons_template_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $sp_person_id);
    my $drone_run_band_project_id = $c->req->param('drone_run_band_project_id');
    my $stock_polygons = $c->req->param('stock_polygons');

    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $polygon_objs = decode_json $stock_polygons;
    my %stock_ids;

    foreach my $stock_name (keys %$polygon_objs) {
        my $polygon = $polygon_objs->{$stock_name};
        my $last_point = pop @$polygon;
        if (scalar(@$polygon) != 4){
            $c->stash->{rest} = {error=>'Error: Polygon for '.$stock_name.' should be 4 long!'};
            $c->detach();
        }
        $polygon_objs->{$stock_name} = $polygon;

        my $stock = $schema->resultset("Stock::Stock")->find({uniquename => $stock_name});
        if (!$stock) {
            $c->stash->{rest} = {error=>'Error: Stock name '.$stock_name.' does not exist in the database!'};
            $c->detach();
        }
        $stock_ids{$stock_name} = $stock->stock_id;
    }

    my $drone_run_band_plot_polygons_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_plot_polygons', 'project_property')->cvterm_id();
    my $previous_plot_polygons_rs = $schema->resultset('Project::Projectprop')->search({type_id=>$drone_run_band_plot_polygons_type_id, project_id=>$drone_run_band_project_id});
    if ($previous_plot_polygons_rs->count > 1) {
        die "There should not be more than one saved entry for plot polygons for a drone run band";
    }

    my $save_stock_polygons;
    if ($previous_plot_polygons_rs->count > 0) {
        $save_stock_polygons = decode_json $previous_plot_polygons_rs->first->value;
    }
    foreach my $stock_name (keys %$polygon_objs) {
        $save_stock_polygons->{$stock_name} = $polygon_objs->{$stock_name};
    }

    my $drone_run_band_plot_polygons = $schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$drone_run_band_plot_polygons_type_id,
        project_id=>$drone_run_band_project_id,
        rank=>0,
        value=> encode_json($save_stock_polygons)
    },
    {
        key=>'projectprop_c1'
    });

    $c->stash->{rest} = {success => 1, drone_run_band_template_id => $drone_run_band_plot_polygons->projectprop_id};
}

sub drone_imagery_save_plot_polygons_template_separated : Path('/api/drone_imagery/save_plot_polygons_template_separated') : ActionClass('REST') { }
sub drone_imagery_save_plot_polygons_template_separated_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    print STDERR Dumper $c->req->params();
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $sp_person_id);
    my $drone_run_band_project_id = $c->req->param('drone_run_band_project_id');
    my $stock_polygons = $c->req->param('stock_polygons');
    my $flight_pass_counter = $c->req->param('flight_pass_counter');

    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $polygon_objs = decode_json $stock_polygons;
    my %stock_ids;

    foreach my $stock_name (keys %$polygon_objs) {
        my $polygon = $polygon_objs->{$stock_name};
        my $last_point = pop @$polygon;
        if (scalar(@$polygon) != 4){
            $c->stash->{rest} = {error=>'Error: Polygon for '.$stock_name.' should be 4 long!'};
            $c->detach();
        }
        $polygon_objs->{$stock_name} = $polygon;

        my $stock = $schema->resultset("Stock::Stock")->find({uniquename => $stock_name});
        if (!$stock) {
            $c->stash->{rest} = {error=>'Error: Stock name '.$stock_name.' does not exist in the database!'};
            $c->detach();
        }
        $stock_ids{$stock_name} = $stock->stock_id;
    }

    my $drone_run_band_plot_polygons_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_plot_polygons_separated', 'project_property')->cvterm_id();
    my $previous_plot_polygons_rs = $schema->resultset('Project::Projectprop')->search({type_id=>$drone_run_band_plot_polygons_type_id, project_id=>$drone_run_band_project_id});
    if ($previous_plot_polygons_rs->count > 1) {
        die "There should not be more than one saved entry for plot polygons for a drone run band";
    }

    my $save_stock_polygons;
    if ($previous_plot_polygons_rs->count > 0) {
        $save_stock_polygons = decode_json $previous_plot_polygons_rs->first->value;
    }
    foreach my $stock_name (keys %$polygon_objs) {
        $save_stock_polygons->{$flight_pass_counter}->{$stock_name} = $polygon_objs->{$stock_name};
    }
    # print STDERR Dumper $save_stock_polygons;

    my $drone_run_band_plot_polygons = $schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$drone_run_band_plot_polygons_type_id,
        project_id=>$drone_run_band_project_id,
        rank=>0,
        value=> encode_json($save_stock_polygons)
    },
    {
        key=>'projectprop_c1'
    });

    $c->stash->{rest} = {success => 1, drone_run_band_template_id => $drone_run_band_plot_polygons->projectprop_id};
}

sub drone_imagery_denoise : Path('/api/drone_imagery/denoise') : ActionClass('REST') { }
sub drone_imagery_denoise_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $sp_person_id);
    my $image_id = $c->req->param('image_id');
    my $drone_run_band_project_id = $c->req->param('drone_run_band_project_id');
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $dir = $c->tempfiles_subdir('/drone_imagery_denoise');
    my $archive_denoise_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_denoise/imageXXXX');
    $archive_denoise_temp_image .= '.png';

    my $return = _perform_image_denoise($c, $schema, $metadata_schema, $image_id, $drone_run_band_project_id, $user_id, $user_name, $user_role, $archive_denoise_temp_image);

    $c->stash->{rest} = $return;
}

sub _perform_image_denoise {
    my $c = shift;
    my $schema = shift;
    my $metadata_schema = shift;
    my $image_id = shift;
    my $drone_run_band_project_id = shift;
    my $user_id = shift;
    my $user_name = shift;
    my $user_role = shift;
    my $archive_denoise_temp_image = shift;

    my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
    my $image_url = $image->get_image_url("original");
    my $image_fullpath = $image->get_filename('original_converted', 'full');

    my $cmd = $c->config->{python_executable}.' '.$c->config->{rootpath}.'/DroneImageScripts/ImageProcess/Denoise.py --image_path \''.$image_fullpath.'\' --outfile_path \''.$archive_denoise_temp_image.'\'';
    print STDERR Dumper $cmd;
    my $status = system("$cmd > /dev/null");

    my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'denoised_stitched_drone_imagery', 'project_md_image')->cvterm_id();

    my $previous_denoised_images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        project_image_type_id=>$linking_table_type_id,
        drone_run_band_project_id_list=>[$drone_run_band_project_id]
    });
    my ($previous_denoised_result, $previous_denoised_total_count) = $previous_denoised_images_search->search();
    foreach (@$previous_denoised_result){
        my $previous_image = SGN::Image->new( $schema->storage->dbh, $_->{image_id}, $c );
        $previous_image->delete(); #Sets to obsolete
    }

    my $denoised_image_fullpath;
    my $denoised_image_url;
    my $denoised_image_id;
    $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
    my $md5checksum = $image->calculate_md5sum($archive_denoise_temp_image);
    my $q = "SELECT md_image.image_id FROM metadata.md_image AS md_image
        JOIN phenome.project_md_image AS project_md_image ON(project_md_image.image_id = md_image.image_id)
        WHERE md_image.obsolete = 'f' AND md_image.md5sum = ? AND project_md_image.type_id = ? AND project_md_image.project_id = ?;";
    my $h = $schema->storage->dbh->prepare($q);
    $h->execute($md5checksum, $linking_table_type_id, $drone_run_band_project_id);
    my ($saved_image_id) = $h->fetchrow_array();

    if ($saved_image_id) {
        print STDERR Dumper "Image $archive_denoise_temp_image has already been added to the database and will not be added again.";
        $image = SGN::Image->new( $schema->storage->dbh, $saved_image_id, $c );
        $denoised_image_fullpath = $image->get_filename('original_converted', 'full');
        $denoised_image_url = $image->get_image_url('original');
        $denoised_image_id = $image->get_image_id();
    } else {
        $image->set_sp_person_id($user_id);
        my $ret = $image->process_image($archive_denoise_temp_image, 'project', $drone_run_band_project_id, $linking_table_type_id);
        $denoised_image_fullpath = $image->get_filename('original_converted', 'full');
        $denoised_image_url = $image->get_image_url('original');
        $denoised_image_id = $image->get_image_id();
    }

    unlink($archive_denoise_temp_image);
    return {
        image_url => $image_url, image_fullpath => $image_fullpath, denoised_image_id => $denoised_image_id, denoised_image_url => $denoised_image_url, denoised_image_fullpath => $denoised_image_fullpath
    };
}

sub drone_imagery_remove_background_display : Path('/api/drone_imagery/remove_background_display') : ActionClass('REST') { }
sub drone_imagery_remove_background_display_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $image_id = $c->req->param('image_id');
    my $drone_run_band_project_id = $c->req->param('drone_run_band_project_id');
    my $lower_threshold = $c->req->param('lower_threshold');
    my $upper_threshold = $c->req->param('upper_threshold');
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    if (!$lower_threshold && !defined($lower_threshold)) {
        $c->stash->{rest} = {error => 'Please give a lower threshold'};
        $c->detach();
    }
    if (!$upper_threshold && !defined($upper_threshold)) {
        $c->stash->{rest} = {error => 'Please give an upper threshold'};
        $c->detach();
    }

    my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
    my $image_url = $image->get_image_url("original");
    my $image_fullpath = $image->get_filename('original_converted', 'full');

    my $dir = $c->tempfiles_subdir('/drone_imagery_remove_background');
    my $archive_remove_background_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_remove_background/imageXXXX');
    $archive_remove_background_temp_image .= '.png';

    my $cmd = $c->config->{python_executable}.' '.$c->config->{rootpath}.'/DroneImageScripts/ImageProcess/RemoveBackground.py --image_path \''.$image_fullpath.'\' --outfile_path \''.$archive_remove_background_temp_image.'\' --lower_threshold '.$lower_threshold.' --upper_threshold '.$upper_threshold;
    print STDERR Dumper $cmd;
    my $status = system("$cmd > /dev/null");

    $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
    $image->set_sp_person_id($user_id);
    my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'background_removed_temporary_stitched_drone_imagery', 'project_md_image')->cvterm_id();

    my $previous_background_removed_temp_images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        project_image_type_id=>$linking_table_type_id,
        drone_run_band_project_id_list=>[$drone_run_band_project_id]
    });
    my ($previous_result, $previous_total_count) = $previous_background_removed_temp_images_search->search();
    foreach (@$previous_result){
        my $previous_image = SGN::Image->new( $schema->storage->dbh, $_->{image_id}, $c );
        $previous_image->delete(); #Sets to obsolete
    }

    my $ret = $image->process_image($archive_remove_background_temp_image, 'project', $drone_run_band_project_id, $linking_table_type_id);
    my $removed_background_image_fullpath = $image->get_filename('original_converted', 'full');
    my $removed_background_image_url = $image->get_image_url('original');

    unlink($archive_remove_background_temp_image);
    $c->stash->{rest} = { image_url => $image_url, image_fullpath => $image_fullpath, removed_background_image_url => $removed_background_image_url, removed_background_image_fullpath => $removed_background_image_fullpath };
}

sub drone_imagery_remove_background_save : Path('/api/drone_imagery/remove_background_save') : ActionClass('REST') { }
sub drone_imagery_remove_background_save_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $image_id = $c->req->param('image_id');
    my $image_type = $c->req->param('image_type');
    my $drone_run_band_project_id = $c->req->param('drone_run_band_project_id');
    my $lower_threshold = $c->req->param('lower_threshold');
    my $upper_threshold = $c->req->param('upper_threshold') || '255';
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    if (!$lower_threshold && !defined($lower_threshold)) {
        $c->stash->{rest} = {error => 'Please give a lower threshold'};
        $c->detach();
    }
    if (!$upper_threshold && !defined($upper_threshold)) {
        $c->stash->{rest} = {error => 'Please give an upper threshold'};
        $c->detach();
    }

    my $dir = $c->tempfiles_subdir('/drone_imagery_remove_background');
    my $archive_remove_background_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_remove_background/imageXXXX');
    $archive_remove_background_temp_image .= '.png';

    my $return = _perform_image_background_remove_threshold($c, $schema, $image_id, $drone_run_band_project_id, $image_type, $lower_threshold, $upper_threshold, $user_id, $user_name, $user_role, $archive_remove_background_temp_image);

    $c->stash->{rest} = $return;
}

sub _perform_image_background_remove_threshold {
    my $c = shift;
    my $schema = shift;
    my $image_id = shift;
    my $drone_run_band_project_id = shift;
    my $image_type = shift;
    my $lower_threshold = shift;
    my $upper_threshold = shift;
    my $user_id = shift;
    my $user_name = shift;
    my $user_role = shift;
    my $archive_remove_background_temp_image = shift;
    print STDERR "Background Remove Threshold Image Type: $image_type\n";

    my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, $image_type, 'project_md_image')->cvterm_id();
    my $drone_run_band_remove_background_threshold_type_id;
    my $imagery_attribute_map = CXGN::DroneImagery::ImageTypes::get_imagery_attribute_map();

    if ($imagery_attribute_map->{$image_type}->{name} eq 'threshold') {
        $drone_run_band_remove_background_threshold_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, $imagery_attribute_map->{$image_type}->{key}, 'project_property')->cvterm_id();
    }
    if (!$drone_run_band_remove_background_threshold_type_id) {
        die "Remove background threshold not found: $image_type\n";
    }

    my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
    my $image_url = $image->get_image_url("original");
    my $image_fullpath = $image->get_filename('original_converted', 'full');

    my $cmd = $c->config->{python_executable}.' '.$c->config->{rootpath}.'/DroneImageScripts/ImageProcess/RemoveBackground.py --image_path \''.$image_fullpath.'\' --outfile_path \''.$archive_remove_background_temp_image.'\' --lower_threshold '.$lower_threshold.' --upper_threshold '.$upper_threshold;
    print STDERR Dumper $cmd;
    my $status = system("$cmd > /dev/null");

    $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
    $image->set_sp_person_id($user_id);

    my $previous_background_removed_images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        project_image_type_id=>$linking_table_type_id,
        drone_run_band_project_id_list=>[$drone_run_band_project_id]
    });
    my ($previous_result, $previous_total_count) = $previous_background_removed_images_search->search();
    foreach (@$previous_result){
        my $previous_image = SGN::Image->new( $schema->storage->dbh, $_->{image_id}, $c );
        $previous_image->delete(); #Sets to obsolete
    }

    my $ret = $image->process_image($archive_remove_background_temp_image, 'project', $drone_run_band_project_id, $linking_table_type_id);
    my $removed_background_image_fullpath = $image->get_filename('original_converted', 'full');
    my $removed_background_image_url = $image->get_image_url('original');
    my $removed_background_image_id = $image->get_image_id();

    my $drone_run_band_remove_background_threshold = $schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$drone_run_band_remove_background_threshold_type_id,
        project_id=>$drone_run_band_project_id,
        rank=>0,
        value=>"Lower Threshold:$lower_threshold. Upper Threshold:$upper_threshold"
    },
    {
        key=>'projectprop_c1'
    });

    unlink($archive_remove_background_temp_image);
    return {
        image_url => $image_url, image_fullpath => $image_fullpath, removed_background_image_id => $removed_background_image_id, removed_background_image_url => $removed_background_image_url, removed_background_image_fullpath => $removed_background_image_fullpath
    };
}

sub drone_imagery_remove_background_percentage_save : Path('/api/drone_imagery/remove_background_percentage_save') : ActionClass('REST') { }
sub drone_imagery_remove_background_percentage_save_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $image_id = $c->req->param('image_id');
    my $image_type_list = $c->req->param('image_type_list');
    my $drone_run_band_project_id = $c->req->param('drone_run_band_project_id');
    my $lower_threshold_percentage = $c->req->param('lower_threshold_percentage');
    my $upper_threshold_percentage = $c->req->param('upper_threshold_percentage');
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    if (!$lower_threshold_percentage && !defined($lower_threshold_percentage)) {
        $c->stash->{rest} = {error => 'Please give a lower threshold percentage'};
        $c->detach();
    }
    if (!$upper_threshold_percentage && !defined($upper_threshold_percentage)) {
        $c->stash->{rest} = {error => 'Please give an upper threshold percentage'};
        $c->detach();
    }

    my @image_types = split ',', $image_type_list;
    my @returns;
    foreach my $image_type (@image_types) {
        my $dir = $c->tempfiles_subdir('/drone_imagery_remove_background');
        my $archive_remove_background_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_remove_background/imageXXXX');
        $archive_remove_background_temp_image .= '.png';

        my $return = _perform_image_background_remove_threshold_percentage($c, $schema, $image_id, $drone_run_band_project_id, $image_type, $lower_threshold_percentage, $upper_threshold_percentage, $user_id, $user_name, $user_role, $archive_remove_background_temp_image);
        push @returns, $return;
    }

    $c->stash->{rest} = \@returns;
}

sub _perform_image_background_remove_threshold_percentage {
    my $c = shift;
    my $schema = shift;
    my $image_id = shift;
    my $drone_run_band_project_id = shift;
    my $image_type = shift;
    my $lower_threshold_percentage = shift;
    my $upper_threshold_percentage = shift;
    my $user_id = shift;
    my $user_name = shift;
    my $user_role = shift;
    my $archive_remove_background_temp_image = shift;
    print STDERR "Remove background threshold percentage $image_type\n";

    my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
    my $image_url = $image->get_image_url("original");
    my $image_fullpath = $image->get_filename('original_converted', 'full');

    my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, $image_type, 'project_md_image')->cvterm_id();
    my $drone_run_band_remove_background_threshold_type_id;
    my $imagery_attribute_map = CXGN::DroneImagery::ImageTypes::get_imagery_attribute_map();

    if ($imagery_attribute_map->{$image_type}->{name} eq 'threshold') {
        $drone_run_band_remove_background_threshold_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, $imagery_attribute_map->{$image_type}->{key}, 'project_property')->cvterm_id();
    }
    if (!$drone_run_band_remove_background_threshold_type_id) {
        die "Remove background threshold not found: $image_type\n";
    }

    my $corresponding_channel = CXGN::DroneImagery::ImageTypes::get_all_project_md_image_types_whole_images($schema)->{$linking_table_type_id}->{corresponding_channel};
    my $image_band_index_string = '';
    if (defined($corresponding_channel)) {
        $image_band_index_string = "--image_band_index $corresponding_channel";
    }

    my $previous_background_removed_images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        project_image_type_id=>$linking_table_type_id,
        drone_run_band_project_id_list=>[$drone_run_band_project_id]
    });
    my ($previous_result, $previous_total_count) = $previous_background_removed_images_search->search();
    foreach (@$previous_result){
        my $previous_image = SGN::Image->new( $schema->storage->dbh, $_->{image_id}, $c );
        $previous_image->delete(); #Sets to obsolete
    }

    my $cmd = $c->config->{python_executable}.' '.$c->config->{rootpath}.'/DroneImageScripts/ImageProcess/RemoveBackgroundPercentage.py --image_path \''.$image_fullpath.'\' --outfile_path \''.$archive_remove_background_temp_image.'\' --lower_percentage \''.$lower_threshold_percentage.'\' --upper_percentage \''.$upper_threshold_percentage.'\' '.$image_band_index_string;
    print STDERR Dumper $cmd;
    my $status = system("$cmd > /dev/null");

    $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
    $image->set_sp_person_id($user_id);
    my $ret = $image->process_image($archive_remove_background_temp_image, 'project', $drone_run_band_project_id, $linking_table_type_id);
    my $removed_background_image_fullpath = $image->get_filename('original_converted', 'full');
    my $removed_background_image_url = $image->get_image_url('original');
    my $removed_background_image_id = $image->get_image_id();

    my $drone_run_band_remove_background_threshold = $schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$drone_run_band_remove_background_threshold_type_id,
        project_id=>$drone_run_band_project_id,
        rank=>0,
        value=>"Lower Threshold Percentage:$lower_threshold_percentage. Upper Threshold Percentage:$upper_threshold_percentage"
    },
    {
        key=>'projectprop_c1'
    });

    unlink($archive_remove_background_temp_image);
    return {
        image_url => $image_url, image_fullpath => $image_fullpath, removed_background_image_id => $removed_background_image_id, removed_background_image_url => $removed_background_image_url, removed_background_image_fullpath => $removed_background_image_fullpath
    };
}

sub get_drone_run_projects : Path('/api/drone_imagery/drone_runs') : ActionClass('REST') { }
sub get_drone_run_projects_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $sp_person_id);
    my $checkbox_select_name = $c->req->param('select_checkbox_name');
    my $checkbox_select_all = $c->req->param('checkbox_select_all');
    my $field_trial_ids = $c->req->param('field_trial_ids');
    my $disable = $c->req->param('disable');

    my $project_start_date_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'project_start_date', 'project_property')->cvterm_id();
    my $design_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'design', 'project_property')->cvterm_id();
    my $drone_run_camera_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_camera_type', 'project_property')->cvterm_id();
    my $drone_run_project_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_project_type', 'project_property')->cvterm_id();
    my $drone_run_gdd_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_averaged_temperature_growing_degree_days', 'project_property')->cvterm_id();
    my $project_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_on_field_trial', 'project_relationship')->cvterm_id();

    my $where_clause = '';
    if ($field_trial_ids) {
        $where_clause = ' WHERE field_trial.project_id IN ('.$field_trial_ids.') ';
    }

    my $q = "SELECT project.project_id, project.name, project.description, drone_run_type.value, project_start_date.value, field_trial.project_id, field_trial.name, field_trial.description, drone_run_camera_type.value, drone_run_gdd.value FROM project
        JOIN projectprop AS project_start_date ON (project.project_id=project_start_date.project_id AND project_start_date.type_id=$project_start_date_type_id)
        LEFT JOIN projectprop AS drone_run_type ON (project.project_id=drone_run_type.project_id AND drone_run_type.type_id=$drone_run_project_type_cvterm_id)
        LEFT JOIN projectprop AS drone_run_camera_type ON (project.project_id=drone_run_camera_type.project_id AND drone_run_camera_type.type_id=$drone_run_camera_cvterm_id)
        LEFT JOIN projectprop AS drone_run_gdd ON (project.project_id=drone_run_gdd.project_id AND drone_run_gdd.type_id=$drone_run_gdd_cvterm_id)
        JOIN project_relationship ON (project.project_id = project_relationship.subject_project_id AND project_relationship.type_id=$project_relationship_type_id)
        JOIN project AS field_trial ON (field_trial.project_id=project_relationship.object_project_id)
        $where_clause
        ORDER BY project.project_id;";

    my $calendar_funcs = CXGN::Calendar->new({});

    my $h = $bcs_schema->storage->dbh()->prepare($q);
    $h->execute();
    my @result;
    while (my ($drone_run_project_id, $drone_run_project_name, $drone_run_project_description, $drone_run_type, $drone_run_date, $field_trial_project_id, $field_trial_project_name, $field_trial_project_description, $drone_run_camera_type, $drone_run_gdd) = $h->fetchrow_array()) {
        my @res;
        if ($checkbox_select_name){
            my $checkbox = "<input type='checkbox' name='$checkbox_select_name' value='$drone_run_project_id' ";
            if ($checkbox_select_all) {
                $checkbox .= "checked";
            }
            if ($disable) {
                $checkbox .= "disabled";
            }
            $checkbox .= ">";
            push @res, $checkbox;
        }
        my $drone_run_date_display = $drone_run_date ? $calendar_funcs->display_start_date($drone_run_date) : '';
        push @res, (
            "<a href=\"/breeders_toolbox/trial/$drone_run_project_id\">$drone_run_project_name</a>",
            $drone_run_type,
            $drone_run_project_description,
            $drone_run_date_display,
            $drone_run_gdd,
            $drone_run_camera_type,
            "<a href=\"/breeders_toolbox/trial/$field_trial_project_id\">$field_trial_project_name</a>",
            $field_trial_project_description
        );
        push @result, \@res;
    }

    $c->stash->{rest} = { data => \@result };
}

sub get_drone_run_projects_kv : Path('/api/drone_imagery/drone_runs_json') : ActionClass('REST') { }
sub get_drone_run_projects_kv_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $sp_person_id);
    my $checkbox_select_all = $c->req->param('checkbox_select_all');
    my $field_trial_ids = $c->req->param('field_trial_ids');

    my $project_start_date_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'project_start_date', 'project_property')->cvterm_id();
    my $design_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'design', 'project_property')->cvterm_id();
    my $drone_run_camera_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_camera_type', 'project_property')->cvterm_id();
    my $drone_run_project_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_project_type', 'project_property')->cvterm_id();
    my $drone_run_gdd_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_averaged_temperature_growing_degree_days', 'project_property')->cvterm_id();
    my $project_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_on_field_trial', 'project_relationship')->cvterm_id();

    my $where_clause = '';
    if ($field_trial_ids) {
        $where_clause = ' WHERE field_trial.project_id IN ('.$field_trial_ids.') ';
    }

    my $q = "SELECT project.project_id, project.name, project.description, drone_run_type.value, project_start_date.value, field_trial.project_id, field_trial.name, field_trial.description, drone_run_camera_type.value, drone_run_gdd.value FROM project
        JOIN projectprop AS project_start_date ON (project.project_id=project_start_date.project_id AND project_start_date.type_id=$project_start_date_type_id)
        LEFT JOIN projectprop AS drone_run_type ON (project.project_id=drone_run_type.project_id AND drone_run_type.type_id=$drone_run_project_type_cvterm_id)
        LEFT JOIN projectprop AS drone_run_camera_type ON (project.project_id=drone_run_camera_type.project_id AND drone_run_camera_type.type_id=$drone_run_camera_cvterm_id)
        LEFT JOIN projectprop AS drone_run_gdd ON (project.project_id=drone_run_gdd.project_id AND drone_run_gdd.type_id=$drone_run_gdd_cvterm_id)
        JOIN project_relationship ON (project.project_id = project_relationship.subject_project_id AND project_relationship.type_id=$project_relationship_type_id)
        JOIN project AS field_trial ON (field_trial.project_id=project_relationship.object_project_id)
        $where_clause
        ORDER BY project.project_id;";

    my $calendar_funcs = CXGN::Calendar->new({});

    my $h = $bcs_schema->storage->dbh()->prepare($q);
    $h->execute();
    my @result;
    while (my ($drone_run_project_id, $drone_run_project_name, $drone_run_project_description, $drone_run_type, $drone_run_date, $field_trial_project_id, $field_trial_project_name, $field_trial_project_description, $drone_run_camera_type, $drone_run_gdd) = $h->fetchrow_array()) {
        my @res;
        my $drone_run_date_display = $drone_run_date ? $calendar_funcs->display_start_date($drone_run_date) : '';
        my %data = (
            "Drone Run Name" => $drone_run_project_name,
            "Drone Run Type" => $drone_run_type,
            "Drone Run Description" => $drone_run_project_description,
            "Imaging Date" => $drone_run_date_display,
            "Drone Run GDD" => $drone_run_gdd,
            "Camera Type" => $drone_run_camera_type,
            "Field Trial Name" => $field_trial_project_name,
            "Field Trial Description" => $field_trial_project_description
        );
        push @result,\%data;
    }

    $c->stash->{rest} = { data => \@result };
}


sub get_plot_polygon_types_images : Path('/api/drone_imagery/plot_polygon_types_images') : ActionClass('REST') { }
sub get_plot_polygon_types_images_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $sp_person_id);
    my $checkbox_select_name = $c->req->param('select_checkbox_name');
    my $checkbox_select_all = $c->req->param('checkbox_select_all');
    my $field_trial_ids = $c->req->param('field_trial_ids');
    my $stock_ids = $c->req->param('stock_ids');
    my $field_trial_images_only = $c->req->param('field_trial_images_only');
    my $drone_run_ids = $c->req->param('drone_run_ids') ? decode_json $c->req->param('drone_run_ids') : [];
    my $drone_run_band_ids = $c->req->param('drone_run_band_ids') ? decode_json $c->req->param('drone_run_band_ids') : [];

    my $drone_run_project_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_project_type', 'project_property')->cvterm_id();
    my $drone_run_band_project_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_project_type', 'project_property')->cvterm_id();
    my $drone_run_field_trial_project_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_on_field_trial', 'project_relationship')->cvterm_id();
    my $drone_run_band_drone_run_project_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_on_drone_run', 'project_relationship')->cvterm_id();
    my $project_image_type_id_list;
    if (!$field_trial_images_only) {
        $project_image_type_id_list = CXGN::DroneImagery::ImageTypes::get_all_project_md_image_observation_unit_plot_polygon_types($bcs_schema);
    }
    else {
        $project_image_type_id_list = CXGN::DroneImagery::ImageTypes::get_all_project_md_image_types_whole_images($bcs_schema);
    }
    my $project_image_type_id_list_sql = join ",", (keys %$project_image_type_id_list);

    my @where_clause;
    push @where_clause, "project_md_image.type_id in ($project_image_type_id_list_sql)";

    if ($field_trial_ids) {
        push @where_clause, "field_trial.project_id IN ($field_trial_ids)";
    }
    if ($drone_run_ids && scalar(@$drone_run_ids)>0) {
        my $sql = join ("," , @$drone_run_ids);
        push @where_clause, "drone_run.project_id IN ($sql)";
    }
    if ($drone_run_band_ids && scalar(@$drone_run_band_ids)>0) {
        my $sql = join ("," , @$drone_run_band_ids);
        push @where_clause, "drone_run_band.project_id IN ($sql)";
    }
    my $stock_image_join = '';
    if ($stock_ids) {
        my @stock_ids_array = split ',', $stock_ids;
        my $stock_id_sql = join (",", @stock_ids_array);
        $stock_image_join = 'JOIN metadata.md_image AS md_image ON (md_image.image_id=project_md_image.image_id) JOIN phenome.stock_image AS stock_image ON (md_image.image_id=stock_image.image_id)';
        push @where_clause, "stock_image.stock_id IN ($stock_id_sql)";
    }
    my $where_clause = scalar(@where_clause)>0 ? " WHERE " . (join (" AND " , @where_clause)) : '';

    my $q = "SELECT drone_run_band.project_id, drone_run_band.name, drone_run_band.description, drone_run_band_type.value, drone_run.project_id, drone_run.name, drone_run.description, drone_run_type.value, field_trial.project_id, field_trial.name, field_trial.description, project_md_image.type_id, project_md_image_type.name, project_md_image.image_id
        FROM project AS drone_run_band
        LEFT JOIN projectprop AS drone_run_band_type ON (drone_run_band.project_id=drone_run_band_type.project_id AND drone_run_band_type.type_id=$drone_run_band_project_type_cvterm_id)
        JOIN project_relationship AS drone_run_band_rel ON (drone_run_band.project_id = drone_run_band_rel.subject_project_id AND drone_run_band_rel.type_id=$drone_run_band_drone_run_project_relationship_type_id)
        JOIN project AS drone_run ON (drone_run.project_id=drone_run_band_rel.object_project_id)
        LEFT JOIN projectprop AS drone_run_type ON (drone_run.project_id=drone_run_type.project_id AND drone_run_type.type_id=$drone_run_project_type_cvterm_id)
        JOIN project_relationship AS field_trial_rel ON (drone_run.project_id = field_trial_rel.subject_project_id AND field_trial_rel.type_id=$drone_run_field_trial_project_relationship_type_id)
        JOIN project AS field_trial ON (field_trial.project_id=field_trial_rel.object_project_id)
        JOIN phenome.project_md_image AS project_md_image ON (drone_run_band.project_id = project_md_image.project_id)
        JOIN cvterm AS project_md_image_type ON (project_md_image_type.cvterm_id = project_md_image.type_id)
        $stock_image_join
        $where_clause
        GROUP BY drone_run_band.project_id, drone_run_band.name, drone_run_band.description, drone_run_band_type.value, drone_run.project_id, drone_run.name, drone_run.description, drone_run_type.value, field_trial.project_id, field_trial.name, field_trial.description, project_md_image.type_id, project_md_image_type.name, project_md_image.image_id
        ORDER BY drone_run_band.project_id;";

    my $h = $bcs_schema->storage->dbh()->prepare($q);
    $h->execute();
    my @result;
    while (my ($drone_run_band_project_id, $drone_run_band_project_name, $drone_run_band_project_description, $drone_run_band_type, $drone_run_project_id, $drone_run_project_name, $drone_run_project_description, $drone_run_type, $field_trial_project_id, $field_trial_project_name, $field_trial_project_description, $project_md_image_type_id, $project_md_image_type_name, $image_id) = $h->fetchrow_array()) {
        my @res;
        if ($checkbox_select_name){
            my $input = "<input type='checkbox' name='$checkbox_select_name' value='$image_id' ";
            if ($checkbox_select_all) {
                $input .= "checked";
            }
            $input .= ">";
            push @res, $input;
        }
        my $image = SGN::Image->new($bcs_schema->storage->dbh, $image_id, $c);
        my $image_id = $image->get_image_id;
        my $image_name = $image->get_name() || '';
        my $image_description = $image->get_description() || '';
        my $image_img = $image->get_image_url("medium");
        my $original_img = $image->get_image_url("large");
        my $small_image = $image->get_image_url("tiny");
        my $image_page = "/image/view/$image_id";
        my $colorbox = qq|<a href="$image_img"  title="<a href=$image_page>Go to image page ($image_name)</a>" class="image_search_group" rel="gallery-figures"><img src="$small_image" width="40" height="30" border="0" alt="$image_description" /></a>|;

        push @res, (
            $colorbox,
            "<a href=\"/breeders_toolbox/trial/$field_trial_project_id\">$field_trial_project_name</a>",
            $drone_run_project_name,
            $drone_run_band_project_name,
            $drone_run_band_type,
            $project_md_image_type_name
        );
        push @result, \@res;
    }

    $c->stash->{rest} = { data => \@result };
}

sub _get_standard_4_polygon_types {
    return (
        'observation_unit_polygon_rgb_imagery' => 1, #77976, 77689
        'observation_unit_polygon_nrn_imagery' => 1, #77980, 77693
        'observation_unit_polygon_nren_imagery' => 1, #77981, 77694
        # 'observation_unit_polygon_green_background_removed_threshold_imagery' => 1, #77995, 77708
        # 'observation_unit_polygon_red_background_removed_threshold_imagery' => 1, #77996, 77709
        # 'observation_unit_polygon_red_edge_background_removed_threshold_imagery' => 1, #77997, 77710
        # 'observation_unit_polygon_green_imagery' => 1, #77983, 77696
        # 'observation_unit_polygon_red_imagery' => 1, #77984, 77697
        # 'observation_unit_polygon_red_edge_imagery' => 1, #77985, 77698
        # 'observation_unit_polygon_nir_imagery' => 1, #77986, 77699
        'observation_unit_polygon_nir_background_removed_threshold_imagery' => 1, #77998, 77711
        #'observation_unit_polygon_vari_imagery' => 1, #78003, 77716
        #'observation_unit_polygon_ndvi_imagery' => 1, #78004, 77717
        # 'observation_unit_polygon_ndre_imagery' => 1, #78005, 77718
        #'observation_unit_polygon_background_removed_ndre_imagery' => 1, #78009, 77722
    );
}

sub _get_standard_9_polygon_types {
    return (
        'observation_unit_polygon_rgb_imagery' => 1, #77976, 77689
        'observation_unit_polygon_nrn_imagery' => 1, #77980, 77693
        'observation_unit_polygon_nren_imagery' => 1, #77981, 77694
        # 'observation_unit_polygon_green_background_removed_threshold_imagery' => 1, #77995, 77708
        # 'observation_unit_polygon_red_background_removed_threshold_imagery' => 1, #77996, 77709
        'observation_unit_polygon_red_edge_background_removed_threshold_imagery' => 1, #77997, 77710
        # 'observation_unit_polygon_green_imagery' => 1, #77983, 77696
        # 'observation_unit_polygon_red_imagery' => 1, #77984, 77697
        # 'observation_unit_polygon_red_edge_imagery' => 1, #77985, 77698
        # 'observation_unit_polygon_nir_imagery' => 1, #77986, 77699
        'observation_unit_polygon_nir_background_removed_threshold_imagery' => 1, #77998, 77711
        'observation_unit_polygon_vari_imagery' => 1, #78003, 77716
        'observation_unit_polygon_ndvi_imagery' => 1, #78004, 77717
        'observation_unit_polygon_ndre_imagery' => 1, #78005, 77718
        'observation_unit_polygon_tgi_imagery' => 1, #78005, 77718
        #'observation_unit_polygon_background_removed_ndre_imagery' => 1, #78009, 77722
    );
}

sub _get_standard_ndvi_ndre_polygon_types {
    return (
        'observation_unit_polygon_red_imagery' => 1, #77984, 77697
        'observation_unit_polygon_red_edge_imagery' => 1, #77985, 77698
        'observation_unit_polygon_nir_imagery' => 1, #77986, 77699
    );
}

sub get_plot_polygon_types : Path('/api/drone_imagery/plot_polygon_types') : ActionClass('REST') { }
sub get_plot_polygon_types_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $sp_person_id);
    my $checkbox_select_name = $c->req->param('select_checkbox_name');
    my $checkbox_select_all = $c->req->param('checkbox_select_all');
    my $checkbox_select_standard_ndvi_ndre = $c->req->param('checkbox_select_standard_ndvi_ndre');
    my $checkbox_select_standard_4 = $c->req->param('checkbox_select_standard_4');
    my $checkbox_select_standard_9 = $c->req->param('checkbox_select_standard_9');
    my $field_trial_ids = $c->req->param('field_trial_ids');
    my $stock_ids = $c->req->param('stock_ids');
    my $field_trial_images_only = $c->req->param('field_trial_images_only');
    my $field_trial_images_only_2d = $c->req->param('field_trial_images_only_2d');
    my $drone_run_ids = $c->req->param('drone_run_ids') ? decode_json $c->req->param('drone_run_ids') : [];
    my $drone_run_band_ids = $c->req->param('drone_run_band_ids') ? decode_json $c->req->param('drone_run_band_ids') : [];

    my $drone_run_project_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_project_type', 'project_property')->cvterm_id();
    my $drone_run_band_project_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_project_type', 'project_property')->cvterm_id();
    my $drone_run_field_trial_project_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_on_field_trial', 'project_relationship')->cvterm_id();
    my $drone_run_band_drone_run_project_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_on_drone_run', 'project_relationship')->cvterm_id();
    my $project_image_type_id_list_sql;
    if ($field_trial_images_only_2d) {
        my $project_image_type_id_list = CXGN::DroneImagery::ImageTypes::get_all_project_md_image_observation_unit_plot_polygon_types($bcs_schema);
        my @image_type_ids;
        while (my ($key, $val) = each %$project_image_type_id_list) {
            if (scalar(@{$val->{channels}}) == 1) {
                push @image_type_ids, $key;
            }
        }
        $project_image_type_id_list_sql = join ",", @image_type_ids;
    }
    elsif (!$field_trial_images_only) {
        my $project_image_type_id_list = CXGN::DroneImagery::ImageTypes::get_all_project_md_image_observation_unit_plot_polygon_types($bcs_schema);
        $project_image_type_id_list_sql = join ",", (keys %$project_image_type_id_list);
    }
    else {
        my $project_image_type_id_list = CXGN::DroneImagery::ImageTypes::get_all_project_md_image_types_whole_images($bcs_schema);
        $project_image_type_id_list_sql = join ",", (keys %$project_image_type_id_list);
    }

    my %standard_ndvi_ndre = _get_standard_ndvi_ndre_polygon_types();
    my %standard_4 = _get_standard_4_polygon_types();
    my %standard_9 = _get_standard_9_polygon_types();

    my @where_clause;
    push @where_clause, "project_md_image.type_id in ($project_image_type_id_list_sql)";

    if ($field_trial_ids) {
        push @where_clause, "field_trial.project_id IN ($field_trial_ids)";
    }
    if ($drone_run_ids && scalar(@$drone_run_ids)>0) {
        my $sql = join ("," , @$drone_run_ids);
        push @where_clause, "drone_run.project_id IN ($sql)";
    }
    if ($drone_run_band_ids && scalar(@$drone_run_band_ids)>0) {
        my $sql = join ("," , @$drone_run_band_ids);
        push @where_clause, "drone_run_band.project_id IN ($sql)";
    }
    my $stock_image_join = '';
    if ($stock_ids) {
        my @stock_ids_array = split ',', $stock_ids;
        my $stock_id_sql = join (",", @stock_ids_array);
        $stock_image_join = 'JOIN metadata.md_image AS md_image ON (md_image.image_id=project_md_image.image_id) JOIN phenome.stock_image AS stock_image ON (md_image.image_id=stock_image.image_id)';
        push @where_clause, "stock_image.stock_id IN ($stock_id_sql)";
    }
    my $where_clause = scalar(@where_clause)>0 ? " WHERE " . (join (" AND " , @where_clause)) : '';

    my $q = "SELECT drone_run_band.project_id, drone_run_band.name, drone_run_band.description, drone_run_band_type.value, drone_run.project_id, drone_run.name, drone_run.description, drone_run_type.value, field_trial.project_id, field_trial.name, field_trial.description, project_md_image.type_id, project_md_image_type.name, count(project_md_image.image_id)
        FROM project AS drone_run_band
        LEFT JOIN projectprop AS drone_run_band_type ON (drone_run_band.project_id=drone_run_band_type.project_id AND drone_run_band_type.type_id=$drone_run_band_project_type_cvterm_id)
        JOIN project_relationship AS drone_run_band_rel ON (drone_run_band.project_id = drone_run_band_rel.subject_project_id AND drone_run_band_rel.type_id=$drone_run_band_drone_run_project_relationship_type_id)
        JOIN project AS drone_run ON (drone_run.project_id=drone_run_band_rel.object_project_id)
        LEFT JOIN projectprop AS drone_run_type ON (drone_run.project_id=drone_run_type.project_id AND drone_run_type.type_id=$drone_run_project_type_cvterm_id)
        JOIN project_relationship AS field_trial_rel ON (drone_run.project_id = field_trial_rel.subject_project_id AND field_trial_rel.type_id=$drone_run_field_trial_project_relationship_type_id)
        JOIN project AS field_trial ON (field_trial.project_id=field_trial_rel.object_project_id)
        JOIN phenome.project_md_image AS project_md_image ON (drone_run_band.project_id = project_md_image.project_id)
        JOIN cvterm AS project_md_image_type ON (project_md_image_type.cvterm_id = project_md_image.type_id)
        $stock_image_join
        $where_clause
        GROUP BY drone_run_band.project_id, drone_run_band.name, drone_run_band.description, drone_run_band_type.value, drone_run.project_id, drone_run.name, drone_run.description, drone_run_type.value, field_trial.project_id, field_trial.name, field_trial.description, project_md_image.type_id, project_md_image_type.name
        ORDER BY drone_run_band.project_id;";

    my $h = $bcs_schema->storage->dbh()->prepare($q);
    $h->execute();
    my @result;
    while (my ($drone_run_band_project_id, $drone_run_band_project_name, $drone_run_band_project_description, $drone_run_band_type, $drone_run_project_id, $drone_run_project_name, $drone_run_project_description, $drone_run_type, $field_trial_project_id, $field_trial_project_name, $field_trial_project_description, $project_md_image_type_id, $project_md_image_type_name, $plot_polygon_count) = $h->fetchrow_array()) {
        my @res;
        if ($checkbox_select_name){
            my $input = "<input type='checkbox' name='$checkbox_select_name' value='$project_md_image_type_id' ";
            if ($checkbox_select_all) {
                $input .= "checked";
            }
            elsif ($checkbox_select_standard_4) {
                if (exists($standard_4{$project_md_image_type_name})) {
                    $input .= "checked disabled";
                }
                else {
                    $input .= "disabled";
                }
            }
            elsif ($checkbox_select_standard_9) {
                if (exists($standard_9{$project_md_image_type_name})) {
                    $input .= "checked disabled";
                }
                else {
                    $input .= "disabled";
                }
            }
            elsif ($checkbox_select_standard_ndvi_ndre) {
                if (exists($standard_ndvi_ndre{$project_md_image_type_name})) {
                    $input .= "checked disabled";
                }
                else {
                    $input .= "disabled";
                }
            }
            $input .= ">";
            push @res, $input;
        }
        push @res, (
            "<a href=\"/breeders_toolbox/trial/$field_trial_project_id\">$field_trial_project_name</a>",
            $drone_run_project_name,
            $drone_run_band_project_name,
            $drone_run_band_type,
            $project_md_image_type_name,
            $plot_polygon_count
        );
        push @result, \@res;
    }

    $c->stash->{rest} = { data => \@result };
}


# jQuery('#drone_image_upload_drone_bands_table').DataTable({
#     destroy : true,
#     ajax : '/api/drone_imagery/drone_run_bands?select_checkbox_name=upload_drone_imagery_drone_run_band_select&drone_run_project_id='+drone_run_project_id
# });
sub get_drone_run_band_projects : Path('/api/drone_imagery/drone_run_bands') : ActionClass('REST') { }
sub get_drone_run_band_projects_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $sp_person_id);
    my $checkbox_select_name = $c->req->param('select_checkbox_name');
    my $field_trial_id = $c->req->param('field_trial_id');
    my $drone_run_project_id = $c->req->param('drone_run_project_id');
    my $drone_run_project_ids = $c->req->param('drone_run_project_ids') ? decode_json $c->req->param('drone_run_project_ids') : [];
    my $exclude_drone_run_band_project_id = $c->req->param('exclude_drone_run_band_project_id') || 0;
    my $select_all = $c->req->param('select_all') || 0;
    my $disable = $c->req->param('disable') || 0;
    # print STDERR Dumper $c->req->params();

    my $project_start_date_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'project_start_date', 'project_property')->cvterm_id();
    my $design_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'design', 'project_property')->cvterm_id();
    my $drone_run_band_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_project_type', 'project_property')->cvterm_id();
    my $project_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_on_field_trial', 'project_relationship')->cvterm_id();
    my $drone_run_band_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_on_drone_run', 'project_relationship')->cvterm_id();

    my $where_clause = '';
    if ($drone_run_project_id) {
        $where_clause = ' WHERE project.project_id = '.$drone_run_project_id.' ';
    }
    if ($drone_run_project_ids && scalar(@$drone_run_project_ids)>0) {
        my $sql = join ",", @$drone_run_project_ids;
        $where_clause = ' WHERE project.project_id IN ('.$sql.') ';
    }

    my $q = "SELECT drone_run_band.project_id, drone_run_band.name, drone_run_band.description, drone_run_band_type.value, project.project_id, project.name, project.description, project_start_date.value, field_trial.project_id, field_trial.name, field_trial.description
        FROM project AS drone_run_band
        JOIN projectprop AS drone_run_band_type ON(drone_run_band.project_id=drone_run_band_type.project_id AND drone_run_band_type.type_id=$drone_run_band_type_cvterm_id)
        JOIN project_relationship AS drone_run_band_rel ON(drone_run_band.project_id=drone_run_band_rel.subject_project_id AND drone_run_band_rel.type_id=$drone_run_band_relationship_type_id)
        JOIN project ON (drone_run_band_rel.object_project_id = project.project_id)
        JOIN projectprop AS project_start_date ON (project.project_id=project_start_date.project_id AND project_start_date.type_id=$project_start_date_type_id)
        JOIN project_relationship ON (project.project_id = project_relationship.subject_project_id AND project_relationship.type_id=$project_relationship_type_id)
        JOIN project AS field_trial ON (field_trial.project_id=project_relationship.object_project_id)
        $where_clause
        ORDER BY project.project_id;";

    my $calendar_funcs = CXGN::Calendar->new({});

    my $h = $bcs_schema->storage->dbh()->prepare($q);
    $h->execute();
    my @result;
    while (my ($drone_run_band_project_id, $drone_run_band_name, $drone_run_band_description, $drone_run_band_type, $drone_run_project_id, $drone_run_project_name, $drone_run_project_description, $drone_run_date, $field_trial_project_id, $field_trial_project_name, $field_trial_project_description) = $h->fetchrow_array()) {
        my @res;
        if ($drone_run_band_project_id != $exclude_drone_run_band_project_id) {
            my $background_removed_threshold_type;
            if ($drone_run_band_type eq 'Blue (450-520nm)') {
                $background_removed_threshold_type = 'threshold_background_removed_stitched_drone_imagery_blue';
            }
            elsif ($drone_run_band_type eq 'Green (515-600nm)') {
                $background_removed_threshold_type = 'threshold_background_removed_stitched_drone_imagery_green';
            }
            elsif ($drone_run_band_type eq 'Red (600-690nm)') {
                $background_removed_threshold_type = 'threshold_background_removed_stitched_drone_imagery_red';
            }
            elsif ($drone_run_band_type eq 'Red Edge (690-750nm)') {
                $background_removed_threshold_type = 'threshold_background_removed_stitched_drone_imagery_red_edge';
            }
            elsif ($drone_run_band_type eq 'NIR (780-3000nm)') {
                $background_removed_threshold_type = 'threshold_background_removed_stitched_drone_imagery_nir';
            }
            elsif ($drone_run_band_type eq 'MIR (3000-50000nm)') {
                $background_removed_threshold_type = 'threshold_background_removed_stitched_drone_imagery_mir';
            }
            elsif ($drone_run_band_type eq 'FIR (50000-1000000nm)') {
                $background_removed_threshold_type = 'threshold_background_removed_stitched_drone_imagery_fir';
            }
            elsif ($drone_run_band_type eq 'Thermal IR (9000-14000nm)') {
                $background_removed_threshold_type = 'threshold_background_removed_stitched_drone_imagery_tir';
            }
            elsif ($drone_run_band_type eq 'Black and White Image') {
                $background_removed_threshold_type = 'threshold_background_removed_stitched_drone_imagery_bw';
            }
            elsif ($drone_run_band_type eq 'RGB Color Image') {
                $background_removed_threshold_type = 'threshold_background_removed_stitched_drone_imagery_rgb_channel_1,threshold_background_removed_stitched_drone_imagery_rgb_channel_2,threshold_background_removed_stitched_drone_imagery_rgb_channel_3';
            }
            if ($checkbox_select_name){
                my $checked = $select_all ? 'checked' : '';
                my $disabled = $disable ? 'disabled' : '';
                my $extra_data = $background_removed_threshold_type ? "data-background_removed_threshold_type='$background_removed_threshold_type'" : '';
                push @res, "<input type='checkbox' name='$checkbox_select_name' value='$drone_run_band_project_id' $extra_data $checked $disabled>";
            }
            my $drone_run_date_display = $drone_run_date ? $calendar_funcs->display_start_date($drone_run_date) : '';
            push @res, (
                $drone_run_band_name,
                $drone_run_band_description,
                $drone_run_band_type,
                $drone_run_project_name,
                $drone_run_project_description,
                $drone_run_date_display,
                "<a href=\"/breeders_toolbox/trial/$field_trial_project_id\">$field_trial_project_name</a>",
                $field_trial_project_description
            );
            push @result, \@res;
        }
    }

    $c->stash->{rest} = { data => \@result };
}

sub get_week_after_planting_date : Path('/api/drone_imagery/get_weeks_after_planting_date') : ActionClass('REST') { }
sub get_week_after_planting_date_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    $c->response->headers->header( "Access-Control-Allow-Origin" => '*' );
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $sp_person_id);
    my $drone_run_project_id = $c->req->param('drone_run_project_id');

    $c->stash->{rest} = _perform_get_weeks_drone_run_after_planting($schema, $drone_run_project_id);
}

sub _perform_get_weeks_drone_run_after_planting {
    my $schema = shift;
    my $drone_run_project_id = shift;

    my $project_start_date_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project_start_date', 'project_property')->cvterm_id();
    my $drone_run_base_date_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_base_date', 'project_property')->cvterm_id();
    my $project_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_on_field_trial', 'project_relationship')->cvterm_id();
    my $calendar_funcs = CXGN::Calendar->new({});

    my $drone_run_date_rs = $schema->resultset('Project::Projectprop')->search({project_id=>$drone_run_project_id, type_id=>$project_start_date_type_id});
    if ($drone_run_date_rs->count != 1) {
        return { error => 'There is no drone run date saved! This should not be possible, please contact us'};
    }
    my $drone_run_date = $drone_run_date_rs->first->value;
    my $drone_date = $calendar_funcs->display_start_date($drone_run_date);

    my $drone_run_base_date_rs = $schema->resultset('Project::Projectprop')->search({project_id=>$drone_run_project_id, type_id=>$drone_run_base_date_type_id});
    my $drone_run_base_date;
    if ($drone_run_base_date_rs->count == 1) {
        $drone_run_base_date = $calendar_funcs->display_start_date($drone_run_base_date_rs->first->value);
    }

    my $field_trial_rs = $schema->resultset("Project::ProjectRelationship")->search({subject_project_id=>$drone_run_project_id, type_id=>$project_relationship_type_id});
    if ($field_trial_rs->count != 1) {
        return { drone_run_date => $drone_date, error => 'There is no field trial saved to the drone run! This should not be possible, please contact us'};
    }
    my $trial_id = $field_trial_rs->first->object_project_id;
    my $trial = CXGN::Trial->new( { bcs_schema => $schema, trial_id => $trial_id });
    my $planting_date = $trial->get_planting_date();

    print STDERR $drone_date."\n";
    my $drone_date_time_object = Time::Piece->strptime($drone_date, "%Y-%B-%d %H:%M:%S");
    my $drone_date_full_calendar_datetime = $drone_date_time_object->strftime("%Y/%m/%d %H:%M:%S");

    if (!$planting_date) {
        return { drone_run_date => $drone_date, drone_run_date_calendar => $drone_date_full_calendar_datetime, error => 'The planting date is not set on the field trial, so we could not get the time of this flight automaticaly'};
    }

    print STDERR "$planting_date\n";
    print STDERR "$drone_run_base_date\n";
    my $planting_date_time_object = Time::Piece->strptime($planting_date, "%Y-%B-%d");
    my $planting_date_full_calendar_datetime = $planting_date_time_object->strftime("%Y/%m/%d %H:%M:%S");
    my $time_diff;
    if ($drone_run_base_date) {
        my $imaging_event_base_date_time_object = Time::Piece->strptime($drone_run_base_date, "%Y-%B-%d %H:%M:%S");
        $time_diff = $drone_date_time_object - $imaging_event_base_date_time_object;
    }
    else {
        $time_diff = $drone_date_time_object - $planting_date_time_object;
    }
    my $time_diff_weeks = $time_diff->weeks;
    my $time_diff_days = $time_diff->days;
    my $time_diff_hours = $time_diff->hours;
    my $rounded_time_diff_weeks = round($time_diff_weeks);
    if ($rounded_time_diff_weeks == 0) {
        $rounded_time_diff_weeks = 1;
    }

    my $week_term_string = "week $rounded_time_diff_weeks";
    my $q = "SELECT t.cvterm_id FROM cvterm as t JOIN cv ON(t.cv_id=cv.cv_id) WHERE t.name=? and cv.name=?;";
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute($week_term_string, 'cxgn_time_ontology');
    my ($week_cvterm_id) = $h->fetchrow_array();

    if (!$week_cvterm_id) {
        my $new_week_term = $schema->resultset("Cv::Cvterm")->create_with({
           name => $week_term_string,
           cv => 'cxgn_time_ontology'
        });
        $week_cvterm_id = $new_week_term->cvterm_id();
    }

    my $day_term_string = "day $time_diff_days";
    $h->execute($day_term_string, 'cxgn_time_ontology');
    my ($day_cvterm_id) = $h->fetchrow_array();

    if (!$day_cvterm_id) {
        my $new_day_term = $schema->resultset("Cv::Cvterm")->create_with({
           name => $day_term_string,
           cv => 'cxgn_time_ontology'
        });
        $day_cvterm_id = $new_day_term->cvterm_id();
    }

    if (!$week_cvterm_id) {
        return { planting_date => $planting_date, planting_date_calendar => $planting_date_full_calendar_datetime, drone_run_date => $drone_date, drone_run_date_calendar => $drone_date_full_calendar_datetime, time_difference_weeks => $time_diff_weeks, time_difference_days => $time_diff_days, rounded_time_difference_weeks => $rounded_time_diff_weeks, error => 'The time ontology term was not found automatically! Maybe the field trial planting date or the drone run date are not correct in the database? This should not be possible, please contact us.'};
    }

    my $week_term = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $week_cvterm_id, 'extended');
    my $day_term = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $day_cvterm_id, 'extended');

    return { planting_date => $planting_date, planting_date_calendar => $planting_date_full_calendar_datetime, drone_run_date => $drone_date, drone_run_date_calendar => $drone_date_full_calendar_datetime, time_difference_weeks => $time_diff_weeks, time_difference_days => $time_diff_days, rounded_time_difference_weeks => $rounded_time_diff_weeks, time_ontology_week_cvterm_id => $week_cvterm_id, time_ontology_week_term => $week_term, time_ontology_day_cvterm_id => $day_cvterm_id, time_ontology_day_term => $day_term};
}

sub standard_process_apply : Path('/api/drone_imagery/standard_process_apply') : ActionClass('REST') { }
sub standard_process_apply_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $sp_person_id);
    my $metadata_schema = $c->dbic_schema('CXGN::Metadata::Schema', undef, $sp_person_id);
    my $phenome_schema = $c->dbic_schema('CXGN::Phenome::Schema', undef, $sp_person_id);
    my $apply_drone_run_band_project_ids_input = decode_json $c->req->param('apply_drone_run_band_project_ids');
    my $field_trial_id = $c->req->param('field_trial_id');
    my $drone_run_band_project_id_input = $c->req->param('drone_run_band_project_id');
    my $drone_run_project_id_input = $c->req->param('drone_run_project_id');
    my $time_cvterm_id_input = $c->req->param('time_cvterm_id');
    my $vegetative_indices = decode_json $c->req->param('vegetative_indices');
    my $phenotype_methods = $c->req->param('phenotype_types') ? decode_json $c->req->param('phenotype_types') : ['zonal'];
    my $standard_process_type = $c->req->param('standard_process_type');
    my $camera_rig_apply = $c->req->param('apply_to_all_drone_runs_from_same_camera_rig') eq 'Yes' ? 1 : 0;
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $rotate_angle_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_rotate_angle', 'project_property')->cvterm_id();
    my $cropping_polygon_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_cropped_polygon', 'project_property')->cvterm_id();
    my $plot_polygon_template_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_plot_polygons', 'project_property')->cvterm_id();
    my $drone_run_field_trial_project_relationship_type_id_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_on_field_trial', 'project_relationship')->cvterm_id();
    my $drone_run_drone_run_band_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_on_drone_run', 'project_relationship')->cvterm_id();
    my $drone_run_camera_rig_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_camera_rig_description', 'project_property')->cvterm_id();
    my $process_indicator_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_standard_process_in_progress', 'project_property')->cvterm_id();
    my $processed_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_standard_process_completed', 'project_property')->cvterm_id();
    my $processed_minimal_vi_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_standard_process_vi_completed', 'project_property')->cvterm_id();
    my $project_image_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $drone_run_band_type_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_project_type', 'project_property')->cvterm_id();

    my @apply_projects;
    if ($camera_rig_apply) {
        my $q = "SELECT value FROM projectprop WHERE project_id = ? AND type_id = $drone_run_camera_rig_cvterm_id;";
        my $h = $bcs_schema->storage->dbh()->prepare($q);
        $h->execute($drone_run_project_id_input);
        my ($camera_rig) = $h->fetchrow_array();

        my $q2 = "SELECT drone_run_band.project_id, drone_run.project_id, processed.value, inprogress.value
            FROM project AS drone_run_band
            JOIN project_relationship ON(project_relationship.subject_project_id = drone_run_band.project_id AND project_relationship.type_id = $drone_run_drone_run_band_type_id)
            JOIN project AS drone_run ON(project_relationship.object_project_id = drone_run.project_id)
            JOIN project_relationship AS field_trial_rel ON (drone_run.project_id = field_trial_rel.subject_project_id AND field_trial_rel.type_id=$drone_run_field_trial_project_relationship_type_id_cvterm_id)
            JOIN projectprop AS camera_rig ON(drone_run.project_id = camera_rig.project_id AND camera_rig.type_id=$drone_run_camera_rig_cvterm_id AND camera_rig.value=?)
            LEFT JOIN projectprop AS processed ON(drone_run.project_id = processed.project_id AND processed.type_id=$processed_cvterm_id)
            LEFT JOIN projectprop AS inprogress ON(drone_run.project_id = inprogress.project_id AND inprogress.type_id=$process_indicator_cvterm_id)
            WHERE field_trial_rel.object_project_id = ?;";

        my $h2 = $bcs_schema->storage->dbh()->prepare($q2);
        $h2->execute($camera_rig, $field_trial_id);
        my %apply_project_hash;
        while (my ($drone_run_band_project_id, $drone_run_project_id, $processed, $inprogress) = $h2->fetchrow_array()) {
            if (!$processed && !$inprogress) {
                push @{$apply_project_hash{$drone_run_project_id}}, $drone_run_band_project_id;
            }
        }
        while (my ($k, $v) = each %apply_project_hash) {
            my $time_hash = _perform_get_weeks_drone_run_after_planting($bcs_schema, $k);
            my $time_cvterm_id = $time_hash->{time_ontology_day_cvterm_id};
            push @apply_projects, {
                drone_run_band_project_id => $drone_run_band_project_id_input,
                apply_drone_run_band_project_ids => $v,
                drone_run_project_id => $k,
                time_cvterm_id => $time_cvterm_id
            };
        }
    } else {
        @apply_projects = (
            {
                drone_run_band_project_id => $drone_run_band_project_id_input,
                apply_drone_run_band_project_ids => $apply_drone_run_band_project_ids_input,
                drone_run_project_id => $drone_run_project_id_input,
                time_cvterm_id => $time_cvterm_id_input
            }
        );
    }
    print STDERR Dumper \@apply_projects;

    foreach (@apply_projects) {
        my $drone_run_project_id_in = $_->{drone_run_project_id};
        my $time_cvterm_id = $_->{time_cvterm_id};
        my $drone_run_band_project_id = $_->{drone_run_band_project_id};
        my $apply_drone_run_band_project_ids = $_->{apply_drone_run_band_project_ids};

        my $drone_run_process_in_progress = $bcs_schema->resultset('Project::Projectprop')->update_or_create({
            type_id=>$process_indicator_cvterm_id,
            project_id=>$drone_run_project_id_in,
            rank=>0,
            value=>1
        },
        {
            key=>'projectprop_c1'
        });

        my $drone_run_process_completed = $bcs_schema->resultset('Project::Projectprop')->update_or_create({
            type_id=>$processed_cvterm_id,
            project_id=>$drone_run_project_id_in,
            rank=>0,
            value=>0
        },
        {
            key=>'projectprop_c1'
        });

        my $drone_run_process_minimal_vi_completed = $bcs_schema->resultset('Project::Projectprop')->update_or_create({
            type_id=>$processed_minimal_vi_cvterm_id,
            project_id=>$drone_run_project_id_in,
            rank=>0,
            value=>0
        },
        {
            key=>'projectprop_c1'
        });

        my %vegetative_indices_hash;
        foreach (@$vegetative_indices) {
            $vegetative_indices_hash{$_}++;
        }

        my $q = "SELECT rotate.value, plot_polygons.value, cropping.value, drone_run.project_id, drone_run.name
            FROM project AS drone_run_band
            JOIN project_relationship ON(project_relationship.subject_project_id = drone_run_band.project_id AND project_relationship.type_id = $drone_run_drone_run_band_type_id)
            JOIN project AS drone_run ON(project_relationship.object_project_id = drone_run.project_id)
            JOIN projectprop AS rotate ON(drone_run_band.project_id = rotate.project_id AND rotate.type_id=$rotate_angle_type_id)
            JOIN projectprop AS plot_polygons ON(drone_run_band.project_id = plot_polygons.project_id AND plot_polygons.type_id=$plot_polygon_template_type_id)
            JOIN projectprop AS cropping ON(drone_run_band.project_id = cropping.project_id AND cropping.type_id=$cropping_polygon_type_id)
            WHERE drone_run_band.project_id = $drone_run_band_project_id;";

        my $h = $bcs_schema->storage->dbh()->prepare($q);
        $h->execute();
        my ($rotate_value, $plot_polygons_value, $cropping_value, $drone_run_project_id, $drone_run_project_name) = $h->fetchrow_array();

        my %selected_drone_run_band_types;
        my $q2 = "SELECT project_md_image.image_id, drone_run_band_type.value, drone_run_band.project_id
            FROM project AS drone_run_band
            JOIN projectprop AS drone_run_band_type ON(drone_run_band_type.project_id = drone_run_band.project_id AND drone_run_band_type.type_id = $drone_run_band_type_type_id)
            JOIN phenome.project_md_image AS project_md_image ON(project_md_image.project_id = drone_run_band.project_id)
            JOIN metadata.md_image ON(project_md_image.image_id = metadata.md_image.image_id)
            WHERE project_md_image.type_id = $project_image_type_id
            AND drone_run_band.project_id = ?
            AND metadata.md_image.obsolete = 'f';";

        my $h2 = $bcs_schema->storage->dbh()->prepare($q2);
        $h2->execute($drone_run_band_project_id);
        my ($image_id, $drone_run_band_type, $drone_run_band_project_id_q) = $h2->fetchrow_array();
        $selected_drone_run_band_types{$drone_run_band_type} = $drone_run_band_project_id_q;

        my $check_image = SGN::Image->new( $bcs_schema->storage->dbh, $image_id, $c );
        my $check_image_fullpath = $check_image->get_filename('original_converted', 'full');
        my ($check_image_width, $check_image_height) = imgsize($check_image_fullpath);

        my $term_map = CXGN::DroneImagery::ImageTypes::get_base_imagery_observation_unit_plot_polygon_term_map();

        my %drone_run_band_info;
        foreach my $apply_drone_run_band_project_id (@$apply_drone_run_band_project_ids) {
            my $h2 = $bcs_schema->storage->dbh()->prepare($q2);
            $h2->execute($apply_drone_run_band_project_id);
            my ($image_id, $drone_run_band_type, $drone_run_band_project_id) = $h2->fetchrow_array();
            $selected_drone_run_band_types{$drone_run_band_type} = $drone_run_band_project_id;

            my $check_image_apply = SGN::Image->new( $bcs_schema->storage->dbh, $image_id, $c );
            my $check_image_apply_fullpath = $check_image_apply->get_filename('original_converted', 'full');
            my ($check_image_apply_width, $check_image_apply_height) = imgsize($check_image_apply_fullpath);

            my $apply_image_width_ratio = $check_image_width/$check_image_apply_width;
            my $apply_image_height_ratio = $check_image_height/$check_image_apply_height;

            my $dir = $c->tempfiles_subdir('/drone_imagery_rotate');
            my $archive_rotate_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_rotate/imageXXXX');
            $archive_rotate_temp_image .= '.png';

            my $rotate_return = _perform_image_rotate($c, $bcs_schema, $metadata_schema, $drone_run_band_project_id, $image_id, $rotate_value, 0, $user_id, $user_name, $user_role, $archive_rotate_temp_image, 0, 0, 1, 0);
            my $rotated_image_id = $rotate_return->{rotated_image_id};

            $dir = $c->tempfiles_subdir('/drone_imagery_cropped_image');
            my $archive_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_cropped_image/imageXXXX');
            $archive_temp_image .= '.png';

            my $cropping_return = _perform_image_cropping($c, $bcs_schema, $drone_run_band_project_id, $rotated_image_id, $cropping_value, $user_id, $user_name, $user_role, $archive_temp_image, $apply_image_width_ratio, $apply_image_height_ratio);
            my $cropped_image_id = $cropping_return->{cropped_image_id};

            $dir = $c->tempfiles_subdir('/drone_imagery_denoise');
            my $archive_denoise_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_denoise/imageXXXX');
            $archive_denoise_temp_image .= '.png';

            my $denoise_return = _perform_image_denoise($c, $bcs_schema, $metadata_schema, $cropped_image_id, $drone_run_band_project_id, $user_id, $user_name, $user_role, $archive_denoise_temp_image);
            my $denoised_image_id = $denoise_return->{denoised_image_id};

            $drone_run_band_info{$drone_run_band_project_id} = {
                denoised_image_id => $denoised_image_id,
                rotate_value => $rotate_value,
                cropping_value => $cropping_value,
                drone_run_band_type => $drone_run_band_type,
                drone_run_project_id => $drone_run_project_id_in,
                drone_run_project_name => $drone_run_project_name,
                plot_polygons_value => $plot_polygons_value,
                check_resize => 1,
                keep_original_size_rotate => 0
            };

            my @denoised_plot_polygon_type = @{$term_map->{$drone_run_band_type}->{observation_unit_plot_polygon_types}->{base}};
            my @denoised_background_threshold_removed_imagery_types = @{$term_map->{$drone_run_band_type}->{imagery_types}->{threshold_background}};
            my @denoised_background_threshold_removed_plot_polygon_types = @{$term_map->{$drone_run_band_type}->{observation_unit_plot_polygon_types}->{threshold_background}};

            foreach (@denoised_plot_polygon_type) {
                my $plot_polygon_original_denoised_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $denoised_image_id, $drone_run_band_project_id, $plot_polygons_value, $_, $user_id, $user_name, $user_role, 0, 0, $apply_image_width_ratio, $apply_image_height_ratio, 'rectangular_square');
            }

            for my $iterator (0..(scalar(@denoised_background_threshold_removed_imagery_types)-1)) {
                $dir = $c->tempfiles_subdir('/drone_imagery_remove_background');
                my $archive_remove_background_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_remove_background/imageXXXX');
                $archive_remove_background_temp_image .= '.png';

                my $background_removed_threshold_return = _perform_image_background_remove_threshold_percentage($c, $bcs_schema, $denoised_image_id, $drone_run_band_project_id, $denoised_background_threshold_removed_imagery_types[$iterator], '25', '25', $user_id, $user_name, $user_role, $archive_remove_background_temp_image);

                my $plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $background_removed_threshold_return->{removed_background_image_id}, $drone_run_band_project_id, $plot_polygons_value, $denoised_background_threshold_removed_plot_polygon_types[$iterator], $user_id, $user_name, $user_role, 0, 0, $apply_image_width_ratio, $apply_image_height_ratio, 'rectangular_square');
            }
        }

        print STDERR Dumper \%selected_drone_run_band_types;
        print STDERR Dumper \%vegetative_indices_hash;

        _perform_minimal_vi_standard_process($c, $bcs_schema, $metadata_schema, \%vegetative_indices_hash, \%selected_drone_run_band_types, \%drone_run_band_info, $user_id, $user_name, $user_role, 'rectangular_square');

        $drone_run_process_in_progress = $bcs_schema->resultset('Project::Projectprop')->update_or_create({
            type_id=>$process_indicator_cvterm_id,
            project_id=>$drone_run_project_id_in,
            rank=>0,
            value=>0
        },
        {
            key=>'projectprop_c1'
        });

        $drone_run_process_completed = $bcs_schema->resultset('Project::Projectprop')->update_or_create({
            type_id=>$processed_cvterm_id,
            project_id=>$drone_run_project_id_in,
            rank=>0,
            value=>1
        },
        {
            key=>'projectprop_c1'
        });

        $drone_run_process_minimal_vi_completed = $bcs_schema->resultset('Project::Projectprop')->update_or_create({
            type_id=>$processed_minimal_vi_cvterm_id,
            project_id=>$drone_run_project_id_in,
            rank=>0,
            value=>1
        },
        {
            key=>'projectprop_c1'
        });

        my $return = _perform_phenotype_automated($c, $bcs_schema, $metadata_schema, $phenome_schema, $drone_run_project_id_in, $time_cvterm_id, $phenotype_methods, $standard_process_type, 1, undef, $user_id, $user_name, $user_role);
    }

    my @result;
    $c->stash->{rest} = { data => \@result, success => 1 };
}

sub standard_process_apply_ground_control_points : Path('/api/drone_imagery/standard_process_apply_ground_control_points') : ActionClass('REST') { }
sub standard_process_apply_ground_control_points_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $sp_person_id);
    my $metadata_schema = $c->dbic_schema('CXGN::Metadata::Schema', undef, $sp_person_id);
    my $phenome_schema = $c->dbic_schema('CXGN::Phenome::Schema', undef, $sp_person_id);
    my $field_trial_id = $c->req->param('field_trial_id');
    my $drone_run_project_id_input = $c->req->param('drone_run_project_id');
    my $drone_run_band_project_id_input = $c->req->param('drone_run_band_project_id');
    my $gcp_drone_run_project_id_input = $c->req->param('gcp_drone_run_project_id');
    my $time_cvterm_id = $c->req->param('time_cvterm_id');
    my $is_test = $c->req->param('is_test');
    my $is_test_run = $c->req->param('test_run');
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $phenotype_methods = ['zonal'];
    my $standard_process_type = 'minimal';

    my $vegetative_indices = ['TGI', 'VARI', 'NDVI', 'NDRE'];
    my %vegetative_indices_hash;
    foreach (@$vegetative_indices) {
        $vegetative_indices_hash{$_}++;
    }

    if (!$gcp_drone_run_project_id_input) {
        $c->stash->{rest} = { error => "Please select an imaging event to use as a template!" };
        $c->detach();
    }

    my $drone_run_band_drone_run_project_relationship_type_id_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_on_drone_run', 'project_relationship')->cvterm_id();
    my $drone_run_band_drone_run_project_type = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_project_type', 'project_property')->cvterm_id();

    my $project_image_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $rotated_image_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'rotated_stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $cropped_image_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'cropped_stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $denoised_project_image_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'denoised_stitched_drone_imagery', 'project_md_image')->cvterm_id();

    my $apply_drone_run_band_project_ids;
    my %apply_drone_run_band_project_ids_type_hash;
    my $drone_run_band_q = "SELECT project.project_id, project_md_image.type_id, projectprop.value
        FROM project
        JOIN projectprop ON(project.project_id = projectprop.project_id)
        JOIN project_relationship ON(project.project_id=project_relationship.subject_project_id AND project_relationship.type_id=$drone_run_band_drone_run_project_relationship_type_id_cvterm_id)
        JOIN phenome.project_md_image AS project_md_image ON(project.project_id = project_md_image.project_id)
        WHERE project_relationship.object_project_id=?
        AND project_md_image.type_id=?
        AND projectprop.type_id=$drone_run_band_drone_run_project_type;";
    my $drone_run_band_h = $bcs_schema->storage->dbh()->prepare($drone_run_band_q);
    $drone_run_band_h->execute($drone_run_project_id_input, $project_image_type_id);
    while (my ($drone_run_band_project_id, $drone_run_band_project_image_type_id, $drone_run_band_project_type) = $drone_run_band_h->fetchrow_array()) {
        push @$apply_drone_run_band_project_ids, $drone_run_band_project_id;
        $apply_drone_run_band_project_ids_type_hash{$drone_run_band_project_id} = {
            image_type_id => $drone_run_band_project_image_type_id,
            band_type => $drone_run_band_project_type
        };
    }
    print STDERR Dumper \%apply_drone_run_band_project_ids_type_hash;
    my $drone_run_band_project_type_current = $apply_drone_run_band_project_ids_type_hash{$drone_run_band_project_id_input}->{band_type};

    my $gcp_drone_run_band_q = "SELECT project.project_id
        FROM project
        JOIN projectprop ON(project.project_id = projectprop.project_id)
        JOIN project_relationship ON(project.project_id=project_relationship.subject_project_id AND project_relationship.type_id=$drone_run_band_drone_run_project_relationship_type_id_cvterm_id)
        WHERE project_relationship.object_project_id=?
        AND projectprop.type_id=$drone_run_band_drone_run_project_type
        AND projectprop.value='$drone_run_band_project_type_current';";
    my $gcp_drone_run_band_h = $bcs_schema->storage->dbh()->prepare($gcp_drone_run_band_q);
    $gcp_drone_run_band_h->execute($gcp_drone_run_project_id_input);
    my ($gcp_drone_run_band_project_id) = $gcp_drone_run_band_h->fetchrow_array();

    my $drone_run_gcp_type_id_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_ground_control_points', 'project_property')->cvterm_id();

    my $template_gcp_q = "SELECT value
        FROM projectprop
        JOIN project USING(project_id)
        WHERE project.project_id=? AND projectprop.type_id=$drone_run_gcp_type_id_cvterm_id;";
    my $template_gcp_h = $bcs_schema->storage->dbh()->prepare($template_gcp_q);
    $template_gcp_h->execute($gcp_drone_run_project_id_input);
    my ($template_gcp_points_json) = $template_gcp_h->fetchrow_array();
    my $template_gcp_points = decode_json $template_gcp_points_json;
    # print STDERR Dumper $template_gcp_points;
    if (scalar(keys %$template_gcp_points)<3) {
        $c->stash->{rest} = { error => "Not enough GCP points defined in the template drone run!" };
        $c->detach();
    }

    my $current_gcp_q = "SELECT value
        FROM projectprop
        JOIN project USING(project_id)
        WHERE project.project_id=? AND projectprop.type_id=$drone_run_gcp_type_id_cvterm_id;";
    my $current_gcp_h = $bcs_schema->storage->dbh()->prepare($current_gcp_q);
    $current_gcp_h->execute($drone_run_project_id_input);
    my ($current_gcp_points_json) = $current_gcp_h->fetchrow_array();
    my $current_gcp_points = decode_json $current_gcp_points_json;
    # print STDERR Dumper $current_gcp_points;
    if (scalar(keys %$current_gcp_points)<3) {
        $c->stash->{rest} = { error => "Not enough GCP points defined in the current drone run!" };
        $c->detach();
    }

    my $tl_gcp_template_point_x = 1000000000;
    my $tl_gcp_template_point_y = 1000000000;
    my $tr_gcp_template_point_x = 0;
    my $tr_gcp_template_point_y = 1000000000;
    my $br_gcp_template_point_x = 0;
    my $br_gcp_template_point_y = 0;
    my $bl_gcp_template_point_x = 1000000000;
    my $bl_gcp_template_point_y = 0;

    my @template_x_vals;
    my @template_y_vals;
    my @gcp_points_template;
    my @gcp_names_template;
    while (my ($name, $o) = each %$template_gcp_points) {
        if (exists($current_gcp_points->{$name})) {
            my $x = $o->{x_pos};
            my $y = $o->{y_pos};
            push @template_x_vals, $x;
            push @template_y_vals, $y;
            push @gcp_points_template, [$x, $y];
            push @gcp_names_template, $name;

            if ($x < $tl_gcp_template_point_x) {
                $tl_gcp_template_point_x = $x;
            }
            if ($y < $tl_gcp_template_point_y) {
                $tl_gcp_template_point_y = $y;
            }
            if ($x > $tr_gcp_template_point_x) {
                $tr_gcp_template_point_x = $x;
            }
            if ($y < $tr_gcp_template_point_y) {
                $tr_gcp_template_point_y = $y;
            }
            if ($x > $br_gcp_template_point_x) {
                $br_gcp_template_point_x = $x;
            }
            if ($y > $br_gcp_template_point_y) {
                $br_gcp_template_point_y = $y;
            }
            if ($x < $bl_gcp_template_point_x) {
                $bl_gcp_template_point_x = $x;
            }
            if ($y > $bl_gcp_template_point_y) {
                $bl_gcp_template_point_y = $y;
            }
        }
    }
    print STDERR Dumper \@gcp_names_template;

    my $template_central_x = sum(@template_x_vals)/scalar(@template_x_vals);
    my $template_central_y = sum(@template_y_vals)/scalar(@template_y_vals);

    my @current_x_vals;
    my @current_y_vals;
    my @gcp_points_current;
    foreach my $name (@gcp_names_template) {
        my $o = $current_gcp_points->{$name};
        my $x = $o->{x_pos};
        my $y = $o->{y_pos};
        push @current_x_vals, $x;
        push @current_y_vals, $y;
        push @gcp_points_current, [$x, $y];
    }

    my $current_central_x = sum(@current_x_vals)/scalar(@current_x_vals);
    my $current_central_y = sum(@current_y_vals)/scalar(@current_y_vals);

    my $rad_conversion = 0.0174533;

    my @angle_rad_templates;
    foreach my $g (@gcp_points_template) {
        my $x_diff = $g->[0]-$template_central_x;
        my $y_diff = $g->[1]-$template_central_y;
        if ($x_diff > 0 && $y_diff > 0) {
            push @angle_rad_templates, atan(abs($x_diff/$y_diff));
        }
        # elsif ($x_diff < 0 && $y_diff > 0) {
        #     push @angle_rad_templates, 360*$rad_conversion - atan(abs($x_diff/$y_diff));
        # }
        elsif ($x_diff < 0 && $y_diff < 0) {
            push @angle_rad_templates, 180*$rad_conversion + atan(abs($x_diff/$y_diff));
        }
        elsif ($x_diff > 0 && $y_diff < 0) {
            push @angle_rad_templates, 180*$rad_conversion - atan(abs($x_diff/$y_diff));
        }
        else {
            push @angle_rad_templates, undef;
        }
    }

    my @angle_rad_currents;
    foreach my $g (@gcp_points_current) {
        my $x_diff = $g->[0]-$current_central_x;
        my $y_diff = $g->[1]-$current_central_y;
        if ($x_diff > 0 && $y_diff > 0) {
            push @angle_rad_currents, atan(abs($x_diff/$y_diff));
        }
        # elsif ($x_diff < 0 && $y_diff > 0) {
        #     push @angle_rad_currents, 360*$rad_conversion - atan(abs($x_diff/$y_diff));
        # }
        elsif ($x_diff < 0 && $y_diff < 0) {
            push @angle_rad_currents, 180*$rad_conversion + atan(abs($x_diff/$y_diff));
        }
        elsif ($x_diff > 0 && $y_diff < 0) {
            push @angle_rad_currents, 180*$rad_conversion - atan(abs($x_diff/$y_diff));
        }
        else {
            push @angle_rad_currents, undef;
        }
    }
    # print STDERR Dumper \@angle_rad_templates;
    # print STDERR Dumper \@angle_rad_currents;

    my $counter = 0;
    my @angle_diffs;
    foreach (@angle_rad_templates) {
        if ($_ && $angle_rad_currents[$counter]) {
            my $diff = $_ - $angle_rad_currents[$counter];
            # print STDERR "DIFF:". $diff."\n";
            push @angle_diffs, $diff;
        }
        $counter++;
    }
    print STDERR Dumper \@angle_diffs;

    my $rotate_rad_gcp = sum(@angle_diffs)/scalar(@angle_diffs);
    print STDERR "AVG ROTATION: $rotate_rad_gcp\n";

    my $q2 = "SELECT project_md_image.image_id, drone_run_band_type.value
        FROM project AS drone_run_band
        JOIN projectprop AS drone_run_band_type ON(drone_run_band_type.project_id = drone_run_band.project_id AND drone_run_band_type.type_id = $drone_run_band_drone_run_project_type)
        JOIN phenome.project_md_image AS project_md_image ON(project_md_image.project_id = drone_run_band.project_id)
        JOIN metadata.md_image ON(project_md_image.image_id = metadata.md_image.image_id)
        WHERE project_md_image.type_id = ?
        AND drone_run_band.project_id = ?
        AND metadata.md_image.obsolete = 'f'
        AND drone_run_band_type.value='$drone_run_band_project_type_current';";

    my $h2 = $bcs_schema->storage->dbh()->prepare($q2);
    $h2->execute($project_image_type_id, $drone_run_band_project_id_input);
    my ($check_image_id, $check_drone_run_band_type) = $h2->fetchrow_array();

    my $check_image = SGN::Image->new( $bcs_schema->storage->dbh, $check_image_id, $c );
    my $check_image_url = $check_image->get_image_url("original");
    my $check_image_fullpath = $check_image->get_filename('original_converted', 'full');
    my ($check_image_width, $check_image_height) = imgsize($check_image_fullpath);

    my $tl_o_x = 0;
    my $tl_o_y = 0;
    my $tr_o_x = $check_image_width;
    my $tr_o_y = 0;
    my $br_o_x = $check_image_width;
    my $br_o_y = $check_image_height;
    my $bl_o_x = 0;
    my $bl_o_y = $check_image_height;
    my $tl_o_rotated_x = ($tl_o_x - $check_image_width/2)*cos($rotate_rad_gcp*-1) - ($tl_o_y - $check_image_height/2)*sin($rotate_rad_gcp*-1) + $check_image_width/2;
    my $tl_o_rotated_y = ($tl_o_x - $check_image_width/2)*sin($rotate_rad_gcp*-1) + ($tl_o_y - $check_image_height/2)*cos($rotate_rad_gcp*-1) + $check_image_height/2;
    my $tr_o_rotated_x = ($tr_o_x - $check_image_width/2)*cos($rotate_rad_gcp*-1) - ($tr_o_y - $check_image_height/2)*sin($rotate_rad_gcp*-1) + $check_image_width/2;
    my $tr_o_rotated_y = ($tr_o_x - $check_image_width/2)*sin($rotate_rad_gcp*-1) + ($tr_o_y - $check_image_height/2)*cos($rotate_rad_gcp*-1) + $check_image_height/2;
    my $br_o_rotated_x = ($br_o_x - $check_image_width/2)*cos($rotate_rad_gcp*-1) - ($br_o_y - $check_image_height/2)*sin($rotate_rad_gcp*-1) + $check_image_width/2;
    my $br_o_rotated_y = ($br_o_x - $check_image_width/2)*sin($rotate_rad_gcp*-1) + ($br_o_y - $check_image_height/2)*cos($rotate_rad_gcp*-1) + $check_image_height/2;
    my $bl_o_rotated_x = ($bl_o_x - $check_image_width/2)*cos($rotate_rad_gcp*-1) - ($bl_o_y - $check_image_height/2)*sin($rotate_rad_gcp*-1) + $check_image_width/2;
    my $bl_o_rotated_y = ($bl_o_x - $check_image_width/2)*sin($rotate_rad_gcp*-1) + ($bl_o_y - $check_image_height/2)*cos($rotate_rad_gcp*-1) + $check_image_height/2;
    my $min_o_rot_x = 100000000;
    my $min_o_rot_y = 100000000;
    foreach (($tl_o_rotated_x, $tr_o_rotated_x, $br_o_rotated_x, $bl_o_rotated_x)) {
        if ($_ < $min_o_rot_x) {
            $min_o_rot_x = $_;
        }
    }
    foreach (($tl_o_rotated_y, $tr_o_rotated_y, $br_o_rotated_y, $bl_o_rotated_y)) {
        if ($_ < $min_o_rot_y) {
            $min_o_rot_y = $_;
        }
    }
    print STDERR Dumper [$min_o_rot_x, $min_o_rot_y];

    my @rotated_current_points;
    foreach (@gcp_points_current) {
        my $x_rot = ($_->[0] - $check_image_width/2)*cos($rotate_rad_gcp*-1) - ($_->[1] - $check_image_height/2)*sin($rotate_rad_gcp*-1) + $check_image_width/2 - $min_o_rot_x;
        my $y_rot = ($_->[0] - $check_image_width/2)*sin($rotate_rad_gcp*-1) + ($_->[1] - $check_image_height/2)*cos($rotate_rad_gcp*-1) + $check_image_height/2 - $min_o_rot_y;
        push @rotated_current_points, [$x_rot, $y_rot];
    }

    my $tl_gcp_current_point_x = 1000000000;
    my $tl_gcp_current_point_y = 1000000000;
    my $tr_gcp_current_point_x = 0;
    my $tr_gcp_current_point_y = 1000000000;
    my $br_gcp_current_point_x = 0;
    my $br_gcp_current_point_y = 0;
    my $bl_gcp_current_point_x = 1000000000;
    my $bl_gcp_current_point_y = 0;

    foreach (@rotated_current_points) {
        my $x = $_->[0];
        my $y = $_->[1];

        if ($x < $tl_gcp_current_point_x) {
            $tl_gcp_current_point_x = $x;
        }
        if ($y < $tl_gcp_current_point_y) {
            $tl_gcp_current_point_y = $y;
        }
        if ($x > $tr_gcp_current_point_x) {
            $tr_gcp_current_point_x = $x;
        }
        if ($y < $tr_gcp_current_point_y) {
            $tr_gcp_current_point_y = $y;
        }
        if ($x > $br_gcp_current_point_x) {
            $br_gcp_current_point_x = $x;
        }
        if ($y > $br_gcp_current_point_y) {
            $br_gcp_current_point_y = $y;
        }
        if ($x < $bl_gcp_current_point_x) {
            $bl_gcp_current_point_x = $x;
        }
        if ($y > $bl_gcp_current_point_y) {
            $bl_gcp_current_point_y = $y;
        }
    }

    my $dir = $c->tempfiles_subdir('/drone_imagery_rotate');
    my $archive_rotate_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_rotate/imageXXXX');
    $archive_rotate_temp_image .= '.png';
    my $rotate_return = _perform_image_rotate($c, $bcs_schema, $metadata_schema, $drone_run_band_project_id_input, $check_image_id, $rotate_rad_gcp/$rad_conversion, 0, $user_id, $user_name, $user_role, $archive_rotate_temp_image, 0, 0, 1, 0);
    my $rotated_image_id = $rotate_return->{rotated_image_id};

    my $h_rotate_check = $bcs_schema->storage->dbh()->prepare($q2);
    $h_rotate_check->execute($rotated_image_type_id, $gcp_drone_run_band_project_id);
    my ($rotate_check_image_id, $rotate_check_drone_run_band_type) = $h_rotate_check->fetchrow_array();

    my $rotate_check_target_image = SGN::Image->new( $bcs_schema->storage->dbh, $rotated_image_id, $c );
    my $rotate_check_target_image_url = $rotate_check_target_image->get_image_url("original");
    my $rotate_check_target_image_fullpath = $rotate_check_target_image->get_filename('original_converted', 'full');
    my ($rotate_check_target_image_width, $rotate_check_target_image_height) = imgsize($rotate_check_target_image_fullpath);
    print STDERR "Target Rotation: $rotate_check_target_image_width $rotate_check_target_image_height \n";

    my $rotate_check_image = SGN::Image->new( $bcs_schema->storage->dbh, $rotate_check_image_id, $c );
    my $rotate_check_image_url = $rotate_check_image->get_image_url("original");
    my $rotate_check_image_fullpath = $rotate_check_image->get_filename('original_converted', 'full');
    my ($rotate_check_image_width, $rotate_check_image_height) = imgsize($rotate_check_image_fullpath);
    print STDERR "Template Rotation: $rotate_check_image_width $rotate_check_image_height \n";

    # my $template_gcp_x_scale = $rotate_check_image_width/$rotate_check_target_image_width;
    # my $template_gcp_y_scale = $rotate_check_image_height/$rotate_check_target_image_height;
    my $template_gcp_x_scale;
    if ($tr_gcp_template_point_x - $tl_gcp_template_point_x != 0 && $tr_gcp_current_point_x - $tl_gcp_current_point_x != 0) {
        $template_gcp_x_scale = ($tr_gcp_template_point_x - $tl_gcp_template_point_x) / ($tr_gcp_current_point_x - $tl_gcp_current_point_x);
    }
    elsif ($br_gcp_template_point_x - $bl_gcp_template_point_x != 0 && $br_gcp_current_point_x - $bl_gcp_current_point_x != 0) {
        $template_gcp_x_scale = ($br_gcp_template_point_x - $bl_gcp_template_point_x) / ($br_gcp_current_point_x - $bl_gcp_current_point_x);
    }
    else {
        $c->stash->{rest} = { error => "Not enough GCP points to get the x scale!" };
        $c->detach();
    }
    my $template_gcp_y_scale;
    if ($bl_gcp_template_point_y - $tl_gcp_template_point_y != 0 && $bl_gcp_current_point_y - $tl_gcp_current_point_y != 0) {
        $template_gcp_y_scale = ($bl_gcp_template_point_y - $tl_gcp_template_point_y) / ($bl_gcp_current_point_y - $tl_gcp_current_point_y);
    }
    if ($br_gcp_template_point_y - $tr_gcp_template_point_y != 0 && $br_gcp_current_point_y - $tr_gcp_current_point_y != 0) {
        $template_gcp_y_scale = ($br_gcp_template_point_y - $tr_gcp_template_point_y) / ($br_gcp_current_point_y - $tr_gcp_current_point_y);
    }
    else {
        $c->stash->{rest} = { error => "Not enough GCP points to get the y scale!" };
        $c->detach();
    }
    print STDERR Dumper [$template_gcp_x_scale, $template_gcp_y_scale];

    my $rotate_angle_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_rotate_angle', 'project_property')->cvterm_id();
    my $cropping_polygon_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_cropped_polygon', 'project_property')->cvterm_id();
    my $plot_polygon_template_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_plot_polygons', 'project_property')->cvterm_id();
    my $drone_run_drone_run_band_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_on_drone_run', 'project_relationship')->cvterm_id();

    my $q = "SELECT rotate.value, plot_polygons.value, cropping.value, drone_run.project_id, drone_run.name
        FROM project AS drone_run_band
        JOIN project_relationship ON(project_relationship.subject_project_id = drone_run_band.project_id AND project_relationship.type_id = $drone_run_drone_run_band_type_id)
        JOIN project AS drone_run ON(project_relationship.object_project_id = drone_run.project_id)
        JOIN projectprop AS rotate ON(drone_run_band.project_id = rotate.project_id AND rotate.type_id=$rotate_angle_type_id)
        JOIN projectprop AS plot_polygons ON(drone_run_band.project_id = plot_polygons.project_id AND plot_polygons.type_id=$plot_polygon_template_type_id)
        JOIN projectprop AS cropping ON(drone_run_band.project_id = cropping.project_id AND cropping.type_id=$cropping_polygon_type_id)
        WHERE drone_run_band.project_id = $gcp_drone_run_band_project_id;";

    my $h = $bcs_schema->storage->dbh()->prepare($q);
    $h->execute();
    my ($rotate_value_old, $plot_polygons_value_json, $cropping_value_json, $drone_run_project_id, $drone_run_project_name) = $h->fetchrow_array();
    print STDERR Dumper $rotate_value_old;
    print STDERR Dumper $rotate_value_old * $rad_conversion;
    print STDERR Dumper $cropping_value_json;
    print STDERR Dumper $plot_polygons_value_json;
    my $cropping_value_old = decode_json $cropping_value_json;
    my $plot_polygons_value_old = decode_json $plot_polygons_value_json;

    my $min_old_crop_x = 1000000000;
    my $min_old_crop_y = 1000000000;
    foreach (@{$cropping_value_old->[0]}) {
        my $x = $_->{'x'};
        my $y = $_->{'y'};
        if ($x < $min_old_crop_x) {
            $min_old_crop_x = $x;
        }
        if ($y < $min_old_crop_y) {
            $min_old_crop_y = $y;
        }
    }

    my @old_cropping_val_dists;
    foreach (@{$cropping_value_old->[0]}) {
        my $x = $_->{'x'} - $min_old_crop_x;
        my $y = $_->{'y'} - $min_old_crop_y;
        my @diffs;
        foreach my $t (@gcp_points_template) {
            push @diffs, [$t->[0] - $x, $t->[1] - $y];
        }
        push @old_cropping_val_dists, \@diffs;
    }
    # print STDERR Dumper \@old_cropping_val_dists;

    my $image_crop;
    my $counter_c = 0;
    foreach my $o (@old_cropping_val_dists) {
        my @pos_x;
        my @pos_y;
        my $counter = 0;
        foreach my $r (@rotated_current_points) {
            my $o_x = $o->[$counter]->[0]/$template_gcp_x_scale;
            my $o_y = $o->[$counter]->[1]/$template_gcp_y_scale;
            my $r_x = $r->[0];
            my $r_y = $r->[1];
            push @pos_x, $r_x - $o_x;
            push @pos_y, $r_y - $o_y;
            $counter++;
        }
        $image_crop->[0]->[$counter_c] = {
            x => sum(@pos_x)/scalar(@pos_x),
            y => sum(@pos_y)/scalar(@pos_y)
        };
        $counter_c++;
    }
    # print STDERR Dumper $image_crop;

    $dir = $c->tempfiles_subdir('/drone_imagery_cropped_image');
    my $archive_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_cropped_image/imageXXXX');
    $archive_temp_image .= '.png';

    my $check_cropping_return = _perform_image_cropping($c, $bcs_schema, $drone_run_band_project_id_input, $rotated_image_id, encode_json $image_crop, $user_id, $user_name, $user_role, $archive_temp_image, 1, 1);
    my $check_cropped_image_id = $check_cropping_return->{cropped_image_id};

    my $crop_check_target_image = SGN::Image->new( $bcs_schema->storage->dbh, $check_cropped_image_id, $c );
    my $crop_check_target_image_url = $crop_check_target_image->get_image_url("original");
    my $crop_check_target_image_fullpath = $crop_check_target_image->get_filename('original_converted', 'full');

    my $min_new_crop_x = 1000000000;
    my $min_new_crop_y = 1000000000;
    foreach (@{$image_crop->[0]}) {
        my $x = $_->{'x'};
        my $y = $_->{'y'};
        if ($x < $min_new_crop_x) {
            $min_new_crop_x = $x;
        }
        if ($y < $min_new_crop_y) {
            $min_new_crop_y = $y;
        }
    }

    my @old_plot_val_names;
    my @old_plot_val_dists;
    foreach my $key (sort keys %$plot_polygons_value_old) {
        push @old_plot_val_names, $key;
        my $v = $plot_polygons_value_old->{$key};
        my @points;
        foreach (@{$v}) {
            my $x = $_->{'x'};
            my $y = $_->{'y'};
            my @diffs;
            foreach my $t (@gcp_points_template) {
                push @diffs, [$t->[0] - $x, $t->[1] - $y];
            }
            push @points, \@diffs;
        }
        push @old_plot_val_dists, \@points;
    }

    my %scaled_plot_polygons;
    my $counter_p = 0;
    foreach my $o (@old_plot_val_names) {
        my $point_diffs = $old_plot_val_dists[$counter_p];
        my @adjusted;
        my @adjusted_display;
        foreach my $p (@$point_diffs) {
            my @pos_x;
            my @pos_y;
            my $counter = 0;
            foreach my $r (@rotated_current_points) {
                my $o_x = $p->[$counter]->[0]/$template_gcp_x_scale;
                my $o_y = $p->[$counter]->[1]/$template_gcp_y_scale;
                my $r_x = $r->[0] - $min_new_crop_x;
                my $r_y = $r->[1] - $min_new_crop_y;
                push @pos_x, $r_x - $o_x;
                push @pos_y, $r_y - $o_y;
                $counter++;
            }
            push @adjusted, {
                x => sum(@pos_x)/scalar(@pos_x),
                y => sum(@pos_y)/scalar(@pos_y)
            };
        }
        $scaled_plot_polygons{$o} = \@adjusted;
        $counter_p++;
    }

    if ($is_test_run eq 'Yes') {
        $c->stash->{rest} = { old_cropped_points => $cropping_value_old, cropped_points => $image_crop, rotated_points => \@rotated_current_points, rotated_image_id => $check_cropped_image_id, plot_polygons => \%scaled_plot_polygons };
        $c->detach();
    }

    my $rotate_value = $rotate_rad_gcp/$rad_conversion;
    my $cropping_value = encode_json $image_crop;
    my $plot_polygons_value = encode_json \%scaled_plot_polygons;

    my $process_indicator_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_standard_process_in_progress', 'project_property')->cvterm_id();
    my $processed_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_standard_process_completed', 'project_property')->cvterm_id();
    my $processed_minimal_vi_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_standard_process_vi_completed', 'project_property')->cvterm_id();
    my $drone_run_process_in_progress = $bcs_schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$process_indicator_cvterm_id,
        project_id=>$drone_run_project_id_input,
        rank=>0,
        value=>1
    },
    {
        key=>'projectprop_c1'
    });

    my $drone_run_process_completed = $bcs_schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$processed_cvterm_id,
        project_id=>$drone_run_project_id_input,
        rank=>0,
        value=>0
    },
    {
        key=>'projectprop_c1'
    });

    my $drone_run_process_minimal_vi_completed = $bcs_schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$processed_minimal_vi_cvterm_id,
        project_id=>$drone_run_project_id_input,
        rank=>0,
        value=>0
    },
    {
        key=>'projectprop_c1'
    });

    my %selected_drone_run_band_types;

    my $q4 = "SELECT project_md_image.image_id, drone_run_band_type.value, drone_run_band.project_id
        FROM project AS drone_run_band
        JOIN projectprop AS drone_run_band_type ON(drone_run_band_type.project_id = drone_run_band.project_id AND drone_run_band_type.type_id = $drone_run_band_drone_run_project_type)
        JOIN phenome.project_md_image AS project_md_image ON(project_md_image.project_id = drone_run_band.project_id)
        JOIN metadata.md_image ON(project_md_image.image_id = metadata.md_image.image_id)
        WHERE project_md_image.type_id = ?
        AND drone_run_band.project_id = ?
        AND metadata.md_image.obsolete = 'f';";
    my $h4 = $bcs_schema->storage->dbh()->prepare($q4);

    my $term_map = CXGN::DroneImagery::ImageTypes::get_base_imagery_observation_unit_plot_polygon_term_map();
    my %drone_run_band_info;
    foreach my $apply_drone_run_band_project_id (@$apply_drone_run_band_project_ids) {
        $h4->execute($project_image_type_id, $apply_drone_run_band_project_id);
        my ($image_id, $drone_run_band_type, $drone_run_band_project_id) = $h4->fetchrow_array();
        $selected_drone_run_band_types{$drone_run_band_type} = $drone_run_band_project_id;

        my $check_image_apply_crop = SGN::Image->new( $bcs_schema->storage->dbh, $image_id, $c );
        my $check_image_apply_crop_fullpath = $check_image_apply_crop->get_filename('original_converted', 'full');
        my ($check_image_apply_crop_width, $check_image_apply_crop_height) = imgsize($check_image_apply_crop_fullpath);

        my $apply_image_width_ratio = $check_image_width/$check_image_apply_crop_width;
        my $apply_image_height_ratio = $check_image_height/$check_image_apply_crop_height;

        my $dir = $c->tempfiles_subdir('/drone_imagery_rotate');
        my $archive_rotate_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_rotate/imageXXXX');
        $archive_rotate_temp_image .= '.png';

        my $rotate_return = _perform_image_rotate($c, $bcs_schema, $metadata_schema, $drone_run_band_project_id, $image_id, $rotate_value, 0, $user_id, $user_name, $user_role, $archive_rotate_temp_image, 0, 0, 1, 0);
        my $rotated_image_id = $rotate_return->{rotated_image_id};

        $dir = $c->tempfiles_subdir('/drone_imagery_cropped_image');
        my $archive_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_cropped_image/imageXXXX');
        $archive_temp_image .= '.png';

        my $cropping_return = _perform_image_cropping($c, $bcs_schema, $drone_run_band_project_id, $rotated_image_id, $cropping_value, $user_id, $user_name, $user_role, $archive_temp_image, $apply_image_width_ratio, $apply_image_height_ratio);
        my $cropped_image_id = $cropping_return->{cropped_image_id};

        $dir = $c->tempfiles_subdir('/drone_imagery_denoise');
        my $archive_denoise_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_denoise/imageXXXX');
        $archive_denoise_temp_image .= '.png';

        my $denoise_return = _perform_image_denoise($c, $bcs_schema, $metadata_schema, $cropped_image_id, $drone_run_band_project_id, $user_id, $user_name, $user_role, $archive_denoise_temp_image);
        my $denoised_image_id = $denoise_return->{denoised_image_id};

        $drone_run_band_info{$drone_run_band_project_id} = {
            denoised_image_id => $denoised_image_id,
            rotate_value => $rotate_value,
            cropping_value => $cropping_value,
            drone_run_band_type => $drone_run_band_type,
            drone_run_project_id => $drone_run_project_id_input,
            drone_run_project_name => $drone_run_project_name,
            plot_polygons_value => $plot_polygons_value,
            check_resize => 1,
            keep_original_size_rotate => 0
        };

        my @denoised_plot_polygon_type = @{$term_map->{$drone_run_band_type}->{observation_unit_plot_polygon_types}->{base}};
        my @denoised_background_threshold_removed_imagery_types = @{$term_map->{$drone_run_band_type}->{imagery_types}->{threshold_background}};
        my @denoised_background_threshold_removed_plot_polygon_types = @{$term_map->{$drone_run_band_type}->{observation_unit_plot_polygon_types}->{threshold_background}};

        foreach (@denoised_plot_polygon_type) {
            my $plot_polygon_original_denoised_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $denoised_image_id, $drone_run_band_project_id, $plot_polygons_value, $_, $user_id, $user_name, $user_role, 0, 0, $apply_image_width_ratio, $apply_image_height_ratio, 'rectangular_square');
        }

        for my $iterator (0..(scalar(@denoised_background_threshold_removed_imagery_types)-1)) {
            $dir = $c->tempfiles_subdir('/drone_imagery_remove_background');
            my $archive_remove_background_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_remove_background/imageXXXX');
            $archive_remove_background_temp_image .= '.png';

            my $background_removed_threshold_return = _perform_image_background_remove_threshold_percentage($c, $bcs_schema, $denoised_image_id, $drone_run_band_project_id, $denoised_background_threshold_removed_imagery_types[$iterator], '25', '25', $user_id, $user_name, $user_role, $archive_remove_background_temp_image);

            my $plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $background_removed_threshold_return->{removed_background_image_id}, $drone_run_band_project_id, $plot_polygons_value, $denoised_background_threshold_removed_plot_polygon_types[$iterator], $user_id, $user_name, $user_role, 0, 0, $apply_image_width_ratio, $apply_image_height_ratio, 'rectangular_square');
        }
    }

    print STDERR Dumper \%selected_drone_run_band_types;
    print STDERR Dumper \%vegetative_indices_hash;

    _perform_minimal_vi_standard_process($c, $bcs_schema, $metadata_schema, \%vegetative_indices_hash, \%selected_drone_run_band_types, \%drone_run_band_info, $user_id, $user_name, $user_role, 'rectangular_square');

    $drone_run_process_in_progress = $bcs_schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$process_indicator_cvterm_id,
        project_id=>$drone_run_project_id_input,
        rank=>0,
        value=>0
    },
    {
        key=>'projectprop_c1'
    });

    $drone_run_process_completed = $bcs_schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$processed_cvterm_id,
        project_id=>$drone_run_project_id_input,
        rank=>0,
        value=>1
    },
    {
        key=>'projectprop_c1'
    });

    $drone_run_process_minimal_vi_completed = $bcs_schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$processed_minimal_vi_cvterm_id,
        project_id=>$drone_run_project_id_input,
        rank=>0,
        value=>1
    },
    {
        key=>'projectprop_c1'
    });

    if (!$is_test) {
        my $return = _perform_phenotype_automated($c, $bcs_schema, $metadata_schema, $phenome_schema, $drone_run_project_id_input, $time_cvterm_id, $phenotype_methods, $standard_process_type, 1, undef, $user_id, $user_name, $user_role);
    }

    my @result;
    $c->stash->{rest} = { data => \@result, success => 1 };
}

sub standard_process_apply_previous_imaging_event : Path('/api/drone_imagery/standard_process_apply_previous_imaging_event') : ActionClass('REST') { }
sub standard_process_apply_previous_imaging_event_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $sp_person_id);
    my $metadata_schema = $c->dbic_schema('CXGN::Metadata::Schema', undef, $sp_person_id);
    my $phenome_schema = $c->dbic_schema('CXGN::Phenome::Schema', undef, $sp_person_id);
    my $field_trial_id = $c->req->param('field_trial_id');
    my $drone_run_band_project_id_input = $c->req->param('drone_run_band_project_id');
    my $drone_run_project_id_input = $c->req->param('drone_run_project_id');
    my $gcp_drone_run_project_id_input = $c->req->param('previous_drone_run_project_id');
    my $time_cvterm_id = $c->req->param('time_cvterm_id');
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $phenotype_methods = ['zonal'];
    my $standard_process_type = 'minimal';

    my $vegetative_indices = ['TGI', 'VARI', 'NDVI', 'NDRE'];
    my %vegetative_indices_hash;
    foreach (@$vegetative_indices) {
        $vegetative_indices_hash{$_}++;
    }

    if (!$gcp_drone_run_project_id_input) {
        $c->stash->{rest} = { error => "Please select an imaging event to use as a template!" };
        $c->detach();
    }

    my $drone_run_band_drone_run_project_relationship_type_id_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_on_drone_run', 'project_relationship')->cvterm_id();
    my $drone_run_band_drone_run_project_type = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_project_type', 'project_property')->cvterm_id();

    my $project_image_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $rotated_image_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'rotated_stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $cropped_image_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'cropped_stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $denoised_project_image_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'denoised_stitched_drone_imagery', 'project_md_image')->cvterm_id();

    my $apply_drone_run_band_project_ids;
    my %apply_drone_run_band_project_ids_type_hash;
    my $drone_run_band_q = "SELECT project.project_id, project_md_image.type_id, projectprop.value
        FROM project
        JOIN projectprop ON(project.project_id = projectprop.project_id)
        JOIN project_relationship ON(project.project_id=project_relationship.subject_project_id AND project_relationship.type_id=$drone_run_band_drone_run_project_relationship_type_id_cvterm_id)
        JOIN phenome.project_md_image AS project_md_image ON(project.project_id = project_md_image.project_id)
        WHERE project_relationship.object_project_id=?
        AND project_md_image.type_id=?
        AND projectprop.type_id=$drone_run_band_drone_run_project_type;";
    my $drone_run_band_h = $bcs_schema->storage->dbh()->prepare($drone_run_band_q);
    $drone_run_band_h->execute($drone_run_project_id_input, $project_image_type_id);
    while (my ($drone_run_band_project_id, $drone_run_band_project_image_type_id, $drone_run_band_project_type) = $drone_run_band_h->fetchrow_array()) {
        push @$apply_drone_run_band_project_ids, $drone_run_band_project_id;
        $apply_drone_run_band_project_ids_type_hash{$drone_run_band_project_id} = {
            image_type_id => $drone_run_band_project_image_type_id,
            band_type => $drone_run_band_project_type
        };
    }
    print STDERR Dumper \%apply_drone_run_band_project_ids_type_hash;
    my $drone_run_band_project_type_current = $apply_drone_run_band_project_ids_type_hash{$drone_run_band_project_id_input}->{band_type};

    my $gcp_drone_run_band_q = "SELECT project.project_id
        FROM project
        JOIN projectprop ON(project.project_id = projectprop.project_id)
        JOIN project_relationship ON(project.project_id=project_relationship.subject_project_id AND project_relationship.type_id=$drone_run_band_drone_run_project_relationship_type_id_cvterm_id)
        WHERE project_relationship.object_project_id=?
        AND projectprop.type_id=$drone_run_band_drone_run_project_type
        AND projectprop.value='$drone_run_band_project_type_current';";
    my $gcp_drone_run_band_h = $bcs_schema->storage->dbh()->prepare($gcp_drone_run_band_q);
    $gcp_drone_run_band_h->execute($gcp_drone_run_project_id_input);
    my ($gcp_drone_run_band_project_id) = $gcp_drone_run_band_h->fetchrow_array();

    my $rotate_angle_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_rotate_angle', 'project_property')->cvterm_id();
    my $cropping_polygon_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_cropped_polygon', 'project_property')->cvterm_id();
    my $plot_polygon_template_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_plot_polygons', 'project_property')->cvterm_id();
    my $drone_run_drone_run_band_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_on_drone_run', 'project_relationship')->cvterm_id();

    my $q = "SELECT rotate.value, plot_polygons.value, cropping.value, drone_run.project_id, drone_run.name
        FROM project AS drone_run_band
        JOIN project_relationship ON(project_relationship.subject_project_id = drone_run_band.project_id AND project_relationship.type_id = $drone_run_drone_run_band_type_id)
        JOIN project AS drone_run ON(project_relationship.object_project_id = drone_run.project_id)
        JOIN projectprop AS rotate ON(drone_run_band.project_id = rotate.project_id AND rotate.type_id=$rotate_angle_type_id)
        JOIN projectprop AS plot_polygons ON(drone_run_band.project_id = plot_polygons.project_id AND plot_polygons.type_id=$plot_polygon_template_type_id)
        JOIN projectprop AS cropping ON(drone_run_band.project_id = cropping.project_id AND cropping.type_id=$cropping_polygon_type_id)
        WHERE drone_run_band.project_id = $gcp_drone_run_band_project_id;";

    my $h = $bcs_schema->storage->dbh()->prepare($q);
    $h->execute();
    my ($rotate_value, $plot_polygons_value_json, $cropping_value_json, $drone_run_project_id, $drone_run_project_name) = $h->fetchrow_array();
    print STDERR Dumper $rotate_value;
    print STDERR Dumper $cropping_value_json;
    print STDERR Dumper $plot_polygons_value_json;

    my $process_indicator_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_standard_process_in_progress', 'project_property')->cvterm_id();
    my $processed_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_standard_process_completed', 'project_property')->cvterm_id();
    my $processed_minimal_vi_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_standard_process_vi_completed', 'project_property')->cvterm_id();
    my $drone_run_process_in_progress = $bcs_schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$process_indicator_cvterm_id,
        project_id=>$drone_run_project_id_input,
        rank=>0,
        value=>1
    },
    {
        key=>'projectprop_c1'
    });

    my $drone_run_process_completed = $bcs_schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$processed_cvterm_id,
        project_id=>$drone_run_project_id_input,
        rank=>0,
        value=>0
    },
    {
        key=>'projectprop_c1'
    });

    my $drone_run_process_minimal_vi_completed = $bcs_schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$processed_minimal_vi_cvterm_id,
        project_id=>$drone_run_project_id_input,
        rank=>0,
        value=>0
    },
    {
        key=>'projectprop_c1'
    });

    my %selected_drone_run_band_types;

    my $q4 = "SELECT project_md_image.image_id, drone_run_band_type.value, drone_run_band.project_id
        FROM project AS drone_run_band
        JOIN projectprop AS drone_run_band_type ON(drone_run_band_type.project_id = drone_run_band.project_id AND drone_run_band_type.type_id = $drone_run_band_drone_run_project_type)
        JOIN phenome.project_md_image AS project_md_image ON(project_md_image.project_id = drone_run_band.project_id)
        JOIN metadata.md_image ON(project_md_image.image_id = metadata.md_image.image_id)
        WHERE project_md_image.type_id = ?
        AND drone_run_band.project_id = ?
        AND metadata.md_image.obsolete = 'f';";
    my $h4 = $bcs_schema->storage->dbh()->prepare($q4);

    my $term_map = CXGN::DroneImagery::ImageTypes::get_base_imagery_observation_unit_plot_polygon_term_map();
    my %drone_run_band_info;
    foreach my $apply_drone_run_band_project_id (@$apply_drone_run_band_project_ids) {
        $h4->execute($project_image_type_id, $apply_drone_run_band_project_id);
        my ($image_id, $drone_run_band_type, $drone_run_band_project_id) = $h4->fetchrow_array();
        $selected_drone_run_band_types{$drone_run_band_type} = $drone_run_band_project_id;

        my $apply_image_width_ratio = 1;
        my $apply_image_height_ratio = 1;

        my $dir = $c->tempfiles_subdir('/drone_imagery_rotate');
        my $archive_rotate_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_rotate/imageXXXX');
        $archive_rotate_temp_image .= '.png';

        my $rotate_return = _perform_image_rotate($c, $bcs_schema, $metadata_schema, $drone_run_band_project_id, $image_id, $rotate_value, 0, $user_id, $user_name, $user_role, $archive_rotate_temp_image, 0, 0, 1, 0);
        my $rotated_image_id = $rotate_return->{rotated_image_id};

        $dir = $c->tempfiles_subdir('/drone_imagery_cropped_image');
        my $archive_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_cropped_image/imageXXXX');
        $archive_temp_image .= '.png';

        my $cropping_return = _perform_image_cropping($c, $bcs_schema, $drone_run_band_project_id, $rotated_image_id, $cropping_value_json, $user_id, $user_name, $user_role, $archive_temp_image, $apply_image_width_ratio, $apply_image_height_ratio);
        my $cropped_image_id = $cropping_return->{cropped_image_id};

        $dir = $c->tempfiles_subdir('/drone_imagery_denoise');
        my $archive_denoise_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_denoise/imageXXXX');
        $archive_denoise_temp_image .= '.png';

        my $denoise_return = _perform_image_denoise($c, $bcs_schema, $metadata_schema, $cropped_image_id, $drone_run_band_project_id, $user_id, $user_name, $user_role, $archive_denoise_temp_image);
        my $denoised_image_id = $denoise_return->{denoised_image_id};

        $drone_run_band_info{$drone_run_band_project_id} = {
            denoised_image_id => $denoised_image_id,
            rotate_value => $rotate_value,
            cropping_value => $cropping_value_json,
            drone_run_band_type => $drone_run_band_type,
            drone_run_project_id => $drone_run_project_id_input,
            drone_run_project_name => $drone_run_project_name,
            plot_polygons_value => $plot_polygons_value_json,
            check_resize => 1,
            keep_original_size_rotate => 0
        };

        my @denoised_plot_polygon_type = @{$term_map->{$drone_run_band_type}->{observation_unit_plot_polygon_types}->{base}};
        my @denoised_background_threshold_removed_imagery_types = @{$term_map->{$drone_run_band_type}->{imagery_types}->{threshold_background}};
        my @denoised_background_threshold_removed_plot_polygon_types = @{$term_map->{$drone_run_band_type}->{observation_unit_plot_polygon_types}->{threshold_background}};

        foreach (@denoised_plot_polygon_type) {
            my $plot_polygon_original_denoised_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $denoised_image_id, $drone_run_band_project_id, $plot_polygons_value_json, $_, $user_id, $user_name, $user_role, 0, 0, $apply_image_width_ratio, $apply_image_height_ratio, 'rectangular_square');
        }

        for my $iterator (0..(scalar(@denoised_background_threshold_removed_imagery_types)-1)) {
            $dir = $c->tempfiles_subdir('/drone_imagery_remove_background');
            my $archive_remove_background_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_remove_background/imageXXXX');
            $archive_remove_background_temp_image .= '.png';

            my $background_removed_threshold_return = _perform_image_background_remove_threshold_percentage($c, $bcs_schema, $denoised_image_id, $drone_run_band_project_id, $denoised_background_threshold_removed_imagery_types[$iterator], '25', '25', $user_id, $user_name, $user_role, $archive_remove_background_temp_image);

            my $plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $background_removed_threshold_return->{removed_background_image_id}, $drone_run_band_project_id, $plot_polygons_value_json, $denoised_background_threshold_removed_plot_polygon_types[$iterator], $user_id, $user_name, $user_role, 0, 0, $apply_image_width_ratio, $apply_image_height_ratio, 'rectangular_square');
        }
    }

    print STDERR Dumper \%selected_drone_run_band_types;
    print STDERR Dumper \%vegetative_indices_hash;

    _perform_minimal_vi_standard_process($c, $bcs_schema, $metadata_schema, \%vegetative_indices_hash, \%selected_drone_run_band_types, \%drone_run_band_info, $user_id, $user_name, $user_role, 'rectangular_square');

    $drone_run_process_in_progress = $bcs_schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$process_indicator_cvterm_id,
        project_id=>$drone_run_project_id_input,
        rank=>0,
        value=>0
    },
    {
        key=>'projectprop_c1'
    });

    $drone_run_process_completed = $bcs_schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$processed_cvterm_id,
        project_id=>$drone_run_project_id_input,
        rank=>0,
        value=>1
    },
    {
        key=>'projectprop_c1'
    });

    $drone_run_process_minimal_vi_completed = $bcs_schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$processed_minimal_vi_cvterm_id,
        project_id=>$drone_run_project_id_input,
        rank=>0,
        value=>1
    },
    {
        key=>'projectprop_c1'
    });

    my $return = _perform_phenotype_automated($c, $bcs_schema, $metadata_schema, $phenome_schema, $drone_run_project_id_input, $time_cvterm_id, $phenotype_methods, $standard_process_type, 1, undef, $user_id, $user_name, $user_role);

    my @result;
    $c->stash->{rest} = { data => \@result, success => 1 };
}

sub standard_process_apply_raw_images_interactive : Path('/api/drone_imagery/standard_process_apply_raw_images_interactive') : ActionClass('REST') { }
sub standard_process_apply_raw_images_interactive_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    print STDERR Dumper $c->req->params();
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $sp_person_id);
    my $metadata_schema = $c->dbic_schema('CXGN::Metadata::Schema', undef, $sp_person_id);
    my $phenome_schema = $c->dbic_schema('CXGN::Phenome::Schema', undef, $sp_person_id);
    my $apply_drone_run_band_project_ids = decode_json $c->req->param('apply_drone_run_band_project_ids');
    my $drone_run_band_project_id = $c->req->param('drone_run_band_project_id');
    my $drone_run_project_id_input = $c->req->param('drone_run_project_id');
    my $vegetative_indices = decode_json $c->req->param('vegetative_indices');
    my $phenotype_methods = $c->req->param('phenotype_types') ? decode_json $c->req->param('phenotype_types') : ['zonal'];
    my $time_cvterm_id = $c->req->param('time_cvterm_id');
    my $standard_process_type = $c->req->param('standard_process_type');
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $process_indicator_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_standard_process_in_progress', 'project_property')->cvterm_id();
    my $processed_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_standard_process_completed', 'project_property')->cvterm_id();
    my $processed_minimal_vi_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_standard_process_vi_completed', 'project_property')->cvterm_id();

    my $drone_run_process_in_progress = $schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$process_indicator_cvterm_id,
        project_id=>$drone_run_project_id_input,
        rank=>0,
        value=>1
    },
    {
        key=>'projectprop_c1'
    });

    my $drone_run_process_completed = $schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$processed_cvterm_id,
        project_id=>$drone_run_project_id_input,
        rank=>0,
        value=>0
    },
    {
        key=>'projectprop_c1'
    });

    my $drone_run_process_minimal_vi_completed = $schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$processed_minimal_vi_cvterm_id,
        project_id=>$drone_run_project_id_input,
        rank=>0,
        value=>0
    },
    {
        key=>'projectprop_c1'
    });

    my %vegetative_indices_hash;
    foreach (@$vegetative_indices) {
        $vegetative_indices_hash{$_}++;
    }

    my $saved_gps_positions_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_raw_images_saved_gps_pixel_positions', 'project_property')->cvterm_id();
    my $drone_run_band_saved_gps = $schema->resultset('Project::Projectprop')->find({
        type_id=>$saved_gps_positions_type_id,
        project_id=>$drone_run_project_id_input,
    });
    my $saved_gps_positions_separated = decode_json $drone_run_band_saved_gps->value();

    my $drone_run_band_plot_polygons_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_plot_polygons_separated', 'project_property')->cvterm_id();
    my $previous_plot_polygons_rs = $schema->resultset('Project::Projectprop')->search({type_id=>$drone_run_band_plot_polygons_type_id, project_id=>$drone_run_band_project_id});
    if ($previous_plot_polygons_rs->count > 1) {
        $c->stash->{rest} = { error => "There should not be more than one saved entry for plot polygons for a drone run band" };
        $c->detach();
    }

    my $save_stock_polygons_separated;
    if ($previous_plot_polygons_rs->count > 0) {
        $save_stock_polygons_separated = decode_json $previous_plot_polygons_rs->first->value;
    }
    if (!$save_stock_polygons_separated) {
        $c->stash->{rest} = { error => "There are no stock polygons saved!" };
        $c->detach();
    }
    # print STDERR Dumper $save_stock_polygons;
    # print STDERR Dumper $saved_gps_positions;

    #if (scalar(keys %$saved_gps_positions_separated) != scalar(keys %$save_stock_polygons_separated)) {
    #    $c->stash->{rest} = { error => "The number of imaging passes is not equal for the image positions and the plot polygons!" };
    #    $c->detach();
    #}

    my %polygons_images_positions;
    foreach my $flight_pass_counter (keys %$saved_gps_positions_separated) {
        my $saved_gps_positions = $saved_gps_positions_separated->{$flight_pass_counter};
        my $save_stock_polygons = $save_stock_polygons_separated->{$flight_pass_counter};

        while (my ($lat, $lo) = each %$saved_gps_positions) {
            while (my ($long, $pos) = each %$lo) {
                my $size = $pos->{image_size};
                my $rotated_bound = $pos->{rotated_bound_translated};
                my $x1_pos = $pos->{x_pos} + 0;
                my $y1_pos = $pos->{y_pos} + 0;
                my $x1_min = 10000000000;
                my $y1_min = 10000000000;
                foreach (@$rotated_bound) {
                    if ($_->[0] < $x1_min) {
                        $x1_min = $_->[0];
                    }
                    if ($_->[1] < $y1_min) {
                        $y1_min = $_->[1];
                    }
                }

                my @image_bound = (@$rotated_bound, $rotated_bound->[0]);
                my $bound = Math::Polygon->new(points => \@image_bound);

                while (my ($plot_name, $points) = each %$save_stock_polygons) {
                    my $polygon_x1 = $points->[0]->{x} + 0;
                    my $polygon_y1 = $points->[0]->{y} + 0;
                    my $polygon_x2 = $points->[1]->{x} + 0;
                    my $polygon_y2 = $points->[1]->{y} + 0;
                    my $polygon_x3 = $points->[2]->{x} + 0;
                    my $polygon_y3 = $points->[2]->{y} + 0;
                    my $polygon_x4 = $points->[3]->{x} + 0;
                    my $polygon_y4 = $points->[3]->{y} + 0;

                    if ($bound->contains([$polygon_x1,$polygon_y1]) && $bound->contains([$polygon_x2,$polygon_y2]) && $bound->contains([$polygon_x3,$polygon_y3]) && $bound->contains([$polygon_x4,$polygon_y4])) {
                        my $points_shifted = [
                            {'x' => $polygon_x1 - $x1_min, 'y' => $polygon_y1 - $y1_min},
                            {'x' => $polygon_x2 - $x1_min, 'y' => $polygon_y2 - $y1_min},
                            {'x' => $polygon_x3 - $x1_min, 'y' => $polygon_y3 - $y1_min},
                            {'x' => $polygon_x4 - $x1_min, 'y' => $polygon_y4 - $y1_min},
                        ];
                        my $obj = {
                            images => $pos,
                            points => $points_shifted,
                            image_bound => \@image_bound
                        };
                        push @{$polygons_images_positions{$plot_name}}, $obj;
                    } else {
                        print STDERR "Polygon outside image!\n";
                    }
                }
            }
        }
    }
    # print STDERR Dumper \%polygons_images_positions;

    my $term_map = CXGN::DroneImagery::ImageTypes::get_base_imagery_observation_unit_plot_polygon_term_map();
    my $drone_image_types = CXGN::DroneImagery::ImageTypes::get_all_project_md_image_observation_unit_plot_polygon_types($schema);
    my @plot_polygon_type_ids = (
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_blue_imagery', 'project_md_image')->cvterm_id(),
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_green_imagery', 'project_md_image')->cvterm_id(),
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_red_imagery', 'project_md_image')->cvterm_id(),
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_nir_imagery', 'project_md_image')->cvterm_id(),
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_red_edge_imagery', 'project_md_image')->cvterm_id()
    );
    my @plot_polygon_type_objects;
    my @plot_polygon_type_tags;
    foreach (@plot_polygon_type_ids) {
        push @plot_polygon_type_objects, $drone_image_types->{$_};
        my $assign_plot_polygons_type = $drone_image_types->{$_}->{name};

        my $image_tag_id = CXGN::Tag::exists_tag_named($schema->storage->dbh, $assign_plot_polygons_type);
        if (!$image_tag_id) {
            my $image_tag = CXGN::Tag->new($schema->storage->dbh);
            $image_tag->set_name($assign_plot_polygons_type);
            $image_tag->set_description('Drone run band project type for plot polygon assignment: '.$assign_plot_polygons_type);
            $image_tag->set_sp_person_id($user_id);
            $image_tag_id = $image_tag->store();
        }
        my $image_tag = CXGN::Tag->new($schema->storage->dbh, $image_tag_id);
        push @plot_polygon_type_tags, $image_tag;
    }

    my %drone_run_band_info;
    my $band_counter = 0;

    my $dir = $c->tempfiles_subdir('/drone_imagery_plot_polygons');
    my $bulk_input_temp_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_plot_polygons/bulkinputXXXX');

    open(my $F, ">", $bulk_input_temp_file) || die "Can't open file ".$bulk_input_temp_file;
    # print STDERR Dumper \%polygons_images_positions;

    my $plot_polygon_type_hash = CXGN::DroneImagery::ImageTypes::get_all_project_md_image_observation_unit_plot_polygon_types($schema);
    my @input_bulk_hash;
    foreach my $apply_drone_run_band_project_id (@$apply_drone_run_band_project_ids) {
        while (my ($plot_name, $pi_array) = each %polygons_images_positions) {

            my $stock = $schema->resultset("Stock::Stock")->find({uniquename => $plot_name});
            if (!$stock) {
                $c->stash->{rest} = {error=>'Error: Stock name '.$plot_name.' does not exist in the database!'};
                $c->detach();
            }
            my $stock_id = $stock->stock_id;

            foreach my $pi (@$pi_array) {
                my $points = $pi->{points};
                my $images = $pi->{images};
                my $image_ids = $images->{rotated_image_ids};

                my $current_image_id = $image_ids->[$band_counter];

                if ($current_image_id) {
                    my $plot_polygon_json = encode_json [$points];

                    my $linking_table_type_id = $plot_polygon_type_ids[$band_counter];
                    my $corresponding_channel = $plot_polygon_type_hash->{$linking_table_type_id}->{corresponding_channel};

                    my $image = SGN::Image->new( $schema->storage->dbh, $current_image_id, $c );
                    my $image_url = $image->get_image_url("original");
                    my $image_fullpath = $image->get_filename('original_converted', 'full');
                    my $archive_plot_polygons_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_plot_polygons/imageXXXX');
                    $archive_plot_polygons_temp_image .= '.png';

                    print $F "$image_fullpath\t$archive_plot_polygons_temp_image\t$plot_polygon_json\trectangular_square\t$corresponding_channel\n";

                    push @input_bulk_hash, {
                        plot_temp_image => $archive_plot_polygons_temp_image,
                        plot_id => $stock_id,
                        band_counter => $band_counter,
                        drone_run_band_project_id => $apply_drone_run_band_project_id
                    };
                    # my $return = _perform_plot_polygon_assign_bulk($c, $bcs_schema, $metadata_schema, $current_image_id, $apply_drone_run_band_project_id, $plot_polygon_json, $plot_polygon_type, $user_id, $user_name, $user_role, 0, 1, 1, 1, 'rectangular_square');
                }
            }
        }
        $band_counter++;
    }
    close($F);
    # print STDERR Dumper \@input_bulk_hash;

    my $cmd = $c->config->{python_executable}." ".$c->config->{rootpath}."/DroneImageScripts/ImageCropping/CropToPolygonBulk.py --inputfile_path '$bulk_input_temp_file'";
    print STDERR Dumper $cmd;
    my $status = system("$cmd > /dev/null");

    my $number_system_cores = `getconf _NPROCESSORS_ONLN` or die "Could not get number of system cores!\n";
    chomp($number_system_cores);
    print STDERR "NUMCORES $number_system_cores\n";

    my $pm = Parallel::ForkManager->new(ceil($number_system_cores/4));
    $pm->run_on_finish( sub {
        my ($pid, $exit_code, $ident, $exit_signal, $core_dump, $data_structure_reference) = @_;
    });

    foreach my $obj (@input_bulk_hash) {
        my $pid = $pm->start and next;

        my $archive_plot_polygons_temp_image = $obj->{plot_temp_image};
        my $stock_id = $obj->{plot_id};
        print STDERR Dumper $stock_id;
        my $drone_run_band_project_id = $obj->{drone_run_band_project_id};

        my $drone_run_band_project_type = $plot_polygon_type_objects[$band_counter]->{drone_run_project_types}->[0];
        my $plot_polygon_type = $plot_polygon_type_objects[$band_counter]->{name};
        my $image_tag = $plot_polygon_type_tags[$band_counter];
        my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, $plot_polygon_type, 'project_md_image')->cvterm_id();

        my $plot_polygon_image_fullpath;
        my $plot_polygon_image_url;
        my $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
        $image->set_sp_person_id($user_id);
        my $ret = $image->process_image($archive_plot_polygons_temp_image, 'project', $drone_run_band_project_id, $linking_table_type_id);
        my $stock_associate = $image->associate_stock($stock_id, $user_name);
        $plot_polygon_image_fullpath = $image->get_filename('original_converted', 'full');
        $plot_polygon_image_url = $image->get_image_url('original');
        my $added_image_tag_id = $image->add_tag($image_tag);

        $pm->finish(0, {});
    }
    $pm->wait_all_children;

    $drone_run_process_in_progress = $schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$process_indicator_cvterm_id,
        project_id=>$drone_run_project_id_input,
        rank=>0,
        value=>0
    },
    {
        key=>'projectprop_c1'
    });

    $drone_run_process_completed = $schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$processed_cvterm_id,
        project_id=>$drone_run_project_id_input,
        rank=>0,
        value=>1
    },
    {
        key=>'projectprop_c1'
    });

    $drone_run_process_minimal_vi_completed = $schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$processed_minimal_vi_cvterm_id,
        project_id=>$drone_run_project_id_input,
        rank=>0,
        value=>1
    },
    {
        key=>'projectprop_c1'
    });

    my $return = _perform_phenotype_automated($c, $schema, $metadata_schema, $phenome_schema, $drone_run_project_id_input, $time_cvterm_id, $phenotype_methods, $standard_process_type, 1, undef, $user_id, $user_name, $user_role);

    my @result;
    $c->stash->{rest} = { data => \@result, success => 1 };
}

sub drone_imagery_get_vehicle : Path('/api/drone_imagery/get_vehicle') : ActionClass('REST') { }
sub drone_imagery_get_vehicle_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    $c->response->headers->header( "Access-Control-Allow-Origin" => '*' );
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $sp_person_id);
    my $metadata_schema = $c->dbic_schema('CXGN::Metadata::Schema', undef, $sp_person_id);
    my $vehicle_id = $c->req->param('vehicle_id');
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $imaging_vehicle_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'imaging_event_vehicle', 'stock_type')->cvterm_id();
    my $imaging_vehicle_properties_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'imaging_event_vehicle_json', 'stock_property')->cvterm_id();

    my $q = "SELECT stock.stock_id, stock.uniquename, stock.description, stockprop.value
        FROM stock
        JOIN stockprop ON(stock.stock_id=stockprop.stock_id AND stockprop.type_id=$imaging_vehicle_properties_cvterm_id)
        WHERE stock.type_id=$imaging_vehicle_cvterm_id";
    if ($vehicle_id) {
        $q .= " AND stock.stock_id=?"
    }
    $q .= ";";
    my $h = $bcs_schema->storage->dbh()->prepare($q);
    if ($vehicle_id) {
        $h->execute($vehicle_id);
    }
    else {
        $h->execute();
    }
    my @vehicles;
    while (my ($stock_id, $name, $description, $prop) = $h->fetchrow_array()) {
        my $prop_hash = decode_json $prop;
        push @vehicles, {
            vehicle_id => $stock_id,
            name => $name,
            description => $description,
            properties => $prop_hash
        };
    }

    $c->stash->{rest} = { vehicles => \@vehicles, success => 1 };
}

sub drone_imagery_get_vehicles : Path('/api/drone_imagery/imaging_vehicles') : ActionClass('REST') { }
sub drone_imagery_get_vehicles_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $sp_person_id);
    my $metadata_schema = $c->dbic_schema('CXGN::Metadata::Schema', undef, $sp_person_id);
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $imaging_vehicle_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'imaging_event_vehicle', 'stock_type')->cvterm_id();
    my $imaging_vehicle_properties_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'imaging_event_vehicle_json', 'stock_property')->cvterm_id();

    my $q = "SELECT stock.stock_id, stock.uniquename, stock.description, stockprop.value
        FROM stock
        JOIN stockprop ON(stock.stock_id=stockprop.stock_id AND stockprop.type_id=$imaging_vehicle_properties_cvterm_id)
        WHERE stock.type_id=$imaging_vehicle_cvterm_id;";
    my $h = $bcs_schema->storage->dbh()->prepare($q);
    $h->execute();
    my @vehicles;
    while (my ($stock_id, $name, $description, $prop) = $h->fetchrow_array()) {
        my $prop_hash = decode_json $prop;
        my @batt_info;
        foreach (sort keys %{$prop_hash->{batteries}}) {
            my $p = $prop_hash->{batteries}->{$_};
            push @batt_info, "$_: Usage = ".$p->{usage}." Obsolete = ".$p->{obsolete};
        }
        my $batt_info_string = join '<br/>', @batt_info;
        push @vehicles, [$name, $description, $batt_info_string]
    }

    $c->stash->{rest} = { data => \@vehicles };
}

sub drone_imagery_accession_phenotype_histogram : Path('/api/drone_imagery/accession_phenotype_histogram') : ActionClass('REST') { }
sub drone_imagery_accession_phenotype_histogram_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $sp_person_id);
    my $metadata_schema = $c->dbic_schema('CXGN::Metadata::Schema', undef, $sp_person_id);
    my ($user_id, $user_name, $user_role) = _check_user_login($c);
    my $plot_id = $c->req->param('plot_id');
    my $accession_id = $c->req->param('accession_id');
    my $trait_id = $c->req->param('trait_id');
    my $field_trial_id = $c->req->param('field_trial_id');
    my $figure_type = $c->req->param('figure_type');

    my $dir = $c->tempfiles_subdir('/drone_imagery_pheno_plot_dir');
    my $phenos_tempfile = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_pheno_plot_dir/phenoXXXX');
    my $pheno_plot_tempfile = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_pheno_plot_dir/phenoplotXXXX');
    my $pheno_accession_tempfile = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_pheno_plot_dir/phenoplotaccXXXX');
    my $pheno_figure_tempfile_string = $c->tempfile( TEMPLATE => 'drone_imagery_pheno_plot_dir/figureXXXX');
    my $pheno_figure_tempfile = $c->config->{basepath}."/".$pheno_figure_tempfile_string;

    my $search_params = {
        bcs_schema=>$bcs_schema,
        data_level=>'all',
        trait_list=>[$trait_id],
        include_timestamp=>0,
        exclude_phenotype_outlier=>0
    };

    # Comparing plot_id pheno against all phenotypes in trial
    if ($field_trial_id && $figure_type eq 'all_pheno_of_this_trial') {
        $search_params->{trial_list} = [$field_trial_id];
    }
    # Comparing plot_id pheno against all phenotypes for accession
    if ($accession_id && $figure_type eq 'all_pheno_of_this_accession'){
        $search_params->{accession_list} = [$accession_id];
    }

    my $phenotypes_search = CXGN::Phenotypes::SearchFactory->instantiate(
        'MaterializedViewTable',
        $search_params
    );
    my ($data, $unique_traits) = $phenotypes_search->search();
    my @sorted_trait_names = sort keys %$unique_traits;

    if (scalar(@$data) == 0) {
        $c->stash->{rest} = { error => "There are no phenotypes for the trait you have selected in the current field trial!"};
        $c->detach();
    }

    my @accession_phenotypes;
    if ($accession_id) {
        my $accession_phenotypes_search = CXGN::Phenotypes::SearchFactory->instantiate(
            'MaterializedViewTable',
            {
                bcs_schema=>$bcs_schema,
                data_level=>'plot',
                trait_list=>[$trait_id],
                accession_list=>[$accession_id],
                include_timestamp=>0,
                exclude_phenotype_outlier=>0
            }
        );
        my ($accession_data, $accession_unique_traits) = $accession_phenotypes_search->search();
        my @accession_sorted_trait_names = sort keys %$accession_unique_traits;

        foreach my $obs_unit (@$accession_data){
            my $observations = $obs_unit->{observations};
            foreach (@$observations){
                push @accession_phenotypes, $_->{value};
            }
        }
    }

    my $plot_phenotypes_search = CXGN::Phenotypes::SearchFactory->instantiate(
        'MaterializedViewTable',
        {
            bcs_schema=>$bcs_schema,
            data_level=>'plot',
            trait_list=>[$trait_id],
            plot_list=>[$plot_id],
            include_timestamp=>0,
            exclude_phenotype_outlier=>0
        }
    );
    my ($plot_data, $plot_unique_traits) = $plot_phenotypes_search->search();
    my @plot_sorted_trait_names = sort keys %$plot_unique_traits;

    my @all_phenotypes;
    foreach my $obs_unit (@$data){
        my $observations = $obs_unit->{observations};
        foreach (@$observations){
            push @all_phenotypes, $_->{value};
        }
    }

    my @plot_phenotypes;
    foreach my $obs_unit (@$plot_data){
        my $observations = $obs_unit->{observations};
        foreach (@$observations){
            push @plot_phenotypes, $_->{value};
        }
    }

    open(my $F, ">", $phenos_tempfile) || die "Can't open file ".$phenos_tempfile;
        print $F "phenotype\n";
        foreach (@all_phenotypes) {
            print $F "$_\n";
        }
    close($F);

    open(my $F2, ">", $pheno_plot_tempfile) || die "Can't open file ".$pheno_plot_tempfile;
        print $F2 "phenotype\n";
        foreach (@plot_phenotypes) {
            print $F2 "$_\n";
        }
    close($F2);

    open(my $F3, ">", $pheno_accession_tempfile) || die "Can't open file ".$pheno_accession_tempfile;
        print $F3 "phenotype\n";
        foreach (@accession_phenotypes) {
            print $F3 "$_\n";
        }
    close($F3);

    my $cmd = 'R -e "library(ggplot2);
    options(device=\'png\');
    par();
    pheno_all <- read.table(\''.$phenos_tempfile.'\', header=TRUE, sep=\',\');
    pheno_plot <- read.table(\''.$pheno_plot_tempfile.'\', header=TRUE, sep=\',\');
    pheno_accession <- read.table(\''.$pheno_accession_tempfile.'\', header=TRUE, sep=\',\');
    sp <- ggplot(pheno_all, aes(x=phenotype)) + geom_histogram();
    if (length(pheno_plot\$phenotype) > 0) {
        sp <- sp + geom_vline(xintercept = pheno_plot\$phenotype[1], color = \'red\', size=1.2);
    }
    if (length(pheno_accession\$phenotype) > 0) {
        sp <- sp + geom_vline(xintercept = mean(pheno_accession\$phenotype), color = \'green\', size=1.2);
    }
    ggsave(\''.$pheno_figure_tempfile.'\', sp, device=\'png\', width=3, height=3, units=\'in\');
    dev.off();"';
    print STDERR Dumper $cmd;
    my $status = system("$cmd > /dev/null");

    $c->stash->{rest} = { success => 1, figure => $pheno_figure_tempfile_string };
}

sub drone_imagery_save_single_plot_image : Path('/api/drone_imagery/save_single_plot_image') : ActionClass('REST') { }
sub drone_imagery_save_single_plot_image_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    $c->response->headers->header( "Access-Control-Allow-Origin" => '*' );
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $sp_person_id);
    my $metadata_schema = $c->dbic_schema('CXGN::Metadata::Schema', undef, $sp_person_id);
    my $observation_unit_id = $c->req->param('observation_unit_id');
    my $drone_run_band_project_id_input = $c->req->param('drone_run_band_project_id');
    my $image_input = $c->req->upload('image');
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my %expected_types = (
        'observation_unit_polygon_blue_imagery' => 1,
        'observation_unit_polygon_green_imagery' => 1,
        'observation_unit_polygon_red_imagery' => 1,
        'observation_unit_polygon_nir_imagery' => 1,
        'observation_unit_polygon_red_edge_imagery' => 1
    );

    my $drone_run_band_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_project_type', 'project_property')->cvterm_id();
    my $q = "SELECT name,value FROM projectprop JOIN project USING(project_id) WHERE type_id=$drone_run_band_type_cvterm_id and project_id=?;";
    my $h = $bcs_schema->storage->dbh()->prepare($q);
    $h->execute($drone_run_band_project_id_input);
    my ($project_band_name, $project_band_type) = $h->fetchrow_array();
    if (!$project_band_name || !$project_band_type) {
        $c->stash->{rest} = { error => "Drone run band not found or the drone run band is not of a known type!" };
        $c->detach();
    }

    my $plot_polygon_types = CXGN::DroneImagery::ImageTypes::get_all_project_md_image_observation_unit_plot_polygon_types($bcs_schema);
    my %band_type_image_hash;
    while ( my ($plot_image_type_id, $o) = each %$plot_polygon_types) {
        foreach my $band_type (@{$o->{drone_run_project_types}}) {
            if ($band_type eq $project_band_type && exists($expected_types{$o->{name}})) {
                $band_type_image_hash{$band_type} = {
                    cvterm_id => $plot_image_type_id,
                    name => $o->{name}
                };
            }
        }
    }
    my $linking_table_type_id = $band_type_image_hash{$project_band_type}->{cvterm_id};
    my $assign_plot_polygons_type = $band_type_image_hash{$project_band_type}->{name};

    my $image_tag_id = CXGN::Tag::exists_tag_named($bcs_schema->storage->dbh, $assign_plot_polygons_type);
    if (!$image_tag_id) {
        my $image_tag = CXGN::Tag->new($bcs_schema->storage->dbh);
        $image_tag->set_name($assign_plot_polygons_type);
        $image_tag->set_description('Drone run band project type for plot polygon assignment: '.$assign_plot_polygons_type);
        $image_tag->set_sp_person_id($user_id);
        $image_tag_id = $image_tag->store();
    }
    my $image_tag = CXGN::Tag->new($bcs_schema->storage->dbh, $image_tag_id);

    if (!$image_input) {
        $c->stash->{rest} = { error => "ERROR!" };
        $c->detach();
    }
    my $image_input_filename = $image_input->tempname();
    if (!$image_input_filename) {
        $c->stash->{rest} = { error => "ERROR! filename" };
        $c->detach();
    }

    my $stock = $bcs_schema->resultset("Stock::Stock")->find({stock_id => $observation_unit_id});
    if (!$stock) {
        $c->stash->{rest} = {error=>'Error: Stock '.$observation_unit_id.' does not exist in the database!'};
        $c->detach();
    }

    my $image = SGN::Image->new( $bcs_schema->storage->dbh, undef, $c );
    $image->set_sp_person_id($user_id);
    my $ret = $image->process_image($image_input_filename, 'project', $drone_run_band_project_id_input, $linking_table_type_id);
    my $stock_associate = $image->associate_stock($observation_unit_id, $user_name);
    my $plot_polygon_image_fullpath = $image->get_filename('original_converted', 'full');
    my $plot_polygon_image_url = $image->get_image_url('original');
    my $added_image_tag_id = $image->add_tag($image_tag);

    $c->stash->{rest} = { success => 1 };
}

sub standard_process_minimal_vi_apply : Path('/api/drone_imagery/standard_process_minimal_vi_apply') : ActionClass('REST') { }
sub standard_process_minimal_vi_apply_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $sp_person_id);
    my $metadata_schema = $c->dbic_schema('CXGN::Metadata::Schema', undef, $sp_person_id);
    my $drone_run_project_id_input = $c->req->param('drone_run_project_id');
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $process_indicator_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_standard_process_in_progress', 'project_property')->cvterm_id();
    my $processed_minimal_vi_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_standard_process_vi_completed', 'project_property')->cvterm_id();
    my $drone_run_process_in_progress = $bcs_schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$process_indicator_cvterm_id,
        project_id=>$drone_run_project_id_input,
        rank=>0,
        value=>1
    },
    {
        key=>'projectprop_c1'
    });

    my $drone_run_process_minimal_vi_completed = $bcs_schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$processed_minimal_vi_cvterm_id,
        project_id=>$drone_run_project_id_input,
        rank=>0,
        value=>0
    },
    {
        key=>'projectprop_c1'
    });

    my $extended_process_indicator_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_standard_process_in_progress', 'project_property')->cvterm_id();
    my $extended_processed_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_standard_process_extended_completed', 'project_property')->cvterm_id();
    my $extended_drone_run_process_in_progress = $bcs_schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$extended_process_indicator_cvterm_id,
        project_id=>$drone_run_project_id_input,
        rank=>0,
        value=>1
    },
    {
        key=>'projectprop_c1'
    });

    $extended_drone_run_process_in_progress = $bcs_schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$extended_processed_cvterm_id,
        project_id=>$drone_run_project_id_input,
        rank=>0,
        value=>0
    },
    {
        key=>'projectprop_c1'
    });

    my %vegetative_indices_hash = (
        'TGI' => 1,
        'VARI' => 1,
        'NDVI' => 1,
        'NDRE' => 1
    );

    my $rotate_angle_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_rotate_angle', 'project_property')->cvterm_id();
    my $cropping_polygon_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_cropped_polygon', 'project_property')->cvterm_id();
    my $plot_polygon_template_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_plot_polygons', 'project_property')->cvterm_id();
    my $drone_run_drone_run_band_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_on_drone_run', 'project_relationship')->cvterm_id();
    my $project_image_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'denoised_stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $drone_run_band_type_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_project_type', 'project_property')->cvterm_id();

    my %selected_drone_run_band_types;
    my %drone_run_band_info;
    my $q = "SELECT rotate.value, plot_polygons.value, cropping.value, drone_run.project_id, drone_run.name, drone_run_band.project_id, drone_run_band.name, drone_run_band_type.value, project_md_image.image_id
        FROM project AS drone_run_band
        JOIN project_relationship ON(project_relationship.subject_project_id = drone_run_band.project_id AND project_relationship.type_id = $drone_run_drone_run_band_type_id)
        JOIN project AS drone_run ON(project_relationship.object_project_id = drone_run.project_id)
        JOIN projectprop AS rotate ON(drone_run_band.project_id = rotate.project_id AND rotate.type_id=$rotate_angle_type_id)
        JOIN projectprop AS plot_polygons ON(drone_run_band.project_id = plot_polygons.project_id AND plot_polygons.type_id=$plot_polygon_template_type_id)
        JOIN projectprop AS cropping ON(drone_run_band.project_id = cropping.project_id AND cropping.type_id=$cropping_polygon_type_id)
        JOIN projectprop AS drone_run_band_type ON(drone_run_band_type.project_id = drone_run_band.project_id AND drone_run_band_type.type_id = $drone_run_band_type_type_id)
        JOIN phenome.project_md_image AS project_md_image ON(project_md_image.project_id=drone_run_band.project_id AND project_md_image.type_id = $project_image_type_id)
        JOIN metadata.md_image ON(project_md_image.image_id = metadata.md_image.image_id)
        WHERE drone_run.project_id = $drone_run_project_id_input
        AND metadata.md_image.obsolete = 'f';";

    my $h = $bcs_schema->storage->dbh()->prepare($q);
    $h->execute();
    while (my ($rotate_value, $plot_polygons_value, $cropping_value, $drone_run_project_id, $drone_run_project_name, $drone_run_band_project_id, $drone_run_band_project_name, $drone_run_band_type, $denoised_image_id) = $h->fetchrow_array()) {
        $selected_drone_run_band_types{$drone_run_band_type} = $drone_run_band_project_id;
        $drone_run_band_info{$drone_run_band_project_id} = {
            drone_run_project_id => $drone_run_project_id,
            drone_run_project_name => $drone_run_project_name,
            drone_run_band_project_id => $drone_run_band_project_id,
            drone_run_band_project_name => $drone_run_band_project_name,
            drone_run_band_type => $drone_run_band_type,
            rotate_value => $rotate_value,
            plot_polygons_value => $plot_polygons_value,
            cropping_value => $cropping_value,
            denoised_image_id => $denoised_image_id,
            check_resize => 1,
            keep_original_size_rotate => 0
        };
    }

    print STDERR Dumper \%selected_drone_run_band_types;
    print STDERR Dumper \%vegetative_indices_hash;

    _perform_minimal_vi_standard_process($c, $bcs_schema, $metadata_schema, \%vegetative_indices_hash, \%selected_drone_run_band_types, \%drone_run_band_info, $user_id, $user_name, $user_role, 'rectangular_square');

    $drone_run_process_in_progress = $bcs_schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$process_indicator_cvterm_id,
        project_id=>$drone_run_project_id_input,
        rank=>0,
        value=>0
    },
    {
        key=>'projectprop_c1'
    });

    $drone_run_process_minimal_vi_completed = $bcs_schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$processed_minimal_vi_cvterm_id,
        project_id=>$drone_run_project_id_input,
        rank=>0,
        value=>1
    },
    {
        key=>'projectprop_c1'
    });

    _perform_extended_vi_standard_process($c, $bcs_schema, $metadata_schema, \%vegetative_indices_hash, \%selected_drone_run_band_types, \%drone_run_band_info, $user_id, $user_name, $user_role);

    $extended_drone_run_process_in_progress = $bcs_schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$extended_process_indicator_cvterm_id,
        project_id=>$drone_run_project_id_input,
        rank=>0,
        value=>0
    },
    {
        key=>'projectprop_c1'
    });

    $extended_drone_run_process_in_progress = $bcs_schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$extended_processed_cvterm_id,
        project_id=>$drone_run_project_id_input,
        rank=>0,
        value=>1
    },
    {
        key=>'projectprop_c1'
    });

    my @result;
    $c->stash->{rest} = { data => \@result, success => 1 };
}

sub standard_process_extended_apply : Path('/api/drone_imagery/standard_process_extended_apply') : ActionClass('REST') { }
sub standard_process_extended_apply_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $sp_person_id);
    my $metadata_schema = $c->dbic_schema('CXGN::Metadata::Schema', undef, $sp_person_id);
    my $phenome_schema = $c->dbic_schema('CXGN::Phenome::Schema', undef, $sp_person_id);
    my $drone_run_project_id_input = $c->req->param('drone_run_project_id');
    my $time_cvterm_id = $c->req->param('time_days_cvterm_id');
    my $standard_process_type = $c->req->param('standard_process_type');
    my $phenotype_methods = $c->req->param('phenotype_types') ? decode_json $c->req->param('phenotype_types') : ['zonal'];
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $process_indicator_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_standard_process_in_progress', 'project_property')->cvterm_id();
    my $processed_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_standard_process_extended_completed', 'project_property')->cvterm_id();
    my $drone_run_process_in_progress = $bcs_schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$process_indicator_cvterm_id,
        project_id=>$drone_run_project_id_input,
        rank=>0,
        value=>1
    },
    {
        key=>'projectprop_c1'
    });

    $drone_run_process_in_progress = $bcs_schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$processed_cvterm_id,
        project_id=>$drone_run_project_id_input,
        rank=>0,
        value=>0
    },
    {
        key=>'projectprop_c1'
    });

    my %vegetative_indices_hash = (
        'TGI' => 1,
        'VARI' => 1,
        'NDVI' => 1,
        'NDRE' => 1
    );

    my $rotate_angle_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_rotate_angle', 'project_property')->cvterm_id();
    my $cropping_polygon_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_cropped_polygon', 'project_property')->cvterm_id();
    my $plot_polygon_template_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_plot_polygons', 'project_property')->cvterm_id();
    my $drone_run_drone_run_band_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_on_drone_run', 'project_relationship')->cvterm_id();
    my $project_image_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'denoised_stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $drone_run_band_type_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_project_type', 'project_property')->cvterm_id();

    my %selected_drone_run_band_types;
    my %drone_run_band_info;
    my $q = "SELECT rotate.value, plot_polygons.value, cropping.value, drone_run.project_id, drone_run.name, drone_run_band.project_id, drone_run_band.name, drone_run_band_type.value, project_md_image.image_id
        FROM project AS drone_run_band
        JOIN project_relationship ON(project_relationship.subject_project_id = drone_run_band.project_id AND project_relationship.type_id = $drone_run_drone_run_band_type_id)
        JOIN project AS drone_run ON(project_relationship.object_project_id = drone_run.project_id)
        JOIN projectprop AS rotate ON(drone_run_band.project_id = rotate.project_id AND rotate.type_id=$rotate_angle_type_id)
        JOIN projectprop AS plot_polygons ON(drone_run_band.project_id = plot_polygons.project_id AND plot_polygons.type_id=$plot_polygon_template_type_id)
        JOIN projectprop AS cropping ON(drone_run_band.project_id = cropping.project_id AND cropping.type_id=$cropping_polygon_type_id)
        JOIN projectprop AS drone_run_band_type ON(drone_run_band_type.project_id = drone_run_band.project_id AND drone_run_band_type.type_id = $drone_run_band_type_type_id)
        JOIN phenome.project_md_image AS project_md_image ON(project_md_image.project_id=drone_run_band.project_id AND project_md_image.type_id = $project_image_type_id)
        WHERE drone_run.project_id = $drone_run_project_id_input;";

    my $h = $bcs_schema->storage->dbh()->prepare($q);
    $h->execute();
    while (my ($rotate_value, $plot_polygons_value, $cropping_value, $drone_run_project_id, $drone_run_project_name, $drone_run_band_project_id, $drone_run_band_project_name, $drone_run_band_type, $denoised_image_id) = $h->fetchrow_array()) {
        $selected_drone_run_band_types{$drone_run_band_type} = $drone_run_band_project_id;
        $drone_run_band_info{$drone_run_band_project_id} = {
            drone_run_project_name => $drone_run_project_name,
            drone_run_project_id => $drone_run_project_id,
            drone_run_band_project_id => $drone_run_band_project_id,
            drone_run_band_project_name => $drone_run_band_project_name,
            drone_run_band_type => $drone_run_band_type,
            rotate_value => $rotate_value,
            plot_polygons_value => $plot_polygons_value,
            cropping_value => $cropping_value,
            denoised_image_id => $denoised_image_id
        };
    }

    my $original_denoised_imagery_terms = CXGN::DroneImagery::ImageTypes::get_base_imagery_observation_unit_plot_polygon_term_map();

    my $q2 = "SELECT project_md_image.image_id
        FROM project AS drone_run_band
        JOIN phenome.project_md_image AS project_md_image ON(project_md_image.project_id=drone_run_band.project_id AND project_md_image.type_id = ?)
        JOIN metadata.md_image ON(project_md_image.image_id = metadata.md_image.image_id)
        WHERE drone_run_band.project_id = ?
        AND metadata.md_image.obsolete = 'f';";

    my $h2 = $bcs_schema->storage->dbh()->prepare($q2);
    foreach (keys %drone_run_band_info) {
        my $threshold_term = $original_denoised_imagery_terms->{$drone_run_band_info{$_}->{drone_run_band_type}}->{imagery_types}->{threshold_background};
        if ($threshold_term) {
            my $image_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, $threshold_term, 'project_md_image')->cvterm_id();
            $h2->execute($image_type_id, $_);
            my ($threshold_image_id) = $h2->fetchrow_array();
            $drone_run_band_info{$_}->{thresholded_image_id} = $threshold_image_id;
        }
    }

    foreach my $drone_run_band_project_id (keys %drone_run_band_info) {
        my $image_id = $drone_run_band_info{$drone_run_band_project_id}->{denoised_image_id};
        my $drone_run_band_type = $drone_run_band_info{$drone_run_band_project_id}->{drone_run_band_type};
        my $denoised_image_id = $drone_run_band_info{$drone_run_band_project_id}->{denoised_image_id};
        my $plot_polygons_value = $drone_run_band_info{$drone_run_band_project_id}->{plot_polygons_value};
        my $background_removed_threshold_image_id = $drone_run_band_info{$drone_run_band_project_id}->{thresholded_image_id};

        if ($original_denoised_imagery_terms->{$drone_run_band_type}->{imagery_types}->{ft_hpf}->{20}) {
            my @ft_hpf20_imagery_types = @{$original_denoised_imagery_terms->{$drone_run_band_type}->{imagery_types}->{ft_hpf}->{20}};
            my @ft_hpf30_imagery_types = @{$original_denoised_imagery_terms->{$drone_run_band_type}->{imagery_types}->{ft_hpf}->{30}};
            my @ft_hpf40_imagery_types = @{$original_denoised_imagery_terms->{$drone_run_band_type}->{imagery_types}->{ft_hpf}->{40}};
            my @ft_hpf20_plot_polygon_types = @{$original_denoised_imagery_terms->{$drone_run_band_type}->{observation_unit_plot_polygon_types}->{ft_hpf}->{20}};
            my @ft_hpf30_plot_polygon_types = @{$original_denoised_imagery_terms->{$drone_run_band_type}->{observation_unit_plot_polygon_types}->{ft_hpf}->{30}};
            my @ft_hpf40_plot_polygon_types = @{$original_denoised_imagery_terms->{$drone_run_band_type}->{observation_unit_plot_polygon_types}->{ft_hpf}->{40}};
            my @ft_hpf20_background_threshold_removed_imagery_types = @{$original_denoised_imagery_terms->{$drone_run_band_type}->{imagery_types}->{ft_hpf}->{'20_threshold_background'}};
            my @ft_hpf30_background_threshold_removed_imagery_types = @{$original_denoised_imagery_terms->{$drone_run_band_type}->{imagery_types}->{ft_hpf}->{'30_threshold_background'}};
            my @ft_hpf40_background_threshold_removed_imagery_types = @{$original_denoised_imagery_terms->{$drone_run_band_type}->{imagery_types}->{ft_hpf}->{'40_threshold_background'}};
            my @ft_hpf20_background_threshold_removed_plot_polygon_types = @{$original_denoised_imagery_terms->{$drone_run_band_type}->{observation_unit_plot_polygon_types}->{ft_hpf}->{'20_threshold_background'}};
            my @ft_hpf30_background_threshold_removed_plot_polygon_types = @{$original_denoised_imagery_terms->{$drone_run_band_type}->{observation_unit_plot_polygon_types}->{ft_hpf}->{'30_threshold_background'}};
            my @ft_hpf40_background_threshold_removed_plot_polygon_types = @{$original_denoised_imagery_terms->{$drone_run_band_type}->{observation_unit_plot_polygon_types}->{ft_hpf}->{'40_threshold_background'}};

            for my $iterator (0..(scalar(@ft_hpf20_imagery_types)-1)) {
                _perform_extended_base_standard_process($c, $bcs_schema, $metadata_schema, $denoised_image_id, $drone_run_band_project_id, $plot_polygons_value, $ft_hpf20_imagery_types[$iterator], $ft_hpf20_plot_polygon_types[$iterator], $ft_hpf30_imagery_types[$iterator], $ft_hpf30_plot_polygon_types[$iterator], $ft_hpf40_imagery_types[$iterator], $ft_hpf40_plot_polygon_types[$iterator], $background_removed_threshold_image_id, $ft_hpf20_background_threshold_removed_imagery_types[$iterator], $ft_hpf20_background_threshold_removed_plot_polygon_types[$iterator], $ft_hpf30_background_threshold_removed_imagery_types[$iterator], $ft_hpf30_background_threshold_removed_plot_polygon_types[$iterator], $ft_hpf40_background_threshold_removed_imagery_types[$iterator], $ft_hpf40_background_threshold_removed_plot_polygon_types[$iterator], $user_id, $user_name, $user_role);
            }
        }
    }

    print STDERR Dumper \%selected_drone_run_band_types;
    print STDERR Dumper \%vegetative_indices_hash;

    _perform_extended_vi_standard_process($c, $bcs_schema, $metadata_schema, \%vegetative_indices_hash, \%selected_drone_run_band_types, \%drone_run_band_info, $user_id, $user_name, $user_role);

    $drone_run_process_in_progress = $bcs_schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$process_indicator_cvterm_id,
        project_id=>$drone_run_project_id_input,
        rank=>0,
        value=>0
    },
    {
        key=>'projectprop_c1'
    });

    $drone_run_process_in_progress = $bcs_schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$processed_cvterm_id,
        project_id=>$drone_run_project_id_input,
        rank=>0,
        value=>1
    },
    {
        key=>'projectprop_c1'
    });

    my $return = _perform_phenotype_automated($c, $bcs_schema, $metadata_schema, $phenome_schema, $drone_run_project_id_input, $time_cvterm_id, $phenotype_methods, $standard_process_type, 1, undef, $user_id, $user_name, $user_role);

    $c->stash->{rest} = {success => 1};
}

sub _perform_standard_process_minimal_vi_calc {
    my $c = shift;
    my $bcs_schema = shift;
    my $metadata_schema = shift;
    my $denoised_image_id = shift;
    my $merged_drone_run_band_project_id = shift;
    my $user_id = shift;
    my $user_name = shift;
    my $user_role = shift;
    my $plot_polygons_value = shift;
    my $vi = shift;
    my $bands = shift;
    my $cropping_polygon_type = shift || 'rectangular_square';

    my $vi_map_hash = CXGN::DroneImagery::ImageTypes::get_vegetative_index_image_type_term_map();
    my %vi_map = %$vi_map_hash;

    my $index_return = _perform_vegetative_index_calculation($c, $bcs_schema, $metadata_schema, $denoised_image_id, $merged_drone_run_band_project_id, $vi, 0, $bands, $user_id, $user_name, $user_role);
    my $index_image_id = $index_return->{index_image_id};

    my $plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $index_image_id, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{index}->{(%{$vi_map{$vi}->{index}})[0]}->[0], $user_id, $user_name, $user_role, 0, 0, 1, 1, $cropping_polygon_type);
}

sub _perform_standard_process_extended_vi_calc {
    my $c = shift;
    my $bcs_schema = shift;
    my $metadata_schema = shift;
    my $denoised_image_id = shift;
    my $merged_drone_run_band_project_id = shift;
    my $user_id = shift;
    my $user_name = shift;
    my $user_role = shift;
    my $plot_polygons_value = shift;
    my $vi = shift;
    my $bands = shift;

    my $vi_map_hash = CXGN::DroneImagery::ImageTypes::get_vegetative_index_image_type_term_map();
    my %vi_map = %$vi_map_hash;
    my $index_image_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, (%{$vi_map{$vi}->{index}})[0], 'project_md_image')->cvterm_id();
    my $q = "SELECT project_md_image.image_id
            FROM project AS drone_run_band
            JOIN phenome.project_md_image AS project_md_image ON(project_md_image.project_id=drone_run_band.project_id AND project_md_image.type_id = $index_image_type_id)
            JOIN metadata.md_image ON(project_md_image.image_id = metadata.md_image.image_id)
            WHERE drone_run_band.project_id = $merged_drone_run_band_project_id
            AND metadata.md_image.obsolete = 'f';";
    my $h = $bcs_schema->storage->dbh()->prepare($q);
    $h->execute();
    my ($index_image_id) = $h->fetchrow_array();

    #my $fourier_transform_hpf20_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $index_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf20}})[0], '20', 'frequency', $user_id, $user_name, $user_role);

    #my $plot_polygon_ft_hpf20_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf20_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf20}->{(%{$vi_map{$vi}->{ft_hpf20}})[0]}->[0], $user_id, $user_name, $user_role, 0, 0, 1, 1, 'rectangular_square');

    #my $fourier_transform_hpf30_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $index_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf30}})[0], '30', 'frequency', $user_id, $user_name, $user_role);

    #my $plot_polygon_ft_hpf30_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf30_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf30}->{(%{$vi_map{$vi}->{ft_hpf30}})[0]}->[0], $user_id, $user_name, $user_role, 0, 0, 1, 1, 'rectangular_square');

    #my $fourier_transform_hpf40_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $index_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf40}})[0], '40', 'frequency', $user_id, $user_name, $user_role);

    #my $plot_polygon_ft_hpf40_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf40_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf40}->{(%{$vi_map{$vi}->{ft_hpf40}})[0]}->[0], $user_id, $user_name, $user_role, 0, 0, 1, 1, 'rectangular_square');

    my $dir = $c->tempfiles_subdir('/drone_imagery_remove_background');
    my $archive_remove_background_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_remove_background/imageXXXX');
    $archive_remove_background_temp_image .= '.png';

    my $background_removed_threshold_return = _perform_image_background_remove_threshold_percentage($c, $bcs_schema, $index_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{index_threshold_background}})[0], '25', '25', $user_id, $user_name, $user_role, $archive_remove_background_temp_image);
    my $background_removed_threshold_image_id = $background_removed_threshold_return->{removed_background_image_id};

    my $plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $background_removed_threshold_image_id, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{index_threshold_background}->{(%{$vi_map{$vi}->{index_threshold_background}})[0]}->[0], $user_id, $user_name, $user_role, 0, 0, 1, 1, 'rectangular_square');

    #my $fourier_transform_hpf20_thresholded_vi_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $background_removed_threshold_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf20_index_threshold_background}})[0], '20', 'frequency', $user_id, $user_name, $user_role);

    #$plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf20_thresholded_vi_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf20_index_threshold_background}->{(%{$vi_map{$vi}->{ft_hpf20_index_threshold_background}})[0]}->[0], $user_id, $user_name, $user_role, 0, 0, 1, 1, 'rectangular_square');

    #my $fourier_transform_hpf30_thresholded_vi_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $background_removed_threshold_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf30_index_threshold_background}})[0], '30', 'frequency', $user_id, $user_name, $user_role);

    #$plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf30_thresholded_vi_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf30_index_threshold_background}->{(%{$vi_map{$vi}->{ft_hpf30_index_threshold_background}})[0]}->[0], $user_id, $user_name, $user_role, 0, 0, 1, 1, 'rectangular_square');

    #my $fourier_transform_hpf40_thresholded_vi_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $background_removed_threshold_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf40_index_threshold_background}})[0], '40', 'frequency', $user_id, $user_name, $user_role);

    #$plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf40_thresholded_vi_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf40_index_threshold_background}->{(%{$vi_map{$vi}->{ft_hpf40_index_threshold_background}})[0]}->[0], $user_id, $user_name, $user_role, 0, 0, 1, 1);

    #my $threshold_masked_return = _perform_image_background_remove_mask($c, $bcs_schema, $denoised_image_id, $background_removed_threshold_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{original_thresholded_index_mask_background}})[0], $user_id, $user_name, $user_role);
    #my $threshold_masked_image_id = $threshold_masked_return->{masked_image_id};

    #$plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $threshold_masked_image_id, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{original_thresholded_index_mask_background}->{(%{$vi_map{$vi}->{original_thresholded_index_mask_background}})[0]}->[0], $user_id, $user_name, $user_role, 0, 0, 1, 1, 'rectangular_square');

    #$plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $threshold_masked_image_id, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{original_thresholded_index_mask_background}->{(%{$vi_map{$vi}->{original_thresholded_index_mask_background}})[0]}->[1], $user_id, $user_name, $user_role, 0, 0, 1, 1, 'rectangular_square');

    #$plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $threshold_masked_image_id, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{original_thresholded_index_mask_background}->{(%{$vi_map{$vi}->{original_thresholded_index_mask_background}})[0]}->[2], $user_id, $user_name, $user_role, 0, 0, 1, 1, 'rectangular_square');

    #if ($vi_map{$vi}->{original_thresholded_index_mask_background}->{(%{$vi_map{$vi}->{original_thresholded_index_mask_background}})[0]}->[3]) {
    #    $plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $threshold_masked_image_id, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{original_thresholded_index_mask_background}->{(%{$vi_map{$vi}->{original_thresholded_index_mask_background}})[0]}->[3], $user_id, $user_name, $user_role, 0, 0, 1, 1, 'rectangular_square');
    #}

    #my $fourier_transform_hpf20_original_background_removed_thresholded_vi_mask_channel_1_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $threshold_masked_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf20_original_thresholded_index_mask_background_channel_1}})[0], '20', 'frequency', $user_id, $user_name, $user_role);

    #my $plot_polygon_ft_hpf20_background_threshold_mask_channel_1_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf20_original_background_removed_thresholded_vi_mask_channel_1_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf20_original_thresholded_index_mask_background_channel_1}->{(%{$vi_map{$vi}->{ft_hpf20_original_thresholded_index_mask_background_channel_1}})[0]}->[0], $user_id, $user_name, $user_role, 0, 0, 1, 1, 'rectangular_square');

    #my $fourier_transform_hpf30_original_background_removed_thresholded_vi_mask_channel_1_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $threshold_masked_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf30_original_thresholded_index_mask_background_channel_1}})[0], '30', 'frequency', $user_id, $user_name, $user_role);

    #my $plot_polygon_ft_hpf30_background_threshold_mask_channel_1_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf30_original_background_removed_thresholded_vi_mask_channel_1_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf30_original_thresholded_index_mask_background_channel_1}->{(%{$vi_map{$vi}->{ft_hpf30_original_thresholded_index_mask_background_channel_1}})[0]}->[0], $user_id, $user_name, $user_role, 0, 0, 1, 1, 'rectangular_square');

    #my $fourier_transform_hpf40_original_background_removed_thresholded_vi_mask_channel_1_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $threshold_masked_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf40_original_thresholded_index_mask_background_channel_1}})[0], '40', 'frequency', $user_id, $user_name, $user_role);

    #my $plot_polygon_ft_hpf40_background_threshold_mask_channel_1_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf40_original_background_removed_thresholded_vi_mask_channel_1_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf40_original_thresholded_index_mask_background_channel_1}->{(%{$vi_map{$vi}->{ft_hpf40_original_thresholded_index_mask_background_channel_1}})[0]}->[0], $user_id, $user_name, $user_role, 0, 0, 1, 1, 'rectangular_square');

    #my $fourier_transform_hpf20_original_background_removed_thresholded_vi_mask_channel_2_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $threshold_masked_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf20_original_thresholded_index_mask_background_channel_2}})[0], '20', 'frequency', $user_id, $user_name, $user_role);

    #my $plot_polygon_ft_hpf20_background_threshold_mask_channel_2_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf20_original_background_removed_thresholded_vi_mask_channel_2_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf20_original_thresholded_index_mask_background_channel_2}->{(%{$vi_map{$vi}->{ft_hpf20_original_thresholded_index_mask_background_channel_2}})[0]}->[0], $user_id, $user_name, $user_role, 0, 0, 1, 1, 'rectangular_square');

    #my $fourier_transform_hpf30_original_background_removed_thresholded_vi_mask_channel_2_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $threshold_masked_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf30_original_thresholded_index_mask_background_channel_2}})[0], '30', 'frequency', $user_id, $user_name, $user_role);

    #my $plot_polygon_ft_hpf30_background_threshold_mask_channel_2_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf30_original_background_removed_thresholded_vi_mask_channel_2_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf30_original_thresholded_index_mask_background_channel_2}->{(%{$vi_map{$vi}->{ft_hpf30_original_thresholded_index_mask_background_channel_2}})[0]}->[0], $user_id, $user_name, $user_role, 0, 0, 1, 1, 'rectangular_square');

    #my $fourier_transform_hpf40_original_background_removed_thresholded_vi_mask_channel_2_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $threshold_masked_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf40_original_thresholded_index_mask_background_channel_2}})[0], '40', 'frequency', $user_id, $user_name, $user_role);

    #my $plot_polygon_ft_hpf40_background_threshold_mask_channel_2_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf40_original_background_removed_thresholded_vi_mask_channel_2_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf40_original_thresholded_index_mask_background_channel_2}->{(%{$vi_map{$vi}->{ft_hpf40_original_thresholded_index_mask_background_channel_2}})[0]}->[0], $user_id, $user_name, $user_role, 0, 0, 1, 1, 'rectangular_square');

    #if ($vi_map{$vi}->{ft_hpf20_original_thresholded_index_mask_background_channel_3}) {
    #    my $fourier_transform_hpf20_original_background_removed_thresholded_vi_mask_channel_3_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $threshold_masked_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf20_original_thresholded_index_mask_background_channel_3}})[0], '20', 'frequency', $user_id, $user_name, $user_role);

    #    my $plot_polygon_ft_hpf20_background_threshold_mask_channel_3_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf20_original_background_removed_thresholded_vi_mask_channel_3_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf20_original_thresholded_index_mask_background_channel_3}->{(%{$vi_map{$vi}->{ft_hpf20_original_thresholded_index_mask_background_channel_3}})[0]}->[0], $user_id, $user_name, $user_role, 0, 0, 1, 1, 'rectangular_square');
    #}

    #if ($vi_map{$vi}->{ft_hpf30_original_thresholded_index_mask_background_channel_3}) {
    #    my $fourier_transform_hpf30_original_background_removed_thresholded_vi_mask_channel_3_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $threshold_masked_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf30_original_thresholded_index_mask_background_channel_3}})[0], '30', 'frequency', $user_id, $user_name, $user_role);

    #    my $plot_polygon_ft_hpf30_background_threshold_mask_channel_3_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf30_original_background_removed_thresholded_vi_mask_channel_3_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf30_original_thresholded_index_mask_background_channel_3}->{(%{$vi_map{$vi}->{ft_hpf30_original_thresholded_index_mask_background_channel_3}})[0]}->[0], $user_id, $user_name, $user_role, 0, 0, 1, 1, 'rectangular_square');
    #}

    #if ($vi_map{$vi}->{ft_hpf40_original_thresholded_index_mask_background_channel_3}) {
    #    my $fourier_transform_hpf40_original_background_removed_thresholded_vi_mask_channel_3_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $threshold_masked_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf40_original_thresholded_index_mask_background_channel_3}})[0], '40', 'frequency', $user_id, $user_name, $user_role);

    #    my $plot_polygon_ft_hpf40_background_threshold_mask_channel_3_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf40_original_background_removed_thresholded_vi_mask_channel_3_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf40_original_thresholded_index_mask_background_channel_3}->{(%{$vi_map{$vi}->{ft_hpf40_original_thresholded_index_mask_background_channel_3}})[0]}->[0], $user_id, $user_name, $user_role, 0, 0, 1, 1, 'rectangular_square');
    #}

    # my $masked_return = _perform_image_background_remove_mask($c, $bcs_schema, $denoised_image_id, $index_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{original_index_mask_background}})[0], $user_id, $user_name, $user_role);
    # my $masked_image_id = $masked_return->{masked_image_id};

    # $plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $masked_image_id, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{original_index_mask_background}->{(%{$vi_map{$vi}->{original_index_mask_background}})[0]}->[0], $user_id, $user_name, $user_role, 0, 0, 1, 1, 'rectangular_square');
    #
    # $plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $masked_image_id, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{original_index_mask_background}->{(%{$vi_map{$vi}->{original_index_mask_background}})[0]}->[1], $user_id, $user_name, $user_role, 0, 0, 1, 1, 'rectangular_square');
    #
    # $plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $masked_image_id, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{original_index_mask_background}->{(%{$vi_map{$vi}->{original_index_mask_background}})[0]}->[2], $user_id, $user_name, $user_role, 0, 0, 1, 1, 'rectangular_square');
    #
    # if ($vi_map{$vi}->{original_index_mask_background}->{(%{$vi_map{$vi}->{original_index_mask_background}})[0]}->[3]) {
    #     $plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $masked_image_id, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{original_index_mask_background}->{(%{$vi_map{$vi}->{original_index_mask_background}})[0]}->[3], $user_id, $user_name, $user_role, 0, 0, 1, 1, 'rectangular_square');
    # }

    #my $fourier_transform_hpf20_original_vi_mask_channel_1_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $masked_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf20_original_index_mask_background_channel_1}})[0], '20', 'frequency', $user_id, $user_name, $user_role);

    #my $plot_polygon_ft_hpf20_vi_return_channel_1 = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf20_original_vi_mask_channel_1_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf20_original_index_mask_background_channel_1}->{(%{$vi_map{$vi}->{ft_hpf20_original_index_mask_background_channel_1}})[0]}->[0], $user_id, $user_name, $user_role, 0, 0, 1, 1, 'rectangular_square');

    #my $fourier_transform_hpf30_original_vi_mask_channel_1_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $masked_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf30_original_index_mask_background_channel_1}})[0], '30', 'frequency', $user_id, $user_name, $user_role);

    #my $plot_polygon_ft_hpf30_vi_return_channel_1 = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf30_original_vi_mask_channel_1_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf30_original_index_mask_background_channel_1}->{(%{$vi_map{$vi}->{ft_hpf30_original_index_mask_background_channel_1}})[0]}->[0], $user_id, $user_name, $user_role, 0, 0, 1, 1, 'rectangular_square');

    #my $fourier_transform_hpf40_original_vi_mask_channel_1_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $masked_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf40_original_index_mask_background_channel_1}})[0], '40', 'frequency', $user_id, $user_name, $user_role);

    #my $plot_polygon_ft_hpf40_vi_return_channel_1 = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf40_original_vi_mask_channel_1_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf40_original_index_mask_background_channel_1}->{(%{$vi_map{$vi}->{ft_hpf40_original_index_mask_background_channel_1}})[0]}->[0], $user_id, $user_name, $user_role, 0, 0, 1, 1, 'rectangular_square');

    #my $fourier_transform_hpf20_original_vi_mask_channel_2_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $masked_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf20_original_index_mask_background_channel_2}})[0], '20', 'frequency', $user_id, $user_name, $user_role);

    #my $plot_polygon_ft_hpf20_vi_return_channel_2 = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf20_original_vi_mask_channel_2_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf20_original_index_mask_background_channel_2}->{(%{$vi_map{$vi}->{ft_hpf20_original_index_mask_background_channel_2}})[0]}->[0], $user_id, $user_name, $user_role, 0, 0, 1, 1, 'rectangular_square');

    #my $fourier_transform_hpf30_original_vi_mask_channel_2_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $masked_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf30_original_index_mask_background_channel_2}})[0], '30', 'frequency', $user_id, $user_name, $user_role);

    #my $plot_polygon_ft_hpf30_vi_return_channel_2 = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf30_original_vi_mask_channel_2_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf30_original_index_mask_background_channel_2}->{(%{$vi_map{$vi}->{ft_hpf30_original_index_mask_background_channel_2}})[0]}->[0], $user_id, $user_name, $user_role, 0, 0, 1, 1, 'rectangular_square');

    #my $fourier_transform_hpf40_original_vi_mask_channel_2_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $masked_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf40_original_index_mask_background_channel_2}})[0], '40', 'frequency', $user_id, $user_name, $user_role);

    #my $plot_polygon_ft_hpf40_vi_return_channel_2 = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf40_original_vi_mask_channel_2_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf40_original_index_mask_background_channel_2}->{(%{$vi_map{$vi}->{ft_hpf40_original_index_mask_background_channel_2}})[0]}->[0], $user_id, $user_name, $user_role, 0, 0, 1, 1, 'rectangular_square');

    #if ($vi_map{$vi}->{ft_hpf20_original_index_mask_background_channel_3}) {
    #    my $fourier_transform_hpf20_original_vi_mask_channel_3_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $masked_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf20_original_index_mask_background_channel_3}})[0], '20', 'frequency', $user_id, $user_name, $user_role);

    #    my $plot_polygon_ft_hpf20_vi_return_channel_3 = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf20_original_vi_mask_channel_3_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf20_original_index_mask_background_channel_3}->{(%{$vi_map{$vi}->{ft_hpf20_original_index_mask_background_channel_3}})[0]}->[0], $user_id, $user_name, $user_role, 0, 0, 1, 1, 'rectangular_square');
    #}

    #if ($vi_map{$vi}->{ft_hpf30_original_index_mask_background_channel_3}) {
    #    my $fourier_transform_hpf30_original_vi_mask_channel_3_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $masked_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf30_original_index_mask_background_channel_3}})[0], '30', 'frequency', $user_id, $user_name, $user_role);

    #    my $plot_polygon_ft_hpf30_vi_return_channel_3 = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf30_original_vi_mask_channel_3_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf30_original_index_mask_background_channel_3}->{(%{$vi_map{$vi}->{ft_hpf30_original_index_mask_background_channel_3}})[0]}->[0], $user_id, $user_name, $user_role, 0, 0, 1, 1, 'rectangular_square');
    #}

    #if ($vi_map{$vi}->{ft_hpf40_original_index_mask_background_channel_3}) {
    #    my $fourier_transform_hpf40_original_vi_mask_channel_3_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $masked_image_id, $merged_drone_run_band_project_id, (%{$vi_map{$vi}->{ft_hpf40_original_index_mask_background_channel_3}})[0], '40', 'frequency', $user_id, $user_name, $user_role);

    #    my $plot_polygon_ft_hpf40_vi_return_channel_3 = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf40_original_vi_mask_channel_3_return->{ft_image_id}, $merged_drone_run_band_project_id, $plot_polygons_value, $vi_map{$vi}->{ft_hpf40_original_index_mask_background_channel_3}->{(%{$vi_map{$vi}->{ft_hpf40_original_index_mask_background_channel_3}})[0]}->[0], $user_id, $user_name, $user_role, 0, 0, 1, 1, 'rectangular_square');
    #}
}

sub _perform_extended_base_standard_process {
    my $c = shift;
    my $bcs_schema = shift;
    my $metadata_schema = shift;
    my $denoised_image_id = shift;
    my $drone_run_band_project_id = shift;
    my $plot_polygons_value = shift;
    my $ft_hpf20_imagery_type = shift;
    my $ft_hpf20_plot_polygon_type = shift;
    my $ft_hpf30_imagery_type = shift;
    my $ft_hpf30_plot_polygon_type = shift;
    my $ft_hpf40_imagery_type = shift;
    my $ft_hpf40_plot_polygon_type = shift;
    my $background_removed_threshold_image_id = shift;
    my $ft_hpf20_background_threshold_removed_imagery_type = shift;
    my $ft_hpf20_background_threshold_removed_plot_polygon_type = shift;
    my $ft_hpf30_background_threshold_removed_imagery_type = shift;
    my $ft_hpf30_background_threshold_removed_plot_polygon_type = shift;
    my $ft_hpf40_background_threshold_removed_imagery_type = shift;
    my $ft_hpf40_background_threshold_removed_plot_polygon_type = shift;
    my $user_id = shift;
    my $user_name = shift;
    my $user_role = shift;

    #my $fourier_transform_hpf20_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $denoised_image_id, $drone_run_band_project_id, $ft_hpf20_imagery_type, '20', 'frequency', $user_id, $user_name, $user_role);

    #my $plot_polygon_ft_hpf20_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf20_return->{ft_image_id}, $drone_run_band_project_id, $plot_polygons_value, $ft_hpf20_plot_polygon_type, $user_id, $user_name, $user_role, 0, 0, 1, 1);

    #my $fourier_transform_hpf30_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $denoised_image_id, $drone_run_band_project_id, $ft_hpf30_imagery_type, '30', 'frequency', $user_id, $user_name, $user_role);

    #my $plot_polygon_ft_hpf30_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf30_return->{ft_image_id}, $drone_run_band_project_id, $plot_polygons_value, $ft_hpf30_plot_polygon_type, $user_id, $user_name, $user_role, 0, 0, 1, 1);

    #my $fourier_transform_hpf40_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $denoised_image_id, $drone_run_band_project_id, $ft_hpf40_imagery_type, '40', 'frequency', $user_id, $user_name, $user_role);

    #my $plot_polygon_ft_hpf40_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf40_return->{ft_image_id}, $drone_run_band_project_id, $plot_polygons_value, $ft_hpf40_plot_polygon_type, $user_id, $user_name, $user_role, 0, 0, 1, 1);

    #my $fourier_transform_hpf20_background_removed_threshold_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $background_removed_threshold_image_id, $drone_run_band_project_id, $ft_hpf20_background_threshold_removed_imagery_type, '20', 'frequency', $user_id, $user_name, $user_role);

    #my $plot_polygon_ft_hpf20_background_removed_threshold_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf20_background_removed_threshold_return->{ft_image_id}, $drone_run_band_project_id, $plot_polygons_value, $ft_hpf20_background_threshold_removed_plot_polygon_type, $user_id, $user_name, $user_role, 0, 0, 1, 1);

    #my $fourier_transform_hpf30_background_removed_threshold_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $background_removed_threshold_image_id, $drone_run_band_project_id, $ft_hpf30_background_threshold_removed_imagery_type, '30', 'frequency', $user_id, $user_name, $user_role);

    #my $plot_polygon_ft_hpf30_background_removed_threshold_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf30_background_removed_threshold_return->{ft_image_id}, $drone_run_band_project_id, $plot_polygons_value, $ft_hpf30_background_threshold_removed_plot_polygon_type, $user_id, $user_name, $user_role, 0, 0, 1, 1);

    #my $fourier_transform_hpf40_background_removed_threshold_return = _perform_fourier_transform_calculation($c, $bcs_schema, $metadata_schema, $background_removed_threshold_image_id, $drone_run_band_project_id, $ft_hpf40_background_threshold_removed_imagery_type, '40', 'frequency', $user_id, $user_name, $user_role);

    #my $plot_polygon_ft_hpf40_background_removed_threshold_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $fourier_transform_hpf40_background_removed_threshold_return->{ft_image_id}, $drone_run_band_project_id, $plot_polygons_value, $ft_hpf40_background_threshold_removed_plot_polygon_type, $user_id, $user_name, $user_role, 0, 0, 1, 1);
}

sub _perform_minimal_vi_standard_process {
    my $c = shift;
    my $bcs_schema = shift;
    my $metadata_schema = shift;
    my $vegetative_indices = shift;
    my $selected_drone_run_band_types = shift;
    my $drone_run_band_info = shift;
    my $user_id = shift;
    my $user_name = shift;
    my $user_role = shift;
    my $cropping_polygon_type = shift || 'rectangular_square';

    if (exists($vegetative_indices->{'TGI'}) || exists($vegetative_indices->{'VARI'})) {
        if(exists($selected_drone_run_band_types->{'Blue (450-520nm)'}) && exists($selected_drone_run_band_types->{'Green (515-600nm)'}) && exists($selected_drone_run_band_types->{'Red (600-690nm)'}) ) {
            my $merged_return = _perform_image_merge($c, $bcs_schema, $metadata_schema, $drone_run_band_info->{$selected_drone_run_band_types->{'Blue (450-520nm)'}}->{drone_run_project_id}, $drone_run_band_info->{$selected_drone_run_band_types->{'Blue (450-520nm)'}}->{drone_run_project_name}, $selected_drone_run_band_types->{'Blue (450-520nm)'}, $selected_drone_run_band_types->{'Green (515-600nm)'}, $selected_drone_run_band_types->{'Red (600-690nm)'}, 'BGR', $user_id, $user_name, $user_role);
            my $merged_image_id = $merged_return->{merged_image_id};
            my $merged_drone_run_band_project_id = $merged_return->{merged_drone_run_band_project_id};

            my $dir = $c->tempfiles_subdir('/drone_imagery_rotate');
            my $archive_rotate_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_rotate/imageXXXX');
            $archive_rotate_temp_image .= '.png';

            my $rotate_return = _perform_image_rotate($c, $bcs_schema, $metadata_schema, $merged_drone_run_band_project_id, $merged_image_id, $drone_run_band_info->{$selected_drone_run_band_types->{'Blue (450-520nm)'}}->{rotate_value}, 0, $user_id, $user_name, $user_role, $archive_rotate_temp_image,0,0, $drone_run_band_info->{$selected_drone_run_band_types->{'Blue (450-520nm)'}}->{check_resize}, $drone_run_band_info->{$selected_drone_run_band_types->{'Blue (450-520nm)'}}->{keep_original_size_rotate});
            my $rotated_image_id = $rotate_return->{rotated_image_id};

            $dir = $c->tempfiles_subdir('/drone_imagery_cropped_image');
            my $archive_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_cropped_image/imageXXXX');
            $archive_temp_image .= '.png';

            my $cropping_return = _perform_image_cropping($c, $bcs_schema, $merged_drone_run_band_project_id, $rotated_image_id, $drone_run_band_info->{$selected_drone_run_band_types->{'Blue (450-520nm)'}}->{cropping_value}, $user_id, $user_name, $user_role, $archive_temp_image, 1, 1);
            my $cropped_image_id = $cropping_return->{cropped_image_id};

            $dir = $c->tempfiles_subdir('/drone_imagery_denoise');
            my $archive_denoise_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_denoise/imageXXXX');
            $archive_denoise_temp_image .= '.png';

            my $denoise_return = _perform_image_denoise($c, $bcs_schema, $metadata_schema, $cropped_image_id, $merged_drone_run_band_project_id, $user_id, $user_name, $user_role, $archive_denoise_temp_image);
            my $denoised_image_id = $denoise_return->{denoised_image_id};

            my $plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $denoised_image_id, $merged_drone_run_band_project_id, $drone_run_band_info->{$selected_drone_run_band_types->{'Blue (450-520nm)'}}->{plot_polygons_value}, 'observation_unit_polygon_rgb_imagery', $user_id, $user_name, $user_role, 0, 0, 1, 1, $cropping_polygon_type);

            if (exists($vegetative_indices->{'TGI'})) {
                _perform_standard_process_minimal_vi_calc($c, $bcs_schema, $metadata_schema, $denoised_image_id, $merged_drone_run_band_project_id, $user_id, $user_name, $user_role, $drone_run_band_info->{$selected_drone_run_band_types->{'Blue (450-520nm)'}}->{plot_polygons_value}, 'TGI', 'BGR', $cropping_polygon_type);
            }
            if (exists($vegetative_indices->{'VARI'})) {
                _perform_standard_process_minimal_vi_calc($c, $bcs_schema, $metadata_schema, $denoised_image_id, $merged_drone_run_band_project_id, $user_id, $user_name, $user_role, $drone_run_band_info->{$selected_drone_run_band_types->{'Blue (450-520nm)'}}->{plot_polygons_value}, 'VARI', 'BGR', $cropping_polygon_type);
            }
        }
        if (exists($selected_drone_run_band_types->{'RGB Color Image'})) {
            if (exists($vegetative_indices->{'TGI'})) {
                _perform_standard_process_minimal_vi_calc($c, $bcs_schema, $metadata_schema, $drone_run_band_info->{$selected_drone_run_band_types->{'RGB Color Image'}}->{denoised_image_id}, $selected_drone_run_band_types->{'RGB Color Image'}, $user_id, $user_name, $user_role, $drone_run_band_info->{$selected_drone_run_band_types->{'RGB Color Image'}}->{plot_polygons_value}, 'TGI', 'BGR', $cropping_polygon_type);
            }
            if (exists($vegetative_indices->{'VARI'})) {
                _perform_standard_process_minimal_vi_calc($c, $bcs_schema, $metadata_schema, $drone_run_band_info->{$selected_drone_run_band_types->{'RGB Color Image'}}->{denoised_image_id}, $selected_drone_run_band_types->{'RGB Color Image'}, $user_id, $user_name, $user_role, $drone_run_band_info->{$selected_drone_run_band_types->{'RGB Color Image'}}->{plot_polygons_value}, 'VARI', 'BGR', $cropping_polygon_type);
            }
        }
    }
    if (exists($vegetative_indices->{'NDVI'})) {
        if(exists($selected_drone_run_band_types->{'NIR (780-3000nm)'}) && exists($selected_drone_run_band_types->{'Red (600-690nm)'}) ) {
            my $merged_return = _perform_image_merge($c, $bcs_schema, $metadata_schema, $drone_run_band_info->{$selected_drone_run_band_types->{'NIR (780-3000nm)'}}->{drone_run_project_id}, $drone_run_band_info->{$selected_drone_run_band_types->{'NIR (780-3000nm)'}}->{drone_run_project_name}, $selected_drone_run_band_types->{'NIR (780-3000nm)'}, $selected_drone_run_band_types->{'Red (600-690nm)'}, $selected_drone_run_band_types->{'NIR (780-3000nm)'}, 'NRN', $user_id, $user_name, $user_role);
            my $merged_image_id = $merged_return->{merged_image_id};
            my $merged_drone_run_band_project_id = $merged_return->{merged_drone_run_band_project_id};

            my $dir = $c->tempfiles_subdir('/drone_imagery_rotate');
            my $archive_rotate_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_rotate/imageXXXX');
            $archive_rotate_temp_image .= '.png';

            my $rotate_return = _perform_image_rotate($c, $bcs_schema, $metadata_schema, $merged_drone_run_band_project_id, $merged_image_id, $drone_run_band_info->{$selected_drone_run_band_types->{'NIR (780-3000nm)'}}->{rotate_value}, 0, $user_id, $user_name, $user_role, $archive_rotate_temp_image, 0, 0, $drone_run_band_info->{$selected_drone_run_band_types->{'NIR (780-3000nm)'}}->{check_resize}, $drone_run_band_info->{$selected_drone_run_band_types->{'NIR (780-3000nm)'}}->{keep_original_size_rotate});
            my $rotated_image_id = $rotate_return->{rotated_image_id};

            $dir = $c->tempfiles_subdir('/drone_imagery_cropped_image');
            my $archive_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_cropped_image/imageXXXX');
            $archive_temp_image .= '.png';

            my $cropping_return = _perform_image_cropping($c, $bcs_schema, $merged_drone_run_band_project_id, $rotated_image_id, $drone_run_band_info->{$selected_drone_run_band_types->{'NIR (780-3000nm)'}}->{cropping_value}, $user_id, $user_name, $user_role, $archive_temp_image, 1, 1);
            my $cropped_image_id = $cropping_return->{cropped_image_id};

            $dir = $c->tempfiles_subdir('/drone_imagery_denoise');
            my $archive_denoise_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_denoise/imageXXXX');
            $archive_denoise_temp_image .= '.png';

            my $denoise_return = _perform_image_denoise($c, $bcs_schema, $metadata_schema, $cropped_image_id, $merged_drone_run_band_project_id, $user_id, $user_name, $user_role, $archive_denoise_temp_image);
            my $denoised_image_id = $denoise_return->{denoised_image_id};

            my $plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $denoised_image_id, $merged_drone_run_band_project_id, $drone_run_band_info->{$selected_drone_run_band_types->{'NIR (780-3000nm)'}}->{plot_polygons_value}, 'observation_unit_polygon_nrn_imagery', $user_id, $user_name, $user_role, 0, 0, 1, 1, $cropping_polygon_type);

            _perform_standard_process_minimal_vi_calc($c, $bcs_schema, $metadata_schema, $denoised_image_id, $merged_drone_run_band_project_id, $user_id, $user_name, $user_role, $drone_run_band_info->{$selected_drone_run_band_types->{'NIR (780-3000nm)'}}->{plot_polygons_value}, 'NDVI', 'NRN', $cropping_polygon_type);
        }
    }
    if (exists($vegetative_indices->{'NDRE'})) {
        if(exists($selected_drone_run_band_types->{'NIR (780-3000nm)'}) && exists($selected_drone_run_band_types->{'Red Edge (690-750nm)'}) ) {
            my $merged_return = _perform_image_merge($c, $bcs_schema, $metadata_schema, $drone_run_band_info->{$selected_drone_run_band_types->{'NIR (780-3000nm)'}}->{drone_run_project_id}, $drone_run_band_info->{$selected_drone_run_band_types->{'NIR (780-3000nm)'}}->{drone_run_project_name}, $selected_drone_run_band_types->{'NIR (780-3000nm)'}, $selected_drone_run_band_types->{'Red Edge (690-750nm)'}, $selected_drone_run_band_types->{'NIR (780-3000nm)'}, 'NReN', $user_id, $user_name, $user_role);
            my $merged_image_id = $merged_return->{merged_image_id};
            my $merged_drone_run_band_project_id = $merged_return->{merged_drone_run_band_project_id};

            my $dir = $c->tempfiles_subdir('/drone_imagery_rotate');
            my $archive_rotate_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_rotate/imageXXXX');
            $archive_rotate_temp_image .= '.png';

            my $rotate_return = _perform_image_rotate($c, $bcs_schema, $metadata_schema, $merged_drone_run_band_project_id, $merged_image_id, $drone_run_band_info->{$selected_drone_run_band_types->{'NIR (780-3000nm)'}}->{rotate_value}, 0, $user_id, $user_name, $user_role, $archive_rotate_temp_image, 0, 0, $drone_run_band_info->{$selected_drone_run_band_types->{'NIR (780-3000nm)'}}->{check_resize}, $drone_run_band_info->{$selected_drone_run_band_types->{'NIR (780-3000nm)'}}->{keep_original_size_rotate});
            my $rotated_image_id = $rotate_return->{rotated_image_id};

            $dir = $c->tempfiles_subdir('/drone_imagery_cropped_image');
            my $archive_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_cropped_image/imageXXXX');
            $archive_temp_image .= '.png';

            my $cropping_return = _perform_image_cropping($c, $bcs_schema, $merged_drone_run_band_project_id, $rotated_image_id, $drone_run_band_info->{$selected_drone_run_band_types->{'NIR (780-3000nm)'}}->{cropping_value}, $user_id, $user_name, $user_role, $archive_temp_image, 1, 1);
            my $cropped_image_id = $cropping_return->{cropped_image_id};

            $dir = $c->tempfiles_subdir('/drone_imagery_denoise');
            my $archive_denoise_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_denoise/imageXXXX');
            $archive_denoise_temp_image .= '.png';

            my $denoise_return = _perform_image_denoise($c, $bcs_schema, $metadata_schema, $cropped_image_id, $merged_drone_run_band_project_id, $user_id, $user_name, $user_role, $archive_denoise_temp_image);
            my $denoised_image_id = $denoise_return->{denoised_image_id};

            my $plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $denoised_image_id, $merged_drone_run_band_project_id, $drone_run_band_info->{$selected_drone_run_band_types->{'NIR (780-3000nm)'}}->{plot_polygons_value}, 'observation_unit_polygon_nren_imagery', $user_id, $user_name, $user_role, 0, 0, 1, 1, $cropping_polygon_type);

            _perform_standard_process_minimal_vi_calc($c, $bcs_schema, $metadata_schema, $denoised_image_id, $merged_drone_run_band_project_id, $user_id, $user_name, $user_role, $drone_run_band_info->{$selected_drone_run_band_types->{'NIR (780-3000nm)'}}->{plot_polygons_value}, 'NDRE', 'NReN', $cropping_polygon_type);
        }
    }
}

sub _perform_extended_vi_standard_process {
    my $c = shift;
    my $bcs_schema = shift;
    my $metadata_schema = shift;
    my $vegetative_indices = shift;
    my %vegetative_indices_hash = %$vegetative_indices;
    my $selected_drone_run_band_types_input = shift;
    my %selected_drone_run_band_types = %$selected_drone_run_band_types_input;
    my $drone_run_band_info = shift;
    my $user_id = shift;
    my $user_name = shift;
    my $user_role = shift;

    if (exists($vegetative_indices_hash{'TGI'}) || exists($vegetative_indices_hash{'VARI'})) {
        if(exists($selected_drone_run_band_types{'Merged 3 Bands BGR'}) ) {
            my $drone_run_band_project_id = $selected_drone_run_band_types{'Merged 3 Bands BGR'};
            my $drone_run_band_info = $drone_run_band_info->{$drone_run_band_project_id};
            if (exists($vegetative_indices_hash{'TGI'})) {
                _perform_standard_process_extended_vi_calc($c, $bcs_schema, $metadata_schema, $drone_run_band_info->{denoised_image_id}, $drone_run_band_project_id, $user_id, $user_name, $user_role, $drone_run_band_info->{plot_polygons_value}, 'TGI', 'BGR');
            }
            if (exists($vegetative_indices_hash{'VARI'})) {
                _perform_standard_process_extended_vi_calc($c, $bcs_schema, $metadata_schema, $drone_run_band_info->{denoised_image_id}, $selected_drone_run_band_types{'Merged 3 Bands BGR'}, $user_id, $user_name, $user_role, $drone_run_band_info->{plot_polygons_value}, 'VARI', 'BGR');
            }
        }
        if (exists($selected_drone_run_band_types{'RGB Color Image'})) {
            my $drone_run_band_project_id = $selected_drone_run_band_types{'RGB Color Image'};
            my $drone_run_band_info = $drone_run_band_info->{$drone_run_band_project_id};
            if (exists($vegetative_indices_hash{'TGI'})) {
                _perform_standard_process_extended_vi_calc($c, $bcs_schema, $metadata_schema, $drone_run_band_info->{denoised_image_id}, $drone_run_band_project_id, $user_id, $user_name, $user_role, $drone_run_band_info->{plot_polygons_value}, 'TGI', 'BGR');
            }
            if (exists($vegetative_indices_hash{'VARI'})) {
                _perform_standard_process_extended_vi_calc($c, $bcs_schema, $metadata_schema, $drone_run_band_info->{denoised_image_id}, $drone_run_band_project_id, $user_id, $user_name, $user_role, $drone_run_band_info->{plot_polygons_value}, 'VARI', 'BGR');
            }
        }
    }
    if (exists($vegetative_indices_hash{'NDVI'})) {
        if(exists($selected_drone_run_band_types{'Merged 3 Bands NRN'}) ) {
            my $drone_run_band_project_id = $selected_drone_run_band_types{'Merged 3 Bands NRN'};
            my $drone_run_band_info = $drone_run_band_info->{$drone_run_band_project_id};
            _perform_standard_process_extended_vi_calc($c, $bcs_schema, $metadata_schema, $drone_run_band_info->{denoised_image_id}, $drone_run_band_project_id, $user_id, $user_name, $user_role, $drone_run_band_info->{plot_polygons_value}, 'NDVI', 'NRN');
        }
    }
    if (exists($vegetative_indices_hash{'NDRE'})) {
        if(exists($selected_drone_run_band_types{'Merged 3 Bands NReN'}) ) {
            my $drone_run_band_project_id = $selected_drone_run_band_types{'Merged 3 Bands NReN'};
            my $drone_run_band_info = $drone_run_band_info->{$drone_run_band_project_id};
            _perform_standard_process_extended_vi_calc($c, $bcs_schema, $metadata_schema, $drone_run_band_info->{denoised_image_id}, $drone_run_band_project_id, $user_id, $user_name, $user_role, $drone_run_band_info->{plot_polygons_value}, 'NDRE', 'NReN');
        }
    }
}

sub get_project_md_image : Path('/api/drone_imagery/get_project_md_image') : ActionClass('REST') { }
sub get_project_md_image_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $sp_person_id);
    my $drone_run_band_project_id = $c->req->param('drone_run_band_project_id');
    my $project_image_type_name = $c->req->param('project_image_type_name');

    my $project_image_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, $project_image_type_name, 'project_md_image')->cvterm_id();

    my $q = "SELECT project_md_image.image_id
        FROM project AS drone_run_band
        JOIN phenome.project_md_image AS project_md_image USING(project_id)
        WHERE project_md_image.type_id = $project_image_type_id AND project_id = $drone_run_band_project_id
        ORDER BY project_id;";

    my $h = $bcs_schema->storage->dbh()->prepare($q);
    $h->execute();
    my @result;
    while (my ($image_id) = $h->fetchrow_array()) {
        push @result, {
            image_id => $image_id
        };
    }

    $c->stash->{rest} = { data => \@result };
}

sub drone_imagery_get_image : Path('/api/drone_imagery/get_image') : ActionClass('REST') { }
sub drone_imagery_get_image_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $image_id = $c->req->param('image_id');
    my $size = $c->req->param('size') || 'original_converted';
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
    my $image_url = $image->get_image_url($size);
    my $image_fullpath = $image->get_filename('original_converted', 'full');
    my @size = imgsize($image_fullpath);

    my $images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        image_id_list=>[$image_id],
    });
    my ($result, $total_count) = $images_search->search();
    my $drone_run_band_project_id = $result->[0]->{drone_run_band_project_id};

    $c->stash->{rest} = { image_url => $image_url, image_fullpath => $image_fullpath, image_width => $size[0], image_height => $size[1], drone_run_band_project_id => $drone_run_band_project_id };
}

sub drone_imagery_remove_image : Path('/api/drone_imagery/remove_image') : ActionClass('REST') { }
sub drone_imagery_remove_image_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $image_id = $c->req->param('image_id');
    my ($user_id, $user_name, $user_role) = _check_user_login($c, 'curator');

    my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
    my $resp = $image->delete(); #Sets to obsolete

    $c->stash->{rest} = { status => $resp };
}

sub drone_imagery_crop_image : Path('/api/drone_imagery/crop_image') : ActionClass('REST') { }
sub drone_imagery_crop_image_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $sp_person_id);
    my $image_id = $c->req->param('image_id');
    my $drone_run_band_project_id = $c->req->param('drone_run_band_project_id');
    my $polygon = $c->req->param('polygon');
    my $polygon_obj = decode_json $polygon;
    if (scalar(@$polygon_obj) != 4){
        $c->stash->{rest} = {error=>'Polygon should be 4 long!'};
        $c->detach();
    }
    my $polygons = encode_json [$polygon_obj];
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $dir = $c->tempfiles_subdir('/drone_imagery_cropped_image');
    my $archive_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_cropped_image/imageXXXX');
    $archive_temp_image .= '.png';

    my $return = _perform_image_cropping($c, $schema, $drone_run_band_project_id, $image_id, $polygons, $user_id, $user_name, $user_role, $archive_temp_image, 1, 1);

    $c->stash->{rest} = $return;
}

sub _perform_image_cropping {
    my $c = shift;
    my $schema = shift;
    my $drone_run_band_project_id = shift;
    my $image_id = shift;
    my $polygons = shift;
    my $user_id = shift;
    my $user_name = shift;
    my $user_role = shift;
    my $archive_temp_image = shift;
    my $apply_image_width_ratio = shift;
    my $apply_image_height_ratio = shift;

    my $polygons_array = decode_json $polygons;
    my @polygons_rescaled = ();
    foreach my $p (@$polygons_array) {
        my @p_rescaled;
        foreach my $point (@$p) {
            my $x = $point->{x};
            my $y = $point->{y};
            push @p_rescaled, {x=>round($x/$apply_image_width_ratio), y=>round($y/$apply_image_height_ratio)};
        }
        push @polygons_rescaled, \@p_rescaled;
    }
    $polygons = encode_json \@polygons_rescaled;

    my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
    my $image_url = $image->get_image_url("original");
    my $image_fullpath = $image->get_filename('original_converted', 'full');

    my $cmd = $c->config->{python_executable}." ".$c->config->{rootpath}."/DroneImageScripts/ImageCropping/CropToPolygon.py --inputfile_path '$image_fullpath' --outputfile_path '$archive_temp_image' --polygon_json '$polygons' --polygon_type rectangular_square";
    print STDERR Dumper $cmd;
    my $status = system("$cmd > /dev/null");

    $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
    $image->set_sp_person_id($user_id);
    my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'cropped_stitched_drone_imagery', 'project_md_image')->cvterm_id();

    my $previous_cropped_images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        project_image_type_id=>$linking_table_type_id,
        drone_run_band_project_id_list=>[$drone_run_band_project_id]
    });
    my ($previous_result, $previous_total_count) = $previous_cropped_images_search->search();
    foreach (@$previous_result) {
        my $previous_image = SGN::Image->new( $schema->storage->dbh, $_->{image_id}, $c );
        $previous_image->delete(); #Sets to obsolete
    }

    my $ret = $image->process_image($archive_temp_image, 'project', $drone_run_band_project_id, $linking_table_type_id);
    my $cropped_image_fullpath = $image->get_filename('original_converted', 'full');
    my $cropped_image_url = $image->get_image_url('original');
    my $cropped_image_id = $image->get_image_id();

    my $drone_run_band_cropped_polygon_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_cropped_polygon', 'project_property')->cvterm_id();
    my $drone_run_band_cropped_polygon = $schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$drone_run_band_cropped_polygon_type_id,
        project_id=>$drone_run_band_project_id,
        rank=>0,
        value=>$polygons
    },
    {
        key=>'projectprop_c1'
    });

    unlink($archive_temp_image);
    return {
        cropped_image_id => $cropped_image_id, image_url => $image_url, image_fullpath => $image_fullpath, cropped_image_url => $cropped_image_url, cropped_image_fullpath => $cropped_image_fullpath
    };
}

sub drone_imagery_calculate_fourier_transform : Path('/api/drone_imagery/calculate_fourier_transform') : ActionClass('REST') { }
sub drone_imagery_calculate_fourier_transform_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $sp_person_id);
    my $image_id = $c->req->param('image_id');
    my $drone_run_band_project_id = $c->req->param('drone_run_band_project_id');
    my $drone_run_band_project_type = $c->req->param('drone_run_band_project_type');
    my $image_type = $c->req->param('image_type');
    my $high_pass_filter = $c->req->param('high_pass_filter');
    my $high_pass_filter_type = $c->req->param('high_pass_filter_type') || 'frequency';

    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $return = _perform_fourier_transform_calculation($c, $schema, $metadata_schema, $image_id, $drone_run_band_project_id, $image_type, $high_pass_filter, $high_pass_filter_type, $user_id, $user_name, $user_role);

    $c->stash->{rest} = $return;
}

sub _perform_fourier_transform_calculation {
    my $c = shift;
    my $schema = shift;
    my $metadata_schema = shift;
    my $image_id = shift;
    my $drone_run_band_project_id = shift;
    my $drone_run_band_project_type;
    my $image_type = shift;
    my $high_pass_filter = shift;
    my $high_pass_filter_type = shift;
    my $user_id = shift;
    my $user_name = shift;
    my $user_role = shift;
    print STDERR "FT Linking Table Type: $image_type\n";
    my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, $image_type, 'project_md_image')->cvterm_id();
    my $image_channel_lookup = CXGN::DroneImagery::ImageTypes::get_all_project_md_image_types_whole_images($schema)->{$linking_table_type_id}->{corresponding_channel};

    my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
    my $image_url = $image->get_image_url("original");
    my $image_fullpath = $image->get_filename('original_converted', 'full');

    my $dir = $c->tempfiles_subdir('/drone_imagery_fourier_transform_hpf_image');
    my $archive_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_fourier_transform_hpf_image/imageXXXX');
    $archive_temp_image .= '.png';

    my $cmd = $c->config->{python_executable}." ".$c->config->{rootpath}."/DroneImageScripts/ImageProcess/FourierTransform.py --image_path '$image_fullpath' --outfile_path '$archive_temp_image' --image_band_index ".$image_channel_lookup." --frequency_threshold $high_pass_filter --frequency_threshold_method $high_pass_filter_type";
    print STDERR Dumper $cmd;
    my $status = system("$cmd > /dev/null");

    my $ft_image_fullpath;
    my $ft_image_url;
    my $ft_image_id;
    $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
    my $md5checksum = $image->calculate_md5sum($archive_temp_image);
    my $q = "SELECT md_image.image_id FROM metadata.md_image AS md_image
        JOIN phenome.project_md_image AS project_md_image ON(project_md_image.image_id = md_image.image_id)
        WHERE md_image.obsolete = 'f' AND md_image.md5sum = ? AND project_md_image.type_id = ? AND project_md_image.project_id = ?;";
    my $h = $schema->storage->dbh->prepare($q);
    $h->execute($md5checksum, $linking_table_type_id, $drone_run_band_project_id);
    my ($saved_image_id) = $h->fetchrow_array();

    if ($saved_image_id) {
        print STDERR Dumper "Image $archive_temp_image has already been added to the database and will not be added again.";
        $image = SGN::Image->new( $schema->storage->dbh, $saved_image_id, $c );
        $ft_image_fullpath = $image->get_filename('original_converted', 'full');
        $ft_image_url = $image->get_image_url('original');
        $ft_image_id = $image->get_image_id();
    } else {
        my $previous_index_images_search = CXGN::DroneImagery::ImagesSearch->new({
            bcs_schema=>$schema,
            project_image_type_id=>$linking_table_type_id,
            drone_run_band_project_id_list=>[$drone_run_band_project_id]
        });
        my ($previous_result, $previous_total_count) = $previous_index_images_search->search();
        foreach (@$previous_result){
            my $previous_image = SGN::Image->new( $schema->storage->dbh, $_->{image_id}, $c );
            $previous_image->delete(); #Sets to obsolete
        }

        $image->set_sp_person_id($user_id);
        my $ret = $image->process_image($archive_temp_image, 'project', $drone_run_band_project_id, $linking_table_type_id);
        $ft_image_fullpath = $image->get_filename('original_converted', 'full');
        $ft_image_url = $image->get_image_url('original');
        $ft_image_id = $image->get_image_id();
    }

    unlink($archive_temp_image);
    return {
        image_url => $image_url, image_fullpath => $image_fullpath, ft_image_id => $ft_image_id, ft_image_url => $ft_image_url, ft_image_fullpath => $ft_image_fullpath
    };
}

sub drone_imagery_calculate_vegetative_index : Path('/api/drone_imagery/calculate_vegetative_index') : ActionClass('REST') { }
sub drone_imagery_calculate_vegetative_index_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $sp_person_id);
    my $image_id = $c->req->param('image_id');
    my $drone_run_band_project_id = $c->req->param('drone_run_band_project_id');
    my $vegetative_index = $c->req->param('vegetative_index');
    my $image_type = $c->req->param('image_type');
    my $view_only = $c->req->param('view_only');

    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $return = _perform_vegetative_index_calculation($c, $schema, $metadata_schema, $image_id, $drone_run_band_project_id, $vegetative_index, $view_only, $image_type, $user_id, $user_name, $user_role);

    $c->stash->{rest} = $return;
}

sub _perform_vegetative_index_calculation {
    my $c = shift;
    my $schema = shift;
    my $metadata_schema = shift;
    my $image_id = shift;
    my $drone_run_band_project_id = shift;
    my $vegetative_index = shift;
    my $view_only = shift;
    my $image_type = shift;
    my $user_id = shift;
    my $user_name = shift;
    my $user_role = shift;

    my $index_script = '';
    my $linking_table_type_id;
    if ($image_type eq 'BGR') {
        if ($vegetative_index eq 'TGI') {
            $index_script = 'TGI';
            if ($view_only == 1){
                $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_tgi_temporary_drone_imagery', 'project_md_image')->cvterm_id();
            } else {
                $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_tgi_drone_imagery', 'project_md_image')->cvterm_id();
            }
        }
        if ($vegetative_index eq 'VARI') {
            $index_script = 'VARI';
            if ($view_only == 1){
                $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_vari_temporary_drone_imagery', 'project_md_image')->cvterm_id();
            } else {
                $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_vari_drone_imagery', 'project_md_image')->cvterm_id();
            }
        }
    }
    elsif ($image_type eq 'NRN') {
        if ($vegetative_index eq 'NDVI') {
            $index_script = 'NDVI';
            if ($view_only == 1){
                $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_ndvi_temporary_drone_imagery', 'project_md_image')->cvterm_id();
            } else {
                $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_ndvi_drone_imagery', 'project_md_image')->cvterm_id();
            }
        }
    }
    elsif ($image_type eq 'NReN') {
        if ($vegetative_index eq 'NDRE') {
            $index_script = 'NDRE';
            if ($view_only == 1){
                $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_ndre_temporary_drone_imagery', 'project_md_image')->cvterm_id();
            } else {
                $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_ndre_drone_imagery', 'project_md_image')->cvterm_id();
            }
        }
    }
    if (!$linking_table_type_id) {
        die "Could not get vegetative index image type id\n";
    }

    my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
    my $image_url = $image->get_image_url("original");
    my $image_fullpath = $image->get_filename('original_converted', 'full');

    my $dir = $c->tempfiles_subdir('/drone_imagery_vegetative_index_image');
    my $archive_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_vegetative_index_image/imageXXXX');
    $archive_temp_image .= '.png';

    my $cmd = $c->config->{python_executable}." ".$c->config->{rootpath}."/DroneImageScripts/VegetativeIndex/$index_script.py --image_path '$image_fullpath' --outfile_path '$archive_temp_image'";
    print STDERR Dumper $cmd;
    my $status = system("$cmd > /dev/null");

    my $index_image_fullpath;
    my $index_image_url;
    my $index_image_id;
    $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
    my $md5checksum = $image->calculate_md5sum($archive_temp_image);
    my $q = "SELECT md_image.image_id FROM metadata.md_image AS md_image
        JOIN phenome.project_md_image AS project_md_image ON(project_md_image.image_id = md_image.image_id)
        WHERE md_image.obsolete = 'f' AND md_image.md5sum = ? AND project_md_image.type_id = ? AND project_md_image.project_id = ?;";
    my $h = $schema->storage->dbh->prepare($q);
    $h->execute($md5checksum, $linking_table_type_id, $drone_run_band_project_id);
    my ($saved_image_id) = $h->fetchrow_array();

    if ($view_only == 1 && $saved_image_id) {
        print STDERR Dumper "Image $archive_temp_image has already been added to the database and will not be added again.";
        $image = SGN::Image->new( $schema->storage->dbh, $saved_image_id, $c );
        $index_image_fullpath = $image->get_filename('original_converted', 'full');
        $index_image_url = $image->get_image_url('original');
        $index_image_id = $image->get_image_id();
    } else {
        my $previous_index_images_search = CXGN::DroneImagery::ImagesSearch->new({
            bcs_schema=>$schema,
            project_image_type_id=>$linking_table_type_id,
            drone_run_band_project_id_list=>[$drone_run_band_project_id]
        });
        my ($previous_result, $previous_total_count) = $previous_index_images_search->search();
        foreach (@$previous_result){
            my $previous_image = SGN::Image->new( $schema->storage->dbh, $_->{image_id}, $c );
            $previous_image->delete(); #Sets to obsolete
        }
        $image->set_sp_person_id($user_id);
        my $ret = $image->process_image($archive_temp_image, 'project', $drone_run_band_project_id, $linking_table_type_id);
        $index_image_fullpath = $image->get_filename('original_converted', 'full');
        $index_image_url = $image->get_image_url('original');
        $index_image_id = $image->get_image_id();
    }

    unlink($archive_temp_image);
    return {
        image_url => $image_url, image_fullpath => $image_fullpath, index_image_id => $index_image_id, index_image_url => $index_image_url, index_image_fullpath => $index_image_fullpath
    };
}

sub drone_imagery_mask_remove_background : Path('/api/drone_imagery/mask_remove_background') : ActionClass('REST') { }
sub drone_imagery_mask_remove_background_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $image_id = $c->req->param('image_id');
    my $mask_image_id = $c->req->param('mask_image_id');
    my $drone_run_band_project_id = $c->req->param('drone_run_band_project_id');
    my $mask_type = $c->req->param('mask_type');

    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $return = _perform_image_background_remove_mask($c, $schema, $image_id, $mask_image_id, $drone_run_band_project_id, $mask_type, $user_id, $user_name, $user_role);

    $c->stash->{rest} = $return;
}

sub _perform_image_background_remove_mask {
    my $c = shift;
    my $schema = shift;
    my $image_id = shift;
    my $mask_image_id = shift;
    my $drone_run_band_project_id = shift;
    my $mask_type = shift;
    my $user_id = shift;
    my $user_name = shift;
    my $user_role = shift;

    my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
    my $image_url = $image->get_image_url("original");
    my $image_fullpath = $image->get_filename('original_converted', 'full');

    my $mask_image = SGN::Image->new( $schema->storage->dbh, $mask_image_id, $c );
    my $mask_image_url = $mask_image->get_image_url("original");
    my $mask_image_fullpath = $mask_image->get_filename('original_converted', 'full');

    my $dir = $c->tempfiles_subdir('/drone_imagery_mask_remove_background');
    my $archive_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_mask_remove_background/imageXXXX');
    $archive_temp_image .= '.png';

    my $cmd = $c->config->{python_executable}." ".$c->config->{rootpath}."/DroneImageScripts/ImageProcess/MaskRemoveBackground.py --image_path '$image_fullpath' --mask_image_path '$mask_image_fullpath' --outfile_path '$archive_temp_image'";
    print STDERR Dumper $cmd;
    my $status = system("$cmd > /dev/null");

    $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
    $image->set_sp_person_id($user_id);

    my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, $mask_type, 'project_md_image')->cvterm_id();;

    my $previous_images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        project_image_type_id=>$linking_table_type_id,
        drone_run_band_project_id_list=>[$drone_run_band_project_id]
    });
    my ($previous_result, $previous_total_count) = $previous_images_search->search();
    foreach (@$previous_result){
        my $previous_image = SGN::Image->new( $schema->storage->dbh, $_->{image_id}, $c );
        $previous_image->delete(); #Sets to obsolete
    }

    my $ret = $image->process_image($archive_temp_image, 'project', $drone_run_band_project_id, $linking_table_type_id);
    my $masked_image_fullpath = $image->get_filename('original_converted', 'full');
    my $masked_image_url = $image->get_image_url('original');
    my $masked_image_id = $image->get_image_id();

    unlink($archive_temp_image);
    return {
        image_url => $image_url, image_fullpath => $image_fullpath, masked_image_id => $masked_image_id, masked_image_url => $masked_image_url, masked_image_fullpath => $masked_image_fullpath
    };
}

sub drone_imagery_get_plot_polygon_images : Path('/api/drone_imagery/get_plot_polygon_images') : ActionClass('REST') { }
sub drone_imagery_get_plot_polygon_images_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $drone_run_band_project_id = $c->req->param('drone_run_band_project_id');
    my $plot_polygons_type = $c->req->param('plot_polygons_type');
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $plot_polygons_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, $plot_polygons_type, 'project_md_image')->cvterm_id();
    my $images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        drone_run_band_project_id_list=>[$drone_run_band_project_id],
        project_image_type_id=>$plot_polygons_images_cvterm_id
    });
    my ($result, $total_count) = $images_search->search();
    #print STDERR Dumper $result;

    my @image_paths;
    my @image_urls;
    foreach (@$result) {
        my $image_id = $_->{image_id};
        my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
        my $image_url = $image->get_image_url("original");
        my $image_fullpath = $image->get_filename('original_converted', 'full');
        push @image_urls, $image_url;
        push @image_paths, $image_fullpath;
    }

    $c->stash->{rest} = { image_urls => \@image_urls };
}

sub drone_imagery_merge_bands : Path('/api/drone_imagery/merge_bands') : ActionClass('REST') { }
sub drone_imagery_merge_bands_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $sp_person_id);
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $drone_run_project_id = $c->req->param('drone_run_project_id');
    my $drone_run_project_name = $c->req->param('drone_run_project_name');
    my $band_1_drone_run_band_project_id = $c->req->param('band_1_drone_run_band_project_id');
    my $band_2_drone_run_band_project_id = $c->req->param('band_2_drone_run_band_project_id');
    my $band_3_drone_run_band_project_id = $c->req->param('band_3_drone_run_band_project_id');
    my $merged_image_type = $c->req->param('merged_image_type');

    my $return = _perform_image_merge($c, $schema, $metadata_schema, $drone_run_project_id, $drone_run_project_name, $band_1_drone_run_band_project_id, $band_2_drone_run_band_project_id, $band_3_drone_run_band_project_id, $merged_image_type, $user_id, $user_name, $user_role);

    $c->stash->{rest} = $return;
}

sub _perform_image_merge {
    my $c = shift;
    my $schema = shift;
    my $metadata_schema = shift;
    my $drone_run_project_id = shift;
    my $drone_run_project_name = shift;
    my $band_1_drone_run_band_project_id = shift;
    my $band_2_drone_run_band_project_id = shift;
    my $band_3_drone_run_band_project_id = shift;
    my $merged_image_type = shift;
    my $user_id = shift;
    my $user_name = shift;
    my $user_role = shift;

    if (!$band_1_drone_run_band_project_id || !$band_2_drone_run_band_project_id || !$band_3_drone_run_band_project_id) {
        $c->stash->{rest} = { error => 'Please select 3 drone run bands' };
        $c->detach();
    }
    my @drone_run_bands = ($band_1_drone_run_band_project_id, $band_2_drone_run_band_project_id, $band_3_drone_run_band_project_id);

    my $project_image_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        project_image_type_id=>$project_image_type_id,
        drone_run_band_project_id_list=>\@drone_run_bands,
    });
    my ($result, $total_count) = $images_search->search();
    #print STDERR Dumper $result;

    my %drone_run_bands_images;
    foreach (@$result) {
        $drone_run_bands_images{$_->{drone_run_band_project_id}} = $_->{image_id};
    }
    #print STDERR Dumper \%drone_run_bands_images;

    my @image_filesnames;
    foreach (@drone_run_bands) {
        my $image = SGN::Image->new( $schema->storage->dbh, $drone_run_bands_images{$_}, $c );
        my $image_url = $image->get_image_url("original");
        my $image_fullpath = $image->get_filename('original_converted', 'full');
        push @image_filesnames, $image_fullpath;
    }

    my $dir = $c->tempfiles_subdir('/drone_imagery_merge_bands');
    my $archive_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_merge_bands/imageXXXX');
    $archive_temp_image .= '.png';

    my $cmd = $c->config->{python_executable}." ".$c->config->{rootpath}."/DroneImageScripts/ImageProcess/MergeChannels.py --image_path_band_1 '".$image_filesnames[0]."' --image_path_band_2 '".$image_filesnames[1]."' --image_path_band_3 '".$image_filesnames[2]."' --outfile_path '$archive_temp_image'";
    print STDERR Dumper $cmd;
    my $status = system("$cmd > /dev/null");

    my $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
    $image->set_sp_person_id($user_id);

    my $drone_run_band_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_project_type', 'project_property')->cvterm_id();
    my $design_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'design', 'project_property')->cvterm_id();
    my $project_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_on_drone_run', 'project_relationship')->cvterm_id();

    my $band_1_drone_run_band_project_type = $schema->resultset("Project::Projectprop")->search({project_id => $band_1_drone_run_band_project_id, type_id => $drone_run_band_type_cvterm_id})->first->value;
    my $band_2_drone_run_band_project_type = $schema->resultset("Project::Projectprop")->search({project_id => $band_2_drone_run_band_project_id, type_id => $drone_run_band_type_cvterm_id})->first->value;
    my $band_3_drone_run_band_project_type = $schema->resultset("Project::Projectprop")->search({project_id => $band_3_drone_run_band_project_id, type_id => $drone_run_band_type_cvterm_id})->first->value;

    my $merged_drone_run_band_id;
    my $project_rs_check = $schema->resultset("Project::Project")->find({
        name => "$drone_run_project_name Merged:$band_1_drone_run_band_project_type (project_id:$band_1_drone_run_band_project_id),$band_2_drone_run_band_project_type (project_id:$band_2_drone_run_band_project_id),$band_3_drone_run_band_project_type (project_id:$band_3_drone_run_band_project_id)"
    });
    if ($project_rs_check) {
        $merged_drone_run_band_id = $project_rs_check->project_id;
    } else {
        my $project_rs = $schema->resultset("Project::Project")->create({
            name => "$drone_run_project_name Merged:$band_1_drone_run_band_project_type (project_id:$band_1_drone_run_band_project_id),$band_2_drone_run_band_project_type (project_id:$band_2_drone_run_band_project_id),$band_3_drone_run_band_project_type (project_id:$band_3_drone_run_band_project_id)",
            description => "Merged $band_1_drone_run_band_project_type (project_id:$band_1_drone_run_band_project_id),$band_2_drone_run_band_project_type (project_id:$band_2_drone_run_band_project_id),$band_3_drone_run_band_project_type (project_id:$band_3_drone_run_band_project_id)",
            projectprops => [{type_id => $drone_run_band_type_cvterm_id, value => 'Merged 3 Bands '.$merged_image_type}, {type_id => $design_cvterm_id, value => 'drone_run_band'}],
            project_relationship_subject_projects => [{type_id => $project_relationship_type_id, object_project_id => $drone_run_project_id}]
        });
        $merged_drone_run_band_id = $project_rs->project_id();
    }

    my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $ret = $image->process_image($archive_temp_image, 'project', $merged_drone_run_band_id, $linking_table_type_id);
    my $merged_image_fullpath = $image->get_filename('original_converted', 'full');
    my $merged_image_url = $image->get_image_url('original');
    my $merged_image_id = $image->get_image_id();

    unlink($archive_temp_image);
    return {
        merged_drone_run_band_project_id => $merged_drone_run_band_id, merged_image_url => $merged_image_url, merged_image_fullpath => $merged_image_fullpath, merged_image_id => $merged_image_id
    };
}

sub _perform_phenotype_automated {
    my $c = shift;
    my $schema = shift;
    my $metadata_schema = shift;
    my $phenome_schema = shift;
    my $drone_run_project_id = shift;
    my $time_cvterm_id = shift;
    my $phenotype_types = shift;
    my $standard_process_type = shift;
    my $ignore_new_phenotype_values = shift;
    my $overwrite_phenotype_values = shift;
    my $user_id = shift;
    my $user_name = shift;
    my $user_role = shift;

    my $number_system_cores = `getconf _NPROCESSORS_ONLN` or die "Could not get number of system cores!\n";
    chomp($number_system_cores);
    print STDERR "NUMCORES $number_system_cores\n";

    my @allowed_composed_cvs = split ',', $c->config->{composable_cvs};
    my $composable_cvterm_delimiter = $c->config->{composable_cvterm_delimiter};
    my $composable_cvterm_format = $c->config->{composable_cvterm_format};

    my $drone_run_phenotype_calc_progress_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_standard_process_phenotype_calculation_in_progress', 'project_property')->cvterm_id();
    my $drone_run_phenotype_calc_progress = $schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$drone_run_phenotype_calc_progress_type_id,
        project_id=>$drone_run_project_id,
        rank=>0,
        value=>1
    },
    {
        key=>'projectprop_c1'
    });

    my $in_progress_indicator = 1;
    while ($in_progress_indicator == 1) {
        sleep(30);
        print STDERR "Waiting for drone standard image process to finish before calculating phenotypes\n";
        my $process_indicator_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_standard_process_in_progress', 'project_property')->cvterm_id();
        my $drone_run_band_remove_background_threshold_rs = $schema->resultset('Project::Projectprop')->search({
            type_id=>$process_indicator_cvterm_id,
            project_id=>$drone_run_project_id,
        });
        $in_progress_indicator = $drone_run_band_remove_background_threshold_rs->first ? $drone_run_band_remove_background_threshold_rs->first->value() : 0;
    }

    my $project_image_type_id_map = CXGN::DroneImagery::ImageTypes::get_all_project_md_image_observation_unit_plot_polygon_types($schema);
    my %project_observation_unit_plot_polygons_types;
    while (my ($k, $v) = each %$project_image_type_id_map) {
        foreach my $p (@{$v->{drone_run_project_types}}) {
            if (!$p) {
                die "No project for ".$v->{name}."\n";
            }
            foreach my $t (@{$v->{standard_process}}) {
                if (!$t) {
                    die "No standard process type for ".$v->{name}."\n";
                }
                push @{$project_observation_unit_plot_polygons_types{$p}->{$t}}, $v->{name};
            }
        }
    }

    my $drone_run_band_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_on_drone_run', 'project_relationship')->cvterm_id();
    my $drone_run_band_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_project_type', 'project_property')->cvterm_id();
    my $q = "SELECT drone_run_band.project_id, drone_run_band.name, drone_run_band_project_type.value
        FROM project AS drone_run_band
        JOIN projectprop AS drone_run_band_project_type ON (drone_run_band_project_type.project_id=drone_run_band.project_id AND drone_run_band_project_type.type_id=$drone_run_band_type_cvterm_id)
        JOIN project_relationship AS drone_run_band_rel ON(drone_run_band.project_id=drone_run_band_rel.subject_project_id AND drone_run_band_rel.type_id=$drone_run_band_relationship_type_id)
        JOIN project ON (drone_run_band_rel.object_project_id = project.project_id)
        WHERE project.project_id = ?;";

    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute($drone_run_project_id);

    my @result;
    while (my ($drone_run_band_project_id, $drone_run_band_name, $drone_run_band_project_type) = $h->fetchrow_array()) {
        print STDERR Dumper [$drone_run_band_name, $drone_run_band_project_type];
        foreach my $phenotype_method (@$phenotype_types) {
            #my $pm = Parallel::ForkManager->new(floor(int($number_system_cores)*0.5));
            foreach my $plot_polygon_type (@{$project_observation_unit_plot_polygons_types{$drone_run_band_project_type}->{$standard_process_type}}) {
                #my $pid = $pm->start and next;
                my $return = _perform_phenotype_calculation($c, $schema, $metadata_schema, $phenome_schema, $drone_run_band_project_id, $drone_run_band_project_type, $phenotype_method, $time_cvterm_id, $plot_polygon_type, $user_id, $user_name, $user_role, \@allowed_composed_cvs, $composable_cvterm_delimiter, $composable_cvterm_format, 1, $ignore_new_phenotype_values, $overwrite_phenotype_values);
                if ($return->{error}){
                    print STDERR Dumper $return->{error};
                }
                #$pm->finish();
            }
            #$pm->wait_all_children;
        }
    }

    my $bs = CXGN::BreederSearch->new( { dbh=>$c->dbc->dbh, dbname=>$c->config->{dbname}, } );
    my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'fullview', 'nonconcurrent', $c->config->{basepath});

    $drone_run_phenotype_calc_progress = $schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$drone_run_phenotype_calc_progress_type_id,
        project_id=>$drone_run_project_id,
        rank=>0,
        value=>0
    },
    {
        key=>'projectprop_c1'
    });

    return {
        success => 1
    };
}

sub drone_imagery_get_drone_run_image_counts : Path('/api/drone_imagery/get_drone_run_image_counts') : ActionClass('REST') { }
sub drone_imagery_get_drone_run_image_counts_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $sp_person_id);
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema", undef, $sp_person_id);
    my $drone_run_id = $c->req->param('drone_run_id');
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $plot_polygon_types = CXGN::DroneImagery::ImageTypes::get_all_project_md_image_observation_unit_plot_polygon_types($schema);
    my @plot_polygon_minimal_cvterm_ids;
    while (my ($plot_polygon_type_cvterm_id, $plot_polygon_type) = each %$plot_polygon_types) {
        my $processes = $plot_polygon_type->{standard_process};
        foreach (@$processes) {
            if ($_ eq 'minimal') {
                push @plot_polygon_minimal_cvterm_ids, $plot_polygon_type_cvterm_id;
            }
        }
    }

    my $plot_number_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot number', 'stock_property')->cvterm_id();
    my $q = "SELECT value FROM stockprop WHERE stock_id=? and type_id=$plot_number_cvterm_id;";
    my $h = $schema->storage->dbh()->prepare($q);

    my %plot_image_counts;
    my %plot_numbers;
    foreach my $plot_polygons_images_cvterm_id (@plot_polygon_minimal_cvterm_ids) {
        my $images_search = CXGN::DroneImagery::ImagesSearch->new({
            bcs_schema=>$schema,
            drone_run_project_id_list=>[$drone_run_id],
            project_image_type_id=>$plot_polygons_images_cvterm_id
        });
        my ($result, $total_count) = $images_search->search();
        foreach (@$result) {
            my $plot_id = $_->{stock_id};
            my $plot_name = $_->{stock_uniquename};
            $plot_image_counts{$plot_name}->{$_->{project_image_type_name}}++;
            $h->execute($plot_id);
            my ($plot_number) = $h->fetchrow_array();
            $plot_numbers{$plot_name} = $plot_number;
        }
    }

    my @return;
    while (my ($stock_name, $obj) = each %plot_image_counts) {
        my $image_counts_string = '';
        while (my ($image_type, $count) = each %$obj) {
            $image_counts_string .= "$image_type: $count<br/>";
        }
        push @return, {plot_name => $stock_name, plot_number => $plot_numbers{$stock_name}, image_counts => $image_counts_string};
    }

    $c->stash->{rest} = {data => \@return};
}

sub drone_imagery_update_details : Path('/api/drone_imagery/update_details') : ActionClass('REST') { }
sub drone_imagery_update_details_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $sp_person_id);
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema", undef, $sp_person_id);
    my $drone_run_project_id = $c->req->param('drone_run_project_id');
    my $drone_run_date = $c->req->param('drone_run_date');
    my $description = $c->req->param('description');
    my $drone_run_name = $c->req->param('drone_run_name');
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $trial = CXGN::Trial->new({bcs_schema=>$schema, trial_id=>$drone_run_project_id});

    if ($drone_run_date) {
        $trial->set_drone_run_date($drone_run_date);
    }
    if ($description) {
        $trial->set_description($description);
    }
    if ($drone_run_name) {
        $trial->set_name($drone_run_name);
    }

    $c->stash->{rest} = {success => 1};
}

sub drone_imagery_quality_control_get_images : Path('/api/drone_imagery/quality_control_get_images') : ActionClass('REST') { }
sub drone_imagery_quality_control_get_images_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $sp_person_id);
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema", undef, $sp_person_id);
    my $drone_run_project_id = $c->req->param('drone_run_project_id');

    my $images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        drone_run_project_id_list=>[$drone_run_project_id]
    });
    my ($result, $total_count) = $images_search->search();
    # print STDERR Dumper $total_count;

    my %stock_images;
    foreach (@$result) {
        my $image_id = $_->{image_id};
        my $stock_id = $_->{stock_id};
        my $stock_uniquename = $_->{stock_uniquename};

        if ($stock_uniquename) {
            my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
            my $image_url = $image->get_image_url("original");
            my $image_fullpath = $image->get_filename('original_converted', 'full');
            my $image_source_tag_small = $image->get_img_src_tag("thumbnail");

            push @{$stock_images{$stock_uniquename}}, {
                stock_id => $stock_id,
                stock_uniquename => $_->{stock_uniquename},
                stock_type_id => $_->{stock_type_id},
                image => '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_small.'</a>',
                image_id => $image_id,
                project_image_type_name => $_->{project_image_type_name}
            };
        }
    }
    my @result;
    foreach (sort keys %stock_images) {
        my $i = $stock_images{$_};
        my $image_string = '';
        my $counter = 0;
        foreach my $j (@$i) {
            if ($counter == 0) {
                $image_string .= '<div class="row">';
            }
            $image_string .= '<div class="col-sm-2"><div class="well well-sm>"><span title="'.$j->{project_image_type_name}.'">'.$j->{image}."</span><input type='checkbox' name='manage_drone_imagery_quality_control_image_select' value='".$j->{image_id}."'></div></div>";
            if ($counter == 5) {
                $image_string .= '</div>';
                $counter = 0;
            } else {
                $counter++;
            }
        }
        push @result, [$_, $image_string];
    }

    $c->stash->{rest} = {success => 1, result => \@result};
}

sub drone_imagery_get_image_for_saving_gcp : Path('/api/drone_imagery/get_image_for_saving_gcp') : ActionClass('REST') { }
sub drone_imagery_get_image_for_saving_gcp_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $sp_person_id);
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema", undef, $sp_person_id);
    my $drone_run_project_id = $c->req->param('drone_run_project_id');
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $image_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'denoised_stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        drone_run_project_id_list=>[$drone_run_project_id],
        project_image_type_id_list => [$image_type_id]
    });
    my ($result, $total_count) = $images_search->search();
    # print STDERR Dumper $result;

    my @image_ids;
    my @image_types;
    foreach (@$result) {
        push @image_ids, $_->{image_id};
        push @image_types, $_->{drone_run_band_project_type};
    }

    my $gcps_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_ground_control_points', 'project_property')->cvterm_id();
    my $saved_gcps_json = $schema->resultset("Project::Projectprop")->find({
        project_id => $drone_run_project_id,
        type_id => $gcps_type_id
    });
    my $saved_gcps_full = {};
    if ($saved_gcps_json) {
        $saved_gcps_full = decode_json $saved_gcps_json->value();
    }

    my @saved_gcps_array = values %$saved_gcps_full;

    $c->stash->{rest} = {success => 1, result => $result, image_ids => \@image_ids, image_types => \@image_types, saved_gcps_full => $saved_gcps_full, gcps_array => \@saved_gcps_array};
}

sub drone_imagery_get_image_for_time_series : Path('/api/drone_imagery/get_image_for_time_series') : ActionClass('REST') { }
sub drone_imagery_get_image_for_time_series_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $sp_person_id);
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema", undef, $sp_person_id);
    my $field_trial_id = $c->req->param('field_trial_id');
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    if (!$field_trial_id) {
        $c->stash->{rest} = {error => "No field trial id given!" };
        $c->detach();
    }

    my $image_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'denoised_stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $tgi_image_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_tgi_drone_imagery', 'project_md_image')->cvterm_id();
    my $vari_image_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_vari_drone_imagery', 'project_md_image')->cvterm_id();
    my $ndvi_image_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_ndvi_drone_imagery', 'project_md_image')->cvterm_id();
    my $ndre_image_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_ndre_drone_imagery', 'project_md_image')->cvterm_id();
    my $images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        trial_id_list=>[$field_trial_id],
        project_image_type_id_list => [$image_type_id, $tgi_image_type_id, $vari_image_type_id, $ndvi_image_type_id, $ndre_image_type_id]
    });
    my ($result, $total_count) = $images_search->search();
    # print STDERR Dumper $result;

    my $calendar_funcs = CXGN::Calendar->new({});

    my %image_type_map = (
        "denoised_stitched_drone_imagery" => "",
        "calculate_tgi_drone_imagery" => " (TGI)",
        "calculate_vari_drone_imagery" => " (VARI)",
        "calculate_ndvi_drone_imagery" => " (NDVI)",
        "calculate_ndre_drone_imagery" => " (NDRE)"
    );

    my %image_ids;
    my %seen_epoch_seconds;
    my %seen_image_types;
    my %time_lookup;
    foreach (@$result) {
        # print STDERR Dumper $_;
        if ($_->{drone_run_band_plot_polygons}) {
            my $image_type = $_->{drone_run_band_project_type}.$image_type_map{$_->{project_image_type_name}};
            my $drone_run_date = $calendar_funcs->display_start_date($_->{drone_run_date});
            my $drone_run_date_object = Time::Piece->strptime($drone_run_date, "%Y-%B-%d %H:%M:%S");
            my $epoch_seconds = $drone_run_date_object->epoch;
            $time_lookup{$epoch_seconds} = $drone_run_date;
            $seen_epoch_seconds{$epoch_seconds}++;
            $seen_image_types{$image_type}++;
            $image_ids{$epoch_seconds}->{$image_type} = {
                image_id => $_->{image_id},
                drone_run_band_project_type => $image_type,
                drone_run_project_id => $_->{drone_run_project_id},
                drone_run_project_name => $_->{drone_run_project_name},
                plot_polygons => $_->{drone_run_band_plot_polygons},
                date => $drone_run_date
            };
        }
    }
    my @sorted_epoch_seconds = sort keys %seen_epoch_seconds;
    my @sorted_image_types = sort keys %seen_image_types;
    my @sorted_dates;
    foreach (@sorted_epoch_seconds) {
        push @sorted_dates, $time_lookup{$_};
    }

    my $field_layout = CXGN::Trial->new({bcs_schema => $schema, trial_id => $field_trial_id})->get_layout->get_design;
    my %plot_layout;
    while (my ($k, $v) = each %$field_layout) {
        $plot_layout{$v->{plot_name}} = $v;
    }

    $c->stash->{rest} = {
        success => 1,
        image_ids_hash => \%image_ids,
        sorted_times => \@sorted_epoch_seconds,
        sorted_image_types => \@sorted_image_types,
        sorted_dates => \@sorted_dates,
        field_layout => \%plot_layout
    };
}

sub drone_imagery_saving_gcp : Path('/api/drone_imagery/saving_gcp') : ActionClass('REST') { }
sub drone_imagery_saving_gcp_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $sp_person_id);
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema", undef, $sp_person_id);
    my $drone_run_project_id = $c->req->param('drone_run_project_id');
    my $gcp_name = $c->req->param('name');
    my $gcp_x_pos = $c->req->param('x_pos');
    my $gcp_y_pos = $c->req->param('y_pos');
    my $gcp_latitude = $c->req->param('latitude');
    my $gcp_longitude = $c->req->param('longitude');
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $gcps_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_ground_control_points', 'project_property')->cvterm_id();
    my $saved_gcps_json = $schema->resultset("Project::Projectprop")->find({
        project_id => $drone_run_project_id,
        type_id => $gcps_type_id
    });
    my $saved_gcps_full = {};
    if ($saved_gcps_json) {
        $saved_gcps_full = decode_json $saved_gcps_json->value();
    }

    $saved_gcps_full->{$gcp_name} = {
        name => $gcp_name,
        x_pos => $gcp_x_pos,
        y_pos => $gcp_y_pos,
        latitude => $gcp_latitude,
        longitude => $gcp_longitude
    };

    my $saved_gcps_update = $schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$gcps_type_id,
        project_id=>$drone_run_project_id,
        rank=>0,
        value=>encode_json $saved_gcps_full
    },
    {
        key=>'projectprop_c1'
    });

    my @saved_gcps_array = sort values %$saved_gcps_full;

    $c->stash->{rest} = {success => 1, saved_gcps_full => $saved_gcps_full, gcps_array => \@saved_gcps_array};
}

sub drone_imagery_remove_one_gcp : Path('/api/drone_imagery/remove_one_gcp') : ActionClass('REST') { }
sub drone_imagery_remove_one_gcp_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $sp_person_id);
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema", undef, $sp_person_id);
    my $drone_run_project_id = $c->req->param('drone_run_project_id');
    my $gcp_name = $c->req->param('name');
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $gcps_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_ground_control_points', 'project_property')->cvterm_id();
    my $saved_gcps_json = $schema->resultset("Project::Projectprop")->find({
        project_id => $drone_run_project_id,
        type_id => $gcps_type_id
    });
    my $saved_gcps_full = {};
    if ($saved_gcps_json) {
        $saved_gcps_full = decode_json $saved_gcps_json->value();
    }

    delete $saved_gcps_full->{$gcp_name};

    my $saved_gcps_update = $schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$gcps_type_id,
        project_id=>$drone_run_project_id,
        rank=>0,
        value=>encode_json $saved_gcps_full
    },
    {
        key=>'projectprop_c1'
    });

    my @saved_gcps_array = values %$saved_gcps_full;

    $c->stash->{rest} = {success => 1, saved_gcps_full => $saved_gcps_full, gcps_array => \@saved_gcps_array};
}

sub drone_imagery_obsolete_image_change : Path('/api/drone_imagery/obsolete_image_change') : ActionClass('REST') { }
sub drone_imagery_obsolete_image_change_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $sp_person_id);
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema", undef, $sp_person_id);
    my $image_id = $c->req->param('image_id');
    my ($user_id, $user_name, $user_role) = _check_user_login($c, 'curator');

    my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
    $image->delete(); #makes obsolete

    $c->stash->{rest} = {success => 1};
}

sub drone_imagery_calculate_phenotypes : Path('/api/drone_imagery/calculate_phenotypes') : ActionClass('REST') { }
sub drone_imagery_calculate_phenotypes_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $sp_person_id);
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema", undef, $sp_person_id);
    my $drone_run_band_project_id = $c->req->param('drone_run_band_project_id');
    my $drone_run_band_project_type = $c->req->param('drone_run_band_project_type');
    my $phenotype_method = $c->req->param('method');
    my $time_cvterm_id = $c->req->param('time_cvterm_id');
    my $plot_polygons_type = $c->req->param('plot_polygons_type');
    my @allowed_composed_cvs = split ',', $c->config->{composable_cvs};
    my $composable_cvterm_delimiter = $c->config->{composable_cvterm_delimiter};
    my $composable_cvterm_format = $c->config->{composable_cvterm_format};
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $return = _perform_phenotype_calculation($c, $schema, $metadata_schema, $phenome_schema, $drone_run_band_project_id, $drone_run_band_project_type, $phenotype_method, $time_cvterm_id, $plot_polygons_type, $user_id, $user_name, $user_role, \@allowed_composed_cvs, $composable_cvterm_delimiter, $composable_cvterm_format, undef, undef, 1);

    $c->stash->{rest} = $return;
}

sub drone_imagery_generate_phenotypes : Path('/api/drone_imagery/generate_phenotypes') : ActionClass('REST') { }
sub drone_imagery_generate_phenotypes_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $sp_person_id);
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema", undef, $sp_person_id);
    my $drone_run_project_id = $c->req->param('drone_run_project_id');
    my $time_cvterm_id = $c->req->param('time_cvterm_id');
    my $phenotype_methods = $c->req->param('phenotype_types') ? decode_json $c->req->param('phenotype_types') : ['zonal'];
    my $standard_process_type = $c->req->param('standard_process_type');
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my @standard_processes = split ',', $standard_process_type;
    my $return;
    foreach my $standard_process_type (@standard_processes) {
        $return = _perform_phenotype_automated($c, $schema, $metadata_schema, $phenome_schema, $drone_run_project_id, $time_cvterm_id, $phenotype_methods, $standard_process_type, undef, 1, $user_id, $user_name, $user_role);
    }

    $c->stash->{rest} = $return;
}

sub _perform_phenotype_calculation {
    my $c = shift;
    my $schema = shift;
    my $metadata_schema = shift;
    my $phenome_schema = shift;
    my $drone_run_band_project_id = shift;
    my $drone_run_band_project_type = shift;
    my $phenotype_method = shift;
    my $time_cvterm_id = shift;
    my $plot_polygons_type = shift;
    my $user_id = shift;
    my $user_name = shift;
    my $user_role = shift;
    my $allowed_composed_cvs = shift;
    my $composable_cvterm_delimiter = shift;
    my $composable_cvterm_format = shift;
    my $do_not_run_materialized_view_refresh = shift;
    my $ignore_new_phenotype_values = shift;
    my $overwrite_phenotype_values = shift;

    print STDERR Dumper [$drone_run_band_project_id, $drone_run_band_project_type, $phenotype_method, $time_cvterm_id, $plot_polygons_type];

    my $non_zero_pixel_count_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Nonzero Pixel Count|G2F:0000014')->cvterm_id;
    my $total_pixel_sum_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Total Pixel Sum|G2F:0000015')->cvterm_id;
    my $mean_pixel_value_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Mean Pixel Value|G2F:0000016')->cvterm_id;
    my $harmonic_mean_pixel_value_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Harmonic Mean Pixel Value|G2F:0000017')->cvterm_id;
    my $median_pixel_value_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Median Pixel Value|G2F:0000018')->cvterm_id;
    my $pixel_variance_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Pixel Variance|G2F:0000019')->cvterm_id;
    my $pixel_standard_dev_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Pixel Standard Deviation|G2F:0000020')->cvterm_id;
    my $pixel_pstandard_dev_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Pixel Population Standard Deviation|G2F:0000021')->cvterm_id;
    my $minimum_pixel_value_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Minimum Pixel Value|G2F:0000022')->cvterm_id;
    my $maximum_pixel_value_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Maximum Pixel Value|G2F:0000023')->cvterm_id;
    my $minority_pixel_value_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Minority Pixel Value|G2F:0000024')->cvterm_id;
    my $minority_pixel_count_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Minority Pixel Count|G2F:0000025')->cvterm_id;
    my $majority_pixel_value_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Majority Pixel Value|G2F:0000026')->cvterm_id;
    my $majority_pixel_count_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Majority Pixel Count|G2F:0000027')->cvterm_id;
    my $pixel_group_count_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Pixel Group Count|G2F:0000028')->cvterm_id;

    my $drone_run_band_project_type_cvterm_id;
    if ($drone_run_band_project_type eq 'Black and White Image') {
        $drone_run_band_project_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Black and White Image|ISOL:0000003')->cvterm_id;
    }
    elsif ($drone_run_band_project_type eq 'Blue (450-520nm)') {
        $drone_run_band_project_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Blue (450-520nm)|ISOL:0000004')->cvterm_id;
    }
    elsif ($drone_run_band_project_type eq 'Green (515-600nm)') {
        $drone_run_band_project_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Green (515-600nm)|ISOL:0000005')->cvterm_id;
    }
    elsif ($drone_run_band_project_type eq 'Red (600-690nm)') {
        $drone_run_band_project_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Red (600-690nm)|ISOL:0000006')->cvterm_id;
    }
    elsif ($drone_run_band_project_type eq 'Red Edge (690-750nm)') {
        $drone_run_band_project_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Red Edge (690-750nm)|ISOL:0000007')->cvterm_id;
    }
    elsif ($drone_run_band_project_type eq 'NIR (780-3000nm)') {
        $drone_run_band_project_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'NIR (780-3000nm)|ISOL:0000008')->cvterm_id;
    }
    elsif ($drone_run_band_project_type eq 'MIR (3000-50000nm)') {
        $drone_run_band_project_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'MIR (3000-50000nm)|ISOL:0000009')->cvterm_id;
    }
    elsif ($drone_run_band_project_type eq 'FIR (50000-1000000nm)') {
        $drone_run_band_project_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'FIR (50000-1000000nm)|ISOL:0000010')->cvterm_id;
    }
    elsif ($drone_run_band_project_type eq 'Thermal IR (9000-14000nm)') {
        $drone_run_band_project_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Thermal IR (9000-14000nm)|ISOL:0000011')->cvterm_id;
    }
    elsif ($drone_run_band_project_type eq 'Raster DSM') {
        $drone_run_band_project_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Raster DSM|ISOL:0000323')->cvterm_id;
    }
    elsif ($drone_run_band_project_type eq 'RGB Color Image') {
        $drone_run_band_project_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'RGB Color Image|ISOL:0000002')->cvterm_id;
    }
    elsif ($drone_run_band_project_type eq 'Merged 3 Bands BGR') {
        $drone_run_band_project_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Merged 3 Bands BGR|ISOL:0000012')->cvterm_id;
    }
    elsif ($drone_run_band_project_type eq 'Merged 3 Bands NRN') {
        $drone_run_band_project_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Merged 3 Bands NRN|ISOL:0000013')->cvterm_id;
    }
    elsif ($drone_run_band_project_type eq 'Merged 3 Bands NReN') {
        $drone_run_band_project_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Merged 3 Bands NReN|ISOL:0000014')->cvterm_id;
    }

    if (!$drone_run_band_project_type_cvterm_id) {
        die "No drone run band project type term found: $drone_run_band_project_type\n";
    }

    my $observation_unit_plot_polygon_types = CXGN::DroneImagery::ImageTypes::get_all_project_md_image_observation_unit_plot_polygon_types($schema);
    my %isol_terms_map;
    while (my($k, $v) = each %$observation_unit_plot_polygon_types) {
        $isol_terms_map{$v->{name}} = {
            ISOL_name => $v->{ISOL_name},
            corresponding_channel => $v->{corresponding_channel},
            channels => $v->{channels}
        };
    }
    my $drone_run_band_plot_polygons_preprocess_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, $isol_terms_map{$plot_polygons_type}->{ISOL_name})->cvterm_id;;
    if (!$drone_run_band_plot_polygons_preprocess_cvterm_id) {
        die "Could not get preprocess cvterm for $plot_polygons_type\n";
    }

    my $image_band_selected = $isol_terms_map{$plot_polygons_type}->{corresponding_channel};
    if (!defined($image_band_selected) && $phenotype_method eq 'zonal') {
        return {error => "No corresponding image band for this type $plot_polygons_type!"};
    }

    my $plot_polygons_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, $plot_polygons_type, 'project_md_image')->cvterm_id();
    my $images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        drone_run_band_project_id_list=>[$drone_run_band_project_id],
        project_image_type_id=>$plot_polygons_images_cvterm_id
    });
    my ($result, $total_count) = $images_search->search();
    print STDERR Dumper $total_count;

    my @header_cols;
    my @stocks;
    if ($total_count == 0) {
        return {error => "No plot polygon images for this type $plot_polygons_type!"};
    } else {

        my $traits = SGN::Model::Cvterm->get_traits_from_component_categories($schema, $allowed_composed_cvs, $composable_cvterm_delimiter, $composable_cvterm_format, {
            object => [],
            attribute => [$drone_run_band_project_type_cvterm_id],
            method => [],
            unit => [],
            trait => [$non_zero_pixel_count_cvterm_id, $total_pixel_sum_cvterm_id, $mean_pixel_value_cvterm_id, $harmonic_mean_pixel_value_cvterm_id, $median_pixel_value_cvterm_id, $pixel_variance_cvterm_id, $pixel_standard_dev_cvterm_id, $pixel_pstandard_dev_cvterm_id, $minimum_pixel_value_cvterm_id, $maximum_pixel_value_cvterm_id, $minority_pixel_value_cvterm_id, $minority_pixel_count_cvterm_id, $majority_pixel_value_cvterm_id, $majority_pixel_count_cvterm_id, $pixel_group_count_cvterm_id],
            tod => [$drone_run_band_plot_polygons_preprocess_cvterm_id],
            toy => [$time_cvterm_id],
            gen => [],
        });
        my $existing_traits = $traits->{existing_traits};
        my $new_traits = $traits->{new_traits};
        #print STDERR Dumper $new_traits;
        #print STDERR Dumper $existing_traits;
        my %new_trait_names;
        foreach (@$new_traits) {
            my $components = $_->[0];
            $new_trait_names{$_->[1]} = join ',', @$components;
        }

        my $onto = CXGN::Onto->new( { schema => $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $user_id) } );
        my $new_terms = $onto->store_composed_term(\%new_trait_names);

        my $non_zero_pixel_count_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, [$non_zero_pixel_count_cvterm_id, $drone_run_band_project_type_cvterm_id, $drone_run_band_plot_polygons_preprocess_cvterm_id, $time_cvterm_id]);
        my $total_pixel_sum_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, [$total_pixel_sum_cvterm_id, $drone_run_band_project_type_cvterm_id, $drone_run_band_plot_polygons_preprocess_cvterm_id, $time_cvterm_id]);
        my $mean_pixel_value_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, [$mean_pixel_value_cvterm_id, $drone_run_band_project_type_cvterm_id, $drone_run_band_plot_polygons_preprocess_cvterm_id, $time_cvterm_id]);
        my $harmonic_mean_pixel_value_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, [$harmonic_mean_pixel_value_cvterm_id, $drone_run_band_project_type_cvterm_id, $drone_run_band_plot_polygons_preprocess_cvterm_id, $time_cvterm_id]);
        my $median_pixel_value_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, [$median_pixel_value_cvterm_id, $drone_run_band_project_type_cvterm_id, $drone_run_band_plot_polygons_preprocess_cvterm_id, $time_cvterm_id]);
        my $pixel_variance_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, [$pixel_variance_cvterm_id, $drone_run_band_project_type_cvterm_id, $drone_run_band_plot_polygons_preprocess_cvterm_id, $time_cvterm_id]);
        my $pixel_standard_dev_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, [$pixel_standard_dev_cvterm_id, $drone_run_band_project_type_cvterm_id, $drone_run_band_plot_polygons_preprocess_cvterm_id, $time_cvterm_id]);
        my $pixel_pstandard_dev_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, [$pixel_pstandard_dev_cvterm_id, $drone_run_band_project_type_cvterm_id, $drone_run_band_plot_polygons_preprocess_cvterm_id, $time_cvterm_id]);
        my $minimum_pixel_value_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, [$minimum_pixel_value_cvterm_id, $drone_run_band_project_type_cvterm_id, $drone_run_band_plot_polygons_preprocess_cvterm_id, $time_cvterm_id]);
        my $maximum_pixel_value_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, [$maximum_pixel_value_cvterm_id, $drone_run_band_project_type_cvterm_id, $drone_run_band_plot_polygons_preprocess_cvterm_id, $time_cvterm_id]);
        my $minority_pixel_value_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, [$minority_pixel_value_cvterm_id, $drone_run_band_project_type_cvterm_id, $drone_run_band_plot_polygons_preprocess_cvterm_id, $time_cvterm_id]);
        my $minority_pixel_count_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, [$minority_pixel_count_cvterm_id, $drone_run_band_project_type_cvterm_id, $drone_run_band_plot_polygons_preprocess_cvterm_id, $time_cvterm_id]);
        my $majority_pixel_value_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, [$majority_pixel_value_cvterm_id, $drone_run_band_project_type_cvterm_id, $drone_run_band_plot_polygons_preprocess_cvterm_id, $time_cvterm_id]);
        my $majority_pixel_count_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, [$majority_pixel_count_cvterm_id, $drone_run_band_project_type_cvterm_id, $drone_run_band_plot_polygons_preprocess_cvterm_id, $time_cvterm_id]);
        my $pixel_group_count_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, [$pixel_group_count_cvterm_id, $drone_run_band_project_type_cvterm_id, $drone_run_band_plot_polygons_preprocess_cvterm_id, $time_cvterm_id]);

        my $non_zero_pixel_count_composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $non_zero_pixel_count_composed_cvterm_id, 'extended');
        my $total_pixel_sum_composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $total_pixel_sum_composed_cvterm_id, 'extended');
        my $mean_pixel_value_composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $mean_pixel_value_composed_cvterm_id, 'extended');
        my $harmonic_mean_pixel_value_composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $harmonic_mean_pixel_value_composed_cvterm_id, 'extended');
        my $median_pixel_value_composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $median_pixel_value_composed_cvterm_id, 'extended');
        my $pixel_variance_composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $pixel_variance_composed_cvterm_id, 'extended');
        my $pixel_standard_dev_composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $pixel_standard_dev_composed_cvterm_id, 'extended');
        my $pixel_pstandard_dev_composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $pixel_pstandard_dev_composed_cvterm_id, 'extended');
        my $minimum_pixel_value_composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $minimum_pixel_value_composed_cvterm_id, 'extended');
        my $maximum_pixel_value_composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $maximum_pixel_value_composed_cvterm_id, 'extended');
        my $majority_pixel_value_composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $minority_pixel_value_composed_cvterm_id, 'extended');
        my $majority_pixel_count_composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $minority_pixel_count_composed_cvterm_id, 'extended');
        my $minority_pixel_value_composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $majority_pixel_value_composed_cvterm_id, 'extended');
        my $minority_pixel_count_composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $majority_pixel_count_composed_cvterm_id, 'extended');
        my $pixel_group_count_composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $pixel_group_count_composed_cvterm_id, 'extended');

        my $temp_images_subdir = '';
        my $temp_results_subdir = '';
        my $calculate_phenotypes_script = '';
        my $linking_table_type_id;
        my $calculate_phenotypes_extra_args = '';
        my $archive_file_type = '';
        if ($phenotype_method eq 'zonal') {
            $temp_images_subdir = 'drone_imagery_calc_phenotypes_zonal_stats';
            $temp_results_subdir = 'drone_imagery_calc_phenotypes_zonal_stats_results';
            $calculate_phenotypes_script = 'CalculatePhenotypeZonalStats.py';
            $calculate_phenotypes_extra_args = ' --image_band_index '.$image_band_selected.' --plot_polygon_type '.$plot_polygons_type. ' --margin_percent 5';
            $archive_file_type = 'zonal_statistics_image_phenotypes';
        } elsif ($phenotype_method eq 'sift') {
            $temp_images_subdir = 'drone_imagery_calc_phenotypes_sift';
            $temp_results_subdir = 'drone_imagery_calc_phenotypes_sift_results';
            $calculate_phenotypes_script = 'CalculatePhenotypeSift.py';
            $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_phenotypes_sift_drone_imagery', 'project_md_image')->cvterm_id();
        } elsif ($phenotype_method eq 'orb') {
            $temp_images_subdir = 'drone_imagery_calc_phenotypes_orb';
            $temp_results_subdir = 'drone_imagery_calc_phenotypes_orb_results';
            $calculate_phenotypes_script = 'CalculatePhenotypeOrb.py';
            $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_phenotypes_orb_drone_imagery', 'project_md_image')->cvterm_id();
        } elsif ($phenotype_method eq 'surf') {
            $temp_images_subdir = 'drone_imagery_calc_phenotypes_surf';
            $temp_results_subdir = 'drone_imagery_calc_phenotypes_surf_results';
            $calculate_phenotypes_script = 'CalculatePhenotypeSurf.py';
            $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_phenotypes_surf_drone_imagery', 'project_md_image')->cvterm_id();
        } elsif ($phenotype_method eq 'fourier_transform') {
            $temp_images_subdir = 'drone_imagery_calc_phenotypes_fourier_transform';
            $temp_results_subdir = 'drone_imagery_calc_phenotypes_fourier_transform_results';
            $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_phenotypes_fourier_transform_drone_imagery', 'project_md_image')->cvterm_id();
            $calculate_phenotypes_script = 'CalculatePhenotypeFourierTransform.py';
            $calculate_phenotypes_extra_args = ' --image_band_index '.$image_band_selected.' --plot_polygon_type '.$plot_polygons_type. ' --margin_percent 5 --frequency_threshold 30 --frequency_threshold_method frequency';
            $archive_file_type = 'fourier_transform_image_phenotypes';
        }

        my @image_paths;
        my @out_paths;
        my %stock_images;
        my %stock_info;
        foreach (@$result) {
            my $image_id = $_->{image_id};
            my $stock_id = $_->{stock_id};
            my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
            my $image_url = $image->get_image_url("original");
            my $image_fullpath = $image->get_filename('original_converted', 'full');
            my $image_source_tag_small = $image->get_img_src_tag("tiny");

            push @{$stock_images{$stock_id}}, $image_fullpath;
            $stock_info{$stock_id} = {
                stock_id => $stock_id,
                stock_uniquename => $_->{stock_uniquename},
                stock_type_id => $_->{stock_type_id},
                image => '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_small.'</a>',
                image_id => $image_id
            };
        }

        my $dir = $c->tempfiles_subdir('/drone_imagery_calculate_phenotypes_input_file_dir');
        my $temp_input_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_calculate_phenotypes_input_file_dir/fileXXXX');

        open(my $F, ">", $temp_input_file) || die "Can't open file ".$temp_input_file;
            foreach my $stock_id (sort keys %stock_images) {
                my $images_string = join ',', @{$stock_images{$stock_id}};
                print $F "$stock_id\t$images_string\n";

                if ($phenotype_method ne 'zonal') {
                    my $dir = $c->tempfiles_subdir('/'.$temp_images_subdir);
                    my $archive_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => $temp_images_subdir.'/imageXXXX');
                    $archive_temp_image .= '.png';
                    push @out_paths, $archive_temp_image;
                }
            }
        close($F);

        my $out_paths_string = join ',', @out_paths;

        if ($out_paths_string) {
            $out_paths_string = ' --outfile_paths '.$out_paths_string;
        }

        $dir = $c->tempfiles_subdir('/'.$temp_results_subdir);
        my $archive_temp_results = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => $temp_results_subdir.'/imageXXXX');

        my $cmd = $c->config->{python_executable}.' '.$c->config->{rootpath}.'/DroneImageScripts/ImageProcess/'.$calculate_phenotypes_script.' --image_paths_input_file \''.$temp_input_file.'\' '.$out_paths_string.' --results_outfile_path \''.$archive_temp_results.'\''.$calculate_phenotypes_extra_args;
        print STDERR Dumper $cmd;
        my $status = system("$cmd > /dev/null");

        my $time = DateTime->now();
        my $timestamp = $time->ymd()."_".$time->hms();

        my $csv = Text::CSV->new({ sep_char => ',' });
        open(my $fh, '<', $archive_temp_results)
            or die "Could not open file '$archive_temp_results' $!";

            print STDERR "Opened $archive_temp_results\n";
            my $header = <$fh>;
            if ($csv->parse($header)) {
                @header_cols = $csv->fields();
            }

            my $line = 0;
            my %zonal_stat_phenotype_data;
            my %plots_seen;
            my @traits_seen;
            if ($phenotype_method eq 'zonal' || $phenotype_method eq 'fourier_transform') {
                if ($header_cols[0] ne 'stock_id' ||
                    $header_cols[1] ne 'nonzero_pixel_count' ||
                    $header_cols[2] ne 'total_pixel_sum' ||
                    $header_cols[3] ne 'mean_pixel_value' ||
                    $header_cols[4] ne 'harmonic_mean_value' ||
                    $header_cols[5] ne 'median_pixel_value' ||
                    $header_cols[6] ne 'variance_pixel_value' ||
                    $header_cols[7] ne 'stdev_pixel_value' ||
                    $header_cols[8] ne 'pstdev_pixel_value' ||
                    $header_cols[9] ne 'min_pixel_value' ||
                    $header_cols[10] ne 'max_pixel_value' ||
                    $header_cols[11] ne 'minority_pixel_value' ||
                    $header_cols[12] ne 'minority_pixel_count' ||
                    $header_cols[13] ne 'majority_pixel_value' ||
                    $header_cols[14] ne 'majority_pixel_count' ||
                    $header_cols[15] ne 'pixel_variety_count'
                ) {
                    $c->stash->{rest} = { error => "Pheno results must have header: 'stock_id', 'nonzero_pixel_count', 'total_pixel_sum', 'mean_pixel_value', 'harmonic_mean_value', 'median_pixel_value', 'variance_pixel_value', 'stdev_pixel_value', 'pstdev_pixel_value', 'min_pixel_value', 'max_pixel_value', 'minority_pixel_value', 'minority_pixel_count', 'majority_pixel_value', 'majority_pixel_count', 'pixel_variety_count'" };
                    return;
                }

                @traits_seen = (
                    $non_zero_pixel_count_composed_trait_name,
                    $total_pixel_sum_composed_trait_name,
                    $mean_pixel_value_composed_trait_name,
                    $harmonic_mean_pixel_value_composed_trait_name,
                    $median_pixel_value_composed_trait_name,
                    $pixel_variance_composed_trait_name,
                    $pixel_standard_dev_composed_trait_name,
                    $pixel_pstandard_dev_composed_trait_name,
                    $minimum_pixel_value_composed_trait_name,
                    $maximum_pixel_value_composed_trait_name,
                    $majority_pixel_value_composed_trait_name,
                    $majority_pixel_count_composed_trait_name,
                    $minority_pixel_value_composed_trait_name,
                    $minority_pixel_count_composed_trait_name,
                    $pixel_group_count_composed_trait_name
                );

                while ( my $row = <$fh> ){
                    my @columns;
                    if ($csv->parse($row)) {
                        @columns = $csv->fields();
                    }

                    my $stock_id = $columns[0];
                    my $stock_uniquename = $stock_info{$stock_id}->{stock_uniquename};
                    my $image_id = $stock_info{$stock_id}->{image_id};

                    #print STDERR Dumper \@columns;
                    $stock_info{$stock_id}->{result} = \@columns;

                    $plots_seen{$stock_uniquename} = 1;
                    $zonal_stat_phenotype_data{$stock_uniquename}->{$non_zero_pixel_count_composed_trait_name} = [$columns[1], $timestamp, $user_name, '', $image_id];
                    $zonal_stat_phenotype_data{$stock_uniquename}->{$total_pixel_sum_composed_trait_name} = [$columns[2], $timestamp, $user_name, '', $image_id];
                    $zonal_stat_phenotype_data{$stock_uniquename}->{$mean_pixel_value_composed_trait_name} = [$columns[3], $timestamp, $user_name, '', $image_id];
                    $zonal_stat_phenotype_data{$stock_uniquename}->{$harmonic_mean_pixel_value_composed_trait_name} = [$columns[4], $timestamp, $user_name, '', $image_id];
                    $zonal_stat_phenotype_data{$stock_uniquename}->{$median_pixel_value_composed_trait_name} = [$columns[5], $timestamp, $user_name, '', $image_id];
                    $zonal_stat_phenotype_data{$stock_uniquename}->{$pixel_variance_composed_trait_name} = [$columns[6], $timestamp, $user_name, '', $image_id];
                    $zonal_stat_phenotype_data{$stock_uniquename}->{$pixel_standard_dev_composed_trait_name} = [$columns[7], $timestamp, $user_name, '', $image_id];
                    $zonal_stat_phenotype_data{$stock_uniquename}->{$pixel_pstandard_dev_composed_trait_name} = [$columns[8], $timestamp, $user_name, '', $image_id];
                    $zonal_stat_phenotype_data{$stock_uniquename}->{$minimum_pixel_value_composed_trait_name} = [$columns[9], $timestamp, $user_name, '', $image_id];
                    $zonal_stat_phenotype_data{$stock_uniquename}->{$maximum_pixel_value_composed_trait_name} = [$columns[10], $timestamp, $user_name, '', $image_id];
                    $zonal_stat_phenotype_data{$stock_uniquename}->{$minority_pixel_value_composed_trait_name} = [$columns[11], $timestamp, $user_name, '', $image_id];
                    $zonal_stat_phenotype_data{$stock_uniquename}->{$minority_pixel_count_composed_trait_name} = [$columns[12], $timestamp, $user_name, '', $image_id];
                    $zonal_stat_phenotype_data{$stock_uniquename}->{$majority_pixel_value_composed_trait_name} = [$columns[13], $timestamp, $user_name, '', $image_id];
                    $zonal_stat_phenotype_data{$stock_uniquename}->{$majority_pixel_count_composed_trait_name} = [$columns[14], $timestamp, $user_name, '', $image_id];
                    $zonal_stat_phenotype_data{$stock_uniquename}->{$pixel_group_count_composed_trait_name} = [$columns[15], $timestamp, $user_name, '', $image_id];

                    $line++;
                }
                @stocks = values %stock_info;
            }

        close $fh;
        print STDERR "Read $line lines in results file\n";

        if ($line > 0) {
            my %phenotype_metadata = (
                'archived_file' => $archive_temp_results,
                'archived_file_type' => $archive_file_type,
                'operator' => $user_name,
                'date' => $timestamp
            );
            my @plot_units_seen = keys %plots_seen;

            my $store_args = {
                basepath=>$c->config->{basepath},
                dbhost=>$c->config->{dbhost},
                dbname=>$c->config->{dbname},
                dbuser=>$c->config->{dbuser},
                dbpass=>$c->config->{dbpass},
                bcs_schema=>$schema,
                metadata_schema=>$metadata_schema,
                phenome_schema=>$phenome_schema,
                user_id=>$user_id,
                stock_list=>\@plot_units_seen,
                trait_list=>\@traits_seen,
                values_hash=>\%zonal_stat_phenotype_data,
                has_timestamps=>1,
                metadata_hash=>\%phenotype_metadata,
                composable_validation_check_name=>$c->config->{composable_validation_check_name},
                allow_repeat_measures=>$c->config->{allow_repeat_measures}
            };

            if ($overwrite_phenotype_values) {
                $store_args->{overwrite_values} = $overwrite_phenotype_values;
            }
            if ($ignore_new_phenotype_values) {
                $store_args->{ignore_new_values} = $ignore_new_phenotype_values;
            }

            my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new(
                $store_args
            );
            my ($verified_warning, $verified_error) = $store_phenotypes->verify();
            my ($stored_phenotype_error, $stored_phenotype_success) = $store_phenotypes->store();

            if (!$do_not_run_materialized_view_refresh) {
                my $bs = CXGN::BreederSearch->new( { dbh=>$c->dbc->dbh, dbname=>$c->config->{dbname}, } );
                my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'fullview', 'nonconcurrent', $c->config->{basepath});
            }
        }

        my $count = 0;
        foreach (@out_paths) {
            my $stock = $stocks[$count];

            my $image_fullpath;
            my $image_url;
            my $image_source_tag_small;
            my $image_id;

            my $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
            my $md5checksum = $image->calculate_md5sum($_);
            my $q = "SELECT md_image.image_id FROM metadata.md_image AS md_image
                JOIN phenome.project_md_image AS project_md_image ON(project_md_image.image_id = md_image.image_id)
                WHERE md_image.obsolete = 'f' AND md_image.md5sum = ? AND project_md_image.type_id = ? AND project_md_image.project_id = ?;";
            my $h = $schema->storage->dbh->prepare($q);
            $h->execute($md5checksum, $linking_table_type_id, $drone_run_band_project_id);
            my ($saved_image_id) = $h->fetchrow_array();

            if ($saved_image_id) {
                print STDERR Dumper "Image $_ has already been added to the database and will not be added again.";
                $image_id = $saved_image_id;
                $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
                $image_fullpath = $image->get_filename('original_converted', 'full');
                $image_url = $image->get_image_url('original');
                $image_source_tag_small = $image->get_img_src_tag("tiny");
            } else {
                $image->set_sp_person_id($user_id);
                my $ret = $image->process_image($_, 'project', $drone_run_band_project_id, $linking_table_type_id);
                $ret = $image->associate_stock($stock->{stock_id}, $user_name);
                $image_fullpath = $image->get_filename('original_converted', 'full');
                $image_url = $image->get_image_url('original');
                $image_source_tag_small = $image->get_img_src_tag("tiny");
                $image_id = $image->get_image_id;
            }

            $stocks[$count]->{image} = '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_small.'</a>';
            $stocks[$count]->{image_path} = $image_fullpath;
            $stocks[$count]->{image_url} = $image_url;
            $count++;

            unlink($_);
        }
    }

    return {
        result_header => \@header_cols, results => \@stocks
    };
}

sub drone_imagery_compare_images : Path('/api/drone_imagery/compare_images') : ActionClass('REST') { }
sub drone_imagery_compare_images_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $sp_person_id);
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema", undef, $sp_person_id);
    my $stock_id_list = $c->req->param('stock_id') ? [$c->req->param('stock_id')] : [];
    my $comparison_type = $c->req->param('comparison_type');
    my $image_ids = $c->req->param('image_ids') ? decode_json($c->req->param('image_ids')) : [];
    my $drone_run_band_ids = $c->req->param('drone_run_band_ids') ? decode_json($c->req->param('drone_run_band_ids')) : [];
    my $drone_run_ids = $c->req->param('drone_run_ids') ? decode_json($c->req->param('drone_run_ids')) : [];
    my $plot_polygon_type_ids = $c->req->param('image_type_ids') ? decode_json($c->req->param('image_type_ids')) : [];
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        project_image_type_id_list=>$plot_polygon_type_ids,
        drone_run_project_id_list=>$drone_run_ids,
        drone_run_band_project_id_list=>$drone_run_band_ids,
        stock_id_list=>$stock_id_list,
        image_id_list=>$image_ids
    });
    my ($result, $total_count) = $images_search->search();
    #print STDERR Dumper $result;
    print STDERR Dumper $total_count;

    my %data_hash;
    my %unique_drone_run_band_project_names;
    my %unique_image_type_names;
    foreach (@$result) {
        my $image_id = $_->{image_id};
        my $project_image_type_name = $_->{project_image_type_name};
        my $drone_run_band_project_name = $_->{drone_run_band_project_name};
        $unique_drone_run_band_project_names{$drone_run_band_project_name}++;
        $unique_image_type_names{$project_image_type_name}++;
        my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
        my $image_url = $image->get_image_url("original");
        my $image_fullpath = $image->get_filename('original_converted', 'full');
        push @{$data_hash{$drone_run_band_project_name}->{$project_image_type_name}->{image_fullpaths}}, $image_fullpath;
    }
    print STDERR Dumper \%data_hash;
    my @unique_drone_run_band_project_names_sort = sort keys %unique_drone_run_band_project_names;
    my @unique_image_type_names_sort = sort keys %unique_image_type_names;
    my $images1 = $data_hash{$unique_drone_run_band_project_names_sort[0]}->{$unique_image_type_names_sort[0]}->{image_fullpaths};
    my $image1 = $images1->[0];
    my $images2 = $data_hash{$unique_drone_run_band_project_names_sort[0]}->{$unique_image_type_names_sort[1]}->{image_fullpaths};
    my $image2 = $images2->[0];
    if (!$image2) {
        $images2 = $data_hash{$unique_drone_run_band_project_names_sort[1]}->{$unique_image_type_names_sort[1]}->{image_fullpaths};
        $image2 = $images2->[0];
    }
    if (!$image2) {
        $images2 = $data_hash{$unique_drone_run_band_project_names_sort[1]}->{$unique_image_type_names_sort[0]}->{image_fullpaths};
        $image2 = $images2->[0];
    }

    my $dir = $c->tempfiles_subdir('/drone_imagery_compare_images_dir');
    my $archive_temp_output = $c->tempfile( TEMPLATE => 'drone_imagery_compare_images_dir/outputfileXXXX');
    my $archive_temp_output_file = $c->config->{basepath}."/".$archive_temp_output;

    my $cmd = $c->config->{python_executable}.' '.$c->config->{rootpath}.'/DroneImageScripts/ImageProcess/CompareTwoImagesPixelValues.py --image_path1 \''.$image1.'\' --image_path2 \''.$image2.'\' --image_type1 \''.$unique_image_type_names_sort[0].'\' --image_type2 \''.$unique_image_type_names_sort[1].'\' --outfile_path \''.$archive_temp_output_file.'\' ';
    print STDERR Dumper $cmd;
    my $status = system("$cmd > /dev/null");

    $c->stash->{rest} = { success => 1, result => $c->config->{main_production_site_url}.$archive_temp_output.".png" };
}

sub drone_imagery_train_keras_model : Path('/api/drone_imagery/train_keras_model') : ActionClass('REST') { }
sub drone_imagery_train_keras_model_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    print STDERR Dumper $c->req->params();
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $sp_person_id);
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema", undef, $sp_person_id);
    my $people_schema = $c->dbic_schema("CXGN::People::Schema", undef, $sp_person_id);
    my @field_trial_ids = split ',', $c->req->param('field_trial_ids');
    my $trait_id = $c->req->param('trait_id');
    my @aux_trait_id = $c->req->param('aux_trait_id[]') ? $c->req->param('aux_trait_id[]') : ();
    my $model_type = $c->req->param('model_type');
    my $population_id = $c->req->param('population_id');
    my $protocol_id = $c->req->param('nd_protocol_id');
    my $use_parents_grm = $c->req->param('use_parents_grm') eq 'yes' ? 1 : 0;
    my $drone_run_ids = decode_json($c->req->param('drone_run_ids'));
    my $plot_polygon_type_ids = decode_json($c->req->param('plot_polygon_type_ids'));
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $project_image_type_id_list = CXGN::DroneImagery::ImageTypes::get_all_project_md_image_observation_unit_plot_polygon_types($schema);

    my $dir = $c->tempfiles_subdir('/drone_imagery_keras_cnn_dir');
    my $archive_temp_result_agg_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_dir/resultaggXXXX');

    my @accession_ids;
    if ($population_id && $population_id ne 'null') {
        my $accession_manager = CXGN::BreedersToolbox::Accessions->new(schema=>$schema);
        my $population_members = $accession_manager->get_population_members($population_id);
        foreach (@$population_members) {
            push @accession_ids, $_->{stock_id};
        }
    }

    my @result_agg;
    my $images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        drone_run_project_id_list=>$drone_run_ids,
        project_image_type_id_list=>$plot_polygon_type_ids,
        accession_list=>\@accession_ids
    });
    my ($result, $total_count) = $images_search->search();
    #print STDERR Dumper $result;
    print STDERR Dumper $total_count;

    my %data_hash;
    my %seen_day_times;
    my %seen_image_types;
    my %seen_drone_run_band_project_ids;
    my %seen_drone_run_project_ids;
    my %seen_field_trial_ids;
    my %seen_stock_ids;
    foreach (@$result) {
        my $image_id = $_->{image_id};
        my $stock_id = $_->{stock_id};
        my $field_trial_id = $_->{trial_id};
        my $project_image_type_id = $_->{project_image_type_id};
        my $drone_run_band_project_id = $_->{drone_run_band_project_id};
        my $drone_run_project_id = $_->{drone_run_project_id};
        my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
        my $image_url = $image->get_image_url("original");
        my $image_fullpath = $image->get_filename('original_converted', 'full');
        my $time_days_cvterm = $_->{drone_run_related_time_cvterm_json}->{day};
        my $time_days = (split '\|', $time_days_cvterm)[0];
        my $days = (split ' ', $time_days)[1];
        $data_hash{$field_trial_id}->{$stock_id}->{$project_image_type_id}->{$days} = {
            image => $image_fullpath,
            drone_run_project_id => $drone_run_project_id
        };
        $seen_day_times{$days}++;
        $seen_image_types{$project_image_type_id}++;
        $seen_drone_run_band_project_ids{$drone_run_band_project_id}++;
        $seen_drone_run_project_ids{$drone_run_project_id}++;
        $seen_field_trial_ids{$field_trial_id}++;
        $seen_stock_ids{$stock_id}++;
    }
    print STDERR Dumper \%seen_day_times;
    undef $result;

    my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $plot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id();
    my $plot_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot_of', 'stock_relationship')->cvterm_id();
    my $female_parent_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'female_parent', 'stock_relationship')->cvterm_id();
    my $male_parent_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'male_parent', 'stock_relationship')->cvterm_id();

    my @seen_plots = keys %seen_stock_ids;
    print STDERR Dumper \@seen_plots;
    my $plot_list_string = join ',', @seen_plots;
    my $q = "SELECT plot.stock_id, accession.stock_id, female_parent.stock_id, male_parent.stock_id
        FROM stock AS plot
        JOIN stock_relationship AS plot_acc_rel ON(plot_acc_rel.subject_id=plot.stock_id AND plot_acc_rel.type_id=$plot_of_cvterm_id)
        JOIN stock AS accession ON(plot_acc_rel.object_id=accession.stock_id AND accession.type_id=$accession_cvterm_id)
        JOIN stock_relationship AS female_parent_rel ON(accession.stock_id=female_parent_rel.object_id AND female_parent_rel.type_id=$female_parent_cvterm_id)
        JOIN stock AS female_parent ON(female_parent_rel.subject_id = female_parent.stock_id AND female_parent.type_id=$accession_cvterm_id)
        JOIN stock_relationship AS male_parent_rel ON(accession.stock_id=male_parent_rel.object_id AND male_parent_rel.type_id=$male_parent_cvterm_id)
        JOIN stock AS male_parent ON(male_parent_rel.subject_id = male_parent.stock_id AND male_parent.type_id=$accession_cvterm_id)
        WHERE plot.type_id=$plot_cvterm_id AND plot.stock_id IN ($plot_list_string);";
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute();
    my %plot_pedigrees_found = ();
    my %accession_pedigrees_found = ();
    my %unique_accession_ids_genotypes = ();
    while (my ($plot_stock_id, $accession_stock_id, $female_parent_stock_id, $male_parent_stock_id) = $h->fetchrow_array()) {
        $unique_accession_ids_genotypes{$accession_stock_id}++;
        $plot_pedigrees_found{$plot_stock_id} = {
            female_stock_id => $female_parent_stock_id,
            male_stock_id => $male_parent_stock_id
        };
        $accession_pedigrees_found{$accession_stock_id} = {
            female_stock_id => $female_parent_stock_id,
            male_stock_id => $male_parent_stock_id
        };
    }

    my %unique_genotype_accessions;
    if ($protocol_id) {
        my @accession_list = sort keys %unique_accession_ids_genotypes;
        my $geno = CXGN::Genotype::DownloadFactory->instantiate(
            'DosageMatrix',    #can be either 'VCF' or 'DosageMatrix'
            {
                bcs_schema=>$schema,
                people_schema=>$people_schema,
                cache_root_dir=>$c->config->{cache_file_path},
                accession_list=>\@accession_list,
                protocol_id_list=>[$protocol_id],
                compute_from_parents=>$use_parents_grm,
                return_only_first_genotypeprop_for_stock=>1,
                prevent_transpose=>1
            }
        );
        my $file_handle = $geno->download(
            $c->config->{cluster_shared_tempdir},
            $c->config->{backend},
            $c->config->{cluster_host},
            $c->config->{'web_cluster_queue'},
            $c->config->{basepath}
        );
        open my $geno_fh, "<&", $file_handle or die "Can't open output file: $!";
            my $header = <$geno_fh>;
            while (my $row = <$geno_fh>) {
                chomp($row);
                if ($row) {
                    my @line = split "\t", $row;
                    my $stock_id = shift @line;
                    my $out_line = join "\n", @line;
                    if ($out_line) {
                        my $geno_temp_input_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_dir/genoinputfileXXXX');
                        my $status = write_file($geno_temp_input_file, $out_line."\n");
                        $unique_genotype_accessions{$stock_id} = $geno_temp_input_file;
                    }
                }
            }
        close($geno_fh);
        @accession_ids = keys %unique_genotype_accessions;
    }

    my @trait_ids = ($trait_id);
    if (scalar(@aux_trait_id) > 0) {
        push @trait_ids, @aux_trait_id;
    }

    my $phenotypes_search = CXGN::Phenotypes::SearchFactory->instantiate(
        'MaterializedViewTable',
        {
            bcs_schema=>$schema,
            data_level=>'plot',
            trait_list=>\@trait_ids,
            trial_list=>\@field_trial_ids,
            plot_list=>\@seen_plots,
            accession_list=>\@accession_ids,
            exclude_phenotype_outlier=>0,
            include_timestamp=>0
        }
    );
    my ($data, $unique_traits) = $phenotypes_search->search();

    my %phenotype_data_hash;
    my %aux_data_hash;
    foreach my $d (@$data) {
        foreach my $o (@{$d->{observations}}) {
            if ($o->{trait_id} == $trait_id) {
                $phenotype_data_hash{$d->{observationunit_stock_id}}->{trait_value} = {
                    trait_name => $o->{trait_name},
                    value => $o->{value}
                };
            } else {
                $phenotype_data_hash{$d->{observationunit_stock_id}}->{aux_trait_value}->{$o->{trait_id}} = $o->{value};
            }
        }
        $aux_data_hash{$d->{trial_id}}->{$d->{observationunit_stock_id}} = $d;
    }
    #print STDERR Dumper \%data_hash;
    undef $data;

    my $archive_temp_input_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_dir/inputfileXXXX');
    my $archive_temp_input_aux_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_dir/inputfileauxXXXX');
    my $archive_temp_output_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_dir/outputfileXXXX');
    my $archive_temp_autoencoder_output_model_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_dir/autoencodermodelfileXXXX').".hdf5";
    my $archive_temp_loss_history_file_string = $c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_dir/losshistoryXXXX');
    my $archive_temp_loss_history_file = $c->config->{basepath}."/".$archive_temp_loss_history_file_string;

    my $keras_project_name = basename($c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_dir/keras_tuner_XXXX'));
    my $archive_temp_output_model_file = $c->config->{cluster_shared_tempdir}.'/'.$keras_project_name.'.hdf5';
    my $keras_tuner_dir = $c->config->{cluster_shared_tempdir};
    my $keras_tuner_output_project_dir = $keras_tuner_dir.$keras_project_name;

    my %output_images;

    open(my $F_aux, ">", $archive_temp_input_aux_file) || die "Can't open file ".$archive_temp_input_aux_file;
        print $F_aux 'stock_id,value,trait_name,field_trial_id,accession_id,female_id,male_id,output_image_file,genotype_file';
        if (scalar(@aux_trait_id)>0) {
            my $aux_trait_counter = 0;
            foreach (@aux_trait_id) {
                print $F_aux ",aux_trait_$aux_trait_counter";
                $aux_trait_counter++;
            }
        }
        print $F_aux "\n";

        # LSTM model uses longitudinal time information, so input ordered by field_trial, then stock_id, then by image_type, then by chronological ascending time for each drone run
        if ($model_type eq 'KerasCNNLSTMDenseNet121ImageNetWeights') {
            foreach my $field_trial_id (sort keys %seen_field_trial_ids){
                foreach my $stock_id (sort keys %seen_stock_ids){
                    foreach my $image_type (sort keys %seen_image_types) {
                        my $d = $aux_data_hash{$field_trial_id}->{$stock_id};
                        my $value = $phenotype_data_hash{$stock_id}->{trait_value}->{value};
                        my $trait_name = $phenotype_data_hash{$stock_id}->{trait_value}->{trait_name};
                        my $female_parent_stock_id = $plot_pedigrees_found{$stock_id}->{female_stock_id} || 0;
                        my $male_parent_stock_id = $plot_pedigrees_found{$stock_id}->{male_stock_id} || 0;
                        my $germplasm_id = $d->{germplasm_stock_id};
                        if (defined($value)) {
                            my $archive_temp_output_image_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_dir/outputimagefileXXXX');
                            $archive_temp_output_image_file .= ".png";
                            $output_images{$stock_id} = {
                                image_file => $archive_temp_output_image_file,
                                field_trial_id => $field_trial_id
                            };
                            my $geno_file = $unique_genotype_accessions{$germplasm_id} || '';

                            print $F_aux "$stock_id,";
                            print $F_aux "$value,";
                            print $F_aux "$trait_name,";
                            print $F_aux "$field_trial_id,";
                            print $F_aux "$germplasm_id,";
                            print $F_aux "$female_parent_stock_id,";
                            print $F_aux "$male_parent_stock_id,";
                            print $F_aux "$archive_temp_output_image_file,";
                            print $F_aux "$geno_file";
                            if (scalar(@aux_trait_id)>0) {
                                print $F_aux ',';
                                my @aux_values;
                                foreach my $aux_trait (@aux_trait_id) {
                                    my $aux_value = $phenotype_data_hash{$stock_id} ? $phenotype_data_hash{$stock_id}->{aux_trait_value}->{$aux_trait} : '';
                                    if (!$aux_value) {
                                        $aux_value = '';
                                    }
                                    push @aux_values, $aux_value;
                                }
                                my $aux_values_string = scalar(@aux_values)>0 ? join ',', @aux_values : '';
                                print $F_aux $aux_values_string;
                            }
                            print $F_aux "\n";
                        }
                    }
                }
            }
        }
        #Non-LSTM models group image types for each stock into a single montage, so the input is ordered by field trial, then ascending chronological time, then by stock_id, and then by image_type.
        else {
            foreach my $field_trial_id (sort keys %seen_field_trial_ids){
                foreach my $day_time (sort { $a <=> $b } keys %seen_day_times) {
                    foreach my $stock_id (sort keys %seen_stock_ids){
                        my $d = $aux_data_hash{$field_trial_id}->{$stock_id};
                        my $value = $phenotype_data_hash{$stock_id}->{trait_value}->{value};
                        my $trait_name = $phenotype_data_hash{$stock_id}->{trait_value}->{trait_name};
                        my $female_parent_stock_id = $plot_pedigrees_found{$stock_id}->{female_stock_id} || 0;
                        my $male_parent_stock_id = $plot_pedigrees_found{$stock_id}->{male_stock_id} || 0;
                        my $germplasm_id = $d->{germplasm_stock_id};
                        if (defined($value)) {
                            my $archive_temp_output_image_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_dir/outputimagefileXXXX');
                            $archive_temp_output_image_file .= ".png";
                            $output_images{$stock_id} = {
                                image_file => $archive_temp_output_image_file,
                                field_trial_id => $field_trial_id
                            };
                            my $geno_file = $unique_genotype_accessions{$germplasm_id} || '';
                            print STDERR Dumper $geno_file;

                            print $F_aux "$stock_id,";
                            print $F_aux "$value,";
                            print $F_aux "$trait_name,";
                            print $F_aux "$field_trial_id,";
                            print $F_aux "$germplasm_id,";
                            print $F_aux "$female_parent_stock_id,";
                            print $F_aux "$male_parent_stock_id,";
                            print $F_aux "$archive_temp_output_image_file,";
                            print $F_aux "$geno_file";
                            if (scalar(@aux_trait_id)>0) {
                                print $F_aux ',';
                                my @aux_values;
                                foreach my $aux_trait (@aux_trait_id) {
                                    my $aux_value = $phenotype_data_hash{$stock_id} ? $phenotype_data_hash{$stock_id}->{aux_trait_value}->{$aux_trait} : '';
                                    if (!$aux_value) {
                                        $aux_value = '';
                                    }
                                    push @aux_values, $aux_value;
                                }
                                my $aux_values_string = scalar(@aux_values)>0 ? join ',', @aux_values : '';
                                print $F_aux $aux_values_string;
                            }
                            print $F_aux "\n";
                        }
                    }
                }
            }
        }
    close($F_aux);

    open(my $F, ">", $archive_temp_input_file) || die "Can't open file ".$archive_temp_input_file;
        print $F "stock_id,image_path,image_type,day,drone_run_project_id,value\n";

        # LSTM model uses longitudinal time information, so input ordered by field_trial, then stock_id, then by image_type, then by chronological ascending time for each drone run
        if ($model_type eq 'KerasCNNLSTMDenseNet121ImageNetWeights') {
            foreach my $field_trial_id (sort keys %seen_field_trial_ids){
                foreach my $stock_id (sort keys %seen_stock_ids){
                    foreach my $image_type (sort keys %seen_image_types) {
                        foreach my $day_time (sort { $a <=> $b } keys %seen_day_times) {
                            my $data = $data_hash{$field_trial_id}->{$stock_id}->{$image_type}->{$day_time};
                            my $image_fullpath = $data->{image};
                            my $drone_run_project_id = $data->{drone_run_project_id};
                            my $value = $phenotype_data_hash{$stock_id}->{trait_value}->{value};
                            if (defined($value)) {
                                print $F "$stock_id,";
                                print $F "$image_fullpath,";
                                print $F "$image_type,";
                                print $F "$day_time,";
                                print $F "$drone_run_project_id,";
                                print $F "$value\n";
                            }
                        }
                    }
                }
            }
        }
        #Non-LSTM models group image types for each stock into a single montage, so the input is ordered by field trial, then ascending chronological time, then by stock_id, and then by image_type.
        else {
            foreach my $field_trial_id (sort keys %seen_field_trial_ids) {
                foreach my $day_time (sort { $a <=> $b } keys %seen_day_times) {
                    foreach my $stock_id (sort keys %seen_stock_ids){
                        foreach my $image_type (sort keys %seen_image_types) {
                            my $data = $data_hash{$field_trial_id}->{$stock_id}->{$image_type}->{$day_time};
                            my $image_fullpath = $data->{image};
                            my $drone_run_project_id = $data->{drone_run_project_id};
                            my $value = $phenotype_data_hash{$stock_id}->{trait_value}->{value};
                            if (defined($value)) {
                                print $F "$stock_id,";
                                print $F "$image_fullpath,";
                                print $F "$image_type,";
                                print $F "$day_time,";
                                print $F "$drone_run_project_id,";
                                print $F "$value\n";
                            }
                        }
                    }
                }
            }
        }
    close($F);

    undef %data_hash;
    undef %phenotype_data_hash;
    undef %aux_data_hash;

    my $log_file_path = '';
    if ($c->config->{error_log}) {
        $log_file_path = ' --log_file_path \''.$c->config->{error_log}.'\'';
    }

    my $cmd = '';
    if ($model_type eq 'KerasTunerCNNSequentialSoftmaxCategorical') {
        $cmd = $c->config->{python_executable}.' '.$c->config->{rootpath}.'/DroneImageScripts/CNN/KerasCNNSequentialSoftmaxCategorical.py --input_image_label_file \''.$archive_temp_input_file.'\' --input_aux_data_file \''.$archive_temp_input_aux_file.'\' --outfile_path \''.$archive_temp_output_file.'\' --output_model_file_path \''.$archive_temp_output_model_file.'\' '.$log_file_path.' --output_random_search_result_project \''.$keras_tuner_output_project_dir.'\' --keras_model_type simple_1_tuner --output_loss_history \''.$archive_temp_loss_history_file.'\' --output_autoencoder_model_file_path \''.$archive_temp_autoencoder_output_model_file.'\' ';
    }
    elsif ($model_type eq 'SimpleKerasTunerCNNSequentialSoftmaxCategorical') {
        $cmd = $c->config->{python_executable}.' '.$c->config->{rootpath}.'/DroneImageScripts/CNN/KerasCNNSequentialSoftmaxCategorical.py --input_image_label_file \''.$archive_temp_input_file.'\' --input_aux_data_file \''.$archive_temp_input_aux_file.'\' --outfile_path \''.$archive_temp_output_file.'\' --output_model_file_path \''.$archive_temp_output_model_file.'\' '.$log_file_path.' --output_random_search_result_project \''.$keras_tuner_output_project_dir.'\' --keras_model_type simple_tuner --output_loss_history \''.$archive_temp_loss_history_file.'\' --output_autoencoder_model_file_path \''.$archive_temp_autoencoder_output_model_file.'\' ';
    }
    # elsif ($model_type eq 'KerasTunerCNNInceptionResNetV2') {
    #     $cmd = $c->config->{python_executable}.' '.$c->config->{rootpath}.'/DroneImageScripts/CNN/KerasCNNSequentialSoftmaxCategorical.py --input_image_label_file \''.$archive_temp_input_file.'\' --input_aux_data_file \''.$archive_temp_input_aux_file.'\' --outfile_path \''.$archive_temp_output_file.'\' --output_model_file_path \''.$archive_temp_output_model_file.'\' '.$log_file_path.' --output_random_search_result_project \''.$keras_tuner_output_project_dir.'\' --keras_model_type inceptionresnetv2application_tuner --output_loss_history \''.$archive_temp_loss_history_file.'\' --output_autoencoder_model_file_path \''.$archive_temp_autoencoder_output_model_file.'\' ';
    # }
    elsif ($model_type eq 'KerasCNNInceptionResNetV2ImageNetWeights') {
        $cmd = $c->config->{python_executable}.' '.$c->config->{rootpath}.'/DroneImageScripts/CNN/KerasCNNSequentialSoftmaxCategorical.py --input_image_label_file \''.$archive_temp_input_file.'\' --input_aux_data_file \''.$archive_temp_input_aux_file.'\' --outfile_path \''.$archive_temp_output_file.'\' --output_model_file_path \''.$archive_temp_output_model_file.'\' '.$log_file_path.' --keras_model_type inceptionresnetv2application --keras_model_weights imagenet --output_loss_history \''.$archive_temp_loss_history_file.'\' --output_autoencoder_model_file_path \''.$archive_temp_autoencoder_output_model_file.'\' ';
    }
    elsif ($model_type eq 'KerasCNNInceptionResNetV2') {
        $cmd = $c->config->{python_executable}.' '.$c->config->{rootpath}.'/DroneImageScripts/CNN/KerasCNNSequentialSoftmaxCategorical.py --input_image_label_file \''.$archive_temp_input_file.'\' --input_aux_data_file \''.$archive_temp_input_aux_file.'\' --outfile_path \''.$archive_temp_output_file.'\' --output_model_file_path \''.$archive_temp_output_model_file.'\' '.$log_file_path.' --keras_model_type inceptionresnetv2 --output_loss_history \''.$archive_temp_loss_history_file.'\' --output_autoencoder_model_file_path \''.$archive_temp_autoencoder_output_model_file.'\' ';
    }
    elsif ($model_type eq 'KerasCNNLSTMDenseNet121ImageNetWeights') {
        $cmd = $c->config->{python_executable}.' '.$c->config->{rootpath}.'/DroneImageScripts/CNN/KerasCNNSequentialSoftmaxCategorical.py --input_image_label_file \''.$archive_temp_input_file.'\' --input_aux_data_file \''.$archive_temp_input_aux_file.'\' --outfile_path \''.$archive_temp_output_file.'\' --output_model_file_path \''.$archive_temp_output_model_file.'\' '.$log_file_path.' --keras_model_type densenet121_lstm_imagenet --keras_model_weights imagenet --output_loss_history \''.$archive_temp_loss_history_file.'\' --output_autoencoder_model_file_path \''.$archive_temp_autoencoder_output_model_file.'\' ';
    }
    elsif ($model_type eq 'KerasCNNDenseNet121ImageNetWeights') {
        $cmd = $c->config->{python_executable}.' '.$c->config->{rootpath}.'/DroneImageScripts/CNN/KerasCNNSequentialSoftmaxCategorical.py --input_image_label_file \''.$archive_temp_input_file.'\' --input_aux_data_file \''.$archive_temp_input_aux_file.'\' --outfile_path \''.$archive_temp_output_file.'\' --output_model_file_path \''.$archive_temp_output_model_file.'\' '.$log_file_path.' --keras_model_type densenet121application --keras_model_weights imagenet --output_loss_history \''.$archive_temp_loss_history_file.'\' --output_autoencoder_model_file_path \''.$archive_temp_autoencoder_output_model_file.'\' ';
    }
    elsif ($model_type eq 'KerasCNNSequentialSoftmaxCategorical') {
        $cmd = $c->config->{python_executable}.' '.$c->config->{rootpath}.'/DroneImageScripts/CNN/KerasCNNSequentialSoftmaxCategorical.py --input_image_label_file \''.$archive_temp_input_file.'\' --input_aux_data_file \''.$archive_temp_input_aux_file.'\' --outfile_path \''.$archive_temp_output_file.'\' --output_model_file_path \''.$archive_temp_output_model_file.'\' '.$log_file_path.' --keras_model_type simple_1 --output_loss_history \''.$archive_temp_loss_history_file.'\' --output_autoencoder_model_file_path \''.$archive_temp_autoencoder_output_model_file.'\' ';
    }
    elsif ($model_type eq 'KerasCNNMLPExample') {
        $cmd = $c->config->{python_executable}.' '.$c->config->{rootpath}.'/DroneImageScripts/CNN/KerasCNNSequentialSoftmaxCategorical.py --input_image_label_file \''.$archive_temp_input_file.'\' --input_aux_data_file \''.$archive_temp_input_aux_file.'\' --outfile_path \''.$archive_temp_output_file.'\' --output_model_file_path \''.$archive_temp_output_model_file.'\' '.$log_file_path.' --keras_model_type mlp_cnn_example --output_loss_history \''.$archive_temp_loss_history_file.'\' --output_autoencoder_model_file_path \''.$archive_temp_autoencoder_output_model_file.'\' ';
    }
    else {
        $c->stash->{rest} = {error => "$model_type not supported!"};
        $c->detach();
    }
    print STDERR Dumper $cmd;
    my $status = system("$cmd > /dev/null");

    my $csv = Text::CSV->new({ sep_char => ',' });
    open(my $fh, '<', $archive_temp_output_file)
        or die "Could not open file '$archive_temp_output_file' $!";

        while ( my $row = <$fh> ){
            my @columns;
            if ($csv->parse($row)) {
                @columns = $csv->fields();
            }
            my $line = '';
            foreach (@columns) {
                if ($_ eq ' ') {
                    $line .= '&nbsp;';
                }
                else {
                    $line .= $_;
                }
            }
            push @result_agg, $line;
        }
    close($fh);
    #print STDERR Dumper \@result_agg;

    open($F, ">", $archive_temp_result_agg_file) || die "Can't open file ".$archive_temp_result_agg_file;
        foreach my $data (@result_agg){
            print $F $data;
            print $F "\n";
        }
    close($F);

    my @loss_history;
    open(my $fh3, '<', $archive_temp_loss_history_file)
        or die "Could not open file '$archive_temp_loss_history_file' $!";

        while ( my $row = <$fh3> ){
            my @columns;
            if ($csv->parse($row)) {
                @columns = $csv->fields();
            }
            push @loss_history, $columns[0];
        }
    close($fh3);

    print STDERR "Train loss PLOT $archive_temp_loss_history_file \n";
    my $rmatrix = R::YapRI::Data::Matrix->new({
        name => 'matrix1',
        coln => 1,
        rown => scalar(@loss_history),
        colnames => ["loss"],
        data => \@loss_history
    });

    my $rbase = R::YapRI::Base->new();
    my $r_block = $rbase->create_block('r_block');
    $rmatrix->send_rbase($rbase, 'r_block');
    $r_block->add_command('dataframe.matrix1 <- data.frame(matrix1)');
    $r_block->add_command('dataframe.matrix1$loss <- as.numeric(dataframe.matrix1$loss)');
    $r_block->add_command('png(filename=\''.$archive_temp_loss_history_file.'\')');
    $r_block->add_command('plot(seq(1,length(dataframe.matrix1$loss)), dataframe.matrix1$loss)');
    $r_block->add_command('dev.off()');
    $r_block->run_block();

    my @saved_trained_image_urls;
    if ($c->req->param('save_model') == 1) {
        my $model_name = $c->req->param('model_name');
        my $model_description = $c->req->param('model_description');

        my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_keras_trained', 'project_md_image')->cvterm_id();

        # my $q = "SELECT md_image.image_id FROM metadata.md_image AS md_image
        #     JOIN phenome.project_md_image AS project_md_image ON(project_md_image.image_id = md_image.image_id)
        #     JOIN phenome.stock_image AS stock_image ON(md_image.image_id = stock_image.image_id)
        #     WHERE md_image.obsolete = 'f' AND md_image.md5sum = ? AND project_md_image.type_id = ? AND project_md_image.project_id = ? AND stock_image.stock_id = ?;";
        # my $h = $schema->storage->dbh->prepare($q);

        foreach my $stock_id (keys %output_images){
            my $image_file = $output_images{$stock_id}->{image_file};
            my $field_trial_id = $output_images{$stock_id}->{field_trial_id};
            my $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
            # my $md5checksum = $image->calculate_md5sum($image_file);
            # $h->execute($md5checksum, $linking_table_type_id, $field_trial_id, $stock_id);
            # my ($saved_image_id) = $h->fetchrow_array();

            my $output_image_id;
            my $output_image_url;
            my $output_image_fullpath;
            # if ($saved_image_id) {
            #     print STDERR Dumper "Image $image_file has already been added to the database and will not be added again.";
            #     $image = SGN::Image->new( $schema->storage->dbh, $saved_image_id, $c );
            #     $output_image_fullpath = $image->get_filename('original_converted', 'full');
            #     $output_image_url = $image->get_image_url('original');
            #     $output_image_id = $image->get_image_id();
            # } else {
                $image->set_sp_person_id($user_id);
                my $ret = $image->process_image($image_file, 'project', $field_trial_id, $linking_table_type_id);
                my $stock_associate = $image->associate_stock($stock_id, $user_name);
                $output_image_fullpath = $image->get_filename('original_converted', 'full');
                $output_image_url = $image->get_image_url('original');
                $output_image_id = $image->get_image_id();
            # }
            push @saved_trained_image_urls, $output_image_url;
        }

        _perform_save_trained_keras_cnn_model($c, $schema, $metadata_schema, $phenome_schema, \@field_trial_ids, $archive_temp_output_model_file, $archive_temp_autoencoder_output_model_file, $archive_temp_input_file, $archive_temp_input_aux_file, $model_name, $model_description, $drone_run_ids, $plot_polygon_type_ids, $trait_id, $model_type, \@aux_trait_id, $protocol_id, $use_parents_grm, $user_id, $user_name, $user_role);
    }

    $c->stash->{rest} = { success => 1, results => \@result_agg, model_input_file => $archive_temp_input_file, model_input_aux_file => $archive_temp_input_aux_file, model_temp_file => $archive_temp_output_model_file, model_autoencoder_temp_file => $archive_temp_autoencoder_output_model_file, trait_id => $trait_id, loss_history => \@loss_history, loss_history_file => $archive_temp_loss_history_file_string, saved_trained_image_urls => \@saved_trained_image_urls };
}

sub drone_imagery_save_keras_model : Path('/api/drone_imagery/save_keras_model') : ActionClass('REST') { }
sub drone_imagery_save_keras_model_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $sp_person_id);
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema", undef, $sp_person_id);
    my @field_trial_ids = split ',', $c->req->param('field_trial_ids');
    my $model_file = $c->req->param('model_file');
    my $archive_temp_autoencoder_output_model_file = $c->req->param('model_autoencoder_file');
    my $model_input_file = $c->req->param('model_input_file');
    my $model_input_aux_file = $c->req->param('model_input_aux_file');
    my $model_name = $c->req->param('model_name');
    my $model_description = $c->req->param('model_description');
    my $trait_id = $c->req->param('trait_id');
    my @aux_trait_id = $c->req->param('aux_trait_id[]') ? $c->req->param('aux_trait_id[]') : ();
    my $protocol_id = $c->req->param('protocol_id');
    my $use_parents_grm = $c->req->param('use_parents_grm');
    my $model_type = $c->req->param('model_type');
    my $drone_run_ids = decode_json($c->req->param('drone_run_ids'));
    my $plot_polygon_type_ids = decode_json($c->req->param('plot_polygon_type_ids'));
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    _perform_save_trained_keras_cnn_model($c, $schema, $metadata_schema, $phenome_schema, \@field_trial_ids, $model_file, $model_input_file, $archive_temp_autoencoder_output_model_file, $model_input_aux_file, $model_name, $model_description, $drone_run_ids, $plot_polygon_type_ids, $trait_id, $model_type, \@aux_trait_id, $protocol_id, $use_parents_grm, $user_id, $user_name, $user_role);
}

sub _perform_save_trained_keras_cnn_model {
    my $c = shift;
    my $schema = shift;
    my $metadata_schema = shift;
    my $phenome_schema = shift;
    my $field_trial_ids = shift;
    my $model_file = shift;
    my $archive_temp_autoencoder_output_model_file = shift;
    my $model_input_file = shift;
    my $model_input_aux_file = shift;
    my $model_name = shift;
    my $model_description = shift;
    my $drone_run_ids = shift;
    my $plot_polygon_type_ids = shift;
    my $trait_id = shift;
    my $model_type = shift;
    my $aux_trait_ids = shift;
    my $geno_protocol_id = shift;
    my $use_parents_grm = shift;
    my $user_id = shift;
    my $user_name = shift;
    my $user_role = shift;
    my @field_trial_ids = @$field_trial_ids;
    my $trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $trait_id, 'extended');

    my $keras_cnn_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'trained_keras_cnn_model', 'protocol_type')->cvterm_id();
    my $keras_cnn_experiment_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'analysis_model_experiment', 'experiment_type')->cvterm_id();

    my $m = CXGN::AnalysisModel::SaveModel->new({
        bcs_schema=>$schema,
        metadata_schema=>$metadata_schema,
        phenome_schema=>$phenome_schema,
        archive_path=>$c->config->{archive_path},
        model_name=>$model_name,
        model_description=>$model_description,
        model_language=>'Python',
        model_type_cvterm_id=>$keras_cnn_cvterm_id,
        model_properties=>{variable_name => $trait_name, variable_id => $trait_id, aux_trait_ids => $aux_trait_ids, model_type=>$model_type, image_type=>'standard_4_montage', nd_protocol_id => $geno_protocol_id, use_parents_grm => $use_parents_grm},
        application_name=>'KerasCNNModels',
        application_version=>'V1.01',
        is_public=>1,
        user_id=>$user_id,
        user_role=>$user_role
    });
    my $saved_model = $m->save_model();
    my $saved_model_id = $saved_model->{nd_protocol_id};

    my $analysis_model = CXGN::AnalysisModel::GetModel->new({
        bcs_schema=>$schema,
        metadata_schema=>$metadata_schema,
        phenome_schema=>$phenome_schema,
        nd_protocol_id=>$saved_model_id
    });
    $analysis_model->store_analysis_model_files({
        # project_id => $saved_analysis_id,
        archived_model_file_type=>'trained_keras_cnn_model',
        model_file=>$model_file,
        archived_training_data_file_type=>'trained_keras_cnn_model_input_data_file',
        archived_training_data_file=>$model_input_file,
        archived_auxiliary_files=>[
            {auxiliary_model_file => $archive_temp_autoencoder_output_model_file, auxiliary_model_file_archive_type => 'trained_keras_cnn_autoencoder_model'},
            {auxiliary_model_file => $model_input_aux_file, auxiliary_model_file_archive_type => 'trained_keras_cnn_model_input_aux_data_file'}
        ],
        archive_path=>$c->config->{archive_path},
        user_id=>$user_id,
        user_role=>$user_role
    });

    $c->stash->{rest} = $saved_model;
}

sub drone_imagery_predict_keras_model : Path('/api/drone_imagery/predict_keras_model') : ActionClass('REST') { }
sub drone_imagery_predict_keras_model_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    print STDERR Dumper $c->req->params();
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $sp_person_id);
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $sp_person_id);
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema", undef, $sp_person_id);
    my $people_schema = $c->dbic_schema("CXGN::People::Schema", undef, $sp_person_id);
    my @field_trial_ids = split ',', $c->req->param('field_trial_ids');
    my $model_id = $c->req->param('model_id');
    my $model_prediction_type = $c->req->param('model_prediction_type');
    my $population_id = $c->req->param('population_id');
    my $drone_run_ids = decode_json($c->req->param('drone_run_ids'));
    my $plot_polygon_type_ids = decode_json($c->req->param('plot_polygon_type_ids'));
    my @aux_trait_ids = $c->req->param('aux_trait_ids[]') ? $c->req->param('aux_trait_ids[]') : ();
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my @allowed_composed_cvs = split ',', $c->config->{composable_cvs};
    my $composable_cvterm_delimiter = $c->config->{composable_cvterm_delimiter};
    my $composable_cvterm_format = $c->config->{composable_cvterm_format};

    my $return = _perform_keras_cnn_predict($c, $schema, $metadata_schema, $people_schema, $phenome_schema, \@field_trial_ids, $model_id, $drone_run_ids, $plot_polygon_type_ids, $model_prediction_type, $population_id, \@allowed_composed_cvs, $composable_cvterm_format, $composable_cvterm_delimiter, \@aux_trait_ids, $user_id, $user_name, $user_role);

    $c->stash->{rest} = $return;
}

sub _perform_keras_cnn_predict {
    my $c = shift;
    my $schema = shift;
    my $metadata_schema = shift;
    my $people_schema = shift;
    my $phenome_schema = shift;
    my $field_trial_ids = shift;
    my $model_id = shift;
    my $drone_run_ids = shift;
    my $plot_polygon_type_ids = shift;
    my $model_prediction_type = shift;
    my $population_id = shift;
    my $allowed_composed_cvs = shift;
    my $composable_cvterm_format = shift;
    my $composable_cvterm_delimiter = shift;
    my $aux_trait_ids = shift;
    my $user_id = shift;
    my $user_name = shift;
    my $user_role = shift;
    my @field_trial_ids = @$field_trial_ids;

    my $keras_cnn_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'trained_keras_cnn_model', 'protocol_type')->cvterm_id();
    my $model_properties_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'analysis_model_properties', 'protocol_property')->cvterm_id();
    my $keras_cnn_experiment_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'analysis_model_experiment', 'experiment_type')->cvterm_id();

    my $plot_polygon_rgb_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_rgb_imagery', 'project_md_image')->cvterm_id();
    my $plot_polygon_green_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_rgb_imagery_channel_2', 'project_md_image')->cvterm_id();
    my $plot_polygon_red_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_rgb_imagery_channel_3', 'project_md_image')->cvterm_id();
    my $plot_polygon_red_threshold_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_rgb_background_removed_threshold_imagery_channel_3', 'project_md_image')->cvterm_id();

    if (scalar(@$plot_polygon_type_ids) == 1) {
        #To match standard_4 image types of micasense
        $plot_polygon_type_ids = [$plot_polygon_rgb_cvterm_id, $plot_polygon_green_cvterm_id, $plot_polygon_red_cvterm_id, $plot_polygon_red_threshold_cvterm_id];
    }

    my @accession_ids;
    if ($population_id && $population_id ne 'null') {
        my $accession_manager = CXGN::BreedersToolbox::Accessions->new(schema=>$schema);
        my $population_members = $accession_manager->get_population_members($population_id);
        foreach (@$population_members) {
            push @accession_ids, $_->{stock_id};
        }
    }

    my $images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        drone_run_project_id_list=>$drone_run_ids,
        project_image_type_id_list=>$plot_polygon_type_ids,
        accession_list=>\@accession_ids
    });
    my ($result, $total_count) = $images_search->search();

    my %data_hash;
    my %seen_day_times;
    my %seen_image_types;
    my %seen_drone_run_band_project_ids;
    my %seen_drone_run_project_ids;
    my %seen_field_trial_ids;
    my %seen_stock_ids;
    foreach (@$result) {
        my $image_id = $_->{image_id};
        my $stock_id = $_->{stock_id};
        my $field_trial_id = $_->{trial_id};
        my $project_image_type_id = $_->{project_image_type_id};
        my $drone_run_band_project_id = $_->{drone_run_band_project_id};
        my $drone_run_project_id = $_->{drone_run_project_id};
        my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
        my $image_url = $image->get_image_url("original");
        my $image_fullpath = $image->get_filename('original_converted', 'full');
        my $time_days_cvterm = $_->{drone_run_related_time_cvterm_json}->{day};
        my $time_days = (split '\|', $time_days_cvterm)[0];
        my $days = (split ' ', $time_days)[1];
        $data_hash{$field_trial_id}->{$stock_id}->{$project_image_type_id}->{$days} = {
            image => $image_fullpath,
            drone_run_project_id => $drone_run_project_id
        };
        $seen_day_times{$days}++;
        $seen_image_types{$project_image_type_id}++;
        $seen_drone_run_band_project_ids{$drone_run_band_project_id}++;
        $seen_drone_run_project_ids{$drone_run_project_id}++;
        $seen_field_trial_ids{$field_trial_id}++;
        $seen_stock_ids{$stock_id}++;
    }
    print STDERR Dumper \%seen_day_times;
    undef $result;
    my @seen_plots = keys %seen_stock_ids;

    my $plot_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot_of', 'stock_relationship')->cvterm_id();
    my $plot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id();
    my $replicate_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'replicate', 'stock_property')->cvterm_id;
    my $block_number_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'block', 'stock_property')->cvterm_id();
    my $plot_number_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot number', 'stock_property')->cvterm_id();
    my $row_number_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'row_number', 'stock_property')->cvterm_id();
    my $col_number_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'col_number', 'stock_property')->cvterm_id();

    my $stock_ids_sql = join ',', @seen_plots;
    my $accession_ids_sql = '';
    if (scalar(@accession_ids)>0) {
        my $accession_ids_sql_string = join ',', @accession_ids;
        $accession_ids_sql = " AND germplasm.stock_id IN ($accession_ids_sql_string)";
    }
    my $stock_metadata_q = "SELECT stock.stock_id, stock.uniquename, germplasm.uniquename, germplasm.stock_id, plot_number.value, rep.value, block_number.value, col_number.value, row_number.value
        FROM stock
        JOIN stock_relationship ON(stock.stock_id=stock_relationship.subject_id AND stock_relationship.type_id=$plot_of_cvterm_id)
        JOIN stock AS germplasm ON(stock_relationship.object_id=germplasm.stock_id)
        LEFT JOIN stockprop AS plot_number ON(stock.stock_id=plot_number.stock_id AND plot_number.type_id=$plot_number_cvterm_id)
        LEFT JOIN stockprop AS rep ON(stock.stock_id=rep.stock_id AND rep.type_id=$replicate_cvterm_id)
        LEFT JOIN stockprop AS block_number ON(stock.stock_id=block_number.stock_id AND block_number.type_id=$block_number_cvterm_id)
        LEFT JOIN stockprop AS col_number ON(stock.stock_id=col_number.stock_id AND col_number.type_id=$col_number_cvterm_id)
        LEFT JOIN stockprop AS row_number ON(stock.stock_id=row_number.stock_id AND row_number.type_id=$row_number_cvterm_id)
        WHERE stock.type_id=$plot_cvterm_id AND stock.stock_id IN ($stock_ids_sql) $accession_ids_sql";
    my $stock_metadata_h = $schema->storage->dbh()->prepare($stock_metadata_q);
    $stock_metadata_h->execute();
    my %stock_info;
    while (my ($stock_id, $stock_uniquename, $germplasm_uniquename, $germplasm_stock_id, $plot_number, $rep, $block, $col, $row) = $stock_metadata_h->fetchrow_array()) {
        $stock_info{$stock_id} = {
            uniquename => $stock_uniquename,
            germplasm_uniquename => $germplasm_uniquename,
            germplasm_stock_id => $germplasm_stock_id,
            plot_number => $plot_number,
            replicate => $rep,
            block_number => $block,
            row_number => $row,
            col_number => $col
        };
    }

    my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $female_parent_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'female_parent', 'stock_relationship')->cvterm_id();
    my $male_parent_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'male_parent', 'stock_relationship')->cvterm_id();

    my $plot_list_string = join ',', @seen_plots;
    my $q = "SELECT plot.stock_id, accession.stock_id, female_parent.stock_id, male_parent.stock_id
        FROM stock AS plot
        JOIN stock_relationship AS plot_acc_rel ON(plot_acc_rel.subject_id=plot.stock_id AND plot_acc_rel.type_id=$plot_of_cvterm_id)
        JOIN stock AS accession ON(plot_acc_rel.object_id=accession.stock_id AND accession.type_id=$accession_cvterm_id)
        JOIN stock_relationship AS female_parent_rel ON(accession.stock_id=female_parent_rel.object_id AND female_parent_rel.type_id=$female_parent_cvterm_id)
        JOIN stock AS female_parent ON(female_parent_rel.subject_id = female_parent.stock_id AND female_parent.type_id=$accession_cvterm_id)
        JOIN stock_relationship AS male_parent_rel ON(accession.stock_id=male_parent_rel.object_id AND male_parent_rel.type_id=$male_parent_cvterm_id)
        JOIN stock AS male_parent ON(male_parent_rel.subject_id = male_parent.stock_id AND male_parent.type_id=$accession_cvterm_id)
        WHERE plot.type_id=$plot_cvterm_id AND plot.stock_id IN ($plot_list_string);";
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute();
    my %plot_pedigrees_found = ();
    my %unique_accession_ids_genotypes;
    while (my ($plot_stock_id, $accession_stock_id, $female_parent_stock_id, $male_parent_stock_id) = $h->fetchrow_array()) {
        $unique_accession_ids_genotypes{$accession_stock_id}++;
        $plot_pedigrees_found{$plot_stock_id} = {
            female_stock_id => $female_parent_stock_id,
            male_stock_id => $male_parent_stock_id
        };
    }

    my $m = CXGN::AnalysisModel::GetModel->new({
        bcs_schema=>$schema,
        metadata_schema=>$metadata_schema,
        phenome_schema=>$phenome_schema,
        nd_protocol_id=>$model_id
    });
    my $saved_model_object = $m->get_model();
    print STDERR Dumper $saved_model_object;
    my $trait_id = $saved_model_object->{model_properties}->{variable_id};
    my $trained_trait_name = $saved_model_object->{model_properties}->{variable_name};
    my $aux_trait_ids_previous = $saved_model_object->{model_properties}->{aux_trait_ids};
    my $model_type = $saved_model_object->{model_properties}->{model_type};
    my $nd_protocol_id = $saved_model_object->{model_properties}->{nd_protocol_id};
    my $use_parents_grm = $saved_model_object->{model_properties}->{use_parents_grm};
    my $trained_image_type = $saved_model_object->{model_properties}->{image_type};
    my $model_file = $saved_model_object->{model_files}->{trained_keras_cnn_model};
    my $training_autoencoder_model_file = $saved_model_object->{model_files}->{trained_keras_cnn_autoencoder_model};
    my $training_input_data_file = $saved_model_object->{model_files}->{trained_keras_cnn_model_input_data_file};
    my $training_input_aux_data_file = $saved_model_object->{model_files}->{trained_keras_cnn_model_input_aux_data_file};

    my $dir = $c->tempfiles_subdir('/drone_imagery_keras_cnn_dir');

    my %unique_genotype_accessions;
    if ($nd_protocol_id) {
        my @accession_list = sort keys %unique_accession_ids_genotypes;
        my $geno = CXGN::Genotype::DownloadFactory->instantiate(
            'DosageMatrix',    #can be either 'VCF' or 'DosageMatrix'
            {
                bcs_schema=>$schema,
                people_schema=>$people_schema,
                cache_root_dir=>$c->config->{cache_file_path},
                accession_list=>\@accession_list,
                protocol_id_list=>[$nd_protocol_id],
                compute_from_parents=>$use_parents_grm,
                return_only_first_genotypeprop_for_stock=>1,
                prevent_transpose=>1
            }
        );
        my $file_handle = $geno->download(
            $c->config->{cluster_shared_tempdir},
            $c->config->{backend},
            $c->config->{cluster_host},
            $c->config->{'web_cluster_queue'},
            $c->config->{basepath}
        );
        open my $geno_fh, "<&", $file_handle or die "Can't open output file: $!";
            my $header = <$geno_fh>;
            while (my $row = <$geno_fh>) {
                chomp($row);
                if ($row) {
                    my @line = split "\t", $row;
                    my $stock_id = shift @line;
                    my $out_line = join "\n", @line;
                    if ($out_line) {
                        my $geno_temp_input_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_dir/genoinputfileXXXX');
                        my $status = write_file($geno_temp_input_file, $out_line."\n");
                        $unique_genotype_accessions{$stock_id} = $geno_temp_input_file;
                    }
                }
            }
        close($geno_fh);
        @accession_ids = keys %unique_genotype_accessions;
    }

    my @trait_ids = ($trait_id);
    if (scalar(@$aux_trait_ids) > 0) {
        push @trait_ids, @$aux_trait_ids;
    }

    my $phenotypes_search = CXGN::Phenotypes::SearchFactory->instantiate(
        'MaterializedViewTable',
        {
            bcs_schema=>$schema,
            data_level=>'plot',
            trait_list=>\@trait_ids,
            trial_list=>\@field_trial_ids,
            plot_list=>\@seen_plots,
            accession_list=>\@accession_ids,
            exclude_phenotype_outlier=>0,
            include_timestamp=>0
        }
    );
    my ($data, $unique_traits) = $phenotypes_search->search();

    my %phenotype_data_hash;
    my %aux_data_hash;
    foreach my $d (@$data) {
        foreach my $o (@{$d->{observations}}) {
            if ($o->{trait_id} == $trait_id) {
                $phenotype_data_hash{$d->{observationunit_stock_id}}->{trait_value} = {
                    trait_name => $o->{trait_name},
                    value => $o->{value}
                };
            } else {
                $phenotype_data_hash{$d->{observationunit_stock_id}}->{aux_trait_value}->{$o->{trait_id}} = $o->{value};
            }
        }
        $aux_data_hash{$d->{trial_id}}->{$d->{observationunit_stock_id}} = $d;
    }
    undef $data;

    $dir = $c->tempfiles_subdir('/drone_imagery_keras_cnn_predict_dir');
    my $archive_temp_input_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_predict_dir/inputfileXXXX');
    my $archive_temp_input_aux_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_predict_dir/inputfileXXXX');
    my $archive_temp_output_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_predict_dir/outputfileXXXX');
    my $archive_temp_output_evaluation_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_predict_dir/outputevaluationfileXXXX');
    my $archive_temp_output_activation_file = $c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_predict_dir/outputactivationfileXXXX');
    my $archive_temp_output_corr_plot = $c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_predict_dir/corrplotXXXX').".png";
    my $archive_temp_output_corr_plot_file = $c->config->{basepath}."/".$archive_temp_output_corr_plot;
    $archive_temp_output_activation_file .= ".pdf";
    my $archive_temp_output_activation_file_path = $c->config->{basepath}."/".$archive_temp_output_activation_file;

    my %predicted_stock_ids;
    my %output_images;

    open(my $F_aux, ">", $archive_temp_input_aux_file) || die "Can't open file ".$archive_temp_input_aux_file;
        print $F_aux 'stock_id,value,trait_name,field_trial_id,accession_id,female_id,male_id,output_image_file,genotype_file';
        if (scalar(@$aux_trait_ids)>0) {
            my $aux_trait_counter = 0;
            foreach (@$aux_trait_ids) {
                print $F_aux ",aux_trait_$aux_trait_counter";
                $aux_trait_counter++;
            }
        }
        print $F_aux "\n";

        # LSTM model uses longitudinal time information, so input ordered by field_trial, then stock_id, then by image_type, then by chronological ascending time for each drone run
        if ($model_type eq 'KerasCNNLSTMDenseNet121ImageNetWeights') {
            foreach my $field_trial_id (sort keys %seen_field_trial_ids){
                foreach my $stock_id (sort keys %seen_stock_ids){
                    foreach my $image_type (sort keys %seen_image_types) {
                        my $d = $aux_data_hash{$field_trial_id}->{$stock_id};
                        my $value = $phenotype_data_hash{$stock_id}->{trait_value}->{value};
                        my $trait_name = $phenotype_data_hash{$stock_id}->{trait_value}->{trait_name};
                        my $female_parent_stock_id = $plot_pedigrees_found{$stock_id}->{female_stock_id} || 0;
                        my $male_parent_stock_id = $plot_pedigrees_found{$stock_id}->{male_stock_id} || 0;
                        my $germplasm_id = $d->{germplasm_stock_id};
                        if (defined($value)) {
                            my $archive_temp_output_image_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_predict_dir/outputimagefileXXXX');
                            $archive_temp_output_image_file .= ".png";
                            $output_images{$stock_id} = {
                                image_file => $archive_temp_output_image_file,
                                field_trial_id => $field_trial_id
                            };
                            $predicted_stock_ids{$stock_id}++;
                            my $geno_file = $unique_genotype_accessions{$germplasm_id} || '';

                            print $F_aux "$stock_id,";
                            print $F_aux "$value,";
                            print $F_aux "$trait_name,";
                            print $F_aux "$field_trial_id,";
                            print $F_aux "$germplasm_id,";
                            print $F_aux "$female_parent_stock_id,";
                            print $F_aux "$male_parent_stock_id,";
                            print $F_aux "$archive_temp_output_image_file,";
                            print $F_aux "$geno_file";
                            if (scalar(@$aux_trait_ids)>0) {
                                print $F_aux ',';
                                my @aux_values;
                                foreach my $aux_trait (@$aux_trait_ids) {
                                    my $aux_value = $phenotype_data_hash{$stock_id} ? $phenotype_data_hash{$stock_id}->{aux_trait_value}->{$aux_trait} : '';
                                    if (!$aux_value) {
                                        $aux_value = '';
                                    }
                                    push @aux_values, $aux_value;
                                }
                                my $aux_values_string = scalar(@aux_values)>0 ? join ',', @aux_values : '';
                                print $F_aux $aux_values_string;
                            }
                            print $F_aux "\n";
                        }
                    }
                }
            }
        }
        #Non-LSTM models group image types for each stock into a single montage, so the input is ordered by field trial, then ascending chronological time, then by stock_id, and then by image_type.
        else {
            foreach my $field_trial_id (sort keys %seen_field_trial_ids){
                foreach my $day_time (sort { $a <=> $b } keys %seen_day_times) {
                    foreach my $stock_id (sort keys %seen_stock_ids){
                        my $d = $aux_data_hash{$field_trial_id}->{$stock_id};
                        my $value = $phenotype_data_hash{$stock_id}->{trait_value}->{value};
                        my $trait_name = $phenotype_data_hash{$stock_id}->{trait_value}->{trait_name};
                        my $female_parent_stock_id = $plot_pedigrees_found{$stock_id}->{female_stock_id} || 0;
                        my $male_parent_stock_id = $plot_pedigrees_found{$stock_id}->{male_stock_id} || 0;
                        my $germplasm_id = $d->{germplasm_stock_id};
                        if (defined($value)) {
                            my $archive_temp_output_image_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_predict_dir/outputimagefileXXXX');
                            $archive_temp_output_image_file .= ".png";
                            $output_images{$stock_id} = {
                                image_file => $archive_temp_output_image_file,
                                field_trial_id => $field_trial_id
                            };
                            $predicted_stock_ids{$stock_id}++;
                            my $geno_file = $unique_genotype_accessions{$germplasm_id} || '';

                            print $F_aux "$stock_id,";
                            print $F_aux "$value,";
                            print $F_aux "$trait_name,";
                            print $F_aux "$field_trial_id,";
                            print $F_aux "$d->{germplasm_stock_id},";
                            print $F_aux "$female_parent_stock_id,";
                            print $F_aux "$male_parent_stock_id,";
                            print $F_aux "$archive_temp_output_image_file,";
                            print $F_aux "$geno_file";
                            if (scalar(@$aux_trait_ids)>0) {
                                print $F_aux ',';
                                my @aux_values;
                                foreach my $aux_trait (@$aux_trait_ids) {
                                    my $aux_value = $phenotype_data_hash{$stock_id} ? $phenotype_data_hash{$stock_id}->{aux_trait_value}->{$aux_trait} : '';
                                    if (!$aux_value) {
                                        $aux_value = '';
                                    }
                                    push @aux_values, $aux_value;
                                }
                                my $aux_values_string = scalar(@aux_values)>0 ? join ',', @aux_values : '';
                                print $F_aux $aux_values_string;
                            }
                            print $F_aux "\n";
                        }
                    }
                }
            }
        }
    close($F_aux);

    open(my $F, ">", $archive_temp_input_file) || die "Can't open file ".$archive_temp_input_file;
        print $F "stock_id,image_path,image_type,day,drone_run_project_id,value\n";

        # LSTM model uses longitudinal time information, so input ordered by field_trial, then stock_id, then by image_type, then by chronological ascending time for each drone run
        if ($model_type eq 'KerasCNNLSTMDenseNet121ImageNetWeights') {
            foreach my $field_trial_id (sort keys %seen_field_trial_ids){
                foreach my $stock_id (sort keys %seen_stock_ids){
                    foreach my $image_type (sort keys %seen_image_types) {
                        foreach my $day_time (sort { $a <=> $b } keys %seen_day_times) {
                            my $data = $data_hash{$field_trial_id}->{$stock_id}->{$image_type}->{$day_time};
                            my $image_fullpath = $data->{image};
                            my $drone_run_project_id = $data->{drone_run_project_id};
                            my $value = $phenotype_data_hash{$stock_id}->{trait_value}->{value};
                            if (defined($value)) {
                                print $F "$stock_id,";
                                print $F "$image_fullpath,";
                                print $F "$image_type,";
                                print $F "$day_time,";
                                print $F "$drone_run_project_id,";
                                print $F "$value\n";
                            }
                        }
                    }
                }
            }
        }
        #Non-LSTM models group image types for each stock into a single montage, so the input is ordered by field trial, then ascending chronological time, then by stock_id, and then by image_type.
        else {
            foreach my $field_trial_id (sort keys %seen_field_trial_ids) {
                foreach my $day_time (sort { $a <=> $b } keys %seen_day_times) {
                    foreach my $stock_id (sort keys %seen_stock_ids){
                        foreach my $image_type (sort keys %seen_image_types) {
                            my $data = $data_hash{$field_trial_id}->{$stock_id}->{$image_type}->{$day_time};
                            my $image_fullpath = $data->{image};
                            my $drone_run_project_id = $data->{drone_run_project_id};
                            my $value = $phenotype_data_hash{$stock_id}->{trait_value}->{value};
                            if (defined($value)) {
                                print $F "$stock_id,";
                                print $F "$image_fullpath,";
                                print $F "$image_type,";
                                print $F "$day_time,";
                                print $F "$drone_run_project_id,";
                                print $F "$value\n";
                            }
                        }
                    }
                }
            }
        }
    close($F);

    undef %data_hash;
    undef %aux_data_hash;

    print STDERR "Predicting $trained_trait_name from Keras CNN $model_type\n";

    my $log_file_path = '';
    if ($c->config->{error_log}) {
        $log_file_path = ' --log_file_path \''.$c->config->{error_log}.'\'';
    }

    my $cmd = $c->config->{python_executable}.' '.$c->config->{rootpath}.'/DroneImageScripts/CNN/PredictKerasCNN.py --input_image_label_file \''.$archive_temp_input_file.'\' --input_image_aux_file \''.$archive_temp_input_aux_file.'\' --outfile_path \''.$archive_temp_output_file.'\' --input_model_file_path \''.$model_file.'\' --input_autoencoder_model_file_path \''.$training_autoencoder_model_file.'\' --keras_model_type_name \''.$model_type.'\' --training_data_input_file \''.$training_input_data_file.'\' --training_aux_data_input_file \''.$training_input_aux_data_file.'\' --outfile_evaluation_path \''.$archive_temp_output_evaluation_file.'\' --outfile_activation_path \''.$archive_temp_output_activation_file_path.'\' '.$log_file_path;
    print STDERR Dumper $cmd;
    my $status = system("$cmd > /dev/null");

    my @saved_trained_image_urls;
    my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_keras_trained', 'project_md_image')->cvterm_id();
    foreach my $stock_id (keys %output_images){
        my $image_file = $output_images{$stock_id}->{image_file};
        my $field_trial_id = $output_images{$stock_id}->{field_trial_id};
        my $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
        # my $md5checksum = $image->calculate_md5sum($image_file);
        # my $q = "SELECT md_image.image_id FROM metadata.md_image AS md_image
        #     JOIN phenome.project_md_image AS project_md_image ON(project_md_image.image_id = md_image.image_id)
        #     JOIN phenome.stock_image AS stock_image ON(md_image.image_id = stock_image.image_id)
        #     WHERE md_image.obsolete = 'f' AND md_image.md5sum = ? AND project_md_image.type_id = ? AND project_md_image.project_id = ? AND stock_image.stock_id = ?;";
        # my $h = $schema->storage->dbh->prepare($q);
        # $h->execute($md5checksum, $linking_table_type_id, $field_trial_id, $stock_id);
        # my ($saved_image_id) = $h->fetchrow_array();

        my $output_image_id;
        my $output_image_url;
        my $output_image_fullpath;
        # if ($saved_image_id) {
        #     print STDERR Dumper "Image $image_file has already been added to the database and will not be added again.";
        #     $image = SGN::Image->new( $schema->storage->dbh, $saved_image_id, $c );
        #     $output_image_fullpath = $image->get_filename('original_converted', 'full');
        #     $output_image_url = $image->get_image_url('original');
        #     $output_image_id = $image->get_image_id();
        # } else {
            $image->set_sp_person_id($user_id);
            my $ret = $image->process_image($image_file, 'project', $field_trial_id, $linking_table_type_id);
            my $stock_associate = $image->associate_stock($stock_id, $user_name);
            $output_image_fullpath = $image->get_filename('original_converted', 'full');
            $output_image_url = $image->get_image_url('original');
            $output_image_id = $image->get_image_id();
        # }
        $output_images{$stock_id}->{image_id} = $output_image_id;
        push @saved_trained_image_urls, $output_image_url;
    }

    my @result_agg;
    my @data_matrix;
    my $data_matrix_rows = 0;
    my @data_matrix_colnames = ('stock_id', 'germplasm_stock_id', 'replicate', 'block_number', 'row_number', 'col_number', 'growing_degree_days', 'previous_value', 'prediction');
    my @simple_data_matrix;

    my @predictions;
    my $csv = Text::CSV->new({ sep_char => ',' });
    open(my $fh, '<', $archive_temp_output_file)
        or die "Could not open file '$archive_temp_output_file' $!";

        print STDERR "Opened $archive_temp_output_file\n";
        while ( my $row = <$fh> ){
            my @columns;
            if ($csv->parse($row)) {
                @columns = $csv->fields();
            }
            my $prediction = shift @columns;
            push @predictions, $prediction;
        }
    close($fh);
    #print STDERR Dumper \@predictions;

    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();

    my $keras_predict_image_type_id;
    my $keras_predict_model_type_id;
    if ($trained_image_type eq 'standard_4_montage') {
        $keras_predict_image_type_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Standard 4 Image Montage|ISOL:0000324')->cvterm_id;
    }
    if ($model_type eq 'KerasTunerCNNSequentialSoftmaxCategorical') {
        $keras_predict_model_type_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Keras Predicted KerasTunerCNNSequentialSoftmaxCategorical|ISOL:0000326')->cvterm_id;
    }
    if ($model_type eq 'SimpleKerasTunerCNNSequentialSoftmaxCategorical') {
        $keras_predict_model_type_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Keras Predicted SimpleKerasTunerCNNSequentialSoftmaxCategorical|ISOL:0000327')->cvterm_id;
    }
    if ($model_type eq 'KerasCNNInceptionResNetV2ImageNetWeights') {
        $keras_predict_model_type_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Keras Predicted KerasCNNInceptionResNetV2ImageNetWeights|ISOL:0000328')->cvterm_id;
    }
    if ($model_type eq 'KerasCNNInceptionResNetV2') {
        $keras_predict_model_type_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Keras Predicted KerasCNNInceptionResNetV2|ISOL:0000329')->cvterm_id;
    }
    if ($model_type eq 'KerasCNNLSTMDenseNet121ImageNetWeights') {
        $keras_predict_model_type_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Keras Predicted KerasCNNLSTMDenseNet121ImageNetWeights|ISOL:0000330')->cvterm_id;
    }
    if ($model_type eq 'KerasCNNDenseNet121ImageNetWeights') {
        $keras_predict_model_type_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Keras Predicted KerasCNNDenseNet121ImageNetWeights|ISOL:0000331')->cvterm_id;
    }
    if ($model_type eq 'KerasCNNSequentialSoftmaxCategorical') {
        $keras_predict_model_type_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Keras Predicted KerasCNNSequentialSoftmaxCategorical|ISOL:0000332')->cvterm_id;
    }
    if ($model_type eq 'KerasCNNMLPExample') {
        $keras_predict_model_type_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Keras Predicted KerasCNNMLPExample|ISOL:0000333')->cvterm_id;
    }

    my $trained_trait_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, $trained_trait_name)->cvterm_id;

    my $traits = SGN::Model::Cvterm->get_traits_from_component_categories($schema, $allowed_composed_cvs, $composable_cvterm_delimiter, $composable_cvterm_format, {
        object => [],
        attribute => [$keras_predict_image_type_id],
        method => [],
        unit => [],
        trait => [$trained_trait_cvterm_id],
        tod => [$keras_predict_model_type_id],
        toy => [],
        gen => [],
    });
    my $existing_traits = $traits->{existing_traits};
    my $new_traits = $traits->{new_traits};
    # print STDERR Dumper $new_traits;
    # print STDERR Dumper $existing_traits;
    my %new_trait_names;
    foreach (@$new_traits) {
        my $components = $_->[0];
        $new_trait_names{$_->[1]} = join ',', @$components;
    }

    my $onto = CXGN::Onto->new( { schema => $schema } );
    my $new_terms = $onto->store_composed_term(\%new_trait_names);

    my $keras_predict_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, [$trained_trait_cvterm_id, $keras_predict_image_type_id, $keras_predict_model_type_id]);
    my $keras_predict_composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $keras_predict_composed_cvterm_id, 'extended');

    my %keras_features_phenotype_data;
    my $iter = 0;
    my %seen_stock_names;
    #print STDERR Dumper \%phenotype_data_hash;
    foreach my $sorted_stock_id (sort keys %predicted_stock_ids) {
        my $prediction = $predictions[$iter];
        my $stock_uniquename = $stock_info{$sorted_stock_id}->{uniquename};
        my $previous_value = $phenotype_data_hash{$sorted_stock_id} ? $phenotype_data_hash{$sorted_stock_id}->{trait_value}->{value} : '';
        my $image_id = $output_images{$sorted_stock_id}->{image_id};

        $keras_features_phenotype_data{$stock_uniquename}->{$keras_predict_composed_trait_name} = [$prediction, $timestamp, $user_name, '', $image_id];
        $seen_stock_names{$stock_uniquename}++;

        if ($previous_value){
            push @data_matrix, ($sorted_stock_id, $stock_info{$sorted_stock_id}->{germplasm_stock_id}, $stock_info{$sorted_stock_id}->{replicate}, $stock_info{$sorted_stock_id}->{block_number}, $stock_info{$sorted_stock_id}->{row_number}, $stock_info{$sorted_stock_id}->{col_number}, $stock_info{$sorted_stock_id}->{drone_run_related_time_cvterm_json}->{gdd_average_temp}, $previous_value, $prediction);
            push @simple_data_matrix, ($previous_value, $prediction);
            $data_matrix_rows++;
        }
        push @result_agg, [$stock_uniquename, $sorted_stock_id, $prediction, $previous_value];
        $iter++;
    }

    my @traits_seen = (
        $keras_predict_composed_trait_name
    );

    print STDERR "Read $iter lines in results file\n";

    if ($iter > 0) {
        my %phenotype_metadata = (
            'archived_file' => $archive_temp_output_file,
            'archived_file_type' => 'image_keras_prediction_output',
            'operator' => $user_name,
            'date' => $timestamp
        );
        my @plot_units_seen = keys %seen_stock_names;

        my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new({
            basepath=>$c->config->{basepath},
            dbhost=>$c->config->{dbhost},
            dbname=>$c->config->{dbname},
            dbuser=>$c->config->{dbuser},
            dbpass=>$c->config->{dbpass},
            bcs_schema=>$schema,
            metadata_schema=>$metadata_schema,
            phenome_schema=>$phenome_schema,
            user_id=>$user_id,
            stock_list=>\@plot_units_seen,
            trait_list=>\@traits_seen,
            values_hash=>\%keras_features_phenotype_data,
            has_timestamps=>1,
            metadata_hash=>\%phenotype_metadata,
            ignore_new_values=>undef,
            overwrite_values=>1,
            composable_validation_check_name=>$c->config->{composable_validation_check_name},
            allow_repeat_measures=>$c->config->{allow_repeat_measures}
        });
        my ($verified_warning, $verified_error) = $store_phenotypes->verify();
        my ($stored_phenotype_error, $stored_phenotype_success) = $store_phenotypes->store();

        my $bs = CXGN::BreederSearch->new( { dbh=>$c->dbc->dbh, dbname=>$c->config->{dbname}, } );
        my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'fullview', 'nonconcurrent', $c->config->{basepath});
    }

    undef %data_hash;
    undef %phenotype_data_hash;

    print STDERR "CNN Prediction Correlation\n";
    my @model_results;
    my @simple_data_matrix_colnames = ("previous_value", "prediction");
    print STDERR Dumper \@simple_data_matrix;
    my $rmatrix = R::YapRI::Data::Matrix->new({
        name => 'matrix1',
        coln => scalar(@simple_data_matrix_colnames),
        rown => $data_matrix_rows,
        colnames => \@simple_data_matrix_colnames,
        data => \@simple_data_matrix
    });

    print STDERR "CORR PLOT $archive_temp_output_corr_plot_file \n";
    my $rbase = R::YapRI::Base->new();
    my $r_block = $rbase->create_block('r_block');
    $rmatrix->send_rbase($rbase, 'r_block');
    $r_block->add_command('dataframe.matrix1 <- data.frame(matrix1)');
    $r_block->add_command('dataframe.matrix1$previous_value <- as.numeric(dataframe.matrix1$previous_value)');
    $r_block->add_command('dataframe.matrix1$prediction <- as.numeric(dataframe.matrix1$prediction)');
    $r_block->add_command('mixed.lmer.matrix <- matrix(NA,nrow = 1, ncol = 1)');
    $r_block->add_command('mixed.lmer.matrix[1,1] <- cor(dataframe.matrix1$previous_value, dataframe.matrix1$prediction)');

    $r_block->add_command('png(filename=\''.$archive_temp_output_corr_plot_file.'\')');
    $r_block->add_command('plot(dataframe.matrix1$previous_value, dataframe.matrix1$prediction)');
    $r_block->add_command('dev.off()');
    $r_block->run_block();
    my $result_matrix = R::YapRI::Data::Matrix->read_rbase($rbase,'r_block','mixed.lmer.matrix');
    print STDERR Dumper $result_matrix;
    push @model_results, $result_matrix->{data}->[0];

    my @data_matrix_clean;
    foreach (@data_matrix) {
        if ($_) {
            push @data_matrix_clean, $_ + 0;
        }
        else {
            push @data_matrix_clean, 'NA';
        }
    }
    #print STDERR Dumper \@data_matrix_clean;

    if ($model_prediction_type eq 'cnn_prediction_mixed_model') {
        print STDERR "CNN Prediction Mixed Model\n";

        my $rmatrix = R::YapRI::Data::Matrix->new({
            name => 'matrix1',
            coln => scalar(@data_matrix_colnames),
            rown => $data_matrix_rows,
            colnames => \@data_matrix_colnames,
            data => \@data_matrix_clean
        });

        my $rbase = R::YapRI::Base->new();
        my $r_block = $rbase->create_block('r_block');
        $rmatrix->send_rbase($rbase, 'r_block');
        $r_block->add_command('library(lme4)');
        $r_block->add_command('dataframe.matrix1 <- data.frame(matrix1)');
        $r_block->add_command('dataframe.matrix1$previous_value <- as.numeric(dataframe.matrix1$previous_value)');
        $r_block->add_command('dataframe.matrix1$prediction <- as.numeric(dataframe.matrix1$prediction)');
        $r_block->add_command('mixed.lmer <- lmer(previous_value ~ prediction + replicate + (1|germplasm_stock_id), data = dataframe.matrix1, na.action = na.omit )');
        # $r_block->add_command('mixed.lmer.summary <- summary(mixed.lmer)');
        $r_block->add_command('mixed.lmer.matrix <- matrix(NA,nrow = 1, ncol = 2)');
        $r_block->add_command('mixed.lmer.matrix[1,1] <- cor(predict(mixed.lmer), dataframe.matrix1$previous_value)');

        $r_block->add_command('mixed.lmer <- lmer(prediction ~ replicate + (1|germplasm_stock_id), data = dataframe.matrix1 )');
        # $r_block->add_command('mixed.lmer.summary <- summary(mixed.lmer)');
        $r_block->add_command('mixed.lmer.matrix[1,2] <- cor(predict(mixed.lmer), dataframe.matrix1$previous_value)');
        $r_block->run_block();
        my $result_matrix = R::YapRI::Data::Matrix->read_rbase($rbase,'r_block','mixed.lmer.matrix');
        print STDERR Dumper $result_matrix;
        push @model_results, $result_matrix->{data}->[0];
        push @model_results, $result_matrix->{data}->[1];
    }

    my @evaluation_results;
    open(my $fh_eval, '<', $archive_temp_output_evaluation_file)
        or die "Could not open file '$archive_temp_output_evaluation_file' $!";

        while ( my $row = <$fh_eval> ){
            my @columns;
            if ($csv->parse($row)) {
                @columns = $csv->fields();
            }
            my $line = '';
            foreach (@columns) {
                if ($_ eq ' ') {
                    $line .= '&nbsp;';
                }
                else {
                    $line .= $_;
                }
            }
            push @evaluation_results, $line;
        }
    close($fh_eval);

    return { success => 1, results => \@result_agg, evaluation_results => \@evaluation_results, activation_output => $archive_temp_output_activation_file, corr_plot => $archive_temp_output_corr_plot, trained_trait_name => $trained_trait_name, mixed_model_results => \@model_results };
}

sub drone_imagery_autoencoder_keras_vi_model : Path('/api/drone_imagery/perform_autoencoder_vi') : ActionClass('REST') { }
sub drone_imagery_autoencoder_keras_vi_model_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    print STDERR Dumper $c->req->params();
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $sp_person_id);
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $sp_person_id);
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema", undef, $sp_person_id);
    my $people_schema = $c->dbic_schema("CXGN::People::Schema", undef, $sp_person_id);
    my @training_field_trial_ids = split ',', $c->req->param('training_field_trial_ids');
    my @field_trial_ids = split ',', $c->req->param('field_trial_ids');
    my $autoencoder_model_type = $c->req->param('autoencoder_model_type');
    my $time_cvterm_id = $c->req->param('time_cvterm_id');
    my $training_drone_run_ids = decode_json($c->req->param('training_drone_run_ids'));
    my $drone_run_ids = decode_json($c->req->param('drone_run_ids'));
    my $training_plot_polygon_type_ids = decode_json($c->req->param('training_plot_polygon_type_ids'));
    my $plot_polygon_type_ids = decode_json($c->req->param('plot_polygon_type_ids'));
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    if (scalar(@$drone_run_ids) > 1) {
        $c->stash->{rest} = {error => "Please select only one drone run to predict on!"};
        $c->detach();
    }

    my @allowed_composed_cvs = split ',', $c->config->{composable_cvs};
    my $composable_cvterm_delimiter = $c->config->{composable_cvterm_delimiter};
    my $composable_cvterm_format = $c->config->{composable_cvterm_format};

    my $return = _perform_autoencoder_keras_cnn_vi($c, $schema, $metadata_schema, $people_schema, $phenome_schema, \@training_field_trial_ids, \@field_trial_ids, $training_drone_run_ids, $drone_run_ids, $training_plot_polygon_type_ids, $plot_polygon_type_ids, $autoencoder_model_type, \@allowed_composed_cvs, $composable_cvterm_format, $composable_cvterm_delimiter, $time_cvterm_id, $user_id, $user_name, $user_role);

    $c->stash->{rest} = $return;
}

sub _perform_autoencoder_keras_cnn_vi {
    my $c = shift;
    my $schema = shift;
    my $metadata_schema = shift;
    my $people_schema = shift;
    my $phenome_schema = shift;
    my $training_field_trial_ids = shift;
    my $field_trial_ids = shift;
    my $training_drone_run_ids = shift;
    my $drone_run_ids = shift;
    my $training_plot_polygon_type_ids = shift;
    my $plot_polygon_type_ids = shift;
    my $autoencoder_model_type = shift;
    my $allowed_composed_cvs = shift;
    my $composable_cvterm_format = shift;
    my $composable_cvterm_delimiter = shift;
    my $time_cvterm_id = shift;
    my $user_id = shift;
    my $user_name = shift;
    my $user_role = shift;
    my @field_trial_ids = @$field_trial_ids;

    my $keras_cnn_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'trained_keras_cnn_model', 'protocol_type')->cvterm_id();
    my $keras_cnn_experiment_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'analysis_model_experiment', 'experiment_type')->cvterm_id();

    my $training_images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        drone_run_project_id_list=>$training_drone_run_ids,
        project_image_type_id_list=>$training_plot_polygon_type_ids
    });
    my ($training_result, $training_total_count) = $training_images_search->search();

    if ($training_total_count == 0) {
        return {error => "No plot-polygon images for training!"};
    }

    my $images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        drone_run_project_id_list=>$drone_run_ids,
        project_image_type_id_list=>$plot_polygon_type_ids
    });
    my ($result, $total_count) = $images_search->search();

    if ($total_count == 0) {
        return {error => "No plot-polygon images for predicting!"};
    }

    my %training_data_hash;
    my %training_seen_day_times;
    my %training_seen_image_types;
    my %training_seen_drone_run_band_project_ids;
    my %training_seen_drone_run_project_ids;
    my %training_seen_field_trial_ids;
    my %training_seen_stock_ids;
    foreach (@$training_result) {
        my $image_id = $_->{image_id};
        my $stock_id = $_->{stock_id};
        my $field_trial_id = $_->{trial_id};
        my $project_image_type_id = $_->{project_image_type_id};
        my $drone_run_band_project_id = $_->{drone_run_band_project_id};
        my $drone_run_project_id = $_->{drone_run_project_id};
        my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
        my $image_url = $image->get_image_url("original");
        my $image_fullpath = $image->get_filename('original_converted', 'full');
        my $time_days_cvterm = $_->{drone_run_related_time_cvterm_json}->{day};
        my $time_days = (split '\|', $time_days_cvterm)[0];
        my $days = (split ' ', $time_days)[1];
        push @{$training_data_hash{$field_trial_id}->{$drone_run_project_id}->{$stock_id}->{$project_image_type_id}->{$days}}, {
            image => $image_fullpath,
            drone_run_project_id => $drone_run_project_id
        };
        $training_seen_day_times{$days}++;
        $training_seen_image_types{$project_image_type_id}++;
        $training_seen_drone_run_band_project_ids{$drone_run_band_project_id}++;
        $training_seen_drone_run_project_ids{$drone_run_project_id}++;
        $training_seen_field_trial_ids{$field_trial_id}++;
        $training_seen_stock_ids{$stock_id}++;
    }
    print STDERR Dumper \%training_seen_day_times;
    undef $training_result;
    my @training_seen_plots = keys %training_seen_stock_ids;

    my %data_hash;
    my %seen_day_times;
    my %seen_image_types;
    my %seen_drone_run_band_project_ids;
    my %seen_drone_run_project_ids;
    my %seen_field_trial_ids;
    my %seen_stock_ids;
    foreach (@$result) {
        my $image_id = $_->{image_id};
        my $stock_id = $_->{stock_id};
        my $field_trial_id = $_->{trial_id};
        my $project_image_type_id = $_->{project_image_type_id};
        my $drone_run_band_project_id = $_->{drone_run_band_project_id};
        my $drone_run_project_id = $_->{drone_run_project_id};
        my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
        my $image_url = $image->get_image_url("original");
        my $image_fullpath = $image->get_filename('original_converted', 'full');
        my $time_days_cvterm = $_->{drone_run_related_time_cvterm_json}->{day};
        my $time_days = (split '\|', $time_days_cvterm)[0];
        my $days = (split ' ', $time_days)[1];
        push @{$data_hash{$field_trial_id}->{$drone_run_project_id}->{$stock_id}->{$project_image_type_id}->{$days}}, {
            image => $image_fullpath,
            drone_run_project_id => $drone_run_project_id
        };
        $seen_day_times{$days}++;
        $seen_image_types{$project_image_type_id}++;
        $seen_drone_run_band_project_ids{$drone_run_band_project_id}++;
        $seen_drone_run_project_ids{$drone_run_project_id}++;
        $seen_field_trial_ids{$field_trial_id}++;
        $seen_stock_ids{$stock_id}++;
    }
    print STDERR Dumper \%seen_day_times;
    undef $result;
    my @seen_plots = keys %seen_stock_ids;

    my $plot_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot_of', 'stock_relationship')->cvterm_id();
    my $plot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id();
    my $replicate_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'replicate', 'stock_property')->cvterm_id;
    my $block_number_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'block', 'stock_property')->cvterm_id();
    my $plot_number_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot number', 'stock_property')->cvterm_id();
    my $row_number_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'row_number', 'stock_property')->cvterm_id();
    my $col_number_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'col_number', 'stock_property')->cvterm_id();

    my $stock_ids_sql = join ',', @seen_plots;
    my %seen_accession_names;
    my $stock_metadata_q = "SELECT stock.stock_id, stock.uniquename, germplasm.uniquename, germplasm.stock_id, plot_number.value, rep.value, block_number.value, col_number.value, row_number.value
        FROM stock
        JOIN stock_relationship ON(stock.stock_id=stock_relationship.subject_id AND stock_relationship.type_id=$plot_of_cvterm_id)
        JOIN stock AS germplasm ON(stock_relationship.object_id=germplasm.stock_id)
        LEFT JOIN stockprop AS plot_number ON(stock.stock_id=plot_number.stock_id AND plot_number.type_id=$plot_number_cvterm_id)
        LEFT JOIN stockprop AS rep ON(stock.stock_id=rep.stock_id AND rep.type_id=$replicate_cvterm_id)
        LEFT JOIN stockprop AS block_number ON(stock.stock_id=block_number.stock_id AND block_number.type_id=$block_number_cvterm_id)
        LEFT JOIN stockprop AS col_number ON(stock.stock_id=col_number.stock_id AND col_number.type_id=$col_number_cvterm_id)
        LEFT JOIN stockprop AS row_number ON(stock.stock_id=row_number.stock_id AND row_number.type_id=$row_number_cvterm_id)
        WHERE stock.type_id=$plot_cvterm_id AND stock.stock_id IN ($stock_ids_sql) ";
    my $stock_metadata_h = $schema->storage->dbh()->prepare($stock_metadata_q);
    $stock_metadata_h->execute();
    my %stock_info;
    while (my ($stock_id, $stock_uniquename, $germplasm_uniquename, $germplasm_stock_id, $plot_number, $rep, $block, $col, $row) = $stock_metadata_h->fetchrow_array()) {
        $stock_info{$stock_id} = {
            stock_uniquename => $stock_uniquename,
            germplasm_uniquename => $germplasm_uniquename,
            germplasm_stock_id => $germplasm_stock_id,
            plot_number => $plot_number,
            replicate => $rep,
            block_number => $block,
            row_number => $row,
            col_number => $col
        };
        $seen_accession_names{$germplasm_uniquename}++;
    }
    my @unique_accession_names = keys %seen_accession_names;

    my $dir = $c->tempfiles_subdir('/drone_imagery_keras_cnn_autoencoder_dir');
    my $archive_training_temp_input_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_autoencoder_dir/inputtrainingfileXXXX');
    my $archive_temp_input_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_autoencoder_dir/inputfileXXXX');
    my $archive_temp_output_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_autoencoder_dir/outputfileXXXX');
    my $archive_temp_output_images_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_autoencoder_dir/outputfileXXXX');

    my %predicted_stock_ids;
    my %output_images;

    my @autoencoder_vi_image_type_ids = (
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_red_imagery', 'project_md_image')->cvterm_id(),
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_red_edge_imagery', 'project_md_image')->cvterm_id(),
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_nir_imagery', 'project_md_image')->cvterm_id()
    );

    open(my $Fi, ">", $archive_training_temp_input_file) || die "Can't open file ".$archive_training_temp_input_file;
        print $Fi "stock_id\tred_image_string\tred_edge_image_string\tnir_image_string\n";

        foreach my $field_trial_id (sort keys %training_seen_field_trial_ids) {
            foreach my $drone_run_project_id (sort keys %training_seen_drone_run_project_ids) {
                foreach my $stock_id (sort keys %training_seen_stock_ids) {
                    print $Fi "$stock_id";
                    foreach my $image_type (@autoencoder_vi_image_type_ids) {
                        my @imgs;
                        foreach my $day_time (sort { $a <=> $b } keys %training_seen_day_times) {
                            my $images = $training_data_hash{$field_trial_id}->{$drone_run_project_id}->{$stock_id}->{$image_type}->{$day_time};
                            foreach (@$images) {
                                push @imgs, $_->{image};
                            }
                        }
                        my $img_string = join ',', @imgs;
                        print $Fi "\t$img_string";
                    }
                    print $Fi "\n";
                }
            }
        }
    close($Fi);

    open(my $F, ">", $archive_temp_input_file) || die "Can't open file ".$archive_temp_input_file;
        print $F "stock_id\tred_image_string\tred_edge_image_string\tnir_image_string\n";

        foreach my $field_trial_id (sort keys %seen_field_trial_ids) {
            foreach my $drone_run_project_id (sort keys %seen_drone_run_project_ids) {
                foreach my $stock_id (sort keys %seen_stock_ids) {
                    print $F "$stock_id";
                    foreach my $image_type (@autoencoder_vi_image_type_ids) {
                        my @imgs;
                        foreach my $day_time (sort { $a <=> $b } keys %seen_day_times) {
                            my $images = $data_hash{$field_trial_id}->{$drone_run_project_id}->{$stock_id}->{$image_type}->{$day_time};
                            foreach (@$images) {
                                push @imgs, $_->{image};
                            }
                        }
                        my $img_string = join ',', @imgs;
                        print $F "\t$img_string";
                    }
                    print $F "\n";
                }
            }
        }
    close($F);

    open(my $F2, ">", $archive_temp_output_images_file) || die "Can't open file ".$archive_temp_output_images_file;
        print $F2 "stock_id\tred_image_encoded\tred_edge_image_encoded\tnir_image_encoded\n";

        foreach my $field_trial_id (sort keys %seen_field_trial_ids) {
            foreach my $stock_id (sort keys %seen_stock_ids) {
                my $archive_temp_output_ndvi_image_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_autoencoder_dir/outputimagefileXXXX');
                $archive_temp_output_ndvi_image_file .= ".png";
                my $archive_temp_output_ndre_image_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_autoencoder_dir/outputimagefileXXXX');
                $archive_temp_output_ndre_image_file .= ".png";

                my @autoencoded_image_files = ($archive_temp_output_ndvi_image_file, $archive_temp_output_ndre_image_file);
                $output_images{$stock_id} = \@autoencoded_image_files;
                my $img_string = join "\t", @autoencoded_image_files;
                print $F2 "$stock_id\t$img_string\n";
            }
        }
    close($F2);

    undef %data_hash;

    my $log_file_path = '';
    if ($c->config->{error_log}) {
        $log_file_path = ' --log_file_path \''.$c->config->{error_log}.'\'';
    }

    my $cmd = $c->config->{python_executable}.' '.$c->config->{rootpath}.'/DroneImageScripts/ImageProcess/CalculatePhenotypeAutoEncoderVegetationIndices.py --input_training_image_file \''.$archive_training_temp_input_file.'\' --input_image_file \''.$archive_temp_input_file.'\' --output_encoded_images_file \''.$archive_temp_output_images_file.'\' --outfile_path \''.$archive_temp_output_file.'\' --autoencoder_model_type \''.$autoencoder_model_type.'\' '.$log_file_path;
    print STDERR Dumper $cmd;
    my $status = system("$cmd > /dev/null");

    my @saved_trained_image_urls;
    my %output_image_ids;
    my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_keras_autoencoder_decoded', 'project_md_image')->cvterm_id();
    foreach my $stock_id (keys %output_images) {
        my $autoencoded_images = $output_images{$stock_id};
        foreach my $image_file (@$autoencoded_images) {
            my $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
            $image->set_sp_person_id($user_id);
            my $ret = $image->process_image($image_file, 'project', $drone_run_ids->[0], $linking_table_type_id);
            my $stock_associate = $image->associate_stock($stock_id, $user_name);
            my $output_image_fullpath = $image->get_filename('original_converted', 'full');
            my $output_image_url = $image->get_image_url('original');
            my $output_image_id = $image->get_image_id();
            push @saved_trained_image_urls, $output_image_url;
            push @{$output_image_ids{$stock_id}}, $output_image_id;
        }
    }

    my $ndvi_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'NDVI Vegetative Index Image|ISOL:0000131')->cvterm_id;
    my $ndre_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'NDRE Vegetative Index Image|ISOL:0000132')->cvterm_id;

    my $keras_autoencoder_model_type_id;
    if ($autoencoder_model_type eq 'keras_autoencoder_64_32_filters_16_latent') {
        $keras_autoencoder_model_type_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Keras Autoencoder 64_32_Conv_16_Latent|ISOL:0000336')->cvterm_id;
    }

    my $traits = SGN::Model::Cvterm->get_traits_from_component_categories($schema, $allowed_composed_cvs, $composable_cvterm_delimiter, $composable_cvterm_format, {
        object => [],
        attribute => [],
        method => [],
        unit => [],
        trait => [$ndvi_cvterm_id, $ndre_cvterm_id],
        tod => [$keras_autoencoder_model_type_id],
        toy => [$time_cvterm_id],
        gen => [],
    });
    my $existing_traits = $traits->{existing_traits};
    my $new_traits = $traits->{new_traits};
    #print STDERR Dumper $new_traits;
    #print STDERR Dumper $existing_traits;
    my %new_trait_names;
    foreach (@$new_traits) {
        my $components = $_->[0];
        $new_trait_names{$_->[1]} = join ',', @$components;
    }

    my $onto = CXGN::Onto->new( { schema => $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $user_id) } );
    my $new_terms = $onto->store_composed_term(\%new_trait_names);

    my $autoencoder_ndvi_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, [$ndvi_cvterm_id, $keras_autoencoder_model_type_id, $time_cvterm_id]);
    my $autoencoder_ndre_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, [$ndre_cvterm_id, $keras_autoencoder_model_type_id, $time_cvterm_id]);

    my $autoencoder_ndvi_composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $autoencoder_ndvi_composed_cvterm_id, 'extended');
    my $autoencoder_ndre_composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $autoencoder_ndre_composed_cvterm_id, 'extended');

    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();

    my $csv = Text::CSV->new({ sep_char => ',' });
    open(my $fh, '<', $archive_temp_output_file)
        or die "Could not open file '$archive_temp_output_file' $!";

        print STDERR "Opened $archive_temp_output_file\n";
        my $line = 0;
        my %autoencoder_vi_phenotype_data;
        my %plots_seen;

        my @traits_seen = (
            $autoencoder_ndvi_composed_trait_name,
            $autoencoder_ndre_composed_trait_name
        );

        my $header = <$fh>;
        while ( my $row = <$fh> ){
            my @columns;
            if ($csv->parse($row)) {
                @columns = $csv->fields();
            }

            my $stock_id = $columns[0];
            my $stock_uniquename = $stock_info{$stock_id}->{stock_uniquename};
            my $output_images = $output_image_ids{$stock_id};

            #print STDERR Dumper \@columns;
            $stock_info{$stock_id}->{result} = \@columns;

            $plots_seen{$stock_uniquename} = 1;
            $autoencoder_vi_phenotype_data{$stock_uniquename}->{$autoencoder_ndvi_composed_trait_name} = [$columns[1], $timestamp, $user_name, '', $output_images->[0]];
            $autoencoder_vi_phenotype_data{$stock_uniquename}->{$autoencoder_ndre_composed_trait_name} = [$columns[2], $timestamp, $user_name, '', $output_images->[1]];

            $line++;
        }
        my @stocks = values %stock_info;

    close($fh);
    print STDERR "Read $line lines in results file\n";
    # print STDERR Dumper \%autoencoder_vi_phenotype_data;

    if ($line > 0) {
        my %phenotype_metadata = (
            'archived_file' => $archive_temp_output_file,
            'archived_file_type' => 'keras_autoencoder_vegetation_indices',
            'operator' => $user_name,
            'date' => $timestamp
        );
        my @plot_units_seen = keys %plots_seen;

        my $store_args = {
            basepath=>$c->config->{basepath},
            dbhost=>$c->config->{dbhost},
            dbname=>$c->config->{dbname},
            dbuser=>$c->config->{dbuser},
            dbpass=>$c->config->{dbpass},
            bcs_schema=>$schema,
            metadata_schema=>$metadata_schema,
            phenome_schema=>$phenome_schema,
            user_id=>$user_id,
            stock_list=>\@plot_units_seen,
            trait_list=>\@traits_seen,
            values_hash=>\%autoencoder_vi_phenotype_data,
            has_timestamps=>1,
            metadata_hash=>\%phenotype_metadata,
            overwrite_values=>1,
            #ignore_new_values=>1,
            composable_validation_check_name=>$c->config->{composable_validation_check_name},
            allow_repeat_measures=>$c->config->{allow_repeat_measures}
        };

        my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new(
            $store_args
        );
        my ($verified_warning, $verified_error) = $store_phenotypes->verify();
        my ($stored_phenotype_error, $stored_phenotype_success) = $store_phenotypes->store();

        my $bs = CXGN::BreederSearch->new( { dbh=>$c->dbc->dbh, dbname=>$c->config->{dbname}, } );
        my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'fullview', 'nonconcurrent', $c->config->{basepath});
    }

    return { success => 1 };
}

sub drone_imagery_delete_drone_run : Path('/api/drone_imagery/delete_drone_run') : ActionClass('REST') { }
sub drone_imagery_delete_drone_run_GET : Args(0) {
    my $self = shift;
    my $c = shift;    
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $sp_person_id);
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema", undef, $sp_person_id);
    my $drone_run_project_id = $c->req->param('drone_run_project_id');
    my ($user_id, $user_name, $user_role) = _check_user_login($c, 'curator');
    print STDERR "DELETING DRONE RUN\n";

    my $images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        drone_run_project_id_list=>[$drone_run_project_id],
    });
    my ($result, $total_count) = $images_search->search();
    print STDERR Dumper $total_count;

    my %drone_run_band_project_ids;
    my %image_ids;
    foreach (@$result) {
        $drone_run_band_project_ids{$_->{drone_run_band_project_id}}++;
        $image_ids{$_->{image_id}}++;
    }
    my @drone_run_band_ids = keys %drone_run_band_project_ids;
    my @drone_run_image_ids = keys %image_ids;

    foreach (keys %image_ids) {
        my $image = SGN::Image->new( $schema->storage->dbh, $_, $c );
        $image->delete(); #Sets to obsolete
    }

    my $drone_run_band_project_ids_sql = join ",", @drone_run_band_ids;
    my $drone_run_band_image_ids_sql = join ",", @drone_run_image_ids;
    my $q1 = "DELETE FROM phenome.project_md_image WHERE project_id IN ($drone_run_band_project_ids_sql);";
    my $q2 = "DELETE FROM project WHERE project_id IN ($drone_run_band_project_ids_sql);";
    my $q3 = "DELETE FROM project WHERE project_id = $drone_run_project_id;";
    my $q4 = "DELETE FROM phenome.stock_image WHERE image_id IN (SELECT image_id FROM phenome.project_md_image WHERE project_id IN ($drone_run_band_project_ids_sql));";
    print STDERR $q4."\n";
    print STDERR $q1."\n";
    print STDERR $q2."\n";
    print STDERR $q3."\n";
    my $h4 = $schema->storage->dbh()->prepare($q4);
    $h4->execute();
    my $h1 = $schema->storage->dbh()->prepare($q1);
    $h1->execute();
    my $h2 = $schema->storage->dbh()->prepare($q2);
    $h2->execute();
    my $h3 = $schema->storage->dbh()->prepare($q3);
    $h3->execute();

    my $q5 = "
        DROP TABLE IF EXISTS temp_drone_image_pheno_deletion;
        CREATE TEMP TABLE temp_drone_image_pheno_deletion AS
        (SELECT phenotype.phenotype_id, md_image.image_id
        FROM phenotype
        JOIN nd_experiment_phenotype using(phenotype_id)
        JOIN nd_experiment using(nd_experiment_id)
        JOIN phenome.nd_experiment_md_images AS md_image using(nd_experiment_id)
        WHERE md_image.image_id IN ($drone_run_band_image_ids_sql) );
        DELETE FROM phenotype WHERE phenotype_id IN (SELECT phenotype_id FROM temp_drone_image_pheno_deletion);
        DROP TABLE IF EXISTS temp_drone_image_pheno_deletion;
        ";
    my $h5 = $schema->storage->dbh()->prepare($q5);
    $h5->execute();

    $c->stash->{rest} = {success => 1};
}

sub drone_imagery_get_image_types : Path('/api/drone_imagery/get_image_types') : ActionClass('REST') { }
sub drone_imagery_get_image_types_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    $c->response->headers->header( "Access-Control-Allow-Origin" => '*' );
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $sp_person_id);
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema", undef, $sp_person_id);
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $image_types = CXGN::DroneImagery::ImageTypes::get_all_drone_run_band_image_types()->{array_ref};

    $c->stash->{rest} = {success => 1, image_types => $image_types};
}

sub drone_imagery_growing_degree_days : Path('/api/drone_imagery/growing_degree_days') : ActionClass('REST') { }
sub drone_imagery_growing_degree_days_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $sp_person_id);
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema", undef, $sp_person_id);
    my $field_trial_id = $c->req->param('field_trial_id');
    my $drone_run_project_id = $c->req->param('drone_run_project_id');
    my $formula = $c->req->param('formula');
    my $gdd_base_temperature = $c->req->param('gdd_base_temperature');
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $gdd_result = _perform_gdd_calculation_and_drone_run_time_saving($c, $schema, $field_trial_id, $drone_run_project_id, $c->config->{noaa_ncdc_access_token}, $gdd_base_temperature, $formula);
    print STDERR Dumper $gdd_result;

    $c->stash->{rest} = {success => 1};
}

sub drone_imagery_precipitation_sum : Path('/api/drone_imagery/precipitation_sum') : ActionClass('REST') { }
sub drone_imagery_precipitation_sum_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $sp_person_id);
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema", undef, $sp_person_id);
    my $field_trial_id = $c->req->param('field_trial_id');
    my $drone_run_project_id = $c->req->param('drone_run_project_id');
    my $formula = $c->req->param('formula');
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $precipitation_result = _perform_precipitation_sum_calculation_and_drone_run_time_saving($c, $schema, $field_trial_id, $drone_run_project_id, $c->config->{noaa_ncdc_access_token}, $formula);
    print STDERR Dumper $precipitation_result;

    $c->stash->{rest} = {success => 1};
}

sub _perform_gdd_calculation_and_drone_run_time_saving {
    my $c = shift;
    my $schema = shift;
    my $field_trial_id = shift;
    my $drone_run_project_id = shift;
    my $noaa_ncdc_access_token = shift;
    my $gdd_base_temperature = shift;
    my $formula = shift;

    my $field_trial = CXGN::Trial->new({
        bcs_schema => $schema,
        trial_id => $field_trial_id
    });
    my $planting_date = $field_trial->get_planting_date();
    my $noaa_station_id = $field_trial->get_location_noaa_station_id();

    my $drone_run_project = CXGN::Trial->new({
        bcs_schema => $schema,
        trial_id => $drone_run_project_id
    });
    my $project_start_date = $drone_run_project->get_project_start_date();
    my $drone_run_bands = $drone_run_project->get_associated_image_band_projects();

    my $planting_date_time_object = Time::Piece->strptime($planting_date, "%Y-%B-%d");
    my $planting_date_datetime = $planting_date_time_object->strftime("%Y-%m-%d");
    my $project_start_date_time_object = Time::Piece->strptime($project_start_date, "%Y-%B-%d %H:%M:%S");
    my $project_start_date_datetime = $project_start_date_time_object->strftime("%Y-%m-%d");

    my $gdd = CXGN::NOAANCDC->new({
        bcs_schema => $schema,
        start_date => $planting_date_datetime, #YYYY-MM-DD
        end_date => $project_start_date_datetime, #YYYY-MM-DD
        noaa_station_id => $noaa_station_id,
        noaa_ncdc_access_token => $noaa_ncdc_access_token
    });
    my $gdd_result;
    my %related_cvterms;
    if ($formula eq 'average_daily_temp_sum') {
        $gdd_result = $gdd->get_temperature_averaged_gdd($gdd_base_temperature);
        # if (exists($gdd_result->{error})) {
        #     $c->stash->{rest} = {error => $gdd_result->{error}};
        #     $c->detach();
        # }
        $gdd_result = $gdd_result->{gdd};
        $related_cvterms{gdd_average_temp} = $gdd_result;

        $drone_run_project->set_temperature_averaged_gdd($gdd_result);

        foreach (@$drone_run_bands) {
            my $drone_run_band = CXGN::Trial->new({bcs_schema => $schema, trial_id => $_->[0]});
            $drone_run_band->set_temperature_averaged_gdd($gdd_result);
        }
    }

    my $time_diff = $project_start_date_time_object - $planting_date_time_object;
    my $time_diff_weeks = $time_diff->weeks;
    my $time_diff_days = $time_diff->days;
    my $rounded_time_diff_weeks = round($time_diff_weeks);

    my $week_term_string = "week $rounded_time_diff_weeks";
    my $q = "SELECT t.cvterm_id FROM cvterm as t JOIN cv ON(t.cv_id=cv.cv_id) WHERE t.name=? and cv.name=?;";
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute($week_term_string, 'cxgn_time_ontology');
    my ($week_cvterm_id) = $h->fetchrow_array();

    if (!$week_cvterm_id) {
        my $new_week_term = $schema->resultset("Cv::Cvterm")->create_with({
           name => $week_term_string,
           cv => 'cxgn_time_ontology'
        });
        $week_cvterm_id = $new_week_term->cvterm_id();
    }

    my $day_term_string = "day $time_diff_days";
    $h->execute($day_term_string, 'cxgn_time_ontology');
    my ($day_cvterm_id) = $h->fetchrow_array();

    if (!$day_cvterm_id) {
        my $new_day_term = $schema->resultset("Cv::Cvterm")->create_with({
           name => $day_term_string,
           cv => 'cxgn_time_ontology'
        });
        $day_cvterm_id = $new_day_term->cvterm_id();
    }

    my $week_term = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $week_cvterm_id, 'extended');
    my $day_term = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $day_cvterm_id, 'extended');

    $related_cvterms{week} = $week_term;
    $related_cvterms{day} = $day_term;
    my $related_cvterms_result = encode_json \%related_cvterms;

    $drone_run_project->set_related_time_cvterms_json($related_cvterms_result);

    foreach (@$drone_run_bands) {
        my $drone_run_band = CXGN::Trial->new({bcs_schema => $schema, trial_id => $_->[0]});
        $drone_run_band->set_related_time_cvterms_json($related_cvterms_result);
    }

    return \%related_cvterms;
}

sub _perform_precipitation_sum_calculation_and_drone_run_time_saving {
    my $c = shift;
    my $schema = shift;
    my $field_trial_id = shift;
    my $drone_run_project_id = shift;
    my $noaa_ncdc_access_token = shift;
    my $formula = shift;

    my $field_trial = CXGN::Trial->new({
        bcs_schema => $schema,
        trial_id => $field_trial_id
    });
    my $planting_date = $field_trial->get_planting_date();
    my $noaa_station_id = $field_trial->get_location_noaa_station_id();

    my $drone_run_project = CXGN::Trial->new({
        bcs_schema => $schema,
        trial_id => $drone_run_project_id
    });
    my $project_start_date = $drone_run_project->get_project_start_date();
    my $drone_run_bands = $drone_run_project->get_associated_image_band_projects();
    my $related_cvterms = $drone_run_project->get_related_time_cvterms_json() ? decode_json $drone_run_project->get_related_time_cvterms_json() : {};

    my $planting_date_time_object = Time::Piece->strptime($planting_date, "%Y-%B-%d");
    my $planting_date_datetime = $planting_date_time_object->strftime("%Y-%m-%d");
    my $project_start_date_time_object = Time::Piece->strptime($project_start_date, "%Y-%B-%d %H:%M:%S");
    my $project_start_date_datetime = $project_start_date_time_object->strftime("%Y-%m-%d");

    my $noaa = CXGN::NOAANCDC->new({
        bcs_schema => $schema,
        start_date => $planting_date_datetime, #YYYY-MM-DD
        end_date => $project_start_date_datetime, #YYYY-MM-DD
        noaa_station_id => $noaa_station_id,
        noaa_ncdc_access_token => $noaa_ncdc_access_token
    });
    my $precipitation_result;
    if ($formula eq 'average_daily_precipitation_sum') {
        $precipitation_result = $noaa->get_averaged_precipitation();
        $related_cvterms->{precipitation_averaged_sum} = $precipitation_result;

        $drone_run_project->set_precipitation_averaged_sum_gdd($precipitation_result);

        foreach (@$drone_run_bands) {
            my $drone_run_band = CXGN::Trial->new({bcs_schema => $schema, trial_id => $_->[0]});
            $drone_run_band->set_precipitation_averaged_sum_gdd($precipitation_result);
        }
    }

    my $time_diff = $project_start_date_time_object - $planting_date_time_object;
    my $time_diff_weeks = $time_diff->weeks;
    my $time_diff_days = $time_diff->days;
    my $rounded_time_diff_weeks = round($time_diff_weeks);

    my $week_term_string = "week $rounded_time_diff_weeks";
    my $q = "SELECT t.cvterm_id FROM cvterm as t JOIN cv ON(t.cv_id=cv.cv_id) WHERE t.name=? and cv.name=?;";
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute($week_term_string, 'cxgn_time_ontology');
    my ($week_cvterm_id) = $h->fetchrow_array();

    if (!$week_cvterm_id) {
        my $new_week_term = $schema->resultset("Cv::Cvterm")->create_with({
           name => $week_term_string,
           cv => 'cxgn_time_ontology'
        });
        $week_cvterm_id = $new_week_term->cvterm_id();
    }

    my $day_term_string = "day $time_diff_days";
    $h->execute($day_term_string, 'cxgn_time_ontology');
    my ($day_cvterm_id) = $h->fetchrow_array();

    if (!$day_cvterm_id) {
        my $new_day_term = $schema->resultset("Cv::Cvterm")->create_with({
           name => $day_term_string,
           cv => 'cxgn_time_ontology'
        });
        $day_cvterm_id = $new_day_term->cvterm_id();
    }

    my $week_term = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $week_cvterm_id, 'extended');
    my $day_term = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $day_cvterm_id, 'extended');

    $related_cvterms->{week} = $week_term;
    $related_cvterms->{day} = $day_term;
    my $related_cvterms_result = encode_json $related_cvterms;

    $drone_run_project->set_related_time_cvterms_json($related_cvterms_result);

    foreach (@$drone_run_bands) {
        my $drone_run_band = CXGN::Trial->new({bcs_schema => $schema, trial_id => $_->[0]});
        $drone_run_band->set_related_time_cvterms_json($related_cvterms_result);
    }

    return $related_cvterms;
}

sub drone_imagery_retrain_mask_rcnn : Path('/api/drone_imagery/retrain_mask_rcnn') : ActionClass('REST') { }
sub drone_imagery_retrain_mask_rcnn_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $sp_person_id);
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema", undef, $sp_person_id);
    my ($user_id, $user_name, $user_role) = _check_user_login($c);
    my $model_name = $c->req->param('model_name');
    my $model_description = $c->req->param('model_description');
    my $model_type = $c->req->param('model_type');

    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();

    my $manual_plot_polygon_template_partial = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_plot_polygons_partial', 'project_property')->cvterm_id();
    my $q = "SELECT value FROM projectprop WHERE type_id=$manual_plot_polygon_template_partial;";
    my $h = $schema->storage->dbh->prepare($q);
    $h->execute();

    my @result;
    my %unique_image_ids;
    while (my ($value) = $h->fetchrow_array()) {
        if ($value) {
            my $partial_templates = decode_json $value;
            foreach my $t (@$partial_templates) {
                my $image_id = $t->{image_id};
                my $polygon = $t->{polygon};
                my $stock_polygon = $t->{stock_polygon};
                my $template_name = $t->{template_name};
                my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
                my $image_url = $image->get_image_url("original");
                my $image_fullpath = $image->get_filename('original_converted', 'full');
                my @size = imgsize($image_fullpath);

                push @{$unique_image_ids{$image_id}->{p}}, {
                    polygon => $polygon,
                    template_name => $template_name
                };
                $unique_image_ids{$image_id}->{width} = $size[0];
                $unique_image_ids{$image_id}->{height} = $size[1];
                $unique_image_ids{$image_id}->{image_fullpath} = $image_fullpath;
                $unique_image_ids{$image_id}->{image_url} = $image_url;
            }
        }
    }
    # print STDERR Dumper \%unique_image_ids;

    my $drone_run_band_plot_polygons_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_plot_polygons', 'project_property')->cvterm_id();
    my $denoised_stitched_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'denoised_stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $drone_run_band_polygons_q = "SELECT project.project_id, image_type.image_id, polygons.value
        FROM project
        JOIN projectprop AS polygons ON (project.project_id=polygons.project_id AND polygons.type_id=$drone_run_band_plot_polygons_type_id)
        JOIN phenome.project_md_image AS image_type ON(project.project_id=image_type.project_id AND image_type.type_id=$denoised_stitched_type_id)
        JOIN metadata.md_image AS image ON(image_type.image_id=image.image_id)
        WHERE image.obsolete = 'f';";
    my $drone_run_band_polygons_h = $schema->storage->dbh->prepare($drone_run_band_polygons_q);
    $drone_run_band_polygons_h->execute();
    while (my ($project_id, $image_id, $polygon_json) = $drone_run_band_polygons_h->fetchrow_array()) {
        my $polygons = decode_json $polygon_json;
        # print STDERR Dumper $polygons;
        # print STDERR Dumper $image_id;

        my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
        my $image_url = $image->get_image_url("original");
        my $image_fullpath = $image->get_filename('original_converted', 'full');
        my @size = imgsize($image_fullpath);

        push @{$unique_image_ids{$image_id}->{p}}, {
            polygon => $polygons,
            template_name => $project_id
        };

        $unique_image_ids{$image_id}->{width} = $size[0];
        $unique_image_ids{$image_id}->{height} = $size[1];
        $unique_image_ids{$image_id}->{image_fullpath} = $image_fullpath;
        $unique_image_ids{$image_id}->{image_url} = $image_url;
    }
    # print STDERR Dumper \%unique_image_ids;

    my $dir = $c->tempfiles_subdir('/drone_imagery_keras_cnn_maskrcnn_input_annotations_dir');
    my $output_dir = $c->tempfiles_subdir('/drone_imagery_keras_cnn_maskrcnn_dir');
    my $temp_output_model_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_maskrcnn_dir/outputmodelfileXXXX').".h5";
    my $temp_output_dir = $c->config->{basepath}."/".$output_dir;
    my $temp_input_dir = $c->config->{basepath}."/".$dir;
    print STDERR Dumper $temp_input_dir;

    my $temp_model_input_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_maskrcnn_dir/annotationfileXXXX');
    open(my $F_model, ">", $temp_model_input_file) || die "Can't open file ".$temp_model_input_file;
        print $F_model "<annotations>\n";

        while (my ($image_id, $p) = each %unique_image_ids) {
            my $file_path = $p->{image_fullpath};
            my $width = $p->{width};
            my $height = $p->{height};
            my $temp_input_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_maskrcnn_input_annotations_dir/inputannotationfileXXXX');
            # print STDERR Dumper $archive_temp_input_file;

            open(my $F_img, ">", $temp_input_file) || die "Can't open file ".$temp_input_file;
                print $F_img "<annotation>\n";
                print $F_img "\t<image_id>$image_id</image_id>\n";
                print $F_img "\t<image_path>$file_path</image_path>\n";
                print $F_img "\t<size>\n";
                print $F_img "\t\t<width>$width</width>\n";
                print $F_img "\t\t<height>$height</height>\n";
                print $F_img "\t</size>\n";

                print $F_model "<annotation>\n";
                print $F_model "\t<image_id>$image_id</image_id>\n";
                print $F_model "\t<image_path>$file_path</image_path>\n";
                print $F_model "\t<size>\n";
                print $F_model "\t\t<width>$width</width>\n";
                print $F_model "\t\t<height>$height</height>\n";
                print $F_model "\t</size>\n";

                foreach my $poly (@{$p->{p}}) {
                    foreach my $po (values %{$poly->{polygon}}) {
                        my $xmin = 1000000;
                        my $ymin = 1000000;
                        my $xmax = 0;
                        my $ymax = 0;
                        foreach my $ob (@$po) {
                            if ($ob->{x} < $xmin) {
                                $xmin = round($ob->{x});
                            }
                            if ($ob->{y} < $ymin) {
                                $ymin = round($ob->{y});
                            }
                            if ($ob->{x} > $xmax) {
                                $xmax = round($ob->{x});
                            }
                            if ($ob->{y} > $ymax) {
                                $ymax = round($ob->{y});
                            }
                        }
                        print $F_img "\t<object>\n";
                        print $F_img "\t\t<name>".$poly->{template_name}."</name>\n";
                        print $F_img "\t\t<bndbox>\n";
                        print $F_img "\t\t\t<xmin>$xmin</xmin>\n";
                        print $F_img "\t\t\t<ymin>$ymin</ymin>\n";
                        print $F_img "\t\t\t<xmax>$xmax</xmax>\n";
                        print $F_img "\t\t\t<ymax>$ymax</ymax>\n";
                        print $F_img "\t\t</bndbox>\n";
                        print $F_img "\t</object>\n";

                        print $F_model "\t<object>\n";
                        print $F_model "\t\t<name>".$poly->{template_name}."</name>\n";
                        print $F_model "\t\t<bndbox>\n";
                        print $F_model "\t\t\t<xmin>$xmin</xmin>\n";
                        print $F_model "\t\t\t<ymin>$ymin</ymin>\n";
                        print $F_model "\t\t\t<xmax>$xmax</xmax>\n";
                        print $F_model "\t\t\t<ymax>$ymax</ymax>\n";
                        print $F_model "\t\t</bndbox>\n";
                        print $F_model "\t</object>\n";
                    }
                }
                print $F_img "</annotation>\n";

                print $F_model "</annotation>\n";
            close($F_img);
        }
        print $F_model "</annotations>\n";
    close($F_model);

    my $log_file_path = '';
    if ($c->config->{error_log}) {
        $log_file_path = ' --log_file_path \''.$c->config->{error_log}.'\'';
    }
    my $cmd = $c->config->{python_executable_maskrcnn_env}.' '.$c->config->{rootpath}.'/DroneImageScripts/CNN/MaskRCNNBoundingBoxTrain.py --input_annotations_dir \''.$temp_input_dir.'\' --output_model_path \''.$temp_output_model_file.'\' --output_model_dir \''.$temp_output_dir.'\' '.$log_file_path;
    print STDERR Dumper $cmd;
    my $status = system("$cmd > /dev/null");

    my $keras_mask_r_cnn_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'trained_keras_mask_r_cnn_model', 'protocol_type')->cvterm_id();
    my $keras_cnn_experiment_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'analysis_model_experiment', 'experiment_type')->cvterm_id();

    my $m = CXGN::AnalysisModel::SaveModel->new({
        bcs_schema=>$schema,
        metadata_schema=>$metadata_schema,
        phenome_schema=>$phenome_schema,
        archive_path=>$c->config->{archive_path},
        model_name=>$model_name,
        model_description=>$model_description,
        model_language=>'Python',
        model_type_cvterm_id=>$keras_mask_r_cnn_cvterm_id,
        model_properties=>{model_type=>$model_type, image_type=>'all_annotated_plot_images'},
        application_name=>'MaskRCNNModel',
        application_version=>'V1.1',
        is_public=>1,
        user_id=>$user_id,
        user_role=>$user_role
    });
    my $saved_model = $m->save_model();
    my $saved_model_id = $saved_model->{nd_protocol_id};

    my $analysis_model = CXGN::AnalysisModel::GetModel->new({
        bcs_schema=>$schema,
        metadata_schema=>$metadata_schema,
        phenome_schema=>$phenome_schema,
        nd_protocol_id=>$saved_model_id
    });
    $analysis_model->store_analysis_model_files({
        # project_id => $saved_analysis_id,
        archived_model_file_type=>'trained_keras_mask_r_cnn_model',
        model_file=>$temp_output_model_file,
        archived_training_data_file_type=>'trained_keras_mask_r_cnn_model_input_data_file',
        archived_training_data_file=>$temp_model_input_file,
        # archived_auxiliary_files=>[
        #     {auxiliary_model_file => $archive_temp_autoencoder_output_model_file, auxiliary_model_file_archive_type => 'trained_keras_cnn_autoencoder_model'},
        #     {auxiliary_model_file => $model_input_aux_file, auxiliary_model_file_archive_type => 'trained_keras_cnn_model_input_aux_data_file'}
        # ],
        archive_path=>$c->config->{archive_path},
        user_id=>$user_id,
        user_role=>$user_role
    });

    $c->stash->{rest} = {success => 1};
}

sub drone_imagery_predict_mask_rcnn : Path('/api/drone_imagery/predict_mask_rcnn') : ActionClass('REST') { }
sub drone_imagery_predict_mask_rcnn_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $sp_person_id);
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema", undef, $sp_person_id);
    my ($user_id, $user_name, $user_role) = _check_user_login($c);
    my $model_id = $c->req->param('model_id');
    my $image_id = $c->req->param('image_id');

    my $time = DateTime->now();
    my $timestamp = $time->ymd();

    my $keras_mask_r_cnn_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'trained_keras_mask_r_cnn_model', 'protocol_type')->cvterm_id();
    my $model_properties_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'analysis_model_properties', 'protocol_property')->cvterm_id();
    my $keras_cnn_experiment_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'analysis_model_experiment', 'experiment_type')->cvterm_id();

    my $m = CXGN::AnalysisModel::GetModel->new({
        bcs_schema=>$schema,
        metadata_schema=>$metadata_schema,
        phenome_schema=>$phenome_schema,
        nd_protocol_id=>$model_id
    });
    my $saved_model_object = $m->get_model();
    print STDERR Dumper $saved_model_object;
    my $model_type = $saved_model_object->{model_properties}->{model_type};
    my $trained_image_type = $saved_model_object->{model_properties}->{image_type};
    my $model_file = $saved_model_object->{model_files}->{trained_keras_mask_r_cnn_model};
    my $training_input_data_file = $saved_model_object->{model_files}->{trained_keras_mask_r_cnn_model_input_data_file};

    my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
    my $image_url = $image->get_image_url("original");
    my $image_fullpath = $image->get_filename('original_converted', 'full');
    my @size = imgsize($image_fullpath);
    my $width = $size[0];
    my $height = $size[1];

    my $output_dir = $c->tempfiles_subdir('/drone_imagery_keras_cnn_maskrcnn_predict_dir');
    my $dir = $c->tempfiles_subdir('/drone_imagery_keras_cnn_maskrcnn_predict_input_annotations_dir');
    my $model_dir = $c->tempfiles_subdir('/drone_imagery_keras_cnn_maskrcnn_predict_input_model_dir');
    my $temp_input_dir = $c->config->{basepath}."/".$dir;
    my $temp_model_dir = $c->config->{basepath}."/".$model_dir;
    print STDERR Dumper $temp_input_dir;

    my $archive_temp_output_results_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_maskrcnn_predict_dir/outputfileXXXX');
    my $archive_temp_output_activation_file = $c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_maskrcnn_predict_input_model_dir/outputactivationfileXXXX');
    $archive_temp_output_activation_file .= ".pdf";
    my $archive_temp_output_activation_file_path = $c->config->{basepath}."/".$archive_temp_output_activation_file;

    my $temp_input_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_maskrcnn_predict_input_annotations_dir/inputannotationfileXXXX');
    # print STDERR Dumper $archive_temp_input_file;

    open(my $F_img, ">", $temp_input_file) || die "Can't open file ".$temp_input_file;
        print $F_img "<annotation>\n";
        print $F_img "\t<image_id>$image_id</image_id>\n";
        print $F_img "\t<image_path>$image_fullpath</image_path>\n";
        print $F_img "\t<size>\n";
        print $F_img "\t\t<width>$width</width>\n";
        print $F_img "\t\t<height>$height</height>\n";
        print $F_img "\t</size>\n";
        print $F_img "</annotation>\n";
    close($F_img);

    my $log_file_path = '';
    if ($c->config->{error_log}) {
        $log_file_path = ' --log_file_path \''.$c->config->{error_log}.'\'';
    }
    my $cmd = $c->config->{python_executable_maskrcnn_env}.' '.$c->config->{rootpath}.'/DroneImageScripts/CNN/MaskRCNNBoundingBoxPredict.py --input_annotations_dir \''.$temp_input_dir.'\' --model_path \''.$model_file.'\' --model_dir \''.$temp_model_dir.'\' --outfile_annotated \''.$archive_temp_output_activation_file_path.'\' --results_outfile \''.$archive_temp_output_results_file.'\' '.$log_file_path;
    print STDERR Dumper $cmd;
    my $status = system("$cmd /dev/null");

    my @bounding_boxes;
    my $csv = Text::CSV->new({ sep_char => ',' });
    open(my $fh, '<', $archive_temp_output_results_file) or die "Could not open file '$archive_temp_output_results_file' $!";
        print STDERR "Opened $archive_temp_output_results_file\n";
        while ( my $row = <$fh> ){
            my @columns;
            if ($csv->parse($row)) {
                @columns = $csv->fields();
            }
            print STDERR Dumper \@columns;
            push @bounding_boxes, \@columns;
        }
    close($fh);

    $c->stash->{rest} = {success => 1, activation_output => $archive_temp_output_activation_file, bounding_boxes => \@bounding_boxes};
}

sub drone_imagery_export_drone_runs : Path('/api/drone_imagery/export_drone_runs') : ActionClass('REST') { }
sub drone_imagery_export_drone_runs_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $sp_person_id);
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema", undef, $sp_person_id);
    my $drone_run_project_ids = decode_json $c->req->param('drone_run_project_ids');
    my $field_trial_id = $c->req->param('field_trial_id');
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $plot_polygon_template_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_plot_polygons', 'project_property')->cvterm_id();
    my $drone_run_drone_run_band_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_on_drone_run', 'project_relationship')->cvterm_id();
    my $original_denoised_image_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'denoised_stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $imaging_vehicle_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'imaging_event_vehicle', 'stock_type')->cvterm_id();
    my $imaging_vehicle_properties_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'imaging_event_vehicle_json', 'stock_property')->cvterm_id();
    my $drone_run_experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_experiment', 'experiment_type')->cvterm_id();
    my $drone_run_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_project_type', 'project_property')->cvterm_id();
    my $drone_run_camera_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_camera_type', 'project_property')->cvterm_id();
    my $project_start_date_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project_start_date', 'project_property')->cvterm_id();
    my $drone_run_base_date_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_base_date', 'project_property')->cvterm_id();
    my $drone_run_rig_desc_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_camera_rig_description', 'project_property')->cvterm_id();
    my $project_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_on_field_trial', 'project_relationship')->cvterm_id();
    my $drone_run_band_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_project_type', 'project_property')->cvterm_id();
    my $calendar_funcs = CXGN::Calendar->new({});

    my %spectral_lookup = (
        "Blue (450-520nm)" => "blue",
        "Green (515-600nm)" => "green",
        "Red (600-690nm)" => "red",
        "Red Edge (690-750nm)" => "rededge",
        "NIR (780-3000nm)" => "nir",
        "MIR (3000-50000nm)" => "mir",
        "FIR (50000-1000000nm)" => "fir",
        "Thermal IR (9000-14000nm)" => "thir",
        "RGB Color Image" => "rgb",
        "Black and White Image" => "bw"
    );

    my %sensor_map = (
        "micasense_5" => "MicaSense 5 Channel Camera",
        "ccd_color" => "CCD Color Camera",
        "cmos_color" => "CMOS Color Camera"
    );

    my %drone_run_csv_info;
    foreach my $drone_run_project_id (@$drone_run_project_ids) {
        my $q = "SELECT plot_polygons.value, drone_run.project_id, drone_run.name, drone_run.description, drone_run_band.project_id, drone_run_band.name, drone_run_band.description, project_image.image_id, project_image_type.name, stock.uniquename, stock.stock_id, imaging_event_type.value, camera.value, imaging_event_date.value, base_date.value, camera_rig.value, field_trial.name, field_trial.project_id, drone_run_band_type.value
            FROM project AS drone_run_band
            JOIN project_relationship ON(project_relationship.subject_project_id = drone_run_band.project_id AND project_relationship.type_id = $drone_run_drone_run_band_type_id)
            JOIN project AS drone_run ON(project_relationship.object_project_id = drone_run.project_id)
            JOIN projectprop AS plot_polygons ON(drone_run_band.project_id = plot_polygons.project_id AND plot_polygons.type_id=$plot_polygon_template_type_id)
            JOIN projectprop AS drone_run_band_type ON(drone_run_band.project_id = drone_run_band_type.project_id AND drone_run_band_type.type_id=$drone_run_band_type_cvterm_id)
            JOIN phenome.project_md_image AS project_image ON(drone_run_band.project_id = project_image.project_id AND project_image.type_id=$original_denoised_image_type_id)
            JOIN metadata.md_image AS md_image ON(md_image.image_id = project_image.image_id)
            JOIN cvterm AS project_image_type ON(project_image.type_id = project_image_type.cvterm_id)
            JOIN nd_experiment_project ON(nd_experiment_project.project_id = drone_run.project_id)
            JOIN nd_experiment ON(nd_experiment_project.nd_experiment_id = nd_experiment.nd_experiment_id AND nd_experiment.type_id=$drone_run_experiment_type_id)
            JOIN nd_experiment_stock ON(nd_experiment.nd_experiment_id = nd_experiment_stock.nd_experiment_id)
            JOIN stock ON(nd_experiment_stock.stock_id=stock.stock_id AND stock.type_id=$imaging_vehicle_cvterm_id)
            JOIN projectprop AS imaging_event_type ON(imaging_event_type.project_id = drone_run.project_id AND imaging_event_type.type_id=$drone_run_type_cvterm_id)
            JOIN projectprop AS camera ON(camera.project_id = drone_run.project_id AND camera.type_id=$drone_run_camera_type_cvterm_id)
            JOIN projectprop AS imaging_event_date ON(imaging_event_date.project_id = drone_run.project_id AND imaging_event_date.type_id=$project_start_date_type_id)
            LEFT JOIN projectprop AS base_date ON(base_date.project_id = drone_run.project_id AND base_date.type_id=$drone_run_base_date_type_id)
            LEFT JOIN projectprop AS camera_rig ON(camera_rig.project_id = drone_run.project_id AND camera_rig.type_id=$drone_run_rig_desc_type_id)
            JOIN project_relationship AS field_trial_rel ON(field_trial_rel.subject_project_id = drone_run.project_id AND field_trial_rel.type_id = $project_relationship_type_id)
            JOIN project AS field_trial ON(field_trial_rel.object_project_id = field_trial.project_id)
            WHERE drone_run.project_id = ? AND md_image.obsolete='f'
            ORDER BY drone_run_band.project_id;";

        my $h = $schema->storage->dbh()->prepare($q);
        $h->execute($drone_run_project_id);
        while (my ($plot_polygons_value, $drone_run_project_id, $drone_run_project_name, $drone_run_description, $drone_run_band_project_id, $drone_run_band_project_name, $drone_run_band_description, $image_id, $project_image_type, $imaging_vehicle_name, $imaging_vehicle_id, $imaging_event_type, $camera, $imaging_event_calendar, $base_date_calendar, $camera_rig, $field_trial_name, $field_trial_id, $drone_run_band_type) = $h->fetchrow_array()) {
            my $imaging_event_date = $imaging_event_calendar ? $calendar_funcs->display_start_date($imaging_event_calendar) : '';
            my $imaging_event_base_date = $base_date_calendar ? $calendar_funcs->display_start_date($base_date_calendar) : '';
            $drone_run_csv_info{$drone_run_project_id}->{plot_polygons_value} = $plot_polygons_value;
            $drone_run_csv_info{$drone_run_project_id}->{imaging_event_date} = $imaging_event_date;
            $drone_run_csv_info{$drone_run_project_id}->{imaging_event_base_date} = $imaging_event_base_date;
            $drone_run_csv_info{$drone_run_project_id}->{drone_run_name} = $drone_run_project_name;
            $drone_run_csv_info{$drone_run_project_id}->{drone_run_description} = $drone_run_description;
            $drone_run_csv_info{$drone_run_project_id}->{imaging_vehicle_name} = $imaging_vehicle_name;
            $drone_run_csv_info{$drone_run_project_id}->{imaging_vehicle_id} = $imaging_vehicle_id;
            $drone_run_csv_info{$drone_run_project_id}->{imaging_event_type} = $imaging_event_type;
            $drone_run_csv_info{$drone_run_project_id}->{camera} = $sensor_map{$camera};
            $drone_run_csv_info{$drone_run_project_id}->{camera_rig} = $camera_rig;
            $drone_run_csv_info{$drone_run_project_id}->{field_trial_name} = $field_trial_name;
            $drone_run_csv_info{$drone_run_project_id}->{field_trial_id} = $field_trial_id;
            my $spec = $spectral_lookup{$drone_run_band_type};
            if ($spec) {
                push @{$drone_run_csv_info{$drone_run_project_id}->{drone_run_bands}}, {
                    drone_run_band_project_id => $drone_run_band_project_id,
                    drone_run_band_project_name => $drone_run_band_project_name,
                    drone_run_band_description => $drone_run_band_description,
                    image_id => $image_id,
                    project_image_type => $project_image_type,
                    drone_run_band_type => $drone_run_band_type,
                    drone_run_band_type_short => $spec,
                };
            }
        }
    }
    # print STDERR Dumper \%drone_run_csv_info;

    my $images_zip = Archive::Zip->new();
    # my $dir_images_member = $images_zip->addDirectory( 'orthoimage_files/' );

    my $output_image_zipfile_dir = $c->tempfiles_subdir('/drone_imagery_export_image_zipfile_dir');
    my $imaging_events_file = $c->tempfile( TEMPLATE => 'drone_imagery_export_image_zipfile_dir/imagingeventsXXXX');
    $imaging_events_file .= ".xls";
    my $imaging_events_file_path = $c->config->{basepath}."/".$imaging_events_file;

    my @imaging_events_spreadsheet_rows;
    my @images_file_names_return;
    my $workbook = Spreadsheet::WriteExcel->new($imaging_events_file_path);
    my $worksheet = $workbook->add_worksheet();
        my $header_row = ['Imaging Event Name','Type','Description','Date','Vehicle Name','Vehicle Battery Set','Sensor','Field Trial Name','GeoJSON Filename','Image Filenames','Coordinate System','Base Date','Camera Rig'];
        $worksheet->write_row(0, 0, $header_row);
        push @imaging_events_spreadsheet_rows, $header_row;
        my $line_number = 1;

        my %geojson_hash;
        foreach my $drone_run_project_id (sort keys %drone_run_csv_info) {
            my $drone_run_info = $drone_run_csv_info{$drone_run_project_id};

            my $plot_polygons_value = decode_json $drone_run_info->{plot_polygons_value};
            my $field_trial_id = $drone_run_info->{field_trial_id};
            my $field_trial_name = $drone_run_info->{field_trial_name};
            my $drone_run_name = $drone_run_info->{drone_run_name};
            my $imaging_event_date = $drone_run_info->{imaging_event_date};
            my $imaging_event_base_date = $drone_run_info->{imaging_event_base_date} || '';
            my $drone_run_description = $drone_run_info->{drone_run_description};
            my $imaging_vehicle_name = $drone_run_info->{imaging_vehicle_name};
            my $imaging_event_type = $drone_run_info->{imaging_event_type};
            my $camera = $drone_run_info->{camera};
            my $camera_rig = $drone_run_info->{camera_rig} || '';
            my $drone_run_bands = $drone_run_info->{drone_run_bands};
            my @image_filenames;
            foreach my $band (@$drone_run_bands) {
                my $spec = $band->{drone_run_band_type_short};
                my $image_id = $band->{image_id};
                my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
                my $image_fullpath = $image->get_filename('original_converted', 'full');
                print STDERR Dumper $image_fullpath;
                my $image_name = $image_id."__".$spec.".JPG";
                my $file_member = $images_zip->addFile( $image_fullpath, $image_name );
                push @images_file_names_return, $image_name;
                push @image_filenames, $image_name;
            }

            my $trial = CXGN::Trial->new({ bcs_schema => $schema, trial_id => $field_trial_id });
            my $trial_layout = $trial->get_layout()->get_design();
            # print STDERR Dumper $trial_layout;
            # print STDERR Dumper $plot_polygons_value;

            my %plot_name_lookup;
            while (my ($plot_number, $plot_info) = each %$trial_layout) {
                $plot_name_lookup{$plot_info->{plot_name}} = $plot_number;
            }

            foreach my $stock_name (keys %$plot_polygons_value) {
                my $polygon = $plot_polygons_value->{$stock_name};
                my @coords;
                foreach my $point (@$polygon) {
                    my $x = $point->{x};
                    my $y = $point->{y};
                    push @coords, [$x, $y];
                }
                $geojson_hash{$drone_run_project_id}->{$plot_name_lookup{$stock_name}} = \@coords;
            }
            my $geojson_filename = $drone_run_project_id.".geojson";

            my $orthoimage_filenames = join ',', @image_filenames;
            $drone_run_info->{orthoimage_files} = $orthoimage_filenames;
            $drone_run_info->{geojson_file} = $geojson_filename;

            my $imaging_event_row = [$drone_run_name, $imaging_event_type, $drone_run_description, $imaging_event_date, $imaging_vehicle_name, '', $camera, $field_trial_name, $geojson_filename, $orthoimage_filenames, "Pixels", $imaging_event_base_date, $camera_rig];
            $worksheet->write_row($line_number, 0, $imaging_event_row);
            push @imaging_events_spreadsheet_rows, $imaging_event_row;
            $line_number++;
        }
    $workbook->close();

    my $orthoimage_zipfile = $c->tempfile( TEMPLATE => 'drone_imagery_export_image_zipfile_dir/orthoimagezipfileXXXX');
    $orthoimage_zipfile .= ".zip";
    my $orthoimage_zipfile_file_path = $c->config->{basepath}."/".$orthoimage_zipfile;

    unless ( $images_zip->writeToFileNamed($orthoimage_zipfile_file_path) == AZ_OK ) {
        $c->stash->{rest} = {error => "Images zipfile could not be saved!"};
        $c->detach;
    }

    my $geojson_zip = Archive::Zip->new();
    # my $dir_geojson_member = $geojson_zip->addDirectory( 'geojson_files/' );

    my $output_geojson_zipfile_dir = $c->tempfiles_subdir('/drone_imagery_export_image_geojson_dir');

    my @geojson_file_names_return;
    foreach my $drone_run_project_id (sort keys %geojson_hash) {
        my $plot_geo = $geojson_hash{$drone_run_project_id};

        my @features_geojson;
        while (my($plot_number, $coords) = each %$plot_geo) {
            my $first_coord = $coords->[0];
            push @$coords, $first_coord;
            my %feature_geojson = (
                type => "Feature",
                field_trial_name => $drone_run_csv_info{$drone_run_project_id}->{field_trial_name},
                properties => {
                    ID => $plot_number
                },
                geometry => {
                    type => "Polygon",
                    coordinates => [$coords]
                }
            );
            push @features_geojson, \%feature_geojson;
        }

        my %geojson = (
            type => "FeatureCollection",
            features => \@features_geojson
        );
        my $geojson_string = encode_json \%geojson;

        my $geojson_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_export_image_geojson_dir/geojsonXXXX');

        open(my $fh_geojson, '>', $geojson_file) or die "Could not open file '$geojson_file' $!";
            print STDERR "Opened $geojson_file\n";
            print $fh_geojson $geojson_string;
        close($fh_geojson);

        my $geojson_filename_save = $drone_run_csv_info{$drone_run_project_id}->{geojson_file};
        my $file_member = $geojson_zip->addFile( $geojson_file, $geojson_filename_save );
        push @geojson_file_names_return, $geojson_filename_save;
    }

    my $geojson_zipfile = $c->tempfile( TEMPLATE => 'drone_imagery_export_image_zipfile_dir/geojsonzipfileXXXX');
    $geojson_zipfile .= ".zip";
    my $geojson_zipfile_file_path = $c->config->{basepath}."/".$geojson_zipfile;

    unless ( $geojson_zip->writeToFileNamed($geojson_zipfile_file_path) == AZ_OK ) {
        $c->stash->{rest} = {error => "GeoJSON zipfile could not be saved!"};
        $c->detach;
    }

    my $trial = CXGN::Trial->new({ bcs_schema => $schema, trial_id => $field_trial_id });
    my $trial_layout = $trial->get_layout()->get_design();
    my $planting_date = $trial->get_planting_date();
    my $trial_desc = $trial->get_description();
    my $trial_year = $trial->get_year();
    my $trial_location = $trial->get_location();
    my $location_id = $trial_location->[0];
    my $location = CXGN::Location->new( { bcs_schema => $schema, nd_geolocation_id => $location_id } );

    $c->stash->{rest} = {
        success => 1,
        orthoimage_zipfile => $orthoimage_zipfile,
        geojson_zipfile => $geojson_zipfile,
        imaging_events_spreadsheet => $imaging_events_file,
        field_trial_id => $field_trial_id,
        planting_date => $planting_date,
        trial_layout => $trial_layout,
        drone_run_csv_info => \%drone_run_csv_info,
        imaging_events_spreadsheet_rows => \@imaging_events_spreadsheet_rows,
        images_file_names_return => \@images_file_names_return,
        geojson_file_names_return => \@geojson_file_names_return
    };
}

sub _check_user_login {
    my $c = shift;
    my $role_check = shift;
    my $user_id;
    my $user_name;
    my $user_role;
    my $session_id = $c->req->param("sgn_session_id");

    if ($session_id){
        my $dbh = $c->dbc->dbh;
        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);
        if (!$user_info[0]){
            $c->stash->{rest} = {error=>'You must be logged in to do this!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else{
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to do this!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }
    if ($role_check && $user_role ne $role_check) {
        $c->stash->{rest} = {error=>'You must have permission to do this! Please contact us!'};
        $c->detach();
    }
    return ($user_id, $user_name, $user_role);
}

1;
