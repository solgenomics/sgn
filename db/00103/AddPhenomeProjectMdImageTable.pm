#!/usr/bin/env perl


=head1 NAME

 AddPhenomeProjectMdImageTable

=head1 SYNOPSIS

mx-run AddPhenomeProjectMdImageTable [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION
This patch adds a linking table called project_md_image to the phenome schema, which links project to metadata.md_image
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR


=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddPhenomeProjectMdImageTable;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;
use SGN::Model::Cvterm;
use JSON;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch adds a linking table called project_md_image to the phenome schema, which links project to metadata.md_image

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
        'project_md_image' => [
            'raw_drone_imagery',
            'stitched_drone_imagery',
            'denoised_stitched_drone_imagery',
            'cropped_stitched_drone_imagery',
            'fourier_transform_stitched_drone_imagery'
        ],
        'project_property' => [
            'project_start_date'
        ],
        'project_relationship' => [
            'drone_run_on_field_trial'
        ]
    };

    foreach my $t (keys %$terms){
        foreach (@{$terms->{$t}}){
            $schema->resultset("Cv::Cvterm")->create_with({
                name => $_,
                cv => $t
            });
        }
    }

    my $coderef = sub {
        my $sql = <<SQL;
CREATE TABLE if not exists phenome.project_md_image (
    project_md_image_id serial PRIMARY KEY,
    project_id integer NOT NULL,
    image_id integer NOT NULL,
    type_id integer NOT NULL,
    constraint project_md_image_project_id_fkey FOREIGN KEY (project_id) REFERENCES project (project_id) MATCH SIMPLE ON UPDATE NO ACTION ON DELETE NO ACTION,
    constraint project_md_image_image_id_fkey FOREIGN KEY (image_id) REFERENCES metadata.md_image (image_id) MATCH SIMPLE ON UPDATE NO ACTION ON DELETE NO ACTION,
    constraint project_md_image_type_id_fkey FOREIGN KEY (type_id) REFERENCES cvterm (cvterm_id) MATCH SIMPLE ON UPDATE NO ACTION ON DELETE NO ACTION
);
SQL
        $schema->storage->dbh->do($sql);
    };

    my $transaction_error;
    try {
        $schema->txn_do($coderef);
    } catch {
        $transaction_error =  $_;
    };
    if ($transaction_error){
        print STDERR "ERROR: $transaction_error\n";
    } else {
        print "You're done!\n";
    }
}


####
1; #
####
