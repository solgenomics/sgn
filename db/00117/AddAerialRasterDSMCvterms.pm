#!/usr/bin/env perl


=head1 NAME

 AddAerialRasterDSMCvterms

=head1 SYNOPSIS

mx-run AddAerialRasterDSMCvterms [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION
This patch adds cvterms for phenotype spreadsheet associated images
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR


=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddAerialRasterDSMCvterms;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch adds cvterms for phenotype spreadsheet associated images

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


    print STDERR "INSERTING CV TERMS...\n";

    my $terms = {
        'project_md_image' => [
            'observation_unit_polygon_raster_dsm_imagery',
            'threshold_background_removed_stitched_drone_imagery_raster_dsm',
            'observation_unit_polygon_raster_dsm_background_removed_threshold_imagery',
            'raw_boundaries_top_left_drone_imagery',
            'raw_boundaries_top_right_drone_imagery',
            'raw_boundaries_bottom_left_drone_imagery',
            'raw_boundaries_bottom_right_drone_imagery'
        ],
        'project_property' => [
            'drone_run_raw_images_saved_micasense_stacks',
            'drone_run_band_plot_polygons_partial'
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
