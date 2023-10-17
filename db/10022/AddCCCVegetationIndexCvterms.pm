#!/usr/bin/env perl


=head1 NAME

 AddCCCVegetationIndexCvterms

=head1 SYNOPSIS

mx-run AddCCCVegetationIndexCvterms [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION
This patch adds cvterms for calculating the CCC Canopy Cover Canopeo algorithm vegetation index
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

David Waring <djw64@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddCCCVegetationIndexCvterms;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch adds cvterms for calculating the CCC Canopy Cover Canopeo algorithm vegetation index

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
            'calculate_ccc_drone_imagery',
            'calculate_ccc_temporary_drone_imagery',
            'threshold_background_removed_ccc_stitched_drone_imagery',
            'denoised_background_removed_ccc_mask_original',
            'denoised_background_removed_thresholded_ccc_mask_original',
            'observation_unit_polygon_ccc_imagery',
            'observation_unit_polygon_background_removed_ccc_imagery',
            'observation_unit_polygon_original_background_removed_ccc_mask_imagery',
            'observation_unit_polygon_original_background_removed_ccc_mask_imagery_channel_1',
            'observation_unit_polygon_original_background_removed_ccc_mask_imagery_channel_2',
            'observation_unit_polygon_original_background_removed_ccc_mask_imagery_channel_3',
            'observation_unit_polygon_original_background_removed_thresholded_ccc_mask_imagery',
            'observation_unit_polygon_original_background_removed_thresholded_ccc_mask_imagery_channel_1',
            'observation_unit_polygon_original_background_removed_thresholded_ccc_mask_imagery_channel_2',
            'observation_unit_polygon_original_background_removed_thresholded_ccc_mask_imagery_channel_3',
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
