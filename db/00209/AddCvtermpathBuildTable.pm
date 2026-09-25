#!/usr/bin/env perl


=head1 NAME

AddCvtermpathBuildTable.pm

=head1 SYNOPSIS

mx-run AddCvtermpathBuildTable.pm [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This DB patch adds a table called public.cvtermpath_build. This table tracks processes
building cvterm paths for a given cv_id, similar to how the matview table tracks
materialized view refreshes and ensures that no two processes attempt to build transitive
closures for the same cv at the same time. 
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

Ryan Preble <rsp98@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2025 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

package AddCvtermpathBuildTable;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;

extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
Adds cvtermpath_build table for transitive closure build tracking

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

    my $dbuser = $self->dbuser;

    $self->dbh->do(<<EOSQL);
CREATE TABLE public.cvtermpath_build(
    cvtermpath_build_id SERIAL PRIMARY KEY,
    cv_id BIGINT REFERENCES public.cv UNIQUE,
    currently_building BOOLEAN NOT NULL DEFAULT FALSE,
    last_build TIMESTAMPTZ(0),
    build_start TIMESTAMPTZ(0)
);

GRANT SELECT,UPDATE,DELETE,INSERT ON public.cvtermpath_build TO $dbuser ;

GRANT USAGE ON SEQUENCE public.cvtermpath_build_cvtermpath_build_id_seq TO $dbuser ;

EOSQL

    print "You're done!\n";
}


####
1; #
####