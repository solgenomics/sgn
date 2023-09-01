
=head1 NAME

SGN::Controller::AJAX::DroneRover::DroneRoverMainDisplay - a REST controller class to provide the
functions for showing the main drone rover display of all rover events.

=head1 DESCRIPTION

=head1 AUTHOR

=cut

package SGN::Controller::AJAX::DroneRover::DroneRoverMainDisplay;

use Moose;
use Data::Dumper;
use JSON;
use SGN::Model::Cvterm;
use DateTime;
use SGN::Image;
use CXGN::DroneImagery::ImagesSearch;
use URI::Encode qw(uri_encode uri_decode);
use CXGN::Calendar;
use Image::Size;
use CXGN::DroneImagery::ImageTypes;
use CXGN::PrivateCompany;
#use Inline::Python;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON'  },
);

sub drone_rover_summary_top : Path('/api/drone_rover/drone_rover_top') : ActionClass('REST') { }
sub drone_rover_summary_top_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");

    my ($user_id, $user_name, $user_role) = _check_user_login_drone_rover_main_display($c, 0, 0, 0);

    my $private_companies = CXGN::PrivateCompany->new( { schema=> $schema } );
    my ($private_companies_array, $private_companies_ids, $allowed_private_company_ids_hash, $allowed_private_company_access_hash, $private_company_access_is_private_hash) = $private_companies->get_users_private_companies($user_id, 0);
    my $private_company_ids_sql = join ',', @$private_companies_ids;

    my $drone_run_field_trial_project_relationship_type_id_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_on_field_trial', 'project_relationship')->cvterm_id();
    my $project_start_date_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project_start_date', 'project_property')->cvterm_id();
    my $drone_run_project_type_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_project_type', 'project_property')->cvterm_id();
    my $drone_run_project_averaged_temperature_gdd_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_averaged_temperature_growing_degree_days', 'project_property')->cvterm_id();
    my $drone_run_project_averaged_precipitation_sum_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_averaged_precipitation_sum', 'project_property')->cvterm_id();
    my $drone_run_is_rover_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_is_rover', 'project_property')->cvterm_id();
    my $drone_run_experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_experiment', 'experiment_type')->cvterm_id();
    my $design_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'design', 'project_property')->cvterm_id();
    my $drone_run_camera_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_camera_type', 'project_property')->cvterm_id();
    my $drone_run_related_cvterms_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_related_time_cvterms_json', 'project_property')->cvterm_id();
    my $field_trial_drone_runs_in_same_rover_event_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'field_trial_drone_runs_in_same_rover_event', 'experiment_type')->cvterm_id();
    my $imaging_vehicle_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'imaging_event_vehicle_rover', 'stock_type')->cvterm_id();
    my $imaging_vehicle_properties_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'imaging_event_vehicle_json', 'stock_property')->cvterm_id();
    my $earthsense_collections_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'earthsense_ground_rover_collections_archived', 'project_property')->cvterm_id();

    my $drone_run_q = "SELECT drone_run_project.project_id, drone_run_project.name, drone_run_project.description, field_trial.project_id, field_trial.name, field_trial.description, drone_run_date.value, drone_run_type.value, is_rover.value, drone_run_averaged_temperature_gdd.value, drone_run_averaged_precipitation_sum.value, drone_run_related_time_cvterm_json.value, earthsense_collections_archived.value, company.private_company_id, company.name
        FROM project AS drone_run_project
        JOIN sgn_people.private_company AS company ON (company.private_company_id=drone_run_project.private_company_id)
        JOIN projectprop AS drone_run_date ON(drone_run_project.project_id=drone_run_date.project_id AND drone_run_date.type_id=$project_start_date_type_id)
        JOIN projectprop AS earthsense_collections_archived ON(drone_run_project.project_id=earthsense_collections_archived.project_id AND earthsense_collections_archived.type_id=$earthsense_collections_cvterm_id)
        LEFT JOIN projectprop AS drone_run_type ON(drone_run_project.project_id=drone_run_type.project_id AND drone_run_type.type_id=$drone_run_project_type_type_id)
        LEFT JOIN projectprop AS drone_run_averaged_temperature_gdd ON(drone_run_project.project_id=drone_run_averaged_temperature_gdd.project_id AND drone_run_averaged_temperature_gdd.type_id=$drone_run_project_averaged_temperature_gdd_type_id)
        LEFT JOIN projectprop AS drone_run_averaged_precipitation_sum ON(drone_run_project.project_id=drone_run_averaged_precipitation_sum.project_id AND drone_run_averaged_precipitation_sum.type_id=$drone_run_project_averaged_precipitation_sum_type_id)
        LEFT JOIN projectprop AS drone_run_related_time_cvterm_json ON(drone_run_related_time_cvterm_json.project_id = drone_run_project.project_id AND drone_run_related_time_cvterm_json.type_id = $drone_run_related_cvterms_cvterm_id)
        LEFT JOIN projectprop AS is_rover ON (drone_run_project.project_id=is_rover.project_id AND is_rover.type_id=$drone_run_is_rover_cvterm_id)
        JOIN project_relationship AS field_trial_rel ON (drone_run_project.project_id = field_trial_rel.subject_project_id AND field_trial_rel.type_id=$drone_run_field_trial_project_relationship_type_id_cvterm_id)
        JOIN project AS field_trial ON (field_trial_rel.object_project_id = field_trial.project_id)
        WHERE company.private_company_id IN($private_company_ids_sql);";
    # print STDERR $drone_run_q."\n";
    my $h = $schema->storage->dbh()->prepare($drone_run_q);
    $h->execute();

    my $calendar_funcs = CXGN::Calendar->new({});

    my %unique_drone_runs;
    my %unique_drone_run_dates;
    my $epoch_seconds = 0;
    my %trial_id_hash;
    while( my ($drone_run_project_id, $drone_run_project_name, $drone_run_project_desc, $field_trial_project_id, $field_trial_project_name, $field_trial_project_desc, $drone_run_date, $drone_run_type, $drone_rover_type, $drone_run_averaged_temperature_gdd, $drone_run_averaged_precipitation_sum, $drone_run_related_time_cvterm_json, $earthsense_collections_archived_json, $private_company_id, $private_company_name) = $h->fetchrow_array()) {
        my $drone_run_date_formatted = $drone_run_date ? $calendar_funcs->display_start_date($drone_run_date) : '';

        $unique_drone_runs{$field_trial_project_name}->{$drone_run_project_id}->{private_company_id} = $private_company_id;
        $unique_drone_runs{$field_trial_project_name}->{$drone_run_project_id}->{private_company_is_private} = $private_company_access_is_private_hash->{$private_company_id};
        $unique_drone_runs{$field_trial_project_name}->{$drone_run_project_id}->{private_company_name} = $private_company_name;
        $unique_drone_runs{$field_trial_project_name}->{$drone_run_project_id}->{trial_id} = $field_trial_project_id;
        $unique_drone_runs{$field_trial_project_name}->{$drone_run_project_id}->{trial_name} = $field_trial_project_name;
        $unique_drone_runs{$field_trial_project_name}->{$drone_run_project_id}->{drone_run_project_name} = $drone_run_project_name;
        $unique_drone_runs{$field_trial_project_name}->{$drone_run_project_id}->{drone_run_date} = $drone_run_date_formatted;
        $unique_drone_runs{$field_trial_project_name}->{$drone_run_project_id}->{drone_run_type} = $drone_run_type;
        $unique_drone_runs{$field_trial_project_name}->{$drone_run_project_id}->{drone_run_rover_type} = $drone_rover_type;
        $unique_drone_runs{$field_trial_project_name}->{$drone_run_project_id}->{drone_run_project_description} = $drone_run_project_desc;
        $unique_drone_runs{$field_trial_project_name}->{$drone_run_project_id}->{drone_run_averaged_temperature_gdd} = $drone_run_averaged_temperature_gdd;
        $unique_drone_runs{$field_trial_project_name}->{$drone_run_project_id}->{drone_run_averaged_precipitation_sum} = $drone_run_averaged_precipitation_sum;
        $unique_drone_runs{$field_trial_project_name}->{$drone_run_project_id}->{drone_run_related_time_cvterm_json} = decode_json $drone_run_related_time_cvterm_json;
        $unique_drone_runs{$field_trial_project_name}->{$drone_run_project_id}->{drone_run_earthsense_collections_archive_json} = decode_json $earthsense_collections_archived_json;

        $trial_id_hash{$field_trial_project_name} = $field_trial_project_id;

        if ($drone_run_date_formatted) {
            my $date_obj = Time::Piece->strptime($drone_run_date_formatted, "%Y-%B-%d %H:%M:%S");
            $epoch_seconds = $date_obj->epoch;
        }
        else {
            $epoch_seconds++;
        }
        $unique_drone_run_dates{$field_trial_project_name}->{$epoch_seconds} = $drone_run_project_id;
    }
    $h = undef;
    # print STDERR Dumper \%unique_drone_runs;

    my @return;
    foreach my $trial_name (sort keys %unique_drone_runs) {
        my %unique_drone_runs_k = %{$unique_drone_runs{$trial_name}};

        my $drone_run_html = '<div class="panel-group" id="drone_rover_runs_trial_accordion_table_wrapper_'.$trial_id_hash{$trial_name}.'" ><div class="panel panel-default"><div class="panel-heading"><div class="row"><div class="col-sm-8"><h4 class="panel-title"><a data-toggle="collapse" data-parent="#drone_rover_runs_trial_accordion_table_wrapper_'.$trial_id_hash{$trial_name}.'" href="#drone_rover_runs_trial_accordion_table_wrapper_one_'.$trial_id_hash{$trial_name}.'" >Field Trial: '.$trial_name.'&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;('.scalar(keys %unique_drone_runs_k).' Rover Events)</a>';

        $drone_run_html .= '</h4></div><div class="col-sm-2">&nbsp;';

        $drone_run_html .= '</div><div class="col-sm-2"></div></div></div><div id="drone_rover_runs_trial_accordion_table_wrapper_one_'.$trial_id_hash{$trial_name}.'" class="panel-collapse collapse"><div class="panel-body">';

        foreach my $epoch_seconds (sort keys %{$unique_drone_run_dates{$trial_name}}) {
            my $k = $unique_drone_run_dates{$trial_name}->{$epoch_seconds};
            my $v = $unique_drone_runs_k{$k};
            my $collections = $v->{drone_run_earthsense_collections_archive_json};
            my $drone_run_date = $v->{drone_run_date};
            my $drone_run_name = $v->{drone_run_project_name};
            my $trial_name = $v->{trial_name};

            $drone_run_html .= '<div class="panel-group" id="drone_run_rover_accordion_drone_run_wrapper_'.$k.'" ><div class="panel panel-default"><div class="panel-heading"><h4 class="panel-title"><a data-toggle="collapse" data-parent="#drone_run_rover_accordion_drone_run_wrapper_'.$k.'" href="#drone_run_rover_accordion_drone_run_wrapper_one_'.$k.'" >'.$v->{drone_run_project_name}.'&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp'.$drone_run_date;

            $drone_run_html .= '</a></h4></div><div id="drone_run_rover_accordion_drone_run_wrapper_one_'.$k.'" class="panel-collapse collapse"><div class="panel-body">';

            $drone_run_html .= '<div class="well well-sm">';

            $drone_run_html .= '<div class="row"><div class="col-sm-7">';

            $drone_run_html .= '<div class="row"><div class="col-sm-5"><b>Imaging Event Name</b>:</div><div class="col-sm-7"><a href="/breeders_toolbox/trial/'.$k.'" _target="blank">'.$drone_run_name.'</a></div></div>';
            $drone_run_html .= '<div class="row"><div class="col-sm-5"><b>Rover Event Type</b>:</div><div class="col-sm-7">'.$v->{drone_run_rover_type}.'</div></div>';
            $drone_run_html .= '<div class="row"><div class="col-sm-5"><b>Rover Data Type</b>:</div><div class="col-sm-7">'.$v->{drone_run_type}.'</div></div>';
            $drone_run_html .= '<div class="row"><div class="col-sm-5"><b>Description</b>:</div><div class="col-sm-7">'.$v->{drone_run_project_description}.'</div></div>';
            $drone_run_html .= '<div class="row"><div class="col-sm-5"><b>Date</b>:</div><div class="col-sm-7">'.$drone_run_date.'</div></div>';
            if (defined($v->{drone_run_averaged_temperature_gdd})) {
                $drone_run_html .= '<div class="row"><div class="col-sm-5"><b>Averaged Temperature Growing Degree Days</b>:</div><div class="col-sm-7">'.$v->{drone_run_averaged_temperature_gdd}.'&nbsp;&nbsp;&nbsp;<button class="btn btn-default btn-sm" name="drone_imagery_drone_run_calculate_gdd" data-drone_run_project_id="'.$k.'" data-field_trial_id="'.$v->{trial_id}.'">Recalculate GDD</button></div></div>';
            }
            else {
                $drone_run_html .= '<div class="row"><div class="col-sm-5"><b>Growing Degree Days</b>:</div><div class="col-sm-7"><button class="btn btn-default btn-sm" name="drone_imagery_drone_run_calculate_gdd" data-drone_run_project_id="'.$k.'" data-field_trial_id="'.$v->{trial_id}.'">Calculate GDD</button></div></div>';
            }
            if (defined($v->{drone_run_averaged_precipitation_sum}) ) {
                $drone_run_html .= '<div class="row"><div class="col-sm-5"><b>Averaged Precipitation Sum</b>:</div><div class="col-sm-7">'.$v->{drone_run_averaged_precipitation_sum}.'&nbsp;&nbsp;&nbsp;<button class="btn btn-default btn-sm" name="drone_imagery_drone_run_calculate_precipitation_sum" data-drone_run_project_id="'.$k.'" data-field_trial_id="'.$v->{trial_id}.'">Recalculate Precipitation Sum</button></div></div>';
            }
            else {
                $drone_run_html .= '<div class="row"><div class="col-sm-5"><b>Precipitation Sum</b>:</div><div class="col-sm-7"><button class="btn btn-default btn-sm" name="drone_imagery_drone_run_calculate_precipitation_sum" data-drone_run_project_id="'.$k.'" data-field_trial_id="'.$v->{trial_id}.'">Calculate Precipitation Sum</button></div></div>';
            }
            my $days_after_planting_string = 'NA. Recalculate GDD or Contact Us.';
            if ($v->{drone_run_related_time_cvterm_json}->{day}) {
                my @days_after_planting_strings = split '\|', $v->{drone_run_related_time_cvterm_json}->{day};
                $days_after_planting_string = $days_after_planting_strings[0];
            }
            $drone_run_html .= '<div class="row"><div class="col-sm-5"><b>Growing Season Days</b>:</div><div class="col-sm-7">'.$days_after_planting_string.'</div></div>';
            $drone_run_html .= '<div class="row"><div class="col-sm-5"><b>Field Trial</b>:</div><div class="col-sm-7"><a href="/breeders_toolbox/trial/'.$v->{trial_id}.'" _target="blank">'.$trial_name.'</a></div></div>';

            $drone_run_html .= '</div><div class="col-sm-5">';

            $drone_run_html .= '<div class="panel-group" id="project_drone_rover_buttons_sections_'.$k.'" ><div class="panel panel-default"><div class="panel-heading"><h4 class="panel-title"><a data-toggle="collapse" data-parent="#project_drone_rover_buttons_sections_'.$k.'" href="#project_drone_rover_buttons_sections_accordian_'.$k.'" >Additional Options</a></h4></div><div id="project_drone_rover_buttons_sections_accordian_'.$k.'" class="panel-collapse collapse"><div class="panel-body">';

                $drone_run_html .= '<button class="btn btn-default btn-sm" name="project_drone_rover_field_name_link" data-drone_run_project_id="'.$k.'" data-field_trial_id="'.$v->{trial_id}.'" data-field_trial_name="'.$v->{trial_name}.'" data-private_company_id="'.$v->{private_company_id}.'" data-private_company_is_private="'.$v->{private_company_is_private}.'" >Define Collection Field Names</button><br/><br/>';

                # $drone_run_html .= '<button class="btn btn-danger btn-sm" name="project_drone_imagery_delete_drone_run" data-drone_run_project_id="'.$k.'" data-drone_run_project_name="'.$v->{drone_run_project_name}.'" >Delete Imaging Event</button>';

            $drone_run_html .= '</div></div></div></div>';

            $drone_run_html .= '</div></div></div>';

            $drone_run_html .= "<hr>";

            $drone_run_html .= '<div name="drone_run_band_total_plot_point_cloud_div" id="drone_run_band_total_plot_point_cloud_count_div_'.$k.'">';
            $drone_run_html .= '<div class="panel-group"><div class="panel panel-default panel-sm"><div class="panel-heading"><h4 class="panel-title"><a data-toggle="collapse" >Loading Plot Point Cloud Summary...</a></h4></div></div></div>';
            $drone_run_html .= '</div>';

                my %collection_times;
                my %collected_fields;
                while (my ($collection_number, $collect) = each %$collections) {
                    my $start_time = $collect->{run_info}->{tracker}->{start_date};
                    my $field_name = $collect->{run_info}->{field}->{name};

                    $collection_times{$start_time} = {
                        collection_number => $collection_number,
                        collect => $collect
                    };

                    $collected_fields{$field_name} = $collect->{run_info}->{field};
                }

                $drone_run_html .= '<div class="well well-sm"><table class="table table-bordered table-hover"><thead><tr><th>Collected Fields</th><th>Range Min</th><th>Range Max</th><th>Column Min</th><th>Column Max</th><th>Rows Per Column</th><th>Plot Length</th><th>Row Width</th><th>Planting Spacing</th><th>Crop</th></tr></thead><tbody>';
                foreach my $field_name (sort keys %collected_fields) {
                    $drone_run_html .= '<tr><td>'.$field_name.'</td><td>'.$collected_fields{$field_name}->{range_min}.'</td><td>'.$collected_fields{$field_name}->{range_max}.'</td><td>'.$collected_fields{$field_name}->{column_min}.'</td><td>'.$collected_fields{$field_name}->{column_max}.'</td><td>'.$collected_fields{$field_name}->{rows_per_column}.'</td><td>'.$collected_fields{$field_name}->{plot_length}.'</td><td>'.$collected_fields{$field_name}->{row_width}.'</td><td>'.$collected_fields{$field_name}->{planting_spacing}.'</td><td>'.$collected_fields{$field_name}->{crop_name}.'</td></tr>';
                }
                $drone_run_html .= '</tbody></table></div>';

                my $drone_run_band_table_html = '<table class="table table-bordered"><thead><tr><th>Rover Collection(s)</th><th>Images/Actions</th></thead><tbody>';

                my $collections_displaying = 0;
                foreach my $collection_time (sort keys %collection_times) {
                    my $collect_obj = $collection_times{$collection_time};
                    my $collection_number = $collect_obj->{collection_number};
                    my $collect = $collect_obj->{collect};
                    # print STDERR Dumper $collect;

                    my $field_name = $collect->{run_info}->{field}->{name};
                    my $database_field_name = $collect->{run_info}->{field}->{database_field_name} || $field_name;
                    my $collect_plot_polygons = $collect->{plot_polygons};

                    if ($trial_name eq $database_field_name) {
                        $collections_displaying = 1;
                        my $original_image_id = $collect->{processed_image_ids}->{points_original};
                        my $filtered_image_id = $collect->{processed_image_ids}->{points_filtered_height};
                        my $filtered_side_span_image_id = $collect->{processed_image_ids}->{points_filtered_side_span};
                        my $filtered_side_height_image_id = $collect->{processed_image_ids}->{points_filtered_side_height};

                        $drone_run_band_table_html .= '<tr><td>';
                        $drone_run_band_table_html .= '<b>Collection Number</b>: '.$collection_number.'<br/>';
                        $drone_run_band_table_html .= '<b>Collection Field</b>: '.$field_name.'&nbsp;&nbsp;&nbsp;<b>Database Field Trial</b>: '.$database_field_name.'<br/>';
                        $drone_run_band_table_html .= '<b>Start Range</b>: '.$collect->{run_info}->{tracker}->{start_range}.'&nbsp;&nbsp;&nbsp;&nbsp;<b>Start Column</b>: '.$collect->{run_info}->{tracker}->{start_column}.'<br/>';
                        $drone_run_band_table_html .= '<b>Stop Range</b>: '.$collect->{run_info}->{tracker}->{stop_range}.'&nbsp;&nbsp;&nbsp;&nbsp;<b>Stop Column</b>: '.$collect->{run_info}->{tracker}->{stop_column}.'<br/>';
                        $drone_run_band_table_html .= '<b>Original Number Points</b>: '.$collect->{processing}->{pcd_original_num_points}.'<br/><b>Filtered Number Points</b>: '.$collect->{processing}->{pcd_down_filtered_height_side_points}.'<br/>';

                        if (!$collect_plot_polygons) {
                            $drone_run_band_table_html .= '<br/><button class="btn btn-primary btn-sm" name="project_drone_rover_plot_polygons" data-drone_run_project_id="'.$k.'" data-drone_run_project_name="'.$drone_run_name.'" data-field_trial_id="'.$v->{trial_id}.'" data-field_trial_name="'.$v->{trial_name}.'" data-private_company_id="'.$v->{private_company_id}.'" data-private_company_is_private="'.$v->{private_company_is_private}.'" data-original_image_id="'.$original_image_id.'" data-filtered_image_id="'.$filtered_image_id.'" data-filtered_side_span_image_id="'.$filtered_side_span_image_id.'" data-filtered_side_height_image_id="'.$filtered_side_height_image_id.'" data-collection_number="'.$collection_number.'" data-collection_project_id="'.$collect->{project_id}.'" data-database_field_name="'.$database_field_name.'" >Process Plot Polygons</button><br/><br/>';
                        }
                        else {
                           $drone_run_band_table_html .= '<br/><span class="label label-success" ><span class="glyphicon glyphicon-ok"></span>&nbsp;&nbsp;&nbsp;Plot Polygons Processed</span><br/><br/>';
                        }

                        $drone_run_band_table_html .= '</td><td>';
                        $drone_run_band_table_html .= '<div class="panel-group" id="drone_run_rover_accordion_'.$k.'_'.$collection_number.'" ><div class="panel panel-default"><div class="panel-heading"><h4 class="panel-title"><a data-toggle="collapse" data-parent="#drone_run_rover_accordion_'.$k.'_'.$collection_number.'" href="#drone_run_rover_accordion_one_'.$k.'_'.$collection_number.'" onclick="manageDroneRoverEventDisplay('.$k.',&quot;'.$collection_number.'&quot;,'.$original_image_id.','.$filtered_image_id.')">View Images</a></h4></div><div id="drone_run_rover_accordion_one_'.$k.'_'.$collection_number.'" class="panel-collapse collapse"><div class="panel-body">';

                        $drone_run_band_table_html .= '<div id="drone_run_rover_accordian_drone_run_band_div_'.$k.'_'.$collection_number.'"></div>';

                        $drone_run_band_table_html .= '</div></div></div></div>';
                        $drone_run_band_table_html .= '</td></tr>';
                    }
                }
                if (!$collections_displaying) {
                    $drone_run_band_table_html .= '<tr><td><button class="btn btn-danger" name="project_drone_rover_field_name_link" data-drone_run_project_id="'.$k.'" data-field_trial_id="'.$v->{trial_id}.'" data-field_trial_name="'.$v->{trial_name}.'" data-private_company_id="'.$v->{private_company_id}.'" data-private_company_is_private="'.$v->{private_company_is_private}.'" >Error: Please Define Collection Field Names</button><br/><br/></td></tr>';

                }
                $drone_run_band_table_html .= '</tbody></table>';

                $drone_run_html .= $drone_run_band_table_html;

            $drone_run_html .= '</div></div></div></div>';

            $drone_run_html .= '<br/>';
        }
        $drone_run_html .= '</div></div></div></div>';

        push @return, [$drone_run_html];
    }

    $c->stash->{rest} = { data => \@return };
}

sub _check_user_login_drone_rover_main_display {
    my $c = shift;
    my $check_priv = shift;
    my $original_private_company_id = shift;
    my $user_access = shift;

    my $login_check_return = CXGN::Login::_check_user_login($c, $check_priv, $original_private_company_id, $user_access);
    if ($login_check_return->{error}) {
        $c->stash->{rest} = $login_check_return;
        $c->detach();
    }
    my ($user_id, $user_name, $user_role) = @{$login_check_return->{info}};

    return ($user_id, $user_name, $user_role);
}

1;
