#!/usr/bin/env perl


=head1 NAME

 AddSpTeamTable.pm

=head1 SYNOPSIS

mx-run AddSpTeamTable [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

Add the sp_teams and sp_person_teams tables
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

 Naama Menda<nm249@cornell.edu>

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

CREATE TABLE sgn_people.sp_stage_gate (
  sp_stage_gate_id serial primary key,
  name varchar(100),
  description text,
  breeding_program_id bigint references public.project
);

CREATE TABLE sgn_people.sp_teams (
  sp_team_id serial primary key,
  name varchar(100),
  sp_stage_gate_id bigint references sgn_people.sp_stage_gate,
  description text
);

CREATE TABLE sgn_people.sp_person_team (
  sp_person_team_id serial primary key,
  sp_person_id bigint references sgn_people.sp_person NOT NULL ON DELETE CASCADE,
  sp_team_id bigint references sgn_people.sp_team NOT NULL ON DELETE CASCADE,
  functional_role varchar(100)
);


EOSQL

print "You're done!\n";
}


####
1; #
####
