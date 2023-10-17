#!/usr/bin/env perl


=head1 NAME

 AddMoreStitchingReportandODMCvterms

=head1 SYNOPSIS

mx-run AddMoreStitchingReportandODMCvterms [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION
This patch adds cvterms for saving stitching reports and point clouds from ODM
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR


=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddMoreStitchingReportandODMCvterms;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;
use SGN::Model::Cvterm;

extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch adds cvterms for saving stitching reports and point clouds from ODM

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
        'experiment_type' => [
            'drone_run_experiment_odm_stitched_dsm',
            'drone_run_experiment_odm_stitched_dtm',
            'drone_run_experiment_odm_stitched_dsm_minus_dtm',
            'drone_run_experiment_odm_stitched_point_cloud_obj',
            'drone_run_experiment_odm_stitched_point_cloud_pcd',
            'drone_run_experiment_odm_stitched_point_cloud_gltf',
            'drone_run_experiment_odm_stitched_point_cloud_csv',
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
