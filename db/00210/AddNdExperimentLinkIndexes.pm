#!/usr/bin/env perl


=head1 NAME

AddNdExperimentLinkIndexes.pm

=head1 SYNOPSIS

mx-run AddNdExperimentLinkIndexes [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This DB patch adds b-tree indexes on the foreign key columns of the two tables that link
experiments to trials and to observation units: nd_experiment_stock (nd_experiment_id and
stock_id) and nd_experiment_project (project_id and nd_experiment_id). Until now both tables
were indexed only by their primary keys.

Without these indexes, a trial's plots and plants can be reached through the two tables only
by scanning them. When the planner's statistics lag behind a recent upload, it can choose a
nested loop for the observation unit search in CXGN::Trial::TrialLayoutSearch, which the BrAPI
observationunits search uses, that rescans all of nd_experiment_stock once for each experiment
in the trial. On a database with about 67,000 nd_experiment_stock rows, a plant-level search of
a trial with 1,025 plots took 67 seconds that way, and 0.6 seconds with these indexes.

The statements run in one transaction, so a trial run (-t) builds the indexes and then rolls
them back. Indexes that already exist under these names are left unchanged.
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

Scott Brainard

=cut

package AddNdExperimentLinkIndexes;

use Moose;

extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
Adds indexes on the foreign key columns of nd_experiment_stock and nd_experiment_project

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

    # The patch framework runs with AutoCommit on, so without this transaction a trial run would keep the indexes.
    # Stop at a failed statement, so a failure is never recorded as applied.
    local $self->dbh->{RaiseError} = 1;
    $self->dbh->begin_work();
    $self->dbh->do(<<EOSQL);
CREATE INDEX IF NOT EXISTS nd_experiment_stock_nd_experiment_id_idx ON public.nd_experiment_stock (nd_experiment_id);
CREATE INDEX IF NOT EXISTS nd_experiment_stock_stock_id_idx ON public.nd_experiment_stock (stock_id);
CREATE INDEX IF NOT EXISTS nd_experiment_project_project_id_idx ON public.nd_experiment_project (project_id);
CREATE INDEX IF NOT EXISTS nd_experiment_project_nd_experiment_id_idx ON public.nd_experiment_project (nd_experiment_id);
EOSQL
    if ($self->trial) {
        $self->dbh->rollback();
        print "Trial mode: the indexes were built and rolled back.\n";
    }
    else {
        $self->dbh->commit();
    }

    print "You're done!\n";
}


####
1; #
####
