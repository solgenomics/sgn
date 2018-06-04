#!/usr/bin/env perl

=head1 NAME

PhenotypeTableMaterializedView.pm

=head1 SYNOPSIS

mx-run PhenotypeTableMaterializedView [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch creates a materialized view for all stockprops

=head1 AUTHOR



=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package PhenotypeTableMaterializedView;

use Moose;
use SGN::Model::Cvterm;
use Bio::Chado::Schema;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch creates/updates a materialized view for phenotypes in the traditional table format.

sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    my $schema = Bio::Chado::Schema->connect( sub { $self->dbh->clone } );

    my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $rep_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'replicate', 'stock_property')->cvterm_id();
    my $block_number_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'block', 'stock_property')->cvterm_id();
    my $plot_number_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot number', 'stock_property')->cvterm_id();
    my $row_number_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'row_number', 'stock_property')->cvterm_id();
    my $col_number_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'col_number', 'stock_property')->cvterm_id();
    my $year_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project year', 'project_property')->cvterm_id();
    my $design_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'design', 'project_property')->cvterm_id();
    my $planting_date_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project_planting_date', 'project_property')->cvterm_id();
    my $havest_date_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project_harvest_date', 'project_property')->cvterm_id();
    my $project_location_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project location', 'project_property')->cvterm_id();
    my $plot_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id();
    my $plant_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plant', 'stock_type')->cvterm_id();
    my $subplot_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'subplot', 'stock_type')->cvterm_id();
    my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $phenotype_outlier_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'phenotype_outlier', 'phenotype_property')->cvterm_id();
    my $breeding_program_rel_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'breeding_program_trial_relationship', 'project_relationship')->cvterm_id();

    my $cast_cols = '"observationunit_stock_id" int, "observationunit_uniquename" text, "observationunit_type_name" text, "germplasm_uniquename" text, "germplasm_stock_id" text, "rep" text, "block" text, "plot_number" text, "row_number" text, "col_number" text, "phenotype_location_id" int, "phenotype_location_name" text, "trial_id" int, "trial_name" text, "breeding_program_id" int, "breeding_program_name" text, "year" text, "design" text, "location_id" text, "planting_date" text, "harvest_date" text';

    my $q = 'SELECT distinct(phenotype.cvalue_id)
    FROM phenotype
    JOIN nd_experiment_phenotype USING(phenotype_id)
    JOIN nd_experiment USING(nd_experiment_id)
    JOIN nd_experiment_stock USING(nd_experiment_id)
    JOIN stock AS observationunit USING(stock_id)
    JOIN cvterm ON (phenotype.cvalue_id=cvterm.cvterm_id)
    JOIN dbxref ON (cvterm.dbxref_id = dbxref.dbxref_id)
    JOIN db USING(db_id)
    JOIN nd_experiment_project USING(nd_experiment_id)
    JOIN project USING(project_id)
    ORDER by phenotype.cvalue_id ASC';
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute();
    my @trait_ids;
    while (my ($type_id) = $h->fetchrow_array()){
        push @trait_ids, $type_id;
        $cast_cols = $cast_cols . ', "'.$type_id.'" jsonb';
    }
    my $type_cols = join '\'\'),(\'\'', @trait_ids;
    $type_cols = '(\'\'' . $type_cols . '\'\')';

    $self->dbh->do(<<EOSQL);
--do your SQL here

DROP EXTENSION IF EXISTS tablefunc CASCADE;
CREATE EXTENSION tablefunc;

DROP MATERIALIZED VIEW IF EXISTS public.materialized_phenotype_table CASCADE;
CREATE MATERIALIZED VIEW public.materialized_phenotype_table AS
SELECT *
FROM crosstab(
    'SELECT observationunit.stock_id, observationunit.uniquename, observationunit_cvterm.name, germplasm.uniquename, germplasm.stock_id, rep.value, block_number.value, plot_number.value, row_number.value, col_number.value, nd_geolocation.nd_geolocation_id, nd_geolocation.description, project.project_id, project.name, breeding_program.project_id, breeding_program.name, year.value, design.value, location_id.value, planting_date.value, harvest_date.value, phenotype.cvalue_id, jsonb_object_agg(phenotype.value, json_build_array(phenotype.phenotype_id, outlier.value, phenotype.uniquename))
    FROM phenotype
    JOIN nd_experiment_phenotype USING(phenotype_id)
    JOIN nd_experiment USING(nd_experiment_id)
    JOIN nd_geolocation USING(nd_geolocation_id)
    JOIN nd_experiment_stock USING(nd_experiment_id)
    JOIN stock AS observationunit USING(stock_id)
    JOIN cvterm AS observationunit_cvterm ON(observationunit.type_id=observationunit_cvterm.cvterm_id)
    JOIN stock_relationship ON(observationunit.stock_id=stock_relationship.subject_id)
    JOIN stock AS germplasm ON(stock_relationship.object_id=germplasm.stock_id AND germplasm.type_id = $accession_type_id)
    LEFT JOIN stockprop AS rep ON (observationunit.stock_id=rep.stock_id AND rep.type_id = $rep_type_id)
    LEFT JOIN stockprop AS block_number ON (observationunit.stock_id=block_number.stock_id AND block_number.type_id = $block_number_type_id)
    LEFT JOIN stockprop AS plot_number ON (observationunit.stock_id=plot_number.stock_id AND plot_number.type_id = $plot_number_type_id)
    LEFT JOIN stockprop AS row_number ON (observationunit.stock_id=row_number.stock_id AND row_number.type_id = $row_number_type_id)
    LEFT JOIN stockprop AS col_number ON (observationunit.stock_id=col_number.stock_id AND col_number.type_id = $col_number_type_id)
    LEFT JOIN phenotypeprop AS outlier ON (phenotype.phenotype_id=outlier.phenotype_id AND outlier.type_id = $phenotype_outlier_type_id)
    JOIN cvterm ON (phenotype.cvalue_id=cvterm.cvterm_id)
    JOIN dbxref ON (cvterm.dbxref_id = dbxref.dbxref_id)
    JOIN db USING(db_id)
    JOIN nd_experiment_project USING(nd_experiment_id)
    JOIN project USING(project_id)
    JOIN project_relationship ON (project.project_id=project_relationship.subject_project_id AND project_relationship.type_id=$breeding_program_rel_type_id)
    JOIN project as breeding_program on (breeding_program.project_id=project_relationship.object_project_id)
    LEFT JOIN projectprop as year ON (project.project_id=year.project_id AND year.type_id = $year_type_id)
    LEFT JOIN projectprop as design ON (project.project_id=design.project_id AND design.type_id = $design_type_id)
    LEFT JOIN projectprop as location_id ON (project.project_id=location_id.project_id AND location_id.type_id = $project_location_type_id)
    LEFT JOIN projectprop as planting_date ON (project.project_id=planting_date.project_id AND planting_date.type_id = $planting_date_type_id)
    LEFT JOIN projectprop as harvest_date ON (project.project_id=harvest_date.project_id AND harvest_date.type_id = $havest_date_type_id)
    WHERE phenotype.value IS NOT NULL
    GROUP BY (observationunit.stock_id, observationunit.uniquename, observationunit_cvterm.name, germplasm.uniquename, germplasm.stock_id, rep.value, block_number.value, plot_number.value, row_number.value, col_number.value, nd_geolocation.nd_geolocation_id, nd_geolocation.description, project.project_id, project.name, breeding_program.project_id, breeding_program.name, year.value, design.value, location_id.value, planting_date.value, harvest_date.value, phenotype.cvalue_id)
    ORDER by observationunit.stock_id ASC',
    'SELECT type_id FROM (VALUES $type_cols) AS t (type_id);'
)
AS ($cast_cols);

CREATE UNIQUE INDEX materialized_phenotype_table_stock_idx ON public.materialized_phenotype_table(observationunit_stock_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.materialized_phenotype_table OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.refresh_materialized_phenotype_table() RETURNS VOID AS '
REFRESH MATERIALIZED VIEW public.materialized_phenotype_table;'
    LANGUAGE SQL;

ALTER FUNCTION public.refresh_materialized_phenotype_table() OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.refresh_materialized_phenotype_table_concurrently() RETURNS VOID AS '
REFRESH MATERIALIZED VIEW CONCURRENTLY public.materialized_phenotype_table;'
    LANGUAGE SQL;

ALTER FUNCTION public.refresh_materialized_phenotype_table_concurrently() OWNER TO web_usr;
--

EOSQL

print "You're done!\n";
}


####
1; #
####
