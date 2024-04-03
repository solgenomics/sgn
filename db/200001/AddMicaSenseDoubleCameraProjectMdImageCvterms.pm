#!/usr/bin/env perl


=head1 NAME

 AddMicaSenseDoubleCameraProjectMdImageCvterms

=head1 SYNOPSIS

mx-run AddMicaSenseDoubleCameraProjectMdImageCvterms [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION
This patch adds cvterms for the micasense double camera 10-channels
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR


=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddMicaSenseDoubleCameraProjectMdImageCvterms;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;
use SGN::Model::Cvterm;
use JSON;
use Data::Dumper;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch adds cvterms for the micasense double camera 10-channels

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
            'threshold_background_removed_stitched_drone_imagery_coastal_blue',
            'threshold_background_removed_stitched_drone_imagery_green2',
            'threshold_background_removed_stitched_drone_imagery_red2',
            'threshold_background_removed_stitched_drone_imagery_red_edge2',
            'threshold_background_removed_stitched_drone_imagery_red_edge3',
            'calculate_fourier_transform_hpf20_coastal_blue_denoised_stitched_image_channel_1',
            'calculate_fourier_transform_hpf30_coastal_blue_denoised_stitched_image_channel_1',
            'calculate_fourier_transform_hpf40_coastal_blue_denoised_stitched_image_channel_1',
            'calculate_fourier_transform_hpf20_green2_denoised_stitched_image_channel_1',
            'calculate_fourier_transform_hpf30_green2_denoised_stitched_image_channel_1',
            'calculate_fourier_transform_hpf40_green2_denoised_stitched_image_channel_1',
            'calculate_fourier_transform_hpf20_red2_denoised_stitched_image_channel_1',
            'calculate_fourier_transform_hpf30_red2_denoised_stitched_image_channel_1',
            'calculate_fourier_transform_hpf40_red2_denoised_stitched_image_channel_1',
            'calculate_fourier_transform_hpf20_red_edge2_denoised_stitched_image_channel_1',
            'calculate_fourier_transform_hpf30_red_edge2_denoised_stitched_image_channel_1',
            'calculate_fourier_transform_hpf40_red_edge2_denoised_stitched_image_channel_1',
            'calculate_fourier_transform_hpf20_red_edge3_denoised_stitched_image_channel_1',
            'calculate_fourier_transform_hpf30_red_edge3_denoised_stitched_image_channel_1',
            'calculate_fourier_transform_hpf40_red_edge3_denoised_stitched_image_channel_1',
            'calculate_fourier_transform_hpf20_coastal_blue_threshold_background_removed_stitched_drone_imagery_channel_1',
            'calculate_fourier_transform_hpf30_coastal_blue_threshold_background_removed_stitched_drone_imagery_channel_1',
            'calculate_fourier_transform_hpf40_coastal_blue_threshold_background_removed_stitched_drone_imagery_channel_1',
            'calculate_fourier_transform_hpf20_green2_threshold_background_removed_stitched_drone_imagery_channel_1',
            'calculate_fourier_transform_hpf30_green2_threshold_background_removed_stitched_drone_imagery_channel_1',
            'calculate_fourier_transform_hpf40_green2_threshold_background_removed_stitched_drone_imagery_channel_1',
            'calculate_fourier_transform_hpf20_red2_threshold_background_removed_stitched_drone_imagery_channel_1',
            'calculate_fourier_transform_hpf30_red2_threshold_background_removed_stitched_drone_imagery_channel_1',
            'calculate_fourier_transform_hpf40_red2_threshold_background_removed_stitched_drone_imagery_channel_1',
            'calculate_fourier_transform_hpf20_red_edge2_threshold_background_removed_stitched_drone_imagery_channel_1',
            'calculate_fourier_transform_hpf30_red_edge2_threshold_background_removed_stitched_drone_imagery_channel_1',
            'calculate_fourier_transform_hpf40_red_edge2_threshold_background_removed_stitched_drone_imagery_channel_1',
            'calculate_fourier_transform_hpf20_red_edge3_threshold_background_removed_stitched_drone_imagery_channel_1',
            'calculate_fourier_transform_hpf30_red_edge3_threshold_background_removed_stitched_drone_imagery_channel_1',
            'calculate_fourier_transform_hpf40_red_edge3_threshold_background_removed_stitched_drone_imagery_channel_1',
            'observation_unit_polygon_coastal_blue_imagery',
            'observation_unit_polygon_green2_imagery',
            'observation_unit_polygon_red2_imagery',
            'observation_unit_polygon_red_edge2_imagery',
            'observation_unit_polygon_red_edge3_imagery',
            'observation_unit_polygon_coastal_blue_background_removed_threshold_imagery',
            'observation_unit_polygon_green2_background_removed_threshold_imagery',
            'observation_unit_polygon_red2_background_removed_threshold_imagery',
            'observation_unit_polygon_red_edge2_background_removed_threshold_imagery',
            'observation_unit_polygon_red_edge3_background_removed_threshold_imagery',
            'observation_unit_polygon_fourier_transform_hpf20_coastal_blue_denoised_stitched_image_channel_1',
            'observation_unit_polygon_fourier_transform_hpf30_coastal_blue_denoised_stitched_image_channel_1',
            'observation_unit_polygon_fourier_transform_hpf40_coastal_blue_denoised_stitched_image_channel_1',
            'observation_unit_polygon_fourier_transform_hpf20_green2_denoised_stitched_image_channel_1',
            'observation_unit_polygon_fourier_transform_hpf30_green2_denoised_stitched_image_channel_1',
            'observation_unit_polygon_fourier_transform_hpf40_green2_denoised_stitched_image_channel_1',
            'observation_unit_polygon_fourier_transform_hpf20_red2_denoised_stitched_image_channel_1',
            'observation_unit_polygon_fourier_transform_hpf30_red2_denoised_stitched_image_channel_1',
            'observation_unit_polygon_fourier_transform_hpf40_red2_denoised_stitched_image_channel_1',
            'observation_unit_polygon_fourier_transform_hpf20_red_edge2_denoised_stitched_image_channel_1',
            'observation_unit_polygon_fourier_transform_hpf30_red_edge2_denoised_stitched_image_channel_1',
            'observation_unit_polygon_fourier_transform_hpf40_red_edge2_denoised_stitched_image_channel_1',
            'observation_unit_polygon_fourier_transform_hpf20_red_edge3_denoised_stitched_image_channel_1',
            'observation_unit_polygon_fourier_transform_hpf30_red_edge3_denoised_stitched_image_channel_1',
            'observation_unit_polygon_fourier_transform_hpf40_red_edge3_denoised_stitched_image_channel_1',
            'observation_unit_polygon_fourier_transform_hpf20_coastal_blue_denoised_background_threshold_removed_image_channel_1',
            'observation_unit_polygon_fourier_transform_hpf30_coastal_blue_denoised_background_threshold_removed_image_channel_1',
            'observation_unit_polygon_fourier_transform_hpf40_coastal_blue_denoised_background_threshold_removed_image_channel_1',
            'observation_unit_polygon_fourier_transform_hpf20_green2_denoised_background_threshold_removed_image_channel_1',
            'observation_unit_polygon_fourier_transform_hpf30_green2_denoised_background_threshold_removed_image_channel_1',
            'observation_unit_polygon_fourier_transform_hpf40_green2_denoised_background_threshold_removed_image_channel_1',
            'observation_unit_polygon_fourier_transform_hpf20_red2_denoised_background_threshold_removed_image_channel_1',
            'observation_unit_polygon_fourier_transform_hpf30_red2_denoised_background_threshold_removed_image_channel_1',
            'observation_unit_polygon_fourier_transform_hpf40_red2_denoised_background_threshold_removed_image_channel_1',
            'observation_unit_polygon_fourier_transform_hpf20_red_edge2_denoised_background_threshold_removed_image_channel_1',
            'observation_unit_polygon_fourier_transform_hpf30_red_edge2_denoised_background_threshold_removed_image_channel_1',
            'observation_unit_polygon_fourier_transform_hpf40_red_edge2_denoised_background_threshold_removed_image_channel_1',
            'observation_unit_polygon_fourier_transform_hpf20_red_edge3_denoised_background_threshold_removed_image_channel_1',
            'observation_unit_polygon_fourier_transform_hpf30_red_edge3_denoised_background_threshold_removed_image_channel_1',
            'observation_unit_polygon_fourier_transform_hpf40_red_edge3_denoised_background_threshold_removed_image_channel_1'
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

    print "You're done!\n";
}


####
1; #
####
