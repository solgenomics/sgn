#!/usr/bin/env perl


=head1 NAME

FixOutOfSyncNdGeolocations

=head1 SYNOPSIS

mx-run FixOutOfSyncNdGeolocations [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION
This patch updates nd_experiment.nd_geolocation_ids that are out of sync with the location specified in linked projectprop.values
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

Bryan Ellerbrock<bje24@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package FixOutOfSyncNdGeolocations;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;
use SGN::Model::Cvterm;
use JSON;
use Data::Dumper;

extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch updates nd_experiment.nd_geolocation_ids that are out of sync with the location specified in linked projectprop.values

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
    my $project_location_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project_property', 'project location')->cvterm_id();

    my $query = "UPDATE nd_experiment
        SET nd_geolocation_id = projectprop.value::int
        FROM nd_experiment_project
        JOIN projectprop ON(
            nd_experiment_project.project_id = projectprop.project_id AND
            projectprop.type_id = 76463
        )
        WHERE nd_experiment_project.nd_experiment_id = nd_experiment.nd_experiment_id
        AND nd_experiment_project.nd_experiment_id IN (
            SELECT ne.nd_experiment_id
            FROM nd_experiment_project nep
            JOIN nd_experiment ne USING(nd_experiment_id)
            EXCEPT
            SELECT ne.nd_experiment_id
            FROM project p
            JOIN projectprop pp ON(
                p.project_id=pp.project_id AND
                pp.type_id = (
                    SELECT cvterm_id FROM cvterm WHERE name = 'project location'
                )
            )
            JOIN nd_experiment_project nep ON(p.project_id = nep.project_id)
            JOIN nd_experiment ne ON(
                nep.nd_experiment_id = ne.nd_experiment_id AND
                ne.nd_geolocation_id = pp.value::int
            )
            JOIN cvterm c ON(ne.type_id=c.cvterm_id)
        );";

    # print STDERR Dumper $q;
    my $h = $schema->storage->dbh()->prepare($query);
    $h->execute();

    print "You're done!\n";
}


####
1; #
####
