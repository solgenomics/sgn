#!/usr/bin/env perl


=head1 NAME

AddJobsTable.pm

=head1 SYNOPSIS

mx-run AddJobsTable.pm [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This DB patch adds an sp_job table to sgn_people. This table tracks background job submissions.
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

Ryan Preble <rsp98@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2025 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddJobsTable;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;

extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
Adds sp_job table to sgn_people for slurm job tracking

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

    my $schema = Bio::Chado::Schema->connect( sub { $self->dbh->clone } );

    my $terms = {
        'job_type' => [
            ['download','A background job downloading data from the server'],
            ['upload', 'A background job uploading data to the server'],
            # 'pca_analysis',
            # 'kinship_analysis',
            ['tool_compatibility','A background job for determining which analysis tools can be used on a dataset'],
            # 'cluster_analysis',
            # 'correlation_analysis',
            # 'training_dataset',
            # 'training_model',
            # 'training_prediction',
            # 'anova_analysis',
            # 'heritability_analysis',
            # 'stability_analysis',
            # 'blastn',
            # 'blastp',
            # 'blastx',
            # 'tblastn',
            # 'tblastx',
            ['phenotypic_analysis','Any analysis done on phenotypes, such as calculating adjusted means. Includes phenotypic correlation, trait stability, heritability, etc'],
            ['genotypic_analysis','Any analysis using genotypic data, such as GWAS or genotype clustering'],
            ['genomic_prediction','Any analysis to predict breeding value or phenotype from genomic data, such as solGS'],
            ['sequence_analysis','Any BLAST analysis or other analysis using sequence alignments']
        ]
    };

    foreach my $cv (keys %$terms){
        foreach my $term (@{$terms->{$cv}}){
            $schema->resultset("Cv::Cvterm")->create_with({
                name => $term->[0],
                cv => $cv,
                definition => $term->[1]
            });
        }
    }

    $self->dbh->do(<<EOSQL);
CREATE TABLE sgn_people.sp_job(
    sp_job_id SERIAL PRIMARY KEY,
    sp_person_id BIGINT REFERENCES sgn_people.sp_person,
    backend_id VARCHAR(255) NOT NULL,
    status VARCHAR(100),
    create_timestamp VARCHAR(100) NOT NULL,
    finish_timestamp VARCHAR(100), 
    type_id BIGINT REFERENCES public.cvterm,
    args JSONB
);

EOSQL

    print "You're done!\n";
}


####
1; #
####
