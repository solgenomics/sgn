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
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This is a patch to migrate to phenotype value storage to a simpler/faster system using nd_experiment_phenotype_bridge.

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

# Legacy Upload date either: 2020-07-30_16:24:00 or 2013/4/9
# Actual phenotypic timestamp in collect_date in phenotype table

    my $schema = Bio::Chado::Schema->connect( sub { $self->dbh->clone } );
    #$self->dbh->do();

    my $nd_experiment_phenotype_bridge_q = "INSERT INTO nd_experiment_phenotype_bridge (stock_id, project_id, phenotype_id, nd_geolocation_id, file_id, image_id, json_id, upload_date) VALUES (?, ?, ?, ?, ?, ?, ?, ?);";
    my $nd_experiment_phenotype_bridge_dbh = $self->bcs_schema->storage->dbh()->prepare($nd_experiment_phenotype_bridge_q);

    my $phenotyping_experiment_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'phenotyping_experiment', 'experiment_type')->cvterm_id();
    my $local_date_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'date', 'local')->cvterm_id();
    my $local_operator_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'operator', 'local')->cvterm_id();

    my $q = "SELECT nd_experiment_id, phenotype_id, stock_id, project_id, nd_geolocation_id, file_id, image_id, json_id, upload_date.value
        FROM phenotype
        JOIN nd_experiment_phenotype USING(phenotype_id)
        JOIN nd_experiment_stock USING(nd_experiment_id)
        JOIN nd_experiment_project USING(nd_experiment_id)
        JOIN nd_experiment USING(nd_experiment_id)
        JOIN nd_experimentprop AS upload_date ON(upload_date.nd_experiment_id=nd_experiment.nd_experiment_id AND upload_date.type_id=$local_date_cvterm_id)
        LEFT JOIN phenome.nd_experiment_md_files USING(nd_experiment_id)
        LEFT JOIN phenome.nd_experiment_md_images USING(nd_experiment_id)
        LEFT JOIN phenome.nd_experiment_md_json USING(nd_experiment_id)
        WHERE nd_experiment.type_id=$phenotyping_experiment_cvterm_id;";

    my $h = $self->dbh()->prepare($q);
    $h->execute();
    my @seen_nd_experiment_ids;
    while (my ($nd_experiment_id, $phenotype_id, $stock_id, $project_id, $nd_geolocation_id, $file_id, $image_id, $json_id, $upload_date) = $h->fetchrow_array()) {
        print STDERR $upload_date;
        #$nd_experiment_phenotype_bridge_dbh->execute($stock_id, $project_id, $phenotype_id, $nd_geolocation_id, $file_id, $image_id, $json_id, $upload_date_formatted);
        push @seen_nd_experiment_ids, $nd_experiment_id;
    }

print "You're done!\n";
}


####
1; #
####
