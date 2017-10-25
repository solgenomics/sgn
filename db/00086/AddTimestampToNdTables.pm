#!/usr/bin/env perl


=head1 NAME

 AddTimestampToNdTables.pm

=head1 SYNOPSIS

mx-run ThisPackageName [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

Adds a column called 'create_date' to the stock, project, genotype, phenotype, and nd_protocol tables. this column is set to DEFAULT NOW() when an entry is created. This is useful for creating reports of which project, stocks, phenotypes, etc were added over different time periods.

This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR


=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddTimestampToNdTables;

use Moose;
use Try::Tiny;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
Adds a column called 'create_date' to the nd_experiment, stock, project, genotype, phenotype, and nd_protocol tables. this column is set to DEFAULT NOW() when an entry is created. This is useful for creating reports of which project, stocks, phenotypes, etc were added over different time periods.

sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";


    try {
        $self->dbh->do(<<EOSQL);
ALTER TABLE nd_experiment ADD COLUMN create_date TIMESTAMP;
ALTER TABLE nd_experiment ALTER COLUMN create_date SET DEFAULT now();
EOSQL
    }
    catch {
        print STDOUT "nd_experiment already had create_date\n";
    };

    try {
        $self->dbh->do(<<EOSQL);
ALTER TABLE stock ADD COLUMN create_date TIMESTAMP;
ALTER TABLE stock ALTER COLUMN create_date SET DEFAULT now();
EOSQL
    }
    catch {
        print STDOUT "stock already had create_date\n";
    };

    try {
        $self->dbh->do(<<EOSQL);
ALTER TABLE project ADD COLUMN create_date TIMESTAMP;
ALTER TABLE project ALTER COLUMN create_date SET DEFAULT now();
EOSQL
    }
    catch {
        print STDOUT "project already had create_date\n";
    };

    try {
        $self->dbh->do(<<EOSQL);
ALTER TABLE phenotype ADD COLUMN create_date TIMESTAMP;
ALTER TABLE phenotype ALTER COLUMN create_date SET DEFAULT now();
EOSQL
    }
    catch {
        print STDOUT "phenotype already had create_date\n";
    };

    try {
        $self->dbh->do(<<EOSQL);
ALTER TABLE genotype ADD COLUMN create_date TIMESTAMP;
ALTER TABLE genotype ALTER COLUMN create_date SET DEFAULT now();
EOSQL
    }
    catch {
        print STDOUT "genotype already had create_date\n";
    };

    try {
        $self->dbh->do(<<EOSQL);
ALTER TABLE nd_protocol ADD COLUMN create_date TIMESTAMP;
ALTER TABLE nd_protocol ALTER COLUMN create_date SET DEFAULT now();
EOSQL
    }
    catch {
        print STDOUT "nd_protocol already had create_date\n";
    };

    try {
        $self->dbh->do(<<EOSQL);
ALTER TABLE stock_relationship ADD COLUMN create_date TIMESTAMP;
ALTER TABLE stock_relationship ALTER COLUMN create_date SET DEFAULT now();
EOSQL
    }
    catch {
        print STDOUT "stock_relationship already had create_date\n";
    };

    try {
        $self->dbh->do(<<EOSQL);
ALTER TABLE project_relationship ADD COLUMN create_date TIMESTAMP;
ALTER TABLE project_relationship ALTER COLUMN create_date SET DEFAULT now();
EOSQL
    }
    catch {
        print STDOUT "project_relationship already had create_date\n";
    };

print "You're done!\n";
}


####
1; #
####
