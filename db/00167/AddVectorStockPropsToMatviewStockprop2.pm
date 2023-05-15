#!/usr/bin/env perl

=head1 NAME

 AddVectorStockPropsToMatviewStockprop2.pm

=head1 SYNOPSIS

mx-run AddVectorStockPropsToMatviewStockprop2.pm [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This is a test dummy patch.
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

 Mirella Flores mrf252@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
    

package AddVectorStockPropsToMatviewStockprop2;

use Moose;
use Bio::Chado::Schema;
use SGN::Model::Cvterm;

extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => ' This patch adds required stock prop types for vectors.');

has '+prereq' => (
    default => sub {
        [ ],
    },
  );

sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

     my $schema = Bio::Chado::Schema->connect( sub { $self->dbh->clone } );

    $schema->resultset("Cv::Cvterm")->create_with(
	{
	        name => 'VectorType',
		    cv => 'stock_property'
			});



    # Now re-generate the materialized view (code lifted from db patch 00113)
    my $block_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'block', 'stock_property')->cvterm_id();
    my $col_number_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'col_number', 'stock_property')->cvterm_id();
    my $igd_synonym_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'igd_synonym', 'stock_property')->cvterm_id();
    my $is_a_control_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'is a control', 'stock_property')->cvterm_id();
    my $location_code_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'location_code', 'stock_property')->cvterm_id();
    my $organization_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'organization', 'stock_property')->cvterm_id();
    my $plant_index_number_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plant_index_number', 'stock_property')->cvterm_id();
    my $subplot_index_number_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'subplot_index_number', 'stock_property')->cvterm_id();
    my $tissue_sample_index_number_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'tissue_sample_index_number', 'stock_property')->cvterm_id();
    my $plot_number_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot number', 'stock_property')->cvterm_id();
    my $plot_geo_json_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot_geo_json', 'stock_property')->cvterm_id();
    my $range_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'range', 'stock_property')->cvterm_id();
    my $replicate_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'replicate', 'stock_property')->cvterm_id();
    my $row_number_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'row_number', 'stock_property')->cvterm_id();
    my $synonym_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stock_synonym', 'stock_property')->cvterm_id();
    my $T1_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'T1', 'stock_property')->cvterm_id();
    my $T2_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'T2', 'stock_property')->cvterm_id();
    my $transgenic_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'transgenic', 'stock_property')->cvterm_id();
    my $variety_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'variety', 'stock_property')->cvterm_id();
    my $notes_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'notes', 'stock_property')->cvterm_id();
    my $state_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'state', 'stock_property')->cvterm_id();
    my $accession_number_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession number', 'stock_property')->cvterm_id();
    my $PUI_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'PUI', 'stock_property')->cvterm_id();
    my $donor_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'donor', 'stock_property')->cvterm_id();
    my $donor_institute_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'donor institute', 'stock_property')->cvterm_id();
    my $donor_PUI_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'donor PUI', 'stock_property')->cvterm_id();
    my $seed_source_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'seed source', 'stock_property')->cvterm_id();
    my $institute_code_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'institute code', 'stock_property')->cvterm_id();
    my $institute_name_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'institute name', 'stock_property')->cvterm_id();
    my $biological_status_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'biological status of accession code', 'stock_property')->cvterm_id();
    my $country_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'country of origin', 'stock_property')->cvterm_id();
    my $germplasm_storage_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'type of germplasm storage code', 'stock_property')->cvterm_id();
    my $entry_number_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'entry number', 'stock_property')->cvterm_id();
    my $acquisition_date_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'acquisition date', 'stock_property')->cvterm_id();
    my $current_count_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'current_count', 'stock_property')->cvterm_id();
    my $current_weight_gram_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'current_weight_gram', 'stock_property')->cvterm_id();
    my $crossing_metadata_json_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'crossing_metadata_json', 'stock_property')->cvterm_id();
    my $ploidy_level_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'ploidy_level', 'stock_property')->cvterm_id();
    my $genome_structure_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'genome_structure', 'stock_property')->cvterm_id();
    my $introgression_parent_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'introgression_parent', 'stock_property')->cvterm_id();
    my $introgression_backcross_parent_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'introgression_backcross_parent', 'stock_property')->cvterm_id();
    my $introgression_map_version_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'introgression_map_version', 'stock_property')->cvterm_id();
    my $introgression_chromosome_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'introgression_chromosome', 'stock_property')->cvterm_id();
    my $introgression_start_position_bp_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'introgression_start_position_bp', 'stock_property')->cvterm_id();
    my $introgression_end_position_bp_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'introgression_end_position_bp', 'stock_property')->cvterm_id();
    my $is_blank_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'is_blank', 'stock_property')->cvterm_id();
    my $concentration_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'concentration', 'stock_property')->cvterm_id();
    my $volume_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'volume', 'stock_property')->cvterm_id();
    my $extraction_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'extraction', 'stock_property')->cvterm_id();
    my $dna_person_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'dna_person', 'stock_property')->cvterm_id();
    my $tissue_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'tissue_type', 'stock_property')->cvterm_id();
    my $ncbi_taxonomy_id_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'ncbi_taxonomy_id', 'stock_property')->cvterm_id();
    my $seedlot_quality_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'seedlot_quality', 'stock_property')->cvterm_id();
    

    my $selection_marker_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'SelectionMarker', 'stock_property')->cvterm_id();
    my $cloning_organism_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'CloningOrganism', 'stock_property')->cvterm_id();
    my $cassette_name_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'CassetteName', 'stock_property')->cvterm_id();
    my $microbial_strain_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'Strain', 'stock_property')->cvterm_id();
    my $inherent_marker_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'InherentMarker', 'stock_property')->cvterm_id();
    my $backbone_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'Backbone', 'stock_property')->cvterm_id();
    my $svector_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'VectorType', 'stock_property')->cvterm_id();
    my $gene_id_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'Gene', 'stock_property')->cvterm_id();
    my $promotors_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'Promotors', 'stock_property')->cvterm_id();
    my $terminators_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'Terminators', 'stock_property')->cvterm_id();
    my $plant_marker_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'PlantAntibioticResistantMarker', 'stock_property')->cvterm_id();
    my $bacterial_maker_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'BacterialResistantMarker', 'stock_property')->cvterm_id();

    $self->dbh->do(<<EOSQL);
--do your SQL here

DROP EXTENSION IF EXISTS tablefunc CASCADE;
CREATE EXTENSION tablefunc;

DROP MATERIALIZED VIEW IF EXISTS public.materialized_stockprop CASCADE;
CREATE MATERIALIZED VIEW public.materialized_stockprop AS
SELECT *
FROM crosstab(
  'SELECT stockprop.stock_id, stock.uniquename, stock.type_id, stock_cvterm.name, stock.organism_id, stockprop.type_id, jsonb_object_agg(stockprop.value, ''RANK'' || stockprop.rank) FROM public.stockprop JOIN public.stock USING(stock_id) JOIN public.cvterm as stock_cvterm ON (stock_cvterm.cvterm_id=stock.type_id) GROUP BY (stockprop.stock_id, stock.uniquename, stock.type_id, stock_cvterm.name, stock.organism_id, stockprop.type_id) ORDER by stockprop.stock_id ASC',
  'SELECT type_id FROM (VALUES
    (''$block_cvterm_id''),
    (''$col_number_cvterm_id''),
    (''$igd_synonym_cvterm_id''),
    (''$is_a_control_cvterm_id''),
    (''$location_code_cvterm_id''),
    (''$organization_cvterm_id''),
    (''$plant_index_number_cvterm_id''),
    (''$subplot_index_number_cvterm_id''),
    (''$tissue_sample_index_number_cvterm_id''),
    (''$plot_number_cvterm_id''),
    (''$plot_geo_json_cvterm_id''),
    (''$range_cvterm_id''),
    (''$replicate_cvterm_id''),
    (''$row_number_cvterm_id''),
    (''$synonym_cvterm_id''),
    (''$T1_cvterm_id''),
    (''$T2_cvterm_id''),
    (''$transgenic_cvterm_id''),
    (''$variety_cvterm_id''),
    (''$notes_cvterm_id''),
    (''$state_cvterm_id''),
    (''$accession_number_cvterm_id''),
    (''$PUI_cvterm_id''),
    (''$donor_cvterm_id''),
    (''$donor_institute_cvterm_id''),
    (''$donor_PUI_cvterm_id''),
    (''$seed_source_cvterm_id''),
    (''$institute_code_cvterm_id''),
    (''$institute_name_cvterm_id''),
    (''$biological_status_cvterm_id''),
    (''$country_cvterm_id''),
    (''$germplasm_storage_cvterm_id''),
    (''$entry_number_cvterm_id''),
    (''$acquisition_date_cvterm_id''),
    (''$current_count_cvterm_id''),
    (''$current_weight_gram_cvterm_id''),
    (''$crossing_metadata_json_cvterm_id''),
    (''$ploidy_level_cvterm_id''),
    (''$genome_structure_cvterm_id''),
    (''$introgression_parent_cvterm_id''),
    (''$introgression_backcross_parent_cvterm_id''),
    (''$introgression_map_version_cvterm_id''),
    (''$introgression_chromosome_cvterm_id''),
    (''$introgression_start_position_bp_cvterm_id''),
    (''$introgression_end_position_bp_cvterm_id''),
    (''$is_blank_cvterm_id''),
    (''$concentration_cvterm_id''),
    (''$volume_cvterm_id''),
    (''$extraction_cvterm_id''),
    (''$dna_person_cvterm_id''),
    (''$tissue_type_cvterm_id''),
    (''$seedlot_quality_cvterm_id''),
    (''$selection_marker_cvterm_id''),
    (''$cloning_organism_cvterm_id''),
    (''$cassette_name_cvterm_id''),
    (''$microbial_strain_cvterm_id''),
    (''$inherent_marker_cvterm_id''),
    (''$backbone_cvterm_id''),
    (''$svector_type_cvterm_id''),
    (''$gene_id_cvterm_id''),
    (''$promotors_cvterm_id''),
    (''$terminators_type_cvterm_id''),
    (''$plant_marker_cvterm_id''),
    (''$bacterial_maker_cvterm_id''),
    (''$ncbi_taxonomy_id_cvterm_id'')) AS t (type_id);'
    
)
AS (stock_id int,
    "uniquename" text,
    "stock_type_id" int,
    "stock_type_name" text,
    "organism_id" int,
    "block" json,
    "col_number" jsonb,
    "igd_synonym" jsonb,
    "is a control" jsonb,
    "location_code" jsonb,
    "organization" jsonb,
    "plant_index_number" jsonb,
    "subplot_index_number" jsonb,
    "tissue_sample_index_number" jsonb,
    "plot number" jsonb,
    "plot_geo_json" jsonb,
    "range" jsonb,
    "replicate" jsonb,
    "row_number" jsonb,
    "stock_synonym" jsonb,
    "T1" jsonb,
    "T2" jsonb,
    "transgenic" jsonb,
    "variety" jsonb,
    "notes" jsonb,
    "state" jsonb,
    "accession number" jsonb,
    "PUI" jsonb,
    "donor" jsonb,
    "donor institute" jsonb,
    "donor PUI" jsonb,
    "seed source" jsonb,
    "institute code" jsonb,
    "institute name" jsonb,
    "biological status of accession code" jsonb,
    "country of origin" jsonb,
    "type of germplasm storage code" jsonb,
    "entry number" jsonb,
    "acquisition date" jsonb,
    "current_count" jsonb,
    "current_weight_gram" jsonb,
    "crossing_metadata_jsonb" jsonb,
    "ploidy_level" jsonb,
    "genome_structure" jsonb,
    "introgression_parent" jsonb,
    "introgression_backcross_parent" jsonb,
    "introgression_map_version" jsonb,
    "introgression_chromosome" jsonb,
    "introgression_start_position_bp" jsonb,
    "introgression_end_position_bp" jsonb,
    "is_blank" jsonb,
    "concentration" jsonb,
    "volume" jsonb,
    "extraction" jsonb,
    "dna_person" jsonb,
    "tissue_type" jsonb,
    "seedlot_quality" jsonb,
    "SelectionMarker" jsonb,
    "CloningOrganism" jsonb,
    "CassetteName" jsonb,
    "Strain" jsonb,
    "InherentMarker" jsonb,
    "Backbone" jsonb,
    "VectorType" jsonb,
    "Gene" jsonb,
    "Promotors" jsonb,
    "Terminators" jsonb,
    "PlantAntibioticResistantMarker" jsonb,
    "BacterialResistantMarker" jsonb,
    "ncbi_taxonomy_id" jsonb
);
CREATE UNIQUE INDEX materialized_stockprop_stock_idx ON public.materialized_stockprop(stock_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.materialized_stockprop OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.refresh_materialized_stockprop() RETURNS VOID AS '
REFRESH MATERIALIZED VIEW public.materialized_stockprop;'
    LANGUAGE SQL;

ALTER FUNCTION public.refresh_materialized_stockprop() OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.refresh_materialized_stockprop_concurrently() RETURNS VOID AS '
REFRESH MATERIALIZED VIEW CONCURRENTLY public.materialized_stockprop;'
    LANGUAGE SQL;

ALTER FUNCTION public.refresh_materialized_stockprop_concurrently() OWNER TO web_usr;
--

EOSQL

    

    
    print STDERR "Done!\n";
}


####
1; #
####
