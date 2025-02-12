#!/usr/bin/env perl


=head1 NAME

   AddBasicPrivileges

=head1 SYNOPSIS

mx-run AddBasicPrivileges [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

Adds the basic privileges so that the new privileges feature works identically to the old system

=head1 AUTHOR

   Lukas Mueller <lam87@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2025 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddBasicPrivileges;

use Moose;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
Adds privileges that imitate the old privileges

has '+prereq' => (
    
  );

sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    $self->dbh->do(<<EOSQL);
--do your SQL here
--
-- add resources
--
insert into sgn_people.sp_resource (name) values ('pedigrees');
insert into sgn_people.sp_resource (name) values ('privileges');
insert into sgn_people.sp_resource (name) values ('genotyping');
insert into sgn_people.sp_resource (name) values ('images');
insert into sgn_people.sp_resource (name) values ('phenotyping');

-- add access levels
insert into sgn_people.sp_access_level (name) values ('read');
insert into sgn_people.sp_access_level (name) values ('write');
insert into sgn_people.sp_access_level (name) values ('delete');

-- add specific privileges
--
-- curator for pedigrees:
insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (1, 1, 1);
insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (1, 1, 2);

-- submitter for pedigrees:

insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (1, 3, 1);
insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (1, 3, 2);

-- user for pedigrees
insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (1, 4, 1);

-- curator for privileges:
insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (2, 1, 1);
insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (2, 1, 2);

-- curator for genotyping
insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (3, 1, 1);
insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (3, 1, 2);

-- submitter for genotyping
insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (3, 3, 1);
insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (3, 3, 2);

-- user for genotyping
insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (3, 4, 1);


EOSQL

print "You're done!\n";
}


####
1; #
####
