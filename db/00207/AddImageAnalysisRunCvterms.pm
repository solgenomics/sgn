#!/usr/bin/env perl

=head1 NAME

AddImageAnalysisRunCvterms

=head1 SYNOPSIS

mx-run AddImageAnalysisRunCvterms [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION
This patch adds cvterms required for image analysis run projects,
including project properties, project relationships, experiment types,
nd_experiment_stock types, and image linking types.
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

package AddImageAnalysisRunCvterms;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;
extends 'CXGN::Metadata::Dbpatch';

has '+description' => ( default => <<'' );
This patch adds cvterms required for image analysis run projects

has '+prereq' => (
    default => sub {
        [],
    },
);

sub patch {
    my $self = shift;

    print STDOUT "Executing the patch:\n " .
        $self->name . ".\n\nDescription:\n  " .
        $self->description . ".\n\nExecuted by:\n " .
        $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before " .
        "or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    my $schema = Bio::Chado::Schema->connect(
        sub { $self->dbh->clone }
    );

    print STDERR "INSERTING CV TERMS...\n";

    my $terms = {
        'project_property' => [
            'image_analysis_run_project_type',
            'image_analysis_run_parameters_json',
            'image_analysis_job_id',
            'image_analysis_pipeline_name',
            'image_analysis_pipeline_version',
            'image_analysis_run_timestamp',
            'image_analysis_input_filename',
            'image_analysis_qc_json',
            'image_analysis_traits_emitted_json',
            'image_analysis_raw_result_json',
            'image_analysis_image_stock_map_json'
        ],
        'project_relationship' => [

            'image_analysis_run_on_field_trial',
        ],

        'experiment_type' => [

            'image_analysis_experiment',
        ],

        'nd_experiment_stock_type' => [

            'image_analysis_source_stock',
            'image_analysis_tissue_sample',
        ],
        'project_md_image' => [

            'image_analysis_source_image',
            'image_analysis_result_overlay',
        ],

        'stock_md_image' => [
            'image_analysis_tissue_sample_result_image',
        ],
        
        'stock_property' => [
            'image_analysis_object_metadata_json',
        ]

    };

    foreach my $cv_name (keys %$terms) {
        foreach my $term_name (@{ $terms->{$cv_name} }) {
            try {
                $schema->resultset("Cv::Cvterm")->create_with({
                    name => $term_name,
                    cv   => $cv_name,
                });
                print STDERR "Created cvterm: $term_name " .
                    "in cv: $cv_name\n";
            } catch {
                print STDERR "Could not create cvterm " .
                    "$term_name in cv $cv_name: $_\n";
            };
        }
    }

    print "You're done!\n";
}

####
1; #
####