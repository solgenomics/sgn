
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
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
);

sub raw_drone_imagery_summary : Path('/api/drone_imagery/raw_drone_imagery') : ActionClass('REST') { }
sub raw_drone_imagery_summary_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $raw_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'raw_drone_imagery', 'project_md_image')->cvterm_id();
    my $stitched_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stitched_drone_imagery', 'project_md_image')->cvterm_id();

    my $images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        project_image_type_id_list=>[
            $raw_drone_images_cvterm_id,
            $stitched_drone_images_cvterm_id
        ]
    });
    my ($result, $total_count) = $images_search->search();
    #print STDERR Dumper $result;

    my @return;
    my %unique_drone_runs;
    my %trial_id_hash;
    foreach (@$result) {
        my $image_id = $_->{image_id};
        my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
        my $image_source_tag_tiny = $image->get_img_src_tag("tiny");
        my $image_source_tag_small = $image->get_img_src_tag("thumbnail");
        my $image_original = $image->get_image_url("original");
        if ($_->{project_image_type_name} eq 'raw_drone_imagery') {
            push @{$unique_drone_runs{$_->{trial_name}}->{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{images}}, '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_tiny.'</a>';
            $unique_drone_runs{$_->{trial_name}}->{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{usernames}->{$_->{username}}++;
            $unique_drone_runs{$_->{trial_name}}->{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{drone_run_band_project_name} = $_->{drone_run_band_project_name};
            $unique_drone_runs{$_->{trial_name}}->{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{drone_run_band_project_description} = $_->{drone_run_band_project_description};
            $unique_drone_runs{$_->{trial_name}}->{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{drone_run_band_project_type} = $_->{drone_run_band_project_type};
            $unique_drone_runs{$_->{trial_name}}->{$_->{drone_run_project_id}}->{trial_id} = $_->{trial_id};
            $unique_drone_runs{$_->{trial_name}}->{$_->{drone_run_project_id}}->{trial_name} = $_->{trial_name};
            $unique_drone_runs{$_->{trial_name}}->{$_->{drone_run_project_id}}->{drone_run_project_name} = $_->{drone_run_project_name};
            $unique_drone_runs{$_->{trial_name}}->{$_->{drone_run_project_id}}->{drone_run_date} = $_->{drone_run_date};
            $unique_drone_runs{$_->{trial_name}}->{$_->{drone_run_project_id}}->{drone_run_type} = $_->{drone_run_type};
            $unique_drone_runs{$_->{trial_name}}->{$_->{drone_run_project_id}}->{drone_run_indicator} = $_->{drone_run_indicator};
            $unique_drone_runs{$_->{trial_name}}->{$_->{drone_run_project_id}}->{drone_run_processed} = $_->{drone_run_processed};
            $unique_drone_runs{$_->{trial_name}}->{$_->{drone_run_project_id}}->{drone_run_phenotypes_indicator} = $_->{drone_run_phenotypes_indicator};
            $unique_drone_runs{$_->{trial_name}}->{$_->{drone_run_project_id}}->{drone_run_project_description} = $_->{drone_run_project_description};
            $trial_id_hash{$_->{trial_name}} = $_->{trial_id};
        }
        elsif ($_->{project_image_type_name} eq 'stitched_drone_imagery') {
            $unique_drone_runs{$_->{trial_name}}->{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{stitched_image} = '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_small.'</a>';
            $unique_drone_runs{$_->{trial_name}}->{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{stitched_image_username} = $_->{username};
            $unique_drone_runs{$_->{trial_name}}->{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{stitched_image_modified_date} = $_->{image_modified_date};
            $unique_drone_runs{$_->{trial_name}}->{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{stitched_image_original} = $image_original;
            $unique_drone_runs{$_->{trial_name}}->{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{stitched_image_id} = $image_id;
            $unique_drone_runs{$_->{trial_name}}->{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{drone_run_band_project_name} = $_->{drone_run_band_project_name};
            $unique_drone_runs{$_->{trial_name}}->{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{drone_run_band_project_description} = $_->{drone_run_band_project_description};
            $unique_drone_runs{$_->{trial_name}}->{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{drone_run_band_project_type} = $_->{drone_run_band_project_type};
            $unique_drone_runs{$_->{trial_name}}->{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{usernames}->{$_->{username}}++;
            $unique_drone_runs{$_->{trial_name}}->{$_->{drone_run_project_id}}->{trial_id} = $_->{trial_id};
            $unique_drone_runs{$_->{trial_name}}->{$_->{drone_run_project_id}}->{trial_name} = $_->{trial_name};
            $unique_drone_runs{$_->{trial_name}}->{$_->{drone_run_project_id}}->{drone_run_project_name} = $_->{drone_run_project_name};
            $unique_drone_runs{$_->{trial_name}}->{$_->{drone_run_project_id}}->{drone_run_date} = $_->{drone_run_date};
            $unique_drone_runs{$_->{trial_name}}->{$_->{drone_run_project_id}}->{drone_run_type} = $_->{drone_run_type};
            $unique_drone_runs{$_->{trial_name}}->{$_->{drone_run_project_id}}->{drone_run_indicator} = $_->{drone_run_indicator};
            $unique_drone_runs{$_->{trial_name}}->{$_->{drone_run_project_id}}->{drone_run_processed} = $_->{drone_run_processed};
            $unique_drone_runs{$_->{trial_name}}->{$_->{drone_run_project_id}}->{drone_run_phenotypes_indicator} = $_->{drone_run_phenotypes_indicator};
            $unique_drone_runs{$_->{trial_name}}->{$_->{drone_run_project_id}}->{drone_run_project_description} = $_->{drone_run_project_description};
            $trial_id_hash{$_->{trial_name}} = $_->{trial_id};
        }
    }

    #print STDERR Dumper \%unique_drone_runs;

    my $calendar_funcs = CXGN::Calendar->new({});
    foreach my $trial_name (sort keys %unique_drone_runs) {
        my %unique_drone_runs_k = %{$unique_drone_runs{$trial_name}};

        my $drone_run_html = '<div class="panel-group" id="drone_runs_trial_accordion_table_wrapper_'.$trial_id_hash{$trial_name}.'" ><div class="panel panel-default"><div class="panel-heading"><h4 class="panel-title"><a data-toggle="collapse" data-parent="#drone_runs_trial_accordion_table_wrapper_'.$trial_id_hash{$trial_name}.'" href="#drone_runs_trial_accordion_table_wrapper_one_'.$trial_id_hash{$trial_name}.'" >Field Trial: '.$trial_name.'&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;('.scalar(keys %unique_drone_runs_k).' Drone Runs)</a></h4></div><div id="drone_runs_trial_accordion_table_wrapper_one_'.$trial_id_hash{$trial_name}.'" class="panel-collapse collapse"><div class="panel-body">';

        foreach my $k (sort keys %unique_drone_runs_k) {
            my $v = $unique_drone_runs_k{$k};
            my $drone_run_bands = $v->{bands};
            my $drone_run_date = $v->{drone_run_date} ? $calendar_funcs->display_start_date($v->{drone_run_date}) : '';

            $drone_run_html .= '<div class="panel-group" id="drone_run_band_accordion_drone_run_wrapper_'.$k.'" ><div class="panel panel-default"><div class="panel-heading"><h4 class="panel-title"><a data-toggle="collapse" data-parent="#drone_run_band_accordion_drone_run_wrapper_'.$k.'" href="#drone_run_band_accordion_drone_run_wrapper_one_'.$k.'" >'.$v->{drone_run_project_name}.'&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp'.$drone_run_date.'</a></h4></div><div id="drone_run_band_accordion_drone_run_wrapper_one_'.$k.'" class="panel-collapse collapse"><div class="panel-body">';

            $drone_run_html .= '<div class="well well-sm">';

            $drone_run_html .= '<div class="row"><div class="col-sm-6">';
            $drone_run_html .= '<div class="row"><div class="col-sm-5"><b>Drone Run Name</b>:</div><div class="col-sm-7">'.$v->{drone_run_project_name}.'</div></div>';
            $drone_run_html .= '<div class="row"><div class="col-sm-5"><b>Drone Run Type</b>:</div><div class="col-sm-7">'.$v->{drone_run_type}.'</div></div>';
            $drone_run_html .= '<div class="row"><div class="col-sm-5"><b>Description</b>:</div><div class="col-sm-7">'.$v->{drone_run_project_description}.'</div></div>';
            $drone_run_html .= '<div class="row"><div class="col-sm-5"><b>Date</b>:</div><div class="col-sm-7">'.$drone_run_date.'</div></div>';
            $drone_run_html .= '<div class="row"><div class="col-sm-5"><b>Field Trial</b>:</div><div class="col-sm-7"><a href="/breeders_toolbox/trial/'.$v->{trial_id}.'">'.$v->{trial_name}.'</a></div></div>';
            $drone_run_html .= '</div><div class="col-sm-3">';
            if ($v->{drone_run_indicator}) {
                $drone_run_html .= '<span class="label label-info" ><span class="glyphicon glyphicon-hourglass"></span>&nbsp;&nbsp;&nbsp;Processing Images in Progress</span><br/><br/>';
            }
            if ($v->{drone_run_phenotypes_indicator}) {
                $drone_run_html .= '<span class="label label-info" ><span class="glyphicon glyphicon-hourglass"></span>&nbsp;&nbsp;&nbsp;Processing Phenotypes in Progress</span><br/><br/>';
            } elsif ($v->{drone_run_processed}) {
                $drone_run_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_phenotype_run" data-drone_run_project_id="'.$k.'" data-field_trial_id="'.$v->{trial_id}.'" data-field_trial_name="'.$v->{trial_name}.'" >Generate Phenotypes for <br/>'.$v->{drone_run_project_name}.'</button>';
            }
            $drone_run_html .= '</div><div class="col-sm-3">';
            if (!$v->{drone_run_processed}) {
                $drone_run_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_standard_process" data-drone_run_project_id="'.$k.'" data-drone_run_project_name="'.$v->{drone_run_project_name}.'" data-field_trial_id="'.$v->{trial_id}.'" data-field_trial_name="'.$v->{trial_name}.'" >Run Standard Process For<br/>'.$v->{drone_run_project_name}.'</button><br/><br/>';
            }
            $drone_run_html .= '<button class="btn btn-danger btn-sm" name="project_drone_imagery_delete_drone_run" data-drone_run_project_id="'.$k.'" data-drone_run_project_name="'.$v->{drone_run_project_name}.'" >Delete Drone Run</button>';

            $drone_run_html .= '</div></div></div>';

            $drone_run_html .= "<hr>";

            $drone_run_html .= '<div name="drone_run_band_total_plot_image_div" id="drone_run_band_total_plot_image_count_div_'.$k.'">';
            $drone_run_html .= '<div class="panel-group"><div class="panel panel-default panel-sm"><div class="panel-heading"><h4 class="panel-title"><a data-toggle="collapse" >Loading Plot Image Summary...</a></h4></div></div></div>';
            $drone_run_html .= '</div>';

            $drone_run_html .= '<div class="panel-group" id="drone_run_band_accordion_table_wrapper_'.$k.'" ><div class="panel panel-default"><div class="panel-heading"><h4 class="panel-title"><a data-toggle="collapse" data-parent="#drone_run_band_accordion_table_wrapper_'.$k.'" href="#drone_run_band_accordion_table_wrapper_one_'.$k.'" >View All Drone Run Images</a></h4></div><div id="drone_run_band_accordion_table_wrapper_one_'.$k.'" class="panel-collapse collapse"><div class="panel-body">';

            my $drone_run_band_table_html = '<table class="table table-bordered"><thead><tr><th>Drone Run Band(s)</th><th>Images/Actions</th></thead><tbody>';

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

            $drone_run_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_merge_channels" data-drone_run_project_id="'.$k.'" data-drone_run_project_name="'.$v->{drone_run_project_name}.'" >Merge Drone Run Bands For '.$v->{drone_run_project_name}.'</button><br/><br/>';

            $drone_run_html .= '</div></div></div></div>';

            $drone_run_html .= '</div></div></div>';
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
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
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
    my @observation_unit_plot_polygon_types_array = keys %$observation_unit_plot_polygon_types;
    my $observation_unit_polygon_imagery_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        drone_run_band_project_id_list=>[$drone_run_band_project_id],
        project_image_type_id_list=>\@observation_unit_plot_polygon_types_array
    });
    my ($observation_unit_polygon_result, $observation_unit_polygon_total_count) = $observation_unit_polygon_imagery_search->search();
    #print STDERR Dumper $observation_unit_polygon_result;

    my %imagery_attribute_map = (
        'cropped_stitched_drone_imagery' => {
            name => 'polygon',
            key => 'drone_run_band_cropped_polygon'
        },
        'rotated_stitched_drone_imagery' => {
            name => 'angle',
            key => 'drone_run_band_rotate_angle'
        },
        'threshold_background_removed_stitched_drone_imagery_blue' => {
            name => 'threshold',
            key => 'drone_run_band_removed_background_threshold',
            observation_unit_plot_polygon_type => 'observation_unit_polygon_blue_background_removed_threshold_imagery'
        },
        'threshold_background_removed_stitched_drone_imagery_green' => {
            name => 'threshold',
            key => 'drone_run_band_removed_background_threshold',
            observation_unit_plot_polygon_type => 'observation_unit_polygon_green_background_removed_threshold_imagery'
        },
        'threshold_background_removed_stitched_drone_imagery_red' => {
            name => 'threshold',
            key => 'drone_run_band_removed_background_threshold',
            observation_unit_plot_polygon_type => 'observation_unit_polygon_red_background_removed_threshold_imagery'
        },
        'threshold_background_removed_stitched_drone_imagery_red_edge' => {
            name => 'threshold',
            key => 'drone_run_band_removed_background_threshold',
            observation_unit_plot_polygon_type => 'observation_unit_polygon_red_edge_background_removed_threshold_imagery'
        },
        'threshold_background_removed_stitched_drone_imagery_nir' => {
            name => 'threshold',
            key => 'drone_run_band_removed_background_threshold',
            observation_unit_plot_polygon_type => 'observation_unit_polygon_nir_background_removed_threshold_imagery'
        },
        'threshold_background_removed_stitched_drone_imagery_mir' => {
            name => 'threshold',
            key => 'drone_run_band_removed_background_threshold',
            observation_unit_plot_polygon_type => 'observation_unit_polygon_mir_background_removed_threshold_imagery'
        },
        'threshold_background_removed_stitched_drone_imagery_fir' => {
            name => 'threshold',
            key => 'drone_run_band_removed_background_threshold',
            observation_unit_plot_polygon_type => 'observation_unit_polygon_fir_background_removed_threshold_imagery'
        },
        'threshold_background_removed_stitched_drone_imagery_tir' => {
            name => 'threshold',
            key => 'drone_run_band_removed_background_threshold',
            observation_unit_plot_polygon_type => 'observation_unit_polygon_tir_background_removed_threshold_imagery'
        },
        'threshold_background_removed_stitched_drone_imagery_bw' => {
            name => 'threshold',
            key => 'drone_run_band_removed_background_threshold',
            observation_unit_plot_polygon_type => 'observation_unit_polygon_bw_background_removed_threshold_imagery'
        },
        'threshold_background_removed_stitched_drone_imagery_rgb_channel_1' => {
            name => 'threshold',
            key => 'drone_run_band_removed_background_threshold',
            observation_unit_plot_polygon_type => 'observation_unit_polygon_rgb_background_removed_threshold_imagery_channel_1'
        },
        'threshold_background_removed_stitched_drone_imagery_rgb_channel_2' => {
            name => 'threshold',
            key => 'drone_run_band_removed_background_threshold',
            observation_unit_plot_polygon_type => 'observation_unit_polygon_rgb_background_removed_threshold_imagery_channel_2'
        },
        'threshold_background_removed_stitched_drone_imagery_rgb_channel_3' => {
            name => 'threshold',
            key => 'drone_run_band_removed_background_threshold',
            observation_unit_plot_polygon_type => 'observation_unit_polygon_rgb_background_removed_threshold_imagery_channel_3'
        },
        'threshold_background_removed_tgi_stitched_drone_imagery' => {
            name => 'threshold',
            key => 'drone_run_band_removed_background_tgi_threshold',
            observation_unit_plot_polygon_type => 'observation_unit_polygon_background_removed_tgi_imagery'
        },
        'threshold_background_removed_vari_stitched_drone_imagery' => {
            name => 'threshold',
            key => 'drone_run_band_removed_background_vari_threshold',
            observation_unit_plot_polygon_type => 'observation_unit_polygon_background_removed_vari_imagery'
        },
        'threshold_background_removed_ndvi_stitched_drone_imagery' => {
            name => 'threshold',
            key => 'drone_run_band_removed_background_ndvi_threshold',
            observation_unit_plot_polygon_type => 'observation_unit_polygon_background_removed_ndvi_imagery'
        },
        'threshold_background_removed_ndre_stitched_drone_imagery' => {
            name => 'threshold',
            key => 'drone_run_band_removed_background_ndre_threshold',
            observation_unit_plot_polygon_type => 'observation_unit_polygon_background_removed_ndre_imagery'
        }
    );

    my %original_background_removed_threshold_terms = (
        'threshold_background_removed_stitched_drone_imagery_blue' => 'Blue (450-520nm)',
        'threshold_background_removed_stitched_drone_imagery_green' => 'Green (515-600nm)',
        'threshold_background_removed_stitched_drone_imagery_red' => 'Red (600-690nm)',
        'threshold_background_removed_stitched_drone_imagery_red_edge' => 'Red Edge (690-750nm)',
        'threshold_background_removed_stitched_drone_imagery_nir' => 'NIR (750-900nm)',
        'threshold_background_removed_stitched_drone_imagery_mir' => 'MIR (1550-1750nm)',
        'threshold_background_removed_stitched_drone_imagery_fir' => 'FIR (2080-2350nm)',
        'threshold_background_removed_stitched_drone_imagery_tir' => 'Thermal IR (10400-12500nm)',
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
        'NIR (750-900nm)' => ['observation_unit_polygon_nir_imagery'],
        'MIR (1550-1750nm)' => ['observation_unit_polygon_mir_imagery'],
        'FIR (2080-2350nm)' => ['observation_unit_polygon_fir_imagery'],
        'Thermal IR (10400-12500nm)' => ['observation_unit_polygon_tir_imagery'],
        'Black and White Image' => ['observation_unit_polygon_bw_imagery'],
        'RGB Color Image' => ['observation_unit_polygon_rgb_imagery', 'observation_unit_polygon_rgb_imagery_channel_1', 'observation_unit_polygon_rgb_imagery_channel_2', 'observation_unit_polygon_rgb_imagery_channel_3'],
    );

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
            if (exists($imagery_attribute_map{$_->{project_image_type_name}})) {
                $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{$_->{project_image_type_name}."_".$imagery_attribute_map{$_->{project_image_type_name}}->{name}} = $_->{$imagery_attribute_map{$_->{project_image_type_name}}->{key}};
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

    print STDERR Dumper \%unique_drone_runs;

    foreach my $k (sort keys %unique_drone_runs) {
        my $v = $unique_drone_runs{$k};

        my $drone_run_bands = $v->{bands};

        my $drone_run_band_table_html = '';

        foreach my $drone_run_band_project_id (sort keys %$drone_run_bands) {
            my $d = $drone_run_bands->{$drone_run_band_project_id};

            if ($d->{stitched_image}) {
                $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-6"><h5>Stitched Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{stitched_image_id}.'"></span></h5><b>By</b>: '.$d->{stitched_image_username}.'<br/><b>Date</b>: '.$d->{stitched_image_modified_date}.'</div><div class="col-sm-6">'.$d->{stitched_image}.'</div></div></div>';

                if ($d->{rotated_stitched_drone_imagery}) {
                    $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-6"><h5>Rotated Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{rotated_stitched_drone_imagery_id}.'"></span></h5><b>By</b>: '.$d->{rotated_stitched_drone_imagery_username}.'<br/><b>Date</b>: '.$d->{rotated_stitched_drone_imagery_modified_date}.'<br/><b>Rotated Angle</b>: '.$d->{rotated_stitched_drone_imagery_angle}.'</div><div class="col-sm-6">'.$d->{rotated_stitched_drone_imagery}.'</div></div></div>';

                    if ($d->{cropped_stitched_drone_imagery}) {
                        $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-6"><h5>Cropped Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{cropped_stitched_drone_imagery_id}.'"></span></h5><b>By</b>: '.$d->{cropped_stitched_drone_imagery_username}.'<br/><b>Date</b>: '.$d->{cropped_stitched_drone_imagery_modified_date}.'<br/><b>Cropped Polygon</b>: '.$d->{cropped_stitched_drone_imagery_polygon}.'</div><div class="col-sm-6">'.$d->{cropped_stitched_drone_imagery}.'</div></div></div>';

                        if ($d->{denoised_stitched_drone_imagery}) {
                            $drone_run_band_table_html .= '<div class="well well-sm" style="overflow-x:auto"><div class="row"><div class="col-sm-3"><h5>Original Denoised Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{denoised_stitched_drone_imagery_id}.'"></span></h5><b>By</b>: '.$d->{denoised_stitched_drone_imagery_username}.'</br><b>Date</b>: '.$d->{denoised_stitched_drone_imagery_modified_date}.'</div><div class="col-sm-3">'.$d->{denoised_stitched_drone_imagery}.'</div><div class="col-sm-6">';

                            foreach my $denoised_original_plot_polygon_term (@{$original_denoised_observation_unit_polygon_terms{$d->{drone_run_band_project_type}}}) {
                                $drone_run_band_table_html .= '<button class="btn btn-default btn-sm" name="project_drone_imagery_plot_polygons" data-stitched_image_id="'.$d->{stitched_image_id}.'" data-cropped_stitched_image_id="'.$d->{cropped_stitched_drone_imagery_id}.'" data-denoised_stitched_image_id="'.$d->{denoised_stitched_drone_imagery_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-background_removed_stitched_image_id="'.$d->{denoised_stitched_drone_imagery_id}.'" data-assign_plot_polygons_type="'.$denoised_original_plot_polygon_term.'">Create/View Plot Polygons ('.$denoised_original_plot_polygon_term.')</button>';

                                $drone_run_band_table_html .= '<hr>';
                                my $plot_polygon_images = '';
                                if ($d->{$denoised_original_plot_polygon_term."_images"}) {
                                    $plot_polygon_images = scalar(@{$d->{$denoised_original_plot_polygon_term."_images"}})." Plot Polygons<br/><span>";
                                    $plot_polygon_images .= join '', @{$d->{$denoised_original_plot_polygon_term."_images"}};
                                    $plot_polygon_images .= "</span>";
                                    $plot_polygon_images .= '<br/><br/><button class="btn btn-primary btn-sm" name="project_drone_imagery_get_phenotypes" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'" data-plot_polygons_type="'.$denoised_original_plot_polygon_term.'" >Calculate Phenotypes</button>';
                                } else {
                                    $plot_polygon_images = 'No Plot Polygons Assigned';
                                }
                                $drone_run_band_table_html .= $plot_polygon_images;
                            }

                            $drone_run_band_table_html .= '</div></div></div>';

                            $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_add_georeference" data-stitched_image_id="'.$d->{stitched_image_id}.'" data-cropped_stitched_image_id="'.$d->{cropped_stitched_drone_imagery_id}.'" data-denoised_stitched_image_id="'.$d->{denoised_stitched_drone_imagery_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" >Add Georeferenced Points</button><br/><br/>';

                            if ($d->{drone_run_band_project_type} eq 'RGB Color Image' || $d->{drone_run_band_project_type} eq 'Merged 3 Bands BGR' || $d->{drone_run_band_project_type} eq 'Merged 3 Bands NRN' || $d->{drone_run_band_project_type} eq 'Merged 3 Bands NReN') {
                                if ($d->{drone_run_band_project_type} eq 'RGB Color Image') {
                                    $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_rgb_vegetative" data-denoised_stitched_image_id="'.$d->{denoised_stitched_drone_imagery_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-denoised_stitched_image="'.uri_encode($d->{denoised_stitched_drone_imagery_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'">Convert to Vegetative Index</button><br/><br/>';
                                }
                                if ($d->{drone_run_band_project_type} eq 'Merged 3 Bands BGR') {
                                    $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_3_band_bgr_vegetative" data-denoised_stitched_image_id="'.$d->{denoised_stitched_drone_imagery_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-denoised_stitched_image="'.uri_encode($d->{denoised_stitched_drone_imagery_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'">Convert to Vegetative Index</button><br/><br/>';
                                }
                                if ($d->{drone_run_band_project_type} eq 'Merged 3 Bands NRN') {
                                    $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_3_band_nrn_vegetative" data-denoised_stitched_image_id="'.$d->{denoised_stitched_drone_imagery_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-denoised_stitched_image="'.uri_encode($d->{denoised_stitched_drone_imagery_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'">Convert to Vegetative Index</button><br/><br/>';
                                }
                                if ($d->{drone_run_band_project_type} eq 'Merged 3 Bands NReN') {
                                    $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_3_band_nren_vegetative" data-denoised_stitched_image_id="'.$d->{denoised_stitched_drone_imagery_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-denoised_stitched_image="'.uri_encode($d->{denoised_stitched_drone_imagery_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'">Convert to Vegetative Index</button><br/><br/>';
                                }
                            } else {
                                $drone_run_band_table_html .= '<button class="btn btn-default btn-sm disabled">Vegetative index cannot be calculated on an image with a single channel.<br/>You can merge bands into a multi-channel image using the "Merge Drone Run Bands" button below this table</button><br/><br/>';
                            }

                            foreach my $original_background_removed_threshold_term (keys %original_background_removed_threshold_terms) {
                                if(exists($d->{$original_background_removed_threshold_term})) {
                                    my $plot_polygon_type = $imagery_attribute_map{$original_background_removed_threshold_term}->{observation_unit_plot_polygon_type};

                                    $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-3"><h5>Background Removed Original Denoised Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{$original_background_removed_threshold_term."_id"}.'"></span></h5><b>By</b>: '.$d->{$original_background_removed_threshold_term."_username"}.'</br><b>Date</b>: '.$d->{$original_background_removed_threshold_term."_modified_date"}.'<br/><b>Background Removed Threshold</b>: '.$d->{$original_background_removed_threshold_term."_threshold"}.'</div><div class="col-sm-3">'.$d->{$original_background_removed_threshold_term}.'</div><div class="col-sm-6">';

                                    $drone_run_band_table_html .= '<button class="btn btn-default btn-sm" name="project_drone_imagery_plot_polygons" data-stitched_image_id="'.$d->{stitched_image_id}.'" data-cropped_stitched_image_id="'.$d->{cropped_stitched_drone_imagery_id}.'" data-denoised_stitched_image_id="'.$d->{denoised_stitched_drone_imagery_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-background_removed_stitched_image_id="'.$d->{$original_background_removed_threshold_term."_id"}.'" data-assign_plot_polygons_type="'.$plot_polygon_type.'">Create/View Plot Polygons</button>';

                                    $drone_run_band_table_html .= '<hr>';
                                    my $plot_polygon_original_background_removed_threshold_images = '';
                                    if ($d->{$plot_polygon_type."_images"}) {
                                        $plot_polygon_original_background_removed_threshold_images = scalar(@{$d->{$plot_polygon_type."_images"}})." Plot Polygons<br/><span>";
                                        $plot_polygon_original_background_removed_threshold_images .= join '', @{$d->{$plot_polygon_type."_images"}};
                                        $plot_polygon_original_background_removed_threshold_images .= "</span>";
                                        $plot_polygon_original_background_removed_threshold_images .= '<br/><br/><button class="btn btn-primary btn-sm" name="project_drone_imagery_get_phenotypes" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'" data-plot_polygons_type="'.$plot_polygon_type.'" >Calculate Phenotypes</button>';
                                    } else {
                                        $plot_polygon_original_background_removed_threshold_images = 'No Plot Polygons Assigned';
                                    }
                                    $drone_run_band_table_html .= $plot_polygon_original_background_removed_threshold_images;

                                    $drone_run_band_table_html .= '</div></div></div>';

                                    # if ($d->{calculate_fourier_transform_hpf30_nren_denoised_background_removed_ndre_mask_original_channel_1_image}) {
                                    #     $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-3"><h5>FT HPF30 Denoised Image with Background Removed via NDRE Mask&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{calculate_fourier_transform_hpf30_nren_denoised_background_removed_ndre_mask_original_channel_1_image_id}.'"></span></h5><b>By</b>: '.$d->{calculate_fourier_transform_hpf30_nren_denoised_background_removed_ndre_mask_original_channel_1_image_username}.'</br><b>Date</b>: '.$d->{calculate_fourier_transform_hpf30_nren_denoised_background_removed_ndre_mask_original_channel_1_modified_date}.'</div><div class="col-sm-3">'.$d->{calculate_fourier_transform_hpf30_nren_denoised_background_removed_ndre_mask_original_channel_1_image}.'</div><div class="col-sm-6">';
                                    #     $drone_run_band_table_html .= '</div></div></div>';
                                    # } else {
                                    #     $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_fourier_transform_hpf30" data-image_id="'.$d->{threshold_background_removed_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'", data-selected_image_type="threshold_background_removed_stitched_drone_imagery" >Fourier Transform HPF30</button><br/><br/>';
                                    # }
                                } else {
                                    print STDERR Dumper $original_background_removed_threshold_term;
                                    if ($d->{drone_run_band_project_type} eq $original_background_removed_threshold_terms{$original_background_removed_threshold_term}) {
                                        $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_remove_background" data-denoised_stitched_image_id="'.$d->{denoised_stitched_drone_imagery_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-denoised_stitched_image="'.uri_encode($d->{denoised_stitched_drone_imagery_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-remove_background_current_image_id="'.$d->{denoised_stitched_drone_imagery_id}.'" data-remove_background_current_image_type="'.$original_background_removed_threshold_term.'" >Remove Background From Original Denoised Image via Threshold</button><br/><br/>';
                                    }
                                }
                            } 

                            my $plot_polygon_type = '';
                            if ($d->{drone_run_band_project_type} eq 'Black and White Image') {
                                $plot_polygon_type = 'observation_unit_polygon_bw_background_removed_threshold_imagery';
                            } elsif ($d->{drone_run_band_project_type} eq 'Blue (450-520nm)') {
                                $plot_polygon_type = 'observation_unit_polygon_blue_background_removed_threshold_imagery';

                                if (!$d->{calculate_fourier_transform_hpf30_blue_denoised_stitched_image_channel_1_image}) {
                                    $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_fourier_transform_hpf30" data-image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'", data-selected_image_type="denoised_stitched_image" >Fourier Transform HPF30 Blue</button><br/><br/>';
                                }
                            } elsif ($d->{drone_run_band_project_type} eq 'Green (515-600nm)') {
                                $plot_polygon_type = 'observation_unit_polygon_green_background_removed_threshold_imagery';

                                if (!$d->{calculate_fourier_transform_hpf30_green_denoised_stitched_image_channel_1_image}) {
                                    $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_fourier_transform_hpf30" data-image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'", data-selected_image_type="denoised_stitched_image" >Fourier Transform HPF30 Green</button><br/><br/>';
                                }
                            } elsif ($d->{drone_run_band_project_type} eq 'Red (600-690nm)') {
                                $plot_polygon_type = 'observation_unit_polygon_red_background_removed_threshold_imagery';

                                if (!$d->{calculate_fourier_transform_hpf30_red_denoised_stitched_image_channel_1_image}) {
                                    $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_fourier_transform_hpf30" data-image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'", data-selected_image_type="denoised_stitched_image" >Fourier Transform HPF30 Red</button><br/><br/>';
                                }
                            } elsif ($d->{drone_run_band_project_type} eq 'Red Edge (690-750nm)') {
                                $plot_polygon_type = 'observation_unit_polygon_red_edge_background_removed_threshold_imagery';

                                if (!$d->{calculate_fourier_transform_hpf30_rededge_denoised_stitched_image_channel_1_image}) {
                                    $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_fourier_transform_hpf30" data-image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'", data-selected_image_type="denoised_stitched_image" >Fourier Transform HPF30 Red Edge</button><br/><br/>';
                                }
                            } elsif ($d->{drone_run_band_project_type} eq 'NIR (750-900nm)') {
                                $plot_polygon_type = 'observation_unit_polygon_nir_background_removed_threshold_imagery';

                                if (!$d->{calculate_fourier_transform_hpf30_nir_denoised_stitched_image_channel_1_image}) {
                                    $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_fourier_transform_hpf30" data-image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'", data-selected_image_type="denoised_stitched_image" >Fourier Transform HPF30 NIR</button><br/><br/>';
                                }
                            } elsif ($d->{drone_run_band_project_type} eq 'MIR (1550-1750nm)') {
                                $plot_polygon_type = 'observation_unit_polygon_mir_background_removed_threshold_imagery';
                            } elsif ($d->{drone_run_band_project_type} eq 'FIR (2080-2350nm)') {
                                $plot_polygon_type = 'observation_unit_polygon_fir_background_removed_threshold_imagery';
                            } elsif ($d->{drone_run_band_project_type} eq 'Thermal IR (10400-12500nm)') {
                                $plot_polygon_type = 'observation_unit_polygon_tir_background_removed_threshold_imagery';
                            } elsif ($d->{drone_run_band_project_type} eq 'RGB Color Image') {
                                $plot_polygon_type = 'observation_unit_polygon_rgb_background_removed_threshold_imagery';
                                
                                if ($d->{vegetative_index_tgi_stitched_image}) {
                                    $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-3"><h5>TGI Vegetative Index Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{vegetative_index_tgi_image_id}.'"></span></h5><b>By</b>: '.$d->{vegetative_index_tgi_username}.'</br><b>Date</b>: '.$d->{vegetative_index_tgi_modified_date}.'</div><div class="col-sm-3">'.$d->{vegetative_index_tgi_stitched_image}.'</div><div class="col-sm-6">';

                                    $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_plot_polygons" data-stitched_image_id="'.$d->{stitched_image_id}.'" data-cropped_stitched_image_id="'.$d->{cropped_stitched_image_id}.'" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-background_removed_stitched_image_id="'.$d->{vegetative_index_tgi_image_id}.'" data-assign_plot_polygons_type="observation_unit_polygon_tgi_imagery">Create/View Plot Polygons</button>';

                                    $drone_run_band_table_html .= '<hr>';
                                    my $plot_polygon_tgi_images = '';
                                    if ($d->{plot_polygon_tgi_images}) {
                                        $plot_polygon_tgi_images = scalar(@{$d->{plot_polygon_tgi_images}})." Plot Polygons<br/><span>";
                                        $plot_polygon_tgi_images .= join '', @{$d->{plot_polygon_tgi_images}};
                                        $plot_polygon_tgi_images .= "</span>";
                                        $plot_polygon_tgi_images .= '<br/><br/>';
                                        $plot_polygon_tgi_images .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_get_phenotypes" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'" data-plot_polygons_type="observation_unit_polygon_tgi_imagery" >Calculate Phenotypes</button>';
                                    } else {
                                        $plot_polygon_tgi_images = 'No Plot Polygons Assigned';
                                    }
                                    $drone_run_band_table_html .= $plot_polygon_tgi_images;

                                    $drone_run_band_table_html .= '</div></div></div>';
                                }
                            }

                            if ($d->{vegetative_index_tgi_stitched_image}) {
                                $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-3"><h5>TGI Vegetative Index Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{vegetative_index_tgi_image_id}.'"></span></h5><b>By</b>: '.$d->{vegetative_index_tgi_username}.'</br><b>Date</b>: '.$d->{vegetative_index_tgi_modified_date}.'</div><div class="col-sm-3">'.$d->{vegetative_index_tgi_stitched_image}.'</div><div class="col-sm-6">';

                                $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_plot_polygons" data-stitched_image_id="'.$d->{stitched_image_id}.'" data-cropped_stitched_image_id="'.$d->{cropped_stitched_image_id}.'" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-background_removed_stitched_image_id="'.$d->{vegetative_index_tgi_image_id}.'" data-assign_plot_polygons_type="observation_unit_polygon_tgi_imagery">Create/View Plot Polygons</button>';

                                $drone_run_band_table_html .= '<hr>';
                                my $plot_polygon_tgi_images = '';
                                if ($d->{plot_polygon_tgi_images}) {
                                    $plot_polygon_tgi_images = scalar(@{$d->{plot_polygon_tgi_images}})." Plot Polygons<br/><span>";
                                    $plot_polygon_tgi_images .= join '', @{$d->{plot_polygon_tgi_images}};
                                    $plot_polygon_tgi_images .= "</span>";
                                    $plot_polygon_tgi_images .= '<br/><br/>';
                                    $plot_polygon_tgi_images .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_get_phenotypes" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'" data-plot_polygons_type="observation_unit_polygon_tgi_imagery" >Calculate Phenotypes</button>';
                                } else {
                                    $plot_polygon_tgi_images = 'No Plot Polygons Assigned';
                                }
                                $drone_run_band_table_html .= $plot_polygon_tgi_images;

                                $drone_run_band_table_html .= '</div></div></div>';

                                if ($d->{calculate_fourier_transform_hpf30_bgr_calculate_tgi_drone_imagery_channel_1_image}) {
                                    $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-3"><h5>FT HPF30 TGI Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{calculate_fourier_transform_hpf30_bgr_calculate_tgi_drone_imagery_channel_1_image_id}.'"></span></h5><b>By</b>: '.$d->{calculate_fourier_transform_hpf30_bgr_calculate_tgi_drone_imagery_channel_1_image_username}.'</br><b>Date</b>: '.$d->{calculate_fourier_transform_hpf30_bgr_calculate_tgi_drone_imagery_channel_1_modified_date}.'</div><div class="col-sm-3">'.$d->{calculate_fourier_transform_hpf30_bgr_calculate_tgi_drone_imagery_channel_1_image}.'</div><div class="col-sm-6">';

                                    $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_plot_polygons" data-stitched_image_id="'.$d->{stitched_image_id}.'" data-cropped_stitched_image_id="'.$d->{cropped_stitched_image_id}.'" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-background_removed_stitched_image_id="'.$d->{calculate_fourier_transform_hpf30_bgr_calculate_tgi_drone_imagery_channel_1_image_id}.'" data-assign_plot_polygons_type="observation_unit_polygon_fourier_transform_hpf30_bgr_calculate_tgi_drone_imagery_channel_1">Create/View Plot Polygons</button>';

                                    $drone_run_band_table_html .= '<hr>';
                                    my $plot_polygon_ft_hpf30_tgi_images = '';
                                    if ($d->{plot_polygon_fourier_transform_hpf30_bgr_calculate_tgi_drone_imagery_channel_1_images}) {
                                        $plot_polygon_ft_hpf30_tgi_images = scalar(@{$d->{plot_polygon_fourier_transform_hpf30_bgr_calculate_tgi_drone_imagery_channel_1_images}})." Plot Polygons<br/><span>";
                                        $plot_polygon_ft_hpf30_tgi_images .= join '', @{$d->{plot_polygon_fourier_transform_hpf30_bgr_calculate_tgi_drone_imagery_channel_1_images}};
                                        $plot_polygon_ft_hpf30_tgi_images .= "</span>";
                                        $plot_polygon_ft_hpf30_tgi_images .= '<br/><br/>';
                                        $plot_polygon_ft_hpf30_tgi_images .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_get_phenotypes" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'" data-plot_polygons_type="observation_unit_polygon_fourier_transform_hpf30_bgr_calculate_tgi_drone_imagery_channel_1" >Calculate Phenotypes</button>';
                                    } else {
                                        $plot_polygon_ft_hpf30_tgi_images = 'No Plot Polygons Assigned';
                                    }
                                    $drone_run_band_table_html .= $plot_polygon_ft_hpf30_tgi_images;

                                    $drone_run_band_table_html .= '</div></div></div>';
                                } else {
                                    $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_fourier_transform_hpf30" data-image_id="'.$d->{vegetative_index_tgi_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'", data-selected_image_type="calculate_tgi_drone_imagery" >Fourier Transform HPF30 TGI Channel 1</button><br/><br/>';
                                }

                                if ($d->{threshold_background_removed_tgi_stitched_image}) {
                                    $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-3"><h5>Background Removed TGI Vegetative Index Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{threshold_background_removed_tgi_stitched_image_id}.'"></span></h5><b>By</b>: '.$d->{threshold_background_removed_tgi_stitched_image_username}.'</br><b>Date</b>: '.$d->{threshold_background_removed_tgi_stitched_image_modified_date}.'<br/><b>Background Removed Threshold</b>: '.$d->{threshold_background_removed_tgi_stitched_image_threshold}.'</div><div class="col-sm-3">'.$d->{threshold_background_removed_tgi_stitched_image}.'</div><div class="col-sm-6">';

                                    $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_plot_polygons" data-stitched_image_id="'.$d->{stitched_image_id}.'" data-cropped_stitched_image_id="'.$d->{cropped_stitched_image_id}.'" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-background_removed_stitched_image_id="'.$d->{threshold_background_removed_tgi_stitched_image_id}.'" data-assign_plot_polygons_type="observation_unit_polygon_background_removed_tgi_imagery">Create/View Plot Polygons</button>';

                                    $drone_run_band_table_html .= '<hr>';
                                    my $plot_polygon_background_removed_tgi_images = '';
                                    if ($d->{plot_polygon_background_removed_tgi_images}) {
                                        $plot_polygon_background_removed_tgi_images = scalar(@{$d->{plot_polygon_background_removed_tgi_images}})." Plot Polygons<br/><span>";
                                        $plot_polygon_background_removed_tgi_images .= join '', @{$d->{plot_polygon_background_removed_tgi_images}};
                                        $plot_polygon_background_removed_tgi_images .= "</span>";
                                        $plot_polygon_background_removed_tgi_images .= '<br/><br/>';
                                        $plot_polygon_background_removed_tgi_images .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_get_phenotypes" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'" data-plot_polygons_type="observation_unit_polygon_background_removed_tgi_imagery" >Calculate Phenotypes</button>';
                                    } else {
                                        $plot_polygon_background_removed_tgi_images = 'No Plot Polygons Assigned';
                                    }
                                    $drone_run_band_table_html .= $plot_polygon_background_removed_tgi_images;

                                    $drone_run_band_table_html .= '</div></div></div>';

                                    if ($d->{calculate_fourier_transform_hpf30_bgr_threshold_background_removed_tgi_stitched_drone_imagery_channel_1_image}) {
                                        $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-3"><h5>FT HPF30 TGI Image with Background Removed via Threshold&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{calculate_fourier_transform_hpf30_bgr_threshold_background_removed_tgi_stitched_drone_imagery_channel_1_image_id}.'"></span></h5><b>By</b>: '.$d->{calculate_fourier_transform_hpf30_bgr_threshold_background_removed_tgi_stitched_drone_imagery_channel_1_image_username}.'</br><b>Date</b>: '.$d->{calculate_fourier_transform_hpf30_bgr_threshold_background_removed_tgi_stitched_drone_imagery_channel_1_modified_date}.'</div><div class="col-sm-3">'.$d->{calculate_fourier_transform_hpf30_bgr_threshold_background_removed_tgi_stitched_drone_imagery_channel_1_image}.'</div><div class="col-sm-6">';
                                        $drone_run_band_table_html .= '</div></div></div>';
                                    } else {
                                        $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_fourier_transform_hpf30" data-image_id="'.$d->{threshold_background_removed_tgi_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'", data-selected_image_type="threshold_background_removed_tgi_stitched_drone_imagery" >Fourier Transform HPF30 TGI Channel 1 with Background Removed via Threshold</button><br/><br/>';
                                    }

                                    if ($d->{denoised_background_removed_thresholded_tgi_mask_original_image}) {
                                        $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-3"><h5>Background Removed TGI Vegetative Index Mask on Original Denoised Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{denoised_background_removed_thresholded_tgi_mask_original_image_id}.'"></span></h5><b>By</b>: '.$d->{denoised_background_removed_thresholded_tgi_mask_original_image_username}.'</br><b>Date</b>: '.$d->{denoised_background_removed_thresholded_tgi_mask_original_modified_date}.'</div><div class="col-sm-3">'.$d->{denoised_background_removed_thresholded_tgi_mask_original_image}.'</div><div class="col-sm-6">';

                                        $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_plot_polygons" data-stitched_image_id="'.$d->{stitched_image_id}.'" data-cropped_stitched_image_id="'.$d->{cropped_stitched_image_id}.'" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-background_removed_stitched_image_id="'.$d->{denoised_background_removed_thresholded_tgi_mask_original_image_id}.'" data-assign_plot_polygons_type="observation_unit_polygon_original_background_removed_thresholded_tgi_mask_imagery">Create/View Plot Polygons</button>';

                                        $drone_run_band_table_html .= '<hr>';
                                        my $plot_polygon_original_background_removed_thresholded_tgi_mask_images = '';
                                        if ($d->{plot_polygon_original_background_removed_thresholded_tgi_mask_images}) {
                                            $plot_polygon_original_background_removed_thresholded_tgi_mask_images = scalar(@{$d->{plot_polygon_original_background_removed_thresholded_tgi_mask_images}})." Plot Polygons<br/><span>";
                                            $plot_polygon_original_background_removed_thresholded_tgi_mask_images .= join '', @{$d->{plot_polygon_original_background_removed_thresholded_tgi_mask_images}};
                                            $plot_polygon_original_background_removed_thresholded_tgi_mask_images .= "</span>";
                                            $plot_polygon_original_background_removed_thresholded_tgi_mask_images .= '<br/><br/>';
                                            $plot_polygon_original_background_removed_thresholded_tgi_mask_images .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_get_phenotypes" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'" data-plot_polygons_type="observation_unit_polygon_original_background_removed_thresholded_tgi_mask_imagery" >Calculate Phenotypes</button>';
                                        } else {
                                            $plot_polygon_original_background_removed_thresholded_tgi_mask_images = 'No Plot Polygons Assigned';
                                        }
                                        $drone_run_band_table_html .= $plot_polygon_original_background_removed_thresholded_tgi_mask_images;

                                        $drone_run_band_table_html .= '</div></div></div>';

                                        if ($d->{calculate_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_tgi_mask_original_channel_1_image}) {
                                            $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-3"><h5>FT HPF30 Denoised Channel 1 with Background Removed via Thresholded TGI Mask&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{calculate_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_tgi_mask_original_channel_1_image_id}.'"></span></h5><b>By</b>: '.$d->{calculate_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_tgi_mask_original_channel_1_image_username}.'</br><b>Date</b>: '.$d->{calculate_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_tgi_mask_original_channel_1_modified_date}.'</div><div class="col-sm-3">'.$d->{calculate_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_tgi_mask_original_channel_1_image}.'</div><div class="col-sm-6">';
                                            $drone_run_band_table_html .= '</div></div></div>';
                                        } else {
                                            $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_fourier_transform_hpf30" data-image_id="'.$d->{denoised_background_removed_thresholded_tgi_mask_original_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'", data-selected_image_type="denoised_background_removed_thresholded_tgi_mask_original" >Fourier Transform HPF30 Denoised Image Channel 1 with Background Removed via Thresholded TGI Mask</button><br/><br/>';
                                        }
                                    } else {
                                        $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_apply_tgi_removed_background_mask_to_denoised_image" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'"  data-background_removed_tgi_stitched_image_id="'.$d->{threshold_background_removed_tgi_stitched_image_id}.'" >Remove Background From Original Denoised Image via Thresholded TGI Mask</button><br/><br/>';
                                    }
                                    if ($d->{denoised_background_removed_tgi_mask_original_image}) {
                                        $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-3"><h5>TGI Vegetative Index Mask on Original Denoised Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{denoised_background_removed_tgi_mask_original_image_id}.'"></span></h5><b>By</b>: '.$d->{denoised_background_removed_tgi_mask_original_image_username}.'</br><b>Date</b>: '.$d->{denoised_background_removed_tgi_mask_original_modified_date}.'</div><div class="col-sm-3">'.$d->{denoised_background_removed_tgi_mask_original_image}.'</div><div class="col-sm-6">';

                                        $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_plot_polygons" data-stitched_image_id="'.$d->{stitched_image_id}.'" data-cropped_stitched_image_id="'.$d->{cropped_stitched_image_id}.'" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-background_removed_stitched_image_id="'.$d->{denoised_background_removed_tgi_mask_original_image_id}.'" data-assign_plot_polygons_type="observation_unit_polygon_original_background_removed_tgi_mask_imagery">Create/View Plot Polygons</button>';

                                        $drone_run_band_table_html .= '<hr>';
                                        my $plot_polygon_original_background_removed_tgi_mask_images = '';
                                        if ($d->{plot_polygon_original_background_removed_tgi_mask_images}) {
                                            $plot_polygon_original_background_removed_tgi_mask_images = scalar(@{$d->{plot_polygon_original_background_removed_tgi_mask_images}})." Plot Polygons<br/><span>";
                                            $plot_polygon_original_background_removed_tgi_mask_images .= join '', @{$d->{plot_polygon_original_background_removed_tgi_mask_images}};
                                            $plot_polygon_original_background_removed_tgi_mask_images .= "</span>";
                                            $plot_polygon_original_background_removed_tgi_mask_images .= '<br/><br/>';
                                            $plot_polygon_original_background_removed_tgi_mask_images .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_get_phenotypes" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'" data-plot_polygons_type="observation_unit_polygon_original_background_removed_tgi_mask_imagery" >Calculate Phenotypes</button>';
                                        } else {
                                            $plot_polygon_original_background_removed_tgi_mask_images = 'No Plot Polygons Assigned';
                                        }
                                        $drone_run_band_table_html .= $plot_polygon_original_background_removed_tgi_mask_images;

                                        $drone_run_band_table_html .= '</div></div></div>';

                                        if ($d->{calculate_fourier_transform_hpf30_bgr_denoised_background_removed_tgi_mask_original_channel_1_image}) {
                                            $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-3"><h5>FT HPF30 Denoised Channel 1 with Background Removed via TGI Mask&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{calculate_fourier_transform_hpf30_bgr_denoised_background_removed_tgi_mask_original_channel_1_image_id}.'"></span></h5><b>By</b>: '.$d->{calculate_fourier_transform_hpf30_bgr_denoised_background_removed_tgi_mask_original_channel_1_image_username}.'</br><b>Date</b>: '.$d->{calculate_fourier_transform_hpf30_bgr_denoised_background_removed_tgi_mask_original_channel_1_modified_date}.'</div><div class="col-sm-3">'.$d->{calculate_fourier_transform_hpf30_bgr_denoised_background_removed_tgi_mask_original_channel_1_image}.'</div><div class="col-sm-6">';
                                            $drone_run_band_table_html .= '</div></div></div>';
                                        } else {
                                            $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_fourier_transform_hpf30" data-image_id="'.$d->{denoised_background_removed_tgi_mask_original_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'", data-selected_image_type="denoised_background_removed_tgi_mask_original" >Fourier Transform HPF30 Denoised Image Channel 1 with Background Removed via TGI Mask</button><br/><br/>';
                                        }
                                    } else {
                                        $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_apply_tgi_mask_to_denoised_image" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'"  data-tgi_stitched_image_id="'.$d->{calculate_tgi_drone_imagery}.'" >Remove Background From Original Denoised Image via TGI Mask</button><br/><br/>';
                                    }
                                } else {
                                    $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_remove_background" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-denoised_stitched_image="'.uri_encode($d->{denoised_stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-remove_background_current_image_id="'.$d->{vegetative_index_tgi_image_id}.'" data-remove_background_current_image_type="threshold_background_removed_tgi_stitched_drone_imagery" >TGI Vegetative Index Remove Background via Threshold</button><br/><br/>';
                                }
                            }
                            if ($d->{vegetative_index_vari_stitched_image}) {
                                $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-3"><h5>VARI Vegetative Index Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{vegetative_index_vari_image_id}.'"></span></h5><b>By</b>: '.$d->{vegetative_index_tgi_username}.'</br><b>Date</b>: '.$d->{vegetative_index_vari_modified_date}.'</div><div class="col-sm-3">'.$d->{vegetative_index_vari_stitched_image}.'</div><div class="col-sm-6">';

                                $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_plot_polygons" data-stitched_image_id="'.$d->{stitched_image_id}.'" data-cropped_stitched_image_id="'.$d->{cropped_stitched_image_id}.'" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-background_removed_stitched_image_id="'.$d->{vegetative_index_vari_image_id}.'" data-assign_plot_polygons_type="observation_unit_polygon_vari_imagery">Create/View Plot Polygons</button>';

                                $drone_run_band_table_html .= '<hr>';
                                my $plot_polygon_vari_images = '';
                                if ($d->{plot_polygon_vari_images}) {
                                    $plot_polygon_vari_images = scalar(@{$d->{plot_polygon_vari_images}})." Plot Polygons<br/><span>";
                                    $plot_polygon_vari_images .= join '', @{$d->{plot_polygon_vari_images}};
                                    $plot_polygon_vari_images .= "</span>";
                                    $plot_polygon_vari_images .= '<br/><br/>';
                                    $plot_polygon_vari_images .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_get_phenotypes" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'" data-plot_polygons_type="observation_unit_polygon_vari_imagery" >Calculate Phenotypes</button>';
                                } else {
                                    $plot_polygon_vari_images = 'No Plot Polygons Assigned';
                                }
                                $drone_run_band_table_html .= $plot_polygon_vari_images;

                                $drone_run_band_table_html .= '</div></div></div>';

                                if ($d->{calculate_fourier_transform_hpf30_bgr_calculate_vari_drone_imagery_channel_1_image}) {
                                    $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-3"><h5>FT HPF30 VARI Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{calculate_fourier_transform_hpf30_bgr_calculate_vari_drone_imagery_channel_1_image_id}.'"></span></h5><b>By</b>: '.$d->{calculate_fourier_transform_hpf30_bgr_calculate_vari_drone_imagery_channel_1_image_username}.'</br><b>Date</b>: '.$d->{calculate_fourier_transform_hpf30_bgr_calculate_vari_drone_imagery_channel_1_modified_date}.'</div><div class="col-sm-3">'.$d->{calculate_fourier_transform_hpf30_bgr_calculate_vari_drone_imagery_channel_1_image}.'</div><div class="col-sm-6">';

                                    $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_plot_polygons" data-stitched_image_id="'.$d->{stitched_image_id}.'" data-cropped_stitched_image_id="'.$d->{cropped_stitched_image_id}.'" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-background_removed_stitched_image_id="'.$d->{calculate_fourier_transform_hpf30_bgr_calculate_vari_drone_imagery_channel_1_image_id}.'" data-assign_plot_polygons_type="observation_unit_polygon_fourier_transform_hpf30_bgr_calculate_vari_drone_imagery_channel_1">Create/View Plot Polygons</button>';

                                    $drone_run_band_table_html .= '<hr>';
                                    my $plot_polygon_ft_hpf30_vari_images = '';
                                    if ($d->{plot_polygon_fourier_transform_hpf30_bgr_calculate_vari_drone_imagery_channel_1_images}) {
                                        $plot_polygon_ft_hpf30_vari_images = scalar(@{$d->{plot_polygon_fourier_transform_hpf30_bgr_calculate_vari_drone_imagery_channel_1_images}})." Plot Polygons<br/><span>";
                                        $plot_polygon_ft_hpf30_vari_images .= join '', @{$d->{plot_polygon_fourier_transform_hpf30_bgr_calculate_vari_drone_imagery_channel_1_images}};
                                        $plot_polygon_ft_hpf30_vari_images .= "</span>";
                                        $plot_polygon_ft_hpf30_vari_images .= '<br/><br/>';
                                        $plot_polygon_ft_hpf30_vari_images .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_get_phenotypes" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'" data-plot_polygons_type="observation_unit_polygon_fourier_transform_hpf30_bgr_calculate_vari_drone_imagery_channel_1" >Calculate Phenotypes</button>';
                                    } else {
                                        $plot_polygon_ft_hpf30_vari_images = 'No Plot Polygons Assigned';
                                    }
                                    $drone_run_band_table_html .= $plot_polygon_ft_hpf30_vari_images;

                                    $drone_run_band_table_html .= '</div></div></div>';
                                } else {
                                    $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_fourier_transform_hpf30" data-image_id="'.$d->{vegetative_index_vari_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'", data-selected_image_type="calculate_vari_drone_imagery" >Fourier Transform HPF30 VARI Channel 1</button><br/><br/>';
                                }

                                if ($d->{threshold_background_removed_vari_stitched_image}) {
                                    $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-3"><h5>Background Removed VARI Vegetative Index Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{threshold_background_removed_vari_stitched_image_id}.'"></span></h5><b>By</b>: '.$d->{threshold_background_removed_vari_stitched_image_username}.'</br><b>Date</b>: '.$d->{threshold_background_removed_vari_stitched_image_modified_date}.'<br/><b>Background Removed Threshold</b>: '.$d->{threshold_background_removed_vari_stitched_image_threshold}.'</div><div class="col-sm-3">'.$d->{threshold_background_removed_vari_stitched_image}.'</div><div class="col-sm-6">';

                                    $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_plot_polygons" data-stitched_image_id="'.$d->{stitched_image_id}.'" data-cropped_stitched_image_id="'.$d->{cropped_stitched_image_id}.'" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-background_removed_stitched_image_id="'.$d->{threshold_background_removed_vari_stitched_image_id}.'" data-assign_plot_polygons_type="observation_unit_polygon_background_removed_vari_imagery">Create/View Plot Polygons</button>';

                                    $drone_run_band_table_html .= '<hr>';
                                    my $plot_polygon_background_removed_vari_images = '';
                                    if ($d->{plot_polygon_background_removed_vari_images}) {
                                        $plot_polygon_background_removed_vari_images = scalar(@{$d->{plot_polygon_background_removed_vari_images}})." Plot Polygons<br/><span>";
                                        $plot_polygon_background_removed_vari_images .= join '', @{$d->{plot_polygon_background_removed_vari_images}};
                                        $plot_polygon_background_removed_vari_images .= "</span>";
                                        $plot_polygon_background_removed_vari_images .= '<br/><br/>';
                                        $plot_polygon_background_removed_vari_images .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_get_phenotypes" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'" data-plot_polygons_type="observation_unit_polygon_background_removed_vari_imagery" >Calculate Phenotypes</button>';
                                    } else {
                                        $plot_polygon_background_removed_vari_images = 'No Plot Polygons Assigned';
                                    }
                                    $drone_run_band_table_html .= $plot_polygon_background_removed_vari_images;

                                    $drone_run_band_table_html .= '</div></div></div>';

                                    if ($d->{calculate_fourier_transform_hpf30_bgr_threshold_background_removed_vari_stitched_drone_imagery_channel_1_image}) {
                                        $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-3"><h5>FT HPF30 VARI with Background Removed via Threshold&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{calculate_fourier_transform_hpf30_bgr_threshold_background_removed_vari_stitched_drone_imagery_channel_1_image_id}.'"></span></h5><b>By</b>: '.$d->{calculate_fourier_transform_hpf30_bgr_threshold_background_removed_vari_stitched_drone_imagery_channel_1_image_username}.'</br><b>Date</b>: '.$d->{calculate_fourier_transform_hpf30_bgr_threshold_background_removed_vari_stitched_drone_imagery_channel_1_modified_date}.'</div><div class="col-sm-3">'.$d->{calculate_fourier_transform_hpf30_bgr_threshold_background_removed_vari_stitched_drone_imagery_channel_1_image}.'</div><div class="col-sm-6">';
                                        $drone_run_band_table_html .= '</div></div></div>';
                                    } else {
                                        $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_fourier_transform_hpf30" data-image_id="'.$d->{threshold_background_removed_vari_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'", data-selected_image_type="threshold_background_removed_vari_stitched_drone_imagery" >Fourier Transform HPF30 VARI Channel 1 with Background Removed via Threshold</button><br/><br/>';
                                    }

                                    if ($d->{denoised_background_removed_thresholded_vari_mask_original_image}) {
                                        $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-3"><h5>Background Removed VARI Vegetative Index Mask on Original Denoised Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{denoised_background_removed_thresholded_vari_mask_original_image_id}.'"></span></h5><b>By</b>: '.$d->{denoised_background_removed_thresholded_vari_mask_original_image_username}.'</br><b>Date</b>: '.$d->{denoised_background_removed_thresholded_vari_mask_original_image_modified_date}.'</div><div class="col-sm-3">'.$d->{denoised_background_removed_thresholded_vari_mask_original_image}.'</div><div class="col-sm-6">';

                                        $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_plot_polygons" data-stitched_image_id="'.$d->{stitched_image_id}.'" data-cropped_stitched_image_id="'.$d->{cropped_stitched_image_id}.'" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-background_removed_stitched_image_id="'.$d->{denoised_background_removed_thresholded_vari_mask_original_image_id}.'" data-assign_plot_polygons_type="observation_unit_polygon_original_background_removed_thresholded_vari_mask_imagery" >Create/View Plot Polygons</button>';

                                        $drone_run_band_table_html .= '<hr>';
                                        my $plot_polygon_original_background_removed_thresholded_vari_mask_images = '';
                                        if ($d->{plot_polygon_original_background_removed_thresholded_vari_mask_images}) {
                                            $plot_polygon_original_background_removed_thresholded_vari_mask_images = scalar(@{$d->{plot_polygon_original_background_removed_thresholded_vari_mask_images}})." Plot Polygons<br/><span>";
                                            $plot_polygon_original_background_removed_thresholded_vari_mask_images .= join '', @{$d->{plot_polygon_original_background_removed_thresholded_vari_mask_images}};
                                            $plot_polygon_original_background_removed_thresholded_vari_mask_images .= "</span>";
                                            $plot_polygon_original_background_removed_thresholded_vari_mask_images .= '<br/><br/>';
                                            $plot_polygon_original_background_removed_thresholded_vari_mask_images .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_get_phenotypes" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'" data-plot_polygons_type="observation_unit_polygon_original_background_removed_thresholded_vari_mask_imagery" >Calculate Phenotypes</button>';
                                        } else {
                                            $plot_polygon_original_background_removed_thresholded_vari_mask_images = 'No Plot Polygons Assigned';
                                        }
                                        $drone_run_band_table_html .= $plot_polygon_original_background_removed_thresholded_vari_mask_images;

                                        $drone_run_band_table_html .= '</div></div></div>';

                                        if ($d->{calculate_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_vari_mask_original_channel_1_image}) {
                                            $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-3"><h5>FT HPF30 Denoised Channel 1 with Background Removed via Thresholded VARI Mask&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{calculate_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_vari_mask_original_channel_1_image_id}.'"></span></h5><b>By</b>: '.$d->{calculate_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_vari_mask_original_channel_1_image_username}.'</br><b>Date</b>: '.$d->{calculate_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_vari_mask_original_channel_1_modified_date}.'</div><div class="col-sm-3">'.$d->{calculate_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_vari_mask_original_channel_1_image}.'</div><div class="col-sm-6">';
                                            $drone_run_band_table_html .= '</div></div></div>';
                                        } else {
                                            $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_fourier_transform_hpf30" data-image_id="'.$d->{denoised_background_removed_thresholded_vari_mask_original_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'", data-selected_image_type="denoised_background_removed_thresholded_vari_mask_original" >Fourier Transform HPF30 Denoised Image Channel 1 with Background Removed via Thresholded VARI Mask</button><br/><br/>';
                                        }
                                    } else {
                                        $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_apply_vari_removed_background_mask_to_denoised_image" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'"  data-background_removed_vari_stitched_image_id="'.$d->{threshold_background_removed_vari_stitched_image_id}.'" >Remove Background From Original Denoised Image via Thresholded VARI Mask</button><br/><br/>';
                                    }
                                    if ($d->{denoised_background_removed_vari_mask_original_image}) {
                                        $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-3"><h5>VARI Vegetative Index Mask on Original Denoised Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{denoised_background_removed_vari_mask_original_image_id}.'"></span></h5><b>By</b>: '.$d->{denoised_background_removed_vari_mask_original_image_username}.'</br><b>Date</b>: '.$d->{denoised_background_removed_vari_mask_original_image_modified_date}.'</div><div class="col-sm-3">'.$d->{denoised_background_removed_vari_mask_original_image}.'</div><div class="col-sm-6">';

                                        $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_plot_polygons" data-stitched_image_id="'.$d->{stitched_image_id}.'" data-cropped_stitched_image_id="'.$d->{cropped_stitched_image_id}.'" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-background_removed_stitched_image_id="'.$d->{denoised_background_removed_vari_mask_original_image_id}.'" data-assign_plot_polygons_type="observation_unit_polygon_original_background_removed_vari_mask_imagery" >Create/View Plot Polygons</button>';

                                        $drone_run_band_table_html .= '<hr>';
                                        my $plot_polygon_original_background_removed_vari_mask_images = '';
                                        if ($d->{plot_polygon_original_background_removed_vari_mask_images}) {
                                            $plot_polygon_original_background_removed_vari_mask_images = scalar(@{$d->{plot_polygon_original_background_removed_vari_mask_images}})." Plot Polygons<br/><span>";
                                            $plot_polygon_original_background_removed_vari_mask_images .= join '', @{$d->{plot_polygon_original_background_removed_vari_mask_images}};
                                            $plot_polygon_original_background_removed_vari_mask_images .= "</span>";
                                            $plot_polygon_original_background_removed_vari_mask_images .= '<br/><br/>';
                                            $plot_polygon_original_background_removed_vari_mask_images .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_get_phenotypes" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'" data-plot_polygons_type="observation_unit_polygon_original_background_removed_vari_mask_imagery" >Calculate Phenotypes</button>';
                                        } else {
                                            $plot_polygon_original_background_removed_vari_mask_images = 'No Plot Polygons Assigned';
                                        }
                                        $drone_run_band_table_html .= $plot_polygon_original_background_removed_vari_mask_images;

                                        $drone_run_band_table_html .= '</div></div></div>';

                                        if ($d->{calculate_fourier_transform_hpf30_bgr_denoised_background_removed_vari_mask_original_channel_1_image}) {
                                            $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-3"><h5>FT HPF30 Denoised Channel 1 with Background Removed via VARI Mask&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{calculate_fourier_transform_hpf30_bgr_denoised_background_removed_vari_mask_original_channel_1_image_id}.'"></span></h5><b>By</b>: '.$d->{calculate_fourier_transform_hpf30_bgr_denoised_background_removed_vari_mask_original_channel_1_image_username}.'</br><b>Date</b>: '.$d->{calculate_fourier_transform_hpf30_bgr_denoised_background_removed_vari_mask_original_channel_1_modified_date}.'</div><div class="col-sm-3">'.$d->{calculate_fourier_transform_hpf30_bgr_denoised_background_removed_vari_mask_original_channel_1_image}.'</div><div class="col-sm-6">';
                                            $drone_run_band_table_html .= '</div></div></div>';
                                        } else {
                                            $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_fourier_transform_hpf30" data-image_id="'.$d->{denoised_background_removed_vari_mask_original_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'", data-selected_image_type="denoised_background_removed_vari_mask_original" >Fourier Transform HPF30 Denoised Image Channel 1 with Background Removed via VARI MASK</button><br/><br/>';
                                        }
                                    } else {
                                        $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_apply_vari_mask_to_denoised_image" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'"  data-vari_stitched_image_id="'.$d->{calculate_vari_drone_imagery}.'" >Remove Background From Original Denoised Image via VARI Mask</button><br/><br/>';
                                    }
                                } else {
                                    $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_remove_background" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-denoised_stitched_image="'.uri_encode($d->{denoised_stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-remove_background_current_image_id="'.$d->{vegetative_index_vari_image_id}.'" data-remove_background_current_image_type="threshold_background_removed_vari_stitched_drone_imagery" >VARI Vegetative Index Remove Background via Threshold</button><br/><br/>';
                                }
                            }
                            if ($d->{vegetative_index_ndvi_stitched_image}) {
                                $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-3"><h5>NDVI Vegetative Index Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{vegetative_index_ndvi_image_id}.'"></span></h5><b>By</b>: '.$d->{vegetative_index_ndvi_username}.'</br><b>Date</b>: '.$d->{vegetative_index_ndvi_modified_date}.'</div><div class="col-sm-3">'.$d->{vegetative_index_ndvi_stitched_image}.'</div><div class="col-sm-6">';

                                $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_plot_polygons" data-stitched_image_id="'.$d->{stitched_image_id}.'" data-cropped_stitched_image_id="'.$d->{cropped_stitched_image_id}.'" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-background_removed_stitched_image_id="'.$d->{vegetative_index_ndvi_image_id}.'" data-assign_plot_polygons_type="observation_unit_polygon_ndvi_imagery">Create/View Plot Polygons</button>';

                                $drone_run_band_table_html .= '<hr>';
                                my $plot_polygon_ndvi_images = '';
                                if ($d->{plot_polygon_ndvi_images}) {
                                    $plot_polygon_ndvi_images = scalar(@{$d->{plot_polygon_ndvi_images}})." Plot Polygons<br/><span>";
                                    $plot_polygon_ndvi_images .= join '', @{$d->{plot_polygon_ndvi_images}};
                                    $plot_polygon_ndvi_images .= "</span>";
                                    $plot_polygon_ndvi_images .= '<br/><br/>';
                                    $plot_polygon_ndvi_images .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_get_phenotypes" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'" data-plot_polygons_type="observation_unit_polygon_ndvi_imagery" >Calculate Phenotypes</button>';
                                } else {
                                    $plot_polygon_ndvi_images = 'No Plot Polygons Assigned';
                                }
                                $drone_run_band_table_html .= $plot_polygon_ndvi_images;

                                $drone_run_band_table_html .= '</div></div></div>';

                                if ($d->{calculate_fourier_transform_hpf30_nrn_calculate_ndvi_drone_imagery_channel_1_image}) {
                                    $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-3"><h5>FT HPF30 NDVI&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{calculate_fourier_transform_hpf30_nrn_calculate_ndvi_drone_imagery_channel_1_image_id}.'"></span></h5><b>By</b>: '.$d->{calculate_fourier_transform_hpf30_nrn_calculate_ndvi_drone_imagery_channel_1_image_username}.'</br><b>Date</b>: '.$d->{calculate_fourier_transform_hpf30_nrn_calculate_ndvi_drone_imagery_channel_1_modified_date}.'</div><div class="col-sm-3">'.$d->{calculate_fourier_transform_hpf30_nrn_calculate_ndvi_drone_imagery_channel_1_image}.'</div><div class="col-sm-6">';
                                    $drone_run_band_table_html .= '</div></div></div>';
                                } else {
                                    $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_fourier_transform_hpf30" data-image_id="'.$d->{vegetative_index_ndvi_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'", data-selected_image_type="calculate_ndvi_drone_imagery" >Fourier Transform HPF30 NDVI Channel 1</button><br/><br/>';
                                }

                                if ($d->{threshold_background_removed_ndvi_stitched_image}) {
                                    $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-3"><h5>Background Removed NDVI Vegetative Index Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{threshold_background_removed_ndvi_stitched_image_id}.'"></span></h5><b>By</b>: '.$d->{threshold_background_removed_ndvi_stitched_image_username}.'</br><b>Date</b>: '.$d->{threshold_background_removed_ndvi_stitched_image_modified_date}.'<br/><b>Background Removed Threshold</b>: '.$d->{threshold_background_removed_ndvi_stitched_image_threshold}.'</div><div class="col-sm-3">'.$d->{threshold_background_removed_ndvi_stitched_image}.'</div><div class="col-sm-6">';

                                    $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_plot_polygons" data-stitched_image_id="'.$d->{stitched_image_id}.'" data-cropped_stitched_image_id="'.$d->{cropped_stitched_image_id}.'" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-background_removed_stitched_image_id="'.$d->{threshold_background_removed_ndvi_stitched_image_id}.'" data-assign_plot_polygons_type="observation_unit_polygon_background_removed_ndvi_imagery">Create/View Plot Polygons</button>';

                                    $drone_run_band_table_html .= '<hr>';
                                    my $plot_polygon_background_removed_ndvi_images = '';
                                    if ($d->{plot_polygon_background_removed_ndvi_images}) {
                                        $plot_polygon_background_removed_ndvi_images = scalar(@{$d->{plot_polygon_background_removed_ndvi_images}})." Plot Polygons<br/><span>";
                                        $plot_polygon_background_removed_ndvi_images .= join '', @{$d->{plot_polygon_background_removed_ndvi_images}};
                                        $plot_polygon_background_removed_ndvi_images .= "</span>";
                                        $plot_polygon_background_removed_ndvi_images .= '<br/><br/>';
                                        $plot_polygon_background_removed_ndvi_images .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_get_phenotypes" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'" data-plot_polygons_type="observation_unit_polygon_background_removed_ndvi_imagery" >Calculate Phenotypes</button>';
                                    } else {
                                        $plot_polygon_background_removed_ndvi_images = 'No Plot Polygons Assigned';
                                    }
                                    $drone_run_band_table_html .= $plot_polygon_background_removed_ndvi_images;

                                    $drone_run_band_table_html .= '</div></div></div>';

                                    if ($d->{calculate_fourier_transform_hpf30_nrn_threshold_background_removed_ndvi_stitched_drone_imagery_channel_1_image}) {
                                        $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-3"><h5>FT HPF30 NDVI with Background Removed via Threshold&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{calculate_fourier_transform_hpf30_nrn_threshold_background_removed_ndvi_stitched_drone_imagery_channel_1_image_id}.'"></span></h5><b>By</b>: '.$d->{calculate_fourier_transform_hpf30_nrn_threshold_background_removed_ndvi_stitched_drone_imagery_channel_1_image_username}.'</br><b>Date</b>: '.$d->{calculate_fourier_transform_hpf30_nrn_threshold_background_removed_ndvi_stitched_drone_imagery_channel_1_modified_date}.'</div><div class="col-sm-3">'.$d->{calculate_fourier_transform_hpf30_nrn_threshold_background_removed_ndvi_stitched_drone_imagery_channel_1_image}.'</div><div class="col-sm-6">';
                                        $drone_run_band_table_html .= '</div></div></div>';
                                    } else {
                                        $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_fourier_transform_hpf30" data-image_id="'.$d->{threshold_background_removed_ndvi_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'", data-selected_image_type="threshold_background_removed_ndvi_stitched_drone_imagery" >Fourier Transform HPF30 NDVI Channel 1 with Background Removed via Threshold</button><br/><br/>';
                                    }

                                    if ($d->{denoised_background_removed_thresholded_ndvi_mask_original_image}) {
                                        $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-3"><h5>Background Removed NDVI Vegetative Index Mask on Original Denoised Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{denoised_background_removed_thresholded_ndvi_mask_original_image_id}.'"></span></h5><b>By</b>: '.$d->{denoised_background_removed_thresholded_ndvi_mask_original_image_username}.'</br><b>Date</b>: '.$d->{denoised_background_removed_thresholded_ndvi_mask_original_image_modified_date}.'</div><div class="col-sm-3">'.$d->{denoised_background_removed_thresholded_ndvi_mask_original_image}.'</div><div class="col-sm-6">';

                                        $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_plot_polygons" data-stitched_image_id="'.$d->{stitched_image_id}.'" data-cropped_stitched_image_id="'.$d->{cropped_stitched_image_id}.'" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-background_removed_stitched_image_id="'.$d->{denoised_background_removed_thresholded_ndvi_mask_original_image_id}.'" data-assign_plot_polygons_type="observation_unit_polygon_original_background_removed_thresholded_ndvi_mask_imagery" >Create/View Plot Polygons</button>';

                                        $drone_run_band_table_html .= '<hr>';
                                        my $plot_polygon_original_background_removed_thresholded_ndvi_mask_images = '';
                                        if ($d->{plot_polygon_original_background_removed_thresholded_ndvi_mask_images}) {
                                            $plot_polygon_original_background_removed_thresholded_ndvi_mask_images = scalar(@{$d->{plot_polygon_original_background_removed_thresholded_ndvi_mask_images}})." Plot Polygons<br/><span>";
                                            $plot_polygon_original_background_removed_thresholded_ndvi_mask_images .= join '', @{$d->{plot_polygon_original_background_removed_thresholded_ndvi_mask_images}};
                                            $plot_polygon_original_background_removed_thresholded_ndvi_mask_images .= "</span>";
                                            $plot_polygon_original_background_removed_thresholded_ndvi_mask_images .= '<br/><br/>';
                                            $plot_polygon_original_background_removed_thresholded_ndvi_mask_images .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_get_phenotypes" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'" data-plot_polygons_type="observation_unit_polygon_original_background_removed_thresholded_ndvi_mask_imagery" >Calculate Phenotypes</button>';
                                        } else {
                                            $plot_polygon_original_background_removed_thresholded_ndvi_mask_images = 'No Plot Polygons Assigned';
                                        }
                                        $drone_run_band_table_html .= $plot_polygon_original_background_removed_thresholded_ndvi_mask_images;

                                        $drone_run_band_table_html .= '</div></div></div>';

                                        if ($d->{calculate_fourier_transform_hpf30_nrn_denoised_background_removed_thresholded_ndvi_mask_original_channel_1_image}) {
                                            $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-3"><h5>FT HPF30 Denoised Channel 1 with Background Removed via Thresholded NDVI Mask&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{calculate_fourier_transform_hpf30_nrn_denoised_background_removed_thresholded_ndvi_mask_original_channel_1_image_id}.'"></span></h5><b>By</b>: '.$d->{calculate_fourier_transform_hpf30_nrn_denoised_background_removed_thresholded_ndvi_mask_original_channel_1_image_username}.'</br><b>Date</b>: '.$d->{calculate_fourier_transform_hpf30_nrn_denoised_background_removed_thresholded_ndvi_mask_original_channel_1_modified_date}.'</div><div class="col-sm-3">'.$d->{calculate_fourier_transform_hpf30_nrn_denoised_background_removed_thresholded_ndvi_mask_original_channel_1_image}.'</div><div class="col-sm-6">';
                                            $drone_run_band_table_html .= '</div></div></div>';
                                        } else {
                                            $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_fourier_transform_hpf30" data-image_id="'.$d->{denoised_background_removed_thresholded_ndvi_mask_original_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'", data-selected_image_type="denoised_background_removed_thresholded_ndvi_mask_original" >Fourier Transform HPF30 Denoised Image Channel 1 with Background Removed via Thresholded NDVI Mask</button><br/><br/>';
                                        }
                                    } else {
                                        $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_apply_ndvi_removed_background_mask_to_denoised_image" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'"  data-background_removed_ndvi_stitched_image_id="'.$d->{threshold_background_removed_ndvi_stitched_image_id}.'" >Remove Background From Original Denoised Image via Thresholded NDVI Mask</button><br/><br/>';
                                    }
                                    if ($d->{denoised_background_removed_ndvi_mask_original_image}) {
                                        $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-3"><h5>NDVI Vegetative Index Mask on Original Denoised Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{denoised_background_removed_ndvi_mask_original_image_id}.'"></span></h5><b>By</b>: '.$d->{denoised_background_removed_ndvi_mask_original_image_username}.'</br><b>Date</b>: '.$d->{denoised_background_removed_ndvi_mask_original_image_modified_date}.'</div><div class="col-sm-3">'.$d->{denoised_background_removed_ndvi_mask_original_image}.'</div><div class="col-sm-6">';

                                        $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_plot_polygons" data-stitched_image_id="'.$d->{stitched_image_id}.'" data-cropped_stitched_image_id="'.$d->{cropped_stitched_image_id}.'" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-background_removed_stitched_image_id="'.$d->{denoised_background_removed_ndvi_mask_original_image_id}.'" data-assign_plot_polygons_type="observation_unit_polygon_original_background_removed_ndvi_mask_imagery" >Create/View Plot Polygons</button>';

                                        $drone_run_band_table_html .= '<hr>';
                                        my $plot_polygon_original_background_removed_ndvi_mask_images = '';
                                        if ($d->{plot_polygon_original_background_removed_ndvi_mask_images}) {
                                            $plot_polygon_original_background_removed_ndvi_mask_images = scalar(@{$d->{plot_polygon_original_background_removed_ndvi_mask_images}})." Plot Polygons<br/><span>";
                                            $plot_polygon_original_background_removed_ndvi_mask_images .= join '', @{$d->{plot_polygon_original_background_removed_ndvi_mask_images}};
                                            $plot_polygon_original_background_removed_ndvi_mask_images .= "</span>";
                                            $plot_polygon_original_background_removed_ndvi_mask_images .= '<br/><br/>';
                                            $plot_polygon_original_background_removed_ndvi_mask_images .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_get_phenotypes" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'" data-plot_polygons_type="observation_unit_polygon_original_background_removed_ndvi_mask_imagery" >Calculate Phenotypes</button>';
                                        } else {
                                            $plot_polygon_original_background_removed_ndvi_mask_images = 'No Plot Polygons Assigned';
                                        }
                                        $drone_run_band_table_html .= $plot_polygon_original_background_removed_ndvi_mask_images;

                                        $drone_run_band_table_html .= '</div></div></div>';

                                        if ($d->{calculate_fourier_transform_hpf30_nrn_denoised_background_removed_ndvi_mask_original_channel_1_image}) {
                                            $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-3"><h5>FT HPF30 Denoised Channel 1 with Background Removed via NDVI Mask&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{calculate_fourier_transform_hpf30_nrn_denoised_background_removed_ndvi_mask_original_channel_1_image_id}.'"></span></h5><b>By</b>: '.$d->{calculate_fourier_transform_hpf30_nrn_denoised_background_removed_ndvi_mask_original_channel_1_image_username}.'</br><b>Date</b>: '.$d->{calculate_fourier_transform_hpf30_nrn_denoised_background_removed_ndvi_mask_original_channel_1_modified_date}.'</div><div class="col-sm-3">'.$d->{calculate_fourier_transform_hpf30_nrn_denoised_background_removed_ndvi_mask_original_channel_1_image}.'</div><div class="col-sm-6">';
                                            $drone_run_band_table_html .= '</div></div></div>';
                                        } else {
                                            $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_fourier_transform_hpf30" data-image_id="'.$d->{denoised_background_removed_ndvi_mask_original_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'", data-selected_image_type="denoised_background_removed_ndvi_mask_original" >Fourier Transform HPF30 Denoised Channel 1 with Background Removed via NDVI Mask</button><br/><br/>';
                                        }
                                    } else {
                                        $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_apply_ndvi_mask_to_denoised_image" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'"  data-ndvi_stitched_image_id="'.$d->{calculate_ndvi_drone_imagery}.'" >Remove Background From Original Denoised Image via NDVI Mask</button><br/><br/>';
                                    }
                                } else {
                                    $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_remove_background" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-denoised_stitched_image="'.uri_encode($d->{denoised_stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-remove_background_current_image_id="'.$d->{vegetative_index_ndvi_image_id}.'" data-remove_background_current_image_type="threshold_background_removed_ndvi_stitched_drone_imagery" >NDVI Vegetative Index Remove Background via Threshold</button><br/><br/>';
                                }
                            }
                            if ($d->{vegetative_index_ndre_stitched_image}) {
                                $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-3"><h5>NDRE Vegetative Index Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{vegetative_index_ndre_image_id}.'"></span></h5><b>By</b>: '.$d->{vegetative_index_ndre_username}.'</br><b>Date</b>: '.$d->{vegetative_index_ndre_modified_date}.'</div><div class="col-sm-3">'.$d->{vegetative_index_ndre_stitched_image}.'</div><div class="col-sm-6">';

                                $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_plot_polygons" data-stitched_image_id="'.$d->{stitched_image_id}.'" data-cropped_stitched_image_id="'.$d->{cropped_stitched_image_id}.'" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-background_removed_stitched_image_id="'.$d->{vegetative_index_ndre_image_id}.'" data-assign_plot_polygons_type="observation_unit_polygon_ndre_imagery">Create/View Plot Polygons</button>';

                                $drone_run_band_table_html .= '<hr>';
                                my $plot_polygon_ndre_images = '';
                                if ($d->{plot_polygon_ndre_images}) {
                                    $plot_polygon_ndre_images = scalar(@{$d->{plot_polygon_ndre_images}})." Plot Polygons<br/><span>";
                                    $plot_polygon_ndre_images .= join '', @{$d->{plot_polygon_ndre_images}};
                                    $plot_polygon_ndre_images .= "</span>";
                                    $plot_polygon_ndre_images .= '<br/><br/>';
                                    $plot_polygon_ndre_images .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_get_phenotypes" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'" data-plot_polygons_type="observation_unit_polygon_ndre_imagery" >Calculate Phenotypes</button>';
                                } else {
                                    $plot_polygon_ndre_images = 'No Plot Polygons Assigned';
                                }
                                $drone_run_band_table_html .= $plot_polygon_ndre_images;

                                $drone_run_band_table_html .= '</div></div></div>';

                                if ($d->{calculate_fourier_transform_hpf30_nren_calculate_ndre_drone_imagery_channel_1_image}) {
                                    $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-3"><h5>FT HPF30 NDRE Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{calculate_fourier_transform_hpf30_nren_calculate_ndre_drone_imagery_channel_1_image_id}.'"></span></h5><b>By</b>: '.$d->{calculate_fourier_transform_hpf30_nren_calculate_ndre_drone_imagery_channel_1_image_username}.'</br><b>Date</b>: '.$d->{calculate_fourier_transform_hpf30_nren_calculate_ndre_drone_imagery_channel_1_modified_date}.'</div><div class="col-sm-3">'.$d->{calculate_fourier_transform_hpf30_nren_calculate_ndre_drone_imagery_channel_1_image}.'</div><div class="col-sm-6">';
                                    $drone_run_band_table_html .= '</div></div></div>';
                                } else {
                                    $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_fourier_transform_hpf30" data-image_id="'.$d->{vegetative_index_ndre_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'", data-selected_image_type="calculate_ndre_drone_imagery" >Fourier Transform HPF30 NDRE Channel 1</button><br/><br/>';
                                }

                                if ($d->{threshold_background_removed_ndre_stitched_image}) {
                                    $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-3"><h5>Background Removed NDRE Vegetative Index Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{threshold_background_removed_ndre_stitched_image_id}.'"></span></h5><b>By</b>: '.$d->{threshold_background_removed_ndre_stitched_image_username}.'</br><b>Date</b>: '.$d->{threshold_background_removed_ndre_stitched_image_modified_date}.'<br/><b>Background Removed Threshold</b>: '.$d->{threshold_background_removed_ndre_stitched_image_threshold}.'</div><div class="col-sm-3">'.$d->{threshold_background_removed_ndre_stitched_image}.'</div><div class="col-sm-6">';

                                    $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_plot_polygons" data-stitched_image_id="'.$d->{stitched_image_id}.'" data-cropped_stitched_image_id="'.$d->{cropped_stitched_image_id}.'" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-background_removed_stitched_image_id="'.$d->{threshold_background_removed_ndre_stitched_image_id}.'" data-assign_plot_polygons_type="observation_unit_polygon_background_removed_ndre_imagery">Create/View Plot Polygons</button>';

                                    $drone_run_band_table_html .= '<hr>';
                                    my $plot_polygon_background_removed_ndre_images = '';
                                    if ($d->{plot_polygon_background_removed_ndre_images}) {
                                        $plot_polygon_background_removed_ndre_images = scalar(@{$d->{plot_polygon_background_removed_ndre_images}})." Plot Polygons<br/><span>";
                                        $plot_polygon_background_removed_ndre_images .= join '', @{$d->{plot_polygon_background_removed_ndre_images}};
                                        $plot_polygon_background_removed_ndre_images .= "</span>";
                                        $plot_polygon_background_removed_ndre_images .= '<br/><br/>';
                                        $plot_polygon_background_removed_ndre_images .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_get_phenotypes" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'" data-plot_polygons_type="observation_unit_polygon_background_removed_ndre_imagery" >Calculate Phenotypes</button>';
                                    } else {
                                        $plot_polygon_background_removed_ndre_images = 'No Plot Polygons Assigned';
                                    }
                                    $drone_run_band_table_html .= $plot_polygon_background_removed_ndre_images;

                                    $drone_run_band_table_html .= '</div></div></div>';

                                    if ($d->{calculate_fourier_transform_hpf30_nren_threshold_background_removed_ndre_stitched_drone_imagery_channel_1_image}) {
                                        $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-3"><h5>FT HPF30 NDRE Image with Background Removed via Threshold&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{calculate_fourier_transform_hpf30_nren_threshold_background_removed_ndre_stitched_drone_imagery_channel_1_image_id}.'"></span></h5><b>By</b>: '.$d->{calculate_fourier_transform_hpf30_nren_threshold_background_removed_ndre_stitched_drone_imagery_channel_1_image_username}.'</br><b>Date</b>: '.$d->{calculate_fourier_transform_hpf30_nren_threshold_background_removed_ndre_stitched_drone_imagery_channel_1_modified_date}.'</div><div class="col-sm-3">'.$d->{calculate_fourier_transform_hpf30_nren_threshold_background_removed_ndre_stitched_drone_imagery_channel_1_image}.'</div><div class="col-sm-6">';
                                        $drone_run_band_table_html .= '</div></div></div>';
                                    } else {
                                        $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_fourier_transform_hpf30" data-image_id="'.$d->{threshold_background_removed_ndre_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'", data-selected_image_type="threshold_background_removed_ndre_stitched_drone_imagery" >Fourier Transform HPF30 NDRE Channel 1 with Background Removed via Threshold</button><br/><br/>';
                                    }

                                    if ($d->{denoised_background_removed_thresholded_ndre_mask_original_image}) {
                                        $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-3"><h5>Background Removed NDRE Vegetative Index Mask on Original Denoised Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{denoised_background_removed_thresholded_ndre_mask_original_image_id}.'"></span></h5><b>By</b>: '.$d->{denoised_background_removed_thresholded_ndre_mask_original_image_username}.'</br><b>Date</b>: '.$d->{denoised_background_removed_thresholded_ndre_mask_original_image_modified_date}.'</div><div class="col-sm-3">'.$d->{denoised_background_removed_thresholded_ndre_mask_original_image}.'</div><div class="col-sm-6">';

                                        $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_plot_polygons" data-stitched_image_id="'.$d->{stitched_image_id}.'" data-cropped_stitched_image_id="'.$d->{cropped_stitched_image_id}.'" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-background_removed_stitched_image_id="'.$d->{denoised_background_removed_thresholded_ndre_mask_original_image_id}.'" data-assign_plot_polygons_type="observation_unit_polygon_original_background_removed_thresholded_ndre_mask_imagery" >Create/View Plot Polygons</button>';

                                        $drone_run_band_table_html .= '<hr>';
                                        my $plot_polygon_original_background_removed_thresholded_ndre_mask_images = '';
                                        if ($d->{plot_polygon_original_background_removed_thresholded_ndre_mask_images}) {
                                            $plot_polygon_original_background_removed_thresholded_ndre_mask_images = scalar(@{$d->{plot_polygon_original_background_removed_thresholded_ndre_mask_images}})." Plot Polygons<br/><span>";
                                            $plot_polygon_original_background_removed_thresholded_ndre_mask_images .= join '', @{$d->{plot_polygon_original_background_removed_thresholded_ndre_mask_images}};
                                            $plot_polygon_original_background_removed_thresholded_ndre_mask_images .= "</span>";
                                            $plot_polygon_original_background_removed_thresholded_ndre_mask_images .= '<br/><br/>';
                                            $plot_polygon_original_background_removed_thresholded_ndre_mask_images .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_get_phenotypes" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'" data-plot_polygons_type="observation_unit_polygon_original_background_removed_thresholded_ndre_mask_imagery" >Calculate Phenotypes</button>';
                                        } else {
                                            $plot_polygon_original_background_removed_thresholded_ndre_mask_images = 'No Plot Polygons Assigned';
                                        }
                                        $drone_run_band_table_html .= $plot_polygon_original_background_removed_thresholded_ndre_mask_images;

                                        $drone_run_band_table_html .= '</div></div></div>';

                                        if ($d->{calculate_fourier_transform_hpf30_nren_denoised_background_removed_thresholded_ndre_mask_original_channel_1_image}) {
                                            $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-3"><h5>FT HPF30 Denoised Image with Background Removed via Thresholded NDRE Mask&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{calculate_fourier_transform_hpf30_nren_denoised_background_removed_thresholded_ndre_mask_original_channel_1_image_id}.'"></span></h5><b>By</b>: '.$d->{calculate_fourier_transform_hpf30_nren_denoised_background_removed_thresholded_ndre_mask_original_channel_1_image_username}.'</br><b>Date</b>: '.$d->{calculate_fourier_transform_hpf30_nren_denoised_background_removed_thresholded_ndre_mask_original_channel_1_modified_date}.'</div><div class="col-sm-3">'.$d->{calculate_fourier_transform_hpf30_nren_denoised_background_removed_thresholded_ndre_mask_original_channel_1_image}.'</div><div class="col-sm-6">';
                                            $drone_run_band_table_html .= '</div></div></div>';
                                        } else {
                                            $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_fourier_transform_hpf30" data-image_id="'.$d->{denoised_background_removed_thresholded_ndre_mask_original_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'", data-selected_image_type="denoised_background_removed_thresholded_ndre_mask_original" >Fourier Transform HPF30 Denoised Image Channel 1 with Background Removed via Thresholded NDRE Mask</button><br/><br/>';
                                        }
                                    } else {
                                        $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_apply_ndre_removed_background_mask_to_denoised_image" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'"  data-background_removed_ndre_stitched_image_id="'.$d->{threshold_background_removed_ndre_stitched_image_id}.'" >Remove Background From Original Denoised Image via Tresholded NDRE Mask</button><br/><br/>';
                                    }
                                    if ($d->{denoised_background_removed_ndre_mask_original_image}) {
                                        $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-3"><h5>NDRE Vegetative Index Mask on Original Denoised Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{denoised_background_removed_ndre_mask_original_image_id}.'"></span></h5><b>By</b>: '.$d->{denoised_background_removed_ndre_mask_original_image_username}.'</br><b>Date</b>: '.$d->{denoised_background_removed_ndre_mask_original_image_modified_date}.'</div><div class="col-sm-3">'.$d->{denoised_background_removed_ndre_mask_original_image}.'</div><div class="col-sm-6">';

                                        $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_plot_polygons" data-stitched_image_id="'.$d->{stitched_image_id}.'" data-cropped_stitched_image_id="'.$d->{cropped_stitched_image_id}.'" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-background_removed_stitched_image_id="'.$d->{denoised_background_removed_ndre_mask_original_image_id}.'" data-assign_plot_polygons_type="observation_unit_polygon_original_background_removed_ndre_mask_imagery" >Create/View Plot Polygons</button>';

                                        $drone_run_band_table_html .= '<hr>';
                                        my $plot_polygon_original_background_removed_ndre_mask_images = '';
                                        if ($d->{plot_polygon_original_background_removed_ndre_mask_images}) {
                                            $plot_polygon_original_background_removed_ndre_mask_images = scalar(@{$d->{plot_polygon_original_background_removed_ndre_mask_images}})." Plot Polygons<br/><span>";
                                            $plot_polygon_original_background_removed_ndre_mask_images .= join '', @{$d->{plot_polygon_original_background_removed_ndre_mask_images}};
                                            $plot_polygon_original_background_removed_ndre_mask_images .= "</span>";
                                            $plot_polygon_original_background_removed_ndre_mask_images .= '<br/><br/>';
                                            $plot_polygon_original_background_removed_ndre_mask_images .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_get_phenotypes" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'" data-plot_polygons_type="observation_unit_polygon_original_background_removed_ndre_mask_imagery" >Calculate Phenotypes</button>';
                                        } else {
                                            $plot_polygon_original_background_removed_ndre_mask_images = 'No Plot Polygons Assigned';
                                        }
                                        $drone_run_band_table_html .= $plot_polygon_original_background_removed_ndre_mask_images;

                                        $drone_run_band_table_html .= '</div></div></div>';

                                        if ($d->{calculate_fourier_transform_hpf30_nren_denoised_background_removed_ndre_mask_original_channel_1_image}) {
                                            $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-3"><h5>FT HPF30 Denoised Image with Background Removed via NDRE Mask&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{calculate_fourier_transform_hpf30_nren_denoised_background_removed_ndre_mask_original_channel_1_image_id}.'"></span></h5><b>By</b>: '.$d->{calculate_fourier_transform_hpf30_nren_denoised_background_removed_ndre_mask_original_channel_1_image_username}.'</br><b>Date</b>: '.$d->{calculate_fourier_transform_hpf30_nren_denoised_background_removed_ndre_mask_original_channel_1_modified_date}.'</div><div class="col-sm-3">'.$d->{calculate_fourier_transform_hpf30_nren_denoised_background_removed_ndre_mask_original_channel_1_image}.'</div><div class="col-sm-6">';
                                            $drone_run_band_table_html .= '</div></div></div>';
                                        } else {
                                            $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_fourier_transform_hpf30" data-image_id="'.$d->{denoised_background_removed_ndre_mask_original_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'", data-selected_image_type="denoised_background_removed_ndre_mask_original" >Fourier Transform HPF30 Denoised Image Channel 1 with Background Removed via NDRE Mask</button><br/><br/>';
                                        }
                                    } else {
                                        $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_apply_ndre_mask_to_denoised_image" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'"  data-ndre_stitched_image_id="'.$d->{calculate_ndre_drone_imagery}.'" >Remove Background From Original Denoised Image via NDRE Mask</button><br/><br/>';
                                    }
                                } else {
                                    $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_remove_background" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-denoised_stitched_image="'.uri_encode($d->{denoised_stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-remove_background_current_image_id="'.$d->{vegetative_index_ndre_image_id}.'" data-remove_background_current_image_type="threshold_background_removed_ndre_stitched_drone_imagery" >NDRE Vegetative Index Remove Background via Threshold</button><br/><br/>';
                                }
                            }
                            if ($d->{calculate_fourier_transform_hpf30_nrn_denoised_stitched_image_channel_1_image}) {
                                $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-3"><h5>Fourier Transform HPF30 on NRN Denoised Channel 1 Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{calculate_fourier_transform_hpf30_nrn_denoised_stitched_image_channel_1_image_id}.'"></span></h5><b>By</b>: '.$d->{calculate_fourier_transform_hpf30_nrn_denoised_stitched_image_channel_1_image_username}.'</br><b>Date</b>: '.$d->{calculate_fourier_transform_hpf30_nrn_denoised_stitched_image_channel_1_modified_date}.'</div><div class="col-sm-3">'.$d->{calculate_fourier_transform_hpf30_nrn_denoised_stitched_image_channel_1_image}.'</div><div class="col-sm-6">';

                                $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_plot_polygons" data-stitched_image_id="'.$d->{stitched_image_id}.'" data-cropped_stitched_image_id="'.$d->{cropped_stitched_image_id}.'" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-background_removed_stitched_image_id="'.$d->{calculate_fourier_transform_hpf30_nrn_denoised_stitched_image_channel_1_image_id}.'" data-assign_plot_polygons_type="observation_unit_polygon_fourier_transform_hpf30_nrn_denoised_stitched_image_channel_1">Create/View Plot Polygons</button>';

                                $drone_run_band_table_html .= '<hr>';
                                my $plot_polygon_images = '';
                                if ($d->{plot_polygon_fourier_transform_hpf30_nrn_denoised_stitched_image_channel_1_images}) {
                                    $plot_polygon_images = scalar(@{$d->{plot_polygon_fourier_transform_hpf30_nrn_denoised_stitched_image_channel_1_images}})." Plot Polygons<br/><span>";
                                    $plot_polygon_images .= join '', @{$d->{plot_polygon_fourier_transform_hpf30_nrn_denoised_stitched_image_channel_1_images}};
                                    $plot_polygon_images .= "</span>";
                                    $plot_polygon_images .= '<br/><br/>';
                                    $plot_polygon_images .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_get_phenotypes" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'" data-plot_polygons_type="observation_unit_polygon_fourier_transform_hpf30_nrn_denoised_stitched_image_channel_1" >Calculate Phenotypes</button>';
                                } else {
                                    $plot_polygon_images = 'No Plot Polygons Assigned';
                                }
                                $drone_run_band_table_html .= $plot_polygon_images;

                                $drone_run_band_table_html .= '</div></div></div>';
                            }
                            if ($d->{calculate_fourier_transform_hpf30_blue_denoised_stitched_image_channel_1_image}) {
                                $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-3"><h5>Fourier Transform HPF30 on Blue Denoised Channel 1 Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{calculate_fourier_transform_hpf30_blue_denoised_stitched_image_channel_1_image_id}.'"></span></h5><b>By</b>: '.$d->{calculate_fourier_transform_hpf30_blue_denoised_stitched_image_channel_1_image_username}.'</br><b>Date</b>: '.$d->{calculate_fourier_transform_hpf30_blue_denoised_stitched_image_channel_1_modified_date}.'</div><div class="col-sm-3">'.$d->{calculate_fourier_transform_hpf30_blue_denoised_stitched_image_channel_1_image}.'</div><div class="col-sm-6">';

                                $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_plot_polygons" data-stitched_image_id="'.$d->{stitched_image_id}.'" data-cropped_stitched_image_id="'.$d->{cropped_stitched_image_id}.'" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-background_removed_stitched_image_id="'.$d->{calculate_fourier_transform_hpf30_blue_denoised_stitched_image_channel_1_image_id}.'" data-assign_plot_polygons_type="observation_unit_polygon_fourier_transform_hpf30_blue_denoised_stitched_image_channel_1">Create/View Plot Polygons</button>';

                                $drone_run_band_table_html .= '<hr>';
                                my $plot_polygon_images = '';
                                if ($d->{plot_polygon_fourier_transform_hpf30_blue_denoised_stitched_image_channel_1_images}) {
                                    $plot_polygon_images = scalar(@{$d->{plot_polygon_fourier_transform_hpf30_blue_denoised_stitched_image_channel_1_images}})." Plot Polygons<br/><span>";
                                    $plot_polygon_images .= join '', @{$d->{plot_polygon_fourier_transform_hpf30_blue_denoised_stitched_image_channel_1_images}};
                                    $plot_polygon_images .= "</span>";
                                    $plot_polygon_images .= '<br/><br/>';
                                    $plot_polygon_images .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_get_phenotypes" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'" data-plot_polygons_type="observation_unit_polygon_fourier_transform_hpf30_blue_denoised_stitched_image_channel_1" >Calculate Phenotypes</button>';
                                } else {
                                    $plot_polygon_images = 'No Plot Polygons Assigned';
                                }
                                $drone_run_band_table_html .= $plot_polygon_images;

                                $drone_run_band_table_html .= '</div></div></div>';
                            }
                            if ($d->{calculate_fourier_transform_hpf30_green_denoised_stitched_image_channel_1_image}) {
                                $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-3"><h5>Fourier Transform HPF30 on Green Denoised Channel 1 Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{calculate_fourier_transform_hpf30_green_denoised_stitched_image_channel_1_image_id}.'"></span></h5><b>By</b>: '.$d->{calculate_fourier_transform_hpf30_green_denoised_stitched_image_channel_1_image_username}.'</br><b>Date</b>: '.$d->{calculate_fourier_transform_hpf30_green_denoised_stitched_image_channel_1_modified_date}.'</div><div class="col-sm-3">'.$d->{calculate_fourier_transform_hpf30_green_denoised_stitched_image_channel_1_image}.'</div><div class="col-sm-6">';

                                $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_plot_polygons" data-stitched_image_id="'.$d->{stitched_image_id}.'" data-cropped_stitched_image_id="'.$d->{cropped_stitched_image_id}.'" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-background_removed_stitched_image_id="'.$d->{calculate_fourier_transform_hpf30_green_denoised_stitched_image_channel_1_image_id}.'" data-assign_plot_polygons_type="observation_unit_polygon_fourier_transform_hpf30_green_denoised_stitched_image_channel_1">Create/View Plot Polygons</button>';

                                $drone_run_band_table_html .= '<hr>';
                                my $plot_polygon_images = '';
                                if ($d->{plot_polygon_fourier_transform_hpf30_green_denoised_stitched_image_channel_1_images}) {
                                    $plot_polygon_images = scalar(@{$d->{plot_polygon_fourier_transform_hpf30_green_denoised_stitched_image_channel_1_images}})." Plot Polygons<br/><span>";
                                    $plot_polygon_images .= join '', @{$d->{plot_polygon_fourier_transform_hpf30_green_denoised_stitched_image_channel_1_images}};
                                    $plot_polygon_images .= "</span>";
                                    $plot_polygon_images .= '<br/><br/>';
                                    $plot_polygon_images .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_get_phenotypes" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'" data-plot_polygons_type="observation_unit_polygon_fourier_transform_hpf30_green_denoised_stitched_image_channel_1" >Calculate Phenotypes</button>';
                                } else {
                                    $plot_polygon_images = 'No Plot Polygons Assigned';
                                }
                                $drone_run_band_table_html .= $plot_polygon_images;

                                $drone_run_band_table_html .= '</div></div></div>';
                            }
                            if ($d->{calculate_fourier_transform_hpf30_red_denoised_stitched_image_channel_1_image}) {
                                $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-3"><h5>Fourier Transform HPF30 on Red Denoised Channel 1 Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{calculate_fourier_transform_hpf30_red_denoised_stitched_image_channel_1_image_id}.'"></span></h5><b>By</b>: '.$d->{calculate_fourier_transform_hpf30_red_denoised_stitched_image_channel_1_image_username}.'</br><b>Date</b>: '.$d->{calculate_fourier_transform_hpf30_red_denoised_stitched_image_channel_1_modified_date}.'</div><div class="col-sm-3">'.$d->{calculate_fourier_transform_hpf30_red_denoised_stitched_image_channel_1_image}.'</div><div class="col-sm-6">';

                                $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_plot_polygons" data-stitched_image_id="'.$d->{stitched_image_id}.'" data-cropped_stitched_image_id="'.$d->{cropped_stitched_image_id}.'" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-background_removed_stitched_image_id="'.$d->{calculate_fourier_transform_hpf30_red_denoised_stitched_image_channel_1_image_id}.'" data-assign_plot_polygons_type="observation_unit_polygon_fourier_transform_hpf30_red_denoised_stitched_image_channel_1">Create/View Plot Polygons</button>';

                                $drone_run_band_table_html .= '<hr>';
                                my $plot_polygon_images = '';
                                if ($d->{plot_polygon_fourier_transform_hpf30_red_denoised_stitched_image_channel_1_images}) {
                                    $plot_polygon_images = scalar(@{$d->{plot_polygon_fourier_transform_hpf30_red_denoised_stitched_image_channel_1_images}})." Plot Polygons<br/><span>";
                                    $plot_polygon_images .= join '', @{$d->{plot_polygon_fourier_transform_hpf30_red_denoised_stitched_image_channel_1_images}};
                                    $plot_polygon_images .= "</span>";
                                    $plot_polygon_images .= '<br/><br/>';
                                    $plot_polygon_images .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_get_phenotypes" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'" data-plot_polygons_type="observation_unit_polygon_fourier_transform_hpf30_red_denoised_stitched_image_channel_1" >Calculate Phenotypes</button>';
                                } else {
                                    $plot_polygon_images = 'No Plot Polygons Assigned';
                                }
                                $drone_run_band_table_html .= $plot_polygon_images;

                                $drone_run_band_table_html .= '</div></div></div>';
                            }
                            if ($d->{calculate_fourier_transform_hpf30_rededge_denoised_stitched_image_channel_1_image}) {
                                $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-3"><h5>Fourier Transform HPF30 on Red Edge Denoised Channel 1 Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{calculate_fourier_transform_hpf30_rededge_denoised_stitched_image_channel_1_image_id}.'"></span></h5><b>By</b>: '.$d->{calculate_fourier_transform_hpf30_rededge_denoised_stitched_image_channel_1_image_username}.'</br><b>Date</b>: '.$d->{calculate_fourier_transform_hpf30_rededge_denoised_stitched_image_channel_1_modified_date}.'</div><div class="col-sm-3">'.$d->{calculate_fourier_transform_hpf30_rededge_denoised_stitched_image_channel_1_image}.'</div><div class="col-sm-6">';

                                $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_plot_polygons" data-stitched_image_id="'.$d->{stitched_image_id}.'" data-cropped_stitched_image_id="'.$d->{cropped_stitched_image_id}.'" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-background_removed_stitched_image_id="'.$d->{calculate_fourier_transform_hpf30_rededge_denoised_stitched_image_channel_1_image_id}.'" data-assign_plot_polygons_type="observation_unit_polygon_fourier_transform_hpf30_rededge_denoised_stitched_image_channel_1">Create/View Plot Polygons</button>';

                                $drone_run_band_table_html .= '<hr>';
                                my $plot_polygon_images = '';
                                if ($d->{plot_polygon_fourier_transform_hpf30_rededge_denoised_stitched_image_channel_1_images}) {
                                    $plot_polygon_images = scalar(@{$d->{plot_polygon_fourier_transform_hpf30_rededge_denoised_stitched_image_channel_1_images}})." Plot Polygons<br/><span>";
                                    $plot_polygon_images .= join '', @{$d->{plot_polygon_fourier_transform_hpf30_rededge_denoised_stitched_image_channel_1_images}};
                                    $plot_polygon_images .= "</span>";
                                    $plot_polygon_images .= '<br/><br/>';
                                    $plot_polygon_images .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_get_phenotypes" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'" data-plot_polygons_type="observation_unit_polygon_fourier_transform_hpf30_rededge_denoised_stitched_image_channel_1" >Calculate Phenotypes</button>';
                                } else {
                                    $plot_polygon_images = 'No Plot Polygons Assigned';
                                }
                                $drone_run_band_table_html .= $plot_polygon_images;

                                $drone_run_band_table_html .= '</div></div></div>';
                            }
                            if ($d->{calculate_fourier_transform_hpf30_nir_denoised_stitched_image_channel_1_image}) {
                                $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-3"><h5>Fourier Transform HPF30 on NIR Denoised Channel 1 Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{calculate_fourier_transform_hpf30_nir_denoised_stitched_image_channel_1_image_id}.'"></span></h5><b>By</b>: '.$d->{calculate_fourier_transform_hpf30_nir_denoised_stitched_image_channel_1_image_username}.'</br><b>Date</b>: '.$d->{calculate_fourier_transform_hpf30_nir_denoised_stitched_image_channel_1_modified_date}.'</div><div class="col-sm-3">'.$d->{calculate_fourier_transform_hpf30_nir_denoised_stitched_image_channel_1_image}.'</div><div class="col-sm-6">';

                                $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_plot_polygons" data-stitched_image_id="'.$d->{stitched_image_id}.'" data-cropped_stitched_image_id="'.$d->{cropped_stitched_image_id}.'" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-background_removed_stitched_image_id="'.$d->{calculate_fourier_transform_hpf30_nir_denoised_stitched_image_channel_1_image_id}.'" data-assign_plot_polygons_type="observation_unit_polygon_fourier_transform_hpf30_nir_denoised_stitched_image_channel_1">Create/View Plot Polygons</button>';

                                $drone_run_band_table_html .= '<hr>';
                                my $plot_polygon_images = '';
                                if ($d->{plot_polygon_fourier_transform_hpf30_nir_denoised_stitched_image_channel_1_images}) {
                                    $plot_polygon_images = scalar(@{$d->{plot_polygon_fourier_transform_hpf30_nir_denoised_stitched_image_channel_1_images}})." Plot Polygons<br/><span>";
                                    $plot_polygon_images .= join '', @{$d->{plot_polygon_fourier_transform_hpf30_nir_denoised_stitched_image_channel_1_images}};
                                    $plot_polygon_images .= "</span>";
                                    $plot_polygon_images .= '<br/><br/>';
                                    $plot_polygon_images .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_get_phenotypes" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'" data-plot_polygons_type="observation_unit_polygon_fourier_transform_hpf30_nir_denoised_stitched_image_channel_1" >Calculate Phenotypes</button>';
                                } else {
                                    $plot_polygon_images = 'No Plot Polygons Assigned';
                                }
                                $drone_run_band_table_html .= $plot_polygon_images;

                                $drone_run_band_table_html .= '</div></div></div>';
                            }
                        } else {
                            $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_denoise" data-cropped_stitched_image_id="'.$d->{cropped_stitched_drone_imagery_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-cropped_stitched_image="'.uri_encode($d->{cropped_stitched_drone_imagery_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" >Denoise</button><br/><br/>';
                        }
                    } else {
                        $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_crop_image" data-rotated_stitched_image_id="'.$d->{rotated_stitched_drone_imagery_id}.'" data-stitched_image_id="'.$d->{stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" >Crop Rotated Image</button><br/><br/>';
                    }
                } else {
                    $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_rotate_image" data-stitched_image_id="'.$d->{stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" >Rotate Stitched Image</button><br/><br/>';
                }
            } else {
                $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_stitch" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" >Stitch Uploaded Images Into Ortho Image Now</button><br/><br/>';
                $drone_run_band_table_html .= '<button class="btn btn-default btn-sm" name="project_drone_imagery_upload_stitched" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" >Upload Previously Stitched Ortho Image</button>';
            }


        }

        push @return, [$drone_run_band_table_html];
    }

    $c->stash->{rest} = { data => \@return };
}

1;
