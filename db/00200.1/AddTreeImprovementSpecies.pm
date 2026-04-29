#!/usr/bin/env perl

=head1 NAME

AddTreeImprovementSpecies.pm

=head1 SYNOPSIS

mx-run AddTreeImprovementSpecies [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch:
 - Adds new trial types: Progeny, Provenance, Wild Tree Selection

=head1 AUTHOR

Katherine Eaton

=head1 COPYRIGHT & LICENSE

Copyright 2025 University of Alberta

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

package AddTreeImprovementSpecies;

use Moose;
use Bio::Chado::Schema;
extends 'CXGN::Metadata::Dbpatch';

has '+description' => ( default => <<'' );
This patch adds new tree improvement species: Lodgepole pine, White spruce.

sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";
    my $schema = Bio::Chado::Schema->connect( sub { $self->dbh->clone } );

    print STDERR "INSERTING CV TERMS...\n";

    $schema->resultset("Organism::Organism")->create({
        abbreviation => "P.contorta",
        genus => "Pinus",
        species => "Pinus contorta",
        common_name => "lodgepole pine",
    });

    $schema->resultset("Organism::Organism")->create({
        abbreviation => "P.glauca",
        genus => "Picea",
        species => "Picea glauca",
        common_name => "white spruce",
    });

    print "You're done!\n";
}

####
1; #
####
