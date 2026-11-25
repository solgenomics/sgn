#!/usr/bin/env perl


=head1 NAME

AddNdExperimentPhenotypeGenotypeIndexes.pm

=head1 SYNOPSIS

mx-run AddNdExperimentPhenotypeGenotypeIndexes [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This DB patch adds b-tree indexes on phenotype_id in nd_experiment_phenotype and on genotype_id in
nd_experiment_genotype. Besides its primary key, each of these tables has only a unique index that
starts with nd_experiment_id, so a lookup by phenotype_id or genotype_id has no index that starts
with that column, and can require scanning the table or the whole of that index.

CXGN::Phenotype makes such a lookup whenever it is built from a phenotype_id, and the stock genotype
download filters nd_experiment_genotype by genotype_id. On a database with about 40,000
nd_experiment_phenotype rows, the CXGN::Phenotype lookup took 3.4 milliseconds without the index and
0.24 milliseconds with it, and the difference is expected to grow with the table.

The statements run in one transaction, so a trial run (-t) builds the indexes and then rolls
them back. Indexes that already exist under these names are left unchanged.
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

Scott Brainard

=cut

package AddNdExperimentPhenotypeGenotypeIndexes;

use Moose;

extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
Adds indexes on phenotype_id in nd_experiment_phenotype and genotype_id in nd_experiment_genotype

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
CREATE INDEX IF NOT EXISTS nd_experiment_phenotype_phenotype_id_idx ON public.nd_experiment_phenotype (phenotype_id);
CREATE INDEX IF NOT EXISTS nd_experiment_genotype_genotype_id_idx ON public.nd_experiment_genotype (genotype_id);
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
