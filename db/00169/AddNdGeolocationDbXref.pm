#!/usr/bin/env perl


=head1 NAME

AddNdGeolocationDbXref.pm

=head1 SYNOPSIS

mx-run AddNdGeolocationDbXref [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch creates a nd_geolocation_dbxref table to allow projects to store external references for brapi

=head1 AUTHOR

Chris Tucker

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddNdGeolocationDbXref;

use Moose;
use Try::Tiny;
use Bio::Chado::Schema;

extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch creates a nd_geolocation_dbxref table to allow projects to store external references for brapi


sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";
    my $schema = Bio::Chado::Schema->connect( sub { $self->dbh->clone } );

    my $coderef = sub {
        $self->dbh->do(<<EOSQL);

 --do your SQL here
CREATE TABLE IF NOT EXISTS public.nd_geolocation_dbxref (
	nd_geolocation_dbxref_id serial NOT NULL PRIMARY KEY,
	nd_geolocation_id int4 NOT NULL REFERENCES nd_geolocation(nd_geolocation_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
	dbxref_id int4 REFERENCES dbxref(dbxref_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
	is_current bool NOT NULL DEFAULT true
);
EOSQL

        return 1;
    };

    try {
        $schema->txn_do($coderef);
    } catch {
        die "Load failed! " . $_ .  "\n" ;
    };
    print "You're done!\n";
}


####
1; #
####
