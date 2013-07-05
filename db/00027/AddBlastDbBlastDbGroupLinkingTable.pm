#!/usr/bin/env perl


=head1 NAME

 AddBlastDbBlastDbGroupLinkingTable.pm

=head1 SYNOPSIS

mx-run ThisPackageName [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

 Lukas Mueller<lam87@cornell.edu> 

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddBlastDbBlastDbGroupLinkingTable;

use Moose;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
Adds a linking table between the blast_db and blast_db_group table

has '+prereq' => (
    default => sub {
        [ ],
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

create table blast_db_blast_db_group (
    blast_db_blast_db_group_id serial primary key,
    blast_db_id bigint REFERENCES blast_db,
    blast_db_group_id bigint REFERENCES blast_db_group
);

-- populate table with current data from blast_db table

insert into sgn.blast_db_blast_db_group (blast_db_id, blast_db_group_id) SELECT blast_db_id, blast_db_group_id FROM sgn.blast_db;

-- also add blast_db_organism table

create table blast_db_organism ( 
    blast_db_organism_id serial primary key,
    blast_db_id bigint reference sgn.blast_db,
    organism_id bigint reference public.organism
);

EOSQL

print "You're done!\n";
}


####
1; #
####
