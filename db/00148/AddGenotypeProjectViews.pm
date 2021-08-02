#!/usr/bin/env perl


=head1 NAME

AddGenotypeProjectViews.pm

=head1 SYNOPSIS

mx-run AddGenotypeProjectViews [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch:
 - updates the materialized_genoview matview to include genotype project id column
 - adds the binary genotype_project views

=head1 AUTHOR

Bryan Ellerbrock - original matviews and views
David Waring <djw64@cornell.edu> - genotype_project views

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddGenotypeProjectViews;

use Moose;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch updates the materialized_genoview matview and adds the genotype project binary views


sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    $self->dbh->do(<<EOSQL);
--do your SQL here



-- drop and recreate phenoview with single unique index and no joining through nd_experiment

/* ======= Included in the SpeedUpMatviews DB Patch =========

DROP MATERIALIZED VIEW IF EXISTS public.materialized_phenoview CASCADE;
CREATE MATERIALIZED VIEW public.materialized_phenoview AS
SELECT
  breeding_program.project_id AS breeding_program_id,
  location.value::int AS location_id,
  year.value AS year_id,
  trial.project_id AS trial_id,
  accession.stock_id AS accession_id,
  seedlot.stock_id AS seedlot_id,
  stock.stock_id AS stock_id,
  phenotype.phenotype_id as phenotype_id,
  phenotype.cvalue_id as trait_id
  FROM stock accession
     LEFT JOIN stock_relationship ON accession.stock_id = stock_relationship.object_id AND stock_relationship.type_id IN (SELECT cvterm_id from cvterm where cvterm.name = 'plot_of' OR cvterm.name = 'plant_of' OR cvterm.name = 'analysis_of')
     LEFT JOIN stock ON stock_relationship.subject_id = stock.stock_id AND stock.type_id IN (SELECT cvterm_id from cvterm where cvterm.name = 'plot' OR cvterm.name = 'plant' OR cvterm.name = 'analysis_instance')
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

*/


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


-- EXISTING VIEWS --

-- drop and recreate all the single category matviews as just views

/* ======= Included in the SpeedUpMatviews DB Patch =========

DROP VIEW IF EXISTS public.accessions CASCADE;
CREATE VIEW public.accessions AS
  SELECT stock.stock_id AS accession_id,
  stock.uniquename AS accession_name
  FROM stock
  WHERE stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'accession') AND is_obsolete = 'f'
  GROUP BY stock.stock_id, stock.uniquename;
ALTER VIEW accessions OWNER TO web_usr;

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
CREATE VIEW public.traits AS
  SELECT cvterm.cvterm_id AS trait_id,
  (((cvterm.name::text || '|'::text) || db.name::text) || ':'::text) || dbxref.accession::text AS trait_name
	FROM cv
    JOIN cvprop ON(cv.cv_id = cvprop.cv_id AND cvprop.type_id IN (SELECT cvterm_id from cvterm where cvterm.name = 'trait_ontology'))
    JOIN cvterm ON(cvprop.cv_id = cvterm.cv_id)
	  JOIN dbxref USING(dbxref_id)
    JOIN db ON(dbxref.db_id = db.db_id)
    LEFT JOIN cvterm_relationship is_variable ON cvterm.cvterm_id = is_variable.subject_id AND is_variable.type_id = (SELECT cvterm_id FROM cvterm WHERE name = 'VARIABLE_OF')
    WHERE is_variable.subject_id IS NOT NULL
    GROUP BY 1,2
  UNION
  SELECT cvterm.cvterm_id AS trait_id,
  (((cvterm.name::text || '|'::text) || db.name::text) || ':'::text) || dbxref.accession::text AS trait_name
  FROM cv
    JOIN cvprop ON(cv.cv_id = cvprop.cv_id AND cvprop.type_id IN (SELECT cvterm_id from cvterm where cvterm.name = 'composed_trait_ontology'))
    JOIN cvterm ON(cvprop.cv_id = cvterm.cv_id)
    JOIN dbxref USING(dbxref_id)
    JOIN db ON(dbxref.db_id = db.db_id)
    LEFT JOIN cvterm_relationship is_subject ON cvterm.cvterm_id = is_subject.subject_id
    WHERE is_subject.subject_id IS NOT NULL
    GROUP BY 1,2 ORDER BY 2;
    ALTER VIEW traits OWNER TO web_usr;

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
   GROUP BY projectprop.value;
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

*/


-- drop and recreate all the binary matviews as just views

/* ======= Included in the SpeedUpMatviews DB Patch =========

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

*/

DROP VIEW IF EXISTS public.genotyping_protocolsXseedlots CASCADE;
CREATE VIEW public.genotyping_protocolsXseedlots AS
SELECT public.materialized_genoview.genotyping_protocol_id,
public.stock.stock_id AS seedlot_id
FROM public.materialized_genoview
LEFT JOIN stock_relationship seedlot_relationship ON materialized_genoview.accession_id = seedlot_relationship.subject_id AND seedlot_relationship.type_id IN (SELECT cvterm_id from cvterm where cvterm.name = 'collection_of')
LEFT JOIN stock ON seedlot_relationship.object_id = stock.stock_id AND stock.type_id IN (SELECT cvterm_id from cvterm where cvterm.name = 'seedlot')
  GROUP BY 1,2;
ALTER VIEW genotyping_protocolsXseedlots OWNER TO web_usr;

/* ======= Included in the SpeedUpMatviews DB Patch =========

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

*/

DROP VIEW IF EXISTS public.genotyping_protocolsXtraits CASCADE;
CREATE VIEW public.genotyping_protocolsXtraits AS
SELECT public.materialized_genoview.genotyping_protocol_id,
    public.materialized_phenoview.trait_id
   FROM public.materialized_genoview
   JOIN public.materialized_phenoview USING(accession_id)
  GROUP BY public.materialized_genoview.genotyping_protocol_id, public.materialized_phenoview.trait_id;
  ALTER VIEW genotyping_protocolsXtraits OWNER TO web_usr;

/* ======= Included in the SpeedUpMatviews DB Patch =========

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

DROP VIEW IF EXISTS public.traitsXtrials CASCADE;
CREATE VIEW public.traitsXtrials AS
SELECT public.materialized_phenoview.trait_id,
    public.materialized_phenoview.trial_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.trait_id, public.materialized_phenoview.trial_id;
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

*/

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

/* ======= Included in the SpeedUpMatviews DB Patch =========

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

*/

DROP VIEW IF EXISTS public.accessionsXgenotyping_protocols CASCADE;
CREATE VIEW public.accessionsXgenotyping_protocols AS
SELECT public.materialized_genoview.accession_id,
    public.materialized_genoview.genotyping_protocol_id
   FROM public.materialized_genoview
  GROUP BY public.materialized_genoview.accession_id, public.materialized_genoview.genotyping_protocol_id;
  ALTER VIEW accessionsXgenotyping_protocols OWNER TO web_usr;

/* ======= Included in the SpeedUpMatviews DB Patch =========

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

*/

DROP VIEW IF EXISTS public.breeding_programsXgenotyping_protocols CASCADE;
CREATE VIEW public.breeding_programsXgenotyping_protocols AS
SELECT public.materialized_phenoview.breeding_program_id,
    public.materialized_genoview.genotyping_protocol_id
   FROM public.materialized_phenoview
   JOIN public.materialized_genoview USING(accession_id)
  GROUP BY public.materialized_phenoview.breeding_program_id, public.materialized_genoview.genotyping_protocol_id;
ALTER VIEW breeding_programsXgenotyping_protocols OWNER TO web_usr;

/* ======= Included in the SpeedUpMatviews DB Patch =========

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

*/

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

/* ======= Included in the SpeedUpMatviews DB Patch =========

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

DROP VIEW IF EXISTS public.plotsXtrial_designs CASCADE;
CREATE VIEW public.plotsXtrial_designs AS
SELECT public.stock.stock_id AS plot_id,
    trialdesign.value AS trial_design_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plot'))
   JOIN public.projectprop trialdesign ON materialized_phenoview.trial_id = trialdesign.project_id AND trialdesign.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'design' )
  GROUP BY stock.stock_id, trialdesign.value;
ALTER VIEW plotsXtrial_designs OWNER TO web_usr;

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

DROP VIEW IF EXISTS public.plotsXyears CASCADE;
CREATE VIEW public.plotsXyears AS
SELECT public.stock.stock_id AS plot_id,
    public.materialized_phenoview.year_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plot'))
  GROUP BY public.stock.stock_id, public.materialized_phenoview.year_id;
ALTER VIEW plotsXyears OWNER TO web_usr;

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

*/


-- NEW GENOTYPE PROJECT VIEWS --


-- Drop any remaining genotype project matviews
DROP MATERIALIZED VIEW IF EXISTS public.genotyping_projects CASCADE;
DROP MATERIALIZED VIEW IF EXISTS public.accessionsXgenotyping_projects CASCADE;
DROP MATERIALIZED VIEW IF EXISTS public.breeding_programsXgenotyping_projects CASCADE;
DROP MATERIALIZED VIEW IF EXISTS public.genotyping_protocolsXgenotyping_projects CASCADE;
DROP MATERIALIZED VIEW IF EXISTS public.locationsXgenotyping_projects CASCADE;
DROP MATERIALIZED VIEW IF EXISTS public.trialsXgenotyping_projects CASCADE;
DROP MATERIALIZED VIEW IF EXISTS public.genotyping_projectsXtraits CASCADE;
DROP MATERIALIZED VIEW IF EXISTS public.genotyping_projectsXyears CASCADE;
DROP MATERIALIZED VIEW IF EXISTS public.genotyping_projectsXaccessions CASCADE;
DROP MATERIALIZED VIEW IF EXISTS public.genotyping_projectsXbreeding_programs CASCADE;
DROP MATERIALIZED VIEW IF EXISTS public.genotyping_projectsXgenotyping_protocols CASCADE;
DROP MATERIALIZED VIEW IF EXISTS public.genotyping_projectsXlocations CASCADE;
DROP MATERIALIZED VIEW IF EXISTS public.genotyping_projectsXtrials CASCADE;

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
