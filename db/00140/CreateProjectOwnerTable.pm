#!/usr/bin/env perl


=head1 NAME

    CreateProjectOwnerTable.pm

=head1 SYNOPSIS

mx-run CreateProjectOwnerTable [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch creates the phenome.project_owner table used for storing sp_person_id of hte person who created the trial

This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR


=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package CreateProjectOwnerTable;

use Moose;

extends 'CXGN::Metadata::Dbpatch';

has '+description' => ( default => <<'');
This patch creates a phenome.project_owner table used for assigning sp_person_id to created trials 


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

-- table definition
CREATE TABLE IF NOT EXISTS phenome.project_owner (
    "project_owner_id" SERIAL PRIMARY KEY,
    "project_id" integer REFERENCES public.project NOT NULL,
    "sp_person_id" integer REFERENCES sgn_people.sp_person NOT NULL,
    "create_date" timestamp default now()
);


-- grant usage to web_usr
GRANT ALL on phenome.project_owner to web_usr;
GRANT USAGE ON phenome.project_owner_project_owner_id_seq to web_usr;

EOSQL

print "You're done!\n";
}


####
1; #
####
