
=head1 NAME

SGN::Controller::AJAX::DroneImagery::DroneImageryAnalytics - a REST controller class to provide the
functions for drone imagery analytics

=head1 DESCRIPTION

=head1 AUTHOR

=cut

package SGN::Controller::AJAX::DroneImagery::DroneImageryAnalytics;

use strict;
use warnings;
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
use CXGN::DroneImagery::DroneImageryAnalyticsRunSimulation;
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
use Scalar::Util qw(looks_like_number);
use SGN::Controller::AJAX::DroneImagery::DroneImagery;
use Storable qw(dclone);
use Statistics::Descriptive;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON'  },
);

sub drone_imagery_calculate_analytics : Path('/api/drone_imagery/calculate_analytics') : ActionClass('REST') { }
sub drone_imagery_calculate_analytics_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    print STDERR Dumper $c->req->params();
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $people_schema = $c->dbic_schema("CXGN::People::Schema", undef, $sp_person_id);
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $sp_person_id);
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema", undef, $sp_person_id);
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $statistics_select_original = $c->req->param('statistics_select');
    my $analytics_protocol_id = $c->req->param('analytics_protocol_id');
    my $analytics_protocol_name = $c->req->param('analytics_protocol_name');
    my $analytics_protocol_desc = $c->req->param('analytics_protocol_desc');
    my $sim_env_change_over_time = $c->req->param('sim_env_change_over_time') || '';

    my $field_trial_id_list = $c->req->param('field_trial_id_list') ? decode_json $c->req->param('field_trial_id_list') : [];
    my $field_trial_id_list_string = join ',', @$field_trial_id_list;

    if (scalar(@$field_trial_id_list) != 1) {
        $c->stash->{rest} = { error => "Please select one field trial!"};
        return;
    }

    my $protocol_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_imagery_analytics_env_simulation_protocol', 'protocol_type')->cvterm_id();
    my $protocolprop_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'analytics_protocol_properties', 'protocol_property')->cvterm_id();
    my $protocolprop_result_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'analytics_protocol_result_summary', 'protocol_property')->cvterm_id();
    my $analytics_experiment_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'analytics_protocol_experiment', 'experiment_type')->cvterm_id();

    my $protocol_properties;
    my $analytics_nd_experiment_id;
    my $protocol_result_summary = [];
    my $protocol_result_summary_id;
    if (!$analytics_protocol_id) {
        my $q = "INSERT INTO nd_protocol (name, description, type_id) VALUES (?,?,?) RETURNING nd_protocol_id;";
        my $h = $schema->storage->dbh()->prepare($q);
        $h->execute($analytics_protocol_name, $analytics_protocol_desc, $protocol_type_cvterm_id);
        ($analytics_protocol_id) = $h->fetchrow_array();

        my $number_iterations = $c->req->param('number_iterations') || 2;
        my $env_iterations;
        for my $iterations (1..$number_iterations) {
            my $a_env = rand(1);
            my $b_env = rand(1);
            my $ro_env = rand(1);
            my $row_ro_env = rand(1);

            $env_iterations->{$iterations} = {
                a_env => $a_env,
                b_env => $b_env,
                ro_env => $ro_env,
                row_ro_env => $row_ro_env,
            };
        }

        $protocol_properties = {
            analytics_select => $c->req->param('analytics_select') || 'minimize_local_env_effect',
            observation_variable_id_list => $c->req->param('observation_variable_id_list') ? decode_json $c->req->param('observation_variable_id_list') : [],
            relationship_matrix_type => $c->req->param('relationship_matrix_type') || 'genotypes',
            htp_pheno_rel_matrix_type => $c->req->param('htp_pheno_rel_matrix_type'),
            htp_pheno_rel_matrix_time_points => $c->req->param('htp_pheno_rel_matrix_time_points'),
            htp_pheno_rel_matrix_blues_inversion => $c->req->param('htp_pheno_rel_matrix_blues_inversion'),
            genotype_compute_from_parents => $c->req->param('compute_from_parents') eq 'yes' ? 1 : 0,
            include_pedgiree_info_if_compute_from_parents => $c->req->param('include_pedgiree_info_if_compute_from_parents') eq 'yes' ? 1 : 0,
            use_parental_grms_if_compute_from_parents => $c->req->param('use_parental_grms_if_compute_from_parents') eq 'yes' ? 1 : 0,
            use_area_under_curve => $c->req->param('use_area_under_curve') eq 'yes' ? 1 : 0,
            genotyping_protocol_id => $c->req->param('protocol_id'),
            tolparinv => $c->req->param('tolparinv'),
            legendre_order_number => $c->req->param('legendre_order_number'),
            permanent_environment_structure => $c->req->param('permanent_environment_structure'),
            permanent_environment_structure_phenotype_correlation_traits => decode_json $c->req->param('permanent_environment_structure_phenotype_correlation_traits'),
            permanent_environment_structure_phenotype_trait_ids => decode_json $c->req->param('permanent_environment_structure_phenotype_trait_ids'),
            env_variance_percent => $c->req->param('env_variance_percent') || "0.2,0.1,0.05,0.01,0.3",
            number_iterations => $number_iterations,
            simulated_environment_real_data_trait_id => $c->req->param('simulated_environment_real_data_trait_id'),
            sim_env_change_over_time_correlation => $c->req->param('sim_env_change_over_time_correlation') || '0.9',
            fixed_effect_type => $c->req->param('fixed_effect_type'),
            fixed_effect_trait_id => $c->req->param('fixed_effect_trait_id'),
            fixed_effect_quantiles => $c->req->param('fixed_effect_quantiles'),
            env_iterations => $env_iterations,
            perform_cv => $c->req->param('drone_imagery_analytics_select_perform_cv') || 0
        };
        my $q2 = "INSERT INTO nd_protocolprop (nd_protocol_id, value, type_id) VALUES (?,?,?);";
        my $h2 = $schema->storage->dbh()->prepare($q2);
        $h2->execute($analytics_protocol_id, encode_json $protocol_properties, $protocolprop_type_cvterm_id);

        my $q3 = "INSERT INTO nd_protocolprop (nd_protocol_id, value, type_id) VALUES (?,?,?) RETURNING nd_protocolprop_id;";
        my $h3 = $schema->storage->dbh()->prepare($q3);
        $h3->execute($analytics_protocol_id, encode_json $protocol_result_summary, $protocolprop_result_type_cvterm_id);
        ($protocol_result_summary_id) = $h3->fetchrow_array();

        my $location_id = $schema->resultset("NaturalDiversity::NdGeolocation")->search({description=>'[Computation]'})->first->nd_geolocation_id();
        my $experiment = $schema->resultset('NaturalDiversity::NdExperiment')->create({
            nd_geolocation_id => $location_id,
            type_id => $analytics_experiment_type_cvterm_id,
            nd_experiment_protocols => [{nd_protocol_id => $analytics_protocol_id}]
        });
        $analytics_nd_experiment_id = $experiment->nd_experiment_id();
    }
    else {
        my $q = "SELECT value FROM nd_protocolprop WHERE nd_protocol_id=? AND type_id=?;";
        my $h = $schema->storage->dbh()->prepare($q);
        $h->execute($analytics_protocol_id, $protocolprop_type_cvterm_id);
        my ($value) = $h->fetchrow_array();
        $protocol_properties = decode_json $value;

        my $q3 = "SELECT nd_experiment.nd_experiment_id
            FROM nd_experiment_protocol
            JOIN nd_experiment ON(nd_experiment_protocol.nd_experiment_id = nd_experiment.nd_experiment_id)
            WHERE nd_protocol_id=? AND nd_experiment.type_id = ?;";
        my $h3 = $schema->storage->dbh()->prepare($q3);
        $h3->execute($analytics_protocol_id, $analytics_experiment_type_cvterm_id);
        ($analytics_nd_experiment_id) = $h3->fetchrow_array();
    }

    my $analytics_select = $protocol_properties->{analytics_select};
    my $trait_id_list = $protocol_properties->{observation_variable_id_list};
    my $compute_relationship_matrix_from_htp_phenotypes = $protocol_properties->{relationship_matrix_type};
    my $compute_relationship_matrix_from_htp_phenotypes_type = $protocol_properties->{htp_pheno_rel_matrix_type};
    my $compute_relationship_matrix_from_htp_phenotypes_time_points = $protocol_properties->{htp_pheno_rel_matrix_time_points};
    my $compute_relationship_matrix_from_htp_phenotypes_blues_inversion = $protocol_properties->{htp_pheno_rel_matrix_blues_inversion};
    my $compute_from_parents = $protocol_properties->{genotype_compute_from_parents};
    my $include_pedgiree_info_if_compute_from_parents = $protocol_properties->{include_pedgiree_info_if_compute_from_parents};
    my $use_parental_grms_if_compute_from_parents = $protocol_properties->{use_parental_grms_if_compute_from_parents};
    my $use_area_under_curve = $protocol_properties->{use_area_under_curve};
    my $protocol_id = $protocol_properties->{genotyping_protocol_id};
    my $tolparinv = $protocol_properties->{tolparinv};
    my $legendre_order_number = $protocol_properties->{legendre_order_number};
    my $permanent_environment_structure = $protocol_properties->{permanent_environment_structure};
    my $permanent_environment_structure_phenotype_correlation_traits = $protocol_properties->{permanent_environment_structure_phenotype_correlation_traits};
    my $permanent_environment_structure_phenotype_trait_ids = $protocol_properties->{permanent_environment_structure_phenotype_trait_ids};
    my @env_variance_percents = split ',', $protocol_properties->{env_variance_percent};
    my $number_iterations = $protocol_properties->{number_iterations};
    my $simulated_environment_real_data_trait_id = $protocol_properties->{simulated_environment_real_data_trait_id};
    my $correlation_between_times = $protocol_properties->{sim_env_change_over_time_correlation} || 0.9;
    my $fixed_effect_type = $protocol_properties->{fixed_effect_type} || 'replicate';
    my $fixed_effect_trait_id = $protocol_properties->{fixed_effect_trait_id};
    my $fixed_effect_quantiles = $protocol_properties->{fixed_effect_quantiles};
    my $env_iterations = $protocol_properties->{env_iterations};
    my $perform_cv = $protocol_properties->{perform_cv} || 0;

    my $shared_cluster_dir_config = $c->config->{cluster_shared_tempdir};
    my $tmp_stats_dir = $shared_cluster_dir_config."/tmp_drone_statistics";
    mkdir $tmp_stats_dir if ! -d $tmp_stats_dir;
    my ($grm_rename_tempfile_fh, $grm_rename_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    $grm_rename_tempfile .= '.GRM';
    my ($minimization_iterations_tempfile_fh, $minimization_iterations_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);

    my $dir = $c->tempfiles_subdir('/tmp_drone_statistics');
    my $minimization_iterations_tempfile_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
    $minimization_iterations_tempfile_string .= '.png';
    my $minimization_iterations_figure_tempfile = $c->config->{basepath}."/".$minimization_iterations_tempfile_string;

    my $env_effects_figure_tempfile_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
    $env_effects_figure_tempfile_string .= '.png';
    my $env_effects_figure_tempfile = $c->config->{basepath}."/".$env_effects_figure_tempfile_string;

    my $statistics_select;
    my $blupf90_solutions_tempfile;
    my $yhat_residual_tempfile;
    my $grm_file;

    my $field_trial_design;

    eval {
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
                $related_time_terms = SGN::Controller::AJAX::DroneImagery::DroneImagery::_perform_gdd_calculation_and_drone_run_time_saving($c, $schema, $field_trial_project_id, $drone_run_project_id, $c->config->{noaa_ncdc_access_token}, 50, 'average_daily_temp_sum');
                $refresh_mat_views = 1;
            }
            else {
                $related_time_terms = decode_json $related_time_terms_json;
            }
            if (!exists($related_time_terms->{gdd_average_temp})) {
                $related_time_terms = SGN::Controller::AJAX::DroneImagery::DroneImagery::_perform_gdd_calculation_and_drone_run_time_saving($c, $schema, $field_trial_project_id, $drone_run_project_id, $c->config->{noaa_ncdc_access_token}, 50, 'average_daily_temp_sum');
                $refresh_mat_views = 1;
            }
        }
        if ($refresh_mat_views) {
            my $bs = CXGN::BreederSearch->new( { dbh=>$c->dbc->dbh, dbname=>$c->config->{dbname}, } );
            my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'fullview', 'nonconcurrent', $c->config->{basepath});
            sleep(10);
        }
    };

    my ($permanent_environment_structure_tempfile_fh, $permanent_environment_structure_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    my ($permanent_environment_structure_env_tempfile_fh, $permanent_environment_structure_env_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    my ($permanent_environment_structure_env_tempfile2_fh, $permanent_environment_structure_env_tempfile2) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    my ($permanent_environment_structure_env_tempfile_mat_fh, $permanent_environment_structure_env_tempfile_mat) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    my ($sim_env_changing_mat_tempfile_fh, $sim_env_changing_mat_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    my ($sim_env_changing_mat_full_tempfile_fh, $sim_env_changing_mat_full_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    my ($stats_tempfile_fh, $stats_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    my ($stats_tempfile_2_fh, $stats_tempfile_2) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    $stats_tempfile_2 .= '.dat';
    my ($stats_tempfile_fixed_effect_binning_fh, $stats_tempfile_fixed_effect_binning) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    my ($stats_tempfile_fixed_effect_binned_fh, $stats_tempfile_fixed_effect_binned) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    my ($stats_prep_tempfile_fh, $stats_prep_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    my ($stats_prep_factor_tempfile_fh, $stats_prep_factor_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    my ($parameter_tempfile_fh, $parameter_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    $parameter_tempfile .= '.f90';
    my ($parameter_asreml_tempfile_fh, $parameter_asreml_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    $parameter_asreml_tempfile .= '.as';
    my ($coeff_genetic_tempfile_fh, $coeff_genetic_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    $coeff_genetic_tempfile .= '_genetic_coefficients.csv';
    my ($coeff_pe_tempfile_fh, $coeff_pe_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    $coeff_pe_tempfile .= '_permanent_environment_coefficients.csv';

    my $stats_out_tempfile_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/drone_stats_XXXXX');
    my $stats_out_tempfile = $c->config->{basepath}."/".$stats_out_tempfile_string;

    my ($stats_prep2_tempfile_fh, $stats_prep2_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    my ($stats_out_htp_rel_tempfile_input_fh, $stats_out_htp_rel_tempfile_input) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    my ($stats_out_htp_rel_tempfile_fh, $stats_out_htp_rel_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);

    my $stats_out_htp_rel_tempfile_out_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/drone_stats_XXXXX');
    my $stats_out_htp_rel_tempfile_out = $c->config->{basepath}."/".$stats_out_htp_rel_tempfile_out_string;

    my ($stats_out_pe_pheno_rel_tempfile_fh, $stats_out_pe_pheno_rel_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    my ($stats_out_pe_pheno_rel_tempfile2_fh, $stats_out_pe_pheno_rel_tempfile2) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);

    my ($stats_out_pe_pheno_rel_2dspline_grm_tempfile_fh, $stats_out_pe_pheno_rel_2dspline_grm_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    my ($stats_out_pe_pheno_rel_tempfile3_fh, $stats_out_pe_pheno_rel_tempfile3) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    my ($stats_out_pe_pheno_rel_tempfile4_fh, $stats_out_pe_pheno_rel_tempfile4) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    my ($stats_out_pe_pheno_rel_tempfile5_fh, $stats_out_pe_pheno_rel_tempfile5) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);

    my ($stats_out_param_tempfile_fh, $stats_out_param_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    my ($stats_out_tempfile_row_fh, $stats_out_tempfile_row) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    my ($stats_out_tempfile_col_fh, $stats_out_tempfile_col) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    my ($stats_out_tempfile_2dspl_fh, $stats_out_tempfile_2dspl) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    my ($stats_out_tempfile_residual_fh, $stats_out_tempfile_residual) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    my ($stats_out_tempfile_genetic_fh, $stats_out_tempfile_genetic) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    my ($stats_out_tempfile_permanent_environment_fh, $stats_out_tempfile_permanent_environment) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    my ($stats_out_tempfile_varcomp_fh, $stats_out_tempfile_varcomp) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);

    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();

    my $csv = Text::CSV->new({ sep_char => "\t" });

    my @legendre_coeff_exec = (
        '1 * $b',
        '$time * $b',
        '(1/2*(3*$time**2 - 1)*$b)',
        '1/2*(5*$time**3 - 3*$time)*$b',
        '1/8*(35*$time**4 - 30*$time**2 + 3)*$b',
        '1/16*(63*$time**5 - 70*$time**2 + 15*$time)*$b',
        '1/16*(231*$time**6 - 315*$time**4 + 105*$time**2 - 5)*$b'
    );

    my $env_sim_exec = {
        "linear_gradient" => '( ($a_env-$a_env_adjustment)*$row_number/$max_row + ($b_env-$b_env_adjustment)*$col_number/$max_col )',
        "random_1d_normal_gradient" => '( (1/(2*3.14159)) * exp(-1*(( ($row_number-$row_number_adjustment) /$max_row)**2)/2) )',
        "random_2d_normal_gradient" => '( exp( (-1/(2*(1-$ro_env**2))) * ( ( (( ($row_number-$row_number_adjustment) - $mean_row)/$max_row)**2)/($sig_row**2) + ( (( ($col_number-$col_number_adjustment) - $mean_col)/$max_col)**2)/($sig_col**2) - ((2*$ro_env)*(( ($row_number-$row_number_adjustment) - $mean_row)/$max_row)*(( ($col_number-$col_number_adjustment) - $mean_col)/$max_col) )/($sig_row*$sig_col) ) ) / (2*3.14159*$sig_row*$sig_col*sqrt(1-$ro_env**2)) )',
        "random" => 'rand(1)'
    };

    my @plot_ids_ordered;
    my $F;
    my $q_time;
    my $h_time;
    my @seen_rows_array;
    my @seen_cols_array;
    my $row_stat;
    my $mean_row;
    my $sig_row;
    my $col_stat;
    my $mean_col;
    my $sig_col;

    my $spatial_effects_plots;
    my $spatial_effects_files_store;
    my $env_corr_res;
    my $env_varcomps;

    my (@sorted_trait_names, @unique_accession_names, @unique_plot_names, %trait_name_encoder, %trait_to_time_map);

    foreach my $env_variance_percent (@env_variance_percents) {
        for my $iterations (1..$number_iterations) {
            print STDERR "ITERATION $iterations\n";

            my $a_env = $env_iterations->{$iterations}->{a_env};
            my $b_env = $env_iterations->{$iterations}->{b_env};
            my $ro_env = $env_iterations->{$iterations}->{ro_env};
            my $row_ro_env = $env_iterations->{$iterations}->{row_ro_env};

            my $fixed_effect_trait_data;
            if ($fixed_effect_type eq 'fixed_effect_trait') {
                my $phenotypes_search_fixed_effect = CXGN::Phenotypes::SearchFactory->instantiate(
                    'MaterializedViewTable',
                    {
                        bcs_schema=>$schema,
                        data_level=>'plot',
                        trait_list=>[$fixed_effect_trait_id],
                        trial_list=>$field_trial_id_list,
                        include_timestamp=>0,
                        exclude_phenotype_outlier=>0
                    }
                );
                my ($fixed_effect_data, $fixed_effect_unique_traits) = $phenotypes_search_fixed_effect->search();

                open(my $F, ">", $stats_tempfile_fixed_effect_binning) || die "Can't open file ".$stats_tempfile_fixed_effect_binning;
                    print $F "stock_id\tvalue_continuous\tvalue_binned\n";
                    foreach my $obs_unit (@$fixed_effect_data){
                        my $obsunit_stock_id = $obs_unit->{observationunit_stock_id};
                        my $observations = $obs_unit->{observations};
                        foreach (@$observations){
                            my $value = $_->{value};
                            print $F "$obsunit_stock_id\t$value\t0\n";
                        }
                    }
                close($F);

                my $cmd_factor = 'R -e "library(data.table); library(dplyr);
                mat <- fread(\''.$stats_tempfile_fixed_effect_binning.'\', header=TRUE, sep=\'\t\');
                mat <- mat %>% mutate(value_binned = cut(value_continuous, breaks = unique(quantile(value_continuous,probs=seq.int(0,1, by=1/'.$fixed_effect_quantiles.'))), include.lowest=TRUE));
                mat\$value_binned <- as.numeric(as.factor(mat\$value_binned));
                write.table(mat, file=\''.$stats_tempfile_fixed_effect_binned.'\', row.names=FALSE, col.names=TRUE, sep=\'\t\');"';
                my $status_factor = system($cmd_factor);

                open(my $fh_factor, '<', $stats_tempfile_fixed_effect_binned) or die "Could not open file '$stats_tempfile_fixed_effect_binned' $!";
                    print STDERR "Opened $stats_tempfile_fixed_effect_binned\n";
                    my $header = <$fh_factor>;
                    if ($csv->parse($header)) {
                        my @header_cols = $csv->fields();
                    }

                    while (my $row = <$fh_factor>) {
                        my @columns;
                        if ($csv->parse($row)) {
                            @columns = $csv->fields();
                        }
                        my $plot_id = $columns[0];
                        my $value = $columns[1];
                        my $value_binned = $columns[2];
                        $fixed_effect_trait_data->{$plot_id} = $value_binned;
                    }
                close($fh_factor);
            }

            my (%phenotype_data_original, @data_matrix_original, @data_matrix_phenotypes_original);
            my (%trait_name_encoder_rev, %stock_info, %unique_accessions, %seen_days_after_plantings, %seen_times, %obsunit_row_col, %stock_row_col, %stock_name_row_col, %stock_row_col_id, %seen_rows, %seen_cols, %seen_plots, %seen_plot_names, %plot_id_map, %trait_composing_info, %seen_trial_ids, %seen_trait_names, %unique_traits_ids, @phenotype_header, $header_string);
            my (@sorted_scaled_ln_times, %plot_id_factor_map_reverse, %plot_id_count_map_reverse, %accession_id_factor_map, %accession_id_factor_map_reverse, %time_count_map_reverse, @rep_time_factors, @ind_rep_factors, %plot_rep_time_factor_map, %seen_rep_times, %seen_ind_reps, @legs_header, %polynomial_map);
            my $time_min = 100000000;
            my $time_max = 0;
            my $min_row = 10000000000;
            my $max_row = 0;
            my $min_col = 10000000000;
            my $max_col = 0;
            my $phenotype_min_original = 1000000000;
            my $phenotype_max_original = -1000000000;

            if ($statistics_select_original eq 'airemlf90_grm_random_regression_dap_blups') {
                $statistics_select = 'airemlf90_grm_random_regression_dap_blups';

                print STDERR "PREPARE RELATIONSHIP MATRIX\n";
                eval {
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
                            my $status = system($cmd);

                            my %rel_pos_def_result_hash;
                            open(my $F3, '<', $grm_out_tempfile) or die "Could not open file '$grm_out_tempfile' $!";
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

                            my %result_hash_2dspline_rr_structure;
                            my $data_2dspline_rr = '';
                            foreach my $s (sort @accession_ids) {
                                foreach my $c (sort @accession_ids) {
                                    if (!exists($result_hash_2dspline_rr_structure{$s}->{$c}) && !exists($result_hash_2dspline_rr_structure{$c}->{$s})) {
                                        my $val = $rel_pos_def_result_hash{$s}->{$c};
                                        if (defined $val and length $val) {
                                            $result_hash_2dspline_rr_structure{$s}->{$c} = $val;
                                            $result_hash_2dspline_rr_structure{$c}->{$s} = $val;
                                            $data_2dspline_rr .= "S$s\tS$c\t$val\n";
                                            if ($s != $c) {
                                                $data_2dspline_rr .= "S$c\tS$s\t$val\n";
                                            }
                                        }
                                    }
                                }
                            }

                            open(my $F5, ">", $stats_out_pe_pheno_rel_2dspline_grm_tempfile) || die "Can't open file ".$stats_out_pe_pheno_rel_2dspline_grm_tempfile;
                                print $F5 $data_2dspline_rr;
                            close($F5);

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
                            my $status = system($cmd);

                            my %rel_pos_def_result_hash;
                            open(my $F3, '<', $grm_out_tempfile) or die "Could not open file '$grm_out_tempfile' $!";
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

                            my %result_hash_2dspline_rr_structure;
                            my $data_2dspline_rr = '';
                            foreach my $s (sort @accession_ids) {
                                foreach my $c (sort @accession_ids) {
                                    if (!exists($result_hash_2dspline_rr_structure{$s}->{$c}) && !exists($result_hash_2dspline_rr_structure{$c}->{$s})) {
                                        my $val = $rel_pos_def_result_hash{$s}->{$c};
                                        if (defined $val and length $val) {
                                            $result_hash_2dspline_rr_structure{$s}->{$c} = $val;
                                            $result_hash_2dspline_rr_structure{$c}->{$s} = $val;
                                            $data_2dspline_rr .= "S$s\tS$c\t$val\n";
                                            if ($s != $c) {
                                                $data_2dspline_rr .= "S$c\tS$s\t$val\n";
                                            }
                                        }
                                    }
                                }
                            }

                            open(my $F5, ">", $stats_out_pe_pheno_rel_2dspline_grm_tempfile) || die "Can't open file ".$stats_out_pe_pheno_rel_2dspline_grm_tempfile;
                                print $F5 $data_2dspline_rr;
                            close($F5);

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

                            $grm_search_params->{download_format} = 'three_column_reciprocal';
                            my $geno_rr_2dspline_env = CXGN::Genotype::GRM->new($grm_search_params);
                            my $grm_data_rr_2dspline_env = $geno_rr_2dspline_env->download_grm(
                                'data',
                                $shared_cluster_dir_config,
                                $c->config->{backend},
                                $c->config->{cluster_host},
                                $c->config->{'web_cluster_queue'},
                                $c->config->{basepath}
                            );

                            open(my $F5, ">", $stats_out_pe_pheno_rel_2dspline_grm_tempfile) || die "Can't open file ".$stats_out_pe_pheno_rel_2dspline_grm_tempfile;
                                print $F5 $grm_data_rr_2dspline_env;
                            close($F5);
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
                            my $status = system($htp_cmd);
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
                            my $status = system($htp_cmd);
                        }
                        else {
                            $c->stash->{rest} = { error => "The value of $compute_relationship_matrix_from_htp_phenotypes_type htp_pheno_rel_matrix_type is not valid!" };
                            return;
                        }

                        open(my $htp_rel_res, '<', $stats_out_htp_rel_tempfile) or die "Could not open file '$stats_out_htp_rel_tempfile' $!";
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

                        my %result_hash_2dspline_rr_structure;
                        my $data_2dspline_rr = '';
                        foreach my $s (sort @accession_ids) {
                            foreach my $c (sort @accession_ids) {
                                if (!exists($result_hash_2dspline_rr_structure{$s}->{$c}) && !exists($result_hash_2dspline_rr_structure{$c}->{$s})) {
                                    my $val = $rel_htp_result_hash{$s}->{$c};
                                    if (defined $val and length $val) {
                                        $result_hash_2dspline_rr_structure{$s}->{$c} = $val;
                                        $result_hash_2dspline_rr_structure{$c}->{$s} = $val;
                                        $data_2dspline_rr .= "S$s\tS$c\t$val\n";
                                        if ($s != $c) {
                                            $data_2dspline_rr .= "S$c\tS$s\t$val\n";
                                        }
                                    }
                                }
                            }
                        }

                        open(my $F5, ">", $stats_out_pe_pheno_rel_2dspline_grm_tempfile) || die "Can't open file ".$stats_out_pe_pheno_rel_2dspline_grm_tempfile;
                            print $F5 $data_2dspline_rr;
                        close($F5);

                        open(my $htp_rel_out, ">", $stats_out_htp_rel_tempfile_out) || die "Can't open file ".$stats_out_htp_rel_tempfile_out;
                            print $htp_rel_out $data_rel_htp;
                        close($htp_rel_out);

                        $grm_file = $stats_out_htp_rel_tempfile_out;
                    }
                    else {
                        $c->stash->{rest} = { error => "The value of $compute_relationship_matrix_from_htp_phenotypes is not valid!" };
                        return;
                    }
                };

                print STDERR "PREPARE ORIGINAL PHENOTYPE FILES\n";
                eval {
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

                    $q_time = "SELECT t.cvterm_id FROM cvterm as t JOIN cv ON(t.cv_id=cv.cv_id) WHERE t.name=? and cv.name=?;";
                    $h_time = $schema->storage->dbh()->prepare($q_time);

                    foreach my $obs_unit (@$data){
                        my $germplasm_name = $obs_unit->{germplasm_uniquename};
                        my $germplasm_stock_id = $obs_unit->{germplasm_stock_id};
                        my $replicate_number = $obs_unit->{obsunit_rep} || '';
                        my $block_number = $obs_unit->{obsunit_block} || '';
                        my $obsunit_stock_id = $obs_unit->{observationunit_stock_id};
                        my $obsunit_stock_uniquename = $obs_unit->{observationunit_uniquename};
                        my $row_number = $obs_unit->{obsunit_row_number} || '';
                        my $col_number = $obs_unit->{obsunit_col_number} || '';
                        push @plot_ids_ordered, $obsunit_stock_id;

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

                        $obsunit_row_col{$row_number}->{$col_number} = {
                            stock_id => $obsunit_stock_id,
                            stock_uniquename => $obsunit_stock_uniquename
                        };
                        $seen_rows{$row_number}++;
                        $seen_cols{$col_number}++;
                        $plot_id_map{$obsunit_stock_id} = $obsunit_stock_uniquename;
                        $seen_plot_names{$obsunit_stock_uniquename}++;
                        $seen_plots{$obsunit_stock_id} = $obsunit_stock_uniquename;
                        $stock_row_col{$obsunit_stock_id} = {
                            row_number => $row_number,
                            col_number => $col_number,
                            obsunit_stock_id => $obsunit_stock_id,
                            obsunit_name => $obsunit_stock_uniquename,
                            rep => $replicate_number,
                            block => $block_number,
                            germplasm_stock_id => $germplasm_stock_id,
                            germplasm_name => $germplasm_name
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
                        $stock_row_col_id{$row_number}->{$col_number} = $obsunit_stock_id;
                        $unique_accessions{$germplasm_name}++;
                        $stock_info{$germplasm_stock_id} = {
                            uniquename => $germplasm_name
                        };
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

                                my $value = $_->{value};
                                my $trait_name = $_->{trait_name};
                                $phenotype_data_original{$obsunit_stock_uniquename}->{$time} = $value;
                                $seen_times{$time} = $trait_name;
                                $seen_trait_names{$trait_name} = $time_term_string;
                                $trait_to_time_map{$trait_name} = $time;

                                if ($value < $phenotype_min_original) {
                                    $phenotype_min_original = $value;
                                }
                                elsif ($value >= $phenotype_max_original) {
                                    $phenotype_max_original = $value;
                                }
                            }
                        }
                    }
                    if (scalar(keys %seen_times) == 0) {
                        $c->stash->{rest} = { error => "There are no phenotypes with associated days after planting time associated to the traits you have selected!"};
                        return;
                    }

                    @sorted_trait_names = sort {$a <=> $b} keys %seen_times;
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

                    foreach (@sorted_trait_names) {
                        if ($_ < $time_min) {
                            $time_min = $_;
                        }
                        if ($_ >= $time_max) {
                            $time_max = $_;
                        }
                    }
                    print STDERR Dumper [$time_min, $time_max];

                    while ( my ($trait_name, $time_term) = each %seen_trait_names) {
                        push @{$trait_composing_info{$trait_name}}, $time_term;
                    }

                    @unique_plot_names = sort keys %seen_plot_names;
                    if ($legendre_order_number >= scalar(@sorted_trait_names)) {
                        $legendre_order_number = scalar(@sorted_trait_names) - 1;
                    }

                    my @sorted_trait_names_scaled;
                    my $leg_pos_counter = 0;
                    foreach (@sorted_trait_names) {
                        my $scaled_time = ($_ - $time_min)/($time_max - $time_min);
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
                    my $status = system($cmd);

                    open(my $fh, '<', $stats_out_tempfile) or die "Could not open file '$stats_out_tempfile' $!";
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
                        print $F_prep "accession_id,accession_id_factor,plot_id,plot_id_factor,replicate,time,replicate_time,ind_replicate,fixed_effect_trait_binned\n";
                        foreach my $p (@unique_plot_names) {
                            my $replicate = $stock_name_row_col{$p}->{rep};
                            my $germplasm_stock_id = $stock_name_row_col{$p}->{germplasm_stock_id};
                            my $obsunit_stock_id = $stock_name_row_col{$p}->{obsunit_stock_id};
                            my $fixed_effect_trait_value = defined($fixed_effect_trait_data->{$obsunit_stock_id}) ? $fixed_effect_trait_data->{$obsunit_stock_id} : 0;
                            foreach my $t (@sorted_trait_names) {
                                print $F_prep "$germplasm_stock_id,,$obsunit_stock_id,,$replicate,$t,$replicate"."_"."$t,$germplasm_stock_id"."_"."$replicate,$fixed_effect_trait_value\n";
                            }
                        }
                    close($F_prep);

                    my $cmd_factor = 'R -e "library(data.table); library(dplyr);
                    mat <- fread(\''.$stats_prep_tempfile.'\', header=TRUE, sep=\',\');
                    mat\$replicate_time <- as.numeric(as.factor(mat\$replicate_time));
                    mat\$ind_replicate <- as.numeric(as.factor(mat\$ind_replicate));
                    mat\$accession_id_factor <- as.numeric(as.factor(mat\$accession_id));
                    mat\$plot_id_factor <- as.numeric(as.factor(mat\$plot_id));
                    ';
                    if ($fixed_effect_type eq 'fixed_effect_trait') {
                        $cmd_factor .= 'mat\$replicate_time <- as.numeric(as.factor(paste(mat\$fixed_effect_trait_binned, mat\$time, sep=\'_\')));';
                    }
                    $cmd_factor .= 'write.table(mat, file=\''.$stats_prep_factor_tempfile.'\', row.names=FALSE, col.names=TRUE, sep=\'\t\');"';
                    my $status_factor = system($cmd_factor);

                    open(my $fh_factor, '<', $stats_prep_factor_tempfile) or die "Could not open file '$stats_prep_factor_tempfile' $!";
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
                            $stock_row_col{$plot_id}->{plot_id_factor} = $plot_id_factor;
                            $stock_name_row_col{$plot_id_map{$plot_id}}->{plot_id_factor} = $plot_id_factor;
                            $plot_rep_time_factor_map{$plot_id}->{$rep}->{$time} = $rep_time;
                            $seen_rep_times{$rep_time}++;
                            $seen_ind_reps{$plot_id_factor}++;
                            $accession_id_factor_map{$accession_id} = $accession_id_factor;
                            $accession_id_factor_map_reverse{$accession_id_factor} = $stock_info{$accession_id}->{uniquename};
                            $plot_id_factor_map_reverse{$plot_id_factor} = $seen_plots{$plot_id};
                            $plot_id_count_map_reverse{$line_factor_count} = $seen_plots{$plot_id};
                            $time_count_map_reverse{$line_factor_count} = $time;
                            $line_factor_count++;
                        }
                    close($fh_factor);
                    @rep_time_factors = sort keys %seen_rep_times;
                    @ind_rep_factors = sort keys %seen_ind_reps;

                    foreach my $p (@unique_plot_names) {
                        my $row_number = $stock_name_row_col{$p}->{row_number};
                        my $col_number = $stock_name_row_col{$p}->{col_number};
                        my $replicate = $stock_name_row_col{$p}->{rep};
                        my $block = $stock_name_row_col{$p}->{block};
                        my $germplasm_stock_id = $stock_name_row_col{$p}->{germplasm_stock_id};
                        my $germplasm_name = $stock_name_row_col{$p}->{germplasm_name};
                        my $obsunit_stock_id = $stock_name_row_col{$p}->{obsunit_stock_id};

                        my @data_matrix_phenotypes_row;
                        my $current_trait_index = 0;
                        foreach my $t (@sorted_trait_names) {
                            my @row = (
                                $accession_id_factor_map{$germplasm_stock_id},
                                $obsunit_stock_id,
                                $replicate,
                                $t,
                                $plot_rep_time_factor_map{$obsunit_stock_id}->{$replicate}->{$t},
                                $stock_row_col{$obsunit_stock_id}->{plot_id_factor}
                            );

                            my $polys = $polynomial_map{$t};
                            push @row, @$polys;

                            if (defined($phenotype_data_original{$p}->{$t})) {
                                if ($use_area_under_curve) {
                                    my $val = 0;
                                    foreach my $counter (0..$current_trait_index) {
                                        if ($counter == 0) {
                                            $val = $val + $phenotype_data_original{$p}->{$sorted_trait_names[$counter]} + 0;
                                        }
                                        else {
                                            my $t1 = $sorted_trait_names[$counter-1];
                                            my $t2 = $sorted_trait_names[$counter];
                                            my $p1 = $phenotype_data_original{$p}->{$t1} + 0;
                                            my $p2 = $phenotype_data_original{$p}->{$t2} + 0;
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
                                    push @row, $phenotype_data_original{$p}->{$t} + 0;
                                    push @data_matrix_phenotypes_row, $phenotype_data_original{$p}->{$t} + 0;
                                }
                            } else {
                                print STDERR $p." : $t : $germplasm_name : NA \n";
                                push @row, '';
                                push @data_matrix_phenotypes_row, 'NA';
                            }

                            push @data_matrix_original, \@row;
                            push @data_matrix_phenotypes_original, \@data_matrix_phenotypes_row;

                            $current_trait_index++;
                        }
                    }

                    for (0..$legendre_order_number) {
                        push @legs_header, "legendre$_";
                    }
                    @phenotype_header = ("id", "plot_id", "replicate", "time", "replicate_time", "ind_replicate", @legs_header, "phenotype");
                    open($F, ">", $stats_tempfile_2) || die "Can't open file ".$stats_tempfile_2;
                        foreach (@data_matrix_original) {
                            my $line = join ' ', @$_;
                            print $F "$line\n";
                        }
                    close($F);

                    open(my $F2, ">", $stats_prep2_tempfile) || die "Can't open file ".$stats_prep2_tempfile;
                        foreach (@data_matrix_phenotypes_original) {
                            my $line = join ',', @$_;
                            print $F2 "$line\n";
                        }
                    close($F2);

                    if ($permanent_environment_structure eq 'euclidean_rows_and_columns') {
                        my $data = '';
                        my %euclidean_distance_hash;
                        my $min_euc_dist = 10000000000000000000;
                        my $max_euc_dist = 0;
                        foreach my $s (sort { $a <=> $b } @plot_ids_ordered) {
                            foreach my $r (sort { $a <=> $b } @plot_ids_ordered) {
                                my $s_factor = $stock_name_row_col{$plot_id_map{$s}}->{plot_id_factor};
                                my $r_factor = $stock_name_row_col{$plot_id_map{$r}}->{plot_id_factor};
                                if (!exists($euclidean_distance_hash{$s_factor}->{$r_factor}) && !exists($euclidean_distance_hash{$r_factor}->{$s_factor})) {
                                    my $row_1 = $stock_name_row_col{$plot_id_map{$s}}->{row_number};
                                    my $col_1 = $stock_name_row_col{$plot_id_map{$s}}->{col_number};
                                    my $row_2 = $stock_name_row_col{$plot_id_map{$r}}->{row_number};
                                    my $col_2 = $stock_name_row_col{$plot_id_map{$r}}->{col_number};
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
                            my @row = ($stock_name_row_col{$p}->{plot_id_factor});
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
                        mat_pheno <- mat_agg[,-1];
                        cor_mat <- cor(t(mat_pheno));
                        rownames(cor_mat) <- mat_agg\$plot_id;
                        colnames(cor_mat) <- mat_agg\$plot_id;
                        range01 <- function(x){(x-min(x))/(max(x)-min(x))};
                        cor_mat <- range01(cor_mat);
                        write.table(cor_mat, file=\''.$stats_out_pe_pheno_rel_tempfile2.'\', row.names=TRUE, col.names=TRUE, sep=\'\t\');"';
                        # print STDERR Dumper $pe_rel_cmd;
                        my $status_pe_rel = system($pe_rel_cmd);

                        open(my $pe_rel_res, '<', $stats_out_pe_pheno_rel_tempfile2) or die "Could not open file '$stats_out_pe_pheno_rel_tempfile2' $!";
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
                        foreach my $s (sort { $a <=> $b } @plot_ids_ordered) {
                            foreach my $r (sort { $a <=> $b } @plot_ids_ordered) {
                                my $s_factor = $stock_name_row_col{$plot_id_map{$s}}->{plot_id_factor};
                                my $r_factor = $stock_name_row_col{$plot_id_map{$r}}->{plot_id_factor};
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
                    elsif ($permanent_environment_structure eq 'phenotype_2dspline_effect') {
                        my $phenotypes_search_permanent_environment_structure = CXGN::Phenotypes::SearchFactory->instantiate(
                            'MaterializedViewTable',
                            {
                                bcs_schema=>$schema,
                                data_level=>'plot',
                                trial_list=>$field_trial_id_list,
                                trait_list=>$permanent_environment_structure_phenotype_trait_ids,
                                include_timestamp=>0,
                                exclude_phenotype_outlier=>0
                            }
                        );
                        my ($data_permanent_environment_structure, $unique_traits_permanent_environment_structure) = $phenotypes_search_permanent_environment_structure->search();
                        my @sorted_trait_names_permanent_environment_structure = sort keys %$unique_traits_permanent_environment_structure;

                        if (scalar(@$data_permanent_environment_structure) == 0) {
                            $c->stash->{rest} = { error => "There are no phenotypes for the permanent environment structure traits you have selected!"};
                            return;
                        }

                        my %seen_plot_names_pe;
                        my %phenotype_data_pe;
                        my %stock_name_row_col_pe;
                        foreach my $obs_unit (@$data_permanent_environment_structure){
                            my $germplasm_name = $obs_unit->{germplasm_uniquename};
                            my $germplasm_stock_id = $obs_unit->{germplasm_stock_id};
                            my $replicate_number = $obs_unit->{obsunit_rep} || '';
                            my $block_number = $obs_unit->{obsunit_block} || '';
                            my $obsunit_stock_id = $obs_unit->{observationunit_stock_id};
                            my $obsunit_stock_uniquename = $obs_unit->{observationunit_uniquename};
                            my $row_number = $obs_unit->{obsunit_row_number} || '';
                            my $col_number = $obs_unit->{obsunit_col_number} || '';
                            $seen_plot_names_pe{$obsunit_stock_uniquename}++;
                            $stock_name_row_col_pe{$obsunit_stock_uniquename} = {
                                row_number => $row_number,
                                col_number => $col_number,
                                obsunit_stock_id => $obsunit_stock_id,
                                obsunit_name => $obsunit_stock_uniquename,
                                rep => $replicate_number,
                                block => $block_number,
                                germplasm_stock_id => $germplasm_stock_id,
                                germplasm_name => $germplasm_name
                            };
                            my $observations = $obs_unit->{observations};
                            foreach (@$observations){
                                my $value = $_->{value};
                                my $trait_name = $_->{trait_name};
                                $phenotype_data_pe{$obsunit_stock_uniquename}->{$trait_name} = $value;
                            }
                        }

                        my @unique_plot_names_pe = sort keys %seen_plot_names_pe;

                        my %trait_name_encoder_permanent_environment_structure;
                        my %trait_name_encoder_rev_permanent_environment_structure;
                        my $trait_name_encoded_pe = 1;
                        foreach my $trait_name (@sorted_trait_names_permanent_environment_structure) {
                            if (!exists($trait_name_encoder_permanent_environment_structure{$trait_name})) {
                                my $trait_name_e = 't'.$trait_name_encoded_pe;
                                $trait_name_encoder_permanent_environment_structure{$trait_name} = $trait_name_e;
                                $trait_name_encoder_rev_permanent_environment_structure{$trait_name_e} = $trait_name;
                                $trait_name_encoded_pe++;
                            }
                        }

                        my @data_matrix_pe;
                        foreach my $p (@unique_plot_names_pe) {
                            my $row_number = $stock_name_row_col_pe{$p}->{row_number};
                            my $col_number = $stock_name_row_col_pe{$p}->{col_number};
                            my $replicate = $stock_name_row_col_pe{$p}->{rep};
                            my $block = $stock_name_row_col_pe{$p}->{block};
                            my $germplasm_stock_id = $stock_name_row_col_pe{$p}->{germplasm_stock_id};
                            my $germplasm_name = $stock_name_row_col_pe{$p}->{germplasm_name};
                            my $obsunit_stock_id = $stock_name_row_col_pe{$p}->{obsunit_stock_id};

                            my @row = ($replicate, $block, "S".$germplasm_stock_id, $obsunit_stock_id, $row_number, $col_number, $row_number, $col_number);

                            foreach my $t (@sorted_trait_names_permanent_environment_structure) {
                                if (defined($phenotype_data_pe{$p}->{$t})) {
                                    push @row, $phenotype_data_pe{$p}->{$t};
                                } else {
                                    print STDERR $p." : $t : $germplasm_name : NA \n";
                                    push @row, 'NA';
                                }
                            }
                            push @data_matrix_pe, \@row;
                        }

                        my @phenotype_header_pe = ("replicate", "block", "id", "plot_id", "rowNumber", "colNumber", "rowNumberFactor", "colNumberFactor");
                        foreach (@sorted_trait_names_permanent_environment_structure) {
                            push @phenotype_header_pe, $trait_name_encoder_permanent_environment_structure{$_};
                        }
                        my $header_string_pe = join ',', @phenotype_header_pe;

                        open($F, ">", $stats_out_pe_pheno_rel_tempfile3) || die "Can't open file ".$stats_out_pe_pheno_rel_tempfile3;
                            print $F $header_string_pe."\n";
                            foreach (@data_matrix_pe) {
                                my $line = join ',', @$_;
                                print $F "$line\n";
                            }
                        close($F);

                        my @encoded_traits_pe = values %trait_name_encoder_permanent_environment_structure;
                        my $encoded_trait_string_pe = join ',', @encoded_traits_pe;
                        my $number_traits_pe = scalar(@encoded_traits_pe);
                        my $cbind_string_pe = $number_traits_pe > 1 ? "cbind($encoded_trait_string_pe)" : $encoded_trait_string_pe;

                        my $statistics_cmd_pe = 'R -e "library(sommer); library(data.table); library(reshape2);
                        mat <- data.frame(fread(\''.$stats_out_pe_pheno_rel_tempfile3.'\', header=TRUE, sep=\',\'));
                        geno_mat_3col <- data.frame(fread(\''.$stats_out_pe_pheno_rel_2dspline_grm_tempfile.'\', header=FALSE, sep=\'\t\'));
                        geno_mat <- acast(geno_mat_3col, V1~V2, value.var=\'V3\');
                        geno_mat[is.na(geno_mat)] <- 0;
                        mat\$rowNumber <- as.numeric(mat\$rowNumber);
                        mat\$colNumber <- as.numeric(mat\$colNumber);
                        mat\$rowNumberFactor <- as.factor(mat\$rowNumberFactor);
                        mat\$colNumberFactor <- as.factor(mat\$colNumberFactor);
                        mix <- mmer('.$cbind_string_pe.'~1 + replicate, random=~vs(id, Gu=geno_mat, Gtc=unsm('.$number_traits_pe.')) +vs(spl2D(rowNumber, colNumber), Gtc=diag('.$number_traits_pe.')), rcov=~vs(units, Gtc=unsm('.$number_traits_pe.')), data=mat, tolparinv='.$tolparinv.');
                        if (!is.null(mix\$U)) {
                        #gen_cor <- cov2cor(mix\$sigma\$\`u:id\`);
                        X <- with(mat, spl2D(rowNumber, colNumber));
                        spatial_blup_results <- data.frame(plot_id = mat\$plot_id);
                        ';
                        my $trait_index = 1;
                        foreach my $enc_trait_name (@encoded_traits_pe) {
                            $statistics_cmd_pe .= '
                        blups'.$trait_index.' <- mix\$U\$\`u:rowNumber\`\$'.$enc_trait_name.';
                        spatial_blup_results\$'.$enc_trait_name.' <- data.matrix(X) %*% data.matrix(blups'.$trait_index.');
                            ';
                            $trait_index++;
                        }
                        $statistics_cmd_pe .= 'cor_mat <- cor(t(spatial_blup_results[,-1]));
                        rownames(cor_mat) <- spatial_blup_results\$plot_id;
                        colnames(cor_mat) <- spatial_blup_results\$plot_id;
                        range01 <- function(x){(x-min(x))/(max(x)-min(x))};
                        cor_mat <- range01(cor_mat);
                        write.table(spatial_blup_results, file=\''.$stats_out_pe_pheno_rel_tempfile5.'\', row.names=FALSE, col.names=TRUE, sep=\'\t\');
                        write.table(cor_mat, file=\''.$stats_out_pe_pheno_rel_tempfile4.'\', row.names=TRUE, col.names=TRUE, sep=\'\t\');
                        }
                        "';
                        # print STDERR Dumper $statistics_cmd;
                        eval {
                            my $status = system($statistics_cmd_pe);
                        };
                        my $run_stats_fault = 0;
                        my %rel_pe_result_hash;
                        my $current_env_row_count = 0;
                        if ($@) {
                            print STDERR "R ERROR\n";
                            print STDERR Dumper $@;
                            $run_stats_fault = 1;
                        }
                        else {
                            open(my $pe_rel_res, '<', $stats_out_pe_pheno_rel_tempfile4) or die "Could not open file '$stats_out_pe_pheno_rel_tempfile4' $!";
                                print STDERR "Opened $stats_out_pe_pheno_rel_tempfile4\n";
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
                                    $current_env_row_count++;
                                }
                            close($pe_rel_res);
                            # print STDERR Dumper \%rel_pe_result_hash;

                            my $data_rel_pe = '';
                            my %result_hash_pe;
                            foreach my $s (sort { $a <=> $b } @plot_ids_ordered) {
                                foreach my $r (sort { $a <=> $b } @plot_ids_ordered) {
                                    my $s_factor = $stock_name_row_col{$plot_id_map{$s}}->{plot_id_factor};
                                    my $r_factor = $stock_name_row_col{$plot_id_map{$r}}->{plot_id_factor};
                                    if (!exists($result_hash_pe{$s_factor}->{$r_factor}) && !exists($result_hash_pe{$r_factor}->{$s_factor})) {
                                        $result_hash_pe{$s_factor}->{$r_factor} = $rel_pe_result_hash{$s}->{$r};
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
                                print STDERR "Opened $permanent_environment_structure_tempfile\n";
                                print $pe_rel_out $data_rel_pe;
                            close($pe_rel_out);
                        }

                        if ($run_stats_fault || $current_env_row_count == 0) {
                            $c->stash->{rest} = { error => "There was a problem running the 2D-spline model for the permanent environment structure!"};
                            return;
                        }
                    }

                    print STDERR Dumper [$phenotype_min_original, $phenotype_max_original];

                    @unique_accession_names = sort keys %unique_accessions;
                    @unique_plot_names = sort keys %seen_plot_names;
                };

                @seen_rows_array = keys %seen_rows;
                @seen_cols_array = keys %seen_cols;
                $row_stat = Statistics::Descriptive::Full->new();
                $row_stat->add_data(@seen_rows_array);
                $mean_row = $row_stat->mean();
                $sig_row = $row_stat->variance();
                $col_stat = Statistics::Descriptive::Full->new();
                $col_stat->add_data(@seen_cols_array);
                $mean_col = $col_stat->mean();
                $sig_col = $col_stat->variance();

                my $result_1 = CXGN::DroneImagery::DroneImageryAnalyticsRunSimulation::perform_drone_imagery_analytics($schema, $a_env, $b_env, $ro_env, $row_ro_env, $env_variance_percent, $protocol_id, $statistics_select, $analytics_select, $tolparinv, $use_area_under_curve, $legendre_order_number, $permanent_environment_structure, \@legendre_coeff_exec, \%trait_name_encoder, \%trait_name_encoder_rev, \%stock_info, \%plot_id_map, \@sorted_trait_names, \%accession_id_factor_map, \@rep_time_factors, \@ind_rep_factors, \@unique_accession_names, \%plot_id_count_map_reverse, \@sorted_scaled_ln_times, \%time_count_map_reverse, \%accession_id_factor_map_reverse, \%seen_times, \%plot_id_factor_map_reverse, \%trait_to_time_map, \@unique_plot_names, \%stock_name_row_col, \%phenotype_data_original, \%plot_rep_time_factor_map, \%stock_row_col, \%stock_row_col_id, \%polynomial_map, \@plot_ids_ordered, $csv, $timestamp, $user_name, $stats_tempfile, $grm_file, $grm_rename_tempfile, $tmp_stats_dir, $stats_out_tempfile, $stats_out_tempfile_row, $stats_out_tempfile_col, $stats_out_tempfile_residual, $stats_out_tempfile_2dspl, $stats_prep2_tempfile, $stats_out_param_tempfile, $parameter_tempfile, $parameter_asreml_tempfile, $stats_tempfile_2, $permanent_environment_structure_tempfile, $permanent_environment_structure_env_tempfile, $permanent_environment_structure_env_tempfile2, $permanent_environment_structure_env_tempfile_mat, $sim_env_changing_mat_tempfile, $sim_env_changing_mat_full_tempfile, $yhat_residual_tempfile, $blupf90_solutions_tempfile, $coeff_genetic_tempfile, $coeff_pe_tempfile, $stats_out_tempfile_varcomp, $time_min, $time_max, $header_string, $env_sim_exec, $min_row, $max_row, $min_col, $max_col, $mean_row, $sig_row, $mean_col, $sig_col, $sim_env_change_over_time, $correlation_between_times, $field_trial_id_list, $simulated_environment_real_data_trait_id, $fixed_effect_type, $perform_cv);
                if (ref($result_1) eq 'HASH') {
                    $c->stash->{rest} = $result_1;
                    $c->detach();
                }
                my ($statistical_ontology_term_1, $analysis_model_training_data_file_type_1, $analysis_model_language_1, $sorted_residual_trait_names_array_1, $rr_unique_traits_hash_1, $rr_residual_unique_traits_hash_1, $statistics_cmd_1, $cmd_f90_1, $number_traits_1, $trait_to_time_map_hash_1,

                $result_blup_data_original_1, $result_blup_data_delta_original_1, $result_blup_spatial_data_original_1, $result_blup_pe_data_original_1, $result_blup_pe_data_delta_original_1, $result_residual_data_original_1, $result_fitted_data_original_1, $fixed_effects_original_hash_1,
                $rr_genetic_coefficients_original_hash_1, $rr_temporal_coefficients_original_hash_1,
                $rr_coeff_genetic_covariance_original_array_1, $rr_coeff_env_covariance_original_array_1, $rr_coeff_genetic_correlation_original_array_1, $rr_coeff_env_correlation_original_array_1, $rr_residual_variance_original_1, $varcomp_original_array_1,
                $model_sum_square_residual_original_1, $genetic_effect_min_original_1, $genetic_effect_max_original_1, $env_effect_min_original_1, $env_effect_max_original_1, $genetic_effect_sum_square_original_1, $genetic_effect_sum_original_1, $env_effect_sum_square_original_1, $env_effect_sum_original_1, $residual_sum_square_original_1, $residual_sum_original_1, $result_cv_original_1, $result_cv_2_original_1,

                $phenotype_data_altered_hash_1, $data_matrix_altered_array_1, $data_matrix_phenotypes_altered_array_1, $phenotype_min_altered_1, $phenotype_max_altered_1,
                $result_blup_data_altered_1, $result_blup_data_delta_altered_1, $result_blup_spatial_data_altered_1, $result_blup_pe_data_altered_1, $result_blup_pe_data_delta_altered_1, $result_residual_data_altered_1, $result_fitted_data_altered_1, $fixed_effects_altered_hash_1,
                $rr_genetic_coefficients_altered_hash_1, $rr_temporal_coefficients_altered_hash_1,
                $rr_coeff_genetic_covariance_altered_array_1, $rr_coeff_env_covariance_altered_array_1, $rr_coeff_genetic_correlation_altered_array_1, $rr_coeff_env_correlation_altered_array_1, $rr_residual_variance_altered_1, $varcomp_altered_array_1,
                $model_sum_square_residual_altered_1, $genetic_effect_min_altered_1, $genetic_effect_max_altered_1, $env_effect_min_altered_1, $env_effect_max_altered_1, $genetic_effect_sum_square_altered_1, $genetic_effect_sum_altered_1, $env_effect_sum_square_altered_1, $env_effect_sum_altered_1, $residual_sum_square_altered_1, $residual_sum_altered_1, $result_cv_altered_1, $result_cv_2_altered_1,

                $phenotype_data_altered_env_hash_1_1, $data_matrix_altered_env_array_1_1, $data_matrix_phenotypes_altered_env_array_1_1, $phenotype_min_altered_env_1_1, $phenotype_max_altered_env_1_1, $env_sim_min_1_1, $env_sim_max_1_1, $sim_data_hash_1_1,
                $result_blup_data_altered_env_1_1, $result_blup_data_delta_altered_env_1_1, $result_blup_spatial_data_altered_env_1_1, $result_blup_pe_data_altered_env_1_1, $result_blup_pe_data_delta_altered_env_1_1, $result_residual_data_altered_env_1_1, $result_fitted_data_altered_env_1_1, $fixed_effects_altered_env_hash_1_1,
                $rr_genetic_coefficients_altered_env_hash_1_1, $rr_temporal_coefficients_altered_env_hash_1_1,
                $rr_coeff_genetic_covariance_altered_env_array_1_1, $rr_coeff_env_covariance_altered_env_array_1_1, $rr_coeff_genetic_correlation_altered_env_array_1_1, $rr_coeff_env_correlation_altered_env_array_1_1, $rr_residual_variance_altered_env_1_1, $varcomp_altered_array_env_1_1,
                $model_sum_square_residual_altered_env_1_1, $genetic_effect_min_altered_env_1_1, $genetic_effect_max_altered_env_1_1, $env_effect_min_altered_env_1_1, $env_effect_max_altered_env_1_1, $genetic_effect_sum_square_altered_env_1_1, $genetic_effect_sum_altered_env_1_1, $env_effect_sum_square_altered_env_1_1, $env_effect_sum_altered_env_1_1, $residual_sum_square_altered_env_1_1, $residual_sum_altered_env_1_1, $result_cv_altered_env_1_1, $result_cv_2_altered_env_1_1,

                $phenotype_data_altered_env_hash_2_1, $data_matrix_altered_env_array_2_1, $data_matrix_phenotypes_altered_env_array_2_1, $phenotype_min_altered_env_2_1, $phenotype_max_altered_env_2_1, $env_sim_min_2_1, $env_sim_max_2_1, $sim_data_hash_2_1,
                $result_blup_data_altered_env_2_1, $result_blup_data_delta_altered_env_2_1, $result_blup_spatial_data_altered_env_2_1, $result_blup_pe_data_altered_env_2_1, $result_blup_pe_data_delta_altered_env_2_1, $result_residual_data_altered_env_2_1, $result_fitted_data_altered_env_2_1, $fixed_effects_altered_env_hash_2_1, $rr_genetic_coefficients_altered_env_hash_2_1, $rr_temporal_coefficients_altered_env_hash_2_1,
                $rr_coeff_genetic_covariance_altered_env_array_2_1, $rr_coeff_env_covariance_altered_env_array_2_1, $rr_coeff_genetic_correlation_altered_env_array_2_1, $rr_coeff_env_correlation_altered_env_array_2_1, $rr_residual_variance_altered_env_2_1, $varcomp_altered_array_env_2_1,
                $model_sum_square_residual_altered_env_2_1, $genetic_effect_min_altered_env_2_1, $genetic_effect_max_altered_env_2_1, $env_effect_min_altered_env_2_1, $env_effect_max_altered_env_2_1, $genetic_effect_sum_square_altered_env_2_1, $genetic_effect_sum_altered_env_2_1, $env_effect_sum_square_altered_env_2_1, $env_effect_sum_altered_env_2_1, $residual_sum_square_altered_env_2_1, $residual_sum_altered_env_2_1, $result_cv_altered_env_2_1, $result_cv_2_altered_env_2_1,

                $phenotype_data_altered_env_hash_3_1, $data_matrix_altered_env_array_3_1, $data_matrix_phenotypes_altered_env_array_3_1, $phenotype_min_altered_env_3_1, $phenotype_max_altered_env_3_1, $env_sim_min_3_1, $env_sim_max_3_1, $sim_data_hash_3_1,
                $result_blup_data_altered_env_3_1, $result_blup_data_delta_altered_env_3_1, $result_blup_spatial_data_altered_env_3_1, $result_blup_pe_data_altered_env_3_1, $result_blup_pe_data_delta_altered_env_3_1, $result_residual_data_altered_env_3_1, $result_fitted_data_altered_env_3_1, $fixed_effects_altered_env_hash_3_1, $rr_genetic_coefficients_altered_env_hash_3_1, $rr_temporal_coefficients_altered_env_hash_3_1,
                $rr_coeff_genetic_covariance_altered_env_array_3_1, $rr_coeff_env_covariance_altered_env_array_3_1, $rr_coeff_genetic_correlation_altered_env_array_3_1, $rr_coeff_env_correlation_altered_env_array_3_1, $rr_residual_variance_altered_env_3_1, $varcomp_altered_array_env_3_1,
                $model_sum_square_residual_altered_env_3_1, $genetic_effect_min_altered_env_3_1, $genetic_effect_max_altered_env_3_1, $env_effect_min_altered_env_3_1, $env_effect_max_altered_env_3_1, $genetic_effect_sum_square_altered_env_3_1, $genetic_effect_sum_altered_env_3_1, $env_effect_sum_square_altered_env_3_1, $env_effect_sum_altered_env_3_1, $residual_sum_square_altered_env_3_1, $residual_sum_altered_env_3_1, $result_cv_altered_env_3_1, $result_cv_2_altered_env_3_1,

                $phenotype_data_altered_env_hash_4_1, $data_matrix_altered_env_array_4_1, $data_matrix_phenotypes_altered_env_array_4_1, $phenotype_min_altered_env_4_1, $phenotype_max_altered_env_4_1, $env_sim_min_4_1, $env_sim_max_4_1, $sim_data_hash_4_1,
                $result_blup_data_altered_env_4_1, $result_blup_data_delta_altered_env_4_1, $result_blup_spatial_data_altered_env_4_1, $result_blup_pe_data_altered_env_4_1, $result_blup_pe_data_delta_altered_env_4_1, $result_residual_data_altered_env_4_1, $result_fitted_data_altered_env_4_1, $fixed_effects_altered_env_hash_4_1, $rr_genetic_coefficients_altered_env_hash_4_1, $rr_temporal_coefficients_altered_env_hash_4_1,
                $rr_coeff_genetic_covariance_altered_env_array_4_1, $rr_coeff_env_covariance_altered_env_array_4_1, $rr_coeff_genetic_correlation_altered_env_array_4_1, $rr_coeff_env_correlation_altered_env_array_4_1, $rr_residual_variance_altered_env_4_1, $varcomp_altered_array_env_4_1,
                $model_sum_square_residual_altered_env_4_1, $genetic_effect_min_altered_env_4_1, $genetic_effect_max_altered_env_4_1, $env_effect_min_altered_env_4_1, $env_effect_max_altered_env_4_1, $genetic_effect_sum_square_altered_env_4_1, $genetic_effect_sum_altered_env_4_1, $env_effect_sum_square_altered_env_4_1, $env_effect_sum_altered_env_4_1, $residual_sum_square_altered_env_4_1, $residual_sum_altered_env_4_1, $result_cv_altered_env_4_1, $result_cv_2_altered_env_4_1,

                $phenotype_data_altered_env_hash_5_1, $data_matrix_altered_env_array_5_1, $data_matrix_phenotypes_altered_env_array_5_1, $phenotype_min_altered_env_5_1, $phenotype_max_altered_env_5_1, $env_sim_min_5_1, $env_sim_max_5_1, $sim_data_hash_5_1,
                $result_blup_data_altered_env_5_1, $result_blup_data_delta_altered_env_5_1, $result_blup_spatial_data_altered_env_5_1, $result_blup_pe_data_altered_env_5_1, $result_blup_pe_data_delta_altered_env_5_1, $result_residual_data_altered_env_5_1, $result_fitted_data_altered_env_5_1, $fixed_effects_altered_env_hash_5_1, $rr_genetic_coefficients_altered_env_hash_5_1, $rr_temporal_coefficients_altered_env_hash_5_1,
                $rr_coeff_genetic_covariance_altered_env_array_5_1, $rr_coeff_env_covariance_altered_env_array_5_1, $rr_coeff_genetic_correlation_altered_env_array_5_1, $rr_coeff_env_correlation_altered_env_array_5_1, $rr_residual_variance_altered_env_5_1, $varcomp_altered_array_env_5_1,
                $model_sum_square_residual_altered_env_5_1, $genetic_effect_min_altered_env_5_1, $genetic_effect_max_altered_env_5_1, $env_effect_min_altered_env_5_1, $env_effect_max_altered_env_5_1, $genetic_effect_sum_square_altered_env_5_1, $genetic_effect_sum_altered_env_5_1, $env_effect_sum_square_altered_env_5_1, $env_effect_sum_altered_env_5_1, $residual_sum_square_altered_env_5_1, $residual_sum_altered_env_5_1, $result_cv_altered_env_5_1, $result_cv_2_altered_env_5_1,

                $phenotype_data_altered_env_hash_6_1, $data_matrix_altered_env_array_6_1, $data_matrix_phenotypes_altered_env_array_6_1, $phenotype_min_altered_env_6_1, $phenotype_max_altered_env_6_1, $env_sim_min_6_1, $env_sim_max_6_1, $sim_data_hash_6_1,
                $result_blup_data_altered_env_6_1, $result_blup_data_delta_altered_env_6_1, $result_blup_spatial_data_altered_env_6_1, $result_blup_pe_data_altered_env_6_1, $result_blup_pe_data_delta_altered_env_6_1, $result_residual_data_altered_env_6_1, $result_fitted_data_altered_env_6_1, $fixed_effects_altered_env_hash_6_1, $rr_genetic_coefficients_altered_env_hash_6_1, $rr_temporal_coefficients_altered_env_hash_6_1,
                $rr_coeff_genetic_covariance_altered_env_array_6_1, $rr_coeff_env_covariance_altered_env_array_6_1, $rr_coeff_genetic_correlation_altered_env_array_6_1, $rr_coeff_env_correlation_altered_env_array_6_1, $rr_residual_variance_altered_env_6_1, $varcomp_altered_array_env_6_1,
                $model_sum_square_residual_altered_env_6_1, $genetic_effect_min_altered_env_6_1, $genetic_effect_max_altered_env_6_1, $env_effect_min_altered_env_6_1, $env_effect_max_altered_env_6_1, $genetic_effect_sum_square_altered_env_6_1, $genetic_effect_sum_altered_env_6_1, $env_effect_sum_square_altered_env_6_1, $env_effect_sum_altered_env_6_1, $residual_sum_square_altered_env_6_1, $residual_sum_altered_env_6_1, $result_cv_altered_env_6_1, $result_cv_2_altered_env_6_1
                ) = @$result_1;

                eval {
                    print STDERR "PLOTTING CORRELATION\n";
                    my ($full_plot_level_correlation_tempfile_fh, $full_plot_level_correlation_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open(my $F_fullplot, ">", $full_plot_level_correlation_tempfile) || die "Can't open file ".$full_plot_level_correlation_tempfile;
                        print STDERR "OPENED PLOTCORR FILE $full_plot_level_correlation_tempfile\n";

                        my @header_full_plot_corr = ('plot_name, plot_id, row_number, col_number, rep, block, germplasm_name, germplasm_id');
                        my @types_full_plot_corr = ('pheno_orig_', 'pheno_postm1_', 'eff_origm1_', 'eff_postm1_',
                        'sim_env1_', 'simm1_pheno1_', 'effm1_sim1_',
                        'sim_env2_', 'simm1_pheno2_', 'effm1_sim2_',
                        'sim_env3_', 'simm1_pheno3_', 'effm1_sim3_',
                        'sim_env4_', 'simm1_pheno4_', 'effm1_sim4_',
                        'sim_env5_', 'simm1_pheno5_', 'effm1_sim5_',
                        'sim_env6_', 'simm1_pheno6_', 'effm1_sim6_');
                        foreach my $t (@sorted_trait_names) {
                            foreach my $type (@types_full_plot_corr) {
                                push @header_full_plot_corr, $type.$trait_name_encoder{$t};
                            }
                        }
                        my $header_string_full_plot_corr = join ',', @header_full_plot_corr;
                        print $F_fullplot "$header_string_full_plot_corr\n";
                        foreach my $p (@unique_plot_names) {
                            my @row = ($p, $stock_name_row_col{$p}->{obsunit_stock_id}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $stock_name_row_col{$p}->{rep}, $stock_name_row_col{$p}->{block}, $stock_name_row_col{$p}->{germplasm_name}, $stock_name_row_col{$p}->{germplasm_stock_id});
                            foreach my $t (@sorted_trait_names) {
                                my $phenotype_original = $phenotype_data_original{$p}->{$t};
                                my $phenotype_post_1 = $phenotype_data_altered_hash_1->{$p}->{$t};
                                my $effect_original_1 = $result_blup_pe_data_delta_original_1->{$p}->{$t}->[0];
                                my $effect_post_1 = $result_blup_pe_data_delta_altered_1->{$p}->{$t}->[0];
                                push @row, ($phenotype_original, $phenotype_post_1, $effect_original_1, $effect_post_1);

                                my $sim_env = $sim_data_hash_1_1->{$p}->{$t};
                                my $pheno_sim_1 = $phenotype_data_altered_env_hash_1_1->{$p}->{$t};
                                my $effect_sim_1 = $result_blup_pe_data_delta_altered_env_1_1->{$p}->{$t}->[0];
                                push @row, ($sim_env, $pheno_sim_1, $effect_sim_1);

                                my $sim_env2 = $sim_data_hash_2_1->{$p}->{$t};
                                my $pheno_sim2_1 = $phenotype_data_altered_env_hash_2_1->{$p}->{$t};
                                my $effect_sim2_1 = $result_blup_pe_data_delta_altered_env_2_1->{$p}->{$t}->[0];
                                push @row, ($sim_env2, $pheno_sim2_1, $effect_sim2_1);

                                my $sim_env3 = $sim_data_hash_3_1->{$p}->{$t};
                                my $pheno_sim3_1 = $phenotype_data_altered_env_hash_3_1->{$p}->{$t};
                                my $effect_sim3_1 = $result_blup_pe_data_delta_altered_env_3_1->{$p}->{$t}->[0];
                                push @row, ($sim_env3, $pheno_sim3_1, $effect_sim3_1);

                                my $sim_env4 = $sim_data_hash_4_1->{$p}->{$t};
                                my $pheno_sim4_1 = $phenotype_data_altered_env_hash_4_1->{$p}->{$t};
                                my $effect_sim4_1 = $result_blup_pe_data_delta_altered_env_4_1->{$p}->{$t}->[0];
                                push @row, ($sim_env4, $pheno_sim4_1, $effect_sim4_1);

                                my $sim_env5 = $sim_data_hash_5_1->{$p}->{$t};
                                my $pheno_sim5_1 = $phenotype_data_altered_env_hash_5_1->{$p}->{$t};
                                my $effect_sim5_1 = $result_blup_pe_data_delta_altered_env_5_1->{$p}->{$t}->[0];
                                push @row, ($sim_env5, $pheno_sim5_1, $effect_sim5_1);

                                my $sim_env6 = $sim_data_hash_6_1->{$p}->{$t};
                                my $pheno_sim6_1 = $phenotype_data_altered_env_hash_6_1->{$p}->{$t};
                                my $effect_sim6_1 = $result_blup_pe_data_delta_altered_env_6_1->{$p}->{$t}->[0];
                                push @row, ($sim_env6, $pheno_sim6_1, $effect_sim6_1);
                            }
                            my $line = join ',', @row;
                            print $F_fullplot "$line\n";
                        }
                    close($F_fullplot);

                    my $plot_corr_figure_tempfile_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $plot_corr_figure_tempfile_string .= '.png';
                    my $plot_corr_figure_tempfile = $c->config->{basepath}."/".$plot_corr_figure_tempfile_string;

                    my $cmd_plotcorr_plot = 'R -e "library(data.table); library(ggplot2); library(GGally);
                    mat_orig <- fread(\''.$full_plot_level_correlation_tempfile.'\', header=TRUE, sep=\',\');
                    gg <- ggcorr(data=mat_orig[,-seq(1,8)], hjust = 1, size = 2, color = \'grey50\', layout.exp = 1, label = TRUE);
                    ggsave(\''.$plot_corr_figure_tempfile.'\', gg, device=\'png\', width=30, height=30, limitsize = FALSE, units=\'in\');
                    "';
                    # print STDERR Dumper $cmd;
                    my $status_plotcorr_plot = system($cmd_plotcorr_plot);
                    push @$spatial_effects_plots, [$plot_corr_figure_tempfile_string, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_fullcorr_"."envvar_".$env_variance_percent."_".$permanent_environment_structure."_".$iterations];
                    push @$spatial_effects_files_store, [$full_plot_level_correlation_tempfile, "datafile_".$statistics_select.$sim_env_change_over_time.$correlation_between_times."_fullcorr_"."envvar_".$env_variance_percent."_".$permanent_environment_structure."_".$iterations];
                };

                eval {
                    my @plot_corr_full_vals;

                    my @original_pheno_vals;
                    my ($phenotypes_original_heatmap_tempfile_fh, $phenotypes_original_heatmap_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open(my $F_pheno, ">", $phenotypes_original_heatmap_tempfile) || die "Can't open file ".$phenotypes_original_heatmap_tempfile;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names) {
                                my $val = $phenotype_data_original{$p}->{$t};
                                my @row = ("pheno_orig_".$trait_name_encoder{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                push @original_pheno_vals, $val;
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                            }
                        }
                    close($F_pheno);
                    push @plot_corr_full_vals, \@original_pheno_vals;

                    my $original_pheno_stat = Statistics::Descriptive::Full->new();
                    $original_pheno_stat->add_data(@original_pheno_vals);
                    my $sig_original_pheno = $original_pheno_stat->variance();

                    #PHENO POST M START

                    my @altered_pheno_vals;
                    my ($phenotypes_post_heatmap_tempfile_fh, $phenotypes_post_heatmap_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $phenotypes_post_heatmap_tempfile) || die "Can't open file ".$phenotypes_post_heatmap_tempfile;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names) {
                                my $val = $phenotype_data_altered_hash_1->{$p}->{$t};
                                my @row = ("pheno_postm1_".$trait_name_encoder{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                push @altered_pheno_vals, $val;
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                            }
                        }
                    close($F_pheno);
                    push @plot_corr_full_vals, \@altered_pheno_vals;

                    my $altered_pheno_stat = Statistics::Descriptive::Full->new();
                    $altered_pheno_stat->add_data(@altered_pheno_vals);
                    my $sig_altered_pheno = $altered_pheno_stat->variance();

                    # EFFECT ORIGINAL M

                    my @original_effect_vals;
                    my ($effects_heatmap_tempfile_fh, $effects_heatmap_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open(my $F_eff, ">", $effects_heatmap_tempfile) || die "Can't open file ".$effects_heatmap_tempfile;
                        print $F_eff "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names) {
                                my $val = $result_blup_pe_data_delta_original_1->{$p}->{$t}->[0];
                                my @row = ("eff_origm1_".$trait_name_encoder{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_eff "$line\n";
                                push @original_effect_vals, $val;
                            }
                        }
                    close($F_eff);
                    push @plot_corr_full_vals, \@original_effect_vals;

                    my $original_effect_stat = Statistics::Descriptive::Full->new();
                    $original_effect_stat->add_data(@original_effect_vals);
                    my $sig_original_effect = $original_effect_stat->variance();

                    # EFFECT POST M MIN

                    my @altered_effect_vals;
                    my ($effects_post_heatmap_tempfile_fh, $effects_post_heatmap_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_eff, ">", $effects_post_heatmap_tempfile) || die "Can't open file ".$effects_post_heatmap_tempfile;
                        print $F_eff "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names) {
                                my $val = $result_blup_pe_data_delta_altered_1->{$p}->{$t}->[0];
                                my @row = ("eff_postm1_".$trait_name_encoder{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_eff "$line\n";
                                push @altered_effect_vals, $val;
                            }
                        }
                    close($F_eff);
                    push @plot_corr_full_vals, \@altered_effect_vals;

                    my $altered_effect_stat = Statistics::Descriptive::Full->new();
                    $altered_effect_stat->add_data(@altered_effect_vals);
                    my $sig_altered_effect = $altered_effect_stat->variance();

                    # SIM ENV 1: ALTERED PHENO + EFFECT

                    my ($phenotypes_env_heatmap_tempfile_fh, $phenotypes_env_heatmap_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $phenotypes_env_heatmap_tempfile) || die "Can't open file ".$phenotypes_env_heatmap_tempfile;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names) {
                                my @row = ("sim_env1_".$trait_name_encoder{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $sim_data_hash_1_1->{$p}->{$t});
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                            }
                        }
                    close($F_pheno);

                    my @sim_pheno1_vals;
                    my ($phenotypes_pheno_sim_heatmap_tempfile_fh, $phenotypes_pheno_sim_heatmap_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $phenotypes_pheno_sim_heatmap_tempfile) || die "Can't open file ".$phenotypes_pheno_sim_heatmap_tempfile;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names) {
                                my $val = $phenotype_data_altered_env_hash_1_1->{$p}->{$t};
                                my @row = ("simm1_pheno1_".$trait_name_encoder{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                                push @sim_pheno1_vals, $val;
                            }
                        }
                    close($F_pheno);
                    push @plot_corr_full_vals, \@sim_pheno1_vals;

                    my $sim_pheno1_stat = Statistics::Descriptive::Full->new();
                    $sim_pheno1_stat->add_data(@sim_pheno1_vals);
                    my $sig_sim_pheno1 = $sim_pheno1_stat->variance();

                    my @sim_effect1_vals;
                    my ($effects_sim_heatmap_tempfile_fh, $effects_sim_heatmap_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_eff, ">", $effects_sim_heatmap_tempfile) || die "Can't open file ".$effects_sim_heatmap_tempfile;
                        print $F_eff "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names) {
                                my $val = $result_blup_pe_data_delta_altered_env_1_1->{$p}->{$t}->[0];
                                my @row = ("effm1_sim1_".$trait_name_encoder{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_eff "$line\n";
                                push @sim_effect1_vals, $val;
                            }
                        }
                    close($F_eff);
                    push @plot_corr_full_vals, \@sim_effect1_vals;

                    my $sim_effect1_stat = Statistics::Descriptive::Full->new();
                    $sim_effect1_stat->add_data(@sim_effect1_vals);
                    my $sig_sim_effect1 = $sim_effect1_stat->variance();

                    # SIM ENV 2: ALTERED PHENO + EFFECT

                    my ($phenotypes_env_heatmap_tempfile2_fh, $phenotypes_env_heatmap_tempfile2) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $phenotypes_env_heatmap_tempfile2) || die "Can't open file ".$phenotypes_env_heatmap_tempfile2;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names) {
                                my @row = ("sim_env2_".$trait_name_encoder{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $sim_data_hash_2_1->{$p}->{$t});
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                            }
                        }
                    close($F_pheno);

                    my @sim_pheno2_vals;
                    my ($phenotypes_pheno_sim_heatmap_tempfile2_fh, $phenotypes_pheno_sim_heatmap_tempfile2) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $phenotypes_pheno_sim_heatmap_tempfile2) || die "Can't open file ".$phenotypes_pheno_sim_heatmap_tempfile2;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names) {
                                my $val = $phenotype_data_altered_env_hash_2_1->{$p}->{$t};
                                my @row = ("simm1_pheno2_".$trait_name_encoder{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                                push @sim_pheno2_vals, $val;
                            }
                        }
                    close($F_pheno);
                    push @plot_corr_full_vals, \@sim_pheno2_vals;

                    my $sim_pheno2_stat = Statistics::Descriptive::Full->new();
                    $sim_pheno2_stat->add_data(@sim_pheno2_vals);
                    my $sig_sim_pheno2 = $sim_pheno2_stat->variance();

                    my @sim_effect2_vals;
                    my ($effects_sim_heatmap_tempfile2_fh, $effects_sim_heatmap_tempfile2) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_eff, ">", $effects_sim_heatmap_tempfile2) || die "Can't open file ".$effects_sim_heatmap_tempfile2;
                        print $F_eff "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names) {
                                my $val = $result_blup_pe_data_delta_altered_env_2_1->{$p}->{$t}->[0];
                                my @row = ("effm1_sim2_".$trait_name_encoder{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_eff "$line\n";
                                push @sim_effect2_vals, $val;
                            }
                        }
                    close($F_eff);
                    push @plot_corr_full_vals, \@sim_effect2_vals;

                    # SIM ENV 3: ALTERED PHENO + EFFECT

                    my ($phenotypes_env_heatmap_tempfile3_fh, $phenotypes_env_heatmap_tempfile3) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $phenotypes_env_heatmap_tempfile3) || die "Can't open file ".$phenotypes_env_heatmap_tempfile3;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names) {
                                my @row = ("sim_env3_".$trait_name_encoder{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $sim_data_hash_3_1->{$p}->{$t});
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                            }
                        }
                    close($F_pheno);

                    my @sim_pheno3_vals;
                    my ($phenotypes_pheno_sim_heatmap_tempfile3_fh, $phenotypes_pheno_sim_heatmap_tempfile3) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $phenotypes_pheno_sim_heatmap_tempfile3) || die "Can't open file ".$phenotypes_pheno_sim_heatmap_tempfile3;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names) {
                                my $val = $phenotype_data_altered_env_hash_3_1->{$p}->{$t};
                                my @row = ("simm1_pheno3_".$trait_name_encoder{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                                push @sim_pheno3_vals, $val;
                            }
                        }
                    close($F_pheno);
                    push @plot_corr_full_vals, \@sim_pheno3_vals;

                    my $sim_pheno3_stat = Statistics::Descriptive::Full->new();
                    $sim_pheno3_stat->add_data(@sim_pheno3_vals);
                    my $sig_sim_pheno3 = $sim_pheno3_stat->variance();

                    my @sim_effect3_vals;
                    my ($effects_sim_heatmap_tempfile3_fh, $effects_sim_heatmap_tempfile3) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_eff, ">", $effects_sim_heatmap_tempfile3) || die "Can't open file ".$effects_sim_heatmap_tempfile3;
                        print $F_eff "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names) {
                                my $val = $result_blup_pe_data_delta_altered_env_3_1->{$p}->{$t}->[0];
                                my @row = ("effm1_sim3_".$trait_name_encoder{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_eff "$line\n";
                                push @sim_effect3_vals, $val;
                            }
                        }
                    close($F_eff);
                    push @plot_corr_full_vals, \@sim_effect3_vals;

                    my $sim_effect3_stat = Statistics::Descriptive::Full->new();
                    $sim_effect3_stat->add_data(@sim_effect3_vals);
                    my $sig_sim_effect3 = $sim_effect3_stat->variance();

                    # SIM ENV 4: ALTERED PHENO + EFFECT

                    my ($phenotypes_env_heatmap_tempfile4_fh, $phenotypes_env_heatmap_tempfile4) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $phenotypes_env_heatmap_tempfile4) || die "Can't open file ".$phenotypes_env_heatmap_tempfile4;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names) {
                                my @row = ("sim_env4_".$trait_name_encoder{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $sim_data_hash_4_1->{$p}->{$t});
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                            }
                        }
                    close($F_pheno);

                    my @sim_pheno4_vals;
                    my ($phenotypes_pheno_sim_heatmap_tempfile4_fh, $phenotypes_pheno_sim_heatmap_tempfile4) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $phenotypes_pheno_sim_heatmap_tempfile4) || die "Can't open file ".$phenotypes_pheno_sim_heatmap_tempfile4;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names) {
                                my $val = $phenotype_data_altered_env_hash_4_1->{$p}->{$t};
                                my @row = ("simm1_pheno4_".$trait_name_encoder{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                                push @sim_pheno4_vals, $val;
                            }
                        }
                    close($F_pheno);
                    push @plot_corr_full_vals, \@sim_pheno4_vals;

                    my $sim_pheno4_stat = Statistics::Descriptive::Full->new();
                    $sim_pheno4_stat->add_data(@sim_pheno4_vals);
                    my $sig_sim_pheno4 = $sim_pheno4_stat->variance();

                    my @sim_effect4_vals;
                    my ($effects_sim_heatmap_tempfile4_fh, $effects_sim_heatmap_tempfile4) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_eff, ">", $effects_sim_heatmap_tempfile4) || die "Can't open file ".$effects_sim_heatmap_tempfile4;
                        print $F_eff "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names) {
                                my $val = $result_blup_pe_data_delta_altered_env_4_1->{$p}->{$t}->[0];
                                my @row = ("effm1_sim4_".$trait_name_encoder{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_eff "$line\n";
                                push @sim_effect4_vals, $val;
                            }
                        }
                    close($F_eff);
                    push @plot_corr_full_vals, \@sim_effect4_vals;

                    my $sim_effect4_stat = Statistics::Descriptive::Full->new();
                    $sim_effect4_stat->add_data(@sim_effect4_vals);
                    my $sig_sim_effect4 = $sim_effect4_stat->variance();

                    # SIM ENV 5: ALTERED PHENO + EFFECT

                    my ($phenotypes_env_heatmap_tempfile5_fh, $phenotypes_env_heatmap_tempfile5) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $phenotypes_env_heatmap_tempfile5) || die "Can't open file ".$phenotypes_env_heatmap_tempfile5;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names) {
                                my @row = ("sim_env5_".$trait_name_encoder{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $sim_data_hash_5_1->{$p}->{$t});
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                            }
                        }
                    close($F_pheno);

                    my @sim_pheno5_vals;
                    my ($phenotypes_pheno_sim_heatmap_tempfile5_fh, $phenotypes_pheno_sim_heatmap_tempfile5) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $phenotypes_pheno_sim_heatmap_tempfile5) || die "Can't open file ".$phenotypes_pheno_sim_heatmap_tempfile5;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names) {
                                my $val = $phenotype_data_altered_env_hash_5_1->{$p}->{$t};
                                my @row = ("simm1_pheno5_".$trait_name_encoder{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                                push @sim_pheno5_vals, $val;
                            }
                        }
                    close($F_pheno);
                    push @plot_corr_full_vals, \@sim_pheno5_vals;

                    my $sim_pheno5_stat = Statistics::Descriptive::Full->new();
                    $sim_pheno5_stat->add_data(@sim_pheno5_vals);
                    my $sig_sim_pheno5 = $sim_pheno5_stat->variance();

                    my @sim_effect5_vals;
                    my ($effects_sim_heatmap_tempfile5_fh, $effects_sim_heatmap_tempfile5) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_eff, ">", $effects_sim_heatmap_tempfile5) || die "Can't open file ".$effects_sim_heatmap_tempfile5;
                        print $F_eff "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names) {
                                my $val = $result_blup_pe_data_delta_altered_env_5_1->{$p}->{$t}->[0];
                                my @row = ("effm1_sim5_".$trait_name_encoder{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_eff "$line\n";
                                push @sim_effect5_vals, $val;
                            }
                        }
                    close($F_eff);
                    push @plot_corr_full_vals, \@sim_effect5_vals;

                    my $sim_effect5_stat = Statistics::Descriptive::Full->new();
                    $sim_effect5_stat->add_data(@sim_effect5_vals);
                    my $sig_sim_effect5 = $sim_effect5_stat->variance();

                    # SIM ENV 6: ALTERED PHENO + EFFECT

                    my ($phenotypes_env_heatmap_tempfile6_fh, $phenotypes_env_heatmap_tempfile6) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $phenotypes_env_heatmap_tempfile6) || die "Can't open file ".$phenotypes_env_heatmap_tempfile6;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names) {
                                my @row = ("sim_env6_".$trait_name_encoder{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $sim_data_hash_6_1->{$p}->{$t});
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                            }
                        }
                    close($F_pheno);

                    my @sim_pheno6_vals;
                    my ($phenotypes_pheno_sim_heatmap_tempfile6_fh, $phenotypes_pheno_sim_heatmap_tempfile6) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $phenotypes_pheno_sim_heatmap_tempfile6) || die "Can't open file ".$phenotypes_pheno_sim_heatmap_tempfile6;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names) {
                                my $val = $phenotype_data_altered_env_hash_6_1->{$p}->{$t};
                                my @row = ("simm1_pheno6_".$trait_name_encoder{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                                push @sim_pheno6_vals, $val;
                            }
                        }
                    close($F_pheno);
                    push @plot_corr_full_vals, \@sim_pheno6_vals;

                    my $sim_pheno6_stat = Statistics::Descriptive::Full->new();
                    $sim_pheno6_stat->add_data(@sim_pheno6_vals);
                    my $sig_sim_pheno6 = $sim_pheno6_stat->variance();

                    my @sim_effect6_vals;
                    my ($effects_sim_heatmap_tempfile6_fh, $effects_sim_heatmap_tempfile6) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_eff, ">", $effects_sim_heatmap_tempfile6) || die "Can't open file ".$effects_sim_heatmap_tempfile6;
                        print $F_eff "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names) {
                                my $val = $result_blup_pe_data_delta_altered_env_6_1->{$p}->{$t}->[0];
                                my @row = ("effm1_sim6_".$trait_name_encoder{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_eff "$line\n";
                                push @sim_effect6_vals, $val;
                            }
                        }
                    close($F_eff);
                    push @plot_corr_full_vals, \@sim_effect6_vals;

                    my $sim_effect6_stat = Statistics::Descriptive::Full->new();
                    $sim_effect6_stat->add_data(@sim_effect6_vals);
                    my $sig_sim_effect6 = $sim_effect6_stat->variance();

                    my $plot_corr_summary_figure_inputfile_tempfile = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'tmp_drone_statistics/fileXXXX');
                    open($F_eff, ">", $plot_corr_summary_figure_inputfile_tempfile) || die "Can't open file ".$plot_corr_summary_figure_inputfile_tempfile;
                        foreach (@plot_corr_full_vals) {
                            my $line = join ',', @$_;
                            print $F_eff $line."\n";
                        }
                    close($F_eff);

                    my $plot_corr_summary_figure_tempfile_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $plot_corr_summary_figure_tempfile_string .= '.png';
                    my $plot_corr_summary_figure_tempfile = $c->config->{basepath}."/".$plot_corr_summary_figure_tempfile_string;

                    my $cmd_plotcorrsum_plot = 'R -e "library(data.table); library(ggplot2); library(GGally);
                    mat_full_t <- fread(\''.$plot_corr_summary_figure_inputfile_tempfile.'\', header=FALSE, sep=\',\');
                    mat_full <- data.frame(t(mat_full_t));
                    colnames(mat_full) <- c(\'mat_orig\', \'mat_altered_1\', \'mat_eff_1\', \'mat_eff_altered_1\',
                    \'mat_p_sim1_1\', \'mat_eff_sim1_1\',
                    \'mat_p_sim2_1\', \'mat_eff_sim2_1\',
                    \'mat_p_sim3_1\', \'mat_eff_sim3_1\',
                    \'mat_p_sim4_1\', \'mat_eff_sim4_1\',
                    \'mat_p_sim5_1\', \'mat_eff_sim5_1\',
                    \'mat_p_sim6_1\', \'mat_eff_sim6_1\');
                    mat_env <- fread(\''.$phenotypes_env_heatmap_tempfile.'\', header=TRUE, sep=\',\');
                    mat_env2 <- fread(\''.$phenotypes_env_heatmap_tempfile2.'\', header=TRUE, sep=\',\');
                    mat_env3 <- fread(\''.$phenotypes_env_heatmap_tempfile3.'\', header=TRUE, sep=\',\');
                    mat_env4 <- fread(\''.$phenotypes_env_heatmap_tempfile4.'\', header=TRUE, sep=\',\');
                    mat_env5 <- fread(\''.$phenotypes_env_heatmap_tempfile5.'\', header=TRUE, sep=\',\');
                    mat_env6 <- fread(\''.$phenotypes_env_heatmap_tempfile6.'\', header=TRUE, sep=\',\');
                    mat <- data.frame(pheno_orig = mat_full\$mat_orig, pheno_altm1 = mat_full\$mat_altered_1, eff_origm1 = mat_full\$mat_eff_1, eff_altm1 = mat_full\$mat_eff_altered_1, env_lin = mat_env\$value, pheno_linm1 = mat_full\$mat_p_sim1_1, lin_effm1 = mat_full\$mat_eff_sim1_1, env_n1d = mat_env2\$value, pheno_n1dm1 = mat_full\$mat_p_sim2_1, n1d_effm1 = mat_full\$mat_eff_sim2_1, env_n2d = mat_env3\$value, pheno_n2dm1 = mat_full\$mat_p_sim3_1, n2d_effm1 = mat_full\$mat_eff_sim3_1, env_rand = mat_env4\$value, pheno_randm1 = mat_full\$mat_p_sim4_1, rand_effm1 = mat_full\$mat_eff_sim4_1, env_ar1 = mat_env5\$value, pheno_ar1m1 = mat_full\$mat_p_sim5_1, ar1_effm1 = mat_full\$mat_eff_sim5_1, env_realdata = mat_env6\$value, pheno_realdatam1 = mat_full\$mat_p_sim6_1, realdata_effm1 = mat_full\$mat_eff_sim6_1);
                    gg <- ggcorr(data=mat, hjust = 1, size = 2, color = \'grey50\', layout.exp = 1, label = TRUE, label_round = 2);
                    ggsave(\''.$plot_corr_summary_figure_tempfile.'\', gg, device=\'png\', width=30, height=30, units=\'in\');
                    "';
                    # print STDERR Dumper $cmd_plotcorrsum_plot;

                    my $status_plotcorrsum_plot = system($cmd_plotcorrsum_plot);
                    push @$spatial_effects_plots, [$plot_corr_summary_figure_tempfile_string, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_envsimscorr_"."envvar_".$env_variance_percent."_".$permanent_environment_structure."_".$iterations];

                    my $env_effects_first_figure_tempfile_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $env_effects_first_figure_tempfile_string .= '.png';
                    my $env_effects_first_figure_tempfile = $c->config->{basepath}."/".$env_effects_first_figure_tempfile_string;

                    my $env_effects_first_figure_tempfile_string_2 = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $env_effects_first_figure_tempfile_string_2 .= '.png';
                    my $env_effects_first_figure_tempfile_2 = $c->config->{basepath}."/".$env_effects_first_figure_tempfile_string_2;

                    my $output_plot_row = 'row';
                    my $output_plot_col = 'col';
                    if ($max_col > $max_row) {
                        $output_plot_row = 'col';
                        $output_plot_col = 'row';
                    }

                    my $cmd_spatialfirst_plot_2 = 'R -e "library(data.table); library(ggplot2); library(dplyr); library(viridis); library(GGally); library(gridExtra);
                    mat_orig <- fread(\''.$phenotypes_original_heatmap_tempfile.'\', header=TRUE, sep=\',\');
                    mat_altered_1 <- fread(\''.$phenotypes_post_heatmap_tempfile.'\', header=TRUE, sep=\',\');
                    pheno_mat <- rbind(mat_orig, mat_altered_1);
                    options(device=\'png\');
                    par();
                    gg <- ggplot(pheno_mat, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names).');
                    ggsave(\''.$env_effects_first_figure_tempfile_2.'\', gg, device=\'png\', width=20, height=20, units=\'in\');
                    "';
                    # print STDERR Dumper $cmd;
                    my $status_spatialfirst_plot_2 = system($cmd_spatialfirst_plot_2);
                    push @$spatial_effects_plots, [$env_effects_first_figure_tempfile_string_2, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_origheatmap_"."envvar_".$env_variance_percent."_".$permanent_environment_structure."_".$iterations];

                    my ($sim_effects_corr_results_fh, $sim_effects_corr_results) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);

                    my $cmd_spatialfirst_plot = 'R -e "library(data.table); library(ggplot2); library(dplyr); library(viridis); library(GGally); library(gridExtra);
                    mat_full_t <- fread(\''.$plot_corr_summary_figure_inputfile_tempfile.'\', header=FALSE, sep=\',\');
                    mat_full <- data.frame(t(mat_full_t));
                    colnames(mat_full) <- c(\'mat_orig\', \'mat_altered_1\', \'mat_eff_1\', \'mat_eff_altered_1\',
                    \'mat_p_sim1_1\', \'mat_eff_sim1_1\',
                    \'mat_p_sim2_1\', \'mat_eff_sim2_1\',
                    \'mat_p_sim3_1\', \'mat_eff_sim3_1\',
                    \'mat_p_sim4_1\', \'mat_eff_sim4_1\',
                    \'mat_p_sim5_1\', \'mat_eff_sim5_1\',
                    \'mat_p_sim6_1\', \'mat_eff_sim6_1\');
                    mat_eff_1 <- fread(\''.$effects_heatmap_tempfile.'\', header=TRUE, sep=\',\');
                    mat_eff_altered_1 <- fread(\''.$effects_post_heatmap_tempfile.'\', header=TRUE, sep=\',\');
                    effect_mat_1 <- rbind(mat_eff_1, mat_eff_altered_1);
                    mat_env <- fread(\''.$phenotypes_env_heatmap_tempfile.'\', header=TRUE, sep=\',\');
                    mat_env2 <- fread(\''.$phenotypes_env_heatmap_tempfile2.'\', header=TRUE, sep=\',\');
                    mat_env3 <- fread(\''.$phenotypes_env_heatmap_tempfile3.'\', header=TRUE, sep=\',\');
                    mat_env4 <- fread(\''.$phenotypes_env_heatmap_tempfile4.'\', header=TRUE, sep=\',\');
                    mat_env5 <- fread(\''.$phenotypes_env_heatmap_tempfile5.'\', header=TRUE, sep=\',\');
                    mat_env6 <- fread(\''.$phenotypes_env_heatmap_tempfile6.'\', header=TRUE, sep=\',\');
                    options(device=\'png\');
                    par();
                    gg_eff_1 <- ggplot(effect_mat_1, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names).');
                    ggsave(\''.$env_effects_first_figure_tempfile.'\', arrangeGrob(gg_eff_1, nrow=1), device=\'png\', width=20, height=20, units=\'in\');
                    write.table(data.frame(airemlf90_grm_random_regression_dap_blups_env_linear = c(cor(mat_env\$value, mat_full\$mat_eff_sim1_1)), airemlf90_grm_random_regression_dap_blups_env_1DN = c(cor(mat_env2\$value, mat_full\$mat_eff_sim2_1)), airemlf90_grm_random_regression_dap_blups_env_2DN = c(cor(mat_env3\$value, mat_full\$mat_eff_sim3_1)), airemlf90_grm_random_regression_dap_blups_env_random = c(cor(mat_env4\$value, mat_full\$mat_eff_sim4_1)), airemlf90_grm_random_regression_dap_blups_env_ar1xar1 = c(cor(mat_env5\$value, mat_full\$mat_eff_sim5_1)), airemlf90_grm_random_regression_dap_blups_env_realdata = c(cor(mat_env6\$value, mat_full\$mat_eff_sim6_1)) ), file=\''.$sim_effects_corr_results.'\', row.names=FALSE, col.names=TRUE, sep=\'\t\');
                    "';
                    # print STDERR Dumper $cmd;
                    my $status_spatialfirst_plot = system($cmd_spatialfirst_plot);
                    push @$spatial_effects_plots, [$env_effects_first_figure_tempfile_string, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_originaleffheatmap_"."envvar_".$env_variance_percent."_".$permanent_environment_structure."_".$iterations];

                    open(my $fh_corr_result, '<', $sim_effects_corr_results) or die "Could not open file '$sim_effects_corr_results' $!";
                        print STDERR "Opened $sim_effects_corr_results\n";

                        my $header = <$fh_corr_result>;
                        my @header;
                        if ($csv->parse($header)) {
                            @header = $csv->fields();
                        }

                        while (my $row = <$fh_corr_result>) {
                            my @columns;
                            my $counter = 0;
                            if ($csv->parse($row)) {
                                @columns = $csv->fields();
                            }
                            foreach (@columns) {
                                push @{$env_corr_res->{$header[$counter]."_corrtime_".$sim_env_change_over_time.$correlation_between_times."_envvar_".$env_variance_percent."_".$permanent_environment_structure}->{values}}, $_;
                                $counter++;
                            }
                        }
                    close($fh_corr_result);

                    my $env_effects_sim_figure_tempfile_string_env1 = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $env_effects_sim_figure_tempfile_string_env1 .= '.png';
                    my $env_effects_sim_figure_tempfile_env1 = $c->config->{basepath}."/".$env_effects_sim_figure_tempfile_string_env1;

                    my $cmd_spatialenvsim_plot_env1 = 'R -e "library(data.table); library(ggplot2); library(dplyr); library(viridis); library(GGally); library(gridExtra);
                    mat_env <- fread(\''.$phenotypes_env_heatmap_tempfile.'\', header=TRUE, sep=\',\');
                    mat_p_sim <- fread(\''.$phenotypes_pheno_sim_heatmap_tempfile.'\', header=TRUE, sep=\',\');
                    mat_eff_sim <- fread(\''.$effects_sim_heatmap_tempfile.'\', header=TRUE, sep=\',\');
                    options(device=\'png\');
                    par();
                    gg_env <- ggplot(mat_env, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names).');
                    gg_p_sim <- ggplot(mat_p_sim, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names).');
                    gg_eff_sim <- ggplot(mat_eff_sim, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names).');
                    ggsave(\''.$env_effects_sim_figure_tempfile_env1.'\', arrangeGrob(gg_env, gg_p_sim, gg_eff_sim, nrow=1), device=\'png\', width=25, height=25, units=\'in\');
                    "';
                    # print STDERR Dumper $cmd_spatialenvsim_plot_env1;
                    my $status_spatialenvsim_plot_env1 = system($cmd_spatialenvsim_plot_env1);
                    push @$spatial_effects_plots, [$env_effects_sim_figure_tempfile_string_env1, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_env1effheatmap_"."envvar_".$env_variance_percent."_".$permanent_environment_structure."_".$iterations];

                    my $env_effects_sim_figure_tempfile_string_env2 = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $env_effects_sim_figure_tempfile_string_env2 .= '.png';
                    my $env_effects_sim_figure_tempfile_env2 = $c->config->{basepath}."/".$env_effects_sim_figure_tempfile_string_env2;

                    my $cmd_spatialenvsim_plot_env2 = 'R -e "library(data.table); library(ggplot2); library(dplyr); library(viridis); library(GGally); library(gridExtra);
                    mat_env2 <- fread(\''.$phenotypes_env_heatmap_tempfile2.'\', header=TRUE, sep=\',\');
                    mat_p_sim2 <- fread(\''.$phenotypes_pheno_sim_heatmap_tempfile2.'\', header=TRUE, sep=\',\');
                    mat_eff_sim2 <- fread(\''.$effects_sim_heatmap_tempfile2.'\', header=TRUE, sep=\',\');
                    options(device=\'png\');
                    par();
                    gg_env2 <- ggplot(mat_env2, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names).');
                    gg_p_sim2 <- ggplot(mat_p_sim2, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names).');
                    gg_eff_sim2 <- ggplot(mat_eff_sim2, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names).');
                    ggsave(\''.$env_effects_sim_figure_tempfile_env2.'\', arrangeGrob(gg_env2, gg_p_sim2, gg_eff_sim2, nrow=1), device=\'png\', width=25, height=25, units=\'in\');
                    "';
                    # print STDERR Dumper $cmd_spatialenvsim_plot_env2;
                    my $status_spatialenvsim_plot_env2 = system($cmd_spatialenvsim_plot_env2);
                    push @$spatial_effects_plots, [$env_effects_sim_figure_tempfile_string_env2, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_env2effheatmap_"."envvar_".$env_variance_percent."_".$permanent_environment_structure."_".$iterations];

                    my $env_effects_sim_figure_tempfile_string_env3 = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $env_effects_sim_figure_tempfile_string_env3 .= '.png';
                    my $env_effects_sim_figure_tempfile_env3 = $c->config->{basepath}."/".$env_effects_sim_figure_tempfile_string_env3;

                    my $cmd_spatialenvsim_plot_env3 = 'R -e "library(data.table); library(ggplot2); library(dplyr); library(viridis); library(GGally); library(gridExtra);
                    mat_env3 <- fread(\''.$phenotypes_env_heatmap_tempfile3.'\', header=TRUE, sep=\',\');
                    mat_p_sim3 <- fread(\''.$phenotypes_pheno_sim_heatmap_tempfile3.'\', header=TRUE, sep=\',\');
                    mat_eff_sim3 <- fread(\''.$effects_sim_heatmap_tempfile3.'\', header=TRUE, sep=\',\');
                    options(device=\'png\');
                    par();
                    gg_env3 <- ggplot(mat_env3, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names).');
                    gg_p_sim3 <- ggplot(mat_p_sim3, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names).');
                    gg_eff_sim3 <- ggplot(mat_eff_sim3, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names).');
                    ggsave(\''.$env_effects_sim_figure_tempfile_env3.'\', arrangeGrob(gg_env3, gg_p_sim3, gg_eff_sim3, nrow=1), device=\'png\', width=25, height=25, units=\'in\');
                    "';
                    # print STDERR Dumper $cmd_spatialenvsim_plot_env3;
                    my $status_spatialenvsim_plot_env3 = system($cmd_spatialenvsim_plot_env3);
                    push @$spatial_effects_plots, [$env_effects_sim_figure_tempfile_string_env3, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_env3effheatmap_"."envvar_".$env_variance_percent."_".$permanent_environment_structure."_".$iterations];

                    my $env_effects_sim_figure_tempfile_string_env4 = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $env_effects_sim_figure_tempfile_string_env4 .= '.png';
                    my $env_effects_sim_figure_tempfile_env4 = $c->config->{basepath}."/".$env_effects_sim_figure_tempfile_string_env4;

                    my $cmd_spatialenvsim_plot_env4 = 'R -e "library(data.table); library(ggplot2); library(dplyr); library(viridis); library(GGally); library(gridExtra);
                    mat_env4 <- fread(\''.$phenotypes_env_heatmap_tempfile4.'\', header=TRUE, sep=\',\');
                    mat_p_sim4 <- fread(\''.$phenotypes_pheno_sim_heatmap_tempfile4.'\', header=TRUE, sep=\',\');
                    mat_eff_sim4 <- fread(\''.$effects_sim_heatmap_tempfile4.'\', header=TRUE, sep=\',\');
                    options(device=\'png\');
                    par();
                    gg_env4 <- ggplot(mat_env4, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names).');
                    gg_p_sim4 <- ggplot(mat_p_sim4, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names).');
                    gg_eff_sim4 <- ggplot(mat_eff_sim4, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names).');
                    ggsave(\''.$env_effects_sim_figure_tempfile_env4.'\', arrangeGrob(gg_env4, gg_p_sim4, gg_eff_sim4, nrow=1), device=\'png\', width=25, height=25, units=\'in\');
                    "';
                    # print STDERR Dumper $cmd_spatialenvsim_plot_env4;
                    my $status_spatialenvsim_plot_env4 = system($cmd_spatialenvsim_plot_env4);
                    push @$spatial_effects_plots, [$env_effects_sim_figure_tempfile_string_env4, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_env4effheatmap_"."envvar_".$env_variance_percent."_".$permanent_environment_structure."_".$iterations];

                    my $env_effects_sim_figure_tempfile_string_env5 = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $env_effects_sim_figure_tempfile_string_env5 .= '.png';
                    my $env_effects_sim_figure_tempfile_env5 = $c->config->{basepath}."/".$env_effects_sim_figure_tempfile_string_env5;

                    my $cmd_spatialenvsim_plot_env5 = 'R -e "library(data.table); library(ggplot2); library(dplyr); library(viridis); library(GGally); library(gridExtra);
                    mat_env5 <- fread(\''.$phenotypes_env_heatmap_tempfile5.'\', header=TRUE, sep=\',\');
                    mat_p_sim5 <- fread(\''.$phenotypes_pheno_sim_heatmap_tempfile5.'\', header=TRUE, sep=\',\');
                    mat_eff_sim5 <- fread(\''.$effects_sim_heatmap_tempfile5.'\', header=TRUE, sep=\',\');
                    options(device=\'png\');
                    par();
                    gg_env5 <- ggplot(mat_env5, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names).');
                    gg_p_sim5 <- ggplot(mat_p_sim5, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names).');
                    gg_eff_sim5 <- ggplot(mat_eff_sim5, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names).');
                    ggsave(\''.$env_effects_sim_figure_tempfile_env5.'\', arrangeGrob(gg_env5, gg_p_sim5, gg_eff_sim5, nrow=1), device=\'png\', width=25, height=25, units=\'in\');
                    "';
                    # print STDERR Dumper $cmd_spatialenvsim_plot_env5;
                    my $status_spatialenvsim_plot_env5 = system($cmd_spatialenvsim_plot_env5);
                    push @$spatial_effects_plots, [$env_effects_sim_figure_tempfile_string_env5, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_env5effheatmap_"."envvar_".$env_variance_percent."_".$permanent_environment_structure."_".$iterations];

                    my $env_effects_sim_figure_tempfile_string_env6 = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $env_effects_sim_figure_tempfile_string_env6 .= '.png';
                    my $env_effects_sim_figure_tempfile_env6 = $c->config->{basepath}."/".$env_effects_sim_figure_tempfile_string_env6;

                    my $cmd_spatialenvsim_plot_env6 = 'R -e "library(data.table); library(ggplot2); library(dplyr); library(viridis); library(GGally); library(gridExtra);
                    mat_env6 <- fread(\''.$phenotypes_env_heatmap_tempfile6.'\', header=TRUE, sep=\',\');
                    mat_p_sim6 <- fread(\''.$phenotypes_pheno_sim_heatmap_tempfile6.'\', header=TRUE, sep=\',\');
                    mat_eff_sim6 <- fread(\''.$effects_sim_heatmap_tempfile6.'\', header=TRUE, sep=\',\');
                    options(device=\'png\');
                    par();
                    gg_env6 <- ggplot(mat_env6, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names).');
                    gg_p_sim6 <- ggplot(mat_p_sim6, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names).');
                    gg_eff_sim6 <- ggplot(mat_eff_sim6, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names).');
                    ggsave(\''.$env_effects_sim_figure_tempfile_env6.'\', arrangeGrob(gg_env6, gg_p_sim6, gg_eff_sim6, nrow=1), device=\'png\', width=25, height=25, units=\'in\');
                    "';
                    # print STDERR Dumper $cmd_spatialenvsim_plot_env6;
                    my $status_spatialenvsim_plot_env6 = system($cmd_spatialenvsim_plot_env6);
                    push @$spatial_effects_plots, [$env_effects_sim_figure_tempfile_string_env6, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_env6effheatmap_"."envvar_".$env_variance_percent."_".$permanent_environment_structure."_".$iterations];
                };

                eval {
                    my @sorted_germplasm_names = sort keys %unique_accessions;
                    @sorted_trait_names = sort keys %$rr_unique_traits_hash_1;

                    my @original_blup_vals;
                    my ($effects_original_line_chart_tempfile_fh, $effects_original_line_chart_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open(my $F_pheno, ">", $effects_original_line_chart_tempfile) || die "Can't open file ".$effects_original_line_chart_tempfile;
                        print $F_pheno "germplasmName,time,value\n";
                        foreach my $p (@sorted_germplasm_names) {
                            foreach my $t (@sorted_trait_names) {
                                my $val = $result_blup_data_original_1->{$p}->{$t}->[0];
                                my @row = ($p, $trait_to_time_map_hash_1->{$t}, $val);
                                push @original_blup_vals, $val;
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                            }
                        }
                    close($F_pheno);

                    my $original_blup_stat = Statistics::Descriptive::Full->new();
                    $original_blup_stat->add_data(@original_blup_vals);
                    my $sig_original_blup = $original_blup_stat->variance();

                    my @altered_blups_vals;
                    my ($effects_altered_line_chart_tempfile_fh, $effects_altered_line_chart_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $effects_altered_line_chart_tempfile) || die "Can't open file ".$effects_altered_line_chart_tempfile;
                        print $F_pheno "germplasmName,time,value\n";
                        foreach my $p (@sorted_germplasm_names) {
                            foreach my $t (@sorted_trait_names) {
                                my $val = $result_blup_data_altered_1->{$p}->{$t}->[0];
                                my @row = ($p, $trait_to_time_map_hash_1->{$t}, $val);
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                                push @altered_blups_vals, $val;
                            }
                        }
                    close($F_pheno);

                    my $altered_blup_stat = Statistics::Descriptive::Full->new();
                    $altered_blup_stat->add_data(@altered_blups_vals);
                    my $sig_altered_blup = $altered_blup_stat->variance();

                    my @sim1_blup_vals;
                    my ($effects_altered_env1_line_chart_tempfile_fh, $effects_altered_env1_line_chart_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $effects_altered_env1_line_chart_tempfile) || die "Can't open file ".$effects_altered_env1_line_chart_tempfile;
                        print $F_pheno "germplasmName,time,value\n";
                        foreach my $p (@sorted_germplasm_names) {
                            foreach my $t (@sorted_trait_names) {
                                my $val = $result_blup_data_altered_env_1_1->{$p}->{$t}->[0];
                                my @row = ($p, $trait_to_time_map_hash_1->{$t}, $val);
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                                push @sim1_blup_vals, $val;
                            }
                        }
                    close($F_pheno);

                    my $sim1_blup_stat = Statistics::Descriptive::Full->new();
                    $sim1_blup_stat->add_data(@sim1_blup_vals);
                    my $sig_sim1_blup = $sim1_blup_stat->variance();

                    my @sim2_blup_vals;
                    my ($effects_altered_env2_line_chart_tempfile_fh, $effects_altered_env2_line_chart_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $effects_altered_env2_line_chart_tempfile) || die "Can't open file ".$effects_altered_env2_line_chart_tempfile;
                        print $F_pheno "germplasmName,time,value\n";
                        foreach my $p (@sorted_germplasm_names) {
                            foreach my $t (@sorted_trait_names) {
                                my $val = $result_blup_data_altered_env_2_1->{$p}->{$t}->[0];
                                my @row = ($p, $trait_to_time_map_hash_1->{$t}, $val);
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                                push @sim2_blup_vals, $val;
                            }
                        }
                    close($F_pheno);

                    my $sim2_blup_stat = Statistics::Descriptive::Full->new();
                    $sim2_blup_stat->add_data(@sim2_blup_vals);
                    my $sig_sim2_blup = $sim2_blup_stat->variance();

                    my @sim3_blup_vals;
                    my ($effects_altered_env3_line_chart_tempfile_fh, $effects_altered_env3_line_chart_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $effects_altered_env3_line_chart_tempfile) || die "Can't open file ".$effects_altered_env3_line_chart_tempfile;
                        print $F_pheno "germplasmName,time,value\n";
                        foreach my $p (@sorted_germplasm_names) {
                            foreach my $t (@sorted_trait_names) {
                                my $val = $result_blup_data_altered_env_3_1->{$p}->{$t}->[0];
                                my @row = ($p, $trait_to_time_map_hash_1->{$t}, $val);
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                                push @sim3_blup_vals, $val;
                            }
                        }
                    close($F_pheno);

                    my $sim3_blup_stat = Statistics::Descriptive::Full->new();
                    $sim3_blup_stat->add_data(@sim3_blup_vals);
                    my $sig_sim3_blup = $sim3_blup_stat->variance();

                    my @sim4_blup_vals;
                    my ($effects_altered_env4_line_chart_tempfile_fh, $effects_altered_env4_line_chart_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $effects_altered_env4_line_chart_tempfile) || die "Can't open file ".$effects_altered_env4_line_chart_tempfile;
                        print $F_pheno "germplasmName,time,value\n";
                        foreach my $p (@sorted_germplasm_names) {
                            foreach my $t (@sorted_trait_names) {
                                my $val = $result_blup_data_altered_env_4_1->{$p}->{$t}->[0];
                                my @row = ($p, $trait_to_time_map_hash_1->{$t}, $val);
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                                push @sim4_blup_vals, $val;
                            }
                        }
                    close($F_pheno);

                    my $sim4_blup_stat = Statistics::Descriptive::Full->new();
                    $sim4_blup_stat->add_data(@sim4_blup_vals);
                    my $sig_sim4_blup = $sim4_blup_stat->variance();

                    my @sim5_blup_vals;
                    my ($effects_altered_env5_line_chart_tempfile_fh, $effects_altered_env5_line_chart_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $effects_altered_env5_line_chart_tempfile) || die "Can't open file ".$effects_altered_env5_line_chart_tempfile;
                        print $F_pheno "germplasmName,time,value\n";
                        foreach my $p (@sorted_germplasm_names) {
                            foreach my $t (@sorted_trait_names) {
                                my $val = $result_blup_data_altered_env_5_1->{$p}->{$t}->[0];
                                my @row = ($p, $trait_to_time_map_hash_1->{$t}, $val);
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                                push @sim5_blup_vals, $val;
                            }
                        }
                    close($F_pheno);

                    my $sim5_blup_stat = Statistics::Descriptive::Full->new();
                    $sim5_blup_stat->add_data(@sim5_blup_vals);
                    my $sig_sim5_blup = $sim5_blup_stat->variance();

                    my @sim6_blup_vals;
                    my ($effects_altered_env6_line_chart_tempfile_fh, $effects_altered_env6_line_chart_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $effects_altered_env6_line_chart_tempfile) || die "Can't open file ".$effects_altered_env6_line_chart_tempfile;
                        print $F_pheno "germplasmName,time,value\n";
                        foreach my $p (@sorted_germplasm_names) {
                            foreach my $t (@sorted_trait_names) {
                                my $val = $result_blup_data_altered_env_6_1->{$p}->{$t}->[0];
                                my @row = ($p, $trait_to_time_map_hash_1->{$t}, $val);
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                                push @sim6_blup_vals, $val;
                            }
                        }
                    close($F_pheno);

                    my $sim6_blup_stat = Statistics::Descriptive::Full->new();
                    $sim6_blup_stat->add_data(@sim6_blup_vals);
                    my $sig_sim6_blup = $sim6_blup_stat->variance();

                    my @set = ('0' ..'9', 'A' .. 'F');
                    my @colors;
                    for (1..scalar(@sorted_germplasm_names)) {
                        my $str = join '' => map $set[rand @set], 1 .. 6;
                        push @colors, '#'.$str;
                    }
                    my $color_string = join '\',\'', @colors;

                    my $genetic_effects_figure_tempfile_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $genetic_effects_figure_tempfile_string .= '.png';
                    my $genetic_effects_figure_tempfile = $c->config->{basepath}."/".$genetic_effects_figure_tempfile_string;

                    my $genetic_effects_alt_figure_tempfile_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $genetic_effects_alt_figure_tempfile_string .= '.png';
                    my $genetic_effects_alt_figure_tempfile = $c->config->{basepath}."/".$genetic_effects_alt_figure_tempfile_string;

                    my $genetic_effects_alt_env1_figure_tempfile_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $genetic_effects_alt_env1_figure_tempfile_string .= '.png';
                    my $genetic_effects_alt_env1_figure_tempfile = $c->config->{basepath}."/".$genetic_effects_alt_env1_figure_tempfile_string;

                    my $genetic_effects_alt_env2_figure_tempfile_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $genetic_effects_alt_env2_figure_tempfile_string .= '.png';
                    my $genetic_effects_alt_env2_figure_tempfile = $c->config->{basepath}."/".$genetic_effects_alt_env2_figure_tempfile_string;

                    my $genetic_effects_alt_env3_figure_tempfile_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $genetic_effects_alt_env3_figure_tempfile_string .= '.png';
                    my $genetic_effects_alt_env3_figure_tempfile = $c->config->{basepath}."/".$genetic_effects_alt_env3_figure_tempfile_string;

                    my $genetic_effects_alt_env4_figure_tempfile_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $genetic_effects_alt_env4_figure_tempfile_string .= '.png';
                    my $genetic_effects_alt_env4_figure_tempfile = $c->config->{basepath}."/".$genetic_effects_alt_env4_figure_tempfile_string;

                    my $genetic_effects_alt_env5_figure_tempfile_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $genetic_effects_alt_env5_figure_tempfile_string .= '.png';
                    my $genetic_effects_alt_env5_figure_tempfile = $c->config->{basepath}."/".$genetic_effects_alt_env5_figure_tempfile_string;

                    my $genetic_effects_alt_env6_figure_tempfile_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $genetic_effects_alt_env6_figure_tempfile_string .= '.png';
                    my $genetic_effects_alt_env6_figure_tempfile = $c->config->{basepath}."/".$genetic_effects_alt_env6_figure_tempfile_string;

                    my $cmd_gen_plot = 'R -e "library(data.table); library(ggplot2); library(GGally); library(gridExtra);
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
                    sp <- sp + theme(legend.title = element_text(size = 3), legend.text = element_text(size = 3));
                    sp <- sp + labs(title = \'Original Genetic Effects\');';
                    if (scalar(@sorted_germplasm_names) > 100) {
                        $cmd_gen_plot .= 'sp <- sp + theme(legend.position = \'none\');';
                    }
                    $cmd_gen_plot .= 'ggsave(\''.$genetic_effects_figure_tempfile.'\', sp, device=\'png\', width=12, height=6, units=\'in\');
                    "';
                    print STDERR Dumper $cmd_gen_plot;
                    my $status_gen_plot = system($cmd_gen_plot);
                    push @$spatial_effects_plots, [$genetic_effects_figure_tempfile_string, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_efforigline_"."envvar_".$env_variance_percent."_".$permanent_environment_structure."_".$iterations];

                    my $cmd_gen_alt_plot = 'R -e "library(data.table); library(ggplot2); library(GGally); library(gridExtra);
                    mat <- fread(\''.$effects_altered_line_chart_tempfile.'\', header=TRUE, sep=\',\');
                    mat\$time <- as.numeric(as.character(mat\$time));
                    options(device=\'png\');
                    par();
                    sp <- ggplot(mat, aes(x = time, y = value)) +
                        geom_line(aes(color = germplasmName), size = 1) +
                        scale_fill_manual(values = c(\''.$color_string.'\')) +
                        theme_minimal();
                    sp <- sp + guides(shape = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + guides(color = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + theme(legend.title = element_text(size = 3), legend.text = element_text(size = 3));
                    sp <- sp + labs(title = \'Altered Genetic Effects\');';
                    if (scalar(@sorted_germplasm_names) > 100) {
                        $cmd_gen_alt_plot .= 'sp <- sp + theme(legend.position = \'none\');';
                    }
                    $cmd_gen_alt_plot .= 'ggsave(\''.$genetic_effects_alt_figure_tempfile.'\', sp, device=\'png\', width=12, height=6, units=\'in\');
                    "';
                    print STDERR Dumper $cmd_gen_alt_plot;
                    my $status_gen_alt_plot = system($cmd_gen_alt_plot);
                    push @$spatial_effects_plots, [$genetic_effects_alt_figure_tempfile_string, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_effaltline_"."envvar_".$env_variance_percent."_".$permanent_environment_structure."_".$iterations];

                    my $cmd_gen_env1_plot = 'R -e "library(data.table); library(ggplot2); library(GGally); library(gridExtra);
                    mat <- fread(\''.$effects_altered_env1_line_chart_tempfile.'\', header=TRUE, sep=\',\');
                    mat\$time <- as.numeric(as.character(mat\$time));
                    options(device=\'png\');
                    par();
                    sp <- ggplot(mat, aes(x = time, y = value)) +
                        geom_line(aes(color = germplasmName), size = 1) +
                        scale_fill_manual(values = c(\''.$color_string.'\')) +
                        theme_minimal();
                    sp <- sp + guides(shape = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + guides(color = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + theme(legend.title = element_text(size = 3), legend.text = element_text(size = 3));
                    sp <- sp + labs(title = \'SimLinear Genetic Effects\');';
                    if (scalar(@sorted_germplasm_names) > 100) {
                        $cmd_gen_env1_plot .= 'sp <- sp + theme(legend.position = \'none\');';
                    }
                    $cmd_gen_env1_plot .= 'ggsave(\''.$genetic_effects_alt_env1_figure_tempfile.'\', sp, device=\'png\', width=12, height=6, units=\'in\');
                    "';
                    print STDERR Dumper $cmd_gen_env1_plot;
                    my $status_gen_env1_plot = system($cmd_gen_env1_plot);
                    push @$spatial_effects_plots, [$genetic_effects_alt_env1_figure_tempfile_string, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_effaltenv1line_"."envvar_".$env_variance_percent."_".$permanent_environment_structure."_".$iterations];

                    my $cmd_gen_env2_plot = 'R -e "library(data.table); library(ggplot2); library(GGally); library(gridExtra);
                    mat <- fread(\''.$effects_altered_env2_line_chart_tempfile.'\', header=TRUE, sep=\',\');
                    mat\$time <- as.numeric(as.character(mat\$time));
                    options(device=\'png\');
                    par();
                    sp <- ggplot(mat, aes(x = time, y = value)) +
                        geom_line(aes(color = germplasmName), size = 1) +
                        scale_fill_manual(values = c(\''.$color_string.'\')) +
                        theme_minimal();
                    sp <- sp + guides(shape = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + guides(color = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + theme(legend.title = element_text(size = 3), legend.text = element_text(size = 3));
                    sp <- sp + labs(title = \'Sim1DN Genetic Effects\');';
                    if (scalar(@sorted_germplasm_names) > 100) {
                        $cmd_gen_env2_plot .= 'sp <- sp + theme(legend.position = \'none\');';
                    }
                    $cmd_gen_env2_plot .= 'ggsave(\''.$genetic_effects_alt_env2_figure_tempfile.'\', sp, device=\'png\', width=12, height=6, units=\'in\');
                    "';
                    print STDERR Dumper $cmd_gen_env2_plot;
                    my $status_gen_env2_plot = system($cmd_gen_env2_plot);
                    push @$spatial_effects_plots, [$genetic_effects_alt_env2_figure_tempfile_string, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_effaltenv2line_"."envvar_".$env_variance_percent."_".$permanent_environment_structure."_".$iterations];

                    my $cmd_gen_env3_plot = 'R -e "library(data.table); library(ggplot2); library(GGally); library(gridExtra);
                    mat <- fread(\''.$effects_altered_env3_line_chart_tempfile.'\', header=TRUE, sep=\',\');
                    mat\$time <- as.numeric(as.character(mat\$time));
                    options(device=\'png\');
                    par();
                    sp <- ggplot(mat, aes(x = time, y = value)) +
                        geom_line(aes(color = germplasmName), size = 1) +
                        scale_fill_manual(values = c(\''.$color_string.'\')) +
                        theme_minimal();
                    sp <- sp + guides(shape = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + guides(color = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + theme(legend.title = element_text(size = 3), legend.text = element_text(size = 3));
                    sp <- sp + labs(title = \'Sim2DN Genetic Effects\');';
                    if (scalar(@sorted_germplasm_names) > 100) {
                        $cmd_gen_env3_plot .= 'sp <- sp + theme(legend.position = \'none\');';
                    }
                    $cmd_gen_env3_plot .= 'ggsave(\''.$genetic_effects_alt_env3_figure_tempfile.'\', sp, device=\'png\', width=12, height=6, units=\'in\');
                    "';
                    print STDERR Dumper $cmd_gen_env3_plot;
                    my $status_gen_env3_plot = system($cmd_gen_env3_plot);
                    push @$spatial_effects_plots, [$genetic_effects_alt_env3_figure_tempfile_string, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_effaltenv3line_"."envvar_".$env_variance_percent."_".$permanent_environment_structure."_".$iterations];

                    my $cmd_gen_env4_plot = 'R -e "library(data.table); library(ggplot2); library(GGally); library(gridExtra);
                    mat <- fread(\''.$effects_altered_env4_line_chart_tempfile.'\', header=TRUE, sep=\',\');
                    mat\$time <- as.numeric(as.character(mat\$time));
                    options(device=\'png\');
                    par();
                    sp <- ggplot(mat, aes(x = time, y = value)) +
                        geom_line(aes(color = germplasmName), size = 1) +
                        scale_fill_manual(values = c(\''.$color_string.'\')) +
                        theme_minimal();
                    sp <- sp + guides(shape = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + guides(color = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + theme(legend.title = element_text(size = 3), legend.text = element_text(size = 3));
                    sp <- sp + labs(title = \'SimRandom Genetic Effects\');';
                    if (scalar(@sorted_germplasm_names) > 100) {
                        $cmd_gen_env4_plot .= 'sp <- sp + theme(legend.position = \'none\');';
                    }
                    $cmd_gen_env4_plot .= 'ggsave(\''.$genetic_effects_alt_env4_figure_tempfile.'\', sp, device=\'png\', width=12, height=6, units=\'in\');
                    "';
                    print STDERR Dumper $cmd_gen_env4_plot;
                    my $status_gen_env4_plot = system($cmd_gen_env4_plot);
                    push @$spatial_effects_plots, [$genetic_effects_alt_env4_figure_tempfile_string, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_effaltenv4line_"."envvar_".$env_variance_percent."_".$permanent_environment_structure."_".$iterations];

                    my $cmd_gen_env5_plot = 'R -e "library(data.table); library(ggplot2); library(GGally); library(gridExtra);
                    mat <- fread(\''.$effects_altered_env5_line_chart_tempfile.'\', header=TRUE, sep=\',\');
                    mat\$time <- as.numeric(as.character(mat\$time));
                    options(device=\'png\');
                    par();
                    sp <- ggplot(mat, aes(x = time, y = value)) +
                        geom_line(aes(color = germplasmName), size = 1) +
                        scale_fill_manual(values = c(\''.$color_string.'\')) +
                        theme_minimal();
                    sp <- sp + guides(shape = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + guides(color = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + theme(legend.title = element_text(size = 3), legend.text = element_text(size = 3));
                    sp <- sp + labs(title = \'SimRandom Genetic Effects\');';
                    if (scalar(@sorted_germplasm_names) > 100) {
                        $cmd_gen_env5_plot .= 'sp <- sp + theme(legend.position = \'none\');';
                    }
                    $cmd_gen_env5_plot .= 'ggsave(\''.$genetic_effects_alt_env5_figure_tempfile.'\', sp, device=\'png\', width=12, height=6, units=\'in\');
                    "';
                    print STDERR Dumper $cmd_gen_env5_plot;
                    my $status_gen_env5_plot = system($cmd_gen_env5_plot);
                    push @$spatial_effects_plots, [$genetic_effects_alt_env5_figure_tempfile_string, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_effaltenv5line_"."envvar_".$env_variance_percent."_".$permanent_environment_structure."_".$iterations];

                    my $cmd_gen_env6_plot = 'R -e "library(data.table); library(ggplot2); library(GGally); library(gridExtra);
                    mat <- fread(\''.$effects_altered_env6_line_chart_tempfile.'\', header=TRUE, sep=\',\');
                    mat\$time <- as.numeric(as.character(mat\$time));
                    options(device=\'png\');
                    par();
                    sp <- ggplot(mat, aes(x = time, y = value)) +
                        geom_line(aes(color = germplasmName), size = 1) +
                        scale_fill_manual(values = c(\''.$color_string.'\')) +
                        theme_minimal();
                    sp <- sp + guides(shape = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + guides(color = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + theme(legend.title = element_text(size = 3), legend.text = element_text(size = 3));
                    sp <- sp + labs(title = \'SimRandom Genetic Effects\');';
                    if (scalar(@sorted_germplasm_names) > 100) {
                        $cmd_gen_env6_plot .= 'sp <- sp + theme(legend.position = \'none\');';
                    }
                    $cmd_gen_env6_plot .= 'ggsave(\''.$genetic_effects_alt_env6_figure_tempfile.'\', sp, device=\'png\', width=12, height=6, units=\'in\');
                    "';
                    print STDERR Dumper $cmd_gen_env6_plot;
                    my $status_gen_env6_plot = system($cmd_gen_env6_plot);
                    push @$spatial_effects_plots, [$genetic_effects_alt_env6_figure_tempfile_string, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_effaltenv6line_"."envvar_".$env_variance_percent."_".$permanent_environment_structure."_".$iterations];
                };

                push @$env_varcomps, {
                    type => "$statistics_select: Env Variance $env_variance_percent : PE Structure: $permanent_environment_structure : SimCorrelation: $correlation_between_times : Iteration $iterations",
                    statistics_select => "$statistics_select: Env Variance $env_variance_percent : PE Structure: $permanent_environment_structure : SimCorrelation: $correlation_between_times",
                    correlation_between_times => $correlation_between_times,
                    env_variance => $env_variance_percent,
                    original => {
                        genetic_covariance => $rr_coeff_genetic_covariance_original_array_1,
                        env_covariance => $rr_coeff_env_covariance_original_array_1,
                        residual => $rr_residual_variance_original_1,
                        genetic_correlation => $rr_coeff_genetic_correlation_original_array_1,
                        env_correlation => $rr_coeff_env_correlation_original_array_1,
                        cv_1 => $result_cv_original_1,
                        cv_2 => $result_cv_2_original_1
                    },
                    altered => {
                        genetic_covariance => $rr_coeff_genetic_covariance_altered_array_1,
                        env_covariance => $rr_coeff_env_covariance_altered_array_1,
                        residual => $rr_residual_variance_altered_1,
                        genetic_correlation => $rr_coeff_genetic_correlation_altered_array_1,
                        env_correlation => $rr_coeff_env_correlation_altered_array_1,
                        cv_1 => $result_cv_altered_1,
                        cv_2 => $result_cv_2_altered_1
                    },
                    env_linear => {
                        genetic_covariance => $rr_coeff_genetic_covariance_altered_env_array_1_1,
                        env_covariance => $rr_coeff_env_covariance_altered_env_array_1_1,
                        residual => $rr_residual_variance_altered_env_1_1,
                        genetic_correlation => $rr_coeff_genetic_correlation_altered_env_array_1_1,
                        env_correlation => $rr_coeff_env_correlation_altered_env_array_1_1,
                        cv_1 => $result_cv_altered_env_1_1,
                        cv_2 => $result_cv_2_altered_env_1_1
                    },
                    env_1DN  => {
                        genetic_covariance => $rr_coeff_genetic_covariance_altered_env_array_2_1,
                        env_covariance => $rr_coeff_env_covariance_altered_env_array_2_1,
                        residual => $rr_residual_variance_altered_env_2_1,
                        genetic_correlation => $rr_coeff_genetic_correlation_altered_env_array_2_1,
                        env_correlation => $rr_coeff_env_correlation_altered_env_array_2_1,
                        cv_1 => $result_cv_altered_env_2_1,
                        cv_2 => $result_cv_2_altered_env_2_1
                    },
                    env_2DN  => {
                        genetic_covariance => $rr_coeff_genetic_covariance_altered_env_array_3_1,
                        env_covariance => $rr_coeff_env_covariance_altered_env_array_3_1,
                        residual => $rr_residual_variance_altered_env_3_1,
                        genetic_correlation => $rr_coeff_genetic_correlation_altered_env_array_3_1,
                        env_correlation => $rr_coeff_env_correlation_altered_env_array_3_1,
                        cv_1 => $result_cv_altered_env_3_1,
                        cv_2 => $result_cv_2_altered_env_3_1
                    },
                    env_random  => {
                        genetic_covariance => $rr_coeff_genetic_covariance_altered_env_array_4_1,
                        env_covariance => $rr_coeff_env_covariance_altered_env_array_4_1,
                        residual => $rr_residual_variance_altered_env_4_1,
                        genetic_correlation => $rr_coeff_genetic_correlation_altered_env_array_4_1,
                        env_correlation => $rr_coeff_env_correlation_altered_env_array_4_1,
                        cv_1 => $result_cv_altered_env_4_1,
                        cv_2 => $result_cv_2_altered_env_4_1
                    },
                    env_ar1xar1  => {
                        genetic_covariance => $rr_coeff_genetic_covariance_altered_env_array_5_1,
                        env_covariance => $rr_coeff_env_covariance_altered_env_array_5_1,
                        residual => $rr_residual_variance_altered_env_5_1,
                        genetic_correlation => $rr_coeff_genetic_correlation_altered_env_array_5_1,
                        env_correlation => $rr_coeff_env_correlation_altered_env_array_5_1,
                        cv_1 => $result_cv_altered_env_5_1,
                        cv_2 => $result_cv_2_altered_env_5_1
                    },
                    env_realdata  => {
                        genetic_covariance => $rr_coeff_genetic_covariance_altered_env_array_6_1,
                        env_covariance => $rr_coeff_env_covariance_altered_env_array_6_1,
                        residual => $rr_residual_variance_altered_env_6_1,
                        genetic_correlation => $rr_coeff_genetic_correlation_altered_env_array_6_1,
                        env_correlation => $rr_coeff_env_correlation_altered_env_array_6_1,
                        cv_1 => $result_cv_altered_env_6_1,
                        cv_2 => $result_cv_2_altered_env_6_1
                    }
                };
            }

            my (%phenotype_data_original_2, @data_matrix_original_2, @data_matrix_phenotypes_original_2);
            my (%trait_name_encoder_2, %trait_name_encoder_rev_2, %seen_days_after_plantings_2, %stock_info_2, %seen_times_2, %seen_trial_ids_2, %trait_to_time_map_2, %trait_composing_info_2, @sorted_trait_names_2, %seen_trait_names_2, %unique_traits_ids_2, @phenotype_header_2, $header_string_2);
            my (@sorted_scaled_ln_times_2, %plot_id_factor_map_reverse_2, %plot_id_count_map_reverse_2, %accession_id_factor_map_2, %accession_id_factor_map_reverse_2, %time_count_map_reverse_2, @rep_time_factors_2, @ind_rep_factors_2, %plot_rep_time_factor_map_2, %seen_rep_times_2, %seen_ind_reps_2, @legs_header_2, %polynomial_map_2);
            my $time_min_2 = 100000000;
            my $time_max_2 = 0;
            my $phenotype_min_original_2 = 1000000000;
            my $phenotype_max_original_2 = -1000000000;

            if ($statistics_select_original eq 'sommer_grm_spatial_genetic_blups' || $statistics_select_original eq 'sommer_grm_spatial_pure_2dspl_genetic_blups') {
                $statistics_select = $statistics_select_original eq 'sommer_grm_spatial_genetic_blups' ? 'sommer_grm_spatial_genetic_blups' : 'sommer_grm_spatial_pure_2dspl_genetic_blups';

                print STDERR "PREPARE ORIGINAL PHENOTYPE FILES 2\n";
                eval {
                    my $phenotypes_search_2 = CXGN::Phenotypes::SearchFactory->instantiate(
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
                    my ($data_2, $unique_traits_2) = $phenotypes_search_2->search();
                    @sorted_trait_names_2 = sort keys %$unique_traits_2;

                    if (scalar(@$data_2) == 0) {
                        $c->stash->{rest} = { error => "There are no phenotypes for the trials and traits you have selected!"};
                        return;
                    }

                    foreach my $obs_unit (@$data_2){
                        my $germplasm_name = $obs_unit->{germplasm_uniquename};
                        my $germplasm_stock_id = $obs_unit->{germplasm_stock_id};
                        my $replicate_number = $obs_unit->{obsunit_rep} || '';
                        my $block_number = $obs_unit->{obsunit_block} || '';
                        my $obsunit_stock_id = $obs_unit->{observationunit_stock_id};
                        my $obsunit_stock_uniquename = $obs_unit->{observationunit_uniquename};
                        my $row_number = $obs_unit->{obsunit_row_number} || '';
                        my $col_number = $obs_unit->{obsunit_col_number} || '';
                        $seen_trial_ids_2{$obs_unit->{trial_id}}++;
                        push @plot_ids_ordered, $obsunit_stock_id;

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

                        $obsunit_row_col{$row_number}->{$col_number} = {
                            stock_id => $obsunit_stock_id,
                            stock_uniquename => $obsunit_stock_uniquename
                        };
                        $seen_rows{$row_number}++;
                        $seen_cols{$col_number}++;
                        $plot_id_map{$obsunit_stock_id} = $obsunit_stock_uniquename;
                        $seen_plot_names{$obsunit_stock_uniquename}++;
                        $seen_plots{$obsunit_stock_id} = $obsunit_stock_uniquename;
                        $stock_row_col{$obsunit_stock_id} = {
                            row_number => $row_number,
                            col_number => $col_number,
                            obsunit_stock_id => $obsunit_stock_id,
                            obsunit_name => $obsunit_stock_uniquename,
                            rep => $replicate_number,
                            block => $block_number,
                            germplasm_stock_id => $germplasm_stock_id,
                            germplasm_name => $germplasm_name
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
                        $stock_row_col_id{$row_number}->{$col_number} = $obsunit_stock_id;
                        $unique_accessions{$germplasm_name}++;
                        $stock_info_2{"S".$germplasm_stock_id} = {
                            uniquename => $germplasm_name
                        };
                        my $observations = $obs_unit->{observations};
                        foreach (@$observations){
                            my $value = $_->{value};
                            my $trait_name = $_->{trait_name};
                            $phenotype_data_original_2{$obsunit_stock_uniquename}->{$trait_name} = $value;
                            $seen_trait_names_2{$trait_name}++;

                            if ($value < $phenotype_min_original_2) {
                                $phenotype_min_original_2 = $value;
                            }
                            elsif ($value >= $phenotype_max_original_2) {
                                $phenotype_max_original_2 = $value;
                            }

                            if ($_->{associated_image_project_time_json}) {
                                my $related_time_terms_json = decode_json $_->{associated_image_project_time_json};
                                my $time_days_cvterm = $related_time_terms_json->{day};
                                my $time_term_string = $time_days_cvterm;
                                my $time_days = (split '\|', $time_days_cvterm)[0];
                                my $time_value = (split ' ', $time_days)[1];
                                $seen_days_after_plantings_2{$time_value}++;
                                $trait_to_time_map_2{$trait_name} = $time_value;
                            }
                        }
                    }

                    @unique_plot_names = sort keys %seen_plot_names;

                    my $trait_name_encoded_2 = 1;
                    foreach my $trait_name (@sorted_trait_names_2) {
                        if (!exists($trait_name_encoder_2{$trait_name})) {
                            my $trait_name_e = 't'.$trait_name_encoded_2;
                            $trait_name_encoder_2{$trait_name} = $trait_name_e;
                            $trait_name_encoder_rev_2{$trait_name_e} = $trait_name;
                            $trait_name_encoded_2++;
                        }
                    }

                    foreach my $p (@unique_plot_names) {
                        my $obsunit_stock_id = $stock_name_row_col{$p}->{obsunit_stock_id};
                        if ($fixed_effect_type eq 'fixed_effect_trait') {
                            $stock_name_row_col{$p}->{rep} = defined($fixed_effect_trait_data->{$obsunit_stock_id}) ? $fixed_effect_trait_data->{$obsunit_stock_id} : 0;
                        }
                        my $row_number = $stock_name_row_col{$p}->{row_number};
                        my $col_number = $stock_name_row_col{$p}->{col_number};
                        my $replicate = $stock_name_row_col{$p}->{rep};
                        my $block = $stock_name_row_col{$p}->{block};
                        my $germplasm_stock_id = $stock_name_row_col{$p}->{germplasm_stock_id};
                        my $germplasm_name = $stock_name_row_col{$p}->{germplasm_name};

                        my @row = ($replicate, $block, "S".$germplasm_stock_id, $obsunit_stock_id, $row_number, $col_number, $row_number, $col_number);

                        foreach my $t (@sorted_trait_names_2) {
                            if (defined($phenotype_data_original_2{$p}->{$t})) {
                                push @row, $phenotype_data_original_2{$p}->{$t};
                            } else {
                                print STDERR $p." : $t : $germplasm_name : NA \n";
                                push @row, 'NA';
                            }
                        }
                        push @data_matrix_original_2, \@row;
                    }

                    foreach (keys %seen_trial_ids_2){
                        my $trial = CXGN::Trial->new({bcs_schema=>$schema, trial_id=>$_});
                        my $traits_assayed = $trial->get_traits_assayed('plot', undef, 'time_ontology');
                        foreach (@$traits_assayed) {
                            $unique_traits_ids_2{$_->[0]} = $_;
                        }
                    }
                    foreach (values %unique_traits_ids_2) {
                        foreach my $component (@{$_->[2]}) {
                            if (exists($seen_trait_names_2{$_->[1]}) && $component->{cv_type} && $component->{cv_type} eq 'time_ontology') {
                                my $time_term_string = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $component->{cvterm_id}, 'extended');
                                push @{$trait_composing_info_2{$_->[1]}}, $time_term_string;
                            }
                        }
                    }

                    @phenotype_header_2 = ("replicate", "block", "id", "plot_id", "rowNumber", "colNumber", "rowNumberFactor", "colNumberFactor");
                    foreach (@sorted_trait_names_2) {
                        push @phenotype_header_2, $trait_name_encoder_2{$_};
                    }
                    $header_string_2 = join ',', @phenotype_header_2;

                    open($F, ">", $stats_tempfile) || die "Can't open file ".$stats_tempfile;
                        print $F $header_string_2."\n";
                        foreach (@data_matrix_original_2) {
                            my $line = join ',', @$_;
                            print $F "$line\n";
                        }
                    close($F);

                    print STDERR Dumper [$phenotype_min_original_2, $phenotype_max_original_2];
                };

                @seen_rows_array = keys %seen_rows;
                @seen_cols_array = keys %seen_cols;
                $row_stat = Statistics::Descriptive::Full->new();
                $row_stat->add_data(@seen_rows_array);
                $mean_row = $row_stat->mean();
                $sig_row = $row_stat->variance();
                $col_stat = Statistics::Descriptive::Full->new();
                $col_stat->add_data(@seen_cols_array);
                $mean_col = $col_stat->mean();
                $sig_col = $col_stat->variance();

                print STDERR "PREPARE RELATIONSHIP MATRIX\n";
                eval {
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
                            my $status = system($cmd);

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
                            my $status = system($cmd);

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
                            my $status = system($htp_cmd);
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
                            my $status = system($htp_cmd);
                        }
                        else {
                            $c->stash->{rest} = { error => "The value of $compute_relationship_matrix_from_htp_phenotypes_type htp_pheno_rel_matrix_type is not valid!" };
                            return;
                        }

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
                };

                my $result_2 = CXGN::DroneImagery::DroneImageryAnalyticsRunSimulation::perform_drone_imagery_analytics($schema, $a_env, $b_env, $ro_env, $row_ro_env, $env_variance_percent, $protocol_id, $statistics_select, $analytics_select, $tolparinv, $use_area_under_curve, $legendre_order_number, $permanent_environment_structure, \@legendre_coeff_exec, \%trait_name_encoder_2, \%trait_name_encoder_rev_2, \%stock_info_2, \%plot_id_map, \@sorted_trait_names_2, \%accession_id_factor_map, \@rep_time_factors, \@ind_rep_factors, \@unique_accession_names, \%plot_id_count_map_reverse, \@sorted_scaled_ln_times, \%time_count_map_reverse, \%accession_id_factor_map_reverse, \%seen_times, \%plot_id_factor_map_reverse, \%trait_to_time_map_2, \@unique_plot_names, \%stock_name_row_col, \%phenotype_data_original_2, \%plot_rep_time_factor_map, \%stock_row_col, \%stock_row_col_id, \%polynomial_map, \@plot_ids_ordered, $csv, $timestamp, $user_name, $stats_tempfile, $grm_file, $grm_rename_tempfile, $tmp_stats_dir, $stats_out_tempfile, $stats_out_tempfile_row, $stats_out_tempfile_col, $stats_out_tempfile_residual, $stats_out_tempfile_2dspl, $stats_prep2_tempfile, $stats_out_param_tempfile, $parameter_tempfile, $parameter_asreml_tempfile, $stats_tempfile_2, $permanent_environment_structure_tempfile, $permanent_environment_structure_env_tempfile, $permanent_environment_structure_env_tempfile2, $permanent_environment_structure_env_tempfile_mat, $sim_env_changing_mat_tempfile, $sim_env_changing_mat_full_tempfile, $yhat_residual_tempfile, $blupf90_solutions_tempfile, $coeff_genetic_tempfile, $coeff_pe_tempfile, $stats_out_tempfile_varcomp, $time_min, $time_max, $header_string_2, $env_sim_exec, $min_row, $max_row, $min_col, $max_col, $mean_row, $sig_row, $mean_col, $sig_col, $sim_env_change_over_time, $correlation_between_times, $field_trial_id_list, $simulated_environment_real_data_trait_id, $fixed_effect_type, $perform_cv);
                if (ref($result_2) eq 'HASH') {
                    $c->stash->{rest} = $result_2;
                    $c->detach();
                }
                my ($statistical_ontology_term_2, $analysis_model_training_data_file_type_2, $analysis_model_language_2, $sorted_residual_trait_names_array_2, $rr_unique_traits_hash_2, $rr_residual_unique_traits_hash_2, $statistics_cmd_2, $cmd_f90_2, $number_traits_2, $trait_to_time_map_hash_2,

                $result_blup_data_original_2, $result_blup_data_delta_original_2, $result_blup_spatial_data_original_2, $result_blup_pe_data_original_2, $result_blup_pe_data_delta_original_2, $result_residual_data_original_2, $result_fitted_data_original_2, $fixed_effects_original_hash_2,
                $rr_genetic_coefficients_original_hash_2, $rr_temporal_coefficients_original_hash_2,
                $rr_coeff_genetic_covariance_original_array_2, $rr_coeff_env_covariance_original_array_2, $rr_coeff_genetic_correlation_original_array_2, $rr_coeff_env_correlation_original_array_2, $rr_residual_variance_original_2, $varcomp_original_array_2,
                $model_sum_square_residual_original_2, $genetic_effect_min_original_2, $genetic_effect_max_original_2, $env_effect_min_original_2, $env_effect_max_original_2, $genetic_effect_sum_square_original_2, $genetic_effect_sum_original_2, $env_effect_sum_square_original_2, $env_effect_sum_original_2, $residual_sum_square_original_2, $residual_sum_original_2, $result_cv_original_2, $result_cv_2_original_2,

                $phenotype_data_altered_hash_2, $data_matrix_altered_array_2, $data_matrix_phenotypes_altered_array_2, $phenotype_min_altered_2, $phenotype_max_altered_2,
                $result_blup_data_altered_2, $result_blup_data_delta_altered_2, $result_blup_spatial_data_altered_2, $result_blup_pe_data_altered_2, $result_blup_pe_data_delta_altered_2, $result_residual_data_altered_2, $result_fitted_data_altered_2, $fixed_effects_altered_hash_2,
                $rr_genetic_coefficients_altered_hash_2, $rr_temporal_coefficients_altered_hash_2,
                $rr_coeff_genetic_covariance_altered_array_2, $rr_coeff_env_covariance_altered_array_2, $rr_coeff_genetic_correlation_altered_array_2, $rr_coeff_env_correlation_altered_array_2, $rr_residual_variance_altered_2, $varcomp_altered_array_2,
                $model_sum_square_residual_altered_2, $genetic_effect_min_altered_2, $genetic_effect_max_altered_2, $env_effect_min_altered_2, $env_effect_max_altered_2, $genetic_effect_sum_square_altered_2, $genetic_effect_sum_altered_2, $env_effect_sum_square_altered_2, $env_effect_sum_altered_2, $residual_sum_square_altered_2, $residual_sum_altered_2, $result_cv_altered_2, $result_cv_2_altered_2,

                $phenotype_data_altered_env_hash_1_2, $data_matrix_altered_env_array_1_2, $data_matrix_phenotypes_altered_env_array_1_2, $phenotype_min_altered_env_1_2, $phenotype_max_altered_env_1_2, $env_sim_min_1_2, $env_sim_max_1_2, $sim_data_hash_1_2,
                $result_blup_data_altered_env_1_2, $result_blup_data_delta_altered_env_1_2, $result_blup_spatial_data_altered_env_1_2, $result_blup_pe_data_altered_env_1_2, $result_blup_pe_data_delta_altered_env_1_2, $result_residual_data_altered_env_1_2, $result_fitted_data_altered_env_1_2, $fixed_effects_altered_env_hash_1_2, $rr_genetic_coefficients_altered_env_hash_1_2, $rr_temporal_coefficients_altered_env_hash_1_2,
                $rr_coeff_genetic_covariance_altered_env_array_1_2, $rr_coeff_env_covariance_altered_env_array_1_2, $rr_coeff_genetic_correlation_altered_env_array_1_2, $rr_coeff_env_correlation_altered_env_array_1_2, $rr_residual_variance_altered_env_1_2, $varcomp_altered_array_env_1_2,
                $model_sum_square_residual_altered_env_1_2, $genetic_effect_min_altered_env_1_2, $genetic_effect_max_altered_env_1_2, $env_effect_min_altered_env_1_2, $env_effect_max_altered_env_1_2, $genetic_effect_sum_square_altered_env_1_2, $genetic_effect_sum_altered_env_1_2, $env_effect_sum_square_altered_env_1_2, $env_effect_sum_altered_env_1_2, $residual_sum_square_altered_env_1_2, $residual_sum_altered_env_1_2, $result_cv_altered_env_1_2, $result_cv_2_altered_env_1_2,

                $phenotype_data_altered_env_hash_2_2, $data_matrix_altered_env_array_2_2, $data_matrix_phenotypes_altered_env_array_2_2, $phenotype_min_altered_env_2_2, $phenotype_max_altered_env_2_2, $env_sim_min_2_2, $env_sim_max_2_2, $sim_data_hash_2_2,
                $result_blup_data_altered_env_2_2, $result_blup_data_delta_altered_env_2_2, $result_blup_spatial_data_altered_env_2_2, $result_blup_pe_data_altered_env_2_2, $result_blup_pe_data_delta_altered_env_2_2, $result_residual_data_altered_env_2_2, $result_fitted_data_altered_env_2_2, $fixed_effects_altered_env_hash_2_2, $rr_genetic_coefficients_altered_env_hash_2_2, $rr_temporal_coefficients_altered_env_hash_2_2,
                $rr_coeff_genetic_covariance_altered_env_array_2_2, $rr_coeff_env_covariance_altered_env_array_2_2, $rr_coeff_genetic_correlation_altered_env_array_2_2, $rr_coeff_env_correlation_altered_env_array_2_2, $rr_residual_variance_altered_env_2_2, $varcomp_altered_array_env_2_2,
                $model_sum_square_residual_altered_env_2_2, $genetic_effect_min_altered_env_2_2, $genetic_effect_max_altered_env_2_2, $env_effect_min_altered_env_2_2, $env_effect_max_altered_env_2_2, $genetic_effect_sum_square_altered_env_2_2, $genetic_effect_sum_altered_env_2_2, $env_effect_sum_square_altered_env_2_2, $env_effect_sum_altered_env_2_2, $residual_sum_square_altered_env_2_2, $residual_sum_altered_env_2_2, $result_cv_altered_env_2_2, $result_cv_2_altered_env_2_2,

                $phenotype_data_altered_env_hash_3_2, $data_matrix_altered_env_array_3_2, $data_matrix_phenotypes_altered_env_array_3_2, $phenotype_min_altered_env_3_2, $phenotype_max_altered_env_3_2, $env_sim_min_3_2, $env_sim_max_3_2, $sim_data_hash_3_2,
                $result_blup_data_altered_env_3_2, $result_blup_data_delta_altered_env_3_2, $result_blup_spatial_data_altered_env_3_2, $result_blup_pe_data_altered_env_3_2, $result_blup_pe_data_delta_altered_env_3_2, $result_residual_data_altered_env_3_2, $result_fitted_data_altered_env_3_2, $fixed_effects_altered_env_hash_3_2, $rr_genetic_coefficients_altered_env_hash_3_2, $rr_temporal_coefficients_altered_env_hash_3_2,
                $rr_coeff_genetic_covariance_altered_env_array_3_2, $rr_coeff_env_covariance_altered_env_array_3_2, $rr_coeff_genetic_correlation_altered_env_array_3_2, $rr_coeff_env_correlation_altered_env_array_3_2, $rr_residual_variance_altered_env_3_2, $varcomp_altered_array_env_3_2,
                $model_sum_square_residual_altered_env_3_2, $genetic_effect_min_altered_env_3_2, $genetic_effect_max_altered_env_3_2, $env_effect_min_altered_env_3_2, $env_effect_max_altered_env_3_2, $genetic_effect_sum_square_altered_env_3_2, $genetic_effect_sum_altered_env_3_2, $env_effect_sum_square_altered_env_3_2, $env_effect_sum_altered_env_3_2, $residual_sum_square_altered_env_3_2, $residual_sum_altered_env_3_2, $result_cv_altered_env_3_2, $result_cv_2_altered_env_3_2,

                $phenotype_data_altered_env_hash_4_2, $data_matrix_altered_env_array_4_2, $data_matrix_phenotypes_altered_env_array_4_2, $phenotype_min_altered_env_4_2, $phenotype_max_altered_env_4_2, $env_sim_min_4_2, $env_sim_max_4_2, $sim_data_hash_4_2,
                $result_blup_data_altered_env_4_2, $result_blup_data_delta_altered_env_4_2, $result_blup_spatial_data_altered_env_4_2, $result_blup_pe_data_altered_env_4_2, $result_blup_pe_data_delta_altered_env_4_2, $result_residual_data_altered_env_4_2, $result_fitted_data_altered_env_4_2, $fixed_effects_altered_env_hash_4_2, $rr_genetic_coefficients_altered_env_hash_4_2, $rr_temporal_coefficients_altered_env_hash_4_2,
                $rr_coeff_genetic_covariance_altered_env_array_4_2, $rr_coeff_env_covariance_altered_env_array_4_2, $rr_coeff_genetic_correlation_altered_env_array_4_2, $rr_coeff_env_correlation_altered_env_array_4_2, $rr_residual_variance_altered_env_4_2, $varcomp_altered_array_env_4_2,
                $model_sum_square_residual_altered_env_4_2, $genetic_effect_min_altered_env_4_2, $genetic_effect_max_altered_env_4_2, $env_effect_min_altered_env_4_2, $env_effect_max_altered_env_4_2, $genetic_effect_sum_square_altered_env_4_2, $genetic_effect_sum_altered_env_4_2, $env_effect_sum_square_altered_env_4_2, $env_effect_sum_altered_env_4_2, $residual_sum_square_altered_env_4_2, $residual_sum_altered_env_4_2, $result_cv_altered_env_4_2, $result_cv_2_altered_env_4_2,

                $phenotype_data_altered_env_hash_5_2, $data_matrix_altered_env_array_5_2, $data_matrix_phenotypes_altered_env_array_5_2, $phenotype_min_altered_env_5_2, $phenotype_max_altered_env_5_2, $env_sim_min_5_2, $env_sim_max_5_2, $sim_data_hash_5_2,
                $result_blup_data_altered_env_5_2, $result_blup_data_delta_altered_env_5_2, $result_blup_spatial_data_altered_env_5_2, $result_blup_pe_data_altered_env_5_2, $result_blup_pe_data_delta_altered_env_5_2, $result_residual_data_altered_env_5_2, $result_fitted_data_altered_env_5_2, $fixed_effects_altered_env_hash_5_2, $rr_genetic_coefficients_altered_env_hash_5_2, $rr_temporal_coefficients_altered_env_hash_5_2,
                $rr_coeff_genetic_covariance_altered_env_array_5_2, $rr_coeff_env_covariance_altered_env_array_5_2, $rr_coeff_genetic_correlation_altered_env_array_5_2, $rr_coeff_env_correlation_altered_env_array_5_2, $rr_residual_variance_altered_env_5_2, $varcomp_altered_array_env_5_2,
                $model_sum_square_residual_altered_env_5_2, $genetic_effect_min_altered_env_5_2, $genetic_effect_max_altered_env_5_2, $env_effect_min_altered_env_5_2, $env_effect_max_altered_env_5_2, $genetic_effect_sum_square_altered_env_5_2, $genetic_effect_sum_altered_env_5_2, $env_effect_sum_square_altered_env_5_2, $env_effect_sum_altered_env_5_2, $residual_sum_square_altered_env_5_2, $residual_sum_altered_env_5_2, $result_cv_altered_env_5_2, $result_cv_2_altered_env_5_2,

                $phenotype_data_altered_env_hash_6_2, $data_matrix_altered_env_array_6_2, $data_matrix_phenotypes_altered_env_array_6_2, $phenotype_min_altered_env_6_2, $phenotype_max_altered_env_6_2, $env_sim_min_6_2, $env_sim_max_6_2, $sim_data_hash_6_2,
                $result_blup_data_altered_env_6_2, $result_blup_data_delta_altered_env_6_2, $result_blup_spatial_data_altered_env_6_2, $result_blup_pe_data_altered_env_6_2, $result_blup_pe_data_delta_altered_env_6_2, $result_residual_data_altered_env_6_2, $result_fitted_data_altered_env_6_2, $fixed_effects_altered_env_hash_6_2, $rr_genetic_coefficients_altered_env_hash_6_2, $rr_temporal_coefficients_altered_env_hash_6_2,
                $rr_coeff_genetic_covariance_altered_env_array_6_2, $rr_coeff_env_covariance_altered_env_array_6_2, $rr_coeff_genetic_correlation_altered_env_array_6_2, $rr_coeff_env_correlation_altered_env_array_6_2, $rr_residual_variance_altered_env_6_2, $varcomp_altered_array_env_6_2,
                $model_sum_square_residual_altered_env_6_2, $genetic_effect_min_altered_env_6_2, $genetic_effect_max_altered_env_6_2, $env_effect_min_altered_env_6_2, $env_effect_max_altered_env_6_2, $genetic_effect_sum_square_altered_env_6_2, $genetic_effect_sum_altered_env_6_2, $env_effect_sum_square_altered_env_6_2, $env_effect_sum_altered_env_6_2, $residual_sum_square_altered_env_6_2, $residual_sum_altered_env_6_2, $result_cv_altered_env_6_2, $result_cv_2_altered_env_6_2
                ) = @$result_2;

                eval {
                    print STDERR "PLOTTING CORRELATION\n";
                    my ($full_plot_level_correlation_tempfile_fh, $full_plot_level_correlation_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open(my $F_fullplot, ">", $full_plot_level_correlation_tempfile) || die "Can't open file ".$full_plot_level_correlation_tempfile;

                        my @header_full_plot_corr = ('plot_name, plot_id, row_number, col_number, rep, block, germplasm_name, germplasm_id');
                        my @types_full_plot_corr = ('pheno_orig_', 'pheno_postm2_', 'eff_origm2_', 'eff_postm2_',
                        'sim_env1_', 'simm2_pheno1_', 'effm2_sim1_',
                        'sim_env2_', 'simm2_pheno2_', 'effm2_sim2_',
                        'sim_env3_', 'simm2_pheno3_', 'effm2_sim3_',
                        'sim_env4_', 'simm2_pheno4_', 'effm2_sim4_',
                        'sim_env5_', 'simm2_pheno5_', 'effm2_sim5_',
                        'sim_env6_', 'simm2_pheno6_', 'effm2_sim6_');
                        foreach my $t (@sorted_trait_names_2) {
                            foreach my $type (@types_full_plot_corr) {
                                push @header_full_plot_corr, $type.$trait_name_encoder_2{$t};
                            }
                        }
                        my $header_string_full_plot_corr = join ',', @header_full_plot_corr;
                        print $F_fullplot "$header_string_full_plot_corr\n";
                        foreach my $p (@unique_plot_names) {
                            my @row = ($p, $stock_name_row_col{$p}->{obsunit_stock_id}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $stock_name_row_col{$p}->{rep}, $stock_name_row_col{$p}->{block}, $stock_name_row_col{$p}->{germplasm_name}, $stock_name_row_col{$p}->{germplasm_stock_id});
                            foreach my $t (@sorted_trait_names_2) {
                                my $t_conv = $trait_name_encoder_rev_2{$trait_name_encoder_2{$t}};

                                my $phenotype_original = $phenotype_data_original_2{$p}->{$t};
                                my $phenotype_post_2 = $phenotype_data_altered_hash_2->{$p}->{$t_conv};
                                my $effect_original_2 = $result_blup_spatial_data_original_2->{$p}->{$t_conv}->[0];
                                my $effect_post_2 = $result_blup_spatial_data_altered_2->{$p}->{$t_conv}->[0];
                                push @row, ($phenotype_original, $phenotype_post_2, $effect_original_2, $effect_post_2);

                                my $sim_env = $sim_data_hash_1_2->{$p}->{$t};
                                my $pheno_sim_2 = $phenotype_data_altered_env_hash_1_2->{$p}->{$t_conv};
                                my $effect_sim_2 = $result_blup_spatial_data_altered_env_1_2->{$p}->{$t_conv}->[0];
                                push @row, ($sim_env, $pheno_sim_2, $effect_sim_2);

                                my $sim_env2 = $sim_data_hash_2_2->{$p}->{$t};
                                my $pheno_sim2_2 = $phenotype_data_altered_env_hash_2_2->{$p}->{$t_conv};
                                my $effect_sim2_2 = $result_blup_spatial_data_altered_env_2_2->{$p}->{$t_conv}->[0];
                                push @row, ($sim_env2, $pheno_sim2_2, $effect_sim2_2);

                                my $sim_env3 = $sim_data_hash_3_2->{$p}->{$t};
                                my $pheno_sim3_2 = $phenotype_data_altered_env_hash_3_2->{$p}->{$t_conv};
                                my $effect_sim3_2 = $result_blup_spatial_data_altered_env_3_2->{$p}->{$t_conv}->[0];
                                push @row, ($sim_env3, $pheno_sim3_2, $effect_sim3_2);

                                my $sim_env4 = $sim_data_hash_4_2->{$p}->{$t};
                                my $pheno_sim4_2 = $phenotype_data_altered_env_hash_4_2->{$p}->{$t_conv};
                                my $effect_sim4_2 = $result_blup_spatial_data_altered_env_4_2->{$p}->{$t_conv}->[0];
                                push @row, ($sim_env4, $pheno_sim4_2, $effect_sim4_2);

                                my $sim_env5 = $sim_data_hash_5_2->{$p}->{$t};
                                my $pheno_sim5_2 = $phenotype_data_altered_env_hash_5_2->{$p}->{$t_conv};
                                my $effect_sim5_2 = $result_blup_spatial_data_altered_env_5_2->{$p}->{$t_conv}->[0];
                                push @row, ($sim_env5, $pheno_sim5_2, $effect_sim5_2);

                                my $sim_env6 = $sim_data_hash_6_2->{$p}->{$t};
                                my $pheno_sim6_2 = $phenotype_data_altered_env_hash_6_2->{$p}->{$t_conv};
                                my $effect_sim6_2 = $result_blup_spatial_data_altered_env_6_2->{$p}->{$t_conv}->[0];
                                push @row, ($sim_env6, $pheno_sim6_2, $effect_sim6_2);
                            }
                            my $line = join ',', @row;
                            print $F_fullplot "$line\n";
                        }
                    close($F_fullplot);

                    my $plot_corr_figure_tempfile_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $plot_corr_figure_tempfile_string .= '.png';
                    my $plot_corr_figure_tempfile = $c->config->{basepath}."/".$plot_corr_figure_tempfile_string;

                    my $cmd_plotcorr_plot = 'R -e "library(data.table); library(ggplot2); library(GGally);
                    mat_orig <- fread(\''.$full_plot_level_correlation_tempfile.'\', header=TRUE, sep=\',\');
                    gg <- ggcorr(data=mat_orig[,-seq(1,8)], hjust = 1, size = 2, color = \'grey50\', layout.exp = 1, label = TRUE);
                    ggsave(\''.$plot_corr_figure_tempfile.'\', gg, device=\'png\', width=30, height=30, limitsize = FALSE, units=\'in\');
                    "';
                    # print STDERR Dumper $cmd;
                    my $status_plotcorr_plot = system($cmd_plotcorr_plot);
                    push @$spatial_effects_plots, [$plot_corr_figure_tempfile_string, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_fullcorr_"."envvar_".$env_variance_percent."_".$iterations];
                    push @$spatial_effects_files_store, [$full_plot_level_correlation_tempfile, "datafile_".$statistics_select.$sim_env_change_over_time.$correlation_between_times."_fullcorr_"."envvar_".$env_variance_percent."_".$iterations];
                };

                eval {
                    my @plot_corr_full_vals;

                    my @original_pheno_vals;
                    my ($phenotypes_original_heatmap_tempfile_fh, $phenotypes_original_heatmap_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open(my $F_pheno, ">", $phenotypes_original_heatmap_tempfile) || die "Can't open file ".$phenotypes_original_heatmap_tempfile;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_2) {
                                my $val = $phenotype_data_original_2{$p}->{$t};
                                my @row = ("pheno_orig_".$t, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                push @original_pheno_vals, $val;
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                            }
                        }
                    close($F_pheno);
                    push @plot_corr_full_vals, \@original_pheno_vals;

                    my $original_pheno_stat = Statistics::Descriptive::Full->new();
                    $original_pheno_stat->add_data(@original_pheno_vals);
                    my $sig_original_pheno = $original_pheno_stat->variance();

                    #PHENO POST M START

                    my @altered_pheno_vals_2;
                    my ($phenotypes_post_heatmap_tempfile_fh_2, $phenotypes_post_heatmap_tempfile_2) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $phenotypes_post_heatmap_tempfile_2) || die "Can't open file ".$phenotypes_post_heatmap_tempfile_2;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_2) {
                                my $val = $phenotype_data_altered_hash_2->{$p}->{$t};
                                my @row = ("pheno_postm2_".$trait_name_encoder_2{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                push @altered_pheno_vals_2, $val;
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                            }
                        }
                    close($F_pheno);
                    push @plot_corr_full_vals, \@altered_pheno_vals_2;

                    my $altered_pheno_stat_2 = Statistics::Descriptive::Full->new();
                    $altered_pheno_stat_2->add_data(@altered_pheno_vals_2);
                    my $sig_altered_pheno_2 = $altered_pheno_stat_2->variance();

                    # EFFECT ORIGINAL M

                    my @original_effect_vals_2;
                    my ($effects_heatmap_tempfile_fh_2, $effects_heatmap_tempfile_2) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open(my $F_eff, ">", $effects_heatmap_tempfile_2) || die "Can't open file ".$effects_heatmap_tempfile_2;
                        print $F_eff "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_2) {
                                my $val = $result_blup_spatial_data_original_2->{$p}->{$t}->[0];
                                my @row = ("eff_origm2_".$trait_name_encoder_2{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_eff "$line\n";
                                push @original_effect_vals_2, $val;
                            }
                        }
                    close($F_eff);
                    push @plot_corr_full_vals, \@original_effect_vals_2;

                    my $original_effect_stat_2 = Statistics::Descriptive::Full->new();
                    $original_effect_stat_2->add_data(@original_effect_vals_2);
                    my $sig_original_effect_2 = $original_effect_stat_2->variance();

                    # EFFECT POST M MIN

                    my @altered_effect_vals_2;
                    my ($effects_post_heatmap_tempfile_fh_2, $effects_post_heatmap_tempfile_2) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_eff, ">", $effects_post_heatmap_tempfile_2) || die "Can't open file ".$effects_post_heatmap_tempfile_2;
                        print $F_eff "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_2) {
                                my $val = $result_blup_spatial_data_altered_2->{$p}->{$t}->[0];
                                my @row = ("eff_postm2_".$trait_name_encoder_2{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_eff "$line\n";
                                push @altered_effect_vals_2, $val;
                            }
                        }
                    close($F_eff);
                    push @plot_corr_full_vals, \@altered_effect_vals_2;

                    my $altered_effect_stat_2 = Statistics::Descriptive::Full->new();
                    $altered_effect_stat_2->add_data(@altered_effect_vals_2);
                    my $sig_altered_effect_2 = $altered_effect_stat_2->variance();

                    # SIM ENV 1: ALTERED PHENO + EFFECT

                    my ($phenotypes_env_heatmap_tempfile_fh, $phenotypes_env_heatmap_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $phenotypes_env_heatmap_tempfile) || die "Can't open file ".$phenotypes_env_heatmap_tempfile;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_2) {
                                my @row = ("sim_env1_".$t, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $sim_data_hash_1_2->{$p}->{$t});
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                            }
                        }
                    close($F_pheno);

                    my @sim_pheno1_vals_2;
                    my ($phenotypes_pheno_sim_heatmap_tempfile_fh_2, $phenotypes_pheno_sim_heatmap_tempfile_2) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $phenotypes_pheno_sim_heatmap_tempfile_2) || die "Can't open file ".$phenotypes_pheno_sim_heatmap_tempfile_2;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_2) {
                                my $val = $phenotype_data_altered_env_hash_1_2->{$p}->{$t};
                                my @row = ("simm2_pheno1_".$trait_name_encoder_2{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                                push @sim_pheno1_vals_2, $val;
                            }
                        }
                    close($F_pheno);
                    push @plot_corr_full_vals, \@sim_pheno1_vals_2;

                    my $sim_pheno1_stat_2 = Statistics::Descriptive::Full->new();
                    $sim_pheno1_stat_2->add_data(@sim_pheno1_vals_2);
                    my $sig_sim2_pheno1 = $sim_pheno1_stat_2->variance();

                    my @sim_effect1_vals_2;
                    my ($effects_sim_heatmap_tempfile_fh_2, $effects_sim_heatmap_tempfile_2) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_eff, ">", $effects_sim_heatmap_tempfile_2) || die "Can't open file ".$effects_sim_heatmap_tempfile_2;
                        print $F_eff "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_2) {
                                my $val = $result_blup_spatial_data_altered_env_1_2->{$p}->{$t}->[0];
                                my @row = ("effm2_sim1_".$trait_name_encoder_2{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_eff "$line\n";
                                push @sim_effect1_vals_2, $val;
                            }
                        }
                    close($F_eff);
                    push @plot_corr_full_vals, \@sim_effect1_vals_2;

                    my $sim_effect1_stat_2 = Statistics::Descriptive::Full->new();
                    $sim_effect1_stat_2->add_data(@sim_effect1_vals_2);
                    my $sig_sim2_effect1 = $sim_effect1_stat_2->variance();

                    # SIM ENV 2: ALTERED PHENO + EFFECT

                    my ($phenotypes_env_heatmap_tempfile2_fh, $phenotypes_env_heatmap_tempfile2) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $phenotypes_env_heatmap_tempfile2) || die "Can't open file ".$phenotypes_env_heatmap_tempfile2;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_2) {
                                my @row = ("sim_env2_".$t, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $sim_data_hash_2_2->{$p}->{$t});
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                            }
                        }
                    close($F_pheno);

                    my @sim_pheno2_vals_2;
                    my ($phenotypes_pheno_sim_heatmap_tempfile2_fh_2, $phenotypes_pheno_sim_heatmap_tempfile2_2) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $phenotypes_pheno_sim_heatmap_tempfile2_2) || die "Can't open file ".$phenotypes_pheno_sim_heatmap_tempfile2_2;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_2) {
                                my $val = $phenotype_data_altered_env_hash_2_2->{$p}->{$t};
                                my @row = ("simm2_pheno2_".$trait_name_encoder_2{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                                push @sim_pheno2_vals_2, $val;
                            }
                        }
                    close($F_pheno);
                    push @plot_corr_full_vals, \@sim_pheno2_vals_2;

                    my $sim_pheno2_stat_2 = Statistics::Descriptive::Full->new();
                    $sim_pheno2_stat_2->add_data(@sim_pheno2_vals_2);
                    my $sig_sim_pheno2_2 = $sim_pheno2_stat_2->variance();

                    my @sim_effect2_vals_2;
                    my ($effects_sim_heatmap_tempfile2_fh_2, $effects_sim_heatmap_tempfile2_2) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_eff, ">", $effects_sim_heatmap_tempfile2_2) || die "Can't open file ".$effects_sim_heatmap_tempfile2_2;
                        print $F_eff "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_2) {
                                my $val = $result_blup_spatial_data_altered_env_2_2->{$p}->{$t}->[0];
                                my @row = ("effm2_sim2_".$trait_name_encoder_2{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_eff "$line\n";
                                push @sim_effect2_vals_2, $val;
                            }
                        }
                    close($F_eff);
                    push @plot_corr_full_vals, \@sim_effect2_vals_2;

                    my $sim_effect2_stat_2 = Statistics::Descriptive::Full->new();
                    $sim_effect2_stat_2->add_data(@sim_effect2_vals_2);
                    my $sig_sim_effect2_2 = $sim_effect2_stat_2->variance();

                    # SIM ENV 3: ALTERED PHENO + EFFECT

                    my ($phenotypes_env_heatmap_tempfile3_fh, $phenotypes_env_heatmap_tempfile3) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $phenotypes_env_heatmap_tempfile3) || die "Can't open file ".$phenotypes_env_heatmap_tempfile3;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_2) {
                                my @row = ("sim_env3_".$t, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $sim_data_hash_3_2->{$p}->{$t});
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                            }
                        }
                    close($F_pheno);

                    my @sim_pheno3_vals_2;
                    my ($phenotypes_pheno_sim_heatmap_tempfile3_fh_2, $phenotypes_pheno_sim_heatmap_tempfile3_2) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $phenotypes_pheno_sim_heatmap_tempfile3_2) || die "Can't open file ".$phenotypes_pheno_sim_heatmap_tempfile3_2;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_2) {
                                my $val = $phenotype_data_altered_env_hash_3_2->{$p}->{$t};
                                my @row = ("simm2_pheno3_".$trait_name_encoder_2{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                                push @sim_pheno3_vals_2, $val;
                            }
                        }
                    close($F_pheno);
                    push @plot_corr_full_vals, \@sim_pheno3_vals_2;

                    my $sim_pheno3_stat_2 = Statistics::Descriptive::Full->new();
                    $sim_pheno3_stat_2->add_data(@sim_pheno3_vals_2);
                    my $sig_sim_pheno3_2 = $sim_pheno3_stat_2->variance();

                    my @sim_effect3_vals_2;
                    my ($effects_sim_heatmap_tempfile3_fh_2, $effects_sim_heatmap_tempfile3_2) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_eff, ">", $effects_sim_heatmap_tempfile3_2) || die "Can't open file ".$effects_sim_heatmap_tempfile3_2;
                        print $F_eff "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_2) {
                                my $val = $result_blup_spatial_data_altered_env_3_2->{$p}->{$t}->[0];
                                my @row = ("effm2_sim3_".$trait_name_encoder_2{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_eff "$line\n";
                                push @sim_effect3_vals_2, $val;
                            }
                        }
                    close($F_eff);
                    push @plot_corr_full_vals, \@sim_effect3_vals_2;

                    my $sim_effect3_stat_2 = Statistics::Descriptive::Full->new();
                    $sim_effect3_stat_2->add_data(@sim_effect3_vals_2);
                    my $sig_sim_effect3_2 = $sim_effect3_stat_2->variance();

                    # SIM ENV 4: ALTERED PHENO + EFFECT

                    my ($phenotypes_env_heatmap_tempfile4_fh, $phenotypes_env_heatmap_tempfile4) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $phenotypes_env_heatmap_tempfile4) || die "Can't open file ".$phenotypes_env_heatmap_tempfile4;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_2) {
                                my @row = ("sim_env4_".$t, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $sim_data_hash_4_2->{$p}->{$t});
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                            }
                        }
                    close($F_pheno);

                    my @sim_pheno4_vals_2;
                    my ($phenotypes_pheno_sim_heatmap_tempfile4_fh_2, $phenotypes_pheno_sim_heatmap_tempfile4_2) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $phenotypes_pheno_sim_heatmap_tempfile4_2) || die "Can't open file ".$phenotypes_pheno_sim_heatmap_tempfile4_2;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_2) {
                                my $val = $phenotype_data_altered_env_hash_4_2->{$p}->{$t};
                                my @row = ("simm2_pheno4_".$trait_name_encoder_2{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                                push @sim_pheno4_vals_2, $val;
                            }
                        }
                    close($F_pheno);
                    push @plot_corr_full_vals, \@sim_pheno4_vals_2;

                    my $sim_pheno4_stat_2 = Statistics::Descriptive::Full->new();
                    $sim_pheno4_stat_2->add_data(@sim_pheno4_vals_2);
                    my $sig_sim_pheno4_2 = $sim_pheno4_stat_2->variance();

                    my @sim_effect4_vals_2;
                    my ($effects_sim_heatmap_tempfile4_fh_2, $effects_sim_heatmap_tempfile4_2) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_eff, ">", $effects_sim_heatmap_tempfile4_2) || die "Can't open file ".$effects_sim_heatmap_tempfile4_2;
                        print $F_eff "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_2) {
                                my $val = $result_blup_spatial_data_altered_env_4_2->{$p}->{$t}->[0];
                                my @row = ("effm2_sim4_".$trait_name_encoder_2{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_eff "$line\n";
                                push @sim_effect4_vals_2, $val;
                            }
                        }
                    close($F_eff);
                    push @plot_corr_full_vals, \@sim_effect4_vals_2;

                    my $sim_effect4_stat_2 = Statistics::Descriptive::Full->new();
                    $sim_effect4_stat_2->add_data(@sim_effect4_vals_2);
                    my $sig_sim_effect4_2 = $sim_effect4_stat_2->variance();

                    # SIM ENV 5: ALTERED PHENO + EFFECT

                    my ($phenotypes_env_heatmap_tempfile5_fh, $phenotypes_env_heatmap_tempfile5) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $phenotypes_env_heatmap_tempfile5) || die "Can't open file ".$phenotypes_env_heatmap_tempfile5;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_2) {
                                my @row = ("sim_env5_".$t, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $sim_data_hash_5_2->{$p}->{$t});
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                            }
                        }
                    close($F_pheno);

                    my @sim_pheno5_vals_2;
                    my ($phenotypes_pheno_sim_heatmap_tempfile5_fh_2, $phenotypes_pheno_sim_heatmap_tempfile5_2) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $phenotypes_pheno_sim_heatmap_tempfile5_2) || die "Can't open file ".$phenotypes_pheno_sim_heatmap_tempfile5_2;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_2) {
                                my $val = $phenotype_data_altered_env_hash_5_2->{$p}->{$t};
                                my @row = ("simm2_pheno5_".$trait_name_encoder_2{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                                push @sim_pheno5_vals_2, $val;
                            }
                        }
                    close($F_pheno);
                    push @plot_corr_full_vals, \@sim_pheno5_vals_2;

                    my $sim_pheno5_stat_2 = Statistics::Descriptive::Full->new();
                    $sim_pheno5_stat_2->add_data(@sim_pheno5_vals_2);
                    my $sig_sim_pheno5_2 = $sim_pheno5_stat_2->variance();

                    my @sim_effect5_vals_2;
                    my ($effects_sim_heatmap_tempfile5_fh_2, $effects_sim_heatmap_tempfile5_2) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_eff, ">", $effects_sim_heatmap_tempfile5_2) || die "Can't open file ".$effects_sim_heatmap_tempfile5_2;
                        print $F_eff "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_2) {
                                my $val = $result_blup_spatial_data_altered_env_5_2->{$p}->{$t}->[0];
                                my @row = ("effm2_sim5_".$trait_name_encoder_2{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_eff "$line\n";
                                push @sim_effect5_vals_2, $val;
                            }
                        }
                    close($F_eff);
                    push @plot_corr_full_vals, \@sim_effect5_vals_2;

                    my $sim_effect5_stat_2 = Statistics::Descriptive::Full->new();
                    $sim_effect5_stat_2->add_data(@sim_effect5_vals_2);
                    my $sig_sim_effect5_2 = $sim_effect5_stat_2->variance();

                    # SIM ENV 6: ALTERED PHENO + EFFECT

                    my ($phenotypes_env_heatmap_tempfile6_fh, $phenotypes_env_heatmap_tempfile6) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $phenotypes_env_heatmap_tempfile6) || die "Can't open file ".$phenotypes_env_heatmap_tempfile6;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_2) {
                                my @row = ("sim_env6_".$t, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $sim_data_hash_6_2->{$p}->{$t});
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                            }
                        }
                    close($F_pheno);

                    my @sim_pheno6_vals_2;
                    my ($phenotypes_pheno_sim_heatmap_tempfile6_fh_2, $phenotypes_pheno_sim_heatmap_tempfile6_2) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $phenotypes_pheno_sim_heatmap_tempfile6_2) || die "Can't open file ".$phenotypes_pheno_sim_heatmap_tempfile6_2;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_2) {
                                my $val = $phenotype_data_altered_env_hash_6_2->{$p}->{$t};
                                my @row = ("simm2_pheno6_".$trait_name_encoder_2{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                                push @sim_pheno6_vals_2, $val;
                            }
                        }
                    close($F_pheno);
                    push @plot_corr_full_vals, \@sim_pheno6_vals_2;

                    my $sim_pheno6_stat_2 = Statistics::Descriptive::Full->new();
                    $sim_pheno6_stat_2->add_data(@sim_pheno6_vals_2);
                    my $sig_sim_pheno6_2 = $sim_pheno6_stat_2->variance();

                    my @sim_effect6_vals_2;
                    my ($effects_sim_heatmap_tempfile6_fh_2, $effects_sim_heatmap_tempfile6_2) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_eff, ">", $effects_sim_heatmap_tempfile6_2) || die "Can't open file ".$effects_sim_heatmap_tempfile6_2;
                        print $F_eff "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_2) {
                                my $val = $result_blup_spatial_data_altered_env_6_2->{$p}->{$t}->[0];
                                my @row = ("effm2_sim6_".$trait_name_encoder_2{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_eff "$line\n";
                                push @sim_effect6_vals_2, $val;
                            }
                        }
                    close($F_eff);
                    push @plot_corr_full_vals, \@sim_effect6_vals_2;

                    my $sim_effect6_stat_2 = Statistics::Descriptive::Full->new();
                    $sim_effect6_stat_2->add_data(@sim_effect6_vals_2);
                    my $sig_sim_effect6_2 = $sim_effect6_stat_2->variance();

                    my $plot_corr_summary_figure_inputfile_tempfile = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'tmp_drone_statistics/fileXXXX');
                    open($F_eff, ">", $plot_corr_summary_figure_inputfile_tempfile) || die "Can't open file ".$plot_corr_summary_figure_inputfile_tempfile;
                        foreach (@plot_corr_full_vals) {
                            my $line = join ',', @$_;
                            print $F_eff $line."\n";
                        }
                    close($F_eff);

                    my $plot_corr_summary_figure_tempfile_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $plot_corr_summary_figure_tempfile_string .= '.png';
                    my $plot_corr_summary_figure_tempfile = $c->config->{basepath}."/".$plot_corr_summary_figure_tempfile_string;

                    my $cmd_plotcorrsum_plot = 'R -e "library(data.table); library(ggplot2); library(GGally);
                    mat_full_t <- fread(\''.$plot_corr_summary_figure_inputfile_tempfile.'\', header=FALSE, sep=\',\');
                    mat_full <- data.frame(t(mat_full_t));
                    colnames(mat_full) <- c(\'mat_orig\', \'mat_altered_2\', \'mat_eff_2\', \'mat_eff_altered_2\',
                    \'mat_p_sim1_2\', \'mat_eff_sim1_2\',
                    \'mat_p_sim2_2\', \'mat_eff_sim2_2\',
                    \'mat_p_sim3_2\', \'mat_eff_sim3_2\',
                    \'mat_p_sim4_2\', \'mat_eff_sim4_2\',
                    \'mat_p_sim5_2\', \'mat_eff_sim5_2\',
                    \'mat_p_sim6_2\', \'mat_eff_sim6_2\');
                    mat_env <- fread(\''.$phenotypes_env_heatmap_tempfile.'\', header=TRUE, sep=\',\');
                    mat_env2 <- fread(\''.$phenotypes_env_heatmap_tempfile2.'\', header=TRUE, sep=\',\');
                    mat_env3 <- fread(\''.$phenotypes_env_heatmap_tempfile3.'\', header=TRUE, sep=\',\');
                    mat_env4 <- fread(\''.$phenotypes_env_heatmap_tempfile4.'\', header=TRUE, sep=\',\');
                    mat_env5 <- fread(\''.$phenotypes_env_heatmap_tempfile5.'\', header=TRUE, sep=\',\');
                    mat_env6 <- fread(\''.$phenotypes_env_heatmap_tempfile6.'\', header=TRUE, sep=\',\');
                    mat <- data.frame(pheno_orig = mat_full\$mat_orig, pheno_altm2 = mat_full\$mat_altered_2, eff_origm2 = mat_full\$mat_eff_2, eff_altm2 = mat_full\$mat_eff_altered_2, env_lin = mat_env\$value, pheno_linm2 = mat_full\$mat_p_sim1_2, lin_effm2 = mat_full\$mat_eff_sim1_2, env_n1d = mat_env2\$value, pheno_n1dm2 = mat_full\$mat_p_sim2_2, n1d_effm2 = mat_full\$mat_eff_sim2_2, env_n2d = mat_env3\$value, pheno_n2dm2 = mat_full\$mat_p_sim3_2, n2d_effm2 = mat_full\$mat_eff_sim3_2, env_rand = mat_env4\$value, pheno_randm2 = mat_full\$mat_p_sim4_2, rand_effm2 = mat_full\$mat_eff_sim4_2, env_ar1 = mat_env5\$value, pheno_ar1m2 = mat_full\$mat_p_sim5_2, ar1_effm2 = mat_full\$mat_eff_sim5_2, env_realdata = mat_env6\$value, pheno_realdatam2 = mat_full\$mat_p_sim6_2, realdata_effm2 = mat_full\$mat_eff_sim6_2);
                    gg <- ggcorr(data=mat, hjust = 1, size = 2, color = \'grey50\', layout.exp = 1, label = TRUE, label_round = 2);
                    ggsave(\''.$plot_corr_summary_figure_tempfile.'\', gg, device=\'png\', width=30, height=30, units=\'in\');
                    "';
                    # print STDERR Dumper $cmd_plotcorrsum_plot;
                    my $status_plotcorrsum_plot = system($cmd_plotcorrsum_plot);
                    push @$spatial_effects_plots, [$plot_corr_summary_figure_tempfile_string, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_envsimscorr_"."envvar_".$env_variance_percent."_".$iterations];

                    my $env_effects_first_figure_tempfile_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $env_effects_first_figure_tempfile_string .= '.png';
                    my $env_effects_first_figure_tempfile = $c->config->{basepath}."/".$env_effects_first_figure_tempfile_string;

                    my $env_effects_first_figure_tempfile_string_2 = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $env_effects_first_figure_tempfile_string_2 .= '.png';
                    my $env_effects_first_figure_tempfile_2 = $c->config->{basepath}."/".$env_effects_first_figure_tempfile_string_2;

                    my $output_plot_row = 'row';
                    my $output_plot_col = 'col';
                    if ($max_col > $max_row) {
                        $output_plot_row = 'col';
                        $output_plot_col = 'row';
                    }

                    my $cmd_spatialfirst_plot_2 = 'R -e "library(data.table); library(ggplot2); library(dplyr); library(viridis); library(GGally); library(gridExtra);
                    mat_orig <- fread(\''.$phenotypes_original_heatmap_tempfile.'\', header=TRUE, sep=\',\');
                    mat_altered_2 <- fread(\''.$phenotypes_post_heatmap_tempfile_2.'\', header=TRUE, sep=\',\');
                    pheno_mat <- rbind(mat_orig, mat_altered_2);
                    options(device=\'png\');
                    par();
                    gg <- ggplot(pheno_mat, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_2).');
                    ggsave(\''.$env_effects_first_figure_tempfile_2.'\', gg, device=\'png\', width=20, height=20, units=\'in\');
                    "';
                    # print STDERR Dumper $cmd;
                    my $status_spatialfirst_plot_2 = system($cmd_spatialfirst_plot_2);
                    push @$spatial_effects_plots, [$env_effects_first_figure_tempfile_string_2, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_origheatmap_"."envvar_".$env_variance_percent."_".$iterations];

                    my ($sim_effects_corr_results_fh, $sim_effects_corr_results) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);

                    my $cmd_spatialfirst_plot = 'R -e "library(data.table); library(ggplot2); library(dplyr); library(viridis); library(GGally); library(gridExtra);
                    mat_full_t <- fread(\''.$plot_corr_summary_figure_inputfile_tempfile.'\', header=FALSE, sep=\',\');
                    mat_full <- data.frame(t(mat_full_t));
                    colnames(mat_full) <- c(\'mat_orig\', \'mat_altered_2\', \'mat_eff_2\', \'mat_eff_altered_2\',
                    \'mat_p_sim1_2\', \'mat_eff_sim1_2\',
                    \'mat_p_sim2_2\', \'mat_eff_sim2_2\',
                    \'mat_p_sim3_2\', \'mat_eff_sim3_2\',
                    \'mat_p_sim4_2\', \'mat_eff_sim4_2\',
                    \'mat_p_sim5_2\', \'mat_eff_sim5_2\',
                    \'mat_p_sim6_2\', \'mat_eff_sim6_2\');
                    mat_eff_2 <- fread(\''.$effects_heatmap_tempfile_2.'\', header=TRUE, sep=\',\');
                    mat_eff_altered_2 <- fread(\''.$effects_post_heatmap_tempfile_2.'\', header=TRUE, sep=\',\');
                    effect_mat_2 <- rbind(mat_eff_2, mat_eff_altered_2);
                    mat_env <- fread(\''.$phenotypes_env_heatmap_tempfile.'\', header=TRUE, sep=\',\');
                    mat_env2 <- fread(\''.$phenotypes_env_heatmap_tempfile2.'\', header=TRUE, sep=\',\');
                    mat_env3 <- fread(\''.$phenotypes_env_heatmap_tempfile3.'\', header=TRUE, sep=\',\');
                    mat_env4 <- fread(\''.$phenotypes_env_heatmap_tempfile4.'\', header=TRUE, sep=\',\');
                    mat_env5 <- fread(\''.$phenotypes_env_heatmap_tempfile5.'\', header=TRUE, sep=\',\');
                    mat_env6 <- fread(\''.$phenotypes_env_heatmap_tempfile6.'\', header=TRUE, sep=\',\');
                    options(device=\'png\');
                    par();
                    gg_eff_2 <- ggplot(effect_mat_2, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_2).');
                    ggsave(\''.$env_effects_first_figure_tempfile.'\', arrangeGrob(gg_eff_2, nrow=1), device=\'png\', width=25, height=25, units=\'in\');
                    write.table(data.frame(env_linear = c(cor(mat_env\$value, mat_full\$mat_eff_sim1_2)), env_1DN = c(cor(mat_env2\$value, mat_full\$mat_eff_sim2_2)), env_2DN = c(cor(mat_env3\$value, mat_full\$mat_eff_sim3_2)), env_random = c(cor(mat_env4\$value, mat_full\$mat_eff_sim4_2)), env_ar1xar1 = c(cor(mat_env5\$value, mat_full\$mat_eff_sim5_2)), env_realdata = c(cor(mat_env6\$value, mat_full\$mat_eff_sim6_2)) ), file=\''.$sim_effects_corr_results.'\', row.names=FALSE, col.names=TRUE, sep=\'\t\');
                    "';
                    # print STDERR Dumper $cmd;
                    my $status_spatialfirst_plot = system($cmd_spatialfirst_plot);
                    push @$spatial_effects_plots, [$env_effects_first_figure_tempfile_string, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_originaleffheatmap_"."envvar_".$env_variance_percent."_".$iterations];

                    open(my $fh_corr_result, '<', $sim_effects_corr_results) or die "Could not open file '$sim_effects_corr_results' $!";
                        print STDERR "Opened $sim_effects_corr_results\n";

                        my $header = <$fh_corr_result>;
                        my @header;
                        if ($csv->parse($header)) {
                            @header = $csv->fields();
                        }

                        while (my $row = <$fh_corr_result>) {
                            my @columns;
                            my $counter = 0;
                            if ($csv->parse($row)) {
                                @columns = $csv->fields();
                            }
                            foreach (@columns) {
                                push @{$env_corr_res->{$statistics_select."_".$header[$counter]."_corrtime_".$sim_env_change_over_time.$correlation_between_times."_envvar_".$env_variance_percent}->{values}}, $_;
                                $counter++;
                            }
                        }
                    close($fh_corr_result);

                    my $env_effects_sim_figure_tempfile_string_2_env1 = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $env_effects_sim_figure_tempfile_string_2_env1 .= '.png';
                    my $env_effects_sim_figure_tempfile_2_env1 = $c->config->{basepath}."/".$env_effects_sim_figure_tempfile_string_2_env1;

                    my $cmd_spatialenvsim_plot_2_env1 = 'R -e "library(data.table); library(ggplot2); library(dplyr); library(viridis); library(GGally); library(gridExtra);
                    mat_env <- fread(\''.$phenotypes_env_heatmap_tempfile.'\', header=TRUE, sep=\',\');
                    mat_p_sim <- fread(\''.$phenotypes_pheno_sim_heatmap_tempfile_2.'\', header=TRUE, sep=\',\');
                    mat_eff_sim <- fread(\''.$effects_sim_heatmap_tempfile_2.'\', header=TRUE, sep=\',\');
                    options(device=\'png\');
                    par();
                    gg_env <- ggplot(mat_env, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_2).');
                    gg_p_sim <- ggplot(mat_p_sim, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_2).');
                    gg_eff_sim <- ggplot(mat_eff_sim, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_2).');
                    ggsave(\''.$env_effects_sim_figure_tempfile_2_env1.'\', arrangeGrob(gg_env, gg_p_sim, gg_eff_sim, nrow=1), device=\'png\', width=25, height=25, units=\'in\');
                    "';
                    # print STDERR Dumper $cmd_spatialenvsim_plot_2_env1;
                    my $status_spatialenvsim_plot_2_env1 = system($cmd_spatialenvsim_plot_2_env1);
                    push @$spatial_effects_plots, [$env_effects_sim_figure_tempfile_string_2_env1, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_env1effheatmap_"."envvar_".$env_variance_percent."_".$iterations];

                    my $env_effects_sim_figure_tempfile_string_2_env2 = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $env_effects_sim_figure_tempfile_string_2_env2 .= '.png';
                    my $env_effects_sim_figure_tempfile_2_env2 = $c->config->{basepath}."/".$env_effects_sim_figure_tempfile_string_2_env2;

                    my $cmd_spatialenvsim_plot_2_env2 = 'R -e "library(data.table); library(ggplot2); library(dplyr); library(viridis); library(GGally); library(gridExtra);
                    mat_env2 <- fread(\''.$phenotypes_env_heatmap_tempfile2.'\', header=TRUE, sep=\',\');
                    mat_p_sim2 <- fread(\''.$phenotypes_pheno_sim_heatmap_tempfile2_2.'\', header=TRUE, sep=\',\');
                    mat_eff_sim2 <- fread(\''.$effects_sim_heatmap_tempfile2_2.'\', header=TRUE, sep=\',\');
                    options(device=\'png\');
                    par();
                    gg_env2 <- ggplot(mat_env2, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_2).');
                    gg_p_sim2 <- ggplot(mat_p_sim2, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_2).');
                    gg_eff_sim2 <- ggplot(mat_eff_sim2, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_2).');
                    ggsave(\''.$env_effects_sim_figure_tempfile_2_env2.'\', arrangeGrob(gg_env2, gg_p_sim2, gg_eff_sim2, nrow=1), device=\'png\', width=25, height=25, units=\'in\');
                    "';
                    # print STDERR Dumper $cmd_spatialenvsim_plot_2_env2;
                    my $status_spatialenvsim_plot_2_env2 = system($cmd_spatialenvsim_plot_2_env2);
                    push @$spatial_effects_plots, [$env_effects_sim_figure_tempfile_string_2_env2, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_env2effheatmap_"."envvar_".$env_variance_percent."_".$iterations];

                    my $env_effects_sim_figure_tempfile_string_2_env3 = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $env_effects_sim_figure_tempfile_string_2_env3 .= '.png';
                    my $env_effects_sim_figure_tempfile_2_env3 = $c->config->{basepath}."/".$env_effects_sim_figure_tempfile_string_2_env3;

                    my $cmd_spatialenvsim_plot_2_env3 = 'R -e "library(data.table); library(ggplot2); library(dplyr); library(viridis); library(GGally); library(gridExtra);
                    mat_env3 <- fread(\''.$phenotypes_env_heatmap_tempfile3.'\', header=TRUE, sep=\',\');
                    mat_p_sim3 <- fread(\''.$phenotypes_pheno_sim_heatmap_tempfile3_2.'\', header=TRUE, sep=\',\');
                    mat_eff_sim3 <- fread(\''.$effects_sim_heatmap_tempfile3_2.'\', header=TRUE, sep=\',\');
                    options(device=\'png\');
                    par();
                    gg_env3 <- ggplot(mat_env3, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_2).');
                    gg_p_sim3 <- ggplot(mat_p_sim3, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_2).');
                    gg_eff_sim3 <- ggplot(mat_eff_sim3, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_2).');
                    ggsave(\''.$env_effects_sim_figure_tempfile_2_env3.'\', arrangeGrob(gg_env3, gg_p_sim3, gg_eff_sim3, nrow=1), device=\'png\', width=25, height=25, units=\'in\');
                    "';
                    # print STDERR Dumper $cmd_spatialenvsim_plot_2_env3;
                    my $status_spatialenvsim_plot_2_env3 = system($cmd_spatialenvsim_plot_2_env3);
                    push @$spatial_effects_plots, [$env_effects_sim_figure_tempfile_string_2_env3, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_env3effheatmap_"."envvar_".$env_variance_percent."_".$iterations];

                    my $env_effects_sim_figure_tempfile_string_2_env4 = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $env_effects_sim_figure_tempfile_string_2_env4 .= '.png';
                    my $env_effects_sim_figure_tempfile_2_env4 = $c->config->{basepath}."/".$env_effects_sim_figure_tempfile_string_2_env4;

                    my $cmd_spatialenvsim_plot_2_env4 = 'R -e "library(data.table); library(ggplot2); library(dplyr); library(viridis); library(GGally); library(gridExtra);
                    mat_env4 <- fread(\''.$phenotypes_env_heatmap_tempfile4.'\', header=TRUE, sep=\',\');
                    mat_p_sim4 <- fread(\''.$phenotypes_pheno_sim_heatmap_tempfile4_2.'\', header=TRUE, sep=\',\');
                    mat_eff_sim4 <- fread(\''.$effects_sim_heatmap_tempfile4_2.'\', header=TRUE, sep=\',\');
                    options(device=\'png\');
                    par();
                    gg_env4 <- ggplot(mat_env4, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_2).');
                    gg_p_sim4 <- ggplot(mat_p_sim4, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_2).');
                    gg_eff_sim4 <- ggplot(mat_eff_sim4, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_2).');
                    ggsave(\''.$env_effects_sim_figure_tempfile_2_env4.'\', arrangeGrob(gg_env4, gg_p_sim4, gg_eff_sim4, nrow=1), device=\'png\', width=25, height=25, units=\'in\');
                    "';
                    # print STDERR Dumper $cmd_spatialenvsim_plot_2_env4;
                    my $status_spatialenvsim_plot_2_env4 = system($cmd_spatialenvsim_plot_2_env4);
                    push @$spatial_effects_plots, [$env_effects_sim_figure_tempfile_string_2_env4, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_env4effheatmap_"."envvar_".$env_variance_percent."_".$iterations];

                    my $env_effects_sim_figure_tempfile_string_2_env5 = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $env_effects_sim_figure_tempfile_string_2_env5 .= '.png';
                    my $env_effects_sim_figure_tempfile_2_env5 = $c->config->{basepath}."/".$env_effects_sim_figure_tempfile_string_2_env5;

                    my $cmd_spatialenvsim_plot_2_env5 = 'R -e "library(data.table); library(ggplot2); library(dplyr); library(viridis); library(GGally); library(gridExtra);
                    mat_env5 <- fread(\''.$phenotypes_env_heatmap_tempfile5.'\', header=TRUE, sep=\',\');
                    mat_p_sim5 <- fread(\''.$phenotypes_pheno_sim_heatmap_tempfile5_2.'\', header=TRUE, sep=\',\');
                    mat_eff_sim5 <- fread(\''.$effects_sim_heatmap_tempfile5_2.'\', header=TRUE, sep=\',\');
                    options(device=\'png\');
                    par();
                    gg_env5 <- ggplot(mat_env5, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_2).');
                    gg_p_sim5 <- ggplot(mat_p_sim5, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_2).');
                    gg_eff_sim5 <- ggplot(mat_eff_sim5, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_2).');
                    ggsave(\''.$env_effects_sim_figure_tempfile_2_env5.'\', arrangeGrob(gg_env5, gg_p_sim5, gg_eff_sim5, nrow=1), device=\'png\', width=25, height=25, units=\'in\');
                    "';
                    # print STDERR Dumper $cmd_spatialenvsim_plot_2_env5;
                    my $status_spatialenvsim_plot_2_env5 = system($cmd_spatialenvsim_plot_2_env5);
                    push @$spatial_effects_plots, [$env_effects_sim_figure_tempfile_string_2_env5, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_env5effheatmap_"."envvar_".$env_variance_percent."_".$iterations];

                    my $env_effects_sim_figure_tempfile_string_2_env6 = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $env_effects_sim_figure_tempfile_string_2_env6 .= '.png';
                    my $env_effects_sim_figure_tempfile_2_env6 = $c->config->{basepath}."/".$env_effects_sim_figure_tempfile_string_2_env6;

                    my $cmd_spatialenvsim_plot_2_env6 = 'R -e "library(data.table); library(ggplot2); library(dplyr); library(viridis); library(GGally); library(gridExtra);
                    mat_env6 <- fread(\''.$phenotypes_env_heatmap_tempfile6.'\', header=TRUE, sep=\',\');
                    mat_p_sim6 <- fread(\''.$phenotypes_pheno_sim_heatmap_tempfile6_2.'\', header=TRUE, sep=\',\');
                    mat_eff_sim6 <- fread(\''.$effects_sim_heatmap_tempfile6_2.'\', header=TRUE, sep=\',\');
                    options(device=\'png\');
                    par();
                    gg_env6 <- ggplot(mat_env6, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_2).');
                    gg_p_sim6 <- ggplot(mat_p_sim6, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_2).');
                    gg_eff_sim6 <- ggplot(mat_eff_sim6, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_2).');
                    ggsave(\''.$env_effects_sim_figure_tempfile_2_env6.'\', arrangeGrob(gg_env6, gg_p_sim6, gg_eff_sim6, nrow=1), device=\'png\', width=25, height=25, units=\'in\');
                    "';
                    # print STDERR Dumper $cmd_spatialenvsim_plot_2_env6;
                    my $status_spatialenvsim_plot_2_env6 = system($cmd_spatialenvsim_plot_2_env6);
                    push @$spatial_effects_plots, [$env_effects_sim_figure_tempfile_string_2_env6, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_env6effheatmap_"."envvar_".$env_variance_percent."_".$iterations];
                };

                eval {
                    my @sorted_germplasm_names = sort keys %unique_accessions;

                    my @original_blup_vals_2;
                    my ($effects_original_line_chart_tempfile_fh_2, $effects_original_line_chart_tempfile_2) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open(my $F_pheno, ">", $effects_original_line_chart_tempfile_2) || die "Can't open file ".$effects_original_line_chart_tempfile_2;
                        print $F_pheno "germplasmName,time,value\n";
                        foreach my $p (@sorted_germplasm_names) {
                            foreach my $t (@sorted_trait_names_2) {
                                my $val = $result_blup_data_original_2->{$p}->{$t}->[0];
                                my @row = ($p, $trait_to_time_map_hash_2->{$t}, $val);
                                push @original_blup_vals_2, $val;
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                            }
                        }
                    close($F_pheno);

                    my $original_blup_stat_2 = Statistics::Descriptive::Full->new();
                    $original_blup_stat_2->add_data(@original_blup_vals_2);
                    my $sig_original_blup_2 = $original_blup_stat_2->variance();

                    my @altered_blups_vals_2;
                    my ($effects_altered_line_chart_tempfile_fh_2, $effects_altered_line_chart_tempfile_2) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $effects_altered_line_chart_tempfile_2) || die "Can't open file ".$effects_altered_line_chart_tempfile_2;
                        print $F_pheno "germplasmName,time,value\n";
                        foreach my $p (@sorted_germplasm_names) {
                            foreach my $t (@sorted_trait_names_2) {
                                my $val = $result_blup_data_altered_2->{$p}->{$t}->[0];
                                my @row = ($p, $trait_to_time_map_hash_2->{$t}, $val);
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                                push @altered_blups_vals_2, $val;
                            }
                        }
                    close($F_pheno);

                    my $altered_blup_stat_2 = Statistics::Descriptive::Full->new();
                    $altered_blup_stat_2->add_data(@altered_blups_vals_2);
                    my $sig_altered_blup_2 = $altered_blup_stat_2->variance();

                    my @sim1_blup_vals_2;
                    my ($effects_altered_env1_line_chart_tempfile_fh_2, $effects_altered_env1_line_chart_tempfile_2) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $effects_altered_env1_line_chart_tempfile_2) || die "Can't open file ".$effects_altered_env1_line_chart_tempfile_2;
                        print $F_pheno "germplasmName,time,value\n";
                        foreach my $p (@sorted_germplasm_names) {
                            foreach my $t (@sorted_trait_names_2) {
                                my $val = $result_blup_data_altered_env_1_2->{$p}->{$t}->[0];
                                my @row = ($p, $trait_to_time_map_hash_2->{$t}, $val);
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                                push @sim1_blup_vals_2, $val;
                            }
                        }
                    close($F_pheno);

                    my $sim1_blup_stat_2 = Statistics::Descriptive::Full->new();
                    $sim1_blup_stat_2->add_data(@sim1_blup_vals_2);
                    my $sig_sim1_blup_2 = $sim1_blup_stat_2->variance();

                    my @sim2_blup_vals_2;
                    my ($effects_altered_env2_line_chart_tempfile_fh_2, $effects_altered_env2_line_chart_tempfile_2) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $effects_altered_env2_line_chart_tempfile_2) || die "Can't open file ".$effects_altered_env2_line_chart_tempfile_2;
                        print $F_pheno "germplasmName,time,value\n";
                        foreach my $p (@sorted_germplasm_names) {
                            foreach my $t (@sorted_trait_names_2) {
                                my $val = $result_blup_data_altered_env_2_2->{$p}->{$t}->[0];
                                my @row = ($p, $trait_to_time_map_hash_2->{$t}, $val);
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                                push @sim2_blup_vals_2, $val;
                            }
                        }
                    close($F_pheno);

                    my $sim2_blup_stat_2 = Statistics::Descriptive::Full->new();
                    $sim2_blup_stat_2->add_data(@sim2_blup_vals_2);
                    my $sig_sim2_blup_2 = $sim2_blup_stat_2->variance();

                    my @sim3_blup_vals_2;
                    my ($effects_altered_env3_line_chart_tempfile_fh_2, $effects_altered_env3_line_chart_tempfile_2) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $effects_altered_env3_line_chart_tempfile_2) || die "Can't open file ".$effects_altered_env3_line_chart_tempfile_2;
                        print $F_pheno "germplasmName,time,value\n";
                        foreach my $p (@sorted_germplasm_names) {
                            foreach my $t (@sorted_trait_names_2) {
                                my $val = $result_blup_data_altered_env_3_2->{$p}->{$t}->[0];
                                my @row = ($p, $trait_to_time_map_hash_2->{$t}, $val);
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                                push @sim3_blup_vals_2, $val;
                            }
                        }
                    close($F_pheno);

                    my $sim3_blup_stat_2 = Statistics::Descriptive::Full->new();
                    $sim3_blup_stat_2->add_data(@sim3_blup_vals_2);
                    my $sig_sim3_blup_2 = $sim3_blup_stat_2->variance();

                    my @sim4_blup_vals_2;
                    my ($effects_altered_env4_line_chart_tempfile_fh_2, $effects_altered_env4_line_chart_tempfile_2) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $effects_altered_env4_line_chart_tempfile_2) || die "Can't open file ".$effects_altered_env4_line_chart_tempfile_2;
                        print $F_pheno "germplasmName,time,value\n";
                        foreach my $p (@sorted_germplasm_names) {
                            foreach my $t (@sorted_trait_names_2) {
                                my $val = $result_blup_data_altered_env_4_2->{$p}->{$t}->[0];
                                my @row = ($p, $trait_to_time_map_hash_2->{$t}, $val);
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                                push @sim4_blup_vals_2, $val;
                            }
                        }
                    close($F_pheno);

                    my $sim4_blup_stat_2 = Statistics::Descriptive::Full->new();
                    $sim4_blup_stat_2->add_data(@sim4_blup_vals_2);
                    my $sig_sim4_blup_2 = $sim4_blup_stat_2->variance();

                    my @sim5_blup_vals_2;
                    my ($effects_altered_env5_line_chart_tempfile_fh_2, $effects_altered_env5_line_chart_tempfile_2) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $effects_altered_env5_line_chart_tempfile_2) || die "Can't open file ".$effects_altered_env5_line_chart_tempfile_2;
                        print $F_pheno "germplasmName,time,value\n";
                        foreach my $p (@sorted_germplasm_names) {
                            foreach my $t (@sorted_trait_names_2) {
                                my $val = $result_blup_data_altered_env_5_2->{$p}->{$t}->[0];
                                my @row = ($p, $trait_to_time_map_hash_2->{$t}, $val);
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                                push @sim5_blup_vals_2, $val;
                            }
                        }
                    close($F_pheno);

                    my $sim5_blup_stat_2 = Statistics::Descriptive::Full->new();
                    $sim5_blup_stat_2->add_data(@sim5_blup_vals_2);
                    my $sig_sim5_blup_2 = $sim5_blup_stat_2->variance();

                    my @sim6_blup_vals_2;
                    my ($effects_altered_env6_line_chart_tempfile_fh_2, $effects_altered_env6_line_chart_tempfile_2) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $effects_altered_env6_line_chart_tempfile_2) || die "Can't open file ".$effects_altered_env6_line_chart_tempfile_2;
                        print $F_pheno "germplasmName,time,value\n";
                        foreach my $p (@sorted_germplasm_names) {
                            foreach my $t (@sorted_trait_names_2) {
                                my $val = $result_blup_data_altered_env_6_2->{$p}->{$t}->[0];
                                my @row = ($p, $trait_to_time_map_hash_2->{$t}, $val);
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                                push @sim6_blup_vals_2, $val;
                            }
                        }
                    close($F_pheno);

                    my $sim6_blup_stat_2 = Statistics::Descriptive::Full->new();
                    $sim6_blup_stat_2->add_data(@sim6_blup_vals_2);
                    my $sig_sim6_blup_2 = $sim6_blup_stat_2->variance();

                    my @set = ('0' ..'9', 'A' .. 'F');
                    my @colors;
                    for (1..scalar(@sorted_germplasm_names)) {
                        my $str = join '' => map $set[rand @set], 1 .. 6;
                        push @colors, '#'.$str;
                    }
                    my $color_string = join '\',\'', @colors;

                    my $genetic_effects_figure_tempfile_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $genetic_effects_figure_tempfile_string .= '.png';
                    my $genetic_effects_figure_tempfile = $c->config->{basepath}."/".$genetic_effects_figure_tempfile_string;

                    my $genetic_effects_alt_figure_tempfile_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $genetic_effects_alt_figure_tempfile_string .= '.png';
                    my $genetic_effects_alt_figure_tempfile = $c->config->{basepath}."/".$genetic_effects_alt_figure_tempfile_string;

                    my $genetic_effects_alt_env1_figure_tempfile_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $genetic_effects_alt_env1_figure_tempfile_string .= '.png';
                    my $genetic_effects_alt_env1_figure_tempfile = $c->config->{basepath}."/".$genetic_effects_alt_env1_figure_tempfile_string;

                    my $genetic_effects_alt_env2_figure_tempfile_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $genetic_effects_alt_env2_figure_tempfile_string .= '.png';
                    my $genetic_effects_alt_env2_figure_tempfile = $c->config->{basepath}."/".$genetic_effects_alt_env2_figure_tempfile_string;

                    my $genetic_effects_alt_env3_figure_tempfile_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $genetic_effects_alt_env3_figure_tempfile_string .= '.png';
                    my $genetic_effects_alt_env3_figure_tempfile = $c->config->{basepath}."/".$genetic_effects_alt_env3_figure_tempfile_string;

                    my $genetic_effects_alt_env4_figure_tempfile_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $genetic_effects_alt_env4_figure_tempfile_string .= '.png';
                    my $genetic_effects_alt_env4_figure_tempfile = $c->config->{basepath}."/".$genetic_effects_alt_env4_figure_tempfile_string;

                    my $genetic_effects_alt_env5_figure_tempfile_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $genetic_effects_alt_env5_figure_tempfile_string .= '.png';
                    my $genetic_effects_alt_env5_figure_tempfile = $c->config->{basepath}."/".$genetic_effects_alt_env5_figure_tempfile_string;

                    my $genetic_effects_alt_env6_figure_tempfile_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $genetic_effects_alt_env6_figure_tempfile_string .= '.png';
                    my $genetic_effects_alt_env6_figure_tempfile = $c->config->{basepath}."/".$genetic_effects_alt_env6_figure_tempfile_string;

                    my $cmd_gen_plot = 'R -e "library(data.table); library(ggplot2); library(GGally); library(gridExtra);
                    mat <- fread(\''.$effects_original_line_chart_tempfile_2.'\', header=TRUE, sep=\',\');
                    mat\$time <- as.numeric(as.character(mat\$time));
                    options(device=\'png\');
                    par();
                    sp <- ggplot(mat, aes(x = time, y = value)) +
                        geom_line(aes(color = germplasmName), size = 1) +
                        scale_fill_manual(values = c(\''.$color_string.'\')) +
                        theme_minimal();
                    sp <- sp + guides(shape = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + guides(color = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + theme(legend.title = element_text(size = 3), legend.text = element_text(size = 3));
                    sp <- sp + labs(title = \'Original Genetic Effects\');';
                    if (scalar(@sorted_germplasm_names) > 100) {
                        $cmd_gen_plot .= 'sp <- sp + theme(legend.position = \'none\');';
                    }
                    $cmd_gen_plot .= 'ggsave(\''.$genetic_effects_figure_tempfile.'\', sp, device=\'png\', width=12, height=6, units=\'in\');
                    "';
                    print STDERR Dumper $cmd_gen_plot;
                    my $status_gen_plot = system($cmd_gen_plot);
                    push @$spatial_effects_plots, [$genetic_effects_figure_tempfile_string, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_efforigline_"."envvar_".$env_variance_percent."_".$iterations];

                    my $cmd_gen_alt_plot = 'R -e "library(data.table); library(ggplot2); library(GGally); library(gridExtra);
                    mat <- fread(\''.$effects_altered_line_chart_tempfile_2.'\', header=TRUE, sep=\',\');
                    mat\$time <- as.numeric(as.character(mat\$time));
                    options(device=\'png\');
                    par();
                    sp <- ggplot(mat, aes(x = time, y = value)) +
                        geom_line(aes(color = germplasmName), size = 1) +
                        scale_fill_manual(values = c(\''.$color_string.'\')) +
                        theme_minimal();
                    sp <- sp + guides(shape = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + guides(color = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + theme(legend.title = element_text(size = 3), legend.text = element_text(size = 3));
                    sp <- sp + labs(title = \'Altered Genetic Effects\');';
                    if (scalar(@sorted_germplasm_names) > 100) {
                        $cmd_gen_alt_plot .= 'sp <- sp + theme(legend.position = \'none\');';
                    }
                    $cmd_gen_alt_plot .= 'ggsave(\''.$genetic_effects_alt_figure_tempfile.'\', sp, device=\'png\', width=12, height=6, units=\'in\');
                    "';
                    print STDERR Dumper $cmd_gen_alt_plot;
                    my $status_gen_alt_plot = system($cmd_gen_alt_plot);
                    push @$spatial_effects_plots, [$genetic_effects_alt_figure_tempfile_string, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_effaltline_"."envvar_".$env_variance_percent."_".$iterations];

                    my $cmd_gen_env1_plot = 'R -e "library(data.table); library(ggplot2); library(GGally); library(gridExtra);
                    mat <- fread(\''.$effects_altered_env1_line_chart_tempfile_2.'\', header=TRUE, sep=\',\');
                    mat\$time <- as.numeric(as.character(mat\$time));
                    options(device=\'png\');
                    par();
                    sp <- ggplot(mat, aes(x = time, y = value)) +
                        geom_line(aes(color = germplasmName), size = 1) +
                        scale_fill_manual(values = c(\''.$color_string.'\')) +
                        theme_minimal();
                    sp <- sp + guides(shape = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + guides(color = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + theme(legend.title = element_text(size = 3), legend.text = element_text(size = 3));
                    sp <- sp + labs(title = \'SimLinear Genetic Effects\');';
                    if (scalar(@sorted_germplasm_names) > 100) {
                        $cmd_gen_env1_plot .= 'sp <- sp + theme(legend.position = \'none\');';
                    }
                    $cmd_gen_env1_plot .= 'ggsave(\''.$genetic_effects_alt_env1_figure_tempfile.'\', sp, device=\'png\', width=12, height=6, units=\'in\');
                    "';
                    print STDERR Dumper $cmd_gen_env1_plot;
                    my $status_gen_env1_plot = system($cmd_gen_env1_plot);
                    push @$spatial_effects_plots, [$genetic_effects_alt_env1_figure_tempfile_string, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_effaltenv1line_"."envvar_".$env_variance_percent."_".$iterations];

                    my $cmd_gen_env2_plot = 'R -e "library(data.table); library(ggplot2); library(GGally); library(gridExtra);
                    mat <- fread(\''.$effects_altered_env2_line_chart_tempfile_2.'\', header=TRUE, sep=\',\');
                    mat\$time <- as.numeric(as.character(mat\$time));
                    options(device=\'png\');
                    par();
                    sp <- ggplot(mat, aes(x = time, y = value)) +
                        geom_line(aes(color = germplasmName), size = 1) +
                        scale_fill_manual(values = c(\''.$color_string.'\')) +
                        theme_minimal();
                    sp <- sp + guides(shape = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + guides(color = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + theme(legend.title = element_text(size = 3), legend.text = element_text(size = 3));
                    sp <- sp + labs(title = \'Sim1DN Genetic Effects\');';
                    if (scalar(@sorted_germplasm_names) > 100) {
                        $cmd_gen_env2_plot .= 'sp <- sp + theme(legend.position = \'none\');';
                    }
                    $cmd_gen_env2_plot .= 'ggsave(\''.$genetic_effects_alt_env2_figure_tempfile.'\', sp, device=\'png\', width=12, height=6, units=\'in\');
                    "';
                    print STDERR Dumper $cmd_gen_env2_plot;
                    my $status_gen_env2_plot = system($cmd_gen_env2_plot);
                    push @$spatial_effects_plots, [$genetic_effects_alt_env2_figure_tempfile_string, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_effaltenv2line_"."envvar_".$env_variance_percent."_".$iterations];

                    my $cmd_gen_env3_plot = 'R -e "library(data.table); library(ggplot2); library(GGally); library(gridExtra);
                    mat <- fread(\''.$effects_altered_env3_line_chart_tempfile_2.'\', header=TRUE, sep=\',\');
                    mat\$time <- as.numeric(as.character(mat\$time));
                    options(device=\'png\');
                    par();
                    sp <- ggplot(mat, aes(x = time, y = value)) +
                        geom_line(aes(color = germplasmName), size = 1) +
                        scale_fill_manual(values = c(\''.$color_string.'\')) +
                        theme_minimal();
                    sp <- sp + guides(shape = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + guides(color = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + theme(legend.title = element_text(size = 3), legend.text = element_text(size = 3));
                    sp <- sp + labs(title = \'Sim2DN Genetic Effects\');';
                    if (scalar(@sorted_germplasm_names) > 100) {
                        $cmd_gen_env3_plot .= 'sp <- sp + theme(legend.position = \'none\');';
                    }
                    $cmd_gen_env3_plot .= 'ggsave(\''.$genetic_effects_alt_env3_figure_tempfile.'\', sp, device=\'png\', width=12, height=6, units=\'in\');
                    "';
                    print STDERR Dumper $cmd_gen_env3_plot;
                    my $status_gen_env3_plot = system($cmd_gen_env3_plot);
                    push @$spatial_effects_plots, [$genetic_effects_alt_env3_figure_tempfile_string, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_effaltenv3line_"."envvar_".$env_variance_percent."_".$iterations];

                    my $cmd_gen_env4_plot = 'R -e "library(data.table); library(ggplot2); library(GGally); library(gridExtra);
                    mat <- fread(\''.$effects_altered_env4_line_chart_tempfile_2.'\', header=TRUE, sep=\',\');
                    mat\$time <- as.numeric(as.character(mat\$time));
                    options(device=\'png\');
                    par();
                    sp <- ggplot(mat, aes(x = time, y = value)) +
                        geom_line(aes(color = germplasmName), size = 1) +
                        scale_fill_manual(values = c(\''.$color_string.'\')) +
                        theme_minimal();
                    sp <- sp + guides(shape = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + guides(color = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + theme(legend.title = element_text(size = 3), legend.text = element_text(size = 3));
                    sp <- sp + labs(title = \'SimRandom Genetic Effects\');';
                    if (scalar(@sorted_germplasm_names) > 100) {
                        $cmd_gen_env4_plot .= 'sp <- sp + theme(legend.position = \'none\');';
                    }
                    $cmd_gen_env4_plot .= 'ggsave(\''.$genetic_effects_alt_env4_figure_tempfile.'\', sp, device=\'png\', width=12, height=6, units=\'in\');
                    "';
                    print STDERR Dumper $cmd_gen_env4_plot;
                    my $status_gen_env4_plot = system($cmd_gen_env4_plot);
                    push @$spatial_effects_plots, [$genetic_effects_alt_env4_figure_tempfile_string, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_effaltenv4line_"."envvar_".$env_variance_percent."_".$iterations];

                    my $cmd_gen_env5_plot = 'R -e "library(data.table); library(ggplot2); library(GGally); library(gridExtra);
                    mat <- fread(\''.$effects_altered_env5_line_chart_tempfile_2.'\', header=TRUE, sep=\',\');
                    mat\$time <- as.numeric(as.character(mat\$time));
                    options(device=\'png\');
                    par();
                    sp <- ggplot(mat, aes(x = time, y = value)) +
                        geom_line(aes(color = germplasmName), size = 1) +
                        scale_fill_manual(values = c(\''.$color_string.'\')) +
                        theme_minimal();
                    sp <- sp + guides(shape = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + guides(color = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + theme(legend.title = element_text(size = 3), legend.text = element_text(size = 3));
                    sp <- sp + labs(title = \'SimRandom Genetic Effects\');';
                    if (scalar(@sorted_germplasm_names) > 100) {
                        $cmd_gen_env5_plot .= 'sp <- sp + theme(legend.position = \'none\');';
                    }
                    $cmd_gen_env5_plot .= 'ggsave(\''.$genetic_effects_alt_env5_figure_tempfile.'\', sp, device=\'png\', width=12, height=6, units=\'in\');
                    "';
                    print STDERR Dumper $cmd_gen_env5_plot;
                    my $status_gen_env5_plot = system($cmd_gen_env5_plot);
                    push @$spatial_effects_plots, [$genetic_effects_alt_env5_figure_tempfile_string, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_effaltenv5line_"."envvar_".$env_variance_percent."_".$iterations];

                    my $cmd_gen_env6_plot = 'R -e "library(data.table); library(ggplot2); library(GGally); library(gridExtra);
                    mat <- fread(\''.$effects_altered_env6_line_chart_tempfile_2.'\', header=TRUE, sep=\',\');
                    mat\$time <- as.numeric(as.character(mat\$time));
                    options(device=\'png\');
                    par();
                    sp <- ggplot(mat, aes(x = time, y = value)) +
                        geom_line(aes(color = germplasmName), size = 1) +
                        scale_fill_manual(values = c(\''.$color_string.'\')) +
                        theme_minimal();
                    sp <- sp + guides(shape = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + guides(color = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + theme(legend.title = element_text(size = 3), legend.text = element_text(size = 3));
                    sp <- sp + labs(title = \'SimRandom Genetic Effects\');';
                    if (scalar(@sorted_germplasm_names) > 100) {
                        $cmd_gen_env6_plot .= 'sp <- sp + theme(legend.position = \'none\');';
                    }
                    $cmd_gen_env6_plot .= 'ggsave(\''.$genetic_effects_alt_env6_figure_tempfile.'\', sp, device=\'png\', width=12, height=6, units=\'in\');
                    "';
                    print STDERR Dumper $cmd_gen_env6_plot;
                    my $status_gen_env6_plot = system($cmd_gen_env6_plot);
                    push @$spatial_effects_plots, [$genetic_effects_alt_env6_figure_tempfile_string, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_effaltenv6line_"."envvar_".$env_variance_percent."_".$iterations];
                };

                %trait_name_encoder = %trait_name_encoder_2;
                %trait_to_time_map = %trait_to_time_map_2;

                push @$env_varcomps, {
                    type => "$statistics_select: Env Variance $env_variance_percent : SimCorrelation: $correlation_between_times : Iteration $iterations",
                    statistics_select => "$statistics_select: Env Variance $env_variance_percent : SimCorrelation: $correlation_between_times",
                    correlation_between_times => $correlation_between_times,
                    env_variance => $env_variance_percent,
                    original => {
                        covariance => $varcomp_original_array_2,
                        cv_1 => $result_cv_original_2,
                        cv_2 => $result_cv_2_original_2
                    },
                    altered => {
                        covariance => $varcomp_altered_array_2,
                        cv_1 => $result_cv_altered_2,
                        cv_2 => $result_cv_2_altered_2
                    },
                    env_linear => {
                        covariance => $varcomp_altered_array_env_1_2,
                        cv_1 => $result_cv_altered_env_1_2,
                        cv_2 => $result_cv_2_altered_env_1_2
                    },
                    env_1DN  => {
                        covariance => $varcomp_altered_array_env_2_2,
                        cv_1 => $result_cv_altered_env_2_2,
                        cv_2 => $result_cv_2_altered_env_2_2
                    },
                    env_2DN  => {
                        covariance => $varcomp_altered_array_env_3_2,
                        cv_1 => $result_cv_altered_env_3_2,
                        cv_2 => $result_cv_2_altered_env_3_2
                    },
                    env_random  => {
                        covariance => $varcomp_altered_array_env_4_2,
                        cv_1 => $result_cv_altered_env_4_2,
                        cv_2 => $result_cv_2_altered_env_4_2
                    },
                    env_ar1xar1  => {
                        covariance => $varcomp_altered_array_env_5_2,
                        cv_1 => $result_cv_altered_env_5_2,
                        cv_2 => $result_cv_2_altered_env_5_2
                    },
                    env_realdata  => {
                        covariance => $varcomp_altered_array_env_6_2,
                        cv_1 => $result_cv_altered_env_6_2,
                        cv_2 => $result_cv_2_altered_env_6_2
                    }
                };
            }

            if ($statistics_select_original eq 'sommer_grm_univariate_spatial_genetic_blups' || $statistics_select_original eq 'sommer_grm_univariate_spatial_pure_2dspl_genetic_blups') {
                $statistics_select = $statistics_select_original eq 'sommer_grm_univariate_spatial_genetic_blups' ? 'sommer_grm_univariate_spatial_genetic_blups' : 'sommer_grm_univariate_spatial_pure_2dspl_genetic_blups';

                print STDERR "PREPARE ORIGINAL PHENOTYPE FILES 2\n";
                eval {
                    my $phenotypes_search_2 = CXGN::Phenotypes::SearchFactory->instantiate(
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
                    my ($data_2, $unique_traits_2) = $phenotypes_search_2->search();
                    @sorted_trait_names_2 = sort keys %$unique_traits_2;

                    if (scalar(@$data_2) == 0) {
                        $c->stash->{rest} = { error => "There are no phenotypes for the trials and traits you have selected!"};
                        return;
                    }

                    foreach my $obs_unit (@$data_2){
                        my $germplasm_name = $obs_unit->{germplasm_uniquename};
                        my $germplasm_stock_id = $obs_unit->{germplasm_stock_id};
                        my $replicate_number = $obs_unit->{obsunit_rep} || '';
                        my $block_number = $obs_unit->{obsunit_block} || '';
                        my $obsunit_stock_id = $obs_unit->{observationunit_stock_id};
                        my $obsunit_stock_uniquename = $obs_unit->{observationunit_uniquename};
                        my $row_number = $obs_unit->{obsunit_row_number} || '';
                        my $col_number = $obs_unit->{obsunit_col_number} || '';
                        $seen_trial_ids_2{$obs_unit->{trial_id}}++;
                        push @plot_ids_ordered, $obsunit_stock_id;

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

                        $obsunit_row_col{$row_number}->{$col_number} = {
                            stock_id => $obsunit_stock_id,
                            stock_uniquename => $obsunit_stock_uniquename
                        };
                        $seen_rows{$row_number}++;
                        $seen_cols{$col_number}++;
                        $plot_id_map{$obsunit_stock_id} = $obsunit_stock_uniquename;
                        $seen_plot_names{$obsunit_stock_uniquename}++;
                        $seen_plots{$obsunit_stock_id} = $obsunit_stock_uniquename;
                        $stock_row_col{$obsunit_stock_id} = {
                            row_number => $row_number,
                            col_number => $col_number,
                            obsunit_stock_id => $obsunit_stock_id,
                            obsunit_name => $obsunit_stock_uniquename,
                            rep => $replicate_number,
                            block => $block_number,
                            germplasm_stock_id => $germplasm_stock_id,
                            germplasm_name => $germplasm_name
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
                        $stock_row_col_id{$row_number}->{$col_number} = $obsunit_stock_id;
                        $unique_accessions{$germplasm_name}++;
                        $stock_info_2{"S".$germplasm_stock_id} = {
                            uniquename => $germplasm_name
                        };
                        my $observations = $obs_unit->{observations};
                        foreach (@$observations){
                            my $value = $_->{value};
                            my $trait_name = $_->{trait_name};
                            $phenotype_data_original_2{$obsunit_stock_uniquename}->{$trait_name} = $value;
                            $seen_trait_names_2{$trait_name}++;

                            if ($value < $phenotype_min_original_2) {
                                $phenotype_min_original_2 = $value;
                            }
                            elsif ($value >= $phenotype_max_original_2) {
                                $phenotype_max_original_2 = $value;
                            }

                            if ($_->{associated_image_project_time_json}) {
                                my $related_time_terms_json = decode_json $_->{associated_image_project_time_json};
                                my $time_days_cvterm = $related_time_terms_json->{day};
                                my $time_term_string = $time_days_cvterm;
                                my $time_days = (split '\|', $time_days_cvterm)[0];
                                my $time_value = (split ' ', $time_days)[1];
                                $seen_days_after_plantings_2{$time_value}++;
                                $trait_to_time_map_2{$trait_name} = $time_value;
                            }
                        }
                    }

                    @unique_plot_names = sort keys %seen_plot_names;

                    my $trait_name_encoded_2 = 1;
                    foreach my $trait_name (@sorted_trait_names_2) {
                        if (!exists($trait_name_encoder_2{$trait_name})) {
                            my $trait_name_e = 't'.$trait_name_encoded_2;
                            $trait_name_encoder_2{$trait_name} = $trait_name_e;
                            $trait_name_encoder_rev_2{$trait_name_e} = $trait_name;
                            $trait_name_encoded_2++;
                        }
                    }

                    foreach my $p (@unique_plot_names) {
                        my $obsunit_stock_id = $stock_name_row_col{$p}->{obsunit_stock_id};
                        if ($fixed_effect_type eq 'fixed_effect_trait') {
                            $stock_name_row_col{$p}->{rep} = defined($fixed_effect_trait_data->{$obsunit_stock_id}) ? $fixed_effect_trait_data->{$obsunit_stock_id} : 0;
                        }
                        my $row_number = $stock_name_row_col{$p}->{row_number};
                        my $col_number = $stock_name_row_col{$p}->{col_number};
                        my $replicate = $stock_name_row_col{$p}->{rep};
                        my $block = $stock_name_row_col{$p}->{block};
                        my $germplasm_stock_id = $stock_name_row_col{$p}->{germplasm_stock_id};
                        my $germplasm_name = $stock_name_row_col{$p}->{germplasm_name};

                        my @row = ($replicate, $block, "S".$germplasm_stock_id, $obsunit_stock_id, $row_number, $col_number, $row_number, $col_number);

                        foreach my $t (@sorted_trait_names_2) {
                            if (defined($phenotype_data_original_2{$p}->{$t})) {
                                push @row, $phenotype_data_original_2{$p}->{$t};
                            } else {
                                print STDERR $p." : $t : $germplasm_name : NA \n";
                                push @row, 'NA';
                            }
                        }
                        push @data_matrix_original_2, \@row;
                    }

                    foreach (keys %seen_trial_ids_2){
                        my $trial = CXGN::Trial->new({bcs_schema=>$schema, trial_id=>$_});
                        my $traits_assayed = $trial->get_traits_assayed('plot', undef, 'time_ontology');
                        foreach (@$traits_assayed) {
                            $unique_traits_ids_2{$_->[0]} = $_;
                        }
                    }
                    foreach (values %unique_traits_ids_2) {
                        foreach my $component (@{$_->[2]}) {
                            if (exists($seen_trait_names_2{$_->[1]}) && $component->{cv_type} && $component->{cv_type} eq 'time_ontology') {
                                my $time_term_string = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $component->{cvterm_id}, 'extended');
                                push @{$trait_composing_info_2{$_->[1]}}, $time_term_string;
                            }
                        }
                    }

                    @phenotype_header_2 = ("replicate", "block", "id", "plot_id", "rowNumber", "colNumber", "rowNumberFactor", "colNumberFactor");
                    foreach (@sorted_trait_names_2) {
                        push @phenotype_header_2, $trait_name_encoder_2{$_};
                    }
                    $header_string_2 = join ',', @phenotype_header_2;

                    open($F, ">", $stats_tempfile) || die "Can't open file ".$stats_tempfile;
                        print $F $header_string_2."\n";
                        foreach (@data_matrix_original_2) {
                            my $line = join ',', @$_;
                            print $F "$line\n";
                        }
                    close($F);

                    print STDERR Dumper [$phenotype_min_original_2, $phenotype_max_original_2];
                };

                @seen_rows_array = keys %seen_rows;
                @seen_cols_array = keys %seen_cols;
                $row_stat = Statistics::Descriptive::Full->new();
                $row_stat->add_data(@seen_rows_array);
                $mean_row = $row_stat->mean();
                $sig_row = $row_stat->variance();
                $col_stat = Statistics::Descriptive::Full->new();
                $col_stat->add_data(@seen_cols_array);
                $mean_col = $col_stat->mean();
                $sig_col = $col_stat->variance();

                print STDERR "PREPARE RELATIONSHIP MATRIX\n";
                eval {
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
                            my $status = system($cmd);

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
                            my $status = system($cmd);

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
                            my $status = system($htp_cmd);
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
                            my $status = system($htp_cmd);
                        }
                        else {
                            $c->stash->{rest} = { error => "The value of $compute_relationship_matrix_from_htp_phenotypes_type htp_pheno_rel_matrix_type is not valid!" };
                            return;
                        }

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
                };

                my $result_3 = CXGN::DroneImagery::DroneImageryAnalyticsRunSimulation::perform_drone_imagery_analytics($schema, $a_env, $b_env, $ro_env, $row_ro_env, $env_variance_percent, $protocol_id, $statistics_select, $analytics_select, $tolparinv, $use_area_under_curve, $legendre_order_number, $permanent_environment_structure, \@legendre_coeff_exec, \%trait_name_encoder_2, \%trait_name_encoder_rev_2, \%stock_info_2, \%plot_id_map, \@sorted_trait_names_2, \%accession_id_factor_map, \@rep_time_factors, \@ind_rep_factors, \@unique_accession_names, \%plot_id_count_map_reverse, \@sorted_scaled_ln_times, \%time_count_map_reverse, \%accession_id_factor_map_reverse, \%seen_times, \%plot_id_factor_map_reverse, \%trait_to_time_map_2, \@unique_plot_names, \%stock_name_row_col, \%phenotype_data_original_2, \%plot_rep_time_factor_map, \%stock_row_col, \%stock_row_col_id, \%polynomial_map, \@plot_ids_ordered, $csv, $timestamp, $user_name, $stats_tempfile, $grm_file, $grm_rename_tempfile, $tmp_stats_dir, $stats_out_tempfile, $stats_out_tempfile_row, $stats_out_tempfile_col, $stats_out_tempfile_residual, $stats_out_tempfile_2dspl, $stats_prep2_tempfile, $stats_out_param_tempfile, $parameter_tempfile, $parameter_asreml_tempfile, $stats_tempfile_2, $permanent_environment_structure_tempfile, $permanent_environment_structure_env_tempfile, $permanent_environment_structure_env_tempfile2, $permanent_environment_structure_env_tempfile_mat, $sim_env_changing_mat_tempfile, $sim_env_changing_mat_full_tempfile, $yhat_residual_tempfile, $blupf90_solutions_tempfile, $coeff_genetic_tempfile, $coeff_pe_tempfile, $stats_out_tempfile_varcomp, $time_min, $time_max, $header_string_2, $env_sim_exec, $min_row, $max_row, $min_col, $max_col, $mean_row, $sig_row, $mean_col, $sig_col, $sim_env_change_over_time, $correlation_between_times, $field_trial_id_list, $simulated_environment_real_data_trait_id, $fixed_effect_type, $perform_cv);
                if (ref($result_3) eq 'HASH') {
                    $c->stash->{rest} = $result_3;
                    $c->detach();
                }
                my ($statistical_ontology_term_3, $analysis_model_training_data_file_type_3, $analysis_model_language_3, $sorted_residual_trait_names_array_3, $rr_unique_traits_hash_3, $rr_residual_unique_traits_hash_3, $statistics_cmd_3, $cmd_f90_3, $number_traits_3, $trait_to_time_map_hash_3,

                $result_blup_data_original_3, $result_blup_data_delta_original_3, $result_blup_spatial_data_original_3, $result_blup_pe_data_original_3, $result_blup_pe_data_delta_original_3, $result_residual_data_original_3, $result_fitted_data_original_3, $fixed_effects_original_hash_3,
                $rr_genetic_coefficients_original_hash_3, $rr_temporal_coefficients_original_hash_3,
                $rr_coeff_genetic_covariance_original_array_3, $rr_coeff_env_covariance_original_array_3, $rr_coeff_genetic_correlation_original_array_3, $rr_coeff_env_correlation_original_array_3, $rr_residual_variance_original_3, $varcomp_original_array_3,
                $model_sum_square_residual_original_3, $genetic_effect_min_original_3, $genetic_effect_max_original_3, $env_effect_min_original_3, $env_effect_max_original_3, $genetic_effect_sum_square_original_3, $genetic_effect_sum_original_3, $env_effect_sum_square_original_3, $env_effect_sum_original_3, $residual_sum_square_original_3, $residual_sum_original_3, $result_cv_original_3, $result_cv_2_original_3,

                $phenotype_data_altered_hash_3, $data_matrix_altered_array_3, $data_matrix_phenotypes_altered_array_3, $phenotype_min_altered_3, $phenotype_max_altered_3,
                $result_blup_data_altered_3, $result_blup_data_delta_altered_3, $result_blup_spatial_data_altered_3, $result_blup_pe_data_altered_3, $result_blup_pe_data_delta_altered_3, $result_residual_data_altered_3, $result_fitted_data_altered_3, $fixed_effects_altered_hash_3,
                $rr_genetic_coefficients_altered_hash_3, $rr_temporal_coefficients_altered_hash_3,
                $rr_coeff_genetic_covariance_altered_array_3, $rr_coeff_env_covariance_altered_array_3, $rr_coeff_genetic_correlation_altered_array_3, $rr_coeff_env_correlation_altered_array_3, $rr_residual_variance_altered_3, $varcomp_altered_array_3,
                $model_sum_square_residual_altered_3, $genetic_effect_min_altered_3, $genetic_effect_max_altered_3, $env_effect_min_altered_3, $env_effect_max_altered_3, $genetic_effect_sum_square_altered_3, $genetic_effect_sum_altered_3, $env_effect_sum_square_altered_3, $env_effect_sum_altered_3, $residual_sum_square_altered_3, $residual_sum_altered_3, $result_cv_altered_3, $result_cv_2_altered_3,

                $phenotype_data_altered_env_hash_1_3, $data_matrix_altered_env_array_1_3, $data_matrix_phenotypes_altered_env_array_1_3, $phenotype_min_altered_env_1_3, $phenotype_max_altered_env_1_3, $env_sim_min_1_3, $env_sim_max_1_3, $sim_data_hash_1_3,
                $result_blup_data_altered_env_1_3, $result_blup_data_delta_altered_env_1_3, $result_blup_spatial_data_altered_env_1_3, $result_blup_pe_data_altered_env_1_3, $result_blup_pe_data_delta_altered_env_1_3, $result_residual_data_altered_env_1_3, $result_fitted_data_altered_env_1_3, $fixed_effects_altered_env_hash_1_3, $rr_genetic_coefficients_altered_env_hash_1_3, $rr_temporal_coefficients_altered_env_hash_1_3,
                $rr_coeff_genetic_covariance_altered_env_array_1_3, $rr_coeff_env_covariance_altered_env_array_1_3, $rr_coeff_genetic_correlation_altered_env_array_1_3, $rr_coeff_env_correlation_altered_env_array_1_3, $rr_residual_variance_altered_env_1_3, $varcomp_altered_array_env_1_3,
                $model_sum_square_residual_altered_env_1_3, $genetic_effect_min_altered_env_1_3, $genetic_effect_max_altered_env_1_3, $env_effect_min_altered_env_1_3, $env_effect_max_altered_env_1_3, $genetic_effect_sum_square_altered_env_1_3, $genetic_effect_sum_altered_env_1_3, $env_effect_sum_square_altered_env_1_3, $env_effect_sum_altered_env_1_3, $residual_sum_square_altered_env_1_3, $residual_sum_altered_env_1_3, $result_cv_altered_env_1_3, $result_cv_2_altered_env_1_3,

                $phenotype_data_altered_env_hash_2_3, $data_matrix_altered_env_array_2_3, $data_matrix_phenotypes_altered_env_array_2_3, $phenotype_min_altered_env_2_3, $phenotype_max_altered_env_2_3, $env_sim_min_2_3, $env_sim_max_2_3, $sim_data_hash_2_3,
                $result_blup_data_altered_env_2_3, $result_blup_data_delta_altered_env_2_3, $result_blup_spatial_data_altered_env_2_3, $result_blup_pe_data_altered_env_2_3, $result_blup_pe_data_delta_altered_env_2_3, $result_residual_data_altered_env_2_3, $result_fitted_data_altered_env_2_3, $fixed_effects_altered_env_hash_2_3, $rr_genetic_coefficients_altered_env_hash_2_3, $rr_temporal_coefficients_altered_env_hash_2_3,
                $rr_coeff_genetic_covariance_altered_env_array_2_3, $rr_coeff_env_covariance_altered_env_array_2_3, $rr_coeff_genetic_correlation_altered_env_array_2_3, $rr_coeff_env_correlation_altered_env_array_2_3, $rr_residual_variance_altered_env_2_3, $varcomp_altered_array_env_2_3,
                $model_sum_square_residual_altered_env_2_3, $genetic_effect_min_altered_env_2_3, $genetic_effect_max_altered_env_2_3, $env_effect_min_altered_env_2_3, $env_effect_max_altered_env_2_3, $genetic_effect_sum_square_altered_env_2_3, $genetic_effect_sum_altered_env_2_3, $env_effect_sum_square_altered_env_2_3, $env_effect_sum_altered_env_2_3, $residual_sum_square_altered_env_2_3, $residual_sum_altered_env_2_3, $result_cv_altered_env_2_3, $result_cv_2_altered_env_2_3,

                $phenotype_data_altered_env_hash_3_3, $data_matrix_altered_env_array_3_3, $data_matrix_phenotypes_altered_env_array_3_3, $phenotype_min_altered_env_3_3, $phenotype_max_altered_env_3_3, $env_sim_min_3_3, $env_sim_max_3_3, $sim_data_hash_3_3,
                $result_blup_data_altered_env_3_3, $result_blup_data_delta_altered_env_3_3, $result_blup_spatial_data_altered_env_3_3, $result_blup_pe_data_altered_env_3_3, $result_blup_pe_data_delta_altered_env_3_3, $result_residual_data_altered_env_3_3, $result_fitted_data_altered_env_3_3, $fixed_effects_altered_env_hash_3_3, $rr_genetic_coefficients_altered_env_hash_3_3, $rr_temporal_coefficients_altered_env_hash_3_3,
                $rr_coeff_genetic_covariance_altered_env_array_3_3, $rr_coeff_env_covariance_altered_env_array_3_3, $rr_coeff_genetic_correlation_altered_env_array_3_3, $rr_coeff_env_correlation_altered_env_array_3_3, $rr_residual_variance_altered_env_3_3, $varcomp_altered_array_env_3_3,
                $model_sum_square_residual_altered_env_3_3, $genetic_effect_min_altered_env_3_3, $genetic_effect_max_altered_env_3_3, $env_effect_min_altered_env_3_3, $env_effect_max_altered_env_3_3, $genetic_effect_sum_square_altered_env_3_3, $genetic_effect_sum_altered_env_3_3, $env_effect_sum_square_altered_env_3_3, $env_effect_sum_altered_env_3_3, $residual_sum_square_altered_env_3_3, $residual_sum_altered_env_3_3, $result_cv_altered_env_3_3, $result_cv_2_altered_env_3_3,

                $phenotype_data_altered_env_hash_4_3, $data_matrix_altered_env_array_4_3, $data_matrix_phenotypes_altered_env_array_4_3, $phenotype_min_altered_env_4_3, $phenotype_max_altered_env_4_3, $env_sim_min_4_3, $env_sim_max_4_3, $sim_data_hash_4_3,
                $result_blup_data_altered_env_4_3, $result_blup_data_delta_altered_env_4_3, $result_blup_spatial_data_altered_env_4_3, $result_blup_pe_data_altered_env_4_3, $result_blup_pe_data_delta_altered_env_4_3, $result_residual_data_altered_env_4_3, $result_fitted_data_altered_env_4_3, $fixed_effects_altered_env_hash_4_3, $rr_genetic_coefficients_altered_env_hash_4_3, $rr_temporal_coefficients_altered_env_hash_4_3,
                $rr_coeff_genetic_covariance_altered_env_array_4_3, $rr_coeff_env_covariance_altered_env_array_4_3, $rr_coeff_genetic_correlation_altered_env_array_4_3, $rr_coeff_env_correlation_altered_env_array_4_3, $rr_residual_variance_altered_env_4_3, $varcomp_altered_array_env_4_3,
                $model_sum_square_residual_altered_env_4_3, $genetic_effect_min_altered_env_4_3, $genetic_effect_max_altered_env_4_3, $env_effect_min_altered_env_4_3, $env_effect_max_altered_env_4_3, $genetic_effect_sum_square_altered_env_4_3, $genetic_effect_sum_altered_env_4_3, $env_effect_sum_square_altered_env_4_3, $env_effect_sum_altered_env_4_3, $residual_sum_square_altered_env_4_3, $residual_sum_altered_env_4_3, $result_cv_altered_env_4_3, $result_cv_2_altered_env_4_3,

                $phenotype_data_altered_env_hash_5_3, $data_matrix_altered_env_array_5_3, $data_matrix_phenotypes_altered_env_array_5_3, $phenotype_min_altered_env_5_3, $phenotype_max_altered_env_5_3, $env_sim_min_5_3, $env_sim_max_5_3, $sim_data_hash_5_3,
                $result_blup_data_altered_env_5_3, $result_blup_data_delta_altered_env_5_3, $result_blup_spatial_data_altered_env_5_3, $result_blup_pe_data_altered_env_5_3, $result_blup_pe_data_delta_altered_env_5_3, $result_residual_data_altered_env_5_3, $result_fitted_data_altered_env_5_3, $fixed_effects_altered_env_hash_5_3, $rr_genetic_coefficients_altered_env_hash_5_3, $rr_temporal_coefficients_altered_env_hash_5_3,
                $rr_coeff_genetic_covariance_altered_env_array_5_3, $rr_coeff_env_covariance_altered_env_array_5_3, $rr_coeff_genetic_correlation_altered_env_array_5_3, $rr_coeff_env_correlation_altered_env_array_5_3, $rr_residual_variance_altered_env_5_3, $varcomp_altered_array_env_5_3,
                $model_sum_square_residual_altered_env_5_3, $genetic_effect_min_altered_env_5_3, $genetic_effect_max_altered_env_5_3, $env_effect_min_altered_env_5_3, $env_effect_max_altered_env_5_3, $genetic_effect_sum_square_altered_env_5_3, $genetic_effect_sum_altered_env_5_3, $env_effect_sum_square_altered_env_5_3, $env_effect_sum_altered_env_5_3, $residual_sum_square_altered_env_5_3, $residual_sum_altered_env_5_3, $result_cv_altered_env_5_3, $result_cv_2_altered_env_5_3,

                $phenotype_data_altered_env_hash_6_3, $data_matrix_altered_env_array_6_3, $data_matrix_phenotypes_altered_env_array_6_3, $phenotype_min_altered_env_6_3, $phenotype_max_altered_env_6_3, $env_sim_min_6_3, $env_sim_max_6_3, $sim_data_hash_6_3,
                $result_blup_data_altered_env_6_3, $result_blup_data_delta_altered_env_6_3, $result_blup_spatial_data_altered_env_6_3, $result_blup_pe_data_altered_env_6_3, $result_blup_pe_data_delta_altered_env_6_3, $result_residual_data_altered_env_6_3, $result_fitted_data_altered_env_6_3, $fixed_effects_altered_env_hash_6_3, $rr_genetic_coefficients_altered_env_hash_6_3, $rr_temporal_coefficients_altered_env_hash_6_3,
                $rr_coeff_genetic_covariance_altered_env_array_6_3, $rr_coeff_env_covariance_altered_env_array_6_3, $rr_coeff_genetic_correlation_altered_env_array_6_3, $rr_coeff_env_correlation_altered_env_array_6_3, $rr_residual_variance_altered_env_6_3, $varcomp_altered_array_env_6_3,
                $model_sum_square_residual_altered_env_6_3, $genetic_effect_min_altered_env_6_3, $genetic_effect_max_altered_env_6_3, $env_effect_min_altered_env_6_3, $env_effect_max_altered_env_6_3, $genetic_effect_sum_square_altered_env_6_3, $genetic_effect_sum_altered_env_6_3, $env_effect_sum_square_altered_env_6_3, $env_effect_sum_altered_env_6_3, $residual_sum_square_altered_env_6_3, $residual_sum_altered_env_6_3, $result_cv_altered_env_6_3, $result_cv_2_altered_env_6_3
                ) = @$result_3;

                eval {
                    print STDERR "PLOTTING CORRELATION\n";
                    my ($full_plot_level_correlation_tempfile_fh, $full_plot_level_correlation_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open(my $F_fullplot, ">", $full_plot_level_correlation_tempfile) || die "Can't open file ".$full_plot_level_correlation_tempfile;
                        print STDERR "OPENED PLOTCORR FILE $full_plot_level_correlation_tempfile\n";

                        my @header_full_plot_corr = ('plot_name, plot_id, row_number, col_number, rep, block, germplasm_name, germplasm_id');
                        my @types_full_plot_corr = ('pheno_orig_', 'pheno_postm3_', 'eff_origm3_', 'eff_postm3_',
                        'sim_env1_', 'simm3_pheno1_', 'effm3_sim1_',
                        'sim_env2_', 'simm3_pheno2_', 'effm3_sim2_',
                        'sim_env3_', 'simm3_pheno3_', 'effm3_sim3_',
                        'sim_env4_', 'simm3_pheno4_', 'effm3_sim4_',
                        'sim_env5_', 'simm3_pheno5_', 'effm3_sim5_',
                        'sim_env6_', 'simm3_pheno6_', 'effm3_sim6_');
                        foreach my $t (@sorted_trait_names_2) {
                            foreach my $type (@types_full_plot_corr) {
                                push @header_full_plot_corr, $type.$trait_name_encoder_2{$t};
                            }
                        }
                        my $header_string_full_plot_corr = join ',', @header_full_plot_corr;
                        print $F_fullplot "$header_string_full_plot_corr\n";
                        foreach my $p (@unique_plot_names) {
                            my @row = ($p, $stock_name_row_col{$p}->{obsunit_stock_id}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $stock_name_row_col{$p}->{rep}, $stock_name_row_col{$p}->{block}, $stock_name_row_col{$p}->{germplasm_name}, $stock_name_row_col{$p}->{germplasm_stock_id});
                            foreach my $t (@sorted_trait_names_2) {
                                my $t_conv = $t;

                                my $phenotype_original = $phenotype_data_original_2{$p}->{$t};
                                my $phenotype_post_3 = $phenotype_data_altered_hash_3->{$p}->{$t_conv};
                                my $effect_original_3 = $result_blup_spatial_data_original_3->{$p}->{$t_conv}->[0];
                                my $effect_post_3 = $result_blup_spatial_data_altered_3->{$p}->{$t_conv}->[0] || 'NA';
                                push @row, ($phenotype_original, $phenotype_post_3, $effect_original_3, $effect_post_3);

                                my $sim_env = $sim_data_hash_1_3->{$p}->{$t};
                                my $pheno_sim_3 = $phenotype_data_altered_env_hash_1_3->{$p}->{$t_conv};
                                my $effect_sim_3 = $result_blup_spatial_data_altered_env_1_3->{$p}->{$t_conv}->[0];
                                push @row, ($sim_env, $pheno_sim_3, $effect_sim_3);

                                my $sim_env2 = $sim_data_hash_2_3->{$p}->{$t};
                                my $pheno_sim2_3 = $phenotype_data_altered_env_hash_2_3->{$p}->{$t_conv};
                                my $effect_sim2_3 = $result_blup_spatial_data_altered_env_2_3->{$p}->{$t_conv}->[0];
                                push @row, ($sim_env2, $pheno_sim2_3, $effect_sim2_3);

                                my $sim_env3 = $sim_data_hash_3_3->{$p}->{$t};
                                my $pheno_sim3_3 = $phenotype_data_altered_env_hash_3_3->{$p}->{$t_conv};
                                my $effect_sim3_3 = $result_blup_spatial_data_altered_env_3_3->{$p}->{$t_conv}->[0];
                                push @row, ($sim_env3, $pheno_sim3_3, $effect_sim3_3);

                                my $sim_env4 = $sim_data_hash_4_3->{$p}->{$t};
                                my $pheno_sim4_3 = $phenotype_data_altered_env_hash_4_3->{$p}->{$t_conv};
                                my $effect_sim4_3 = $result_blup_spatial_data_altered_env_4_3->{$p}->{$t_conv}->[0];
                                push @row, ($sim_env4, $pheno_sim4_3, $effect_sim4_3);

                                my $sim_env5 = $sim_data_hash_5_3->{$p}->{$t};
                                my $pheno_sim5_3 = $phenotype_data_altered_env_hash_5_3->{$p}->{$t_conv};
                                my $effect_sim5_3 = $result_blup_spatial_data_altered_env_5_3->{$p}->{$t_conv}->[0];
                                push @row, ($sim_env5, $pheno_sim5_3, $effect_sim5_3);

                                my $sim_env6 = $sim_data_hash_6_3->{$p}->{$t};
                                my $pheno_sim6_3 = $phenotype_data_altered_env_hash_6_3->{$p}->{$t_conv};
                                my $effect_sim6_3 = $result_blup_spatial_data_altered_env_6_3->{$p}->{$t_conv}->[0];
                                push @row, ($sim_env6, $pheno_sim6_3, $effect_sim6_3);
                            }
                            my $line = join ',', @row;
                            print $F_fullplot "$line\n";
                        }
                    close($F_fullplot);

                    my $plot_corr_figure_tempfile_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $plot_corr_figure_tempfile_string .= '.png';
                    my $plot_corr_figure_tempfile = $c->config->{basepath}."/".$plot_corr_figure_tempfile_string;

                    my $cmd_plotcorr_plot = 'R -e "library(data.table); library(ggplot2); library(GGally);
                    mat_orig <- fread(\''.$full_plot_level_correlation_tempfile.'\', header=TRUE, sep=\',\');
                    gg <- ggcorr(data=mat_orig[,-seq(1,8)], hjust = 1, size = 2, color = \'grey50\', layout.exp = 1, label = TRUE);
                    ggsave(\''.$plot_corr_figure_tempfile.'\', gg, device=\'png\', width=30, height=30, limitsize = FALSE, units=\'in\');
                    "';
                    # print STDERR Dumper $cmd;
                    my $status_plotcorr_plot = system($cmd_plotcorr_plot);
                    push @$spatial_effects_plots, [$plot_corr_figure_tempfile_string, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_fullcorr_"."envvar_".$env_variance_percent."_".$iterations];
                    push @$spatial_effects_files_store, [$full_plot_level_correlation_tempfile, "datafile_".$statistics_select.$sim_env_change_over_time.$correlation_between_times."_fullcorr_"."envvar_".$env_variance_percent."_".$iterations];
                };

                eval {
                    my @plot_corr_full_vals;

                    my @original_pheno_vals;
                    my ($phenotypes_original_heatmap_tempfile_fh, $phenotypes_original_heatmap_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open(my $F_pheno, ">", $phenotypes_original_heatmap_tempfile) || die "Can't open file ".$phenotypes_original_heatmap_tempfile;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_2) {
                                my $val = $phenotype_data_original_2{$p}->{$t};
                                my @row = ("pheno_orig_".$t, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                push @original_pheno_vals, $val;
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                            }
                        }
                    close($F_pheno);
                    push @plot_corr_full_vals, \@original_pheno_vals;

                    my $original_pheno_stat = Statistics::Descriptive::Full->new();
                    $original_pheno_stat->add_data(@original_pheno_vals);
                    my $sig_original_pheno = $original_pheno_stat->variance();

                    #PHENO POST M START

                    my @altered_pheno_vals_3;
                    my ($phenotypes_post_heatmap_tempfile_fh_3, $phenotypes_post_heatmap_tempfile_3) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $phenotypes_post_heatmap_tempfile_3) || die "Can't open file ".$phenotypes_post_heatmap_tempfile_3;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_2) {
                                my $val = $phenotype_data_altered_hash_3->{$p}->{$t};
                                my @row = ("pheno_postm3_".$trait_name_encoder_2{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                push @altered_pheno_vals_3, $val;
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                            }
                        }
                    close($F_pheno);
                    push @plot_corr_full_vals, \@altered_pheno_vals_3;

                    my $altered_pheno_stat_3 = Statistics::Descriptive::Full->new();
                    $altered_pheno_stat_3->add_data(@altered_pheno_vals_3);
                    my $sig_altered_pheno_3 = $altered_pheno_stat_3->variance();

                    # EFFECT ORIGINAL M

                    my @original_effect_vals_3;
                    my ($effects_heatmap_tempfile_fh_3, $effects_heatmap_tempfile_3) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open(my $F_eff, ">", $effects_heatmap_tempfile_3) || die "Can't open file ".$effects_heatmap_tempfile_3;
                        print $F_eff "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_2) {
                                my $val = $result_blup_spatial_data_original_3->{$p}->{$t}->[0];
                                my @row = ("eff_origm3_".$trait_name_encoder_2{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_eff "$line\n";
                                push @original_effect_vals_3, $val;
                            }
                        }
                    close($F_eff);
                    push @plot_corr_full_vals, \@original_effect_vals_3;

                    my $original_effect_stat_3 = Statistics::Descriptive::Full->new();
                    $original_effect_stat_3->add_data(@original_effect_vals_3);
                    my $sig_original_effect_3 = $original_effect_stat_3->variance();

                    # EFFECT POST M MIN

                    my @altered_effect_vals_3;
                    my ($effects_post_heatmap_tempfile_fh_3, $effects_post_heatmap_tempfile_3) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_eff, ">", $effects_post_heatmap_tempfile_3) || die "Can't open file ".$effects_post_heatmap_tempfile_3;
                        print $F_eff "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_2) {
                                my $val = $result_blup_spatial_data_altered_3->{$p}->{$t}->[0];
                                my @row = ("eff_postm3_".$trait_name_encoder_2{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_eff "$line\n";
                                push @altered_effect_vals_3, $val;
                            }
                        }
                    close($F_eff);
                    push @plot_corr_full_vals, \@altered_effect_vals_3;

                    my $altered_effect_stat_3 = Statistics::Descriptive::Full->new();
                    $altered_effect_stat_3->add_data(@altered_effect_vals_3);
                    my $sig_altered_effect_3 = $altered_effect_stat_3->variance();

                    # SIM ENV 1: ALTERED PHENO + EFFECT

                    my ($phenotypes_env_heatmap_tempfile_fh, $phenotypes_env_heatmap_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $phenotypes_env_heatmap_tempfile) || die "Can't open file ".$phenotypes_env_heatmap_tempfile;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_2) {
                                my @row = ("sim_env1_".$t, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $sim_data_hash_1_3->{$p}->{$t});
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                            }
                        }
                    close($F_pheno);

                    my @sim_pheno1_vals_3;
                    my ($phenotypes_pheno_sim_heatmap_tempfile_fh_3, $phenotypes_pheno_sim_heatmap_tempfile_3) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $phenotypes_pheno_sim_heatmap_tempfile_3) || die "Can't open file ".$phenotypes_pheno_sim_heatmap_tempfile_3;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_2) {
                                my $val = $phenotype_data_altered_env_hash_1_3->{$p}->{$t};
                                my @row = ("simm3_pheno1_".$trait_name_encoder_2{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                                push @sim_pheno1_vals_3, $val;
                            }
                        }
                    close($F_pheno);
                    push @plot_corr_full_vals, \@sim_pheno1_vals_3;

                    my $sim_pheno1_stat_3 = Statistics::Descriptive::Full->new();
                    $sim_pheno1_stat_3->add_data(@sim_pheno1_vals_3);
                    my $sig_sim3_pheno1 = $sim_pheno1_stat_3->variance();

                    my @sim_effect1_vals_3;
                    my ($effects_sim_heatmap_tempfile_fh_3, $effects_sim_heatmap_tempfile_3) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_eff, ">", $effects_sim_heatmap_tempfile_3) || die "Can't open file ".$effects_sim_heatmap_tempfile_3;
                        print $F_eff "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_2) {
                                my $val = $result_blup_spatial_data_altered_env_1_3->{$p}->{$t}->[0];
                                my @row = ("effm3_sim1_".$trait_name_encoder_2{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_eff "$line\n";
                                push @sim_effect1_vals_3, $val;
                            }
                        }
                    close($F_eff);
                    push @plot_corr_full_vals, \@sim_effect1_vals_3;

                    my $sim_effect1_stat_3 = Statistics::Descriptive::Full->new();
                    $sim_effect1_stat_3->add_data(@sim_effect1_vals_3);
                    my $sig_sim3_effect1 = $sim_effect1_stat_3->variance();

                    # SIM ENV 2: ALTERED PHENO + EFFECT

                    my ($phenotypes_env_heatmap_tempfile2_fh, $phenotypes_env_heatmap_tempfile2) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $phenotypes_env_heatmap_tempfile2) || die "Can't open file ".$phenotypes_env_heatmap_tempfile2;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_2) {
                                my @row = ("sim_env2_".$t, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $sim_data_hash_2_3->{$p}->{$t});
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                            }
                        }
                    close($F_pheno);

                    my @sim_pheno2_vals_3;
                    my ($phenotypes_pheno_sim_heatmap_tempfile2_fh_3, $phenotypes_pheno_sim_heatmap_tempfile2_3) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $phenotypes_pheno_sim_heatmap_tempfile2_3) || die "Can't open file ".$phenotypes_pheno_sim_heatmap_tempfile2_3;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_2) {
                                my $val = $phenotype_data_altered_env_hash_2_3->{$p}->{$t};
                                my @row = ("simm3_pheno2_".$trait_name_encoder_2{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                                push @sim_pheno2_vals_3, $val;
                            }
                        }
                    close($F_pheno);
                    push @plot_corr_full_vals, \@sim_pheno2_vals_3;

                    my $sim_pheno2_stat_3 = Statistics::Descriptive::Full->new();
                    $sim_pheno2_stat_3->add_data(@sim_pheno2_vals_3);
                    my $sig_sim_pheno2_3 = $sim_pheno2_stat_3->variance();

                    my @sim_effect2_vals_3;
                    my ($effects_sim_heatmap_tempfile2_fh_3, $effects_sim_heatmap_tempfile2_3) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_eff, ">", $effects_sim_heatmap_tempfile2_3) || die "Can't open file ".$effects_sim_heatmap_tempfile2_3;
                        print $F_eff "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_2) {
                                my $val = $result_blup_spatial_data_altered_env_2_3->{$p}->{$t}->[0];
                                my @row = ("effm3_sim2_".$trait_name_encoder_2{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_eff "$line\n";
                                push @sim_effect2_vals_3, $val;
                            }
                        }
                    close($F_eff);
                    push @plot_corr_full_vals, \@sim_effect2_vals_3;

                    my $sim_effect2_stat_3 = Statistics::Descriptive::Full->new();
                    $sim_effect2_stat_3->add_data(@sim_effect2_vals_3);
                    my $sig_sim_effect2_3 = $sim_effect2_stat_3->variance();

                    # SIM ENV 3: ALTERED PHENO + EFFECT

                    my ($phenotypes_env_heatmap_tempfile3_fh, $phenotypes_env_heatmap_tempfile3) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $phenotypes_env_heatmap_tempfile3) || die "Can't open file ".$phenotypes_env_heatmap_tempfile3;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_2) {
                                my @row = ("sim_env3_".$t, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $sim_data_hash_3_3->{$p}->{$t});
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                            }
                        }
                    close($F_pheno);

                    my @sim_pheno3_vals_3;
                    my ($phenotypes_pheno_sim_heatmap_tempfile3_fh_3, $phenotypes_pheno_sim_heatmap_tempfile3_3) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $phenotypes_pheno_sim_heatmap_tempfile3_3) || die "Can't open file ".$phenotypes_pheno_sim_heatmap_tempfile3_3;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_2) {
                                my $val = $phenotype_data_altered_env_hash_3_3->{$p}->{$t};
                                my @row = ("simm3_pheno3_".$trait_name_encoder_2{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                                push @sim_pheno3_vals_3, $val;
                            }
                        }
                    close($F_pheno);
                    push @plot_corr_full_vals, \@sim_pheno3_vals_3;

                    my $sim_pheno3_stat_3 = Statistics::Descriptive::Full->new();
                    $sim_pheno3_stat_3->add_data(@sim_pheno3_vals_3);
                    my $sig_sim_pheno3_3 = $sim_pheno3_stat_3->variance();

                    my @sim_effect3_vals_3;
                    my ($effects_sim_heatmap_tempfile3_fh_3, $effects_sim_heatmap_tempfile3_3) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_eff, ">", $effects_sim_heatmap_tempfile3_3) || die "Can't open file ".$effects_sim_heatmap_tempfile3_3;
                        print $F_eff "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_2) {
                                my $val = $result_blup_spatial_data_altered_env_3_3->{$p}->{$t}->[0];
                                my @row = ("effm3_sim3_".$trait_name_encoder_2{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_eff "$line\n";
                                push @sim_effect3_vals_3, $val;
                            }
                        }
                    close($F_eff);
                    push @plot_corr_full_vals, \@sim_effect3_vals_3;

                    my $sim_effect3_stat_3 = Statistics::Descriptive::Full->new();
                    $sim_effect3_stat_3->add_data(@sim_effect3_vals_3);
                    my $sig_sim_effect3_3 = $sim_effect3_stat_3->variance();

                    # SIM ENV 4: ALTERED PHENO + EFFECT

                    my ($phenotypes_env_heatmap_tempfile4_fh, $phenotypes_env_heatmap_tempfile4) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $phenotypes_env_heatmap_tempfile4) || die "Can't open file ".$phenotypes_env_heatmap_tempfile4;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_2) {
                                my @row = ("sim_env4_".$t, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $sim_data_hash_4_3->{$p}->{$t});
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                            }
                        }
                    close($F_pheno);

                    my @sim_pheno4_vals_3;
                    my ($phenotypes_pheno_sim_heatmap_tempfile4_fh_3, $phenotypes_pheno_sim_heatmap_tempfile4_3) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $phenotypes_pheno_sim_heatmap_tempfile4_3) || die "Can't open file ".$phenotypes_pheno_sim_heatmap_tempfile4_3;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_2) {
                                my $val = $phenotype_data_altered_env_hash_4_3->{$p}->{$t};
                                my @row = ("simm3_pheno4_".$trait_name_encoder_2{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                                push @sim_pheno4_vals_3, $val;
                            }
                        }
                    close($F_pheno);
                    push @plot_corr_full_vals, \@sim_pheno4_vals_3;

                    my $sim_pheno4_stat_3 = Statistics::Descriptive::Full->new();
                    $sim_pheno4_stat_3->add_data(@sim_pheno4_vals_3);
                    my $sig_sim_pheno4_3 = $sim_pheno4_stat_3->variance();

                    my @sim_effect4_vals_3;
                    my ($effects_sim_heatmap_tempfile4_fh_3, $effects_sim_heatmap_tempfile4_3) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_eff, ">", $effects_sim_heatmap_tempfile4_3) || die "Can't open file ".$effects_sim_heatmap_tempfile4_3;
                        print $F_eff "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_2) {
                                my $val = $result_blup_spatial_data_altered_env_4_3->{$p}->{$t}->[0];
                                my @row = ("effm3_sim4_".$trait_name_encoder_2{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_eff "$line\n";
                                push @sim_effect4_vals_3, $val;
                            }
                        }
                    close($F_eff);
                    push @plot_corr_full_vals, \@sim_effect4_vals_3;

                    my $sim_effect4_stat_3 = Statistics::Descriptive::Full->new();
                    $sim_effect4_stat_3->add_data(@sim_effect4_vals_3);
                    my $sig_sim_effect4_3 = $sim_effect4_stat_3->variance();

                    # SIM ENV 5: ALTERED PHENO + EFFECT

                    my ($phenotypes_env_heatmap_tempfile5_fh, $phenotypes_env_heatmap_tempfile5) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $phenotypes_env_heatmap_tempfile5) || die "Can't open file ".$phenotypes_env_heatmap_tempfile5;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_2) {
                                my @row = ("sim_env5_".$t, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $sim_data_hash_5_3->{$p}->{$t});
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                            }
                        }
                    close($F_pheno);

                    my @sim_pheno5_vals_3;
                    my ($phenotypes_pheno_sim_heatmap_tempfile5_fh_3, $phenotypes_pheno_sim_heatmap_tempfile5_3) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $phenotypes_pheno_sim_heatmap_tempfile5_3) || die "Can't open file ".$phenotypes_pheno_sim_heatmap_tempfile5_3;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_2) {
                                my $val = $phenotype_data_altered_env_hash_5_3->{$p}->{$t};
                                my @row = ("simm3_pheno5_".$trait_name_encoder_2{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                                push @sim_pheno5_vals_3, $val;
                            }
                        }
                    close($F_pheno);
                    push @plot_corr_full_vals, \@sim_pheno5_vals_3;

                    my $sim_pheno5_stat_3 = Statistics::Descriptive::Full->new();
                    $sim_pheno5_stat_3->add_data(@sim_pheno5_vals_3);
                    my $sig_sim_pheno5_3 = $sim_pheno5_stat_3->variance();

                    my @sim_effect5_vals_3;
                    my ($effects_sim_heatmap_tempfile5_fh_3, $effects_sim_heatmap_tempfile5_3) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_eff, ">", $effects_sim_heatmap_tempfile5_3) || die "Can't open file ".$effects_sim_heatmap_tempfile5_3;
                        print $F_eff "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_2) {
                                my $val = $result_blup_spatial_data_altered_env_5_3->{$p}->{$t}->[0];
                                my @row = ("effm3_sim5_".$trait_name_encoder_2{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_eff "$line\n";
                                push @sim_effect5_vals_3, $val;
                            }
                        }
                    close($F_eff);
                    push @plot_corr_full_vals, \@sim_effect5_vals_3;

                    my $sim_effect5_stat_3 = Statistics::Descriptive::Full->new();
                    $sim_effect5_stat_3->add_data(@sim_effect5_vals_3);
                    my $sig_sim_effect5_3 = $sim_effect5_stat_3->variance();

                    # SIM ENV 6: ALTERED PHENO + EFFECT

                    my ($phenotypes_env_heatmap_tempfile6_fh, $phenotypes_env_heatmap_tempfile6) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $phenotypes_env_heatmap_tempfile6) || die "Can't open file ".$phenotypes_env_heatmap_tempfile6;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_2) {
                                my @row = ("sim_env6_".$t, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $sim_data_hash_6_3->{$p}->{$t});
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                            }
                        }
                    close($F_pheno);

                    my @sim_pheno6_vals_3;
                    my ($phenotypes_pheno_sim_heatmap_tempfile6_fh_3, $phenotypes_pheno_sim_heatmap_tempfile6_3) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $phenotypes_pheno_sim_heatmap_tempfile6_3) || die "Can't open file ".$phenotypes_pheno_sim_heatmap_tempfile6_3;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_2) {
                                my $val = $phenotype_data_altered_env_hash_6_3->{$p}->{$t};
                                my @row = ("simm3_pheno6_".$trait_name_encoder_2{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                                push @sim_pheno6_vals_3, $val;
                            }
                        }
                    close($F_pheno);
                    push @plot_corr_full_vals, \@sim_pheno6_vals_3;

                    my $sim_pheno6_stat_3 = Statistics::Descriptive::Full->new();
                    $sim_pheno6_stat_3->add_data(@sim_pheno6_vals_3);
                    my $sig_sim_pheno6_3 = $sim_pheno6_stat_3->variance();

                    my @sim_effect6_vals_3;
                    my ($effects_sim_heatmap_tempfile6_fh_3, $effects_sim_heatmap_tempfile6_3) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_eff, ">", $effects_sim_heatmap_tempfile6_3) || die "Can't open file ".$effects_sim_heatmap_tempfile6_3;
                        print $F_eff "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_2) {
                                my $val = $result_blup_spatial_data_altered_env_6_3->{$p}->{$t}->[0];
                                my @row = ("effm3_sim6_".$trait_name_encoder_2{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_eff "$line\n";
                                push @sim_effect6_vals_3, $val;
                            }
                        }
                    close($F_eff);
                    push @plot_corr_full_vals, \@sim_effect6_vals_3;

                    my $sim_effect6_stat_3 = Statistics::Descriptive::Full->new();
                    $sim_effect6_stat_3->add_data(@sim_effect6_vals_3);
                    my $sig_sim_effect6_3 = $sim_effect6_stat_3->variance();

                    my $plot_corr_summary_figure_inputfile_tempfile = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'tmp_drone_statistics/fileXXXX');
                    open($F_eff, ">", $plot_corr_summary_figure_inputfile_tempfile) || die "Can't open file ".$plot_corr_summary_figure_inputfile_tempfile;
                        foreach (@plot_corr_full_vals) {
                            my $line = join ',', @$_;
                            print $F_eff $line."\n";
                        }
                    close($F_eff);

                    my $plot_corr_summary_figure_tempfile_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $plot_corr_summary_figure_tempfile_string .= '.png';
                    my $plot_corr_summary_figure_tempfile = $c->config->{basepath}."/".$plot_corr_summary_figure_tempfile_string;

                    my $cmd_plotcorrsum_plot = 'R -e "library(data.table); library(ggplot2); library(GGally);
                    mat_full_t <- fread(\''.$plot_corr_summary_figure_inputfile_tempfile.'\', header=FALSE, sep=\',\');
                    mat_full <- data.frame(t(mat_full_t));
                    colnames(mat_full) <- c(\'mat_orig\', \'mat_altered_3\', \'mat_eff_3\', \'mat_eff_altered_3\',
                    \'mat_p_sim1_3\', \'mat_eff_sim1_3\',
                    \'mat_p_sim2_3\', \'mat_eff_sim2_3\',
                    \'mat_p_sim3_3\', \'mat_eff_sim3_3\',
                    \'mat_p_sim4_3\', \'mat_eff_sim4_3\',
                    \'mat_p_sim5_3\', \'mat_eff_sim5_3\',
                    \'mat_p_sim6_3\', \'mat_eff_sim6_3\');
                    mat_env <- fread(\''.$phenotypes_env_heatmap_tempfile.'\', header=TRUE, sep=\',\');
                    mat_env2 <- fread(\''.$phenotypes_env_heatmap_tempfile2.'\', header=TRUE, sep=\',\');
                    mat_env3 <- fread(\''.$phenotypes_env_heatmap_tempfile3.'\', header=TRUE, sep=\',\');
                    mat_env4 <- fread(\''.$phenotypes_env_heatmap_tempfile4.'\', header=TRUE, sep=\',\');
                    mat_env5 <- fread(\''.$phenotypes_env_heatmap_tempfile5.'\', header=TRUE, sep=\',\');
                    mat_env6 <- fread(\''.$phenotypes_env_heatmap_tempfile6.'\', header=TRUE, sep=\',\');
                    mat <- data.frame(pheno_orig = mat_full\$mat_orig, pheno_altm3 = mat_full\$mat_altered_3, eff_origm3 = mat_full\$mat_eff_3, eff_altm3 = mat_full\$mat_eff_altered_3, env_lin = mat_env\$value, pheno_linm3 = mat_full\$mat_p_sim1_3, lin_effm3 = mat_full\$mat_eff_sim1_3, env_n1d = mat_env2\$value, pheno_n1dm3 = mat_full\$mat_p_sim2_3, n1d_effm3 = mat_full\$mat_eff_sim2_3, env_n2d = mat_env3\$value, pheno_n2dm3 = mat_full\$mat_p_sim3_3, n2d_effm3 = mat_full\$mat_eff_sim3_3, env_rand = mat_env4\$value, pheno_randm3 = mat_full\$mat_p_sim4_3, rand_effm3 = mat_full\$mat_eff_sim4_3, env_ar1 = mat_env5\$value, pheno_ar1m3 = mat_full\$mat_p_sim5_3, ar1_effm3 = mat_full\$mat_eff_sim5_3, env_realdata = mat_env6\$value, pheno_realdatam3 = mat_full\$mat_p_sim6_3, realdata_effm3 = mat_full\$mat_eff_sim6_3);
                    gg <- ggcorr(data=mat, hjust = 1, size = 2, color = \'grey50\', layout.exp = 1, label = TRUE, label_round = 2);
                    ggsave(\''.$plot_corr_summary_figure_tempfile.'\', gg, device=\'png\', width=30, height=30, units=\'in\');
                    "';
                    # print STDERR Dumper $cmd_plotcorrsum_plot;

                    my $status_plotcorrsum_plot = system($cmd_plotcorrsum_plot);
                    push @$spatial_effects_plots, [$plot_corr_summary_figure_tempfile_string, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_envsimscorr_"."envvar_".$env_variance_percent."_".$iterations];

                    my $env_effects_first_figure_tempfile_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $env_effects_first_figure_tempfile_string .= '.png';
                    my $env_effects_first_figure_tempfile = $c->config->{basepath}."/".$env_effects_first_figure_tempfile_string;

                    my $env_effects_first_figure_tempfile_string_2 = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $env_effects_first_figure_tempfile_string_2 .= '.png';
                    my $env_effects_first_figure_tempfile_2 = $c->config->{basepath}."/".$env_effects_first_figure_tempfile_string_2;

                    my $output_plot_row = 'row';
                    my $output_plot_col = 'col';
                    if ($max_col > $max_row) {
                        $output_plot_row = 'col';
                        $output_plot_col = 'row';
                    }

                    my $cmd_spatialfirst_plot_2 = 'R -e "library(data.table); library(ggplot2); library(dplyr); library(viridis); library(GGally); library(gridExtra);
                    mat_orig <- fread(\''.$phenotypes_original_heatmap_tempfile.'\', header=TRUE, sep=\',\');
                    mat_altered_3 <- fread(\''.$phenotypes_post_heatmap_tempfile_3.'\', header=TRUE, sep=\',\');
                    pheno_mat <- rbind(mat_orig, mat_altered_3);
                    options(device=\'png\');
                    par();
                    gg <- ggplot(pheno_mat, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_2).');
                    ggsave(\''.$env_effects_first_figure_tempfile_2.'\', gg, device=\'png\', width=20, height=20, units=\'in\');
                    "';
                    # print STDERR Dumper $cmd;
                    my $status_spatialfirst_plot_2 = system($cmd_spatialfirst_plot_2);
                    push @$spatial_effects_plots, [$env_effects_first_figure_tempfile_string_2, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_origheatmap_"."envvar_".$env_variance_percent."_".$iterations];

                    my ($sim_effects_corr_results_fh, $sim_effects_corr_results) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);

                    my $cmd_spatialfirst_plot = 'R -e "library(data.table); library(ggplot2); library(dplyr); library(viridis); library(GGally); library(gridExtra);
                    mat_full_t <- fread(\''.$plot_corr_summary_figure_inputfile_tempfile.'\', header=FALSE, sep=\',\');
                    mat_full <- data.frame(t(mat_full_t));
                    colnames(mat_full) <- c(\'mat_orig\', \'mat_altered_3\', \'mat_eff_3\', \'mat_eff_altered_3\',
                    \'mat_p_sim1_3\', \'mat_eff_sim1_3\',
                    \'mat_p_sim2_3\', \'mat_eff_sim2_3\',
                    \'mat_p_sim3_3\', \'mat_eff_sim3_3\',
                    \'mat_p_sim4_3\', \'mat_eff_sim4_3\',
                    \'mat_p_sim5_3\', \'mat_eff_sim5_3\',
                    \'mat_p_sim6_3\', \'mat_eff_sim6_3\');
                    mat_eff_3 <- fread(\''.$effects_heatmap_tempfile_3.'\', header=TRUE, sep=\',\');
                    mat_eff_altered_3 <- fread(\''.$effects_post_heatmap_tempfile_3.'\', header=TRUE, sep=\',\');
                    effect_mat_3 <- rbind(mat_eff_3, mat_eff_altered_3);
                    mat_env <- fread(\''.$phenotypes_env_heatmap_tempfile.'\', header=TRUE, sep=\',\');
                    mat_env2 <- fread(\''.$phenotypes_env_heatmap_tempfile2.'\', header=TRUE, sep=\',\');
                    mat_env3 <- fread(\''.$phenotypes_env_heatmap_tempfile3.'\', header=TRUE, sep=\',\');
                    mat_env4 <- fread(\''.$phenotypes_env_heatmap_tempfile4.'\', header=TRUE, sep=\',\');
                    mat_env5 <- fread(\''.$phenotypes_env_heatmap_tempfile5.'\', header=TRUE, sep=\',\');
                    mat_env6 <- fread(\''.$phenotypes_env_heatmap_tempfile6.'\', header=TRUE, sep=\',\');
                    options(device=\'png\');
                    par();
                    gg_eff_3 <- ggplot(effect_mat_3, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_2).');
                    ggsave(\''.$env_effects_first_figure_tempfile.'\', arrangeGrob(gg_eff_3, nrow=1), device=\'png\', width=25, height=25, units=\'in\');
                    write.table(data.frame(env_linear = c(cor(mat_env\$value, mat_full\$mat_eff_sim1_3)), env_1DN = c(cor(mat_env2\$value, mat_full\$mat_eff_sim2_3)), env_2DN = c(cor(mat_env3\$value, mat_full\$mat_eff_sim3_3)), env_random = c(cor(mat_env4\$value, mat_full\$mat_eff_sim4_3)), env_ar1xar1 = c(cor(mat_env5\$value, mat_full\$mat_eff_sim5_3)), env_realdata = c(cor(mat_env6\$value, mat_full\$mat_eff_sim6_3)) ), file=\''.$sim_effects_corr_results.'\', row.names=FALSE, col.names=TRUE, sep=\'\t\');
                    "';
                    # print STDERR Dumper $cmd;
                    my $status_spatialfirst_plot = system($cmd_spatialfirst_plot);
                    push @$spatial_effects_plots, [$env_effects_first_figure_tempfile_string, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_originaleffheatmap_"."envvar_".$env_variance_percent."_".$iterations];

                    open(my $fh_corr_result, '<', $sim_effects_corr_results) or die "Could not open file '$sim_effects_corr_results' $!";
                        print STDERR "Opened $sim_effects_corr_results\n";

                        my $header = <$fh_corr_result>;
                        my @header;
                        if ($csv->parse($header)) {
                            @header = $csv->fields();
                        }

                        while (my $row = <$fh_corr_result>) {
                            my @columns;
                            my $counter = 0;
                            if ($csv->parse($row)) {
                                @columns = $csv->fields();
                            }
                            foreach (@columns) {
                                push @{$env_corr_res->{$statistics_select."_".$header[$counter]."_corrtime_".$sim_env_change_over_time.$correlation_between_times."_envvar_".$env_variance_percent}->{values}}, $_;
                                $counter++;
                            }
                        }
                    close($fh_corr_result);

                    my $env_effects_sim_figure_tempfile_string_3_env1 = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $env_effects_sim_figure_tempfile_string_3_env1 .= '.png';
                    my $env_effects_sim_figure_tempfile_3_env1 = $c->config->{basepath}."/".$env_effects_sim_figure_tempfile_string_3_env1;

                    my $cmd_spatialenvsim_plot_3_env1 = 'R -e "library(data.table); library(ggplot2); library(dplyr); library(viridis); library(GGally); library(gridExtra);
                    mat_env <- fread(\''.$phenotypes_env_heatmap_tempfile.'\', header=TRUE, sep=\',\');
                    mat_p_sim <- fread(\''.$phenotypes_pheno_sim_heatmap_tempfile_3.'\', header=TRUE, sep=\',\');
                    mat_eff_sim <- fread(\''.$effects_sim_heatmap_tempfile_3.'\', header=TRUE, sep=\',\');
                    options(device=\'png\');
                    par();
                    gg_env <- ggplot(mat_env, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_2).');
                    gg_p_sim <- ggplot(mat_p_sim, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_2).');
                    gg_eff_sim <- ggplot(mat_eff_sim, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_2).');
                    ggsave(\''.$env_effects_sim_figure_tempfile_3_env1.'\', arrangeGrob(gg_env, gg_p_sim, gg_eff_sim, nrow=1), device=\'png\', width=25, height=25, units=\'in\');
                    "';
                    # print STDERR Dumper $cmd_spatialenvsim_plot_3_env1;
                    my $status_spatialenvsim_plot_3_env1 = system($cmd_spatialenvsim_plot_3_env1);
                    push @$spatial_effects_plots, [$env_effects_sim_figure_tempfile_string_3_env1, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_env1effheatmap_"."envvar_".$env_variance_percent."_".$iterations];

                    my $env_effects_sim_figure_tempfile_string_3_env2 = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $env_effects_sim_figure_tempfile_string_3_env2 .= '.png';
                    my $env_effects_sim_figure_tempfile_3_env2 = $c->config->{basepath}."/".$env_effects_sim_figure_tempfile_string_3_env2;

                    my $cmd_spatialenvsim_plot_3_env2 = 'R -e "library(data.table); library(ggplot2); library(dplyr); library(viridis); library(GGally); library(gridExtra);
                    mat_env2 <- fread(\''.$phenotypes_env_heatmap_tempfile2.'\', header=TRUE, sep=\',\');
                    mat_p_sim2 <- fread(\''.$phenotypes_pheno_sim_heatmap_tempfile2_3.'\', header=TRUE, sep=\',\');
                    mat_eff_sim2 <- fread(\''.$effects_sim_heatmap_tempfile2_3.'\', header=TRUE, sep=\',\');
                    options(device=\'png\');
                    par();
                    gg_env2 <- ggplot(mat_env2, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_2).');
                    gg_p_sim2 <- ggplot(mat_p_sim2, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_2).');
                    gg_eff_sim2 <- ggplot(mat_eff_sim2, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_2).');
                    ggsave(\''.$env_effects_sim_figure_tempfile_3_env2.'\', arrangeGrob(gg_env2, gg_p_sim2, gg_eff_sim2, nrow=1), device=\'png\', width=25, height=25, units=\'in\');
                    "';
                    # print STDERR Dumper $cmd_spatialenvsim_plot_3_env2;
                    my $status_spatialenvsim_plot_3_env2 = system($cmd_spatialenvsim_plot_3_env2);
                    push @$spatial_effects_plots, [$env_effects_sim_figure_tempfile_string_3_env2, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_env2effheatmap_"."envvar_".$env_variance_percent."_".$iterations];

                    my $env_effects_sim_figure_tempfile_string_3_env3 = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $env_effects_sim_figure_tempfile_string_3_env3 .= '.png';
                    my $env_effects_sim_figure_tempfile_3_env3 = $c->config->{basepath}."/".$env_effects_sim_figure_tempfile_string_3_env3;

                    my $cmd_spatialenvsim_plot_3_env3 = 'R -e "library(data.table); library(ggplot2); library(dplyr); library(viridis); library(GGally); library(gridExtra);
                    mat_env3 <- fread(\''.$phenotypes_env_heatmap_tempfile3.'\', header=TRUE, sep=\',\');
                    mat_p_sim3 <- fread(\''.$phenotypes_pheno_sim_heatmap_tempfile3_3.'\', header=TRUE, sep=\',\');
                    mat_eff_sim3 <- fread(\''.$effects_sim_heatmap_tempfile3_3.'\', header=TRUE, sep=\',\');
                    options(device=\'png\');
                    par();
                    gg_env3 <- ggplot(mat_env3, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_2).');
                    gg_p_sim3 <- ggplot(mat_p_sim3, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_2).');
                    gg_eff_sim3 <- ggplot(mat_eff_sim3, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_2).');
                    ggsave(\''.$env_effects_sim_figure_tempfile_3_env3.'\', arrangeGrob(gg_env3, gg_p_sim3, gg_eff_sim3, nrow=1), device=\'png\', width=25, height=25, units=\'in\');
                    "';
                    # print STDERR Dumper $cmd_spatialenvsim_plot_3_env3;
                    my $status_spatialenvsim_plot_3_env3 = system($cmd_spatialenvsim_plot_3_env3);
                    push @$spatial_effects_plots, [$env_effects_sim_figure_tempfile_string_3_env3, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_env3effheatmap_"."envvar_".$env_variance_percent."_".$iterations];

                    my $env_effects_sim_figure_tempfile_string_3_env4 = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $env_effects_sim_figure_tempfile_string_3_env4 .= '.png';
                    my $env_effects_sim_figure_tempfile_3_env4 = $c->config->{basepath}."/".$env_effects_sim_figure_tempfile_string_3_env4;

                    my $cmd_spatialenvsim_plot_3_env4 = 'R -e "library(data.table); library(ggplot2); library(dplyr); library(viridis); library(GGally); library(gridExtra);
                    mat_env4 <- fread(\''.$phenotypes_env_heatmap_tempfile4.'\', header=TRUE, sep=\',\');
                    mat_p_sim4 <- fread(\''.$phenotypes_pheno_sim_heatmap_tempfile4_3.'\', header=TRUE, sep=\',\');
                    mat_eff_sim4 <- fread(\''.$effects_sim_heatmap_tempfile4_3.'\', header=TRUE, sep=\',\');
                    options(device=\'png\');
                    par();
                    gg_env4 <- ggplot(mat_env4, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_2).');
                    gg_p_sim4 <- ggplot(mat_p_sim4, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_2).');
                    gg_eff_sim4 <- ggplot(mat_eff_sim4, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_2).');
                    ggsave(\''.$env_effects_sim_figure_tempfile_3_env4.'\', arrangeGrob(gg_env4, gg_p_sim4, gg_eff_sim4, nrow=1), device=\'png\', width=25, height=25, units=\'in\');
                    "';
                    # print STDERR Dumper $cmd_spatialenvsim_plot_3_env4;
                    my $status_spatialenvsim_plot_3_env4 = system($cmd_spatialenvsim_plot_3_env4);
                    push @$spatial_effects_plots, [$env_effects_sim_figure_tempfile_string_3_env4, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_env4effheatmap_"."envvar_".$env_variance_percent."_".$iterations];

                    my $env_effects_sim_figure_tempfile_string_3_env5 = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $env_effects_sim_figure_tempfile_string_3_env5 .= '.png';
                    my $env_effects_sim_figure_tempfile_3_env5 = $c->config->{basepath}."/".$env_effects_sim_figure_tempfile_string_3_env5;

                    my $cmd_spatialenvsim_plot_3_env5 = 'R -e "library(data.table); library(ggplot2); library(dplyr); library(viridis); library(GGally); library(gridExtra);
                    mat_env5 <- fread(\''.$phenotypes_env_heatmap_tempfile5.'\', header=TRUE, sep=\',\');
                    mat_p_sim5 <- fread(\''.$phenotypes_pheno_sim_heatmap_tempfile5_3.'\', header=TRUE, sep=\',\');
                    mat_eff_sim5 <- fread(\''.$effects_sim_heatmap_tempfile5_3.'\', header=TRUE, sep=\',\');
                    options(device=\'png\');
                    par();
                    gg_env5 <- ggplot(mat_env5, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_2).');
                    gg_p_sim5 <- ggplot(mat_p_sim5, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_2).');
                    gg_eff_sim5 <- ggplot(mat_eff_sim5, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_2).');
                    ggsave(\''.$env_effects_sim_figure_tempfile_3_env5.'\', arrangeGrob(gg_env5, gg_p_sim5, gg_eff_sim5, nrow=1), device=\'png\', width=25, height=25, units=\'in\');
                    "';
                    # print STDERR Dumper $cmd_spatialenvsim_plot_3_env5;
                    my $status_spatialenvsim_plot_3_env5 = system($cmd_spatialenvsim_plot_3_env5);
                    push @$spatial_effects_plots, [$env_effects_sim_figure_tempfile_string_3_env5, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_env5effheatmap_"."envvar_".$env_variance_percent."_".$iterations];

                    my $env_effects_sim_figure_tempfile_string_3_env6 = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $env_effects_sim_figure_tempfile_string_3_env6 .= '.png';
                    my $env_effects_sim_figure_tempfile_3_env6 = $c->config->{basepath}."/".$env_effects_sim_figure_tempfile_string_3_env6;

                    my $cmd_spatialenvsim_plot_3_env6 = 'R -e "library(data.table); library(ggplot2); library(dplyr); library(viridis); library(GGally); library(gridExtra);
                    mat_env6 <- fread(\''.$phenotypes_env_heatmap_tempfile6.'\', header=TRUE, sep=\',\');
                    mat_p_sim6 <- fread(\''.$phenotypes_pheno_sim_heatmap_tempfile6_3.'\', header=TRUE, sep=\',\');
                    mat_eff_sim6 <- fread(\''.$effects_sim_heatmap_tempfile6_3.'\', header=TRUE, sep=\',\');
                    options(device=\'png\');
                    par();
                    gg_env6 <- ggplot(mat_env6, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_2).');
                    gg_p_sim6 <- ggplot(mat_p_sim6, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_2).');
                    gg_eff_sim6 <- ggplot(mat_eff_sim6, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_2).');
                    ggsave(\''.$env_effects_sim_figure_tempfile_3_env6.'\', arrangeGrob(gg_env6, gg_p_sim6, gg_eff_sim6, nrow=1), device=\'png\', width=25, height=25, units=\'in\');
                    "';
                    # print STDERR Dumper $cmd_spatialenvsim_plot_3_env6;
                    my $status_spatialenvsim_plot_3_env6 = system($cmd_spatialenvsim_plot_3_env6);
                    push @$spatial_effects_plots, [$env_effects_sim_figure_tempfile_string_3_env6, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_env6effheatmap_"."envvar_".$env_variance_percent."_".$iterations];
                };

                eval {
                    my @sorted_germplasm_names = sort keys %unique_accessions;

                    my @original_blup_vals_3;
                    my ($effects_original_line_chart_tempfile_fh_3, $effects_original_line_chart_tempfile_3) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open(my $F_pheno, ">", $effects_original_line_chart_tempfile_3) || die "Can't open file ".$effects_original_line_chart_tempfile_3;
                        print $F_pheno "germplasmName,time,value\n";
                        foreach my $p (@sorted_germplasm_names) {
                            foreach my $t (@sorted_trait_names_2) {
                                my $val = $result_blup_data_original_3->{$p}->{$t}->[0];
                                my @row = ($p, $trait_to_time_map_2{$t}, $val);
                                push @original_blup_vals_3, $val;
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                            }
                        }
                    close($F_pheno);

                    my $original_blup_stat_3 = Statistics::Descriptive::Full->new();
                    $original_blup_stat_3->add_data(@original_blup_vals_3);
                    my $sig_original_blup_3 = $original_blup_stat_3->variance();

                    my @altered_blups_vals_3;
                    my ($effects_altered_line_chart_tempfile_fh_3, $effects_altered_line_chart_tempfile_3) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $effects_altered_line_chart_tempfile_3) || die "Can't open file ".$effects_altered_line_chart_tempfile_3;
                        print $F_pheno "germplasmName,time,value\n";
                        foreach my $p (@sorted_germplasm_names) {
                            foreach my $t (@sorted_trait_names_2) {
                                my $val = $result_blup_data_altered_3->{$p}->{$t}->[0];
                                my @row = ($p, $trait_to_time_map_2{$t}, $val);
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                                push @altered_blups_vals_3, $val;
                            }
                        }
                    close($F_pheno);

                    my $altered_blup_stat_3 = Statistics::Descriptive::Full->new();
                    $altered_blup_stat_3->add_data(@altered_blups_vals_3);
                    my $sig_altered_blup_3 = $altered_blup_stat_3->variance();

                    my @sim1_blup_vals_3;
                    my ($effects_altered_env1_line_chart_tempfile_fh_3, $effects_altered_env1_line_chart_tempfile_3) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $effects_altered_env1_line_chart_tempfile_3) || die "Can't open file ".$effects_altered_env1_line_chart_tempfile_3;
                        print $F_pheno "germplasmName,time,value\n";
                        foreach my $p (@sorted_germplasm_names) {
                            foreach my $t (@sorted_trait_names_2) {
                                my $val = $result_blup_data_altered_env_1_3->{$p}->{$t}->[0];
                                my @row = ($p, $trait_to_time_map_2{$t}, $val);
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                                push @sim1_blup_vals_3, $val;
                            }
                        }
                    close($F_pheno);

                    my $sim1_blup_stat_3 = Statistics::Descriptive::Full->new();
                    $sim1_blup_stat_3->add_data(@sim1_blup_vals_3);
                    my $sig_sim1_blup_3 = $sim1_blup_stat_3->variance();

                    my @sim2_blup_vals_3;
                    my ($effects_altered_env2_line_chart_tempfile_fh_3, $effects_altered_env2_line_chart_tempfile_3) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $effects_altered_env2_line_chart_tempfile_3) || die "Can't open file ".$effects_altered_env2_line_chart_tempfile_3;
                        print $F_pheno "germplasmName,time,value\n";
                        foreach my $p (@sorted_germplasm_names) {
                            foreach my $t (@sorted_trait_names_2) {
                                my $val = $result_blup_data_altered_env_2_3->{$p}->{$t}->[0];
                                my @row = ($p, $trait_to_time_map_2{$t}, $val);
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                                push @sim2_blup_vals_3, $val;
                            }
                        }
                    close($F_pheno);

                    my $sim2_blup_stat_3 = Statistics::Descriptive::Full->new();
                    $sim2_blup_stat_3->add_data(@sim2_blup_vals_3);
                    my $sig_sim2_blup_3 = $sim2_blup_stat_3->variance();

                    my @sim3_blup_vals_3;
                    my ($effects_altered_env3_line_chart_tempfile_fh_3, $effects_altered_env3_line_chart_tempfile_3) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $effects_altered_env3_line_chart_tempfile_3) || die "Can't open file ".$effects_altered_env3_line_chart_tempfile_3;
                        print $F_pheno "germplasmName,time,value\n";
                        foreach my $p (@sorted_germplasm_names) {
                            foreach my $t (@sorted_trait_names_2) {
                                my $val = $result_blup_data_altered_env_3_3->{$p}->{$t}->[0];
                                my @row = ($p, $trait_to_time_map_2{$t}, $val);
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                                push @sim3_blup_vals_3, $val;
                            }
                        }
                    close($F_pheno);

                    my $sim3_blup_stat_3 = Statistics::Descriptive::Full->new();
                    $sim3_blup_stat_3->add_data(@sim3_blup_vals_3);
                    my $sig_sim3_blup_3 = $sim3_blup_stat_3->variance();

                    my @sim4_blup_vals_3;
                    my ($effects_altered_env4_line_chart_tempfile_fh_3, $effects_altered_env4_line_chart_tempfile_3) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $effects_altered_env4_line_chart_tempfile_3) || die "Can't open file ".$effects_altered_env4_line_chart_tempfile_3;
                        print $F_pheno "germplasmName,time,value\n";
                        foreach my $p (@sorted_germplasm_names) {
                            foreach my $t (@sorted_trait_names_2) {
                                my $val = $result_blup_data_altered_env_4_3->{$p}->{$t}->[0];
                                my @row = ($p, $trait_to_time_map_2{$t}, $val);
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                                push @sim4_blup_vals_3, $val;
                            }
                        }
                    close($F_pheno);

                    my $sim4_blup_stat_3 = Statistics::Descriptive::Full->new();
                    $sim4_blup_stat_3->add_data(@sim4_blup_vals_3);
                    my $sig_sim4_blup_3 = $sim4_blup_stat_3->variance();

                    my @sim5_blup_vals_3;
                    my ($effects_altered_env5_line_chart_tempfile_fh_3, $effects_altered_env5_line_chart_tempfile_3) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $effects_altered_env5_line_chart_tempfile_3) || die "Can't open file ".$effects_altered_env5_line_chart_tempfile_3;
                        print $F_pheno "germplasmName,time,value\n";
                        foreach my $p (@sorted_germplasm_names) {
                            foreach my $t (@sorted_trait_names_2) {
                                my $val = $result_blup_data_altered_env_5_3->{$p}->{$t}->[0];
                                my @row = ($p, $trait_to_time_map_2{$t}, $val);
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                                push @sim5_blup_vals_3, $val;
                            }
                        }
                    close($F_pheno);

                    my $sim5_blup_stat_3 = Statistics::Descriptive::Full->new();
                    $sim5_blup_stat_3->add_data(@sim5_blup_vals_3);
                    my $sig_sim5_blup_3 = $sim5_blup_stat_3->variance();

                    my @sim6_blup_vals_3;
                    my ($effects_altered_env6_line_chart_tempfile_fh_3, $effects_altered_env6_line_chart_tempfile_3) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $effects_altered_env6_line_chart_tempfile_3) || die "Can't open file ".$effects_altered_env6_line_chart_tempfile_3;
                        print $F_pheno "germplasmName,time,value\n";
                        foreach my $p (@sorted_germplasm_names) {
                            foreach my $t (@sorted_trait_names_2) {
                                my $val = $result_blup_data_altered_env_6_3->{$p}->{$t}->[0];
                                my @row = ($p, $trait_to_time_map_2{$t}, $val);
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                                push @sim6_blup_vals_3, $val;
                            }
                        }
                    close($F_pheno);

                    my $sim6_blup_stat_3 = Statistics::Descriptive::Full->new();
                    $sim6_blup_stat_3->add_data(@sim6_blup_vals_3);
                    my $sig_sim6_blup_3 = $sim6_blup_stat_3->variance();

                    my @set = ('0' ..'9', 'A' .. 'F');
                    my @colors;
                    for (1..scalar(@sorted_germplasm_names)) {
                        my $str = join '' => map $set[rand @set], 1 .. 6;
                        push @colors, '#'.$str;
                    }
                    my $color_string = join '\',\'', @colors;

                    my $genetic_effects_figure_tempfile_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $genetic_effects_figure_tempfile_string .= '.png';
                    my $genetic_effects_figure_tempfile = $c->config->{basepath}."/".$genetic_effects_figure_tempfile_string;

                    my $genetic_effects_alt_figure_tempfile_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $genetic_effects_alt_figure_tempfile_string .= '.png';
                    my $genetic_effects_alt_figure_tempfile = $c->config->{basepath}."/".$genetic_effects_alt_figure_tempfile_string;

                    my $genetic_effects_alt_env1_figure_tempfile_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $genetic_effects_alt_env1_figure_tempfile_string .= '.png';
                    my $genetic_effects_alt_env1_figure_tempfile = $c->config->{basepath}."/".$genetic_effects_alt_env1_figure_tempfile_string;

                    my $genetic_effects_alt_env2_figure_tempfile_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $genetic_effects_alt_env2_figure_tempfile_string .= '.png';
                    my $genetic_effects_alt_env2_figure_tempfile = $c->config->{basepath}."/".$genetic_effects_alt_env2_figure_tempfile_string;

                    my $genetic_effects_alt_env3_figure_tempfile_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $genetic_effects_alt_env3_figure_tempfile_string .= '.png';
                    my $genetic_effects_alt_env3_figure_tempfile = $c->config->{basepath}."/".$genetic_effects_alt_env3_figure_tempfile_string;

                    my $genetic_effects_alt_env4_figure_tempfile_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $genetic_effects_alt_env4_figure_tempfile_string .= '.png';
                    my $genetic_effects_alt_env4_figure_tempfile = $c->config->{basepath}."/".$genetic_effects_alt_env4_figure_tempfile_string;

                    my $genetic_effects_alt_env5_figure_tempfile_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $genetic_effects_alt_env5_figure_tempfile_string .= '.png';
                    my $genetic_effects_alt_env5_figure_tempfile = $c->config->{basepath}."/".$genetic_effects_alt_env5_figure_tempfile_string;

                    my $genetic_effects_alt_env6_figure_tempfile_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $genetic_effects_alt_env6_figure_tempfile_string .= '.png';
                    my $genetic_effects_alt_env6_figure_tempfile = $c->config->{basepath}."/".$genetic_effects_alt_env6_figure_tempfile_string;

                    my $cmd_gen_plot = 'R -e "library(data.table); library(ggplot2); library(GGally); library(gridExtra);
                    mat <- fread(\''.$effects_original_line_chart_tempfile_3.'\', header=TRUE, sep=\',\');
                    mat\$time <- as.numeric(as.character(mat\$time));
                    options(device=\'png\');
                    par();
                    sp <- ggplot(mat, aes(x = time, y = value)) +
                        geom_line(aes(color = germplasmName), size = 1) +
                        scale_fill_manual(values = c(\''.$color_string.'\')) +
                        theme_minimal();
                    sp <- sp + guides(shape = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + guides(color = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + theme(legend.title = element_text(size = 3), legend.text = element_text(size = 3));
                    sp <- sp + labs(title = \'Original Genetic Effects\');';
                    if (scalar(@sorted_germplasm_names) > 100) {
                        $cmd_gen_plot .= 'sp <- sp + theme(legend.position = \'none\');';
                    }
                    $cmd_gen_plot .= 'ggsave(\''.$genetic_effects_figure_tempfile.'\', sp, device=\'png\', width=12, height=6, units=\'in\');
                    "';
                    print STDERR Dumper $cmd_gen_plot;
                    my $status_gen_plot = system($cmd_gen_plot);
                    push @$spatial_effects_plots, [$genetic_effects_figure_tempfile_string, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_efforigline_"."envvar_".$env_variance_percent."_".$iterations];

                    my $cmd_gen_alt_plot = 'R -e "library(data.table); library(ggplot2); library(GGally); library(gridExtra);
                    mat <- fread(\''.$effects_altered_line_chart_tempfile_3.'\', header=TRUE, sep=\',\');
                    mat\$time <- as.numeric(as.character(mat\$time));
                    options(device=\'png\');
                    par();
                    sp <- ggplot(mat, aes(x = time, y = value)) +
                        geom_line(aes(color = germplasmName), size = 1) +
                        scale_fill_manual(values = c(\''.$color_string.'\')) +
                        theme_minimal();
                    sp <- sp + guides(shape = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + guides(color = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + theme(legend.title = element_text(size = 3), legend.text = element_text(size = 3));
                    sp <- sp + labs(title = \'Altered Genetic Effects\');';
                    if (scalar(@sorted_germplasm_names) > 100) {
                        $cmd_gen_alt_plot .= 'sp <- sp + theme(legend.position = \'none\');';
                    }
                    $cmd_gen_alt_plot .= 'ggsave(\''.$genetic_effects_alt_figure_tempfile.'\', sp, device=\'png\', width=12, height=6, units=\'in\');
                    "';
                    print STDERR Dumper $cmd_gen_alt_plot;
                    my $status_gen_alt_plot = system($cmd_gen_alt_plot);
                    push @$spatial_effects_plots, [$genetic_effects_alt_figure_tempfile_string, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_effaltline_"."envvar_".$env_variance_percent."_".$iterations];

                    my $cmd_gen_env1_plot = 'R -e "library(data.table); library(ggplot2); library(GGally); library(gridExtra);
                    mat <- fread(\''.$effects_altered_env1_line_chart_tempfile_3.'\', header=TRUE, sep=\',\');
                    mat\$time <- as.numeric(as.character(mat\$time));
                    options(device=\'png\');
                    par();
                    sp <- ggplot(mat, aes(x = time, y = value)) +
                        geom_line(aes(color = germplasmName), size = 1) +
                        scale_fill_manual(values = c(\''.$color_string.'\')) +
                        theme_minimal();
                    sp <- sp + guides(shape = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + guides(color = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + theme(legend.title = element_text(size = 3), legend.text = element_text(size = 3));
                    sp <- sp + labs(title = \'SimLinear Genetic Effects\');';
                    if (scalar(@sorted_germplasm_names) > 100) {
                        $cmd_gen_env1_plot .= 'sp <- sp + theme(legend.position = \'none\');';
                    }
                    $cmd_gen_env1_plot .= 'ggsave(\''.$genetic_effects_alt_env1_figure_tempfile.'\', sp, device=\'png\', width=12, height=6, units=\'in\');
                    "';
                    print STDERR Dumper $cmd_gen_env1_plot;
                    my $status_gen_env1_plot = system($cmd_gen_env1_plot);
                    push @$spatial_effects_plots, [$genetic_effects_alt_env1_figure_tempfile_string, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_effaltenv1line_"."envvar_".$env_variance_percent."_".$iterations];

                    my $cmd_gen_env2_plot = 'R -e "library(data.table); library(ggplot2); library(GGally); library(gridExtra);
                    mat <- fread(\''.$effects_altered_env2_line_chart_tempfile_3.'\', header=TRUE, sep=\',\');
                    mat\$time <- as.numeric(as.character(mat\$time));
                    options(device=\'png\');
                    par();
                    sp <- ggplot(mat, aes(x = time, y = value)) +
                        geom_line(aes(color = germplasmName), size = 1) +
                        scale_fill_manual(values = c(\''.$color_string.'\')) +
                        theme_minimal();
                    sp <- sp + guides(shape = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + guides(color = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + theme(legend.title = element_text(size = 3), legend.text = element_text(size = 3));
                    sp <- sp + labs(title = \'Sim1DN Genetic Effects\');';
                    if (scalar(@sorted_germplasm_names) > 100) {
                        $cmd_gen_env2_plot .= 'sp <- sp + theme(legend.position = \'none\');';
                    }
                    $cmd_gen_env2_plot .= 'ggsave(\''.$genetic_effects_alt_env2_figure_tempfile.'\', sp, device=\'png\', width=12, height=6, units=\'in\');
                    "';
                    print STDERR Dumper $cmd_gen_env2_plot;
                    my $status_gen_env2_plot = system($cmd_gen_env2_plot);
                    push @$spatial_effects_plots, [$genetic_effects_alt_env2_figure_tempfile_string, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_effaltenv2line_"."envvar_".$env_variance_percent."_".$iterations];

                    my $cmd_gen_env3_plot = 'R -e "library(data.table); library(ggplot2); library(GGally); library(gridExtra);
                    mat <- fread(\''.$effects_altered_env3_line_chart_tempfile_3.'\', header=TRUE, sep=\',\');
                    mat\$time <- as.numeric(as.character(mat\$time));
                    options(device=\'png\');
                    par();
                    sp <- ggplot(mat, aes(x = time, y = value)) +
                        geom_line(aes(color = germplasmName), size = 1) +
                        scale_fill_manual(values = c(\''.$color_string.'\')) +
                        theme_minimal();
                    sp <- sp + guides(shape = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + guides(color = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + theme(legend.title = element_text(size = 3), legend.text = element_text(size = 3));
                    sp <- sp + labs(title = \'Sim2DN Genetic Effects\');';
                    if (scalar(@sorted_germplasm_names) > 100) {
                        $cmd_gen_env3_plot .= 'sp <- sp + theme(legend.position = \'none\');';
                    }
                    $cmd_gen_env3_plot .= 'ggsave(\''.$genetic_effects_alt_env3_figure_tempfile.'\', sp, device=\'png\', width=12, height=6, units=\'in\');
                    "';
                    print STDERR Dumper $cmd_gen_env3_plot;
                    my $status_gen_env3_plot = system($cmd_gen_env3_plot);
                    push @$spatial_effects_plots, [$genetic_effects_alt_env3_figure_tempfile_string, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_effaltenv3line_"."envvar_".$env_variance_percent."_".$iterations];

                    my $cmd_gen_env4_plot = 'R -e "library(data.table); library(ggplot2); library(GGally); library(gridExtra);
                    mat <- fread(\''.$effects_altered_env4_line_chart_tempfile_3.'\', header=TRUE, sep=\',\');
                    mat\$time <- as.numeric(as.character(mat\$time));
                    options(device=\'png\');
                    par();
                    sp <- ggplot(mat, aes(x = time, y = value)) +
                        geom_line(aes(color = germplasmName), size = 1) +
                        scale_fill_manual(values = c(\''.$color_string.'\')) +
                        theme_minimal();
                    sp <- sp + guides(shape = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + guides(color = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + theme(legend.title = element_text(size = 3), legend.text = element_text(size = 3));
                    sp <- sp + labs(title = \'SimRandom Genetic Effects\');';
                    if (scalar(@sorted_germplasm_names) > 100) {
                        $cmd_gen_env4_plot .= 'sp <- sp + theme(legend.position = \'none\');';
                    }
                    $cmd_gen_env4_plot .= 'ggsave(\''.$genetic_effects_alt_env4_figure_tempfile.'\', sp, device=\'png\', width=12, height=6, units=\'in\');
                    "';
                    print STDERR Dumper $cmd_gen_env4_plot;
                    my $status_gen_env4_plot = system($cmd_gen_env4_plot);
                    push @$spatial_effects_plots, [$genetic_effects_alt_env4_figure_tempfile_string, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_effaltenv4line_"."envvar_".$env_variance_percent."_".$iterations];

                    my $cmd_gen_env5_plot = 'R -e "library(data.table); library(ggplot2); library(GGally); library(gridExtra);
                    mat <- fread(\''.$effects_altered_env5_line_chart_tempfile_3.'\', header=TRUE, sep=\',\');
                    mat\$time <- as.numeric(as.character(mat\$time));
                    options(device=\'png\');
                    par();
                    sp <- ggplot(mat, aes(x = time, y = value)) +
                        geom_line(aes(color = germplasmName), size = 1) +
                        scale_fill_manual(values = c(\''.$color_string.'\')) +
                        theme_minimal();
                    sp <- sp + guides(shape = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + guides(color = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + theme(legend.title = element_text(size = 3), legend.text = element_text(size = 3));
                    sp <- sp + labs(title = \'SimRandom Genetic Effects\');';
                    if (scalar(@sorted_germplasm_names) > 100) {
                        $cmd_gen_env5_plot .= 'sp <- sp + theme(legend.position = \'none\');';
                    }
                    $cmd_gen_env5_plot .= 'ggsave(\''.$genetic_effects_alt_env5_figure_tempfile.'\', sp, device=\'png\', width=12, height=6, units=\'in\');
                    "';
                    print STDERR Dumper $cmd_gen_env5_plot;
                    my $status_gen_env5_plot = system($cmd_gen_env5_plot);
                    push @$spatial_effects_plots, [$genetic_effects_alt_env5_figure_tempfile_string, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_effaltenv5line_"."envvar_".$env_variance_percent."_".$iterations];

                    my $cmd_gen_env6_plot = 'R -e "library(data.table); library(ggplot2); library(GGally); library(gridExtra);
                    mat <- fread(\''.$effects_altered_env6_line_chart_tempfile_3.'\', header=TRUE, sep=\',\');
                    mat\$time <- as.numeric(as.character(mat\$time));
                    options(device=\'png\');
                    par();
                    sp <- ggplot(mat, aes(x = time, y = value)) +
                        geom_line(aes(color = germplasmName), size = 1) +
                        scale_fill_manual(values = c(\''.$color_string.'\')) +
                        theme_minimal();
                    sp <- sp + guides(shape = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + guides(color = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + theme(legend.title = element_text(size = 3), legend.text = element_text(size = 3));
                    sp <- sp + labs(title = \'SimRandom Genetic Effects\');';
                    if (scalar(@sorted_germplasm_names) > 100) {
                        $cmd_gen_env6_plot .= 'sp <- sp + theme(legend.position = \'none\');';
                    }
                    $cmd_gen_env6_plot .= 'ggsave(\''.$genetic_effects_alt_env6_figure_tempfile.'\', sp, device=\'png\', width=12, height=6, units=\'in\');
                    "';
                    print STDERR Dumper $cmd_gen_env6_plot;
                    my $status_gen_env6_plot = system($cmd_gen_env6_plot);
                    push @$spatial_effects_plots, [$genetic_effects_alt_env6_figure_tempfile_string, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_effaltenv6line_"."envvar_".$env_variance_percent."_".$iterations];
                };

                %trait_name_encoder = %trait_name_encoder_2;
                %trait_to_time_map = %trait_to_time_map_2;

                push @$env_varcomps, {
                    type => "$statistics_select: Env Variance $env_variance_percent : SimCorrelation: $correlation_between_times : Iteration $iterations",
                    statistics_select => "$statistics_select: Env Variance $env_variance_percent : SimCorrelation: $correlation_between_times",
                    correlation_between_times => $correlation_between_times,
                    env_variance => $env_variance_percent,
                    original => {
                        covariance => $varcomp_original_array_3,
                        cv_1 => $result_cv_original_3,
                        cv_2 => $result_cv_2_original_3
                    },
                    altered => {
                        covariance => $varcomp_altered_array_3,
                        cv_1 => $result_cv_altered_3,
                        cv_2 => $result_cv_2_altered_3
                    },
                    env_linear => {
                        covariance => $varcomp_altered_array_env_1_3,
                        cv_1 => $result_cv_altered_env_1_3,
                        cv_2 => $result_cv_2_altered_env_1_3
                    },
                    env_1DN  => {
                        covariance => $varcomp_altered_array_env_2_3,
                        cv_1 => $result_cv_altered_env_2_3,
                        cv_2 => $result_cv_2_altered_env_2_3
                    },
                    env_2DN  => {
                        covariance => $varcomp_altered_array_env_3_3,
                        cv_1 => $result_cv_altered_env_3_3,
                        cv_2 => $result_cv_2_altered_env_3_3
                    },
                    env_random  => {
                        covariance => $varcomp_altered_array_env_4_3,
                        cv_1 => $result_cv_altered_env_4_3,
                        cv_2 => $result_cv_2_altered_env_4_3
                    },
                    env_ar1xar1  => {
                        covariance => $varcomp_altered_array_env_5_3,
                        cv_1 => $result_cv_altered_env_5_3,
                        cv_2 => $result_cv_2_altered_env_5_3
                    },
                    env_realdata  => {
                        covariance => $varcomp_altered_array_env_6_3,
                        cv_1 => $result_cv_altered_env_6_3,
                        cv_2 => $result_cv_2_altered_env_6_3
                    }
                };
            }

            my $return_inverse_matrix = 0;
            my $ensure_positive_definite = 1;

            my (%phenotype_data_original_5, @data_matrix_original_5, @data_matrix_phenotypes_original_5);
            my (%trait_name_encoder_5, %trait_name_encoder_rev_5, %seen_days_after_plantings_5, %stock_info_5, %seen_times_5, %seen_trial_ids_5, %trait_to_time_map_5, %trait_composing_info_5, @sorted_trait_names_5, %seen_trait_names_5, %unique_traits_ids_5, @phenotype_header_5, $header_string_5);
            my (@sorted_scaled_ln_times_5, %plot_id_factor_map_reverse_5, %plot_id_count_map_reverse_5, %accession_id_factor_map_5, %accession_id_factor_map_reverse_5, %time_count_map_reverse_5, @rep_time_factors_5, @ind_rep_factors_5, %plot_rep_time_factor_map_5, %seen_rep_times_5, %seen_ind_reps_5, @legs_header_5, %polynomial_map_5);
            my $time_min_5 = 100000000;
            my $time_max_5 = 0;
            my $phenotype_min_original_5 = 1000000000;
            my $phenotype_max_original_5 = -1000000000;

            if ($statistics_select_original eq 'asreml_grm_univariate_spatial_genetic_blups' || $statistics_select_original eq 'asreml_grm_univariate_pure_spatial_genetic_blups') {
                $statistics_select = $statistics_select_original;

                print STDERR "PREPARE ORIGINAL PHENOTYPE FILES 5\n";
                eval {
                    my $phenotypes_search_5 = CXGN::Phenotypes::SearchFactory->instantiate(
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
                    my ($data_5, $unique_traits_5) = $phenotypes_search_5->search();
                    @sorted_trait_names_5 = sort keys %$unique_traits_5;

                    if (scalar(@$data_5) == 0) {
                        $c->stash->{rest} = { error => "There are no phenotypes for the trials and traits you have selected!"};
                        return;
                    }

                    $q_time = "SELECT t.cvterm_id FROM cvterm as t JOIN cv ON(t.cv_id=cv.cv_id) WHERE t.name=? and cv.name=?;";
                    $h_time = $schema->storage->dbh()->prepare($q_time);

                    foreach my $obs_unit (@$data_5){
                        my $germplasm_name = $obs_unit->{germplasm_uniquename};
                        my $germplasm_stock_id = $obs_unit->{germplasm_stock_id};
                        my $replicate_number = $obs_unit->{obsunit_rep} || '';
                        my $block_number = $obs_unit->{obsunit_block} || '';
                        my $obsunit_stock_id = $obs_unit->{observationunit_stock_id};
                        my $obsunit_stock_uniquename = $obs_unit->{observationunit_uniquename};
                        my $row_number = $obs_unit->{obsunit_row_number} || '';
                        my $col_number = $obs_unit->{obsunit_col_number} || '';
                        push @plot_ids_ordered, $obsunit_stock_id;

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

                        $obsunit_row_col{$row_number}->{$col_number} = {
                            stock_id => $obsunit_stock_id,
                            stock_uniquename => $obsunit_stock_uniquename
                        };
                        $seen_rows{$row_number}++;
                        $seen_cols{$col_number}++;
                        $plot_id_map{$obsunit_stock_id} = $obsunit_stock_uniquename;
                        $seen_plot_names{$obsunit_stock_uniquename}++;
                        $seen_plots{$obsunit_stock_id} = $obsunit_stock_uniquename;
                        $stock_row_col{$obsunit_stock_id} = {
                            row_number => $row_number,
                            col_number => $col_number,
                            obsunit_stock_id => $obsunit_stock_id,
                            obsunit_name => $obsunit_stock_uniquename,
                            rep => $replicate_number,
                            block => $block_number,
                            germplasm_stock_id => $germplasm_stock_id,
                            germplasm_name => $germplasm_name
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
                        $stock_row_col_id{$row_number}->{$col_number} = $obsunit_stock_id;
                        $unique_accessions{$germplasm_name}++;
                        $stock_info_5{$germplasm_stock_id} = {
                            uniquename => $germplasm_name
                        };
                        my $observations = $obs_unit->{observations};
                        foreach (@$observations){
                            if ($_->{associated_image_project_time_json}) {
                                my $related_time_terms_json = decode_json $_->{associated_image_project_time_json};
                                my $time_days_cvterm = $related_time_terms_json->{day};
                                my $time_term_string = $time_days_cvterm;
                                my $time_days = (split '\|', $time_days_cvterm)[0];
                                my $time = (split ' ', $time_days)[1] + 0;
                                $seen_days_after_plantings_5{$time}++;

                                my $value = $_->{value};
                                my $trait_name = $_->{trait_name};
                                $phenotype_data_original_5{$obsunit_stock_uniquename}->{$time} = $value;
                                $seen_times_5{$time} = $trait_name;
                                $seen_trait_names_5{$trait_name} = $time_term_string;
                                $trait_to_time_map_5{$trait_name} = $time;

                                if ($value < $phenotype_min_original_5) {
                                    $phenotype_min_original_5 = $value;
                                }
                                elsif ($value >= $phenotype_max_original_5) {
                                    $phenotype_max_original_5 = $value;
                                }
                            }
                        }
                    }
                    if (scalar(keys %seen_times_5) == 0) {
                        $c->stash->{rest} = { error => "There are no phenotypes with associated days after planting time associated to the traits you have selected!"};
                        return;
                    }

                    @unique_accession_names = sort keys %unique_accessions;
                    @sorted_trait_names_5 = sort {$a <=> $b} keys %seen_times_5;
                    # print STDERR Dumper \@sorted_trait_names_5;

                    my $trait_name_encoded_5 = 1;
                    foreach my $trait_name (@sorted_trait_names_5) {
                        if (!exists($trait_name_encoder_5{$trait_name})) {
                            my $trait_name_e = 't'.$trait_name_encoded_5;
                            $trait_name_encoder_5{$trait_name} = $trait_name_e;
                            $trait_name_encoder_rev_5{$trait_name_e} = $trait_name;
                            $trait_name_encoded_5++;
                        }
                    }

                    foreach (@sorted_trait_names_5) {
                        if ($_ < $time_min_5) {
                            $time_min_5 = $_;
                        }
                        if ($_ >= $time_max_5) {
                            $time_max_5 = $_;
                        }
                    }
                    print STDERR Dumper [$time_min_5, $time_max_5];

                    while ( my ($trait_name, $time_term) = each %seen_trait_names_5) {
                        push @{$trait_composing_info_5{$trait_name}}, $time_term;
                    }

                    @unique_plot_names = sort keys %seen_plot_names;

                    open(my $F_prep, ">", $stats_prep_tempfile) || die "Can't open file ".$stats_prep_tempfile;
                        print $F_prep "accession_id,accession_id_factor,plot_id,plot_id_factor,replicate,time,replicate_time,ind_replicate\n";
                        foreach my $p (@unique_plot_names) {
                            my $replicate = $stock_name_row_col{$p}->{rep};
                            my $germplasm_stock_id = $stock_name_row_col{$p}->{germplasm_stock_id};
                            my $obsunit_stock_id = $stock_name_row_col{$p}->{obsunit_stock_id};
                            foreach my $t (@sorted_trait_names_5) {
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
                    my $status_factor = system($cmd_factor);

                    open(my $fh_factor, '<', $stats_prep_factor_tempfile) or die "Could not open file '$stats_prep_factor_tempfile' $!";
                        print STDERR "Opened $stats_prep_factor_tempfile\n";
                        my $header_d = <$fh_factor>;

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
                            $stock_row_col{$plot_id}->{plot_id_factor} = $plot_id_factor;
                            $stock_name_row_col{$plot_id_map{$plot_id}}->{plot_id_factor} = $plot_id_factor;
                            $plot_rep_time_factor_map{$plot_id}->{$rep}->{$time} = $rep_time;
                            $seen_rep_times{$rep_time}++;
                            $seen_ind_reps{$plot_id_factor}++;
                            $accession_id_factor_map{$accession_id} = $accession_id_factor;
                            $accession_id_factor_map_reverse{$accession_id_factor} = $stock_info_5{$accession_id}->{uniquename};
                            $plot_id_factor_map_reverse{$plot_id_factor} = $seen_plots{$plot_id};
                            $plot_id_count_map_reverse{$line_factor_count} = $seen_plots{$plot_id};
                            $time_count_map_reverse{$line_factor_count} = $time;
                            $line_factor_count++;
                        }
                    close($fh_factor);
                    @rep_time_factors = sort keys %seen_rep_times;
                    @ind_rep_factors = sort keys %seen_ind_reps;

                    foreach my $p (@unique_plot_names) {
                        my $obsunit_stock_id = $stock_name_row_col{$p}->{obsunit_stock_id};
                        if ($fixed_effect_type eq 'fixed_effect_trait') {
                            $stock_name_row_col{$p}->{rep} = defined($fixed_effect_trait_data->{$obsunit_stock_id}) ? $fixed_effect_trait_data->{$obsunit_stock_id} : 0;
                        }
                        my $row_number = $stock_name_row_col{$p}->{row_number};
                        my $col_number = $stock_name_row_col{$p}->{col_number};
                        my $replicate = $stock_name_row_col{$p}->{rep};
                        my $block = $stock_name_row_col{$p}->{block};
                        my $germplasm_stock_id = $stock_name_row_col{$p}->{germplasm_stock_id};
                        my $germplasm_name = $stock_name_row_col{$p}->{germplasm_name};

                        my $current_trait_index = 0;
                        my @row = (
                            $germplasm_stock_id,
                            $obsunit_stock_id,
                            $replicate,
                            $row_number,
                            $col_number,
                            $accession_id_factor_map{$germplasm_stock_id},
                            $stock_row_col{$obsunit_stock_id}->{plot_id_factor}
                        );

                        foreach my $t (@sorted_trait_names_5) {
                            if (defined($phenotype_data_original_5{$p}->{$t})) {
                                push @row, $phenotype_data_original_5{$p}->{$t} + 0;
                            } else {
                                print STDERR $p." : $t : $germplasm_name : NA \n";
                                push @row, '';
                            }

                            $current_trait_index++;
                        }
                        push @data_matrix_original_5, \@row;
                    }

                    @phenotype_header_5 = ("id", "plot_id", "replicate", "rowNumber", "colNumber", "id_factor", "plot_id_factor");
                    foreach (@sorted_trait_names_5) {
                        push @phenotype_header_5, "t$_";
                    }
                    $header_string_5 = join ',', @phenotype_header_5;

                    open($F, ">", $stats_tempfile_2) || die "Can't open file ".$stats_tempfile_2;
                        print $F $header_string_5."\n";
                        foreach (@data_matrix_original_5) {
                            my $line = join ',', @$_;
                            print $F "$line\n";
                        }
                    close($F);
                };

                @seen_rows_array = keys %seen_rows;
                @seen_cols_array = keys %seen_cols;
                $row_stat = Statistics::Descriptive::Full->new();
                $row_stat->add_data(@seen_rows_array);
                $mean_row = $row_stat->mean();
                $sig_row = $row_stat->variance();
                $col_stat = Statistics::Descriptive::Full->new();
                $col_stat->add_data(@seen_cols_array);
                $mean_col = $col_stat->mean();
                $sig_col = $col_stat->variance();

                print STDERR "PREPARE RELATIONSHIP MATRIX\n";
                eval {
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
                            ';
                            if ($return_inverse_matrix) {
                                $cmd .= 'A <- solve(A);
                                ';
                            }
                            $cmd .= 'A <- as.data.frame(A);
                            colnames(A) <- A_wide[,1];
                            A\$stock_id <- A_wide[,1];
                            A_threecol <- melt(A, id.vars = c(\'stock_id\'), measure.vars = A_wide[,1]);
                            A_threecol\$stock_id <- substring(A_threecol\$stock_id, 2);
                            A_threecol\$variable <- substring(A_threecol\$variable, 2);
                            write.table(data.frame(variable = A_threecol\$variable, stock_id = A_threecol\$stock_id, value = A_threecol\$value), file=\''.$grm_out_tempfile.'\', row.names=FALSE, col.names=FALSE, sep=\'\t\');"';
                            print STDERR $cmd."\n";
                            my $status = system($cmd);

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
                            if ($statistics_select eq 'blupf90_grm_random_regression_gdd_blups' || $statistics_select eq 'blupf90_grm_random_regression_dap_blups' || $statistics_select eq 'airemlf90_grm_random_regression_gdd_blups' || $statistics_select eq 'airemlf90_grm_random_regression_dap_blups' || $statistics_select eq 'asreml_grm_univariate_spatial_genetic_blups' || $statistics_select eq 'asreml_grm_univariate_pure_spatial_genetic_blups') {
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
                            ';
                            if ($return_inverse_matrix) {
                                $cmd .= 'A <- solve(A);
                                ';
                            }
                            $cmd .= 'A <- as.data.frame(A);
                            colnames(A) <- A_wide[,1];
                            A\$stock_id <- A_wide[,1];
                            A_threecol <- melt(A, id.vars = c(\'stock_id\'), measure.vars = A_wide[,1]);
                            A_threecol\$stock_id <- substring(A_threecol\$stock_id, 2);
                            A_threecol\$variable <- substring(A_threecol\$variable, 2);
                            write.table(data.frame(variable = A_threecol\$variable, stock_id = A_threecol\$stock_id, value = A_threecol\$value), file=\''.$grm_out_tempfile.'\', row.names=FALSE, col.names=FALSE, sep=\'\t\');"';
                            print STDERR $cmd."\n";
                            my $status = system($cmd);

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
                            if ($statistics_select eq 'blupf90_grm_random_regression_gdd_blups' || $statistics_select eq 'blupf90_grm_random_regression_dap_blups' || $statistics_select eq 'airemlf90_grm_random_regression_gdd_blups' || $statistics_select eq 'airemlf90_grm_random_regression_dap_blups' || $statistics_select eq 'asreml_grm_univariate_spatial_genetic_blups' || $statistics_select eq 'asreml_grm_univariate_pure_spatial_genetic_blups') {
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
                                return_inverse=>$return_inverse_matrix,
                                ensure_positive_definite=>$ensure_positive_definite
                                # minor_allele_frequency=>$minor_allele_frequency,
                                # marker_filter=>$marker_filter,
                                # individuals_filter=>$individuals_filter
                            };

                            if ($statistics_select eq 'blupf90_grm_random_regression_gdd_blups' || $statistics_select eq 'blupf90_grm_random_regression_dap_blups' || $statistics_select eq 'airemlf90_grm_random_regression_gdd_blups' || $statistics_select eq 'airemlf90_grm_random_regression_dap_blups' || $statistics_select eq 'asreml_grm_univariate_spatial_genetic_blups' || $statistics_select eq 'asreml_grm_univariate_pure_spatial_genetic_blups') {
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
                            ';
                            if ($return_inverse_matrix) {
                                $htp_cmd .= 'cor_mat <- solve(cor_mat);
                                ';
                            }
                            $htp_cmd .= 'write.table(cor_mat, file=\''.$stats_out_htp_rel_tempfile.'\', row.names=TRUE, col.names=TRUE, sep=\'\t\');"';
                            print STDERR Dumper $htp_cmd;
                            my $status = system($htp_cmd);
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
                            ';
                            if ($return_inverse_matrix) {
                                $htp_cmd .= 'rel <- solve(rel);
                                ';
                            }
                            $htp_cmd .= 'rownames(rel) <- blues[,2];
                            colnames(rel) <- blues[,2];
                            write.table(rel, file=\''.$stats_out_htp_rel_tempfile.'\', row.names=TRUE, col.names=TRUE, sep=\'\t\');"';
                            print STDERR Dumper $htp_cmd;
                            my $status = system($htp_cmd);
                        }
                        else {
                            $c->stash->{rest} = { error => "The value of $compute_relationship_matrix_from_htp_phenotypes_type htp_pheno_rel_matrix_type is not valid!" };
                            return;
                        }

                        open(my $htp_rel_res, '<', $stats_out_htp_rel_tempfile) or die "Could not open file '$stats_out_htp_rel_tempfile' $!";
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
                        if ($statistics_select eq 'blupf90_grm_random_regression_gdd_blups' || $statistics_select eq 'blupf90_grm_random_regression_dap_blups' || $statistics_select eq 'airemlf90_grm_random_regression_gdd_blups' || $statistics_select eq 'airemlf90_grm_random_regression_dap_blups' || $statistics_select eq 'asreml_grm_univariate_spatial_genetic_blups' || $statistics_select eq 'asreml_grm_univariate_pure_spatial_genetic_blups') {
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
                };

                my $result_5 = CXGN::DroneImagery::DroneImageryAnalyticsRunSimulation::perform_drone_imagery_analytics($schema, $a_env, $b_env, $ro_env, $row_ro_env, $env_variance_percent, $protocol_id, $statistics_select, $analytics_select, $tolparinv, $use_area_under_curve, $legendre_order_number, $permanent_environment_structure, \@legendre_coeff_exec, \%trait_name_encoder_5, \%trait_name_encoder_rev_5, \%stock_info_5, \%plot_id_map, \@sorted_trait_names_5, \%accession_id_factor_map, \@rep_time_factors, \@ind_rep_factors, \@unique_accession_names, \%plot_id_count_map_reverse, \@sorted_scaled_ln_times, \%time_count_map_reverse, \%accession_id_factor_map_reverse, \%seen_times, \%plot_id_factor_map_reverse, \%trait_to_time_map_5, \@unique_plot_names, \%stock_name_row_col, \%phenotype_data_original_5, \%plot_rep_time_factor_map, \%stock_row_col, \%stock_row_col_id, \%polynomial_map, \@plot_ids_ordered, $csv, $timestamp, $user_name, $stats_tempfile, $grm_file, $grm_rename_tempfile, $tmp_stats_dir, $stats_out_tempfile, $stats_out_tempfile_row, $stats_out_tempfile_col, $stats_out_tempfile_residual, $stats_out_tempfile_2dspl, $stats_prep2_tempfile, $stats_out_param_tempfile, $parameter_tempfile, $parameter_asreml_tempfile, $stats_tempfile_2, $permanent_environment_structure_tempfile, $permanent_environment_structure_env_tempfile, $permanent_environment_structure_env_tempfile2, $permanent_environment_structure_env_tempfile_mat, $sim_env_changing_mat_tempfile, $sim_env_changing_mat_full_tempfile, $yhat_residual_tempfile, $blupf90_solutions_tempfile, $coeff_genetic_tempfile, $coeff_pe_tempfile, $stats_out_tempfile_varcomp, $time_min, $time_max, $header_string_5, $env_sim_exec, $min_row, $max_row, $min_col, $max_col, $mean_row, $sig_row, $mean_col, $sig_col, $sim_env_change_over_time, $correlation_between_times, $field_trial_id_list, $simulated_environment_real_data_trait_id, $fixed_effect_type, $perform_cv);
                if (ref($result_5) eq 'HASH') {
                    $c->stash->{rest} = $result_5;
                    $c->detach();
                }
                my ($statistical_ontology_term_5, $analysis_model_training_data_file_type_5, $analysis_model_language_5, $sorted_residual_trait_names_array_5, $rr_unique_traits_hash_5, $rr_residual_unique_traits_hash_5, $statistics_cmd_5, $cmd_f90_5, $number_traits_5, $trait_to_time_map_hash_5,

                $result_blup_data_original_5, $result_blup_data_delta_original_5, $result_blup_spatial_data_original_5, $result_blup_pe_data_original_5, $result_blup_pe_data_delta_original_5, $result_residual_data_original_5, $result_fitted_data_original_5, $fixed_effects_original_hash_5,
                $rr_genetic_coefficients_original_hash_5, $rr_temporal_coefficients_original_hash_5,
                $rr_coeff_genetic_covariance_original_array_5, $rr_coeff_env_covariance_original_array_5, $rr_coeff_genetic_correlation_original_array_5, $rr_coeff_env_correlation_original_array_5, $rr_residual_variance_original_5, $varcomp_original_array_5,
                $model_sum_square_residual_original_5, $genetic_effect_min_original_5, $genetic_effect_max_original_5, $env_effect_min_original_5, $env_effect_max_original_5, $genetic_effect_sum_square_original_5, $genetic_effect_sum_original_5, $env_effect_sum_square_original_5, $env_effect_sum_original_5, $residual_sum_square_original_5, $residual_sum_original_5, $result_cv_original_5, $result_cv_2_original_5,

                $phenotype_data_altered_hash_5, $data_matrix_altered_array_5, $data_matrix_phenotypes_altered_array_5, $phenotype_min_altered_5, $phenotype_max_altered_5,
                $result_blup_data_altered_5, $result_blup_data_delta_altered_5, $result_blup_spatial_data_altered_5, $result_blup_pe_data_altered_5, $result_blup_pe_data_delta_altered_5, $result_residual_data_altered_5, $result_fitted_data_altered_5, $fixed_effects_altered_hash_5,
                $rr_genetic_coefficients_altered_hash_5, $rr_temporal_coefficients_altered_hash_5,
                $rr_coeff_genetic_covariance_altered_array_5, $rr_coeff_env_covariance_altered_array_5, $rr_coeff_genetic_correlation_altered_array_5, $rr_coeff_env_correlation_altered_array_5, $rr_residual_variance_altered_5, $varcomp_altered_array_5,
                $model_sum_square_residual_altered_5, $genetic_effect_min_altered_5, $genetic_effect_max_altered_5, $env_effect_min_altered_5, $env_effect_max_altered_5, $genetic_effect_sum_square_altered_5, $genetic_effect_sum_altered_5, $env_effect_sum_square_altered_5, $env_effect_sum_altered_5, $residual_sum_square_altered_5, $residual_sum_altered_5, $result_cv_altered_5, $result_cv_2_altered_5,

                $phenotype_data_altered_env_hash_1_5, $data_matrix_altered_env_array_1_5, $data_matrix_phenotypes_altered_env_array_1_5, $phenotype_min_altered_env_1_5, $phenotype_max_altered_env_1_5, $env_sim_min_1_5, $env_sim_max_1_5, $sim_data_hash_1_5,
                $result_blup_data_altered_env_1_5, $result_blup_data_delta_altered_env_1_5, $result_blup_spatial_data_altered_env_1_5, $result_blup_pe_data_altered_env_1_5, $result_blup_pe_data_delta_altered_env_1_5, $result_residual_data_altered_env_1_5, $result_fitted_data_altered_env_1_5, $fixed_effects_altered_env_hash_1_5, $rr_genetic_coefficients_altered_env_hash_1_5, $rr_temporal_coefficients_altered_env_hash_1_5,
                $rr_coeff_genetic_covariance_altered_env_array_1_5, $rr_coeff_env_covariance_altered_env_array_1_5, $rr_coeff_genetic_correlation_altered_env_array_1_5, $rr_coeff_env_correlation_altered_env_array_1_5, $rr_residual_variance_altered_env_1_5, $varcomp_altered_array_env_1_5,
                $model_sum_square_residual_altered_env_1_5, $genetic_effect_min_altered_env_1_5, $genetic_effect_max_altered_env_1_5, $env_effect_min_altered_env_1_5, $env_effect_max_altered_env_1_5, $genetic_effect_sum_square_altered_env_1_5, $genetic_effect_sum_altered_env_1_5, $env_effect_sum_square_altered_env_1_5, $env_effect_sum_altered_env_1_5, $residual_sum_square_altered_env_1_5, $residual_sum_altered_env_1_5, $result_cv_altered_env_1_5, $result_cv_2_altered_env_1_5,

                $phenotype_data_altered_env_hash_2_5, $data_matrix_altered_env_array_2_5, $data_matrix_phenotypes_altered_env_array_2_5, $phenotype_min_altered_env_2_5, $phenotype_max_altered_env_2_5, $env_sim_min_2_5, $env_sim_max_2_5, $sim_data_hash_2_5,
                $result_blup_data_altered_env_2_5, $result_blup_data_delta_altered_env_2_5, $result_blup_spatial_data_altered_env_2_5, $result_blup_pe_data_altered_env_2_5, $result_blup_pe_data_delta_altered_env_2_5, $result_residual_data_altered_env_2_5, $result_fitted_data_altered_env_2_5, $fixed_effects_altered_env_hash_2_5, $rr_genetic_coefficients_altered_env_hash_2_5, $rr_temporal_coefficients_altered_env_hash_2_5,
                $rr_coeff_genetic_covariance_altered_env_array_2_5, $rr_coeff_env_covariance_altered_env_array_2_5, $rr_coeff_genetic_correlation_altered_env_array_2_5, $rr_coeff_env_correlation_altered_env_array_2_5, $rr_residual_variance_altered_env_2_5, $varcomp_altered_array_env_2_5,
                $model_sum_square_residual_altered_env_2_5, $genetic_effect_min_altered_env_2_5, $genetic_effect_max_altered_env_2_5, $env_effect_min_altered_env_2_5, $env_effect_max_altered_env_2_5, $genetic_effect_sum_square_altered_env_2_5, $genetic_effect_sum_altered_env_2_5, $env_effect_sum_square_altered_env_2_5, $env_effect_sum_altered_env_2_5, $residual_sum_square_altered_env_2_5, $residual_sum_altered_env_2_5, $result_cv_altered_env_2_5, $result_cv_2_altered_env_2_5,

                $phenotype_data_altered_env_hash_3_5, $data_matrix_altered_env_array_3_5, $data_matrix_phenotypes_altered_env_array_3_5, $phenotype_min_altered_env_3_5, $phenotype_max_altered_env_3_5, $env_sim_min_3_5, $env_sim_max_3_5, $sim_data_hash_3_5,
                $result_blup_data_altered_env_3_5, $result_blup_data_delta_altered_env_3_5, $result_blup_spatial_data_altered_env_3_5, $result_blup_pe_data_altered_env_3_5, $result_blup_pe_data_delta_altered_env_3_5, $result_residual_data_altered_env_3_5, $result_fitted_data_altered_env_3_5, $fixed_effects_altered_env_hash_3_5, $rr_genetic_coefficients_altered_env_hash_3_5, $rr_temporal_coefficients_altered_env_hash_3_5,
                $rr_coeff_genetic_covariance_altered_env_array_3_5, $rr_coeff_env_covariance_altered_env_array_3_5, $rr_coeff_genetic_correlation_altered_env_array_3_5, $rr_coeff_env_correlation_altered_env_array_3_5, $rr_residual_variance_altered_env_3_5, $varcomp_altered_array_env_3_5,
                $model_sum_square_residual_altered_env_3_5, $genetic_effect_min_altered_env_3_5, $genetic_effect_max_altered_env_3_5, $env_effect_min_altered_env_3_5, $env_effect_max_altered_env_3_5, $genetic_effect_sum_square_altered_env_3_5, $genetic_effect_sum_altered_env_3_5, $env_effect_sum_square_altered_env_3_5, $env_effect_sum_altered_env_3_5, $residual_sum_square_altered_env_3_5, $residual_sum_altered_env_3_5, $result_cv_altered_env_3_5, $result_cv_2_altered_env_3_5,

                $phenotype_data_altered_env_hash_4_5, $data_matrix_altered_env_array_4_5, $data_matrix_phenotypes_altered_env_array_4_5, $phenotype_min_altered_env_4_5, $phenotype_max_altered_env_4_5, $env_sim_min_4_5, $env_sim_max_4_5, $sim_data_hash_4_5,
                $result_blup_data_altered_env_4_5, $result_blup_data_delta_altered_env_4_5, $result_blup_spatial_data_altered_env_4_5, $result_blup_pe_data_altered_env_4_5, $result_blup_pe_data_delta_altered_env_4_5, $result_residual_data_altered_env_4_5, $result_fitted_data_altered_env_4_5, $fixed_effects_altered_env_hash_4_5, $rr_genetic_coefficients_altered_env_hash_4_5, $rr_temporal_coefficients_altered_env_hash_4_5,
                $rr_coeff_genetic_covariance_altered_env_array_4_5, $rr_coeff_env_covariance_altered_env_array_4_5, $rr_coeff_genetic_correlation_altered_env_array_4_5, $rr_coeff_env_correlation_altered_env_array_4_5, $rr_residual_variance_altered_env_4_5, $varcomp_altered_array_env_4_5,
                $model_sum_square_residual_altered_env_4_5, $genetic_effect_min_altered_env_4_5, $genetic_effect_max_altered_env_4_5, $env_effect_min_altered_env_4_5, $env_effect_max_altered_env_4_5, $genetic_effect_sum_square_altered_env_4_5, $genetic_effect_sum_altered_env_4_5, $env_effect_sum_square_altered_env_4_5, $env_effect_sum_altered_env_4_5, $residual_sum_square_altered_env_4_5, $residual_sum_altered_env_4_5, $result_cv_altered_env_4_5, $result_cv_2_altered_env_4_5,

                $phenotype_data_altered_env_hash_5_5, $data_matrix_altered_env_array_5_5, $data_matrix_phenotypes_altered_env_array_5_5, $phenotype_min_altered_env_5_5, $phenotype_max_altered_env_5_5, $env_sim_min_5_5, $env_sim_max_5_5, $sim_data_hash_5_5,
                $result_blup_data_altered_env_5_5, $result_blup_data_delta_altered_env_5_5, $result_blup_spatial_data_altered_env_5_5, $result_blup_pe_data_altered_env_5_5, $result_blup_pe_data_delta_altered_env_5_5, $result_residual_data_altered_env_5_5, $result_fitted_data_altered_env_5_5, $fixed_effects_altered_env_hash_5_5, $rr_genetic_coefficients_altered_env_hash_5_5, $rr_temporal_coefficients_altered_env_hash_5_5,
                $rr_coeff_genetic_covariance_altered_env_array_5_5, $rr_coeff_env_covariance_altered_env_array_5_5, $rr_coeff_genetic_correlation_altered_env_array_5_5, $rr_coeff_env_correlation_altered_env_array_5_5, $rr_residual_variance_altered_env_5_5, $varcomp_altered_array_env_5_5,
                $model_sum_square_residual_altered_env_5_5, $genetic_effect_min_altered_env_5_5, $genetic_effect_max_altered_env_5_5, $env_effect_min_altered_env_5_5, $env_effect_max_altered_env_5_5, $genetic_effect_sum_square_altered_env_5_5, $genetic_effect_sum_altered_env_5_5, $env_effect_sum_square_altered_env_5_5, $env_effect_sum_altered_env_5_5, $residual_sum_square_altered_env_5_5, $residual_sum_altered_env_5_5, $result_cv_altered_env_5_5, $result_cv_2_altered_env_5_5,

                $phenotype_data_altered_env_hash_6_5, $data_matrix_altered_env_array_6_5, $data_matrix_phenotypes_altered_env_array_6_5, $phenotype_min_altered_env_6_5, $phenotype_max_altered_env_6_5, $env_sim_min_6_5, $env_sim_max_6_5, $sim_data_hash_6_5,
                $result_blup_data_altered_env_6_5, $result_blup_data_delta_altered_env_6_5, $result_blup_spatial_data_altered_env_6_5, $result_blup_pe_data_altered_env_6_5, $result_blup_pe_data_delta_altered_env_6_5, $result_residual_data_altered_env_6_5, $result_fitted_data_altered_env_6_5, $fixed_effects_altered_env_hash_6_5, $rr_genetic_coefficients_altered_env_hash_6_5, $rr_temporal_coefficients_altered_env_hash_6_5,
                $rr_coeff_genetic_covariance_altered_env_array_6_5, $rr_coeff_env_covariance_altered_env_array_6_5, $rr_coeff_genetic_correlation_altered_env_array_6_5, $rr_coeff_env_correlation_altered_env_array_6_5, $rr_residual_variance_altered_env_6_5, $varcomp_altered_array_env_6_5,
                $model_sum_square_residual_altered_env_6_5, $genetic_effect_min_altered_env_6_5, $genetic_effect_max_altered_env_6_5, $env_effect_min_altered_env_6_5, $env_effect_max_altered_env_6_5, $genetic_effect_sum_square_altered_env_6_5, $genetic_effect_sum_altered_env_6_5, $env_effect_sum_square_altered_env_6_5, $env_effect_sum_altered_env_6_5, $residual_sum_square_altered_env_6_5, $residual_sum_altered_env_6_5, $result_cv_altered_env_6_5, $result_cv_2_altered_env_6_5
                ) = @$result_5;

                eval {
                    print STDERR "PLOTTING CORRELATION\n";
                    my ($full_plot_level_correlation_tempfile_fh, $full_plot_level_correlation_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open(my $F_fullplot, ">", $full_plot_level_correlation_tempfile) || die "Can't open file ".$full_plot_level_correlation_tempfile;
                        print STDERR "OPENED PLOTCORR FILE $full_plot_level_correlation_tempfile\n";

                        my @header_full_plot_corr = ('plot_name, plot_id, row_number, col_number, rep, block, germplasm_name, germplasm_id');
                        my @types_full_plot_corr = ('pheno_orig_', 'pheno_postm5_', 'eff_origm5_', 'eff_postm5_',
                        'sim_env1_', 'simm5_pheno1_', 'effm5_sim1_',
                        'sim_env2_', 'simm5_pheno2_', 'effm5_sim2_',
                        'sim_env3_', 'simm5_pheno3_', 'effm5_sim3_',
                        'sim_env4_', 'simm5_pheno4_', 'effm5_sim4_',
                        'sim_env5_', 'simm5_pheno5_', 'effm5_sim5_',
                        'sim_env6_', 'simm5_pheno6_', 'effm5_sim6_');
                        foreach my $t (@sorted_trait_names_5) {
                            foreach my $type (@types_full_plot_corr) {
                                push @header_full_plot_corr, $type.$trait_name_encoder_5{$t};
                            }
                        }
                        my $header_string_full_plot_corr = join ',', @header_full_plot_corr;
                        print $F_fullplot "$header_string_full_plot_corr\n";
                        foreach my $p (@unique_plot_names) {
                            my @row = ($p, $stock_name_row_col{$p}->{obsunit_stock_id}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $stock_name_row_col{$p}->{rep}, $stock_name_row_col{$p}->{block}, $stock_name_row_col{$p}->{germplasm_name}, $stock_name_row_col{$p}->{germplasm_stock_id});
                            foreach my $t (@sorted_trait_names_5) {
                                my $phenotype_original = $phenotype_data_original_5{$p}->{$t};
                                my $phenotype_post_5 = $phenotype_data_altered_hash_5->{$p}->{$t};
                                my $effect_original_5 = $result_blup_spatial_data_original_5->{$p}->{$t}->[0];
                                my $effect_post_5 = $result_blup_spatial_data_altered_5->{$p}->{$t}->[0];
                                push @row, ($phenotype_original, $phenotype_post_5, $effect_original_5, $effect_post_5);

                                my $sim_env = $sim_data_hash_1_5->{$p}->{$t};
                                my $pheno_sim_5 = $phenotype_data_altered_env_hash_1_5->{$p}->{$t};
                                my $effect_sim_5 = $result_blup_spatial_data_altered_env_1_5->{$p}->{$t}->[0];
                                push @row, ($sim_env, $pheno_sim_5, $effect_sim_5);

                                my $sim_env2 = $sim_data_hash_2_5->{$p}->{$t};
                                my $pheno_sim2_5 = $phenotype_data_altered_env_hash_2_5->{$p}->{$t};
                                my $effect_sim2_5 = $result_blup_spatial_data_altered_env_2_5->{$p}->{$t}->[0];
                                push @row, ($sim_env2, $pheno_sim2_5, $effect_sim2_5);

                                my $sim_env3 = $sim_data_hash_3_5->{$p}->{$t};
                                my $pheno_sim3_5 = $phenotype_data_altered_env_hash_3_5->{$p}->{$t};
                                my $effect_sim3_5 = $result_blup_spatial_data_altered_env_3_5->{$p}->{$t}->[0];
                                push @row, ($sim_env3, $pheno_sim3_5, $effect_sim3_5);

                                my $sim_env4 = $sim_data_hash_4_5->{$p}->{$t};
                                my $pheno_sim4_5 = $phenotype_data_altered_env_hash_4_5->{$p}->{$t};
                                my $effect_sim4_5 = $result_blup_spatial_data_altered_env_4_5->{$p}->{$t}->[0];
                                push @row, ($sim_env4, $pheno_sim4_5, $effect_sim4_5);

                                my $sim_env5 = $sim_data_hash_5_5->{$p}->{$t};
                                my $pheno_sim5_5 = $phenotype_data_altered_env_hash_5_5->{$p}->{$t};
                                my $effect_sim5_5 = $result_blup_spatial_data_altered_env_5_5->{$p}->{$t}->[0];
                                push @row, ($sim_env5, $pheno_sim5_5, $effect_sim5_5);

                                my $sim_env6 = $sim_data_hash_6_5->{$p}->{$t};
                                my $pheno_sim6_5 = $phenotype_data_altered_env_hash_6_5->{$p}->{$t};
                                my $effect_sim6_5 = $result_blup_spatial_data_altered_env_6_5->{$p}->{$t}->[0];
                                push @row, ($sim_env6, $pheno_sim6_5, $effect_sim6_5);
                            }
                            my $line = join ',', @row;
                            print $F_fullplot "$line\n";
                        }
                    close($F_fullplot);

                    my $plot_corr_figure_tempfile_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $plot_corr_figure_tempfile_string .= '.png';
                    my $plot_corr_figure_tempfile = $c->config->{basepath}."/".$plot_corr_figure_tempfile_string;

                    my $cmd_plotcorr_plot = 'R -e "library(data.table); library(ggplot2); library(GGally);
                    mat_orig <- fread(\''.$full_plot_level_correlation_tempfile.'\', header=TRUE, sep=\',\');
                    gg <- ggcorr(data=mat_orig[,-seq(1,8)], hjust = 1, size = 2, color = \'grey50\', layout.exp = 1, label = TRUE);
                    ggsave(\''.$plot_corr_figure_tempfile.'\', gg, device=\'png\', width=30, height=30, limitsize = FALSE, units=\'in\');
                    "';
                    # print STDERR Dumper $cmd;
                    my $status_plotcorr_plot = system($cmd_plotcorr_plot);
                    push @$spatial_effects_plots, [$plot_corr_figure_tempfile_string, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_fullcorr_"."envvar_".$env_variance_percent."_".$iterations];
                    push @$spatial_effects_files_store, [$full_plot_level_correlation_tempfile, "datafile_".$statistics_select.$sim_env_change_over_time.$correlation_between_times."_fullcorr_"."envvar_".$env_variance_percent."_".$iterations];
                };

                eval {
                    my @plot_corr_full_vals;

                    my @original_pheno_vals;
                    my ($phenotypes_original_heatmap_tempfile_fh, $phenotypes_original_heatmap_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open(my $F_pheno, ">", $phenotypes_original_heatmap_tempfile) || die "Can't open file ".$phenotypes_original_heatmap_tempfile;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_5) {
                                my $val = $phenotype_data_original_5{$p}->{$t};
                                my @row = ("pheno_orig_".$trait_name_encoder_5{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                push @original_pheno_vals, $val;
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                            }
                        }
                    close($F_pheno);
                    push @plot_corr_full_vals, \@original_pheno_vals;

                    my $original_pheno_stat = Statistics::Descriptive::Full->new();
                    $original_pheno_stat->add_data(@original_pheno_vals);
                    my $sig_original_pheno = $original_pheno_stat->variance();

                    #PHENO POST M START

                    my @altered_pheno_vals_5;
                    my ($phenotypes_post_heatmap_tempfile_fh_5, $phenotypes_post_heatmap_tempfile_5) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $phenotypes_post_heatmap_tempfile_5) || die "Can't open file ".$phenotypes_post_heatmap_tempfile_5;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_5) {
                                my $val = $phenotype_data_altered_hash_5->{$p}->{$t};
                                my @row = ("pheno_postm5_".$trait_name_encoder_5{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                push @altered_pheno_vals_5, $val;
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                            }
                        }
                    close($F_pheno);
                    push @plot_corr_full_vals, \@altered_pheno_vals_5;

                    my $altered_pheno_stat_5 = Statistics::Descriptive::Full->new();
                    $altered_pheno_stat_5->add_data(@altered_pheno_vals_5);
                    my $sig_altered_pheno_5 = $altered_pheno_stat_5->variance();

                    # EFFECT ORIGINAL M

                    my @original_effect_vals_5;
                    my ($effects_heatmap_tempfile_fh_5, $effects_heatmap_tempfile_5) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open(my $F_eff, ">", $effects_heatmap_tempfile_5) || die "Can't open file ".$effects_heatmap_tempfile_5;
                        print $F_eff "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_5) {
                                my $val = $result_blup_spatial_data_original_5->{$p}->{$t}->[0];
                                my @row = ("eff_origm5_".$trait_name_encoder_5{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_eff "$line\n";
                                push @original_effect_vals_5, $val;
                            }
                        }
                    close($F_eff);
                    push @plot_corr_full_vals, \@original_effect_vals_5;

                    my $original_effect_stat_5 = Statistics::Descriptive::Full->new();
                    $original_effect_stat_5->add_data(@original_effect_vals_5);
                    my $sig_original_effect_5 = $original_effect_stat_5->variance();

                    # EFFECT POST M MIN

                    my @altered_effect_vals_5;
                    my ($effects_post_heatmap_tempfile_fh_5, $effects_post_heatmap_tempfile_5) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_eff, ">", $effects_post_heatmap_tempfile_5) || die "Can't open file ".$effects_post_heatmap_tempfile_5;
                        print $F_eff "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_5) {
                                my $val = $result_blup_spatial_data_altered_5->{$p}->{$t}->[0];
                                my @row = ("eff_postm5_".$trait_name_encoder_5{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_eff "$line\n";
                                push @altered_effect_vals_5, $val;
                            }
                        }
                    close($F_eff);
                    push @plot_corr_full_vals, \@altered_effect_vals_5;

                    my $altered_effect_stat_5 = Statistics::Descriptive::Full->new();
                    $altered_effect_stat_5->add_data(@altered_effect_vals_5);
                    my $sig_altered_effect_5 = $altered_effect_stat_5->variance();

                    # SIM ENV 1: ALTERED PHENO + EFFECT

                    my ($phenotypes_env_heatmap_tempfile_fh, $phenotypes_env_heatmap_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $phenotypes_env_heatmap_tempfile) || die "Can't open file ".$phenotypes_env_heatmap_tempfile;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_5) {
                                my @row = ("sim_env1_".$trait_name_encoder_5{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $sim_data_hash_1_5->{$p}->{$t});
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                            }
                        }
                    close($F_pheno);

                    my @sim_pheno1_vals_5;
                    my ($phenotypes_pheno_sim_heatmap_tempfile_fh_5, $phenotypes_pheno_sim_heatmap_tempfile_5) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $phenotypes_pheno_sim_heatmap_tempfile_5) || die "Can't open file ".$phenotypes_pheno_sim_heatmap_tempfile_5;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_5) {
                                my $val = $phenotype_data_altered_env_hash_1_5->{$p}->{$t};
                                my @row = ("simm5_pheno1_".$trait_name_encoder_5{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                                push @sim_pheno1_vals_5, $val;
                            }
                        }
                    close($F_pheno);
                    push @plot_corr_full_vals, \@sim_pheno1_vals_5;

                    my $sim_pheno1_stat_5 = Statistics::Descriptive::Full->new();
                    $sim_pheno1_stat_5->add_data(@sim_pheno1_vals_5);
                    my $sig_sim5_pheno1 = $sim_pheno1_stat_5->variance();

                    my @sim_effect1_vals_5;
                    my ($effects_sim_heatmap_tempfile_fh_5, $effects_sim_heatmap_tempfile_5) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_eff, ">", $effects_sim_heatmap_tempfile_5) || die "Can't open file ".$effects_sim_heatmap_tempfile_5;
                        print $F_eff "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_5) {
                                my $val = $result_blup_spatial_data_altered_env_1_5->{$p}->{$t}->[0];
                                my @row = ("effm5_sim1_".$trait_name_encoder_5{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_eff "$line\n";
                                push @sim_effect1_vals_5, $val;
                            }
                        }
                    close($F_eff);
                    push @plot_corr_full_vals, \@sim_effect1_vals_5;

                    my $sim_effect1_stat_5 = Statistics::Descriptive::Full->new();
                    $sim_effect1_stat_5->add_data(@sim_effect1_vals_5);
                    my $sig_sim5_effect1 = $sim_effect1_stat_5->variance();

                    # SIM ENV 2: ALTERED PHENO + EFFECT

                    my ($phenotypes_env_heatmap_tempfile2_fh, $phenotypes_env_heatmap_tempfile2) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $phenotypes_env_heatmap_tempfile2) || die "Can't open file ".$phenotypes_env_heatmap_tempfile2;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_5) {
                                my @row = ("sim_env2_".$trait_name_encoder_5{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $sim_data_hash_2_5->{$p}->{$t});
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                            }
                        }
                    close($F_pheno);

                    my @sim_pheno2_vals_5;
                    my ($phenotypes_pheno_sim_heatmap_tempfile2_fh_5, $phenotypes_pheno_sim_heatmap_tempfile2_5) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $phenotypes_pheno_sim_heatmap_tempfile2_5) || die "Can't open file ".$phenotypes_pheno_sim_heatmap_tempfile2_5;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_5) {
                                my $val = $phenotype_data_altered_env_hash_2_5->{$p}->{$t};
                                my @row = ("simm5_pheno2_".$trait_name_encoder_5{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                                push @sim_pheno2_vals_5, $val;
                            }
                        }
                    close($F_pheno);
                    push @plot_corr_full_vals, \@sim_pheno2_vals_5;

                    my $sim_pheno2_stat_5 = Statistics::Descriptive::Full->new();
                    $sim_pheno2_stat_5->add_data(@sim_pheno2_vals_5);
                    my $sig_sim_pheno2_5 = $sim_pheno2_stat_5->variance();

                    my @sim_effect2_vals_5;
                    my ($effects_sim_heatmap_tempfile2_fh_5, $effects_sim_heatmap_tempfile2_5) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_eff, ">", $effects_sim_heatmap_tempfile2_5) || die "Can't open file ".$effects_sim_heatmap_tempfile2_5;
                        print $F_eff "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_5) {
                                my $val = $result_blup_spatial_data_altered_env_2_5->{$p}->{$t}->[0];
                                my @row = ("effm5_sim2_".$trait_name_encoder_5{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_eff "$line\n";
                                push @sim_effect2_vals_5, $val;
                            }
                        }
                    close($F_eff);
                    push @plot_corr_full_vals, \@sim_effect2_vals_5;

                    my $sim_effect2_stat_5 = Statistics::Descriptive::Full->new();
                    $sim_effect2_stat_5->add_data(@sim_effect2_vals_5);
                    my $sig_sim_effect2_5 = $sim_effect2_stat_5->variance();

                    # SIM ENV 3: ALTERED PHENO + EFFECT

                    my ($phenotypes_env_heatmap_tempfile3_fh, $phenotypes_env_heatmap_tempfile3) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $phenotypes_env_heatmap_tempfile3) || die "Can't open file ".$phenotypes_env_heatmap_tempfile3;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_5) {
                                my @row = ("sim_env3_".$trait_name_encoder_5{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $sim_data_hash_3_5->{$p}->{$t});
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                            }
                        }
                    close($F_pheno);

                    my @sim_pheno3_vals_5;
                    my ($phenotypes_pheno_sim_heatmap_tempfile3_fh_5, $phenotypes_pheno_sim_heatmap_tempfile3_5) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $phenotypes_pheno_sim_heatmap_tempfile3_5) || die "Can't open file ".$phenotypes_pheno_sim_heatmap_tempfile3_5;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_5) {
                                my $val = $phenotype_data_altered_env_hash_3_5->{$p}->{$t};
                                my @row = ("simm5_pheno3_".$trait_name_encoder_5{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                                push @sim_pheno3_vals_5, $val;
                            }
                        }
                    close($F_pheno);
                    push @plot_corr_full_vals, \@sim_pheno3_vals_5;

                    my $sim_pheno3_stat_5 = Statistics::Descriptive::Full->new();
                    $sim_pheno3_stat_5->add_data(@sim_pheno3_vals_5);
                    my $sig_sim_pheno3_5 = $sim_pheno3_stat_5->variance();

                    my @sim_effect3_vals_5;
                    my ($effects_sim_heatmap_tempfile3_fh_5, $effects_sim_heatmap_tempfile3_5) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_eff, ">", $effects_sim_heatmap_tempfile3_5) || die "Can't open file ".$effects_sim_heatmap_tempfile3_5;
                        print $F_eff "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_5) {
                                my $val = $result_blup_spatial_data_altered_env_3_5->{$p}->{$t}->[0];
                                my @row = ("effm5_sim3_".$trait_name_encoder_5{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_eff "$line\n";
                                push @sim_effect3_vals_5, $val;
                            }
                        }
                    close($F_eff);
                    push @plot_corr_full_vals, \@sim_effect3_vals_5;

                    my $sim_effect3_stat_5 = Statistics::Descriptive::Full->new();
                    $sim_effect3_stat_5->add_data(@sim_effect3_vals_5);
                    my $sig_sim_effect3_5 = $sim_effect3_stat_5->variance();

                    # SIM ENV 4: ALTERED PHENO + EFFECT

                    my ($phenotypes_env_heatmap_tempfile4_fh, $phenotypes_env_heatmap_tempfile4) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $phenotypes_env_heatmap_tempfile4) || die "Can't open file ".$phenotypes_env_heatmap_tempfile4;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_5) {
                                my @row = ("sim_env4_".$trait_name_encoder_5{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $sim_data_hash_4_5->{$p}->{$t});
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                            }
                        }
                    close($F_pheno);

                    my @sim_pheno4_vals_5;
                    my ($phenotypes_pheno_sim_heatmap_tempfile4_fh_5, $phenotypes_pheno_sim_heatmap_tempfile4_5) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $phenotypes_pheno_sim_heatmap_tempfile4_5) || die "Can't open file ".$phenotypes_pheno_sim_heatmap_tempfile4_5;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_5) {
                                my $val = $phenotype_data_altered_env_hash_4_5->{$p}->{$t};
                                my @row = ("simm5_pheno4_".$trait_name_encoder_5{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                                push @sim_pheno4_vals_5, $val;
                            }
                        }
                    close($F_pheno);
                    push @plot_corr_full_vals, \@sim_pheno4_vals_5;

                    my $sim_pheno4_stat_5 = Statistics::Descriptive::Full->new();
                    $sim_pheno4_stat_5->add_data(@sim_pheno4_vals_5);
                    my $sig_sim_pheno4_5 = $sim_pheno4_stat_5->variance();

                    my @sim_effect4_vals_5;
                    my ($effects_sim_heatmap_tempfile4_fh_5, $effects_sim_heatmap_tempfile4_5) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_eff, ">", $effects_sim_heatmap_tempfile4_5) || die "Can't open file ".$effects_sim_heatmap_tempfile4_5;
                        print $F_eff "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_5) {
                                my $val = $result_blup_spatial_data_altered_env_4_5->{$p}->{$t}->[0];
                                my @row = ("effm5_sim4_".$trait_name_encoder_5{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_eff "$line\n";
                                push @sim_effect4_vals_5, $val;
                            }
                        }
                    close($F_eff);
                    push @plot_corr_full_vals, \@sim_effect4_vals_5;

                    my $sim_effect4_stat_5 = Statistics::Descriptive::Full->new();
                    $sim_effect4_stat_5->add_data(@sim_effect4_vals_5);
                    my $sig_sim_effect4_5 = $sim_effect4_stat_5->variance();

                    # SIM ENV 5: ALTERED PHENO + EFFECT

                    my ($phenotypes_env_heatmap_tempfile5_fh, $phenotypes_env_heatmap_tempfile5) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $phenotypes_env_heatmap_tempfile5) || die "Can't open file ".$phenotypes_env_heatmap_tempfile5;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_5) {
                                my @row = ("sim_env5_".$trait_name_encoder_5{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $sim_data_hash_5_5->{$p}->{$t});
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                            }
                        }
                    close($F_pheno);

                    my @sim_pheno5_vals_5;
                    my ($phenotypes_pheno_sim_heatmap_tempfile5_fh_5, $phenotypes_pheno_sim_heatmap_tempfile5_5) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $phenotypes_pheno_sim_heatmap_tempfile5_5) || die "Can't open file ".$phenotypes_pheno_sim_heatmap_tempfile5_5;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_5) {
                                my $val = $phenotype_data_altered_env_hash_5_5->{$p}->{$t};
                                my @row = ("simm5_pheno5_".$trait_name_encoder_5{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                                push @sim_pheno5_vals_5, $val;
                            }
                        }
                    close($F_pheno);
                    push @plot_corr_full_vals, \@sim_pheno5_vals_5;

                    my $sim_pheno5_stat_5 = Statistics::Descriptive::Full->new();
                    $sim_pheno5_stat_5->add_data(@sim_pheno5_vals_5);
                    my $sig_sim_pheno5_5 = $sim_pheno5_stat_5->variance();

                    my @sim_effect5_vals_5;
                    my ($effects_sim_heatmap_tempfile5_fh_5, $effects_sim_heatmap_tempfile5_5) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_eff, ">", $effects_sim_heatmap_tempfile5_5) || die "Can't open file ".$effects_sim_heatmap_tempfile5_5;
                        print $F_eff "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_5) {
                                my $val = $result_blup_spatial_data_altered_env_5_5->{$p}->{$t}->[0];
                                my @row = ("effm5_sim5_".$trait_name_encoder_5{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_eff "$line\n";
                                push @sim_effect5_vals_5, $val;
                            }
                        }
                    close($F_eff);
                    push @plot_corr_full_vals, \@sim_effect5_vals_5;

                    my $sim_effect5_stat_5 = Statistics::Descriptive::Full->new();
                    $sim_effect5_stat_5->add_data(@sim_effect5_vals_5);
                    my $sig_sim_effect5_5 = $sim_effect5_stat_5->variance();

                    # SIM ENV 6: ALTERED PHENO + EFFECT

                    my ($phenotypes_env_heatmap_tempfile6_fh, $phenotypes_env_heatmap_tempfile6) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $phenotypes_env_heatmap_tempfile6) || die "Can't open file ".$phenotypes_env_heatmap_tempfile6;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_5) {
                                my @row = ("sim_env6_".$trait_name_encoder_5{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $sim_data_hash_6_5->{$p}->{$t});
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                            }
                        }
                    close($F_pheno);

                    my @sim_pheno6_vals_5;
                    my ($phenotypes_pheno_sim_heatmap_tempfile6_fh_5, $phenotypes_pheno_sim_heatmap_tempfile6_5) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $phenotypes_pheno_sim_heatmap_tempfile6_5) || die "Can't open file ".$phenotypes_pheno_sim_heatmap_tempfile6_5;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_5) {
                                my $val = $phenotype_data_altered_env_hash_6_5->{$p}->{$t};
                                my @row = ("simm5_pheno6_".$trait_name_encoder_5{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                                push @sim_pheno6_vals_5, $val;
                            }
                        }
                    close($F_pheno);
                    push @plot_corr_full_vals, \@sim_pheno6_vals_5;

                    my $sim_pheno6_stat_5 = Statistics::Descriptive::Full->new();
                    $sim_pheno6_stat_5->add_data(@sim_pheno6_vals_5);
                    my $sig_sim_pheno6_5 = $sim_pheno6_stat_5->variance();

                    my @sim_effect6_vals_5;
                    my ($effects_sim_heatmap_tempfile6_fh_5, $effects_sim_heatmap_tempfile6_5) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_eff, ">", $effects_sim_heatmap_tempfile6_5) || die "Can't open file ".$effects_sim_heatmap_tempfile6_5;
                        print $F_eff "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_5) {
                                my $val = $result_blup_spatial_data_altered_env_6_5->{$p}->{$t}->[0];
                                my @row = ("effm5_sim6_".$trait_name_encoder_5{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_eff "$line\n";
                                push @sim_effect6_vals_5, $val;
                            }
                        }
                    close($F_eff);
                    push @plot_corr_full_vals, \@sim_effect6_vals_5;

                    my $sim_effect6_stat_5 = Statistics::Descriptive::Full->new();
                    $sim_effect6_stat_5->add_data(@sim_effect6_vals_5);
                    my $sig_sim_effect6_5 = $sim_effect6_stat_5->variance();

                    my $plot_corr_summary_figure_inputfile_tempfile = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'tmp_drone_statistics/fileXXXX');
                    open($F_eff, ">", $plot_corr_summary_figure_inputfile_tempfile) || die "Can't open file ".$plot_corr_summary_figure_inputfile_tempfile;
                        foreach (@plot_corr_full_vals) {
                            my $line = join ',', @$_;
                            print $F_eff $line."\n";
                        }
                    close($F_eff);

                    my $plot_corr_summary_figure_tempfile_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $plot_corr_summary_figure_tempfile_string .= '.png';
                    my $plot_corr_summary_figure_tempfile = $c->config->{basepath}."/".$plot_corr_summary_figure_tempfile_string;

                    my $cmd_plotcorrsum_plot = 'R -e "library(data.table); library(ggplot2); library(GGally);
                    mat_full_t <- fread(\''.$plot_corr_summary_figure_inputfile_tempfile.'\', header=FALSE, sep=\',\');
                    mat_full <- data.frame(t(mat_full_t));
                    colnames(mat_full) <- c(\'mat_orig\', \'mat_altered_5\', \'mat_eff_5\', \'mat_eff_altered_5\',
                    \'mat_p_sim1_5\', \'mat_eff_sim1_5\',
                    \'mat_p_sim2_5\', \'mat_eff_sim2_5\',
                    \'mat_p_sim3_5\', \'mat_eff_sim3_5\',
                    \'mat_p_sim4_5\', \'mat_eff_sim4_5\',
                    \'mat_p_sim5_5\', \'mat_eff_sim5_5\',
                    \'mat_p_sim6_5\', \'mat_eff_sim6_5\');
                    mat_env <- fread(\''.$phenotypes_env_heatmap_tempfile.'\', header=TRUE, sep=\',\');
                    mat_env2 <- fread(\''.$phenotypes_env_heatmap_tempfile2.'\', header=TRUE, sep=\',\');
                    mat_env3 <- fread(\''.$phenotypes_env_heatmap_tempfile3.'\', header=TRUE, sep=\',\');
                    mat_env4 <- fread(\''.$phenotypes_env_heatmap_tempfile4.'\', header=TRUE, sep=\',\');
                    mat_env5 <- fread(\''.$phenotypes_env_heatmap_tempfile5.'\', header=TRUE, sep=\',\');
                    mat_env6 <- fread(\''.$phenotypes_env_heatmap_tempfile6.'\', header=TRUE, sep=\',\');
                    mat <- data.frame(pheno_orig = mat_full\$mat_orig, pheno_altm5 = mat_full\$mat_altered_5, eff_origm5 = mat_full\$mat_eff_5, eff_altm5 = mat_full\$mat_eff_altered_5, env_lin = mat_env\$value, pheno_linm5 = mat_full\$mat_p_sim1_5, lin_effm5 = mat_full\$mat_eff_sim1_5, env_n1d = mat_env2\$value, pheno_n1dm5 = mat_full\$mat_p_sim2_5, n1d_effm5 = mat_full\$mat_eff_sim2_5, env_n2d = mat_env3\$value, pheno_n2dm5 = mat_full\$mat_p_sim3_5, env_rand = mat_env4\$value, pheno_randm5 = mat_full\$mat_p_sim4_5, rand_effm5 = mat_full\$mat_eff_sim4_5, env_ar1 = mat_env5\$value, pheno_ar1m5 = mat_full\$mat_p_sim5_5, ar1_effm5 = mat_full\$mat_eff_sim5_5, env_realdata = mat_env6\$value, pheno_realdatam5 = mat_full\$mat_p_sim6_5, realdata_effm5 = mat_full\$mat_eff_sim6_5);
                    gg <- ggcorr(data=mat, hjust = 1, size = 2, color = \'grey50\', layout.exp = 1, label = TRUE, label_round = 2);
                    ggsave(\''.$plot_corr_summary_figure_tempfile.'\', gg, device=\'png\', width=30, height=30, units=\'in\');
                    "';
                    # print STDERR Dumper $cmd_plotcorrsum_plot;

                    my $status_plotcorrsum_plot = system($cmd_plotcorrsum_plot);
                    push @$spatial_effects_plots, [$plot_corr_summary_figure_tempfile_string, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_envsimscorr_"."envvar_".$env_variance_percent."_".$iterations];

                    my $env_effects_first_figure_tempfile_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $env_effects_first_figure_tempfile_string .= '.png';
                    my $env_effects_first_figure_tempfile = $c->config->{basepath}."/".$env_effects_first_figure_tempfile_string;

                    my $env_effects_first_figure_tempfile_string_2 = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $env_effects_first_figure_tempfile_string_2 .= '.png';
                    my $env_effects_first_figure_tempfile_2 = $c->config->{basepath}."/".$env_effects_first_figure_tempfile_string_2;

                    my $output_plot_row = 'row';
                    my $output_plot_col = 'col';
                    if ($max_col > $max_row) {
                        $output_plot_row = 'col';
                        $output_plot_col = 'row';
                    }

                    my $cmd_spatialfirst_plot_2 = 'R -e "library(data.table); library(ggplot2); library(dplyr); library(viridis); library(GGally); library(gridExtra);
                    mat_orig <- fread(\''.$phenotypes_original_heatmap_tempfile.'\', header=TRUE, sep=\',\');
                    mat_altered_5 <- fread(\''.$phenotypes_post_heatmap_tempfile_5.'\', header=TRUE, sep=\',\');
                    pheno_mat <- rbind(mat_orig, mat_altered_5);
                    options(device=\'png\');
                    par();
                    gg <- ggplot(pheno_mat, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_5).');
                    ggsave(\''.$env_effects_first_figure_tempfile_2.'\', gg, device=\'png\', width=20, height=20, units=\'in\');
                    "';
                    # print STDERR Dumper $cmd;
                    my $status_spatialfirst_plot_2 = system($cmd_spatialfirst_plot_2);
                    push @$spatial_effects_plots, [$env_effects_first_figure_tempfile_string_2, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_origheatmap_"."envvar_".$env_variance_percent."_".$iterations];

                    my ($sim_effects_corr_results_fh, $sim_effects_corr_results) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);

                    my $cmd_spatialfirst_plot = 'R -e "library(data.table); library(ggplot2); library(dplyr); library(viridis); library(GGally); library(gridExtra);
                    mat_full_t <- fread(\''.$plot_corr_summary_figure_inputfile_tempfile.'\', header=FALSE, sep=\',\');
                    mat_full <- data.frame(t(mat_full_t));
                    colnames(mat_full) <- c(\'mat_orig\', \'mat_altered_5\', \'mat_eff_5\', \'mat_eff_altered_5\',
                    \'mat_p_sim1_5\', \'mat_eff_sim1_5\',
                    \'mat_p_sim2_5\', \'mat_eff_sim2_5\',
                    \'mat_p_sim3_5\', \'mat_eff_sim3_5\',
                    \'mat_p_sim4_5\', \'mat_eff_sim4_5\',
                    \'mat_p_sim5_5\', \'mat_eff_sim5_5\',
                    \'mat_p_sim6_5\', \'mat_eff_sim6_5\');
                    mat_eff_5 <- fread(\''.$effects_heatmap_tempfile_5.'\', header=TRUE, sep=\',\');
                    mat_eff_altered_5 <- fread(\''.$effects_post_heatmap_tempfile_5.'\', header=TRUE, sep=\',\');
                    effect_mat_5 <- rbind(mat_eff_5, mat_eff_altered_5);
                    mat_env <- fread(\''.$phenotypes_env_heatmap_tempfile.'\', header=TRUE, sep=\',\');
                    mat_env2 <- fread(\''.$phenotypes_env_heatmap_tempfile2.'\', header=TRUE, sep=\',\');
                    mat_env3 <- fread(\''.$phenotypes_env_heatmap_tempfile3.'\', header=TRUE, sep=\',\');
                    mat_env4 <- fread(\''.$phenotypes_env_heatmap_tempfile4.'\', header=TRUE, sep=\',\');
                    mat_env5 <- fread(\''.$phenotypes_env_heatmap_tempfile5.'\', header=TRUE, sep=\',\');
                    mat_env6 <- fread(\''.$phenotypes_env_heatmap_tempfile6.'\', header=TRUE, sep=\',\');
                    options(device=\'png\');
                    par();
                    gg_eff_5 <- ggplot(effect_mat_5, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_5).');
                    ggsave(\''.$env_effects_first_figure_tempfile.'\', arrangeGrob(gg_eff_5, nrow=1), device=\'png\', width=25, height=25, units=\'in\');
                    write.table(data.frame(asreml_grm_univariate_spatial_genetic_blups_env_linear = c(cor(mat_env\$value, mat_full\$mat_eff_sim1_5)), asreml_grm_univariate_spatial_genetic_blups_env_1DN = c(cor(mat_env2\$value, mat_full\$mat_eff_sim2_5)), asreml_grm_univariate_spatial_genetic_blups_env_2DN = c(cor(mat_env3\$value, mat_full\$mat_eff_sim3_5)), asreml_grm_univariate_spatial_genetic_blups_env_random = c(cor(mat_env4\$value, mat_full\$mat_eff_sim4_5)), asreml_grm_univariate_spatial_genetic_blups_env_ar1xar1 = c(cor(mat_env5\$value, mat_full\$mat_eff_sim5_5)), asreml_grm_univariate_spatial_genetic_blups_env_realdata = c(cor(mat_env6\$value, mat_full\$mat_eff_sim6_5)) ), file=\''.$sim_effects_corr_results.'\', row.names=FALSE, col.names=TRUE, sep=\'\t\');
                    "';
                    # print STDERR Dumper $cmd;
                    my $status_spatialfirst_plot = system($cmd_spatialfirst_plot);
                    push @$spatial_effects_plots, [$env_effects_first_figure_tempfile_string, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_originaleffheatmap_"."envvar_".$env_variance_percent."_".$iterations];

                    open(my $fh_corr_result, '<', $sim_effects_corr_results) or die "Could not open file '$sim_effects_corr_results' $!";
                        print STDERR "Opened $sim_effects_corr_results\n";

                        my $header = <$fh_corr_result>;
                        my @header;
                        if ($csv->parse($header)) {
                            @header = $csv->fields();
                        }

                        while (my $row = <$fh_corr_result>) {
                            my @columns;
                            my $counter = 0;
                            if ($csv->parse($row)) {
                                @columns = $csv->fields();
                            }
                            foreach (@columns) {
                                push @{$env_corr_res->{$header[$counter]."_corrtime_".$sim_env_change_over_time.$correlation_between_times."_envvar_".$env_variance_percent}->{values}}, $_;
                                $counter++;
                            }
                        }
                    close($fh_corr_result);

                    my $env_effects_sim_figure_tempfile_string_5_env1 = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $env_effects_sim_figure_tempfile_string_5_env1 .= '.png';
                    my $env_effects_sim_figure_tempfile_5_env1 = $c->config->{basepath}."/".$env_effects_sim_figure_tempfile_string_5_env1;

                    my $cmd_spatialenvsim_plot_5_env1 = 'R -e "library(data.table); library(ggplot2); library(dplyr); library(viridis); library(GGally); library(gridExtra);
                    mat_env <- fread(\''.$phenotypes_env_heatmap_tempfile.'\', header=TRUE, sep=\',\');
                    mat_p_sim <- fread(\''.$phenotypes_pheno_sim_heatmap_tempfile_5.'\', header=TRUE, sep=\',\');
                    mat_eff_sim <- fread(\''.$effects_sim_heatmap_tempfile_5.'\', header=TRUE, sep=\',\');
                    options(device=\'png\');
                    par();
                    gg_env <- ggplot(mat_env, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_5).');
                    gg_p_sim <- ggplot(mat_p_sim, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_5).');
                    gg_eff_sim <- ggplot(mat_eff_sim, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_5).');
                    ggsave(\''.$env_effects_sim_figure_tempfile_5_env1.'\', arrangeGrob(gg_env, gg_p_sim, gg_eff_sim, nrow=1), device=\'png\', width=25, height=25, units=\'in\');
                    "';
                    # print STDERR Dumper $cmd_spatialenvsim_plot_5_env1;
                    my $status_spatialenvsim_plot_5_env1 = system($cmd_spatialenvsim_plot_5_env1);
                    push @$spatial_effects_plots, [$env_effects_sim_figure_tempfile_string_5_env1, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_env1effheatmap_"."envvar_".$env_variance_percent."_".$iterations];

                    my $env_effects_sim_figure_tempfile_string_5_env2 = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $env_effects_sim_figure_tempfile_string_5_env2 .= '.png';
                    my $env_effects_sim_figure_tempfile_5_env2 = $c->config->{basepath}."/".$env_effects_sim_figure_tempfile_string_5_env2;

                    my $cmd_spatialenvsim_plot_5_env2 = 'R -e "library(data.table); library(ggplot2); library(dplyr); library(viridis); library(GGally); library(gridExtra);
                    mat_env2 <- fread(\''.$phenotypes_env_heatmap_tempfile2.'\', header=TRUE, sep=\',\');
                    mat_p_sim2 <- fread(\''.$phenotypes_pheno_sim_heatmap_tempfile2_5.'\', header=TRUE, sep=\',\');
                    mat_eff_sim2 <- fread(\''.$effects_sim_heatmap_tempfile2_5.'\', header=TRUE, sep=\',\');
                    options(device=\'png\');
                    par();
                    gg_env2 <- ggplot(mat_env2, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_5).');
                    gg_p_sim2 <- ggplot(mat_p_sim2, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_5).');
                    gg_eff_sim2 <- ggplot(mat_eff_sim2, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_5).');
                    ggsave(\''.$env_effects_sim_figure_tempfile_5_env2.'\', arrangeGrob(gg_env2, gg_p_sim2, gg_eff_sim2, nrow=1), device=\'png\', width=25, height=25, units=\'in\');
                    "';
                    # print STDERR Dumper $cmd_spatialenvsim_plot_5_env2;
                    my $status_spatialenvsim_plot_5_env2 = system($cmd_spatialenvsim_plot_5_env2);
                    push @$spatial_effects_plots, [$env_effects_sim_figure_tempfile_string_5_env2, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_env2effheatmap_"."envvar_".$env_variance_percent."_".$iterations];

                    my $env_effects_sim_figure_tempfile_string_5_env3 = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $env_effects_sim_figure_tempfile_string_5_env3 .= '.png';
                    my $env_effects_sim_figure_tempfile_5_env3 = $c->config->{basepath}."/".$env_effects_sim_figure_tempfile_string_5_env3;

                    my $cmd_spatialenvsim_plot_5_env3 = 'R -e "library(data.table); library(ggplot2); library(dplyr); library(viridis); library(GGally); library(gridExtra);
                    mat_env3 <- fread(\''.$phenotypes_env_heatmap_tempfile3.'\', header=TRUE, sep=\',\');
                    mat_p_sim3 <- fread(\''.$phenotypes_pheno_sim_heatmap_tempfile3_5.'\', header=TRUE, sep=\',\');
                    mat_eff_sim3 <- fread(\''.$effects_sim_heatmap_tempfile3_5.'\', header=TRUE, sep=\',\');
                    options(device=\'png\');
                    par();
                    gg_env3 <- ggplot(mat_env3, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_5).');
                    gg_p_sim3 <- ggplot(mat_p_sim3, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_5).');
                    gg_eff_sim3 <- ggplot(mat_eff_sim3, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_5).');
                    ggsave(\''.$env_effects_sim_figure_tempfile_5_env3.'\', arrangeGrob(gg_env3, gg_p_sim3, gg_eff_sim3, nrow=1), device=\'png\', width=25, height=25, units=\'in\');
                    "';
                    # print STDERR Dumper $cmd_spatialenvsim_plot_5_env3;
                    my $status_spatialenvsim_plot_5_env3 = system($cmd_spatialenvsim_plot_5_env3);
                    push @$spatial_effects_plots, [$env_effects_sim_figure_tempfile_string_5_env3, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_env3effheatmap_"."envvar_".$env_variance_percent."_".$iterations];

                    my $env_effects_sim_figure_tempfile_string_5_env4 = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $env_effects_sim_figure_tempfile_string_5_env4 .= '.png';
                    my $env_effects_sim_figure_tempfile_5_env4 = $c->config->{basepath}."/".$env_effects_sim_figure_tempfile_string_5_env4;

                    my $cmd_spatialenvsim_plot_5_env4 = 'R -e "library(data.table); library(ggplot2); library(dplyr); library(viridis); library(GGally); library(gridExtra);
                    mat_env4 <- fread(\''.$phenotypes_env_heatmap_tempfile4.'\', header=TRUE, sep=\',\');
                    mat_p_sim4 <- fread(\''.$phenotypes_pheno_sim_heatmap_tempfile4_5.'\', header=TRUE, sep=\',\');
                    mat_eff_sim4 <- fread(\''.$effects_sim_heatmap_tempfile4_5.'\', header=TRUE, sep=\',\');
                    options(device=\'png\');
                    par();
                    gg_env4 <- ggplot(mat_env4, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_5).');
                    gg_p_sim4 <- ggplot(mat_p_sim4, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_5).');
                    gg_eff_sim4 <- ggplot(mat_eff_sim4, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_5).');
                    ggsave(\''.$env_effects_sim_figure_tempfile_5_env4.'\', arrangeGrob(gg_env4, gg_p_sim4, gg_eff_sim4, nrow=1), device=\'png\', width=25, height=25, units=\'in\');
                    "';
                    # print STDERR Dumper $cmd_spatialenvsim_plot_5_env4;
                    my $status_spatialenvsim_plot_5_env4 = system($cmd_spatialenvsim_plot_5_env4);
                    push @$spatial_effects_plots, [$env_effects_sim_figure_tempfile_string_5_env4, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_env4effheatmap_"."envvar_".$env_variance_percent."_".$iterations];

                    my $env_effects_sim_figure_tempfile_string_5_env5 = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $env_effects_sim_figure_tempfile_string_5_env5 .= '.png';
                    my $env_effects_sim_figure_tempfile_5_env5 = $c->config->{basepath}."/".$env_effects_sim_figure_tempfile_string_5_env5;

                    my $cmd_spatialenvsim_plot_5_env5 = 'R -e "library(data.table); library(ggplot2); library(dplyr); library(viridis); library(GGally); library(gridExtra);
                    mat_env5 <- fread(\''.$phenotypes_env_heatmap_tempfile5.'\', header=TRUE, sep=\',\');
                    mat_p_sim5 <- fread(\''.$phenotypes_pheno_sim_heatmap_tempfile5_5.'\', header=TRUE, sep=\',\');
                    mat_eff_sim5 <- fread(\''.$effects_sim_heatmap_tempfile5_5.'\', header=TRUE, sep=\',\');
                    options(device=\'png\');
                    par();
                    gg_env5 <- ggplot(mat_env5, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_5).');
                    gg_p_sim5 <- ggplot(mat_p_sim5, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_5).');
                    gg_eff_sim5 <- ggplot(mat_eff_sim5, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_5).');
                    ggsave(\''.$env_effects_sim_figure_tempfile_5_env5.'\', arrangeGrob(gg_env5, gg_p_sim5, gg_eff_sim5, nrow=1), device=\'png\', width=25, height=25, units=\'in\');
                    "';
                    # print STDERR Dumper $cmd_spatialenvsim_plot_5_env5;
                    my $status_spatialenvsim_plot_5_env5 = system($cmd_spatialenvsim_plot_5_env5);
                    push @$spatial_effects_plots, [$env_effects_sim_figure_tempfile_string_5_env5, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_env5effheatmap_"."envvar_".$env_variance_percent."_".$iterations];

                    my $env_effects_sim_figure_tempfile_string_5_env6 = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $env_effects_sim_figure_tempfile_string_5_env6 .= '.png';
                    my $env_effects_sim_figure_tempfile_5_env6 = $c->config->{basepath}."/".$env_effects_sim_figure_tempfile_string_5_env6;

                    my $cmd_spatialenvsim_plot_5_env6 = 'R -e "library(data.table); library(ggplot2); library(dplyr); library(viridis); library(GGally); library(gridExtra);
                    mat_env6 <- fread(\''.$phenotypes_env_heatmap_tempfile6.'\', header=TRUE, sep=\',\');
                    mat_p_sim6 <- fread(\''.$phenotypes_pheno_sim_heatmap_tempfile6_5.'\', header=TRUE, sep=\',\');
                    mat_eff_sim6 <- fread(\''.$effects_sim_heatmap_tempfile6_5.'\', header=TRUE, sep=\',\');
                    options(device=\'png\');
                    par();
                    gg_env6 <- ggplot(mat_env6, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_5).');
                    gg_p_sim6 <- ggplot(mat_p_sim6, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_5).');
                    gg_eff_sim6 <- ggplot(mat_eff_sim6, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_5).');
                    ggsave(\''.$env_effects_sim_figure_tempfile_5_env6.'\', arrangeGrob(gg_env6, gg_p_sim6, gg_eff_sim6, nrow=1), device=\'png\', width=25, height=25, units=\'in\');
                    "';
                    # print STDERR Dumper $cmd_spatialenvsim_plot_5_env6;
                    my $status_spatialenvsim_plot_5_env6 = system($cmd_spatialenvsim_plot_5_env6);
                    push @$spatial_effects_plots, [$env_effects_sim_figure_tempfile_string_5_env6, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_env6effheatmap_"."envvar_".$env_variance_percent."_".$iterations];
                };

                eval {
                    my @sorted_germplasm_names = sort keys %unique_accessions;

                    my @original_blup_vals_5;
                    my ($effects_original_line_chart_tempfile_fh_5, $effects_original_line_chart_tempfile_5) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open(my $F_pheno, ">", $effects_original_line_chart_tempfile_5) || die "Can't open file ".$effects_original_line_chart_tempfile_5;
                        print $F_pheno "germplasmName,time,value\n";
                        foreach my $p (@sorted_germplasm_names) {
                            foreach my $t (@sorted_trait_names_5) {
                                my $val = $result_blup_data_original_5->{$p}->{$t}->[0];
                                my @row = ($p, $t, $val);
                                push @original_blup_vals_5, $val;
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                            }
                        }
                    close($F_pheno);

                    my $original_blup_stat_5 = Statistics::Descriptive::Full->new();
                    $original_blup_stat_5->add_data(@original_blup_vals_5);
                    my $sig_original_blup_5 = $original_blup_stat_5->variance();

                    my @altered_blups_vals_5;
                    my ($effects_altered_line_chart_tempfile_fh_5, $effects_altered_line_chart_tempfile_5) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $effects_altered_line_chart_tempfile_5) || die "Can't open file ".$effects_altered_line_chart_tempfile_5;
                        print $F_pheno "germplasmName,time,value\n";
                        foreach my $p (@sorted_germplasm_names) {
                            foreach my $t (@sorted_trait_names_5) {
                                my $val = $result_blup_data_altered_5->{$p}->{$t}->[0];
                                my @row = ($p, $t, $val);
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                                push @altered_blups_vals_5, $val;
                            }
                        }
                    close($F_pheno);

                    my $altered_blup_stat_5 = Statistics::Descriptive::Full->new();
                    $altered_blup_stat_5->add_data(@altered_blups_vals_5);
                    my $sig_altered_blup_5 = $altered_blup_stat_5->variance();

                    my @sim1_blup_vals_5;
                    my ($effects_altered_env1_line_chart_tempfile_fh_5, $effects_altered_env1_line_chart_tempfile_5) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $effects_altered_env1_line_chart_tempfile_5) || die "Can't open file ".$effects_altered_env1_line_chart_tempfile_5;
                        print $F_pheno "germplasmName,time,value\n";
                        foreach my $p (@sorted_germplasm_names) {
                            foreach my $t (@sorted_trait_names_5) {
                                my $val = $result_blup_data_altered_env_1_5->{$p}->{$t}->[0];
                                my @row = ($p, $t, $val);
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                                push @sim1_blup_vals_5, $val;
                            }
                        }
                    close($F_pheno);

                    my $sim1_blup_stat_5 = Statistics::Descriptive::Full->new();
                    $sim1_blup_stat_5->add_data(@sim1_blup_vals_5);
                    my $sig_sim1_blup_5 = $sim1_blup_stat_5->variance();

                    my @sim2_blup_vals_5;
                    my ($effects_altered_env2_line_chart_tempfile_fh_5, $effects_altered_env2_line_chart_tempfile_5) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $effects_altered_env2_line_chart_tempfile_5) || die "Can't open file ".$effects_altered_env2_line_chart_tempfile_5;
                        print $F_pheno "germplasmName,time,value\n";
                        foreach my $p (@sorted_germplasm_names) {
                            foreach my $t (@sorted_trait_names_5) {
                                my $val = $result_blup_data_altered_env_2_5->{$p}->{$t}->[0];
                                my @row = ($p, $t, $val);
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                                push @sim2_blup_vals_5, $val;
                            }
                        }
                    close($F_pheno);

                    my $sim2_blup_stat_5 = Statistics::Descriptive::Full->new();
                    $sim2_blup_stat_5->add_data(@sim2_blup_vals_5);
                    my $sig_sim2_blup_5 = $sim2_blup_stat_5->variance();

                    my @sim3_blup_vals_5;
                    my ($effects_altered_env3_line_chart_tempfile_fh_5, $effects_altered_env3_line_chart_tempfile_5) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $effects_altered_env3_line_chart_tempfile_5) || die "Can't open file ".$effects_altered_env3_line_chart_tempfile_5;
                        print $F_pheno "germplasmName,time,value\n";
                        foreach my $p (@sorted_germplasm_names) {
                            foreach my $t (@sorted_trait_names_5) {
                                my $val = $result_blup_data_altered_env_3_5->{$p}->{$t}->[0];
                                my @row = ($p, $t, $val);
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                                push @sim3_blup_vals_5, $val;
                            }
                        }
                    close($F_pheno);

                    my $sim3_blup_stat_5 = Statistics::Descriptive::Full->new();
                    $sim3_blup_stat_5->add_data(@sim3_blup_vals_5);
                    my $sig_sim3_blup_5 = $sim3_blup_stat_5->variance();

                    my @sim4_blup_vals_5;
                    my ($effects_altered_env4_line_chart_tempfile_fh_5, $effects_altered_env4_line_chart_tempfile_5) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $effects_altered_env4_line_chart_tempfile_5) || die "Can't open file ".$effects_altered_env4_line_chart_tempfile_5;
                        print $F_pheno "germplasmName,time,value\n";
                        foreach my $p (@sorted_germplasm_names) {
                            foreach my $t (@sorted_trait_names_5) {
                                my $val = $result_blup_data_altered_env_4_5->{$p}->{$t}->[0];
                                my @row = ($p, $t, $val);
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                                push @sim4_blup_vals_5, $val;
                            }
                        }
                    close($F_pheno);

                    my $sim4_blup_stat_5 = Statistics::Descriptive::Full->new();
                    $sim4_blup_stat_5->add_data(@sim4_blup_vals_5);
                    my $sig_sim4_blup_5 = $sim4_blup_stat_5->variance();

                    my @sim5_blup_vals_5;
                    my ($effects_altered_env5_line_chart_tempfile_fh_5, $effects_altered_env5_line_chart_tempfile_5) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $effects_altered_env5_line_chart_tempfile_5) || die "Can't open file ".$effects_altered_env5_line_chart_tempfile_5;
                        print $F_pheno "germplasmName,time,value\n";
                        foreach my $p (@sorted_germplasm_names) {
                            foreach my $t (@sorted_trait_names_5) {
                                my $val = $result_blup_data_altered_env_5_5->{$p}->{$t}->[0];
                                my @row = ($p, $t, $val);
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                                push @sim5_blup_vals_5, $val;
                            }
                        }
                    close($F_pheno);

                    my $sim5_blup_stat_5 = Statistics::Descriptive::Full->new();
                    $sim5_blup_stat_5->add_data(@sim5_blup_vals_5);
                    my $sig_sim5_blup_5 = $sim5_blup_stat_5->variance();

                    my @sim6_blup_vals_5;
                    my ($effects_altered_env6_line_chart_tempfile_fh_5, $effects_altered_env6_line_chart_tempfile_5) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $effects_altered_env6_line_chart_tempfile_5) || die "Can't open file ".$effects_altered_env6_line_chart_tempfile_5;
                        print $F_pheno "germplasmName,time,value\n";
                        foreach my $p (@sorted_germplasm_names) {
                            foreach my $t (@sorted_trait_names_5) {
                                my $val = $result_blup_data_altered_env_6_5->{$p}->{$t}->[0];
                                my @row = ($p, $t, $val);
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                                push @sim6_blup_vals_5, $val;
                            }
                        }
                    close($F_pheno);

                    my $sim6_blup_stat_5 = Statistics::Descriptive::Full->new();
                    $sim6_blup_stat_5->add_data(@sim6_blup_vals_5);
                    my $sig_sim6_blup_5 = $sim6_blup_stat_5->variance();

                    my @set = ('0' ..'9', 'A' .. 'F');
                    my @colors;
                    for (1..scalar(@sorted_germplasm_names)) {
                        my $str = join '' => map $set[rand @set], 1 .. 6;
                        push @colors, '#'.$str;
                    }
                    my $color_string = join '\',\'', @colors;

                    my $genetic_effects_figure_tempfile_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $genetic_effects_figure_tempfile_string .= '.png';
                    my $genetic_effects_figure_tempfile = $c->config->{basepath}."/".$genetic_effects_figure_tempfile_string;

                    my $genetic_effects_alt_figure_tempfile_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $genetic_effects_alt_figure_tempfile_string .= '.png';
                    my $genetic_effects_alt_figure_tempfile = $c->config->{basepath}."/".$genetic_effects_alt_figure_tempfile_string;

                    my $genetic_effects_alt_env1_figure_tempfile_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $genetic_effects_alt_env1_figure_tempfile_string .= '.png';
                    my $genetic_effects_alt_env1_figure_tempfile = $c->config->{basepath}."/".$genetic_effects_alt_env1_figure_tempfile_string;

                    my $genetic_effects_alt_env2_figure_tempfile_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $genetic_effects_alt_env2_figure_tempfile_string .= '.png';
                    my $genetic_effects_alt_env2_figure_tempfile = $c->config->{basepath}."/".$genetic_effects_alt_env2_figure_tempfile_string;

                    my $genetic_effects_alt_env3_figure_tempfile_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $genetic_effects_alt_env3_figure_tempfile_string .= '.png';
                    my $genetic_effects_alt_env3_figure_tempfile = $c->config->{basepath}."/".$genetic_effects_alt_env3_figure_tempfile_string;

                    my $genetic_effects_alt_env4_figure_tempfile_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $genetic_effects_alt_env4_figure_tempfile_string .= '.png';
                    my $genetic_effects_alt_env4_figure_tempfile = $c->config->{basepath}."/".$genetic_effects_alt_env4_figure_tempfile_string;

                    my $genetic_effects_alt_env5_figure_tempfile_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $genetic_effects_alt_env5_figure_tempfile_string .= '.png';
                    my $genetic_effects_alt_env5_figure_tempfile = $c->config->{basepath}."/".$genetic_effects_alt_env5_figure_tempfile_string;

                    my $genetic_effects_alt_env6_figure_tempfile_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $genetic_effects_alt_env6_figure_tempfile_string .= '.png';
                    my $genetic_effects_alt_env6_figure_tempfile = $c->config->{basepath}."/".$genetic_effects_alt_env6_figure_tempfile_string;

                    my $cmd_gen_plot = 'R -e "library(data.table); library(ggplot2); library(GGally); library(gridExtra);
                    mat <- fread(\''.$effects_original_line_chart_tempfile_5.'\', header=TRUE, sep=\',\');
                    mat\$time <- as.numeric(as.character(mat\$time));
                    options(device=\'png\');
                    par();
                    sp <- ggplot(mat, aes(x = time, y = value)) +
                        geom_line(aes(color = germplasmName), size = 1) +
                        scale_fill_manual(values = c(\''.$color_string.'\')) +
                        theme_minimal();
                    sp <- sp + guides(shape = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + guides(color = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + theme(legend.title = element_text(size = 3), legend.text = element_text(size = 3));
                    sp <- sp + labs(title = \'Original Genetic Effects\');';
                    if (scalar(@sorted_germplasm_names) > 100) {
                        $cmd_gen_plot .= 'sp <- sp + theme(legend.position = \'none\');';
                    }
                    $cmd_gen_plot .= 'ggsave(\''.$genetic_effects_figure_tempfile.'\', sp, device=\'png\', width=12, height=6, units=\'in\');
                    "';
                    print STDERR Dumper $cmd_gen_plot;
                    my $status_gen_plot = system($cmd_gen_plot);
                    push @$spatial_effects_plots, [$genetic_effects_figure_tempfile_string, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_efforigline_"."envvar_".$env_variance_percent."_".$iterations];

                    my $cmd_gen_alt_plot = 'R -e "library(data.table); library(ggplot2); library(GGally); library(gridExtra);
                    mat <- fread(\''.$effects_altered_line_chart_tempfile_5.'\', header=TRUE, sep=\',\');
                    mat\$time <- as.numeric(as.character(mat\$time));
                    options(device=\'png\');
                    par();
                    sp <- ggplot(mat, aes(x = time, y = value)) +
                        geom_line(aes(color = germplasmName), size = 1) +
                        scale_fill_manual(values = c(\''.$color_string.'\')) +
                        theme_minimal();
                    sp <- sp + guides(shape = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + guides(color = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + theme(legend.title = element_text(size = 3), legend.text = element_text(size = 3));
                    sp <- sp + labs(title = \'Altered Genetic Effects\');';
                    if (scalar(@sorted_germplasm_names) > 100) {
                        $cmd_gen_alt_plot .= 'sp <- sp + theme(legend.position = \'none\');';
                    }
                    $cmd_gen_alt_plot .= 'ggsave(\''.$genetic_effects_alt_figure_tempfile.'\', sp, device=\'png\', width=12, height=6, units=\'in\');
                    "';
                    print STDERR Dumper $cmd_gen_alt_plot;
                    my $status_gen_alt_plot = system($cmd_gen_alt_plot);
                    push @$spatial_effects_plots, [$genetic_effects_alt_figure_tempfile_string, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_effaltline_"."envvar_".$env_variance_percent."_".$iterations];

                    my $cmd_gen_env1_plot = 'R -e "library(data.table); library(ggplot2); library(GGally); library(gridExtra);
                    mat <- fread(\''.$effects_altered_env1_line_chart_tempfile_5.'\', header=TRUE, sep=\',\');
                    mat\$time <- as.numeric(as.character(mat\$time));
                    options(device=\'png\');
                    par();
                    sp <- ggplot(mat, aes(x = time, y = value)) +
                        geom_line(aes(color = germplasmName), size = 1) +
                        scale_fill_manual(values = c(\''.$color_string.'\')) +
                        theme_minimal();
                    sp <- sp + guides(shape = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + guides(color = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + theme(legend.title = element_text(size = 3), legend.text = element_text(size = 3));
                    sp <- sp + labs(title = \'SimLinear Genetic Effects\');';
                    if (scalar(@sorted_germplasm_names) > 100) {
                        $cmd_gen_env1_plot .= 'sp <- sp + theme(legend.position = \'none\');';
                    }
                    $cmd_gen_env1_plot .= 'ggsave(\''.$genetic_effects_alt_env1_figure_tempfile.'\', sp, device=\'png\', width=12, height=6, units=\'in\');
                    "';
                    print STDERR Dumper $cmd_gen_env1_plot;
                    my $status_gen_env1_plot = system($cmd_gen_env1_plot);
                    push @$spatial_effects_plots, [$genetic_effects_alt_env1_figure_tempfile_string, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_effaltenv1line_"."envvar_".$env_variance_percent."_".$iterations];

                    my $cmd_gen_env2_plot = 'R -e "library(data.table); library(ggplot2); library(GGally); library(gridExtra);
                    mat <- fread(\''.$effects_altered_env2_line_chart_tempfile_5.'\', header=TRUE, sep=\',\');
                    mat\$time <- as.numeric(as.character(mat\$time));
                    options(device=\'png\');
                    par();
                    sp <- ggplot(mat, aes(x = time, y = value)) +
                        geom_line(aes(color = germplasmName), size = 1) +
                        scale_fill_manual(values = c(\''.$color_string.'\')) +
                        theme_minimal();
                    sp <- sp + guides(shape = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + guides(color = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + theme(legend.title = element_text(size = 3), legend.text = element_text(size = 3));
                    sp <- sp + labs(title = \'Sim1DN Genetic Effects\');';
                    if (scalar(@sorted_germplasm_names) > 100) {
                        $cmd_gen_env2_plot .= 'sp <- sp + theme(legend.position = \'none\');';
                    }
                    $cmd_gen_env2_plot .= 'ggsave(\''.$genetic_effects_alt_env2_figure_tempfile.'\', sp, device=\'png\', width=12, height=6, units=\'in\');
                    "';
                    print STDERR Dumper $cmd_gen_env2_plot;
                    my $status_gen_env2_plot = system($cmd_gen_env2_plot);
                    push @$spatial_effects_plots, [$genetic_effects_alt_env2_figure_tempfile_string, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_effaltenv2line_"."envvar_".$env_variance_percent."_".$iterations];

                    my $cmd_gen_env3_plot = 'R -e "library(data.table); library(ggplot2); library(GGally); library(gridExtra);
                    mat <- fread(\''.$effects_altered_env3_line_chart_tempfile_5.'\', header=TRUE, sep=\',\');
                    mat\$time <- as.numeric(as.character(mat\$time));
                    options(device=\'png\');
                    par();
                    sp <- ggplot(mat, aes(x = time, y = value)) +
                        geom_line(aes(color = germplasmName), size = 1) +
                        scale_fill_manual(values = c(\''.$color_string.'\')) +
                        theme_minimal();
                    sp <- sp + guides(shape = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + guides(color = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + theme(legend.title = element_text(size = 3), legend.text = element_text(size = 3));
                    sp <- sp + labs(title = \'Sim2DN Genetic Effects\');';
                    if (scalar(@sorted_germplasm_names) > 100) {
                        $cmd_gen_env3_plot .= 'sp <- sp + theme(legend.position = \'none\');';
                    }
                    $cmd_gen_env3_plot .= 'ggsave(\''.$genetic_effects_alt_env3_figure_tempfile.'\', sp, device=\'png\', width=12, height=6, units=\'in\');
                    "';
                    print STDERR Dumper $cmd_gen_env3_plot;
                    my $status_gen_env3_plot = system($cmd_gen_env3_plot);
                    push @$spatial_effects_plots, [$genetic_effects_alt_env3_figure_tempfile_string, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_effaltenv3line_"."envvar_".$env_variance_percent."_".$iterations];

                    my $cmd_gen_env4_plot = 'R -e "library(data.table); library(ggplot2); library(GGally); library(gridExtra);
                    mat <- fread(\''.$effects_altered_env4_line_chart_tempfile_5.'\', header=TRUE, sep=\',\');
                    mat\$time <- as.numeric(as.character(mat\$time));
                    options(device=\'png\');
                    par();
                    sp <- ggplot(mat, aes(x = time, y = value)) +
                        geom_line(aes(color = germplasmName), size = 1) +
                        scale_fill_manual(values = c(\''.$color_string.'\')) +
                        theme_minimal();
                    sp <- sp + guides(shape = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + guides(color = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + theme(legend.title = element_text(size = 3), legend.text = element_text(size = 3));
                    sp <- sp + labs(title = \'SimRandom Genetic Effects\');';
                    if (scalar(@sorted_germplasm_names) > 100) {
                        $cmd_gen_env4_plot .= 'sp <- sp + theme(legend.position = \'none\');';
                    }
                    $cmd_gen_env4_plot .= 'ggsave(\''.$genetic_effects_alt_env4_figure_tempfile.'\', sp, device=\'png\', width=12, height=6, units=\'in\');
                    "';
                    print STDERR Dumper $cmd_gen_env4_plot;
                    my $status_gen_env4_plot = system($cmd_gen_env4_plot);
                    push @$spatial_effects_plots, [$genetic_effects_alt_env4_figure_tempfile_string, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_effaltenv4line_"."envvar_".$env_variance_percent."_".$iterations];

                    my $cmd_gen_env5_plot = 'R -e "library(data.table); library(ggplot2); library(GGally); library(gridExtra);
                    mat <- fread(\''.$effects_altered_env5_line_chart_tempfile_5.'\', header=TRUE, sep=\',\');
                    mat\$time <- as.numeric(as.character(mat\$time));
                    options(device=\'png\');
                    par();
                    sp <- ggplot(mat, aes(x = time, y = value)) +
                        geom_line(aes(color = germplasmName), size = 1) +
                        scale_fill_manual(values = c(\''.$color_string.'\')) +
                        theme_minimal();
                    sp <- sp + guides(shape = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + guides(color = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + theme(legend.title = element_text(size = 3), legend.text = element_text(size = 3));
                    sp <- sp + labs(title = \'SimRandom Genetic Effects\');';
                    if (scalar(@sorted_germplasm_names) > 100) {
                        $cmd_gen_env5_plot .= 'sp <- sp + theme(legend.position = \'none\');';
                    }
                    $cmd_gen_env5_plot .= 'ggsave(\''.$genetic_effects_alt_env5_figure_tempfile.'\', sp, device=\'png\', width=12, height=6, units=\'in\');
                    "';
                    print STDERR Dumper $cmd_gen_env5_plot;
                    my $status_gen_env5_plot = system($cmd_gen_env5_plot);
                    push @$spatial_effects_plots, [$genetic_effects_alt_env5_figure_tempfile_string, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_effaltenv5line_"."envvar_".$env_variance_percent."_".$iterations];

                    my $cmd_gen_env6_plot = 'R -e "library(data.table); library(ggplot2); library(GGally); library(gridExtra);
                    mat <- fread(\''.$effects_altered_env6_line_chart_tempfile_5.'\', header=TRUE, sep=\',\');
                    mat\$time <- as.numeric(as.character(mat\$time));
                    options(device=\'png\');
                    par();
                    sp <- ggplot(mat, aes(x = time, y = value)) +
                        geom_line(aes(color = germplasmName), size = 1) +
                        scale_fill_manual(values = c(\''.$color_string.'\')) +
                        theme_minimal();
                    sp <- sp + guides(shape = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + guides(color = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + theme(legend.title = element_text(size = 3), legend.text = element_text(size = 3));
                    sp <- sp + labs(title = \'SimRandom Genetic Effects\');';
                    if (scalar(@sorted_germplasm_names) > 100) {
                        $cmd_gen_env6_plot .= 'sp <- sp + theme(legend.position = \'none\');';
                    }
                    $cmd_gen_env6_plot .= 'ggsave(\''.$genetic_effects_alt_env6_figure_tempfile.'\', sp, device=\'png\', width=12, height=6, units=\'in\');
                    "';
                    print STDERR Dumper $cmd_gen_env6_plot;
                    my $status_gen_env6_plot = system($cmd_gen_env6_plot);
                    push @$spatial_effects_plots, [$genetic_effects_alt_env6_figure_tempfile_string, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_effaltenv6line_"."envvar_".$env_variance_percent."_".$iterations];
                };

                %trait_name_encoder = %trait_name_encoder_5;
                %trait_to_time_map = %trait_to_time_map_5;

                push @$env_varcomps, {
                    type => "$statistics_select: Env Variance $env_variance_percent : SimCorrelation: $correlation_between_times : Iteration $iterations",
                    statistics_select => "$statistics_select: Env Variance $env_variance_percent : SimCorrelation: $correlation_between_times",
                    correlation_between_times => $correlation_between_times,
                    env_variance => $env_variance_percent,
                    original => {
                        covariance => $varcomp_original_array_5,
                        cv_1 => $result_cv_original_5,
                        cv_2 => $result_cv_2_original_5
                    },
                    altered => {
                        covariance => $varcomp_altered_array_5,
                        cv_1 => $result_cv_altered_5,
                        cv_2 => $result_cv_2_altered_5
                    },
                    env_linear => {
                        covariance => $varcomp_altered_array_env_1_5,
                        cv_1 => $result_cv_altered_env_1_5,
                        cv_2 => $result_cv_2_altered_env_1_5
                    },
                    env_1DN  => {
                        covariance => $varcomp_altered_array_env_2_5,
                        cv_1 => $result_cv_altered_env_2_5,
                        cv_2 => $result_cv_2_altered_env_2_5
                    },
                    env_2DN  => {
                        covariance => $varcomp_altered_array_env_3_5,
                        cv_1 => $result_cv_altered_env_3_5,
                        cv_2 => $result_cv_2_altered_env_3_5
                    },
                    env_random  => {
                        covariance => $varcomp_altered_array_env_4_5,
                        cv_1 => $result_cv_altered_env_4_5,
                        cv_2 => $result_cv_2_altered_env_4_5
                    },
                    env_ar1xar1  => {
                        covariance => $varcomp_altered_array_env_5_5,
                        cv_1 => $result_cv_altered_env_5_5,
                        cv_2 => $result_cv_2_altered_env_5_5
                    },
                    env_realdata  => {
                        covariance => $varcomp_altered_array_env_6_5,
                        cv_1 => $result_cv_altered_env_6_5,
                        cv_2 => $result_cv_2_altered_env_6_5
                    }
                };
            }

            my (%phenotype_data_original_6, @data_matrix_original_6, @data_matrix_phenotypes_original_6);
            my (%trait_name_encoder_6, %trait_name_encoder_rev_6, %seen_days_after_plantings_6, %stock_info_6, %seen_times_6, %seen_trial_ids_6, %trait_to_time_map_6, %trait_composing_info_6, @sorted_trait_names_6, %seen_trait_names_6, %unique_traits_ids_6, @phenotype_header_6, $header_string_6);
            my (@sorted_scaled_ln_times_6, %plot_id_factor_map_reverse_6, %plot_id_count_map_reverse_6, %accession_id_factor_map_6, %accession_id_factor_map_reverse_6, %time_count_map_reverse_6, @rep_time_factors_6, @ind_rep_factors_6, %plot_rep_time_factor_map_6, %seen_rep_times_6, %seen_ind_reps_6, @legs_header_6, %polynomial_map_6);
            my $time_min_6 = 100000000;
            my $time_max_6 = 0;
            my $phenotype_min_original_6 = 1000000000;
            my $phenotype_max_original_6 = -1000000000;

            if ($statistics_select_original eq 'asreml_grm_multivariate_spatial_genetic_blups') {
                $statistics_select = 'asreml_grm_multivariate_spatial_genetic_blups';

                print STDERR "PREPARE ORIGINAL PHENOTYPE FILES 6\n";
                eval {
                    my $phenotypes_search_6 = CXGN::Phenotypes::SearchFactory->instantiate(
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
                    my ($data_6, $unique_traits_6) = $phenotypes_search_6->search();
                    @sorted_trait_names_6 = sort keys %$unique_traits_6;

                    if (scalar(@$data_6) == 0) {
                        $c->stash->{rest} = { error => "There are no phenotypes for the trials and traits you have selected!"};
                        return;
                    }

                    $q_time = "SELECT t.cvterm_id FROM cvterm as t JOIN cv ON(t.cv_id=cv.cv_id) WHERE t.name=? and cv.name=?;";
                    $h_time = $schema->storage->dbh()->prepare($q_time);

                    foreach my $obs_unit (@$data_6){
                        my $germplasm_name = $obs_unit->{germplasm_uniquename};
                        my $germplasm_stock_id = $obs_unit->{germplasm_stock_id};
                        my $replicate_number = $obs_unit->{obsunit_rep} || '';
                        my $block_number = $obs_unit->{obsunit_block} || '';
                        my $obsunit_stock_id = $obs_unit->{observationunit_stock_id};
                        my $obsunit_stock_uniquename = $obs_unit->{observationunit_uniquename};
                        my $row_number = $obs_unit->{obsunit_row_number} || '';
                        my $col_number = $obs_unit->{obsunit_col_number} || '';
                        push @plot_ids_ordered, $obsunit_stock_id;

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

                        $obsunit_row_col{$row_number}->{$col_number} = {
                            stock_id => $obsunit_stock_id,
                            stock_uniquename => $obsunit_stock_uniquename
                        };
                        $seen_rows{$row_number}++;
                        $seen_cols{$col_number}++;
                        $plot_id_map{$obsunit_stock_id} = $obsunit_stock_uniquename;
                        $seen_plot_names{$obsunit_stock_uniquename}++;
                        $seen_plots{$obsunit_stock_id} = $obsunit_stock_uniquename;
                        $stock_row_col{$obsunit_stock_id} = {
                            row_number => $row_number,
                            col_number => $col_number,
                            obsunit_stock_id => $obsunit_stock_id,
                            obsunit_name => $obsunit_stock_uniquename,
                            rep => $replicate_number,
                            block => $block_number,
                            germplasm_stock_id => $germplasm_stock_id,
                            germplasm_name => $germplasm_name
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
                        $stock_row_col_id{$row_number}->{$col_number} = $obsunit_stock_id;
                        $unique_accessions{$germplasm_name}++;
                        $stock_info_6{$germplasm_stock_id} = {
                            uniquename => $germplasm_name
                        };
                        my $observations = $obs_unit->{observations};
                        foreach (@$observations){
                            if ($_->{associated_image_project_time_json}) {
                                my $related_time_terms_json = decode_json $_->{associated_image_project_time_json};
                                my $time_days_cvterm = $related_time_terms_json->{day};
                                my $time_term_string = $time_days_cvterm;
                                my $time_days = (split '\|', $time_days_cvterm)[0];
                                my $time = (split ' ', $time_days)[1] + 0;
                                $seen_days_after_plantings_6{$time}++;

                                my $value = $_->{value};
                                my $trait_name = $_->{trait_name};
                                $phenotype_data_original_6{$obsunit_stock_uniquename}->{$time} = $value;
                                $seen_times_6{$time} = $trait_name;
                                $seen_trait_names_6{$trait_name} = $time_term_string;
                                $trait_to_time_map_6{$trait_name} = $time;

                                if ($value < $phenotype_min_original_6) {
                                    $phenotype_min_original_6 = $value;
                                }
                                elsif ($value >= $phenotype_max_original_6) {
                                    $phenotype_max_original_6 = $value;
                                }
                            }
                        }
                    }
                    if (scalar(keys %seen_times_6) == 0) {
                        $c->stash->{rest} = { error => "There are no phenotypes with associated days after planting time associated to the traits you have selected!"};
                        return;
                    }

                    @unique_accession_names = sort keys %unique_accessions;
                    @sorted_trait_names_6 = sort {$a <=> $b} keys %seen_times_6;
                    # print STDERR Dumper \@sorted_trait_names_6;

                    my $trait_name_encoded_6 = 1;
                    foreach my $trait_name (@sorted_trait_names_6) {
                        if (!exists($trait_name_encoder_6{$trait_name})) {
                            my $trait_name_e = 't'.$trait_name_encoded_6;
                            $trait_name_encoder_6{$trait_name} = $trait_name_e;
                            $trait_name_encoder_rev_6{$trait_name_e} = $trait_name;
                            $trait_name_encoded_6++;
                        }
                    }

                    foreach (@sorted_trait_names_6) {
                        if ($_ < $time_min_6) {
                            $time_min_6 = $_;
                        }
                        if ($_ >= $time_max_6) {
                            $time_max_6 = $_;
                        }
                    }
                    print STDERR Dumper [$time_min_6, $time_max_6];

                    while ( my ($trait_name, $time_term) = each %seen_trait_names_6) {
                        push @{$trait_composing_info_6{$trait_name}}, $time_term;
                    }

                    @unique_plot_names = sort keys %seen_plot_names;

                    open(my $F_prep, ">", $stats_prep_tempfile) || die "Can't open file ".$stats_prep_tempfile;
                        print $F_prep "accession_id,accession_id_factor,plot_id,plot_id_factor,replicate,time,replicate_time,ind_replicate\n";
                        foreach my $p (@unique_plot_names) {
                            my $replicate = $stock_name_row_col{$p}->{rep};
                            my $germplasm_stock_id = $stock_name_row_col{$p}->{germplasm_stock_id};
                            my $obsunit_stock_id = $stock_name_row_col{$p}->{obsunit_stock_id};
                            foreach my $t (@sorted_trait_names_6) {
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
                    my $status_factor = system($cmd_factor);

                    open(my $fh_factor, '<', $stats_prep_factor_tempfile) or die "Could not open file '$stats_prep_factor_tempfile' $!";
                        print STDERR "Opened $stats_prep_factor_tempfile\n";
                        my $header_d = <$fh_factor>;

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
                            $stock_row_col{$plot_id}->{plot_id_factor} = $plot_id_factor;
                            $stock_name_row_col{$plot_id_map{$plot_id}}->{plot_id_factor} = $plot_id_factor;
                            $plot_rep_time_factor_map{$plot_id}->{$rep}->{$time} = $rep_time;
                            $seen_rep_times{$rep_time}++;
                            $seen_ind_reps{$plot_id_factor}++;
                            $accession_id_factor_map{$accession_id} = $accession_id_factor;
                            $accession_id_factor_map_reverse{$accession_id_factor} = $stock_info_6{$accession_id}->{uniquename};
                            $plot_id_factor_map_reverse{$plot_id_factor} = $seen_plots{$plot_id};
                            $plot_id_count_map_reverse{$line_factor_count} = $seen_plots{$plot_id};
                            $time_count_map_reverse{$line_factor_count} = $time;
                            $line_factor_count++;
                        }
                    close($fh_factor);
                    @rep_time_factors = sort keys %seen_rep_times;
                    @ind_rep_factors = sort keys %seen_ind_reps;

                    foreach my $p (@unique_plot_names) {
                        my $obsunit_stock_id = $stock_name_row_col{$p}->{obsunit_stock_id};
                        if ($fixed_effect_type eq 'fixed_effect_trait') {
                            $stock_name_row_col{$p}->{rep} = defined($fixed_effect_trait_data->{$obsunit_stock_id}) ? $fixed_effect_trait_data->{$obsunit_stock_id} : 0;
                        }
                        my $row_number = $stock_name_row_col{$p}->{row_number};
                        my $col_number = $stock_name_row_col{$p}->{col_number};
                        my $replicate = $stock_name_row_col{$p}->{rep};
                        my $block = $stock_name_row_col{$p}->{block};
                        my $germplasm_stock_id = $stock_name_row_col{$p}->{germplasm_stock_id};
                        my $germplasm_name = $stock_name_row_col{$p}->{germplasm_name};

                        my $current_trait_index = 0;
                        my @row = (
                            $germplasm_stock_id,
                            $obsunit_stock_id,
                            $replicate,
                            $row_number,
                            $col_number,
                            $accession_id_factor_map{$germplasm_stock_id},
                            $stock_row_col{$obsunit_stock_id}->{plot_id_factor}
                        );

                        foreach my $t (@sorted_trait_names_6) {
                            if (defined($phenotype_data_original_6{$p}->{$t})) {
                                push @row, $phenotype_data_original_6{$p}->{$t} + 0;
                            } else {
                                print STDERR $p." : $t : $germplasm_name : NA \n";
                                push @row, '';
                            }

                            $current_trait_index++;
                        }
                        push @data_matrix_original_6, \@row;
                    }

                    @phenotype_header_6 = ("id", "plot_id", "replicate", "rowNumber", "colNumber", "id_factor", "plot_id_factor");
                    foreach (@sorted_trait_names_6) {
                        push @phenotype_header_6, "t$_";
                    }
                    $header_string_6 = join ',', @phenotype_header_6;

                    open($F, ">", $stats_tempfile_2) || die "Can't open file ".$stats_tempfile_2;
                        print $F $header_string_6."\n";
                        foreach (@data_matrix_original_6) {
                            my $line = join ',', @$_;
                            print $F "$line\n";
                        }
                    close($F);
                };

                @seen_rows_array = keys %seen_rows;
                @seen_cols_array = keys %seen_cols;
                $row_stat = Statistics::Descriptive::Full->new();
                $row_stat->add_data(@seen_rows_array);
                $mean_row = $row_stat->mean();
                $sig_row = $row_stat->variance();
                $col_stat = Statistics::Descriptive::Full->new();
                $col_stat->add_data(@seen_cols_array);
                $mean_col = $col_stat->mean();
                $sig_col = $col_stat->variance();

                print STDERR "PREPARE RELATIONSHIP MATRIX\n";
                eval {
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
                            ';
                            if ($return_inverse_matrix) {
                                $cmd .= 'A <- solve(A);
                                ';
                            }
                            $cmd .= 'A <- as.data.frame(A);
                            colnames(A) <- A_wide[,1];
                            A\$stock_id <- A_wide[,1];
                            A_threecol <- melt(A, id.vars = c(\'stock_id\'), measure.vars = A_wide[,1]);
                            A_threecol\$stock_id <- substring(A_threecol\$stock_id, 2);
                            A_threecol\$variable <- substring(A_threecol\$variable, 2);
                            write.table(data.frame(variable = A_threecol\$variable, stock_id = A_threecol\$stock_id, value = A_threecol\$value), file=\''.$grm_out_tempfile.'\', row.names=FALSE, col.names=FALSE, sep=\'\t\');"';
                            print STDERR $cmd."\n";
                            my $status = system($cmd);

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
                            if ($statistics_select eq 'blupf90_grm_random_regression_gdd_blups' || $statistics_select eq 'blupf90_grm_random_regression_dap_blups' || $statistics_select eq 'airemlf90_grm_random_regression_gdd_blups' || $statistics_select eq 'airemlf90_grm_random_regression_dap_blups' || $statistics_select eq 'asreml_grm_univariate_spatial_genetic_blups' || $statistics_select eq 'asreml_grm_multivariate_spatial_genetic_blups') {
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
                            ';
                            if ($return_inverse_matrix) {
                                $cmd .= 'A <- solve(A);
                                ';
                            }
                            $cmd .= 'A <- as.data.frame(A);
                            colnames(A) <- A_wide[,1];
                            A\$stock_id <- A_wide[,1];
                            A_threecol <- melt(A, id.vars = c(\'stock_id\'), measure.vars = A_wide[,1]);
                            A_threecol\$stock_id <- substring(A_threecol\$stock_id, 2);
                            A_threecol\$variable <- substring(A_threecol\$variable, 2);
                            write.table(data.frame(variable = A_threecol\$variable, stock_id = A_threecol\$stock_id, value = A_threecol\$value), file=\''.$grm_out_tempfile.'\', row.names=FALSE, col.names=FALSE, sep=\'\t\');"';
                            print STDERR $cmd."\n";
                            my $status = system($cmd);

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
                            if ($statistics_select eq 'blupf90_grm_random_regression_gdd_blups' || $statistics_select eq 'blupf90_grm_random_regression_dap_blups' || $statistics_select eq 'airemlf90_grm_random_regression_gdd_blups' || $statistics_select eq 'airemlf90_grm_random_regression_dap_blups' || $statistics_select eq 'asreml_grm_univariate_spatial_genetic_blups' || $statistics_select eq 'asreml_grm_multivariate_spatial_genetic_blups') {
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
                                return_inverse=>$return_inverse_matrix,
                                ensure_positive_definite=>$ensure_positive_definite
                                # minor_allele_frequency=>$minor_allele_frequency,
                                # marker_filter=>$marker_filter,
                                # individuals_filter=>$individuals_filter
                            };

                            if ($statistics_select eq 'blupf90_grm_random_regression_gdd_blups' || $statistics_select eq 'blupf90_grm_random_regression_dap_blups' || $statistics_select eq 'airemlf90_grm_random_regression_gdd_blups' || $statistics_select eq 'airemlf90_grm_random_regression_dap_blups' || $statistics_select eq 'asreml_grm_univariate_spatial_genetic_blups' || $statistics_select eq 'asreml_grm_multivariate_spatial_genetic_blups') {
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
                            ';
                            if ($return_inverse_matrix) {
                                $htp_cmd .= 'cor_mat <- solve(cor_mat);
                                ';
                            }
                            $htp_cmd .= 'write.table(cor_mat, file=\''.$stats_out_htp_rel_tempfile.'\', row.names=TRUE, col.names=TRUE, sep=\'\t\');"';
                            print STDERR Dumper $htp_cmd;
                            my $status = system($htp_cmd);
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
                            ';
                            if ($return_inverse_matrix) {
                                $htp_cmd .= 'rel <- solve(rel);
                                ';
                            }
                            $htp_cmd .= 'rownames(rel) <- blues[,2];
                            colnames(rel) <- blues[,2];
                            write.table(rel, file=\''.$stats_out_htp_rel_tempfile.'\', row.names=TRUE, col.names=TRUE, sep=\'\t\');"';
                            print STDERR Dumper $htp_cmd;
                            my $status = system($htp_cmd);
                        }
                        else {
                            $c->stash->{rest} = { error => "The value of $compute_relationship_matrix_from_htp_phenotypes_type htp_pheno_rel_matrix_type is not valid!" };
                            return;
                        }

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
                        if ($statistics_select eq 'blupf90_grm_random_regression_gdd_blups' || $statistics_select eq 'blupf90_grm_random_regression_dap_blups' || $statistics_select eq 'airemlf90_grm_random_regression_gdd_blups' || $statistics_select eq 'airemlf90_grm_random_regression_dap_blups' || $statistics_select eq 'asreml_grm_univariate_spatial_genetic_blups' || $statistics_select eq 'asreml_grm_multivariate_spatial_genetic_blups') {
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
                };

                my $result_6 = CXGN::DroneImagery::DroneImageryAnalyticsRunSimulation::perform_drone_imagery_analytics($schema, $a_env, $b_env, $ro_env, $row_ro_env, $env_variance_percent, $protocol_id, $statistics_select, $analytics_select, $tolparinv, $use_area_under_curve, $legendre_order_number, $permanent_environment_structure, \@legendre_coeff_exec, \%trait_name_encoder_6, \%trait_name_encoder_rev_6, \%stock_info_6, \%plot_id_map, \@sorted_trait_names_6, \%accession_id_factor_map, \@rep_time_factors, \@ind_rep_factors, \@unique_accession_names, \%plot_id_count_map_reverse, \@sorted_scaled_ln_times, \%time_count_map_reverse, \%accession_id_factor_map_reverse, \%seen_times, \%plot_id_factor_map_reverse, \%trait_to_time_map_6, \@unique_plot_names, \%stock_name_row_col, \%phenotype_data_original_6, \%plot_rep_time_factor_map, \%stock_row_col, \%stock_row_col_id, \%polynomial_map, \@plot_ids_ordered, $csv, $timestamp, $user_name, $stats_tempfile, $grm_file, $grm_rename_tempfile, $tmp_stats_dir, $stats_out_tempfile, $stats_out_tempfile_row, $stats_out_tempfile_col, $stats_out_tempfile_residual, $stats_out_tempfile_2dspl, $stats_prep2_tempfile, $stats_out_param_tempfile, $parameter_tempfile, $parameter_asreml_tempfile, $stats_tempfile_2, $permanent_environment_structure_tempfile, $permanent_environment_structure_env_tempfile, $permanent_environment_structure_env_tempfile2, $permanent_environment_structure_env_tempfile_mat, $sim_env_changing_mat_tempfile, $sim_env_changing_mat_full_tempfile, $yhat_residual_tempfile, $blupf90_solutions_tempfile, $coeff_genetic_tempfile, $coeff_pe_tempfile, $stats_out_tempfile_varcomp, $time_min, $time_max, $header_string_6, $env_sim_exec, $min_row, $max_row, $min_col, $max_col, $mean_row, $sig_row, $mean_col, $sig_col, $sim_env_change_over_time, $correlation_between_times, $field_trial_id_list, $simulated_environment_real_data_trait_id, $fixed_effect_type, $perform_cv);
                if (ref($result_6) eq 'HASH') {
                    $c->stash->{rest} = $result_6;
                    $c->detach();
                }
                my ($statistical_ontology_term_6, $analysis_model_training_data_file_type_6, $analysis_model_language_6, $sorted_residual_trait_names_array_6, $rr_unique_traits_hash_6, $rr_residual_unique_traits_hash_6, $statistics_cmd_6, $cmd_f90_6, $number_traits_6, $trait_to_time_map_hash_6,

                $result_blup_data_original_6, $result_blup_data_delta_original_6, $result_blup_spatial_data_original_6, $result_blup_pe_data_original_6, $result_blup_pe_data_delta_original_6, $result_residual_data_original_6, $result_fitted_data_original_6, $fixed_effects_original_hash_6,
                $rr_genetic_coefficients_original_hash_6, $rr_temporal_coefficients_original_hash_6,
                $rr_coeff_genetic_covariance_original_array_6, $rr_coeff_env_covariance_original_array_6, $rr_coeff_genetic_correlation_original_array_6, $rr_coeff_env_correlation_original_array_6, $rr_residual_variance_original_6, $varcomp_original_array_6,
                $model_sum_square_residual_original_6, $genetic_effect_min_original_6, $genetic_effect_max_original_6, $env_effect_min_original_6, $env_effect_max_original_6, $genetic_effect_sum_square_original_6, $genetic_effect_sum_original_6, $env_effect_sum_square_original_6, $env_effect_sum_original_6, $residual_sum_square_original_6, $residual_sum_original_6, $result_cv_original_6, $result_cv_2_original_6,

                $phenotype_data_altered_hash_6, $data_matrix_altered_array_6, $data_matrix_phenotypes_altered_array_6, $phenotype_min_altered_6, $phenotype_max_altered_6,
                $result_blup_data_altered_6, $result_blup_data_delta_altered_6, $result_blup_spatial_data_altered_6, $result_blup_pe_data_altered_6, $result_blup_pe_data_delta_altered_6, $result_residual_data_altered_6, $result_fitted_data_altered_6, $fixed_effects_altered_hash_6,
                $rr_genetic_coefficients_altered_hash_6, $rr_temporal_coefficients_altered_hash_6,
                $rr_coeff_genetic_covariance_altered_array_6, $rr_coeff_env_covariance_altered_array_6, $rr_coeff_genetic_correlation_altered_array_6, $rr_coeff_env_correlation_altered_array_6, $rr_residual_variance_altered_6, $varcomp_altered_array_6,
                $model_sum_square_residual_altered_6, $genetic_effect_min_altered_6, $genetic_effect_max_altered_6, $env_effect_min_altered_6, $env_effect_max_altered_6, $genetic_effect_sum_square_altered_6, $genetic_effect_sum_altered_6, $env_effect_sum_square_altered_6, $env_effect_sum_altered_6, $residual_sum_square_altered_6, $residual_sum_altered_6, $result_cv_altered_6, $result_cv_2_altered_6,

                $phenotype_data_altered_env_hash_1_6, $data_matrix_altered_env_array_1_6, $data_matrix_phenotypes_altered_env_array_1_6, $phenotype_min_altered_env_1_6, $phenotype_max_altered_env_1_6, $env_sim_min_1_6, $env_sim_max_1_6, $sim_data_hash_1_6,
                $result_blup_data_altered_env_1_6, $result_blup_data_delta_altered_env_1_6, $result_blup_spatial_data_altered_env_1_6, $result_blup_pe_data_altered_env_1_6, $result_blup_pe_data_delta_altered_env_1_6, $result_residual_data_altered_env_1_6, $result_fitted_data_altered_env_1_6, $fixed_effects_altered_env_hash_1_6, $rr_genetic_coefficients_altered_env_hash_1_6, $rr_temporal_coefficients_altered_env_hash_1_6,
                $rr_coeff_genetic_covariance_altered_env_array_1_6, $rr_coeff_env_covariance_altered_env_array_1_6, $rr_coeff_genetic_correlation_altered_env_array_1_6, $rr_coeff_env_correlation_altered_env_array_1_6, $rr_residual_variance_altered_env_1_6, $varcomp_altered_array_env_1_6,
                $model_sum_square_residual_altered_env_1_6, $genetic_effect_min_altered_env_1_6, $genetic_effect_max_altered_env_1_6, $env_effect_min_altered_env_1_6, $env_effect_max_altered_env_1_6, $genetic_effect_sum_square_altered_env_1_6, $genetic_effect_sum_altered_env_1_6, $env_effect_sum_square_altered_env_1_6, $env_effect_sum_altered_env_1_6, $residual_sum_square_altered_env_1_6, $residual_sum_altered_env_1_6, $result_cv_altered_env_1_6, $result_cv_2_altered_env_1_6,

                $phenotype_data_altered_env_hash_2_6, $data_matrix_altered_env_array_2_6, $data_matrix_phenotypes_altered_env_array_2_6, $phenotype_min_altered_env_2_6, $phenotype_max_altered_env_2_6, $env_sim_min_2_6, $env_sim_max_2_6, $sim_data_hash_2_6,
                $result_blup_data_altered_env_2_6, $result_blup_data_delta_altered_env_2_6, $result_blup_spatial_data_altered_env_2_6, $result_blup_pe_data_altered_env_2_6, $result_blup_pe_data_delta_altered_env_2_6, $result_residual_data_altered_env_2_6, $result_fitted_data_altered_env_2_6, $fixed_effects_altered_env_hash_2_6, $rr_genetic_coefficients_altered_env_hash_2_6, $rr_temporal_coefficients_altered_env_hash_2_6,
                $rr_coeff_genetic_covariance_altered_env_array_2_6, $rr_coeff_env_covariance_altered_env_array_2_6, $rr_coeff_genetic_correlation_altered_env_array_2_6, $rr_coeff_env_correlation_altered_env_array_2_6, $rr_residual_variance_altered_env_2_6, $varcomp_altered_array_env_2_6,
                $model_sum_square_residual_altered_env_2_6, $genetic_effect_min_altered_env_2_6, $genetic_effect_max_altered_env_2_6, $env_effect_min_altered_env_2_6, $env_effect_max_altered_env_2_6, $genetic_effect_sum_square_altered_env_2_6, $genetic_effect_sum_altered_env_2_6, $env_effect_sum_square_altered_env_2_6, $env_effect_sum_altered_env_2_6, $residual_sum_square_altered_env_2_6, $residual_sum_altered_env_2_6, $result_cv_altered_env_2_6, $result_cv_2_altered_env_2_6,

                $phenotype_data_altered_env_hash_3_6, $data_matrix_altered_env_array_3_6, $data_matrix_phenotypes_altered_env_array_3_6, $phenotype_min_altered_env_3_6, $phenotype_max_altered_env_3_6, $env_sim_min_3_6, $env_sim_max_3_6, $sim_data_hash_3_6,
                $result_blup_data_altered_env_3_6, $result_blup_data_delta_altered_env_3_6, $result_blup_spatial_data_altered_env_3_6, $result_blup_pe_data_altered_env_3_6, $result_blup_pe_data_delta_altered_env_3_6, $result_residual_data_altered_env_3_6, $result_fitted_data_altered_env_3_6, $fixed_effects_altered_env_hash_3_6, $rr_genetic_coefficients_altered_env_hash_3_6, $rr_temporal_coefficients_altered_env_hash_3_6,
                $rr_coeff_genetic_covariance_altered_env_array_3_6, $rr_coeff_env_covariance_altered_env_array_3_6, $rr_coeff_genetic_correlation_altered_env_array_3_6, $rr_coeff_env_correlation_altered_env_array_3_6, $rr_residual_variance_altered_env_3_6, $varcomp_altered_array_env_3_6,
                $model_sum_square_residual_altered_env_3_6, $genetic_effect_min_altered_env_3_6, $genetic_effect_max_altered_env_3_6, $env_effect_min_altered_env_3_6, $env_effect_max_altered_env_3_6, $genetic_effect_sum_square_altered_env_3_6, $genetic_effect_sum_altered_env_3_6, $env_effect_sum_square_altered_env_3_6, $env_effect_sum_altered_env_3_6, $residual_sum_square_altered_env_3_6, $residual_sum_altered_env_3_6, $result_cv_altered_env_3_6, $result_cv_2_altered_env_3_6,

                $phenotype_data_altered_env_hash_4_6, $data_matrix_altered_env_array_4_6, $data_matrix_phenotypes_altered_env_array_4_6, $phenotype_min_altered_env_4_6, $phenotype_max_altered_env_4_6, $env_sim_min_4_6, $env_sim_max_4_6, $sim_data_hash_4_6,
                $result_blup_data_altered_env_4_6, $result_blup_data_delta_altered_env_4_6, $result_blup_spatial_data_altered_env_4_6, $result_blup_pe_data_altered_env_4_6, $result_blup_pe_data_delta_altered_env_4_6, $result_residual_data_altered_env_4_6, $result_fitted_data_altered_env_4_6, $fixed_effects_altered_env_hash_4_6, $rr_genetic_coefficients_altered_env_hash_4_6, $rr_temporal_coefficients_altered_env_hash_4_6,
                $rr_coeff_genetic_covariance_altered_env_array_4_6, $rr_coeff_env_covariance_altered_env_array_4_6, $rr_coeff_genetic_correlation_altered_env_array_4_6, $rr_coeff_env_correlation_altered_env_array_4_6, $rr_residual_variance_altered_env_4_6, $varcomp_altered_array_env_4_6,
                $model_sum_square_residual_altered_env_4_6, $genetic_effect_min_altered_env_4_6, $genetic_effect_max_altered_env_4_6, $env_effect_min_altered_env_4_6, $env_effect_max_altered_env_4_6, $genetic_effect_sum_square_altered_env_4_6, $genetic_effect_sum_altered_env_4_6, $env_effect_sum_square_altered_env_4_6, $env_effect_sum_altered_env_4_6, $residual_sum_square_altered_env_4_6, $residual_sum_altered_env_4_6, $result_cv_altered_env_4_6, $result_cv_2_altered_env_4_6,

                $phenotype_data_altered_env_hash_5_6, $data_matrix_altered_env_array_5_6, $data_matrix_phenotypes_altered_env_array_5_6, $phenotype_min_altered_env_5_6, $phenotype_max_altered_env_5_6, $env_sim_min_5_6, $env_sim_max_5_6, $sim_data_hash_5_6,
                $result_blup_data_altered_env_5_6, $result_blup_data_delta_altered_env_5_6, $result_blup_spatial_data_altered_env_5_6, $result_blup_pe_data_altered_env_5_6, $result_blup_pe_data_delta_altered_env_5_6, $result_residual_data_altered_env_5_6, $result_fitted_data_altered_env_5_6, $fixed_effects_altered_env_hash_5_6, $rr_genetic_coefficients_altered_env_hash_5_6, $rr_temporal_coefficients_altered_env_hash_5_6,
                $rr_coeff_genetic_covariance_altered_env_array_5_6, $rr_coeff_env_covariance_altered_env_array_5_6, $rr_coeff_genetic_correlation_altered_env_array_5_6, $rr_coeff_env_correlation_altered_env_array_5_6, $rr_residual_variance_altered_env_5_6, $varcomp_altered_array_env_5_6,
                $model_sum_square_residual_altered_env_5_6, $genetic_effect_min_altered_env_5_6, $genetic_effect_max_altered_env_5_6, $env_effect_min_altered_env_5_6, $env_effect_max_altered_env_5_6, $genetic_effect_sum_square_altered_env_5_6, $genetic_effect_sum_altered_env_5_6, $env_effect_sum_square_altered_env_5_6, $env_effect_sum_altered_env_5_6, $residual_sum_square_altered_env_5_6, $residual_sum_altered_env_5_6, $result_cv_altered_env_5_6, $result_cv_2_altered_env_5_6,

                $phenotype_data_altered_env_hash_6_6, $data_matrix_altered_env_array_6_6, $data_matrix_phenotypes_altered_env_array_6_6, $phenotype_min_altered_env_6_6, $phenotype_max_altered_env_6_6, $env_sim_min_6_6, $env_sim_max_6_6, $sim_data_hash_6_6,
                $result_blup_data_altered_env_6_6, $result_blup_data_delta_altered_env_6_6, $result_blup_spatial_data_altered_env_6_6, $result_blup_pe_data_altered_env_6_6, $result_blup_pe_data_delta_altered_env_6_6, $result_residual_data_altered_env_6_6, $result_fitted_data_altered_env_6_6, $fixed_effects_altered_env_hash_6_6, $rr_genetic_coefficients_altered_env_hash_6_6, $rr_temporal_coefficients_altered_env_hash_6_6,
                $rr_coeff_genetic_covariance_altered_env_array_6_6, $rr_coeff_env_covariance_altered_env_array_6_6, $rr_coeff_genetic_correlation_altered_env_array_6_6, $rr_coeff_env_correlation_altered_env_array_6_6, $rr_residual_variance_altered_env_6_6, $varcomp_altered_array_env_6_6,
                $model_sum_square_residual_altered_env_6_6, $genetic_effect_min_altered_env_6_6, $genetic_effect_max_altered_env_6_6, $env_effect_min_altered_env_6_6, $env_effect_max_altered_env_6_6, $genetic_effect_sum_square_altered_env_6_6, $genetic_effect_sum_altered_env_6_6, $env_effect_sum_square_altered_env_6_6, $env_effect_sum_altered_env_6_6, $residual_sum_square_altered_env_6_6, $residual_sum_altered_env_6_6, $result_cv_altered_env_6_6, $result_cv_2_altered_env_6_6
                ) = @$result_6;

                eval {
                    print STDERR "PLOTTING CORRELATION\n";
                    my ($full_plot_level_correlation_tempfile_fh, $full_plot_level_correlation_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open(my $F_fullplot, ">", $full_plot_level_correlation_tempfile) || die "Can't open file ".$full_plot_level_correlation_tempfile;
                        print STDERR "OPENED PLOTCORR FILE $full_plot_level_correlation_tempfile\n";

                        my @header_full_plot_corr = ('plot_name, plot_id, row_number, col_number, rep, block, germplasm_name, germplasm_id');
                        my @types_full_plot_corr = ('pheno_orig_', 'pheno_postm6_', 'eff_origm6_', 'eff_postm6_',
                        'sim_env1_', 'simm6_pheno1_', 'effm6_sim1_',
                        'sim_env2_', 'simm6_pheno2_', 'effm6_sim2_',
                        'sim_env3_', 'simm6_pheno3_', 'effm6_sim3_',
                        'sim_env4_', 'simm6_pheno4_', 'effm6_sim4_',
                        'sim_env5_', 'simm6_pheno5_', 'effm6_sim5_',
                        'sim_env6_', 'simm6_pheno6_', 'effm6_sim6_');
                        foreach my $t (@sorted_trait_names_6) {
                            foreach my $type (@types_full_plot_corr) {
                                push @header_full_plot_corr, $type.$trait_name_encoder_6{$t};
                            }
                        }
                        my $header_string_full_plot_corr = join ',', @header_full_plot_corr;
                        print $F_fullplot "$header_string_full_plot_corr\n";
                        foreach my $p (@unique_plot_names) {
                            my @row = ($p, $stock_name_row_col{$p}->{obsunit_stock_id}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $stock_name_row_col{$p}->{rep}, $stock_name_row_col{$p}->{block}, $stock_name_row_col{$p}->{germplasm_name}, $stock_name_row_col{$p}->{germplasm_stock_id});
                            foreach my $t (@sorted_trait_names_6) {
                                my $phenotype_original = $phenotype_data_original_6{$p}->{$t};
                                my $phenotype_post_6 = $phenotype_data_altered_hash_6->{$p}->{$t};
                                my $effect_original_6 = $result_blup_spatial_data_original_6->{$p}->{$t}->[0];
                                my $effect_post_6 = $result_blup_spatial_data_altered_6->{$p}->{$t}->[0];
                                push @row, ($phenotype_original, $phenotype_post_6, $effect_original_6, $effect_post_6);

                                my $sim_env = $sim_data_hash_1_6->{$p}->{$t};
                                my $pheno_sim_6 = $phenotype_data_altered_env_hash_1_6->{$p}->{$t};
                                my $effect_sim_6 = $result_blup_spatial_data_altered_env_1_6->{$p}->{$t}->[0];
                                push @row, ($sim_env, $pheno_sim_6, $effect_sim_6);

                                my $sim_env2 = $sim_data_hash_2_6->{$p}->{$t};
                                my $pheno_sim2_6 = $phenotype_data_altered_env_hash_2_6->{$p}->{$t};
                                my $effect_sim2_6 = $result_blup_spatial_data_altered_env_2_6->{$p}->{$t}->[0];
                                push @row, ($sim_env2, $pheno_sim2_6, $effect_sim2_6);

                                my $sim_env3 = $sim_data_hash_3_6->{$p}->{$t};
                                my $pheno_sim3_6 = $phenotype_data_altered_env_hash_3_6->{$p}->{$t};
                                my $effect_sim3_6 = $result_blup_spatial_data_altered_env_3_6->{$p}->{$t}->[0];
                                push @row, ($sim_env3, $pheno_sim3_6, $effect_sim3_6);

                                my $sim_env4 = $sim_data_hash_4_6->{$p}->{$t};
                                my $pheno_sim4_6 = $phenotype_data_altered_env_hash_4_6->{$p}->{$t};
                                my $effect_sim4_6 = $result_blup_spatial_data_altered_env_4_6->{$p}->{$t}->[0];
                                push @row, ($sim_env4, $pheno_sim4_6, $effect_sim4_6);

                                my $sim_env5 = $sim_data_hash_5_6->{$p}->{$t};
                                my $pheno_sim5_6 = $phenotype_data_altered_env_hash_5_6->{$p}->{$t};
                                my $effect_sim5_6 = $result_blup_spatial_data_altered_env_5_6->{$p}->{$t}->[0];
                                push @row, ($sim_env5, $pheno_sim5_6, $effect_sim5_6);

                                my $sim_env6 = $sim_data_hash_6_6->{$p}->{$t};
                                my $pheno_sim6_6 = $phenotype_data_altered_env_hash_6_6->{$p}->{$t};
                                my $effect_sim6_6 = $result_blup_spatial_data_altered_env_6_6->{$p}->{$t}->[0];
                                push @row, ($sim_env6, $pheno_sim6_6, $effect_sim6_6);
                            }
                            my $line = join ',', @row;
                            print $F_fullplot "$line\n";
                        }
                    close($F_fullplot);

                    my $plot_corr_figure_tempfile_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $plot_corr_figure_tempfile_string .= '.png';
                    my $plot_corr_figure_tempfile = $c->config->{basepath}."/".$plot_corr_figure_tempfile_string;

                    my $cmd_plotcorr_plot = 'R -e "library(data.table); library(ggplot2); library(GGally);
                    mat_orig <- fread(\''.$full_plot_level_correlation_tempfile.'\', header=TRUE, sep=\',\');
                    gg <- ggcorr(data=mat_orig[,-seq(1,8)], hjust = 1, size = 2, color = \'grey50\', layout.exp = 1, label = TRUE);
                    ggsave(\''.$plot_corr_figure_tempfile.'\', gg, device=\'png\', width=30, height=30, limitsize = FALSE, units=\'in\');
                    "';
                    # print STDERR Dumper $cmd;
                    my $status_plotcorr_plot = system($cmd_plotcorr_plot);
                    push @$spatial_effects_plots, [$plot_corr_figure_tempfile_string, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_fullcorr_"."envvar_".$env_variance_percent."_".$iterations];
                    push @$spatial_effects_files_store, [$full_plot_level_correlation_tempfile, "datafile_".$statistics_select.$sim_env_change_over_time.$correlation_between_times."_fullcorr_"."envvar_".$env_variance_percent."_".$iterations];
                };

                eval {
                    my @plot_corr_full_vals;

                    my @original_pheno_vals;
                    my ($phenotypes_original_heatmap_tempfile_fh, $phenotypes_original_heatmap_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open(my $F_pheno, ">", $phenotypes_original_heatmap_tempfile) || die "Can't open file ".$phenotypes_original_heatmap_tempfile;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_6) {
                                my $val = $phenotype_data_original_6{$p}->{$t};
                                my @row = ("pheno_orig_".$trait_name_encoder_6{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                push @original_pheno_vals, $val;
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                            }
                        }
                    close($F_pheno);
                    push @plot_corr_full_vals, \@original_pheno_vals;

                    my $original_pheno_stat = Statistics::Descriptive::Full->new();
                    $original_pheno_stat->add_data(@original_pheno_vals);
                    my $sig_original_pheno = $original_pheno_stat->variance();

                    #PHENO POST M START

                    my @altered_pheno_vals_6;
                    my ($phenotypes_post_heatmap_tempfile_fh_6, $phenotypes_post_heatmap_tempfile_6) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $phenotypes_post_heatmap_tempfile_6) || die "Can't open file ".$phenotypes_post_heatmap_tempfile_6;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_6) {
                                my $val = $phenotype_data_altered_hash_6->{$p}->{$t};
                                my @row = ("pheno_postm6_".$trait_name_encoder_6{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                push @altered_pheno_vals_6, $val;
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                            }
                        }
                    close($F_pheno);
                    push @plot_corr_full_vals, \@altered_pheno_vals_6;

                    my $altered_pheno_stat_6 = Statistics::Descriptive::Full->new();
                    $altered_pheno_stat_6->add_data(@altered_pheno_vals_6);
                    my $sig_altered_pheno_6 = $altered_pheno_stat_6->variance();

                    # EFFECT ORIGINAL M

                    my @original_effect_vals_6;
                    my ($effects_heatmap_tempfile_fh_6, $effects_heatmap_tempfile_6) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open(my $F_eff, ">", $effects_heatmap_tempfile_6) || die "Can't open file ".$effects_heatmap_tempfile_6;
                        print $F_eff "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_6) {
                                my $val = $result_blup_spatial_data_original_6->{$p}->{$t}->[0];
                                my @row = ("eff_origm6_".$trait_name_encoder_6{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_eff "$line\n";
                                push @original_effect_vals_6, $val;
                            }
                        }
                    close($F_eff);
                    push @plot_corr_full_vals, \@original_effect_vals_6;

                    my $original_effect_stat_6 = Statistics::Descriptive::Full->new();
                    $original_effect_stat_6->add_data(@original_effect_vals_6);
                    my $sig_original_effect_6 = $original_effect_stat_6->variance();

                    # EFFECT POST M MIN

                    my @altered_effect_vals_6;
                    my ($effects_post_heatmap_tempfile_fh_6, $effects_post_heatmap_tempfile_6) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_eff, ">", $effects_post_heatmap_tempfile_6) || die "Can't open file ".$effects_post_heatmap_tempfile_6;
                        print $F_eff "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_6) {
                                my $val = $result_blup_spatial_data_altered_6->{$p}->{$t}->[0];
                                my @row = ("eff_postm6_".$trait_name_encoder_6{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_eff "$line\n";
                                push @altered_effect_vals_6, $val;
                            }
                        }
                    close($F_eff);
                    push @plot_corr_full_vals, \@altered_effect_vals_6;

                    my $altered_effect_stat_6 = Statistics::Descriptive::Full->new();
                    $altered_effect_stat_6->add_data(@altered_effect_vals_6);
                    my $sig_altered_effect_6 = $altered_effect_stat_6->variance();

                    # SIM ENV 1: ALTERED PHENO + EFFECT

                    my ($phenotypes_env_heatmap_tempfile_fh, $phenotypes_env_heatmap_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $phenotypes_env_heatmap_tempfile) || die "Can't open file ".$phenotypes_env_heatmap_tempfile;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_6) {
                                my @row = ("sim_env1_".$trait_name_encoder_6{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $sim_data_hash_1_6->{$p}->{$t});
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                            }
                        }
                    close($F_pheno);

                    my @sim_pheno1_vals_6;
                    my ($phenotypes_pheno_sim_heatmap_tempfile_fh_6, $phenotypes_pheno_sim_heatmap_tempfile_6) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $phenotypes_pheno_sim_heatmap_tempfile_6) || die "Can't open file ".$phenotypes_pheno_sim_heatmap_tempfile_6;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_6) {
                                my $val = $phenotype_data_altered_env_hash_1_6->{$p}->{$t};
                                my @row = ("simm6_pheno1_".$trait_name_encoder_6{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                                push @sim_pheno1_vals_6, $val;
                            }
                        }
                    close($F_pheno);
                    push @plot_corr_full_vals, \@sim_pheno1_vals_6;

                    my $sim_pheno1_stat_6 = Statistics::Descriptive::Full->new();
                    $sim_pheno1_stat_6->add_data(@sim_pheno1_vals_6);
                    my $sig_sim6_pheno1 = $sim_pheno1_stat_6->variance();

                    my @sim_effect1_vals_6;
                    my ($effects_sim_heatmap_tempfile_fh_6, $effects_sim_heatmap_tempfile_6) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_eff, ">", $effects_sim_heatmap_tempfile_6) || die "Can't open file ".$effects_sim_heatmap_tempfile_6;
                        print $F_eff "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_6) {
                                my $val = $result_blup_spatial_data_altered_env_1_6->{$p}->{$t}->[0];
                                my @row = ("effm6_sim1_".$trait_name_encoder_6{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_eff "$line\n";
                                push @sim_effect1_vals_6, $val;
                            }
                        }
                    close($F_eff);
                    push @plot_corr_full_vals, \@sim_effect1_vals_6;

                    my $sim_effect1_stat_6 = Statistics::Descriptive::Full->new();
                    $sim_effect1_stat_6->add_data(@sim_effect1_vals_6);
                    my $sig_sim6_effect1 = $sim_effect1_stat_6->variance();

                    # SIM ENV 2: ALTERED PHENO + EFFECT

                    my ($phenotypes_env_heatmap_tempfile2_fh, $phenotypes_env_heatmap_tempfile2) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $phenotypes_env_heatmap_tempfile2) || die "Can't open file ".$phenotypes_env_heatmap_tempfile2;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_6) {
                                my @row = ("sim_env2_".$trait_name_encoder_6{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $sim_data_hash_2_6->{$p}->{$t});
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                            }
                        }
                    close($F_pheno);

                    my @sim_pheno2_vals_6;
                    my ($phenotypes_pheno_sim_heatmap_tempfile2_fh_6, $phenotypes_pheno_sim_heatmap_tempfile2_6) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $phenotypes_pheno_sim_heatmap_tempfile2_6) || die "Can't open file ".$phenotypes_pheno_sim_heatmap_tempfile2_6;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_6) {
                                my $val = $phenotype_data_altered_env_hash_2_6->{$p}->{$t};
                                my @row = ("simm6_pheno2_".$trait_name_encoder_6{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                                push @sim_pheno2_vals_6, $val;
                            }
                        }
                    close($F_pheno);
                    push @plot_corr_full_vals, \@sim_pheno2_vals_6;

                    my $sim_pheno2_stat_6 = Statistics::Descriptive::Full->new();
                    $sim_pheno2_stat_6->add_data(@sim_pheno2_vals_6);
                    my $sig_sim_pheno2_6 = $sim_pheno2_stat_6->variance();

                    my @sim_effect2_vals_6;
                    my ($effects_sim_heatmap_tempfile2_fh_6, $effects_sim_heatmap_tempfile2_6) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_eff, ">", $effects_sim_heatmap_tempfile2_6) || die "Can't open file ".$effects_sim_heatmap_tempfile2_6;
                        print $F_eff "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_6) {
                                my $val = $result_blup_spatial_data_altered_env_2_6->{$p}->{$t}->[0];
                                my @row = ("effm6_sim2_".$trait_name_encoder_6{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_eff "$line\n";
                                push @sim_effect2_vals_6, $val;
                            }
                        }
                    close($F_eff);
                    push @plot_corr_full_vals, \@sim_effect2_vals_6;

                    my $sim_effect2_stat_6 = Statistics::Descriptive::Full->new();
                    $sim_effect2_stat_6->add_data(@sim_effect2_vals_6);
                    my $sig_sim_effect2_6 = $sim_effect2_stat_6->variance();

                    # SIM ENV 3: ALTERED PHENO + EFFECT

                    my ($phenotypes_env_heatmap_tempfile3_fh, $phenotypes_env_heatmap_tempfile3) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $phenotypes_env_heatmap_tempfile3) || die "Can't open file ".$phenotypes_env_heatmap_tempfile3;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_6) {
                                my @row = ("sim_env3_".$trait_name_encoder_6{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $sim_data_hash_3_6->{$p}->{$t});
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                            }
                        }
                    close($F_pheno);

                    my @sim_pheno3_vals_6;
                    my ($phenotypes_pheno_sim_heatmap_tempfile3_fh_6, $phenotypes_pheno_sim_heatmap_tempfile3_6) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $phenotypes_pheno_sim_heatmap_tempfile3_6) || die "Can't open file ".$phenotypes_pheno_sim_heatmap_tempfile3_6;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_6) {
                                my $val = $phenotype_data_altered_env_hash_3_6->{$p}->{$t};
                                my @row = ("simm6_pheno3_".$trait_name_encoder_6{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                                push @sim_pheno3_vals_6, $val;
                            }
                        }
                    close($F_pheno);
                    push @plot_corr_full_vals, \@sim_pheno3_vals_6;

                    my $sim_pheno3_stat_6 = Statistics::Descriptive::Full->new();
                    $sim_pheno3_stat_6->add_data(@sim_pheno3_vals_6);
                    my $sig_sim_pheno3_6 = $sim_pheno3_stat_6->variance();

                    my @sim_effect3_vals_6;
                    my ($effects_sim_heatmap_tempfile3_fh_6, $effects_sim_heatmap_tempfile3_6) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_eff, ">", $effects_sim_heatmap_tempfile3_6) || die "Can't open file ".$effects_sim_heatmap_tempfile3_6;
                        print $F_eff "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_6) {
                                my $val = $result_blup_spatial_data_altered_env_3_6->{$p}->{$t}->[0];
                                my @row = ("effm6_sim3_".$trait_name_encoder_6{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_eff "$line\n";
                                push @sim_effect3_vals_6, $val;
                            }
                        }
                    close($F_eff);
                    push @plot_corr_full_vals, \@sim_effect3_vals_6;

                    my $sim_effect3_stat_6 = Statistics::Descriptive::Full->new();
                    $sim_effect3_stat_6->add_data(@sim_effect3_vals_6);
                    my $sig_sim_effect3_6 = $sim_effect3_stat_6->variance();

                    # SIM ENV 4: ALTERED PHENO + EFFECT

                    my ($phenotypes_env_heatmap_tempfile4_fh, $phenotypes_env_heatmap_tempfile4) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $phenotypes_env_heatmap_tempfile4) || die "Can't open file ".$phenotypes_env_heatmap_tempfile4;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_6) {
                                my @row = ("sim_env4_".$trait_name_encoder_6{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $sim_data_hash_4_6->{$p}->{$t});
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                            }
                        }
                    close($F_pheno);

                    my @sim_pheno4_vals_6;
                    my ($phenotypes_pheno_sim_heatmap_tempfile4_fh_6, $phenotypes_pheno_sim_heatmap_tempfile4_6) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $phenotypes_pheno_sim_heatmap_tempfile4_6) || die "Can't open file ".$phenotypes_pheno_sim_heatmap_tempfile4_6;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_6) {
                                my $val = $phenotype_data_altered_env_hash_4_6->{$p}->{$t};
                                my @row = ("simm6_pheno4_".$trait_name_encoder_6{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                                push @sim_pheno4_vals_6, $val;
                            }
                        }
                    close($F_pheno);
                    push @plot_corr_full_vals, \@sim_pheno4_vals_6;

                    my $sim_pheno4_stat_6 = Statistics::Descriptive::Full->new();
                    $sim_pheno4_stat_6->add_data(@sim_pheno4_vals_6);
                    my $sig_sim_pheno4_6 = $sim_pheno4_stat_6->variance();

                    my @sim_effect4_vals_6;
                    my ($effects_sim_heatmap_tempfile4_fh_6, $effects_sim_heatmap_tempfile4_6) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_eff, ">", $effects_sim_heatmap_tempfile4_6) || die "Can't open file ".$effects_sim_heatmap_tempfile4_6;
                        print $F_eff "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_6) {
                                my $val = $result_blup_spatial_data_altered_env_4_6->{$p}->{$t}->[0];
                                my @row = ("effm6_sim4_".$trait_name_encoder_6{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_eff "$line\n";
                                push @sim_effect4_vals_6, $val;
                            }
                        }
                    close($F_eff);
                    push @plot_corr_full_vals, \@sim_effect4_vals_6;

                    my $sim_effect4_stat_6 = Statistics::Descriptive::Full->new();
                    $sim_effect4_stat_6->add_data(@sim_effect4_vals_6);
                    my $sig_sim_effect4_6 = $sim_effect4_stat_6->variance();

                    # SIM ENV 5: ALTERED PHENO + EFFECT

                    my ($phenotypes_env_heatmap_tempfile5_fh, $phenotypes_env_heatmap_tempfile5) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $phenotypes_env_heatmap_tempfile5) || die "Can't open file ".$phenotypes_env_heatmap_tempfile5;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_6) {
                                my @row = ("sim_env5_".$trait_name_encoder_6{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $sim_data_hash_5_6->{$p}->{$t});
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                            }
                        }
                    close($F_pheno);

                    my @sim_pheno5_vals_6;
                    my ($phenotypes_pheno_sim_heatmap_tempfile5_fh_6, $phenotypes_pheno_sim_heatmap_tempfile5_6) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $phenotypes_pheno_sim_heatmap_tempfile5_6) || die "Can't open file ".$phenotypes_pheno_sim_heatmap_tempfile5_6;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_6) {
                                my $val = $phenotype_data_altered_env_hash_5_6->{$p}->{$t};
                                my @row = ("simm6_pheno5_".$trait_name_encoder_6{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                                push @sim_pheno5_vals_6, $val;
                            }
                        }
                    close($F_pheno);
                    push @plot_corr_full_vals, \@sim_pheno5_vals_6;

                    my $sim_pheno5_stat_6 = Statistics::Descriptive::Full->new();
                    $sim_pheno5_stat_6->add_data(@sim_pheno5_vals_6);
                    my $sig_sim_pheno5_6 = $sim_pheno5_stat_6->variance();

                    my @sim_effect5_vals_6;
                    my ($effects_sim_heatmap_tempfile5_fh_6, $effects_sim_heatmap_tempfile5_6) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_eff, ">", $effects_sim_heatmap_tempfile5_6) || die "Can't open file ".$effects_sim_heatmap_tempfile5_6;
                        print $F_eff "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_6) {
                                my $val = $result_blup_spatial_data_altered_env_5_6->{$p}->{$t}->[0];
                                my @row = ("effm6_sim5_".$trait_name_encoder_6{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_eff "$line\n";
                                push @sim_effect5_vals_6, $val;
                            }
                        }
                    close($F_eff);
                    push @plot_corr_full_vals, \@sim_effect5_vals_6;

                    my $sim_effect5_stat_6 = Statistics::Descriptive::Full->new();
                    $sim_effect5_stat_6->add_data(@sim_effect5_vals_6);
                    my $sig_sim_effect5_6 = $sim_effect5_stat_6->variance();

                    # SIM ENV 6: ALTERED PHENO + EFFECT

                    my ($phenotypes_env_heatmap_tempfile6_fh, $phenotypes_env_heatmap_tempfile6) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $phenotypes_env_heatmap_tempfile6) || die "Can't open file ".$phenotypes_env_heatmap_tempfile6;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_6) {
                                my @row = ("sim_env6_".$trait_name_encoder_6{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $sim_data_hash_6_6->{$p}->{$t});
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                            }
                        }
                    close($F_pheno);

                    my @sim_pheno6_vals_6;
                    my ($phenotypes_pheno_sim_heatmap_tempfile6_fh_6, $phenotypes_pheno_sim_heatmap_tempfile6_6) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $phenotypes_pheno_sim_heatmap_tempfile6_6) || die "Can't open file ".$phenotypes_pheno_sim_heatmap_tempfile6_6;
                        print $F_pheno "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_6) {
                                my $val = $phenotype_data_altered_env_hash_6_6->{$p}->{$t};
                                my @row = ("simm6_pheno6_".$trait_name_encoder_6{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                                push @sim_pheno6_vals_6, $val;
                            }
                        }
                    close($F_pheno);
                    push @plot_corr_full_vals, \@sim_pheno6_vals_6;

                    my $sim_pheno6_stat_6 = Statistics::Descriptive::Full->new();
                    $sim_pheno6_stat_6->add_data(@sim_pheno6_vals_6);
                    my $sig_sim_pheno6_6 = $sim_pheno6_stat_6->variance();

                    my @sim_effect6_vals_6;
                    my ($effects_sim_heatmap_tempfile6_fh_6, $effects_sim_heatmap_tempfile6_6) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_eff, ">", $effects_sim_heatmap_tempfile6_6) || die "Can't open file ".$effects_sim_heatmap_tempfile6_6;
                        print $F_eff "trait_type,row,col,value\n";
                        foreach my $p (@unique_plot_names) {
                            foreach my $t (@sorted_trait_names_6) {
                                my $val = $result_blup_spatial_data_altered_env_6_6->{$p}->{$t}->[0];
                                my @row = ("effm6_sim6_".$trait_name_encoder_6{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $val);
                                my $line = join ',', @row;
                                print $F_eff "$line\n";
                                push @sim_effect6_vals_6, $val;
                            }
                        }
                    close($F_eff);
                    push @plot_corr_full_vals, \@sim_effect6_vals_6;

                    my $sim_effect6_stat_6 = Statistics::Descriptive::Full->new();
                    $sim_effect6_stat_6->add_data(@sim_effect6_vals_6);
                    my $sig_sim_effect6_6 = $sim_effect6_stat_6->variance();

                    my $plot_corr_summary_figure_inputfile_tempfile = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'tmp_drone_statistics/fileXXXX');
                    open($F_eff, ">", $plot_corr_summary_figure_inputfile_tempfile) || die "Can't open file ".$plot_corr_summary_figure_inputfile_tempfile;
                        foreach (@plot_corr_full_vals) {
                            my $line = join ',', @$_;
                            print $F_eff $line."\n";
                        }
                    close($F_eff);

                    my $plot_corr_summary_figure_tempfile_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $plot_corr_summary_figure_tempfile_string .= '.png';
                    my $plot_corr_summary_figure_tempfile = $c->config->{basepath}."/".$plot_corr_summary_figure_tempfile_string;

                    my $cmd_plotcorrsum_plot = 'R -e "library(data.table); library(ggplot2); library(GGally);
                    mat_full_t <- fread(\''.$plot_corr_summary_figure_inputfile_tempfile.'\', header=FALSE, sep=\',\');
                    mat_full <- data.frame(t(mat_full_t));
                    colnames(mat_full) <- c(\'mat_orig\', \'mat_altered_6\', \'mat_eff_6\', \'mat_eff_altered_6\',
                    \'mat_p_sim1_6\', \'mat_eff_sim1_6\',
                    \'mat_p_sim2_6\', \'mat_eff_sim2_6\',
                    \'mat_p_sim3_6\', \'mat_eff_sim3_6\',
                    \'mat_p_sim4_6\', \'mat_eff_sim4_6\',
                    \'mat_p_sim5_6\', \'mat_eff_sim5_6\',
                    \'mat_p_sim6_6\', \'mat_eff_sim6_6\');
                    mat_env <- fread(\''.$phenotypes_env_heatmap_tempfile.'\', header=TRUE, sep=\',\');
                    mat_env2 <- fread(\''.$phenotypes_env_heatmap_tempfile2.'\', header=TRUE, sep=\',\');
                    mat_env3 <- fread(\''.$phenotypes_env_heatmap_tempfile3.'\', header=TRUE, sep=\',\');
                    mat_env4 <- fread(\''.$phenotypes_env_heatmap_tempfile4.'\', header=TRUE, sep=\',\');
                    mat_env5 <- fread(\''.$phenotypes_env_heatmap_tempfile5.'\', header=TRUE, sep=\',\');
                    mat_env6 <- fread(\''.$phenotypes_env_heatmap_tempfile6.'\', header=TRUE, sep=\',\');
                    mat <- data.frame(pheno_orig = mat_full\$mat_orig, pheno_altm6 = mat_full\$mat_altered_6, eff_origm6 = mat_full\$mat_eff_6, eff_altm6 = mat_full\$mat_eff_altered_6, env_lin = mat_env\$value, pheno_linm6 = mat_full\$mat_p_sim1_6, lin_effm6 = mat_full\$mat_eff_sim1_6, env_n1d = mat_env2\$value, pheno_n1dm6 = mat_full\$mat_p_sim2_6, n1d_effm6 = mat_full\$mat_eff_sim2_6, env_n2d = mat_env3\$value, pheno_n2dm6 = mat_full\$mat_p_sim3_6, env_rand = mat_env4\$value, pheno_randm6 = mat_full\$mat_p_sim4_6, rand_effm6 = mat_full\$mat_eff_sim4_6, env_ar1 = mat_env5\$value, pheno_ar1m6 = mat_full\$mat_p_sim5_6, ar1_effm6 = mat_full\$mat_eff_sim5_6, env_realdata = mat_env6\$value, pheno_realdatam6 = mat_full\$mat_p_sim6_6, realdata_effm6 = mat_full\$mat_eff_sim6_6);
                    gg <- ggcorr(data=mat, hjust = 1, size = 2, color = \'grey50\', layout.exp = 1, label = TRUE, label_round = 2);
                    ggsave(\''.$plot_corr_summary_figure_tempfile.'\', gg, device=\'png\', width=30, height=30, units=\'in\');
                    "';
                    # print STDERR Dumper $cmd_plotcorrsum_plot;

                    my $status_plotcorrsum_plot = system($cmd_plotcorrsum_plot);
                    push @$spatial_effects_plots, [$plot_corr_summary_figure_tempfile_string, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_envsimscorr_"."envvar_".$env_variance_percent."_".$iterations];

                    my $env_effects_first_figure_tempfile_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $env_effects_first_figure_tempfile_string .= '.png';
                    my $env_effects_first_figure_tempfile = $c->config->{basepath}."/".$env_effects_first_figure_tempfile_string;

                    my $env_effects_first_figure_tempfile_string_2 = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $env_effects_first_figure_tempfile_string_2 .= '.png';
                    my $env_effects_first_figure_tempfile_2 = $c->config->{basepath}."/".$env_effects_first_figure_tempfile_string_2;

                    my $output_plot_row = 'row';
                    my $output_plot_col = 'col';
                    if ($max_col > $max_row) {
                        $output_plot_row = 'col';
                        $output_plot_col = 'row';
                    }

                    my $cmd_spatialfirst_plot_2 = 'R -e "library(data.table); library(ggplot2); library(dplyr); library(viridis); library(GGally); library(gridExtra);
                    mat_orig <- fread(\''.$phenotypes_original_heatmap_tempfile.'\', header=TRUE, sep=\',\');
                    mat_altered_6 <- fread(\''.$phenotypes_post_heatmap_tempfile_6.'\', header=TRUE, sep=\',\');
                    pheno_mat <- rbind(mat_orig, mat_altered_6);
                    options(device=\'png\');
                    par();
                    gg <- ggplot(pheno_mat, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_6).');
                    ggsave(\''.$env_effects_first_figure_tempfile_2.'\', gg, device=\'png\', width=20, height=20, units=\'in\');
                    "';
                    # print STDERR Dumper $cmd;
                    my $status_spatialfirst_plot_2 = system($cmd_spatialfirst_plot_2);
                    push @$spatial_effects_plots, [$env_effects_first_figure_tempfile_string_2, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_origheatmap_"."envvar_".$env_variance_percent."_".$iterations];

                    my ($sim_effects_corr_results_fh, $sim_effects_corr_results) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);

                    my $cmd_spatialfirst_plot = 'R -e "library(data.table); library(ggplot2); library(dplyr); library(viridis); library(GGally); library(gridExtra);
                    mat_full_t <- fread(\''.$plot_corr_summary_figure_inputfile_tempfile.'\', header=FALSE, sep=\',\');
                    mat_full <- data.frame(t(mat_full_t));
                    colnames(mat_full) <- c(\'mat_orig\', \'mat_altered_6\', \'mat_eff_6\', \'mat_eff_altered_6\',
                    \'mat_p_sim1_6\', \'mat_eff_sim1_6\',
                    \'mat_p_sim2_6\', \'mat_eff_sim2_6\',
                    \'mat_p_sim3_6\', \'mat_eff_sim3_6\',
                    \'mat_p_sim4_6\', \'mat_eff_sim4_6\',
                    \'mat_p_sim5_6\', \'mat_eff_sim5_6\',
                    \'mat_p_sim6_6\', \'mat_eff_sim6_6\');
                    mat_eff_6 <- fread(\''.$effects_heatmap_tempfile_6.'\', header=TRUE, sep=\',\');
                    mat_eff_altered_6 <- fread(\''.$effects_post_heatmap_tempfile_6.'\', header=TRUE, sep=\',\');
                    effect_mat_6 <- rbind(mat_eff_6, mat_eff_altered_6);
                    mat_env <- fread(\''.$phenotypes_env_heatmap_tempfile.'\', header=TRUE, sep=\',\');
                    mat_env2 <- fread(\''.$phenotypes_env_heatmap_tempfile2.'\', header=TRUE, sep=\',\');
                    mat_env3 <- fread(\''.$phenotypes_env_heatmap_tempfile3.'\', header=TRUE, sep=\',\');
                    mat_env4 <- fread(\''.$phenotypes_env_heatmap_tempfile4.'\', header=TRUE, sep=\',\');
                    mat_env5 <- fread(\''.$phenotypes_env_heatmap_tempfile5.'\', header=TRUE, sep=\',\');
                    mat_env6 <- fread(\''.$phenotypes_env_heatmap_tempfile6.'\', header=TRUE, sep=\',\');
                    options(device=\'png\');
                    par();
                    gg_eff_6 <- ggplot(effect_mat_6, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_6).');
                    ggsave(\''.$env_effects_first_figure_tempfile.'\', arrangeGrob(gg_eff_6, nrow=1), device=\'png\', width=25, height=25, units=\'in\');
                    write.table(data.frame(asreml_grm_univariate_spatial_genetic_blups_env_linear = c(cor(mat_env\$value, mat_full\$mat_eff_sim1_6)), asreml_grm_univariate_spatial_genetic_blups_env_1DN = c(cor(mat_env2\$value, mat_full\$mat_eff_sim2_6)), asreml_grm_univariate_spatial_genetic_blups_env_2DN = c(cor(mat_env3\$value, mat_full\$mat_eff_sim3_6)), asreml_grm_univariate_spatial_genetic_blups_env_random = c(cor(mat_env4\$value, mat_full\$mat_eff_sim4_6)), asreml_grm_univariate_spatial_genetic_blups_env_ar1xar1 = c(cor(mat_env5\$value, mat_full\$mat_eff_sim5_6)), asreml_grm_univariate_spatial_genetic_blups_env_realdata = c(cor(mat_env6\$value, mat_full\$mat_eff_sim6_6)) ), file=\''.$sim_effects_corr_results.'\', row.names=FALSE, col.names=TRUE, sep=\'\t\');
                    "';
                    # print STDERR Dumper $cmd;
                    my $status_spatialfirst_plot = system($cmd_spatialfirst_plot);
                    push @$spatial_effects_plots, [$env_effects_first_figure_tempfile_string, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_originaleffheatmap_"."envvar_".$env_variance_percent."_".$iterations];

                    open(my $fh_corr_result, '<', $sim_effects_corr_results) or die "Could not open file '$sim_effects_corr_results' $!";
                        print STDERR "Opened $sim_effects_corr_results\n";

                        my $header = <$fh_corr_result>;
                        my @header;
                        if ($csv->parse($header)) {
                            @header = $csv->fields();
                        }

                        while (my $row = <$fh_corr_result>) {
                            my @columns;
                            my $counter = 0;
                            if ($csv->parse($row)) {
                                @columns = $csv->fields();
                            }
                            foreach (@columns) {
                                push @{$env_corr_res->{$header[$counter]."_corrtime_".$sim_env_change_over_time.$correlation_between_times."_envvar_".$env_variance_percent}->{values}}, $_;
                                $counter++;
                            }
                        }
                    close($fh_corr_result);

                    my $env_effects_sim_figure_tempfile_string_6_env1 = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $env_effects_sim_figure_tempfile_string_6_env1 .= '.png';
                    my $env_effects_sim_figure_tempfile_6_env1 = $c->config->{basepath}."/".$env_effects_sim_figure_tempfile_string_6_env1;

                    my $cmd_spatialenvsim_plot_6_env1 = 'R -e "library(data.table); library(ggplot2); library(dplyr); library(viridis); library(GGally); library(gridExtra);
                    mat_env <- fread(\''.$phenotypes_env_heatmap_tempfile.'\', header=TRUE, sep=\',\');
                    mat_p_sim <- fread(\''.$phenotypes_pheno_sim_heatmap_tempfile_6.'\', header=TRUE, sep=\',\');
                    mat_eff_sim <- fread(\''.$effects_sim_heatmap_tempfile_6.'\', header=TRUE, sep=\',\');
                    options(device=\'png\');
                    par();
                    gg_env <- ggplot(mat_env, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_6).');
                    gg_p_sim <- ggplot(mat_p_sim, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_6).');
                    gg_eff_sim <- ggplot(mat_eff_sim, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_6).');
                    ggsave(\''.$env_effects_sim_figure_tempfile_6_env1.'\', arrangeGrob(gg_env, gg_p_sim, gg_eff_sim, nrow=1), device=\'png\', width=25, height=25, units=\'in\');
                    "';
                    # print STDERR Dumper $cmd_spatialenvsim_plot_6_env1;
                    my $status_spatialenvsim_plot_6_env1 = system($cmd_spatialenvsim_plot_6_env1);
                    push @$spatial_effects_plots, [$env_effects_sim_figure_tempfile_string_6_env1, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_env1effheatmap_"."envvar_".$env_variance_percent."_".$iterations];

                    my $env_effects_sim_figure_tempfile_string_6_env2 = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $env_effects_sim_figure_tempfile_string_6_env2 .= '.png';
                    my $env_effects_sim_figure_tempfile_6_env2 = $c->config->{basepath}."/".$env_effects_sim_figure_tempfile_string_6_env2;

                    my $cmd_spatialenvsim_plot_6_env2 = 'R -e "library(data.table); library(ggplot2); library(dplyr); library(viridis); library(GGally); library(gridExtra);
                    mat_env2 <- fread(\''.$phenotypes_env_heatmap_tempfile2.'\', header=TRUE, sep=\',\');
                    mat_p_sim2 <- fread(\''.$phenotypes_pheno_sim_heatmap_tempfile2_6.'\', header=TRUE, sep=\',\');
                    mat_eff_sim2 <- fread(\''.$effects_sim_heatmap_tempfile2_6.'\', header=TRUE, sep=\',\');
                    options(device=\'png\');
                    par();
                    gg_env2 <- ggplot(mat_env2, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_6).');
                    gg_p_sim2 <- ggplot(mat_p_sim2, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_6).');
                    gg_eff_sim2 <- ggplot(mat_eff_sim2, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_6).');
                    ggsave(\''.$env_effects_sim_figure_tempfile_6_env2.'\', arrangeGrob(gg_env2, gg_p_sim2, gg_eff_sim2, nrow=1), device=\'png\', width=25, height=25, units=\'in\');
                    "';
                    # print STDERR Dumper $cmd_spatialenvsim_plot_6_env2;
                    my $status_spatialenvsim_plot_6_env2 = system($cmd_spatialenvsim_plot_6_env2);
                    push @$spatial_effects_plots, [$env_effects_sim_figure_tempfile_string_6_env2, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_env2effheatmap_"."envvar_".$env_variance_percent."_".$iterations];

                    my $env_effects_sim_figure_tempfile_string_6_env3 = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $env_effects_sim_figure_tempfile_string_6_env3 .= '.png';
                    my $env_effects_sim_figure_tempfile_6_env3 = $c->config->{basepath}."/".$env_effects_sim_figure_tempfile_string_6_env3;

                    my $cmd_spatialenvsim_plot_6_env3 = 'R -e "library(data.table); library(ggplot2); library(dplyr); library(viridis); library(GGally); library(gridExtra);
                    mat_env3 <- fread(\''.$phenotypes_env_heatmap_tempfile3.'\', header=TRUE, sep=\',\');
                    mat_p_sim3 <- fread(\''.$phenotypes_pheno_sim_heatmap_tempfile3_6.'\', header=TRUE, sep=\',\');
                    mat_eff_sim3 <- fread(\''.$effects_sim_heatmap_tempfile3_6.'\', header=TRUE, sep=\',\');
                    options(device=\'png\');
                    par();
                    gg_env3 <- ggplot(mat_env3, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_6).');
                    gg_p_sim3 <- ggplot(mat_p_sim3, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_6).');
                    gg_eff_sim3 <- ggplot(mat_eff_sim3, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_6).');
                    ggsave(\''.$env_effects_sim_figure_tempfile_6_env3.'\', arrangeGrob(gg_env3, gg_p_sim3, gg_eff_sim3, nrow=1), device=\'png\', width=25, height=25, units=\'in\');
                    "';
                    # print STDERR Dumper $cmd_spatialenvsim_plot_6_env3;
                    my $status_spatialenvsim_plot_6_env3 = system($cmd_spatialenvsim_plot_6_env3);
                    push @$spatial_effects_plots, [$env_effects_sim_figure_tempfile_string_6_env3, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_env3effheatmap_"."envvar_".$env_variance_percent."_".$iterations];

                    my $env_effects_sim_figure_tempfile_string_6_env4 = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $env_effects_sim_figure_tempfile_string_6_env4 .= '.png';
                    my $env_effects_sim_figure_tempfile_6_env4 = $c->config->{basepath}."/".$env_effects_sim_figure_tempfile_string_6_env4;

                    my $cmd_spatialenvsim_plot_6_env4 = 'R -e "library(data.table); library(ggplot2); library(dplyr); library(viridis); library(GGally); library(gridExtra);
                    mat_env4 <- fread(\''.$phenotypes_env_heatmap_tempfile4.'\', header=TRUE, sep=\',\');
                    mat_p_sim4 <- fread(\''.$phenotypes_pheno_sim_heatmap_tempfile4_6.'\', header=TRUE, sep=\',\');
                    mat_eff_sim4 <- fread(\''.$effects_sim_heatmap_tempfile4_6.'\', header=TRUE, sep=\',\');
                    options(device=\'png\');
                    par();
                    gg_env4 <- ggplot(mat_env4, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_6).');
                    gg_p_sim4 <- ggplot(mat_p_sim4, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_6).');
                    gg_eff_sim4 <- ggplot(mat_eff_sim4, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_6).');
                    ggsave(\''.$env_effects_sim_figure_tempfile_6_env4.'\', arrangeGrob(gg_env4, gg_p_sim4, gg_eff_sim4, nrow=1), device=\'png\', width=25, height=25, units=\'in\');
                    "';
                    # print STDERR Dumper $cmd_spatialenvsim_plot_6_env4;
                    my $status_spatialenvsim_plot_6_env4 = system($cmd_spatialenvsim_plot_6_env4);
                    push @$spatial_effects_plots, [$env_effects_sim_figure_tempfile_string_6_env4, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_env4effheatmap_"."envvar_".$env_variance_percent."_".$iterations];

                    my $env_effects_sim_figure_tempfile_string_6_env5 = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $env_effects_sim_figure_tempfile_string_6_env5 .= '.png';
                    my $env_effects_sim_figure_tempfile_6_env5 = $c->config->{basepath}."/".$env_effects_sim_figure_tempfile_string_6_env5;

                    my $cmd_spatialenvsim_plot_6_env5 = 'R -e "library(data.table); library(ggplot2); library(dplyr); library(viridis); library(GGally); library(gridExtra);
                    mat_env5 <- fread(\''.$phenotypes_env_heatmap_tempfile5.'\', header=TRUE, sep=\',\');
                    mat_p_sim5 <- fread(\''.$phenotypes_pheno_sim_heatmap_tempfile5_6.'\', header=TRUE, sep=\',\');
                    mat_eff_sim5 <- fread(\''.$effects_sim_heatmap_tempfile5_6.'\', header=TRUE, sep=\',\');
                    options(device=\'png\');
                    par();
                    gg_env5 <- ggplot(mat_env5, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_6).');
                    gg_p_sim5 <- ggplot(mat_p_sim5, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_6).');
                    gg_eff_sim5 <- ggplot(mat_eff_sim5, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_6).');
                    ggsave(\''.$env_effects_sim_figure_tempfile_6_env5.'\', arrangeGrob(gg_env5, gg_p_sim5, gg_eff_sim5, nrow=1), device=\'png\', width=25, height=25, units=\'in\');
                    "';
                    # print STDERR Dumper $cmd_spatialenvsim_plot_6_env5;
                    my $status_spatialenvsim_plot_6_env5 = system($cmd_spatialenvsim_plot_6_env5);
                    push @$spatial_effects_plots, [$env_effects_sim_figure_tempfile_string_6_env5, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_env5effheatmap_"."envvar_".$env_variance_percent."_".$iterations];

                    my $env_effects_sim_figure_tempfile_string_6_env6 = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $env_effects_sim_figure_tempfile_string_6_env6 .= '.png';
                    my $env_effects_sim_figure_tempfile_6_env6 = $c->config->{basepath}."/".$env_effects_sim_figure_tempfile_string_6_env6;

                    my $cmd_spatialenvsim_plot_6_env6 = 'R -e "library(data.table); library(ggplot2); library(dplyr); library(viridis); library(GGally); library(gridExtra);
                    mat_env6 <- fread(\''.$phenotypes_env_heatmap_tempfile6.'\', header=TRUE, sep=\',\');
                    mat_p_sim6 <- fread(\''.$phenotypes_pheno_sim_heatmap_tempfile6_6.'\', header=TRUE, sep=\',\');
                    mat_eff_sim6 <- fread(\''.$effects_sim_heatmap_tempfile6_6.'\', header=TRUE, sep=\',\');
                    options(device=\'png\');
                    par();
                    gg_env6 <- ggplot(mat_env6, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_6).');
                    gg_p_sim6 <- ggplot(mat_p_sim6, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_6).');
                    gg_eff_sim6 <- ggplot(mat_eff_sim6, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                        geom_tile() +
                        scale_fill_viridis(discrete=FALSE) +
                        coord_equal() +
                        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names_6).');
                    ggsave(\''.$env_effects_sim_figure_tempfile_6_env6.'\', arrangeGrob(gg_env6, gg_p_sim6, gg_eff_sim6, nrow=1), device=\'png\', width=25, height=25, units=\'in\');
                    "';
                    # print STDERR Dumper $cmd_spatialenvsim_plot_6_env6;
                    my $status_spatialenvsim_plot_6_env6 = system($cmd_spatialenvsim_plot_6_env6);
                    push @$spatial_effects_plots, [$env_effects_sim_figure_tempfile_string_6_env6, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_env6effheatmap_"."envvar_".$env_variance_percent."_".$iterations];
                };

                eval {
                    my @sorted_germplasm_names = sort keys %unique_accessions;

                    my @original_blup_vals_6;
                    my ($effects_original_line_chart_tempfile_fh_6, $effects_original_line_chart_tempfile_6) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open(my $F_pheno, ">", $effects_original_line_chart_tempfile_6) || die "Can't open file ".$effects_original_line_chart_tempfile_6;
                        print $F_pheno "germplasmName,time,value\n";
                        foreach my $p (@sorted_germplasm_names) {
                            foreach my $t (@sorted_trait_names_6) {
                                my $val = $result_blup_data_original_6->{$p}->{$t}->[0];
                                my @row = ($p, $t, $val);
                                push @original_blup_vals_6, $val;
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                            }
                        }
                    close($F_pheno);

                    my $original_blup_stat_6 = Statistics::Descriptive::Full->new();
                    $original_blup_stat_6->add_data(@original_blup_vals_6);
                    my $sig_original_blup_6 = $original_blup_stat_6->variance();

                    my @altered_blups_vals_6;
                    my ($effects_altered_line_chart_tempfile_fh_6, $effects_altered_line_chart_tempfile_6) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $effects_altered_line_chart_tempfile_6) || die "Can't open file ".$effects_altered_line_chart_tempfile_6;
                        print $F_pheno "germplasmName,time,value\n";
                        foreach my $p (@sorted_germplasm_names) {
                            foreach my $t (@sorted_trait_names_6) {
                                my $val = $result_blup_data_altered_6->{$p}->{$t}->[0];
                                my @row = ($p, $t, $val);
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                                push @altered_blups_vals_6, $val;
                            }
                        }
                    close($F_pheno);

                    my $altered_blup_stat_6 = Statistics::Descriptive::Full->new();
                    $altered_blup_stat_6->add_data(@altered_blups_vals_6);
                    my $sig_altered_blup_6 = $altered_blup_stat_6->variance();

                    my @sim1_blup_vals_6;
                    my ($effects_altered_env1_line_chart_tempfile_fh_6, $effects_altered_env1_line_chart_tempfile_6) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $effects_altered_env1_line_chart_tempfile_6) || die "Can't open file ".$effects_altered_env1_line_chart_tempfile_6;
                        print $F_pheno "germplasmName,time,value\n";
                        foreach my $p (@sorted_germplasm_names) {
                            foreach my $t (@sorted_trait_names_6) {
                                my $val = $result_blup_data_altered_env_1_6->{$p}->{$t}->[0];
                                my @row = ($p, $t, $val);
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                                push @sim1_blup_vals_6, $val;
                            }
                        }
                    close($F_pheno);

                    my $sim1_blup_stat_6 = Statistics::Descriptive::Full->new();
                    $sim1_blup_stat_6->add_data(@sim1_blup_vals_6);
                    my $sig_sim1_blup_6 = $sim1_blup_stat_6->variance();

                    my @sim2_blup_vals_6;
                    my ($effects_altered_env2_line_chart_tempfile_fh_6, $effects_altered_env2_line_chart_tempfile_6) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $effects_altered_env2_line_chart_tempfile_6) || die "Can't open file ".$effects_altered_env2_line_chart_tempfile_6;
                        print $F_pheno "germplasmName,time,value\n";
                        foreach my $p (@sorted_germplasm_names) {
                            foreach my $t (@sorted_trait_names_6) {
                                my $val = $result_blup_data_altered_env_2_6->{$p}->{$t}->[0];
                                my @row = ($p, $t, $val);
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                                push @sim2_blup_vals_6, $val;
                            }
                        }
                    close($F_pheno);

                    my $sim2_blup_stat_6 = Statistics::Descriptive::Full->new();
                    $sim2_blup_stat_6->add_data(@sim2_blup_vals_6);
                    my $sig_sim2_blup_6 = $sim2_blup_stat_6->variance();

                    my @sim3_blup_vals_6;
                    my ($effects_altered_env3_line_chart_tempfile_fh_6, $effects_altered_env3_line_chart_tempfile_6) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $effects_altered_env3_line_chart_tempfile_6) || die "Can't open file ".$effects_altered_env3_line_chart_tempfile_6;
                        print $F_pheno "germplasmName,time,value\n";
                        foreach my $p (@sorted_germplasm_names) {
                            foreach my $t (@sorted_trait_names_6) {
                                my $val = $result_blup_data_altered_env_3_6->{$p}->{$t}->[0];
                                my @row = ($p, $t, $val);
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                                push @sim3_blup_vals_6, $val;
                            }
                        }
                    close($F_pheno);

                    my $sim3_blup_stat_6 = Statistics::Descriptive::Full->new();
                    $sim3_blup_stat_6->add_data(@sim3_blup_vals_6);
                    my $sig_sim3_blup_6 = $sim3_blup_stat_6->variance();

                    my @sim4_blup_vals_6;
                    my ($effects_altered_env4_line_chart_tempfile_fh_6, $effects_altered_env4_line_chart_tempfile_6) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $effects_altered_env4_line_chart_tempfile_6) || die "Can't open file ".$effects_altered_env4_line_chart_tempfile_6;
                        print $F_pheno "germplasmName,time,value\n";
                        foreach my $p (@sorted_germplasm_names) {
                            foreach my $t (@sorted_trait_names_6) {
                                my $val = $result_blup_data_altered_env_4_6->{$p}->{$t}->[0];
                                my @row = ($p, $t, $val);
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                                push @sim4_blup_vals_6, $val;
                            }
                        }
                    close($F_pheno);

                    my $sim4_blup_stat_6 = Statistics::Descriptive::Full->new();
                    $sim4_blup_stat_6->add_data(@sim4_blup_vals_6);
                    my $sig_sim4_blup_6 = $sim4_blup_stat_6->variance();

                    my @sim5_blup_vals_6;
                    my ($effects_altered_env5_line_chart_tempfile_fh_6, $effects_altered_env5_line_chart_tempfile_6) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $effects_altered_env5_line_chart_tempfile_6) || die "Can't open file ".$effects_altered_env5_line_chart_tempfile_6;
                        print $F_pheno "germplasmName,time,value\n";
                        foreach my $p (@sorted_germplasm_names) {
                            foreach my $t (@sorted_trait_names_6) {
                                my $val = $result_blup_data_altered_env_5_6->{$p}->{$t}->[0];
                                my @row = ($p, $t, $val);
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                                push @sim5_blup_vals_6, $val;
                            }
                        }
                    close($F_pheno);

                    my $sim5_blup_stat_6 = Statistics::Descriptive::Full->new();
                    $sim5_blup_stat_6->add_data(@sim5_blup_vals_6);
                    my $sig_sim5_blup_6 = $sim5_blup_stat_6->variance();

                    my @sim6_blup_vals_6;
                    my ($effects_altered_env6_line_chart_tempfile_fh_6, $effects_altered_env6_line_chart_tempfile_6) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
                    open($F_pheno, ">", $effects_altered_env6_line_chart_tempfile_6) || die "Can't open file ".$effects_altered_env6_line_chart_tempfile_6;
                        print $F_pheno "germplasmName,time,value\n";
                        foreach my $p (@sorted_germplasm_names) {
                            foreach my $t (@sorted_trait_names_6) {
                                my $val = $result_blup_data_altered_env_6_6->{$p}->{$t}->[0];
                                my @row = ($p, $t, $val);
                                my $line = join ',', @row;
                                print $F_pheno "$line\n";
                                push @sim6_blup_vals_6, $val;
                            }
                        }
                    close($F_pheno);

                    my $sim6_blup_stat_6 = Statistics::Descriptive::Full->new();
                    $sim6_blup_stat_6->add_data(@sim6_blup_vals_6);
                    my $sig_sim6_blup_6 = $sim6_blup_stat_6->variance();

                    my @set = ('0' ..'9', 'A' .. 'F');
                    my @colors;
                    for (1..scalar(@sorted_germplasm_names)) {
                        my $str = join '' => map $set[rand @set], 1 .. 6;
                        push @colors, '#'.$str;
                    }
                    my $color_string = join '\',\'', @colors;

                    my $genetic_effects_figure_tempfile_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $genetic_effects_figure_tempfile_string .= '.png';
                    my $genetic_effects_figure_tempfile = $c->config->{basepath}."/".$genetic_effects_figure_tempfile_string;

                    my $genetic_effects_alt_figure_tempfile_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $genetic_effects_alt_figure_tempfile_string .= '.png';
                    my $genetic_effects_alt_figure_tempfile = $c->config->{basepath}."/".$genetic_effects_alt_figure_tempfile_string;

                    my $genetic_effects_alt_env1_figure_tempfile_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $genetic_effects_alt_env1_figure_tempfile_string .= '.png';
                    my $genetic_effects_alt_env1_figure_tempfile = $c->config->{basepath}."/".$genetic_effects_alt_env1_figure_tempfile_string;

                    my $genetic_effects_alt_env2_figure_tempfile_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $genetic_effects_alt_env2_figure_tempfile_string .= '.png';
                    my $genetic_effects_alt_env2_figure_tempfile = $c->config->{basepath}."/".$genetic_effects_alt_env2_figure_tempfile_string;

                    my $genetic_effects_alt_env3_figure_tempfile_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $genetic_effects_alt_env3_figure_tempfile_string .= '.png';
                    my $genetic_effects_alt_env3_figure_tempfile = $c->config->{basepath}."/".$genetic_effects_alt_env3_figure_tempfile_string;

                    my $genetic_effects_alt_env4_figure_tempfile_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $genetic_effects_alt_env4_figure_tempfile_string .= '.png';
                    my $genetic_effects_alt_env4_figure_tempfile = $c->config->{basepath}."/".$genetic_effects_alt_env4_figure_tempfile_string;

                    my $genetic_effects_alt_env5_figure_tempfile_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $genetic_effects_alt_env5_figure_tempfile_string .= '.png';
                    my $genetic_effects_alt_env5_figure_tempfile = $c->config->{basepath}."/".$genetic_effects_alt_env5_figure_tempfile_string;

                    my $genetic_effects_alt_env6_figure_tempfile_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
                    $genetic_effects_alt_env6_figure_tempfile_string .= '.png';
                    my $genetic_effects_alt_env6_figure_tempfile = $c->config->{basepath}."/".$genetic_effects_alt_env6_figure_tempfile_string;

                    my $cmd_gen_plot = 'R -e "library(data.table); library(ggplot2); library(GGally); library(gridExtra);
                    mat <- fread(\''.$effects_original_line_chart_tempfile_6.'\', header=TRUE, sep=\',\');
                    mat\$time <- as.numeric(as.character(mat\$time));
                    options(device=\'png\');
                    par();
                    sp <- ggplot(mat, aes(x = time, y = value)) +
                        geom_line(aes(color = germplasmName), size = 1) +
                        scale_fill_manual(values = c(\''.$color_string.'\')) +
                        theme_minimal();
                    sp <- sp + guides(shape = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + guides(color = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + theme(legend.title = element_text(size = 3), legend.text = element_text(size = 3));
                    sp <- sp + labs(title = \'Original Genetic Effects\');';
                    if (scalar(@sorted_germplasm_names) > 100) {
                        $cmd_gen_plot .= 'sp <- sp + theme(legend.position = \'none\');';
                    }
                    $cmd_gen_plot .= 'ggsave(\''.$genetic_effects_figure_tempfile.'\', sp, device=\'png\', width=12, height=6, units=\'in\');
                    "';
                    print STDERR Dumper $cmd_gen_plot;
                    my $status_gen_plot = system($cmd_gen_plot);
                    push @$spatial_effects_plots, [$genetic_effects_figure_tempfile_string, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_efforigline_"."envvar_".$env_variance_percent."_".$iterations];

                    my $cmd_gen_alt_plot = 'R -e "library(data.table); library(ggplot2); library(GGally); library(gridExtra);
                    mat <- fread(\''.$effects_altered_line_chart_tempfile_6.'\', header=TRUE, sep=\',\');
                    mat\$time <- as.numeric(as.character(mat\$time));
                    options(device=\'png\');
                    par();
                    sp <- ggplot(mat, aes(x = time, y = value)) +
                        geom_line(aes(color = germplasmName), size = 1) +
                        scale_fill_manual(values = c(\''.$color_string.'\')) +
                        theme_minimal();
                    sp <- sp + guides(shape = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + guides(color = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + theme(legend.title = element_text(size = 3), legend.text = element_text(size = 3));
                    sp <- sp + labs(title = \'Altered Genetic Effects\');';
                    if (scalar(@sorted_germplasm_names) > 100) {
                        $cmd_gen_alt_plot .= 'sp <- sp + theme(legend.position = \'none\');';
                    }
                    $cmd_gen_alt_plot .= 'ggsave(\''.$genetic_effects_alt_figure_tempfile.'\', sp, device=\'png\', width=12, height=6, units=\'in\');
                    "';
                    print STDERR Dumper $cmd_gen_alt_plot;
                    my $status_gen_alt_plot = system($cmd_gen_alt_plot);
                    push @$spatial_effects_plots, [$genetic_effects_alt_figure_tempfile_string, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_effaltline_"."envvar_".$env_variance_percent."_".$iterations];

                    my $cmd_gen_env1_plot = 'R -e "library(data.table); library(ggplot2); library(GGally); library(gridExtra);
                    mat <- fread(\''.$effects_altered_env1_line_chart_tempfile_6.'\', header=TRUE, sep=\',\');
                    mat\$time <- as.numeric(as.character(mat\$time));
                    options(device=\'png\');
                    par();
                    sp <- ggplot(mat, aes(x = time, y = value)) +
                        geom_line(aes(color = germplasmName), size = 1) +
                        scale_fill_manual(values = c(\''.$color_string.'\')) +
                        theme_minimal();
                    sp <- sp + guides(shape = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + guides(color = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + theme(legend.title = element_text(size = 3), legend.text = element_text(size = 3));
                    sp <- sp + labs(title = \'SimLinear Genetic Effects\');';
                    if (scalar(@sorted_germplasm_names) > 100) {
                        $cmd_gen_env1_plot .= 'sp <- sp + theme(legend.position = \'none\');';
                    }
                    $cmd_gen_env1_plot .= 'ggsave(\''.$genetic_effects_alt_env1_figure_tempfile.'\', sp, device=\'png\', width=12, height=6, units=\'in\');
                    "';
                    print STDERR Dumper $cmd_gen_env1_plot;
                    my $status_gen_env1_plot = system($cmd_gen_env1_plot);
                    push @$spatial_effects_plots, [$genetic_effects_alt_env1_figure_tempfile_string, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_effaltenv1line_"."envvar_".$env_variance_percent."_".$iterations];

                    my $cmd_gen_env2_plot = 'R -e "library(data.table); library(ggplot2); library(GGally); library(gridExtra);
                    mat <- fread(\''.$effects_altered_env2_line_chart_tempfile_6.'\', header=TRUE, sep=\',\');
                    mat\$time <- as.numeric(as.character(mat\$time));
                    options(device=\'png\');
                    par();
                    sp <- ggplot(mat, aes(x = time, y = value)) +
                        geom_line(aes(color = germplasmName), size = 1) +
                        scale_fill_manual(values = c(\''.$color_string.'\')) +
                        theme_minimal();
                    sp <- sp + guides(shape = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + guides(color = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + theme(legend.title = element_text(size = 3), legend.text = element_text(size = 3));
                    sp <- sp + labs(title = \'Sim1DN Genetic Effects\');';
                    if (scalar(@sorted_germplasm_names) > 100) {
                        $cmd_gen_env2_plot .= 'sp <- sp + theme(legend.position = \'none\');';
                    }
                    $cmd_gen_env2_plot .= 'ggsave(\''.$genetic_effects_alt_env2_figure_tempfile.'\', sp, device=\'png\', width=12, height=6, units=\'in\');
                    "';
                    print STDERR Dumper $cmd_gen_env2_plot;
                    my $status_gen_env2_plot = system($cmd_gen_env2_plot);
                    push @$spatial_effects_plots, [$genetic_effects_alt_env2_figure_tempfile_string, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_effaltenv2line_"."envvar_".$env_variance_percent."_".$iterations];

                    my $cmd_gen_env3_plot = 'R -e "library(data.table); library(ggplot2); library(GGally); library(gridExtra);
                    mat <- fread(\''.$effects_altered_env3_line_chart_tempfile_6.'\', header=TRUE, sep=\',\');
                    mat\$time <- as.numeric(as.character(mat\$time));
                    options(device=\'png\');
                    par();
                    sp <- ggplot(mat, aes(x = time, y = value)) +
                        geom_line(aes(color = germplasmName), size = 1) +
                        scale_fill_manual(values = c(\''.$color_string.'\')) +
                        theme_minimal();
                    sp <- sp + guides(shape = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + guides(color = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + theme(legend.title = element_text(size = 3), legend.text = element_text(size = 3));
                    sp <- sp + labs(title = \'Sim2DN Genetic Effects\');';
                    if (scalar(@sorted_germplasm_names) > 100) {
                        $cmd_gen_env3_plot .= 'sp <- sp + theme(legend.position = \'none\');';
                    }
                    $cmd_gen_env3_plot .= 'ggsave(\''.$genetic_effects_alt_env3_figure_tempfile.'\', sp, device=\'png\', width=12, height=6, units=\'in\');
                    "';
                    print STDERR Dumper $cmd_gen_env3_plot;
                    my $status_gen_env3_plot = system($cmd_gen_env3_plot);
                    push @$spatial_effects_plots, [$genetic_effects_alt_env3_figure_tempfile_string, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_effaltenv3line_"."envvar_".$env_variance_percent."_".$iterations];

                    my $cmd_gen_env4_plot = 'R -e "library(data.table); library(ggplot2); library(GGally); library(gridExtra);
                    mat <- fread(\''.$effects_altered_env4_line_chart_tempfile_6.'\', header=TRUE, sep=\',\');
                    mat\$time <- as.numeric(as.character(mat\$time));
                    options(device=\'png\');
                    par();
                    sp <- ggplot(mat, aes(x = time, y = value)) +
                        geom_line(aes(color = germplasmName), size = 1) +
                        scale_fill_manual(values = c(\''.$color_string.'\')) +
                        theme_minimal();
                    sp <- sp + guides(shape = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + guides(color = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + theme(legend.title = element_text(size = 3), legend.text = element_text(size = 3));
                    sp <- sp + labs(title = \'SimRandom Genetic Effects\');';
                    if (scalar(@sorted_germplasm_names) > 100) {
                        $cmd_gen_env4_plot .= 'sp <- sp + theme(legend.position = \'none\');';
                    }
                    $cmd_gen_env4_plot .= 'ggsave(\''.$genetic_effects_alt_env4_figure_tempfile.'\', sp, device=\'png\', width=12, height=6, units=\'in\');
                    "';
                    print STDERR Dumper $cmd_gen_env4_plot;
                    my $status_gen_env4_plot = system($cmd_gen_env4_plot);
                    push @$spatial_effects_plots, [$genetic_effects_alt_env4_figure_tempfile_string, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_effaltenv4line_"."envvar_".$env_variance_percent."_".$iterations];

                    my $cmd_gen_env5_plot = 'R -e "library(data.table); library(ggplot2); library(GGally); library(gridExtra);
                    mat <- fread(\''.$effects_altered_env5_line_chart_tempfile_6.'\', header=TRUE, sep=\',\');
                    mat\$time <- as.numeric(as.character(mat\$time));
                    options(device=\'png\');
                    par();
                    sp <- ggplot(mat, aes(x = time, y = value)) +
                        geom_line(aes(color = germplasmName), size = 1) +
                        scale_fill_manual(values = c(\''.$color_string.'\')) +
                        theme_minimal();
                    sp <- sp + guides(shape = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + guides(color = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + theme(legend.title = element_text(size = 3), legend.text = element_text(size = 3));
                    sp <- sp + labs(title = \'SimRandom Genetic Effects\');';
                    if (scalar(@sorted_germplasm_names) > 100) {
                        $cmd_gen_env5_plot .= 'sp <- sp + theme(legend.position = \'none\');';
                    }
                    $cmd_gen_env5_plot .= 'ggsave(\''.$genetic_effects_alt_env5_figure_tempfile.'\', sp, device=\'png\', width=12, height=6, units=\'in\');
                    "';
                    print STDERR Dumper $cmd_gen_env5_plot;
                    my $status_gen_env5_plot = system($cmd_gen_env5_plot);
                    push @$spatial_effects_plots, [$genetic_effects_alt_env5_figure_tempfile_string, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_effaltenv5line_"."envvar_".$env_variance_percent."_".$iterations];

                    my $cmd_gen_env6_plot = 'R -e "library(data.table); library(ggplot2); library(GGally); library(gridExtra);
                    mat <- fread(\''.$effects_altered_env6_line_chart_tempfile_6.'\', header=TRUE, sep=\',\');
                    mat\$time <- as.numeric(as.character(mat\$time));
                    options(device=\'png\');
                    par();
                    sp <- ggplot(mat, aes(x = time, y = value)) +
                        geom_line(aes(color = germplasmName), size = 1) +
                        scale_fill_manual(values = c(\''.$color_string.'\')) +
                        theme_minimal();
                    sp <- sp + guides(shape = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + guides(color = guide_legend(override.aes = list(size = 0.5)));
                    sp <- sp + theme(legend.title = element_text(size = 3), legend.text = element_text(size = 3));
                    sp <- sp + labs(title = \'SimRandom Genetic Effects\');';
                    if (scalar(@sorted_germplasm_names) > 100) {
                        $cmd_gen_env6_plot .= 'sp <- sp + theme(legend.position = \'none\');';
                    }
                    $cmd_gen_env6_plot .= 'ggsave(\''.$genetic_effects_alt_env6_figure_tempfile.'\', sp, device=\'png\', width=12, height=6, units=\'in\');
                    "';
                    print STDERR Dumper $cmd_gen_env6_plot;
                    my $status_gen_env6_plot = system($cmd_gen_env6_plot);
                    push @$spatial_effects_plots, [$genetic_effects_alt_env6_figure_tempfile_string, $statistics_select.$sim_env_change_over_time.$correlation_between_times."_effaltenv6line_"."envvar_".$env_variance_percent."_".$iterations];
                };

                %trait_name_encoder = %trait_name_encoder_6;
                %trait_to_time_map = %trait_to_time_map_6;

                push @$env_varcomps, {
                    type => "$statistics_select: Env Variance $env_variance_percent : SimCorrelation: $correlation_between_times : Iteration $iterations",
                    statistics_select => "$statistics_select: Env Variance $env_variance_percent : SimCorrelation: $correlation_between_times",
                    correlation_between_times => $correlation_between_times,
                    env_variance => $env_variance_percent,
                    original => {
                        covariance => $varcomp_original_array_6,
                        cv_1 => $result_cv_original_6,
                        cv_2 => $result_cv_2_original_6
                    },
                    altered => {
                        covariance => $varcomp_altered_array_6,
                        cv_1 => $result_cv_altered_6,
                        cv_2 => $result_cv_2_altered_6
                    },
                    env_linear => {
                        covariance => $varcomp_altered_array_env_1_6,
                        cv_1 => $result_cv_altered_env_1_6,
                        cv_2 => $result_cv_2_altered_env_1_6
                    },
                    env_1DN  => {
                        covariance => $varcomp_altered_array_env_2_6,
                        cv_1 => $result_cv_altered_env_2_6,
                        cv_2 => $result_cv_2_altered_env_2_6
                    },
                    env_2DN  => {
                        covariance => $varcomp_altered_array_env_3_6,
                        cv_1 => $result_cv_altered_env_3_6,
                        cv_2 => $result_cv_2_altered_env_3_6
                    },
                    env_random  => {
                        covariance => $varcomp_altered_array_env_4_6,
                        cv_1 => $result_cv_altered_env_4_6,
                        cv_2 => $result_cv_2_altered_env_4_6
                    },
                    env_ar1xar1  => {
                        covariance => $varcomp_altered_array_env_5_6,
                        cv_1 => $result_cv_altered_env_5_6,
                        cv_2 => $result_cv_2_altered_env_5_6
                    },
                    env_realdata  => {
                        covariance => $varcomp_altered_array_env_6_6,
                        cv_1 => $result_cv_altered_env_6_6,
                        cv_2 => $result_cv_2_altered_env_6_6
                    }
                };
            }

        }
    }

    foreach my $t (keys %$env_corr_res) {
        my $vals = $env_corr_res->{$t}->{values};
        my $env_corr_res_stat = Statistics::Descriptive::Full->new();
        $env_corr_res_stat->add_data(@$vals);
        $env_corr_res->{$t}->{std} = $env_corr_res_stat->standard_deviation();
        $env_corr_res->{$t}->{mean} = $env_corr_res_stat->mean();
    }

    # print STDERR Dumper $env_corr_res;
    # print STDERR Dumper $env_iterations;
    # print STDERR Dumper \%trait_name_encoder;
    # print STDERR Dumper \%trait_to_time_map;
    # print STDERR Dumper $env_varcomps;

    my %avg_varcomps;
    my @avg_varcomps_display;
    my @varcomp_keys = ('original', 'altered', 'env_linear', 'env_1DN', 'env_2DN', 'env_ar1xar1', 'env_random', 'env_realdata');
    if ($statistics_select ne 'blupf90_grm_random_regression_gdd_blups' && $statistics_select ne 'blupf90_grm_random_regression_dap_blups' && $statistics_select ne 'airemlf90_grm_random_regression_gdd_blups' && $statistics_select ne 'airemlf90_grm_random_regression_dap_blups') {
        foreach (@$env_varcomps) {
            my $type = $_->{statistics_select};
            foreach my $t (@varcomp_keys) {
                foreach my $a (@{$_->{$t}->{covariance}}) {
                    push @{$avg_varcomps{$type}->{$t}->{$a->[0]}->{vals}}, $a->[1];
                }
            }
        }
        # print STDERR Dumper \%avg_varcomps;

        my %avg_varcomps_save;
        while (my($t, $type_obj) = each %avg_varcomps) {
            while (my($type, $level_obj) = each %$type_obj) {
                while (my($level, $vals) = each %$level_obj) {
                    my @values = @{$vals->{vals}};
                    my $level_rec;
                    my @level_split = split '\.', $level;
                    if (scalar(@level_split) == 2) { #For Sommer Varcomp
                        my ($level_type, $level_times) = @level_split;
                        my @ar = split '-', $level_times;
                        my ($t1, $t2) = sort @ar;
                        # print STDERR Dumper [$t1, $t2];
                        $level_rec = $level_type.".".$t1."-".$t2;
                    }
                    else { #For ASREML-R Varcomp
                        $level_rec = $level;
                    }
                    my $stat = Statistics::Descriptive::Full->new();
                    $stat->add_data(@values);
                    my $std = $stat->standard_deviation();
                    my $mean = $stat->mean();
                    $avg_varcomps_save{$t}->{$type}->{$level_rec}->{std} = $std;
                    $avg_varcomps_save{$t}->{$type}->{$level_rec}->{mean} = $mean;
                    $avg_varcomps_save{$t}->{$type}->{$level_rec}->{vals} = \@values;
                    push @avg_varcomps_display, {
                        type => $t,
                        type_scenario => $type,
                        level => $level_rec,
                        vals => $vals->{vals},
                        std => $std,
                        mean => $mean
                    };
                }
            }
        }
        %avg_varcomps = %avg_varcomps_save;

        my @potential_times;
        #Sommer
        foreach (keys %trait_name_encoder) {
            push @potential_times, "t$_";
        }
        #ASREML-R
        foreach (values %trait_name_encoder) {
            push @potential_times, $_;
        }

        while (my($t, $type_obj) = each %avg_varcomps) {
            while (my($type, $level_obj) = each %$type_obj) {
                my @h_values;
                foreach my $time (@potential_times) {
                    #Sommer varcomps
                    if (exists($avg_varcomps{$t}->{$type}->{"u:id.$time-$time"}->{mean}) && exists($avg_varcomps{$t}->{$type}->{"u:units.$time-$time"}->{mean})) {
                        my $g = $avg_varcomps{$t}->{$type}->{"u:id.$time-$time"}->{mean};
                        my $r = $avg_varcomps{$t}->{$type}->{"u:units.$time-$time"}->{mean};
                        my $h = $g + $r == 0 ? 0 : $g/($g + $r);
                        push @h_values, $h;
                        push @avg_varcomps_display, {
                            type => $t,
                            type_scenario => $type,
                            level => "h2-$time",
                            vals => [$h],
                            std => 0,
                            mean => $h
                        };
                    }
                    #ASREML-R multivariate + univariate
                    elsif (exists($avg_varcomps{$t}->{$type}->{"trait:vm(id_factor, geno_mat_3col)!trait_$time:$time"}->{mean}) && (exists($avg_varcomps{$t}->{$type}->{"units:trait!trait_$time:$time"}->{mean}) || exists($avg_varcomps{$t}->{$type}->{"trait:units!units!trait_$time:$time"}->{mean}) ) ) {
                        my $g = $avg_varcomps{$t}->{$type}->{"trait:vm(id_factor, geno_mat_3col)!trait_$time:$time"}->{mean};
                        my $r = $avg_varcomps{$t}->{$type}->{"units:trait!trait_$time:$time"}->{mean} || $avg_varcomps{$t}->{$type}->{"trait:units!units!trait_$time:$time"}->{mean};
                        my $h = $g + $r == 0 ? 0 : $g/($g + $r);
                        push @h_values, $h;
                        push @avg_varcomps_display, {
                            type => $t,
                            type_scenario => $type,
                            level => "h2-$time",
                            vals => [$h],
                            std => 0,
                            mean => $h
                        };
                    }
                }
                my $stat = Statistics::Descriptive::Full->new();
                $stat->add_data(@h_values);
                my $std = $stat->standard_deviation();
                my $mean = $stat->mean();
                push @avg_varcomps_display, {
                    type => $t,
                    type_scenario => $type,
                    level => "h2-avg",
                    vals => \@h_values,
                    std => $std,
                    mean => $mean
                };
            }
        }
    }
    #AIREMLF90 RR
    else {
        foreach (@$env_varcomps) {
            my $type = $_->{statistics_select};
            foreach my $t (@varcomp_keys) {
                my $res = $_->{$t}->{residual};
                my $genetic_line = 1;
                foreach $a (@{$_->{$t}->{genetic_covariance}}) {
                    push @{$avg_varcomps{$type}->{$t}->{genetic_covariance}->{$genetic_line}->{vals}}, $a;
                    $genetic_line++;
                }
                my $env_line = 1;
                foreach $a (@{$_->{$t}->{env_covariance}}) {
                    push @{$avg_varcomps{$type}->{$t}->{env_covariance}->{$env_line}->{vals}}, $a;
                    $env_line++;
                }
                my $hg_line = 1;
                foreach $a (@{$_->{$t}->{genetic_covariance}}) {
                    my $hg = $a + $res == 0 ? 0 : $a/($a + $res);
                    push @{$avg_varcomps{$type}->{$t}->{h2_coeff}->{$hg_line}->{vals}}, $hg;
                    $hg_line++;
                }
                my $he_line = 1;
                foreach $a (@{$_->{$t}->{env_covariance}}) {
                    my $he = $a + $res == 0 ? 0 : $a/($a + $res);
                    push @{$avg_varcomps{$type}->{$t}->{env2_coeff}->{$he_line}->{vals}}, $he;
                    $he_line++;
                }
                my $genetic_corr_line = 1;
                foreach $a (@{$_->{$t}->{genetic_correlation}}) {
                    push @{$avg_varcomps{$type}->{$t}->{genetic_correlation}->{$genetic_corr_line}->{vals}}, $a;
                    $genetic_corr_line++;
                }
                my $env_corr_line = 1;
                foreach $a (@{$_->{$t}->{env_correlation}}) {
                    push @{$avg_varcomps{$type}->{$t}->{env_correlation}->{$env_corr_line}->{vals}}, $a;
                    $env_corr_line++;
                }
                push @{$avg_varcomps{$type}->{$t}->{residual}->{1}->{vals}}, $res;
            }
        }
        # print STDERR Dumper \%avg_varcomps;

        my %avg_varcomps_save;
        while (my($t, $type_obj) = each %avg_varcomps) {
            while (my($type, $line_obj) = each %$type_obj) {
                while (my($var_type, $level_obj) = each %$line_obj) {
                    while (my($line_num, $vals) = each %$level_obj) {
                        my $values = $vals->{vals};
                        my $level_rec = $var_type."_".$line_num;
                        my $stat = Statistics::Descriptive::Full->new();
                        $stat->add_data(@$values);
                        my $std = $stat->standard_deviation();
                        my $mean = $stat->mean();
                        $avg_varcomps_save{$t}->{$type}->{$level_rec}->{std} = $std;
                        $avg_varcomps_save{$t}->{$type}->{$level_rec}->{mean} = $mean;
                        $avg_varcomps_save{$t}->{$type}->{$level_rec}->{vals} = $values;
                        push @avg_varcomps_display, {
                            type => $t,
                            type_scenario => $type,
                            level => $level_rec,
                            vals => $values,
                            std => $std,
                            mean => $mean
                        };
                    }
                }
            }
        }
        %avg_varcomps = %avg_varcomps_save;
    }
    # print STDERR Dumper \%avg_varcomps;

    my %avg_cross_validation;
    my @avg_cross_validation_display;
    foreach (@$env_varcomps) {
        my $type = $_->{statistics_select};
        foreach my $t (@varcomp_keys) {
            my $cv1 = $_->{$t}->{cv_1};
            my $cv2 = $_->{$t}->{cv_2};
            my $cv1_values = $cv1->{values};
            my $cv2_values = $cv2->{values};
            push @{$avg_cross_validation{$type}->{$t}->{cv_1}}, @$cv1_values;
            push @{$avg_cross_validation{$type}->{$t}->{cv_2}}, @$cv2_values;
        }
    }
    while (my($t, $type_obj_m) = each %avg_cross_validation) {
        while (my($type_scenario, $type_obj) = each %$type_obj_m) {
            my $cv1_values = $type_obj->{cv_1};
            my $cv2_values = $type_obj->{cv_2};
            my $stat_cv1 = Statistics::Descriptive::Full->new();
            $stat_cv1->add_data(@$cv1_values);
            my $cv1_std = $stat_cv1->standard_deviation();
            my $cv1_mean = $stat_cv1->mean();
            my $stat_cv2 = Statistics::Descriptive::Full->new();
            $stat_cv2->add_data(@$cv2_values);
            my $cv2_std = $stat_cv2->standard_deviation();
            my $cv2_mean = $stat_cv2->mean();
            push @avg_cross_validation_display, {
                type => $t,
                type_scenario => $type_scenario,
                cv1_mean => $cv1_mean,
                cv1_std => $cv1_std,
                cv2_mean => $cv2_mean,
                cv2_std => $cv2_std
            };
        }
    }

    my $q_save_res = "SELECT nd_protocolprop_id, value FROM nd_protocolprop WHERE nd_protocol_id=? AND type_id=?;";
    my $h_save_res = $schema->storage->dbh()->prepare($q_save_res);
    $h_save_res->execute($analytics_protocol_id, $protocolprop_result_type_cvterm_id);
    my ($protocol_result_summary_id_select, $value2) = $h_save_res->fetchrow_array();
    $protocol_result_summary = $value2 ? decode_json $value2 : [];
    $protocol_result_summary_id = $protocol_result_summary_id_select;

    push @$protocol_result_summary, {
        statistics_select_original => $statistics_select_original,
        number_iterations => $number_iterations,
        env_iterations => $env_iterations,
        env_correlation_results => $env_corr_res,
        trait_name_map => \%trait_name_encoder,
        trait_to_time_map => \%trait_to_time_map,
        env_varcomps => $env_varcomps,
        avg_varcomps => \%avg_varcomps,
        avg_varcomps_display => \@avg_varcomps_display,
        avg_cross_validation => \%avg_cross_validation,
        avg_cross_validation_display => \@avg_cross_validation_display
    };
    my $q2 = "UPDATE nd_protocolprop SET value=? WHERE nd_protocolprop_id=?;";
    my $h2 = $schema->storage->dbh()->prepare($q2);
    $h2->execute(encode_json $protocol_result_summary, $protocol_result_summary_id);

    foreach my $f (@$spatial_effects_plots) {
        my $auxiliary_model_file = $c->config->{basepath}.$f->[0];
        my $auxiliary_model_file_archive_type = "nicksmixedmodelsanalytics_v1_".$f->[1];
        print STDERR "$auxiliary_model_file_archive_type : $auxiliary_model_file\n";

        my $model_aux_original_name = basename($auxiliary_model_file);

        my $uploader_autoencoder = CXGN::UploadFile->new({
            tempfile => $auxiliary_model_file,
            subdirectory => $auxiliary_model_file_archive_type,
            archive_path => $c->config->{archive_path},
            archive_filename => $model_aux_original_name,
            timestamp => $timestamp,
            user_id => $user_id,
            user_role => $user_role
        });
        my $archived_aux_filename_with_path = $uploader_autoencoder->archive();
        my $md5_aux = $uploader_autoencoder->get_md5($archived_aux_filename_with_path);
        if (!$archived_aux_filename_with_path) {
            return { error => "Could not save file $model_aux_original_name in archive." };
        }
        print STDERR "Archived Analytics Figure File: $archived_aux_filename_with_path\n";

        my $md_row_aux = $metadata_schema->resultset("MdMetadata")->create({create_person_id => $user_id});
        my $file_row_aux = $metadata_schema->resultset("MdFiles")->create({
            basename => basename($archived_aux_filename_with_path),
            dirname => dirname($archived_aux_filename_with_path),
            filetype => $auxiliary_model_file_archive_type,
            md5checksum => $md5_aux->hexdigest(),
            metadata_id => $md_row_aux->metadata_id()
        });

        my $experiment_files_aux = $phenome_schema->resultset("NdExperimentMdFiles")->create({
            nd_experiment_id => $analytics_nd_experiment_id,
            file_id => $file_row_aux->file_id()
        });
    }

    foreach my $f (@$spatial_effects_files_store) {
        my $auxiliary_model_file = $f->[0];
        my $auxiliary_model_file_archive_type = "nicksmixedmodelsanalytics_v1_".$f->[1];
        print STDERR "$auxiliary_model_file_archive_type : $auxiliary_model_file\n";

        my $model_aux_original_name = basename($auxiliary_model_file);

        my $uploader_autoencoder = CXGN::UploadFile->new({
            tempfile => $auxiliary_model_file,
            subdirectory => $auxiliary_model_file_archive_type,
            archive_path => $c->config->{archive_path},
            archive_filename => $model_aux_original_name,
            timestamp => $timestamp,
            user_id => $user_id,
            user_role => $user_role
        });
        my $archived_aux_filename_with_path = $uploader_autoencoder->archive();
        my $md5_aux = $uploader_autoencoder->get_md5($archived_aux_filename_with_path);
        if (!$archived_aux_filename_with_path) {
            return { error => "Could not save file $model_aux_original_name in archive." };
        }
        print STDERR "Archived Analytics Data File: $archived_aux_filename_with_path\n";

        my $md_row_aux = $metadata_schema->resultset("MdMetadata")->create({create_person_id => $user_id});
        my $file_row_aux = $metadata_schema->resultset("MdFiles")->create({
            basename => basename($archived_aux_filename_with_path),
            dirname => dirname($archived_aux_filename_with_path),
            filetype => $auxiliary_model_file_archive_type,
            md5checksum => $md5_aux->hexdigest(),
            metadata_id => $md_row_aux->metadata_id()
        });

        my $experiment_files_aux = $phenome_schema->resultset("NdExperimentMdFiles")->create({
            nd_experiment_id => $analytics_nd_experiment_id,
            file_id => $file_row_aux->file_id()
        });
    }

    $c->stash->{rest} = {
        analytics_protocol_id => $analytics_protocol_id,
        unique_traits => \@sorted_trait_names,
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
        analysis_model_type => $statistics_select,
        application_name => "NickMorales Mixed Models Analytics",
        application_version => "V1.01",
        field_trial_design => $field_trial_design,
        spatial_effects_plots => $spatial_effects_plots,
        simulated_environment_to_effect_correlations => $env_corr_res,
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
