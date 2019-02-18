#!/usr/bin/env perl


=head1 NAME

 AddPhenomeProjectMdImageTable

=head1 SYNOPSIS

mx-run AddPhenomeProjectMdImageTable [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION
This patch adds a linking table called project_md_image to the phenome schema, which links project to metadata.md_image
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR


=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddPhenomeProjectMdImageTable;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;
use SGN::Model::Cvterm;
use JSON;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch adds a linking table called project_md_image to the phenome schema, which links project to metadata.md_image

has '+prereq' => (
	default => sub {
        [],
    },

  );

sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";
    my $schema = Bio::Chado::Schema->connect( sub { $self->dbh->clone } );

    my $terms = {
        'project_md_image' => [
            'raw_drone_imagery',
            'stitched_drone_imagery',
            'denoised_stitched_drone_imagery',
            'cropped_stitched_drone_imagery',
            'rotated_stitched_drone_imagery',
            'rotated_stitched_temporary_drone_imagery',
            'fourier_transform_stitched_drone_imagery',
            'contours_stitched_drone_imagery',
            'observation_unit_polygon_imagery',
            'observation_unit_polygon_tgi_imagery',
            'observation_unit_polygon_vari_imagery',
            'observation_unit_polygon_ndvi_imagery',
            'observation_unit_polygon_background_removed_tgi_imagery',
            'observation_unit_polygon_background_removed_vari_imagery',
            'observation_unit_polygon_background_removed_ndvi_imagery',
            'observation_unit_polygon_original_background_removed_tgi_mask_imagery',
            'observation_unit_polygon_original_background_removed_vari_mask_imagery',
            'observation_unit_polygon_original_background_removed_ndvi_mask_imagery',
            'observation_unit_polygon_original_background_removed_thresholded_tgi_mask_imagery',
            'observation_unit_polygon_original_background_removed_thresholded_vari_mask_imagery',
            'observation_unit_polygon_original_background_removed_thresholded_ndvi_mask_imagery',
            'threshold_background_removed_stitched_drone_imagery',
            'threshold_background_removed_temporary_stitched_drone_imagery',
            'threshold_background_removed_tgi_stitched_drone_imagery',
            'threshold_background_removed_vari_stitched_drone_imagery',
            'threshold_background_removed_ndvi_stitched_drone_imagery',
            'denoised_background_removed_tgi_mask_original',
            'denoised_background_removed_vari_mask_original',
            'denoised_background_removed_ndvi_mask_original',
            'denoised_background_removed_thresholded_tgi_mask_original',
            'denoised_background_removed_thresholded_vari_mask_original',
            'denoised_background_removed_thresholded_ndvi_mask_original',
            'calculate_phenotypes_sift_drone_imagery',
            'calculate_phenotypes_sift_drone_imagery_tgi',
            'calculate_phenotypes_sift_drone_imagery_vari',
            'calculate_phenotypes_sift_drone_imagery_ndvi',
            'calculate_phenotypes_orb_drone_imagery',
            'calculate_phenotypes_orb_drone_imagery_tgi',
            'calculate_phenotypes_orb_drone_imagery_vari',
            'calculate_phenotypes_orb_drone_imagery_ndvi',
            'calculate_phenotypes_surf_drone_imagery',
            'calculate_phenotypes_surf_drone_imagery_tgi',
            'calculate_phenotypes_surf_drone_imagery_vari',
            'calculate_phenotypes_surf_drone_imagery_ndvi',
            'calculate_phenotypes_zonal_stats_drone_imagery',
            'calculate_phenotypes_zonal_stats_drone_imagery_tgi',
            'calculate_phenotypes_zonal_stats_drone_imagery_vari',
            'calculate_phenotypes_zonal_stats_drone_imagery_ndvi',
            'calculate_tgi_drone_imagery',
            'calculate_tgi_temporary_drone_imagery',
            'calculate_vari_drone_imagery',
            'calculate_vari_temporary_drone_imagery',
            'calculate_ndvi_drone_imagery',
            'calculate_ndvi_temporary_drone_imagery',
        ],
        'project_property' => [
            'project_start_date',
            'drone_run_project_type',
            'drone_run_band_project_type',
            'drone_run_band_rotate_angle',
            'drone_run_band_cropped_polygon',
            'drone_run_band_background_removed_tgi_threshold',
            'drone_run_band_background_removed_vari_threshold',
            'drone_run_band_background_removed_ndvi_threshold',
            'drone_run_band_background_removed_tgi_mask_original_threshold',
            'drone_run_band_background_removed_vari_mask_original_threshold',
            'drone_run_band_background_removed_ndv_mask_original_threshold',
            'drone_run_band_background_removed_thresholded_tgi_mask_original_threshold',
            'drone_run_band_background_removed_thresholded_vari_mask_original_threshold',
            'drone_run_band_background_removed_thresholded_ndvi_mask_original_threshold',
            'drone_run_band_background_removed_threshold',
            'drone_run_band_plot_polygons'
        ],
        'project_relationship' => [
            'drone_run_on_field_trial',
            'drone_run_band_on_drone_run'
        ]
    };

    foreach my $t (keys %$terms){
        foreach (@{$terms->{$t}}){
            $schema->resultset("Cv::Cvterm")->create_with({
                name => $_,
                cv => $t
            });
        }
    }

    my $coderef = sub {
        my $sql = <<SQL;
CREATE TABLE if not exists phenome.project_md_image (
    project_md_image_id serial PRIMARY KEY,
    project_id integer NOT NULL,
    image_id integer NOT NULL,
    type_id integer NOT NULL,
    constraint project_md_image_project_id_fkey FOREIGN KEY (project_id) REFERENCES project (project_id) MATCH SIMPLE ON UPDATE NO ACTION ON DELETE NO ACTION,
    constraint project_md_image_image_id_fkey FOREIGN KEY (image_id) REFERENCES metadata.md_image (image_id) MATCH SIMPLE ON UPDATE NO ACTION ON DELETE NO ACTION,
    constraint project_md_image_type_id_fkey FOREIGN KEY (type_id) REFERENCES cvterm (cvterm_id) MATCH SIMPLE ON UPDATE NO ACTION ON DELETE NO ACTION
);
grant select,insert on table phenome.project_md_image to web_usr;
grant usage on phenome.project_md_image_project_md_image_id_seq to web_usr;
SQL
        $schema->storage->dbh->do($sql);
    };

    my $transaction_error;
    try {
        $schema->txn_do($coderef);
    } catch {
        $transaction_error =  $_;
    };
    if ($transaction_error){
        print STDERR "ERROR: $transaction_error\n";
    } else {
        print "You're done!\n";
    }
}


####
1; #
####
