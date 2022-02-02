
package SGN::Controller::Analytics;

use Moose;
use URI::FromHash 'uri';
use Data::Dumper;
use JSON::XS;
use Statistics::Descriptive::Full;
use Time::Piece;
use Scalar::Util qw(looks_like_number);

BEGIN { extends 'Catalyst::Controller' };

sub view_analytics_protocols :Path('/analytics_protocols') Args(0) {
    my $self = shift;
    my $c = shift;

    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $user_id;
    if ($c->user()) {
        $user_id = $c->user->get_object()->get_sp_person_id();
    }
    if (!$user_id) {
        $c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
    }

    $c->stash->{template} = '/analytics_protocols/index.mas';
}

sub analytics_protocol_detail :Path('/analytics_protocols') Args(1) {
    my $self = shift;
    my $c = shift;
    my $analytics_protocol_id = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $user = $c->user();

    my $user_id;
    if ($c->user()) {
        $user_id = $c->user->get_object()->get_sp_person_id();
    }
    if (!$user_id) {
        $c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
        $c->detach();
    }

    print STDERR "Viewing analytics protocol with id $analytics_protocol_id\n";

    my $protocolprop_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'analytics_protocol_properties', 'protocol_property')->cvterm_id();
    my $protocolprop_results_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'analytics_protocol_result_summary', 'protocol_property')->cvterm_id();

    my $q = "SELECT nd_protocol.nd_protocol_id, nd_protocol.name, nd_protocol.type_id, nd_protocol.description, nd_protocol.create_date, properties.value
        FROM nd_protocol
        JOIN nd_protocolprop AS properties ON(properties.nd_protocol_id=nd_protocol.nd_protocol_id AND properties.type_id=$protocolprop_type_cvterm_id)
        WHERE nd_protocol.nd_protocol_id = ?;";
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute($analytics_protocol_id);
    my ($nd_protocol_id, $name, $type_id, $description, $create_date, $props_json) = $h->fetchrow_array();

    if (! $name) {
        $c->stash->{template} = '/generic_message.mas';
        $c->stash->{message} = 'The requested analytics protocol ID does not exist in the database.';
        return;
    }

    my @legendre_coeff_exec = (
        '1 * $b',
        '$time * $b',
        '(1/2*(3*$time**2 - 1)*$b)',
        '1/2*(5*$time**3 - 3*$time)*$b',
        '1/8*(35*$time**4 - 30*$time**2 + 3)*$b',
        '1/16*(63*$time**5 - 70*$time**2 + 15*$time)*$b',
        '1/16*(231*$time**6 - 315*$time**4 + 105*$time**2 - 5)*$b'
    );

    my $protocol_properties = decode_json $props_json;
    my $observation_variable_id_list = $protocol_properties->{observation_variable_id_list};
    my $observation_variable_number = scalar(@$observation_variable_id_list);
    my $legendre_poly_number = $protocol_properties->{legendre_order_number} || 3;
    my $analytics_select = $protocol_properties->{analytics_select};
    my $compute_relationship_matrix_from_htp_phenotypes = $protocol_properties->{relationship_matrix_type};
    my $compute_relationship_matrix_from_htp_phenotypes_type = $protocol_properties->{htp_pheno_rel_matrix_type};
    my $compute_relationship_matrix_from_htp_phenotypes_time_points = $protocol_properties->{htp_pheno_rel_matrix_time_points};
    my $compute_relationship_matrix_from_htp_phenotypes_blues_inversion = $protocol_properties->{htp_pheno_rel_matrix_blues_inversion};
    my $compute_from_parents = $protocol_properties->{genotype_compute_from_parents};
    my $include_pedgiree_info_if_compute_from_parents = $protocol_properties->{include_pedgiree_info_if_compute_from_parents};
    my $use_parental_grms_if_compute_from_parents = $protocol_properties->{use_parental_grms_if_compute_from_parents};
    my $use_area_under_curve = $protocol_properties->{use_area_under_curve};
    my $genotyping_protocol_id = $protocol_properties->{genotyping_protocol_id};
    my $tolparinv = $protocol_properties->{tolparinv};
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
    my $tolparinv_10 = $tolparinv*10;

    my $q2 = "SELECT value
        FROM nd_protocolprop
        WHERE type_id=$protocolprop_results_type_cvterm_id AND nd_protocol_id = ?;";
    my $h2 = $schema->storage->dbh()->prepare($q2);
    $h2->execute($analytics_protocol_id);
    my ($result_props_json) = $h2->fetchrow_array();

    my %available_types = (
        SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_imagery_analytics_env_simulation_protocol', 'protocol_type')->cvterm_id() => 'Drone Imagery Environment Simulation'
    );

    my $result_props_json_array = $result_props_json ? decode_json $result_props_json : [];
    # print STDERR Dumper $result_props_json_array;

    my %trait_name_map;
    my $min_time_htp = 1000000000000000;
    my $max_time_htp = -1000000000000000;
    foreach my $a (@$result_props_json_array) {
        my $trait_name_encoder = $a->{trait_name_map};
        while (my ($k,$v) = each %$trait_name_encoder) {
            my $time_val;
            if (looks_like_number($k)) {
                #'181' => 't3',
                $time_val = $k;
            }
            else {
                #'Mean Pixel Value|Merged 3 Bands NRN|NDVI Vegetative Index Image|day 181|COMP:0000618' => 't3',
                my @t_comps = split '\|', $k;
                my $time_term = $t_comps[3];
                my ($day, $time) = split ' ', $time_term;
                $time_val = $time;
            }
            $trait_name_map{$v} = $time_val;

            if ($time_val < $min_time_htp) {
                $min_time_htp = $time_val;
            }
            if ($time_val > $max_time_htp) {
                $max_time_htp = $time_val;
            }
        }
    }
    print STDERR Dumper [$min_time_htp, $max_time_htp];

    my @env_corr_results_array = (["id", "Time", "Models", "Accuracy", "Simulation", "SimulationVariance", "FixedEffect", "Parameters"]);
    my $result_props_json_array_total_counter = 1;
    my $result_props_json_array_counter = 1;
    foreach my $a (@$result_props_json_array) {
        my $analytics_result_type = $a->{statistics_select_original};
        my $trait_name_encoder = $a->{trait_name_map};
        my @potential_times;
        #Sommer
        foreach (keys %$trait_name_encoder) {
            push @potential_times, "t$_";
        }
        #ASREML-R
        foreach (values %$trait_name_encoder) {
            push @potential_times, $_;
        }

        my %avg_varcomps = %{$a->{avg_varcomps}};
        my @avg_varcomps_display = @{$a->{avg_varcomps_display}};

        while (my($t, $type_obj) = each %avg_varcomps) {
            while (my($type, $level_obj) = each %$type_obj) {
                foreach my $time (@potential_times) {
                    #Sommer varcomps
                    if (exists($avg_varcomps{$t}->{$type}->{"u:id.$time-$time"}->{vals}) && exists($avg_varcomps{$t}->{$type}->{"u:units.$time-$time"}->{vals})) {
                        my $g_values = $avg_varcomps{$t}->{$type}->{"u:id.$time-$time"}->{vals};
                        my $r_values = $avg_varcomps{$t}->{$type}->{"u:units.$time-$time"}->{vals};
                        my $g_counter = 0;
                        my @h_values_type;
                        foreach my $g_i (@$g_values) {
                            my $r_i = $r_values->[$g_counter];
                            if ($g_i && $r_i) {
                                my $h_i = $g_i + $r_i == 0 ? 0 : $g_i/($g_i + $r_i);
                                push @h_values_type, $h_i;
                                $g_counter++;
                            }
                        }

                        my $stat = Statistics::Descriptive::Full->new();
                        $stat->add_data(@h_values_type);
                        my $std = $stat->standard_deviation() || 0;
                        my $mean = $stat->mean() || 0;
                        push @avg_varcomps_display, {
                            type => $t,
                            type_scenario => $type,
                            level => "h2-$time",
                            vals => \@h_values_type,
                            std => $std,
                            mean => $mean
                        };
                    }
                    #ASREML-R multivariate + univariate
                    elsif (exists($avg_varcomps{$t}->{$type}->{"trait:vm(id_factor, geno_mat_3col)!trait_$time:$time"}->{vals}) && (exists($avg_varcomps{$t}->{$type}->{"units:trait!trait_$time:$time"}->{vals}) || exists($avg_varcomps{$t}->{$type}->{"trait:units!units!trait_$time:$time"}->{vals}) ) ) {
                        my $g_values = $avg_varcomps{$t}->{$type}->{"trait:vm(id_factor, geno_mat_3col)!trait_$time:$time"}->{vals};
                        my $r_values = $avg_varcomps{$t}->{$type}->{"units:trait!trait_$time:$time"}->{vals} || $avg_varcomps{$t}->{$type}->{"trait:units!units!trait_$time:$time"}->{vals};
                        my $g_counter = 0;
                        my @h_values_type;
                        foreach my $g_i (@$g_values) {
                            my $r_i = $r_values->[$g_counter];
                            if ($g_i && $r_i) {
                                my $h_i = $g_i + $r_i == 0 ? 0 : $g_i/($g_i + $r_i);
                                push @h_values_type, $h_i;
                                $g_counter++;
                            }
                        }

                        my $stat = Statistics::Descriptive::Full->new();
                        $stat->add_data(@h_values_type);
                        my $std = $stat->standard_deviation() || 0;
                        my $mean = $stat->mean() || 0;
                        push @avg_varcomps_display, {
                            type => $t,
                            type_scenario => $type,
                            level => "h2-$time",
                            vals => \@h_values_type,
                            std => $std,
                            mean => $mean
                        };
                    }
                }

            }
        }

        $a->{avg_varcomps_display} = \@avg_varcomps_display;

        my $env_correlation_results = $a->{env_correlation_results};
        foreach my $env_type (sort keys %$env_correlation_results) {
            my $values = $env_correlation_results->{$env_type}->{values};
            my $mean = $env_correlation_results->{$env_type}->{mean};
            my $std = $env_correlation_results->{$env_type}->{std};

            my $parameter = '';
            my $sim_var = '';
            if (index($env_type, '0.1') != -1) {
                $parameter = "Simulation Variance = 0.1";
                $sim_var = 0.1;
            }
            elsif (index($env_type, '0.2') != -1) {
                $parameter = "Simulation Variance = 0.2";
                $sim_var = 0.2;
            }
            elsif (index($env_type, '0.3') != -1) {
                $parameter = "Simulation Variance = 0.3";
                $sim_var = 0.3;
            }

            my $time_change = 'Constant';
            if (index($env_type, 'changing_gradual') != -1) {
                if (index($env_type, '0.75') != -1) {
                    $time_change = "Correlated 0.75";
                }
                elsif (index($env_type, '0.9') != -1) {
                    $time_change = "Correlated 0.9";
                }
            }

            my $sim_name = '';
            if (index($env_type, 'linear') != -1) {
                $sim_name = "Linear";
            }
            elsif (index($env_type, '1DN') != -1) {
                $sim_name = "1D-N";
            }
            elsif (index($env_type, '2DN') != -1) {
                $sim_name = "2D-N";
            }
            elsif (index($env_type, 'ar1xar1') != -1) {
                $sim_name = "AR1xAR1";
            }
            elsif (index($env_type, 'random') != -1) {
                $sim_name = "Random";
            }
            elsif (index($env_type, 'realdata') != -1) {
                $sim_name = "Trait";
            }

            my $model_name = '';
            if (index($env_type, 'airemlf90_') != -1) {
                if (index($env_type, 'identity') != -1) {
                    $model_name = "RR_IDPE";
                }
                elsif (index($env_type, 'euclidean_rows_and_columns') != -1) {
                    $model_name = "RR_EucPE";
                }
                elsif (index($env_type, 'phenotype_2dspline_effect') != -1) {
                    $model_name = "RR_2DsplTraitPE";
                }
                elsif (index($env_type, 'phenotype_ar1xar1_effect') != -1) {
                    $model_name = "RR_AR1xAR1TraitPE";
                }
                elsif (index($env_type, 'phenotype_correlation') != -1) {
                    $model_name = "RR_CorrTraitPE";
                }
            }
            elsif ($analytics_result_type eq 'sommer_grm_spatial_pure_2dspl_genetic_blups') {
                $model_name = '2Dspl_Multi';
            }
            elsif ($analytics_result_type eq 'sommer_grm_univariate_spatial_pure_2dspl_genetic_blups') {
                $model_name = '2Dspl_Uni';
            }
            elsif ($analytics_result_type eq 'asreml_grm_multivariate_spatial_genetic_blups') {
                $model_name = 'AR1_Multi';
            }
            elsif ($analytics_result_type eq 'asreml_grm_univariate_pure_spatial_genetic_blups') {
                $model_name = 'AR1_Uni';
            }
            $model_name .= "_$result_props_json_array_counter";

            my $fixed_effect = 'Replicate';

            foreach my $v (@$values) {
                push @env_corr_results_array, [$result_props_json_array_total_counter, $time_change, $model_name, $v, $sim_name, $sim_var, $fixed_effect, $parameter];
                $result_props_json_array_total_counter++
            }
        }

        $result_props_json_array_counter++;
    }

    my $show_plots = 0;
    my @analytics_protocol_charts;
    if ($show_plots) {
        if (scalar(@$result_props_json_array) > 0) {
            my $dir = $c->tempfiles_subdir('/analytics_protocol_figure');
            my $analytics_protocol_tempfile_string = $c->tempfile( TEMPLATE => 'analytics_protocol_figure/figureXXXX');
            $analytics_protocol_tempfile_string .= '.png';
            my $analytics_protocol_figure_tempfile = $c->config->{basepath}."/".$analytics_protocol_tempfile_string;
            my $analytics_protocol_data_tempfile = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'analytics_protocol_figure/figureXXXX').".csv";

            open(my $F, ">", $analytics_protocol_data_tempfile) || die "Can't open file ".$analytics_protocol_data_tempfile;
                foreach (@env_corr_results_array) {
                    my $string = join ',', @$_;
                    print $F "$string\n";
                }
            close($F);

            my $r_cmd = 'R -e "library(ggplot2); library(data.table);
            data <- data.frame(fread(\''.$analytics_protocol_data_tempfile.'\', header=TRUE, sep=\',\'));
            data\$Models <- factor(data\$Models, levels = c(\'RR_IDPE\',\'RR_EucPE\',\'RR_2DsplTraitPE\',\'RR_CorrTraitPE\',\'AR1_Uni\',\'AR1_Multi\',\'2Dspl_Uni\',\'2Dspl_Multi\'));
            data\$Time <- factor(data\$Time, levels = c(\'Constant\', \'Correlated 0.9\', \'Correlated 0.75\'));
            data\$Simulation <- factor(data\$Simulation, levels = c(\'Linear\', \'1D-N\', \'2D-N\', \'AR1xAR1\', \'Trait\', \'Random\'));
            data\$Parameters <- factor(data\$Parameters, levels = c(\'Simulation Variance = 0.2\', \'Simulation Variance = 0.1\', \'Simulation Variance = 0.3\'));
            p <- ggplot(data, aes(x=Models, y=Accuracy, fill=Time)) + geom_boxplot(position=position_dodge(1), outlier.shape = NA) +theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust=1));
            p <- p + coord_cartesian(ylim=c(0,1));
            p <- p + facet_grid(Simulation~Parameters, scales=\'free\', space=\'free_x\');
            p <- p + ggtitle(\'Environment Simulation Prediction Accuracy\');
            ggsave(\''.$analytics_protocol_figure_tempfile.'\', p, device=\'png\', width=10, height=12, limitsize = FALSE, units=\'in\');
            "';
            print STDERR Dumper $r_cmd;
            my $status = system($r_cmd);

            push @analytics_protocol_charts, $analytics_protocol_tempfile_string;
        }

        my $analytics_experiment_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'analytics_protocol_experiment', 'experiment_type')->cvterm_id();

        my $csv = Text::CSV->new({ sep_char => "," });
        my $dir = $c->tempfiles_subdir('/analytics_protocol_figure');

        my @result_blups_all;
        my $q3 = "SELECT nd_protocol.nd_protocol_id, nd_protocol.name, nd_protocol.description, basename, dirname, md.file_id, md.filetype, nd_protocol.type_id, nd_experiment.type_id
            FROM metadata.md_files AS md
            JOIN metadata.md_metadata AS meta ON (md.metadata_id=meta.metadata_id)
            JOIN phenome.nd_experiment_md_files using(file_id)
            JOIN nd_experiment using(nd_experiment_id)
            JOIN nd_experiment_protocol using(nd_experiment_id)
            JOIN nd_protocol using(nd_protocol_id)
            WHERE nd_protocol.nd_protocol_id=$analytics_protocol_id AND nd_experiment.type_id=$analytics_experiment_type_cvterm_id
            ORDER BY md.file_id ASC;";
        print STDERR $q3."\n";
        my $h3 = $schema->storage->dbh()->prepare($q3);
        $h3->execute();
        while (my ($model_id, $model_name, $model_description, $basename, $filename, $file_id, $filetype, $model_type_id, $experiment_type_id, $property_type_id, $property_value) = $h3->fetchrow_array()) {
            my $result_type;
            if (index($filetype, 'originalgenoeff') != -1 && index($filetype, 'nicksmixedmodelsanalytics_v1') != -1 && index($filetype, 'datafile') != -1) {
                $result_type = 'originalgenoeff';
            }
            elsif (index($filetype, 'fullcorr') != -1 && index($filetype, 'nicksmixedmodelsanalytics_v1') != -1 && index($filetype, 'datafile') != -1) {
                $result_type = 'fullcorr';
            }
            else {
                next;
            }

            my $parameter = '';
            my $sim_var = '';
            if (index($filetype, '0.1') != -1) {
                $parameter = "Simulation Variance = 0.1";
                $sim_var = 0.1;
            }
            elsif (index($filetype, '0.2') != -1) {
                $parameter = "Simulation Variance = 0.2";
                $sim_var = 0.2;
            }
            elsif (index($filetype, '0.3') != -1) {
                $parameter = "Simulation Variance = 0.3";
                $sim_var = 0.3;
            }

            my $time_change = 'Constant';
            if (index($filetype, 'changing_gradual') != -1) {
                if (index($filetype, '0.75') != -1) {
                    $time_change = "Correlated 0.75";
                }
                elsif (index($filetype, '0.9') != -1) {
                    $time_change = "Correlated 0.9";
                }
            }

            my $model_name = '';
            my $is_random_regression;
            if (index($filetype, 'airemlf90_grm_random_regression') != -1) {
                $is_random_regression = 1;
                if (index($filetype, 'identity') != -1) {
                    $model_name = "RR_IDPE";
                }
                elsif (index($filetype, 'euclidean_rows_and_columns') != -1) {
                    $model_name = "RR_EucPE";
                }
                elsif (index($filetype, 'phenotype_2dspline_effect') != -1) {
                    $model_name = "RR_2DsplTraitPE";
                }
                elsif (index($filetype, 'phenotype_ar1xar1_effect') != -1) {
                    $model_name = "RR_AR1xAR1TraitPE";
                }
                elsif (index($filetype, 'phenotype_correlation') != -1) {
                    $model_name = "RR_CorrTraitPE";
                }
            }
            elsif (index($filetype, 'asreml_grm_univariate_pure') != -1) {
                $model_name = 'AR1_Uni';
            }
            elsif (index($filetype, 'sommer_grm_spatial_pure') != -1) {
                $model_name = '2Dspl_Multi';
            }
            elsif (index($filetype, 'sommer_grm_univariate_spatial_pure') != -1) {
                $model_name = '2Dspl_Uni';
            }
            elsif (index($filetype, 'asreml_grm_multivariate') != -1) {
                $model_name = 'AR1_Multi';
            }
            else {
                $c->stash->{rest} = { error => "The model was not recognized for $filetype!"};
                return;
            }

            my %germplasm_result_blups;
            my %germplasm_result_time_blups;
            my %plot_result_blups;
            my %plot_result_time_blups;
            my %seen_times_g;
            my %seen_times_p;
            my $file_destination = File::Spec->catfile($filename, $basename);
            open(my $fh, '<', $file_destination) or die "Could not open file '$file_destination' $!";
                print STDERR "Opened $file_destination\n";

                my $header = <$fh>;
                my @header_columns;
                if ($csv->parse($header)) {
                    @header_columns = $csv->fields();
                }

                while (my $row = <$fh>) {
                    my @columns;
                    if ($csv->parse($row)) {
                        @columns = $csv->fields();
                    }

                    if ($result_type eq 'originalgenoeff') {
                        my $germplasm_name = $columns[0];
                        my $time = $columns[1];
                        my $value = $columns[2];
                        push @{$germplasm_result_blups{$germplasm_name}}, $value;
                        $germplasm_result_time_blups{$germplasm_name}->{$time} = $value;
                        $seen_times_g{$time}++;
                    }
                    elsif ($result_type eq 'fullcorr') {
                        my $plot_name = $columns[0];
                        my $plot_id = $columns[1];

                        my $total_num_t;
                        #if (!$is_random_regression) {
                            $total_num_t = $observation_variable_number;
                        # }
                        # else {
                        #     $total_num_t = $legendre_poly_number;
                        # }

                        # if (!$is_random_regression) {
                            for my $iter (0..$total_num_t-1) {
                                my $step = 10+($iter*22);

                                my $col_name = $header_columns[$step];
                                my ($eff, $mod, $time) = split '_', $col_name;
                                my $time_val = $trait_name_map{$time};
                                my $value = $columns[$step];
                                push @{$plot_result_blups{$plot_name}}, $value;
                                $plot_result_time_blups{$plot_name}->{$time_val} = $value;
                                $seen_times_p{$time_val}++;
                            }
                        # }
                        # else {
                        #     my @coeffs;
                        #     for my $iter (0..$total_num_t-1) {
                        #         my $step = 10+($iter*22);
                        #
                        #         my $col_name = $header_columns[$step];
                        #         my ($eff, $mod, $time) = split '_', $col_name;
                        #         my $time_val = $trait_name_map{$time};
                        #         my $value = $columns[$step];
                        #         push @coeffs, $value;
                        #     }
                        #     print STDERR Dumper \@coeffs;
                        #     foreach my $t_i (0..20) {
                        #         my $time = $t_i*5/100;
                        #         my $time_rescaled = sprintf("%.2f", $time*($max_time_htp - $min_time_htp) + $min_time_htp);
                        #
                        #         my $value = 0;
                        #         my $coeff_counter = 0;
                        #         foreach my $b (@coeffs) {
                        #             my $eval_string = $legendre_coeff_exec[$coeff_counter];
                        #             $value += eval $eval_string;
                        #             # print STDERR Dumper [$eval_string, $b, $time, $value];
                        #             $coeff_counter++;
                        #         }
                        #         push @{$plot_result_blups{$plot_name}}, $value;
                        #         $plot_result_time_blups{$plot_name}->{$time_rescaled} = $value;
                        #         $seen_times_p{$time_rescaled}++;
                        #     }
                        # }
                    }
                }
            close($fh);
            # print STDERR Dumper \%plot_result_time_blups;
            # print STDERR Dumper \%germplasm_result_time_blups;

            my @sorted_seen_times_g = sort { $a <=> $b } keys %seen_times_g;
            my @sorted_seen_times_p = sort { $a <=> $b } keys %seen_times_p;
            my @seen_germplasm = sort keys %germplasm_result_blups;
            my @seen_plots = sort keys %plot_result_blups;

            my $plot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id();
            my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
            my $plot_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot_of', 'stock_relationship')->cvterm_id();
            my $row_number_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'row_number', 'stock_property')->cvterm_id();
            my $col_number_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'col_number', 'stock_property')->cvterm_id();

            my %plot_germplasm_map;
            my %stock_name_row_col;
            my $min_col = 100000000000000;
            my $max_col = -100000000000000;
            my $min_row = 100000000000000;
            my $max_row = -100000000000000;
            my $seen_plots_string = join "','", @seen_plots;
            my $plot_germplasm_q = "SELECT plot.uniquename, germplasm.uniquename, row_number.value, col_number.value
                FROM stock AS plot
                JOIN stockprop AS row_number ON(row_number.stock_id=plot.stock_id AND row_number.type_id=$row_number_cvterm_id)
                JOIN stockprop AS col_number ON(col_number.stock_id=plot.stock_id AND col_number.type_id=$col_number_cvterm_id)
                JOIN stock_relationship ON(plot.stock_id=stock_relationship.subject_id AND stock_relationship.type_id=$plot_of_cvterm_id)
                JOIN stock AS germplasm ON(germplasm.stock_id=stock_relationship.object_id)
                WHERE plot.type_id=$plot_cvterm_id AND germplasm.type_id=$accession_cvterm_id AND plot.uniquename IN ('$seen_plots_string');
            ";
            my $plot_germplasm_h = $schema->storage->dbh()->prepare($plot_germplasm_q);
            $plot_germplasm_h->execute();
            while (my ($plot_name, $germplasm_name, $row_number, $col_number) = $plot_germplasm_h->fetchrow_array()) {
                $plot_germplasm_map{$plot_name} = $germplasm_name;
                $stock_name_row_col{$plot_name} = {
                    row_number => $row_number,
                    col_number => $col_number
                };
            }

            my $analytics_protocol_data_tempfile10 = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'analytics_protocol_figure/figureXXXX').".csv";
            my $analytics_protocol_data_tempfile11 = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'analytics_protocol_figure/figureXXXX').".csv";
            my $analytics_protocol_data_tempfile12 = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'analytics_protocol_figure/figureXXXX').".csv";
            my $analytics_protocol_data_tempfile13 = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'analytics_protocol_figure/figureXXXX').".csv";
            my $analytics_protocol_data_tempfile14 = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'analytics_protocol_figure/figureXXXX').".csv";
            my $analytics_protocol_data_tempfile15 = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'analytics_protocol_figure/figureXXXX').".csv";
            my $analytics_protocol_data_tempfile16 = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'analytics_protocol_figure/figureXXXX').".csv";
            my $analytics_protocol_data_tempfile17 = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'analytics_protocol_figure/figureXXXX').".csv";
            my $analytics_protocol_data_tempfile18 = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'analytics_protocol_figure/figureXXXX').".csv";
            my $analytics_protocol_data_tempfile19 = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'analytics_protocol_figure/figureXXXX').".csv";
            my $analytics_protocol_data_tempfile20 = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'analytics_protocol_figure/figureXXXX').".csv";
            my $analytics_protocol_data_tempfile21= $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'analytics_protocol_figure/figureXXXX').".csv";
            my $analytics_protocol_data_tempfile22= $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'analytics_protocol_figure/figureXXXX').".csv";

            my $analytics_protocol_tempfile_string_1 = $c->tempfile( TEMPLATE => 'analytics_protocol_figure/figureXXXX');
            $analytics_protocol_tempfile_string_1 .= '.png';
            my $analytics_protocol_figure_tempfile_1 = $c->config->{basepath}."/".$analytics_protocol_tempfile_string_1;

            my $analytics_protocol_tempfile_string_2 = $c->tempfile( TEMPLATE => 'analytics_protocol_figure/figureXXXX');
            $analytics_protocol_tempfile_string_2 .= '.png';
            my $analytics_protocol_figure_tempfile_2 = $c->config->{basepath}."/".$analytics_protocol_tempfile_string_2;

            my $analytics_protocol_tempfile_string_3 = $c->tempfile( TEMPLATE => 'analytics_protocol_figure/figureXXXX');
            $analytics_protocol_tempfile_string_3 .= '.png';
            my $analytics_protocol_figure_tempfile_3 = $c->config->{basepath}."/".$analytics_protocol_tempfile_string_3;

            my $analytics_protocol_tempfile_string_4 = $c->tempfile( TEMPLATE => 'analytics_protocol_figure/figureXXXX');
            $analytics_protocol_tempfile_string_4 .= '.png';
            my $analytics_protocol_figure_tempfile_4 = $c->config->{basepath}."/".$analytics_protocol_tempfile_string_4;

            my @germplasm_results;
            my @germplasm_data = ();
            my @germplasm_data_header = ("germplasmName");
            my @germplasm_data_values = ();
            my @germplasm_data_values_header = ();
            my @plots_avg_results;
            my @plots_avg_data = ();
            my @plots_avg_data_header = ("plotName", "germplasmName");
            my @plots_avg_data_values = ();
            my @plots_avg_data_values_header = ();
            my @plots_avg_data_heatmap_values_header = ("trait_type", "row", "col", "value");
            my @plots_avg_data_heatmap_values = ();
            my @plots_h_results;
            my @germplasm_data_iteration_header = ("germplasmName", "tmean", "time", "value");
            my @germplasm_data_iteration_data_values = ();
            my @plots_data_iteration_header = ("plotName", "tvalue", "time", "value");
            my @plots_data_iteration_data_values = ();


            if ($result_type eq 'originalgenoeff') {
                push @germplasm_data_header, ("htpspatialcorrectedgenoeffectmean", "htpspatialcorrectedgenoeffectsd");
                push @germplasm_data_values_header, "htpspatialcorrectedgenoeffectmean";

                foreach my $time (@sorted_seen_times_g) {
                    push @germplasm_data_header, "htpspatialcorrectedgenoeffect$time";
                    push @germplasm_data_values_header, "htpspatialcorrectedgenoeffect$time";
                }
            }
            elsif ($result_type eq 'fullcorr') {
                push @plots_avg_data_header, ("htpspatialeffectsd","htpspatialeffectmean");
                push @plots_avg_data_values_header, "htpspatialeffectmean";

                foreach my $time (@sorted_seen_times_p) {
                    push @plots_avg_data_header, "HTPspatial$time";
                    push @plots_avg_data_values_header, "HTPspatial$time";
                }
            }

            foreach my $g (@seen_germplasm) {
                my @line = ($g); #germplasmName
                my @values;

                if ($result_type eq 'originalgenoeff') {
                    my $geno_blups = $germplasm_result_blups{$g};
                    my $geno_blups_stat = Statistics::Descriptive::Full->new();
                    $geno_blups_stat->add_data(@$geno_blups);
                    my $geno_sd = $geno_blups_stat->standard_deviation();
                    my $geno_mean = $geno_blups_stat->mean();

                    push @line, ($geno_mean, $geno_sd); #"htpspatialcorrectedgenoeffectmean", "htpspatialcorrectedgenoeffectsd"
                    push @values, $geno_mean; #"htpspatialcorrectedgenoeffectmean"

                    foreach my $time (@sorted_seen_times_g) {
                        my $val = $germplasm_result_time_blups{$g}->{$time};
                        push @line, $val; #"htpspatialcorrectedgenoeffect$time"
                        push @values, $val; #"htpspatialcorrectedgenoeffect$time"
                    }
                }
                push @germplasm_data, \@line;
                push @germplasm_data_values, \@values;
            }

            my @type_names_first_line;
            my $is_first_plot = 1;
            foreach my $p (@seen_plots) {
                my $germplasm_name = $plot_germplasm_map{$p};
                my @line = ($p, $germplasm_name); #"plotName", "germplasmName"
                my @values;

                my $row_number = $stock_name_row_col{$p}->{row_number};
                my $col_number = $stock_name_row_col{$p}->{col_number};

                if ($result_type eq 'fullcorr') {
                    my $plot_blups = $plot_result_blups{$p};
                    my $plot_blups_stat = Statistics::Descriptive::Full->new();
                    $plot_blups_stat->add_data(@$plot_blups);
                    my $plot_sd = $plot_blups_stat->standard_deviation();
                    my $plot_mean = $plot_blups_stat->mean();
                    #my $plot_mean_scaled = $plot_mean*(($max_phenotype - $min_phenotype)/($max_phenotype_htp - $min_phenotype_htp));
                    my $plot_mean_scaled = $plot_mean;

                    push @line, ($plot_sd, $plot_mean_scaled); #"htpspatialeffectsd","htpspatialeffectmean"
                    push @values, $plot_mean_scaled; #"htpspatialeffectmean"
                    push @plots_avg_data_heatmap_values, ["HTPspatialmean", $row_number, $col_number, $plot_mean_scaled]; #"trait_type", "row", "col", "value"

                    if ($is_first_plot) {
                        push @type_names_first_line, "HTPspatialmean";
                    }

                    foreach my $time (@sorted_seen_times_p) {
                        my $time_val = $plot_result_time_blups{$p}->{$time};
                        #my $time_val_scaled = $time_val*(($max_phenotype - $min_phenotype)/($max_phenotype_htp - $min_phenotype_htp));
                        my $time_val_scaled = $time_val;
                        push @plots_avg_data_heatmap_values, ["HTPspatial$time", $row_number, $col_number, $time_val_scaled]; #"trait_type", "row", "col", "value"

                        if ($is_first_plot) {
                            push @type_names_first_line, ("HTPspatial$time");
                        }

                        push @line, $time_val_scaled;
                        push @values, $time_val_scaled;
                    }
                }
                push @plots_avg_data, \@line;
                push @plots_avg_data_values, \@values;
                $is_first_plot = 0;
            }

            open(my $F10, ">", $analytics_protocol_data_tempfile10) || die "Can't open file ".$analytics_protocol_data_tempfile10;
                my $header_string10 = join ',', @germplasm_data_header;
                print $F10 "$header_string10\n";

                foreach (@germplasm_data) {
                    my $string = join ',', @$_;
                    print $F10 "$string\n";
                }
            close($F10);

            open(my $F11, ">", $analytics_protocol_data_tempfile11) || die "Can't open file ".$analytics_protocol_data_tempfile11;
                my $header_string11 = join ',', @germplasm_data_values_header;
                print $F11 "$header_string11\n";

                foreach (@germplasm_data_values) {
                    my $string = join ',', @$_;
                    print $F11 "$string\n";
                }
            close($F11);

            open(my $F12, ">", $analytics_protocol_data_tempfile12) || die "Can't open file ".$analytics_protocol_data_tempfile12;
                my $header_string12 = join ',', @plots_avg_data_header;
                print $F12 "$header_string12\n";

                foreach (@plots_avg_data) {
                    my $string = join ',', @$_;
                    print $F12 "$string\n";
                }
            close($F12);

            open(my $F13, ">", $analytics_protocol_data_tempfile13) || die "Can't open file ".$analytics_protocol_data_tempfile13;
                my $header_string13 = join ',', @plots_avg_data_values_header;
                print $F13 "$header_string13\n";

                foreach (@plots_avg_data_values) {
                    my $string = join ',', @$_;
                    print $F13 "$string\n";
                }
            close($F13);

            open(my $F19, ">", $analytics_protocol_data_tempfile19) || die "Can't open file ".$analytics_protocol_data_tempfile19;
                my $header_string19 = join ',', @germplasm_data_iteration_header;
                print $F19 "$header_string19\n";

                foreach (@germplasm_data_iteration_data_values) {
                    my $string = join ',', @$_;
                    print $F19 "$string\n";
                }
            close($F19);

            open(my $F20, ">", $analytics_protocol_data_tempfile20) || die "Can't open file ".$analytics_protocol_data_tempfile20;
                my $header_string20 = join ',', @plots_data_iteration_header;
                print $F20 "$header_string20\n";

                foreach (@plots_data_iteration_data_values) {
                    my $string = join ',', @$_;
                    print $F20 "$string\n";
                }
            close($F20);

            open(my $F22, ">", $analytics_protocol_data_tempfile22) || die "Can't open file ".$analytics_protocol_data_tempfile22;
                my $header_string22 = join ',', @plots_avg_data_heatmap_values_header;
                print $F22 "$header_string22\n";

                foreach (@plots_avg_data_heatmap_values) {
                    my $string = join ',', @$_;
                    print $F22 "$string\n";
                }
            close($F22);

            # if ($result_type eq 'originalgenoeff') {
            #     my $r_cmd_i1 = 'R -e "library(ggplot2); library(data.table);
            #     data <- data.frame(fread(\''.$analytics_protocol_data_tempfile11.'\', header=TRUE, sep=\',\'));
            #     res <- cor(data, use = \'complete.obs\')
            #     res_rounded <- round(res, 2)
            #     write.table(res_rounded, file=\''.$analytics_protocol_data_tempfile16.'\', row.names=TRUE, col.names=TRUE, sep=\',\');
            #     "';
            #     print STDERR Dumper $r_cmd_i1;
            #     my $status_i1 = system($r_cmd_i1);
            #
            #     open(my $fh_i1, '<', $analytics_protocol_data_tempfile16) or die "Could not open file '$analytics_protocol_data_tempfile16' $!";
            #         print STDERR "Opened $analytics_protocol_data_tempfile16\n";
            #         my $header = <$fh_i1>;
            #         my @header_cols;
            #         if ($csv->parse($header)) {
            #             @header_cols = $csv->fields();
            #         }
            #
            #         my @header_trait_names = ("Trait", @header_cols);
            #         push @germplasm_results, \@header_trait_names;
            #
            #         while (my $row = <$fh_i1>) {
            #             my @columns;
            #             if ($csv->parse($row)) {
            #                 @columns = $csv->fields();
            #             }
            #
            #             push @germplasm_results, \@columns;
            #         }
            #     close($fh_i1);
            #
            #     my $r_cmd_p1 = 'R -e "library(data.table); library(ggplot2); library(GGally);
            #     data <- data.frame(fread(\''.$analytics_protocol_data_tempfile19.'\', header=TRUE, sep=\',\'));
            #     data\$time <- as.factor(data\$time);
            #     gg <- ggplot(data, aes(x=value, y=tmean, color=time)) +
            #     geom_point() +
            #     geom_smooth(method=lm, aes(fill=time), se=FALSE, fullrange=TRUE);
            #     ggsave(\''.$analytics_protocol_figure_tempfile_1.'\', gg, device=\'png\', width=8, height=8, units=\'in\');
            #     "';
            #     print STDERR Dumper $r_cmd_p1;
            #     my $status_p1 = system($r_cmd_p1);
            # }
            #
            if ($result_type eq 'fullcorr') {
            #     my $r_cmd_i2 = 'R -e "library(ggplot2); library(data.table);
            #     data <- data.frame(fread(\''.$analytics_protocol_data_tempfile13.'\', header=TRUE, sep=\',\'));
            #     res <- cor(data, use = \'complete.obs\')
            #     res_rounded <- round(res, 2)
            #     write.table(res_rounded, file=\''.$analytics_protocol_data_tempfile17.'\', row.names=TRUE, col.names=TRUE, sep=\',\');
            #     "';
            #     print STDERR Dumper $r_cmd_i2;
            #     my $status_i2 = system($r_cmd_i2);
            #
            #     open(my $fh_i2, '<', $analytics_protocol_data_tempfile17) or die "Could not open file '$analytics_protocol_data_tempfile17' $!";
            #         print STDERR "Opened $analytics_protocol_data_tempfile17\n";
            #         my $header2 = <$fh_i2>;
            #         my @header_cols2;
            #         if ($csv->parse($header2)) {
            #             @header_cols2 = $csv->fields();
            #         }
            #
            #         my @header_trait_names2 = ("Trait", @header_cols2);
            #         push @plots_avg_results, \@header_trait_names2;
            #
            #         while (my $row = <$fh_i2>) {
            #             my @columns;
            #             if ($csv->parse($row)) {
            #                 @columns = $csv->fields();
            #             }
            #
            #             push @plots_avg_results, \@columns;
            #         }
            #     close($fh_i2);
            #
                my $r_cmd_ic1 = 'R -e "library(ggplot2); library(data.table); library(GGally);
                data <- data.frame(fread(\''.$analytics_protocol_data_tempfile13.'\', header=TRUE, sep=\',\'));
                plot <- ggcorr(data, hjust = 1, size = 3, color = \'grey50\', layout.exp = 1, label = TRUE);
                ggsave(\''.$analytics_protocol_figure_tempfile_4.'\', plot, device=\'png\', width=10, height=10, units=\'in\');
                "';
                print STDERR Dumper $r_cmd_ic1;
                my $status_ic1 = system($r_cmd_ic1);

            #     my $r_cmd_p2 = 'R -e "library(data.table); library(ggplot2); library(GGally);
            #     data <- data.frame(fread(\''.$analytics_protocol_data_tempfile20.'\', header=TRUE, sep=\',\'));
            #     data\$time <- as.factor(data\$time);
            #     gg <- ggplot(data, aes(x=value, y=tvalue, color=time)) +
            #     geom_point() +
            #     geom_smooth(method=lm, aes(fill=time), se=FALSE, fullrange=TRUE);
            #     ggsave(\''.$analytics_protocol_figure_tempfile_2.'\', gg, device=\'png\', width=8, height=8, units=\'in\');
            #     "';
            #     print STDERR Dumper $r_cmd_p2;
            #     my $status_p2 = system($r_cmd_p2);
            #
            #     my $r_cmd_i3 = 'R -e "library(data.table); library(lme4);
            #     data <- data.frame(fread(\''.$analytics_protocol_data_tempfile12.'\', header=TRUE, sep=\',\'));
            #     num_columns <- ncol(data);
            #     col_names_results <- c();
            #     results <- c();
            #     for (i in seq(4,num_columns)){
            #         t <- names(data)[i];
            #         print(t);
            #         myformula <- as.formula(paste0(t, \' ~ (1|germplasmName)\'));
            #         m <- NULL;
            #         m.summary <- NULL;
            #         try (m <- lmer(myformula, data=data));
            #         if (!is.null(m)) {
            #             try (m.summary <- summary(m));
            #             if (!is.null(m.summary)) {
            #                 if (!is.null(m.summary\$varcor)) {
            #                     h <- m.summary\$varcor\$germplasmName[1,1]/(m.summary\$varcor\$germplasmName[1,1] + (m.summary\$sigma)^2);
            #                     col_names_results <- append(col_names_results, t);
            #                     results <- append(results, h);
            #                 }
            #             }
            #         }
            #     }
            #     write.table(data.frame(names = col_names_results, results = results), file=\''.$analytics_protocol_data_tempfile21.'\', row.names=FALSE, col.names=TRUE, sep=\',\');
            #     "';
            #     print STDERR Dumper $r_cmd_i3;
            #     my $status_i3 = system($r_cmd_i3);
            #
            #     open(my $fh_i3, '<', $analytics_protocol_data_tempfile21) or die "Could not open file '$analytics_protocol_data_tempfile21' $!";
            #         print STDERR "Opened $analytics_protocol_data_tempfile21\n";
            #         my $header3 = <$fh_i3>;
            #
            #         while (my $row = <$fh_i3>) {
            #             my @columns;
            #             if ($csv->parse($row)) {
            #                 @columns = $csv->fields();
            #             }
            #
            #             push @plots_h_results, \@columns;
            #         }
            #     close($fh_i3);

                my $output_plot_row = 'row';
                my $output_plot_col = 'col';
                if ($max_col < $max_row) {
                    $output_plot_row = 'col';
                    $output_plot_col = 'row';
                }

                my $type_list_string = join '\',\'', @type_names_first_line;
                my $r_cmd_i4 = 'R -e "library(data.table); library(ggplot2); library(dplyr); library(viridis); library(GGally); library(gridExtra);
                pheno_mat <- data.frame(fread(\''.$analytics_protocol_data_tempfile22.'\', header=TRUE, sep=\',\'));
                pheno_mat\$trait_type <- factor(pheno_mat\$trait_type, levels = c(\''.$type_list_string.'\'));
                options(device=\'png\');
                par();
                gg <- ggplot(pheno_mat, aes('.$output_plot_col.', '.$output_plot_row.', fill=value)) +
                    geom_tile() +
                    scale_fill_viridis(discrete=FALSE) +
                    coord_equal() +
                    facet_wrap(~trait_type, ncol=7);
                ggsave(\''.$analytics_protocol_figure_tempfile_3.'\', gg, device=\'png\', width=30, height=30, units=\'in\');
                "';
                print STDERR Dumper $r_cmd_i4;
                my $status_i4 = system($r_cmd_i4);

                push @analytics_protocol_charts, $analytics_protocol_tempfile_string_3;
                push @analytics_protocol_charts, $analytics_protocol_tempfile_string_4;
            }

            push @result_blups_all, {
                result_type => $result_type,
                germplasm_result_blups => \%germplasm_result_blups,
                plot_result_blups => \%plot_result_blups,
                parameter => $parameter,
                sim_var => $sim_var,
                time_change => $time_change,
                model_name => $model_name,
                germplasm_data_header => \@germplasm_data_header,
                germplasm_data => \@germplasm_data,
                germplasm_results => \@germplasm_results,
                plots_avg_data_header => \@plots_avg_data_header,
                plots_avg_data => \@plots_avg_data,
                plots_avg_results => \@plots_avg_results,
                plots_h_results => \@plots_h_results,
                germplasm_geno_corr_plot => $analytics_protocol_tempfile_string_1,
                plots_spatial_corr_plot => $analytics_protocol_tempfile_string_2,
                plots_spatial_heatmap_plot => $analytics_protocol_tempfile_string_3,
                plots_spatial_ggcorr_plot => $analytics_protocol_tempfile_string_4,
            };
        }
    }

    $c->stash->{analytics_protocol_id} = $nd_protocol_id;
    $c->stash->{analytics_protocol_name} = $name;
    $c->stash->{analytics_protocol_description} = $description;
    $c->stash->{analytics_protocol_type_id} = $type_id;
    $c->stash->{analytics_protocol_type_name} = $available_types{$type_id};
    $c->stash->{analytics_protocol_create_date} = $create_date;
    $c->stash->{analytics_protocol_properties} = decode_json $props_json;
    $c->stash->{analytics_protocol_result_summary} = $result_props_json_array;
    $c->stash->{analytics_protocol_charts} = \@analytics_protocol_charts;
    $c->stash->{template} = '/analytics_protocols/detail.mas';
}

1;
