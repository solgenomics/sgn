#!/usr/bin/env perl

=head1 NAME

IndexNdExperiment.pm

=head1 SYNOPSIS

mx-run IndexNdExperiment [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch:
 - Adds indexes to assorted nd_experiment_* tables to speed up phenotype queries.

=head1 AUTHOR

Katherine Eaton

=head1 COPYRIGHT & LICENSE

Copyright 2026 University of Alberta

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

package IndexNdExperiment;

use Moose;
use Bio::Chado::Schema;
extends 'CXGN::Metadata::Dbpatch';

has '+description' => ( default => <<'' );
This patch adds indexes to assorted nd_experiment_* tables to speed up phenotype queries.

sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    $self->dbh->do(<<EOSQL);
create index nd_experiment_phenotype_idx1 on nd_experiment_phenotype (phenotype_id);
create index nd_experiment_stock_idx1 on nd_experiment_stock (nd_experiment_id);
create index nd_experiment_stock_idx2 on nd_experiment_stock (stock_id);
create index nd_experiment_project_idx1 on nd_experiment_project (nd_experiment_id);
create index nd_experiment_project_idx2 on nd_experiment_project (project_id);

EOSQL

    print "You're done!\n";
}

####
1; #
####
