#!/usr/bin/env perl


=head1 NAME

FixComposedTraitRelationships.pm

=head1 SYNOPSIS

mx-run FixComposedTraitRelationships [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This is a patch to update cvterm_relationships for composed traits to include VARIABLE_OF relationships
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

Bryan Ellerbrock <bje24@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package FixComposedTraitRelationships;

use Moose;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
Description of this patch goes here

has '+prereq' => (
    default => sub {
        ['MyPrevPatch'],
    },
  );

sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    $self->dbh->do(<<EOSQL);

    BEGIN;
    UPDATE cvterm_relationship
    SET type_id = (SELECT cvterm_id FROM cvterm WHERE name = 'VARIABLE_OF')
    WHERE subject_id IN (SELECT cvterm_id FROM cvterm WHERE name LIKE '%|%');
    COMMIT;

EOSQL

print "You're done!\n";``
}


####
1; #
####
