#!/usr/bin/env perl


=head1 NAME

AddJobObsoleteColumn.pm

=head1 SYNOPSIS

mx-run AddJobObsoleteColumn [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This DB patch adds a boolean is_obsolete column to sgn_people.sp_job. It defaults to false, so
every existing job stays visible. Dismissing a job in the job log or the upload manager now sets
is_obsolete to true instead of deleting the row, so a record of every submitted job is kept.
Job listings leave out obsolete jobs.

The statement runs in one transaction, so a trial run (-t) adds the column and then rolls it back.
A column that already exists under this name is left unchanged.
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

Ryan Preble <rsp98@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2026 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

package AddJobObsoleteColumn;

use Moose;

extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
Adds an is_obsolete flag to sgn_people.sp_job so that dismissed jobs are kept rather than deleted

has '+prereq' => (
    default => sub {
        ['AddJobsTable'],
    },
  );

sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    # The patch framework runs with AutoCommit on, so without this transaction a trial run would keep the column.
    # Stop at a failed statement, so a failure is never recorded as applied.
    local $self->dbh->{RaiseError} = 1;
    $self->dbh->begin_work();
    $self->dbh->do(<<EOSQL);
ALTER TABLE sgn_people.sp_job ADD COLUMN IF NOT EXISTS is_obsolete BOOLEAN NOT NULL DEFAULT FALSE;
EOSQL
    if ($self->trial) {
        $self->dbh->rollback();
        print "Trial mode: the column was added and rolled back.\n";
    }
    else {
        $self->dbh->commit();
    }

    print "You're done!\n";
}


####
1; #
####
