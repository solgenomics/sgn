package CXGN::DroneImagery::ImageTypes;

=head1 NAME

CXGN::DroneImagery::ImageTypes - an object to assist in image type organization

=head1 USAGE

my $drone_image_types = CXGN::DroneImagery::ImageTypes->new({
    bcs_schema=>$schema,
});

=head1 DESCRIPTION


=head1 AUTHORS

=cut

use strict;
use warnings;
use Moose;
use Try::Tiny;
use Data::Dumper;
use SGN::Model::Cvterm;

has 'bcs_schema' => ( isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1,
);

sub get_all_project_md_image_observation_unit_plot_polygon_types {
    my $schema = shift;
    return {
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_bw_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_bw_imagery', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_rgb_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_rgb_imagery', channels=>[0,1,2], corresponding_channel=>undef
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_rgb_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_rgb_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_rgb_imagery_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_rgb_imagery_channel_2', channels=>[0], corresponding_channel=>1
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_rgb_imagery_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_rgb_imagery_channel_3', channels=>[0], corresponding_channel=>2
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_blue_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_blue_imagery', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_green_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_green_imagery', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_red_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_red_imagery', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_red_edge_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_red_edge_imagery', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_nir_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_nir_imagery', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_mir_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_mir_imagery', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fir_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fir_imagery', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_tir_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_tir_imagery', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_bw_background_removed_threshold_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_bw_background_removed_threshold_imagery', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_rgb_background_removed_threshold_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_rgb_background_removed_threshold_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_rgb_background_removed_threshold_imagery_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_rgb_background_removed_threshold_imagery_channel_2', channels=>[0], corresponding_channel=>1
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_rgb_background_removed_threshold_imagery_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_rgb_background_removed_threshold_imagery_channel_3', channels=>[0], corresponding_channel=>2
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_blue_background_removed_threshold_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_blue_background_removed_threshold_imagery', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_green_background_removed_threshold_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_green_background_removed_threshold_imagery', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_red_background_removed_threshold_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_red_background_removed_threshold_imagery', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_red_edge_background_removed_threshold_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_red_edge_background_removed_threshold_imagery', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_nir_background_removed_threshold_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_nir_background_removed_threshold_imagery', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_mir_background_removed_threshold_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_mir_background_removed_threshold_imagery', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fir_background_removed_threshold_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fir_background_removed_threshold_imagery', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_tir_background_removed_threshold_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_tir_background_removed_threshold_imagery', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_tgi_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_tgi_imagery', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_vari_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_vari_imagery', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_ndvi_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_ndvi_imagery', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_ndre_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_ndre_imagery', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_background_removed_tgi_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_background_removed_tgi_imagery', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_background_removed_vari_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_background_removed_vari_imagery', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_background_removed_ndvi_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_background_removed_ndvi_imagery', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_background_removed_ndre_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_background_removed_ndre_imagery', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_tgi_mask_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_background_removed_tgi_mask_imagery', channels=>[0,1,2], corresponding_channel=>undef
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_tgi_mask_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_background_removed_tgi_mask_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_tgi_mask_imagery_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_background_removed_tgi_mask_imagery_channel_2', channels=>[0], corresponding_channel=>1
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_tgi_mask_imagery_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_background_removed_tgi_mask_imagery_channel_3', channels=>[0], corresponding_channel=>2
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_vari_mask_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_background_removed_vari_mask_imagery', channels=>[0,1,2], corresponding_channel=>undef
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_vari_mask_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_background_removed_vari_mask_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_vari_mask_imagery_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_background_removed_vari_mask_imagery_channel_2', channels=>[0], corresponding_channel=>1
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_vari_mask_imagery_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_background_removed_vari_mask_imagery_channel_3', channels=>[0], corresponding_channel=>2
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_nrn_background_removed_ndvi_mask_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_nrn_background_removed_ndvi_mask_imagery', channels=>[0,1,2], corresponding_channel=>undef
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_nrn_background_removed_ndvi_mask_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_nrn_background_removed_ndvi_mask_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_nrn_background_removed_ndvi_mask_imagery_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_nrn_background_removed_ndvi_mask_imagery_channel_2', channels=>[0], corresponding_channel=>1
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_nren_background_removed_ndre_mask_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_nren_background_removed_ndre_mask_imagery', channels=>[0,1,2], corresponding_channel=>undef
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_nren_background_removed_ndre_mask_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_nren_background_removed_ndre_mask_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_nren_background_removed_ndre_mask_imagery_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_nren_background_removed_ndre_mask_imagery_channel_2', channels=>[0], corresponding_channel=>1
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_thresholded_tgi_mask_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_background_removed_thresholded_tgi_mask_imagery', channels=>[0,1,2], corresponding_channel=>undef
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_thresholded_tgi_mask_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_background_removed_thresholded_tgi_mask_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_thresholded_tgi_mask_imagery_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_background_removed_thresholded_tgi_mask_imagery_channel_2', channels=>[0], corresponding_channel=>1
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_thresholded_tgi_mask_imagery_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_background_removed_thresholded_tgi_mask_imagery_channel_3', channels=>[0], corresponding_channel=>2
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_thresholded_vari_mask_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_background_removed_thresholded_vari_mask_imagery', channels=>[0,1,2], corresponding_channel=>undef
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_thresholded_vari_mask_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_background_removed_thresholded_vari_mask_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_thresholded_vari_mask_imagery_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_background_removed_thresholded_vari_mask_imagery_channel_2', channels=>[0], corresponding_channel=>1
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_thresholded_vari_mask_imagery_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_background_removed_thresholded_vari_mask_imagery_channel_3', channels=>[0], corresponding_channel=>2
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_nrn_background_removed_thresholded_ndvi_mask_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_nrn_background_removed_thresholded_ndvi_mask_imagery', channels=>[0,1,2], corresponding_channel=>undef
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_nrn_background_removed_thresholded_ndvi_mask_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_nrn_background_removed_thresholded_ndvi_mask_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_nrn_background_removed_thresholded_ndvi_mask_imagery_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_nrn_background_removed_thresholded_ndvi_mask_imagery_channel_2', channels=>[0], corresponding_channel=>1
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_nren_background_removed_thresholded_ndre_mask_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_nren_background_removed_thresholded_ndre_mask_imagery', channels=>[0,1,2], corresponding_channel=>undef
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_nren_background_removed_thresholded_ndre_mask_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_nren_background_removed_thresholded_ndre_mask_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_nren_background_removed_thresholded_ndre_mask_imagery_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_nren_background_removed_thresholded_ndre_mask_imagery_channel_2', channels=>[0], corresponding_channel=>1
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_blue_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_blue_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_green_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_green_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_red_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_red_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_rededge_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_rededge_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_nir_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_nir_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bgr_calculate_tgi_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bgr_calculate_tgi_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bgr_calculate_vari_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bgr_calculate_vari_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_nrn_calculate_ndvi_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_nrn_calculate_ndvi_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_nren_calculate_ndre_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_nren_calculate_ndre_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_blue_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_blue_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_green_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_green_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_red_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_red_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_rededge_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_rededge_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_nir_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_nir_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_mir_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_mir_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_fir_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_fir_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_tir_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_tir_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bw_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bw_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_stitched_image_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_stitched_image_channel_2', channels=>[0], corresponding_channel=>1
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_stitched_image_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_stitched_image_channel_3', channels=>[0], corresponding_channel=>2
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_threshold_removed_image_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_threshold_removed_image_channel_2', channels=>[0], corresponding_channel=>1
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_threshold_removed_image_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_threshold_removed_image_channel_3', channels=>[0], corresponding_channel=>2
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_tgi_mask_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_tgi_mask_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_tgi_mask_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_tgi_mask_channel_2', channels=>[0], corresponding_channel=>1
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_tgi_mask_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_tgi_mask_channel_3', channels=>[0], corresponding_channel=>2
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_tgi_mask_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_tgi_mask_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_tgi_mask_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_tgi_mask_channel_2', channels=>[0], corresponding_channel=>1
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_tgi_mask_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_tgi_mask_channel_3', channels=>[0], corresponding_channel=>2
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_vari_mask_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_vari_mask_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_vari_mask_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_vari_mask_channel_2', channels=>[0], corresponding_channel=>1
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_vari_mask_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_vari_mask_channel_3', channels=>[0], corresponding_channel=>2
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_vari_mask_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_vari_mask_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_vari_mask_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_vari_mask_channel_2', channels=>[0], corresponding_channel=>1
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_vari_mask_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_vari_mask_channel_3', channels=>[0], corresponding_channel=>2
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_nrn_denoised_background_removed_ndvi_mask_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_nrn_denoised_background_removed_ndvi_mask_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_nrn_denoised_background_removed_ndvi_mask_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_nrn_denoised_background_removed_ndvi_mask_channel_2', channels=>[0], corresponding_channel=>1
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_nrn_denoised_background_removed_thresholded_ndvi_mask_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_nrn_denoised_background_removed_thresholded_ndvi_mask_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_nrn_denoised_background_removed_thresholded_ndvi_mask_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_nrn_denoised_background_removed_thresholded_ndvi_mask_channel_2', channels=>[0], corresponding_channel=>1
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_nren_denoised_background_removed_ndre_mask_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_nren_denoised_background_removed_ndre_mask_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_nren_denoised_background_removed_ndre_mask_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_nren_denoised_background_removed_ndre_mask_channel_2', channels=>[0], corresponding_channel=>1
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_nren_denoised_background_removed_thresholded_ndre_mask_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_nren_denoised_background_removed_thresholded_ndre_mask_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_nren_denoised_background_removed_thresholded_ndre_mask_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_nren_denoised_background_removed_thresholded_ndre_mask_channel_2', channels=>[0], corresponding_channel=>1
        },
    };
}

sub get_vegetative_index_image_type_term_map {
    my %vi_map = (
        'TGI' => {
            imagery => {
                ft_hpf30_tgi => 'calculate_fourier_transform_hpf30_bgr_calculate_tgi_drone_imagery_channel_1',
                index_threshold_background => 'threshold_background_removed_tgi_stitched_drone_imagery',
                original_thresholded_index_mask_background => 'denoised_background_removed_thresholded_tgi_mask_original',
                ft_hpf30_original_thresholded_index_mask_background_channel_1 => 'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_tgi_mask_original_channel_1',
                ft_hpf30_original_thresholded_index_mask_background_channel_2 => 'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_tgi_mask_original_channel_2',
                ft_hpf30_original_thresholded_index_mask_background_channel_3 => 'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_tgi_mask_original_channel_3',
                original_index_mask_background => 'denoised_background_removed_tgi_mask_original',
                ft_hpf30_original_index_mask_background_channel_1 => 'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_tgi_mask_original_channel_1',
                ft_hpf30_original_index_mask_background_channel_2 => 'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_tgi_mask_original_channel_2',
                ft_hpf30_original_index_mask_background_channel_3 => 'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_tgi_mask_original_channel_3'
            },
            plot_polygon => {
                index_plot_polygon => 'observation_unit_polygon_tgi_imagery',
                ft_hpf30_tgi => 'observation_unit_polygon_fourier_transform_hpf30_bgr_calculate_tgi_drone_imagery_channel_1',
                index_threshold_background => 'observation_unit_polygon_background_removed_tgi_imagery',
                original_thresholded_index_mask_background => 'observation_unit_polygon_original_background_removed_thresholded_tgi_mask_imagery',
                original_thresholded_index_mask_background_channel_1 => 'observation_unit_polygon_original_background_removed_thresholded_tgi_mask_imagery_channel_1',
                original_thresholded_index_mask_background_channel_2 => 'observation_unit_polygon_original_background_removed_thresholded_tgi_mask_imagery_channel_2',
                original_thresholded_index_mask_background_channel_3 => 'observation_unit_polygon_original_background_removed_thresholded_tgi_mask_imagery_channel_3',
                ft_hpf30_original_thresholded_index_mask_background_channel_1 => 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_tgi_mask_channel_1',
                ft_hpf30_original_thresholded_index_mask_background_channel_2 => 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_tgi_mask_channel_2',
                ft_hpf30_original_thresholded_index_mask_background_channel_3 => 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_tgi_mask_channel_3',
                original_index_mask_background => 'observation_unit_polygon_original_background_removed_tgi_mask_imagery',
                original_index_mask_background_channel_1 => 'observation_unit_polygon_original_background_removed_tgi_mask_imagery_channel_1',
                original_index_mask_background_channel_2 => 'observation_unit_polygon_original_background_removed_tgi_mask_imagery_channel_2',
                original_index_mask_background_channel_3 => 'observation_unit_polygon_original_background_removed_tgi_mask_imagery_channel_3',
                ft_hpf30_original_index_mask_background_channel_1 => 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_tgi_mask_channel_1',
                ft_hpf30_original_index_mask_background_channel_2 => 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_tgi_mask_channel_2',
                ft_hpf30_original_index_mask_background_channel_3 => 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_tgi_mask_channel_3'
            }
        },
        'VARI' => {
            imagery => {
                ft_hpf30_tgi => 'calculate_fourier_transform_hpf30_bgr_calculate_vari_drone_imagery_channel_1',
                index_threshold_background => 'threshold_background_removed_vari_stitched_drone_imagery',
                original_thresholded_index_mask_background => 'denoised_background_removed_thresholded_vari_mask_original',
                ft_hpf30_original_thresholded_index_mask_background_channel_1 => 'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_vari_mask_original_channel_1',
                ft_hpf30_original_thresholded_index_mask_background_channel_2 => 'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_vari_mask_original_channel_2',
                ft_hpf30_original_thresholded_index_mask_background_channel_3 => 'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_vari_mask_original_channel_3',
                original_index_mask_background => 'denoised_background_removed_vari_mask_original',
                ft_hpf30_original_index_mask_background_channel_1 => 'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_vari_mask_original_channel_1',
                ft_hpf30_original_index_mask_background_channel_2 => 'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_vari_mask_original_channel_2',
                ft_hpf30_original_index_mask_background_channel_3 => 'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_vari_mask_original_channel_3'
            },
            plot_polygon => {
                index_plot_polygon => 'observation_unit_polygon_vari_imagery',
                ft_hpf30_tgi => 'observation_unit_polygon_fourier_transform_hpf30_bgr_calculate_vari_drone_imagery_channel_1',
                index_threshold_background => 'observation_unit_polygon_background_removed_vari_imagery',
                original_thresholded_index_mask_background => 'observation_unit_polygon_original_background_removed_thresholded_vari_mask_imagery',
                original_thresholded_index_mask_background_channel_1 => 'observation_unit_polygon_original_background_removed_thresholded_vari_mask_imagery_channel_1',
                original_thresholded_index_mask_background_channel_2 => 'observation_unit_polygon_original_background_removed_thresholded_vari_mask_imagery_channel_2',
                original_thresholded_index_mask_background_channel_3 => 'observation_unit_polygon_original_background_removed_thresholded_vari_mask_imagery_channel_3',
                ft_hpf30_original_thresholded_index_mask_background_channel_1 => 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_vari_mask_channel_1',
                ft_hpf30_original_thresholded_index_mask_background_channel_2 => 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_vari_mask_channel_2',
                ft_hpf30_original_thresholded_index_mask_background_channel_3 => 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_vari_mask_channel_3',
                original_index_mask_background => 'observation_unit_polygon_original_background_removed_vari_mask_imagery',
                original_index_mask_background_channel_1 => 'observation_unit_polygon_original_background_removed_vari_mask_imagery_channel_1',
                original_index_mask_background_channel_2 => 'observation_unit_polygon_original_background_removed_vari_mask_imagery_channel_2',
                original_index_mask_background_channel_3 => 'observation_unit_polygon_original_background_removed_vari_mask_imagery_channel_3',
                ft_hpf30_original_index_mask_background_channel_1 => 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_vari_mask_channel_1',
                ft_hpf30_original_index_mask_background_channel_2 => 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_vari_mask_channel_2',
                ft_hpf30_original_index_mask_background_channel_3 => 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_vari_mask_channel_3'
            }
        },
        'NDVI' => {
            imagery => {
                ft_hpf30_tgi => 'calculate_fourier_transform_hpf30_nrn_calculate_ndvi_drone_imagery_channel_1',
                index_threshold_background => 'threshold_background_removed_ndvi_stitched_drone_imagery',
                original_thresholded_index_mask_background => 'denoised_background_removed_thresholded_ndvi_mask_original',
                ft_hpf30_original_thresholded_index_mask_background_channel_1 => 'calculate_fourier_transform_hpf30_nrn_denoised_background_removed_thresholded_ndvi_mask_original_channel_1',
                ft_hpf30_original_thresholded_index_mask_background_channel_2 => 'calculate_fourier_transform_hpf30_nrn_denoised_background_removed_thresholded_ndvi_mask_original_channel_2',
                original_index_mask_background => 'denoised_background_removed_ndvi_mask_original',
                ft_hpf30_original_index_mask_background_channel_1 => 'calculate_fourier_transform_hpf30_nrn_denoised_background_removed_ndvi_mask_original_channel_1',
                ft_hpf30_original_index_mask_background_channel_2 => 'calculate_fourier_transform_hpf30_nrn_denoised_background_removed_ndvi_mask_original_channel_2',
            },
            plot_polygon => {
                index_plot_polygon => 'observation_unit_polygon_ndvi_imagery',
                ft_hpf30_tgi => 'observation_unit_polygon_fourier_transform_hpf30_nrn_calculate_ndvi_drone_imagery_channel_1',
                index_threshold_background => 'observation_unit_polygon_background_removed_ndvi_imagery',
                original_thresholded_index_mask_background => 'observation_unit_polygon_original_nrn_background_removed_thresholded_ndvi_mask_imagery',
                original_thresholded_index_mask_background_channel_1 => 'observation_unit_polygon_original_nrn_background_removed_thresholded_ndvi_mask_imagery_channel_1',
                original_thresholded_index_mask_background_channel_2 => 'observation_unit_polygon_original_nrn_background_removed_thresholded_ndvi_mask_imagery_channel_2',
                ft_hpf30_original_thresholded_index_mask_background_channel_1 => 'observation_unit_polygon_fourier_transform_hpf30_nrn_denoised_background_removed_thresholded_ndvi_mask_channel_1',
                ft_hpf30_original_thresholded_index_mask_background_channel_2 => 'observation_unit_polygon_fourier_transform_hpf30_nrn_denoised_background_removed_thresholded_ndvi_mask_channel_2',
                original_index_mask_background => 'observation_unit_polygon_original_nrn_background_removed_ndvi_mask_imagery',
                original_index_mask_background_channel_1 => 'observation_unit_polygon_original_nrn_background_removed_ndvi_mask_imagery_channel_1',
                original_index_mask_background_channel_2 => 'observation_unit_polygon_original_nrn_background_removed_ndvi_mask_imagery_channel_2',
                ft_hpf30_original_index_mask_background_channel_1 => 'observation_unit_polygon_fourier_transform_hpf30_nrn_denoised_background_removed_ndvi_mask_channel_1',
                ft_hpf30_original_index_mask_background_channel_2 => 'observation_unit_polygon_fourier_transform_hpf30_nrn_denoised_background_removed_ndvi_mask_channel_2',
            }
        },
        'NDRE' => {
            imagery => {
                ft_hpf30_tgi => 'calculate_fourier_transform_hpf30_nren_calculate_ndre_drone_imagery_channel_1',
                index_threshold_background => 'threshold_background_removed_ndre_stitched_drone_imagery',
                original_thresholded_index_mask_background => 'denoised_background_removed_thresholded_ndre_mask_original',
                ft_hpf30_original_thresholded_index_mask_background_channel_1 => 'calculate_fourier_transform_hpf30_nren_denoised_background_removed_thresholded_ndre_mask_original_channel_1',
                ft_hpf30_original_thresholded_index_mask_background_channel_2 => 'calculate_fourier_transform_hpf30_nren_denoised_background_removed_thresholded_ndre_mask_original_channel_2',
                original_index_mask_background => 'denoised_background_removed_ndre_mask_original',
                ft_hpf30_original_index_mask_background_channel_1 => 'calculate_fourier_transform_hpf30_nren_denoised_background_removed_ndre_mask_original_channel_1',
                ft_hpf30_original_index_mask_background_channel_2 => 'calculate_fourier_transform_hpf30_nren_denoised_background_removed_ndre_mask_original_channel_2',
            },
            plot_polygon => {
                index_plot_polygon => 'observation_unit_polygon_ndre_imagery',
                ft_hpf30_tgi => 'observation_unit_polygon_fourier_transform_hpf30_nren_calculate_ndre_drone_imagery_channel_1',
                index_threshold_background => 'observation_unit_polygon_background_removed_ndre_imagery',
                original_thresholded_index_mask_background => 'observation_unit_polygon_original_nren_background_removed_thresholded_ndre_mask_imagery',
                original_thresholded_index_mask_background_channel_1 => 'observation_unit_polygon_original_nren_background_removed_thresholded_ndre_mask_imagery_channel_1',
                original_thresholded_index_mask_background_channel_2 => 'observation_unit_polygon_original_nren_background_removed_thresholded_ndre_mask_imagery_channel_2',
                ft_hpf30_original_thresholded_index_mask_background_channel_1 => 'observation_unit_polygon_fourier_transform_hpf30_nren_denoised_background_removed_thresholded_ndre_mask_channel_1',
                ft_hpf30_original_thresholded_index_mask_background_channel_2 => 'observation_unit_polygon_fourier_transform_hpf30_nren_denoised_background_removed_thresholded_ndre_mask_channel_1',
                original_index_mask_background => 'observation_unit_polygon_original_nren_background_removed_ndre_mask_imagery',
                original_index_mask_background_channel_1 => 'observation_unit_polygon_original_nren_background_removed_ndre_mask_imagery_channel_1',
                original_index_mask_background_channel_2 => 'observation_unit_polygon_original_nren_background_removed_ndre_mask_imagery_channel_2',
                ft_hpf30_original_index_mask_background_channel_1 => 'observation_unit_polygon_fourier_transform_hpf30_nren_denoised_background_removed_ndre_mask_channel_1',
                ft_hpf30_original_index_mask_background_channel_2 => 'observation_unit_polygon_fourier_transform_hpf30_nren_denoised_background_removed_ndre_mask_channel_2',
            }
        }
    );
    return \%vi_map;
}

sub get_all_project_md_image_types_whole_images {
    my $schema = shift;
    return {
        SGN::Model::Cvterm->get_cvterm_row($schema, 'raw_drone_imagery', 'project_md_image')->cvterm_id() => {
            name=>'raw_drone_imagery', channels=>[0,1,2], corresponding_channel=>undef
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'stitched_drone_imagery', 'project_md_image')->cvterm_id() => {
            name=>'stitched_drone_imagery', channels=>[0,1,2], corresponding_channel=>undef
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'cropped_stitched_drone_imagery', 'project_md_image')->cvterm_id() => {
            name=>'cropped_stitched_drone_imagery', channels=>[0,1,2], corresponding_channel=>undef
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'rotated_stitched_drone_imagery', 'project_md_image')->cvterm_id() => {
            name=>'rotated_stitched_drone_imagery', channels=>[0,1,2], corresponding_channel=>undef
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'denoised_stitched_drone_imagery', 'project_md_image')->cvterm_id() => {
            name=>'denoised_stitched_drone_imagery', channels=>[0,1,2], corresponding_channel=>undef
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_tgi_drone_imagery', 'project_md_image')->cvterm_id() => {
            name=>'calculate_tgi_drone_imagery', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_vari_drone_imagery', 'project_md_image')->cvterm_id() => {
            name=>'calculate_vari_drone_imagery', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_ndvi_drone_imagery', 'project_md_image')->cvterm_id() => {
            name=>'calculate_ndvi_drone_imagery', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_ndre_drone_imagery', 'project_md_image')->cvterm_id() => {
            name=>'calculate_ndre_drone_imagery', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'threshold_background_removed_stitched_drone_imagery_blue', 'project_md_image')->cvterm_id() => {
            name=>'threshold_background_removed_stitched_drone_imagery_blue', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'threshold_background_removed_stitched_drone_imagery_green', 'project_md_image')->cvterm_id() => {
            name=>'threshold_background_removed_stitched_drone_imagery_green', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'threshold_background_removed_stitched_drone_imagery_red', 'project_md_image')->cvterm_id() => {
            name=>'threshold_background_removed_stitched_drone_imagery_red', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'threshold_background_removed_stitched_drone_imagery_red_edge', 'project_md_image')->cvterm_id() => {
            name=>'threshold_background_removed_stitched_drone_imagery_red_edge', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'threshold_background_removed_stitched_drone_imagery_nir', 'project_md_image')->cvterm_id() => {
            name=>'threshold_background_removed_stitched_drone_imagery_nir', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'threshold_background_removed_stitched_drone_imagery_mir', 'project_md_image')->cvterm_id() => {
            name=>'threshold_background_removed_stitched_drone_imagery_mir', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'threshold_background_removed_stitched_drone_imagery_fir', 'project_md_image')->cvterm_id() => {
            name=>'threshold_background_removed_stitched_drone_imagery_fir', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'threshold_background_removed_stitched_drone_imagery_tir', 'project_md_image')->cvterm_id() => {
            name=>'threshold_background_removed_stitched_drone_imagery_tir', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'threshold_background_removed_stitched_drone_imagery_bw', 'project_md_image')->cvterm_id() => {
            name=>'threshold_background_removed_stitched_drone_imagery_bw', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'threshold_background_removed_stitched_drone_imagery_rgb_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'threshold_background_removed_stitched_drone_imagery_rgb_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'threshold_background_removed_stitched_drone_imagery_rgb_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'threshold_background_removed_stitched_drone_imagery_rgb_channel_2', channels=>[0], corresponding_channel=>1
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'threshold_background_removed_stitched_drone_imagery_rgb_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'threshold_background_removed_stitched_drone_imagery_rgb_channel_3', channels=>[0], corresponding_channel=>2
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'threshold_background_removed_tgi_stitched_drone_imagery', 'project_md_image')->cvterm_id() => {
            name=>'threshold_background_removed_tgi_stitched_drone_imagery', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'threshold_background_removed_vari_stitched_drone_imagery', 'project_md_image')->cvterm_id() => {
            name=>'threshold_background_removed_vari_stitched_drone_imagery', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'threshold_background_removed_ndvi_stitched_drone_imagery', 'project_md_image')->cvterm_id() => {
            name=>'threshold_background_removed_ndvi_stitched_drone_imagery', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'threshold_background_removed_ndre_stitched_drone_imagery', 'project_md_image')->cvterm_id() => {
            name=>'threshold_background_removed_ndre_stitched_drone_imagery', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'denoised_background_removed_thresholded_tgi_mask_original', 'project_md_image')->cvterm_id() => {
            name=>'denoised_background_removed_thresholded_tgi_mask_original', channels=>[0,1,2], corresponding_channel=>undef
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'denoised_background_removed_thresholded_vari_mask_original', 'project_md_image')->cvterm_id() => {
            name=>'denoised_background_removed_thresholded_vari_mask_original', channels=>[0,1,2], corresponding_channel=>undef
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'denoised_background_removed_thresholded_ndvi_mask_original', 'project_md_image')->cvterm_id() => {
            name=>'denoised_background_removed_thresholded_ndvi_mask_original', channels=>[0,1,2], corresponding_channel=>undef
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'denoised_background_removed_thresholded_ndre_mask_original', 'project_md_image')->cvterm_id() => {
            name=>'denoised_background_removed_thresholded_ndre_mask_original', channels=>[0,1,2], corresponding_channel=>undef
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'denoised_background_removed_tgi_mask_original', 'project_md_image')->cvterm_id() => {
            name=>'denoised_background_removed_tgi_mask_original', channels=>[0,1,2], corresponding_channel=>undef
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'denoised_background_removed_vari_mask_original', 'project_md_image')->cvterm_id() => {
            name=>'denoised_background_removed_vari_mask_original', channels=>[0,1,2], corresponding_channel=>undef
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'denoised_background_removed_ndvi_mask_original', 'project_md_image')->cvterm_id() => {
            name=>'denoised_background_removed_ndvi_mask_original', channels=>[0,1,2], corresponding_channel=>undef
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'denoised_background_removed_ndre_mask_original', 'project_md_image')->cvterm_id() => {
            name=>'denoised_background_removed_ndre_mask_original', channels=>[0,1,2], corresponding_channel=>undef
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_blue_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_blue_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_green_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_green_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_red_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_red_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_rededge_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_rededge_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_nir_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_nir_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_mir_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_mir_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_fir_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_fir_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_tir_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_tir_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_bw_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_bw_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_bgr_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_bgr_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_bgr_denoised_stitched_image_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_bgr_denoised_stitched_image_channel_2', channels=>[0], corresponding_channel=>1
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_bgr_denoised_stitched_image_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_bgr_denoised_stitched_image_channel_3', channels=>[0], corresponding_channel=>2
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_blue_threshold_background_removed_stitched_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_blue_threshold_background_removed_stitched_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_green_threshold_background_removed_stitched_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_green_threshold_background_removed_stitched_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_red_threshold_background_removed_stitched_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_red_threshold_background_removed_stitched_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_rededge_threshold_background_removed_stitched_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_rededge_threshold_background_removed_stitched_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_nir_threshold_background_removed_stitched_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_nir_threshold_background_removed_stitched_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_mir_threshold_background_removed_stitched_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_mir_threshold_background_removed_stitched_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_fir_threshold_background_removed_stitched_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_fir_threshold_background_removed_stitched_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_tir_threshold_background_removed_stitched_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_tir_threshold_background_removed_stitched_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_bw_threshold_background_removed_stitched_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_bw_threshold_background_removed_stitched_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_bgr_threshold_background_removed_stitched_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_bgr_threshold_background_removed_stitched_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_bgr_threshold_background_removed_stitched_drone_imagery_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_bgr_threshold_background_removed_stitched_drone_imagery_channel_2', channels=>[0], corresponding_channel=>1
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_bgr_threshold_background_removed_stitched_drone_imagery_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_bgr_threshold_background_removed_stitched_drone_imagery_channel_3', channels=>[0], corresponding_channel=>2
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_bgr_threshold_background_removed_tgi_stitched_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_bgr_threshold_background_removed_tgi_stitched_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_bgr_threshold_background_removed_vari_stitched_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_bgr_threshold_background_removed_vari_stitched_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_nrn_threshold_background_removed_ndvi_stitched_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_nrn_threshold_background_removed_ndvi_stitched_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_nren_threshold_background_removed_ndre_stitched_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_nren_threshold_background_removed_ndre_stitched_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_tgi_mask_original_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_tgi_mask_original_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_tgi_mask_original_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_tgi_mask_original_channel_2', channels=>[0], corresponding_channel=>1
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_tgi_mask_original_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_tgi_mask_original_channel_3', channels=>[0], corresponding_channel=>2
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_vari_mask_original_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_vari_mask_original_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_vari_mask_original_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_vari_mask_original_channel_2', channels=>[0], corresponding_channel=>1
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_vari_mask_original_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_vari_mask_original_channel_3', channels=>[0], corresponding_channel=>2
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_nrn_denoised_background_removed_ndvi_mask_original_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_nrn_denoised_background_removed_ndvi_mask_original_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_nrn_denoised_background_removed_ndvi_mask_original_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_nrn_denoised_background_removed_ndvi_mask_original_channel_2', channels=>[0], corresponding_channel=>1
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_nren_denoised_background_removed_ndre_mask_original_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_nren_denoised_background_removed_ndre_mask_original_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_nren_denoised_background_removed_ndre_mask_original_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_nren_denoised_background_removed_ndre_mask_original_channel_2', channels=>[0], corresponding_channel=>1
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_tgi_mask_original_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_tgi_mask_original_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_tgi_mask_original_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_tgi_mask_original_channel_2', channels=>[0], corresponding_channel=>1
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_tgi_mask_original_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_tgi_mask_original_channel_3', channels=>[0], corresponding_channel=>2
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_vari_mask_original_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_vari_mask_original_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_vari_mask_original_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_vari_mask_original_channel_2', channels=>[0], corresponding_channel=>1
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_vari_mask_original_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_vari_mask_original_channel_3', channels=>[0], corresponding_channel=>2
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_nrn_denoised_background_removed_thresholded_ndvi_mask_original_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_nrn_denoised_background_removed_thresholded_ndvi_mask_original_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_nrn_denoised_background_removed_thresholded_ndvi_mask_original_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_nrn_denoised_background_removed_thresholded_ndvi_mask_original_channel_2', channels=>[0], corresponding_channel=>1
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_nren_denoised_background_removed_thresholded_ndre_mask_original_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_nren_denoised_background_removed_thresholded_ndre_mask_original_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_nren_denoised_background_removed_thresholded_ndre_mask_original_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_nren_denoised_background_removed_thresholded_ndre_mask_original_channel_2', channels=>[0], corresponding_channel=>1
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_bgr_calculate_tgi_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_bgr_calculate_tgi_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_bgr_calculate_vari_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_bgr_calculate_vari_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_nrn_calculate_ndvi_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_nrn_calculate_ndvi_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_nren_calculate_ndre_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_nren_calculate_ndre_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        }
    };
}

1;
