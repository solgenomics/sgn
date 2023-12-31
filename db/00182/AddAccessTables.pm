#!/usr/bin/env perl


=head1 NAME

 AddAccessTables.pm

=head1 SYNOPSIS

mx-run AddAccessTables [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

Adds tables for more fine-grained access control.
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

 Lukas Mueller <lam87@cornell.edu>
 Naama Menda <nm249@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010-2023 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddAccessTables;

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

create table sgn_people.sp_resource (sp_resource_id serial primary key, name varchar(100), url text);

create table sgn_people.sp_access_level (sp_access_level_id serial primary key, name varchar(20));

create table sgn_people.sp_privilege (sp_privilege_id serial primary key, sp_resource_id bigint references sgn_people.sp_resource, sp_role_id bigint references sgn_people.sp_roles, sp_access_level_id bigint references sgn_people.sp_access_level, require_ownership boolean);

--do your SQL here
--
SELECT * from public.stock;

EOSQL

print "You're done!\n";
}


####
1; #
####



