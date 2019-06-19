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
            name=>'observation_unit_polygon_bw_imagery', channels=>[0], corresponding_channel=>0, display_name=>'Black and White Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_rgb_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_rgb_imagery', channels=>[0,1,2], corresponding_channel=>undef, display_name=>'RGB Color Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_rgb_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_rgb_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Red Image(s) from RGB Color Image'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_rgb_imagery_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_rgb_imagery_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Green Image(s) from RGB Color Image'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_rgb_imagery_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_rgb_imagery_channel_3', channels=>[0], corresponding_channel=>2, display_name=>'Blue Image(s) from RGB Color Image'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_nrn_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_nrn_imagery', channels=>[0,1,2], corresponding_channel=>undef, display_name=>'NRN Merged 3 Bands Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_nren_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_nren_imagery', channels=>[0,1,2], corresponding_channel=>undef, display_name=>'NReN Merged 3 Bands Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_blue_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_blue_imagery', channels=>[0], corresponding_channel=>0, display_name=>'Blue Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_green_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_green_imagery', channels=>[0], corresponding_channel=>0, display_name=>'Green Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_red_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_red_imagery', channels=>[0], corresponding_channel=>0, display_name=>'Red Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_red_edge_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_red_edge_imagery', channels=>[0], corresponding_channel=>0, display_name=>'Red Edge Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_nir_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_nir_imagery', channels=>[0], corresponding_channel=>0, display_name=>'NIR Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_mir_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_mir_imagery', channels=>[0], corresponding_channel=>0, display_name=>'MIR Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fir_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fir_imagery', channels=>[0], corresponding_channel=>0, display_name=>'FIR Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_tir_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_tir_imagery', channels=>[0], corresponding_channel=>0, display_name=>'Thermal IR Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_bw_background_removed_threshold_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_bw_background_removed_threshold_imagery', channels=>[0], corresponding_channel=>0, display_name=>'Black and White Image(s) with Background Removed via Threshold'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_rgb_background_removed_threshold_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_rgb_background_removed_threshold_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Blue Image(s) from RGB Color Image with Background Removed via Threshold'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_rgb_background_removed_threshold_imagery_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_rgb_background_removed_threshold_imagery_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Green Image(s) from RGB Color Image with Background Removed via Threshold'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_rgb_background_removed_threshold_imagery_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_rgb_background_removed_threshold_imagery_channel_3', channels=>[0], corresponding_channel=>2, display_name=>'Red Image(s) from RGB Color Image with Background Removed via Threshold'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_blue_background_removed_threshold_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_blue_background_removed_threshold_imagery', channels=>[0], corresponding_channel=>0, display_name=>'Blue Image(s) with Background Removed via Threshold'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_green_background_removed_threshold_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_green_background_removed_threshold_imagery', channels=>[0], corresponding_channel=>0, display_name=>'Green Image(s) with Background Removed via Threshold'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_red_background_removed_threshold_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_red_background_removed_threshold_imagery', channels=>[0], corresponding_channel=>0, display_name=>'Red Image(s) with Background Removed via Threshold'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_red_edge_background_removed_threshold_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_red_edge_background_removed_threshold_imagery', channels=>[0], corresponding_channel=>0, display_name=>'Red Edge Image(s) with Background Removed via Threshold'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_nir_background_removed_threshold_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_nir_background_removed_threshold_imagery', channels=>[0], corresponding_channel=>0, display_name=>'NIR Image(s) with Background Removed via Threshold'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_mir_background_removed_threshold_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_mir_background_removed_threshold_imagery', channels=>[0], corresponding_channel=>0, display_name=>'MIR Image(s) with Background Removed via Threshold'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fir_background_removed_threshold_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fir_background_removed_threshold_imagery', channels=>[0], corresponding_channel=>0, display_name=>'FIR Image(s) with Background Removed via Threshold'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_tir_background_removed_threshold_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_tir_background_removed_threshold_imagery', channels=>[0], corresponding_channel=>0, display_name=>'Thermal IR Image(s) with Background Removed via Threshold'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_tgi_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_tgi_imagery', channels=>[0], corresponding_channel=>0, display_name=>'TGI Vegetative Index Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_vari_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_vari_imagery', channels=>[0], corresponding_channel=>0, display_name=>'VARI Vegetative Index Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_ndvi_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_ndvi_imagery', channels=>[0], corresponding_channel=>0, display_name=>'NDVI Vegetative Index Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_ndre_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_ndre_imagery', channels=>[0], corresponding_channel=>0, display_name=>'NDRE Vegetative Index Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_background_removed_tgi_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_background_removed_tgi_imagery', channels=>[0], corresponding_channel=>0, display_name=>'TGI Vegetative Index Image(s) with Threshold Applied'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_background_removed_vari_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_background_removed_vari_imagery', channels=>[0], corresponding_channel=>0, display_name=>'VARI Vegetative Index Image(s) with Threshold Applied'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_background_removed_ndvi_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_background_removed_ndvi_imagery', channels=>[0], corresponding_channel=>0, display_name=>'NDVI Vegetative Index Image(s) with Threshold Applied'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_background_removed_ndre_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_background_removed_ndre_imagery', channels=>[0], corresponding_channel=>0, display_name=>'NDRE Vegetative Index Image(s) with Threshold Applied'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_tgi_mask_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_background_removed_tgi_mask_imagery', channels=>[0,1,2], corresponding_channel=>undef, display_name=>'RGB Image(s) with Background Removed via a TGI mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_tgi_mask_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_background_removed_tgi_mask_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Blue Image(s) from RGB Image with Background Removed via a TGI mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_tgi_mask_imagery_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_background_removed_tgi_mask_imagery_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Green Image(s) from RGB Image with Background Removed via a TGI mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_tgi_mask_imagery_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_background_removed_tgi_mask_imagery_channel_3', channels=>[0], corresponding_channel=>2, display_name=>'Red Image(s) from RGB Image with Background Removed via a TGI mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_vari_mask_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_background_removed_vari_mask_imagery', channels=>[0,1,2], corresponding_channel=>undef, display_name=>'RGB Image(s) with Background Removed via a VARI mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_vari_mask_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_background_removed_vari_mask_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Blue Image(s) from RGB Image with Background Removed via a VARI mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_vari_mask_imagery_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_background_removed_vari_mask_imagery_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Green Image(s) from RGB Image with Background Removed via a VARI mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_vari_mask_imagery_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_background_removed_vari_mask_imagery_channel_3', channels=>[0], corresponding_channel=>2, display_name=>'Red Image(s) from RGB Image with Background Removed via a VARI mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_nrn_background_removed_ndvi_mask_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_nrn_background_removed_ndvi_mask_imagery', channels=>[0,1,2], corresponding_channel=>undef, display_name=>'NRN Image(s) with Background Removed via a NDVI mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_nrn_background_removed_ndvi_mask_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_nrn_background_removed_ndvi_mask_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'NIR Image(s) from NRN Image with Background Removed via a NDVI mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_nrn_background_removed_ndvi_mask_imagery_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_nrn_background_removed_ndvi_mask_imagery_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Red Image(s) from NRN Image with Background Removed via a NDVI mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_nren_background_removed_ndre_mask_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_nren_background_removed_ndre_mask_imagery', channels=>[0,1,2], corresponding_channel=>undef, display_name=>'NReN Image(s) with Background Removed via a NDRE mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_nren_background_removed_ndre_mask_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_nren_background_removed_ndre_mask_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'NIR Image(s) from NReN Image with Background Removed via a NDRE mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_nren_background_removed_ndre_mask_imagery_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_nren_background_removed_ndre_mask_imagery_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Red Edge Image(s) from NReN Image with Background Removed via a NDRE mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_thresholded_tgi_mask_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_background_removed_thresholded_tgi_mask_imagery', channels=>[0,1,2], corresponding_channel=>undef, display_name=>'RGB Image(s) with Background Removed via a Thresholded TGI mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_thresholded_tgi_mask_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_background_removed_thresholded_tgi_mask_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Blue Image(s) from RGB Image with Background Removed via a Thresholded TGI mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_thresholded_tgi_mask_imagery_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_background_removed_thresholded_tgi_mask_imagery_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Green Image(s) from RGB Image with Background Removed via a Thresholded TGI mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_thresholded_tgi_mask_imagery_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_background_removed_thresholded_tgi_mask_imagery_channel_3', channels=>[0], corresponding_channel=>2, display_name=>'Red Image(s) from RGB Image with Background Removed via a Thresholded TGI mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_thresholded_vari_mask_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_background_removed_thresholded_vari_mask_imagery', channels=>[0,1,2], corresponding_channel=>undef, display_name=>'RGB Image(s) with Background Removed via a Thresholded VARI mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_thresholded_vari_mask_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_background_removed_thresholded_vari_mask_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Blue Image(s) from RGB Image with Background Removed via a Thresholded VARI mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_thresholded_vari_mask_imagery_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_background_removed_thresholded_vari_mask_imagery_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Green Image(s) from RGB Image with Background Removed via a Thresholded VARI mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_thresholded_vari_mask_imagery_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_background_removed_thresholded_vari_mask_imagery_channel_3', channels=>[0], corresponding_channel=>2, display_name=>'Red Image(s) from RGB Image with Background Removed via a Thresholded VARI mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_nrn_background_removed_thresholded_ndvi_mask_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_nrn_background_removed_thresholded_ndvi_mask_imagery', channels=>[0,1,2], corresponding_channel=>undef, display_name=>'NRN Image(s) with Background Removed via a Thresholded NDVI mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_nrn_background_removed_thresholded_ndvi_mask_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_nrn_background_removed_thresholded_ndvi_mask_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'NIR Image(s) from NRN Image with Background Removed via a Thresholded NDVI mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_nrn_background_removed_thresholded_ndvi_mask_imagery_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_nrn_background_removed_thresholded_ndvi_mask_imagery_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Red Image(s) from NRN Image with Background Removed via a Thresholded NDVI mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_nren_background_removed_thresholded_ndre_mask_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_nren_background_removed_thresholded_ndre_mask_imagery', channels=>[0,1,2], corresponding_channel=>undef, display_name=>'NReN Image(s) with Background Removed via a Thresholded NDRE mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_nren_background_removed_thresholded_ndre_mask_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_nren_background_removed_thresholded_ndre_mask_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'NIR Image(s) from NReN Image with Background Removed via a Thresholded NDRE mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_nren_background_removed_thresholded_ndre_mask_imagery_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_nren_background_removed_thresholded_ndre_mask_imagery_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Red Edge Image(s) from NReN Image with Background Removed via a Thresholded NDRE mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_blue_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_blue_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 Blue Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_blue_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_blue_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 Blue Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_blue_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_blue_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 Blue Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_green_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_green_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 Green Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_green_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_green_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 Green Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_green_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_green_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 Green Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_red_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_red_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 Red Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_red_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_red_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 Red Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_red_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_red_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 Red Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_rededge_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_rededge_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 Red Edge Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_rededge_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_rededge_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 Red Edge Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_rededge_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_rededge_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 Red Edge Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_nir_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_nir_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 NIR Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_nir_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_nir_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 NIR Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_nir_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_nir_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 NIR Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_mir_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_mir_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 MIR Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_mir_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_mir_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 MIR Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_mir_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_mir_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 MIR Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_fir_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_fir_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 FIR Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_fir_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_fir_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 FIR Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_fir_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_fir_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 FIR Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_tir_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_tir_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 Thermal IR Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_tir_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_tir_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 Thermal IR Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_tir_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_tir_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 Thermal IR Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_bw_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_bw_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 Black and White Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bw_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bw_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 Black and White Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_bw_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_bw_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 Black and White Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 Blue Image(s) from RGB Image'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 Blue Image(s) from RGB Image'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 Blue Image(s) from RGB Image'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_stitched_image_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_stitched_image_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Fourier Transform HPF20 Green Image(s) from RGB Image'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_stitched_image_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_stitched_image_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Fourier Transform HPF30 Green Image(s) from RGB Image'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_stitched_image_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_stitched_image_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Fourier Transform HPF40 Green Image(s) from RGB Image'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_stitched_image_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_stitched_image_channel_3', channels=>[0], corresponding_channel=>2, display_name=>'Fourier Transform HPF20 Red Image(s) from RGB Image'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_stitched_image_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_stitched_image_channel_3', channels=>[0], corresponding_channel=>2, display_name=>'Fourier Transform HPF30 Red Image(s) from RGB Image'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_stitched_image_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_stitched_image_channel_3', channels=>[0], corresponding_channel=>2, display_name=>'Fourier Transform HPF40 Red Image(s) from RGB Image'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_bgr_calculate_tgi_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_bgr_calculate_tgi_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 TGI Vegetative Index Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bgr_calculate_tgi_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bgr_calculate_tgi_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 TGI Vegetative Index Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_bgr_calculate_tgi_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_bgr_calculate_tgi_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 TGI Vegetative Index Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_bgr_calculate_vari_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_bgr_calculate_vari_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 VARI Vegetative Index Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bgr_calculate_vari_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bgr_calculate_vari_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 VARI Vegetative Index Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_bgr_calculate_vari_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_bgr_calculate_vari_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 VARI Vegetative Index Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_nrn_calculate_ndvi_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_nrn_calculate_ndvi_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 NDVI Vegetative Index Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_nrn_calculate_ndvi_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_nrn_calculate_ndvi_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 NDVI Vegetative Index Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_nrn_calculate_ndvi_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_nrn_calculate_ndvi_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 NDVI Vegetative Index Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_nren_calculate_ndre_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_nren_calculate_ndre_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 NDRE Vegetative Index Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_nren_calculate_ndre_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_nren_calculate_ndre_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 NDRE Vegetative Index Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_nren_calculate_ndre_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_nren_calculate_ndre_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 NDRE Vegetative Index Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_bgr_calculate_thresholded_tgi_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_bgr_calculate_thresholded_tgi_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 Thresholded TGI Vegetative Index Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bgr_calculate_thresholded_tgi_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bgr_calculate_thresholded_tgi_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 Thresholded TGI Vegetative Index Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_bgr_calculate_thresholded_tgi_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_bgr_calculate_thresholded_tgi_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 Thresholded TGI Vegetative Index Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_bgr_calculate_thresholded_vari_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_bgr_calculate_thresholded_vari_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 Thresholded VARI Vegetative Index Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bgr_calculate_thresholded_vari_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bgr_calculate_thresholded_vari_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 Thresholded VARI Vegetative Index Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_bgr_calculate_thresholded_vari_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_bgr_calculate_thresholded_vari_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 Thresholded VARI Vegetative Index Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_nrn_calculate_thresholded_ndvi_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_nrn_calculate_thresholded_ndvi_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 Thresholded NDVI Vegetative Index Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_nrn_calculate_thresholded_ndvi_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_nrn_calculate_thresholded_ndvi_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 Thresholded NDVI Vegetative Index Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_nrn_calculate_thresholded_ndvi_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_nrn_calculate_thresholded_ndvi_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 Thresholded NDVI Vegetative Index Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_nren_calculate_thresholded_ndre_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_nren_calculate_thresholded_ndre_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 Thresholded NDRE Vegetative Index Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_nren_calculate_thresholded_ndre_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_nren_calculate_thresholded_ndre_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 Thresholded NDRE Vegetative Index Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_nren_calculate_thresholded_ndre_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_nren_calculate_thresholded_ndre_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 Thresholded NDRE Vegetative Index Image(s)'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_blue_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_blue_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 Blue Image(s) with Background Removed via Threshold'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_blue_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_blue_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 Blue Image(s) with Background Removed via Threshold'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_blue_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_blue_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 Blue Image(s) with Background Removed via Threshold'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_green_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_green_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 Green Image(s) with Background Removed via Threshold'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_green_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_green_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 Green Image(s) with Background Removed via Threshold'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_green_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_green_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 Green Image(s) with Background Removed via Threshold'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_red_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_red_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 Red Image(s) with Background Removed via Threshold'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_red_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_red_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 Red Image(s) with Background Removed via Threshold'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_red_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_red_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 Red Image(s) with Background Removed via Threshold'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_rededge_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_rededge_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 Red Edge Image(s) with Background Removed via Threshold'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_rededge_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_rededge_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 Red Edge Image(s) with Background Removed via Threshold'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_rededge_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_rededge_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 Red Edge Image(s) with Background Removed via Threshold'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_nir_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_nir_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 NIR Image(s) with Background Removed via Threshold'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_nir_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_nir_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 NIR Image(s) with Background Removed via Threshold'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_nir_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_nir_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 NIR Image(s) with Background Removed via Threshold'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_mir_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_mir_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 MIR Image(s) with Background Removed via Threshold'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_mir_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_mir_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 MIR Image(s) with Background Removed via Threshold'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_mir_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_mir_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 MIR Image(s) with Background Removed via Threshold'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_fir_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_fir_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 FIR Image(s) with Background Removed via Threshold'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_fir_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_fir_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 FIR Image(s) with Background Removed via Threshold'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_fir_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_fir_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 FIR Image(s) with Background Removed via Threshold'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_tir_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_tir_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 Thermal IR Image(s) with Background Removed via Threshold'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_tir_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_tir_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 Thermal IR Image(s) with Background Removed via Threshold'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_tir_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_tir_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 Thermal IR Image(s) with Background Removed via Threshold'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_bw_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_bw_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 Black and White Image(s) with Background Removed via Threshold'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bw_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bw_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 Black and White Image(s) with Background Removed via Threshold'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_bw_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_bw_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 Black and White Image(s) with Background Removed via Threshold'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 Blue Image(s) from RGB Image with Background Removed via Threshold'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 Blue Image(s) from RGB Image with Background Removed via Threshold'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 Blue Image(s) from RGB Image with Background Removed via Threshold'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_threshold_removed_image_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_threshold_removed_image_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Fourier Transform HPF20 Green Image(s) from RGB Image with Background Removed via Threshold'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_threshold_removed_image_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_threshold_removed_image_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Fourier Transform HPF30 Green Image(s) from RGB Image with Background Removed via Threshold'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_threshold_removed_image_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_threshold_removed_image_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Fourier Transform HPF40 Green Image(s) from RGB Image with Background Removed via Threshold'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_threshold_removed_image_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_threshold_removed_image_channel_3', channels=>[0], corresponding_channel=>2, display_name=>'Fourier Transform HPF20 Red Image(s) from RGB Image with Background Removed via Threshold'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_threshold_removed_image_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_threshold_removed_image_channel_3', channels=>[0], corresponding_channel=>2, display_name=>'Fourier Transform HPF30 Red Image(s) from RGB Image with Background Removed via Threshold'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_threshold_removed_image_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_threshold_removed_image_channel_3', channels=>[0], corresponding_channel=>2, display_name=>'Fourier Transform HPF40 Red Image(s) from RGB Image with Background Removed via Threshold'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_removed_tgi_mask_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_removed_tgi_mask_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 Blue Image(s) from RGB Image with Background Removed via TGI Mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_tgi_mask_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_tgi_mask_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 Blue Image(s) from RGB Image with Background Removed via TGI Mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_removed_tgi_mask_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_removed_tgi_mask_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 Blue Image(s) from RGB Image with Background Removed via TGI Mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_removed_tgi_mask_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_removed_tgi_mask_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Fourier Transform HPF20 Green Image(s) from RGB Image with Background Removed via TGI Mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_tgi_mask_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_tgi_mask_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Fourier Transform HPF30 Green Image(s) from RGB Image with Background Removed via TGI Mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_removed_tgi_mask_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_removed_tgi_mask_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Fourier Transform HPF40 Green Image(s) from RGB Image with Background Removed via TGI Mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_removed_tgi_mask_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_removed_tgi_mask_channel_3', channels=>[0], corresponding_channel=>2, display_name=>'Fourier Transform HPF20 Red Image(s) from RGB Image with Background Removed via TGI Mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_tgi_mask_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_tgi_mask_channel_3', channels=>[0], corresponding_channel=>2, display_name=>'Fourier Transform HPF30 Red Image(s) from RGB Image with Background Removed via TGI Mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_removed_tgi_mask_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_removed_tgi_mask_channel_3', channels=>[0], corresponding_channel=>2, display_name=>'Fourier Transform HPF40 Red Image(s) from RGB Image with Background Removed via TGI Mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_removed_thresholded_tgi_mask_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_removed_thresholded_tgi_mask_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 Blue Image(s) from RGB Image with Background Removed via Thresholded TGI Mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_tgi_mask_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_tgi_mask_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 Blue Image(s) from RGB Image with Background Removed via Thresholded TGI Mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_removed_thresholded_tgi_mask_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_removed_thresholded_tgi_mask_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 Blue Image(s) from RGB Image with Background Removed via Thresholded TGI Mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_removed_thresholded_tgi_mask_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_removed_thresholded_tgi_mask_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Fourier Transform HPF20 Green Image(s) from RGB Image with Background Removed via Thresholded TGI Mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_tgi_mask_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_tgi_mask_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Fourier Transform HPF30 Green Image(s) from RGB Image with Background Removed via Thresholded TGI Mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_removed_thresholded_tgi_mask_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_removed_thresholded_tgi_mask_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Fourier Transform HPF40 Green Image(s) from RGB Image with Background Removed via Thresholded TGI Mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_removed_thresholded_tgi_mask_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_removed_thresholded_tgi_mask_channel_3', channels=>[0], corresponding_channel=>2, display_name=>'Fourier Transform HPF20 Red Image(s) from RGB Image with Background Removed via Thresholded TGI Mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_tgi_mask_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_tgi_mask_channel_3', channels=>[0], corresponding_channel=>2, display_name=>'Fourier Transform HPF30 Red Image(s) from RGB Image with Background Removed via Thresholded TGI Mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_removed_thresholded_tgi_mask_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_removed_thresholded_tgi_mask_channel_3', channels=>[0], corresponding_channel=>2, display_name=>'Fourier Transform HPF40 Red Image(s) from RGB Image with Background Removed via Thresholded TGI Mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_removed_vari_mask_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_removed_vari_mask_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 Blue Image(s) from RGB Image with Background Removed via VARI Mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_vari_mask_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_vari_mask_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 Blue Image(s) from RGB Image with Background Removed via VARI Mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_removed_vari_mask_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_removed_vari_mask_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 Blue Image(s) from RGB Image with Background Removed via VARI Mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_removed_vari_mask_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_removed_vari_mask_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Fourier Transform HPF20 Green Image(s) from RGB Image with Background Removed via VARI Mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_vari_mask_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_vari_mask_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Fourier Transform HPF30 Green Image(s) from RGB Image with Background Removed via VARI Mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_removed_vari_mask_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_removed_vari_mask_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Fourier Transform HPF40 Green Image(s) from RGB Image with Background Removed via VARI Mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_removed_vari_mask_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_removed_vari_mask_channel_3', channels=>[0], corresponding_channel=>2, display_name=>'Fourier Transform HPF20 Red Image(s) from RGB Image with Background Removed via VARI Mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_vari_mask_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_vari_mask_channel_3', channels=>[0], corresponding_channel=>2, display_name=>'Fourier Transform HPF30 Red Image(s) from RGB Image with Background Removed via VARI Mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_removed_vari_mask_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_removed_vari_mask_channel_3', channels=>[0], corresponding_channel=>2, display_name=>'Fourier Transform HPF40 Red Image(s) from RGB Image with Background Removed via VARI Mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_removed_thresholded_vari_mask_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_removed_thresholded_vari_mask_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 Blue Image(s) from RGB Image with Background Removed via Thresholded VARI Mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_vari_mask_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_vari_mask_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 Blue Image(s) from RGB Image with Background Removed via Thresholded VARI Mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_removed_thresholded_vari_mask_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_removed_thresholded_vari_mask_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 Blue Image(s) from RGB Image with Background Removed via Thresholded VARI Mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_removed_thresholded_vari_mask_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_removed_thresholded_vari_mask_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Fourier Transform HPF20 Green Image(s) from RGB Image with Background Removed via Thresholded VARI Mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_vari_mask_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_vari_mask_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Fourier Transform HPF30 Green Image(s) from RGB Image with Background Removed via Thresholded VARI Mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_removed_thresholded_vari_mask_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_removed_thresholded_vari_mask_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Fourier Transform HPF40 Green Image(s) from RGB Image with Background Removed via Thresholded VARI Mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_removed_thresholded_vari_mask_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_removed_thresholded_vari_mask_channel_3', channels=>[0], corresponding_channel=>2, display_name=>'Fourier Transform HPF20 Red Image(s) from RGB Image with Background Removed via Thresholded VARI Mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_vari_mask_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_vari_mask_channel_3', channels=>[0], corresponding_channel=>2, display_name=>'Fourier Transform HPF30 Red Image(s) from RGB Image with Background Removed via Thresholded VARI Mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_removed_thresholded_vari_mask_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_removed_thresholded_vari_mask_channel_3', channels=>[0], corresponding_channel=>2, display_name=>'Fourier Transform HPF40 Red Image(s) from RGB Image with Background Removed via Thresholded VARI Mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_nrn_denoised_background_removed_ndvi_mask_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_nrn_denoised_background_removed_ndvi_mask_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 NIR Image(s) from NRN Image with Background Removed via NDVI Mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_nrn_denoised_background_removed_ndvi_mask_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_nrn_denoised_background_removed_ndvi_mask_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 NIR Image(s) from NRN Image with Background Removed via NDVI Mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_nrn_denoised_background_removed_ndvi_mask_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_nrn_denoised_background_removed_ndvi_mask_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 NIR Image(s) from NRN Image with Background Removed via NDVI Mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_nrn_denoised_background_removed_ndvi_mask_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_nrn_denoised_background_removed_ndvi_mask_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Fourier Transform HPF20 Red Image(s) from NRN Image with Background Removed via NDVI Mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_nrn_denoised_background_removed_ndvi_mask_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_nrn_denoised_background_removed_ndvi_mask_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Fourier Transform HPF30 Red Image(s) from NRN Image with Background Removed via NDVI Mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_nrn_denoised_background_removed_ndvi_mask_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_nrn_denoised_background_removed_ndvi_mask_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Fourier Transform HPF40 Red Image(s) from NRN Image with Background Removed via NDVI Mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_nrn_denoised_background_removed_thresholded_ndvi_mask_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_nrn_denoised_background_removed_thresholded_ndvi_mask_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 NIR Image(s) from NRN Image with Background Removed via Thresholded NDVI Mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_nrn_denoised_background_removed_thresholded_ndvi_mask_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_nrn_denoised_background_removed_thresholded_ndvi_mask_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 NIR Image(s) from NRN Image with Background Removed via Thresholded NDVI Mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_nrn_denoised_background_removed_thresholded_ndvi_mask_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_nrn_denoised_background_removed_thresholded_ndvi_mask_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 NIR Image(s) from NRN Image with Background Removed via Thresholded NDVI Mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_nrn_denoised_background_removed_thresholded_ndvi_mask_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_nrn_denoised_background_removed_thresholded_ndvi_mask_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Fourier Transform HPF20 Red Image(s) from NRN Image with Background Removed via Thresholded NDVI Mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_nrn_denoised_background_removed_thresholded_ndvi_mask_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_nrn_denoised_background_removed_thresholded_ndvi_mask_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Fourier Transform HPF30 Red Image(s) from NRN Image with Background Removed via Thresholded NDVI Mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_nrn_denoised_background_removed_thresholded_ndvi_mask_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_nrn_denoised_background_removed_thresholded_ndvi_mask_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Fourier Transform HPF40 Red Image(s) from NRN Image with Background Removed via Thresholded NDVI Mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_nren_denoised_background_removed_ndre_mask_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_nren_denoised_background_removed_ndre_mask_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 NIR Image(s) from NReN Image with Background Removed via NDRE Mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_nren_denoised_background_removed_ndre_mask_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_nren_denoised_background_removed_ndre_mask_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 NIR Image(s) from NReN Image with Background Removed via NDRE Mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_nren_denoised_background_removed_ndre_mask_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_nren_denoised_background_removed_ndre_mask_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 NIR Image(s) from NReN Image with Background Removed via NDRE Mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_nren_denoised_background_removed_ndre_mask_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_nren_denoised_background_removed_ndre_mask_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Fourier Transform HPF20 Red Edge Image(s) from NReN Image with Background Removed via NDRE Mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_nren_denoised_background_removed_ndre_mask_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_nren_denoised_background_removed_ndre_mask_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Fourier Transform HPF30 Red Edge Image(s) from NReN Image with Background Removed via NDRE Mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_nren_denoised_background_removed_ndre_mask_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_nren_denoised_background_removed_ndre_mask_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Fourier Transform HPF40 Red Edge Image(s) from NReN Image with Background Removed via NDRE Mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_nren_denoised_background_removed_thresholded_ndre_mask_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_nren_denoised_background_removed_thresholded_ndre_mask_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 NIR Image(s) from NReN Image with Background Removed via Thresholded NDRE Mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_nren_denoised_background_removed_thresholded_ndre_mask_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_nren_denoised_background_removed_thresholded_ndre_mask_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 NIR Image(s) from NReN Image with Background Removed via Thresholded NDRE Mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_nren_denoised_background_removed_thresholded_ndre_mask_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_nren_denoised_background_removed_thresholded_ndre_mask_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 NIR Image(s) from NReN Image with Background Removed via Thresholded NDRE Mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_nren_denoised_background_removed_thresholded_ndre_mask_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_nren_denoised_background_removed_thresholded_ndre_mask_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Fourier Transform HPF20 Red Edge Image(s) from NReN Image with Background Removed via Thresholded NDRE Mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_nren_denoised_background_removed_thresholded_ndre_mask_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_nren_denoised_background_removed_thresholded_ndre_mask_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Fourier Transform HPF30 Red Edge Image(s) from NReN Image with Background Removed via Thresholded NDRE Mask'
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_nren_denoised_background_removed_thresholded_ndre_mask_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_nren_denoised_background_removed_thresholded_ndre_mask_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Fourier Transform HPF40 Red Edge Image(s) from NReN Image with Background Removed via Thresholded NDRE Mask'
        }
    };
}

sub get_base_imagery_observation_unit_plot_polygon_term_map {
    return {
        'Blue (450-520nm)' => {
            imagery_types => ['calculate_fourier_transform_hpf20_blue_denoised_stitched_image_channel_1', 'calculate_fourier_transform_hpf30_blue_denoised_stitched_image_channel_1', 'calculate_fourier_transform_hpf40_blue_denoised_stitched_image_channel_1', 'calculate_fourier_transform_hpf20_blue_threshold_background_removed_stitched_drone_imagery_channel_1', 'calculate_fourier_transform_hpf30_blue_threshold_background_removed_stitched_drone_imagery_channel_1', 'calculate_fourier_transform_hpf40_blue_threshold_background_removed_stitched_drone_imagery_channel_1'],
            observation_unit_plot_polygon_types => ['observation_unit_polygon_fourier_transform_hpf20_blue_denoised_stitched_image_channel_1', 'observation_unit_polygon_fourier_transform_hpf30_blue_denoised_stitched_image_channel_1', 'observation_unit_polygon_fourier_transform_hpf40_blue_denoised_stitched_image_channel_1', 'observation_unit_polygon_fourier_transform_hpf20_blue_denoised_background_threshold_removed_image_channel_1', 'observation_unit_polygon_fourier_transform_hpf30_blue_denoised_background_threshold_removed_image_channel_1', 'observation_unit_polygon_fourier_transform_hpf40_blue_denoised_background_threshold_removed_image_channel_1']
        },
        'Green (515-600nm)' => {
            imagery_types => ['calculate_fourier_transform_hpf20_green_denoised_stitched_image_channel_1', 'calculate_fourier_transform_hpf30_green_denoised_stitched_image_channel_1', 'calculate_fourier_transform_hpf40_green_denoised_stitched_image_channel_1', 'calculate_fourier_transform_hpf20_green_threshold_background_removed_stitched_drone_imagery_channel_1', 'calculate_fourier_transform_hpf30_green_threshold_background_removed_stitched_drone_imagery_channel_1', 'calculate_fourier_transform_hpf40_green_threshold_background_removed_stitched_drone_imagery_channel_1'],
            observation_unit_plot_polygon_types => ['observation_unit_polygon_fourier_transform_hpf20_green_denoised_stitched_image_channel_1', 'observation_unit_polygon_fourier_transform_hpf30_green_denoised_stitched_image_channel_1', 'observation_unit_polygon_fourier_transform_hpf40_green_denoised_stitched_image_channel_1', 'observation_unit_polygon_fourier_transform_hpf20_green_denoised_background_threshold_removed_image_channel_1', 'observation_unit_polygon_fourier_transform_hpf30_green_denoised_background_threshold_removed_image_channel_1', 'observation_unit_polygon_fourier_transform_hpf40_green_denoised_background_threshold_removed_image_channel_1']
        },
        'Red (600-690nm)' => {
            imagery_types => ['calculate_fourier_transform_hpf20_red_denoised_stitched_image_channel_1', 'calculate_fourier_transform_hpf30_red_denoised_stitched_image_channel_1', 'calculate_fourier_transform_hpf40_red_denoised_stitched_image_channel_1', 'calculate_fourier_transform_hpf20_red_threshold_background_removed_stitched_drone_imagery_channel_1', 'calculate_fourier_transform_hpf30_red_threshold_background_removed_stitched_drone_imagery_channel_1', 'calculate_fourier_transform_hpf40_red_threshold_background_removed_stitched_drone_imagery_channel_1'],
            observation_unit_plot_polygon_types => ['observation_unit_polygon_fourier_transform_hpf20_red_denoised_stitched_image_channel_1', 'observation_unit_polygon_fourier_transform_hpf30_red_denoised_stitched_image_channel_1', 'observation_unit_polygon_fourier_transform_hpf40_red_denoised_stitched_image_channel_1', 'observation_unit_polygon_fourier_transform_hpf20_red_denoised_background_threshold_removed_image_channel_1', 'observation_unit_polygon_fourier_transform_hpf30_red_denoised_background_threshold_removed_image_channel_1', 'observation_unit_polygon_fourier_transform_hpf40_red_denoised_background_threshold_removed_image_channel_1']
        },
        'Red Edge (690-750nm)' => {
            imagery_types => ['calculate_fourier_transform_hpf20_rededge_denoised_stitched_image_channel_1', 'calculate_fourier_transform_hpf30_rededge_denoised_stitched_image_channel_1', 'calculate_fourier_transform_hpf40_rededge_denoised_stitched_image_channel_1', 'calculate_fourier_transform_hpf20_rededge_threshold_background_removed_stitched_drone_imagery_channel_1', 'calculate_fourier_transform_hpf30_rededge_threshold_background_removed_stitched_drone_imagery_channel_1', 'calculate_fourier_transform_hpf40_rededge_threshold_background_removed_stitched_drone_imagery_channel_1'],
            observation_unit_plot_polygon_types => ['observation_unit_polygon_fourier_transform_hpf20_rededge_denoised_stitched_image_channel_1', 'observation_unit_polygon_fourier_transform_hpf30_rededge_denoised_stitched_image_channel_1', 'observation_unit_polygon_fourier_transform_hpf40_rededge_denoised_stitched_image_channel_1', 'observation_unit_polygon_fourier_transform_hpf20_rededge_denoised_background_threshold_removed_image_channel_1', 'observation_unit_polygon_fourier_transform_hpf30_rededge_denoised_background_threshold_removed_image_channel_1', 'observation_unit_polygon_fourier_transform_hpf40_rededge_denoised_background_threshold_removed_image_channel_1']
        },
        'NIR (750-900nm)' => {
            imagery_types => ['calculate_fourier_transform_hpf20_nir_denoised_stitched_image_channel_1', 'calculate_fourier_transform_hpf30_nir_denoised_stitched_image_channel_1', 'calculate_fourier_transform_hpf40_nir_denoised_stitched_image_channel_1', 'calculate_fourier_transform_hpf20_nir_threshold_background_removed_stitched_drone_imagery_channel_1', 'calculate_fourier_transform_hpf30_nir_threshold_background_removed_stitched_drone_imagery_channel_1', 'calculate_fourier_transform_hpf40_nir_threshold_background_removed_stitched_drone_imagery_channel_1'],
            observation_unit_plot_polygon_types => ['observation_unit_polygon_fourier_transform_hpf20_nir_denoised_stitched_image_channel_1', 'observation_unit_polygon_fourier_transform_hpf30_nir_denoised_stitched_image_channel_1', 'observation_unit_polygon_fourier_transform_hpf40_nir_denoised_stitched_image_channel_1', 'observation_unit_polygon_fourier_transform_hpf20_nir_denoised_background_threshold_removed_image_channel_1', 'observation_unit_polygon_fourier_transform_hpf30_nir_denoised_background_threshold_removed_image_channel_1', 'observation_unit_polygon_fourier_transform_hpf40_nir_denoised_background_threshold_removed_image_channel_1']
        },
        'MIR (1550-1750nm)' => {
            imagery_types => ['calculate_fourier_transform_hpf20_mir_denoised_stitched_image_channel_1', 'calculate_fourier_transform_hpf30_mir_denoised_stitched_image_channel_1', 'calculate_fourier_transform_hpf40_mir_denoised_stitched_image_channel_1', 'calculate_fourier_transform_hpf20_mir_threshold_background_removed_stitched_drone_imagery_channel_1', 'calculate_fourier_transform_hpf30_mir_threshold_background_removed_stitched_drone_imagery_channel_1', 'calculate_fourier_transform_hpf40_mir_threshold_background_removed_stitched_drone_imagery_channel_1'],
            observation_unit_plot_polygon_types => ['observation_unit_polygon_fourier_transform_hpf20_mir_denoised_stitched_image_channel_1', 'observation_unit_polygon_fourier_transform_hpf30_mir_denoised_stitched_image_channel_1', 'observation_unit_polygon_fourier_transform_hpf40_mir_denoised_stitched_image_channel_1', 'observation_unit_polygon_fourier_transform_hpf20_mir_denoised_background_threshold_removed_image_channel_1', 'observation_unit_polygon_fourier_transform_hpf30_mir_denoised_background_threshold_removed_image_channel_1', 'observation_unit_polygon_fourier_transform_hpf40_mir_denoised_background_threshold_removed_image_channel_1']
        },
        'FIR (2080-2350nm)' => {
            imagery_types => ['calculate_fourier_transform_hpf20_fir_denoised_stitched_image_channel_1', 'calculate_fourier_transform_hpf30_fir_denoised_stitched_image_channel_1', 'calculate_fourier_transform_hpf40_fir_denoised_stitched_image_channel_1', 'calculate_fourier_transform_hpf20_fir_threshold_background_removed_stitched_drone_imagery_channel_1', 'calculate_fourier_transform_hpf30_fir_threshold_background_removed_stitched_drone_imagery_channel_1', 'calculate_fourier_transform_hpf40_fir_threshold_background_removed_stitched_drone_imagery_channel_1'],
            observation_unit_plot_polygon_types => ['observation_unit_polygon_fourier_transform_hpf20_fir_denoised_stitched_image_channel_1', 'observation_unit_polygon_fourier_transform_hpf30_fir_denoised_stitched_image_channel_1', 'observation_unit_polygon_fourier_transform_hpf40_fir_denoised_stitched_image_channel_1', 'observation_unit_polygon_fourier_transform_hpf20_fir_denoised_background_threshold_removed_image_channel_1', 'observation_unit_polygon_fourier_transform_hpf30_fir_denoised_background_threshold_removed_image_channel_1', 'observation_unit_polygon_fourier_transform_hpf40_fir_denoised_background_threshold_removed_image_channel_1']
        },
        'Thermal IR (10400-12500nm)' => {
            imagery_types => ['calculate_fourier_transform_hpf20_tir_denoised_stitched_image_channel_1', 'calculate_fourier_transform_hpf30_tir_denoised_stitched_image_channel_1', 'calculate_fourier_transform_hpf40_tir_denoised_stitched_image_channel_1', 'calculate_fourier_transform_hpf20_tir_threshold_background_removed_stitched_drone_imagery_channel_1', 'calculate_fourier_transform_hpf30_tir_threshold_background_removed_stitched_drone_imagery_channel_1', 'calculate_fourier_transform_hpf40_tir_threshold_background_removed_stitched_drone_imagery_channel_1'],
            observation_unit_plot_polygon_types => ['observation_unit_polygon_fourier_transform_hpf20_tir_denoised_stitched_image_channel_1', 'observation_unit_polygon_fourier_transform_hpf30_tir_denoised_stitched_image_channel_1', 'observation_unit_polygon_fourier_transform_hpf40_tir_denoised_stitched_image_channel_1', 'observation_unit_polygon_fourier_transform_hpf20_tir_denoised_background_threshold_removed_image_channel_1', 'observation_unit_polygon_fourier_transform_hpf30_tir_denoised_background_threshold_removed_image_channel_1', 'observation_unit_polygon_fourier_transform_hpf40_tir_denoised_background_threshold_removed_image_channel_1']
        },
        'Black and White Image' => {
            imagery_types => ['calculate_fourier_transform_hpf20_bw_denoised_stitched_image_channel_1', 'calculate_fourier_transform_hpf30_bw_denoised_stitched_image_channel_1', 'calculate_fourier_transform_hpf40_bw_denoised_stitched_image_channel_1', 'calculate_fourier_transform_hpf20_bw_threshold_background_removed_stitched_drone_imagery_channel_1', 'calculate_fourier_transform_hpf30_bw_threshold_background_removed_stitched_drone_imagery_channel_1', 'calculate_fourier_transform_hpf40_bw_threshold_background_removed_stitched_drone_imagery_channel_1'],
            observation_unit_plot_polygon_types => ['observation_unit_polygon_fourier_transform_hpf20_bw_denoised_stitched_image_channel_1', 'observation_unit_polygon_fourier_transform_hpf30_bw_denoised_stitched_image_channel_1', 'observation_unit_polygon_fourier_transform_hpf40_bw_denoised_stitched_image_channel_1', 'observation_unit_polygon_fourier_transform_hpf20_bw_denoised_background_threshold_removed_image_channel_1', 'observation_unit_polygon_fourier_transform_hpf30_bw_denoised_background_threshold_removed_image_channel_1', 'observation_unit_polygon_fourier_transform_hpf40_bw_denoised_background_threshold_removed_image_channel_1']
        },
        'RGB Color Image' => {
            imagery_types => ['calculate_fourier_transform_hpf20_bgr_denoised_stitched_image_channel_1', 'calculate_fourier_transform_hpf30_bgr_denoised_stitched_image_channel_1', 'calculate_fourier_transform_hpf40_bgr_denoised_stitched_image_channel_1', 'calculate_fourier_transform_hpf20_bgr_denoised_stitched_image_channel_2', 'calculate_fourier_transform_hpf30_bgr_denoised_stitched_image_channel_2', 'calculate_fourier_transform_hpf40_bgr_denoised_stitched_image_channel_2', 'calculate_fourier_transform_hpf20_bgr_denoised_stitched_image_channel_3', 'calculate_fourier_transform_hpf30_bgr_denoised_stitched_image_channel_3', 'calculate_fourier_transform_hpf40_bgr_denoised_stitched_image_channel_3', 'calculate_fourier_transform_hpf20_bgr_threshold_background_removed_stitched_drone_imagery_channel_1', 'calculate_fourier_transform_hpf30_bgr_threshold_background_removed_stitched_drone_imagery_channel_1', 'calculate_fourier_transform_hpf40_bgr_threshold_background_removed_stitched_drone_imagery_channel_1', 'calculate_fourier_transform_hpf20_bgr_threshold_background_removed_stitched_drone_imagery_channel_2', 'calculate_fourier_transform_hpf30_bgr_threshold_background_removed_stitched_drone_imagery_channel_2', 'calculate_fourier_transform_hpf40_bgr_threshold_background_removed_stitched_drone_imagery_channel_2', 'calculate_fourier_transform_hpf20_bgr_threshold_background_removed_stitched_drone_imagery_channel_3', 'calculate_fourier_transform_hpf30_bgr_threshold_background_removed_stitched_drone_imagery_channel_3', 'calculate_fourier_transform_hpf40_bgr_threshold_background_removed_stitched_drone_imagery_channel_3'],
            observation_unit_plot_polygon_types => ['observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_stitched_image_channel_1', 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_stitched_image_channel_1', 'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_stitched_image_channel_1', 'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_stitched_image_channel_2', 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_stitched_image_channel_2', 'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_stitched_image_channel_2', 'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_stitched_image_channel_3', 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_stitched_image_channel_3', 'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_stitched_image_channel_3',
            'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_threshold_removed_image_channel_1', 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_threshold_removed_image_channel_1', 'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_threshold_removed_image_channel_1', 'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_threshold_removed_image_channel_2', 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_threshold_removed_image_channel_2', 'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_threshold_removed_image_channel_2', 'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_threshold_removed_image_channel_3', 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_threshold_removed_image_channel_3', 'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_threshold_removed_image_channel_3']
        },
        'Merged 3 Bands BGR' => {
            imagery_types => [],
            observation_unit_plot_polygon_types => []
        },
        'Merged 3 Bands NRN' => {
            imagery_types => [],
            observation_unit_plot_polygon_types => []
        },
        'Merged 3 Bands NReN' => {
            imagery_types => [],
            observation_unit_plot_polygon_types => []
        }
    };
}

sub get_vegetative_index_image_type_term_map {
    my %vi_map = (
        'TGI' => {
            index => {
                'calculate_tgi_drone_imagery' => [
                    'observation_unit_polygon_tgi_imagery'
                ]
            },
            ft_hpf20 => {
                'calculate_fourier_transform_hpf20_bgr_calculate_tgi_drone_imagery_channel_1' => [
                    'observation_unit_polygon_fourier_transform_hpf20_bgr_calculate_tgi_drone_imagery_channel_1'
                ]
            },
            ft_hpf30 => {
                'calculate_fourier_transform_hpf30_bgr_calculate_tgi_drone_imagery_channel_1' => [
                    'observation_unit_polygon_fourier_transform_hpf30_bgr_calculate_tgi_drone_imagery_channel_1'
                ]
            },
            ft_hpf40 => {
                'calculate_fourier_transform_hpf40_bgr_calculate_tgi_drone_imagery_channel_1' => [
                    'observation_unit_polygon_fourier_transform_hpf40_bgr_calculate_tgi_drone_imagery_channel_1'
                ]
            },
            index_threshold_background => {
                'threshold_background_removed_tgi_stitched_drone_imagery' => [
                    'observation_unit_polygon_background_removed_tgi_imagery'
                ]
            },
            ft_hpf20_index_threshold_background => {
                'calculate_fourier_transform_hpf20_bgr_threshold_background_removed_tgi_stitched_drone_imagery_channel_1' => [
                    'observation_unit_polygon_fourier_transform_hpf20_bgr_calculate_thresholded_tgi_drone_imagery_channel_1'
                ]
            },
            ft_hpf30_index_threshold_background => {
                'calculate_fourier_transform_hpf30_bgr_threshold_background_removed_tgi_stitched_drone_imagery_channel_1' => [
                    'observation_unit_polygon_fourier_transform_hpf30_bgr_calculate_thresholded_tgi_drone_imagery_channel_1'
                ]
            },
            ft_hpf40_index_threshold_background => {
                'calculate_fourier_transform_hpf40_bgr_threshold_background_removed_tgi_stitched_drone_imagery_channel_1' => [
                    'observation_unit_polygon_fourier_transform_hpf40_bgr_calculate_thresholded_tgi_drone_imagery_channel_1'
                ]
            },
            original_thresholded_index_mask_background => {
                'denoised_background_removed_thresholded_tgi_mask_original' => [
                    'observation_unit_polygon_original_background_removed_thresholded_tgi_mask_imagery',
                    'observation_unit_polygon_original_background_removed_thresholded_tgi_mask_imagery_channel_1',
                    'observation_unit_polygon_original_background_removed_thresholded_tgi_mask_imagery_channel_2',
                    'observation_unit_polygon_original_background_removed_thresholded_tgi_mask_imagery_channel_3',
                ]
            },
            ft_hpf20_original_thresholded_index_mask_background_channel_1 => {
                'calculate_fourier_transform_hpf20_bgr_denoised_background_removed_thresholded_tgi_mask_original_channel_1' => [
                    'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_removed_thresholded_tgi_mask_channel_1'
                ]
            },
            ft_hpf30_original_thresholded_index_mask_background_channel_1 => {
                'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_tgi_mask_original_channel_1' => [
                    'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_tgi_mask_channel_1'
                ]
            },
            ft_hpf40_original_thresholded_index_mask_background_channel_1 => {
                'calculate_fourier_transform_hpf40_bgr_denoised_background_removed_thresholded_tgi_mask_original_channel_1' => [
                    'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_removed_thresholded_tgi_mask_channel_1'
                ]
            },
            ft_hpf20_original_thresholded_index_mask_background_channel_2 => {
                'calculate_fourier_transform_hpf20_bgr_denoised_background_removed_thresholded_tgi_mask_original_channel_2' => [
                    'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_removed_thresholded_tgi_mask_channel_2'
                ]
            },
            ft_hpf30_original_thresholded_index_mask_background_channel_2 => {
                'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_tgi_mask_original_channel_2' => [
                    'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_tgi_mask_channel_2'
                ]
            },
            ft_hpf40_original_thresholded_index_mask_background_channel_2 => {
                'calculate_fourier_transform_hpf40_bgr_denoised_background_removed_thresholded_tgi_mask_original_channel_2' => [
                    'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_removed_thresholded_tgi_mask_channel_2'
                ]
            },
            ft_hpf20_original_thresholded_index_mask_background_channel_3 => {
                'calculate_fourier_transform_hpf20_bgr_denoised_background_removed_thresholded_tgi_mask_original_channel_3' => [
                    'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_removed_thresholded_tgi_mask_channel_3'
                ]
            },
            ft_hpf30_original_thresholded_index_mask_background_channel_3 => {
                'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_tgi_mask_original_channel_3' => [
                    'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_tgi_mask_channel_3'
                ]
            },
            ft_hpf40_original_thresholded_index_mask_background_channel_3 => {
                'calculate_fourier_transform_hpf40_bgr_denoised_background_removed_thresholded_tgi_mask_original_channel_3' => [
                    'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_removed_thresholded_tgi_mask_channel_3'
                ]
            },
            original_index_mask_background => {
                'denoised_background_removed_tgi_mask_original' => [
                    'observation_unit_polygon_original_background_removed_tgi_mask_imagery',
                    'observation_unit_polygon_original_background_removed_tgi_mask_imagery_channel_1',
                    'observation_unit_polygon_original_background_removed_tgi_mask_imagery_channel_2',
                    'observation_unit_polygon_original_background_removed_tgi_mask_imagery_channel_3',
                ]
            },
            ft_hpf20_original_index_mask_background_channel_1 => {
                'calculate_fourier_transform_hpf20_bgr_denoised_background_removed_tgi_mask_original_channel_1' => [
                    'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_removed_tgi_mask_channel_1'
                ]
            },
            ft_hpf30_original_index_mask_background_channel_1 => {
                'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_tgi_mask_original_channel_1' => [
                    'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_tgi_mask_channel_1'
                ]
            },
            ft_hpf40_original_index_mask_background_channel_1 => {
                'calculate_fourier_transform_hpf40_bgr_denoised_background_removed_tgi_mask_original_channel_1' => [
                    'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_removed_tgi_mask_channel_1'
                ]
            },
            ft_hpf20_original_index_mask_background_channel_2 => {
                'calculate_fourier_transform_hpf20_bgr_denoised_background_removed_tgi_mask_original_channel_2' => [
                    'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_removed_tgi_mask_channel_2'
                ]
            },
            ft_hpf30_original_index_mask_background_channel_2 => {
                'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_tgi_mask_original_channel_2' => [
                    'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_tgi_mask_channel_2'
                ]
            },
            ft_hpf40_original_index_mask_background_channel_2 => {
                'calculate_fourier_transform_hpf40_bgr_denoised_background_removed_tgi_mask_original_channel_2' => [
                    'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_removed_tgi_mask_channel_2'
                ]
            },
            ft_hpf20_original_index_mask_background_channel_3 => {
                'calculate_fourier_transform_hpf20_bgr_denoised_background_removed_tgi_mask_original_channel_3' => [
                    'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_removed_tgi_mask_channel_3'
                ]
            },
            ft_hpf30_original_index_mask_background_channel_3 => {
                'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_tgi_mask_original_channel_3' => [
                    'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_tgi_mask_channel_3'
                ]
            },
            ft_hpf40_original_index_mask_background_channel_3 => {
                'calculate_fourier_transform_hpf40_bgr_denoised_background_removed_tgi_mask_original_channel_3' => [
                    'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_removed_tgi_mask_channel_3'
                ]
            }
        },
        'VARI' => {
            index => {
                'calculate_vari_drone_imagery' => [
                    'observation_unit_polygon_vari_imagery'
                ]
            },
            ft_hpf20 => {
                'calculate_fourier_transform_hpf20_bgr_calculate_vari_drone_imagery_channel_1' => [
                    'observation_unit_polygon_fourier_transform_hpf20_bgr_calculate_vari_drone_imagery_channel_1'
                ]
            },
            ft_hpf30 => {
                'calculate_fourier_transform_hpf30_bgr_calculate_vari_drone_imagery_channel_1' => [
                    'observation_unit_polygon_fourier_transform_hpf30_bgr_calculate_vari_drone_imagery_channel_1'
                ]
            },
            ft_hpf40 => {
                'calculate_fourier_transform_hpf40_bgr_calculate_vari_drone_imagery_channel_1' => [
                    'observation_unit_polygon_fourier_transform_hpf40_bgr_calculate_vari_drone_imagery_channel_1'
                ]
            },
            index_threshold_background => {
                'threshold_background_removed_vari_stitched_drone_imagery' => [
                    'observation_unit_polygon_background_removed_vari_imagery'
                ]
            },
            ft_hpf20_index_threshold_background => {
                'calculate_fourier_transform_hpf20_bgr_threshold_background_removed_vari_stitched_drone_imagery_channel_1' => [
                    'observation_unit_polygon_fourier_transform_hpf20_bgr_calculate_thresholded_vari_drone_imagery_channel_1'
                ]
            },
            ft_hpf30_index_threshold_background => {
                'calculate_fourier_transform_hpf30_bgr_threshold_background_removed_vari_stitched_drone_imagery_channel_1' => [
                    'observation_unit_polygon_fourier_transform_hpf30_bgr_calculate_thresholded_vari_drone_imagery_channel_1'
                ]
            },
            ft_hpf40_index_threshold_background => {
                'calculate_fourier_transform_hpf40_bgr_threshold_background_removed_vari_stitched_drone_imagery_channel_1' => [
                    'observation_unit_polygon_fourier_transform_hpf40_bgr_calculate_thresholded_vari_drone_imagery_channel_1'
                ]
            },
            original_thresholded_index_mask_background => {
                'denoised_background_removed_thresholded_vari_mask_original' => [
                    'observation_unit_polygon_original_background_removed_thresholded_vari_mask_imagery',
                    'observation_unit_polygon_original_background_removed_thresholded_vari_mask_imagery_channel_1',
                    'observation_unit_polygon_original_background_removed_thresholded_vari_mask_imagery_channel_2',
                    'observation_unit_polygon_original_background_removed_thresholded_vari_mask_imagery_channel_3',
                ]
            },
            ft_hpf20_original_thresholded_index_mask_background_channel_1 => {
                'calculate_fourier_transform_hpf20_bgr_denoised_background_removed_thresholded_vari_mask_original_channel_1' => [
                    'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_removed_thresholded_vari_mask_channel_1'
                ]
            },
            ft_hpf30_original_thresholded_index_mask_background_channel_1 => {
                'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_vari_mask_original_channel_1' => [
                    'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_vari_mask_channel_1'
                ]
            },
            ft_hpf40_original_thresholded_index_mask_background_channel_1 => {
                'calculate_fourier_transform_hpf40_bgr_denoised_background_removed_thresholded_vari_mask_original_channel_1' => [
                    'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_removed_thresholded_vari_mask_channel_1'
                ]
            },
            ft_hpf20_original_thresholded_index_mask_background_channel_2 => {
                'calculate_fourier_transform_hpf20_bgr_denoised_background_removed_thresholded_vari_mask_original_channel_2' => [
                    'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_removed_thresholded_vari_mask_channel_2'
                ]
            },
            ft_hpf30_original_thresholded_index_mask_background_channel_2 => {
                'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_vari_mask_original_channel_2' => [
                    'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_vari_mask_channel_2'
                ]
            },
            ft_hpf40_original_thresholded_index_mask_background_channel_2 => {
                'calculate_fourier_transform_hpf40_bgr_denoised_background_removed_thresholded_vari_mask_original_channel_2' => [
                    'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_removed_thresholded_vari_mask_channel_2'
                ]
            },
            ft_hpf20_original_thresholded_index_mask_background_channel_3 => {
                'calculate_fourier_transform_hpf20_bgr_denoised_background_removed_thresholded_vari_mask_original_channel_3' => [
                    'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_removed_thresholded_vari_mask_channel_3'
                ]
            },
            ft_hpf30_original_thresholded_index_mask_background_channel_3 => {
                'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_vari_mask_original_channel_3' => [
                    'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_vari_mask_channel_3'
                ]
            },
            ft_hpf40_original_thresholded_index_mask_background_channel_3 => {
                'calculate_fourier_transform_hpf40_bgr_denoised_background_removed_thresholded_vari_mask_original_channel_3' => [
                    'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_removed_thresholded_vari_mask_channel_3'
                ]
            },
            original_index_mask_background => {
                'denoised_background_removed_vari_mask_original' => [
                    'observation_unit_polygon_original_background_removed_vari_mask_imagery',
                    'observation_unit_polygon_original_background_removed_vari_mask_imagery_channel_1',
                    'observation_unit_polygon_original_background_removed_vari_mask_imagery_channel_2',
                    'observation_unit_polygon_original_background_removed_vari_mask_imagery_channel_3',
                ]
            },
            ft_hpf20_original_index_mask_background_channel_1 => {
                'calculate_fourier_transform_hpf20_bgr_denoised_background_removed_vari_mask_original_channel_1' => [
                    'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_removed_vari_mask_channel_1'
                ]
            },
            ft_hpf30_original_index_mask_background_channel_1 => {
                'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_vari_mask_original_channel_1' => [
                    'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_vari_mask_channel_1'
                ]
            },
            ft_hpf40_original_index_mask_background_channel_1 => {
                'calculate_fourier_transform_hpf40_bgr_denoised_background_removed_vari_mask_original_channel_1' => [
                    'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_removed_vari_mask_channel_1'
                ]
            },
            ft_hpf20_original_index_mask_background_channel_2 => {
                'calculate_fourier_transform_hpf20_bgr_denoised_background_removed_vari_mask_original_channel_2' => [
                    'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_removed_vari_mask_channel_2'
                ]
            },
            ft_hpf30_original_index_mask_background_channel_2 => {
                'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_vari_mask_original_channel_2' => [
                    'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_vari_mask_channel_2'
                ]
            },
            ft_hpf40_original_index_mask_background_channel_2 => {
                'calculate_fourier_transform_hpf40_bgr_denoised_background_removed_vari_mask_original_channel_2' => [
                    'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_removed_vari_mask_channel_2'
                ]
            },
            ft_hpf20_original_index_mask_background_channel_3 => {
                'calculate_fourier_transform_hpf20_bgr_denoised_background_removed_vari_mask_original_channel_3' => [
                    'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_removed_vari_mask_channel_3'
                ]
            },
            ft_hpf30_original_index_mask_background_channel_3 => {
                'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_vari_mask_original_channel_3' => [
                    'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_vari_mask_channel_3'
                ]
            },
            ft_hpf40_original_index_mask_background_channel_3 => {
                'calculate_fourier_transform_hpf40_bgr_denoised_background_removed_vari_mask_original_channel_3' => [
                    'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_removed_vari_mask_channel_3'
                ]
            }
        },
        'NDVI' => {
            index => {
                'calculate_ndvi_drone_imagery' => [
                    'observation_unit_polygon_ndvi_imagery'
                ]
            },
            ft_hpf20 => {
                'calculate_fourier_transform_hpf20_nrn_calculate_ndvi_drone_imagery_channel_1' => [
                    'observation_unit_polygon_fourier_transform_hpf20_nrn_calculate_ndvi_drone_imagery_channel_1'
                ]
            },
            ft_hpf30 => {
                'calculate_fourier_transform_hpf30_nrn_calculate_ndvi_drone_imagery_channel_1' => [
                    'observation_unit_polygon_fourier_transform_hpf30_nrn_calculate_ndvi_drone_imagery_channel_1'
                ]
            },
            ft_hpf40 => {
                'calculate_fourier_transform_hpf40_nrn_calculate_ndvi_drone_imagery_channel_1' => [
                    'observation_unit_polygon_fourier_transform_hpf40_nrn_calculate_ndvi_drone_imagery_channel_1'
                ]
            },
            index_threshold_background => {
                'threshold_background_removed_ndvi_stitched_drone_imagery' => [
                    'observation_unit_polygon_background_removed_ndvi_imagery'
                ]
            },
            ft_hpf20_index_threshold_background => {
                'calculate_fourier_transform_hpf20_nrn_threshold_background_removed_ndvi_stitched_drone_imagery_channel_1' => [
                    'observation_unit_polygon_fourier_transform_hpf20_nrn_calculate_thresholded_ndvi_drone_imagery_channel_1'
                ]
            },
            ft_hpf30_index_threshold_background => {
                'calculate_fourier_transform_hpf30_nrn_threshold_background_removed_ndvi_stitched_drone_imagery_channel_1' => [
                    'observation_unit_polygon_fourier_transform_hpf30_nrn_calculate_thresholded_ndvi_drone_imagery_channel_1'
                ]
            },
            ft_hpf40_index_threshold_background => {
                'calculate_fourier_transform_hpf40_nrn_threshold_background_removed_ndvi_stitched_drone_imagery_channel_1' => [
                    'observation_unit_polygon_fourier_transform_hpf40_nrn_calculate_thresholded_ndvi_drone_imagery_channel_1'
                ]
            },
            original_thresholded_index_mask_background => {
                'denoised_background_removed_thresholded_ndvi_mask_original' => [
                    'observation_unit_polygon_original_nrn_background_removed_thresholded_ndvi_mask_imagery',
                    'observation_unit_polygon_original_nrn_background_removed_thresholded_ndvi_mask_imagery_channel_1',
                    'observation_unit_polygon_original_nrn_background_removed_thresholded_ndvi_mask_imagery_channel_2',
                ]
            },
            ft_hpf20_original_thresholded_index_mask_background_channel_1 => {
                'calculate_fourier_transform_hpf20_nrn_denoised_background_removed_thresholded_ndvi_mask_original_channel_1' => [
                    'observation_unit_polygon_fourier_transform_hpf20_nrn_denoised_background_removed_thresholded_ndvi_mask_channel_1'
                ]
            },
            ft_hpf30_original_thresholded_index_mask_background_channel_1 => {
                'calculate_fourier_transform_hpf30_nrn_denoised_background_removed_thresholded_ndvi_mask_original_channel_1' => [
                    'observation_unit_polygon_fourier_transform_hpf30_nrn_denoised_background_removed_thresholded_ndvi_mask_channel_1'
                ]
            },
            ft_hpf40_original_thresholded_index_mask_background_channel_1 => {
                'calculate_fourier_transform_hpf40_nrn_denoised_background_removed_thresholded_ndvi_mask_original_channel_1' => [
                    'observation_unit_polygon_fourier_transform_hpf40_nrn_denoised_background_removed_thresholded_ndvi_mask_channel_1'
                ]
            },
            ft_hpf20_original_thresholded_index_mask_background_channel_2 => {
                'calculate_fourier_transform_hpf20_nrn_denoised_background_removed_thresholded_ndvi_mask_original_channel_2' => [
                    'observation_unit_polygon_fourier_transform_hpf20_nrn_denoised_background_removed_thresholded_ndvi_mask_channel_2'
                ]
            },
            ft_hpf30_original_thresholded_index_mask_background_channel_2 => {
                'calculate_fourier_transform_hpf30_nrn_denoised_background_removed_thresholded_ndvi_mask_original_channel_2' => [
                    'observation_unit_polygon_fourier_transform_hpf30_nrn_denoised_background_removed_thresholded_ndvi_mask_channel_2'
                ]
            },
            ft_hpf40_original_thresholded_index_mask_background_channel_2 => {
                'calculate_fourier_transform_hpf40_nrn_denoised_background_removed_thresholded_ndvi_mask_original_channel_2' => [
                    'observation_unit_polygon_fourier_transform_hpf40_nrn_denoised_background_removed_thresholded_ndvi_mask_channel_2'
                ]
            },
            original_index_mask_background => {
                'denoised_background_removed_ndvi_mask_original' => [
                    'observation_unit_polygon_original_nrn_background_removed_ndvi_mask_imagery',
                    'observation_unit_polygon_original_nrn_background_removed_ndvi_mask_imagery_channel_1',
                    'observation_unit_polygon_original_nrn_background_removed_ndvi_mask_imagery_channel_2',
                ]
            },
            ft_hpf20_original_index_mask_background_channel_1 => {
                'calculate_fourier_transform_hpf20_nrn_denoised_background_removed_ndvi_mask_original_channel_1' => [
                    'observation_unit_polygon_fourier_transform_hpf20_nrn_denoised_background_removed_ndvi_mask_channel_1'
                ]
            },
            ft_hpf30_original_index_mask_background_channel_1 => {
                'calculate_fourier_transform_hpf30_nrn_denoised_background_removed_ndvi_mask_original_channel_1' => [
                    'observation_unit_polygon_fourier_transform_hpf30_nrn_denoised_background_removed_ndvi_mask_channel_1'
                ]
            },
            ft_hpf40_original_index_mask_background_channel_1 => {
                'calculate_fourier_transform_hpf40_nrn_denoised_background_removed_ndvi_mask_original_channel_1' => [
                    'observation_unit_polygon_fourier_transform_hpf40_nrn_denoised_background_removed_ndvi_mask_channel_1'
                ]
            },
            ft_hpf20_original_index_mask_background_channel_2 => {
                'calculate_fourier_transform_hpf20_nrn_denoised_background_removed_ndvi_mask_original_channel_2' => [
                    'observation_unit_polygon_fourier_transform_hpf20_nrn_denoised_background_removed_ndvi_mask_channel_2'
                ]
            },
            ft_hpf30_original_index_mask_background_channel_2 => {
                'calculate_fourier_transform_hpf30_nrn_denoised_background_removed_ndvi_mask_original_channel_2' => [
                    'observation_unit_polygon_fourier_transform_hpf30_nrn_denoised_background_removed_ndvi_mask_channel_2'
                ]
            },
            ft_hpf40_original_index_mask_background_channel_2 => {
                'calculate_fourier_transform_hpf40_nrn_denoised_background_removed_ndvi_mask_original_channel_2' => [
                    'observation_unit_polygon_fourier_transform_hpf40_nrn_denoised_background_removed_ndvi_mask_channel_2'
                ]
            }
        },
        'NDRE' => {
            index => {
                'calculate_ndre_drone_imagery' => [
                    'observation_unit_polygon_ndre_imagery'
                ]
            },
            ft_hpf20 => {
                'calculate_fourier_transform_hpf20_nren_calculate_ndre_drone_imagery_channel_1' => [
                    'observation_unit_polygon_fourier_transform_hpf20_nren_calculate_ndre_drone_imagery_channel_1'
                ]
            },
            ft_hpf30 => {
                'calculate_fourier_transform_hpf30_nren_calculate_ndre_drone_imagery_channel_1' => [
                    'observation_unit_polygon_fourier_transform_hpf30_nren_calculate_ndre_drone_imagery_channel_1'
                ]
            },
            ft_hpf40 => {
                'calculate_fourier_transform_hpf40_nren_calculate_ndre_drone_imagery_channel_1' => [
                    'observation_unit_polygon_fourier_transform_hpf40_nren_calculate_ndre_drone_imagery_channel_1'
                ]
            },
            index_threshold_background => {
                'threshold_background_removed_ndre_stitched_drone_imagery' => [
                    'observation_unit_polygon_background_removed_ndre_imagery'
                ]
            },
            ft_hpf20_index_threshold_background => {
                'calculate_fourier_transform_hpf20_nren_threshold_background_removed_ndre_stitched_drone_imagery_channel_1' => [
                    'observation_unit_polygon_fourier_transform_hpf20_nren_calculate_thresholded_ndre_drone_imagery_channel_1'
                ]
            },
            ft_hpf30_index_threshold_background => {
                'calculate_fourier_transform_hpf30_nren_threshold_background_removed_ndre_stitched_drone_imagery_channel_1' => [
                    'observation_unit_polygon_fourier_transform_hpf30_nren_calculate_thresholded_ndre_drone_imagery_channel_1'
                ]
            },
            ft_hpf40_index_threshold_background => {
                'calculate_fourier_transform_hpf40_nren_threshold_background_removed_ndre_stitched_drone_imagery_channel_1' => [
                    'observation_unit_polygon_fourier_transform_hpf40_nren_calculate_thresholded_ndre_drone_imagery_channel_1'
                ]
            },
            original_thresholded_index_mask_background => {
                'denoised_background_removed_thresholded_ndre_mask_original' => [
                    'observation_unit_polygon_original_nren_background_removed_thresholded_ndre_mask_imagery',
                    'observation_unit_polygon_original_nren_background_removed_thresholded_ndre_mask_imagery_channel_1',
                    'observation_unit_polygon_original_nren_background_removed_thresholded_ndre_mask_imagery_channel_2'
                ]
            },
            ft_hpf20_original_thresholded_index_mask_background_channel_1 => {
                'calculate_fourier_transform_hpf20_nren_denoised_background_removed_thresholded_ndre_mask_original_channel_1' => [
                    'observation_unit_polygon_fourier_transform_hpf20_nren_denoised_background_removed_thresholded_ndre_mask_channel_1'
                ]
            },
            ft_hpf30_original_thresholded_index_mask_background_channel_1 => {
                'calculate_fourier_transform_hpf30_nren_denoised_background_removed_thresholded_ndre_mask_original_channel_1' => [
                    'observation_unit_polygon_fourier_transform_hpf30_nren_denoised_background_removed_thresholded_ndre_mask_channel_1'
                ]
            },
            ft_hpf40_original_thresholded_index_mask_background_channel_1 => {
                'calculate_fourier_transform_hpf40_nren_denoised_background_removed_thresholded_ndre_mask_original_channel_1' => [
                    'observation_unit_polygon_fourier_transform_hpf40_nren_denoised_background_removed_thresholded_ndre_mask_channel_1'
                ]
            },
            ft_hpf20_original_thresholded_index_mask_background_channel_2 => {
                'calculate_fourier_transform_hpf20_nren_denoised_background_removed_thresholded_ndre_mask_original_channel_2' => [
                    'observation_unit_polygon_fourier_transform_hpf20_nren_denoised_background_removed_thresholded_ndre_mask_channel_2'
                ]
            },
            ft_hpf30_original_thresholded_index_mask_background_channel_2 => {
                'calculate_fourier_transform_hpf30_nren_denoised_background_removed_thresholded_ndre_mask_original_channel_2' => [
                    'observation_unit_polygon_fourier_transform_hpf30_nren_denoised_background_removed_thresholded_ndre_mask_channel_2'
                ]
            },
            ft_hpf40_original_thresholded_index_mask_background_channel_2 => {
                'calculate_fourier_transform_hpf40_nren_denoised_background_removed_thresholded_ndre_mask_original_channel_2' => [
                    'observation_unit_polygon_fourier_transform_hpf40_nren_denoised_background_removed_thresholded_ndre_mask_channel_2'
                ]
            },
            original_index_mask_background => {
                'denoised_background_removed_ndre_mask_original' => [
                    'observation_unit_polygon_original_nren_background_removed_ndre_mask_imagery',
                    'observation_unit_polygon_original_nren_background_removed_ndre_mask_imagery_channel_1',
                    'observation_unit_polygon_original_nren_background_removed_ndre_mask_imagery_channel_2',
                ]
            },
            ft_hpf20_original_index_mask_background_channel_1 => {
                'calculate_fourier_transform_hpf20_nren_denoised_background_removed_ndre_mask_original_channel_1' => [
                    'observation_unit_polygon_fourier_transform_hpf20_nren_denoised_background_removed_ndre_mask_channel_1'
                ]
            },
            ft_hpf30_original_index_mask_background_channel_1 => {
                'calculate_fourier_transform_hpf30_nren_denoised_background_removed_ndre_mask_original_channel_1' => [
                    'observation_unit_polygon_fourier_transform_hpf30_nren_denoised_background_removed_ndre_mask_channel_1'
                ]
            },
            ft_hpf40_original_index_mask_background_channel_1 => {
                'calculate_fourier_transform_hpf40_nren_denoised_background_removed_ndre_mask_original_channel_1' => [
                    'observation_unit_polygon_fourier_transform_hpf40_nren_denoised_background_removed_ndre_mask_channel_1'
                ]
            },
            ft_hpf20_original_index_mask_background_channel_2 => {
                'calculate_fourier_transform_hpf20_nren_denoised_background_removed_ndre_mask_original_channel_2' => [
                    'observation_unit_polygon_fourier_transform_hpf20_nren_denoised_background_removed_ndre_mask_channel_2'
                ]
            },
            ft_hpf30_original_index_mask_background_channel_2 => {
                'calculate_fourier_transform_hpf30_nren_denoised_background_removed_ndre_mask_original_channel_2' => [
                    'observation_unit_polygon_fourier_transform_hpf30_nren_denoised_background_removed_ndre_mask_channel_2'
                ]
            },
            ft_hpf40_original_index_mask_background_channel_2 => {
                'calculate_fourier_transform_hpf40_nren_denoised_background_removed_ndre_mask_original_channel_2' => [
                    'observation_unit_polygon_fourier_transform_hpf40_nren_denoised_background_removed_ndre_mask_channel_2'
                ]
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
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf20_blue_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf20_blue_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_blue_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_blue_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf40_blue_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf40_blue_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf20_green_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf20_green_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_green_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_green_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf40_green_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf40_green_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf20_red_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf20_red_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_red_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_red_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf40_red_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf40_red_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf20_rededge_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf20_rededge_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_rededge_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_rededge_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf40_rededge_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf40_rededge_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf20_nir_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf20_nir_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_nir_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_nir_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf40_nir_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf40_nir_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf20_mir_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf20_mir_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_mir_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_mir_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf40_mir_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf40_mir_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf20_fir_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf20_fir_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_fir_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_fir_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf40_fir_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf40_fir_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf20_tir_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf20_tir_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_tir_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_tir_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf40_tir_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf40_tir_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf20_bw_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf20_bw_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_bw_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_bw_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf40_bw_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf40_bw_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf20_bgr_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf20_bgr_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_bgr_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_bgr_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf40_bgr_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf40_bgr_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf20_bgr_denoised_stitched_image_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf20_bgr_denoised_stitched_image_channel_2', channels=>[0], corresponding_channel=>1
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_bgr_denoised_stitched_image_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_bgr_denoised_stitched_image_channel_2', channels=>[0], corresponding_channel=>1
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf40_bgr_denoised_stitched_image_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf40_bgr_denoised_stitched_image_channel_2', channels=>[0], corresponding_channel=>1
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf20_bgr_denoised_stitched_image_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf20_bgr_denoised_stitched_image_channel_3', channels=>[0], corresponding_channel=>2
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_bgr_denoised_stitched_image_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_bgr_denoised_stitched_image_channel_3', channels=>[0], corresponding_channel=>2
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf40_bgr_denoised_stitched_image_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf40_bgr_denoised_stitched_image_channel_3', channels=>[0], corresponding_channel=>2
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf20_blue_threshold_background_removed_stitched_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf20_blue_threshold_background_removed_stitched_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_blue_threshold_background_removed_stitched_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_blue_threshold_background_removed_stitched_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf40_blue_threshold_background_removed_stitched_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf40_blue_threshold_background_removed_stitched_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf20_green_threshold_background_removed_stitched_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf20_green_threshold_background_removed_stitched_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_green_threshold_background_removed_stitched_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_green_threshold_background_removed_stitched_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf40_green_threshold_background_removed_stitched_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf40_green_threshold_background_removed_stitched_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf20_red_threshold_background_removed_stitched_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf20_red_threshold_background_removed_stitched_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_red_threshold_background_removed_stitched_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_red_threshold_background_removed_stitched_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf40_red_threshold_background_removed_stitched_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf40_red_threshold_background_removed_stitched_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf20_rededge_threshold_background_removed_stitched_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf20_rededge_threshold_background_removed_stitched_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_rededge_threshold_background_removed_stitched_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_rededge_threshold_background_removed_stitched_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf40_rededge_threshold_background_removed_stitched_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf40_rededge_threshold_background_removed_stitched_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf20_nir_threshold_background_removed_stitched_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf20_nir_threshold_background_removed_stitched_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_nir_threshold_background_removed_stitched_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_nir_threshold_background_removed_stitched_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf40_nir_threshold_background_removed_stitched_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf40_nir_threshold_background_removed_stitched_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf20_mir_threshold_background_removed_stitched_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf20_mir_threshold_background_removed_stitched_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_mir_threshold_background_removed_stitched_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_mir_threshold_background_removed_stitched_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf40_mir_threshold_background_removed_stitched_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf40_mir_threshold_background_removed_stitched_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf20_fir_threshold_background_removed_stitched_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf20_fir_threshold_background_removed_stitched_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_fir_threshold_background_removed_stitched_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_fir_threshold_background_removed_stitched_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf40_fir_threshold_background_removed_stitched_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf40_fir_threshold_background_removed_stitched_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf20_tir_threshold_background_removed_stitched_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf20_tir_threshold_background_removed_stitched_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_tir_threshold_background_removed_stitched_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_tir_threshold_background_removed_stitched_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf40_tir_threshold_background_removed_stitched_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf40_tir_threshold_background_removed_stitched_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf20_bw_threshold_background_removed_stitched_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf20_bw_threshold_background_removed_stitched_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_bw_threshold_background_removed_stitched_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_bw_threshold_background_removed_stitched_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf40_bw_threshold_background_removed_stitched_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf40_bw_threshold_background_removed_stitched_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf20_bgr_threshold_background_removed_stitched_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf20_bgr_threshold_background_removed_stitched_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_bgr_threshold_background_removed_stitched_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_bgr_threshold_background_removed_stitched_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf40_bgr_threshold_background_removed_stitched_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf40_bgr_threshold_background_removed_stitched_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf20_bgr_threshold_background_removed_stitched_drone_imagery_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf20_bgr_threshold_background_removed_stitched_drone_imagery_channel_2', channels=>[0], corresponding_channel=>1
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_bgr_threshold_background_removed_stitched_drone_imagery_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_bgr_threshold_background_removed_stitched_drone_imagery_channel_2', channels=>[0], corresponding_channel=>1
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf40_bgr_threshold_background_removed_stitched_drone_imagery_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf40_bgr_threshold_background_removed_stitched_drone_imagery_channel_2', channels=>[0], corresponding_channel=>1
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf20_bgr_threshold_background_removed_stitched_drone_imagery_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf20_bgr_threshold_background_removed_stitched_drone_imagery_channel_3', channels=>[0], corresponding_channel=>2
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_bgr_threshold_background_removed_stitched_drone_imagery_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_bgr_threshold_background_removed_stitched_drone_imagery_channel_3', channels=>[0], corresponding_channel=>2
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf40_bgr_threshold_background_removed_stitched_drone_imagery_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf40_bgr_threshold_background_removed_stitched_drone_imagery_channel_3', channels=>[0], corresponding_channel=>2
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf20_bgr_threshold_background_removed_tgi_stitched_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf20_bgr_threshold_background_removed_tgi_stitched_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_bgr_threshold_background_removed_tgi_stitched_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_bgr_threshold_background_removed_tgi_stitched_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf40_bgr_threshold_background_removed_tgi_stitched_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf40_bgr_threshold_background_removed_tgi_stitched_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf20_bgr_threshold_background_removed_vari_stitched_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf20_bgr_threshold_background_removed_vari_stitched_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_bgr_threshold_background_removed_vari_stitched_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_bgr_threshold_background_removed_vari_stitched_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf40_bgr_threshold_background_removed_vari_stitched_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf40_bgr_threshold_background_removed_vari_stitched_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf20_nrn_threshold_background_removed_ndvi_stitched_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf20_nrn_threshold_background_removed_ndvi_stitched_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_nrn_threshold_background_removed_ndvi_stitched_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_nrn_threshold_background_removed_ndvi_stitched_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf40_nrn_threshold_background_removed_ndvi_stitched_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf40_nrn_threshold_background_removed_ndvi_stitched_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf20_nren_threshold_background_removed_ndre_stitched_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf20_nren_threshold_background_removed_ndre_stitched_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_nren_threshold_background_removed_ndre_stitched_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_nren_threshold_background_removed_ndre_stitched_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf40_nren_threshold_background_removed_ndre_stitched_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf40_nren_threshold_background_removed_ndre_stitched_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf20_bgr_denoised_background_removed_tgi_mask_original_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf20_bgr_denoised_background_removed_tgi_mask_original_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_tgi_mask_original_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_tgi_mask_original_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf40_bgr_denoised_background_removed_tgi_mask_original_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf40_bgr_denoised_background_removed_tgi_mask_original_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf20_bgr_denoised_background_removed_tgi_mask_original_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf20_bgr_denoised_background_removed_tgi_mask_original_channel_2', channels=>[0], corresponding_channel=>1
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_tgi_mask_original_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_tgi_mask_original_channel_2', channels=>[0], corresponding_channel=>1
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf40_bgr_denoised_background_removed_tgi_mask_original_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf40_bgr_denoised_background_removed_tgi_mask_original_channel_2', channels=>[0], corresponding_channel=>1
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf20_bgr_denoised_background_removed_tgi_mask_original_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf20_bgr_denoised_background_removed_tgi_mask_original_channel_3', channels=>[0], corresponding_channel=>2
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_tgi_mask_original_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_tgi_mask_original_channel_3', channels=>[0], corresponding_channel=>2
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf40_bgr_denoised_background_removed_tgi_mask_original_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf40_bgr_denoised_background_removed_tgi_mask_original_channel_3', channels=>[0], corresponding_channel=>2
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf20_bgr_denoised_background_removed_vari_mask_original_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf20_bgr_denoised_background_removed_vari_mask_original_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_vari_mask_original_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_vari_mask_original_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf40_bgr_denoised_background_removed_vari_mask_original_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf40_bgr_denoised_background_removed_vari_mask_original_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf20_bgr_denoised_background_removed_vari_mask_original_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf20_bgr_denoised_background_removed_vari_mask_original_channel_2', channels=>[0], corresponding_channel=>1
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_vari_mask_original_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_vari_mask_original_channel_2', channels=>[0], corresponding_channel=>1
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf40_bgr_denoised_background_removed_vari_mask_original_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf40_bgr_denoised_background_removed_vari_mask_original_channel_2', channels=>[0], corresponding_channel=>1
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf20_bgr_denoised_background_removed_vari_mask_original_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf20_bgr_denoised_background_removed_vari_mask_original_channel_3', channels=>[0], corresponding_channel=>2
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_vari_mask_original_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_vari_mask_original_channel_3', channels=>[0], corresponding_channel=>2
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf40_bgr_denoised_background_removed_vari_mask_original_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf40_bgr_denoised_background_removed_vari_mask_original_channel_3', channels=>[0], corresponding_channel=>2
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf20_nrn_denoised_background_removed_ndvi_mask_original_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf20_nrn_denoised_background_removed_ndvi_mask_original_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_nrn_denoised_background_removed_ndvi_mask_original_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_nrn_denoised_background_removed_ndvi_mask_original_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf40_nrn_denoised_background_removed_ndvi_mask_original_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf40_nrn_denoised_background_removed_ndvi_mask_original_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf20_nrn_denoised_background_removed_ndvi_mask_original_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf20_nrn_denoised_background_removed_ndvi_mask_original_channel_2', channels=>[0], corresponding_channel=>1
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_nrn_denoised_background_removed_ndvi_mask_original_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_nrn_denoised_background_removed_ndvi_mask_original_channel_2', channels=>[0], corresponding_channel=>1
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf40_nrn_denoised_background_removed_ndvi_mask_original_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf40_nrn_denoised_background_removed_ndvi_mask_original_channel_2', channels=>[0], corresponding_channel=>1
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf20_nren_denoised_background_removed_ndre_mask_original_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf20_nren_denoised_background_removed_ndre_mask_original_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_nren_denoised_background_removed_ndre_mask_original_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_nren_denoised_background_removed_ndre_mask_original_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf40_nren_denoised_background_removed_ndre_mask_original_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf40_nren_denoised_background_removed_ndre_mask_original_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf20_nren_denoised_background_removed_ndre_mask_original_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf20_nren_denoised_background_removed_ndre_mask_original_channel_2', channels=>[0], corresponding_channel=>1
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_nren_denoised_background_removed_ndre_mask_original_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_nren_denoised_background_removed_ndre_mask_original_channel_2', channels=>[0], corresponding_channel=>1
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf40_nren_denoised_background_removed_ndre_mask_original_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf40_nren_denoised_background_removed_ndre_mask_original_channel_2', channels=>[0], corresponding_channel=>1
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf20_bgr_denoised_background_removed_thresholded_tgi_mask_original_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf20_bgr_denoised_background_removed_thresholded_tgi_mask_original_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_tgi_mask_original_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_tgi_mask_original_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf40_bgr_denoised_background_removed_thresholded_tgi_mask_original_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf40_bgr_denoised_background_removed_thresholded_tgi_mask_original_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf20_bgr_denoised_background_removed_thresholded_tgi_mask_original_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf20_bgr_denoised_background_removed_thresholded_tgi_mask_original_channel_2', channels=>[0], corresponding_channel=>1
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_tgi_mask_original_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_tgi_mask_original_channel_2', channels=>[0], corresponding_channel=>1
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf40_bgr_denoised_background_removed_thresholded_tgi_mask_original_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf40_bgr_denoised_background_removed_thresholded_tgi_mask_original_channel_2', channels=>[0], corresponding_channel=>1
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf20_bgr_denoised_background_removed_thresholded_tgi_mask_original_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf20_bgr_denoised_background_removed_thresholded_tgi_mask_original_channel_3', channels=>[0], corresponding_channel=>2
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_tgi_mask_original_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_tgi_mask_original_channel_3', channels=>[0], corresponding_channel=>2
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf40_bgr_denoised_background_removed_thresholded_tgi_mask_original_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf40_bgr_denoised_background_removed_thresholded_tgi_mask_original_channel_3', channels=>[0], corresponding_channel=>2
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf20_bgr_denoised_background_removed_thresholded_vari_mask_original_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf20_bgr_denoised_background_removed_thresholded_vari_mask_original_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_vari_mask_original_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_vari_mask_original_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf40_bgr_denoised_background_removed_thresholded_vari_mask_original_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf40_bgr_denoised_background_removed_thresholded_vari_mask_original_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf20_bgr_denoised_background_removed_thresholded_vari_mask_original_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf20_bgr_denoised_background_removed_thresholded_vari_mask_original_channel_2', channels=>[0], corresponding_channel=>1
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_vari_mask_original_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_vari_mask_original_channel_2', channels=>[0], corresponding_channel=>1
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf40_bgr_denoised_background_removed_thresholded_vari_mask_original_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf40_bgr_denoised_background_removed_thresholded_vari_mask_original_channel_2', channels=>[0], corresponding_channel=>1
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf20_bgr_denoised_background_removed_thresholded_vari_mask_original_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf20_bgr_denoised_background_removed_thresholded_vari_mask_original_channel_3', channels=>[0], corresponding_channel=>2
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_vari_mask_original_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_vari_mask_original_channel_3', channels=>[0], corresponding_channel=>2
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf40_bgr_denoised_background_removed_thresholded_vari_mask_original_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf40_bgr_denoised_background_removed_thresholded_vari_mask_original_channel_3', channels=>[0], corresponding_channel=>2
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf20_nrn_denoised_background_removed_thresholded_ndvi_mask_original_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf20_nrn_denoised_background_removed_thresholded_ndvi_mask_original_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_nrn_denoised_background_removed_thresholded_ndvi_mask_original_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_nrn_denoised_background_removed_thresholded_ndvi_mask_original_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf40_nrn_denoised_background_removed_thresholded_ndvi_mask_original_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf40_nrn_denoised_background_removed_thresholded_ndvi_mask_original_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf20_nrn_denoised_background_removed_thresholded_ndvi_mask_original_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf20_nrn_denoised_background_removed_thresholded_ndvi_mask_original_channel_2', channels=>[0], corresponding_channel=>1
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_nrn_denoised_background_removed_thresholded_ndvi_mask_original_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_nrn_denoised_background_removed_thresholded_ndvi_mask_original_channel_2', channels=>[0], corresponding_channel=>1
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf40_nrn_denoised_background_removed_thresholded_ndvi_mask_original_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf40_nrn_denoised_background_removed_thresholded_ndvi_mask_original_channel_2', channels=>[0], corresponding_channel=>1
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf20_nren_denoised_background_removed_thresholded_ndre_mask_original_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf20_nren_denoised_background_removed_thresholded_ndre_mask_original_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_nren_denoised_background_removed_thresholded_ndre_mask_original_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_nren_denoised_background_removed_thresholded_ndre_mask_original_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf40_nren_denoised_background_removed_thresholded_ndre_mask_original_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf40_nren_denoised_background_removed_thresholded_ndre_mask_original_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf20_nren_denoised_background_removed_thresholded_ndre_mask_original_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf20_nren_denoised_background_removed_thresholded_ndre_mask_original_channel_2', channels=>[0], corresponding_channel=>1
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_nren_denoised_background_removed_thresholded_ndre_mask_original_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_nren_denoised_background_removed_thresholded_ndre_mask_original_channel_2', channels=>[0], corresponding_channel=>1
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf40_nren_denoised_background_removed_thresholded_ndre_mask_original_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf40_nren_denoised_background_removed_thresholded_ndre_mask_original_channel_2', channels=>[0], corresponding_channel=>1
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf20_bgr_calculate_tgi_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf20_bgr_calculate_tgi_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_bgr_calculate_tgi_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_bgr_calculate_tgi_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf40_bgr_calculate_tgi_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf40_bgr_calculate_tgi_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf20_bgr_calculate_vari_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf20_bgr_calculate_vari_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_bgr_calculate_vari_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_bgr_calculate_vari_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf40_bgr_calculate_vari_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf40_bgr_calculate_vari_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf20_nrn_calculate_ndvi_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf20_nrn_calculate_ndvi_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_nrn_calculate_ndvi_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_nrn_calculate_ndvi_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf40_nrn_calculate_ndvi_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf40_nrn_calculate_ndvi_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf20_nren_calculate_ndre_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf20_nren_calculate_ndre_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_nren_calculate_ndre_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf30_nren_calculate_ndre_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf40_nren_calculate_ndre_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'calculate_fourier_transform_hpf40_nren_calculate_ndre_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0
        }
    };
}

1;
