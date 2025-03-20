#!/usr/bin/env perl


=head1 NAME

AddJobsTable.pm

=head1 SYNOPSIS

mx-run AddJobsTable.pm [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This DB patch adds an sp_job table to sgn_people. This table tracks background job submissions.

=head1 AUTHOR

Ryan Preble <rsp98@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2025 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package TestDbpatchMoose;

use Moose;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
Adds sp_job table to sgn_people. This table tracks background job submissions (managed by Slurm).
Table includes sp_job_id, sp_person_id, slurm_id, create_timestamp, finish_timestamp, status, args. 
All are simple integers or strings except args, which is a JSON holding extended information about
the job, including job type, submission parameters, cmd, submission URL, results URL, and any other
data that may need to be stored. 

has '+prereq' => (
    default => sub {
        [''],
    },
  );

sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    $self->dbh->do(<<EOSQL);
CREATE TABLE sgn_people.sp_job(
    id SERIAL PRIMARY KEY,
    sp_person_id INT REFERENCES sgn_people.sp_person(id),
    slurm_id VARCHAR(255) NOT NULL,
    status VARCHAR(100),
    create_timestamp VARCHAR(100) NOT NULL,
    finish_timestamp VARCHAR(100), 
    type INT REFERENCES public.cvterm(id)
    args JSONB
);

EOSQL

print "You're done!\n";
}


####
1; #
####
