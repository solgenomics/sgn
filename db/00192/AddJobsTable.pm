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
Adds sp_job table to sgn_people for submitted job tracking

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
            'download',
            'upload',
            'report',
            'search',
            'cluster_analysis',
            'kinship_analysis',
            'heritability_analysis',
            'solGWAS_analysis',
            'spatial_analysis',
            'pca_analysis',
            'stability_analysis',
            'mixed_model_analysis',
            'nirs_analysis',
            'tool_compatibility',
            'genomic_prediction',
            'sequence_analysis',
        ]
    };

    foreach my $cv (keys %$terms){
        foreach my $term (@{$terms->{$cv}}){
            $schema->resultset("Cv::Cvterm")->create_with({
                name => $term,
                cv => $cv,
            });
        }
    }

    #my $dbuser = `cat /home/production/volume/cxgn/sgn/sgn_local.conf | grep dbuser | sed -r 's/\w+\s//'`;
    my $dbuser = 'web_usr';

    $self->dbh->do(<<EOSQL);
CREATE TABLE sgn_people.sp_job(
    sp_job_id SERIAL PRIMARY KEY,
    sp_person_id BIGINT REFERENCES sgn_people.sp_person,
    backend_id VARCHAR(255),
    status VARCHAR(100),
    create_timestamp TIMESTAMPTZ(0) DEFAULT NOW(),
    finish_timestamp TIMESTAMPTZ(0), 
    type_id BIGINT REFERENCES public.cvterm,
    args JSONB
);

GRANT SELECT,UPDATE,DELETE,INSERT ON sgn_people.sp_job TO $dbuser ;

GRANT USAGE ON SEQUENCE sgn_people.sp_job_sp_job_id_seq TO $dbuser ;

EOSQL

    print "You're done!\n";
}


####
1; #
####
