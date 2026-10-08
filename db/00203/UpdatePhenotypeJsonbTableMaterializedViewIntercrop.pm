#!/usr/bin/env perl

=head1 NAME

UpdatePhenotypeJsonbTableMaterializedViewIntercrop.pm

=head1 SYNOPSIS

mx-run UpdatePhenotypeJsonbTableMaterializedViewIntercrop [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch updates the treatment column in the materialized_phenotype_jsonb_table query so that only 
treatments that are applied to the observationunit are include (it was previously including all treatments 
from the entire trial).

=head1 AUTHOR

Updated by David Waring <djw64@cornell.edu>


=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package UpdatePhenotypeJsonbTableMaterializedViewIntercrop;

use Moose;
use SGN::Model::Cvterm;
use Bio::Chado::Schema;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch fixes materialized_phenotype_jsonb_table view to include intercrop accessions

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
    my $notes_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'notes', 'stock_property')->cvterm_id();
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
    my $drone_run_related_time_cvterms_json_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_related_time_cvterms_json', 'project_property')->cvterm_id();
    my $plot_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id();
    my $plant_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plant', 'stock_type')->cvterm_id();
    my $subplot_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'subplot', 'stock_type')->cvterm_id();
    my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $family_name_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'family_name', 'stock_type')->cvterm_id();
    my $cross_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'cross', 'stock_type')->cvterm_id();
    my $analysis_instance_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'analysis_instance', 'stock_type')->cvterm_id();
    my $plant_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plant_of', 'stock_relationship')->cvterm_id();
    my $plot_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot_of', 'stock_relationship')->cvterm_id();
    my $intercrop_plot_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'intercrop_plot_of', 'stock_relationship')->cvterm_id();
    my $subplot_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'subplot_of', 'stock_relationship')->cvterm_id();
    my $analysis_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'analysis_of', 'stock_relationship')->cvterm_id();
    my $phenotype_outlier_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'phenotype_outlier', 'phenotype_property')->cvterm_id();
    my $breeding_program_rel_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'breeding_program_trial_relationship', 'project_relationship')->cvterm_id();
    my $treatment_rel_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'trial_treatment_relationship', 'project_relationship')->cvterm_id();
    my $folder_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'trial_folder', 'project_property')->cvterm_id();
    my $field_layout_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'field_layout', 'experiment_type')->cvterm_id();
    my $genotyping_layout_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'genotyping_layout', 'experiment_type')->cvterm_id();
    my $phenotyping_experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'phenotyping_experiment', 'experiment_type')->cvterm_id();
    my $treatment_experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'treatment_experiment', 'experiment_type')->cvterm_id();
    my $analysis_experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'analysis_experiment', 'experiment_type')->cvterm_id();
    my $seedlot_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'seedlot', 'stock_type')->cvterm_id();
    my $seedlot_transaction_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'seed transaction', 'stock_relationship')->cvterm_id();
    my $seedlot_collection_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'collection_of', 'stock_relationship')->cvterm_id();
    my $current_count_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'current_count', 'stock_property')->cvterm_id();
    my $current_weight_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'current_weight_gram', 'stock_property')->cvterm_id();
    my $seedlot_box_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'location_code', 'stock_property')->cvterm_id();
    
    $self->dbh->do(<<EOSQL);
--do your SQL here

DROP MATERIALIZED VIEW IF EXISTS public.materialized_phenotype_jsonb_table CASCADE;
CREATE MATERIALIZED VIEW public.materialized_phenotype_jsonb_table AS
SELECT observationunit.stock_id AS observationunit_stock_id, observationunit.uniquename AS observationunit_uniquename, observationunit_cvterm.name AS observationunit_type_name, germplasm.uniquename AS germplasm_uniquename, germplasm.stock_id AS germplasm_stock_id, rep.value AS rep, block_number.value AS block, plot_number.value AS plot_number, row_number.value AS row_number, col_number.value AS col_number, plant_number.value AS plant_number, is_a_control.value AS is_a_control, string_agg(distinct(notes.value), ', ') AS notes, project.project_id AS trial_id, project.name AS trial_name, project.description AS trial_description, plot_width.value AS plot_width, plot_length.value AS plot_length, field_size.value AS field_size, field_trial_is_planned_to_be_genotyped.value AS field_trial_is_planned_to_be_genotyped, field_trial_is_planned_to_cross.value AS field_trial_is_planned_to_cross, breeding_program.project_id AS breeding_program_id, breeding_program.name AS breeding_program_name, breeding_program.description AS breeding_program_description, year.value AS year, design.value AS design, location_id.value AS location_id, planting_date.value AS planting_date, harvest_date.value AS harvest_date, folder.project_id AS folder_id, folder.name AS folder_name, folder.description AS folder_description, seedplot_planted.value AS seedlot_transaction, seedlot.stock_id AS seedlot_stock_id, seedlot.uniquename AS seedlot_uniquename, seedlot_current_weight.value AS seedlot_current_weight_gram, seedlot_current_count.value AS seedlot_current_count, seedlot_seedlot_box.value AS seedlot_box_name,
    COALESCE(
        jsonb_object_agg(treatment.name, treatment.description) FILTER (WHERE treatment.name IS NOT NULL), 
        '{"No ManagementFactor": null}'::jsonb
    ) AS treatments,
    COALESCE(
        jsonb_agg(jsonb_build_object('trait_id', phenotype.cvalue_id, 'trait_name', (((cvterm.name::text || '|'::text) || db.name::text) || ':'::text) || dbxref.accession::text, 'value', phenotype.value, 'phenotype_id', phenotype.phenotype_id, 'outlier', outlier.value, 'create_date', phenotype.create_date, 'uniquename', phenotype.uniquename, 'phenotype_location_id', nd_geolocation.nd_geolocation_id, 'phenotype_location_name', nd_geolocation.description, 'collect_date', phenotype.collect_date, 'operator', phenotype.operator, 'associated_image_id', md_image.image_id, 'associated_image_type', project_md_image_type.name, 'associated_image_project_id', drone_image_project.project_id, 'associated_image_project_name', drone_image_project.name, 'associated_image_project_time_json', drone_image_project_time_json.value))
        FILTER (WHERE phenotype.value IS NOT NULL), '[]'
    ) AS observations,
    COALESCE(
        jsonb_agg(jsonb_build_object('stock_id', available_seelot.stock_id, 'stock_uniquename', available_seelot.uniquename, 'current_weight_gram', current_weight.value, 'current_count', current_count.value, 'box_name', seedlot_box.value))
        FILTER (WHERE available_seelot.stock_id IS NOT NULL), '[]'
    ) AS available_germplasm_seedlots,
    COALESCE(jsonb_agg(DISTINCT(jsonb_build_object('stock_id', ics.stock_id, 'stock_uniquename', ics.uniquename))) FILTER (WHERE (ics.stock_id IS NOT NULL)), '[]'::jsonb) AS intercrop_germplasm
    FROM stock AS observationunit
    JOIN nd_experiment_stock ON(observationunit.stock_id=nd_experiment_stock.stock_id)
    JOIN nd_experiment ON (nd_experiment_stock.nd_experiment_id = nd_experiment.nd_experiment_id)
    JOIN nd_geolocation USING(nd_geolocation_id)
    LEFT JOIN stock_relationship AS seedplot_planted ON(seedplot_planted.subject_id = observationunit.stock_id AND seedplot_planted.type_id=$seedlot_transaction_type_id)
    LEFT JOIN stock AS seedlot ON(seedplot_planted.object_id = seedlot.stock_id AND seedlot.type_id=$seedlot_type_id)
    LEFT JOIN stockprop AS seedlot_current_count ON(seedlot.stock_id=seedlot_current_count.stock_id AND seedlot_current_count.type_id = $current_count_type_id)
    LEFT JOIN stockprop AS seedlot_current_weight ON(seedlot.stock_id=seedlot_current_weight.stock_id AND seedlot_current_weight.type_id = $current_weight_type_id)
    LEFT JOIN stockprop AS seedlot_seedlot_box ON(seedlot.stock_id=seedlot_seedlot_box.stock_id AND seedlot_seedlot_box.type_id = $seedlot_box_type_id)
    LEFT JOIN nd_experiment_phenotype ON (nd_experiment_phenotype.nd_experiment_id = nd_experiment.nd_experiment_id)
    LEFT JOIN phenotype USING(phenotype_id)
    JOIN cvterm AS observationunit_cvterm ON(observationunit.type_id=observationunit_cvterm.cvterm_id)
    JOIN stock_relationship ON(observationunit.stock_id=stock_relationship.subject_id AND stock_relationship.type_id IN ($plot_of_cvterm_id, $plant_of_cvterm_id, $subplot_of_cvterm_id, $analysis_of_cvterm_id))
    JOIN stock AS germplasm ON(stock_relationship.object_id=germplasm.stock_id AND germplasm.type_id IN ($accession_type_id, $cross_type_id, $family_name_type_id))
    LEFT JOIN phenome.nd_experiment_md_images AS nd_experiment_md_images ON (nd_experiment.nd_experiment_id = nd_experiment_md_images.nd_experiment_id)
    LEFT JOIN metadata.md_image AS md_image ON (nd_experiment_md_images.image_id = md_image.image_id)
    LEFT JOIN phenome.project_md_image AS project_md_image ON (md_image.image_id = project_md_image.image_id)
    LEFT JOIN cvterm AS project_md_image_type ON (project_md_image.type_id = project_md_image_type.cvterm_id)
    LEFT JOIN project AS drone_image_project ON (project_md_image.project_id = drone_image_project.project_id)
    LEFT JOIN projectprop AS drone_image_project_time_json ON (drone_image_project.project_id = drone_image_project_time_json.project_id AND drone_image_project_time_json.type_id=$drone_run_related_time_cvterms_json_type_id)
    LEFT JOIN stock_relationship AS available_seedlot_rel ON (available_seedlot_rel.subject_id=germplasm.stock_id AND available_seedlot_rel.type_id=$seedlot_collection_of_type_id)
    LEFT JOIN stock AS available_seelot ON(available_seedlot_rel.object_id=available_seelot.stock_id AND seedlot.type_id=$seedlot_type_id)
    LEFT JOIN stockprop AS current_count ON(available_seelot.stock_id=current_count.stock_id AND current_count.type_id = $current_count_type_id)
    LEFT JOIN stockprop AS current_weight ON(available_seelot.stock_id=current_weight.stock_id AND current_weight.type_id = $current_weight_type_id)
    LEFT JOIN stockprop AS seedlot_box ON(available_seelot.stock_id=seedlot_box.stock_id AND seedlot_box.type_id = $seedlot_box_type_id)
    LEFT JOIN stockprop AS rep ON (observationunit.stock_id=rep.stock_id AND rep.type_id = $rep_type_id)
    LEFT JOIN stockprop AS block_number ON (observationunit.stock_id=block_number.stock_id AND block_number.type_id = $block_number_type_id)
    LEFT JOIN stockprop AS plot_number ON (observationunit.stock_id=plot_number.stock_id AND plot_number.type_id = $plot_number_type_id)
    LEFT JOIN stockprop AS row_number ON (observationunit.stock_id=row_number.stock_id AND row_number.type_id = $row_number_type_id AND row_number.rank=0)
    LEFT JOIN stockprop AS col_number ON (observationunit.stock_id=col_number.stock_id AND col_number.type_id = $col_number_type_id AND col_number.rank=0)
    LEFT JOIN stockprop AS plant_number ON (observationunit.stock_id=plant_number.stock_id AND plant_number.type_id = $plant_number_type_id)
    LEFT JOIN stockprop AS is_a_control ON (observationunit.stock_id=is_a_control.stock_id AND is_a_control.type_id = $is_a_control_type_id)
    LEFT JOIN stockprop AS notes ON (observationunit.stock_id=notes.stock_id AND notes.type_id = $notes_type_id)
    LEFT JOIN phenotypeprop AS outlier ON (phenotype.phenotype_id=outlier.phenotype_id AND outlier.type_id = $phenotype_outlier_type_id)
    LEFT JOIN cvterm ON (phenotype.cvalue_id=cvterm.cvterm_id)
    LEFT JOIN dbxref ON (cvterm.dbxref_id = dbxref.dbxref_id)
    LEFT JOIN db USING(db_id)
    JOIN nd_experiment_project ON (nd_experiment_project.nd_experiment_id = nd_experiment.nd_experiment_id)
    JOIN project ON (nd_experiment_project.project_id = project.project_id)
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
    LEFT JOIN nd_experiment_stock treatment_nds ON (treatment_nds.type_id = $treatment_experiment_type_id AND treatment_nds.stock_id = observationunit.stock_id)
    LEFT JOIN nd_experiment_project treatment_ndp ON (treatment_ndp.nd_experiment_id = treatment_nds.nd_experiment_id)
    LEFT JOIN project_relationship treatment_rel ON (project.project_id = treatment_rel.object_project_id AND treatment_rel.type_id = $treatment_rel_type_id)
    LEFT JOIN project treatment ON (treatment.project_id = treatment_rel.subject_project_id AND treatment.project_id = treatment_ndp.project_id)
    LEFT JOIN project_relationship AS folder_rel ON (project.project_id=folder_rel.subject_project_id AND folder_rel.type_id = $folder_type_id)
    LEFT JOIN project AS folder ON (folder.project_id=folder_rel.object_project_id)
    LEFT JOIN stock_relationship icsr ON (icsr.subject_id = observationunit.stock_id) AND (icsr.type_id = $intercrop_plot_of_cvterm_id)
    LEFT JOIN stock ics ON (ics.stock_id = icsr.object_id)
    WHERE nd_experiment.type_id IN ($field_layout_type_id, $genotyping_layout_type_id, $phenotyping_experiment_type_id, $analysis_experiment_type_id) AND design.value != 'genotype_data_project' AND design.value != 'treatment'
    GROUP BY (observationunit.stock_id, observationunit.uniquename, observationunit_cvterm.name, germplasm.uniquename, germplasm.stock_id, rep.value, block_number.value, plot_number.value, row_number.value, col_number.value, plant_number.value, is_a_control.value, project.project_id, project.name, project.description, breeding_program.project_id, breeding_program.name, breeding_program.description, year.value, design.value, location_id.value, planting_date.value, harvest_date.value, plot_width.value, plot_length.value, field_size.value, field_trial_is_planned_to_be_genotyped.value, field_trial_is_planned_to_cross.value, folder.project_id, folder.name, folder.description, seedplot_planted.value, seedlot.stock_id, seedlot.uniquename, seedlot_current_weight.value, seedlot_current_count.value, seedlot_seedlot_box.value)
    ORDER by 14, 2;

CREATE UNIQUE INDEX materialized_phenotype_jsonb_table_obsunit_stock_idx ON public.materialized_phenotype_jsonb_table(observationunit_stock_id) WITH (fillfactor=100);
CREATE INDEX materialized_phenotype_jsonb_table_obsunit_uniquename_idx ON public.materialized_phenotype_jsonb_table(observationunit_uniquename) WITH (fillfactor=100);
CREATE INDEX materialized_phenotype_jsonb_table_germplasm_stock_idx ON public.materialized_phenotype_jsonb_table(germplasm_stock_id) WITH (fillfactor=100);
CREATE INDEX materialized_phenotype_jsonb_table_germplasm_uniquename_idx ON public.materialized_phenotype_jsonb_table(germplasm_uniquename) WITH (fillfactor=100);
CREATE INDEX materialized_phenotype_jsonb_table_trial_idx ON public.materialized_phenotype_jsonb_table(trial_id) WITH (fillfactor=100);
CREATE INDEX materialized_phenotype_jsonb_table_trial_name_idx ON public.materialized_phenotype_jsonb_table(trial_name) WITH (fillfactor=100);
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
