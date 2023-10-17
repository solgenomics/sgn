#!/usr/bin/env perl


=head1 NAME

 AddEarthSenseCollectionsCvterms

=head1 SYNOPSIS

mx-run AddEarthSenseCollectionsCvterms [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION
This patch adds cvterms for saving EarthSense ground rover collection data
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR


=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddEarthSenseCollectionsCvterms;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;
use SGN::Model::Cvterm;

extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch adds cvterms for EarthSense ground rover collection data

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


    print STDERR "INSERTING CV TERMS...\n";

    my $terms = {
        'project_property' => [
            'earthsense_ground_rover_collections_archived',
            'earthsense_collection_number'
        ],
        'project_md_image' => [
            'rover_event_original_points_image',
            'rover_event_points_filtered_height_image',
            'rover_event_points_filtered_side_span_image',
            'rover_event_points_filtered_side_height_image'
        ],
        'project_md_file' => [
            'rover_collection_filtered_plot_point_cloud'
        ],
        'stock_md_file' => [
            'stock_filtered_plot_point_cloud'
        ],
        'experiment_type' => [
            'field_trial_drone_runs_in_same_rover_event'
        ],
        'project_relationship' => [
            'drone_run_collection_on_drone_run'
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

ALTER TABLE nd_experiment_phenotype_bridge
ADD COLUMN stock_file_id bigint REFERENCES metadata.md_files (file_id) ON DELETE SET NULL;
CREATE INDEX nd_experiment_phenotype_bridge_stock_file_idx1 ON nd_experiment_phenotype_bridge USING btree (stock_file_id);

CREATE TABLE if not exists phenome.project_md_file (
    project_md_file_id serial PRIMARY KEY,
    project_id integer NOT NULL,
    file_id integer NOT NULL,
    type_id integer NOT NULL,
    constraint project_md_file_project_id_fkey FOREIGN KEY (project_id) REFERENCES project (project_id) MATCH SIMPLE ON UPDATE NO ACTION ON DELETE NO ACTION,
    constraint project_md_file_file_id_fkey FOREIGN KEY (file_id) REFERENCES metadata.md_files (file_id) MATCH SIMPLE ON UPDATE NO ACTION ON DELETE NO ACTION,
    constraint project_md_file_type_id_fkey FOREIGN KEY (type_id) REFERENCES cvterm (cvterm_id) MATCH SIMPLE ON UPDATE NO ACTION ON DELETE NO ACTION
);
grant select,insert,delete on table phenome.project_md_file to web_usr;
grant usage on phenome.project_md_file_project_md_file_id_seq to web_usr;

CREATE TABLE if not exists phenome.stock_md_file (
    stock_md_file_id serial PRIMARY KEY,
    stock_id integer NOT NULL,
    file_id integer NOT NULL,
    type_id integer NOT NULL,
    constraint stock_md_file_project_id_fkey FOREIGN KEY (stock_id) REFERENCES stock (stock_id) MATCH SIMPLE ON UPDATE NO ACTION ON DELETE NO ACTION,
    constraint stock_md_file_file_id_fkey FOREIGN KEY (file_id) REFERENCES metadata.md_files (file_id) MATCH SIMPLE ON UPDATE NO ACTION ON DELETE NO ACTION,
    constraint stock_md_file_type_id_fkey FOREIGN KEY (type_id) REFERENCES cvterm (cvterm_id) MATCH SIMPLE ON UPDATE NO ACTION ON DELETE NO ACTION
);
grant select,insert,delete on table phenome.stock_md_file to web_usr;
grant usage on phenome.stock_md_file_stock_md_file_id_seq to web_usr;

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
