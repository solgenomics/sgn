#!/usr/bin/env perl


=head1 NAME

AddSubplotToMaterializedview.pm


=head1 SYNOPSIS

mx-run AddSubplotToMaterializedview [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch:
 - updates the materialized_phenoview by adding subplot to the view

=head1 AUTHOR

Chris Simoes

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

package AddSubplotToMaterializedview;

use Moose;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch updates the materialized_phenoview by adding tissue sample to the view


sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    $self->dbh->do(<<EOSQL);
--do your SQL here


-- use definition from SpeedUpMatViews
-- add subplots to the definition

DROP MATERIALIZED VIEW IF EXISTS public.materialized_phenoview CASCADE;
CREATE MATERIALIZED VIEW public.materialized_phenoview AS
  SELECT
    breeding_program.project_id AS breeding_program_id,
    location.value::int AS location_id,
    year.value AS year_id,
    trial.project_id::int AS trial_id,
    accession.stock_id::int AS accession_id,
    seedlot.stock_id AS seedlot_id,
    stock.stock_id AS stock_id,
    phenotype.phenotype_id as phenotype_id,
    phenotype.cvalue_id as trait_id
  FROM stock accession
  LEFT JOIN stock_relationship ON accession.stock_id = stock_relationship.object_id AND stock_relationship.type_id IN (SELECT cvterm_id from cvterm where cvterm.name IN ('plot_of', 'subplot_of', 'plant_of', 'tissue_sample_of' ,'analysis_of'))
  LEFT JOIN stock ON stock_relationship.subject_id = stock.stock_id AND stock.type_id IN (SELECT cvterm_id from cvterm where cvterm.name IN ('plot', 'subplot', 'plant', 'tissue_sample','analysis_instance'))
  LEFT JOIN stock_relationship seedlot_relationship ON stock.stock_id = seedlot_relationship.subject_id AND seedlot_relationship.type_id IN (SELECT cvterm_id from cvterm where cvterm.name = 'seed transaction')
  LEFT JOIN stock seedlot ON seedlot_relationship.object_id = seedlot.stock_id AND seedlot.type_id IN (SELECT cvterm_id from cvterm where cvterm.name = 'seedlot')
  LEFT JOIN nd_experiment_stock ON(stock.stock_id = nd_experiment_stock.stock_id AND nd_experiment_stock.type_id IN (SELECT cvterm_id from cvterm where cvterm.name IN ('phenotyping_experiment', 'field_layout', 'analysis_experiment')))
  LEFT JOIN nd_experiment_project ON nd_experiment_stock.nd_experiment_id = nd_experiment_project.nd_experiment_id
  FULL OUTER JOIN project trial ON nd_experiment_project.project_id = trial.project_id
  LEFT JOIN project_relationship ON trial.project_id = project_relationship.subject_project_id AND project_relationship.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'breeding_program_trial_relationship' )
  FULL OUTER JOIN project breeding_program ON project_relationship.object_project_id = breeding_program.project_id
  LEFT JOIN projectprop location ON trial.project_id = location.project_id AND location.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'project location' )
  LEFT JOIN projectprop year ON trial.project_id = year.project_id AND year.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'project year' )
  LEFT JOIN nd_experiment_phenotype ON(nd_experiment_stock.nd_experiment_id = nd_experiment_phenotype.nd_experiment_id)
  LEFT JOIN phenotype ON nd_experiment_phenotype.phenotype_id = phenotype.phenotype_id
  WHERE accession.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'accession')
  ORDER BY breeding_program_id, location_id, trial_id, accession_id, seedlot_id, stock.stock_id, phenotype_id, trait_id
WITH DATA;
CREATE UNIQUE INDEX unq_pheno_idx ON public.materialized_phenoview(stock_id,phenotype_id,trait_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW materialized_phenoview OWNER TO web_usr;

-- drop and recreate genoview with new column for genotype project id

DROP MATERIALIZED VIEW IF EXISTS public.materialized_genoview CASCADE;
CREATE MATERIALIZED VIEW public.materialized_genoview AS
SELECT stock.stock_id AS accession_id,
     nd_experiment_protocol.nd_protocol_id AS genotyping_protocol_id,
     nd_experiment_project.project_id AS genotyping_project_id,
     genotype.genotype_id AS genotype_id,
     stock_type.name AS stock_type
    FROM stock
      JOIN cvterm AS stock_type ON (stock_type.cvterm_id = stock.type_id AND stock_type.name = 'accession')
      JOIN nd_experiment_stock ON stock.stock_id = nd_experiment_stock.stock_id
      JOIN nd_experiment_protocol ON nd_experiment_stock.nd_experiment_id = nd_experiment_protocol.nd_experiment_id
      LEFT JOIN nd_experiment_project ON nd_experiment_stock.nd_experiment_id = nd_experiment_project.nd_experiment_id
      JOIN nd_protocol ON nd_experiment_protocol.nd_protocol_id = nd_protocol.nd_protocol_id
      JOIN nd_experiment_genotype ON nd_experiment_stock.nd_experiment_id = nd_experiment_genotype.nd_experiment_id
      JOIN genotype ON genotype.genotype_id = nd_experiment_genotype.genotype_id
   GROUP BY 1,2,3,4,5
UNION
SELECT accession.stock_id AS accession_id,
    nd_experiment_protocol.nd_protocol_id AS genotyping_protocol_id,
    nd_experiment_project.project_id AS genotyping_project_id,
    nd_experiment_genotype.genotype_id AS genotype_id,
    stock_type.name AS stock_type
    FROM stock AS accession
      JOIN stock_relationship ON accession.stock_id = stock_relationship.object_id AND stock_relationship.type_id IN (SELECT cvterm_id from cvterm where cvterm.name IN ('tissue_sample_of', 'plant_of', 'plot_of') )
      JOIN stock ON stock_relationship.subject_id = stock.stock_id AND stock.type_id IN (SELECT cvterm_id from cvterm where cvterm.name IN ('tissue_sample', 'plant', 'plot') )
      JOIN cvterm AS stock_type ON (stock_type.cvterm_id = stock.type_id)
     JOIN nd_experiment_stock ON stock.stock_id = nd_experiment_stock.stock_id
     JOIN nd_experiment_protocol ON nd_experiment_stock.nd_experiment_id = nd_experiment_protocol.nd_experiment_id
     LEFT JOIN nd_experiment_project ON nd_experiment_stock.nd_experiment_id = nd_experiment_project.nd_experiment_id
     JOIN nd_protocol ON nd_experiment_protocol.nd_protocol_id = nd_protocol.nd_protocol_id
     JOIN nd_experiment_genotype ON nd_experiment_stock.nd_experiment_id = nd_experiment_genotype.nd_experiment_id
  GROUP BY 1,2,3,4,5 ORDER BY 1,2,3,4
WITH DATA;
CREATE UNIQUE INDEX unq_geno_idx ON public.materialized_genoview(accession_id,genotype_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW materialized_genoview OWNER TO web_usr;

-- drop and recreate all the single category matviews as just views

DROP VIEW IF EXISTS public.accessions CASCADE;
CREATE VIEW public.accessions AS
  SELECT stock.stock_id AS accession_id,
  stock.uniquename AS accession_name
  FROM stock
  WHERE stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'accession') AND is_obsolete = 'f'
  GROUP BY stock.stock_id, stock.uniquename;
ALTER VIEW accessions OWNER TO web_usr;

DROP VIEW IF EXISTS public.subplots CASCADE;
CREATE VIEW public.subplots AS
  SELECT stock.stock_id AS subplot_id,
  stock.uniquename AS subplot_name
  FROM stock
  WHERE stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'subplot') AND is_obsolete = 'f'
  GROUP BY stock.stock_id, stock.uniquename;
ALTER VIEW subplots OWNER TO web_usr;


DROP VIEW IF EXISTS public.organisms CASCADE;
CREATE VIEW public.organisms AS
  SELECT organism.organism_id,
  organism.species AS organism_name
  from public.organism
  group by organism_id, organism_name;
ALTER VIEW organisms OWNER TO web_usr;

DROP VIEW IF EXISTS public.breeding_programs CASCADE;
CREATE VIEW public.breeding_programs AS
SELECT project.project_id AS breeding_program_id,
    project.name AS breeding_program_name
   FROM project join projectprop USING (project_id)
   WHERE projectprop.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'breeding_program')
  GROUP BY project.project_id, project.name;
ALTER VIEW breeding_programs OWNER TO web_usr;

DROP VIEW IF EXISTS public.genotyping_protocols CASCADE;
CREATE VIEW public.genotyping_protocols AS
SELECT nd_protocol.nd_protocol_id AS genotyping_protocol_id,
    nd_protocol.name AS genotyping_protocol_name
   FROM nd_protocol
   WHERE nd_protocol.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'genotyping_experiment')
  GROUP BY public.nd_protocol.nd_protocol_id, public.nd_protocol.name;
ALTER VIEW genotyping_protocols OWNER TO web_usr;

DROP VIEW IF EXISTS public.locations CASCADE;
CREATE VIEW public.locations AS
SELECT nd_geolocation.nd_geolocation_id AS location_id,
  nd_geolocation.description AS location_name
   FROM nd_geolocation
  GROUP BY public.nd_geolocation.nd_geolocation_id, public.nd_geolocation.description;
ALTER VIEW locations OWNER TO web_usr;

DROP VIEW IF EXISTS public.plants CASCADE;
CREATE VIEW public.plants AS
SELECT stock.stock_id AS plant_id,
    stock.uniquename AS plant_name
   FROM stock
   WHERE stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plant') AND is_obsolete = 'f'
  GROUP BY public.stock.stock_id, public.stock.uniquename;
ALTER VIEW plants OWNER TO web_usr;

DROP VIEW IF EXISTS public.plots CASCADE;
CREATE VIEW public.plots AS
SELECT stock.stock_id AS plot_id,
    stock.uniquename AS plot_name
   FROM stock
   WHERE stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plot') AND is_obsolete = 'f'
  GROUP BY public.stock.stock_id, public.stock.uniquename;
ALTER VIEW plots OWNER TO web_usr;

DROP VIEW IF EXISTS public.trait_components CASCADE;
CREATE VIEW public.trait_components AS
SELECT cvterm.cvterm_id AS trait_component_id,
(((cvterm.name::text || '|'::text) || db.name::text) || ':'::text) || dbxref.accession::text AS trait_component_name
    FROM cv
    JOIN cvprop ON(cv.cv_id = cvprop.cv_id AND cvprop.type_id IN (SELECT cvterm_id from cvterm where cvterm.name = ANY ('{object_ontology,attribute_ontology,method_ontology,unit_ontology,time_ontology}')))
    JOIN cvterm ON(cvprop.cv_id = cvterm.cv_id)
    JOIN dbxref USING(dbxref_id)
    JOIN db ON(dbxref.db_id = db.db_id)
    LEFT JOIN cvterm_relationship is_subject ON cvterm.cvterm_id = is_subject.subject_id
    LEFT JOIN cvterm_relationship is_object ON cvterm.cvterm_id = is_object.object_id
    WHERE is_object.object_id IS NULL AND is_subject.subject_id IS NOT NULL
    GROUP BY 2,1 ORDER BY 2,1;
ALTER VIEW trait_components OWNER TO web_usr;

DROP VIEW IF EXISTS public.traits CASCADE;
CREATE OR REPLACE VIEW public.traits AS
SELECT 
    cvterm.cvterm_id AS trait_id,
    (((cvterm.name || '|') || db.name) || ':' || dbxref.accession) AS trait_name
FROM 
    cvterm
    JOIN dbxref USING(dbxref_id)
    JOIN db ON(dbxref.db_id = db.db_id)
    LEFT JOIN cvterm_relationship is_variable 
        ON cvterm.cvterm_id = is_variable.subject_id 
        AND is_variable.type_id IN (SELECT cvterm_id FROM cvterm WHERE name = 'VARIABLE_OF')
WHERE 
    cvterm.cvterm_id IN (
        SELECT cvterm_id 
        FROM cvprop 
        WHERE type_id IN (SELECT cvterm_id FROM cvterm WHERE name = 'trait_ontology')
    )
    AND is_variable.subject_id IS NOT NULL

UNION

SELECT 
    cvterm.cvterm_id AS trait_id,
    (((cvterm.name || '|') || db.name) || ':' || dbxref.accession) AS trait_name
FROM 
    cvterm
    JOIN dbxref USING(dbxref_id)
    JOIN db ON(dbxref.db_id = db.db_id)
    LEFT JOIN cvterm_relationship is_subject 
        ON cvterm.cvterm_id = is_subject.subject_id
WHERE 
    cvterm.cvterm_id IN (
        SELECT cvterm_id 
        FROM cvprop 
        WHERE type_id IN (SELECT cvterm_id FROM cvterm WHERE name = 'composed_trait_ontology')
    )
    AND is_subject.subject_id IS NOT NULL
ORDER BY 2;

ALTER VIEW public.traits OWNER TO web_usr;


DROP VIEW IF EXISTS public.trials CASCADE;
CREATE VIEW public.trials AS
SELECT trial.project_id AS trial_id,
    trial.name AS trial_name
   FROM project breeding_program
   JOIN project_relationship ON(breeding_program.project_id = object_project_id AND project_relationship.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'breeding_program_trial_relationship'))
   JOIN project trial ON(subject_project_id = trial.project_id)
   JOIN projectprop on(trial.project_id = projectprop.project_id)
   WHERE projectprop.type_id NOT IN (SELECT cvterm.cvterm_id FROM cvterm WHERE cvterm.name::text = 'cross'::text OR cvterm.name::text = 'trial_folder'::text OR cvterm.name::text = 'folder_for_trials'::text OR cvterm.name::text = 'folder_for_crosses'::text OR cvterm.name::text = 'folder_for_genotyping_trials'::text)
   GROUP BY trial.project_id, trial.name;
ALTER VIEW trials OWNER TO web_usr;

DROP VIEW IF EXISTS public.trial_designs CASCADE;
CREATE VIEW public.trial_designs AS
SELECT projectprop.value AS trial_design_id,
  projectprop.value AS trial_design_name
   FROM projectprop
   JOIN cvterm ON(projectprop.type_id = cvterm.cvterm_id)
   WHERE cvterm.name = 'design'
   GROUP BY 1,2;
ALTER VIEW trial_designs OWNER TO web_usr;

DROP VIEW IF EXISTS public.trial_types CASCADE;
CREATE VIEW public.trial_types AS
SELECT cvterm.cvterm_id AS trial_type_id,
  cvterm.name AS trial_type_name
   FROM cvterm
   JOIN cv USING(cv_id)
   WHERE cv.name = 'project_type'
   GROUP BY cvterm.cvterm_id;
ALTER VIEW trial_types OWNER TO web_usr;

DROP VIEW IF EXISTS public.years CASCADE;
CREATE VIEW public.years AS
SELECT projectprop.value AS year_id,
  projectprop.value AS year_name
   FROM projectprop
   WHERE projectprop.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'project year')
  GROUP BY public.projectprop.value;
ALTER VIEW years OWNER TO web_usr;

DROP VIEW IF EXISTS public.seedlots CASCADE;
CREATE VIEW public.seedlots AS 
SELECT stock.stock_id AS seedlot_id,
   stock.uniquename AS seedlot_name
   FROM stock
   WHERE stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'seedlot') AND is_obsolete = 'f'
   GROUP BY public.stock.stock_id, public.stock.uniquename;
ALTER VIEW seedlots OWNER TO web_usr;

DROP VIEW IF EXISTS public.tissue_sample CASCADE;
CREATE VIEW public.tissue_sample AS
SELECT stock.stock_id AS tissue_sample_id,
    stock.uniquename AS tissue_sample_name
   FROM stock
   WHERE stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'tissue_sample') AND is_obsolete = 'f'
  GROUP BY public.stock.stock_id, public.stock.uniquename;
ALTER VIEW tissue_sample OWNER TO web_usr;


-- drop and recreate all the binary matviews as just views

DROP VIEW IF EXISTS public.accessionsXseedlots CASCADE;
CREATE VIEW public.accessionsXseedlots AS
SELECT public.materialized_phenoview.accession_id,
    public.stock.stock_id AS seedlot_id
   FROM public.materialized_phenoview
   LEFT JOIN stock_relationship seedlot_relationship ON materialized_phenoview.accession_id = seedlot_relationship.subject_id AND seedlot_relationship.type_id IN (SELECT cvterm_id from cvterm where cvterm.name = 'collection_of')
   LEFT JOIN stock ON seedlot_relationship.object_id = stock.stock_id AND stock.type_id IN (SELECT cvterm_id from cvterm where cvterm.name = 'seedlot')
  GROUP BY public.materialized_phenoview.accession_id,public.stock.stock_id;
ALTER VIEW accessionsXseedlots OWNER TO web_usr;

DROP VIEW IF EXISTS public.breeding_programsXseedlots CASCADE;
CREATE VIEW public.breeding_programsXseedlots AS
SELECT public.materialized_phenoview.breeding_program_id,
    public.nd_experiment_stock.stock_id AS seedlot_id
   FROM public.materialized_phenoview
   LEFT JOIN nd_experiment_project ON materialized_phenoview.breeding_program_id = nd_experiment_project.project_id
   LEFT JOIN nd_experiment ON nd_experiment_project.nd_experiment_id = nd_experiment.nd_experiment_id AND nd_experiment.type_id IN (SELECT cvterm_id from cvterm where cvterm.name = 'seedlot_experiment')
   LEFT JOIN nd_experiment_stock ON nd_experiment.nd_experiment_id = nd_experiment_stock.nd_experiment_id
  GROUP BY 1,2;
ALTER VIEW breeding_programsXseedlots OWNER TO web_usr;

DROP VIEW IF EXISTS public.genotyping_protocolsXseedlots CASCADE;
CREATE VIEW public.genotyping_protocolsXseedlots AS
SELECT public.materialized_genoview.genotyping_protocol_id,
public.stock.stock_id AS seedlot_id
FROM public.materialized_genoview
LEFT JOIN stock_relationship seedlot_relationship ON materialized_genoview.accession_id = seedlot_relationship.subject_id AND seedlot_relationship.type_id IN (SELECT cvterm_id from cvterm where cvterm.name = 'collection_of')
LEFT JOIN stock ON seedlot_relationship.object_id = stock.stock_id AND stock.type_id IN (SELECT cvterm_id from cvterm where cvterm.name = 'seedlot')
  GROUP BY 1,2;
ALTER VIEW genotyping_protocolsXseedlots OWNER TO web_usr;

DROP VIEW IF EXISTS public.locationsXseedlots CASCADE;
CREATE VIEW public.locationsXseedlots AS
SELECT nd_experiment.nd_geolocation_id AS location_id,nd_experiment_stock.stock_id AS seedlot_id
    FROM nd_experiment
    LEFT JOIN nd_experiment_stock ON nd_experiment.nd_experiment_id = nd_experiment_stock.nd_experiment_id
    WHERE nd_experiment.type_id IN (SELECT cvterm.cvterm_id FROM cvterm WHERE cvterm.name = 'seedlot_experiment')
    GROUP BY 1,2;
ALTER VIEW public.locationsXseedlots OWNER TO web_usr;

DROP VIEW IF EXISTS public.plantsXseedlots CASCADE;
CREATE VIEW public.plantsXseedlots AS
SELECT public.stock.stock_id AS plant_id,
    public.materialized_phenoview.seedlot_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plant'))
  GROUP BY 1,2;
ALTER VIEW plantsXseedlots OWNER TO web_usr;

DROP VIEW IF EXISTS public.plotsXseedlots CASCADE;
CREATE VIEW public.plotsXseedlots AS
SELECT public.stock.stock_id AS plot_id,
    public.materialized_phenoview.seedlot_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plot'))
  GROUP BY 1,2;
ALTER VIEW plotsXseedlots OWNER TO web_usr;

DROP VIEW IF EXISTS public.seedlotsXtrait_components CASCADE;
CREATE VIEW public.seedlotsXtrait_components AS
SELECT public.materialized_phenoview.seedlot_id,
trait_component.cvterm_id AS trait_component_id
FROM public.materialized_phenoview
JOIN cvterm trait ON(materialized_phenoview.trait_id = trait.cvterm_id)
JOIN cvterm_relationship ON(trait.cvterm_id = cvterm_relationship.object_id AND cvterm_relationship.type_id = (SELECT cvterm_id from cvterm where name = 'contains'))
JOIN cvterm trait_component ON(cvterm_relationship.subject_id = trait_component.cvterm_id)
GROUP BY 1,2;
ALTER VIEW seedlotsXtrait_components OWNER TO web_usr;

DROP VIEW IF EXISTS public.seedlotsXtraits CASCADE;
CREATE VIEW public.seedlotsXtraits AS
SELECT public.materialized_phenoview.seedlot_id,
    public.materialized_phenoview.trait_id
   FROM public.materialized_phenoview
  GROUP BY 1,2;
ALTER VIEW seedlotsXtraits OWNER TO web_usr;

DROP VIEW IF EXISTS public.seedlotsXtrials CASCADE;
CREATE VIEW public.seedlotsXtrials AS
SELECT public.materialized_phenoview.seedlot_id,
    public.materialized_phenoview.trial_id
   FROM public.materialized_phenoview
  GROUP BY 1,2;
ALTER VIEW seedlotsXtrials OWNER TO web_usr;

DROP VIEW IF EXISTS public.seedlotsXtrial_designs CASCADE;
CREATE VIEW public.seedlotsXtrial_designs AS
SELECT public.materialized_phenoview.seedlot_id,
    trialdesign.value AS trial_design_id
   FROM public.materialized_phenoview
   JOIN public.projectprop trialdesign ON materialized_phenoview.trial_id = trialdesign.project_id AND trialdesign.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'design' )
  GROUP BY 1,2;
ALTER VIEW seedlotsXtrial_designs OWNER TO web_usr;

DROP VIEW IF EXISTS public.seedlotsXtrial_types CASCADE;
CREATE VIEW public.seedlotsXtrial_types AS
SELECT public.materialized_phenoview.seedlot_id,
    trialterm.cvterm_id AS trial_type_id
   FROM public.materialized_phenoview
   JOIN projectprop trialprop ON materialized_phenoview.trial_id = trialprop.project_id AND trialprop.type_id IN (SELECT cvterm_id from cvterm JOIN cv USING(cv_id) WHERE cv.name = 'project_type' )
   JOIN cvterm trialterm ON trialprop.type_id = trialterm.cvterm_id
  GROUP BY 1,2;
ALTER VIEW seedlotsXtrial_types OWNER TO web_usr;

DROP VIEW IF EXISTS public.seedlotsXyears CASCADE;
CREATE VIEW public.seedlotsXyears AS
SELECT public.materialized_phenoview.seedlot_id,
    public.materialized_phenoview.year_id
   FROM public.materialized_phenoview
  GROUP BY 1,2;
ALTER VIEW seedlotsXyears OWNER TO web_usr;

DROP VIEW IF EXISTS public.accessionsXtraits CASCADE;
CREATE VIEW public.accessionsXtraits AS
SELECT public.materialized_phenoview.accession_id,
    public.materialized_phenoview.trait_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.accession_id, public.materialized_phenoview.trait_id;
ALTER VIEW accessionsXtraits OWNER TO web_usr;

DROP VIEW IF EXISTS public.breeding_programsXtraits CASCADE;
CREATE VIEW public.breeding_programsXtraits AS
SELECT public.materialized_phenoview.breeding_program_id,
    public.materialized_phenoview.trait_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.breeding_program_id, public.materialized_phenoview.trait_id;
ALTER VIEW breeding_programsXtraits OWNER TO web_usr;

DROP VIEW IF EXISTS public.genotyping_protocolsXtraits CASCADE;
CREATE VIEW public.genotyping_protocolsXtraits AS
SELECT public.materialized_genoview.genotyping_protocol_id,
    public.materialized_phenoview.trait_id
   FROM public.materialized_genoview
   JOIN public.materialized_phenoview USING(accession_id)
  GROUP BY public.materialized_genoview.genotyping_protocol_id, public.materialized_phenoview.trait_id;
  ALTER VIEW genotyping_protocolsXtraits OWNER TO web_usr;

DROP VIEW IF EXISTS public.locationsXtraits CASCADE;
CREATE VIEW public.locationsXtraits AS
SELECT public.materialized_phenoview.location_id,
    public.materialized_phenoview.trait_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.location_id, public.materialized_phenoview.trait_id;
ALTER VIEW locationsXtraits OWNER TO web_usr;

DROP VIEW IF EXISTS public.plantsXtraits CASCADE;
CREATE VIEW public.plantsXtraits AS
SELECT public.stock.stock_id AS plant_id,
    public.materialized_phenoview.trait_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plant'))
  GROUP BY public.stock.stock_id, public.materialized_phenoview.trait_id;
ALTER VIEW plantsXtraits OWNER TO web_usr;

DROP VIEW IF EXISTS public.plotsXtraits CASCADE;
CREATE VIEW public.plotsXtraits AS
SELECT public.stock.stock_id AS plot_id,
    public.materialized_phenoview.trait_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plot'))
  GROUP BY public.stock.stock_id, public.materialized_phenoview.trait_id;
ALTER VIEW plotsXtraits OWNER TO web_usr;

DROP VIEW IF EXISTS public.subplotsXtraits CASCADE;
CREATE VIEW public.subplotsXtraits AS
select sr.object_id as subplot_id, p.cvalue_id as trait_id from stock_relationship sr 
    join nd_experiment_stock nes on nes.stock_id = sr.object_id
    join nd_experiment_phenotype nep on nep.nd_experiment_id = nes.nd_experiment_id 
    join phenotype p on p.phenotype_id = nep.phenotype_id 
    where sr.type_id = (select cvterm_id from cvterm where name = 'subplot_of')
    group by 1,2;
ALTER VIEW subplotsXtraits OWNER TO web_usr;

DROP VIEW IF EXISTS public.traitsXtrials CASCADE;
CREATE VIEW public.traitsXtrials AS
select  p.cvalue_id as trait_id, nep.project_id as trial_id from nd_experiment_project nep 
join nd_experiment_phenotype nep2 on nep2.nd_experiment_id = nep.nd_experiment_id 
join phenotype p on p.phenotype_id = nep2.phenotype_id
GROUP BY 1,2;
ALTER VIEW traitsXtrials OWNER TO web_usr;

DROP VIEW IF EXISTS public.traitsXtrial_designs CASCADE;
CREATE VIEW public.traitsXtrial_designs AS
SELECT public.materialized_phenoview.trait_id,
    trialdesign.value AS trial_design_id
   FROM public.materialized_phenoview
   JOIN public.projectprop trialdesign ON materialized_phenoview.trial_id = trialdesign.project_id AND trialdesign.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'design' )
  GROUP BY public.materialized_phenoview.trait_id, trialdesign.value;
ALTER VIEW traitsXtrial_designs OWNER TO web_usr;

DROP VIEW IF EXISTS public.traitsXtrial_types CASCADE;
CREATE VIEW public.traitsXtrial_types AS
SELECT public.materialized_phenoview.trait_id,
    trialterm.cvterm_id AS trial_type_id
   FROM public.materialized_phenoview
   JOIN projectprop trialprop ON materialized_phenoview.trial_id = trialprop.project_id AND trialprop.type_id IN (SELECT cvterm_id from cvterm JOIN cv USING(cv_id) WHERE cv.name = 'project_type' )
   JOIN cvterm trialterm ON trialprop.type_id = trialterm.cvterm_id
  GROUP BY public.materialized_phenoview.trait_id, trialterm.cvterm_id;
ALTER VIEW traitsXtrial_types OWNER TO web_usr;

DROP VIEW IF EXISTS public.traitsXyears CASCADE;
CREATE VIEW public.traitsXyears AS
SELECT public.materialized_phenoview.trait_id,
    public.materialized_phenoview.year_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.trait_id, public.materialized_phenoview.year_id;
ALTER VIEW traitsXyears OWNER TO web_usr;

DROP VIEW IF EXISTS public.accessionsXtrait_components CASCADE;
CREATE VIEW public.accessionsXtrait_components AS
SELECT public.materialized_phenoview.accession_id,
    trait_component.cvterm_id AS trait_component_id
   FROM public.materialized_phenoview
   JOIN cvterm trait ON(materialized_phenoview.trait_id = trait.cvterm_id)
   JOIN cvterm_relationship ON(trait.cvterm_id = cvterm_relationship.object_id AND cvterm_relationship.type_id = (SELECT cvterm_id from cvterm where name = 'contains'))
   JOIN cvterm trait_component ON(cvterm_relationship.subject_id = trait_component.cvterm_id)
  GROUP BY 1,2;
ALTER VIEW accessionsXtrait_components OWNER TO web_usr;

DROP VIEW IF EXISTS public.breeding_programsXtrait_components CASCADE;
CREATE VIEW public.breeding_programsXtrait_components AS
SELECT public.materialized_phenoview.breeding_program_id,
trait_component.cvterm_id AS trait_component_id
FROM public.materialized_phenoview
JOIN cvterm trait ON(materialized_phenoview.trait_id = trait.cvterm_id)
JOIN cvterm_relationship ON(trait.cvterm_id = cvterm_relationship.object_id AND cvterm_relationship.type_id = (SELECT cvterm_id from cvterm where name = 'contains'))
JOIN cvterm trait_component ON(cvterm_relationship.subject_id = trait_component.cvterm_id)
GROUP BY 1,2;
ALTER VIEW breeding_programsXtrait_components OWNER TO web_usr;

DROP VIEW IF EXISTS public.genotyping_protocolsXtrait_components CASCADE;
CREATE VIEW public.genotyping_protocolsXtrait_components AS
SELECT public.materialized_genoview.genotyping_protocol_id,
trait_component.cvterm_id AS trait_component_id
FROM public.materialized_genoview
JOIN public.materialized_phenoview USING(accession_id)
JOIN cvterm trait ON(materialized_phenoview.trait_id = trait.cvterm_id)
JOIN cvterm_relationship ON(trait.cvterm_id = cvterm_relationship.object_id AND cvterm_relationship.type_id = (SELECT cvterm_id from cvterm where name = 'contains'))
JOIN cvterm trait_component ON(cvterm_relationship.subject_id = trait_component.cvterm_id)
GROUP BY 1,2;
ALTER VIEW genotyping_protocolsXtrait_components OWNER TO web_usr;

DROP VIEW IF EXISTS public.locationsXtrait_components CASCADE;
CREATE VIEW public.locationsXtrait_components AS
SELECT public.materialized_phenoview.location_id,
trait_component.cvterm_id AS trait_component_id
FROM public.materialized_phenoview
JOIN cvterm trait ON(materialized_phenoview.trait_id = trait.cvterm_id)
JOIN cvterm_relationship ON(trait.cvterm_id = cvterm_relationship.object_id AND cvterm_relationship.type_id = (SELECT cvterm_id from cvterm where name = 'contains'))
JOIN cvterm trait_component ON(cvterm_relationship.subject_id = trait_component.cvterm_id)
GROUP BY 1,2;
ALTER VIEW locationsXtrait_components OWNER TO web_usr;

DROP VIEW IF EXISTS public.plantsXtrait_components CASCADE;
CREATE VIEW public.plantsXtrait_components AS
SELECT public.stock.stock_id AS plant_id,
trait_component.cvterm_id AS trait_component_id
FROM public.materialized_phenoview
JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plant'))
JOIN cvterm trait ON(materialized_phenoview.trait_id = trait.cvterm_id)
JOIN cvterm_relationship ON(trait.cvterm_id = cvterm_relationship.object_id AND cvterm_relationship.type_id = (SELECT cvterm_id from cvterm where name = 'contains'))
JOIN cvterm trait_component ON(cvterm_relationship.subject_id = trait_component.cvterm_id)
GROUP BY 1,2;
ALTER VIEW plantsXtrait_components OWNER TO web_usr;

DROP VIEW IF EXISTS public.plotsXtrait_components CASCADE;
CREATE VIEW public.plotsXtrait_components AS
SELECT public.stock.stock_id AS plot_id,
trait_component.cvterm_id AS trait_component_id
FROM public.materialized_phenoview
JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plot'))
JOIN cvterm trait ON(materialized_phenoview.trait_id = trait.cvterm_id)
JOIN cvterm_relationship ON(trait.cvterm_id = cvterm_relationship.object_id AND cvterm_relationship.type_id = (SELECT cvterm_id from cvterm where name = 'contains'))
JOIN cvterm trait_component ON(cvterm_relationship.subject_id = trait_component.cvterm_id)
GROUP BY 1,2;
ALTER VIEW plotsXtrait_components OWNER TO web_usr;

DROP VIEW IF EXISTS public.trait_componentsXtrials CASCADE;
CREATE VIEW public.trait_componentsXtrials AS
SELECT trait_component.cvterm_id AS trait_component_id,
    public.materialized_phenoview.trial_id
    FROM public.materialized_phenoview
    JOIN cvterm trait ON(materialized_phenoview.trait_id = trait.cvterm_id)
    JOIN cvterm_relationship ON(trait.cvterm_id = cvterm_relationship.object_id AND cvterm_relationship.type_id = (SELECT cvterm_id from cvterm where name = 'contains'))
    JOIN cvterm trait_component ON(cvterm_relationship.subject_id = trait_component.cvterm_id)
    GROUP BY 1,2;
ALTER VIEW trait_componentsXtrials OWNER TO web_usr;

DROP VIEW IF EXISTS public.trait_componentsXtrial_designs CASCADE;
CREATE VIEW public.trait_componentsXtrial_designs AS
SELECT trait_component.cvterm_id AS trait_component_id,
    trialdesign.value AS trial_design_id
   FROM public.materialized_phenoview
   JOIN cvterm trait ON(materialized_phenoview.trait_id = trait.cvterm_id)
   JOIN cvterm_relationship ON(trait.cvterm_id = cvterm_relationship.object_id AND cvterm_relationship.type_id = (SELECT cvterm_id from cvterm where name = 'contains'))
   JOIN cvterm trait_component ON(cvterm_relationship.subject_id = trait_component.cvterm_id)
   JOIN public.projectprop trialdesign ON materialized_phenoview.trial_id = trialdesign.project_id AND trialdesign.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'design' )
  GROUP BY 1,2;
ALTER VIEW trait_componentsXtrial_designs OWNER TO web_usr;

DROP VIEW IF EXISTS public.trait_componentsXtrial_types CASCADE;
CREATE VIEW public.trait_componentsXtrial_types AS
SELECT trait_component.cvterm_id AS trait_component_id,
    trialterm.cvterm_id AS trial_type_id
   FROM public.materialized_phenoview
   JOIN cvterm trait ON(materialized_phenoview.trait_id = trait.cvterm_id)
   JOIN cvterm_relationship ON(trait.cvterm_id = cvterm_relationship.object_id AND cvterm_relationship.type_id = (SELECT cvterm_id from cvterm where name = 'contains'))
   JOIN cvterm trait_component ON(cvterm_relationship.subject_id = trait_component.cvterm_id)
   JOIN projectprop trialprop ON materialized_phenoview.trial_id = trialprop.project_id AND trialprop.type_id IN (SELECT cvterm_id from cvterm JOIN cv USING(cv_id) WHERE cv.name = 'project_type' )
   JOIN cvterm trialterm ON trialprop.type_id = trialterm.cvterm_id
  GROUP BY 1,2;
ALTER VIEW trait_componentsXtrial_types OWNER TO web_usr;

DROP VIEW IF EXISTS public.trait_componentsXyears CASCADE;
CREATE VIEW public.trait_componentsXyears AS
SELECT trait_component.cvterm_id AS trait_component_id,
    public.materialized_phenoview.year_id
   FROM public.materialized_phenoview
   JOIN cvterm trait ON(materialized_phenoview.trait_id = trait.cvterm_id)
   JOIN cvterm_relationship ON(trait.cvterm_id = cvterm_relationship.object_id AND cvterm_relationship.type_id = (SELECT cvterm_id from cvterm where name = 'contains'))
   JOIN cvterm trait_component ON(cvterm_relationship.subject_id = trait_component.cvterm_id)
  GROUP BY 1,2;
ALTER VIEW trait_componentsXyears OWNER TO web_usr;

-- FIX VIEWS FOR PLANTS, PLOTS, TRIAL DESIGNS AND TRIAL TYPES

DROP VIEW IF EXISTS public.accessionsXbreeding_programs CASCADE;
CREATE VIEW public.accessionsXbreeding_programs AS
SELECT public.materialized_phenoview.accession_id,
    public.materialized_phenoview.breeding_program_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.accession_id, public.materialized_phenoview.breeding_program_id;
  ALTER VIEW accessionsXbreeding_programs OWNER TO web_usr;

DROP VIEW IF EXISTS public.accessionsXgenotyping_protocols CASCADE;
CREATE VIEW public.accessionsXgenotyping_protocols AS
SELECT public.materialized_genoview.accession_id,
    public.materialized_genoview.genotyping_protocol_id
   FROM public.materialized_genoview
  GROUP BY public.materialized_genoview.accession_id, public.materialized_genoview.genotyping_protocol_id;
  ALTER VIEW accessionsXgenotyping_protocols OWNER TO web_usr;

DROP VIEW IF EXISTS public.accessionsXlocations CASCADE;
CREATE VIEW public.accessionsXlocations AS
SELECT public.materialized_phenoview.accession_id,
    public.materialized_phenoview.location_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.accession_id, public.materialized_phenoview.location_id;
  ALTER VIEW accessionsXlocations OWNER TO web_usr;

DROP VIEW IF EXISTS public.accessionsXplants CASCADE;
CREATE VIEW public.accessionsXplants AS
SELECT public.materialized_phenoview.accession_id,
    public.stock.stock_id AS plant_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plant'))
  GROUP BY public.materialized_phenoview.accession_id, public.stock.stock_id;
  ALTER VIEW accessionsXplants OWNER TO web_usr;

DROP VIEW IF EXISTS public.accessionsXplots CASCADE;
CREATE VIEW public.accessionsXplots AS
SELECT public.materialized_phenoview.accession_id,
    public.stock.stock_id AS plot_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plot'))
  GROUP BY public.materialized_phenoview.accession_id, public.stock.stock_id;
ALTER VIEW accessionsXplots OWNER TO web_usr;

DROP VIEW IF EXISTS public.accessionsXsubplots CASCADE;
CREATE VIEW public.accessionsXsubplots AS
SELECT public.materialized_phenoview.accession_id,
    public.stock.stock_id AS subplot_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'subplot'))
  GROUP BY public.materialized_phenoview.accession_id, public.stock.stock_id;
ALTER VIEW accessionsXsubplots OWNER TO web_usr;

DROP VIEW IF EXISTS public.accessionsXtrial_designs CASCADE;
CREATE VIEW public.accessionsXtrial_designs AS
SELECT public.materialized_phenoview.accession_id,
    trialdesign.value AS trial_design_id
   FROM public.materialized_phenoview
   JOIN public.projectprop trialdesign ON materialized_phenoview.trial_id = trialdesign.project_id AND trialdesign.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'design' )
  GROUP BY public.materialized_phenoview.accession_id, trialdesign.value;
ALTER VIEW accessionsXtrial_designs OWNER TO web_usr;

DROP VIEW IF EXISTS public.accessionsXtrial_types CASCADE;
CREATE VIEW public.accessionsXtrial_types AS
SELECT public.materialized_phenoview.accession_id,
    trialterm.cvterm_id AS trial_type_id
   FROM public.materialized_phenoview
   JOIN projectprop trialprop ON materialized_phenoview.trial_id = trialprop.project_id AND trialprop.type_id IN (SELECT cvterm_id from cvterm JOIN cv USING(cv_id) WHERE cv.name = 'project_type' )
   JOIN cvterm trialterm ON trialprop.type_id = trialterm.cvterm_id
  GROUP BY public.materialized_phenoview.accession_id, trialterm.cvterm_id;
ALTER VIEW accessionsXtrial_types OWNER TO web_usr;

DROP VIEW IF EXISTS public.accessionsXtrials CASCADE;
CREATE VIEW public.accessionsXtrials AS
SELECT public.materialized_phenoview.accession_id,
    public.materialized_phenoview.trial_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.accession_id, public.materialized_phenoview.trial_id;
ALTER VIEW accessionsXtrials OWNER TO web_usr;

DROP VIEW IF EXISTS public.accessionsXyears CASCADE;
CREATE VIEW public.accessionsXyears AS
SELECT public.materialized_phenoview.accession_id,
    public.materialized_phenoview.year_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.accession_id, public.materialized_phenoview.year_id;
ALTER VIEW accessionsXyears OWNER TO web_usr;

DROP VIEW IF EXISTS public.breeding_programsXgenotyping_protocols CASCADE;
CREATE VIEW public.breeding_programsXgenotyping_protocols AS
SELECT public.materialized_phenoview.breeding_program_id,
    public.materialized_genoview.genotyping_protocol_id
   FROM public.materialized_phenoview
   JOIN public.materialized_genoview USING(accession_id)
  GROUP BY public.materialized_phenoview.breeding_program_id, public.materialized_genoview.genotyping_protocol_id;
ALTER VIEW breeding_programsXgenotyping_protocols OWNER TO web_usr;

DROP VIEW IF EXISTS public.breeding_programsXlocations CASCADE;
CREATE VIEW public.breeding_programsXlocations AS
SELECT public.materialized_phenoview.breeding_program_id,
    public.materialized_phenoview.location_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.breeding_program_id, public.materialized_phenoview.location_id;
ALTER VIEW breeding_programsXlocations OWNER TO web_usr;

DROP VIEW IF EXISTS public.breeding_programsXplants CASCADE;
CREATE VIEW public.breeding_programsXplants AS
SELECT public.materialized_phenoview.breeding_program_id,
    public.stock.stock_id AS plant_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plant'))
  GROUP BY public.materialized_phenoview.breeding_program_id, public.stock.stock_id;
  ALTER VIEW breeding_programsXplants OWNER TO web_usr;

DROP VIEW IF EXISTS public.breeding_programsXplots CASCADE;
CREATE VIEW public.breeding_programsXplots AS
SELECT public.materialized_phenoview.breeding_program_id,
    public.stock.stock_id AS plot_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plot'))
  GROUP BY public.materialized_phenoview.breeding_program_id, public.stock.stock_id;
ALTER VIEW breeding_programsXplots OWNER TO web_usr;

DROP VIEW IF EXISTS public.breeding_programsXsubplots CASCADE;
CREATE VIEW public.breeding_programsXsubplots AS
SELECT public.materialized_phenoview.breeding_program_id,
    public.stock.stock_id AS subplot_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'subplot'))
  GROUP BY public.materialized_phenoview.breeding_program_id, public.stock.stock_id;
ALTER VIEW breeding_programsXsubplots OWNER TO web_usr;


DROP VIEW IF EXISTS public.breeding_programsXtrial_designs CASCADE;
CREATE VIEW public.breeding_programsXtrial_designs AS
SELECT public.materialized_phenoview.breeding_program_id,
    trialdesign.value AS trial_design_id
   FROM public.materialized_phenoview
   JOIN public.projectprop trialdesign ON materialized_phenoview.trial_id = trialdesign.project_id AND trialdesign.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'design' )
  GROUP BY public.materialized_phenoview.breeding_program_id, trialdesign.value;
ALTER VIEW breeding_programsXtrial_designs OWNER TO web_usr;

DROP VIEW IF EXISTS public.breeding_programsXtrial_types CASCADE;
CREATE VIEW public.breeding_programsXtrial_types AS
SELECT public.materialized_phenoview.breeding_program_id,
    trialterm.cvterm_id AS trial_type_id
   FROM public.materialized_phenoview
   JOIN projectprop trialprop ON materialized_phenoview.trial_id = trialprop.project_id AND trialprop.type_id IN (SELECT cvterm_id from cvterm JOIN cv USING(cv_id) WHERE cv.name = 'project_type' )
   JOIN cvterm trialterm ON trialprop.type_id = trialterm.cvterm_id
  GROUP BY public.materialized_phenoview.breeding_program_id, trialterm.cvterm_id;
ALTER VIEW breeding_programsXtrial_types OWNER TO web_usr;

DROP VIEW IF EXISTS public.breeding_programsXtrials CASCADE;
CREATE VIEW public.breeding_programsXtrials AS
SELECT public.materialized_phenoview.breeding_program_id,
    public.materialized_phenoview.trial_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.breeding_program_id, public.materialized_phenoview.trial_id;
ALTER VIEW breeding_programsXtrials OWNER TO web_usr;

DROP VIEW IF EXISTS public.breeding_programsXyears CASCADE;
CREATE VIEW public.breeding_programsXyears AS
SELECT public.materialized_phenoview.breeding_program_id,
    public.materialized_phenoview.year_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.breeding_program_id, public.materialized_phenoview.year_id;
ALTER VIEW breeding_programsXyears OWNER TO web_usr;

DROP VIEW IF EXISTS public.genotyping_protocolsXlocations CASCADE;
CREATE VIEW public.genotyping_protocolsXlocations AS
SELECT public.materialized_genoview.genotyping_protocol_id,
    public.materialized_phenoview.location_id
   FROM public.materialized_genoview
   JOIN public.materialized_phenoview USING(accession_id)
  GROUP BY public.materialized_genoview.genotyping_protocol_id, public.materialized_phenoview.location_id;
ALTER VIEW genotyping_protocolsXlocations OWNER TO web_usr;

DROP VIEW IF EXISTS public.genotyping_protocolsXplants CASCADE;
CREATE VIEW public.genotyping_protocolsXplants AS
SELECT public.materialized_genoview.genotyping_protocol_id,
    public.stock.stock_id AS plant_id
   FROM public.materialized_genoview
   JOIN public.materialized_phenoview USING(accession_id)
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plant'))
  GROUP BY public.materialized_genoview.genotyping_protocol_id, public.stock.stock_id;
  ALTER VIEW genotyping_protocolsXplants OWNER TO web_usr;

DROP VIEW IF EXISTS public.genotyping_protocolsXplots CASCADE;
CREATE VIEW public.genotyping_protocolsXplots AS
SELECT public.materialized_genoview.genotyping_protocol_id,
    public.stock.stock_id AS plot_id
    FROM public.materialized_genoview
    JOIN public.materialized_phenoview USING(accession_id)
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plot'))
  GROUP BY public.materialized_genoview.genotyping_protocol_id, public.stock.stock_id;
ALTER VIEW genotyping_protocolsXplots OWNER TO web_usr;

DROP VIEW IF EXISTS public.genotyping_protocolsXsubplots CASCADE;
CREATE VIEW public.genotyping_protocolsXsubplots AS
SELECT public.materialized_genoview.genotyping_protocol_id,
    public.stock.stock_id AS subplot_id
    FROM public.materialized_genoview
    JOIN public.materialized_phenoview USING(accession_id)
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'subplot'))
  GROUP BY public.materialized_genoview.genotyping_protocol_id, public.stock.stock_id;
ALTER VIEW genotyping_protocolsXsubplots OWNER TO web_usr;

DROP VIEW IF EXISTS public.genotyping_protocolsXtrial_designs CASCADE;
CREATE VIEW public.genotyping_protocolsXtrial_designs AS
SELECT public.materialized_genoview.genotyping_protocol_id,
    trialdesign.value AS trial_design_id
    FROM public.materialized_genoview
    JOIN public.materialized_phenoview USING(accession_id)
   JOIN public.projectprop trialdesign ON materialized_phenoview.trial_id = trialdesign.project_id AND trialdesign.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'design' )
  GROUP BY public.materialized_genoview.genotyping_protocol_id, trialdesign.value;
ALTER VIEW genotyping_protocolsXtrial_designs OWNER TO web_usr;

DROP VIEW IF EXISTS public.genotyping_protocolsXtrial_types CASCADE;
CREATE VIEW public.genotyping_protocolsXtrial_types AS
SELECT public.materialized_genoview.genotyping_protocol_id,
    trialterm.cvterm_id AS trial_type_id
    FROM public.materialized_genoview
    JOIN public.materialized_phenoview USING(accession_id)
   JOIN projectprop trialprop ON materialized_phenoview.trial_id = trialprop.project_id AND trialprop.type_id IN (SELECT cvterm_id from cvterm JOIN cv USING(cv_id) WHERE cv.name = 'project_type' )
   JOIN cvterm trialterm ON trialprop.type_id = trialterm.cvterm_id
  GROUP BY public.materialized_genoview.genotyping_protocol_id, trialterm.cvterm_id;
ALTER VIEW genotyping_protocolsXtrial_types OWNER TO web_usr;

DROP VIEW IF EXISTS public.genotyping_protocolsXtrials CASCADE;
CREATE VIEW public.genotyping_protocolsXtrials AS
SELECT public.materialized_genoview.genotyping_protocol_id,
    public.materialized_phenoview.trial_id
   FROM public.materialized_genoview
   JOIN public.materialized_phenoview USING(accession_id)
  GROUP BY public.materialized_genoview.genotyping_protocol_id, public.materialized_phenoview.trial_id;
ALTER VIEW genotyping_protocolsXtrials OWNER TO web_usr;

DROP VIEW IF EXISTS public.genotyping_protocolsXyears CASCADE;
CREATE VIEW public.genotyping_protocolsXyears AS
SELECT public.materialized_genoview.genotyping_protocol_id,
    public.materialized_phenoview.year_id
   FROM public.materialized_genoview
   JOIN public.materialized_phenoview USING(accession_id)
  GROUP BY public.materialized_genoview.genotyping_protocol_id, public.materialized_phenoview.year_id;
ALTER VIEW genotyping_protocolsXyears OWNER TO web_usr;

DROP VIEW IF EXISTS public.locationsXplants CASCADE;
CREATE VIEW public.locationsXplants AS
SELECT public.materialized_phenoview.location_id,
    public.stock.stock_id AS plant_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plant'))
  GROUP BY public.materialized_phenoview.location_id, public.stock.stock_id;
  ALTER VIEW locationsXplants OWNER TO web_usr;

DROP VIEW IF EXISTS public.locationsXplots CASCADE;
CREATE VIEW public.locationsXplots AS
SELECT public.materialized_phenoview.location_id,
    public.stock.stock_id AS plot_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plot'))
  GROUP BY public.materialized_phenoview.location_id, public.stock.stock_id;
ALTER VIEW locationsXplots OWNER TO web_usr;

DROP VIEW IF EXISTS public.locationsXsubplots CASCADE;
CREATE VIEW public.locationsXsubplots AS
SELECT public.materialized_phenoview.location_id,
    public.stock.stock_id AS subplot_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'subplot'))
  GROUP BY public.materialized_phenoview.location_id, public.stock.stock_id;
ALTER VIEW locationsXsubplots OWNER TO web_usr;

DROP VIEW IF EXISTS public.locationsXtrial_designs CASCADE;
CREATE VIEW public.locationsXtrial_designs AS
SELECT public.materialized_phenoview.location_id,
    trialdesign.value AS trial_design_id
   FROM public.materialized_phenoview
   JOIN public.projectprop trialdesign ON materialized_phenoview.trial_id = trialdesign.project_id AND trialdesign.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'design' )
  GROUP BY public.materialized_phenoview.location_id, trialdesign.value;
ALTER VIEW locationsXtrial_designs OWNER TO web_usr;

DROP VIEW IF EXISTS public.locationsXtrial_types CASCADE;
CREATE VIEW public.locationsXtrial_types AS
SELECT public.materialized_phenoview.location_id,
    trialterm.cvterm_id AS trial_type_id
   FROM public.materialized_phenoview
   JOIN projectprop trialprop ON materialized_phenoview.trial_id = trialprop.project_id AND trialprop.type_id IN (SELECT cvterm_id from cvterm JOIN cv USING(cv_id) WHERE cv.name = 'project_type' )
   JOIN cvterm trialterm ON trialprop.type_id = trialterm.cvterm_id
  GROUP BY public.materialized_phenoview.location_id, trialterm.cvterm_id;
ALTER VIEW locationsXtrial_types OWNER TO web_usr;

DROP VIEW IF EXISTS public.locationsXtrials CASCADE;
CREATE VIEW public.locationsXtrials AS
SELECT public.materialized_phenoview.location_id,
    public.materialized_phenoview.trial_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.location_id, public.materialized_phenoview.trial_id;
ALTER VIEW locationsXtrials OWNER TO web_usr;

DROP VIEW IF EXISTS public.locationsXyears CASCADE;
CREATE VIEW public.locationsXyears AS
SELECT public.materialized_phenoview.location_id,
    public.materialized_phenoview.year_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.location_id, public.materialized_phenoview.year_id;
ALTER VIEW locationsXyears OWNER TO web_usr;

DROP VIEW IF EXISTS public.plantsXplots CASCADE;
CREATE VIEW public.plantsXplots AS
SELECT plant.stock_id AS plant_id,
    plot.stock_id AS plot_id
   FROM public.materialized_phenoview
   JOIN stock plot ON(public.materialized_phenoview.stock_id = plot.stock_id AND plot.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plot'))
   JOIN stock_relationship plant_relationship ON plot.stock_id = plant_relationship.subject_id
   JOIN stock plant ON plant_relationship.object_id = plant.stock_id AND plant.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plant')
  GROUP BY plant.stock_id, plot.stock_id;
ALTER VIEW plantsXplots OWNER TO web_usr;

DROP VIEW IF EXISTS public.subplotsXplots CASCADE;
CREATE VIEW public.subplotsXplots as
SELECT sr.object_id as subplot_id,
s.stock_id AS plot_id
from stock_relationship sr
join stock s on s.stock_id = sr.subject_id 
where sr.type_id = (select cvterm_id from cvterm where name = 'subplot_of')
and s.type_id = (select cvterm_id from cvterm where name = 'plot');
ALTER VIEW public.subplotsXplots OWNER TO web_usr;

DROP VIEW IF EXISTS public.plantsXsubplots CASCADE;
CREATE VIEW public.plantsXsubplots AS
SELECT plant.stock_id AS plant_id,
    plot.stock_id AS subplot_id
   FROM public.materialized_phenoview
   JOIN stock plot ON(public.materialized_phenoview.stock_id = plot.stock_id AND plot.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'subplot'))
   JOIN stock_relationship plant_relationship ON plot.stock_id = plant_relationship.subject_id
   JOIN stock plant ON plant_relationship.object_id = plant.stock_id AND plant.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plant')
  GROUP BY plant.stock_id, plot.stock_id;
ALTER VIEW plantsXsubplots OWNER TO web_usr;

DROP VIEW IF EXISTS public.plantsXtrials CASCADE;
CREATE VIEW public.plantsXtrials AS
SELECT public.stock.stock_id AS plant_id,
    public.materialized_phenoview.trial_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plant'))
  GROUP BY public.stock.stock_id, public.materialized_phenoview.trial_id;
ALTER VIEW plantsXtrials OWNER TO web_usr;

DROP VIEW IF EXISTS public.plantsXtrial_designs CASCADE;
CREATE VIEW public.plantsXtrial_designs AS
SELECT public.stock.stock_id AS plant_id,
    trialdesign.value AS trial_design_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plant'))
   JOIN public.projectprop trialdesign ON materialized_phenoview.trial_id = trialdesign.project_id AND trialdesign.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'design' )
  GROUP BY stock.stock_id, trialdesign.value;
ALTER VIEW plantsXtrial_designs OWNER TO web_usr;

DROP VIEW IF EXISTS public.plantsXtrial_types CASCADE;
CREATE VIEW public.plantsXtrial_types AS
SELECT public.stock.stock_id AS plant_id,
    trialterm.cvterm_id AS trial_type_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plant'))
   JOIN projectprop trialprop ON materialized_phenoview.trial_id = trialprop.project_id AND trialprop.type_id IN (SELECT cvterm_id from cvterm JOIN cv USING(cv_id) WHERE cv.name = 'project_type' )
   JOIN cvterm trialterm ON trialprop.type_id = trialterm.cvterm_id
  GROUP BY public.stock.stock_id, trialterm.cvterm_id;
ALTER VIEW plantsXtrial_types OWNER TO web_usr;

DROP VIEW IF EXISTS public.plantsXyears CASCADE;
CREATE VIEW public.plantsXyears AS
SELECT public.stock.stock_id AS plant_id,
    public.materialized_phenoview.year_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plant'))
  GROUP BY public.stock.stock_id, public.materialized_phenoview.year_id;
ALTER VIEW plantsXyears OWNER TO web_usr;

DROP VIEW IF EXISTS public.plotsXtrials CASCADE;
CREATE VIEW public.plotsXtrials AS
SELECT public.stock.stock_id AS plot_id,
    public.materialized_phenoview.trial_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plot'))
  GROUP BY public.stock.stock_id, public.materialized_phenoview.trial_id;
ALTER VIEW plotsXtrials OWNER TO web_usr;

DROP VIEW IF EXISTS public.subplotsXtrials CASCADE;
CREATE VIEW public.subplotsXtrials AS
SELECT public.stock.stock_id AS subplot_id,
    public.materialized_phenoview.trial_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'subplot'))
  GROUP BY public.stock.stock_id, public.materialized_phenoview.trial_id;
ALTER VIEW subplotsXtrials OWNER TO web_usr;

DROP VIEW IF EXISTS public.tissue_sampleXtrial_designs CASCADE;
CREATE VIEW public.tissue_sampleXtrial_designs AS
SELECT public.stock.stock_id AS tissue_sample_id,
    trialdesign.value AS trial_design_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'tissue_sample'))
   JOIN public.projectprop trialdesign ON materialized_phenoview.trial_id = trialdesign.project_id AND trialdesign.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'design' )
  GROUP BY stock.stock_id, trialdesign.value;
ALTER VIEW tissue_sampleXtrial_designs OWNER TO web_usr;

DROP VIEW IF EXISTS public.plotsXtrial_types CASCADE;
CREATE VIEW public.plotsXtrial_types AS
SELECT public.stock.stock_id AS plot_id,
    trialterm.cvterm_id AS trial_type_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plot'))
   JOIN projectprop trialprop ON materialized_phenoview.trial_id = trialprop.project_id AND trialprop.type_id IN (SELECT cvterm_id from cvterm JOIN cv USING(cv_id) WHERE cv.name = 'project_type' )
   JOIN cvterm trialterm ON trialprop.type_id = trialterm.cvterm_id
  GROUP BY public.stock.stock_id, trialterm.cvterm_id;
ALTER VIEW plotsXtrial_types OWNER TO web_usr;

DROP VIEW IF EXISTS public.subplotsXtrial_types CASCADE;
CREATE VIEW public.subplotsXtrial_types AS
SELECT public.stock.stock_id AS subplot_id,
    trialterm.cvterm_id AS trial_type_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'subplot'))
   JOIN projectprop trialprop ON materialized_phenoview.trial_id = trialprop.project_id AND trialprop.type_id IN (SELECT cvterm_id from cvterm JOIN cv USING(cv_id) WHERE cv.name = 'project_type' )
   JOIN cvterm trialterm ON trialprop.type_id = trialterm.cvterm_id
  GROUP BY public.stock.stock_id, trialterm.cvterm_id;
ALTER VIEW subplotsXtrial_types OWNER TO web_usr;


DROP VIEW IF EXISTS public.plotsXyears CASCADE;
CREATE VIEW public.plotsXyears AS
SELECT public.stock.stock_id AS plot_id,
    public.materialized_phenoview.year_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plot'))
  GROUP BY public.stock.stock_id, public.materialized_phenoview.year_id;
ALTER VIEW plotsXyears OWNER TO web_usr;

DROP VIEW IF EXISTS public.subplotsXyears CASCADE;
CREATE VIEW public.subplotsXyears AS
SELECT public.stock.stock_id AS subplot_id,
    public.materialized_phenoview.year_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'subplot'))
  GROUP BY public.stock.stock_id, public.materialized_phenoview.year_id;
ALTER VIEW subplotsXyears OWNER TO web_usr;

DROP VIEW IF EXISTS public.trial_designsXtrial_types CASCADE;
CREATE VIEW public.trial_designsXtrial_types AS
SELECT trialdesign.value AS trial_design_id,
    trialterm.cvterm_id AS trial_type_id
   FROM public.materialized_phenoview
   JOIN public.projectprop trialdesign ON materialized_phenoview.trial_id = trialdesign.project_id AND trialdesign.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'design' )
   JOIN projectprop trialprop ON materialized_phenoview.trial_id = trialprop.project_id AND trialprop.type_id IN (SELECT cvterm_id from cvterm JOIN cv USING(cv_id) WHERE cv.name = 'project_type' )
   JOIN cvterm trialterm ON trialprop.type_id = trialterm.cvterm_id
  GROUP BY trialdesign.value, trialterm.cvterm_id;
ALTER VIEW trial_designsXtrial_types OWNER TO web_usr;

DROP VIEW IF EXISTS public.trial_designsXtrials CASCADE;
CREATE VIEW public.trial_designsXtrials AS
SELECT trialdesign.value AS trial_design_id,
    public.materialized_phenoview.trial_id
   FROM public.materialized_phenoview
   JOIN public.projectprop trialdesign ON materialized_phenoview.trial_id = trialdesign.project_id AND trialdesign.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'design' )
  GROUP BY trialdesign.value, public.materialized_phenoview.trial_id;
ALTER VIEW trial_designsXtrials OWNER TO web_usr;

DROP VIEW IF EXISTS public.trial_designsXyears CASCADE;
CREATE VIEW public.trial_designsXyears AS
SELECT trialdesign.value AS trial_design_id,
    public.materialized_phenoview.year_id
   FROM public.materialized_phenoview
   JOIN public.projectprop trialdesign ON materialized_phenoview.trial_id = trialdesign.project_id AND trialdesign.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'design' )
  GROUP BY trialdesign.value, public.materialized_phenoview.year_id;
ALTER VIEW trial_designsXyears OWNER TO web_usr;

DROP VIEW IF EXISTS public.trial_typesXtrials CASCADE;
CREATE VIEW public.trial_typesXtrials AS
SELECT trialterm.cvterm_id AS trial_type_id,
    public.materialized_phenoview.trial_id
   FROM public.materialized_phenoview
   JOIN projectprop trialprop ON materialized_phenoview.trial_id = trialprop.project_id AND trialprop.type_id IN (SELECT cvterm_id from cvterm JOIN cv USING(cv_id) WHERE cv.name = 'project_type' )
   JOIN cvterm trialterm ON trialprop.type_id = trialterm.cvterm_id
  GROUP BY trialterm.cvterm_id, public.materialized_phenoview.trial_id;
ALTER VIEW trial_typesXtrials OWNER TO web_usr;

DROP VIEW IF EXISTS public.trial_typesXyears CASCADE;
CREATE VIEW public.trial_typesXyears AS
SELECT trialterm.cvterm_id AS trial_type_id,
    public.materialized_phenoview.year_id
   FROM public.materialized_phenoview
   JOIN projectprop trialprop ON materialized_phenoview.trial_id = trialprop.project_id AND trialprop.type_id IN (SELECT cvterm_id from cvterm JOIN cv USING(cv_id) WHERE cv.name = 'project_type' )
   JOIN cvterm trialterm ON trialprop.type_id = trialterm.cvterm_id
  GROUP BY trialterm.cvterm_id, public.materialized_phenoview.year_id;
ALTER VIEW trial_typesXyears OWNER TO web_usr;

DROP VIEW IF EXISTS public.trialsXyears CASCADE;
CREATE VIEW public.trialsXyears AS
SELECT public.materialized_phenoview.trial_id,
    public.materialized_phenoview.year_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.trial_id, public.materialized_phenoview.year_id;
ALTER VIEW trialsXyears OWNER TO web_usr;

-- ADDING ORGANISMS VIEW --

-- accessionsXorganisms
DROP VIEW IF EXISTS public.accessionsXorganisms CASCADE;
CREATE VIEW public.accessionsXorganisms AS
select s.stock_id as accession_id, s.organism_id
from stock s 
where s.type_id = (select cvterm_id from cvterm where cvterm.name = 'accession')
group by s.stock_id, s.organism_id;
ALTER VIEW accessionsXorganisms OWNER TO web_usr;


-- breeding_programsXorganisms
DROP VIEW IF EXISTS public.breeding_programsXorganisms CASCADE;
CREATE VIEW public.breeding_programsXorganisms AS
SELECT s.organism_id,
    public.materialized_phenoview.breeding_program_id
   FROM public.materialized_phenoview
   join public.stock s on s.stock_id = public.materialized_phenoview.accession_id
   where s.organism_id is not null
   and public.materialized_phenoview.breeding_program_id is not null
  GROUP BY organism_id, public.materialized_phenoview.breeding_program_id;
  ALTER VIEW breeding_programsXorganisms OWNER TO web_usr;


-- organismsXyears
DROP VIEW IF EXISTS public.organismsXyears CASCADE;
CREATE VIEW public.organismsXyears AS
SELECT s.organism_id,
    public.materialized_phenoview.year_id
   FROM public.materialized_phenoview
   join public.stock s on s.stock_id = public.materialized_phenoview.accession_id
   where s.organism_id is not null
   and public.materialized_phenoview.year_id is not null
  GROUP BY organism_id, public.materialized_phenoview.year_id;
ALTER VIEW accessionsXyears OWNER TO web_usr;

-- organismsXtrials
DROP VIEW IF EXISTS public.organismsXtrials CASCADE;
CREATE VIEW public.organismsXtrials AS
SELECT s.organism_id,
    public.materialized_phenoview.trial_id
   FROM public.materialized_phenoview
   left join stock s on s.stock_id = public.materialized_phenoview.accession_id
  GROUP BY s.organism_id, public.materialized_phenoview.trial_id;
ALTER VIEW organismsXtrials OWNER TO web_usr;

-- organismsXtrial_designs
DROP VIEW IF EXISTS public.organismsXtrial_designs CASCADE;
CREATE VIEW public.organismsXtrial_designs AS
SELECT s.organism_id,
    trialdesign.value AS trial_design_id
   FROM public.materialized_phenoview
   JOIN public.projectprop trialdesign ON materialized_phenoview.trial_id = trialdesign.project_id AND trialdesign.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'design' )
   JOIN public.stock s on s.stock_id = public.materialized_phenoview.accession_id  
  GROUP BY organism_id, trialdesign.value;
ALTER VIEW organismsXtrial_designs OWNER TO web_usr;

-- organismsXtrial_types
DROP VIEW IF EXISTS public.organismsXtrial_types CASCADE;
CREATE VIEW public.organismsXtrial_types AS
SELECT s.organism_id,
    trialterm.cvterm_id AS trial_type_id
   FROM public.materialized_phenoview
   JOIN projectprop trialprop ON materialized_phenoview.trial_id = trialprop.project_id AND trialprop.type_id IN (SELECT cvterm_id from cvterm JOIN cv USING(cv_id) WHERE cv.name = 'project_type' )
   JOIN cvterm trialterm ON trialprop.type_id = trialterm.cvterm_id
   JOIN public.stock s on s.stock_id = public.materialized_phenoview.accession_id 
  GROUP BY organism_id, trialterm.cvterm_id;
ALTER VIEW accessionsXtrial_types OWNER TO web_usr;


-- organismsXplots
DROP VIEW IF EXISTS public.organismsXplots CASCADE;
CREATE VIEW public.organismsXplots AS
select s.organism_id, s.stock_id as plot_id
from stock s 
where s.type_id = (select cvterm_id from cvterm where cvterm.name = 'plot')
group by s.stock_id, plot_id;
ALTER VIEW organismsXplots OWNER TO web_usr;

-- organismsXsubplots
DROP VIEW IF EXISTS public.organismsXsubplots CASCADE;
CREATE VIEW public.organismsXsubplots AS
select s.organism_id, s.stock_id as subplot_id
from stock s 
where s.type_id = (select cvterm_id from cvterm where cvterm.name = 'subplot')
group by s.stock_id, subplot_id;
ALTER VIEW organismsXsubplots OWNER TO web_usr;


-- organismsXplants
DROP VIEW IF EXISTS public.organismsXplants CASCADE;
CREATE VIEW public.organismsXplants AS
    select s.organism_id, s.stock_id as plant_id
    from stock s 
    where s.type_id = (select cvterm_id from cvterm where cvterm.name = 'plant')
GROUP BY s.stock_id, plant_id;
ALTER VIEW organismsXplants OWNER TO web_usr;


-- organismsXtissue_sample
DROP VIEW IF EXISTS public.organismsXtissue_sample CASCADE;
CREATE VIEW public.organismsXtissue_sample AS
   select s.organism_id, s.stock_id as tissue_sample_id
   from public.stock s 
   where s.type_id = (select cvterm_id from cvterm where cvterm.name = 'tissue_sample')
   group by s.stock_id, tissue_sample_id;
ALTER VIEW organismsXtissue_sample OWNER TO web_usr;

-- organismsXtraits
DROP VIEW IF EXISTS public.organismsXtraits CASCADE;
CREATE VIEW public.organismsXtraits AS
SELECT s.organism_id, p.cvalue_id AS trait_id
    from public.stock s
    join nd_experiment_stock nes on nes.stock_id = s.stock_id
    join nd_experiment_phenotype nep on nep.nd_experiment_id = nes.nd_experiment_id
    join phenotype p on p.phenotype_id = nep.phenotype_id
GROUP BY s.organism_id, trait_id;
ALTER VIEW organismsXtraits OWNER TO web_usr;

-- organismsXtraits_components
DROP VIEW IF EXISTS public.organismsXtrait_components CASCADE;
CREATE VIEW public.organismsXtrait_components AS
SELECT s.organism_id,
    trait_component.cvterm_id AS trait_component_id
   FROM public.materialized_phenoview
   JOIN stock s on s.stock_id = public.materialized_phenoview.accession_id
   JOIN cvterm trait ON(materialized_phenoview.trait_id = trait.cvterm_id)
   JOIN cvterm_relationship ON(trait.cvterm_id = cvterm_relationship.object_id AND cvterm_relationship.type_id = (SELECT cvterm_id from cvterm where name = 'contains'))
   JOIN cvterm trait_component ON(cvterm_relationship.subject_id = trait_component.cvterm_id)
  GROUP BY 1,2;
ALTER VIEW organismsXtrait_components OWNER TO web_usr;

-- locationsXorganisms
DROP VIEW IF EXISTS public.locationsXorganisms CASCADE;
CREATE VIEW public.locationsXorganisms AS
SELECT s.organism_id,
   public.materialized_phenoview.location_id
   FROM public.materialized_phenoview
   join public.stock s ON s.stock_id = public.materialized_phenoview.accession_id
   where s.organism_id IS NOT NULL -- to skip analysis results
   and public.materialized_phenoview.location_id is not null
GROUP BY s.organism_id, public.materialized_phenoview.location_id;
ALTER VIEW locationsXorganisms OWNER TO web_usr;

--organismsXgenotyping_projects
DROP VIEW IF EXISTS public.genotyping_projectsXorganisms CASCADE;
CREATE VIEW public.genotyping_projectsXorganisms AS 
SELECT s.organism_id, genotyping_project_id
   FROM public.materialized_genoview
   join public.stock s on s.stock_id = accession_id
GROUP BY organism_id, genotyping_project_id;
ALTER VIEW public.genotyping_projectsXorganisms OWNER TO web_usr;

-- organismsXgenotyping_protocols
DROP VIEW IF EXISTS public.genotyping_protocolsXorganisms CASCADE;
CREATE VIEW public.genotyping_protocolsXorganisms AS 
    select s.organism_id,
    genotyping_protocol_id
    FROM public.materialized_genoview
    join public.stock s on s.stock_id = accession_id
GROUP BY organism_id, genotyping_protocol_id;
ALTER VIEW public.genotyping_protocolsXorganisms OWNER TO web_usr;


-- organismsXseedlots
DROP VIEW IF EXISTS public.organismsXseedlots CASCADE;
CREATE VIEW public.organismsXseedlots AS
SELECT s.organism_id, s2.stock_id as seedlot_id from stock s
    JOIN stock_relationship sr on sr.subject_id =s.stock_id
    JOIN stock s2 on s2.stock_id = sr.object_id
    WHERE sr.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'collection_of')
    AND s2.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'seedlot')
    GROUP BY s.organism_id, s2.stock_id;
ALTER VIEW accessionsXseedlots OWNER TO web_usr;


-- ADDING TISSUE SAMPLE VIEWS --

DROP VIEW IF EXISTS public.breeding_programsXtissue_sample CASCADE;
CREATE VIEW public.breeding_programsXtissue_sample AS
SELECT public.materialized_phenoview.breeding_program_id,
    public.stock.stock_id AS tissue_sample_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'tissue_sample'))
  GROUP BY public.materialized_phenoview.breeding_program_id, public.stock.stock_id;
ALTER VIEW breeding_programsXtissue_sample OWNER TO web_usr;

DROP VIEW IF EXISTS public.accessionsXtissue_sample CASCADE;
CREATE VIEW public.accessionsXtissue_sample AS
SELECT public.materialized_phenoview.accession_id,
    public.stock.stock_id AS tissue_sample_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'tissue_sample'))
  GROUP BY public.materialized_phenoview.accession_id, public.stock.stock_id;
ALTER VIEW accessionsXtissue_sample OWNER TO web_usr;

DROP VIEW IF EXISTS public.locationsXtissue_sample CASCADE;
CREATE VIEW public.locationsXtissue_sample AS
SELECT public.materialized_phenoview.location_id,
    public.stock.stock_id AS tissue_sample_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'tissue_sample'))
  GROUP BY public.materialized_phenoview.location_id, public.stock.stock_id;
ALTER VIEW locationsXtissue_sample OWNER TO web_usr;

DROP VIEW IF EXISTS public.tissue_sampleXtrials CASCADE;
CREATE VIEW public.tissue_sampleXtrials AS
SELECT public.stock.stock_id AS tissue_sample_id,
    public.materialized_phenoview.trial_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'tissue_sample'))
  GROUP BY public.stock.stock_id, public.materialized_phenoview.trial_id;
ALTER VIEW tissue_sampleXtrials OWNER TO web_usr;

DROP VIEW IF EXISTS public.tissue_sampleXtrial_designs CASCADE;
CREATE VIEW public.tissue_sampleXtrial_designs AS
SELECT public.stock.stock_id AS tissue_sample_id,
    projectprop.value AS trial_design_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id FROM cvterm WHERE cvterm.name = 'tissue_sample'))
   JOIN public.nd_experiment_stock nes on nes.stock_id = public.stock.stock_id  
   JOIN public.projectprop  on (projectprop.project_id = nes.nd_experiment_id  AND projectprop.type_id = (SELECT cvterm_id FROM cvterm WHERE name = 'design'))
  GROUP BY stock.stock_id, public.projectprop.value;
ALTER VIEW tissue_sampleXtrial_designs OWNER TO web_usr;

DROP VIEW IF EXISTS public.tissue_sampleXtrial_types CASCADE;
CREATE VIEW public.tissue_sampleXtrial_types AS
SELECT public.stock.stock_id AS tissue_sample_id,
    trialterm.cvterm_id AS trial_type_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'tissue_sample'))
   JOIN projectprop trialprop ON materialized_phenoview.trial_id = trialprop.project_id AND trialprop.type_id IN (SELECT cvterm_id from cvterm JOIN cv USING(cv_id) WHERE cv.name = 'project_type' )
   JOIN cvterm trialterm ON trialprop.type_id = trialterm.cvterm_id
  GROUP BY public.stock.stock_id, trialterm.cvterm_id;
ALTER VIEW tissue_sampleXtrial_types OWNER TO web_usr;

DROP VIEW IF EXISTS public.tissue_sampleXyears CASCADE;
CREATE VIEW public.tissue_sampleXyears AS
SELECT public.stock.stock_id AS tissue_sample_id,
    public.materialized_phenoview.year_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'tissue_sample'))
  GROUP BY public.stock.stock_id, public.materialized_phenoview.year_id;
ALTER VIEW tissue_sampleXyears OWNER TO web_usr;

DROP VIEW IF EXISTS public.plotsXtissue_sample CASCADE;
CREATE VIEW public.plotsXtissue_sample AS
SELECT ts.tissue_sample_id, so.stock_id AS plot_id  
    FROM tissue_sample ts
    JOIN stock_relationship sr ON sr.subject_id = ts.tissue_sample_id 
    JOIN stock so ON so.stock_id = sr.object_id  
    WHERE so.type_id = (SELECT cvterm_id FROM cvterm WHERE name = 'plot')
GROUP BY ts.tissue_sample_id, so.stock_id ;
ALTER VIEW public.plotsXtissue_sample OWNER TO web_usr;

DROP VIEW IF EXISTS public.subplotsXtissue_sample CASCADE;
CREATE VIEW public.subplotsXtissue_sample AS
SELECT ts.tissue_sample_id, so.stock_id AS subplot_id  
    FROM tissue_sample ts
    JOIN stock_relationship sr ON sr.subject_id = ts.tissue_sample_id 
    JOIN stock so ON so.stock_id = sr.object_id  
    WHERE so.type_id = (SELECT cvterm_id FROM cvterm WHERE name = 'subplot')
GROUP BY ts.tissue_sample_id, so.stock_id ;
ALTER VIEW public.subplotsXtissue_sample OWNER TO web_usr;

DROP VIEW IF EXISTS public.plantsXtissue_sample CASCADE;
CREATE VIEW public.plantsXtissue_sample AS
SELECT ts.tissue_sample_id, so.stock_id AS plant_id 
    FROM tissue_sample ts
    JOIN stock_relationship sr ON sr.subject_id = ts.tissue_sample_id 
    JOIN stock so ON so.stock_id = sr.object_id  
    WHERE so.type_id = (SELECT cvterm_id FROM cvterm WHERE name = 'plant')
GROUP BY ts.tissue_sample_id, so.stock_id ;
ALTER VIEW plantsXtissue_sample OWNER TO web_usr;

DROP VIEW IF EXISTS public.tissue_sampleXtraits CASCADE;
CREATE VIEW public.tissue_sampleXtraits AS
SELECT public.stock.stock_id AS tissue_sample_id,
    public.materialized_phenoview.trait_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'tissue_sample'))
  GROUP BY public.stock.stock_id, public.materialized_phenoview.trait_id;
ALTER VIEW tissue_sampleXtraits OWNER TO web_usr;

DROP VIEW IF EXISTS public.tissue_sampleXtrait_components CASCADE;
CREATE VIEW public.tissue_sampleXtrait_components AS
SELECT public.stock.stock_id AS tissue_sample_id,
trait_component.cvterm_id AS trait_component_id
FROM public.materialized_phenoview
JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'tissue_sample'))
JOIN cvterm trait ON(materialized_phenoview.trait_id = trait.cvterm_id)
JOIN cvterm_relationship ON(trait.cvterm_id = cvterm_relationship.object_id AND cvterm_relationship.type_id = (SELECT cvterm_id from cvterm where name = 'contains'))
JOIN cvterm trait_component ON(cvterm_relationship.subject_id = trait_component.cvterm_id)
GROUP BY 1,2;
ALTER VIEW tissue_sampleXtrait_components OWNER TO web_usr;

DROP VIEW IF EXISTS public.tissue_sampleXseedlots CASCADE;
CREATE VIEW public.tissue_sampleXseedlots AS
SELECT public.stock.stock_id AS tissue_sample_id,
    public.materialized_phenoview.seedlot_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'tissue_sample'))
  GROUP BY 1,2;
ALTER VIEW tissue_sampleXseedlots OWNER TO web_usr;

CREATE VIEW public.genotyping_projectsXtissue_sample AS
    SELECT materialized_genoview.genotyping_project_id, stock.stock_id AS tissue_sample_id
    FROM materialized_genoview
    JOIN materialized_phenoview USING (accession_id)
    JOIN stock ON materialized_phenoview.stock_id = stock.stock_id AND stock.type_id = (
        SELECT cvterm.cvterm_id
        FROM cvterm
        WHERE cvterm.name = 'tissue_sample'
    )
    GROUP BY 1,2;
ALTER VIEW public.genotyping_projectsXtissue_sample OWNER TO web_usr;

DROP VIEW IF EXISTS public.genotyping_protocolsXtissue_sample CASCADE;
CREATE VIEW public.genotyping_protocolsXtissue_sample AS
SELECT public.materialized_genoview.genotyping_protocol_id,
    public.stock.stock_id AS tissue_sample_id
    FROM public.materialized_genoview
    JOIN public.materialized_phenoview USING(accession_id)
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'tissue_sample'))
  GROUP BY public.materialized_genoview.genotyping_protocol_id, public.stock.stock_id;
ALTER VIEW genotyping_protocolsXtissue_sample OWNER TO web_usr;

-- NEW GENOTYPE PROJECT VIEWS --

-- Drop any remaining genotype project matviews
DROP VIEW IF EXISTS public.genotyping_projects CASCADE;
DROP VIEW IF EXISTS public.accessionsXgenotyping_projects CASCADE;
DROP VIEW IF EXISTS public.breeding_programsXgenotyping_projects CASCADE;
DROP VIEW IF EXISTS public.genotyping_protocolsXgenotyping_projects CASCADE;
DROP VIEW IF EXISTS public.locationsXgenotyping_projects CASCADE;
DROP VIEW IF EXISTS public.trialsXgenotyping_projects CASCADE;
DROP VIEW IF EXISTS public.genotyping_projectsXtraits CASCADE;
DROP VIEW IF EXISTS public.genotyping_projectsXyears CASCADE;
DROP VIEW IF EXISTS public.genotyping_projectsXaccessions CASCADE;
DROP VIEW IF EXISTS public.genotyping_projectsXbreeding_programs CASCADE;
DROP VIEW IF EXISTS public.genotyping_projectsXgenotyping_protocols CASCADE;
DROP VIEW IF EXISTS public.genotyping_projectsXlocations CASCADE;
DROP VIEW IF EXISTS public.genotyping_projectsXtrials CASCADE;

-- Add genotyping_projects view
CREATE VIEW public.genotyping_projects AS
    SELECT project.project_id AS genotyping_project_id, project.name AS genotyping_project_name
    FROM project
    JOIN projectprop USING (project_id)
    WHERE projectprop.type_id = (SELECT cvterm_id FROM public.cvterm WHERE name = 'design')
        AND projectprop.value = 'genotype_data_project';
ALTER VIEW public.genotyping_projects OWNER TO web_usr;

-- Add accessionsXgenotyping_projects view
CREATE VIEW public.accessionsXgenotyping_projects AS 
    SELECT accession_id, genotyping_project_id
    FROM materialized_genoview
    GROUP BY 1,2;
ALTER VIEW public.accessionsXgenotyping_projects OWNER TO web_usr;

-- Add breeding_programsXgenotyping_projects view
CREATE VIEW public.breeding_programsXgenotyping_projects AS 
    SELECT project_relationship.object_project_id AS breeding_program_id,
        project.project_id AS genotyping_project_id
    FROM public.project
    LEFT JOIN public.projectprop ON (project.project_id = projectprop.project_id)
    LEFT JOIN public.project_relationship ON (project.project_id = project_relationship.subject_project_id)
    WHERE projectprop.type_id = (SELECT cvterm_id FROM public.cvterm WHERE name = 'design')
        AND projectprop.value = 'genotype_data_project';
ALTER VIEW public.breeding_programsXgenotyping_projects OWNER TO web_usr;

-- Add genotyping_projectsXgenotyping_protocols view
CREATE VIEW public.genotyping_projectsXgenotyping_protocols AS
    SELECT genotyping_project_id, genotyping_protocol_id
    FROM materialized_genoview
    GROUP BY 1,2;
ALTER VIEW public.genotyping_projectsXgenotyping_protocols OWNER TO web_usr;

-- Add genotyping_projectsXlocations view
CREATE VIEW public.genotyping_projectsXlocations AS
    SELECT materialized_genoview.genotyping_project_id, materialized_phenoview.location_id
    FROM materialized_genoview
    JOIN materialized_phenoview USING (accession_id)
    GROUP BY 1,2;
ALTER VIEW public.genotyping_projectsXlocations OWNER TO web_usr;

-- Add genotyping_projectsXtrials view
CREATE VIEW public.genotyping_projectsXtrials AS
    SELECT materialized_genoview.genotyping_project_id, materialized_phenoview.trial_id
    FROM materialized_genoview
    JOIN materialized_phenoview USING (accession_id)
    GROUP BY 1,2;
ALTER VIEW public.genotyping_projectsXtrials OWNER TO web_usr;

-- Add genotyping_projectsXtraits view
CREATE VIEW public.genotyping_projectsXtraits AS
    SELECT materialized_genoview.genotyping_project_id, materialized_phenoview.trait_id
    FROM materialized_genoview
    JOIN materialized_phenoview USING (accession_id)
    GROUP BY 1,2;
ALTER VIEW public.genotyping_projectsXtraits OWNER TO web_usr;

-- Add genotyping_projectsXyears view
CREATE VIEW public.genotyping_projectsXyears AS
    SELECT projectprop.project_id AS genotyping_project_id, projectprop.value AS year_id
    FROM projectprop
    WHERE projectprop.project_id IN (
        SELECT projectprop.project_id
        FROM projectprop
        WHERE projectprop.type_id = (SELECT cvterm_id FROM public.cvterm WHERE name = 'design')
            AND projectprop.value = 'genotype_data_project'
    )
    AND projectprop.type_id = (SELECT cvterm_id FROM public.cvterm WHERE name = 'project year');
ALTER VIEW public.genotyping_projectsXyears OWNER TO web_usr;

-- Add genotyping_projectsXplants view
CREATE VIEW public.genotyping_projectsXplants AS
    SELECT materialized_genoview.genotyping_project_id, stock.stock_id AS plant_id
    FROM materialized_genoview
    JOIN materialized_phenoview USING (accession_id)
    JOIN stock ON materialized_phenoview.stock_id = stock.stock_id AND stock.type_id = (
        SELECT cvterm.cvterm_id
        FROM cvterm
        WHERE cvterm.name = 'plant'
    )
    GROUP BY 1,2;
ALTER VIEW public.genotyping_projectsXplants OWNER TO web_usr;

-- Add genotyping_projectsXplots view
CREATE VIEW public.genotyping_projectsXplots AS
    SELECT materialized_genoview.genotyping_project_id, stock.stock_id AS plot_id
    FROM materialized_genoview
    JOIN materialized_phenoview USING (accession_id)
    JOIN stock ON materialized_phenoview.stock_id = stock.stock_id AND stock.type_id = (
        SELECT cvterm.cvterm_id
        FROM cvterm
        WHERE cvterm.name = 'plot'
    )
    GROUP BY 1,2;
ALTER VIEW public.genotyping_projectsXplots OWNER TO web_usr;

CREATE VIEW public.genotyping_projectsXsubplots AS
    SELECT materialized_genoview.genotyping_project_id, stock.stock_id AS subplot_id
    FROM materialized_genoview
    JOIN materialized_phenoview USING (accession_id)
    JOIN stock ON materialized_phenoview.stock_id = stock.stock_id AND stock.type_id = (
        SELECT cvterm.cvterm_id
        FROM cvterm
        WHERE cvterm.name = 'subplot'
    )
    GROUP BY 1,2;
ALTER VIEW public.genotyping_projectsXsubplots OWNER TO web_usr;

-- Add genotyping_projectsXseedlots view
CREATE VIEW public.genotyping_projectsXseedlots AS
    SELECT materialized_genoview.genotyping_project_id, stock.stock_id AS seedlot_id
    FROM materialized_genoview
    LEFT JOIN stock_relationship seedlot_relationship ON materialized_genoview.accession_id = seedlot_relationship.subject_id 
        AND seedlot_relationship.type_id IN (SELECT cvterm.cvterm_id FROM cvterm WHERE cvterm.name = 'collection_of')
    LEFT JOIN stock ON seedlot_relationship.object_id = stock.stock_id 
        AND stock.type_id IN (SELECT cvterm.cvterm_id FROM cvterm WHERE cvterm.name = 'seedlot')
    GROUP BY 1,2;
ALTER VIEW public.genotyping_projectsXseedlots OWNER TO web_usr;

-- Add genotyping_projectsXtrait_components view
CREATE VIEW public.genotyping_projectsXtrait_components AS
    SELECT materialized_genoview.genotyping_project_id, trait_component.cvterm_id AS trait_component_id
    FROM materialized_genoview
    JOIN materialized_phenoview USING (accession_id)
    JOIN cvterm trait ON materialized_phenoview.trait_id = trait.cvterm_id
    JOIN cvterm_relationship ON trait.cvterm_id = cvterm_relationship.object_id 
        AND cvterm_relationship.type_id = (SELECT cvterm.cvterm_id FROM cvterm WHERE cvterm.name = 'contains')
    JOIN cvterm trait_component ON cvterm_relationship.subject_id = trait_component.cvterm_id
    GROUP BY 1,2;
ALTER VIEW public.genotyping_projectsXtrait_components OWNER TO web_usr;

-- Add genotyping_projectsXtrial_designs view
CREATE VIEW public.genotyping_projectsXtrial_designs AS
    SELECT materialized_genoview.genotyping_project_id, trialdesign.value AS trial_design_id
    FROM materialized_genoview
    JOIN materialized_phenoview USING (accession_id)
    JOIN projectprop trialdesign ON materialized_phenoview.trial_id = trialdesign.project_id 
        AND trialdesign.type_id = (SELECT cvterm.cvterm_id FROM cvterm WHERE cvterm.name = 'design')
    GROUP BY 1,2;
ALTER VIEW public.genotyping_projectsXtrial_designs OWNER TO web_usr;

-- Add genotyping_projectsXtrial_types view
CREATE VIEW public.genotyping_projectsXtrial_types AS
    SELECT materialized_genoview.genotyping_project_id, trialterm.cvterm_id AS trial_type_id
    FROM materialized_genoview
    JOIN materialized_phenoview USING (accession_id)
    JOIN projectprop trialprop ON materialized_phenoview.trial_id = trialprop.project_id 
        AND trialprop.type_id IN (SELECT cvterm.cvterm_id FROM cvterm JOIN cv USING (cv_id) WHERE cv.name = 'project_type')
    JOIN cvterm trialterm ON trialprop.type_id = trialterm.cvterm_id
    GROUP BY 1,2;
ALTER VIEW genotyping_projectsXtrial_types OWNER TO web_usr;

EOSQL

print "You're done!\n";
}


####
1; #
####