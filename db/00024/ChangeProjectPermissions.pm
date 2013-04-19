#!/usr/bin/env perl


=head1 NAME

 ChangeProjectPermissions.pm  - a db patch to fix permissions in the project table

=head1 SYNOPSIS

mx-run ChangeProjectPermissions [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

Grants select,update,delete,insert privileges on the project and projectprop table to web_usr.

This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

 Naama Menda<nm249@cornell.edu>, Lukas Mueller

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package ChangeProjectPermissions;

use Moose;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
Description of this patch goes here

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

    $self->dbh->do(<<EOSQL);
--do your SQL here
--
GRANT select,insert,update,delete ON project to web_usr;
    GRANT usage ON project_project_id_seq TO web_usr;
GRANT select,insert,update,delete ON projectprop to web_usr;
    GRANT usage ON projectprop_projectprop_id_seq TO web_usr;

EOSQL

print "You're done!\n";
}


####
1; #
####
