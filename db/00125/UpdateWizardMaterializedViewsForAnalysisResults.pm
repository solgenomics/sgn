#!/usr/bin/env perl


=head1 NAME

UpdateMatViews.pm

=head1 SYNOPSIS

mx-run UpdateWizardMaterializedViewsForAnalysisResults [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch updates the materialized views to have analysis results

=head1 AUTHOR

Nicolas Morales 

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package UpdateWizardMaterializedViewsForAnalysisResults;

use Moose;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch updates the materialized views to have analysis results


sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    $self->dbh->do(<<EOSQL);
--do your SQL here

DROP MATERIALIZED VIEW IF EXISTS public.materialized_phenoview CASCADE;
CREATE MATERIALIZED VIEW public.materialized_phenoview AS
SELECT
  breeding_program.project_id AS breeding_program_id,
  nd_experiment.nd_geolocation_id AS location_id,
  projectprop.value AS year_id, 
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
     LEFT JOIN nd_experiment ON(nd_experiment_stock.nd_experiment_id = nd_experiment.nd_experiment_id AND nd_experiment.type_id IN (SELECT cvterm_id from cvterm where cvterm.name IN ('phenotyping_experiment', 'field_layout', 'analysis_experiment')))
     FULL OUTER JOIN nd_geolocation ON nd_experiment.nd_geolocation_id = nd_geolocation.nd_geolocation_id
     LEFT JOIN nd_experiment_project ON nd_experiment_stock.nd_experiment_id = nd_experiment_project.nd_experiment_id
     FULL OUTER JOIN project trial ON nd_experiment_project.project_id = trial.project_id
     LEFT JOIN project_relationship ON trial.project_id = project_relationship.subject_project_id AND project_relationship.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'breeding_program_trial_relationship' )
     FULL OUTER JOIN project breeding_program ON project_relationship.object_project_id = breeding_program.project_id
     LEFT JOIN projectprop ON trial.project_id = projectprop.project_id AND projectprop.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'project year' )
     LEFT JOIN nd_experiment_phenotype ON(nd_experiment_stock.nd_experiment_id = nd_experiment_phenotype.nd_experiment_id)
     LEFT JOIN phenotype ON nd_experiment_phenotype.phenotype_id = phenotype.phenotype_id
  WHERE accession.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'accession')
  ORDER BY breeding_program_id, location_id, trial_id, accession_id, seedlot_id, stock.stock_id, phenotype_id, trait_id
WITH DATA;

CREATE UNIQUE INDEX unq_pheno_idx ON public.materialized_phenoview(stock_id,phenotype_id,trait_id) WITH (fillfactor=100);
CREATE INDEX accession_id_pheno_idx ON public.materialized_phenoview(accession_id) WITH (fillfactor=100);
CREATE INDEX seedlot_id_pheno_idx ON public.materialized_phenoview(seedlot_id) WITH (fillfactor=100);
CREATE INDEX breeding_program_id_idx ON public.materialized_phenoview(breeding_program_id) WITH (fillfactor=100);
CREATE INDEX location_id_idx ON public.materialized_phenoview(location_id) WITH (fillfactor=100);
CREATE INDEX stock_id_idx ON public.materialized_phenoview(stock_id) WITH (fillfactor=100);
CREATE INDEX trial_id_idx ON public.materialized_phenoview(trial_id) WITH (fillfactor=100);
CREATE INDEX year_id_idx ON public.materialized_phenoview(year_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW materialized_phenoview OWNER TO web_usr;

DROP MATERIALIZED VIEW IF EXISTS public.materialized_genoview CASCADE;
CREATE MATERIALIZED VIEW public.materialized_genoview AS
 SELECT COALESCE (stock_relationship.object_id, accession.stock_id) AS accession_id,
    COALESCE (stock_type.name, 'accession') AS stock_type,
    COALESCE (nd_experiment_protocol.nd_protocol_id, nd_experiment_protocol_accession.nd_protocol_id) AS genotyping_protocol_id,
    COALESCE (nd_experiment_genotype.genotype_id, nd_experiment_genotype_accession.genotype_id) AS genotype_id
   FROM stock AS accession
     LEFT JOIN stock_relationship ON accession.stock_id = stock_relationship.object_id AND stock_relationship.type_id IN (SELECT cvterm_id from cvterm where cvterm.name = 'tissue_sample_of')
     LEFT JOIN stock ON stock_relationship.subject_id = stock.stock_id AND stock.type_id IN (SELECT cvterm_id from cvterm where cvterm.name = 'tissue_sample')
     LEFT JOIN cvterm AS stock_type ON (stock_type.cvterm_id = stock.type_id)
     LEFT JOIN nd_experiment_stock ON stock.stock_id = nd_experiment_stock.stock_id
     LEFT JOIN nd_experiment_protocol ON nd_experiment_stock.nd_experiment_id = nd_experiment_protocol.nd_experiment_id
     LEFT JOIN nd_protocol ON nd_experiment_protocol.nd_protocol_id = nd_protocol.nd_protocol_id
     LEFT JOIN nd_experiment_genotype ON nd_experiment_stock.nd_experiment_id = nd_experiment_genotype.nd_experiment_id
     LEFT JOIN nd_experiment_stock AS nd_experiment_stock_accession ON accession.stock_id = nd_experiment_stock_accession.stock_id
     LEFT JOIN nd_experiment_protocol AS nd_experiment_protocol_accession ON nd_experiment_stock_accession.nd_experiment_id = nd_experiment_protocol_accession.nd_experiment_id
     LEFT JOIN nd_protocol AS nd_protocol_accession ON nd_experiment_protocol_accession.nd_protocol_id = nd_protocol_accession.nd_protocol_id
     LEFT JOIN nd_experiment_genotype AS nd_experiment_genotype_accession ON nd_experiment_stock_accession.nd_experiment_id = nd_experiment_genotype_accession.nd_experiment_id
  WHERE accession.type_id IN (SELECT cvterm_id from cvterm where cvterm.name = 'accession') AND (nd_experiment_genotype.genotype_id IS NOT NULL OR nd_experiment_genotype_accession.genotype_id IS NOT NULL)
  GROUP BY 1,2,3,4
  WITH DATA;

CREATE UNIQUE INDEX unq_geno_idx ON public.materialized_genoview(accession_id,genotype_id) WITH (fillfactor=100);
CREATE INDEX accession_id_geno_idx ON public.materialized_genoview(accession_id) WITH (fillfactor=100);
CREATE INDEX genotyping_protocol_id_idx ON public.materialized_genoview(genotyping_protocol_id) WITH (fillfactor=100);
CREATE INDEX genotype_id_idx ON public.materialized_genoview(genotype_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW materialized_genoview OWNER TO web_usr;

UPDATE matviews set mv_dependents = '{"accessionsXbreeding_programs","accessionsXlocations","accessionsXplants","accessionsXplots","accessionsXseedlots","accessionsXtrait_components","accessionsXtraits","accessionsXtrials","accessionsXtrial_designs","accessionsXtrial_types","accessionsXyears","breeding_programsXgenotyping_protocols","breeding_programsXlocations","breeding_programsXplants","breeding_programsXplots","breeding_programsXseedlots","breeding_programsXtrait_components","breeding_programsXtraits","breeding_programsXtrials","breeding_programsXtrial_designs","breeding_programsXtrial_types","breeding_programsXyears","genotyping_protocolsXlocations","genotyping_protocolsXplants","genotyping_protocolsXplots","genotyping_protocolsXseedlots","genotyping_protocolsXtrait_components","genotyping_protocolsXtraits","genotyping_protocolsXtrials","genotyping_protocolsXtrial_designs","genotyping_protocolsXtrial_types","genotyping_protocolsXyears","locationsXplants","locationsXplots","locationsXseedlots","locationsXtrait_components","locationsXtraits","locationsXtrials","locationsXtrial_designs","locationsXtrial_types","locationsXyears","plantsXplots","plantsXseedlots","plantsXtrait_components","plantsXtraits","plantsXtrials","plantsXtrial_designs","plantsXtrial_types","plantsXyears","plotsXseedlots","plotsXtrait_components","plotsXtraits","plotsXtrials","plotsXtrial_designs","plotsXtrial_types","plotsXyears","seedlotsXtrait_components","seedlotsXtraits","seedlotsXtrial_designs","seedlotsXtrial_types","seedlotsXtrials","seedlotsXyears","trait_componentsXtraits","trait_componentsXtrial_designs","trait_componentsXtrial_types","trait_componentsXtrials","trait_componentsXyears","traitsXtrials","traitsXtrial_designs","traitsXtrial_types","traitsXyears","trial_designsXtrials","trial_typesXtrials","trialsXyears","trial_designsXtrial_types","trial_designsXyears","trial_typesXyears"}' WHERE mv_name = 'materialized_phenoview';

--add seedlots view

DROP MATERIALIZED VIEW IF EXISTS public.seedlots CASCADE;
CREATE MATERIALIZED VIEW public.seedlots AS
SELECT stock.stock_id AS seedlot_id,
stock.uniquename AS seedlot_name
FROM stock
WHERE stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'seedlot') AND is_obsolete = 'f'
GROUP BY 1,2
WITH DATA;
CREATE UNIQUE INDEX seedlots_idx ON public.seedlots(seedlot_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW seedlots OWNER TO web_usr;

-- add other individual category views

DROP MATERIALIZED VIEW IF EXISTS public.accessions CASCADE;
CREATE MATERIALIZED VIEW public.accessions AS
  SELECT stock.stock_id AS accession_id,
  stock.uniquename AS accession_name
  FROM stock
  WHERE stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'accession') AND is_obsolete = 'f'
  GROUP BY stock.stock_id, stock.uniquename
  WITH DATA;
CREATE UNIQUE INDEX accessions_idx ON public.accessions(accession_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW accessions OWNER TO web_usr;

DROP MATERIALIZED VIEW IF EXISTS public.breeding_programs CASCADE;
CREATE MATERIALIZED VIEW public.breeding_programs AS
SELECT project.project_id AS breeding_program_id,
    project.name AS breeding_program_name
   FROM project join projectprop USING (project_id)
   WHERE projectprop.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'breeding_program')
  GROUP BY project.project_id, project.name
WITH DATA;
CREATE UNIQUE INDEX breeding_programs_idx ON public.breeding_programs(breeding_program_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW breeding_programs OWNER TO web_usr;

DROP MATERIALIZED VIEW IF EXISTS public.genotyping_protocols CASCADE;
CREATE MATERIALIZED VIEW public.genotyping_protocols AS
SELECT nd_protocol.nd_protocol_id AS genotyping_protocol_id,
    nd_protocol.name AS genotyping_protocol_name
   FROM nd_protocol
   WHERE nd_protocol.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'genotyping_experiment')
  GROUP BY public.nd_protocol.nd_protocol_id, public.nd_protocol.name
WITH DATA;
CREATE UNIQUE INDEX genotyping_protocols_idx ON public.genotyping_protocols(genotyping_protocol_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW genotyping_protocols OWNER TO web_usr;

DROP MATERIALIZED VIEW IF EXISTS public.locations CASCADE;
CREATE MATERIALIZED VIEW public.locations AS
SELECT nd_geolocation.nd_geolocation_id AS location_id,
  nd_geolocation.description AS location_name
   FROM nd_geolocation
  GROUP BY public.nd_geolocation.nd_geolocation_id, public.nd_geolocation.description
WITH DATA;
CREATE UNIQUE INDEX locations_idx ON public.locations(location_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW locations OWNER TO web_usr;

DROP MATERIALIZED VIEW IF EXISTS public.plants CASCADE;
CREATE MATERIALIZED VIEW public.plants AS
SELECT stock.stock_id AS plant_id,
    stock.uniquename AS plant_name
   FROM stock
   WHERE stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plant') AND is_obsolete = 'f'
  GROUP BY public.stock.stock_id, public.stock.uniquename
WITH DATA;
CREATE UNIQUE INDEX plants_idx ON public.plants(plant_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW plants OWNER TO web_usr;

DROP MATERIALIZED VIEW IF EXISTS public.plots CASCADE;
CREATE MATERIALIZED VIEW public.plots AS
SELECT stock.stock_id AS plot_id,
    stock.uniquename AS plot_name
   FROM stock
   WHERE stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plot') AND is_obsolete = 'f'
  GROUP BY public.stock.stock_id, public.stock.uniquename
WITH DATA;
CREATE UNIQUE INDEX plots_idx ON public.plots(plot_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW plots OWNER TO web_usr;

DROP MATERIALIZED VIEW IF EXISTS public.trait_components CASCADE;
CREATE MATERIALIZED VIEW public.trait_components AS
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
    GROUP BY 2,1 ORDER BY 2,1
WITH DATA;
CREATE UNIQUE INDEX trait_components_idx ON public.trait_components(trait_component_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW trait_components OWNER TO web_usr;
    
DROP MATERIALIZED VIEW IF EXISTS public.traits CASCADE;
CREATE MATERIALIZED VIEW public.traits AS
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
    GROUP BY 1,2 ORDER BY 2
  WITH DATA;
  CREATE UNIQUE INDEX traits_idx ON public.traits(trait_id) WITH (fillfactor=100);
  ALTER MATERIALIZED VIEW traits OWNER TO web_usr;

DROP MATERIALIZED VIEW IF EXISTS public.trials CASCADE;
CREATE MATERIALIZED VIEW public.trials AS
SELECT trial.project_id AS trial_id,
    trial.name AS trial_name
    FROM project breeding_program
    JOIN project_relationship ON(breeding_program.project_id = object_project_id AND project_relationship.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'breeding_program_trial_relationship'))
    JOIN project trial ON(subject_project_id = trial.project_id)
    JOIN projectprop on(trial.project_id = projectprop.project_id)
    WHERE projectprop.type_id NOT IN (SELECT cvterm.cvterm_id FROM cvterm WHERE cvterm.name::text = 'cross'::text OR cvterm.name::text = 'trial_folder'::text OR cvterm.name::text = 'folder_for_trials'::text OR cvterm.name::text = 'folder_for_crosses'::text)
    GROUP BY trial.project_id, trial.name
WITH DATA;
CREATE UNIQUE INDEX trials_idx ON public.trials(trial_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW trials OWNER TO web_usr;

DROP MATERIALIZED VIEW IF EXISTS public.trial_designs CASCADE;
CREATE MATERIALIZED VIEW public.trial_designs AS
SELECT projectprop.value AS trial_design_id,
  projectprop.value AS trial_design_name
   FROM projectprop
   JOIN cvterm ON(projectprop.type_id = cvterm.cvterm_id)
   WHERE cvterm.name = 'design'
   GROUP BY projectprop.value
WITH DATA;
CREATE UNIQUE INDEX trial_designs_idx ON public.trial_designs(trial_design_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW trial_designs OWNER TO web_usr;

DROP MATERIALIZED VIEW IF EXISTS public.trial_types CASCADE;
CREATE MATERIALIZED VIEW public.trial_types AS
SELECT cvterm.cvterm_id AS trial_type_id,
  cvterm.name AS trial_type_name
   FROM cvterm
   JOIN cv USING(cv_id)
   WHERE cv.name = 'project_type'
   GROUP BY cvterm.cvterm_id
WITH DATA;
CREATE UNIQUE INDEX trial_types_idx ON public.trial_types(trial_type_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW trial_types OWNER TO web_usr;

DROP MATERIALIZED VIEW IF EXISTS public.years CASCADE;
CREATE MATERIALIZED VIEW public.years AS
SELECT projectprop.value AS year_id,
  projectprop.value AS year_name
   FROM projectprop
   WHERE projectprop.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'project year')
  GROUP BY public.projectprop.value
WITH DATA;
CREATE UNIQUE INDEX years_idx ON public.years(year_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW years OWNER TO web_usr;

-- add seedlots binary views and ADD BACK remaining BINARY VIEWS that were dropped during cascade

DROP MATERIALIZED VIEW IF EXISTS public.accessionsXseedlots CASCADE;
CREATE MATERIALIZED VIEW public.accessionsXseedlots AS
SELECT public.materialized_phenoview.accession_id,
    public.stock.stock_id AS seedlot_id
   FROM public.materialized_phenoview
   LEFT JOIN stock_relationship seedlot_relationship ON materialized_phenoview.accession_id = seedlot_relationship.subject_id AND seedlot_relationship.type_id IN (SELECT cvterm_id from cvterm where cvterm.name = 'collection_of')
   LEFT JOIN stock ON seedlot_relationship.object_id = stock.stock_id AND stock.type_id IN (SELECT cvterm_id from cvterm where cvterm.name = 'seedlot')
  GROUP BY public.materialized_phenoview.accession_id,public.stock.stock_id
WITH DATA;
CREATE UNIQUE INDEX accessionsXseedlots_idx ON public.accessionsXseedlots(accession_id, seedlot_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW accessionsXseedlots OWNER TO web_usr;

DROP MATERIALIZED VIEW IF EXISTS public.breeding_programsXseedlots CASCADE;
CREATE MATERIALIZED VIEW public.breeding_programsXseedlots AS
SELECT public.materialized_phenoview.breeding_program_id,
    public.nd_experiment_stock.stock_id AS seedlot_id
   FROM public.materialized_phenoview
   LEFT JOIN nd_experiment_project ON materialized_phenoview.breeding_program_id = nd_experiment_project.project_id
   LEFT JOIN nd_experiment ON nd_experiment_project.nd_experiment_id = nd_experiment.nd_experiment_id AND nd_experiment.type_id IN (SELECT cvterm_id from cvterm where cvterm.name = 'seedlot_experiment')
   LEFT JOIN nd_experiment_stock ON nd_experiment.nd_experiment_id = nd_experiment_stock.nd_experiment_id
  GROUP BY 1,2
WITH DATA;
CREATE UNIQUE INDEX breeding_programsXseedlots_idx ON public.breeding_programsXseedlots(breeding_program_id, seedlot_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW breeding_programsXseedlots OWNER TO web_usr;

DROP MATERIALIZED VIEW IF EXISTS public.genotyping_protocolsXseedlots CASCADE;
CREATE MATERIALIZED VIEW public.genotyping_protocolsXseedlots AS
SELECT public.materialized_genoview.genotyping_protocol_id,
public.stock.stock_id AS seedlot_id
FROM public.materialized_genoview
LEFT JOIN stock_relationship seedlot_relationship ON materialized_genoview.accession_id = seedlot_relationship.subject_id AND seedlot_relationship.type_id IN (SELECT cvterm_id from cvterm where cvterm.name = 'collection_of')
LEFT JOIN stock ON seedlot_relationship.object_id = stock.stock_id AND stock.type_id IN (SELECT cvterm_id from cvterm where cvterm.name = 'seedlot')
  GROUP BY 1,2
WITH DATA;
CREATE UNIQUE INDEX genotyping_protocolsXseedlots_idx ON public.genotyping_protocolsXseedlots(genotyping_protocol_id, seedlot_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW genotyping_protocolsXseedlots OWNER TO web_usr;

DROP MATERIALIZED VIEW IF EXISTS public.locationsXseedlots CASCADE;
CREATE MATERIALIZED VIEW public.locationsXseedlots AS
SELECT public.nd_experiment.nd_geolocation_id AS location_id,
public.nd_experiment_stock.stock_id AS seedlot_id
FROM nd_experiment
LEFT JOIN nd_experiment_stock ON nd_experiment.nd_experiment_id = nd_experiment_stock.nd_experiment_id
WHERE nd_experiment.type_id IN (SELECT cvterm_id from cvterm where cvterm.name = 'seedlot_experiment')
GROUP BY 1,2
WITH DATA;
CREATE UNIQUE INDEX locationsXseedlots_idx ON public.locationsXseedlots(location_id, seedlot_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW locationsXseedlots OWNER TO web_usr;

DROP MATERIALIZED VIEW IF EXISTS public.plantsXseedlots CASCADE;
CREATE MATERIALIZED VIEW public.plantsXseedlots AS
SELECT public.stock.stock_id AS plant_id,
    public.materialized_phenoview.seedlot_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plant'))
  GROUP BY 1,2
WITH DATA;
CREATE UNIQUE INDEX plantsXseedlots_idx ON public.plantsXseedlots(plant_id, seedlot_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW plantsXseedlots OWNER TO web_usr;

DROP MATERIALIZED VIEW IF EXISTS public.plotsXseedlots CASCADE;
CREATE MATERIALIZED VIEW public.plotsXseedlots AS
SELECT public.stock.stock_id AS plot_id,
    public.materialized_phenoview.seedlot_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plot'))
  GROUP BY 1,2
WITH DATA;
CREATE UNIQUE INDEX plotsXseedlots_idx ON public.plotsXseedlots(plot_id, seedlot_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW plotsXseedlots OWNER TO web_usr;

DROP MATERIALIZED VIEW IF EXISTS public.seedlotsXtrait_components CASCADE;
CREATE MATERIALIZED VIEW public.seedlotsXtrait_components AS
SELECT public.materialized_phenoview.seedlot_id,
trait_component.cvterm_id AS trait_component_id
FROM public.materialized_phenoview
JOIN cvterm trait ON(materialized_phenoview.trait_id = trait.cvterm_id)
JOIN cvterm_relationship ON(trait.cvterm_id = cvterm_relationship.object_id AND cvterm_relationship.type_id = (SELECT cvterm_id from cvterm where name = 'contains'))
JOIN cvterm trait_component ON(cvterm_relationship.subject_id = trait_component.cvterm_id)
GROUP BY 1,2
WITH DATA;
CREATE UNIQUE INDEX seedlotsXtrait_components_idx ON public.seedlotsXtrait_components(seedlot_id, trait_component_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW seedlotsXtrait_components OWNER TO web_usr;

DROP MATERIALIZED VIEW IF EXISTS public.seedlotsXtraits CASCADE;
CREATE MATERIALIZED VIEW public.seedlotsXtraits AS
SELECT public.materialized_phenoview.seedlot_id,
    public.materialized_phenoview.trait_id
   FROM public.materialized_phenoview
  GROUP BY 1,2
WITH DATA;
CREATE UNIQUE INDEX seedlotsXtraits_idx ON public.seedlotsXtraits(seedlot_id, trait_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW seedlotsXtraits OWNER TO web_usr;

DROP MATERIALIZED VIEW IF EXISTS public.seedlotsXtrials CASCADE;
CREATE MATERIALIZED VIEW public.seedlotsXtrials AS
SELECT public.materialized_phenoview.seedlot_id,
    public.materialized_phenoview.trial_id
   FROM public.materialized_phenoview
  GROUP BY 1,2
WITH DATA;
CREATE UNIQUE INDEX seedlotsXtrials_idx ON public.seedlotsXtrials(seedlot_id, trial_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW seedlotsXtrials OWNER TO web_usr;

DROP MATERIALIZED VIEW IF EXISTS public.seedlotsXtrial_designs CASCADE;
CREATE MATERIALIZED VIEW public.seedlotsXtrial_designs AS
SELECT public.materialized_phenoview.seedlot_id,
    trialdesign.value AS trial_design_id
   FROM public.materialized_phenoview
   JOIN public.projectprop trialdesign ON materialized_phenoview.trial_id = trialdesign.project_id AND trialdesign.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'design' )
  GROUP BY 1,2
WITH DATA;
CREATE UNIQUE INDEX seedlotsXtrial_designs_idx ON public.seedlotsXtrial_designs(seedlot_id, trial_design_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW seedlotsXtrial_designs OWNER TO web_usr;

DROP MATERIALIZED VIEW IF EXISTS public.seedlotsXtrial_types CASCADE;
CREATE MATERIALIZED VIEW public.seedlotsXtrial_types AS
SELECT public.materialized_phenoview.seedlot_id,
    trialterm.cvterm_id AS trial_type_id
   FROM public.materialized_phenoview
   JOIN projectprop trialprop ON materialized_phenoview.trial_id = trialprop.project_id AND trialprop.type_id IN (SELECT cvterm_id from cvterm JOIN cv USING(cv_id) WHERE cv.name = 'project_type' )
   JOIN cvterm trialterm ON trialprop.type_id = trialterm.cvterm_id
  GROUP BY 1,2
WITH DATA;
CREATE UNIQUE INDEX seedlotsXtrial_types_idx ON public.seedlotsXtrial_types(seedlot_id, trial_type_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW seedlotsXtrial_types OWNER TO web_usr;

DROP MATERIALIZED VIEW IF EXISTS public.seedlotsXyears CASCADE;
CREATE MATERIALIZED VIEW public.seedlotsXyears AS
SELECT public.materialized_phenoview.seedlot_id,
    public.materialized_phenoview.year_id
   FROM public.materialized_phenoview
  GROUP BY 1,2
WITH DATA;
CREATE UNIQUE INDEX seedlotsXyears_idx ON public.seedlotsXyears(seedlot_id, year_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW seedlotsXyears OWNER TO web_usr;

DROP MATERIALIZED VIEW IF EXISTS public.accessionsXtraits CASCADE;
CREATE MATERIALIZED VIEW public.accessionsXtraits AS
SELECT public.materialized_phenoview.accession_id,
    public.materialized_phenoview.trait_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.accession_id, public.materialized_phenoview.trait_id
WITH DATA;
CREATE UNIQUE INDEX accessionsXtraits_idx ON public.accessionsXtraits(accession_id, trait_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW accessionsXtraits OWNER TO web_usr;

CREATE MATERIALIZED VIEW public.breeding_programsXtraits AS
SELECT public.materialized_phenoview.breeding_program_id,
    public.materialized_phenoview.trait_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.breeding_program_id, public.materialized_phenoview.trait_id
WITH DATA;
CREATE UNIQUE INDEX breeding_programsXtraits_idx ON public.breeding_programsXtraits(breeding_program_id, trait_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW breeding_programsXtraits OWNER TO web_usr;

CREATE MATERIALIZED VIEW public.genotyping_protocolsXtraits AS
SELECT public.materialized_genoview.genotyping_protocol_id,
    public.materialized_phenoview.trait_id
   FROM public.materialized_genoview
   JOIN public.materialized_phenoview USING(accession_id)
  GROUP BY public.materialized_genoview.genotyping_protocol_id, public.materialized_phenoview.trait_id
  WITH DATA;
CREATE UNIQUE INDEX genotyping_protocolsXtraits_idx ON public.genotyping_protocolsXtraits(genotyping_protocol_id, trait_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW genotyping_protocolsXtraits OWNER TO web_usr;

CREATE MATERIALIZED VIEW public.locationsXtraits AS
SELECT public.materialized_phenoview.location_id,
    public.materialized_phenoview.trait_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.location_id, public.materialized_phenoview.trait_id
WITH DATA;
CREATE UNIQUE INDEX locationsXtraits_idx ON public.locationsXtraits(location_id, trait_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW locationsXtraits OWNER TO web_usr;

CREATE MATERIALIZED VIEW public.plantsXtraits AS
SELECT public.stock.stock_id AS plant_id,
    public.materialized_phenoview.trait_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plant'))
  GROUP BY public.stock.stock_id, public.materialized_phenoview.trait_id
WITH DATA;
CREATE UNIQUE INDEX plantsXtraits_idx ON public.plantsXtraits(plant_id, trait_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW plantsXtraits OWNER TO web_usr;

CREATE MATERIALIZED VIEW public.plotsXtraits AS
SELECT public.stock.stock_id AS plot_id,
    public.materialized_phenoview.trait_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plot'))
  GROUP BY public.stock.stock_id, public.materialized_phenoview.trait_id
WITH DATA;
CREATE UNIQUE INDEX plotsXtraits_idx ON public.plotsXtraits(plot_id, trait_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW plotsXtraits OWNER TO web_usr;

CREATE MATERIALIZED VIEW public.traitsXtrials AS
SELECT public.materialized_phenoview.trait_id,
    public.materialized_phenoview.trial_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.trait_id, public.materialized_phenoview.trial_id
WITH DATA;
CREATE UNIQUE INDEX traitsXtrials_idx ON public.traitsXtrials(trait_id, trial_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW traitsXtrials OWNER TO web_usr;

CREATE MATERIALIZED VIEW public.traitsXtrial_designs AS
SELECT public.materialized_phenoview.trait_id,
    trialdesign.value AS trial_design_id
   FROM public.materialized_phenoview
   JOIN public.projectprop trialdesign ON materialized_phenoview.trial_id = trialdesign.project_id AND trialdesign.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'design' )
  GROUP BY public.materialized_phenoview.trait_id, trialdesign.value
WITH DATA;
CREATE UNIQUE INDEX traitsXtrial_designs_idx ON public.traitsXtrial_designs(trait_id, trial_design_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW traitsXtrial_designs OWNER TO web_usr;

CREATE MATERIALIZED VIEW public.traitsXtrial_types AS
SELECT public.materialized_phenoview.trait_id,
    trialterm.cvterm_id AS trial_type_id
   FROM public.materialized_phenoview
   JOIN projectprop trialprop ON materialized_phenoview.trial_id = trialprop.project_id AND trialprop.type_id IN (SELECT cvterm_id from cvterm JOIN cv USING(cv_id) WHERE cv.name = 'project_type' )
   JOIN cvterm trialterm ON trialprop.type_id = trialterm.cvterm_id
  GROUP BY public.materialized_phenoview.trait_id, trialterm.cvterm_id
WITH DATA;
CREATE UNIQUE INDEX traitsXtrial_types_idx ON public.traitsXtrial_types(trait_id, trial_type_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW traitsXtrial_types OWNER TO web_usr;

CREATE MATERIALIZED VIEW public.traitsXyears AS
SELECT public.materialized_phenoview.trait_id,
    public.materialized_phenoview.year_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.trait_id, public.materialized_phenoview.year_id
WITH DATA;
CREATE UNIQUE INDEX traitsXyears_idx ON public.traitsXyears(trait_id, year_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW traitsXyears OWNER TO web_usr;



CREATE MATERIALIZED VIEW public.accessionsXtrait_components AS
SELECT public.materialized_phenoview.accession_id,
    trait_component.cvterm_id AS trait_component_id
   FROM public.materialized_phenoview
   JOIN cvterm trait ON(materialized_phenoview.trait_id = trait.cvterm_id)
   JOIN cvterm_relationship ON(trait.cvterm_id = cvterm_relationship.object_id AND cvterm_relationship.type_id = (SELECT cvterm_id from cvterm where name = 'contains'))
   JOIN cvterm trait_component ON(cvterm_relationship.subject_id = trait_component.cvterm_id)
  GROUP BY 1,2
WITH DATA;
CREATE UNIQUE INDEX accessionsXtrait_components_idx ON public.accessionsXtrait_components(accession_id, trait_component_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW accessionsXtrait_components OWNER TO web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('accessionsXtrait_components', FALSE, CURRENT_TIMESTAMP);

CREATE MATERIALIZED VIEW public.breeding_programsXtrait_components AS
SELECT public.materialized_phenoview.breeding_program_id,
trait_component.cvterm_id AS trait_component_id
FROM public.materialized_phenoview
JOIN cvterm trait ON(materialized_phenoview.trait_id = trait.cvterm_id)
JOIN cvterm_relationship ON(trait.cvterm_id = cvterm_relationship.object_id AND cvterm_relationship.type_id = (SELECT cvterm_id from cvterm where name = 'contains'))
JOIN cvterm trait_component ON(cvterm_relationship.subject_id = trait_component.cvterm_id)
GROUP BY 1,2
WITH DATA;
CREATE UNIQUE INDEX breeding_programsXtrait_components_idx ON public.breeding_programsXtrait_components(breeding_program_id, trait_component_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW breeding_programsXtrait_components OWNER TO web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('breeding_programsXtrait_components', FALSE, CURRENT_TIMESTAMP);

CREATE MATERIALIZED VIEW public.genotyping_protocolsXtrait_components AS
SELECT public.materialized_genoview.genotyping_protocol_id,
trait_component.cvterm_id AS trait_component_id
FROM public.materialized_genoview
JOIN public.materialized_phenoview USING(accession_id)
JOIN cvterm trait ON(materialized_phenoview.trait_id = trait.cvterm_id)
JOIN cvterm_relationship ON(trait.cvterm_id = cvterm_relationship.object_id AND cvterm_relationship.type_id = (SELECT cvterm_id from cvterm where name = 'contains'))
JOIN cvterm trait_component ON(cvterm_relationship.subject_id = trait_component.cvterm_id)
GROUP BY 1,2
WITH DATA;
CREATE UNIQUE INDEX genotyping_protocolsXtrait_components_idx ON public.genotyping_protocolsXtrait_components(genotyping_protocol_id, trait_component_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW genotyping_protocolsXtrait_components OWNER TO web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('genotyping_protocolsXtrait_components', FALSE, CURRENT_TIMESTAMP);

CREATE MATERIALIZED VIEW public.locationsXtrait_components AS
SELECT public.materialized_phenoview.location_id,
trait_component.cvterm_id AS trait_component_id
FROM public.materialized_phenoview
JOIN cvterm trait ON(materialized_phenoview.trait_id = trait.cvterm_id)
JOIN cvterm_relationship ON(trait.cvterm_id = cvterm_relationship.object_id AND cvterm_relationship.type_id = (SELECT cvterm_id from cvterm where name = 'contains'))
JOIN cvterm trait_component ON(cvterm_relationship.subject_id = trait_component.cvterm_id)
GROUP BY 1,2
WITH DATA;
CREATE UNIQUE INDEX locationsXtrait_components_idx ON public.locationsXtrait_components(location_id, trait_component_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW locationsXtrait_components OWNER TO web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('locationsXtrait_components', FALSE, CURRENT_TIMESTAMP);

CREATE MATERIALIZED VIEW public.plantsXtrait_components AS
SELECT public.stock.stock_id AS plant_id,
trait_component.cvterm_id AS trait_component_id
FROM public.materialized_phenoview
JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plant'))
JOIN cvterm trait ON(materialized_phenoview.trait_id = trait.cvterm_id)
JOIN cvterm_relationship ON(trait.cvterm_id = cvterm_relationship.object_id AND cvterm_relationship.type_id = (SELECT cvterm_id from cvterm where name = 'contains'))
JOIN cvterm trait_component ON(cvterm_relationship.subject_id = trait_component.cvterm_id)
GROUP BY 1,2
WITH DATA;
CREATE UNIQUE INDEX plantsXtrait_components_idx ON public.plantsXtrait_components(plant_id, trait_component_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW plantsXtrait_components OWNER TO web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('plantsXtrait_components', FALSE, CURRENT_TIMESTAMP);

CREATE MATERIALIZED VIEW public.plotsXtrait_components AS
SELECT public.stock.stock_id AS plot_id,
trait_component.cvterm_id AS trait_component_id
FROM public.materialized_phenoview
JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plot'))
JOIN cvterm trait ON(materialized_phenoview.trait_id = trait.cvterm_id)
JOIN cvterm_relationship ON(trait.cvterm_id = cvterm_relationship.object_id AND cvterm_relationship.type_id = (SELECT cvterm_id from cvterm where name = 'contains'))
JOIN cvterm trait_component ON(cvterm_relationship.subject_id = trait_component.cvterm_id)
GROUP BY 1,2
WITH DATA;
CREATE UNIQUE INDEX plotsXtrait_components_idx ON public.plotsXtrait_components(plot_id, trait_component_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW plotsXtrait_components OWNER TO web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('plotsXtrait_components', FALSE, CURRENT_TIMESTAMP);

CREATE MATERIALIZED VIEW public.trait_componentsXtraits AS
SELECT traits.trait_id,
trait_component.cvterm_id AS trait_component_id
FROM traits
JOIN cvterm_relationship ON(traits.trait_id = cvterm_relationship.object_id AND cvterm_relationship.type_id = (SELECT cvterm_id from cvterm where name = 'contains'))
JOIN cvterm trait_component ON(cvterm_relationship.subject_id = trait_component.cvterm_id)
GROUP BY 1,2
WITH DATA;
CREATE UNIQUE INDEX trait_componentsXtraits_idx ON public.trait_componentsXtraits(trait_component_id, trait_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW trait_componentsXtraits OWNER TO web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('trait_componentsXtraits', FALSE, CURRENT_TIMESTAMP);

CREATE MATERIALIZED VIEW public.trait_componentsXtrials AS
SELECT trait_component.cvterm_id AS trait_component_id,
    public.materialized_phenoview.trial_id
    FROM public.materialized_phenoview
    JOIN cvterm trait ON(materialized_phenoview.trait_id = trait.cvterm_id)
    JOIN cvterm_relationship ON(trait.cvterm_id = cvterm_relationship.object_id AND cvterm_relationship.type_id = (SELECT cvterm_id from cvterm where name = 'contains'))
    JOIN cvterm trait_component ON(cvterm_relationship.subject_id = trait_component.cvterm_id)
    GROUP BY 1,2
WITH DATA;
CREATE UNIQUE INDEX trait_componentsXtrials_idx ON public.trait_componentsXtrials(trait_component_id, trial_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW trait_componentsXtrials OWNER TO web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('trait_componentsXtrials', FALSE, CURRENT_TIMESTAMP);

CREATE MATERIALIZED VIEW public.trait_componentsXtrial_designs AS
SELECT trait_component.cvterm_id AS trait_component_id,
    trialdesign.value AS trial_design_id
   FROM public.materialized_phenoview
   JOIN cvterm trait ON(materialized_phenoview.trait_id = trait.cvterm_id)
   JOIN cvterm_relationship ON(trait.cvterm_id = cvterm_relationship.object_id AND cvterm_relationship.type_id = (SELECT cvterm_id from cvterm where name = 'contains'))
   JOIN cvterm trait_component ON(cvterm_relationship.subject_id = trait_component.cvterm_id)
   JOIN public.projectprop trialdesign ON materialized_phenoview.trial_id = trialdesign.project_id AND trialdesign.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'design' )
  GROUP BY 1,2
WITH DATA;
CREATE UNIQUE INDEX trait_componentsXtrial_designs_idx ON public.trait_componentsXtrial_designs(trait_component_id, trial_design_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW trait_componentsXtrial_designs OWNER TO web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('trait_componentsXtrial_designs', FALSE, CURRENT_TIMESTAMP);

CREATE MATERIALIZED VIEW public.trait_componentsXtrial_types AS
SELECT trait_component.cvterm_id AS trait_component_id,
    trialterm.cvterm_id AS trial_type_id
   FROM public.materialized_phenoview
   JOIN cvterm trait ON(materialized_phenoview.trait_id = trait.cvterm_id)
   JOIN cvterm_relationship ON(trait.cvterm_id = cvterm_relationship.object_id AND cvterm_relationship.type_id = (SELECT cvterm_id from cvterm where name = 'contains'))
   JOIN cvterm trait_component ON(cvterm_relationship.subject_id = trait_component.cvterm_id)
   JOIN projectprop trialprop ON materialized_phenoview.trial_id = trialprop.project_id AND trialprop.type_id IN (SELECT cvterm_id from cvterm JOIN cv USING(cv_id) WHERE cv.name = 'project_type' )
   JOIN cvterm trialterm ON trialprop.type_id = trialterm.cvterm_id
  GROUP BY 1,2
WITH DATA;
CREATE UNIQUE INDEX trait_componentsXtrial_types_idx ON public.trait_componentsXtrial_types(trait_component_id, trial_type_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW trait_componentsXtrial_types OWNER TO web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('trait_componentsXtrial_types', FALSE, CURRENT_TIMESTAMP);

CREATE MATERIALIZED VIEW public.trait_componentsXyears AS
SELECT trait_component.cvterm_id AS trait_component_id,
    public.materialized_phenoview.year_id
   FROM public.materialized_phenoview
   JOIN cvterm trait ON(materialized_phenoview.trait_id = trait.cvterm_id)
   JOIN cvterm_relationship ON(trait.cvterm_id = cvterm_relationship.object_id AND cvterm_relationship.type_id = (SELECT cvterm_id from cvterm where name = 'contains'))
   JOIN cvterm trait_component ON(cvterm_relationship.subject_id = trait_component.cvterm_id)
  GROUP BY 1,2
WITH DATA;
CREATE UNIQUE INDEX trait_componentsXyears_idx ON public.trait_componentsXyears(trait_component_id, year_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW trait_componentsXyears OWNER TO web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('trait_componentsXyears', FALSE, CURRENT_TIMESTAMP);


-- FIX VIEWS FOR PLANTS, PLOTS, TRIAL DESIGNS AND TRIAL TYPES

DROP MATERIALIZED VIEW IF EXISTS public.accessions;
CREATE MATERIALIZED VIEW public.accessions AS
  SELECT stock.stock_id AS accession_id,
  stock.uniquename AS accession_name
  FROM stock
  WHERE stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'accession') AND is_obsolete = 'f'
  GROUP BY stock.stock_id, stock.uniquename
  WITH DATA;
CREATE UNIQUE INDEX accessions_idx ON public.accessions(accession_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW accessions OWNER TO web_usr;

CREATE MATERIALIZED VIEW public.accessionsXbreeding_programs AS
SELECT public.materialized_phenoview.accession_id,
    public.materialized_phenoview.breeding_program_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.accession_id, public.materialized_phenoview.breeding_program_id
  WITH DATA;
CREATE UNIQUE INDEX accessionsXbreeding_programs_idx ON public.accessionsXbreeding_programs(accession_id, breeding_program_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW accessionsXbreeding_programs OWNER TO web_usr;

CREATE MATERIALIZED VIEW public.accessionsXgenotyping_protocols AS
SELECT public.materialized_genoview.accession_id,
    public.materialized_genoview.genotyping_protocol_id
   FROM public.materialized_genoview
  GROUP BY public.materialized_genoview.accession_id, public.materialized_genoview.genotyping_protocol_id
  WITH DATA;
CREATE UNIQUE INDEX accessionsXgenotyping_protocols_idx ON public.accessionsXgenotyping_protocols(accession_id, genotyping_protocol_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW accessionsXgenotyping_protocols OWNER TO web_usr;

CREATE MATERIALIZED VIEW public.accessionsXlocations AS
SELECT public.materialized_phenoview.accession_id,
    public.materialized_phenoview.location_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.accession_id, public.materialized_phenoview.location_id
  WITH DATA;
CREATE UNIQUE INDEX accessionsXlocations_idx ON public.accessionsXlocations(accession_id, location_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW accessionsXlocations OWNER TO web_usr;

CREATE MATERIALIZED VIEW public.accessionsXplants AS
SELECT public.materialized_phenoview.accession_id,
    public.stock.stock_id AS plant_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plant'))
  GROUP BY public.materialized_phenoview.accession_id, public.stock.stock_id
  WITH DATA;
CREATE UNIQUE INDEX accessionsXplants_idx ON public.accessionsXplants(accession_id, plant_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW accessionsXplants OWNER TO web_usr;

CREATE MATERIALIZED VIEW public.accessionsXplots AS
SELECT public.materialized_phenoview.accession_id,
    public.stock.stock_id AS plot_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plot'))
  GROUP BY public.materialized_phenoview.accession_id, public.stock.stock_id
WITH DATA;
CREATE UNIQUE INDEX accessionsXplots_idx ON public.accessionsXplots(accession_id, plot_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW accessionsXplots OWNER TO web_usr;

CREATE MATERIALIZED VIEW public.accessionsXtrial_designs AS
SELECT public.materialized_phenoview.accession_id,
    trialdesign.value AS trial_design_id
   FROM public.materialized_phenoview
   JOIN public.projectprop trialdesign ON materialized_phenoview.trial_id = trialdesign.project_id AND trialdesign.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'design' )
  GROUP BY public.materialized_phenoview.accession_id, trialdesign.value
WITH DATA;
CREATE UNIQUE INDEX accessionsXtrial_designs_idx ON public.accessionsXtrial_designs(accession_id, trial_design_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW accessionsXtrial_designs OWNER TO web_usr;

CREATE MATERIALIZED VIEW public.accessionsXtrial_types AS
SELECT public.materialized_phenoview.accession_id,
    trialterm.cvterm_id AS trial_type_id
   FROM public.materialized_phenoview
   JOIN projectprop trialprop ON materialized_phenoview.trial_id = trialprop.project_id AND trialprop.type_id IN (SELECT cvterm_id from cvterm JOIN cv USING(cv_id) WHERE cv.name = 'project_type' )
   JOIN cvterm trialterm ON trialprop.type_id = trialterm.cvterm_id
  GROUP BY public.materialized_phenoview.accession_id, trialterm.cvterm_id
WITH DATA;
CREATE UNIQUE INDEX accessionsXtrial_types_idx ON public.accessionsXtrial_types(accession_id, trial_type_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW accessionsXtrial_types OWNER TO web_usr;

CREATE MATERIALIZED VIEW public.accessionsXtrials AS
SELECT public.materialized_phenoview.accession_id,
    public.materialized_phenoview.trial_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.accession_id, public.materialized_phenoview.trial_id
WITH DATA;
CREATE UNIQUE INDEX accessionsXtrials_idx ON public.accessionsXtrials(accession_id, trial_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW accessionsXtrials OWNER TO web_usr;

CREATE MATERIALIZED VIEW public.accessionsXyears AS
SELECT public.materialized_phenoview.accession_id,
    public.materialized_phenoview.year_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.accession_id, public.materialized_phenoview.year_id
WITH DATA;
CREATE UNIQUE INDEX accessionsXyears_idx ON public.accessionsXyears(accession_id, year_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW accessionsXyears OWNER TO web_usr;


CREATE MATERIALIZED VIEW public.breeding_programsXgenotyping_protocols AS
SELECT public.materialized_phenoview.breeding_program_id,
    public.materialized_genoview.genotyping_protocol_id
   FROM public.materialized_phenoview
   JOIN public.materialized_genoview USING(accession_id)
  GROUP BY public.materialized_phenoview.breeding_program_id, public.materialized_genoview.genotyping_protocol_id
WITH DATA;
CREATE UNIQUE INDEX breeding_programsXgenotyping_protocols_idx ON public.breeding_programsXgenotyping_protocols(breeding_program_id, genotyping_protocol_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW breeding_programsXgenotyping_protocols OWNER TO web_usr;

CREATE MATERIALIZED VIEW public.breeding_programsXlocations AS
SELECT public.materialized_phenoview.breeding_program_id,
    public.materialized_phenoview.location_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.breeding_program_id, public.materialized_phenoview.location_id
WITH DATA;
CREATE UNIQUE INDEX breeding_programsXlocations_idx ON public.breeding_programsXlocations(breeding_program_id, location_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW breeding_programsXlocations OWNER TO web_usr;

CREATE MATERIALIZED VIEW public.breeding_programsXplants AS
SELECT public.materialized_phenoview.breeding_program_id,
    public.stock.stock_id AS plant_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plant'))
  GROUP BY public.materialized_phenoview.breeding_program_id, public.stock.stock_id
  WITH DATA;
CREATE UNIQUE INDEX breeding_programsXplants_idx ON public.breeding_programsXplants(breeding_program_id, plant_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW breeding_programsXplants OWNER TO web_usr;

CREATE MATERIALIZED VIEW public.breeding_programsXplots AS
SELECT public.materialized_phenoview.breeding_program_id,
    public.stock.stock_id AS plot_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plot'))
  GROUP BY public.materialized_phenoview.breeding_program_id, public.stock.stock_id
WITH DATA;
CREATE UNIQUE INDEX breeding_programsXplots_idx ON public.breeding_programsXplots(breeding_program_id, plot_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW breeding_programsXplots OWNER TO web_usr;

CREATE MATERIALIZED VIEW public.breeding_programsXtrial_designs AS
SELECT public.materialized_phenoview.breeding_program_id,
    trialdesign.value AS trial_design_id
   FROM public.materialized_phenoview
   JOIN public.projectprop trialdesign ON materialized_phenoview.trial_id = trialdesign.project_id AND trialdesign.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'design' )
  GROUP BY public.materialized_phenoview.breeding_program_id, trialdesign.value
WITH DATA;
CREATE UNIQUE INDEX breeding_programsXtrial_designs_idx ON public.breeding_programsXtrial_designs(breeding_program_id, trial_design_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW breeding_programsXtrial_designs OWNER TO web_usr;

CREATE MATERIALIZED VIEW public.breeding_programsXtrial_types AS
SELECT public.materialized_phenoview.breeding_program_id,
    trialterm.cvterm_id AS trial_type_id
   FROM public.materialized_phenoview
   JOIN projectprop trialprop ON materialized_phenoview.trial_id = trialprop.project_id AND trialprop.type_id IN (SELECT cvterm_id from cvterm JOIN cv USING(cv_id) WHERE cv.name = 'project_type' )
   JOIN cvterm trialterm ON trialprop.type_id = trialterm.cvterm_id
  GROUP BY public.materialized_phenoview.breeding_program_id, trialterm.cvterm_id
WITH DATA;
CREATE UNIQUE INDEX breeding_programsXtrial_types_idx ON public.breeding_programsXtrial_types(breeding_program_id, trial_type_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW breeding_programsXtrial_types OWNER TO web_usr;

CREATE MATERIALIZED VIEW public.breeding_programsXtrials AS
SELECT public.materialized_phenoview.breeding_program_id,
    public.materialized_phenoview.trial_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.breeding_program_id, public.materialized_phenoview.trial_id
WITH DATA;
CREATE UNIQUE INDEX breeding_programsXtrials_idx ON public.breeding_programsXtrials(breeding_program_id, trial_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW breeding_programsXtrials OWNER TO web_usr;

CREATE MATERIALIZED VIEW public.breeding_programsXyears AS
SELECT public.materialized_phenoview.breeding_program_id,
    public.materialized_phenoview.year_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.breeding_program_id, public.materialized_phenoview.year_id
WITH DATA;
CREATE UNIQUE INDEX breeding_programsXyears_idx ON public.breeding_programsXyears(breeding_program_id, year_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW breeding_programsXyears OWNER TO web_usr;


CREATE MATERIALIZED VIEW public.genotyping_protocolsXlocations AS
SELECT public.materialized_genoview.genotyping_protocol_id,
    public.materialized_phenoview.location_id
   FROM public.materialized_genoview
   JOIN public.materialized_phenoview USING(accession_id)
  GROUP BY public.materialized_genoview.genotyping_protocol_id, public.materialized_phenoview.location_id
WITH DATA;
CREATE UNIQUE INDEX genotyping_protocolsXlocations_idx ON public.genotyping_protocolsXlocations(genotyping_protocol_id, location_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW genotyping_protocolsXlocations OWNER TO web_usr;

CREATE MATERIALIZED VIEW public.genotyping_protocolsXplants AS
SELECT public.materialized_genoview.genotyping_protocol_id,
    public.stock.stock_id AS plant_id
   FROM public.materialized_genoview
   JOIN public.materialized_phenoview USING(accession_id)
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plant'))
  GROUP BY public.materialized_genoview.genotyping_protocol_id, public.stock.stock_id
  WITH DATA;
CREATE UNIQUE INDEX genotyping_protocolsXplants_idx ON public.genotyping_protocolsXplants(genotyping_protocol_id, plant_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW genotyping_protocolsXplants OWNER TO web_usr;

CREATE MATERIALIZED VIEW public.genotyping_protocolsXplots AS
SELECT public.materialized_genoview.genotyping_protocol_id,
    public.stock.stock_id AS plot_id
    FROM public.materialized_genoview
    JOIN public.materialized_phenoview USING(accession_id)
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plot'))
  GROUP BY public.materialized_genoview.genotyping_protocol_id, public.stock.stock_id
WITH DATA;
CREATE UNIQUE INDEX genotyping_protocolsXplots_idx ON public.genotyping_protocolsXplots(genotyping_protocol_id, plot_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW genotyping_protocolsXplots OWNER TO web_usr;

CREATE MATERIALIZED VIEW public.genotyping_protocolsXtrial_designs AS
SELECT public.materialized_genoview.genotyping_protocol_id,
    trialdesign.value AS trial_design_id
    FROM public.materialized_genoview
    JOIN public.materialized_phenoview USING(accession_id)
   JOIN public.projectprop trialdesign ON materialized_phenoview.trial_id = trialdesign.project_id AND trialdesign.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'design' )
  GROUP BY public.materialized_genoview.genotyping_protocol_id, trialdesign.value
WITH DATA;
CREATE UNIQUE INDEX genotyping_protocolsXtrial_designs_idx ON public.genotyping_protocolsXtrial_designs(genotyping_protocol_id, trial_design_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW genotyping_protocolsXtrial_designs OWNER TO web_usr;

CREATE MATERIALIZED VIEW public.genotyping_protocolsXtrial_types AS
SELECT public.materialized_genoview.genotyping_protocol_id,
    trialterm.cvterm_id AS trial_type_id
    FROM public.materialized_genoview
    JOIN public.materialized_phenoview USING(accession_id)
   JOIN projectprop trialprop ON materialized_phenoview.trial_id = trialprop.project_id AND trialprop.type_id IN (SELECT cvterm_id from cvterm JOIN cv USING(cv_id) WHERE cv.name = 'project_type' )
   JOIN cvterm trialterm ON trialprop.type_id = trialterm.cvterm_id
  GROUP BY public.materialized_genoview.genotyping_protocol_id, trialterm.cvterm_id
WITH DATA;
CREATE UNIQUE INDEX genotyping_protocolsXtrial_types_idx ON public.genotyping_protocolsXtrial_types(genotyping_protocol_id, trial_type_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW genotyping_protocolsXtrial_types OWNER TO web_usr;

CREATE MATERIALIZED VIEW public.genotyping_protocolsXtrials AS
SELECT public.materialized_genoview.genotyping_protocol_id,
    public.materialized_phenoview.trial_id
   FROM public.materialized_genoview
   JOIN public.materialized_phenoview USING(accession_id)
  GROUP BY public.materialized_genoview.genotyping_protocol_id, public.materialized_phenoview.trial_id
WITH DATA;
CREATE UNIQUE INDEX genotyping_protocolsXtrials_idx ON public.genotyping_protocolsXtrials(genotyping_protocol_id, trial_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW genotyping_protocolsXtrials OWNER TO web_usr;

CREATE MATERIALIZED VIEW public.genotyping_protocolsXyears AS
SELECT public.materialized_genoview.genotyping_protocol_id,
    public.materialized_phenoview.year_id
   FROM public.materialized_genoview
   JOIN public.materialized_phenoview USING(accession_id)
  GROUP BY public.materialized_genoview.genotyping_protocol_id, public.materialized_phenoview.year_id
WITH DATA;
CREATE UNIQUE INDEX genotyping_protocolsXyears_idx ON public.genotyping_protocolsXyears(genotyping_protocol_id, year_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW genotyping_protocolsXyears OWNER TO web_usr;



CREATE MATERIALIZED VIEW public.locationsXplants AS
SELECT public.materialized_phenoview.location_id,
    public.stock.stock_id AS plant_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plant'))
  GROUP BY public.materialized_phenoview.location_id, public.stock.stock_id
  WITH DATA;
CREATE UNIQUE INDEX locationsXplants_idx ON public.locationsXplants(location_id, plant_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW locationsXplants OWNER TO web_usr;

CREATE MATERIALIZED VIEW public.locationsXplots AS
SELECT public.materialized_phenoview.location_id,
    public.stock.stock_id AS plot_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plot'))
  GROUP BY public.materialized_phenoview.location_id, public.stock.stock_id
WITH DATA;
CREATE UNIQUE INDEX locationsXplots_idx ON public.locationsXplots(location_id, plot_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW locationsXplots OWNER TO web_usr;

CREATE MATERIALIZED VIEW public.locationsXtrial_designs AS
SELECT public.materialized_phenoview.location_id,
    trialdesign.value AS trial_design_id
   FROM public.materialized_phenoview
   JOIN public.projectprop trialdesign ON materialized_phenoview.trial_id = trialdesign.project_id AND trialdesign.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'design' )
  GROUP BY public.materialized_phenoview.location_id, trialdesign.value
WITH DATA;
CREATE UNIQUE INDEX locationsXtrial_designs_idx ON public.locationsXtrial_designs(location_id, trial_design_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW locationsXtrial_designs OWNER TO web_usr;

CREATE MATERIALIZED VIEW public.locationsXtrial_types AS
SELECT public.materialized_phenoview.location_id,
    trialterm.cvterm_id AS trial_type_id
   FROM public.materialized_phenoview
   JOIN projectprop trialprop ON materialized_phenoview.trial_id = trialprop.project_id AND trialprop.type_id IN (SELECT cvterm_id from cvterm JOIN cv USING(cv_id) WHERE cv.name = 'project_type' )
   JOIN cvterm trialterm ON trialprop.type_id = trialterm.cvterm_id
  GROUP BY public.materialized_phenoview.location_id, trialterm.cvterm_id
WITH DATA;
CREATE UNIQUE INDEX locationsXtrial_types_idx ON public.locationsXtrial_types(location_id, trial_type_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW locationsXtrial_types OWNER TO web_usr;

CREATE MATERIALIZED VIEW public.locationsXtrials AS
SELECT public.materialized_phenoview.location_id,
    public.materialized_phenoview.trial_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.location_id, public.materialized_phenoview.trial_id
WITH DATA;
CREATE UNIQUE INDEX locationsXtrials_idx ON public.locationsXtrials(location_id, trial_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW locationsXtrials OWNER TO web_usr;

CREATE MATERIALIZED VIEW public.locationsXyears AS
SELECT public.materialized_phenoview.location_id,
    public.materialized_phenoview.year_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.location_id, public.materialized_phenoview.year_id
WITH DATA;
CREATE UNIQUE INDEX locationsXyears_idx ON public.locationsXyears(location_id, year_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW locationsXyears OWNER TO web_usr;



DROP MATERIALIZED VIEW IF EXISTS public.plants;
CREATE MATERIALIZED VIEW public.plants AS
SELECT stock.stock_id AS plant_id,
    stock.uniquename AS plant_name
   FROM stock
   WHERE stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plant') AND is_obsolete = 'f'
  GROUP BY public.stock.stock_id, public.stock.uniquename
WITH DATA;
CREATE UNIQUE INDEX plants_idx ON public.plants(plant_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW plants OWNER TO web_usr;

CREATE MATERIALIZED VIEW public.plantsXplots AS
SELECT plant.stock_id AS plant_id,
    plot.stock_id AS plot_id
   FROM public.materialized_phenoview
   JOIN stock plot ON(public.materialized_phenoview.stock_id = plot.stock_id AND plot.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plot'))
   JOIN stock_relationship plant_relationship ON plot.stock_id = plant_relationship.subject_id
   JOIN stock plant ON plant_relationship.object_id = plant.stock_id AND plant.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plant')
  GROUP BY plant.stock_id, plot.stock_id
WITH DATA;
CREATE UNIQUE INDEX plantsXplots_idx ON public.plantsXplots(plant_id, plot_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW plantsXplots OWNER TO web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('plantsXplots', FALSE, CURRENT_TIMESTAMP);

CREATE MATERIALIZED VIEW public.plantsXtrials AS
SELECT public.stock.stock_id AS plant_id,
    public.materialized_phenoview.trial_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plant'))
  GROUP BY public.stock.stock_id, public.materialized_phenoview.trial_id
WITH DATA;
CREATE UNIQUE INDEX plantsXtrials_idx ON public.plantsXtrials(plant_id, trial_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW plantsXtrials OWNER TO web_usr;

CREATE MATERIALIZED VIEW public.plantsXtrial_designs AS
SELECT public.stock.stock_id AS plant_id,
    trialdesign.value AS trial_design_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plant'))
   JOIN public.projectprop trialdesign ON materialized_phenoview.trial_id = trialdesign.project_id AND trialdesign.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'design' )
  GROUP BY stock.stock_id, trialdesign.value
WITH DATA;
CREATE UNIQUE INDEX plantsXtrial_designs_idx ON public.plantsXtrial_designs(plant_id, trial_design_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW plantsXtrial_designs OWNER TO web_usr;

CREATE MATERIALIZED VIEW public.plantsXtrial_types AS
SELECT public.stock.stock_id AS plant_id,
    trialterm.cvterm_id AS trial_type_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plant'))
   JOIN projectprop trialprop ON materialized_phenoview.trial_id = trialprop.project_id AND trialprop.type_id IN (SELECT cvterm_id from cvterm JOIN cv USING(cv_id) WHERE cv.name = 'project_type' )
   JOIN cvterm trialterm ON trialprop.type_id = trialterm.cvterm_id
  GROUP BY public.stock.stock_id, trialterm.cvterm_id
WITH DATA;
CREATE UNIQUE INDEX plantsXtrial_types_idx ON public.plantsXtrial_types(plant_id, trial_type_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW plantsXtrial_types OWNER TO web_usr;

CREATE MATERIALIZED VIEW public.plantsXyears AS
SELECT public.stock.stock_id AS plant_id,
    public.materialized_phenoview.year_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plant'))
  GROUP BY public.stock.stock_id, public.materialized_phenoview.year_id
WITH DATA;
CREATE UNIQUE INDEX plantsXyears_idx ON public.plantsXyears(plant_id, year_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW plantsXyears OWNER TO web_usr;



DROP MATERIALIZED VIEW IF EXISTS public.plots;
CREATE MATERIALIZED VIEW public.plots AS
SELECT stock.stock_id AS plot_id,
    stock.uniquename AS plot_name
   FROM stock
   WHERE stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plot') AND is_obsolete = 'f'
  GROUP BY public.stock.stock_id, public.stock.uniquename
WITH DATA;
CREATE UNIQUE INDEX plots_idx ON public.plots(plot_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW plots OWNER TO web_usr;

CREATE MATERIALIZED VIEW public.plotsXtrials AS
SELECT public.stock.stock_id AS plot_id,
    public.materialized_phenoview.trial_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plot'))
  GROUP BY public.stock.stock_id, public.materialized_phenoview.trial_id
WITH DATA;
CREATE UNIQUE INDEX plotsXtrials_idx ON public.plotsXtrials(plot_id, trial_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW plotsXtrials OWNER TO web_usr;

CREATE MATERIALIZED VIEW public.plotsXtrial_designs AS
SELECT public.stock.stock_id AS plot_id,
    trialdesign.value AS trial_design_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plot'))
   JOIN public.projectprop trialdesign ON materialized_phenoview.trial_id = trialdesign.project_id AND trialdesign.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'design' )
  GROUP BY stock.stock_id, trialdesign.value
WITH DATA;
CREATE UNIQUE INDEX plotsXtrial_designs_idx ON public.plotsXtrial_designs(plot_id, trial_design_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW plotsXtrial_designs OWNER TO web_usr;

CREATE MATERIALIZED VIEW public.plotsXtrial_types AS
SELECT public.stock.stock_id AS plot_id,
    trialterm.cvterm_id AS trial_type_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plot'))
   JOIN projectprop trialprop ON materialized_phenoview.trial_id = trialprop.project_id AND trialprop.type_id IN (SELECT cvterm_id from cvterm JOIN cv USING(cv_id) WHERE cv.name = 'project_type' )
   JOIN cvterm trialterm ON trialprop.type_id = trialterm.cvterm_id
  GROUP BY public.stock.stock_id, trialterm.cvterm_id
WITH DATA;
CREATE UNIQUE INDEX plotsXtrial_types_idx ON public.plotsXtrial_types(plot_id, trial_type_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW plotsXtrial_types OWNER TO web_usr;

CREATE MATERIALIZED VIEW public.plotsXyears AS
SELECT public.stock.stock_id AS plot_id,
    public.materialized_phenoview.year_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plot'))
  GROUP BY public.stock.stock_id, public.materialized_phenoview.year_id
WITH DATA;
CREATE UNIQUE INDEX plotsXyears_idx ON public.plotsXyears(plot_id, year_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW plotsXyears OWNER TO web_usr;



DROP MATERIALIZED VIEW IF EXISTS public.trial_designs;
CREATE MATERIALIZED VIEW public.trial_designs AS
SELECT projectprop.value AS trial_design_id,
  projectprop.value AS trial_design_name
   FROM projectprop
   JOIN cvterm ON(projectprop.type_id = cvterm.cvterm_id)
   WHERE cvterm.name = 'design'
   GROUP BY projectprop.value
WITH DATA;
CREATE UNIQUE INDEX trial_designs_idx ON public.trial_designs(trial_design_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW trial_designs OWNER TO web_usr;

CREATE MATERIALIZED VIEW public.trial_designsXtrial_types AS
SELECT trialdesign.value AS trial_design_id,
    trialterm.cvterm_id AS trial_type_id
   FROM public.materialized_phenoview
   JOIN public.projectprop trialdesign ON materialized_phenoview.trial_id = trialdesign.project_id AND trialdesign.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'design' )
   JOIN projectprop trialprop ON materialized_phenoview.trial_id = trialprop.project_id AND trialprop.type_id IN (SELECT cvterm_id from cvterm JOIN cv USING(cv_id) WHERE cv.name = 'project_type' )
   JOIN cvterm trialterm ON trialprop.type_id = trialterm.cvterm_id
  GROUP BY trialdesign.value, trialterm.cvterm_id
WITH DATA;
CREATE UNIQUE INDEX trial_designsXtrial_types_idx ON public.trial_designsXtrial_types(trial_design_id, trial_type_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW trial_designsXtrial_types OWNER TO web_usr;

CREATE MATERIALIZED VIEW public.trial_designsXtrials AS
SELECT trialdesign.value AS trial_design_id,
    public.materialized_phenoview.trial_id
   FROM public.materialized_phenoview
   JOIN public.projectprop trialdesign ON materialized_phenoview.trial_id = trialdesign.project_id AND trialdesign.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'design' )
  GROUP BY trialdesign.value, public.materialized_phenoview.trial_id
WITH DATA;
CREATE UNIQUE INDEX trial_designsXtrials_idx ON public.trial_designsXtrials(trial_id, trial_design_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW trial_designsXtrials OWNER TO web_usr;

CREATE MATERIALIZED VIEW public.trial_designsXyears AS
SELECT trialdesign.value AS trial_design_id,
    public.materialized_phenoview.year_id
   FROM public.materialized_phenoview
   JOIN public.projectprop trialdesign ON materialized_phenoview.trial_id = trialdesign.project_id AND trialdesign.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'design' )
  GROUP BY trialdesign.value, public.materialized_phenoview.year_id
WITH DATA;
CREATE UNIQUE INDEX trial_designsXyears_idx ON public.trial_designsXyears(trial_design_id, year_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW trial_designsXyears OWNER TO web_usr;



DROP MATERIALIZED VIEW IF EXISTS public.trial_types;
CREATE MATERIALIZED VIEW public.trial_types AS
SELECT cvterm.cvterm_id AS trial_type_id,
  cvterm.name AS trial_type_name
   FROM cvterm
   JOIN cv USING(cv_id)
   WHERE cv.name = 'project_type'
   GROUP BY cvterm.cvterm_id
WITH DATA;
CREATE UNIQUE INDEX trial_types_idx ON public.trial_types(trial_type_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW trial_types OWNER TO web_usr;

CREATE MATERIALIZED VIEW public.trial_typesXtrials AS
SELECT trialterm.cvterm_id AS trial_type_id,
    public.materialized_phenoview.trial_id
   FROM public.materialized_phenoview
   JOIN projectprop trialprop ON materialized_phenoview.trial_id = trialprop.project_id AND trialprop.type_id IN (SELECT cvterm_id from cvterm JOIN cv USING(cv_id) WHERE cv.name = 'project_type' )
   JOIN cvterm trialterm ON trialprop.type_id = trialterm.cvterm_id
  GROUP BY trialterm.cvterm_id, public.materialized_phenoview.trial_id
WITH DATA;
CREATE UNIQUE INDEX trial_typesXtrials_idx ON public.trial_typesXtrials(trial_id, trial_type_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW trial_typesXtrials OWNER TO web_usr;

CREATE MATERIALIZED VIEW public.trial_typesXyears AS
SELECT trialterm.cvterm_id AS trial_type_id,
    public.materialized_phenoview.year_id
   FROM public.materialized_phenoview
   JOIN projectprop trialprop ON materialized_phenoview.trial_id = trialprop.project_id AND trialprop.type_id IN (SELECT cvterm_id from cvterm JOIN cv USING(cv_id) WHERE cv.name = 'project_type' )
   JOIN cvterm trialterm ON trialprop.type_id = trialterm.cvterm_id
  GROUP BY trialterm.cvterm_id, public.materialized_phenoview.year_id
WITH DATA;
CREATE UNIQUE INDEX trial_typesXyears_idx ON public.trial_typesXyears(trial_type_id, year_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW trial_typesXyears OWNER TO web_usr;



CREATE MATERIALIZED VIEW public.trialsXyears AS
SELECT public.materialized_phenoview.trial_id,
    public.materialized_phenoview.year_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.trial_id, public.materialized_phenoview.year_id
WITH DATA;
CREATE UNIQUE INDEX trialsXyears_idx ON public.trialsXyears(trial_id, year_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW trialsXyears OWNER TO web_usr;

DROP MATERIALIZED VIEW IF EXISTS public.genotyping_protocolsxgenotyping_projects CASCADE;
CREATE MATERIALIZED VIEW public.genotyping_protocolsxgenotyping_projects AS
 SELECT genotyping_protocols.genotyping_protocol_id,
    nd_experiment_project.project_id AS genotyping_project_id
   FROM ((genotyping_protocols
     JOIN nd_experiment_protocol ON ((genotyping_protocols.genotyping_protocol_id = nd_experiment_protocol.nd_protocol_id)))
     JOIN nd_experiment_project ON ((nd_experiment_protocol.nd_experiment_id = nd_experiment_project.nd_experiment_id)))
  GROUP BY genotyping_protocols.genotyping_protocol_id, nd_experiment_project.project_id
 WITH DATA;
CREATE UNIQUE INDEX genotyping_protocolsxgenotyping_projects_idx ON public.genotyping_protocolsxgenotyping_projects(genotyping_protocol_id, genotyping_project_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.genotyping_protocolsxgenotyping_projects OWNER TO web_usr;

DROP MATERIALIZED VIEW IF EXISTS public.genotyping_projects CASCADE;
CREATE MATERIALIZED VIEW public.genotyping_projects AS 
 SELECT project.project_id AS genotyping_project_id,
    project.name AS genotyping_project_name
   FROM (project
     JOIN projectprop USING (project_id))
  WHERE ((projectprop.type_id = ( SELECT cvterm.cvterm_id
           FROM cvterm
          WHERE ((cvterm.name)::text = 'design'::text))) AND (projectprop.value = 'genotype_data_project'::text))
  GROUP BY project.project_id, project.name
 WITH DATA;
CREATE UNIQUE INDEX genotyping_projects_idx ON public.genotyping_projects(genotyping_project_id, genotyping_project_name) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.genotyping_projects OWNER TO web_usr;

DROP MATERIALIZED VIEW IF EXISTS public.accessionsxgenotyping_projects CASCADE;
CREATE MATERIALIZED VIEW public.accessionsxgenotyping_projects AS
 SELECT accessions.accession_id,
    nd_experiment_project.project_id AS genotyping_project_id
   FROM (((accessions
     JOIN materialized_genoview ON ((accessions.accession_id = materialized_genoview.accession_id)))
     JOIN nd_experiment_genotype ON ((materialized_genoview.genotype_id = nd_experiment_genotype.genotype_id)))
     JOIN nd_experiment_project ON ((nd_experiment_genotype.nd_experiment_id = nd_experiment_project.nd_experiment_id)))
  WHERE (nd_experiment_project.project_id IN ( SELECT projectprop.project_id
           FROM projectprop
          WHERE ((projectprop.type_id = ( SELECT cvterm.cvterm_id
                   FROM cvterm
                  WHERE ((cvterm.name)::text = 'design'::text))) AND (projectprop.value = 'genotype_data_project'::text))))
  GROUP BY accessions.accession_id, genotyping_project_id
 WITH DATA;
CREATE UNIQUE INDEX accessionsxgenotyping_projects_idx ON public.accessionsxgenotyping_projects(accession_id, genotyping_project_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.accessionsxgenotyping_projects OWNER TO web_usr;

DROP MATERIALIZED VIEW IF EXISTS public.breeding_programsxgenotyping_projects CASCADE;
CREATE MATERIALIZED VIEW public.breeding_programsxgenotyping_projects AS 
 SELECT breeding_programs.breeding_program_id,
    project_relationship.subject_project_id AS genotyping_project_id
   FROM (breeding_programs
     JOIN project_relationship ON ((breeding_programs.breeding_program_id = project_relationship.object_project_id)))
  WHERE ((project_relationship.type_id = ( SELECT cvterm.cvterm_id
           FROM cvterm
          WHERE ((cvterm.name)::text = 'breeding_program_trial_relationship'::text))) AND (project_relationship.subject_project_id IN ( SELECT genotyping_projects.genotyping_project_id
           FROM genotyping_projects)))
 WITH DATA;
CREATE UNIQUE INDEX breeding_programsxgenotyping_projects_idx ON public.breeding_programsxgenotyping_projects(breeding_program_id, genotyping_project_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.breeding_programsxgenotyping_projects OWNER TO web_usr;

DROP MATERIALIZED VIEW IF EXISTS public.locationsxgenotyping_projects CASCADE;
CREATE MATERIALIZED VIEW public.locationsxgenotyping_projects AS
 SELECT projectprop.value AS location_id,
    projectprop.project_id AS genotyping_project_id
   FROM projectprop
  WHERE ((projectprop.type_id = ( SELECT cvterm.cvterm_id
           FROM cvterm
          WHERE ((cvterm.name)::text = 'project location'::text))) AND (projectprop.value IN ( SELECT (locations.location_id)::text AS location_id
           FROM locations)) AND (projectprop.project_id IN ( SELECT project.project_id
           FROM (project
             JOIN projectprop projectprop_1 USING (project_id))
          WHERE ((projectprop_1.type_id = ( SELECT cvterm.cvterm_id
                   FROM cvterm
                  WHERE ((cvterm.name)::text = 'design'::text))) AND (projectprop_1.value = 'genotype_data_project'::text)))))
 WITH DATA;
CREATE UNIQUE INDEX locationsxgenotyping_projects_idx ON public.locationsxgenotyping_projects(location_id, genotyping_project_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.locationsxgenotyping_projects OWNER TO web_usr;

DROP MATERIALIZED VIEW IF EXISTS public.trialsxgenotyping_projects CASCADE;
CREATE MATERIALIZED VIEW public.trialsxgenotyping_projects AS
 SELECT trials.trial_id,
    nd_experiment_project.project_id AS genotyping_project_id
   FROM ((((trials
     JOIN materialized_phenoview ON ((trials.trial_id = materialized_phenoview.trial_id)))
     JOIN materialized_genoview ON ((materialized_phenoview.accession_id = materialized_genoview.accession_id)))
     JOIN nd_experiment_genotype ON ((materialized_genoview.genotype_id = nd_experiment_genotype.genotype_id)))
     JOIN nd_experiment_project ON ((nd_experiment_genotype.nd_experiment_id = nd_experiment_project.nd_experiment_id)))
  WHERE (nd_experiment_project.project_id IN ( SELECT projectprop.project_id
           FROM projectprop
          WHERE ((projectprop.type_id IN ( SELECT cvterm.cvterm_id
                   FROM cvterm
                  WHERE ((cvterm.name)::text = 'design'::text))) AND (projectprop.value = 'genotype_data_project'::text))))
  GROUP BY trials.trial_id, nd_experiment_project.project_id
 WITH DATA;
CREATE UNIQUE INDEX trialsxgenotyping_projects_idx ON public.trialsxgenotyping_projects(trial_id, genotyping_project_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.trialsxgenotyping_projects OWNER TO web_usr;

DROP MATERIALIZED VIEW IF EXISTS public.genotyping_projectsxaccessions CASCADE;
CREATE MATERIALIZED VIEW public.genotyping_projectsxaccessions AS 
 SELECT nd_experiment_project.project_id AS genotyping_project_id,
    materialized_genoview.accession_id
   FROM ((nd_experiment_project
     JOIN nd_experiment_genotype ON ((nd_experiment_project.nd_experiment_id = nd_experiment_genotype.nd_experiment_id)))
     JOIN materialized_genoview ON ((nd_experiment_genotype.genotype_id = materialized_genoview.genotype_id)))
  WHERE (nd_experiment_project.project_id IN ( SELECT genotyping_projects.genotyping_project_id
           FROM genotyping_projects))
  GROUP BY genotyping_project_id, materialized_genoview.accession_id
 WITH DATA;
CREATE UNIQUE INDEX genotyping_projectsxaccessions_idx ON public.genotyping_projectsxaccessions(genotyping_project_id, accession_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.genotyping_projectsxaccessions OWNER TO web_usr;

DROP MATERIALIZED VIEW IF EXISTS public.genotyping_projectsxbreeding_programs CASCADE;
CREATE MATERIALIZED VIEW public.genotyping_projectsxbreeding_programs AS 
 SELECT project_relationship.subject_project_id AS genotyping_project_id,
    project_relationship.object_project_id AS breeding_program_id
   FROM project_relationship
  WHERE ((project_relationship.type_id = ( SELECT cvterm.cvterm_id
           FROM cvterm
          WHERE ((cvterm.name)::text = 'breeding_program_trial_relationship'::text))) AND (project_relationship.subject_project_id IN ( SELECT genotyping_projects.genotyping_project_id
           FROM genotyping_projects)))
 WITH DATA;
CREATE UNIQUE INDEX genotyping_projectsxbreeding_programs_idx ON public.genotyping_projectsxbreeding_programs(genotyping_project_id, breeding_program_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.genotyping_projectsxbreeding_programs OWNER TO web_usr;

DROP MATERIALIZED VIEW IF EXISTS public.genotyping_projectsxgenotyping_protocols CASCADE;
CREATE MATERIALIZED VIEW public.genotyping_projectsxgenotyping_protocols AS
 SELECT genotyping_projects.genotyping_project_id,
    nd_experiment_protocol.nd_protocol_id AS genotyping_protocol_id
   FROM ((genotyping_projects
     JOIN nd_experiment_project ON ((genotyping_projects.genotyping_project_id = nd_experiment_project.project_id)))
     JOIN nd_experiment_protocol ON ((nd_experiment_project.nd_experiment_id = nd_experiment_protocol.nd_experiment_id)))
     GROUP BY genotyping_projects.genotyping_project_id, nd_experiment_protocol.nd_protocol_id
 WITH DATA;
CREATE UNIQUE INDEX genotyping_projectsxgenotyping_protocols_idx ON public.genotyping_projectsxgenotyping_protocols(genotyping_project_id, genotyping_protocol_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.genotyping_projectsxgenotyping_protocols OWNER TO web_usr;

DROP MATERIALIZED VIEW IF EXISTS public.genotyping_projectsxlocations CASCADE;
CREATE MATERIALIZED VIEW public.genotyping_projectsxlocations AS 
 SELECT projectprop.project_id AS genotyping_project_id,
    (projectprop.value)::integer AS location_id
   FROM projectprop
  WHERE ((projectprop.type_id = ( SELECT cvterm.cvterm_id
           FROM cvterm
          WHERE ((cvterm.name)::text = 'project location'::text))) AND (projectprop.project_id IN ( SELECT genotyping_projects.genotyping_project_id
           FROM genotyping_projects)))
 WITH DATA;
CREATE UNIQUE INDEX genotyping_projectsxlocations_idx ON public.genotyping_projectsxlocations(genotyping_project_id, location_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.genotyping_projectsxlocations OWNER TO web_usr;

DROP MATERIALIZED VIEW IF EXISTS public.genotyping_projectsxtraits CASCADE;
CREATE MATERIALIZED VIEW public.genotyping_projectsxtraits AS
 SELECT nd_experiment_project.project_id AS genotyping_project_id,
    materialized_phenoview.trait_id
   FROM (((nd_experiment_project
     JOIN nd_experiment_genotype ON ((nd_experiment_genotype.nd_experiment_id = nd_experiment_project.nd_experiment_id)))
     JOIN materialized_genoview ON ((materialized_genoview.genotype_id = nd_experiment_genotype.genotype_id)))
     JOIN materialized_phenoview ON ((materialized_genoview.accession_id = materialized_phenoview.accession_id)))
  WHERE (nd_experiment_project.project_id IN ( SELECT projectprop.project_id
           FROM projectprop
          WHERE ((projectprop.type_id IN ( SELECT cvterm.cvterm_id
                   FROM cvterm
                  WHERE ((cvterm.name)::text = 'design'::text))) AND (projectprop.value = 'genotype_data_project'::text))))
  GROUP BY nd_experiment_project.project_id, materialized_phenoview.trait_id
 WITH DATA;
CREATE UNIQUE INDEX genotyping_projectsxtraits_idx ON public.genotyping_projectsxtraits(genotyping_project_id, trait_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.genotyping_projectsxtraits OWNER TO web_usr;

DROP MATERIALIZED VIEW IF EXISTS public.genotyping_projectsxtrials CASCADE;
CREATE MATERIALIZED VIEW public.genotyping_projectsxtrials AS
 SELECT nd_experiment_project.project_id AS genotyping_project_id,
    materialized_phenoview.trial_id
   FROM (((nd_experiment_project
     JOIN nd_experiment_genotype ON ((nd_experiment_genotype.nd_experiment_id = nd_experiment_project.nd_experiment_id)))
     JOIN materialized_genoview ON ((materialized_genoview.genotype_id = nd_experiment_genotype.genotype_id)))
     JOIN materialized_phenoview ON ((materialized_phenoview.accession_id = materialized_genoview.accession_id)))
  WHERE (nd_experiment_project.project_id IN ( SELECT projectprop.project_id
           FROM projectprop
          WHERE ((projectprop.type_id IN ( SELECT cvterm.cvterm_id
                   FROM cvterm
                  WHERE ((cvterm.name)::text = 'design'::text))) AND (projectprop.value = 'genotype_data_project'::text))))
  GROUP BY nd_experiment_project.project_id, materialized_phenoview.trial_id
 WITH DATA;
CREATE UNIQUE INDEX genotyping_projectsxtrials_idx ON public.genotyping_projectsxtrials(genotyping_project_id, trial_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.genotyping_projectsxtrials OWNER TO web_usr;

DROP MATERIALIZED VIEW IF EXISTS public.genotyping_projectsxyears CASCADE;
CREATE MATERIALIZED VIEW public.genotyping_projectsxyears AS 
 SELECT projectprop.project_id AS genotyping_project_id,
    projectprop.value AS year_id
   FROM projectprop
  WHERE ((projectprop.project_id IN ( SELECT project.project_id
           FROM (project
             JOIN projectprop projectprop_1 USING (project_id))
          WHERE ((projectprop_1.type_id = ( SELECT cvterm.cvterm_id
                   FROM cvterm
                  WHERE ((cvterm.name)::text = 'design'::text))) AND (projectprop_1.value = 'genotype_data_project'::text)))) AND (projectprop.type_id = ( SELECT cvterm.cvterm_id
           FROM cvterm
          WHERE ((cvterm.name)::text = 'project year'::text))))
 WITH DATA;
CREATE UNIQUE INDEX genotyping_projectsxyears_idx ON public.genotyping_projectsxyears(genotyping_project_id, year_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.genotyping_projectsxyears OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.refresh_materialized_views() RETURNS VOID AS '
REFRESH MATERIALIZED VIEW public.materialized_phenoview;
REFRESH MATERIALIZED VIEW public.materialized_genoview;
REFRESH MATERIALIZED VIEW public.accessions;
REFRESH MATERIALIZED VIEW public.breeding_programs;
REFRESH MATERIALIZED VIEW public.genotyping_protocols;
REFRESH MATERIALIZED VIEW public.locations;
REFRESH MATERIALIZED VIEW public.plants;
REFRESH MATERIALIZED VIEW public.plots;
REFRESH MATERIALIZED VIEW public.seedlots;
REFRESH MATERIALIZED VIEW public.trait_components;
REFRESH MATERIALIZED VIEW public.traits;
REFRESH MATERIALIZED VIEW public.trial_designs;
REFRESH MATERIALIZED VIEW public.trial_types;
REFRESH MATERIALIZED VIEW public.trials;
REFRESH MATERIALIZED VIEW public.genotyping_projects;
REFRESH MATERIALIZED VIEW public.years;
REFRESH MATERIALIZED VIEW public.accessionsXbreeding_programs;
REFRESH MATERIALIZED VIEW public.accessionsXlocations;
REFRESH MATERIALIZED VIEW public.accessionsXgenotyping_protocols;
REFRESH MATERIALIZED VIEW public.accessionsXplants;
REFRESH MATERIALIZED VIEW public.accessionsXplots;
REFRESH MATERIALIZED VIEW public.accessionsXseedlots;
REFRESH MATERIALIZED VIEW public.accessionsXtrait_components;
REFRESH MATERIALIZED VIEW public.accessionsXtraits;
REFRESH MATERIALIZED VIEW public.accessionsXtrial_designs;
REFRESH MATERIALIZED VIEW public.accessionsXtrial_types;
REFRESH MATERIALIZED VIEW public.accessionsXtrials;
REFRESH MATERIALIZED VIEW public.accessionsxgenotyping_projects;
REFRESH MATERIALIZED VIEW public.accessionsXyears;
REFRESH MATERIALIZED VIEW public.breeding_programsXlocations;
REFRESH MATERIALIZED VIEW public.breeding_programsXgenotyping_protocols;
REFRESH MATERIALIZED VIEW public.breeding_programsXplants;
REFRESH MATERIALIZED VIEW public.breeding_programsXplots;
REFRESH MATERIALIZED VIEW public.breeding_programsXseedlots;
REFRESH MATERIALIZED VIEW public.breeding_programsXtrait_components;
REFRESH MATERIALIZED VIEW public.breeding_programsXtraits;
REFRESH MATERIALIZED VIEW public.breeding_programsXtrial_designs;
REFRESH MATERIALIZED VIEW public.breeding_programsXtrial_types;
REFRESH MATERIALIZED VIEW public.breeding_programsXtrials;
REFRESH MATERIALIZED VIEW public.breeding_programsxgenotyping_projects;
REFRESH MATERIALIZED VIEW public.breeding_programsXyears;
REFRESH MATERIALIZED VIEW public.genotyping_protocolsXlocations;
REFRESH MATERIALIZED VIEW public.genotyping_protocolsXplants;
REFRESH MATERIALIZED VIEW public.genotyping_protocolsXplots;
REFRESH MATERIALIZED VIEW public.genotyping_protocolsXseedlots;
REFRESH MATERIALIZED VIEW public.genotyping_protocolsXtrait_components;
REFRESH MATERIALIZED VIEW public.genotyping_protocolsXtraits;
REFRESH MATERIALIZED VIEW public.genotyping_protocolsXtrial_designs;
REFRESH MATERIALIZED VIEW public.genotyping_protocolsXtrial_types;
REFRESH MATERIALIZED VIEW public.genotyping_protocolsXtrials;
REFRESH MATERIALIZED VIEW public.genotyping_protocolsXyears;
REFRESH MATERIALIZED VIEW public.genotyping_protocolsxgenotyping_projects;
REFRESH MATERIALIZED VIEW public.genotyping_projectsxaccessions;
REFRESH MATERIALIZED VIEW public.genotyping_projectsxbreeding_programs;
REFRESH MATERIALIZED VIEW public.genotyping_projectsxgenotyping_protocols;
REFRESH MATERIALIZED VIEW public.genotyping_projectsxlocations;
REFRESH MATERIALIZED VIEW public.genotyping_projectsxtraits;
REFRESH MATERIALIZED VIEW public.genotyping_projectsxtrials;
REFRESH MATERIALIZED VIEW public.genotyping_projectsxyears;
REFRESH MATERIALIZED VIEW public.locationsXplants;
REFRESH MATERIALIZED VIEW public.locationsXplots;
REFRESH MATERIALIZED VIEW public.locationsXseedlots;
REFRESH MATERIALIZED VIEW public.locationsXtrait_components;
REFRESH MATERIALIZED VIEW public.locationsXtraits;
REFRESH MATERIALIZED VIEW public.locationsXtrial_designs;
REFRESH MATERIALIZED VIEW public.locationsXtrial_types;
REFRESH MATERIALIZED VIEW public.locationsXtrials;
REFRESH MATERIALIZED VIEW public.locationsxgenotyping_projects;
REFRESH MATERIALIZED VIEW public.locationsXyears;
REFRESH MATERIALIZED VIEW public.plantsXplots;
REFRESH MATERIALIZED VIEW public.plantsXseedlots;
REFRESH MATERIALIZED VIEW public.plantsXtrait_components;
REFRESH MATERIALIZED VIEW public.plantsXtraits;
REFRESH MATERIALIZED VIEW public.plantsXtrial_designs;
REFRESH MATERIALIZED VIEW public.plantsXtrial_types;
REFRESH MATERIALIZED VIEW public.plantsXtrials;
REFRESH MATERIALIZED VIEW public.plantsXyears;
REFRESH MATERIALIZED VIEW public.plotsXseedlots;
REFRESH MATERIALIZED VIEW public.plotsXtrait_components;
REFRESH MATERIALIZED VIEW public.plotsXtraits;
REFRESH MATERIALIZED VIEW public.plotsXtrial_designs;
REFRESH MATERIALIZED VIEW public.plotsXtrial_types;
REFRESH MATERIALIZED VIEW public.plotsXtrials;
REFRESH MATERIALIZED VIEW public.plotsXyears;
REFRESH MATERIALIZED VIEW public.seedlotsXtrait_components;
REFRESH MATERIALIZED VIEW public.seedlotsXtraits;
REFRESH MATERIALIZED VIEW public.seedlotsXtrial_designs;
REFRESH MATERIALIZED VIEW public.seedlotsXtrial_types;
REFRESH MATERIALIZED VIEW public.seedlotsXtrials;
REFRESH MATERIALIZED VIEW public.seedlotsXyears;
REFRESH MATERIALIZED VIEW public.trait_componentsXtraits;
REFRESH MATERIALIZED VIEW public.trait_componentsXtrial_designs;
REFRESH MATERIALIZED VIEW public.trait_componentsXtrial_types;
REFRESH MATERIALIZED VIEW public.trait_componentsXtrials;
REFRESH MATERIALIZED VIEW public.trait_componentsXyears;
REFRESH MATERIALIZED VIEW public.traitsXtrial_designs;
REFRESH MATERIALIZED VIEW public.traitsXtrial_types;
REFRESH MATERIALIZED VIEW public.traitsXtrials;
REFRESH MATERIALIZED VIEW public.traitsXyears;
REFRESH MATERIALIZED VIEW public.trialsxgenotyping_projects;
REFRESH MATERIALIZED VIEW public.trial_designsXtrial_types;
REFRESH MATERIALIZED VIEW public.trial_designsXtrials;
REFRESH MATERIALIZED VIEW public.trial_designsXyears;
REFRESH MATERIALIZED VIEW public.trial_typesXtrials;
REFRESH MATERIALIZED VIEW public.trial_typesXyears;
REFRESH MATERIALIZED VIEW public.trialsXyears;
UPDATE public.matviews SET currently_refreshing=FALSE, last_refresh=CURRENT_TIMESTAMP;'
    LANGUAGE SQL;

ALTER FUNCTION public.refresh_materialized_views() OWNER TO web_usr;

CREATE OR REPLACE FUNCTION public.refresh_materialized_views_concurrently() RETURNS VOID AS '
REFRESH MATERIALIZED VIEW CONCURRENTLY public.materialized_phenoview;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.materialized_genoview;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.accessions;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.breeding_programs;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.genotyping_protocols;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.locations;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.plants;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.plots;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.seedlots;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.trait_components;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.traits;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.trial_designs;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.trial_types;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.trials;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.genotyping_projects;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.years;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.accessionsXbreeding_programs;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.accessionsXlocations;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.accessionsXgenotyping_protocols;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.accessionsXplants;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.accessionsXplots;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.accessionsXseedlots;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.accessionsXtrait_components;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.accessionsXtraits;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.accessionsXtrial_designs;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.accessionsXtrial_types;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.accessionsXtrials;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.accessionsxgenotyping_projects;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.accessionsXyears;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.breeding_programsXlocations;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.breeding_programsXgenotyping_protocols;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.breeding_programsXplants;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.breeding_programsXplots;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.breeding_programsXseedlots;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.breeding_programsXtrait_components;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.breeding_programsXtraits;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.breeding_programsXtrial_designs;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.breeding_programsXtrial_types;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.breeding_programsXtrials;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.breeding_programsxgenotyping_projects;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.breeding_programsXyears;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.genotyping_protocolsXlocations;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.genotyping_protocolsXplants;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.genotyping_protocolsXplots;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.genotyping_protocolsXseedlots;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.genotyping_protocolsXtrait_components;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.genotyping_protocolsXtraits;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.genotyping_protocolsXtrial_designs;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.genotyping_protocolsXtrial_types;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.genotyping_protocolsXtrials;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.genotyping_protocolsXyears;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.genotyping_protocolsxgenotyping_projects;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.genotyping_projectsxaccessions;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.genotyping_projectsxbreeding_programs;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.genotyping_projectsxgenotyping_protocols;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.genotyping_projectsxlocations;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.genotyping_projectsxtraits;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.genotyping_projectsxtrials;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.genotyping_projectsxyears;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.locationsXplants;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.locationsXplots;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.locationsXseedlots;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.locationsXtrait_components;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.locationsXtraits;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.locationsXtrial_designs;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.locationsXtrial_types;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.locationsXtrials;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.locationsxgenotyping_projects;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.locationsXyears;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.plantsXplots;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.plantsXseedlots;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.plantsXtrait_components;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.plantsXtraits;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.plantsXtrial_designs;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.plantsXtrial_types;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.plantsXtrials;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.plantsXyears;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.plotsXseedlots;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.plotsXtrait_components;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.plotsXtraits;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.plotsXtrial_designs;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.plotsXtrial_types;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.plotsXtrials;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.plotsXyears;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.seedlotsXtrait_components;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.seedlotsXtraits;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.seedlotsXtrial_designs;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.seedlotsXtrial_types;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.seedlotsXtrials;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.seedlotsXyears;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.trait_componentsXtraits;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.trait_componentsXtrial_designs;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.trait_componentsXtrial_types;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.trait_componentsXtrials;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.trait_componentsXyears;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.traitsXtrial_designs;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.traitsXtrial_types;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.traitsXtrials;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.traitsXyears;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.trialsxgenotyping_projects;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.trial_designsXtrial_types;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.trial_designsXtrials;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.trial_designsXyears;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.trial_typesXtrials;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.trial_typesXyears;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.trialsXyears;
UPDATE public.matviews SET currently_refreshing=FALSE, last_refresh=CURRENT_TIMESTAMP;'
    LANGUAGE SQL;

ALTER FUNCTION public.refresh_materialized_views_concurrently() OWNER TO web_usr;

EOSQL

print "You're done!\n";
}


####
1; #
####
