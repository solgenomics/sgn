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
    my %project_type_lookup = (
        black_and_white => 'Black and White Image',
        rgb_color_image => 'RGB Color Image',
        bgr => 'Merged 3 Bands BGR',
        nrn => 'Merged 3 Bands NRN',
        nren => 'Merged 3 Bands NReN',
        blue => 'Blue (450-520nm)',
        green => 'Green (515-600nm)',
        red => 'Red (600-690nm)',
        red_edge => 'Red Edge (690-750nm)',
        nir => 'NIR (780-3000nm)',
        mir => 'MIR (3000-50000nm)',
        fir => 'FIR (50000-1000000nm)',
        tir => 'Thermal IR (9000-14000nm)',
        raster_dsm => 'Raster DSM'
    );
    return {
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_bw_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_bw_imagery', channels=>[0], corresponding_channel=>0, display_name=>'Black and White Image(s)', ISOL_name=>'Black and White Denoised Original Image|ISOL:0000106', drone_run_project_types=>[$project_type_lookup{black_and_white}], standard_process=>['minimal']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_rgb_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_rgb_imagery', channels=>[0,1,2], corresponding_channel=>undef, display_name=>'RGB Color Image(s)', ISOL_name=>'RGB Denoised Original Image|ISOL:0000102', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['minimal', 'minimal_vi']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_rgb_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_rgb_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Blue Image(s) from RGB Color Image', ISOL_name=>'Blue Image From RGB Denoised Original Image|ISOL:0000103', drone_run_project_types=>[$project_type_lookup{rgb_color_image}], standard_process=>['minimal']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_rgb_imagery_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_rgb_imagery_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Green Image(s) from RGB Color Image', ISOL_name=>'Green Image From RGB Denoised Original Image|ISOL:0000104', drone_run_project_types=>[$project_type_lookup{rgb_color_image}], standard_process=>['minimal']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_rgb_imagery_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_rgb_imagery_channel_3', channels=>[0], corresponding_channel=>2, display_name=>'Red Image(s) from RGB Color Image', ISOL_name=>'Red Image From RGB Denoised Original Image|ISOL:0000105', drone_run_project_types=>[$project_type_lookup{rgb_color_image}], standard_process=>['minimal']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_nrn_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_nrn_imagery', channels=>[0,1,2], corresponding_channel=>undef, display_name=>'NRN Merged 3 Bands Image(s)', ISOL_name=>'Merged 3 Bands NRN Denoised Image|ISOL:0000115', drone_run_project_types=>[$project_type_lookup{nrn}], standard_process=>['minimal', 'minimal_vi']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_nren_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_nren_imagery', channels=>[0,1,2], corresponding_channel=>undef, display_name=>'NReN Merged 3 Bands Image(s)', ISOL_name=>'Merged 3 Bands NReN Denoised Image|ISOL:0000116', drone_run_project_types=>[$project_type_lookup{nren}], standard_process=>['minimal', 'minimal_vi']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_blue_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_blue_imagery', channels=>[0], corresponding_channel=>0, display_name=>'Blue Image(s)', ISOL_name=>'Blue Denoised Original Image|ISOL:0000107', drone_run_project_types=>[$project_type_lookup{blue}], standard_process=>['minimal']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_green_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_green_imagery', channels=>[0], corresponding_channel=>0, display_name=>'Green Image(s)', ISOL_name=>'Green Denoised Original Image|ISOL:0000108', drone_run_project_types=>[$project_type_lookup{green}], standard_process=>['minimal', 'minimal_vi']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_red_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_red_imagery', channels=>[0], corresponding_channel=>0, display_name=>'Red Image(s)', ISOL_name=>'Red Denoised Original Image|ISOL:0000109', drone_run_project_types=>[$project_type_lookup{red}], standard_process=>['minimal']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_red_edge_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_red_edge_imagery', channels=>[0], corresponding_channel=>0, display_name=>'Red Edge Image(s)', ISOL_name=>'Red Edge Denoised Original Image|ISOL:0000110', drone_run_project_types=>[$project_type_lookup{red_edge}], standard_process=>['minimal']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_nir_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_nir_imagery', channels=>[0], corresponding_channel=>0, display_name=>'NIR Image(s)', ISOL_name=>'NIR Denoised Original Image|ISOL:0000111', drone_run_project_types=>[$project_type_lookup{nir}], standard_process=>['minimal']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_mir_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_mir_imagery', channels=>[0], corresponding_channel=>0, display_name=>'MIR Image(s)', ISOL_name=>'MIR Denoised Original Image|ISOL:0000112', drone_run_project_types=>[$project_type_lookup{mir}], standard_process=>['minimal']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fir_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fir_imagery', channels=>[0], corresponding_channel=>0, display_name=>'FIR Image(s)', ISOL_name=>'FIR Denoised Original Image|ISOL:0000113', drone_run_project_types=>[$project_type_lookup{fir}], standard_process=>['minimal']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_tir_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_tir_imagery', channels=>[0], corresponding_channel=>0, display_name=>'Thermal IR Image(s)', ISOL_name=>'Thermal IR Denoised Original Image|ISOL:0000114', drone_run_project_types=>[$project_type_lookup{tir}], standard_process=>['minimal']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_raster_dsm_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_raster_dsm_imagery', channels=>[0], corresponding_channel=>0, display_name=>'Raster DSM Image(s)', ISOL_name=>'Raster DSM Denoised Original Image|ISOL:0000321', drone_run_project_types=>[$project_type_lookup{raster_dsm}], standard_process=>['minimal']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_bw_background_removed_threshold_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_bw_background_removed_threshold_imagery', channels=>[0], corresponding_channel=>0, display_name=>'Black and White Image(s) with Background Removed via Threshold', ISOL_name=>'Thresholded Black and White Denoised Original Image|ISOL:0000117', drone_run_project_types=>[$project_type_lookup{black_and_white}], standard_process=>['minimal']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_rgb_background_removed_threshold_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_rgb_background_removed_threshold_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Blue Image(s) from RGB Color Image with Background Removed via Threshold', ISOL_name=>'Thresholded Blue Image from RGB Color Denoised Original Image|ISOL:0000118', drone_run_project_types=>[$project_type_lookup{rgb_color_image}], standard_process=>['minimal']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_rgb_background_removed_threshold_imagery_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_rgb_background_removed_threshold_imagery_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Green Image(s) from RGB Color Image with Background Removed via Threshold', ISOL_name=>'Thresholded Green Image from RGB Color Denoised Original Image|ISOL:0000119', drone_run_project_types=>[$project_type_lookup{rgb_color_image}], standard_process=>['minimal']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_rgb_background_removed_threshold_imagery_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_rgb_background_removed_threshold_imagery_channel_3', channels=>[0], corresponding_channel=>2, display_name=>'Red Image(s) from RGB Color Image with Background Removed via Threshold', ISOL_name=>'Thresholded Red Image from RGB Color Denoised Original Image|ISOL:0000120', drone_run_project_types=>[$project_type_lookup{rgb_color_image}], standard_process=>['minimal']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_blue_background_removed_threshold_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_blue_background_removed_threshold_imagery', channels=>[0], corresponding_channel=>0, display_name=>'Blue Image(s) with Background Removed via Threshold', ISOL_name=>'Thresholded Blue Denoised Original Image|ISOL:0000121', drone_run_project_types=>[$project_type_lookup{blue}], standard_process=>['minimal']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_green_background_removed_threshold_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_green_background_removed_threshold_imagery', channels=>[0], corresponding_channel=>0, display_name=>'Green Image(s) with Background Removed via Threshold', ISOL_name=>'Thresholded Green Denoised Original Image|ISOL:0000122', drone_run_project_types=>[$project_type_lookup{green}], standard_process=>['minimal']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_red_background_removed_threshold_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_red_background_removed_threshold_imagery', channels=>[0], corresponding_channel=>0, display_name=>'Red Image(s) with Background Removed via Threshold', ISOL_name=>'Thresholded Red Denoised Original Image|ISOL:0000123', drone_run_project_types=>[$project_type_lookup{red}], standard_process=>['minimal']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_red_edge_background_removed_threshold_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_red_edge_background_removed_threshold_imagery', channels=>[0], corresponding_channel=>0, display_name=>'Red Edge Image(s) with Background Removed via Threshold', ISOL_name=>'Thresholded Red Edge Denoised Original Image|ISOL:0000124', drone_run_project_types=>[$project_type_lookup{red_edge}], standard_process=>['minimal']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_nir_background_removed_threshold_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_nir_background_removed_threshold_imagery', channels=>[0], corresponding_channel=>0, display_name=>'NIR Image(s) with Background Removed via Threshold', ISOL_name=>'Thresholded NIR Denoised Original Image|ISOL:0000125', drone_run_project_types=>[$project_type_lookup{nir}], standard_process=>['minimal']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_mir_background_removed_threshold_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_mir_background_removed_threshold_imagery', channels=>[0], corresponding_channel=>0, display_name=>'MIR Image(s) with Background Removed via Threshold', ISOL_name=>'Thresholded MIR Denoised Original Image|ISOL:0000126', drone_run_project_types=>[$project_type_lookup{mir}], standard_process=>['minimal']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fir_background_removed_threshold_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fir_background_removed_threshold_imagery', channels=>[0], corresponding_channel=>0, display_name=>'FIR Image(s) with Background Removed via Threshold', ISOL_name=>'Thresholded FIR Denoised Original Image|ISOL:0000127', drone_run_project_types=>[$project_type_lookup{fir}], standard_process=>['minimal']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_tir_background_removed_threshold_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_tir_background_removed_threshold_imagery', channels=>[0], corresponding_channel=>0, display_name=>'Thermal IR Image(s) with Background Removed via Threshold', ISOL_name=>'Thresholded Thermal IR Denoised Original Image|ISOL:0000128', drone_run_project_types=>[$project_type_lookup{tir}], standard_process=>['minimal']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_raster_dsm_background_removed_threshold_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_raster_dsm_background_removed_threshold_imagery', channels=>[0], corresponding_channel=>0, display_name=>'Raster DSM Image(s) with Background Removed via Threshold', ISOL_name=>'Thresholded Raster DSM Denoised Original Image|ISOL:0000322', drone_run_project_types=>[$project_type_lookup{raster_dsm}], standard_process=>['minimal']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_tgi_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_tgi_imagery', channels=>[0], corresponding_channel=>0, display_name=>'TGI Vegetative Index Image(s)', ISOL_name=>'TGI Vegetative Index Image|ISOL:0000129', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['minimal', 'minimal_vi']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_vari_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_vari_imagery', channels=>[0], corresponding_channel=>0, display_name=>'VARI Vegetative Index Image(s)', ISOL_name=>'VARI Vegetative Index Image|ISOL:0000130', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['minimal', 'minimal_vi']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_ndvi_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_ndvi_imagery', channels=>[0], corresponding_channel=>0, display_name=>'NDVI Vegetative Index Image(s)', ISOL_name=>'NDVI Vegetative Index Image|ISOL:0000131', drone_run_project_types=>[$project_type_lookup{nrn}], standard_process=>['minimal', 'minimal_vi']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_ndre_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_ndre_imagery', channels=>[0], corresponding_channel=>0, display_name=>'NDRE Vegetative Index Image(s)', ISOL_name=>'NDRE Vegetative Index Image|ISOL:0000132', drone_run_project_types=>[$project_type_lookup{nren}], standard_process=>['minimal', 'minimal_vi']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_background_removed_tgi_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_background_removed_tgi_imagery', channels=>[0], corresponding_channel=>0, display_name=>'TGI Vegetative Index Image(s) with Threshold Applied', ISOL_name=>'Thresholded TGI Vegetative Index Image|ISOL:0000133', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_background_removed_vari_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_background_removed_vari_imagery', channels=>[0], corresponding_channel=>0, display_name=>'VARI Vegetative Index Image(s) with Threshold Applied', ISOL_name=>'Thresholded VARI Vegetative Index Image|ISOL:0000134', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_background_removed_ndvi_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_background_removed_ndvi_imagery', channels=>[0], corresponding_channel=>0, display_name=>'NDVI Vegetative Index Image(s) with Threshold Applied', ISOL_name=>'Thresholded NDVI Vegetative Index Image|ISOL:0000135', drone_run_project_types=>[$project_type_lookup{nrn}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_background_removed_ndre_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_background_removed_ndre_imagery', channels=>[0], corresponding_channel=>0, display_name=>'NDRE Vegetative Index Image(s) with Threshold Applied', ISOL_name=>'Thresholded NDRE Vegetative Index Image|ISOL:0000136', drone_run_project_types=>[$project_type_lookup{nren}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_tgi_mask_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_background_removed_tgi_mask_imagery', channels=>[0,1,2], corresponding_channel=>undef, display_name=>'RGB Image(s) with Background Removed via a TGI mask', ISOL_name=>'RGB Color Image Masked with TGI Vegetative Index Image|ISOL:0000137', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_tgi_mask_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_background_removed_tgi_mask_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Blue Image(s) from RGB Image with Background Removed via a TGI mask', ISOL_name=>'Blue Image from RGB Color Image Masked with TGI Vegetative Index Image|ISOL:0000138', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_tgi_mask_imagery_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_background_removed_tgi_mask_imagery_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Green Image(s) from RGB Image with Background Removed via a TGI mask', ISOL_name=>'Green Image from RGB Color Image Masked with TGI Vegetative Index Image|ISOL:0000139', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_tgi_mask_imagery_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_background_removed_tgi_mask_imagery_channel_3', channels=>[0], corresponding_channel=>2, display_name=>'Red Image(s) from RGB Image with Background Removed via a TGI mask', ISOL_name=>'Red Image from RGB Color Image Masked with TGI Vegetative Index Image|ISOL:0000140', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_vari_mask_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_background_removed_vari_mask_imagery', channels=>[0,1,2], corresponding_channel=>undef, display_name=>'RGB Image(s) with Background Removed via a VARI mask', ISOL_name=>'RGB Color Image Masked with VARI Vegetative Index Image|ISOL:0000141', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_vari_mask_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_background_removed_vari_mask_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Blue Image(s) from RGB Image with Background Removed via a VARI mask', ISOL_name=>'Blue Image from RGB Color Image Masked with VARI Vegetative Index Image|ISOL:0000142', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_vari_mask_imagery_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_background_removed_vari_mask_imagery_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Green Image(s) from RGB Image with Background Removed via a VARI mask', ISOL_name=>'Green Image from RGB Color Image Masked with VARI Vegetative Index Image|ISOL:0000143', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_vari_mask_imagery_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_background_removed_vari_mask_imagery_channel_3', channels=>[0], corresponding_channel=>2, display_name=>'Red Image(s) from RGB Image with Background Removed via a VARI mask', ISOL_name=>'Red Image from RGB Color Image Masked with VARI Vegetative Index Image|ISOL:0000144', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_nrn_background_removed_ndvi_mask_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_nrn_background_removed_ndvi_mask_imagery', channels=>[0,1,2], corresponding_channel=>undef, display_name=>'NRN Image(s) with Background Removed via a NDVI mask', ISOL_name=>'Merged 3 Channels NRN Image Masked with NDVI Vegetative Index Image|ISOL:0000145', drone_run_project_types=>[$project_type_lookup{nrn}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_nrn_background_removed_ndvi_mask_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_nrn_background_removed_ndvi_mask_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'NIR Image(s) from NRN Image with Background Removed via a NDVI mask', ISOL_name=>'NIR Image from Merged 3 Channels NRN Image Masked with NDVI Vegetative Index Image|ISOL:0000146', drone_run_project_types=>[$project_type_lookup{nrn}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_nrn_background_removed_ndvi_mask_imagery_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_nrn_background_removed_ndvi_mask_imagery_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Red Image(s) from NRN Image with Background Removed via a NDVI mask', ISOL_name=>'Red Image from Merged 3 Channels NRN Image Masked with NDVI Vegetative Index Image|ISOL:0000147', drone_run_project_types=>[$project_type_lookup{nrn}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_nren_background_removed_ndre_mask_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_nren_background_removed_ndre_mask_imagery', channels=>[0,1,2], corresponding_channel=>undef, display_name=>'NReN Image(s) with Background Removed via a NDRE mask', ISOL_name=>'Merged 3 Channels NReN Image Masked with NDRE Vegetative Index Image|ISOL:0000148', drone_run_project_types=>[$project_type_lookup{nren}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_nren_background_removed_ndre_mask_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_nren_background_removed_ndre_mask_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'NIR Image(s) from NReN Image with Background Removed via a NDRE mask', ISOL_name=>'NIR Image from Merged 3 Channels NReN Image Masked with NDRE Vegetative Index Image|ISOL:0000149', drone_run_project_types=>[$project_type_lookup{nren}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_nren_background_removed_ndre_mask_imagery_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_nren_background_removed_ndre_mask_imagery_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Red Edge Image(s) from NReN Image with Background Removed via a NDRE mask', ISOL_name=>'Red Edge Image from Merged 3 Channels NReN Image Masked with NDRE Vegetative Index Image|ISOL:0000150', drone_run_project_types=>[$project_type_lookup{nren}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_thresholded_tgi_mask_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_background_removed_thresholded_tgi_mask_imagery', channels=>[0,1,2], corresponding_channel=>undef, display_name=>'RGB Image(s) with Background Removed via a Thresholded TGI mask', ISOL_name=>'RGB Color Image Masked with Thresholded TGI Vegetative Index Image|ISOL:0000151', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_thresholded_tgi_mask_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_background_removed_thresholded_tgi_mask_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Blue Image(s) from RGB Image with Background Removed via a Thresholded TGI mask', ISOL_name=>'Blue Image from RGB Color Image Masked with Thresholded TGI Vegetative Index Image|ISOL:0000152', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_thresholded_tgi_mask_imagery_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_background_removed_thresholded_tgi_mask_imagery_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Green Image(s) from RGB Image with Background Removed via a Thresholded TGI mask', ISOL_name=>'Green Image from RGB Color Image Masked with Thresholded TGI Vegetative Index Image|ISOL:0000153', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_thresholded_tgi_mask_imagery_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_background_removed_thresholded_tgi_mask_imagery_channel_3', channels=>[0], corresponding_channel=>2, display_name=>'Red Image(s) from RGB Image with Background Removed via a Thresholded TGI mask', ISOL_name=>'Red Image from RGB Color Image Masked with Thresholded TGI Vegetative Index Image|ISOL:0000154', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_thresholded_vari_mask_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_background_removed_thresholded_vari_mask_imagery', channels=>[0,1,2], corresponding_channel=>undef, display_name=>'RGB Image(s) with Background Removed via a Thresholded VARI mask', ISOL_name=>'RGB Color Image Masked with Thresholded VARI Vegetative Index Image|ISOL:0000155', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_thresholded_vari_mask_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_background_removed_thresholded_vari_mask_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Blue Image(s) from RGB Image with Background Removed via a Thresholded VARI mask', ISOL_name=>'Blue Image from RGB Color Image Masked with Thresholded VARI Vegetative Index Image|ISOL:0000156', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_thresholded_vari_mask_imagery_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_background_removed_thresholded_vari_mask_imagery_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Green Image(s) from RGB Image with Background Removed via a Thresholded VARI mask', ISOL_name=>'Gren Image from RGB Color Image Masked with Thresholded VARI Vegetative Index Image|ISOL:0000157', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_thresholded_vari_mask_imagery_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_background_removed_thresholded_vari_mask_imagery_channel_3', channels=>[0], corresponding_channel=>2, display_name=>'Red Image(s) from RGB Image with Background Removed via a Thresholded VARI mask', ISOL_name=>'Red Image from RGB Color Image Masked with Thresholded VARI Vegetative Index Image|ISOL:0000158', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_nrn_background_removed_thresholded_ndvi_mask_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_nrn_background_removed_thresholded_ndvi_mask_imagery', channels=>[0,1,2], corresponding_channel=>undef, display_name=>'NRN Image(s) with Background Removed via a Thresholded NDVI mask', ISOL_name=>'Merged 3 Channels NRN Image Masked with Thresholded NDVI Vegetative Index Image|ISOL:0000159', drone_run_project_types=>[$project_type_lookup{nrn}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_nrn_background_removed_thresholded_ndvi_mask_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_nrn_background_removed_thresholded_ndvi_mask_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'NIR Image(s) from NRN Image with Background Removed via a Thresholded NDVI mask', ISOL_name=>'NIR Image from Merged 3 Channels NRN Image Masked with Thresholded NDVI Vegetative Index Image|ISOL:0000160', drone_run_project_types=>[$project_type_lookup{nrn}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_nrn_background_removed_thresholded_ndvi_mask_imagery_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_nrn_background_removed_thresholded_ndvi_mask_imagery_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Red Image(s) from NRN Image with Background Removed via a Thresholded NDVI mask', ISOL_name=>'Red Image from Merged 3 Channels NRN Image Masked with Thresholded NDVI Vegetative Index Image|ISOL:0000161', drone_run_project_types=>[$project_type_lookup{nrn}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_nren_background_removed_thresholded_ndre_mask_imagery', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_nren_background_removed_thresholded_ndre_mask_imagery', channels=>[0,1,2], corresponding_channel=>undef, display_name=>'NReN Image(s) with Background Removed via a Thresholded NDRE mask', ISOL_name=>'Merged 3 Channels NReN Image Masked with Thresholded NDRE Vegetative Index Image|ISOL:0000162', drone_run_project_types=>[$project_type_lookup{nren}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_nren_background_removed_thresholded_ndre_mask_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_nren_background_removed_thresholded_ndre_mask_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'NIR Image(s) from NReN Image with Background Removed via a Thresholded NDRE mask', ISOL_name=>'NIR Image from Merged 3 Channels NReN Image Masked with Thresholded NDRE Vegetative Index Image|ISOL:0000163', drone_run_project_types=>[$project_type_lookup{nren}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_nren_background_removed_thresholded_ndre_mask_imagery_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_original_nren_background_removed_thresholded_ndre_mask_imagery_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Red Edge Image(s) from NReN Image with Background Removed via a Thresholded NDRE mask', ISOL_name=>'Red Edge Image from Merged 3 Channels NReN Image Masked with Thresholded NDRE Vegetative Index Image|ISOL:0000164', drone_run_project_types=>[$project_type_lookup{nren}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_blue_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_blue_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 Blue Image(s)', ISOL_name=>'Fourier Transform High Pass Filter 20 Blue Denoised Image|ISOL:0000165', drone_run_project_types=>[$project_type_lookup{blue}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_blue_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_blue_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 Blue Image(s)', ISOL_name=>'Fourier Transform High Pass Filter 30 Blue Denoised Image|ISOL:0000166', drone_run_project_types=>[$project_type_lookup{blue}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_blue_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_blue_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 Blue Image(s)', ISOL_name=>'Fourier Transform High Pass Filter 40 Blue Denoised Image|ISOL:0000167', drone_run_project_types=>[$project_type_lookup{blue}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_green_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_green_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 Green Image(s)', ISOL_name=>'Fourier Transform High Pass Filter 20 Green Denoised Image|ISOL:0000168', drone_run_project_types=>[$project_type_lookup{green}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_green_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_green_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 Green Image(s)', ISOL_name=>'Fourier Transform High Pass Filter 30 Green Denoised Image|ISOL:0000169', drone_run_project_types=>[$project_type_lookup{green}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_green_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_green_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 Green Image(s)', ISOL_name=>'Fourier Transform High Pass Filter 40 Green Denoised Image|ISOL:0000170', drone_run_project_types=>[$project_type_lookup{green}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_red_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_red_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 Red Image(s)', ISOL_name=>'Fourier Transform High Pass Filter 20 Red Denoised Image|ISOL:0000171', drone_run_project_types=>[$project_type_lookup{red}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_red_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_red_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 Red Image(s)', ISOL_name=>'Fourier Transform High Pass Filter 30 Red Denoised Image|ISOL:0000172', drone_run_project_types=>[$project_type_lookup{red}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_red_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_red_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 Red Image(s)', ISOL_name=>'Fourier Transform High Pass Filter 40 Red Denoised Image|ISOL:0000173', drone_run_project_types=>[$project_type_lookup{red}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_rededge_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_rededge_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 Red Edge Image(s)', ISOL_name=>'Fourier Transform High Pass Filter 20 Red Edge Denoised Image|ISOL:0000174', drone_run_project_types=>[$project_type_lookup{red_edge}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_rededge_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_rededge_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 Red Edge Image(s)', ISOL_name=>'Fourier Transform High Pass Filter 30 Red Edge Denoised Image|ISOL:0000175', drone_run_project_types=>[$project_type_lookup{red_edge}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_rededge_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_rededge_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 Red Edge Image(s)', ISOL_name=>'Fourier Transform High Pass Filter 40 Red Edge Denoised Image|ISOL:0000176', drone_run_project_types=>[$project_type_lookup{red_edge}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_nir_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_nir_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 NIR Image(s)', ISOL_name=>'Fourier Transform High Pass Filter 20 NIR Denoised Image|ISOL:0000177', drone_run_project_types=>[$project_type_lookup{nir}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_nir_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_nir_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 NIR Image(s)', ISOL_name=>'Fourier Transform High Pass Filter 30 NIR Denoised Image|ISOL:0000178', drone_run_project_types=>[$project_type_lookup{nir}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_nir_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_nir_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 NIR Image(s)', ISOL_name=>'Fourier Transform High Pass Filter 40 NIR Denoised Image|ISOL:0000179', drone_run_project_types=>[$project_type_lookup{nir}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_mir_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_mir_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 MIR Image(s)', ISOL_name=>'Fourier Transform High Pass Filter 20 MIR Denoised Image|ISOL:0000180', drone_run_project_types=>[$project_type_lookup{mir}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_mir_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_mir_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 MIR Image(s)', ISOL_name=>'Fourier Transform High Pass Filter 30 MIR Denoised Image|ISOL:0000181', drone_run_project_types=>[$project_type_lookup{mir}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_mir_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_mir_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 MIR Image(s)', ISOL_name=>'Fourier Transform High Pass Filter 40 MIR Denoised Image|ISOL:0000182', drone_run_project_types=>[$project_type_lookup{mir}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_fir_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_fir_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 FIR Image(s)', ISOL_name=>'Fourier Transform High Pass Filter 20 FIR Denoised Image|ISOL:0000183', drone_run_project_types=>[$project_type_lookup{fir}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_fir_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_fir_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 FIR Image(s)', ISOL_name=>'Fourier Transform High Pass Filter 30 FIR Denoised Image|ISOL:0000184', drone_run_project_types=>[$project_type_lookup{fir}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_fir_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_fir_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 FIR Image(s)', ISOL_name=>'Fourier Transform High Pass Filter 40 FIR Denoised Image|ISOL:0000185', drone_run_project_types=>[$project_type_lookup{fir}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_tir_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_tir_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 Thermal IR Image(s)', ISOL_name=>'Fourier Transform High Pass Filter 20 Thermal IR Denoised Image|ISOL:0000186', drone_run_project_types=>[$project_type_lookup{tir}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_tir_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_tir_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 Thermal IR Image(s)', ISOL_name=>'Fourier Transform High Pass Filter 30 Thermal IR Denoised Image|ISOL:0000187', drone_run_project_types=>[$project_type_lookup{tir}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_tir_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_tir_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 Thermal IR Image(s)', ISOL_name=>'Fourier Transform High Pass Filter 40 Thermal IR Denoised Image|ISOL:0000188', drone_run_project_types=>[$project_type_lookup{tir}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_bw_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_bw_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 Black and White Image(s)', ISOL_name=>'Fourier Transform High Pass Filter 20 Black and White Denoised Image|ISOL:0000189', drone_run_project_types=>[$project_type_lookup{black_and_white}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bw_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bw_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 Black and White Image(s)', ISOL_name=>'Fourier Transform High Pass Filter 30 Black and White Denoised Image|ISOL:0000190', drone_run_project_types=>[$project_type_lookup{black_and_white}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_bw_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_bw_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 Black and White Image(s)', ISOL_name=>'Fourier Transform High Pass Filter 40 Black and White Denoised Image|ISOL:0000191', drone_run_project_types=>[$project_type_lookup{black_and_white}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 Blue Image(s) from RGB Image', ISOL_name=>'Fourier Transform High Pass Filter 20 Blue Image from Denoised RGB Color Image|ISOL:0000192', drone_run_project_types=>[$project_type_lookup{rgb_color_image}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 Blue Image(s) from RGB Image', ISOL_name=>'Fourier Transform High Pass Filter 30 Blue Image from Denoised RGB Color Image|ISOL:0000193', drone_run_project_types=>[$project_type_lookup{rgb_color_image}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_stitched_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 Blue Image(s) from RGB Image', ISOL_name=>'Fourier Transform High Pass Filter 40 Blue Image from Denoised RGB Color Image|ISOL:0000194', drone_run_project_types=>[$project_type_lookup{rgb_color_image}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_stitched_image_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_stitched_image_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Fourier Transform HPF20 Green Image(s) from RGB Image', ISOL_name=>'Fourier Transform High Pass Filter 20 Green Image from Denoised RGB Color Image|ISOL:0000195', drone_run_project_types=>[$project_type_lookup{rgb_color_image}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_stitched_image_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_stitched_image_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Fourier Transform HPF30 Green Image(s) from RGB Image', ISOL_name=>'Fourier Transform High Pass Filter 30 Green Image from Denoised RGB Color Image|ISOL:0000196', drone_run_project_types=>[$project_type_lookup{rgb_color_image}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_stitched_image_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_stitched_image_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Fourier Transform HPF40 Green Image(s) from RGB Image', ISOL_name=>'Fourier Transform High Pass Filter 40 Green Image from Denoised RGB Color Image|ISOL:0000197', drone_run_project_types=>[$project_type_lookup{rgb_color_image}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_stitched_image_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_stitched_image_channel_3', channels=>[0], corresponding_channel=>2, display_name=>'Fourier Transform HPF20 Red Image(s) from RGB Image', ISOL_name=>'Fourier Transform High Pass Filter 20 Red Image from Denoised RGB Color Image|ISOL:0000198', drone_run_project_types=>[$project_type_lookup{rgb_color_image}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_stitched_image_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_stitched_image_channel_3', channels=>[0], corresponding_channel=>2, display_name=>'Fourier Transform HPF30 Red Image(s) from RGB Image', ISOL_name=>'Fourier Transform High Pass Filter 30 Red Image from Denoised RGB Color Image|ISOL:0000199', drone_run_project_types=>[$project_type_lookup{rgb_color_image}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_stitched_image_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_stitched_image_channel_3', channels=>[0], corresponding_channel=>2, display_name=>'Fourier Transform HPF40 Red Image(s) from RGB Image', ISOL_name=>'Fourier Transform High Pass Filter 40 Red Image from Denoised RGB Color Image|ISOL:0000200', drone_run_project_types=>[$project_type_lookup{rgb_color_image}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_bgr_calculate_tgi_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_bgr_calculate_tgi_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 TGI Vegetative Index Image(s)', ISOL_name=>'Fourier Transform High Pass Filter 20 TGI Vegetative Index Image|ISOL:0000201', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bgr_calculate_tgi_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bgr_calculate_tgi_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 TGI Vegetative Index Image(s)', ISOL_name=>'Fourier Transform High Pass Filter 30 TGI Vegetative Index Image|ISOL:0000202', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_bgr_calculate_tgi_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_bgr_calculate_tgi_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 TGI Vegetative Index Image(s)', ISOL_name=>'Fourier Transform High Pass Filter 40 TGI Vegetative Index Image|ISOL:0000203', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_bgr_calculate_vari_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_bgr_calculate_vari_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 VARI Vegetative Index Image(s)', ISOL_name=>'Fourier Transform High Pass Filter 20 VARI Vegetative Index Image|ISOL:0000204', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bgr_calculate_vari_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bgr_calculate_vari_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 VARI Vegetative Index Image(s)', ISOL_name=>'Fourier Transform High Pass Filter 30 VARI Vegetative Index Image|ISOL:0000205', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_bgr_calculate_vari_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_bgr_calculate_vari_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 VARI Vegetative Index Image(s)', ISOL_name=>'Fourier Transform High Pass Filter 40 VARI Vegetative Index Image|ISOL:0000206', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_nrn_calculate_ndvi_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_nrn_calculate_ndvi_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 NDVI Vegetative Index Image(s)', ISOL_name=>'Fourier Transform High Pass Filter 20 NDVI Vegetative Index Image|ISOL:0000207', drone_run_project_types=>[$project_type_lookup{nrn}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_nrn_calculate_ndvi_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_nrn_calculate_ndvi_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 NDVI Vegetative Index Image(s)', ISOL_name=>'Fourier Transform High Pass Filter 30 NDVI Vegetative Index Image|ISOL:0000208', drone_run_project_types=>[$project_type_lookup{nrn}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_nrn_calculate_ndvi_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_nrn_calculate_ndvi_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 NDVI Vegetative Index Image(s)', ISOL_name=>'Fourier Transform High Pass Filter 40 NDVI Vegetative Index Image|ISOL:0000209', drone_run_project_types=>[$project_type_lookup{nrn}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_nren_calculate_ndre_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_nren_calculate_ndre_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 NDRE Vegetative Index Image(s)', ISOL_name=>'Fourier Transform High Pass Filter 20 NDRE Vegetative Index Image|ISOL:0000210', drone_run_project_types=>[$project_type_lookup{nren}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_nren_calculate_ndre_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_nren_calculate_ndre_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 NDRE Vegetative Index Image(s)', ISOL_name=>'Fourier Transform High Pass Filter 30 NDRE Vegetative Index Image|ISOL:0000211', drone_run_project_types=>[$project_type_lookup{nren}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_nren_calculate_ndre_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_nren_calculate_ndre_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 NDRE Vegetative Index Image(s)', ISOL_name=>'Fourier Transform High Pass Filter 40 NDRE Vegetative Index Image|ISOL:0000212', drone_run_project_types=>[$project_type_lookup{nren}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_bgr_calculate_thresholded_tgi_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_bgr_calculate_thresholded_tgi_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 Thresholded TGI Vegetative Index Image(s)', ISOL_name=>'Fourier Transform High Pass Filter 20 Thresholded TGI Vegetative Index Image|ISOL:0000213', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bgr_calculate_thresholded_tgi_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bgr_calculate_thresholded_tgi_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 Thresholded TGI Vegetative Index Image(s)', ISOL_name=>'Fourier Transform High Pass Filter 30 Thresholded TGI Vegetative Index Image|ISOL:0000214', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_bgr_calculate_thresholded_tgi_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_bgr_calculate_thresholded_tgi_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 Thresholded TGI Vegetative Index Image(s)', ISOL_name=>'Fourier Transform High Pass Filter 40 Thresholded TGI Vegetative Index Image|ISOL:0000215', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_bgr_calculate_thresholded_vari_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_bgr_calculate_thresholded_vari_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 Thresholded VARI Vegetative Index Image(s)', ISOL_name=>'Fourier Transform High Pass Filter 20 Thresholded VARI Vegetative Index Image|ISOL:0000216', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bgr_calculate_thresholded_vari_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bgr_calculate_thresholded_vari_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 Thresholded VARI Vegetative Index Image(s)', ISOL_name=>'Fourier Transform High Pass Filter 30 Thresholded VARI Vegetative Index Image|ISOL:0000217', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_bgr_calculate_thresholded_vari_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_bgr_calculate_thresholded_vari_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 Thresholded VARI Vegetative Index Image(s)', ISOL_name=>'Fourier Transform High Pass Filter 40 Thresholded VARI Vegetative Index Image|ISOL:0000218', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_nrn_calculate_thresholded_ndvi_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_nrn_calculate_thresholded_ndvi_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 Thresholded NDVI Vegetative Index Image(s)', ISOL_name=>'Fourier Transform High Pass Filter 20 Thresholded NDVI Vegetative Index Image|ISOL:0000219', drone_run_project_types=>[$project_type_lookup{nrn}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_nrn_calculate_thresholded_ndvi_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_nrn_calculate_thresholded_ndvi_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 Thresholded NDVI Vegetative Index Image(s)', ISOL_name=>'Fourier Transform High Pass Filter 30 Thresholded NDVI Vegetative Index Image|ISOL:0000220', drone_run_project_types=>[$project_type_lookup{nrn}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_nrn_calculate_thresholded_ndvi_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_nrn_calculate_thresholded_ndvi_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 Thresholded NDVI Vegetative Index Image(s)', ISOL_name=>'Fourier Transform High Pass Filter 40 Thresholded NDVI Vegetative Index Image|ISOL:0000221', drone_run_project_types=>[$project_type_lookup{nrn}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_nren_calculate_thresholded_ndre_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_nren_calculate_thresholded_ndre_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 Thresholded NDRE Vegetative Index Image(s)', ISOL_name=>'Fourier Transform High Pass Filter 20 Thresholded NDRE Vegetative Index Image|ISOL:0000222', drone_run_project_types=>[$project_type_lookup{nren}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_nren_calculate_thresholded_ndre_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_nren_calculate_thresholded_ndre_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 Thresholded NDRE Vegetative Index Image(s)', ISOL_name=>'Fourier Transform High Pass Filter 30 Thresholded NDRE Vegetative Index Image|ISOL:0000223', drone_run_project_types=>[$project_type_lookup{nren}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_nren_calculate_thresholded_ndre_drone_imagery_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_nren_calculate_thresholded_ndre_drone_imagery_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 Thresholded NDRE Vegetative Index Image(s)', ISOL_name=>'Fourier Transform High Pass Filter 40 Thresholded NDRE Vegetative Index Image|ISOL:0000224', drone_run_project_types=>[$project_type_lookup{nren}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_blue_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_blue_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 Blue Image(s) with Background Removed via Threshold', ISOL_name=>'Fourier Transform High Pass Filter 20 Thresholded Blue Denoised Image|ISOL:0000225', drone_run_project_types=>[$project_type_lookup{blue}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_blue_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_blue_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 Blue Image(s) with Background Removed via Threshold', ISOL_name=>'Fourier Transform High Pass Filter 30 Thresholded Blue Denoised Image|ISOL:0000226', drone_run_project_types=>[$project_type_lookup{blue}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_blue_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_blue_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 Blue Image(s) with Background Removed via Threshold', ISOL_name=>'Fourier Transform High Pass Filter 40 Thresholded Blue Denoised Image|ISOL:0000227', drone_run_project_types=>[$project_type_lookup{blue}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_green_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_green_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 Green Image(s) with Background Removed via Threshold', ISOL_name=>'Fourier Transform High Pass Filter 20 Thresholded Green Denoised Image|ISOL:0000228', drone_run_project_types=>[$project_type_lookup{green}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_green_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_green_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 Green Image(s) with Background Removed via Threshold', ISOL_name=>'Fourier Transform High Pass Filter 30 Thresholded Green Denoised Image|ISOL:0000229', drone_run_project_types=>[$project_type_lookup{green}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_green_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_green_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 Green Image(s) with Background Removed via Threshold', ISOL_name=>'Fourier Transform High Pass Filter 40 Thresholded Green Denoised Image|ISOL:0000230', drone_run_project_types=>[$project_type_lookup{green}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_red_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_red_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 Red Image(s) with Background Removed via Threshold', ISOL_name=>'Fourier Transform High Pass Filter 20 Thresholded Red Denoised Image|ISOL:0000231', drone_run_project_types=>[$project_type_lookup{red}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_red_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_red_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 Red Image(s) with Background Removed via Threshold', ISOL_name=>'Fourier Transform High Pass Filter 30 Thresholded Red Denoised Image|ISOL:0000232', drone_run_project_types=>[$project_type_lookup{red}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_red_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_red_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 Red Image(s) with Background Removed via Threshold', ISOL_name=>'Fourier Transform High Pass Filter 40 Thresholded Red Denoised Image|ISOL:0000233', drone_run_project_types=>[$project_type_lookup{red}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_rededge_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_rededge_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 Red Edge Image(s) with Background Removed via Threshold', ISOL_name=>'Fourier Transform High Pass Filter 20 Thresholded Red Edge Denoised Image|ISOL:0000234', drone_run_project_types=>[$project_type_lookup{red_edge}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_rededge_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_rededge_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 Red Edge Image(s) with Background Removed via Threshold', ISOL_name=>'Fourier Transform High Pass Filter 30 Thresholded Red Edge Denoised Image|ISOL:0000235', drone_run_project_types=>[$project_type_lookup{red_edge}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_rededge_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_rededge_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 Red Edge Image(s) with Background Removed via Threshold', ISOL_name=>'Fourier Transform High Pass Filter 40 Thresholded Red Edge Denoised Image|ISOL:0000236', drone_run_project_types=>[$project_type_lookup{red_edge}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_nir_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_nir_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 NIR Image(s) with Background Removed via Threshold', ISOL_name=>'Fourier Transform High Pass Filter 20 Thresholded NIR Denoised Image|ISOL:0000237', drone_run_project_types=>[$project_type_lookup{nir}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_nir_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_nir_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 NIR Image(s) with Background Removed via Threshold', ISOL_name=>'Fourier Transform High Pass Filter 30 Thresholded NIR Denoised Image|ISOL:0000238', drone_run_project_types=>[$project_type_lookup{nir}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_nir_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_nir_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 NIR Image(s) with Background Removed via Threshold', ISOL_name=>'Fourier Transform High Pass Filter 40 Thresholded NIR Denoised Image|ISOL:0000239', drone_run_project_types=>[$project_type_lookup{nir}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_mir_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_mir_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 MIR Image(s) with Background Removed via Threshold', ISOL_name=>'Fourier Transform High Pass Filter 20 Thresholded MIR Denoised Image|ISOL:0000240', drone_run_project_types=>[$project_type_lookup{mir}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_mir_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_mir_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 MIR Image(s) with Background Removed via Threshold', ISOL_name=>'Fourier Transform High Pass Filter 30 Thresholded MIR Denoised Image|ISOL:0000241', drone_run_project_types=>[$project_type_lookup{mir}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_mir_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_mir_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 MIR Image(s) with Background Removed via Threshold', ISOL_name=>'Fourier Transform High Pass Filter 40 Thresholded MIR Denoised Image|ISOL:0000242', drone_run_project_types=>[$project_type_lookup{mir}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_fir_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_fir_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 FIR Image(s) with Background Removed via Threshold', ISOL_name=>'Fourier Transform High Pass Filter 20 Thresholded FIR Denoised Image|ISOL:0000243', drone_run_project_types=>[$project_type_lookup{fir}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_fir_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_fir_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 FIR Image(s) with Background Removed via Threshold', ISOL_name=>'Fourier Transform High Pass Filter 30 Thresholded FIR Denoised Image|ISOL:0000244', drone_run_project_types=>[$project_type_lookup{fir}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_fir_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_fir_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 FIR Image(s) with Background Removed via Threshold', ISOL_name=>'Fourier Transform High Pass Filter 40 Thresholded FIR Denoised Image|ISOL:0000245', drone_run_project_types=>[$project_type_lookup{fir}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_tir_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_tir_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 Thermal IR Image(s) with Background Removed via Threshold', ISOL_name=>'Fourier Transform High Pass Filter 20 Thresholded Thermal IR Denoised Image|ISOL:0000246', drone_run_project_types=>[$project_type_lookup{tir}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_tir_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_tir_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 Thermal IR Image(s) with Background Removed via Threshold', ISOL_name=>'Fourier Transform High Pass Filter 30 Thresholded Thermal IR Denoised Image|ISOL:0000247', drone_run_project_types=>[$project_type_lookup{tir}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_tir_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_tir_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 Thermal IR Image(s) with Background Removed via Threshold', ISOL_name=>'Fourier Transform High Pass Filter 40 Thresholded Thermal IR Denoised Image|ISOL:0000248', drone_run_project_types=>[$project_type_lookup{tir}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_bw_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_bw_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 Black and White Image(s) with Background Removed via Threshold', ISOL_name=>'Fourier Transform High Pass Filter 20 Thresholded Black and White Denoised Image|ISOL:0000249', drone_run_project_types=>[$project_type_lookup{black_and_white}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bw_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bw_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 Black and White Image(s) with Background Removed via Threshold', ISOL_name=>'Fourier Transform High Pass Filter 30 Thresholded Black and White Denoised Image|ISOL:0000250', drone_run_project_types=>[$project_type_lookup{black_and_white}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_bw_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_bw_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 Black and White Image(s) with Background Removed via Threshold', ISOL_name=>'Fourier Transform High Pass Filter 40 Thresholded Black and White Denoised Image|ISOL:0000251', drone_run_project_types=>[$project_type_lookup{black_and_white}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 Blue Image(s) from RGB Image with Background Removed via Threshold', ISOL_name=>'Fourier Transform High Pass Filter 20 Thresholded Blue Image From RGB Color Denoised Image|ISOL:0000252', drone_run_project_types=>[$project_type_lookup{rgb_color_image}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 Blue Image(s) from RGB Image with Background Removed via Threshold', ISOL_name=>'Fourier Transform High Pass Filter 30 Thresholded Blue Image From RGB Color Denoised Image|ISOL:0000253', drone_run_project_types=>[$project_type_lookup{rgb_color_image}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_threshold_removed_image_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_threshold_removed_image_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 Blue Image(s) from RGB Image with Background Removed via Threshold', ISOL_name=>'Fourier Transform High Pass Filter 40 Thresholded Blue Image From RGB Color Denoised Image|ISOL:0000254', drone_run_project_types=>[$project_type_lookup{rgb_color_image}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_threshold_removed_image_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_threshold_removed_image_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Fourier Transform HPF20 Green Image(s) from RGB Image with Background Removed via Threshold', ISOL_name=>'Fourier Transform High Pass Filter 20 Thresholded Green Image From RGB Color Denoised Image|ISOL:0000255', drone_run_project_types=>[$project_type_lookup{rgb_color_image}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_threshold_removed_image_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_threshold_removed_image_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Fourier Transform HPF30 Green Image(s) from RGB Image with Background Removed via Threshold', ISOL_name=>'Fourier Transform High Pass Filter 30 Thresholded Green Image From RGB Color Denoised Image|ISOL:0000256', drone_run_project_types=>[$project_type_lookup{rgb_color_image}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_threshold_removed_image_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_threshold_removed_image_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Fourier Transform HPF40 Green Image(s) from RGB Image with Background Removed via Threshold', ISOL_name=>'Fourier Transform High Pass Filter 40 Thresholded Green Image From RGB Color Denoised Image|ISOL:0000257', drone_run_project_types=>[$project_type_lookup{rgb_color_image}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_threshold_removed_image_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_threshold_removed_image_channel_3', channels=>[0], corresponding_channel=>2, display_name=>'Fourier Transform HPF20 Red Image(s) from RGB Image with Background Removed via Threshold', ISOL_name=>'Fourier Transform High Pass Filter 20 Thresholded Red Image From RGB Color Denoised Image|ISOL:0000258', drone_run_project_types=>[$project_type_lookup{rgb_color_image}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_threshold_removed_image_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_threshold_removed_image_channel_3', channels=>[0], corresponding_channel=>2, display_name=>'Fourier Transform HPF30 Red Image(s) from RGB Image with Background Removed via Threshold', ISOL_name=>'Fourier Transform High Pass Filter 30 Thresholded Red Image From RGB Color Denoised Image|ISOL:0000259', drone_run_project_types=>[$project_type_lookup{rgb_color_image}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_threshold_removed_image_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_threshold_removed_image_channel_3', channels=>[0], corresponding_channel=>2, display_name=>'Fourier Transform HPF40 Red Image(s) from RGB Image with Background Removed via Threshold', ISOL_name=>'Fourier Transform High Pass Filter 40 Thresholded Red Image From RGB Color Denoised Image|ISOL:0000260', drone_run_project_types=>[$project_type_lookup{rgb_color_image}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_removed_tgi_mask_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_removed_tgi_mask_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 Blue Image(s) from RGB Image with Background Removed via TGI Mask', ISOL_name=>'Fourier Transform High Pass Filter 20 Blue Image From RGB Color Denoised TGI Vegetative Index Masked Image|ISOL:0000261', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_tgi_mask_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_tgi_mask_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 Blue Image(s) from RGB Image with Background Removed via TGI Mask', ISOL_name=>'Fourier Transform High Pass Filter 30 Blue Image From RGB Color Denoised TGI Vegetative Index Masked Image|ISOL:0000262', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_removed_tgi_mask_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_removed_tgi_mask_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 Blue Image(s) from RGB Image with Background Removed via TGI Mask', ISOL_name=>'Fourier Transform High Pass Filter 40 Blue Image From RGB Color Denoised TGI Vegetative Index Masked Image|ISOL:0000263', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_removed_tgi_mask_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_removed_tgi_mask_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Fourier Transform HPF20 Green Image(s) from RGB Image with Background Removed via TGI Mask', ISOL_name=>'Fourier Transform High Pass Filter 20 Green Image From RGB Color Denoised TGI Vegetative Index Masked Image|ISOL:0000264', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_tgi_mask_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_tgi_mask_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Fourier Transform HPF30 Green Image(s) from RGB Image with Background Removed via TGI Mask', ISOL_name=>'Fourier Transform High Pass Filter 30 Green Image From RGB Color Denoised TGI Vegetative Index Masked Image|ISOL:0000265', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_removed_tgi_mask_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_removed_tgi_mask_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Fourier Transform HPF40 Green Image(s) from RGB Image with Background Removed via TGI Mask', ISOL_name=>'Fourier Transform High Pass Filter 40 Green Image From RGB Color Denoised TGI Vegetative Index Masked Image|ISOL:0000266', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_removed_tgi_mask_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_removed_tgi_mask_channel_3', channels=>[0], corresponding_channel=>2, display_name=>'Fourier Transform HPF20 Red Image(s) from RGB Image with Background Removed via TGI Mask', ISOL_name=>'Fourier Transform High Pass Filter 20 Red Image From RGB Color Denoised TGI Vegetative Index Masked Image|ISOL:0000267', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_tgi_mask_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_tgi_mask_channel_3', channels=>[0], corresponding_channel=>2, display_name=>'Fourier Transform HPF30 Red Image(s) from RGB Image with Background Removed via TGI Mask', ISOL_name=>'Fourier Transform High Pass Filter 30 Red Image From RGB Color Denoised TGI Vegetative Index Masked Image|ISOL:0000268', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_removed_tgi_mask_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_removed_tgi_mask_channel_3', channels=>[0], corresponding_channel=>2, display_name=>'Fourier Transform HPF40 Red Image(s) from RGB Image with Background Removed via TGI Mask', ISOL_name=>'Fourier Transform High Pass Filter 40 Red Image From RGB Color Denoised TGI Vegetative Index Masked Image|ISOL:0000269', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_removed_thresholded_tgi_mask_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_removed_thresholded_tgi_mask_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 Blue Image(s) from RGB Image with Background Removed via Thresholded TGI Mask', ISOL_name=>'Fourier Transform High Pass Filter 20 Blue Image From RGB Color Denoised Thresholded TGI Vegetative Index Masked Image|ISOL:0000270', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_tgi_mask_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_tgi_mask_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 Blue Image(s) from RGB Image with Background Removed via Thresholded TGI Mask', ISOL_name=>'Fourier Transform High Pass Filter 30 Blue Image From RGB Color Denoised Thresholded TGI Vegetative Index Masked Image|ISOL:0000271', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_removed_thresholded_tgi_mask_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_removed_thresholded_tgi_mask_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 Blue Image(s) from RGB Image with Background Removed via Thresholded TGI Mask', ISOL_name=>'Fourier Transform High Pass Filter 40 Blue Image From RGB Color Denoised Thresholded TGI Vegetative Index Masked Image|ISOL:0000272', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_removed_thresholded_tgi_mask_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_removed_thresholded_tgi_mask_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Fourier Transform HPF20 Green Image(s) from RGB Image with Background Removed via Thresholded TGI Mask', ISOL_name=>'Fourier Transform High Pass Filter 20 Green Image From RGB Color Denoised Thresholded TGI Vegetative Index Masked Image|ISOL:0000273', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_tgi_mask_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_tgi_mask_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Fourier Transform HPF30 Green Image(s) from RGB Image with Background Removed via Thresholded TGI Mask', ISOL_name=>'Fourier Transform High Pass Filter 30 Green Image From RGB Color Denoised Thresholded TGI Vegetative Index Masked Image|ISOL:0000274', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_removed_thresholded_tgi_mask_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_removed_thresholded_tgi_mask_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Fourier Transform HPF40 Green Image(s) from RGB Image with Background Removed via Thresholded TGI Mask', ISOL_name=>'Fourier Transform High Pass Filter 40 Green Image From RGB Color Denoised Thresholded TGI Vegetative Index Masked Image|ISOL:0000275', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_removed_thresholded_tgi_mask_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_removed_thresholded_tgi_mask_channel_3', channels=>[0], corresponding_channel=>2, display_name=>'Fourier Transform HPF20 Red Image(s) from RGB Image with Background Removed via Thresholded TGI Mask', ISOL_name=>'Fourier Transform High Pass Filter 20 Red Image From RGB Color Denoised Thresholded TGI Vegetative Index Masked Image|ISOL:0000276', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_tgi_mask_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_tgi_mask_channel_3', channels=>[0], corresponding_channel=>2, display_name=>'Fourier Transform HPF30 Red Image(s) from RGB Image with Background Removed via Thresholded TGI Mask', ISOL_name=>'Fourier Transform High Pass Filter 30 Red Image From RGB Color Denoised Thresholded TGI Vegetative Index Masked Image|ISOL:0000277', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_removed_thresholded_tgi_mask_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_removed_thresholded_tgi_mask_channel_3', channels=>[0], corresponding_channel=>2, display_name=>'Fourier Transform HPF40 Red Image(s) from RGB Image with Background Removed via Thresholded TGI Mask', ISOL_name=>'Fourier Transform High Pass Filter 40 Red Image From RGB Color Denoised Thresholded TGI Vegetative Index Masked Image|ISOL:0000278', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_removed_vari_mask_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_removed_vari_mask_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 Blue Image(s) from RGB Image with Background Removed via VARI Mask', ISOL_name=>'Fourier Transform High Pass Filter 20 Blue Image From RGB Color Denoised VARI Vegetative Index Masked Image|ISOL:0000279', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_vari_mask_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_vari_mask_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 Blue Image(s) from RGB Image with Background Removed via VARI Mask', ISOL_name=>'Fourier Transform High Pass Filter 30 Blue Image From RGB Color Denoised VARI Vegetative Index Masked Image|ISOL:0000280', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_removed_vari_mask_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_removed_vari_mask_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 Blue Image(s) from RGB Image with Background Removed via VARI Mask', ISOL_name=>'Fourier Transform High Pass Filter 40 Blue Image From RGB Color Denoised VARI Vegetative Index Masked Image|ISOL:0000281', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_removed_vari_mask_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_removed_vari_mask_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Fourier Transform HPF20 Green Image(s) from RGB Image with Background Removed via VARI Mask', ISOL_name=>'Fourier Transform High Pass Filter 20 Green Image From RGB Color Denoised VARI Vegetative Index Masked Image|ISOL:0000282', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_vari_mask_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_vari_mask_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Fourier Transform HPF30 Green Image(s) from RGB Image with Background Removed via VARI Mask', ISOL_name=>'Fourier Transform High Pass Filter 30 Green Image From RGB Color Denoised VARI Vegetative Index Masked Image|ISOL:0000283', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_removed_vari_mask_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_removed_vari_mask_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Fourier Transform HPF40 Green Image(s) from RGB Image with Background Removed via VARI Mask', ISOL_name=>'Fourier Transform High Pass Filter 40 Green Image From RGB Color Denoised VARI Vegetative Index Masked Image|ISOL:0000284', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_removed_vari_mask_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_removed_vari_mask_channel_3', channels=>[0], corresponding_channel=>2, display_name=>'Fourier Transform HPF20 Red Image(s) from RGB Image with Background Removed via VARI Mask', ISOL_name=>'Fourier Transform High Pass Filter 20 Red Image From RGB Color Denoised VARI Vegetative Index Masked Image|ISOL:0000285', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_vari_mask_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_vari_mask_channel_3', channels=>[0], corresponding_channel=>2, display_name=>'Fourier Transform HPF30 Red Image(s) from RGB Image with Background Removed via VARI Mask', ISOL_name=>'Fourier Transform High Pass Filter 30 Red Image From RGB Color Denoised VARI Vegetative Index Masked Image|ISOL:0000286', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_removed_vari_mask_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_removed_vari_mask_channel_3', channels=>[0], corresponding_channel=>2, display_name=>'Fourier Transform HPF40 Red Image(s) from RGB Image with Background Removed via VARI Mask', ISOL_name=>'Fourier Transform High Pass Filter 40 Red Image From RGB Color Denoised VARI Vegetative Index Masked Image|ISOL:0000287', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_removed_thresholded_vari_mask_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_removed_thresholded_vari_mask_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 Blue Image(s) from RGB Image with Background Removed via Thresholded VARI Mask', ISOL_name=>'Fourier Transform High Pass Filter 20 Blue Image From RGB Color Denoised Thresholded VARI Vegetative Index Masked Image|ISOL:0000288', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_vari_mask_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_vari_mask_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 Blue Image(s) from RGB Image with Background Removed via Thresholded VARI Mask', ISOL_name=>'Fourier Transform High Pass Filter 30 Blue Image From RGB Color Denoised Thresholded VARI Vegetative Index Masked Image|ISOL:0000289', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_removed_thresholded_vari_mask_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_removed_thresholded_vari_mask_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 Blue Image(s) from RGB Image with Background Removed via Thresholded VARI Mask', ISOL_name=>'Fourier Transform High Pass Filter 40 Blue Image From RGB Color Denoised Thresholded VARI Vegetative Index Masked Image|ISOL:0000290', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_removed_thresholded_vari_mask_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_removed_thresholded_vari_mask_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Fourier Transform HPF20 Green Image(s) from RGB Image with Background Removed via Thresholded VARI Mask', ISOL_name=>'Fourier Transform High Pass Filter 20 Green Image From RGB Color Denoised Thresholded VARI Vegetative Index Masked Image|ISOL:0000291', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_vari_mask_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_vari_mask_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Fourier Transform HPF30 Green Image(s) from RGB Image with Background Removed via Thresholded VARI Mask', ISOL_name=>'Fourier Transform High Pass Filter 30 Green Image From RGB Color Denoised Thresholded VARI Vegetative Index Masked Image|ISOL:0000292', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_removed_thresholded_vari_mask_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_removed_thresholded_vari_mask_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Fourier Transform HPF40 Green Image(s) from RGB Image with Background Removed via Thresholded VARI Mask', ISOL_name=>'Fourier Transform High Pass Filter 40 Green Image From RGB Color Denoised Thresholded VARI Vegetative Index Masked Image|ISOL:0000293', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_removed_thresholded_vari_mask_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_removed_thresholded_vari_mask_channel_3', channels=>[0], corresponding_channel=>2, display_name=>'Fourier Transform HPF20 Red Image(s) from RGB Image with Background Removed via Thresholded VARI Mask', ISOL_name=>'Fourier Transform High Pass Filter 20 Red Image From RGB Color Denoised Thresholded VARI Vegetative Index Masked Image|ISOL:0000294', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_vari_mask_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_removed_thresholded_vari_mask_channel_3', channels=>[0], corresponding_channel=>2, display_name=>'Fourier Transform HPF30 Red Image(s) from RGB Image with Background Removed via Thresholded VARI Mask', ISOL_name=>'Fourier Transform High Pass Filter 30 Red Image From RGB Color Denoised Thresholded VARI Vegetative Index Masked Image|ISOL:0000295', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_removed_thresholded_vari_mask_channel_3', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_removed_thresholded_vari_mask_channel_3', channels=>[0], corresponding_channel=>2, display_name=>'Fourier Transform HPF40 Red Image(s) from RGB Image with Background Removed via Thresholded VARI Mask', ISOL_name=>'Fourier Transform High Pass Filter 40 Red Image From RGB Color Denoised Thresholded VARI Vegetative Index Masked Image|ISOL:0000296', drone_run_project_types=>[$project_type_lookup{rgb_color_image}, $project_type_lookup{bgr}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_nrn_denoised_background_removed_ndvi_mask_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_nrn_denoised_background_removed_ndvi_mask_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 NIR Image(s) from NRN Image with Background Removed via NDVI Mask', ISOL_name=>'Fourier Transform High Pass Filter 20 NIR Image From 3 Channel Merged NRN Denoised NDVI Vegetative Index Masked Image|ISOL:0000297', drone_run_project_types=>[$project_type_lookup{nrn}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_nrn_denoised_background_removed_ndvi_mask_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_nrn_denoised_background_removed_ndvi_mask_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 NIR Image(s) from NRN Image with Background Removed via NDVI Mask', ISOL_name=>'Fourier Transform High Pass Filter 30 NIR Image From 3 Channel Merged NRN Denoised NDVI Vegetative Index Masked Image|ISOL:0000298', drone_run_project_types=>[$project_type_lookup{nrn}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_nrn_denoised_background_removed_ndvi_mask_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_nrn_denoised_background_removed_ndvi_mask_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 NIR Image(s) from NRN Image with Background Removed via NDVI Mask', ISOL_name=>'Fourier Transform High Pass Filter 40 NIR Image From 3 Channel Merged NRN Denoised NDVI Vegetative Index Masked Image|ISOL:0000299', drone_run_project_types=>[$project_type_lookup{nrn}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_nrn_denoised_background_removed_ndvi_mask_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_nrn_denoised_background_removed_ndvi_mask_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Fourier Transform HPF20 Red Image(s) from NRN Image with Background Removed via NDVI Mask', ISOL_name=>'Fourier Transform High Pass Filter 20 Red Image From 3 Channel Merged NRN Denoised NDVI Vegetative Index Masked Image|ISOL:0000300', drone_run_project_types=>[$project_type_lookup{nrn}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_nrn_denoised_background_removed_ndvi_mask_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_nrn_denoised_background_removed_ndvi_mask_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Fourier Transform HPF30 Red Image(s) from NRN Image with Background Removed via NDVI Mask', ISOL_name=>'Fourier Transform High Pass Filter 30 Red Image From 3 Channel Merged NRN Denoised NDVI Vegetative Index Masked Image|ISOL:0000301', drone_run_project_types=>[$project_type_lookup{nrn}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_nrn_denoised_background_removed_ndvi_mask_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_nrn_denoised_background_removed_ndvi_mask_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Fourier Transform HPF40 Red Image(s) from NRN Image with Background Removed via NDVI Mask', ISOL_name=>'Fourier Transform High Pass Filter 40 Red Image From 3 Channel Merged NRN Denoised NDVI Vegetative Index Masked Image|ISOL:0000302', drone_run_project_types=>[$project_type_lookup{nrn}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_nrn_denoised_background_removed_thresholded_ndvi_mask_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_nrn_denoised_background_removed_thresholded_ndvi_mask_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 NIR Image(s) from NRN Image with Background Removed via Thresholded NDVI Mask', ISOL_name=>'Fourier Transform High Pass Filter 20 NIR Image From 3 Channel Merged NRN Denoised Thresholded NDVI Vegetative Index Masked Image|ISOL:0000303', drone_run_project_types=>[$project_type_lookup{nrn}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_nrn_denoised_background_removed_thresholded_ndvi_mask_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_nrn_denoised_background_removed_thresholded_ndvi_mask_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 NIR Image(s) from NRN Image with Background Removed via Thresholded NDVI Mask', ISOL_name=>'Fourier Transform High Pass Filter 30 NIR Image From 3 Channel Merged NRN Denoised Thresholded NDVI Vegetative Index Masked Image|ISOL:0000304', drone_run_project_types=>[$project_type_lookup{nrn}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_nrn_denoised_background_removed_thresholded_ndvi_mask_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_nrn_denoised_background_removed_thresholded_ndvi_mask_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 NIR Image(s) from NRN Image with Background Removed via Thresholded NDVI Mask', ISOL_name=>'Fourier Transform High Pass Filter 40 NIR Image From 3 Channel Merged NRN Denoised Thresholded NDVI Vegetative Index Masked Image|ISOL:0000305', drone_run_project_types=>[$project_type_lookup{nrn}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_nrn_denoised_background_removed_thresholded_ndvi_mask_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_nrn_denoised_background_removed_thresholded_ndvi_mask_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Fourier Transform HPF20 Red Image(s) from NRN Image with Background Removed via Thresholded NDVI Mask', ISOL_name=>'Fourier Transform High Pass Filter 20 Red Image From 3 Channel Merged NRN Denoised Thresholded NDVI Vegetative Index Masked Image|ISOL:0000306', drone_run_project_types=>[$project_type_lookup{nrn}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_nrn_denoised_background_removed_thresholded_ndvi_mask_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_nrn_denoised_background_removed_thresholded_ndvi_mask_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Fourier Transform HPF30 Red Image(s) from NRN Image with Background Removed via Thresholded NDVI Mask', ISOL_name=>'Fourier Transform High Pass Filter 30 Red Image From 3 Channel Merged NRN Denoised Thresholded NDVI Vegetative Index Masked Image|ISOL:0000307', drone_run_project_types=>[$project_type_lookup{nrn}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_nrn_denoised_background_removed_thresholded_ndvi_mask_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_nrn_denoised_background_removed_thresholded_ndvi_mask_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Fourier Transform HPF40 Red Image(s) from NRN Image with Background Removed via Thresholded NDVI Mask', ISOL_name=>'Fourier Transform High Pass Filter 40 Red Image From 3 Channel Merged NRN Denoised Thresholded NDVI Vegetative Index Masked Image|ISOL:0000308', drone_run_project_types=>[$project_type_lookup{nrn}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_nren_denoised_background_removed_ndre_mask_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_nren_denoised_background_removed_ndre_mask_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 NIR Image(s) from NReN Image with Background Removed via NDRE Mask', ISOL_name=>'Fourier Transform High Pass Filter 20 NIR Image From 3 Channel Merged NReN Denoised NDRE Vegetative Index Masked Image|ISOL:0000309', drone_run_project_types=>[$project_type_lookup{nren}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_nren_denoised_background_removed_ndre_mask_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_nren_denoised_background_removed_ndre_mask_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 NIR Image(s) from NReN Image with Background Removed via NDRE Mask', ISOL_name=>'Fourier Transform High Pass Filter 30 NIR Image From 3 Channel Merged NReN Denoised NDRE Vegetative Index Masked Image|ISOL:0000310', drone_run_project_types=>[$project_type_lookup{nren}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_nren_denoised_background_removed_ndre_mask_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_nren_denoised_background_removed_ndre_mask_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 NIR Image(s) from NReN Image with Background Removed via NDRE Mask', ISOL_name=>'Fourier Transform High Pass Filter 40 NIR Image From 3 Channel Merged NReN Denoised NDRE Vegetative Index Masked Image|ISOL:0000311', drone_run_project_types=>[$project_type_lookup{nren}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_nren_denoised_background_removed_ndre_mask_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_nren_denoised_background_removed_ndre_mask_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Fourier Transform HPF20 Red Edge Image(s) from NReN Image with Background Removed via NDRE Mask', ISOL_name=>'Fourier Transform High Pass Filter 20 Red Edge Image From 3 Channel Merged NReN Denoised NDRE Vegetative Index Masked Image|ISOL:0000312', drone_run_project_types=>[$project_type_lookup{nren}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_nren_denoised_background_removed_ndre_mask_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_nren_denoised_background_removed_ndre_mask_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Fourier Transform HPF30 Red Edge Image(s) from NReN Image with Background Removed via NDRE Mask', ISOL_name=>'Fourier Transform High Pass Filter 30 Red Edge Image From 3 Channel Merged NReN Denoised NDRE Vegetative Index Masked Image|ISOL:0000313', drone_run_project_types=>[$project_type_lookup{nren}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_nren_denoised_background_removed_ndre_mask_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_nren_denoised_background_removed_ndre_mask_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Fourier Transform HPF40 Red Edge Image(s) from NReN Image with Background Removed via NDRE Mask', ISOL_name=>'Fourier Transform High Pass Filter 40 Red Edge Image From 3 Channel Merged NReN Denoised NDRE Vegetative Index Masked Image|ISOL:0000314', drone_run_project_types=>[$project_type_lookup{nren}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_nren_denoised_background_removed_thresholded_ndre_mask_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_nren_denoised_background_removed_thresholded_ndre_mask_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF20 NIR Image(s) from NReN Image with Background Removed via Thresholded NDRE Mask', ISOL_name=>'Fourier Transform High Pass Filter 20 NIR Image From 3 Channel Merged NReN Denoised Thresholded NDRE Vegetative Index Masked Image|ISOL:0000315', drone_run_project_types=>[$project_type_lookup{nren}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_nren_denoised_background_removed_thresholded_ndre_mask_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_nren_denoised_background_removed_thresholded_ndre_mask_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF30 NIR Image(s) from NReN Image with Background Removed via Thresholded NDRE Mask', ISOL_name=>'Fourier Transform High Pass Filter 30 NIR Image From 3 Channel Merged NReN Denoised Thresholded NDRE Vegetative Index Masked Image|ISOL:0000316', drone_run_project_types=>[$project_type_lookup{nren}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_nren_denoised_background_removed_thresholded_ndre_mask_channel_1', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_nren_denoised_background_removed_thresholded_ndre_mask_channel_1', channels=>[0], corresponding_channel=>0, display_name=>'Fourier Transform HPF40 NIR Image(s) from NReN Image with Background Removed via Thresholded NDRE Mask', ISOL_name=>'Fourier Transform High Pass Filter 40 NIR Image From 3 Channel Merged NReN Denoised Thresholded NDRE Vegetative Index Masked Image|ISOL:0000317', drone_run_project_types=>[$project_type_lookup{nren}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf20_nren_denoised_background_removed_thresholded_ndre_mask_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf20_nren_denoised_background_removed_thresholded_ndre_mask_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Fourier Transform HPF20 Red Edge Image(s) from NReN Image with Background Removed via Thresholded NDRE Mask', ISOL_name=>'Fourier Transform High Pass Filter 20 Red Edge Image From 3 Channel Merged NReN Denoised Thresholded NDRE Vegetative Index Masked Image|ISOL:0000318', drone_run_project_types=>[$project_type_lookup{nren}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_nren_denoised_background_removed_thresholded_ndre_mask_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf30_nren_denoised_background_removed_thresholded_ndre_mask_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Fourier Transform HPF30 Red Edge Image(s) from NReN Image with Background Removed via Thresholded NDRE Mask', ISOL_name=>'Fourier Transform High Pass Filter 30 Red Edge Image From 3 Channel Merged NReN Denoised Thresholded NDRE Vegetative Index Masked Image|ISOL:0000319', drone_run_project_types=>[$project_type_lookup{nren}], standard_process=>['extended']
        },
        SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf40_nren_denoised_background_removed_thresholded_ndre_mask_channel_2', 'project_md_image')->cvterm_id() => {
            name=>'observation_unit_polygon_fourier_transform_hpf40_nren_denoised_background_removed_thresholded_ndre_mask_channel_2', channels=>[0], corresponding_channel=>1, display_name=>'Fourier Transform HPF40 Red Edge Image(s) from NReN Image with Background Removed via Thresholded NDRE Mask', ISOL_name=>'Fourier Transform High Pass Filter 40 Red Edge Image From 3 Channel Merged NReN Denoised Thresholded NDRE Vegetative Index Masked Image|ISOL:0000320', drone_run_project_types=>[$project_type_lookup{nren}], standard_process=>['extended']
        }
    };
}

sub get_base_imagery_observation_unit_plot_polygon_term_map {
    return {
        'Blue (450-520nm)' => {
            imagery_types => {
                threshold_background => ['threshold_background_removed_stitched_drone_imagery_blue'],
                ft_hpf => {
                    20 => ['calculate_fourier_transform_hpf20_blue_denoised_stitched_image_channel_1'],
                    '20_threshold_background' => ['calculate_fourier_transform_hpf20_blue_threshold_background_removed_stitched_drone_imagery_channel_1'],
                    30 => ['calculate_fourier_transform_hpf30_blue_denoised_stitched_image_channel_1'],
                    '30_threshold_background' => ['calculate_fourier_transform_hpf30_blue_threshold_background_removed_stitched_drone_imagery_channel_1'],
                    40 => ['calculate_fourier_transform_hpf40_blue_denoised_stitched_image_channel_1'],
                    '40_threshold_background' => ['calculate_fourier_transform_hpf40_blue_threshold_background_removed_stitched_drone_imagery_channel_1']
                }
            },
            observation_unit_plot_polygon_types => {
                base => ['observation_unit_polygon_blue_imagery'],
                threshold_background => ['observation_unit_polygon_blue_background_removed_threshold_imagery'],
                ft_hpf => {
                    20 => ['observation_unit_polygon_fourier_transform_hpf20_blue_denoised_stitched_image_channel_1'],
                    '20_threshold_background' => ['observation_unit_polygon_fourier_transform_hpf20_blue_denoised_background_threshold_removed_image_channel_1'],
                    30 => ['observation_unit_polygon_fourier_transform_hpf30_blue_denoised_stitched_image_channel_1'],
                    '30_threshold_background' => ['observation_unit_polygon_fourier_transform_hpf30_blue_denoised_background_threshold_removed_image_channel_1'],
                    40 => ['observation_unit_polygon_fourier_transform_hpf40_blue_denoised_stitched_image_channel_1'],
                    '40_threshold_background' => ['observation_unit_polygon_fourier_transform_hpf40_blue_denoised_background_threshold_removed_image_channel_1']
                }
            }
        },
        'Green (515-600nm)' => {
            imagery_types => {
                threshold_background => ['threshold_background_removed_stitched_drone_imagery_green'],
                ft_hpf => {
                    20 => ['calculate_fourier_transform_hpf20_green_denoised_stitched_image_channel_1'],
                    '20_threshold_background' => ['calculate_fourier_transform_hpf20_green_threshold_background_removed_stitched_drone_imagery_channel_1'],
                    30 => ['calculate_fourier_transform_hpf30_green_denoised_stitched_image_channel_1'],
                    '30_threshold_background' => ['calculate_fourier_transform_hpf30_green_threshold_background_removed_stitched_drone_imagery_channel_1'],
                    40 => ['calculate_fourier_transform_hpf40_green_denoised_stitched_image_channel_1'],
                    '40_threshold_background' => ['calculate_fourier_transform_hpf40_green_threshold_background_removed_stitched_drone_imagery_channel_1']
                }
            },
            observation_unit_plot_polygon_types => {
                base => ['observation_unit_polygon_green_imagery'],
                threshold_background => ['observation_unit_polygon_green_background_removed_threshold_imagery'],
                ft_hpf => {
                    20 => ['observation_unit_polygon_fourier_transform_hpf20_green_denoised_stitched_image_channel_1'],
                    '20_threshold_background' => ['observation_unit_polygon_fourier_transform_hpf20_green_denoised_background_threshold_removed_image_channel_1'],
                    30 => ['observation_unit_polygon_fourier_transform_hpf30_green_denoised_stitched_image_channel_1'],
                    '30_threshold_background' => ['observation_unit_polygon_fourier_transform_hpf30_green_denoised_background_threshold_removed_image_channel_1'],
                    40 => ['observation_unit_polygon_fourier_transform_hpf40_green_denoised_stitched_image_channel_1'],
                    '40_threshold_background' => ['observation_unit_polygon_fourier_transform_hpf40_green_denoised_background_threshold_removed_image_channel_1']
                }
            }
        },
        'Red (600-690nm)' => {
            imagery_types => {
                threshold_background => ['threshold_background_removed_stitched_drone_imagery_red'],
                ft_hpf => {
                    20 => ['calculate_fourier_transform_hpf20_red_denoised_stitched_image_channel_1'],
                    '20_threshold_background' => ['calculate_fourier_transform_hpf20_red_threshold_background_removed_stitched_drone_imagery_channel_1'],
                    30 => ['calculate_fourier_transform_hpf30_red_denoised_stitched_image_channel_1'],
                    '30_threshold_background' => ['calculate_fourier_transform_hpf30_red_threshold_background_removed_stitched_drone_imagery_channel_1'],
                    40 => ['calculate_fourier_transform_hpf40_red_denoised_stitched_image_channel_1'],
                    '40_threshold_background' => ['calculate_fourier_transform_hpf40_red_threshold_background_removed_stitched_drone_imagery_channel_1']
                }
            },
            observation_unit_plot_polygon_types => {
                base => ['observation_unit_polygon_red_imagery'],
                threshold_background => ['observation_unit_polygon_red_background_removed_threshold_imagery'],
                ft_hpf => {
                    20 => ['observation_unit_polygon_fourier_transform_hpf20_red_denoised_stitched_image_channel_1'],
                    '20_threshold_background' => ['observation_unit_polygon_fourier_transform_hpf20_red_denoised_background_threshold_removed_image_channel_1'],
                    30 => ['observation_unit_polygon_fourier_transform_hpf30_red_denoised_stitched_image_channel_1'],
                    '30_threshold_background' => ['observation_unit_polygon_fourier_transform_hpf30_red_denoised_background_threshold_removed_image_channel_1'],
                    40 => ['observation_unit_polygon_fourier_transform_hpf40_red_denoised_stitched_image_channel_1'],
                    '40_threshold_background' => ['observation_unit_polygon_fourier_transform_hpf40_red_denoised_background_threshold_removed_image_channel_1']
                }
            }
        },
        'Red Edge (690-750nm)' => {
            imagery_types => {
                threshold_background => ['threshold_background_removed_stitched_drone_imagery_red_edge'],
                ft_hpf => {
                    20 => ['calculate_fourier_transform_hpf20_rededge_denoised_stitched_image_channel_1'],
                    '20_threshold_background' => ['calculate_fourier_transform_hpf20_rededge_threshold_background_removed_stitched_drone_imagery_channel_1'],
                    30 => ['calculate_fourier_transform_hpf30_rededge_denoised_stitched_image_channel_1'],
                    '30_threshold_background' => ['calculate_fourier_transform_hpf30_rededge_threshold_background_removed_stitched_drone_imagery_channel_1'],
                    40 => ['calculate_fourier_transform_hpf40_rededge_denoised_stitched_image_channel_1'],
                    '40_threshold_background' => ['calculate_fourier_transform_hpf40_rededge_threshold_background_removed_stitched_drone_imagery_channel_1']
                }
            },
            observation_unit_plot_polygon_types => {
                base => ['observation_unit_polygon_red_edge_imagery'],
                threshold_background => ['observation_unit_polygon_red_edge_background_removed_threshold_imagery'],
                ft_hpf => {
                    20 => ['observation_unit_polygon_fourier_transform_hpf20_rededge_denoised_stitched_image_channel_1'],
                    '20_threshold_background' => ['observation_unit_polygon_fourier_transform_hpf20_rededge_denoised_background_threshold_removed_image_channel_1'],
                    30 => ['observation_unit_polygon_fourier_transform_hpf30_rededge_denoised_stitched_image_channel_1'],
                    '30_threshold_background' => ['observation_unit_polygon_fourier_transform_hpf30_rededge_denoised_background_threshold_removed_image_channel_1'],
                    40 => ['observation_unit_polygon_fourier_transform_hpf40_rededge_denoised_stitched_image_channel_1'],
                    '40_threshold_background' => ['observation_unit_polygon_fourier_transform_hpf40_rededge_denoised_background_threshold_removed_image_channel_1']
                }
            }
        },
        'NIR (780-3000nm)' => {
            imagery_types => {
                threshold_background => ['threshold_background_removed_stitched_drone_imagery_nir'],
                ft_hpf => {
                    20 => ['calculate_fourier_transform_hpf20_nir_denoised_stitched_image_channel_1'],
                    '20_threshold_background' => ['calculate_fourier_transform_hpf20_nir_threshold_background_removed_stitched_drone_imagery_channel_1'],
                    30 => ['calculate_fourier_transform_hpf30_nir_denoised_stitched_image_channel_1'],
                    '30_threshold_background' => ['calculate_fourier_transform_hpf30_nir_threshold_background_removed_stitched_drone_imagery_channel_1'],
                    40 => ['calculate_fourier_transform_hpf40_nir_denoised_stitched_image_channel_1'],
                    '40_threshold_background' => ['calculate_fourier_transform_hpf40_nir_threshold_background_removed_stitched_drone_imagery_channel_1']
                }
            },
            observation_unit_plot_polygon_types => {
                base => ['observation_unit_polygon_nir_imagery'],
                threshold_background => ['observation_unit_polygon_nir_background_removed_threshold_imagery'],
                ft_hpf => {
                    20 => ['observation_unit_polygon_fourier_transform_hpf20_nir_denoised_stitched_image_channel_1'],
                    '20_threshold_background' => ['observation_unit_polygon_fourier_transform_hpf20_nir_denoised_background_threshold_removed_image_channel_1'],
                    30 => ['observation_unit_polygon_fourier_transform_hpf30_nir_denoised_stitched_image_channel_1'],
                    '30_threshold_background' => ['observation_unit_polygon_fourier_transform_hpf30_nir_denoised_background_threshold_removed_image_channel_1'],
                    40 => ['observation_unit_polygon_fourier_transform_hpf40_nir_denoised_stitched_image_channel_1'],
                    '40_threshold_background' => ['observation_unit_polygon_fourier_transform_hpf40_nir_denoised_background_threshold_removed_image_channel_1']
                }
            }
        },
        'MIR (3000-50000nm)' => {
            imagery_types => {
                threshold_background => ['threshold_background_removed_stitched_drone_imagery_mir'],
                ft_hpf => {
                    20 => ['calculate_fourier_transform_hpf20_mir_denoised_stitched_image_channel_1'],
                    '20_threshold_background' => ['calculate_fourier_transform_hpf20_mir_threshold_background_removed_stitched_drone_imagery_channel_1'],
                    30 => ['calculate_fourier_transform_hpf30_mir_denoised_stitched_image_channel_1'],
                    '30_threshold_background' => ['calculate_fourier_transform_hpf30_mir_threshold_background_removed_stitched_drone_imagery_channel_1'],
                    40 => ['calculate_fourier_transform_hpf40_mir_denoised_stitched_image_channel_1'],
                    '40_threshold_background' => ['calculate_fourier_transform_hpf40_mir_threshold_background_removed_stitched_drone_imagery_channel_1']
                }
            },
            observation_unit_plot_polygon_types => {
                base => ['observation_unit_polygon_mir_imagery'],
                threshold_background => ['observation_unit_polygon_mir_background_removed_threshold_imagery'],
                ft_hpf => {
                    20 => ['observation_unit_polygon_fourier_transform_hpf20_mir_denoised_stitched_image_channel_1'],
                    '20_threshold_background' => ['observation_unit_polygon_fourier_transform_hpf20_mir_denoised_background_threshold_removed_image_channel_1'],
                    30 => ['observation_unit_polygon_fourier_transform_hpf30_mir_denoised_stitched_image_channel_1'],
                    '30_threshold_background' => ['observation_unit_polygon_fourier_transform_hpf30_mir_denoised_background_threshold_removed_image_channel_1'],
                    40 => ['observation_unit_polygon_fourier_transform_hpf40_mir_denoised_stitched_image_channel_1'],
                    '40_threshold_background' => ['observation_unit_polygon_fourier_transform_hpf40_mir_denoised_background_threshold_removed_image_channel_1']
                }
            }
        },
        'FIR (50000-1000000nm)' => {
            imagery_types => {
                threshold_background => ['threshold_background_removed_stitched_drone_imagery_fir'],
                ft_hpf => {
                    20 => ['calculate_fourier_transform_hpf20_fir_denoised_stitched_image_channel_1'],
                    '20_threshold_background' => ['calculate_fourier_transform_hpf20_fir_threshold_background_removed_stitched_drone_imagery_channel_1'],
                    30 => ['calculate_fourier_transform_hpf30_fir_denoised_stitched_image_channel_1'],
                    '30_threshold_background' => ['calculate_fourier_transform_hpf30_fir_threshold_background_removed_stitched_drone_imagery_channel_1'],
                    40 => ['calculate_fourier_transform_hpf40_fir_denoised_stitched_image_channel_1'],
                    '40_threshold_background' => ['calculate_fourier_transform_hpf40_fir_threshold_background_removed_stitched_drone_imagery_channel_1']
                }
            },
            observation_unit_plot_polygon_types => {
                base => ['observation_unit_polygon_fir_imagery'],
                threshold_background => ['observation_unit_polygon_fir_background_removed_threshold_imagery'],
                ft_hpf => {
                    20 => ['observation_unit_polygon_fourier_transform_hpf20_fir_denoised_stitched_image_channel_1'],
                    '20_threshold_background' => ['observation_unit_polygon_fourier_transform_hpf20_fir_denoised_background_threshold_removed_image_channel_1'],
                    30 => ['observation_unit_polygon_fourier_transform_hpf30_fir_denoised_stitched_image_channel_1'],
                    '30_threshold_background' => ['observation_unit_polygon_fourier_transform_hpf30_fir_denoised_background_threshold_removed_image_channel_1'],
                    40 => ['observation_unit_polygon_fourier_transform_hpf40_fir_denoised_stitched_image_channel_1'],
                    '40_threshold_background' => ['observation_unit_polygon_fourier_transform_hpf40_fir_denoised_background_threshold_removed_image_channel_1']
                }
            }
        },
        'Thermal IR (9000-14000nm)' => {
            imagery_types => {
                threshold_background => ['threshold_background_removed_stitched_drone_imagery_tir'],
                ft_hpf => {
                    20 => ['calculate_fourier_transform_hpf20_tir_denoised_stitched_image_channel_1'],
                    '20_threshold_background' => ['calculate_fourier_transform_hpf20_tir_threshold_background_removed_stitched_drone_imagery_channel_1'],
                    30 => ['calculate_fourier_transform_hpf30_tir_denoised_stitched_image_channel_1'],
                    '30_threshold_background' => ['calculate_fourier_transform_hpf30_tir_threshold_background_removed_stitched_drone_imagery_channel_1'],
                    40 => ['calculate_fourier_transform_hpf40_tir_denoised_stitched_image_channel_1'],
                    '40_threshold_background' => ['calculate_fourier_transform_hpf40_tir_threshold_background_removed_stitched_drone_imagery_channel_1']
                }
            },
            observation_unit_plot_polygon_types => {
                base => ['observation_unit_polygon_tir_imagery'],
                threshold_background => ['observation_unit_polygon_tir_background_removed_threshold_imagery'],
                ft_hpf => {
                    20 => ['observation_unit_polygon_fourier_transform_hpf20_tir_denoised_stitched_image_channel_1'],
                    '20_threshold_background' => ['observation_unit_polygon_fourier_transform_hpf20_tir_denoised_background_threshold_removed_image_channel_1'],
                    30 => ['observation_unit_polygon_fourier_transform_hpf30_tir_denoised_stitched_image_channel_1'],
                    '30_threshold_background' => ['observation_unit_polygon_fourier_transform_hpf30_tir_denoised_background_threshold_removed_image_channel_1'],
                    40 => ['observation_unit_polygon_fourier_transform_hpf40_tir_denoised_stitched_image_channel_1'],
                    '40_threshold_background' => ['observation_unit_polygon_fourier_transform_hpf40_tir_denoised_background_threshold_removed_image_channel_1']
                }
            }
        },
        'Raster DSM' => {
            imagery_types => {
                threshold_background => ['threshold_background_removed_stitched_drone_imagery_raster_dsm']
            },
            observation_unit_plot_polygon_types => {
                base => ['observation_unit_polygon_raster_dsm_imagery'],
                threshold_background => ['observation_unit_polygon_raster_dsm_background_removed_threshold_imagery']
            }
        },
        'Black and White Image' => {
            imagery_types => {
                threshold_background => ['threshold_background_removed_stitched_drone_imagery_bw'],
                ft_hpf => {
                    20 => ['calculate_fourier_transform_hpf20_bw_denoised_stitched_image_channel_1'],
                    '20_threshold_background' => ['calculate_fourier_transform_hpf20_bw_threshold_background_removed_stitched_drone_imagery_channel_1'],
                    30 => ['calculate_fourier_transform_hpf30_bw_denoised_stitched_image_channel_1'],
                    '30_threshold_background' => ['calculate_fourier_transform_hpf30_bw_threshold_background_removed_stitched_drone_imagery_channel_1'],
                    40 => ['calculate_fourier_transform_hpf40_bw_denoised_stitched_image_channel_1'],
                    '40_threshold_background' => ['calculate_fourier_transform_hpf40_bw_threshold_background_removed_stitched_drone_imagery_channel_1']
                }
            },
            observation_unit_plot_polygon_types => {
                base => ['observation_unit_polygon_bw_imagery'],
                threshold_background => ['observation_unit_polygon_bw_background_removed_threshold_imagery'],
                ft_hpf => {
                    20 => ['observation_unit_polygon_fourier_transform_hpf20_bw_denoised_stitched_image_channel_1'],
                    '20_threshold_background' => ['observation_unit_polygon_fourier_transform_hpf20_bw_denoised_background_threshold_removed_image_channel_1'],
                    30 => ['observation_unit_polygon_fourier_transform_hpf30_bw_denoised_stitched_image_channel_1'],
                    '30_threshold_background' => ['observation_unit_polygon_fourier_transform_hpf30_bw_denoised_background_threshold_removed_image_channel_1'],
                    40 => ['observation_unit_polygon_fourier_transform_hpf40_bw_denoised_stitched_image_channel_1'],
                    '40_threshold_background' => ['observation_unit_polygon_fourier_transform_hpf40_bw_denoised_background_threshold_removed_image_channel_1']
                }
            }
        },
        'RGB Color Image' => {
            imagery_types => {
                threshold_background => ['threshold_background_removed_stitched_drone_imagery_rgb_channel_1', 'threshold_background_removed_stitched_drone_imagery_rgb_channel_2', 'threshold_background_removed_stitched_drone_imagery_rgb_channel_3'],
                ft_hpf => {
                    20 => ['calculate_fourier_transform_hpf20_bgr_denoised_stitched_image_channel_1', 'calculate_fourier_transform_hpf20_bgr_denoised_stitched_image_channel_2', 'calculate_fourier_transform_hpf20_bgr_denoised_stitched_image_channel_3'],
                    '20_threshold_background' => ['calculate_fourier_transform_hpf20_bgr_threshold_background_removed_stitched_drone_imagery_channel_1', 'calculate_fourier_transform_hpf20_bgr_threshold_background_removed_stitched_drone_imagery_channel_2', 'calculate_fourier_transform_hpf20_bgr_threshold_background_removed_stitched_drone_imagery_channel_3'],
                    30 => ['calculate_fourier_transform_hpf30_bgr_denoised_stitched_image_channel_1', 'calculate_fourier_transform_hpf30_bgr_denoised_stitched_image_channel_2', 'calculate_fourier_transform_hpf30_bgr_denoised_stitched_image_channel_3'],
                    '30_threshold_background' => ['calculate_fourier_transform_hpf30_bgr_threshold_background_removed_stitched_drone_imagery_channel_1', 'calculate_fourier_transform_hpf30_bgr_threshold_background_removed_stitched_drone_imagery_channel_2', 'calculate_fourier_transform_hpf30_bgr_threshold_background_removed_stitched_drone_imagery_channel_3'],
                    40 => ['calculate_fourier_transform_hpf40_bgr_denoised_stitched_image_channel_1', 'calculate_fourier_transform_hpf40_bgr_denoised_stitched_image_channel_2', 'calculate_fourier_transform_hpf40_bgr_denoised_stitched_image_channel_3'],
                    '40_threshold_background' => ['calculate_fourier_transform_hpf40_bgr_threshold_background_removed_stitched_drone_imagery_channel_1', 'calculate_fourier_transform_hpf40_bgr_threshold_background_removed_stitched_drone_imagery_channel_2', 'calculate_fourier_transform_hpf40_bgr_threshold_background_removed_stitched_drone_imagery_channel_3']
                }
            },
            observation_unit_plot_polygon_types => {
                base => ['observation_unit_polygon_rgb_imagery', 'observation_unit_polygon_rgb_imagery_channel_1', 'observation_unit_polygon_rgb_imagery_channel_2', 'observation_unit_polygon_rgb_imagery_channel_3'],
                threshold_background => ['observation_unit_polygon_rgb_background_removed_threshold_imagery_channel_1', 'observation_unit_polygon_rgb_background_removed_threshold_imagery_channel_2', 'observation_unit_polygon_rgb_background_removed_threshold_imagery_channel_3'],
                ft_hpf => {
                    20 => ['observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_stitched_image_channel_1', 'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_stitched_image_channel_2', 'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_stitched_image_channel_3'],
                    '20_threshold_background' => ['observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_threshold_removed_image_channel_1', 'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_threshold_removed_image_channel_2', 'observation_unit_polygon_fourier_transform_hpf20_bgr_denoised_background_threshold_removed_image_channel_3'],
                    30 => ['observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_stitched_image_channel_1', 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_stitched_image_channel_2', 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_stitched_image_channel_3'],
                    '30_threshold_background' => ['observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_threshold_removed_image_channel_1', 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_threshold_removed_image_channel_2', 'observation_unit_polygon_fourier_transform_hpf30_bgr_denoised_background_threshold_removed_image_channel_3'],
                    40 => ['observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_stitched_image_channel_1', 'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_stitched_image_channel_2', 'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_stitched_image_channel_3'],
                    '40_threshold_background' => ['observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_threshold_removed_image_channel_1', 'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_threshold_removed_image_channel_2', 'observation_unit_polygon_fourier_transform_hpf40_bgr_denoised_background_threshold_removed_image_channel_3']
                }
            }
        },
        'Merged 3 Bands BGR' => {
            imagery_types => {
                threshold_background => undef
            },
            observation_unit_plot_polygon_types => {
                base => ['observation_unit_polygon_rgb_imagery'],
                threshold_background => undef
            }
        },
        'Merged 3 Bands NRN' => {
            imagery_types => {
                threshold_background => undef
            },
            observation_unit_plot_polygon_types => {
                base => ['observation_unit_polygon_nrn_imagery'],
                threshold_background => undef
            }
        },
        'Merged 3 Bands NReN' => {
            imagery_types => {
                threshold_background => undef
            },
            observation_unit_plot_polygon_types => {
                base => ['observation_unit_polygon_nren_imagery'],
                threshold_background => undef
            }
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
        SGN::Model::Cvterm->get_cvterm_row($schema, 'threshold_background_removed_stitched_drone_imagery_raster_dsm', 'project_md_image')->cvterm_id() => {
            name=>'threshold_background_removed_stitched_drone_imagery_raster_dsm', channels=>[0], corresponding_channel=>0
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

sub get_imagery_attribute_map {
    return {
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
            key => 'drone_run_band_background_removed_threshold',
            observation_unit_plot_polygon_type => 'observation_unit_polygon_blue_background_removed_threshold_imagery'
        },
        'threshold_background_removed_stitched_drone_imagery_green' => {
            name => 'threshold',
            key => 'drone_run_band_background_removed_threshold',
            observation_unit_plot_polygon_type => 'observation_unit_polygon_green_background_removed_threshold_imagery'
        },
        'threshold_background_removed_stitched_drone_imagery_red' => {
            name => 'threshold',
            key => 'drone_run_band_background_removed_threshold',
            observation_unit_plot_polygon_type => 'observation_unit_polygon_red_background_removed_threshold_imagery'
        },
        'threshold_background_removed_stitched_drone_imagery_red_edge' => {
            name => 'threshold',
            key => 'drone_run_band_background_removed_threshold',
            observation_unit_plot_polygon_type => 'observation_unit_polygon_red_edge_background_removed_threshold_imagery'
        },
        'threshold_background_removed_stitched_drone_imagery_nir' => {
            name => 'threshold',
            key => 'drone_run_band_background_removed_threshold',
            observation_unit_plot_polygon_type => 'observation_unit_polygon_nir_background_removed_threshold_imagery'
        },
        'threshold_background_removed_stitched_drone_imagery_mir' => {
            name => 'threshold',
            key => 'drone_run_band_background_removed_threshold',
            observation_unit_plot_polygon_type => 'observation_unit_polygon_mir_background_removed_threshold_imagery'
        },
        'threshold_background_removed_stitched_drone_imagery_fir' => {
            name => 'threshold',
            key => 'drone_run_band_background_removed_threshold',
            observation_unit_plot_polygon_type => 'observation_unit_polygon_fir_background_removed_threshold_imagery'
        },
        'threshold_background_removed_stitched_drone_imagery_tir' => {
            name => 'threshold',
            key => 'drone_run_band_background_removed_threshold',
            observation_unit_plot_polygon_type => 'observation_unit_polygon_tir_background_removed_threshold_imagery'
        },
        'threshold_background_removed_stitched_drone_imagery_raster_dsm' => {
            name => 'threshold',
            key => 'drone_run_band_background_removed_threshold',
            observation_unit_plot_polygon_type => 'observation_unit_polygon_raster_dsm_background_removed_threshold_imagery'
        },
        'threshold_background_removed_stitched_drone_imagery_bw' => {
            name => 'threshold',
            key => 'drone_run_band_background_removed_threshold',
            observation_unit_plot_polygon_type => 'observation_unit_polygon_bw_background_removed_threshold_imagery'
        },
        'threshold_background_removed_stitched_drone_imagery_rgb_channel_1' => {
            name => 'threshold',
            key => 'drone_run_band_background_removed_threshold',
            observation_unit_plot_polygon_type => 'observation_unit_polygon_rgb_background_removed_threshold_imagery_channel_1'
        },
        'threshold_background_removed_stitched_drone_imagery_rgb_channel_2' => {
            name => 'threshold',
            key => 'drone_run_band_background_removed_threshold',
            observation_unit_plot_polygon_type => 'observation_unit_polygon_rgb_background_removed_threshold_imagery_channel_2'
        },
        'threshold_background_removed_stitched_drone_imagery_rgb_channel_3' => {
            name => 'threshold',
            key => 'drone_run_band_background_removed_threshold',
            observation_unit_plot_polygon_type => 'observation_unit_polygon_rgb_background_removed_threshold_imagery_channel_3'
        },
        'threshold_background_removed_tgi_stitched_drone_imagery' => {
            name => 'threshold',
            key => 'drone_run_band_background_removed_tgi_threshold',
            observation_unit_plot_polygon_type => 'observation_unit_polygon_background_removed_tgi_imagery'
        },
        'threshold_background_removed_vari_stitched_drone_imagery' => {
            name => 'threshold',
            key => 'drone_run_band_background_removed_vari_threshold',
            observation_unit_plot_polygon_type => 'observation_unit_polygon_background_removed_vari_imagery'
        },
        'threshold_background_removed_ndvi_stitched_drone_imagery' => {
            name => 'threshold',
            key => 'drone_run_band_background_removed_ndvi_threshold',
            observation_unit_plot_polygon_type => 'observation_unit_polygon_background_removed_ndvi_imagery'
        },
        'threshold_background_removed_ndre_stitched_drone_imagery' => {
            name => 'threshold',
            key => 'drone_run_band_background_removed_ndre_threshold',
            observation_unit_plot_polygon_type => 'observation_unit_polygon_background_removed_ndre_imagery'
        }
    };
}

1;
