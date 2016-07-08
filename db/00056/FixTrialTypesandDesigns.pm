#!/usr/bin/env perl


=head1 NAME

FixTrialTypesandDesigns.pm

=head1 SYNOPSIS

mx-run FixTrialTypesandDesigns [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch updates the list of possible trial types and designs, by removing duplicates, adding missing ones, and changing the way they are stored in the DB to reflect other trial props like location

=head1 AUTHOR

Bryan Ellerbrock<bje24@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package FixTrialTypesandDesigns;

use Moose;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch updates the list of possible trial types and designs, by removing duplicates, adding missing ones, and changing the way they are stored in the DB to reflect other trial props like location


sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    $self->dbh->do(<<EOSQL);

--do your SQL here



--
EOSQL

print "You're done!\n";
}


####
1; #
####
