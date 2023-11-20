#!/usr/bin/env perl


=head1 NAME

UpdateNdGeolocationDbxrefTablePermissions.pm

=head1 SYNOPSIS

mx-run UpdateNdGeolocationDbxrefTablePermissions [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch adds all permissions for web_usr to the project_dbxref table

=head1 AUTHOR

Nick Palladino <np398@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package UpdateNdGeolocationDbxrefTablePermissions;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch adds all permissions for web_usr to the nd_geolocation_dbxref table

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

GRANT ALL ON TABLE public.nd_geolocation_dbxref TO web_usr;
EOSQL

    print "You're done!\n";
}


####
1; #
####
