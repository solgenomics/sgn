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
insert into sgn_people.sp_resource (name) values ('trials');
insert into sgn_people.sp_resource (name) values ('crosses');
insert into sgn_people.sp_resource (name) values ('wizard');
insert into sgn_people.sp_resource (name) values ('community');
insert into sgn_people.sp_resource (name) values ('loci');
insert into sgn_people.sp_resource (name) values ('breeding_programs');
insert into sgn_people.sp_resource (name) values ('stocks');
insert into sgn_people.sp_resource (name) values ('catalog');
insert into sgn_people.sp_resource (name) values ('user_roles');
insert into sgn_people.sp_resource (name) values ('ontologies');
insert into sgn_people.sp_resource (name) values ('publications');
insert into sgn_people.sp_resource (name) values ('locations');
insert into sgn_people.sp_resource (name) values ('seedlots');

-- add access levels

insert into sgn_people.sp_access_level (name) values ('read');
insert into sgn_people.sp_access_level (name) values ('write');
insert into sgn_people.sp_access_level (name) values ('update');
insert into sgn_people.sp_access_level (name) values ('delete');

-- add specific privileges
--

-- CURATOR PRIVILEGES

-- curator for privileges: (should be separate role)

insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (2, 1, 1);
insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (2, 1, 2);

-- curator for pedigrees:

insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (1, 1, 1);
insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (1, 1, 2);

-- curator for genotyping

insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (3, 1, 1);
insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (3, 1, 2);

-- curator for images

insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (4, 1, 1);
insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (4, 1, 2);

-- curator for trials

insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (6, 1, 1);
insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (6, 1, 2);

-- curator for phentoyping (read and write):

insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (5, 1, 1);
insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (5, 1, 2);

-- curator for crosses

insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (7, 1, 1);
insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (7, 1, 2);

--curator for wizard

insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (8, 1, 1);

--curator for community

insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (9, 1, 1);
insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (9, 1, 2);

--curator for loci

insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (10, 1, 1);
insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (10, 1, 2);

-- curator for breeding programs

insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (11, 1, 1);
insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (11, 1, 2);

-- curator for stocks

insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (12, 1, 1);
insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (12, 1, 2);

-- curator for catalog

insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (13, 1, 1);
insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (13, 1, 2);

-- curator for user_roles

insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (14, 1, 1);
insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (14, 1, 2);

-- curator for ontologies

insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (15, 1, 1);
insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (15, 1, 2);

-- curator for publications

insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (16, 1, 1);
insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (16, 1, 2);

-- curator for locations

insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (17, 1, 1);
insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (17, 1, 2);

-- curator for seedlots

insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (18, 1, 1);
insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (18, 1, 2);
insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (18, 1, 4);


--SUBMITTER PRIVILEGES

-- submitter for pedigrees:

insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (1, 3, 1);
insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (1, 3, 2);

-- submitter for images:
insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (4, 3, 1);
insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (4, 3, 2);


-- submitter for phentoyping (read and write):

insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (5, 3, 1);
insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (5, 3, 2);

-- submitter for trial

insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (6, 3, 1);
insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (6, 3, 2);

-- submitter for genotyping

insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (3, 3, 1);
insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (3, 3, 2);

-- submitter for crosses

insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (7, 3, 1);
insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (7, 3, 2);

-- submitter for wizard

insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (8, 3, 1);

-- submitter for community

insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (9, 3, 1);
insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (9, 3, 2);

-- submitter for loci

insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (10, 3, 1);
insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (10, 3, 2);

-- submitter for breeding programs

insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (11, 3, 1);
insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (11, 3, 2);

-- submitter for stocks

insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (12, 3, 1);
insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (12, 3, 2);

-- submitter for user_roles

insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (14, 3, 1);


-- submitter for ontologies

insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (15, 3, 1);
insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (15, 3, 2);

-- submitter for publications

insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (16, 3, 1);
insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (16, 3, 2);

-- submitter for locations

insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (17, 3, 1);
insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (17, 3, 2);

-- submitter for seedlots

insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (18, 3, 1);
insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (18, 3, 2);



-- USER PRIVILEGES

-- user for pedigrees

insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (1, 4, 1);

-- user for genotyping

insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (3, 4, 1);

-- user for images

insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (4, 4, 1);


-- user for phenotyping

insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (5, 4, 1);

-- user for trials

insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (6, 4, 1);

-- user for crosses

insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (8, 4, 1);

-- user for wizard

insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (8, 4, 1);

-- user for community

insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (9, 4, 1);
insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (9, 4, 2);

-- user for loci

insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (10, 4, 1);

-- user for breeding programs

insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (11, 4, 1);

-- user for stocks

insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (12, 4, 1);

-- user for ontologies

insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (15, 4, 1);

-- user for publications

insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (16, 4, 1);

-- user for locations

insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (17, 4,  1);

-- user for seedlots

insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (18, 4, 1);

-- VENDOR PRIVLEGES

insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (13, (select sp_role_id from sgn_people.sp_roles where name='vendor'), 1);
insert into sgn_people.sp_privilege (sp_resource_id, sp_role_id, sp_access_level_id) values (13, (select sp_role_id from sgn_people.sp_roles where name='vendor'), 2);



EOSQL

print "You're done!\n";
}


####
1; #
####
