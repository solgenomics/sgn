#!/usr/bin/env perl


=head1 NAME

 AddMissingProgramPropsToLocations.pm

=head1 SYNOPSIS

mx-run ThisPackageName [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION
This patch finds locations that are missing a program prop, and adds the correct program if it can be inferred based on the trials that have been held at the location.
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

Bryan Ellerbrock

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package  AddMissingProgramPropsToLocations;

use Moose;
use Bio::Chado::Schema;
use SGN::Model::Cvterm;
use Try::Tiny;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch finds locations that are missing a program prop, and adds the correct program if it can be inferred based on the trials that have been held at the location.

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

    my $coderef = sub {
        print STDERR "Updating location breeding programs . . .\n";

        my $query = "SELECT nd_geolocation.nd_geolocation_id, project.project_id, nd_geolocation.description, project.name
        FROM nd_geolocation
        JOIN nd_experiment using(nd_geolocation_id)
        JOIN nd_experiment_project using(nd_experiment_id)
        JOIN project_relationship on (nd_experiment_project.project_id = subject_project_id and project_relationship.type_id = (select cvterm_id from cvterm where name = 'breeding_program_trial_relationship'))
        JOIN project on (project_relationship.object_project_id = project.project_id)
        GROUP by 1,2,3,4";

        my $h = $schema->storage->dbh->prepare($query);
        $h->execute();

        my $breeding_program_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'breeding_program', 'project_property')->cvterm_id();
        my @locations;
        while (my ($location_id, $program_id, $location_name, $program_name) = $h->fetchrow_array()) {
            print STDERR "Trials from $program_name have been held at location $location_name. Checking to see if these are already linked through nd_geolocationprop\n";
            my $location = $schema->resultset("NaturalDiversity::NdGeolocation")->find( { nd_geolocation_id => $location_id });
            my $rs = $schema->resultset("NaturalDiversity::NdGeolocationprop")->search({ nd_geolocation_id=> $location_id, value => $program_id, type_id => $breeding_program_cvterm_id });

            if($rs->next()) {
                #skip, this program - location link is already stored in nd_geolocationprop
            } else {
                print STDERR "No prop found, linking $program_name to $location_name in nd_geolocationprop\n";
                my $count = $schema->resultset("NaturalDiversity::NdGeolocationprop")->search({ nd_geolocation_id=> $location_id, type_id => $breeding_program_cvterm_id })->count();
                my $stored_location = $location->create_geolocationprops({ 'breeding_program' => $program_id }, {cv_name => 'project_property', rank => $count });
            }
        }
    };

    try {
      $schema->txn_do($coderef);
    } catch {
      die " patch failed! " . $_ .  "\n" ;
    };

    print "You're done!\n";

  }


####
1; #
####
