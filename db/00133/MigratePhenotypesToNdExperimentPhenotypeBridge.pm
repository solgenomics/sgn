#!/usr/bin/env perl


=head1 NAME

 MigratePhenotypesToNdExperimentPhenotypeBridge.pm

=head1 SYNOPSIS

mx-run ThisPackageName [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This is a patch to migrate to phenotype value storage to a simpler/faster system using nd_experiment_phenotype_bridge.
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR


=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package MigratePhenotypesToNdExperimentPhenotypeBridge;

use Moose;
use Bio::Chado::Schema;
use SGN::Model::Cvterm;
use Time::Piece;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This is a patch to migrate to phenotype value storage to a simpler/faster system using nd_experiment_phenotype_bridge.

has '+prereq' => (
    default => sub {
        ['AddNdExperimentPhenotypeBridge'],
    },
  );

sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

# Legacy Upload date either: 2020-07-30_16:24:00 or 2013/4/9
# Actual phenotypic timestamp in collect_date in phenotype table

    my $schema = Bio::Chado::Schema->connect( sub { $self->dbh->clone } );
    #$self->dbh->do();

    my $nd_experiment_phenotype_bridge_q = "INSERT INTO nd_experiment_phenotype_bridge (stock_id, project_id, phenotype_id, nd_geolocation_id, file_id, image_id, json_id, upload_date) VALUES (?, ?, ?, ?, ?, ?, ?, ?);";
    my $nd_experiment_phenotype_bridge_dbh = $schema->storage->dbh()->prepare($nd_experiment_phenotype_bridge_q);

    my $phenotyping_experiment_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'phenotyping_experiment', 'experiment_type')->cvterm_id();
    my $local_date_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'date', 'local')->cvterm_id();
    my $local_operator_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'operator', 'local')->cvterm_id();

    my $q = "SELECT nd_experiment.nd_experiment_id, phenotype.phenotype_id, stock.stock_id, nd_experiment_project.project_id, nd_experiment.nd_geolocation_id, file_id, image_id, json_id, upload_date.value, md_files.nd_experiment_md_files_id, md_images.nd_experiment_md_images_id, md_json.nd_experiment_md_json_id
        FROM stock
        JOIN nd_experiment_stock ON(nd_experiment_stock.stock_id=stock.stock_id)
        JOIN nd_experiment ON(nd_experiment_stock.nd_experiment_id=nd_experiment.nd_experiment_id)
        JOIN nd_experimentprop AS upload_date ON(upload_date.nd_experiment_id=nd_experiment.nd_experiment_id AND upload_date.type_id=$local_date_cvterm_id)
        JOIN nd_experiment_project ON(nd_experiment_project.nd_experiment_id=nd_experiment.nd_experiment_id)
        LEFT JOIN nd_experiment_phenotype ON(nd_experiment_phenotype.nd_experiment_id=nd_experiment.nd_experiment_id)
        LEFT JOIN phenotype ON(phenotype.phenotype_id=nd_experiment_phenotype.phenotype_id)
        LEFT JOIN phenome.nd_experiment_md_files AS md_files ON(md_files.nd_experiment_id=nd_experiment.nd_experiment_id)
        LEFT JOIN phenome.nd_experiment_md_images AS md_images ON(md_images.nd_experiment_id=nd_experiment.nd_experiment_id)
        LEFT JOIN phenome.nd_experiment_md_json AS md_json ON(md_json.nd_experiment_id=nd_experiment.nd_experiment_id)
        WHERE nd_experiment.type_id=$phenotyping_experiment_cvterm_id;";

    my $h = $self->dbh()->prepare($q);
    $h->execute();

    my $del_nd_q = "DELETE FROM nd_experiment WHERE nd_experiment_id = ?;";
    my $del_nd_h = $self->dbh()->prepare($del_nd_q);

    my $del_nd_files_q = "DELETE FROM phenome.nd_experiment_md_files WHERE nd_experiment_md_files_id = ?;";
    my $del_nd_files_h = $self->dbh()->prepare($del_nd_files_q);

    my $del_nd_images_q = "DELETE FROM phenome.nd_experiment_md_images WHERE nd_experiment_md_images_id = ?;";
    my $del_nd_images_h = $self->dbh()->prepare($del_nd_images_q);

    my $del_nd_json_q = "DELETE FROM phenome.nd_experiment_md_json WHERE nd_experiment_md_json_id = ?;";
    my $del_nd_json_h = $self->dbh()->prepare($del_nd_json_q);

    #VERIFY that the file_id is actually present in metadata table otherwise it will trigger a constraint failure
    my $verify_nd_files_q = "SELECT file_id FROM metadata.md_files WHERE file_id = ?;";
    my $verify_nd_files_h = $self->dbh()->prepare($verify_nd_files_q);
    my $verify_nd_images_q = "SELECT image_id FROM metadata.md_image WHERE image_id = ?;";
    my $verify_nd_images_h = $self->dbh()->prepare($verify_nd_images_q);
    my $verify_nd_json_q = "SELECT json_id FROM metadata.md_json WHERE json_id = ?;";
    my $verify_nd_json_h = $self->dbh()->prepare($verify_nd_json_q);

    my %unique_nd_experiment_ids;
    my @deleted_nd_experiment_ids;
    my @deleted_nd_experiment_md_files_ids;
    my @deleted_nd_experiment_md_images_ids;
    my @deleted_nd_experiment_md_json_ids;
    while (my ($nd_experiment_id, $phenotype_id, $stock_id, $project_id, $nd_geolocation_id, $file_id, $image_id, $json_id, $upload_date, $nd_experiment_md_files_id, $nd_experiment_md_images_id, $nd_experiment_md_json_id) = $h->fetchrow_array()) {
        my $phenotype_id_string = $phenotype_id ? $phenotype_id : '';
        print STDERR "Working on phenotype_id $phenotype_id_string \n";
        if ($upload_date =~ m/(\d{4})-(\d{2})-(\d{2})_(\d{2}):(\d{2}):(\d{2})/) {
            my $upload_date_obj = Time::Piece->strptime($upload_date, "%Y-%m-%d_%H:%M:%S");
            $upload_date = $upload_date_obj->strftime("%Y-%m-%d_%H:%M:%S");
        }
        elsif ($upload_date =~ m/(\d{4})\/(\d{2})\/(\d{2})/ || $upload_date =~ m/(\d{4})\/(\d{1})\/(\d{1})/ || $upload_date =~ m/(\d{4})\/(\d{1})\/(\d{2})/ || $upload_date =~ m/(\d{4})\/(\d{2})\/(\d{1})/) {
            my $upload_date_obj = Time::Piece->strptime($upload_date, "%Y/%m/%d_%H:%M:%S");
            $upload_date = $upload_date_obj->strftime("%Y-%m-%d_%H:%M:%S");
        }
        else {
            die "Upload date format not accounted for $upload_date\n";
        }

        if ($nd_experiment_md_files_id) {
            $del_nd_files_h->execute($nd_experiment_md_files_id);
            push @deleted_nd_experiment_md_files_ids, $nd_experiment_md_files_id;

            $verify_nd_files_h->execute($file_id);
            my ($file_id_verify) = $verify_nd_files_h->fetchrow_array();
            if (!$file_id_verify) {
                $file_id = undef;
            }
        }
        if ($nd_experiment_md_images_id) {
            $del_nd_images_h->execute($nd_experiment_md_images_id);
            push @deleted_nd_experiment_md_images_ids, $nd_experiment_md_images_id;

            $verify_nd_images_h->execute($image_id);
            my ($image_id_verify) = $verify_nd_images_h->fetchrow_array();
            if (!$image_id_verify) {
                $image_id = undef;
            }
        }
        if ($nd_experiment_md_json_id) {
            $del_nd_json_h->execute($nd_experiment_md_json_id);
            push @deleted_nd_experiment_md_json_ids, $nd_experiment_md_json_id;

            $verify_nd_json_h->execute($json_id);
            my ($json_id_verify) = $verify_nd_json_h->fetchrow_array();
            if (!$json_id_verify) {
                $json_id = undef;
            }
        }

        $nd_experiment_phenotype_bridge_dbh->execute($stock_id, $project_id, $phenotype_id, $nd_geolocation_id, $file_id, $image_id, $json_id, $upload_date);

        $unique_nd_experiment_ids{$nd_experiment_id}++;
        push @deleted_nd_experiment_ids, $nd_experiment_id;
    }

    foreach (keys %unique_nd_experiment_ids) {
        $del_nd_h->execute($_);
        print STDERR "MIGRATED nd_experiment $_\n";
    }

    print STDERR "DELETED ".scalar(keys %unique_nd_experiment_ids)." unique nd_experiment\n";
    print STDERR "DELETED ".scalar(@deleted_nd_experiment_ids)." nd_experiment_* links\n";
    print STDERR "DELETED ".scalar(@deleted_nd_experiment_md_files_ids)." nd_experiment_md_files\n";
    print STDERR "DELETED ".scalar(@deleted_nd_experiment_md_images_ids)." nd_experiment_md_images\n";
    print STDERR "DELETED ".scalar(@deleted_nd_experiment_md_json_ids)." nd_experiment_md_json\n";

print "You're done!\n";
}


####
1; #
####
