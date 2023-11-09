#!/usr/bin/env perl


=head1 NAME

 AddSpTeamTable.pm

=head1 SYNOPSIS

mx-run AddSpTeamTable [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

Add the sp_stage_gate, sp_teams and sp_person_team tables
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddSpTeamTable;

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

CREATE TABLE sgn_people.sp_stage_gate_definition (
    sp_stage_gate_definition_id serial primary key,
    name varchar(20),
    description text,
    breeding_program_id bigint reference public.project
);
GRANT select,insert,update,delete ON sgn_people.sp_stage_gate_definition TO web_usr;
GRANT USAGE ON sgn_people.sp_stage_gate_definition_sp_stage_gate_definition_id_seq TO web_usr;

CREATE TABLE sgn_people.sp_stage_gate (
  sp_stage_gate_id serial primary key,
  sp_stage_gate_definition_id bigint refernences sp_stage_gate_definition,
  name varchar(100) unique,
  description text,
  season varchar(100),
  year varchar(4),
);

CREATE TABLE sgn_people.sp_stage_gate_trial (
  sp_stage_gate_trial_id primary key,
  sp_stage_gate_id bigint references sp_stage_gate,
  project_id biging reference public.project
);



GRANT select,insert,update,delete ON sgn_people.sp_stage_gate TO web_usr;
GRANT USAGE ON sgn_people.sp_stage_gate_sp_stage_gate_id_seq TO web_usr;

CREATE TABLE sgn_people.sp_teams (
  sp_team_id serial primary key,
  name varchar(100),
  sp_stage_gate_id bigint references sgn_people.sp_stage_gate,
  description text
);

GRANT select,insert,update,delete ON sgn_people.sp_teams TO web_usr;
GRANT USAGE ON sgn_people.sp_teams_sp_team_id_seq TO web_usr;

CREATE TABLE sgn_people.sp_person_team (
  sp_person_team_id serial primary key,
  sp_person_id bigint NOT NULL REFERENCES sgn_people.sp_person ON DELETE CASCADE,
  sp_team_id bigint NOT NULL REFERENCES sgn_people.sp_teams ON DELETE CASCADE,
  functional_role varchar(100)
);

GRANT select,insert,update,delete ON sgn_people.sp_person_team TO web_usr;
GRANT USAGE ON sgn_people.sp_person_team_sp_person_team_id_seq TO web_usr;

INSERT INTO cvterm (name, cv_id) values ('stage_gate_selection_info', SELECT cv_id from cv where name='stock_property');

EOSQL

print "You're done!\n";
}


####
1; #
####
