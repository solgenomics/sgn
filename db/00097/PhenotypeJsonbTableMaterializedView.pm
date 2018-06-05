#!/usr/bin/env perl

=head1 NAME

PhenotypeJsonbTableMaterializedView.pm

=head1 SYNOPSIS

mx-run PhenotypeJsonbTableMaterializedView [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch creates a materialized view for phenotypes in a table where rows are observation units and a column called observations has all observations in a jsonb object

=head1 AUTHOR



=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package PhenotypeJsonbTableMaterializedView;

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

    my $rep_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'replicate', 'stock_property')->cvterm_id();
    my $block_number_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'block', 'stock_property')->cvterm_id();
    my $plot_number_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot number', 'stock_property')->cvterm_id();
    my $plant_number_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plant_index_number', 'stock_property')->cvterm_id();
    my $row_number_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'row_number', 'stock_property')->cvterm_id();
    my $col_number_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'col_number', 'stock_property')->cvterm_id();
    my $is_a_control_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'is a control', 'stock_property')->cvterm_id();
    my $year_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project year', 'project_property')->cvterm_id();
    my $design_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'design', 'project_property')->cvterm_id();
    my $planting_date_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project_planting_date', 'project_property')->cvterm_id();
    my $havest_date_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project_harvest_date', 'project_property')->cvterm_id();
    my $project_location_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project location', 'project_property')->cvterm_id();
    my $plot_width_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot_width', 'project_property')->cvterm_id();
    my $plot_length_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot_length', 'project_property')->cvterm_id();
    my $field_size_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'field_size', 'project_property')->cvterm_id();
    my $field_trial_is_planned_to_be_genotyped_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'field_trial_is_planned_to_be_genotyped', 'project_property')->cvterm_id();
    my $field_trial_is_planned_to_cross_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'field_trial_is_planned_to_cross', 'project_property')->cvterm_id();
    my $plot_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id();
    my $plant_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plant', 'stock_type')->cvterm_id();
    my $subplot_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'subplot', 'stock_type')->cvterm_id();
    my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $phenotype_outlier_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'phenotype_outlier', 'phenotype_property')->cvterm_id();
    my $breeding_program_rel_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'breeding_program_trial_relationship', 'project_relationship')->cvterm_id();
    my $treatment_rel_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'trial_treatment_relationship', 'project_relationship')->cvterm_id();
    my $folder_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'trial_folder', 'project_property')->cvterm_id();

    $self->dbh->do(<<EOSQL);
--do your SQL here

DROP MATERIALIZED VIEW IF EXISTS public.materialized_phenotype_jsonb_table CASCADE;
CREATE MATERIALIZED VIEW public.materialized_phenotype_jsonb_table AS
SELECT observationunit.stock_id AS observationunit_stock_id, observationunit.uniquename AS observationunit_uniquename, observationunit_cvterm.name AS observationunit_type_name, germplasm.uniquename AS germplasm_uniquename, germplasm.stock_id AS germplasm_stock_id, rep.value AS rep, block_number.value AS block, plot_number.value AS plot_number, row_number.value AS row_number, col_number.value AS col_number, plant_number.value AS plant_number, is_a_control.value AS is_a_control, project.project_id AS trial_id, project.name AS trial_name, project.description AS trial_description, plot_width.value AS plot_width, plot_length.value AS plot_length, field_size.value AS field_size, field_trial_is_planned_to_be_genotyped.value AS field_trial_is_planned_to_be_genotyped, field_trial_is_planned_to_cross.value AS field_trial_is_planned_to_cross, breeding_program.project_id AS breeding_program_id, breeding_program.name AS breeding_program_name, breeding_program.description AS breeding_program_description, year.value AS year, design.value AS design, location_id.value AS location_id, planting_date.value AS planting_date, harvest_date.value AS harvest_date, folder.project_id AS folder_id, folder.name AS folder_name, folder.description AS folder_description,
    jsonb_object_agg(coalesce(
    case
        when (treatment.name) IS NULL then null
        else (treatment.name)
    end,
    'No ManagementFactor'), treatment.description) AS treatments,
    jsonb_agg(jsonb_build_object('trait_id', phenotype.cvalue_id, 'trait_name', (((cvterm.name::text || '|'::text) || db.name::text) || ':'::text) || dbxref.accession::text, 'value', phenotype.value, 'phenotype_id', phenotype.phenotype_id, 'outlier', outlier.value, 'create_date', phenotype.create_date, 'uniquename', phenotype.uniquename, 'phenotype_location_id', nd_geolocation.nd_geolocation_id, 'phenotype_location_name', nd_geolocation.description)) AS observations
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
    LEFT JOIN stockprop AS plant_number ON (observationunit.stock_id=plant_number.stock_id AND plant_number.type_id = $plant_number_type_id)
    LEFT JOIN stockprop AS is_a_control ON (observationunit.stock_id=is_a_control.stock_id AND is_a_control.type_id = $is_a_control_type_id)
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
    LEFT JOIN projectprop as plot_width ON (project.project_id=plot_width.project_id AND plot_width.type_id = $plot_width_type_id)
    LEFT JOIN projectprop as plot_length ON (project.project_id=plot_length.project_id AND plot_length.type_id = $plot_length_type_id)
    LEFT JOIN projectprop as field_size ON (project.project_id=field_size.project_id AND field_size.type_id = $field_size_type_id)
    LEFT JOIN projectprop as field_trial_is_planned_to_be_genotyped ON (project.project_id=field_trial_is_planned_to_be_genotyped.project_id AND field_trial_is_planned_to_be_genotyped.type_id = $field_trial_is_planned_to_be_genotyped_type_id)
    LEFT JOIN projectprop as field_trial_is_planned_to_cross ON (project.project_id=field_trial_is_planned_to_cross.project_id AND field_trial_is_planned_to_cross.type_id = $field_trial_is_planned_to_cross_type_id)
    LEFT JOIN project_relationship AS treatment_rel ON (project.project_id=treatment_rel.object_project_id AND treatment_rel.type_id = $treatment_rel_type_id)
    LEFT JOIN project AS treatment ON (treatment.project_id=treatment_rel.subject_project_id)
    LEFT JOIN project_relationship AS folder_rel ON (project.project_id=folder_rel.subject_project_id AND folder_rel.type_id = $folder_type_id)
    LEFT JOIN project AS folder ON (folder.project_id=folder_rel.object_project_id)
    WHERE phenotype.value IS NOT NULL
    GROUP BY (observationunit.stock_id, observationunit.uniquename, observationunit_cvterm.name, germplasm.uniquename, germplasm.stock_id, rep.value, block_number.value, plot_number.value, row_number.value, col_number.value, plant_number.value, is_a_control.value, project.project_id, project.name, project.description, breeding_program.project_id, breeding_program.name, breeding_program.description, year.value, design.value, location_id.value, planting_date.value, harvest_date.value, plot_width.value, plot_length.value, field_size.value, field_trial_is_planned_to_be_genotyped.value, field_trial_is_planned_to_cross.value, folder.project_id, folder.name, folder.description)
    ORDER by 14, 2;

CREATE UNIQUE INDEX materialized_phenotype_jsonb_table_observationunit_stock_idx ON public.materialized_phenotype_jsonb_table(observationunit_stock_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.materialized_phenotype_jsonb_table OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.refresh_materialized_phenotype_jsonb_table() RETURNS VOID AS '
REFRESH MATERIALIZED VIEW public.materialized_phenotype_jsonb_table;'
    LANGUAGE SQL;

ALTER FUNCTION public.refresh_materialized_phenotype_jsonb_table() OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.refresh_materialized_phenotype_jsonb_table_concurrently() RETURNS VOID AS '
REFRESH MATERIALIZED VIEW CONCURRENTLY public.materialized_phenotype_jsonb_table;'
    LANGUAGE SQL;

ALTER FUNCTION public.refresh_materialized_phenotype_jsonb_table_concurrently() OWNER TO web_usr;
--

EOSQL

print "You're done!\n";
}


####
1; #
####
