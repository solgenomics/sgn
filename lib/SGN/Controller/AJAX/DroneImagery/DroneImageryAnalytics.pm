
=head1 NAME

SGN::Controller::AJAX::DroneImagery::DroneImageryAnalytics - a REST controller class to provide the
functions for uploading and analyzing drone imagery

=head1 DESCRIPTION

=head1 AUTHOR

=cut

package SGN::Controller::AJAX::DroneImagery::DroneImageryAnalytics;

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
use Scalar::Util qw(looks_like_number);
use SGN::Controller::AJAX::DroneImagery::DroneImagery;
use Storable qw(dclone);
#use Inline::Python;

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
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $people_schema = $c->dbic_schema("CXGN::People::Schema");
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $statistics_select = $c->req->param('statistics_select');
    my $analytics_select = $c->req->param('analytics_select');

    my $field_trial_id_list = $c->req->param('field_trial_id_list') ? decode_json $c->req->param('field_trial_id_list') : [];
    my $field_trial_id_list_string = join ',', @$field_trial_id_list;
    
    if (scalar(@$field_trial_id_list) != 1) {
        $c->stash->{rest} = { error => "Please select one field trial!"};
        return;
    }

    my $trait_id_list = $c->req->param('observation_variable_id_list') ? decode_json $c->req->param('observation_variable_id_list') : [];
    my $compute_relationship_matrix_from_htp_phenotypes = $c->req->param('relationship_matrix_type');
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

    my $minimization_genetic_sum_threshold = $c->req->param('genetic_minimization_threshold');
    my $minimization_env_sum_threshold = $c->req->param('env_minimization_threshold');
    my $env_simulation = $c->req->param('env_simulation');

    my $shared_cluster_dir_config = $c->config->{cluster_shared_tempdir};
    my $tmp_stats_dir = $shared_cluster_dir_config."/tmp_drone_statistics";
    mkdir $tmp_stats_dir if ! -d $tmp_stats_dir;
    my ($grm_rename_tempfile_fh, $grm_rename_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    $grm_rename_tempfile .= '.grm';
    my ($minimization_iterations_tempfile_fh, $minimization_iterations_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    
    my $dir = $c->tempfiles_subdir('/tmp_drone_statistics');
    my $minimization_iterations_tempfile_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
    $minimization_iterations_tempfile_string .= '.png';
    my $minimization_iterations_figure_tempfile = $c->config->{basepath}."/".$minimization_iterations_tempfile_string;

    my $genetic_effects_figure_tempfile_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
    $genetic_effects_figure_tempfile_string .= '.png';
    my $genetic_effects_figure_tempfile = $c->config->{basepath}."/".$genetic_effects_figure_tempfile_string;

    my $env_effects_figure_tempfile_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
    $env_effects_figure_tempfile_string .= '.png';
    my $env_effects_figure_tempfile = $c->config->{basepath}."/".$env_effects_figure_tempfile_string;

    my $blupf90_solutions_tempfile;
    my $yhat_residual_tempfile;
    my $grm_file;

    my @results;
    my $result_blup_data;
    my $result_blup_data_first;
    my $result_blup_data_iterations;
    my $result_blup_spatial_data;
    my $result_blup_spatial_data_first;
    my $result_blup_spatial_data_iterations;
    my $result_blup_pe_data;
    my $result_blup_pe_data_first;
    my $result_blup_pe_data_iterations;
    my $result_residual_data;
    my $result_fitted_data;
    my @result_effect_sum_iterations;
    my @sorted_residual_trait_names;
    my $statistical_ontology_term;
    my $analysis_result_values_type;
    my $analysis_model_language = "R";
    my $analysis_model_training_data_file_type;
    my $field_trial_design;
    my $model_sum_square_residual;
    my $genetic_effect_min = 1000000000;
    my $genetic_effect_max = -1000000000;
    my $env_effect_min = 1000000000;
    my $env_effect_max = -1000000000;
    my $iteration_count = 0;
    my $iteration_max = 2;

    my %sommer_rr_genetic_coeff;
    my %sommer_rr_temporal_coeff;
    my %rr_unique_traits;
    my %rr_residual_unique_traits;
    my %fixed_effects;
    my %rr_genetic_coefficients;
    my %rr_temporal_coefficients;

    my %unique_accessions_seen;

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
        my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'fullview', 'concurrent', $c->config->{basepath});
        sleep(10);
    }

    my ($trait_name_encoder_hash, $trait_name_encoder_rev_hash, $phenotype_data_original_hash_out, $phenotype_data_hash_out, $stock_info_hash, $unique_accessions_hash, $seen_days_after_plantings_hash, $seen_times_hash, $data_matrix_array, $obsunit_row_col_hash, $seen_plot_names_hash, $plot_id_map_hash, $trait_composing_info_hash, $permanent_environment_structure_tempfile, $stats_tempfile, $stats_tempfile_2, $parameter_tempfile, $coeff_genetic_tempfile, $coeff_pe_tempfile, $stats_out_tempfile_string, $stats_out_tempfile, $stats_prep2_tempfile, $stats_out_htp_rel_tempfile_input, $stats_out_htp_rel_tempfile, $stats_out_htp_rel_tempfile_out_string, $stats_out_htp_rel_tempfile_out, $stats_out_param_tempfile, $stats_out_tempfile_row, $stats_out_tempfile_col, $stats_out_tempfile_2dspl, $stats_out_tempfile_residual, $stats_out_tempfile_genetic, $stats_out_tempfile_permanent_environment, $sorted_scaled_ln_times_array, $time_max, $time_min, $plot_id_factor_map_reverse_hash, $plot_id_count_map_reverse_hash, $sorted_trait_names_array, $unique_accession_names_array, $unique_plot_names_array, $accession_id_factor_map_hash, $accession_id_factor_map_reverse_hash, $time_count_map_reverse_hash, $rep_time_factors_array, $ind_rep_factors_array, $stock_name_row_col_hash) = _generate_input_file($c, $schema, $trait_id_list, $field_trial_id_list, $statistics_select, $tmp_stats_dir, $use_area_under_curve, $legendre_order_number, $permanent_environment_structure, undef, $analytics_select, undef, undef, undef, undef, undef, undef, undef, undef);
    my %trait_name_encoder = %$trait_name_encoder_hash;
    my %trait_name_encoder_rev = %$trait_name_encoder_rev_hash;
    my $phenotype_data_original_hash = $phenotype_data_original_hash_out;
    my $phenotype_data_hash = $phenotype_data_hash_out;
    my %stock_info = %$stock_info_hash;
    my %unique_accessions = %$unique_accessions_hash;
    my %seen_days_after_plantings = %$seen_days_after_plantings_hash;
    my %seen_times = %$seen_times_hash;
    my @data_matrix = @$data_matrix_array;
    my %obsunit_row_col = %$obsunit_row_col_hash;
    my %seen_plot_names = %$seen_plot_names_hash;
    my %plot_id_map = %$plot_id_map_hash;
    my %trait_composing_info = %$trait_composing_info_hash;
    my @sorted_scaled_ln_times = @$sorted_scaled_ln_times_array;
    my %plot_id_factor_map_reverse = %$plot_id_factor_map_reverse_hash;
    my %plot_id_count_map_reverse = %$plot_id_count_map_reverse_hash;
    my @sorted_trait_names = @$sorted_trait_names_array;
    my @unique_accession_names = @$unique_accession_names_array;
    my @unique_plot_names = @$unique_plot_names_array;
    my %accession_id_factor_map = %$accession_id_factor_map_hash;
    my %accession_id_factor_map_reverse = %$accession_id_factor_map_reverse_hash;
    my %time_count_map_reverse = %$time_count_map_reverse_hash;
    my @rep_time_factors = @$rep_time_factors_array;
    my @ind_rep_factors = @$ind_rep_factors_array;
    my %stock_name_row_col = %$stock_name_row_col_hash;

    my $minimization_genetic_done = 0;
    my $minimization_env_done = 0;
    my $genetic_effect_sum = 0;
    my $env_effect_sum = 0;
    my $residual_sum = 0;

    my $csv = Text::CSV->new({ sep_char => "\t" });

    if ($statistics_select eq 'sommer_grm_spatial_genetic_blups' || $statistics_select eq 'sommer_grm_temporal_random_regression_dap_genetic_blups' || $statistics_select eq 'sommer_grm_temporal_random_regression_gdd_genetic_blups' || $statistics_select eq 'sommer_grm_genetic_only_random_regression_dap_genetic_blups' || $statistics_select eq 'sommer_grm_genetic_only_random_regression_gdd_genetic_blups' || $statistics_select eq 'blupf90_grm_random_regression_dap_blups' || $statistics_select eq 'blupf90_grm_random_regression_gdd_blups' || $statistics_select eq 'airemlf90_grm_random_regression_dap_blups' || $statistics_select eq 'airemlf90_grm_random_regression_gdd_blups' || $statistics_select eq 'sommer_grm_genetic_blups') {


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
        }

        my $time = DateTime->now();
        my $timestamp = $time->ymd()."_".$time->hms();

        if ($statistics_select eq 'sommer_grm_genetic_blups') {
            $statistical_ontology_term = "Multivariate genetic BLUPs using genetic relationship matrix computed using Sommer R|SGNSTAT:0000024";

            $analysis_result_values_type = "analysis_result_values_match_accession_names";
            $analysis_model_training_data_file_type = "nicksmixedmodels_v1.01_sommer_grm_genetic_blups_phenotype_file";

            @unique_plot_names = sort keys %seen_plot_names;

            my @encoded_traits = values %trait_name_encoder;
            my $encoded_trait_string = join ',', @encoded_traits;
            my $number_traits = scalar(@encoded_traits);
            my $cbind_string = $number_traits > 1 ? "cbind($encoded_trait_string)" : $encoded_trait_string;

            while ($analytics_select eq 'minimize_genetic_effect' && !$minimization_genetic_done) {
                $genetic_effect_min = 1000000000;
                $genetic_effect_max = -1000000000;
                $genetic_effect_sum = 0;
                $env_effect_sum = 0;
                $residual_sum = 0;

                my $cmd = 'R -e "library(sommer); library(data.table); library(reshape2);
                mat <- data.frame(fread(\''.$stats_tempfile.'\', header=TRUE, sep=\',\'));
                geno_mat_3col <- data.frame(fread(\''.$grm_file.'\', header=FALSE, sep=\'\t\'));
                geno_mat <- acast(geno_mat_3col, V1~V2, value.var=\'V3\');
                geno_mat[is.na(geno_mat)] <- 0;
                mix <- mmer('.$cbind_string.'~1 + replicate, random=~vs(id, Gu=geno_mat, Gtc=unsm('.$number_traits.')), rcov=~vs(units, Gtc=unsm('.$number_traits.')), data=mat, tolparinv='.$tolparinv.');
                write.table(data.frame(plot_id = mix\$data\$plot_id, residuals = mix\$residuals, fitted = mix\$fitted), file=\''.$stats_out_tempfile_residual.'\', row.names=FALSE, col.names=TRUE, sep=\'\t\');
                write.table(mix\$U\$\`u:id\`, file=\''.$stats_out_tempfile.'\', row.names=TRUE, col.names=TRUE, sep=\'\t\');
                "';
                print STDERR Dumper $cmd;
                eval {
                    my $status = system($cmd);
                };
                my $run_stats_fault = 0;
                if ($@) {
                    print STDERR "R ERROR\n";
                    print STDERR Dumper $@;
                    $run_stats_fault = 1;
                }
                else {
                    my $current_gen_row_count = 0;

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
                                if (defined $value && $value ne '') {
                                    $result_blup_data->{$stock_name}->{$trait} = [$value, $timestamp, $user_name, '', ''];

                                    if ($value < $genetic_effect_min) {
                                        $genetic_effect_min = $value;
                                    }
                                    elsif ($value >= $genetic_effect_max) {
                                        $genetic_effect_max = $value;
                                    }

                                    $genetic_effect_sum += abs($value);
                                }
                                $col_counter++;
                            }
                            $current_gen_row_count++;
                        }
                    close($fh);

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
                            foreach (0..$number_traits-1) {
                                my $trait_name = $sorted_trait_names[$_];
                                my $residual = $columns[1 + $_];
                                my $fitted = $columns[1 + $number_traits + $_];
                                my $stock_name = $plot_id_map{$stock_id};
                                if (defined $residual && $residual ne '') {
                                    $result_residual_data->{$stock_name}->{$trait_name} = [$residual, $timestamp, $user_name, '', ''];
                                    $residual_sum += abs($residual);
                                }
                                if (defined $fitted && $fitted ne '') {
                                    $result_fitted_data->{$stock_name}->{$trait_name} = [$fitted, $timestamp, $user_name, '', ''];
                                }
                            }
                        }
                    close($fh_residual);

                    if ($current_gen_row_count == 0) {
                        $run_stats_fault = 1;
                    }
                }

                if ($run_stats_fault == 1) {
                    print STDERR "ERROR IN R CMD\n";
                    ($genetic_effect_sum, $env_effect_sum, $phenotype_data_original_hash_out, $phenotype_data_hash_out, $result_blup_data, $result_blup_spatial_data, $result_blup_pe_data) = _select_lowest_effects($analytics_select, $statistics_select, $result_blup_data_iterations, $result_blup_spatial_data_iterations, $result_blup_pe_data_iterations);
                }
                else {
                    push @result_effect_sum_iterations, [$iteration_count, $genetic_effect_sum, $env_effect_sum, $residual_sum];

                    my $result_blup_data_copy = dclone $result_blup_data;
                    my $phenotype_data_hash_out_copy = dclone $phenotype_data_hash_out;

                    $result_blup_data_iterations->{$genetic_effect_sum} = {
                        gen => $result_blup_data_copy,
                        env_effect => $env_effect_sum,
                        phenotype_data => $phenotype_data_hash_out_copy,
                        phenotype_data_original => $phenotype_data_original_hash_out
                    };
                }

                if ($iteration_count == 0) {
                    $result_blup_data_first = $result_blup_data;
                }

                print STDERR "$statistics_select GENETIC EFFECT SUM $genetic_effect_sum\n";

                if ($genetic_effect_sum > $minimization_genetic_sum_threshold && $iteration_count < $iteration_max) {
                    ($trait_name_encoder_hash, $trait_name_encoder_rev_hash, $phenotype_data_original_hash_out, $phenotype_data_hash_out, $stock_info_hash, $unique_accessions_hash, $seen_days_after_plantings_hash, $seen_times_hash, $data_matrix_array, $obsunit_row_col_hash, $seen_plot_names_hash, $plot_id_map_hash, $trait_composing_info_hash, $permanent_environment_structure_tempfile, $stats_tempfile, $stats_tempfile_2, $parameter_tempfile, $coeff_genetic_tempfile, $coeff_pe_tempfile, $stats_out_tempfile_string, $stats_out_tempfile, $stats_prep2_tempfile, $stats_out_htp_rel_tempfile_input, $stats_out_htp_rel_tempfile, $stats_out_htp_rel_tempfile_out_string, $stats_out_htp_rel_tempfile_out, $stats_out_param_tempfile, $stats_out_tempfile_row, $stats_out_tempfile_col, $stats_out_tempfile_2dspl, $stats_out_tempfile_residual, $stats_out_tempfile_genetic, $stats_out_tempfile_permanent_environment, $sorted_scaled_ln_times_array, $time_max, $time_min, $plot_id_factor_map_reverse_hash, $plot_id_count_map_reverse_hash, $sorted_trait_names_array, $unique_accession_names_array, $unique_plot_names_array, $accession_id_factor_map_hash, $accession_id_factor_map_reverse_hash, $time_count_map_reverse_hash, $rep_time_factors_array, $ind_rep_factors_array, $stock_name_row_col_hash) = _generate_input_file($c, $schema, $trait_id_list, $field_trial_id_list, $statistics_select, $tmp_stats_dir, $use_area_under_curve, $legendre_order_number, $permanent_environment_structure, $phenotype_data_hash, $analytics_select, $result_blup_data, undef, undef, $env_simulation, $genetic_effect_min, $genetic_effect_max, undef, undef);

                    $phenotype_data_hash = $phenotype_data_hash_out;
                }
                else {
                    $minimization_genetic_done = 1;
                }

                print STDERR "ITERATION $iteration_count\n";
                $iteration_count++;
            }
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

            while ( ($analytics_select eq 'minimize_genetic_effect' && !$minimization_genetic_done) || ($analytics_select eq 'minimize_local_env_effect' && !$minimization_env_done) ) {
                $genetic_effect_min = 1000000000;
                $genetic_effect_max = -1000000000;
                $env_effect_min = 1000000000;
                $env_effect_max = -1000000000;
                $genetic_effect_sum = 0;
                $env_effect_sum = 0;
                $residual_sum = 0;

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
                if (!is.null(mix\$U)) {
                #gen_cor <- cov2cor(mix\$sigma\$\`u:id\`);
                write.table(mix\$U\$\`u:id\`, file=\''.$stats_out_tempfile.'\', row.names=TRUE, col.names=TRUE, sep=\'\t\');
                write.table(mix\$U\$\`u:rowNumberFactor\`, file=\''.$stats_out_tempfile_row.'\', row.names=TRUE, col.names=TRUE, sep=\'\t\');
                write.table(mix\$U\$\`u:colNumberFactor\`, file=\''.$stats_out_tempfile_col.'\', row.names=TRUE, col.names=TRUE, sep=\'\t\');
                write.table(data.frame(plot_id = mix\$data\$plot_id, residuals = mix\$residuals, fitted = mix\$fitted), file=\''.$stats_out_tempfile_residual.'\', row.names=FALSE, col.names=TRUE, sep=\'\t\');
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
                }
                "';
                # print STDERR Dumper $cmd;
                eval {
                    my $status = system($cmd);
                };
                my $run_stats_fault = 0;
                if ($@) {
                    print STDERR "R ERROR\n";
                    print STDERR Dumper $@;
                    $run_stats_fault = 1;
                }
                else {
                    my $current_gen_row_count = 0;
                    my $current_env_row_count = 0;

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
                                if (defined $value && $value ne '') {
                                    $result_blup_data->{$stock_name}->{$trait} = [$value, $timestamp, $user_name, '', ''];

                                    if ($value < $genetic_effect_min) {
                                        $genetic_effect_min = $value;
                                    }
                                    elsif ($value >= $genetic_effect_max) {
                                        $genetic_effect_max = $value;
                                    }

                                    $genetic_effect_sum += abs($value);
                                }
                                $col_counter++;
                            }
                            $current_gen_row_count++;
                        }
                    close($fh);

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
                                if (defined $value && $value ne '') {
                                    $result_blup_spatial_data->{$plot_name}->{$trait} = [$value, $timestamp, $user_name, '', ''];

                                    if ($value < $env_effect_min) {
                                        $env_effect_min = $value;
                                    }
                                    elsif ($value >= $env_effect_max) {
                                        $env_effect_max = $value;
                                    }

                                    $env_effect_sum += abs($value);
                                }
                                $col_counter++;
                            }
                            $current_env_row_count++;
                        }
                    close($fh_2dspl);

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
                            foreach (0..$number_traits-1) {
                                my $trait_name = $sorted_trait_names[$_];
                                my $residual = $columns[1 + $_];
                                my $fitted = $columns[1 + $number_traits + $_];
                                my $stock_name = $plot_id_map{$stock_id};
                                if (defined $residual && $residual ne '') {
                                    $result_residual_data->{$stock_name}->{$trait_name} = [$residual, $timestamp, $user_name, '', ''];
                                    $residual_sum += abs($residual);
                                }
                                if (defined $fitted && $fitted ne '') {
                                    $result_fitted_data->{$stock_name}->{$trait_name} = [$fitted, $timestamp, $user_name, '', ''];
                                }
                            }
                        }
                    close($fh_residual);

                    if ($current_env_row_count == 0 || $current_gen_row_count == 0) {
                        $run_stats_fault = 1;
                    }
                }

                if ($run_stats_fault == 1) {
                    print STDERR "ERROR IN R CMD\n";
                    ($genetic_effect_sum, $env_effect_sum, $phenotype_data_original_hash_out, $phenotype_data_hash_out, $result_blup_data, $result_blup_spatial_data, $result_blup_pe_data) = _select_lowest_effects($analytics_select, $statistics_select, $result_blup_data_iterations, $result_blup_spatial_data_iterations, $result_blup_pe_data_iterations);
                }
                else {
                    push @result_effect_sum_iterations, [$iteration_count, $genetic_effect_sum, $env_effect_sum, $residual_sum];

                    my $result_blup_data_copy = dclone $result_blup_data;
                    my $result_blup_spatial_data_copy = dclone $result_blup_spatial_data;
                    my $result_residual_data_copy = dclone $result_residual_data;
                    my $result_fitted_data_copy = dclone $result_fitted_data;
                    my $phenotype_data_hash_out_copy = dclone $phenotype_data_hash_out;

                    $result_blup_data_iterations->{$genetic_effect_sum} = {
                        env => $result_blup_spatial_data_copy,
                        gen => $result_blup_data_copy,
                        residual => $result_residual_data_copy,
                        fitted => $result_fitted_data_copy,
                        env_effect => $env_effect_sum,
                        phenotype_data => $phenotype_data_hash_out_copy,
                        phenotype_data_original => $phenotype_data_original_hash_out
                    };

                    $result_blup_spatial_data_iterations->{$env_effect_sum} = {
                        env => $result_blup_spatial_data_copy,
                        gen => $result_blup_data_copy,
                        residual => $result_residual_data_copy,
                        fitted => $result_fitted_data_copy,
                        gen_effect => $genetic_effect_sum,
                        phenotype_data => $phenotype_data_hash_out_copy,
                        phenotype_data_original => $phenotype_data_original_hash_out
                    };
                }

                if ($iteration_count == 0) {
                    $result_blup_data_first = $result_blup_data;
                    $result_blup_spatial_data_first = $result_blup_spatial_data;
                }

                print STDERR "$statistics_select GENETIC EFFECT SUM $genetic_effect_sum\n";
                print STDERR "$statistics_select ENV EFFECT SUM $env_effect_sum\n";

                if ($analytics_select eq 'minimize_genetic_effect' && $genetic_effect_sum > $minimization_genetic_sum_threshold && $iteration_count < $iteration_max) {
                    ($trait_name_encoder_hash, $trait_name_encoder_rev_hash, $phenotype_data_original_hash_out, $phenotype_data_hash_out, $stock_info_hash, $unique_accessions_hash, $seen_days_after_plantings_hash, $seen_times_hash, $data_matrix_array, $obsunit_row_col_hash, $seen_plot_names_hash, $plot_id_map_hash, $trait_composing_info_hash, $permanent_environment_structure_tempfile, $stats_tempfile, $stats_tempfile_2, $parameter_tempfile, $coeff_genetic_tempfile, $coeff_pe_tempfile, $stats_out_tempfile_string, $stats_out_tempfile, $stats_prep2_tempfile, $stats_out_htp_rel_tempfile_input, $stats_out_htp_rel_tempfile, $stats_out_htp_rel_tempfile_out_string, $stats_out_htp_rel_tempfile_out, $stats_out_param_tempfile, $stats_out_tempfile_row, $stats_out_tempfile_col, $stats_out_tempfile_2dspl, $stats_out_tempfile_residual, $stats_out_tempfile_genetic, $stats_out_tempfile_permanent_environment, $sorted_scaled_ln_times_array, $time_max, $time_min, $plot_id_factor_map_reverse_hash, $plot_id_count_map_reverse_hash, $sorted_trait_names_array, $unique_accession_names_array, $unique_plot_names_array, $accession_id_factor_map_hash, $accession_id_factor_map_reverse_hash, $time_count_map_reverse_hash, $rep_time_factors_array, $ind_rep_factors_array, $stock_name_row_col_hash) = _generate_input_file($c, $schema, $trait_id_list, $field_trial_id_list, $statistics_select, $tmp_stats_dir, $use_area_under_curve, $legendre_order_number, $permanent_environment_structure, $phenotype_data_hash, $analytics_select, $result_blup_data, undef, undef, $env_simulation, $genetic_effect_min, $genetic_effect_max, undef, undef);

                    $phenotype_data_hash = $phenotype_data_hash_out;
                }
                else {
                    $minimization_genetic_done = 1;
                }

                if ($analytics_select eq 'minimize_local_env_effect' && $env_effect_sum > $minimization_env_sum_threshold && $iteration_count < $iteration_max) {
                    ($trait_name_encoder_hash, $trait_name_encoder_rev_hash, $phenotype_data_original_hash_out, $phenotype_data_hash_out, $stock_info_hash, $unique_accessions_hash, $seen_days_after_plantings_hash, $seen_times_hash, $data_matrix_array, $obsunit_row_col_hash, $seen_plot_names_hash, $plot_id_map_hash, $trait_composing_info_hash, $permanent_environment_structure_tempfile, $stats_tempfile, $stats_tempfile_2, $parameter_tempfile, $coeff_genetic_tempfile, $coeff_pe_tempfile, $stats_out_tempfile_string, $stats_out_tempfile, $stats_prep2_tempfile, $stats_out_htp_rel_tempfile_input, $stats_out_htp_rel_tempfile, $stats_out_htp_rel_tempfile_out_string, $stats_out_htp_rel_tempfile_out, $stats_out_param_tempfile, $stats_out_tempfile_row, $stats_out_tempfile_col, $stats_out_tempfile_2dspl, $stats_out_tempfile_residual, $stats_out_tempfile_genetic, $stats_out_tempfile_permanent_environment, $sorted_scaled_ln_times_array, $time_max, $time_min, $plot_id_factor_map_reverse_hash, $plot_id_count_map_reverse_hash, $sorted_trait_names_array, $unique_accession_names_array, $unique_plot_names_array, $accession_id_factor_map_hash, $accession_id_factor_map_reverse_hash, $time_count_map_reverse_hash, $rep_time_factors_array, $ind_rep_factors_array, $stock_name_row_col_hash) = _generate_input_file($c, $schema, $trait_id_list, $field_trial_id_list, $statistics_select, $tmp_stats_dir, $use_area_under_curve, $legendre_order_number, $permanent_environment_structure, $phenotype_data_hash, $analytics_select, undef, $result_blup_spatial_data, undef, $env_simulation, undef, undef, $env_effect_min, $env_effect_max);

                    $phenotype_data_hash = $phenotype_data_hash_out;
                }
                else {
                    $minimization_env_done = 1;
                }

                print STDERR "ITERATION $iteration_count\n";
                $iteration_count++;
            }
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

            while ( ($analytics_select eq 'minimize_genetic_effect' && !$minimization_genetic_done) || ($analytics_select eq 'minimize_local_env_effect' && !$minimization_env_done) ) {
                $genetic_effect_min = 1000000000;
                $genetic_effect_max = -1000000000;
                $env_effect_min = 1000000000;
                $env_effect_max = -1000000000;
                $genetic_effect_sum = 0;
                $env_effect_sum = 0;
                $residual_sum = 0;
                my $result_blup_data_delta = {};
                my $result_blup_pe_data_delta = {};

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
                if (!is.null(mix\$U)) {
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
                }
                ';
                print STDERR Dumper $cmd;
                my $status = system($cmd);

                # no warnings 'uninitialized';

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
                            if (defined $value && $value ne '') {
                                push @{$sommer_rr_genetic_coeff{$accession_name}}, $value;
                            }
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

                        my $col_counter = 1;
                        foreach (0..$legendre_order_number) {
                            my $value = $columns[$col_counter];
                            if (defined $value && $value ne '') {
                                push @{$sommer_rr_temporal_coeff{$plot_name}}, $value;
                            }
                            $col_counter++;
                        }
                        $row_counter++;
                    }
                close($fh);

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
                        if (defined $residual && $residual ne '') {
                            $result_residual_data->{$stock_name}->{$seen_times{$time}} = [$residual, $timestamp, $user_name, '', ''];
                            $residual_sum += abs($residual);
                        }
                        if (defined $fitted && $fitted ne '') {
                            $result_fitted_data->{$stock_name}->{$seen_times{$time}} = [$fitted, $timestamp, $user_name, '', ''];
                        }
                    }
                close($fh_residual);

                my $q_time = "SELECT t.cvterm_id FROM cvterm as t JOIN cv ON(t.cv_id=cv.cv_id) WHERE t.name=? and cv.name=?;";
                my $h_time = $schema->storage->dbh()->prepare($q_time);

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

                while ( my ($accession_name, $coeffs) = each %sommer_rr_genetic_coeff) {
                    foreach my $time (@sorted_trait_names) {
                        my $value = 0;
                        my $coeff_counter = 0;
                        foreach my $b (@$coeffs) {
                            my $eval_string = $legendre_coeff_exec[$coeff_counter];
                            # print STDERR Dumper [$eval_string, $b, $time];
                            $value += eval $eval_string;
                            $coeff_counter++;
                        }

                        $result_blup_data_delta->{$accession_name}->{$time} = [$value, $timestamp, $user_name, '', ''];

                        if ($value < $genetic_effect_min) {
                            $genetic_effect_min = $value;
                        }
                        elsif ($value >= $genetic_effect_max) {
                            $genetic_effect_max = $value;
                        }

                        $genetic_effect_sum += abs($value);
                    }
                }

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

                while ( my ($plot_name, $coeffs) = each %sommer_rr_temporal_coeff) {
                    foreach my $time (@sorted_trait_names) {
                        my $value = 0;
                        my $coeff_counter = 0;
                        foreach my $b (@$coeffs) {
                            my $eval_string = $legendre_coeff_exec[$coeff_counter];
                            # print STDERR Dumper [$eval_string, $b, $time];
                            $value += eval $eval_string;
                            $coeff_counter++;
                        }

                        $result_blup_pe_data_delta->{$plot_name}->{$time} = [$value, $timestamp, $user_name, '', ''];

                        if ($value < $env_effect_min) {
                            $env_effect_min = $value;
                        }
                        elsif ($value >= $env_effect_max) {
                            $env_effect_max = $value;
                        }

                        $env_effect_sum += abs($value);
                    }
                }

                push @result_effect_sum_iterations, [$iteration_count, $genetic_effect_sum, $env_effect_sum, $residual_sum];

                my $result_blup_data_delta_copy = dclone $result_blup_data_delta;
                my $result_blup_pe_data_delta_copy = dclone $result_blup_pe_data_delta;
                my $result_residual_data_copy = dclone $result_residual_data;
                my $result_fitted_data_copy = dclone $result_fitted_data;
                my $phenotype_data_hash_out_copy = dclone $phenotype_data_hash_out;

                $result_blup_data_iterations->{$genetic_effect_sum} = {
                    env => $result_blup_pe_data_delta_copy,
                    gen => $result_blup_data_delta_copy,
                    residual => $result_residual_data_copy,
                    fitted => $result_fitted_data_copy,
                    env_effect => $env_effect_sum,
                    phenotype_data => $phenotype_data_hash_out_copy,
                    phenotype_data_original => $phenotype_data_original_hash_out
                };
                $result_blup_pe_data_iterations->{$env_effect_sum} = {
                    env => $result_blup_pe_data_delta_copy,
                    gen => $result_blup_data_delta_copy,
                    residual => $result_residual_data_copy,
                    fitted => $result_fitted_data_copy,
                    gen_effect => $genetic_effect_sum,
                    phenotype_data => $phenotype_data_hash_out_copy,
                    phenotype_data_original => $phenotype_data_original_hash_out
                };

                print STDERR "$statistics_select GENETIC EFFECT SUM $genetic_effect_sum\n";

                if ($analytics_select eq 'minimize_genetic_effect' && $genetic_effect_sum > $minimization_genetic_sum_threshold && $iteration_count < $iteration_max) {
                    ($trait_name_encoder_hash, $trait_name_encoder_rev_hash, $phenotype_data_original_hash_out, $phenotype_data_hash_out, $stock_info_hash, $unique_accessions_hash, $seen_days_after_plantings_hash, $seen_times_hash, $data_matrix_array, $obsunit_row_col_hash, $seen_plot_names_hash, $plot_id_map_hash, $trait_composing_info_hash, $permanent_environment_structure_tempfile, $stats_tempfile, $stats_tempfile_2, $parameter_tempfile, $coeff_genetic_tempfile, $coeff_pe_tempfile, $stats_out_tempfile_string, $stats_out_tempfile, $stats_prep2_tempfile, $stats_out_htp_rel_tempfile_input, $stats_out_htp_rel_tempfile, $stats_out_htp_rel_tempfile_out_string, $stats_out_htp_rel_tempfile_out, $stats_out_param_tempfile, $stats_out_tempfile_row, $stats_out_tempfile_col, $stats_out_tempfile_2dspl, $stats_out_tempfile_residual, $stats_out_tempfile_genetic, $stats_out_tempfile_permanent_environment, $sorted_scaled_ln_times_array, $time_max, $time_min, $plot_id_factor_map_reverse_hash, $plot_id_count_map_reverse_hash, $sorted_trait_names_array, $unique_accession_names_array, $unique_plot_names_array, $accession_id_factor_map_hash, $accession_id_factor_map_reverse_hash, $time_count_map_reverse_hash, $rep_time_factors_array, $ind_rep_factors_array, $stock_name_row_col_hash) = _generate_input_file($c, $schema, $trait_id_list, $field_trial_id_list, $statistics_select, $tmp_stats_dir, $use_area_under_curve, $legendre_order_number, $permanent_environment_structure, $phenotype_data_hash, $analytics_select, $result_blup_data_delta, undef, undef, $env_simulation, $genetic_effect_min, $genetic_effect_max, undef, undef);

                    $phenotype_data_hash = $phenotype_data_hash_out;
                }
                else {
                    $minimization_genetic_done = 1;
                }

                print STDERR "$statistics_select ENV EFFECT SUM $env_effect_sum\n";

                if ($analytics_select eq 'minimize_local_env_effect' && $env_effect_sum > $minimization_env_sum_threshold && $iteration_count < $iteration_max) {
                    ($trait_name_encoder_hash, $trait_name_encoder_rev_hash, $phenotype_data_original_hash_out, $phenotype_data_hash_out, $stock_info_hash, $unique_accessions_hash, $seen_days_after_plantings_hash, $seen_times_hash, $data_matrix_array, $obsunit_row_col_hash, $seen_plot_names_hash, $plot_id_map_hash, $trait_composing_info_hash, $permanent_environment_structure_tempfile, $stats_tempfile, $stats_tempfile_2, $parameter_tempfile, $coeff_genetic_tempfile, $coeff_pe_tempfile, $stats_out_tempfile_string, $stats_out_tempfile, $stats_prep2_tempfile, $stats_out_htp_rel_tempfile_input, $stats_out_htp_rel_tempfile, $stats_out_htp_rel_tempfile_out_string, $stats_out_htp_rel_tempfile_out, $stats_out_param_tempfile, $stats_out_tempfile_row, $stats_out_tempfile_col, $stats_out_tempfile_2dspl, $stats_out_tempfile_residual, $stats_out_tempfile_genetic, $stats_out_tempfile_permanent_environment, $sorted_scaled_ln_times_array, $time_max, $time_min, $plot_id_factor_map_reverse_hash, $plot_id_count_map_reverse_hash, $sorted_trait_names_array, $unique_accession_names_array, $unique_plot_names_array, $accession_id_factor_map_hash, $accession_id_factor_map_reverse_hash, $time_count_map_reverse_hash, $rep_time_factors_array, $ind_rep_factors_array, $stock_name_row_col_hash) = _generate_input_file($c, $schema, $trait_id_list, $field_trial_id_list, $statistics_select, $tmp_stats_dir, $use_area_under_curve, $legendre_order_number, $permanent_environment_structure, $phenotype_data_hash, $analytics_select, undef, undef, $result_blup_pe_data_delta, $env_simulation, undef, undef, $env_effect_min, $env_effect_max);

                    $phenotype_data_hash = $phenotype_data_hash_out;
                }
                else {
                    $minimization_env_done = 1;
                }

                print STDERR "ITERATION $iteration_count\n";
                $iteration_count++;
            }

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
    
            while ( ($analytics_select eq 'minimize_genetic_effect' && !$minimization_genetic_done) || ($analytics_select eq 'minimize_local_env_effect' && !$minimization_env_done) ) {
                $genetic_effect_min = 1000000000;
                $genetic_effect_max = -1000000000;
                $genetic_effect_sum = 0;
                $env_effect_sum = 0;
                $residual_sum = 0;
                my $result_blup_data_delta = {};

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
                if (!is.null(mix\$U)) {
                write.table(data.frame(plot_id = mix\$data\$plot_id, time = mix\$data\$time, residuals = mix\$residuals, fitted = mix\$fitted), file=\''.$stats_out_tempfile_residual.'\', row.names=FALSE, col.names=TRUE, sep=\'\t\');
                write.table(mix\$U\$\`u:id\`, file=\''.$stats_out_tempfile.'\', row.names=TRUE, col.names=TRUE, sep=\'\t\');
                genetic_coeff <- data.frame(id = names(mix\$U\$\`leg0:id\`\$value));';
                for my $leg_num (0..$legendre_order_number) {
                    $cmd .= 'genetic_coeff\$leg_'.$leg_num.' <- mix\$U\$\`leg'.$leg_num.':id\`\$value;';
                }
                $cmd .= 'write.table(genetic_coeff, file=\''.$stats_out_tempfile_genetic.'\', row.names=FALSE, col.names=TRUE, sep=\'\t\');"
                }
                ';
                print STDERR Dumper $cmd;
                my $status = system($cmd);

                # no warnings 'uninitialized';

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
                            if (defined $value && $value ne '') {
                                push @{$sommer_rr_genetic_coeff{$accession_name}}, $value;
                            }
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
                        if (defined $residual && $residual ne '') {
                            $result_residual_data->{$stock_name}->{$seen_times{$time}} = [$residual, $timestamp, $user_name, '', ''];
                            $residual_sum += abs($residual);
                        }
                        if (defined $fitted && $fitted ne '') {
                            $result_fitted_data->{$stock_name}->{$seen_times{$time}} = [$fitted, $timestamp, $user_name, '', ''];
                        }
                    }
                close($fh_residual);

                my $q_time = "SELECT t.cvterm_id FROM cvterm as t JOIN cv ON(t.cv_id=cv.cv_id) WHERE t.name=? and cv.name=?;";
                my $h_time = $schema->storage->dbh()->prepare($q_time);

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

                while ( my ($accession_name, $coeffs) = each %sommer_rr_genetic_coeff) {
                    foreach my $time (@sorted_trait_names) {
                        my $value = 0;
                        my $coeff_counter = 0;
                        foreach my $b (@$coeffs) {
                            my $eval_string = $legendre_coeff_exec[$coeff_counter];
                            # print STDERR Dumper [$eval_string, $b, $time];
                            $value += eval $eval_string;
                            $coeff_counter++;
                        }

                        $result_blup_data_delta->{$accession_name}->{$time} = [$value, $timestamp, $user_name, '', ''];

                        if ($value < $genetic_effect_min) {
                            $genetic_effect_min = $value;
                        }
                        elsif ($value >= $genetic_effect_max) {
                            $genetic_effect_max = $value;
                        }

                        $genetic_effect_sum += abs($value);
                    }
                }

                push @result_effect_sum_iterations, [$iteration_count, $genetic_effect_sum, $env_effect_sum, $residual_sum];

                my $result_blup_data_delta_copy = dclone $result_blup_data_delta;
                my $result_residual_data_copy = dclone $result_residual_data;
                my $result_fitted_data_copy = dclone $result_fitted_data;
                my $phenotype_data_hash_out_copy = dclone $phenotype_data_hash_out;

                $result_blup_data_iterations->{$genetic_effect_sum} = {
                    gen => $result_blup_data_delta_copy,
                    residual => $result_residual_data_copy,
                    fitted => $result_fitted_data_copy,
                    phenotype_data => $phenotype_data_hash_out_copy,
                    phenotype_data_original => $phenotype_data_original_hash_out
                };

                print STDERR "$statistics_select GENETIC EFFECT SUM $genetic_effect_sum\n";

                if ($analytics_select eq 'minimize_genetic_effect' && $genetic_effect_sum > $minimization_genetic_sum_threshold && $iteration_count < $iteration_max) {
                    ($trait_name_encoder_hash, $trait_name_encoder_rev_hash, $phenotype_data_original_hash_out, $phenotype_data_hash_out, $stock_info_hash, $unique_accessions_hash, $seen_days_after_plantings_hash, $seen_times_hash, $data_matrix_array, $obsunit_row_col_hash, $seen_plot_names_hash, $plot_id_map_hash, $trait_composing_info_hash, $permanent_environment_structure_tempfile, $stats_tempfile, $stats_tempfile_2, $parameter_tempfile, $coeff_genetic_tempfile, $coeff_pe_tempfile, $stats_out_tempfile_string, $stats_out_tempfile, $stats_prep2_tempfile, $stats_out_htp_rel_tempfile_input, $stats_out_htp_rel_tempfile, $stats_out_htp_rel_tempfile_out_string, $stats_out_htp_rel_tempfile_out, $stats_out_param_tempfile, $stats_out_tempfile_row, $stats_out_tempfile_col, $stats_out_tempfile_2dspl, $stats_out_tempfile_residual, $stats_out_tempfile_genetic, $stats_out_tempfile_permanent_environment, $sorted_scaled_ln_times_array, $time_max, $time_min, $plot_id_factor_map_reverse_hash, $plot_id_count_map_reverse_hash, $sorted_trait_names_array, $unique_accession_names_array, $unique_plot_names_array, $accession_id_factor_map_hash, $accession_id_factor_map_reverse_hash, $time_count_map_reverse_hash, $rep_time_factors_array, $ind_rep_factors_array, $stock_name_row_col_hash) = _generate_input_file($c, $schema, $trait_id_list, $field_trial_id_list, $statistics_select, $tmp_stats_dir, $use_area_under_curve, $legendre_order_number, $permanent_environment_structure, $phenotype_data_hash, $analytics_select, $result_blup_data_delta, undef, undef, $env_simulation, $genetic_effect_min, $genetic_effect_max, undef, undef);

                    $phenotype_data_hash = $phenotype_data_hash_out;
                }
                else {
                    $minimization_genetic_done = 1;
                }

                print STDERR "ITERATION $iteration_count\n";
                $iteration_count++;
            }

            @sorted_trait_names = sort keys %rr_unique_traits;
        }
        elsif ($statistics_select eq 'blupf90_grm_random_regression_gdd_blups' || $statistics_select eq 'blupf90_grm_random_regression_dap_blups' || $statistics_select eq 'airemlf90_grm_random_regression_gdd_blups' || $statistics_select eq 'airemlf90_grm_random_regression_dap_blups') {

            $analysis_model_language = "F90";

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

            while ( ($analytics_select eq 'minimize_genetic_effect' && !$minimization_genetic_done) || ($analytics_select eq 'minimize_local_env_effect' && !$minimization_env_done) ) {
                $genetic_effect_min = 1000000000;
                $genetic_effect_max = -1000000000;
                $env_effect_min = 1000000000;
                $env_effect_max = -1000000000;
                $genetic_effect_sum = 0;
                $env_effect_sum = 0;
                $residual_sum = 0;
                my $result_blup_pe_data_delta = {};
                my $result_blup_data_delta = {};

                my $cmd_r = 'R -e "
                    pheno <- read.csv(\''.$stats_prep2_tempfile.'\', header=FALSE, sep=\',\');
                    v <- var(pheno);
                    v <- v[1:'.$pheno_var_pos.', 1:'.$pheno_var_pos.'];
                    #v <- matrix(rep(0.1, '.$pheno_var_pos.'*'.$pheno_var_pos.'), nrow = '.$pheno_var_pos.');
                    #diag(v) <- rep(1, '.$pheno_var_pos.');
                    write.table(v, file=\''.$stats_out_param_tempfile.'\', row.names=FALSE, col.names=FALSE, sep=\'\t\');
                "';
                print STDERR Dumper $cmd_r;
                my $status_r = system($cmd_r);

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
                    'RANDOM_TYPE',
                    'user_file_inv',
                    'FILE',
                    $grm_file_basename,
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
                elsif ($permanent_environment_structure eq 'euclidean_rows_and_columns') {
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
                my $status = system($cmd);

                open(my $fh_log, '<', $stats_out_tempfile)
                    or die "Could not open file '$stats_out_tempfile' $!";

                    print STDERR "Opened $stats_out_tempfile\n";
                    while (my $row = <$fh_log>) {
                        print STDERR $row;
                    }
                close($fh_log);

                my $q_time = "SELECT t.cvterm_id FROM cvterm as t JOIN cv ON(t.cv_id=cv.cv_id) WHERE t.name=? and cv.name=?;";
                my $h_time = $schema->storage->dbh()->prepare($q_time);

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

                        if (defined $residual && $residual ne '') {
                            $result_residual_data->{$plot_name}->{$seen_times{$time}} = [$residual, $timestamp, $user_name, '', ''];
                            $residual_sum += abs($residual);
                        }
                        if (defined $pred && $pred ne '') {
                            $result_fitted_data->{$plot_name}->{$seen_times{$time}} = [$pred, $timestamp, $user_name, '', ''];
                        }

                        $pred_res_counter++;
                    }
                close($fh_yhat_res);
                $model_sum_square_residual = $sum_square_res;

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
                            if (defined $value && $value ne '') {
                                push @{$rr_genetic_coefficients{$accession_name}}, $value;
                            }
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
                            if (defined $value && $value ne '') {
                                push @{$rr_temporal_coefficients{$plot_name}}, $value;
                            }
                        }
                        $solution_file_counter++;
                    }
                close($fh_sol);

                # print STDERR Dumper \%rr_genetic_coefficients;
                # print STDERR Dumper \%rr_temporal_coefficients;

                open(my $Fgc, ">", $coeff_genetic_tempfile) || die "Can't open file ".$coeff_genetic_tempfile;

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
                    foreach my $time (@sorted_trait_names) {
                        my $value = 0;
                        my $coeff_counter = 0;
                        foreach my $b (@$coeffs) {
                            my $eval_string = $legendre_coeff_exec[$coeff_counter];
                            # print STDERR Dumper [$eval_string, $b, $time];
                            $value += eval $eval_string;
                            $coeff_counter++;
                        }

                        $result_blup_data_delta->{$accession_name}->{$time} = [$value, $timestamp, $user_name, '', ''];

                        if ($value < $genetic_effect_min) {
                            $genetic_effect_min = $value;
                        }
                        elsif ($value >= $genetic_effect_max) {
                            $genetic_effect_max = $value;
                        }

                        $genetic_effect_sum += abs($value);
                    }
                }

                open(my $Fpc, ">", $coeff_pe_tempfile) || die "Can't open file ".$coeff_pe_tempfile;

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
                    foreach my $time (@sorted_trait_names) {
                        my $value = 0;
                        my $coeff_counter = 0;
                        foreach my $b (@$coeffs) {
                            my $eval_string = $legendre_coeff_exec[$coeff_counter];
                            # print STDERR Dumper [$eval_string, $b, $time];
                            $value += eval $eval_string;
                            $coeff_counter++;
                        }

                        $result_blup_pe_data_delta->{$plot_name}->{$time} = [$value, $timestamp, $user_name, '', ''];

                        if ($value < $env_effect_min) {
                            $env_effect_min = $value;
                        }
                        elsif ($value >= $env_effect_max) {
                            $env_effect_max = $value;
                        }

                        $env_effect_sum += abs($value);
                    }
                }

                push @result_effect_sum_iterations, [$iteration_count, $genetic_effect_sum, $env_effect_sum, $residual_sum];

                my $result_blup_data_delta_copy = dclone $result_blup_data_delta;
                my $result_blup_pe_data_delta_copy = dclone $result_blup_pe_data_delta;
                my $result_residual_data_copy = dclone $result_residual_data;
                my $result_fitted_data_copy = dclone $result_fitted_data;
                my $phenotype_data_hash_out_copy = dclone $phenotype_data_hash_out;

                $result_blup_data_iterations->{$genetic_effect_sum} = {
                    env => $result_blup_pe_data_delta_copy,
                    gen => $result_blup_data_delta_copy,
                    residual => $result_residual_data_copy,
                    fitted => $result_fitted_data_copy,
                    env_effect => $env_effect_sum,
                    phenotype_data => $phenotype_data_hash_out_copy,
                    phenotype_data_original => $phenotype_data_original_hash_out
                };
                $result_blup_pe_data_iterations->{$env_effect_sum} = {
                    env => $result_blup_pe_data_delta_copy,
                    gen => $result_blup_data_delta_copy,
                    residual => $result_residual_data_copy,
                    fitted => $result_fitted_data_copy,
                    gen_effect => $genetic_effect_sum,
                    phenotype_data => $phenotype_data_hash_out_copy,
                    phenotype_data_original => $phenotype_data_original_hash_out
                };

                print STDERR "$statistics_select GENETIC EFFECT SUM $genetic_effect_sum\n";

                if ($analytics_select eq 'minimize_genetic_effect' && $genetic_effect_sum > $minimization_genetic_sum_threshold && $iteration_count < $iteration_max) {
                    ($trait_name_encoder_hash, $trait_name_encoder_rev_hash, $phenotype_data_original_hash_out, $phenotype_data_hash_out, $stock_info_hash, $unique_accessions_hash, $seen_days_after_plantings_hash, $seen_times_hash, $data_matrix_array, $obsunit_row_col_hash, $seen_plot_names_hash, $plot_id_map_hash, $trait_composing_info_hash, $permanent_environment_structure_tempfile, $stats_tempfile, $stats_tempfile_2, $parameter_tempfile, $coeff_genetic_tempfile, $coeff_pe_tempfile, $stats_out_tempfile_string, $stats_out_tempfile, $stats_prep2_tempfile, $stats_out_htp_rel_tempfile_input, $stats_out_htp_rel_tempfile, $stats_out_htp_rel_tempfile_out_string, $stats_out_htp_rel_tempfile_out, $stats_out_param_tempfile, $stats_out_tempfile_row, $stats_out_tempfile_col, $stats_out_tempfile_2dspl, $stats_out_tempfile_residual, $stats_out_tempfile_genetic, $stats_out_tempfile_permanent_environment, $sorted_scaled_ln_times_array, $time_max, $time_min, $plot_id_factor_map_reverse_hash, $plot_id_count_map_reverse_hash, $sorted_trait_names_array, $unique_accession_names_array, $unique_plot_names_array, $accession_id_factor_map_hash, $accession_id_factor_map_reverse_hash, $time_count_map_reverse_hash, $rep_time_factors_array, $ind_rep_factors_array, $stock_name_row_col_hash) = _generate_input_file($c, $schema, $trait_id_list, $field_trial_id_list, $statistics_select, $tmp_stats_dir, $use_area_under_curve, $legendre_order_number, $permanent_environment_structure, $phenotype_data_hash, $analytics_select, $result_blup_data_delta, undef, undef, $env_simulation, $genetic_effect_min, $genetic_effect_max, undef, undef);

                    $phenotype_data_hash = $phenotype_data_hash_out;
                }
                else {
                    $minimization_genetic_done = 1;
                }

                print STDERR "$statistics_select ENV EFFECT SUM $env_effect_sum\n";

                if ($analytics_select eq 'minimize_local_env_effect' && $env_effect_sum > $minimization_env_sum_threshold && $iteration_count < $iteration_max) {
                    ($trait_name_encoder_hash, $trait_name_encoder_rev_hash, $phenotype_data_original_hash_out, $phenotype_data_hash_out, $stock_info_hash, $unique_accessions_hash, $seen_days_after_plantings_hash, $seen_times_hash, $data_matrix_array, $obsunit_row_col_hash, $seen_plot_names_hash, $plot_id_map_hash, $trait_composing_info_hash, $permanent_environment_structure_tempfile, $stats_tempfile, $stats_tempfile_2, $parameter_tempfile, $coeff_genetic_tempfile, $coeff_pe_tempfile, $stats_out_tempfile_string, $stats_out_tempfile, $stats_prep2_tempfile, $stats_out_htp_rel_tempfile_input, $stats_out_htp_rel_tempfile, $stats_out_htp_rel_tempfile_out_string, $stats_out_htp_rel_tempfile_out, $stats_out_param_tempfile, $stats_out_tempfile_row, $stats_out_tempfile_col, $stats_out_tempfile_2dspl, $stats_out_tempfile_residual, $stats_out_tempfile_genetic, $stats_out_tempfile_permanent_environment, $sorted_scaled_ln_times_array, $time_max, $time_min, $plot_id_factor_map_reverse_hash, $plot_id_count_map_reverse_hash, $sorted_trait_names_array, $unique_accession_names_array, $unique_plot_names_array, $accession_id_factor_map_hash, $accession_id_factor_map_reverse_hash, $time_count_map_reverse_hash, $rep_time_factors_array, $ind_rep_factors_array, $stock_name_row_col_hash) = _generate_input_file($c, $schema, $trait_id_list, $field_trial_id_list, $statistics_select, $tmp_stats_dir, $use_area_under_curve, $legendre_order_number, $permanent_environment_structure, $phenotype_data_hash, $analytics_select, undef, undef, $result_blup_pe_data_delta, $env_simulation, undef, undef, $env_effect_min, $env_effect_max);

                    $phenotype_data_hash = $phenotype_data_hash_out;
                }
                else {
                    $minimization_env_done = 1;
                }

                print STDERR "ITERATION $iteration_count\n";
                $iteration_count++;

                # print STDERR Dumper \%fixed_effects;
                # print STDERR Dumper $result_blup_data;
                # print STDERR Dumper $result_blup_pe_data;
                @sorted_trait_names = sort keys %rr_unique_traits;
                @sorted_residual_trait_names = sort keys %rr_residual_unique_traits;
            }
        }
    }
    else {
        $c->stash->{rest} = { error => "Not supported $statistics_select!"};
        return;
    }

    ($genetic_effect_sum, $env_effect_sum, $phenotype_data_original_hash_out, $phenotype_data_hash_out, $result_blup_data, $result_blup_spatial_data, $result_blup_pe_data) = _select_lowest_effects($analytics_select, $statistics_select, $result_blup_data_iterations, $result_blup_spatial_data_iterations, $result_blup_pe_data_iterations);

    # print STDERR Dumper $result_blup_data;
    # print STDERR Dumper $result_blup_spatial_data;
    # print STDERR Dumper $result_blup_pe_data;

    my @sorted_germplasm_names = sort keys %$unique_accessions_hash;
    my @set = ('0' ..'9', 'A' .. 'F');
    my @colors;
    for (1..scalar(@sorted_germplasm_names)) {
        my $str = join '' => map $set[rand @set], 1 .. 6;
        push @colors, '#'.$str;
    }
    my $color_string = join '\',\'', @colors;

    # my $cmd_gen_plot = 'R -e "library(data.table); library(ggplot2);
    # mat <- fread(\''.$stats_tempfile.'\', header=TRUE, sep=\',\');
    # mat\$time <- as.numeric(as.character(mat\$time));
    # options(device=\'png\');
    # par();
    # sp <- ggplot(mat, aes(x = time, y = value)) +
    #     geom_line(aes(color = germplasmName), size = 1) +
    #     scale_fill_manual(values = c(\''.$color_string.'\')) +
    #     theme_minimal();
    # sp <- sp + guides(shape = guide_legend(override.aes = list(size = 0.5)));
    # sp <- sp + guides(color = guide_legend(override.aes = list(size = 0.5)));
    # sp <- sp + theme(legend.title = element_text(size = 3), legend.text = element_text(size = 3));';
    # if (scalar(@sorted_germplasm_names) > 100) {
    #     $cmd_gen_plot .= 'sp <- sp + theme(legend.position = \'none\');';
    # }
    # $cmd_gen_plot .= 'ggsave(\''.$genetic_effects_figure_tempfile.'\', sp, device=\'png\', width=12, height=6, units=\'in\');
    # dev.off();"';

    my ($phenotypes_heatmap_tempfile_fh, $phenotypes_heatmap_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    open(my $F_pheno, ">", $phenotypes_heatmap_tempfile) || die "Can't open file ".$phenotypes_heatmap_tempfile;
        print $F_pheno "trait_type,row,col,value\n";
        foreach my $p (@unique_plot_names) {
            foreach my $t (@sorted_trait_names) {
                my @row = ("phenotype_original_".$trait_name_encoder{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $phenotype_data_original_hash_out->{$p}->{$t});
                my $line = join ',', @row;
                print $F_pheno "$line\n";

                my @row = ("phenotype_post_".$trait_name_encoder{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $phenotype_data_hash_out->{$p}->{$t});
                my $line = join ',', @row;
                print $F_pheno "$line\n";
            }
        }
    close($F_pheno);

    my ($effects_heatmap_tempfile_fh, $effects_heatmap_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    open(my $F_eff, ">", $effects_heatmap_tempfile) || die "Can't open file ".$effects_heatmap_tempfile;
        print $F_eff "trait_type,row,col,value\n";
        foreach my $p (@unique_plot_names) {
            foreach my $t (@sorted_trait_names) {
                my @row = ("effect_original_".$trait_name_encoder{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $result_blup_spatial_data_first->{$p}->{$t}->[0]);
                my $line = join ',', @row;
                print $F_eff "$line\n";

                my @row = ("effect_post_".$trait_name_encoder{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $result_blup_spatial_data->{$p}->{$t}->[0]);
                my $line = join ',', @row;
                print $F_eff "$line\n";
            }
        }
    close($F_eff);

    my $spatial_effects_first_plots;
    my $env_effects_first_figure_tempfile_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/figureXXXX');
    $env_effects_first_figure_tempfile_string .= '.png';
    my $env_effects_first_figure_tempfile = $c->config->{basepath}."/".$env_effects_first_figure_tempfile_string;

    my $cmd_spatialfirst_plot = 'R -e "library(data.table); library(ggplot2); library(dplyr); library(viridis); library(GGally); library(gridExtra);
    mat <- fread(\''.$phenotypes_heatmap_tempfile.'\', header=TRUE, sep=\',\');
    mat_eff <- fread(\''.$effects_heatmap_tempfile.'\', header=TRUE, sep=\',\');
    options(device=\'png\');
    par();
    gg <- ggplot(mat, aes(col, row, fill=value)) +
        geom_tile() +
        scale_fill_viridis(discrete=FALSE) +
        coord_equal() +
        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names).');
    gg_eff <- ggplot(mat_eff, aes(col, row, fill=value)) +
        geom_tile() +
        scale_fill_viridis(discrete=FALSE) +
        coord_equal() +
        facet_wrap(~trait_type, ncol='.scalar(@sorted_trait_names).');
    ggsave(\''.$env_effects_first_figure_tempfile.'\', arrangeGrob(gg, gg_eff, nrow=2), device=\'png\', width=10, height=10, units=\'in\');
    dev.off();"';
    # print STDERR Dumper $cmd;
    my $status_spatialfirst_plot = system($cmd_spatialfirst_plot);
    push @$spatial_effects_first_plots, $env_effects_first_figure_tempfile_string;

    my ($selected_spatial_effects_heatmap_tempfile_fh, $selected_spatial_effects_heatmap_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    open(my $F_spatialsel, ">", $selected_spatial_effects_heatmap_tempfile) || die "Can't open file ".$selected_spatial_effects_heatmap_tempfile;
        print $F_spatialsel "trait,row,col,effect\n";
        foreach my $p (@unique_plot_names) {
            foreach my $t (@sorted_trait_names) {
                my @row = ($trait_name_encoder{$t}, $stock_name_row_col{$p}->{row_number}, $stock_name_row_col{$p}->{col_number}, $result_blup_spatial_data->{$p}->{$t}->[0]);
                my $line = join ',', @row;
                print $F_spatialsel "$line\n";
            }
        }
    close($F_spatialsel);

    my $spatial_effects_minimized_plots;

    open(my $F_min, ">", $minimization_iterations_tempfile) || die "Can't open file ".$minimization_iterations_tempfile;
        print STDERR "Opened $minimization_iterations_tempfile\n";
        print $F_min "iteration,genetic,environment,residual\n";
        foreach (@result_effect_sum_iterations) {
            my $line = join ',', @$_;
            print $F_min "$line\n";
        }
    close($F_min);

    my $cmd_min_plot = 'R -e "library(data.table); library(ggplot2); library(dplyr);
    mat <- fread(\''.$minimization_iterations_tempfile.'\', header=TRUE, sep=\',\');
    ';
    if ($analytics_select eq 'minimize_genetic_effect') {
        $cmd_min_plot .= 'mat <- mat[order(-genetic),];';
    }
    elsif ($analytics_select eq 'minimize_local_env_effect') {
        $cmd_min_plot .= 'mat <- mat[order(-environment),];';
    }
    $cmd_min_plot .= 'mat\$iteration <- seq.int(nrow(mat));
    matmelted <- reshape2::melt(mat, id.var=\'iteration\');
    options(device=\'png\');
    par();
    sp <- ggplot(matmelted, aes(x=iteration, y=value, col=variable)) + geom_line();
    sp <- sp + guides(shape = guide_legend(override.aes = list(size = 0.5)));
    sp <- sp + guides(color = guide_legend(override.aes = list(size = 0.5)));
    sp <- sp + theme(legend.title = element_text(size = 3), legend.text = element_text(size = 3));
    ggsave(\''.$minimization_iterations_figure_tempfile.'\', sp, device=\'png\', width=3, height=2, units=\'in\');
    dev.off();"';
    # print STDERR Dumper $cmd;
    my $status_min_plot = system($cmd_min_plot);

    $c->stash->{rest} = {
        results => \@results,
        result_blup_genetic_data => $result_blup_data,
        result_blup_genetic_data_iterations => $result_blup_data_iterations,
        result_blup_spatial_data => $result_blup_spatial_data,
        result_blup_spatial_data_iterations => $result_blup_spatial_data_iterations,
        result_blup_pe_data => $result_blup_pe_data,
        result_blup_pe_data_iterations => $result_blup_pe_data_iterations,
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
        genetic_effect_sum => $genetic_effect_sum,
        env_effect_sum => $env_effect_sum,
        minimization_iterations_effect_result_file => $minimization_iterations_tempfile,
        minimization_iterations_figure_tempfile => $minimization_iterations_figure_tempfile,
        minimization_iterations_tempfile_string => $minimization_iterations_tempfile_string,
        spatial_effects_first_plots => $spatial_effects_first_plots,
        spatial_effects_minimized_plots => $spatial_effects_minimized_plots,
    };
}

sub _select_lowest_effects {
    my $analytics_select = shift;
    my $statistics_select = shift;
    my $result_blup_data_iterations = shift;
    my $result_blup_spatial_data_iterations = shift;
    my $result_blup_pe_data_iterations = shift;

    my $phenotype_data_original_hash_out_selected;
    my $phenotype_data_hash_out_selected;
    my $result_blup_data_selected;
    my $result_blup_spatial_data_selected;
    my $result_blup_pe_data_selected;

    my $minimum_genetic_effect;
    my $minimum_env_effect;

    if ($analytics_select eq 'minimize_genetic_effect') {
        my @sorted = sort { $a <=> $b } keys %$result_blup_data_iterations;
        $minimum_genetic_effect = $sorted[0];
        my $sel = $result_blup_data_iterations->{$minimum_genetic_effect};
        $result_blup_data_selected = $sel->{gen};
        $phenotype_data_original_hash_out_selected = $sel->{phenotype_data_original};
        $phenotype_data_hash_out_selected = $sel->{phenotype_data};

        if ($statistics_select eq 'sommer_grm_spatial_genetic_blups') {
            $result_blup_spatial_data_selected = $sel->{env};
            $minimum_env_effect = $sel->{env_effect};
        }
        elsif ($statistics_select eq 'sommer_grm_temporal_random_regression_dap_genetic_blups' || $statistics_select eq 'sommer_grm_temporal_random_regression_gdd_genetic_blups' || $statistics_select eq 'blupf90_grm_random_regression_dap_blups' || $statistics_select eq 'blupf90_grm_random_regression_gdd_blups' || $statistics_select eq 'airemlf90_grm_random_regression_dap_blups' || $statistics_select eq 'airemlf90_grm_random_regression_gdd_blups') {
            $result_blup_pe_data_selected = $sel->{env};
            $minimum_env_effect = $sel->{env_effect};
        }
    }
    if ($analytics_select eq 'minimize_local_env_effect') {
        if ($statistics_select eq 'sommer_grm_spatial_genetic_blups') {
            my @sorted = sort { $a <=> $b } keys %$result_blup_spatial_data_iterations;
            $minimum_env_effect = $sorted[0];
            my $sel = $result_blup_spatial_data_iterations->{$minimum_env_effect};
            $phenotype_data_original_hash_out_selected = $sel->{phenotype_data_original};
            $phenotype_data_hash_out_selected = $sel->{phenotype_data};
            $result_blup_data_selected = $sel->{gen};
            $result_blup_spatial_data_selected = $sel->{env};
            $minimum_genetic_effect = $sel->{gen_effect};
        }
        elsif ($statistics_select eq 'sommer_grm_temporal_random_regression_dap_genetic_blups' || $statistics_select eq 'sommer_grm_temporal_random_regression_gdd_genetic_blups' || $statistics_select eq 'blupf90_grm_random_regression_dap_blups' || $statistics_select eq 'blupf90_grm_random_regression_gdd_blups' || $statistics_select eq 'airemlf90_grm_random_regression_dap_blups' || $statistics_select eq 'airemlf90_grm_random_regression_gdd_blups') {
            my @sorted = sort { $a <=> $b } keys %$result_blup_pe_data_iterations;
            $minimum_env_effect = $sorted[0];
            my $sel = $result_blup_pe_data_iterations->{$minimum_env_effect};
            $phenotype_data_original_hash_out_selected = $sel->{phenotype_data_original};
            $phenotype_data_hash_out_selected = $sel->{phenotype_data};
            $result_blup_data_selected = $sel->{gen};
            $result_blup_pe_data_selected = $sel->{env};
            $minimum_genetic_effect = $sel->{gen_effect};
        }
    }
    return ($minimum_genetic_effect, $minimum_env_effect, $phenotype_data_original_hash_out_selected, $phenotype_data_hash_out_selected, $result_blup_data_selected, $result_blup_spatial_data_selected, $result_blup_pe_data_selected);
}

sub _generate_input_file {
    my $c = shift;
    my $schema = shift;
    my $trait_id_list = shift;
    my $field_trial_id_list = shift;
    my $statistics_select = shift;
    my $tmp_stats_dir = shift;
    my $use_area_under_curve = shift;
    my $legendre_order_number = shift;
    my $permanent_environment_structure = shift;
    my $previous_phenotype_data = shift;
    my $analytics_select = shift;
    my $result_blup_data = shift;
    my $result_blup_spatial_data = shift;
    my $result_blup_pe_data = shift;
    my $env_simulation = shift;
    my $genetic_effect_min = shift;
    my $genetic_effect_max = shift;
    my $env_effect_min = shift;
    my $env_effect_max = shift;

    # print STDERR Dumper $result_blup_data;
    # print STDERR Dumper $result_blup_spatial_data;
    # print STDERR Dumper $result_blup_pe_data;

    my ($permanent_environment_structure_tempfile_fh, $permanent_environment_structure_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    my ($stats_tempfile_fh, $stats_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    my ($stats_tempfile_2_fh, $stats_tempfile_2) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    $stats_tempfile_2 .= '.dat';
    my ($stats_prep_tempfile_fh, $stats_prep_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    my ($stats_prep_factor_tempfile_fh, $stats_prep_factor_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    my ($parameter_tempfile_fh, $parameter_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    $parameter_tempfile .= '.f90';
    my ($coeff_genetic_tempfile_fh, $coeff_genetic_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    $coeff_genetic_tempfile .= '_genetic_coefficients.csv';
    my ($coeff_pe_tempfile_fh, $coeff_pe_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    $coeff_pe_tempfile .= '_permanent_environment_coefficients.csv';

    my $dir = $c->tempfiles_subdir('/tmp_drone_statistics');
    my $stats_out_tempfile_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/drone_stats_XXXXX');
    my $stats_out_tempfile = $c->config->{basepath}."/".$stats_out_tempfile_string;

    my ($stats_prep2_tempfile_fh, $stats_prep2_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    my ($stats_out_htp_rel_tempfile_input_fh, $stats_out_htp_rel_tempfile_input) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    my ($stats_out_htp_rel_tempfile_fh, $stats_out_htp_rel_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);

    my $stats_out_htp_rel_tempfile_out_string = $c->tempfile( TEMPLATE => 'tmp_drone_statistics/drone_stats_XXXXX');
    my $stats_out_htp_rel_tempfile_out = $c->config->{basepath}."/".$stats_out_htp_rel_tempfile_out_string;

    my ($stats_out_param_tempfile_fh, $stats_out_param_tempfile) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    my ($stats_out_tempfile_row_fh, $stats_out_tempfile_row) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    my ($stats_out_tempfile_col_fh, $stats_out_tempfile_col) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    my ($stats_out_tempfile_2dspl_fh, $stats_out_tempfile_2dspl) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    my ($stats_out_tempfile_residual_fh, $stats_out_tempfile_residual) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    my ($stats_out_tempfile_genetic_fh, $stats_out_tempfile_genetic) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);
    my ($stats_out_tempfile_permanent_environment_fh, $stats_out_tempfile_permanent_environment) = tempfile("drone_stats_XXXXX", DIR=> $tmp_stats_dir);

    my %trait_name_encoder;
    my %trait_name_encoder_rev;
    my $phenotype_data_original;
    my %phenotype_data;
    my %stock_info;
    my %unique_accessions;
    my %seen_days_after_plantings;
    my %seen_times;
    my @data_matrix;
    my %obsunit_row_col;
    my %stock_row_col;
    my %stock_name_row_col;
    my %seen_rows;
    my %seen_cols;
    my %seen_plots;
    my %seen_plot_names;
    my %plot_id_map;
    my %trait_composing_info;
    my @sorted_scaled_ln_times;
    my $time_min = 100000000;
    my $time_max = 0;
    my %plot_id_factor_map_reverse;
    my %plot_id_count_map_reverse;
    my @sorted_trait_names;
    my @unique_accession_names;
    my @unique_plot_names;
    my %accession_id_factor_map;
    my %accession_id_factor_map_reverse;
    my %time_count_map_reverse;
    my @rep_time_factors;
    my @ind_rep_factors;
    my %seen_trial_ids;
    my %seen_trait_names;
    my %unique_traits_ids;
    my $phenotype_min = 1000000000;
    my $phenotype_max = -1000000000;

    my $csv = Text::CSV->new({ sep_char => "\t" });

    if ($statistics_select eq 'sommer_grm_spatial_genetic_blups' || $statistics_select eq 'sommer_grm_genetic_blups') {

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

        foreach my $obs_unit (@$data){
            my $germplasm_name = $obs_unit->{germplasm_uniquename};
            my $germplasm_stock_id = $obs_unit->{germplasm_stock_id};
            my $replicate_number = $obs_unit->{obsunit_rep};
            my $obsunit_stock_id = $obs_unit->{observationunit_stock_id};
            my $obsunit_stock_uniquename = $obs_unit->{observationunit_uniquename};
            my $row_number = $obs_unit->{obsunit_row_number} || '';
            my $col_number = $obs_unit->{obsunit_col_number} || '';
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
                col_number => $col_number
            };
            $stock_name_row_col{$obsunit_stock_uniquename} = {
                row_number => $row_number,
                col_number => $col_number
            };
            $unique_accessions{$germplasm_name}++;
            $stock_info{"S".$germplasm_stock_id} = {
                uniquename => $germplasm_name
            };
            my $observations = $obs_unit->{observations};
            foreach (@$observations){
                my $value = $_->{value};
                $phenotype_data{$obs_unit->{observationunit_uniquename}}->{$_->{trait_name}} = $value;
                $seen_trait_names{$_->{trait_name}}++;

                if ($value < $phenotype_min) {
                    $phenotype_min = $value;
                }
                elsif ($value >= $phenotype_max) {
                    $phenotype_max = $value;
                }

                if ($_->{associated_image_project_time_json}) {
                    my $related_time_terms_json = decode_json $_->{associated_image_project_time_json};
                    my $time_days_cvterm = $related_time_terms_json->{day};
                    my $time_term_string = $time_days_cvterm;
                    my $time_days = (split '\|', $time_days_cvterm)[0];
                    my $time_value = (split ' ', $time_days)[1];
                    $seen_days_after_plantings{$time_value}++;
                }
            }
        }
        @unique_accession_names = sort keys %unique_accessions;

        my $trait_name_encoded = 1;
        foreach my $trait_name (@sorted_trait_names) {
            if (!exists($trait_name_encoder{$trait_name})) {
                my $trait_name_e = 't'.$trait_name_encoded;
                $trait_name_encoder{$trait_name} = $trait_name_e;
                $trait_name_encoder_rev{$trait_name_e} = $trait_name;
                $trait_name_encoded++;
            }
        }

        if ($previous_phenotype_data) {
            %phenotype_data = %$previous_phenotype_data;
        }
        $phenotype_data_original = dclone \%phenotype_data;

        foreach (@$data) {
            my $germplasm_name = $_->{germplasm_uniquename};
            my $germplasm_stock_id = $_->{germplasm_stock_id};
            my $obsunit_stock_id = $_->{observationunit_stock_id};
            my $obsunit_stock_uniquename = $_->{observationunit_uniquename};
            my $row_number = $_->{obsunit_row_number} || '';
            my $col_number = $_->{obsunit_col_number} || '';
            my @row = ($_->{obsunit_rep}, $_->{obsunit_block}, "S".$germplasm_stock_id, $obsunit_stock_id, $row_number, $col_number, $row_number, $col_number);
            $seen_trial_ids{$_->{trial_id}}++;
            foreach my $t (@sorted_trait_names) {
                if (defined($phenotype_data{$obsunit_stock_uniquename}->{$t})) {
                    my $minimizer = 0;
                    if ($analytics_select eq 'minimize_local_env_effect') {
                        if (defined($result_blup_spatial_data->{$obsunit_stock_uniquename}->{$t})) {
                            $minimizer = $result_blup_spatial_data->{$obsunit_stock_uniquename}->{$t}->[0];
                            $minimizer = $minimizer * ($phenotype_max - $phenotype_min)/($env_effect_max - $env_effect_min);
                        }
                    }
                    elsif ($analytics_select eq 'minimize_genetic_effect') {
                        if (defined($result_blup_data->{$obsunit_stock_uniquename}->{$t})) {
                            $minimizer = $result_blup_data->{$obsunit_stock_uniquename}->{$t}->[0];
                            $minimizer = $minimizer * ($phenotype_max - $phenotype_min)/($genetic_effect_max - $genetic_effect_min);
                        }
                    }
                    my $new_val = $phenotype_data{$obsunit_stock_uniquename}->{$t} + 0 - $minimizer;
                    $phenotype_data{$obsunit_stock_uniquename}->{$t} = $new_val;
                    push @row, $new_val;
                } else {
                    print STDERR $obsunit_stock_uniquename." : $t : $germplasm_name : NA \n";
                    push @row, 'NA';
                }
            }
            push @data_matrix, \@row;
        }

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

        foreach my $obs_unit (@$data){
            my $germplasm_name = $obs_unit->{germplasm_uniquename};
            my $germplasm_stock_id = $obs_unit->{germplasm_stock_id};
            my $replicate_number = $obs_unit->{obsunit_rep};
            my $obsunit_stock_id = $obs_unit->{observationunit_stock_id};
            my $obsunit_stock_uniquename = $obs_unit->{observationunit_uniquename};
            my $row_number = $obs_unit->{obsunit_row_number} || '';
            my $col_number = $obs_unit->{obsunit_col_number} || '';
            $obsunit_row_col{$row_number}->{$col_number} = {
                stock_id => $obsunit_stock_id,
                stock_uniquename => $obsunit_stock_uniquename
            };
            $seen_rows{$row_number}++;
            $seen_cols{$col_number}++;
            $plot_id_map{"P".$obsunit_stock_id} = $obsunit_stock_uniquename;
            $seen_plot_names{$obsunit_stock_uniquename}++;
            $seen_plots{$obsunit_stock_id} = $obsunit_stock_uniquename;
            $stock_row_col{$obsunit_stock_id} = {
                row_number => $row_number,
                col_number => $col_number
            };
            $stock_name_row_col{$obsunit_stock_uniquename} = {
                row_number => $row_number,
                col_number => $col_number
            };
            $unique_accessions{$germplasm_name}++;
            $stock_info{"S".$germplasm_stock_id} = {
                uniquename => $germplasm_name
            };
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

                    my $value = $_->{value};
                    $phenotype_data{$obs_unit->{observationunit_uniquename}}->{$time_value} = $value;
                    $seen_times{$time_value} = $_->{trait_name};
                    $seen_trait_names{$_->{trait_name}} = $time_term_string;

                    if ($value < $phenotype_min) {
                        $phenotype_min = $value;
                    }
                    elsif ($value >= $phenotype_max) {
                        $phenotype_max = $value;
                    }
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

        while ( my ($trait_name, $time_term) = each %seen_trait_names) {
            push @{$trait_composing_info{$trait_name}}, $time_term;
        }

        if ($previous_phenotype_data) {
            %phenotype_data = %$previous_phenotype_data;
        }
        $phenotype_data_original = dclone \%phenotype_data;

        foreach (@$data) {
            my $germplasm_name = $_->{germplasm_uniquename};
            my $germplasm_stock_id = $_->{germplasm_stock_id};
            my $obsunit_stock_id = $_->{observationunit_stock_id};
            my $obsunit_stock_uniquename = $_->{observationunit_uniquename};
            my $row_number = $_->{obsunit_row_number};
            my $col_number = $_->{obsunit_col_number};

            my @row = ($_->{obsunit_rep}, $_->{obsunit_block}, "S".$germplasm_stock_id, "P".$obsunit_stock_id, $row_number, $col_number, $row_number, $col_number);
            my $current_trait_index = 0;
            foreach my $t (@sorted_trait_names) {
                if (defined($phenotype_data{$obsunit_stock_uniquename}->{$t})) {
                    my $minimizer = 0;
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

                        if ($analytics_select eq 'minimize_local_env_effect') {
                            if (defined($result_blup_pe_data->{$obsunit_stock_uniquename}->{$t})) {
                                $minimizer = $result_blup_pe_data->{$obsunit_stock_uniquename}->{$t}->[0];
                                $minimizer = $minimizer * ($phenotype_max - $phenotype_min)/($env_effect_max - $env_effect_min);
                            }
                        }
                        elsif ($analytics_select eq 'minimize_genetic_effect') {
                            if (defined($result_blup_data->{$obsunit_stock_uniquename}->{$t})) {
                                $minimizer = $result_blup_data->{$obsunit_stock_uniquename}->{$t}->[0];
                                $minimizer = $minimizer * ($phenotype_max - $phenotype_min)/($genetic_effect_max - $genetic_effect_min);
                            }
                        }
                        my $new_val = $val - $minimizer;
                        $phenotype_data{$obsunit_stock_uniquename}->{$t} = $new_val;
                        push @row, $new_val;
                    }
                    else {
                        if ($analytics_select eq 'minimize_local_env_effect') {
                            if (defined($result_blup_pe_data->{$obsunit_stock_uniquename}->{$t})) {
                                $minimizer = $result_blup_pe_data->{$obsunit_stock_uniquename}->{$t}->[0];
                                $minimizer = $minimizer * ($phenotype_max - $phenotype_min)/($env_effect_max - $env_effect_min);
                            }
                        }
                        elsif ($analytics_select eq 'minimize_genetic_effect') {
                            if (defined($result_blup_data->{$obsunit_stock_uniquename}->{$t})) {
                                $minimizer = $result_blup_data->{$obsunit_stock_uniquename}->{$t}->[0];
                                $minimizer = $minimizer * ($phenotype_max - $phenotype_min)/($genetic_effect_max - $genetic_effect_min);
                            }
                        }
                        my $new_val = $phenotype_data{$obsunit_stock_uniquename}->{$t} + 0 - $minimizer;
                        $phenotype_data{$obsunit_stock_uniquename}->{$t} = $new_val;
                        push @row, $new_val;
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

        foreach my $obs_unit (@$data){
            my $germplasm_name = $obs_unit->{germplasm_uniquename};
            my $germplasm_stock_id = $obs_unit->{germplasm_stock_id};
            my $replicate_number = $obs_unit->{obsunit_rep};
            my $obsunit_stock_id = $obs_unit->{observationunit_stock_id};
            my $obsunit_stock_uniquename = $obs_unit->{observationunit_uniquename};
            my $row_number = $obs_unit->{obsunit_row_number} || '';
            my $col_number = $obs_unit->{obsunit_col_number} || '';
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
                col_number => $col_number
            };
            $stock_name_row_col{$obsunit_stock_uniquename} = {
                row_number => $row_number,
                col_number => $col_number
            };
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
                    $phenotype_data{$obs_unit->{observationunit_uniquename}}->{$time} = $value;
                    $seen_times{$time} = $_->{trait_name};
                    $seen_trait_names{$_->{trait_name}} = $time_term_string;

                    if ($value < $phenotype_min) {
                        $phenotype_min = $value;
                    }
                    elsif ($value >= $phenotype_max) {
                        $phenotype_max = $value;
                    }
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
        # print STDERR Dumper \@sorted_trait_names;

        while ( my ($trait_name, $time_term) = each %seen_trait_names) {
            push @{$trait_composing_info{$trait_name}}, $time_term;
        }

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
        my $status = system($cmd);

        my %polynomial_map;
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
        my $status_factor = system($cmd_factor);

        my %plot_factor_map;
        my %plot_rep_time_factor_map;
        my %plot_ind_rep_factor_map;
        my %seen_rep_times;
        my %seen_ind_reps;
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

        if ($previous_phenotype_data) {
            %phenotype_data = %$previous_phenotype_data;
        }
        $phenotype_data_original = dclone \%phenotype_data;

        my @data_matrix_phenotypes;
        my @stocks_ordered;
        foreach (@$data) {
            my $germplasm_name = $_->{germplasm_uniquename};
            my $germplasm_stock_id = $_->{germplasm_stock_id};
            my $obsunit_stock_id = $_->{observationunit_stock_id};
            my $obsunit_stock_uniquename = $_->{observationunit_uniquename};
            my $replicate_number = $_->{obsunit_rep};

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
                    my $minimizer = 0;
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

                        if ($analytics_select eq 'minimize_local_env_effect') {
                            if (defined($result_blup_pe_data->{$obsunit_stock_uniquename}->{$t})) {
                                $minimizer = $result_blup_pe_data->{$obsunit_stock_uniquename}->{$t}->[0];
                                $minimizer = $minimizer * ($phenotype_max - $phenotype_min)/($env_effect_max - $env_effect_min);
                            }
                        }
                        elsif ($analytics_select eq 'minimize_genetic_effect') {
                            if (defined($result_blup_data->{$obsunit_stock_uniquename}->{$t})) {
                                $minimizer = $result_blup_data->{$obsunit_stock_uniquename}->{$t}->[0];
                                $minimizer = $minimizer * ($phenotype_max - $phenotype_min)/($genetic_effect_max - $genetic_effect_min);
                            }
                        }
                        my $new_val = $val - $minimizer;
                        $phenotype_data{$obsunit_stock_uniquename}->{$t} = $new_val;
                        push @row, $new_val;
                        push @data_matrix_phenotypes_row, $new_val;
                    }
                    else {
                        if ($analytics_select eq 'minimize_local_env_effect') {
                            if (defined($result_blup_pe_data->{$obsunit_stock_uniquename}->{$t})) {
                                $minimizer = $result_blup_pe_data->{$obsunit_stock_uniquename}->{$t}->[0];
                                $minimizer = $minimizer * ($phenotype_max - $phenotype_min)/($env_effect_max - $env_effect_min);
                            }
                        }
                        elsif ($analytics_select eq 'minimize_genetic_effect') {
                            if (defined($result_blup_data->{$obsunit_stock_uniquename}->{$t})) {
                                $minimizer = $result_blup_data->{$obsunit_stock_uniquename}->{$t}->[0];
                                $minimizer = $minimizer * ($phenotype_max - $phenotype_min)/($genetic_effect_max - $genetic_effect_min);
                            }
                        }
                        my $new_val = $phenotype_data{$obsunit_stock_uniquename}->{$t} + 0 - $minimizer;
                        $phenotype_data{$obsunit_stock_uniquename}->{$t} = $new_val;
                        push @row, $new_val;
                        push @data_matrix_phenotypes_row, $new_val;
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
                        if (defined $dist and length $dist) {
                            $euclidean_distance_hash{$s_factor}->{$r_factor} = $dist;
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
                        $data .= "$r\t$s\t$val\n";
                    }
                }
            }

            open(my $F3, ">", $permanent_environment_structure_tempfile) || die "Can't open file ".$permanent_environment_structure_tempfile;
                print $F3 $data;
            close($F3);
        }
    }

    foreach (@sorted_trait_names) {
        if (looks_like_number($_)) {
            if ($_ < $time_min) {
                $time_min = $_;
            }
            if ($_ >= $time_max) {
                $time_max = $_;
            }
        }
    }
    # print STDERR Dumper [$time_min, $time_max];

    return (\%trait_name_encoder, \%trait_name_encoder_rev, $phenotype_data_original, \%phenotype_data, \%stock_info, \%unique_accessions, \%seen_days_after_plantings, \%seen_times, \@data_matrix, \%obsunit_row_col, \%seen_plot_names, \%plot_id_map, \%trait_composing_info, $permanent_environment_structure_tempfile, $stats_tempfile, $stats_tempfile_2, $parameter_tempfile, $coeff_genetic_tempfile, $coeff_pe_tempfile, $stats_out_tempfile_string, $stats_out_tempfile, $stats_prep2_tempfile, $stats_out_htp_rel_tempfile_input, $stats_out_htp_rel_tempfile, $stats_out_htp_rel_tempfile_out_string, $stats_out_htp_rel_tempfile_out, $stats_out_param_tempfile, $stats_out_tempfile_row, $stats_out_tempfile_col, $stats_out_tempfile_2dspl, $stats_out_tempfile_residual, $stats_out_tempfile_genetic, $stats_out_tempfile_permanent_environment, \@sorted_scaled_ln_times, $time_max, $time_min, \%plot_id_factor_map_reverse, \%plot_id_count_map_reverse, \@sorted_trait_names, \@unique_accession_names, \@unique_plot_names, \%accession_id_factor_map, \%accession_id_factor_map_reverse, \%time_count_map_reverse, \@rep_time_factors, \@ind_rep_factors, \%stock_name_row_col);
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
