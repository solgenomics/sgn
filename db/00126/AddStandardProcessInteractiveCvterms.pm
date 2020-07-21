#!/usr/bin/env perl


=head1 NAME

 AddStandardProcessInteractiveCvterms

=head1 SYNOPSIS

mx-run AddStandardProcessInteractiveCvterms [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION
This patch adds cvterms for standard process interactive drone imagery
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR


=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddStandardProcessInteractiveCvterms;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch adds cvterms for standard process interactive drone imagery

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
            'standard_process_interactive_match_temporary_drone_imagery',
            'standard_process_interactive_align_temporary_drone_imagery'
        ],
        'project_property' => [
            'drone_run_raw_images_saved_gps_pixel_positions',
            'drone_run_raw_images_saved_micasense_stacks_rotated',
            'drone_run_is_raw_images',
            'drone_run_raw_images_rotation_occuring',
            'drone_run_raw_images_saved_micasense_stacks_separated',
            'drone_run_band_plot_polygons_separated'
        ],
        'protocol_type' => [
            'sommer_grm_temporal_random_regression_dap_genetic_blups',
            'sommer_grm_temporal_random_regression_gdd_genetic_blups'
        ],
        'experiment_type' => [
            'drone_run_experiment'
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
