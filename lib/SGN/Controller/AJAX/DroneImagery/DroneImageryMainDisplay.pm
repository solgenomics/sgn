
=head1 NAME

SGN::Controller::AJAX::DroneImagery::DroneImageryMainDisplay - a REST controller class to provide the
functions for showing the main drone imagery display of all images. All other functions are
controlled by SGN::Controller::AJAX::DroneImagery

=head1 DESCRIPTION

=head1 AUTHOR

=cut

package SGN::Controller::AJAX::DroneImagery::DroneImageryMainDisplay;

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
#use Inline::Python;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON'  },
);

sub raw_drone_imagery_summary_top : Path('/api/drone_imagery/raw_drone_imagery_top') : ActionClass('REST') { }
sub raw_drone_imagery_summary_top_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    my $drone_run_field_trial_project_relationship_type_id_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_on_field_trial', 'project_relationship')->cvterm_id();
    my $drone_run_band_drone_run_project_relationship_type_id_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_on_drone_run', 'project_relationship')->cvterm_id();
    my $project_start_date_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project_start_date', 'project_property')->cvterm_id();
    my $drone_run_project_type_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_project_type', 'project_property')->cvterm_id();
    my $drone_run_is_raw_images_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_is_raw_images', 'project_property')->cvterm_id();
    my $drone_run_ground_control_points_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_ground_control_points', 'project_property')->cvterm_id();
    my $drone_run_project_averaged_temperature_gdd_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_averaged_temperature_growing_degree_days', 'project_property')->cvterm_id();
    my $drone_run_project_averaged_precipitation_sum_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_averaged_precipitation_sum', 'project_property')->cvterm_id();
    my $drone_run_related_time_cvterms_json_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_related_time_cvterms_json', 'project_property')->cvterm_id();
    my $process_indicator_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_standard_process_in_progress', 'project_property')->cvterm_id();
    my $processed_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_standard_process_completed', 'project_property')->cvterm_id();
    my $processed_extended_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_standard_process_extended_completed', 'project_property')->cvterm_id();
    my $processed_vi_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_standard_process_vi_completed', 'project_property')->cvterm_id();
    my $phenotypes_processed_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_standard_process_phenotype_calculation_in_progress', 'project_property')->cvterm_id();
    my $drone_run_band_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_project_type', 'project_property')->cvterm_id();
    my $drone_run_camera_rig_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_camera_rig_description', 'project_property')->cvterm_id();
    my $drone_run_base_date_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_base_date', 'project_property')->cvterm_id();

    my $drone_run_q = "SELECT drone_run_band_project.project_id, drone_run_band_project.name, drone_run_band_project.description, drone_run_project.project_id, drone_run_project.name, drone_run_project.description, field_trial.project_id, field_trial.name, field_trial.description, drone_run_band_type.value, drone_run_date.value, drone_run_type.value, drone_run_averaged_temperature_gdd.value, drone_run_averaged_precipitation_sum.value, drone_run_related_time_cvterm_json.value, drone_run_indicator.value, drone_run_phenotypes_indicator.value, drone_run_processed.value, drone_run_processed_extended.value, drone_run_processed_vi.value, drone_run_is_raw_images.value, drone_run_ground_control_points.value, drone_run_camera_rig.value, drone_run_base_date.value
        FROM project AS drone_run_band_project
        JOIN projectprop AS drone_run_band_type ON(drone_run_band_project.project_id=drone_run_band_type.project_id AND drone_run_band_type.type_id=$drone_run_band_type_cvterm_id)
        JOIN project_relationship AS drone_run_band_rel ON (drone_run_band_rel.subject_project_id = drone_run_band_project.project_id AND drone_run_band_rel.type_id = $drone_run_band_drone_run_project_relationship_type_id_cvterm_id)
        JOIN project AS drone_run_project ON (drone_run_band_rel.object_project_id = drone_run_project.project_id)
        JOIN projectprop AS drone_run_date ON(drone_run_project.project_id=drone_run_date.project_id AND drone_run_date.type_id=$project_start_date_type_id)
        LEFT JOIN projectprop AS drone_run_type ON(drone_run_project.project_id=drone_run_type.project_id AND drone_run_type.type_id=$drone_run_project_type_type_id)
        LEFT JOIN projectprop AS drone_run_is_raw_images ON(drone_run_project.project_id=drone_run_is_raw_images.project_id AND drone_run_is_raw_images.type_id=$drone_run_is_raw_images_type_id)
        LEFT JOIN projectprop AS drone_run_ground_control_points ON(drone_run_project.project_id=drone_run_ground_control_points.project_id AND drone_run_ground_control_points.type_id=$drone_run_ground_control_points_type_id)
        LEFT JOIN projectprop AS drone_run_averaged_temperature_gdd ON(drone_run_project.project_id=drone_run_averaged_temperature_gdd.project_id AND drone_run_averaged_temperature_gdd.type_id=$drone_run_project_averaged_temperature_gdd_type_id)
        LEFT JOIN projectprop AS drone_run_averaged_precipitation_sum ON(drone_run_project.project_id=drone_run_averaged_precipitation_sum.project_id AND drone_run_averaged_precipitation_sum.type_id=$drone_run_project_averaged_precipitation_sum_type_id)
        LEFT JOIN projectprop AS drone_run_related_time_cvterm_json ON(drone_run_related_time_cvterm_json.project_id = drone_run_project.project_id AND drone_run_related_time_cvterm_json.type_id = $drone_run_related_time_cvterms_json_type_id)
        LEFT JOIN projectprop AS drone_run_indicator ON(drone_run_indicator.project_id = drone_run_project.project_id AND drone_run_indicator.type_id = $process_indicator_cvterm_id)
        LEFT JOIN projectprop AS drone_run_phenotypes_indicator ON(drone_run_phenotypes_indicator.project_id = drone_run_project.project_id AND drone_run_phenotypes_indicator.type_id = $phenotypes_processed_cvterm_id)
        LEFT JOIN projectprop AS drone_run_processed_extended ON(drone_run_processed_extended.project_id = drone_run_project.project_id AND drone_run_processed_extended.type_id = $processed_extended_cvterm_id)
        LEFT JOIN projectprop AS drone_run_processed_vi ON(drone_run_processed_vi.project_id = drone_run_project.project_id AND drone_run_processed_vi.type_id = $processed_vi_cvterm_id)
        LEFT JOIN projectprop AS drone_run_processed ON(drone_run_processed.project_id = drone_run_project.project_id AND drone_run_processed.type_id = $processed_cvterm_id)
        LEFT JOIN projectprop AS drone_run_camera_rig ON(drone_run_camera_rig.project_id = drone_run_project.project_id AND drone_run_camera_rig.type_id = $drone_run_camera_rig_cvterm_id)
        LEFT JOIN projectprop AS drone_run_base_date ON(drone_run_base_date.project_id = drone_run_project.project_id AND drone_run_base_date.type_id = $drone_run_base_date_cvterm_id)
        JOIN project_relationship AS field_trial_rel ON (drone_run_project.project_id = field_trial_rel.subject_project_id AND field_trial_rel.type_id=$drone_run_field_trial_project_relationship_type_id_cvterm_id)
        JOIN project AS field_trial ON (field_trial_rel.object_project_id = field_trial.project_id);";
    my $h = $schema->storage->dbh()->prepare($drone_run_q);
    $h->execute();

    my $calendar_funcs = CXGN::Calendar->new({});

    my %unique_drone_runs;
    my %unique_drone_run_dates;
    my $epoch_seconds = 0;
    my %trial_id_hash;
    while( my ($drone_run_band_project_id, $drone_run_band_project_name, $drone_run_band_project_desc, $drone_run_project_id, $drone_run_project_name, $drone_run_project_desc, $field_trial_project_id, $field_trial_project_name, $field_trial_project_desc, $drone_run_band_project_type, $drone_run_date, $drone_run_type, $drone_run_averaged_temperature_gdd, $drone_run_averaged_precipitation_sum, $drone_run_related_time_cvterm_json, $drone_run_indicator, $drone_run_phenotypes_indicator, $drone_run_processed, $drone_run_processed_extended, $drone_run_processed_vi, $drone_run_is_raw_images, $drone_run_ground_control_points_json, $drone_run_camera_rig, $drone_run_base_date) = $h->fetchrow_array()) {
        my $drone_run_date_formatted = $drone_run_date ? $calendar_funcs->display_start_date($drone_run_date) : '';

        $unique_drone_runs{$field_trial_project_name}->{$drone_run_project_id}->{bands}->{$drone_run_band_project_id}->{drone_run_band_project_name} = $drone_run_band_project_name;
        $unique_drone_runs{$field_trial_project_name}->{$drone_run_project_id}->{bands}->{$drone_run_band_project_id}->{drone_run_band_project_description} = $drone_run_band_project_desc;
        $unique_drone_runs{$field_trial_project_name}->{$drone_run_project_id}->{bands}->{$drone_run_band_project_id}->{drone_run_band_project_type} = $drone_run_band_project_type;
        $unique_drone_runs{$field_trial_project_name}->{$drone_run_project_id}->{trial_id} = $field_trial_project_id;
        $unique_drone_runs{$field_trial_project_name}->{$drone_run_project_id}->{trial_name} = $field_trial_project_name;
        $unique_drone_runs{$field_trial_project_name}->{$drone_run_project_id}->{drone_run_project_name} = $drone_run_project_name;
        $unique_drone_runs{$field_trial_project_name}->{$drone_run_project_id}->{drone_run_date} = $drone_run_date_formatted;
        $unique_drone_runs{$field_trial_project_name}->{$drone_run_project_id}->{drone_run_type} = $drone_run_type;
        $unique_drone_runs{$field_trial_project_name}->{$drone_run_project_id}->{drone_run_is_raw_images} = $drone_run_is_raw_images;
        $unique_drone_runs{$field_trial_project_name}->{$drone_run_project_id}->{drone_run_indicator} = $drone_run_indicator;
        $unique_drone_runs{$field_trial_project_name}->{$drone_run_project_id}->{drone_run_processed} = $drone_run_processed;
        $unique_drone_runs{$field_trial_project_name}->{$drone_run_project_id}->{drone_run_processed_minimal_vi} = $drone_run_processed_vi;
        $unique_drone_runs{$field_trial_project_name}->{$drone_run_project_id}->{drone_run_processed_extended} = $drone_run_processed_extended;
        $unique_drone_runs{$field_trial_project_name}->{$drone_run_project_id}->{drone_run_phenotypes_indicator} = $drone_run_phenotypes_indicator;
        $unique_drone_runs{$field_trial_project_name}->{$drone_run_project_id}->{drone_run_project_description} = $drone_run_project_desc;
        $unique_drone_runs{$field_trial_project_name}->{$drone_run_project_id}->{drone_run_averaged_temperature_gdd} = $drone_run_averaged_temperature_gdd;
        $unique_drone_runs{$field_trial_project_name}->{$drone_run_project_id}->{drone_run_averaged_precipitation_sum} = $drone_run_averaged_precipitation_sum;
        $unique_drone_runs{$field_trial_project_name}->{$drone_run_project_id}->{drone_run_camera_rig} = $drone_run_camera_rig;
        $unique_drone_runs{$field_trial_project_name}->{$drone_run_project_id}->{drone_run_base_date} = $drone_run_base_date ? $calendar_funcs->display_start_date($drone_run_base_date) : '';
        $unique_drone_runs{$field_trial_project_name}->{$drone_run_project_id}->{drone_run_related_time_cvterm_json} = decode_json $drone_run_related_time_cvterm_json;
        $unique_drone_runs{$field_trial_project_name}->{$drone_run_project_id}->{drone_run_ground_control_points} = $drone_run_ground_control_points_json ? decode_json $drone_run_ground_control_points_json : undef;

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

    my @return;
    foreach my $trial_name (sort keys %unique_drone_runs) {
        my %unique_drone_runs_k = %{$unique_drone_runs{$trial_name}};

        my $drone_run_html = '<div class="panel-group" id="drone_runs_trial_accordion_table_wrapper_'.$trial_id_hash{$trial_name}.'" ><div class="panel panel-default"><div class="panel-heading"><div class="row"><div class="col-sm-10"><h4 class="panel-title"><a data-toggle="collapse" data-parent="#drone_runs_trial_accordion_table_wrapper_'.$trial_id_hash{$trial_name}.'" href="#drone_runs_trial_accordion_table_wrapper_one_'.$trial_id_hash{$trial_name}.'" >Field Trial: '.$trial_name.'&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;('.scalar(keys %unique_drone_runs_k).' Imaging Events)</a></h4></div><div class="col-sm-2"><button class="btn btn-sm btn-default" name="drone_runs_trial_view_timeseries" data-field_trial_name='.$trial_name.' data-field_trial_id='.$trial_id_hash{$trial_name}.'>View TimeSeries</button></div></div></div><div id="drone_runs_trial_accordion_table_wrapper_one_'.$trial_id_hash{$trial_name}.'" class="panel-collapse collapse"><div class="panel-body">';

        foreach my $epoch_seconds (sort keys %{$unique_drone_run_dates{$trial_name}}) {
            my $k = $unique_drone_run_dates{$trial_name}->{$epoch_seconds};
            my $v = $unique_drone_runs_k{$k};
            my $drone_run_bands = $v->{bands};
            my $drone_run_date = $v->{drone_run_date};

            $drone_run_html .= '<div class="panel-group" id="drone_run_band_accordion_drone_run_wrapper_'.$k.'" ><div class="panel panel-default"><div class="panel-heading"><h4 class="panel-title"><a data-toggle="collapse" data-parent="#drone_run_band_accordion_drone_run_wrapper_'.$k.'" href="#drone_run_band_accordion_drone_run_wrapper_one_'.$k.'" >'.$v->{drone_run_project_name}.'&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp'.$drone_run_date.'</a></h4></div><div id="drone_run_band_accordion_drone_run_wrapper_one_'.$k.'" class="panel-collapse collapse"><div class="panel-body">';

            $drone_run_html .= '<div class="well well-sm">';

            $drone_run_html .= '<div class="row"><div class="col-sm-6">';
            $drone_run_html .= '<div class="row"><div class="col-sm-5"><b>Imaging Event Name</b>:</div><div class="col-sm-7"><a href="/breeders_toolbox/trial/'.$k.'" _target="blank">'.$v->{drone_run_project_name}.'</a></div></div>';
            $drone_run_html .= '<div class="row"><div class="col-sm-5"><b>Imaging Event Type</b>:</div><div class="col-sm-7">'.$v->{drone_run_type}.'</div></div>';
            $drone_run_html .= '<div class="row"><div class="col-sm-5"><b>Description</b>:</div><div class="col-sm-7">'.$v->{drone_run_project_description}.'</div></div>';
            $drone_run_html .= '<div class="row"><div class="col-sm-5"><b>Date</b>:</div><div class="col-sm-7">'.$drone_run_date.'</div></div>';
            if ($v->{drone_run_base_date}) {
                $drone_run_html .= '<div class="row"><div class="col-sm-5"><b>Base Date</b>:</div><div class="col-sm-7">'.$v->{drone_run_base_date}.'</div></div>';
            }
            if ($v->{drone_run_camera_rig}) {
                $drone_run_html .= '<div class="row"><div class="col-sm-5"><b>Camera Rig</b>:</div><div class="col-sm-7">'.$v->{drone_run_camera_rig}.'</div></div>';
            }
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
            my @days_after_planting_strings = split '\|', $v->{drone_run_related_time_cvterm_json}->{day};
            my $days_after_planting_string = $days_after_planting_strings[0];
            $drone_run_html .= '<div class="row"><div class="col-sm-5"><b>Growing Season Days</b>:</div><div class="col-sm-7">'.$days_after_planting_string.'</div></div>';
            $drone_run_html .= '<div class="row"><div class="col-sm-5"><b>Field Trial</b>:</div><div class="col-sm-7"><a href="/breeders_toolbox/trial/'.$v->{trial_id}.'" _target="blank">'.$v->{trial_name}.'</a></div></div>';
            $drone_run_html .= '</div><div class="col-sm-3">';
            if ($v->{drone_run_indicator}) {
                $drone_run_html .= '<span class="label label-info" ><span class="glyphicon glyphicon-hourglass"></span>&nbsp;&nbsp;&nbsp;Processing Images in Progress</span><br/><br/>';
            }
            if ($v->{drone_run_phenotypes_indicator}) {
                $drone_run_html .= '<span class="label label-info" ><span class="glyphicon glyphicon-hourglass"></span>&nbsp;&nbsp;&nbsp;Processing Phenotypes in Progress</span><br/><br/>';
            } elsif ($v->{drone_run_processed}) {
                # $drone_run_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_phenotype_run" data-drone_run_project_id="'.$k.'" data-field_trial_id="'.$v->{trial_id}.'" data-field_trial_name="'.$v->{trial_name}.'" >Generate Phenotypes for <br/>'.$v->{drone_run_project_name}.'</button>';
            }
            #$drone_run_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_phenotype_run" data-drone_run_project_id="'.$k.'" data-field_trial_id="'.$v->{trial_id}.'" data-field_trial_name="'.$v->{trial_name}.'" >Generate Phenotypes for <br/>'.$v->{drone_run_project_name}.'</button>';

            $drone_run_html .= '</div><div class="col-sm-3">';
            if (!$v->{drone_run_indicator}) {
                # if ($v->{drone_run_is_raw_images}) {
                #     $drone_run_html .= '<button class="btn btn-default btn-sm" name="project_drone_imagery_stadard_process_raw_images_add_images" data-drone_run_project_id="'.$k.'" data-field_trial_id="'.$v->{trial_id}.'" data-field_trial_name="'.$v->{trial_name}.'" >Upload More Raw Images <br/>'.$v->{drone_run_project_name}.'</button><br/><br/>';
                #
                #     #$drone_run_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_standard_process_raw_images" data-drone_run_project_id="'.$k.'" data-drone_run_project_name="'.$v->{drone_run_project_name}.'" data-field_trial_id="'.$v->{trial_id}.'" data-field_trial_name="'.$v->{trial_name}.'" >Run Raw Image Standard Process For<br/>'.$v->{drone_run_project_name}.'</button><br/><br/>';
                #
                #     $drone_run_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_standard_process_raw_images_interactive" data-drone_run_project_id="'.$k.'" data-drone_run_project_name="'.$v->{drone_run_project_name}.'" data-field_trial_id="'.$v->{trial_id}.'" data-field_trial_name="'.$v->{trial_name}.'" >Run Interactive Raw Image Standard Process For<br/>'.$v->{drone_run_project_name}.'</button><br/><br/>';
                #
                #     $drone_run_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_phenotype_run" data-drone_run_project_id="'.$k.'" data-field_trial_id="'.$v->{trial_id}.'" data-field_trial_name="'.$v->{trial_name}.'" >Generate Phenotypes for <br/>'.$v->{drone_run_project_name}.'</button><br/><br/>';
                # }
                # else {
                    if (!$v->{drone_run_processed}) {
                        $drone_run_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_standard_process" data-drone_run_project_id="'.$k.'" data-drone_run_project_name="'.$v->{drone_run_project_name}.'" data-field_trial_id="'.$v->{trial_id}.'" data-field_trial_name="'.$v->{trial_name}.'" >Run Standard Process For<br/>'.$v->{drone_run_project_name}.'</button><br/><br/>';
                    } elsif (!$v->{drone_run_processed_minimal_vi}) {
                        $drone_run_html .= '<button class="btn btn-default btn-sm" name="project_drone_imagery_standard_process_minimal_vi" data-drone_run_project_id="'.$k.'" data-drone_run_project_name="'.$v->{drone_run_project_name}.'" data-field_trial_id="'.$v->{trial_id}.'" data-field_trial_name="'.$v->{trial_name}.'" >Run Minimal Vegetitative Index Standard Process For<br/>'.$v->{drone_run_project_name}.'</button><br/><br/>';
                    } elsif (!$v->{drone_run_processed_extended}) {
                        #$drone_run_html .= '<button class="btn btn-default btn-sm" name="project_drone_imagery_standard_process_extended" data-drone_run_project_id="'.$k.'" data-drone_run_project_name="'.$v->{drone_run_project_name}.'" data-field_trial_id="'.$v->{trial_id}.'" data-field_trial_name="'.$v->{trial_name}.'" >Run Extended Standard Process For<br/>'.$v->{drone_run_project_name}.'</button><br/><br/>';
                    }

                    # if ($v->{drone_run_processed} && !$v->{drone_run_ground_control_points}) {
                    if ($v->{drone_run_processed}) {
                        $drone_run_html .= '<button class="btn btn-default btn-sm" name="project_drone_imagery_ground_control_points" data-drone_run_project_id="'.$k.'" data-drone_run_project_name="'.$v->{drone_run_project_name}.'" data-field_trial_id="'.$v->{trial_id}.'" data-field_trial_name="'.$v->{trial_name}.'" >Save Ground Control Points For<br/>'.$v->{drone_run_project_name}.'</button><br/><br/>';
                    }
                # }
            }
            $drone_run_html .= '<button class="btn btn-default btn-sm" name="project_drone_imagery_quality_control_check" data-drone_run_project_id="'.$k.'" data-drone_run_project_name="'.$v->{drone_run_project_name}.'" data-field_trial_id="'.$v->{trial_id}.'" data-field_trial_name="'.$v->{trial_name}.'" >Quality Control Plot Images For<br/>'.$v->{drone_run_project_name}.'</button><br/><br/>';

            $drone_run_html .= '<button class="btn btn-danger btn-sm" name="project_drone_imagery_delete_drone_run" data-drone_run_project_id="'.$k.'" data-drone_run_project_name="'.$v->{drone_run_project_name}.'" >Delete Imaging Event</button>';

            $drone_run_html .= '</div></div></div>';

            $drone_run_html .= "<hr>";

            $drone_run_html .= '<div name="drone_run_band_total_plot_image_div" id="drone_run_band_total_plot_image_count_div_'.$k.'">';
            $drone_run_html .= '<div class="panel-group"><div class="panel panel-default panel-sm"><div class="panel-heading"><h4 class="panel-title"><a data-toggle="collapse" >Loading Plot Image Summary...</a></h4></div></div></div>';
            $drone_run_html .= '</div>';

            my $drone_run_band_table_html = '<table class="table table-bordered"><thead><tr><th>Image Band(s)</th><th>Images/Actions</th></thead><tbody>';

            foreach my $drone_run_band_project_id (sort keys %$drone_run_bands) {
                my $d = $drone_run_bands->{$drone_run_band_project_id};

                $drone_run_band_table_html .= '<tr><td><b>Name</b>: '.$d->{drone_run_band_project_name}.'<br/><b>Description</b>: '.$d->{drone_run_band_project_description}.'<br/><b>Type</b>: '.$d->{drone_run_band_project_type}.'</td><td>';

                $drone_run_band_table_html .= '<div class="panel-group" id="drone_run_band_accordion_'.$drone_run_band_project_id.'" ><div class="panel panel-default"><div class="panel-heading"><h4 class="panel-title"><a data-toggle="collapse" data-parent="#drone_run_band_accordion_'.$drone_run_band_project_id.'" href="#drone_run_band_accordion_one_'.$drone_run_band_project_id.'" onclick="manageDroneImageryDroneRunBandDisplay('.$drone_run_band_project_id.')">View Images</a></h4></div><div id="drone_run_band_accordion_one_'.$drone_run_band_project_id.'" class="panel-collapse collapse"><div class="panel-body">';

                $drone_run_band_table_html .= '<div id="drone_run_band_accordian_drone_run_band_div_'.$drone_run_band_project_id.'"></div>';

                $drone_run_band_table_html .= '</div></div></div></div>';
                $drone_run_band_table_html .= '</td></tr>';

            }
            $drone_run_band_table_html .= '</tbody></table>';

            $drone_run_html .= $drone_run_band_table_html;

            # $drone_run_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_merge_channels" data-drone_run_project_id="'.$k.'" data-drone_run_project_name="'.$v->{drone_run_project_name}.'" >Merge Drone Run Bands For '.$v->{drone_run_project_name}.'</button><br/><br/>';

            $drone_run_html .= '</div></div></div></div>';

            $drone_run_html .= '<br/>';
        }
        $drone_run_html .= '</div></div></div></div>';

        push @return, [$drone_run_html];
    }

    $c->stash->{rest} = { data => \@return };
}

sub raw_drone_imagery_drone_run_band_summary : Path('/api/drone_imagery/raw_drone_imagery_drone_run_band') : ActionClass('REST') { }
sub raw_drone_imagery_drone_run_band_summary_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $drone_run_band_project_id = $c->req->param('drone_run_band_project_id');
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $calendar_funcs = CXGN::Calendar->new({});

    my $main_image_types = CXGN::DroneImagery::ImageTypes::get_all_project_md_image_types_whole_images($schema);
    my @main_image_types_array = keys %$main_image_types;
    my $images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        drone_run_band_project_id_list=>[$drone_run_band_project_id],
        project_image_type_id_list=>\@main_image_types_array
    });
    my ($result, $total_count) = $images_search->search();
    #print STDERR Dumper $result;

    my $observation_unit_plot_polygon_types = CXGN::DroneImagery::ImageTypes::get_all_project_md_image_observation_unit_plot_polygon_types($schema);
    my $observation_unit_plot_polygon_type_names;
    while (my ($k, $v) = each %$observation_unit_plot_polygon_types) {
        $observation_unit_plot_polygon_type_names->{$v->{name}} = $v->{display_name};
    }

    my @observation_unit_plot_polygon_types_array = keys %$observation_unit_plot_polygon_types;
    my $observation_unit_polygon_imagery_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        drone_run_band_project_id_list=>[$drone_run_band_project_id],
        project_image_type_id_list=>\@observation_unit_plot_polygon_types_array
    });
    my ($observation_unit_polygon_result, $observation_unit_polygon_total_count) = $observation_unit_polygon_imagery_search->search();
    #print STDERR Dumper $observation_unit_polygon_result;

    my %original_background_removed_threshold_terms = (
        'threshold_background_removed_stitched_drone_imagery_blue' => 'Blue (450-520nm)',
        'threshold_background_removed_stitched_drone_imagery_green' => 'Green (515-600nm)',
        'threshold_background_removed_stitched_drone_imagery_red' => 'Red (600-690nm)',
        'threshold_background_removed_stitched_drone_imagery_red_edge' => 'Red Edge (690-750nm)',
        'threshold_background_removed_stitched_drone_imagery_nir' => 'NIR (780-3000nm)',
        'threshold_background_removed_stitched_drone_imagery_mir' => 'MIR (3000-50000nm)',
        'threshold_background_removed_stitched_drone_imagery_fir' => 'FIR (50000-1000000nm)',
        'threshold_background_removed_stitched_drone_imagery_tir' => 'Thermal IR (9000-14000nm)',
        'threshold_background_removed_stitched_drone_imagery_bw' => 'Black and White Image',
        'threshold_background_removed_stitched_drone_imagery_rgb_channel_1' => 'RGB Color Image',
        'threshold_background_removed_stitched_drone_imagery_rgb_channel_2' => 'RGB Color Image',
        'threshold_background_removed_stitched_drone_imagery_rgb_channel_3' => 'RGB Color Image',
    );

    my %original_denoised_observation_unit_polygon_terms = (
        'Blue (450-520nm)' => ['observation_unit_polygon_blue_imagery'],
        'Green (515-600nm)' => ['observation_unit_polygon_green_imagery'],
        'Red (600-690nm)' => ['observation_unit_polygon_red_imagery'],
        'Red Edge (690-750nm)' => ['observation_unit_polygon_red_edge_imagery'],
        'NIR (780-3000nm)' => ['observation_unit_polygon_nir_imagery'],
        'MIR (3000-50000nm)' => ['observation_unit_polygon_mir_imagery'],
        'FIR (50000-1000000nm)' => ['observation_unit_polygon_fir_imagery'],
        'Thermal IR (9000-14000nm)' => ['observation_unit_polygon_tir_imagery'],
        'Black and White Image' => ['observation_unit_polygon_bw_imagery'],
        'RGB Color Image' => ['observation_unit_polygon_rgb_imagery', 'observation_unit_polygon_rgb_imagery_channel_1', 'observation_unit_polygon_rgb_imagery_channel_2', 'observation_unit_polygon_rgb_imagery_channel_3'],
        'Merged 3 Bands BGR' => ['observation_unit_polygon_rgb_imagery'],
        'Merged 3 Bands NRN' => ['observation_unit_polygon_nrn_imagery'],
        'Merged 3 Bands NReN' => ['observation_unit_polygon_nren_imagery']
    );

    my $imagery_attribute_map = CXGN::DroneImagery::ImageTypes::get_imagery_attribute_map();
    my $original_denoised_imagery_terms = CXGN::DroneImagery::ImageTypes::get_base_imagery_observation_unit_plot_polygon_term_map();
    my $vi_map_hash = CXGN::DroneImagery::ImageTypes::get_vegetative_index_image_type_term_map();

    my @return;
    my %unique_drone_runs;
    foreach (@$result) {
        my $image_id = $_->{image_id};
        my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
        my $image_source_tag_tiny = $image->get_img_src_tag("tiny");
        my $image_source_tag_small = $image->get_img_src_tag("thumbnail");
        my $image_original = $image->get_image_url("original");
        if ($_->{project_image_type_name} eq 'raw_drone_imagery') {
            push @{$unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{images}}, '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_tiny.'</a>';
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{usernames}->{$_->{username}}++;
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{drone_run_band_project_name} = $_->{drone_run_band_project_name};
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{drone_run_band_project_description} = $_->{drone_run_band_project_description};
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{drone_run_band_project_type} = $_->{drone_run_band_project_type};
            $unique_drone_runs{$_->{drone_run_project_id}}->{trial_id} = $_->{trial_id};
            $unique_drone_runs{$_->{drone_run_project_id}}->{trial_name} = $_->{trial_name};
            $unique_drone_runs{$_->{drone_run_project_id}}->{drone_run_project_name} = $_->{drone_run_project_name};
            $unique_drone_runs{$_->{drone_run_project_id}}->{drone_run_date} = $_->{drone_run_date};
            $unique_drone_runs{$_->{drone_run_project_id}}->{drone_run_type} = $_->{drone_run_type};
            $unique_drone_runs{$_->{drone_run_project_id}}->{drone_run_project_description} = $_->{drone_run_project_description};
        }
        elsif ($_->{project_image_type_name} eq 'stitched_drone_imagery') {
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{stitched_image} = '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_small.'</a>';
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{stitched_image_username} = $_->{username};
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{stitched_image_modified_date} = $_->{image_modified_date};
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{stitched_image_original} = $image_original;
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{stitched_image_id} = $image_id;
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{drone_run_band_project_name} = $_->{drone_run_band_project_name};
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{drone_run_band_project_description} = $_->{drone_run_band_project_description};
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{drone_run_band_project_type} = $_->{drone_run_band_project_type};
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{usernames}->{$_->{username}}++;
            $unique_drone_runs{$_->{drone_run_project_id}}->{trial_id} = $_->{trial_id};
            $unique_drone_runs{$_->{drone_run_project_id}}->{trial_name} = $_->{trial_name};
            $unique_drone_runs{$_->{drone_run_project_id}}->{drone_run_project_name} = $_->{drone_run_project_name};
            $unique_drone_runs{$_->{drone_run_project_id}}->{drone_run_date} = $_->{drone_run_date};
            $unique_drone_runs{$_->{drone_run_project_id}}->{drone_run_type} = $_->{drone_run_type};
            $unique_drone_runs{$_->{drone_run_project_id}}->{drone_run_project_description} = $_->{drone_run_project_description};
        }
        else {
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{$_->{project_image_type_name}} = '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_small.'</a>';
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{$_->{project_image_type_name}."_username"} = $_->{username};
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{$_->{project_image_type_name}."_modified_date"} = $_->{image_modified_date};
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{$_->{project_image_type_name}."_original"} = $image_original;
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{$_->{project_image_type_name}."_id"} = $image_id;
            if (exists($imagery_attribute_map->{$_->{project_image_type_name}})) {
                $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{$_->{project_image_type_name}."_".$imagery_attribute_map->{$_->{project_image_type_name}}->{name}} = $_->{$imagery_attribute_map->{$_->{project_image_type_name}}->{key}};
            }
        }
    }

    foreach (@$observation_unit_polygon_result) {
        my $image_id = $_->{image_id};
        my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
        my $image_source_tag_tiny = $image->get_img_src_tag("tiny");
        my $image_original = $image->get_image_url("original");
        $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{$_->{project_image_type_name}."_polygons"} = $_->{drone_run_band_plot_polygons};
        push @{$unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{$_->{project_image_type_name}."_images"}}, '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_tiny.'</a>';
    }

    # print STDERR Dumper \%unique_drone_runs;

    foreach my $k (sort keys %unique_drone_runs) {
        my $v = $unique_drone_runs{$k};

        my $drone_run_bands = $v->{bands};

        my $drone_run_band_table_html = '';

        foreach my $drone_run_band_project_id (sort keys %$drone_run_bands) {
            my $d = $drone_run_bands->{$drone_run_band_project_id};

            # If raw images were uploaded and orthomosaic will not be used.
            if ($d->{images}) {
                $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-6"><h5>Raw Images</h5></div><div class="col-sm-6">';
                foreach (@{$d->{images}}) {
                    $drone_run_band_table_html .= $_;
                }
                $drone_run_band_table_html .= '</div></div></div>';

                foreach my $t (@{$original_denoised_imagery_terms->{$d->{drone_run_band_project_type}}->{observation_unit_plot_polygon_types}->{base}}) {
                    if ($d->{$t."_images"}) {
                        $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-6"><h5>Assigned Plot-Polygon Images</h5></div><div class="col-sm-6">';
                        foreach (@{$d->{$t."_images"}}) {
                            $drone_run_band_table_html .= $_;
                        }
                        $drone_run_band_table_html .= '</div></div></div>';
                    }
                }
            }

            # If orthomosaic was uploaded or stitched by ImageBreed on upload of raw images.
            if ($d->{stitched_image}) {
                $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-6"><h5>Stitched Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{stitched_image_id}.'"></span></h5><b>By</b>: '.$d->{stitched_image_username}.'<br/><b>Date</b>: '.$d->{stitched_image_modified_date}.'</div><div class="col-sm-6">'.$d->{stitched_image}.'</div></div></div>';

                if ($d->{rotated_stitched_drone_imagery}) {
                    $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-6"><h5>Rotated Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{rotated_stitched_drone_imagery_id}.'"></span></h5><b>By</b>: '.$d->{rotated_stitched_drone_imagery_username}.'<br/><b>Date</b>: '.$d->{rotated_stitched_drone_imagery_modified_date}.'<br/><b>Rotated Angle</b>: '.$d->{rotated_stitched_drone_imagery_angle}.'</div><div class="col-sm-6">'.$d->{rotated_stitched_drone_imagery}.'</div></div></div>';

                    if ($d->{cropped_stitched_drone_imagery}) {
                        $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-6"><h5>Cropped Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{cropped_stitched_drone_imagery_id}.'"></span></h5><b>By</b>: '.$d->{cropped_stitched_drone_imagery_username}.'<br/><b>Date</b>: '.$d->{cropped_stitched_drone_imagery_modified_date}.'<br/><b>Cropped Polygon</b>: '.$d->{cropped_stitched_drone_imagery_polygon}.'</div><div class="col-sm-6">'.$d->{cropped_stitched_drone_imagery}.'</div></div></div>';

                        if ($d->{denoised_stitched_drone_imagery}) {
                            $drone_run_band_table_html .= _draw_drone_imagery_section($observation_unit_plot_polygon_type_names, $d, $d->{denoised_stitched_drone_imagery_id}, $d->{denoised_stitched_drone_imagery_username}, $d->{denoised_stitched_drone_imagery_modified_date}, undef, $d->{denoised_stitched_drone_imagery}, $original_denoised_observation_unit_polygon_terms{$d->{drone_run_band_project_type}}, $d->{stitched_image_id}, $d->{cropped_stitched_drone_imagery_id}, $d->{denoised_stitched_drone_imagery_id}, $v->{trial_id}, uri_encode($d->{stitched_image_original}), $drone_run_band_project_id, $d->{drone_run_band_project_type}, $k, $d->{denoised_stitched_drone_imagery_id}, $v->{drone_run_project_name});

                            # $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_add_georeference" data-stitched_image_id="'.$d->{stitched_image_id}.'" data-cropped_stitched_image_id="'.$d->{cropped_stitched_drone_imagery_id}.'" data-denoised_stitched_image_id="'.$d->{denoised_stitched_drone_imagery_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" >Add Georeferenced Points</button><br/><br/>';

                            foreach my $original_background_removed_threshold_term (keys %original_background_removed_threshold_terms) {
                                my $plot_polygon_type = $imagery_attribute_map->{$original_background_removed_threshold_term}->{observation_unit_plot_polygon_type};
                                if (exists($d->{$original_background_removed_threshold_term})) {
                                    $drone_run_band_table_html .= _draw_drone_imagery_section($observation_unit_plot_polygon_type_names, $d, $d->{$original_background_removed_threshold_term."_id"}, $d->{$original_background_removed_threshold_term."_username"}, $d->{$original_background_removed_threshold_term."_modified_date"}, $d->{$original_background_removed_threshold_term."_threshold"}, $d->{$original_background_removed_threshold_term}, [$plot_polygon_type], $d->{stitched_image_id}, $d->{cropped_stitched_drone_imagery_id}, $d->{denoised_stitched_drone_imagery_id}, $v->{trial_id}, uri_encode($d->{stitched_image_original}), $drone_run_band_project_id, $d->{drone_run_band_project_type}, $k, $d->{$original_background_removed_threshold_term."_id"}, $v->{drone_run_project_name});
                                } else {
                                    if ($d->{drone_run_band_project_type} eq $original_background_removed_threshold_terms{$original_background_removed_threshold_term}) {
                                    #     $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_remove_background" data-denoised_stitched_image_id="'.$d->{denoised_stitched_drone_imagery_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-denoised_stitched_image="'.uri_encode($d->{denoised_stitched_drone_imagery_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-remove_background_current_image_id="'.$d->{denoised_stitched_drone_imagery_id}.'" data-remove_background_current_image_type="'.$original_background_removed_threshold_term.'" >Remove Background From Original Denoised Image via Threshold</button><br/><br/>';
                                        # $drone_run_band_table_html .= '<button class="btn btn-default btn-sm disabled">Imagery of type '.$original_background_removed_threshold_term.' and subsequently plot polygons of type '.$plot_polygon_type.' are not found. The standard process should have covered all supported image cases. Please try again or contact us.</button><br/><br/>';
                                    }
                                }
                            }

                            foreach my $ft_hpf_denoised_original_image_type_filter (keys %{$original_denoised_imagery_terms->{$d->{drone_run_band_project_type}}->{imagery_types}->{ft_hpf}}) {
                                my $ft_hpf30_denoised_imagery_type_counter = 0;
                                foreach my $ft_hpf30_denoised_original_image_type (@{$original_denoised_imagery_terms->{$d->{drone_run_band_project_type}}->{imagery_types}->{ft_hpf}->{$ft_hpf_denoised_original_image_type_filter}}) {
                                    my $ft_hpf30_denoised_plot_polygon_type = $original_denoised_imagery_terms->{$d->{drone_run_band_project_type}}->{observation_unit_plot_polygon_types}->{ft_hpf}->{$ft_hpf_denoised_original_image_type_filter}->[$ft_hpf30_denoised_imagery_type_counter];
                                    if ($d->{$ft_hpf30_denoised_original_image_type}) {
                                        $drone_run_band_table_html .= _draw_drone_imagery_section($observation_unit_plot_polygon_type_names, $d, $d->{$ft_hpf30_denoised_original_image_type."_id"}, $d->{$ft_hpf30_denoised_original_image_type."_username"}, $d->{$ft_hpf30_denoised_original_image_type."_modified_date"}, undef, $d->{$ft_hpf30_denoised_original_image_type}, [$ft_hpf30_denoised_plot_polygon_type], $d->{stitched_image_id}, $d->{cropped_stitched_drone_imagery_id}, $d->{denoised_stitched_drone_imagery_id}, $v->{trial_id}, uri_encode($d->{stitched_image_original}), $drone_run_band_project_id, $d->{drone_run_band_project_type}, $k, $d->{$ft_hpf30_denoised_original_image_type.'_id'}, $v->{drone_run_project_name});
                                    } else {
                                        #$drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_fourier_transform_hpf30" data-image_id="'.$d->{denoised_stitched_drone_imagery_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'", data-selected_image_type="'.$ft_hpf30_denoised_original_image_type.'" >Run Fourier Transform HPF30 ('.$ft_hpf30_denoised_original_image_type.')</button><br/><br/>';
                                        # $drone_run_band_table_html .= '<button class="btn btn-default btn-sm disabled">Imagery of type '.$ft_hpf30_denoised_original_image_type.' and subsequently plot polygons of type '.$ft_hpf30_denoised_plot_polygon_type.' are not found. The standard process should have covered all supported image cases. Please try again or contact us.</button><br/><br/>';
                                    }
                                    $ft_hpf30_denoised_imagery_type_counter++;
                                }
                            }

                            if ($d->{drone_run_band_project_type} eq 'RGB Color Image' || $d->{drone_run_band_project_type} eq 'Merged 3 Bands BGR' || $d->{drone_run_band_project_type} eq 'Merged 3 Bands NRN' || $d->{drone_run_band_project_type} eq 'Merged 3 Bands NReN') {
                                if ($d->{drone_run_band_project_type} eq 'RGB Color Image') {
                                    # $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_rgb_vegetative" data-denoised_stitched_image_id="'.$d->{denoised_stitched_drone_imagery_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-denoised_stitched_image="'.uri_encode($d->{denoised_stitched_drone_imagery_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'">Convert to Vegetative Index</button><br/><br/>';
                                }
                                elsif ($d->{drone_run_band_project_type} eq 'Merged 3 Bands BGR') {
                                    # $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_3_band_bgr_vegetative" data-denoised_stitched_image_id="'.$d->{denoised_stitched_drone_imagery_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-denoised_stitched_image="'.uri_encode($d->{denoised_stitched_drone_imagery_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'">Convert to Vegetative Index</button><br/><br/>';
                                }
                                elsif ($d->{drone_run_band_project_type} eq 'Merged 3 Bands NRN') {
                                    # $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_3_band_nrn_vegetative" data-denoised_stitched_image_id="'.$d->{denoised_stitched_drone_imagery_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-denoised_stitched_image="'.uri_encode($d->{denoised_stitched_drone_imagery_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'">Convert to Vegetative Index</button><br/><br/>';

                                    foreach my $imagery_term (sort keys %{$vi_map_hash->{NDVI}}) {
                                        while (my ($image_type_term, $observation_unit_plot_polygon_types) = each %{$vi_map_hash->{NDVI}->{$imagery_term}}) {
                                            foreach my $observation_unit_plot_polygon_type (@$observation_unit_plot_polygon_types) {
                                                if ($d->{$image_type_term}) {
                                                    $drone_run_band_table_html .= _draw_drone_imagery_section($observation_unit_plot_polygon_type_names, $d, $d->{$image_type_term."_id"}, $d->{$image_type_term."_username"}, $d->{$image_type_term."_modified_date"}, undef, $d->{$image_type_term}, [$observation_unit_plot_polygon_type], $d->{stitched_image_id}, $d->{cropped_stitched_drone_imagery_id}, $d->{denoised_stitched_drone_imagery_id}, $v->{trial_id}, uri_encode($d->{stitched_image_original}), $drone_run_band_project_id, $d->{drone_run_band_project_type}, $k, $d->{$image_type_term.'_id'}, $v->{drone_run_project_name});
                                                } else {
                                                    # $drone_run_band_table_html .= '<button class="btn btn-default btn-sm disabled">Imagery of type '.$image_type_term.' and subsequently plot polygons of type '.$observation_unit_plot_polygon_type.' are not found. The standard process should have covered all supported image cases. Please try again or contact us.</button><br/><br/>';
                                                }
                                            }
                                        }
                                    }
                                }
                                elsif ($d->{drone_run_band_project_type} eq 'Merged 3 Bands NReN') {
                                    # $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_3_band_nren_vegetative" data-denoised_stitched_image_id="'.$d->{denoised_stitched_drone_imagery_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-denoised_stitched_image="'.uri_encode($d->{denoised_stitched_drone_imagery_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'">Convert to Vegetative Index</button><br/><br/>';

                                    foreach my $imagery_term (sort keys %{$vi_map_hash->{NDRE}}) {
                                        while (my ($image_type_term, $observation_unit_plot_polygon_types) = each %{$vi_map_hash->{NDRE}->{$imagery_term}}) {
                                            foreach my $observation_unit_plot_polygon_type (@$observation_unit_plot_polygon_types) {
                                                if ($d->{$image_type_term}) {
                                                    $drone_run_band_table_html .= _draw_drone_imagery_section($observation_unit_plot_polygon_type_names, $d, $d->{$image_type_term."_id"}, $d->{$image_type_term."_username"}, $d->{$image_type_term."_modified_date"}, undef, $d->{$image_type_term}, [$observation_unit_plot_polygon_type], $d->{stitched_image_id}, $d->{cropped_stitched_drone_imagery_id}, $d->{denoised_stitched_drone_imagery_id}, $v->{trial_id}, uri_encode($d->{stitched_image_original}), $drone_run_band_project_id, $d->{drone_run_band_project_type}, $k, $d->{$image_type_term.'_id'}, $v->{drone_run_project_name});
                                                } else {
                                                    # $drone_run_band_table_html .= '<button class="btn btn-default btn-sm disabled">Imagery of type '.$image_type_term.' and subsequently plot polygons of type '.$observation_unit_plot_polygon_type.' are not found. The standard process should have covered all supported image cases. Please try again or contact us.</button><br/><br/>';
                                                }
                                            }
                                        }
                                    }
                                }

                                if ($d->{drone_run_band_project_type} eq 'RGB Color Image' || $d->{drone_run_band_project_type} eq 'Merged 3 Bands BGR') {
                                    foreach my $imagery_term (sort keys %{$vi_map_hash->{TGI}}) {
                                        while (my ($image_type_term, $observation_unit_plot_polygon_types) = each %{$vi_map_hash->{TGI}->{$imagery_term}}) {
                                            foreach my $observation_unit_plot_polygon_type (@$observation_unit_plot_polygon_types) {
                                                if ($d->{$image_type_term}) {
                                                    $drone_run_band_table_html .= _draw_drone_imagery_section($observation_unit_plot_polygon_type_names, $d, $d->{$image_type_term."_id"}, $d->{$image_type_term."_username"}, $d->{$image_type_term."_modified_date"}, undef, $d->{$image_type_term}, [$observation_unit_plot_polygon_type], $d->{stitched_image_id}, $d->{cropped_stitched_drone_imagery_id}, $d->{denoised_stitched_drone_imagery_id}, $v->{trial_id}, uri_encode($d->{stitched_image_original}), $drone_run_band_project_id, $d->{drone_run_band_project_type}, $k, $d->{$image_type_term.'_id'}, $v->{drone_run_project_name});
                                                } else {
                                                    # $drone_run_band_table_html .= '<button class="btn btn-default btn-sm disabled">Imagery of type '.$image_type_term.' and subsequently plot polygons of type '.$observation_unit_plot_polygon_type.' are not found. The standard process should have covered all supported image cases. Please try again or contact us.</button><br/><br/>';
                                                }
                                            }
                                        }
                                    }
                                    foreach my $imagery_term (sort keys %{$vi_map_hash->{VARI}}) {
                                        while (my ($image_type_term, $observation_unit_plot_polygon_types) = each %{$vi_map_hash->{VARI}->{$imagery_term}}) {
                                            foreach my $observation_unit_plot_polygon_type (@$observation_unit_plot_polygon_types) {
                                                if ($d->{$image_type_term}) {
                                                    $drone_run_band_table_html .= _draw_drone_imagery_section($observation_unit_plot_polygon_type_names, $d, $d->{$image_type_term."_id"}, $d->{$image_type_term."_username"}, $d->{$image_type_term."_modified_date"}, undef, $d->{$image_type_term}, [$observation_unit_plot_polygon_type], $d->{stitched_image_id}, $d->{cropped_stitched_drone_imagery_id}, $d->{denoised_stitched_drone_imagery_id}, $v->{trial_id}, uri_encode($d->{stitched_image_original}), $drone_run_band_project_id, $d->{drone_run_band_project_type}, $k, $d->{$image_type_term.'_id'}, $v->{drone_run_project_name});
                                                } else {
                                                    # $drone_run_band_table_html .= '<button class="btn btn-default btn-sm disabled">Imagery of type '.$image_type_term.' and subsequently plot polygons of type '.$observation_unit_plot_polygon_type.' are not found. The standard process should have covered all supported image cases. Please contact try again or us.</button><br/><br/>';
                                                }
                                            }
                                        }
                                    }
                                }
                            } else {
                                $drone_run_band_table_html .= '<button class="btn btn-default btn-sm disabled">Vegetative index cannot be calculated on an image with a single channel.<br/>You can merge bands into a multi-channel image using the "Merge Drone Run Bands" button below this table.<br/>If the standard process was run and vegetative indices were selected, merged images should appear at the bottom of this table.</button><br/><br/>';
                            }
                        } else {
                            #$drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_denoise" data-cropped_stitched_image_id="'.$d->{cropped_stitched_drone_imagery_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-cropped_stitched_image="'.uri_encode($d->{cropped_stitched_drone_imagery_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" >Denoise</button><br/><br/>';
                            $drone_run_band_table_html .= '<button class="btn btn-default btn-sm disabled">Denoised imagery not found. The standard process should have covered all supported image cases. Please try again or contact us.</button><br/><br/>';
                        }
                    } else {
                        #$drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_crop_image" data-rotated_stitched_image_id="'.$d->{rotated_stitched_drone_imagery_id}.'" data-stitched_image_id="'.$d->{stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" >Crop Rotated Image</button><br/><br/>';
                        $drone_run_band_table_html .= '<button class="btn btn-default btn-sm disabled">Cropped imagery not found. The standard process should have covered all supported image cases. Please try again or contact us.</button><br/><br/>';
                    }
                } else {
                    #$drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_rotate_image" data-stitched_image_id="'.$d->{stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" >Rotate Stitched Image</button><br/><br/>';
                    $drone_run_band_table_html .= '<button class="btn btn-default btn-sm disabled">Rotated imagery not found. The standard process should have covered all supported image cases. Please try again or contact us.</button><br/><br/>';
                }
            } else {
                # $drone_run_band_table_html .= '<button class="btn btn-default btn-sm disabled">Please upload previously stitched imagery. We do not support unstitched imagery at this time. Please try again or contact us.</button><br/><br/>';
            }


        }

        push @return, [$drone_run_band_table_html];
    }

    $c->stash->{rest} = { data => \@return };
}

sub _draw_drone_imagery_section {
    my $observation_unit_plot_polygon_type_names = shift;
    my $d = shift;
    my $imagery_id = shift;
    my $imagery_username = shift;
    my $imagery_modified_date = shift;
    my $threshold_value = shift;
    my $imagery = shift;
    my $plot_polygon_terms = shift;
    my $stitched_image_id = shift;
    my $cropped_stitched_drone_imagery_id = shift;
    my $denoised_stitched_drone_imagery_id = shift;
    my $trial_id = shift;
    my $stitched_image_original_uri_encoded = shift;
    my $drone_run_band_project_id = shift;
    my $drone_run_band_project_type = shift;
    my $drone_run_project_id = shift;
    my $plot_polygon_background_to_use_image_id = shift;
    my $drone_run_project_name = shift;

    my $html .= '<div class="well well-sm"><h5>'.$observation_unit_plot_polygon_type_names->{$plot_polygon_terms->[0]}.'&nbsp;&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$imagery_id.'"></span></h5><div class="row"><div class="col-sm-3"><b>By</b>: '.$imagery_username.'</br><b>Date</b>: '.$imagery_modified_date;
    if ($threshold_value) {
        $html .= '<br/><b>Threshold Value</b>: '.$threshold_value;
    }
    $html .= '<hr>'.$imagery.'</div><div class="col-sm-9">';

    foreach my $plot_polygon_term (@$plot_polygon_terms) {
        $html .= _draw_plot_polygon_images_panel($d, $stitched_image_id, $cropped_stitched_drone_imagery_id, $denoised_stitched_drone_imagery_id, $trial_id, $stitched_image_original_uri_encoded, $drone_run_band_project_id, $plot_polygon_term, $drone_run_band_project_type, $drone_run_project_id, $plot_polygon_background_to_use_image_id, $drone_run_project_name);
    }

    $html .= '</div></div></div>';
    return $html;
}

sub _draw_plot_polygon_images_panel {
    my $d = shift;
    my $stitched_image_id = shift;
    my $cropped_stitched_drone_imagery_id = shift;
    my $denoised_stitched_drone_imagery_id = shift;
    my $trial_id = shift;
    my $stitched_image_original_uri_encoded = shift;
    my $drone_run_band_project_id = shift;
    my $plot_polygon_term = shift;
    my $drone_run_band_project_type = shift;
    my $drone_run_project_id = shift;
    my $plot_polygon_background_to_use_image_id = shift;
    my $drone_run_project_name = shift;

    my $html .= '<div class="panel panel-default panel-sm"><div class="panel-body" style="overflow-x:auto">';
        $html .= '<button class="btn btn-default btn-sm" name="project_drone_imagery_plot_polygons" data-stitched_image_id="'.$stitched_image_id.'" data-cropped_stitched_image_id="'.$cropped_stitched_drone_imagery_id.'" data-denoised_stitched_image_id="'.$denoised_stitched_drone_imagery_id.'" data-field_trial_id="'.$trial_id.'" data-stitched_image="'.$stitched_image_original_uri_encoded.'" data-drone_run_project_id="'.$drone_run_project_id.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-background_removed_stitched_image_id="'.$plot_polygon_background_to_use_image_id.'" data-assign_plot_polygons_type="'.$plot_polygon_term.'" data-drone_run_project_name="'.$drone_run_project_name.'" >Create/View Plot Polygons</button><br/><br/>';

        my $plot_polygon_images = '';
        if ($d->{$plot_polygon_term."_images"}) {
            $plot_polygon_images = scalar(@{$d->{$plot_polygon_term."_images"}})." Plot Polygons<br/><span>";
            $plot_polygon_images .= join '', @{$d->{$plot_polygon_term."_images"}};
            $plot_polygon_images .= "</span>";
            # $html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_get_phenotypes" data-field_trial_id="'.$trial_id.'" data-drone_run_project_id="'.$drone_run_project_id.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$drone_run_band_project_type.'" data-plot_polygons_type="'.$plot_polygon_term.'" >Calculate Phenotypes</button><br/><br/>';
        } else {
            $plot_polygon_images = 'No Plot Polygons Assigned';
        }
        $html .= $plot_polygon_images;
    $html .= '</div></div>';
    return $html;
}

1;
