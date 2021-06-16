#!/usr/bin/env perl


=head1 NAME

UpdateRefreshFunction.pm

=head1 SYNOPSIS

mx-run UpdateRefreshFunction [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch updates the refresh_materialized_views_concurrently() postgres function to save time by building and renaming new views instead.

=head1 AUTHOR

Bryan Ellerbrock

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package UpdateRefreshFunction;

use Moose;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch updates the materialized_phenoview and materialized_genoview to speed up their underlying queries (prevents joining through nd_experiment, drops indexes). Also redefines trials view to exclude genotyping trial folders


sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    $self->dbh->do(<<EOSQL);
--do your SQL here


CREATE OR REPLACE FUNCTION public.refresh_materialized_views_concurrently() RETURNS VOID AS \$\$
CREATE MATERIALIZED VIEW public.materialized_phenoview_new AS
SELECT
  breeding_program.project_id AS breeding_program_id,
  location.type_id AS location_id,
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

ALTER MATERIALIZED VIEW public.materialized_phenoview rename to materialized_phenoview_old;
ALTER MATERIALIZED VIEW public.materialized_phenoview_new rename to materialized_phenoview;
DROP MATERIALIZED VIEW IF EXISTS public.materialized_phenoview_old CASCADE;
CREATE UNIQUE INDEX unq_pheno_idx ON public.materialized_phenoview(stock_id,phenotype_id,trait_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW materialized_phenoview OWNER TO web_usr;

CREATE MATERIALIZED VIEW public.materialized_genoview_new AS
 SELECT
     CASE WHEN nd_experiment_stock.stock_id IS NOT NULL THEN stock_relationship.object_id ELSE accession.stock_id END AS accession_id,
     CASE WHEN nd_experiment_stock.stock_id IS NOT NULL THEN nd_experiment_protocol.nd_protocol_id ELSE nd_experiment_protocol_accession.nd_protocol_id END AS genotyping_protocol_id,
     CASE WHEN nd_experiment_stock.stock_id IS NOT NULL THEN nd_experiment_genotype.genotype_id ELSE nd_experiment_genotype_accession.genotype_id END AS genotype_id,
     CASE WHEN nd_experiment_stock.stock_id IS NOT NULL THEN stock_type.name ELSE 'accession' END AS stock_type
   FROM stock AS accession
     LEFT JOIN stock_relationship ON accession.stock_id = stock_relationship.object_id AND stock_relationship.type_id IN (SELECT cvterm_id from cvterm where cvterm.name IN ('tissue_sample_of', 'plant_of', 'plot_of') )
     LEFT JOIN stock ON stock_relationship.subject_id = stock.stock_id AND stock.type_id IN (SELECT cvterm_id from cvterm where cvterm.name IN ('tissue_sample', 'plant', 'plot') )
     LEFT JOIN cvterm AS stock_type ON (stock_type.cvterm_id = stock.type_id)
     LEFT JOIN nd_experiment_stock ON (stock.stock_id = nd_experiment_stock.stock_id AND nd_experiment_stock.type_id IN (SELECT cvterm_id from cvterm where cvterm.name='genotyping_experiment'))
     LEFT JOIN nd_experiment_protocol ON nd_experiment_stock.nd_experiment_id = nd_experiment_protocol.nd_experiment_id
     LEFT JOIN nd_protocol ON (nd_experiment_protocol.nd_protocol_id = nd_protocol.nd_protocol_id AND nd_protocol.type_id IN (SELECT cvterm_id from cvterm where cvterm.name='genotyping_experiment'))
     LEFT JOIN nd_experiment_genotype ON nd_experiment_stock.nd_experiment_id = nd_experiment_genotype.nd_experiment_id
     LEFT JOIN nd_experiment_stock AS nd_experiment_stock_accession ON (accession.stock_id = nd_experiment_stock_accession.stock_id AND nd_experiment_stock_accession.type_id IN (SELECT cvterm_id from cvterm where cvterm.name='genotyping_experiment'))
     LEFT JOIN nd_experiment_protocol AS nd_experiment_protocol_accession ON nd_experiment_stock_accession.nd_experiment_id = nd_experiment_protocol_accession.nd_experiment_id
     LEFT JOIN nd_protocol AS nd_protocol_accession ON (nd_experiment_protocol_accession.nd_protocol_id = nd_protocol_accession.nd_protocol_id AND nd_protocol_accession.type_id IN (SELECT cvterm_id from cvterm where cvterm.name='genotyping_experiment'))
     LEFT JOIN nd_experiment_genotype AS nd_experiment_genotype_accession ON nd_experiment_stock_accession.nd_experiment_id = nd_experiment_genotype_accession.nd_experiment_id
  WHERE accession.type_id IN (SELECT cvterm_id from cvterm where cvterm.name = 'accession') AND ( (nd_experiment_genotype.genotype_id IS NOT NULL AND nd_protocol.nd_protocol_id IS NOT NULL AND nd_experiment_stock.stock_id IS NOT NULL) OR (nd_experiment_genotype_accession.genotype_id IS NOT NULL AND nd_protocol_accession.nd_protocol_id IS NOT NULL AND nd_experiment_stock_accession.stock_id IS NOT NULL AND nd_experiment_stock IS NULL) )
  GROUP BY 1,2,3,4
  WITH DATA;

ALTER MATERIALIZED VIEW public.materialized_genoview rename to materialized_genoview_old;
ALTER MATERIALIZED VIEW public.materialized_genoview_new rename to materialized_genoview;
DROP MATERIALIZED VIEW IF EXISTS public.materialized_genoview_old CASCADE;
CREATE UNIQUE INDEX unq_geno_idx ON public.materialized_genoview(accession_id,genotype_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW materialized_genoview OWNER TO web_usr;\$\$
LANGUAGE SQL;
ALTER FUNCTION public.refresh_materialized_views_concurrently() OWNER TO web_usr;



DROP MATERIALIZED VIEW IF EXISTS public.materialized_phenoview CASCADE;
CREATE MATERIALIZED VIEW public.materialized_phenoview AS
SELECT
  breeding_program.project_id AS breeding_program_id,
  location.type_id AS location_id,
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

DROP MATERIALIZED VIEW IF EXISTS public.materialized_genoview CASCADE;
CREATE MATERIALIZED VIEW public.materialized_genoview AS
 SELECT
     CASE WHEN nd_experiment_stock.stock_id IS NOT NULL THEN stock_relationship.object_id ELSE accession.stock_id END AS accession_id,
     CASE WHEN nd_experiment_stock.stock_id IS NOT NULL THEN nd_experiment_protocol.nd_protocol_id ELSE nd_experiment_protocol_accession.nd_protocol_id END AS genotyping_protocol_id,
     CASE WHEN nd_experiment_stock.stock_id IS NOT NULL THEN nd_experiment_genotype.genotype_id ELSE nd_experiment_genotype_accession.genotype_id END AS genotype_id,
     CASE WHEN nd_experiment_stock.stock_id IS NOT NULL THEN stock_type.name ELSE 'accession' END AS stock_type
   FROM stock AS accession
     LEFT JOIN stock_relationship ON accession.stock_id = stock_relationship.object_id AND stock_relationship.type_id IN (SELECT cvterm_id from cvterm where cvterm.name IN ('tissue_sample_of', 'plant_of', 'plot_of') )
     LEFT JOIN stock ON stock_relationship.subject_id = stock.stock_id AND stock.type_id IN (SELECT cvterm_id from cvterm where cvterm.name IN ('tissue_sample', 'plant', 'plot') )
     LEFT JOIN cvterm AS stock_type ON (stock_type.cvterm_id = stock.type_id)
     LEFT JOIN nd_experiment_stock ON (stock.stock_id = nd_experiment_stock.stock_id AND nd_experiment_stock.type_id IN (SELECT cvterm_id from cvterm where cvterm.name='genotyping_experiment'))
     LEFT JOIN nd_experiment_protocol ON nd_experiment_stock.nd_experiment_id = nd_experiment_protocol.nd_experiment_id
     LEFT JOIN nd_protocol ON (nd_experiment_protocol.nd_protocol_id = nd_protocol.nd_protocol_id AND nd_protocol.type_id IN (SELECT cvterm_id from cvterm where cvterm.name='genotyping_experiment'))
     LEFT JOIN nd_experiment_genotype ON nd_experiment_stock.nd_experiment_id = nd_experiment_genotype.nd_experiment_id
     LEFT JOIN nd_experiment_stock AS nd_experiment_stock_accession ON (accession.stock_id = nd_experiment_stock_accession.stock_id AND nd_experiment_stock_accession.type_id IN (SELECT cvterm_id from cvterm where cvterm.name='genotyping_experiment'))
     LEFT JOIN nd_experiment_protocol AS nd_experiment_protocol_accession ON nd_experiment_stock_accession.nd_experiment_id = nd_experiment_protocol_accession.nd_experiment_id
     LEFT JOIN nd_protocol AS nd_protocol_accession ON (nd_experiment_protocol_accession.nd_protocol_id = nd_protocol_accession.nd_protocol_id AND nd_protocol_accession.type_id IN (SELECT cvterm_id from cvterm where cvterm.name='genotyping_experiment'))
     LEFT JOIN nd_experiment_genotype AS nd_experiment_genotype_accession ON nd_experiment_stock_accession.nd_experiment_id = nd_experiment_genotype_accession.nd_experiment_id
  WHERE accession.type_id IN (SELECT cvterm_id from cvterm where cvterm.name = 'accession') AND ( (nd_experiment_genotype.genotype_id IS NOT NULL AND nd_protocol.nd_protocol_id IS NOT NULL AND nd_experiment_stock.stock_id IS NOT NULL) OR (nd_experiment_genotype_accession.genotype_id IS NOT NULL AND nd_protocol_accession.nd_protocol_id IS NOT NULL AND nd_experiment_stock_accession.stock_id IS NOT NULL AND nd_experiment_stock IS NULL) )
  GROUP BY 1,2,3,4
  WITH DATA;
CREATE UNIQUE INDEX unq_geno_idx ON public.materialized_genoview(accession_id,genotype_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW materialized_genoview OWNER TO web_usr;



CREATE VIEW public.accessionsXseedlots AS
SELECT public.materialized_phenoview.accession_id,
    public.stock.stock_id AS seedlot_id
   FROM public.materialized_phenoview
   LEFT JOIN stock_relationship seedlot_relationship ON materialized_phenoview.accession_id = seedlot_relationship.subject_id AND seedlot_relationship.type_id IN (SELECT cvterm_id from cvterm where cvterm.name = 'collection_of')
   LEFT JOIN stock ON seedlot_relationship.object_id = stock.stock_id AND stock.type_id IN (SELECT cvterm_id from cvterm where cvterm.name = 'seedlot')
  GROUP BY public.materialized_phenoview.accession_id,public.stock.stock_id;
ALTER VIEW accessionsXseedlots OWNER TO web_usr;

CREATE VIEW public.breeding_programsXseedlots AS
SELECT public.materialized_phenoview.breeding_program_id,
    public.nd_experiment_stock.stock_id AS seedlot_id
   FROM public.materialized_phenoview
   LEFT JOIN nd_experiment_project ON materialized_phenoview.breeding_program_id = nd_experiment_project.project_id
   LEFT JOIN nd_experiment ON nd_experiment_project.nd_experiment_id = nd_experiment.nd_experiment_id AND nd_experiment.type_id IN (SELECT cvterm_id from cvterm where cvterm.name = 'seedlot_experiment')
   LEFT JOIN nd_experiment_stock ON nd_experiment.nd_experiment_id = nd_experiment_stock.nd_experiment_id
  GROUP BY 1,2;
ALTER VIEW breeding_programsXseedlots OWNER TO web_usr;

CREATE VIEW public.genotyping_protocolsXseedlots AS
SELECT public.materialized_genoview.genotyping_protocol_id,
public.stock.stock_id AS seedlot_id
FROM public.materialized_genoview
LEFT JOIN stock_relationship seedlot_relationship ON materialized_genoview.accession_id = seedlot_relationship.subject_id AND seedlot_relationship.type_id IN (SELECT cvterm_id from cvterm where cvterm.name = 'collection_of')
LEFT JOIN stock ON seedlot_relationship.object_id = stock.stock_id AND stock.type_id IN (SELECT cvterm_id from cvterm where cvterm.name = 'seedlot')
  GROUP BY 1,2;
ALTER VIEW genotyping_protocolsXseedlots OWNER TO web_usr;

CREATE VIEW public.plantsXseedlots AS
SELECT public.stock.stock_id AS plant_id,
    public.materialized_phenoview.seedlot_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plant'))
  GROUP BY 1,2;
ALTER VIEW plantsXseedlots OWNER TO web_usr;

CREATE VIEW public.plotsXseedlots AS
SELECT public.stock.stock_id AS plot_id,
    public.materialized_phenoview.seedlot_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plot'))
  GROUP BY 1,2;
ALTER VIEW plotsXseedlots OWNER TO web_usr;

CREATE VIEW public.seedlotsXtrait_components AS
SELECT public.materialized_phenoview.seedlot_id,
trait_component.cvterm_id AS trait_component_id
FROM public.materialized_phenoview
JOIN cvterm trait ON(materialized_phenoview.trait_id = trait.cvterm_id)
JOIN cvterm_relationship ON(trait.cvterm_id = cvterm_relationship.object_id AND cvterm_relationship.type_id = (SELECT cvterm_id from cvterm where name = 'contains'))
JOIN cvterm trait_component ON(cvterm_relationship.subject_id = trait_component.cvterm_id)
GROUP BY 1,2;
ALTER VIEW seedlotsXtrait_components OWNER TO web_usr;

CREATE VIEW public.seedlotsXtraits AS
SELECT public.materialized_phenoview.seedlot_id,
    public.materialized_phenoview.trait_id
   FROM public.materialized_phenoview
  GROUP BY 1,2;
ALTER VIEW seedlotsXtraits OWNER TO web_usr;

CREATE VIEW public.seedlotsXtrials AS
SELECT public.materialized_phenoview.seedlot_id,
    public.materialized_phenoview.trial_id
   FROM public.materialized_phenoview
  GROUP BY 1,2;
ALTER VIEW seedlotsXtrials OWNER TO web_usr;

CREATE VIEW public.seedlotsXtrial_designs AS
SELECT public.materialized_phenoview.seedlot_id,
    trialdesign.value AS trial_design_id
   FROM public.materialized_phenoview
   JOIN public.projectprop trialdesign ON materialized_phenoview.trial_id = trialdesign.project_id AND trialdesign.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'design' )
  GROUP BY 1,2;
ALTER VIEW seedlotsXtrial_designs OWNER TO web_usr;

CREATE VIEW public.seedlotsXtrial_types AS
SELECT public.materialized_phenoview.seedlot_id,
    trialterm.cvterm_id AS trial_type_id
   FROM public.materialized_phenoview
   JOIN projectprop trialprop ON materialized_phenoview.trial_id = trialprop.project_id AND trialprop.type_id IN (SELECT cvterm_id from cvterm JOIN cv USING(cv_id) WHERE cv.name = 'project_type' )
   JOIN cvterm trialterm ON trialprop.type_id = trialterm.cvterm_id
  GROUP BY 1,2;
ALTER VIEW seedlotsXtrial_types OWNER TO web_usr;

CREATE VIEW public.seedlotsXyears AS
SELECT public.materialized_phenoview.seedlot_id,
    public.materialized_phenoview.year_id
   FROM public.materialized_phenoview
  GROUP BY 1,2;
ALTER VIEW seedlotsXyears OWNER TO web_usr;

CREATE VIEW public.accessionsXtraits AS
SELECT public.materialized_phenoview.accession_id,
    public.materialized_phenoview.trait_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.accession_id, public.materialized_phenoview.trait_id;
ALTER VIEW accessionsXtraits OWNER TO web_usr;

CREATE VIEW public.breeding_programsXtraits AS
SELECT public.materialized_phenoview.breeding_program_id,
    public.materialized_phenoview.trait_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.breeding_program_id, public.materialized_phenoview.trait_id;
ALTER VIEW breeding_programsXtraits OWNER TO web_usr;

CREATE VIEW public.genotyping_protocolsXtraits AS
SELECT public.materialized_genoview.genotyping_protocol_id,
    public.materialized_phenoview.trait_id
   FROM public.materialized_genoview
   JOIN public.materialized_phenoview USING(accession_id)
  GROUP BY public.materialized_genoview.genotyping_protocol_id, public.materialized_phenoview.trait_id;
  ALTER VIEW genotyping_protocolsXtraits OWNER TO web_usr;

CREATE VIEW public.locationsXtraits AS
SELECT public.materialized_phenoview.location_id,
    public.materialized_phenoview.trait_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.location_id, public.materialized_phenoview.trait_id;
ALTER VIEW locationsXtraits OWNER TO web_usr;

CREATE VIEW public.plantsXtraits AS
SELECT public.stock.stock_id AS plant_id,
    public.materialized_phenoview.trait_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plant'))
  GROUP BY public.stock.stock_id, public.materialized_phenoview.trait_id;
ALTER VIEW plantsXtraits OWNER TO web_usr;

CREATE VIEW public.plotsXtraits AS
SELECT public.stock.stock_id AS plot_id,
    public.materialized_phenoview.trait_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plot'))
  GROUP BY public.stock.stock_id, public.materialized_phenoview.trait_id;
ALTER VIEW plotsXtraits OWNER TO web_usr;

CREATE VIEW public.traitsXtrials AS
SELECT public.materialized_phenoview.trait_id,
    public.materialized_phenoview.trial_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.trait_id, public.materialized_phenoview.trial_id;
ALTER VIEW traitsXtrials OWNER TO web_usr;

CREATE VIEW public.traitsXtrial_designs AS
SELECT public.materialized_phenoview.trait_id,
    trialdesign.value AS trial_design_id
   FROM public.materialized_phenoview
   JOIN public.projectprop trialdesign ON materialized_phenoview.trial_id = trialdesign.project_id AND trialdesign.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'design' )
  GROUP BY public.materialized_phenoview.trait_id, trialdesign.value;
ALTER VIEW traitsXtrial_designs OWNER TO web_usr;

CREATE VIEW public.traitsXtrial_types AS
SELECT public.materialized_phenoview.trait_id,
    trialterm.cvterm_id AS trial_type_id
   FROM public.materialized_phenoview
   JOIN projectprop trialprop ON materialized_phenoview.trial_id = trialprop.project_id AND trialprop.type_id IN (SELECT cvterm_id from cvterm JOIN cv USING(cv_id) WHERE cv.name = 'project_type' )
   JOIN cvterm trialterm ON trialprop.type_id = trialterm.cvterm_id
  GROUP BY public.materialized_phenoview.trait_id, trialterm.cvterm_id;
ALTER VIEW traitsXtrial_types OWNER TO web_usr;

CREATE VIEW public.traitsXyears AS
SELECT public.materialized_phenoview.trait_id,
    public.materialized_phenoview.year_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.trait_id, public.materialized_phenoview.year_id;
ALTER VIEW traitsXyears OWNER TO web_usr;

CREATE VIEW public.accessionsXtrait_components AS
SELECT public.materialized_phenoview.accession_id,
    trait_component.cvterm_id AS trait_component_id
   FROM public.materialized_phenoview
   JOIN cvterm trait ON(materialized_phenoview.trait_id = trait.cvterm_id)
   JOIN cvterm_relationship ON(trait.cvterm_id = cvterm_relationship.object_id AND cvterm_relationship.type_id = (SELECT cvterm_id from cvterm where name = 'contains'))
   JOIN cvterm trait_component ON(cvterm_relationship.subject_id = trait_component.cvterm_id)
  GROUP BY 1,2;
ALTER VIEW accessionsXtrait_components OWNER TO web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('accessionsXtrait_components', FALSE, CURRENT_TIMESTAMP) ON CONFLICT DO NOTHING;

CREATE VIEW public.breeding_programsXtrait_components AS
SELECT public.materialized_phenoview.breeding_program_id,
trait_component.cvterm_id AS trait_component_id
FROM public.materialized_phenoview
JOIN cvterm trait ON(materialized_phenoview.trait_id = trait.cvterm_id)
JOIN cvterm_relationship ON(trait.cvterm_id = cvterm_relationship.object_id AND cvterm_relationship.type_id = (SELECT cvterm_id from cvterm where name = 'contains'))
JOIN cvterm trait_component ON(cvterm_relationship.subject_id = trait_component.cvterm_id)
GROUP BY 1,2;
ALTER VIEW breeding_programsXtrait_components OWNER TO web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('breeding_programsXtrait_components', FALSE, CURRENT_TIMESTAMP) ON CONFLICT DO NOTHING;

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
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('genotyping_protocolsXtrait_components', FALSE, CURRENT_TIMESTAMP) ON CONFLICT DO NOTHING;

CREATE VIEW public.locationsXtrait_components AS
SELECT public.materialized_phenoview.location_id,
trait_component.cvterm_id AS trait_component_id
FROM public.materialized_phenoview
JOIN cvterm trait ON(materialized_phenoview.trait_id = trait.cvterm_id)
JOIN cvterm_relationship ON(trait.cvterm_id = cvterm_relationship.object_id AND cvterm_relationship.type_id = (SELECT cvterm_id from cvterm where name = 'contains'))
JOIN cvterm trait_component ON(cvterm_relationship.subject_id = trait_component.cvterm_id)
GROUP BY 1,2;
ALTER VIEW locationsXtrait_components OWNER TO web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('locationsXtrait_components', FALSE, CURRENT_TIMESTAMP) ON CONFLICT DO NOTHING;

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
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('plantsXtrait_components', FALSE, CURRENT_TIMESTAMP) ON CONFLICT DO NOTHING;

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
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('plotsXtrait_components', FALSE, CURRENT_TIMESTAMP) ON CONFLICT DO NOTHING;

CREATE VIEW public.trait_componentsXtrials AS
SELECT trait_component.cvterm_id AS trait_component_id,
    public.materialized_phenoview.trial_id
    FROM public.materialized_phenoview
    JOIN cvterm trait ON(materialized_phenoview.trait_id = trait.cvterm_id)
    JOIN cvterm_relationship ON(trait.cvterm_id = cvterm_relationship.object_id AND cvterm_relationship.type_id = (SELECT cvterm_id from cvterm where name = 'contains'))
    JOIN cvterm trait_component ON(cvterm_relationship.subject_id = trait_component.cvterm_id)
    GROUP BY 1,2;
ALTER VIEW trait_componentsXtrials OWNER TO web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('trait_componentsXtrials', FALSE, CURRENT_TIMESTAMP) ON CONFLICT DO NOTHING;

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
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('trait_componentsXtrial_designs', FALSE, CURRENT_TIMESTAMP) ON CONFLICT DO NOTHING;

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
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('trait_componentsXtrial_types', FALSE, CURRENT_TIMESTAMP) ON CONFLICT DO NOTHING;

CREATE VIEW public.trait_componentsXyears AS
SELECT trait_component.cvterm_id AS trait_component_id,
    public.materialized_phenoview.year_id
   FROM public.materialized_phenoview
   JOIN cvterm trait ON(materialized_phenoview.trait_id = trait.cvterm_id)
   JOIN cvterm_relationship ON(trait.cvterm_id = cvterm_relationship.object_id AND cvterm_relationship.type_id = (SELECT cvterm_id from cvterm where name = 'contains'))
   JOIN cvterm trait_component ON(cvterm_relationship.subject_id = trait_component.cvterm_id)
  GROUP BY 1,2;
ALTER VIEW trait_componentsXyears OWNER TO web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('trait_componentsXyears', FALSE, CURRENT_TIMESTAMP) ON CONFLICT DO NOTHING;

-- FIX VIEWS FOR PLANTS, PLOTS, TRIAL DESIGNS AND TRIAL TYPES

CREATE VIEW public.accessionsXbreeding_programs AS
SELECT public.materialized_phenoview.accession_id,
    public.materialized_phenoview.breeding_program_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.accession_id, public.materialized_phenoview.breeding_program_id
  ALTER VIEW accessionsXbreeding_programs OWNER TO web_usr;

CREATE VIEW public.accessionsXgenotyping_protocols AS
SELECT public.materialized_genoview.accession_id,
    public.materialized_genoview.genotyping_protocol_id
   FROM public.materialized_genoview
  GROUP BY public.materialized_genoview.accession_id, public.materialized_genoview.genotyping_protocol_id
  ALTER VIEW accessionsXgenotyping_protocols OWNER TO web_usr;

CREATE VIEW public.accessionsXlocations AS
SELECT public.materialized_phenoview.accession_id,
    public.materialized_phenoview.location_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.accession_id, public.materialized_phenoview.location_id
  ALTER VIEW accessionsXlocations OWNER TO web_usr;

CREATE VIEW public.accessionsXplants AS
SELECT public.materialized_phenoview.accession_id,
    public.stock.stock_id AS plant_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plant'))
  GROUP BY public.materialized_phenoview.accession_id, public.stock.stock_id
  ALTER VIEW accessionsXplants OWNER TO web_usr;

CREATE VIEW public.accessionsXplots AS
SELECT public.materialized_phenoview.accession_id,
    public.stock.stock_id AS plot_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plot'))
  GROUP BY public.materialized_phenoview.accession_id, public.stock.stock_id;
ALTER VIEW accessionsXplots OWNER TO web_usr;

CREATE VIEW public.accessionsXtrial_designs AS
SELECT public.materialized_phenoview.accession_id,
    trialdesign.value AS trial_design_id
   FROM public.materialized_phenoview
   JOIN public.projectprop trialdesign ON materialized_phenoview.trial_id = trialdesign.project_id AND trialdesign.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'design' )
  GROUP BY public.materialized_phenoview.accession_id, trialdesign.value;
ALTER VIEW accessionsXtrial_designs OWNER TO web_usr;

CREATE VIEW public.accessionsXtrial_types AS
SELECT public.materialized_phenoview.accession_id,
    trialterm.cvterm_id AS trial_type_id
   FROM public.materialized_phenoview
   JOIN projectprop trialprop ON materialized_phenoview.trial_id = trialprop.project_id AND trialprop.type_id IN (SELECT cvterm_id from cvterm JOIN cv USING(cv_id) WHERE cv.name = 'project_type' )
   JOIN cvterm trialterm ON trialprop.type_id = trialterm.cvterm_id
  GROUP BY public.materialized_phenoview.accession_id, trialterm.cvterm_id;
ALTER VIEW accessionsXtrial_types OWNER TO web_usr;

CREATE VIEW public.accessionsXtrials AS
SELECT public.materialized_phenoview.accession_id,
    public.materialized_phenoview.trial_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.accession_id, public.materialized_phenoview.trial_id;
ALTER VIEW accessionsXtrials OWNER TO web_usr;

CREATE VIEW public.accessionsXyears AS
SELECT public.materialized_phenoview.accession_id,
    public.materialized_phenoview.year_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.accession_id, public.materialized_phenoview.year_id;
ALTER VIEW accessionsXyears OWNER TO web_usr;

CREATE VIEW public.breeding_programsXgenotyping_protocols AS
SELECT public.materialized_phenoview.breeding_program_id,
    public.materialized_genoview.genotyping_protocol_id
   FROM public.materialized_phenoview
   JOIN public.materialized_genoview USING(accession_id)
  GROUP BY public.materialized_phenoview.breeding_program_id, public.materialized_genoview.genotyping_protocol_id;
ALTER VIEW breeding_programsXgenotyping_protocols OWNER TO web_usr;

CREATE VIEW public.breeding_programsXlocations AS
SELECT public.materialized_phenoview.breeding_program_id,
    public.materialized_phenoview.location_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.breeding_program_id, public.materialized_phenoview.location_id;
ALTER VIEW breeding_programsXlocations OWNER TO web_usr;

CREATE VIEW public.breeding_programsXplants AS
SELECT public.materialized_phenoview.breeding_program_id,
    public.stock.stock_id AS plant_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plant'))
  GROUP BY public.materialized_phenoview.breeding_program_id, public.stock.stock_id
  ALTER VIEW breeding_programsXplants OWNER TO web_usr;

CREATE VIEW public.breeding_programsXplots AS
SELECT public.materialized_phenoview.breeding_program_id,
    public.stock.stock_id AS plot_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plot'))
  GROUP BY public.materialized_phenoview.breeding_program_id, public.stock.stock_id;
ALTER VIEW breeding_programsXplots OWNER TO web_usr;

CREATE VIEW public.breeding_programsXtrial_designs AS
SELECT public.materialized_phenoview.breeding_program_id,
    trialdesign.value AS trial_design_id
   FROM public.materialized_phenoview
   JOIN public.projectprop trialdesign ON materialized_phenoview.trial_id = trialdesign.project_id AND trialdesign.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'design' )
  GROUP BY public.materialized_phenoview.breeding_program_id, trialdesign.value;
ALTER VIEW breeding_programsXtrial_designs OWNER TO web_usr;

CREATE VIEW public.breeding_programsXtrial_types AS
SELECT public.materialized_phenoview.breeding_program_id,
    trialterm.cvterm_id AS trial_type_id
   FROM public.materialized_phenoview
   JOIN projectprop trialprop ON materialized_phenoview.trial_id = trialprop.project_id AND trialprop.type_id IN (SELECT cvterm_id from cvterm JOIN cv USING(cv_id) WHERE cv.name = 'project_type' )
   JOIN cvterm trialterm ON trialprop.type_id = trialterm.cvterm_id
  GROUP BY public.materialized_phenoview.breeding_program_id, trialterm.cvterm_id;
ALTER VIEW breeding_programsXtrial_types OWNER TO web_usr;

CREATE VIEW public.breeding_programsXtrials AS
SELECT public.materialized_phenoview.breeding_program_id,
    public.materialized_phenoview.trial_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.breeding_program_id, public.materialized_phenoview.trial_id;
ALTER VIEW breeding_programsXtrials OWNER TO web_usr;

CREATE VIEW public.breeding_programsXyears AS
SELECT public.materialized_phenoview.breeding_program_id,
    public.materialized_phenoview.year_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.breeding_program_id, public.materialized_phenoview.year_id;
ALTER VIEW breeding_programsXyears OWNER TO web_usr;

CREATE VIEW public.genotyping_protocolsXlocations AS
SELECT public.materialized_genoview.genotyping_protocol_id,
    public.materialized_phenoview.location_id
   FROM public.materialized_genoview
   JOIN public.materialized_phenoview USING(accession_id)
  GROUP BY public.materialized_genoview.genotyping_protocol_id, public.materialized_phenoview.location_id;
ALTER VIEW genotyping_protocolsXlocations OWNER TO web_usr;

CREATE VIEW public.genotyping_protocolsXplants AS
SELECT public.materialized_genoview.genotyping_protocol_id,
    public.stock.stock_id AS plant_id
   FROM public.materialized_genoview
   JOIN public.materialized_phenoview USING(accession_id)
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plant'))
  GROUP BY public.materialized_genoview.genotyping_protocol_id, public.stock.stock_id
  ALTER VIEW genotyping_protocolsXplants OWNER TO web_usr;

CREATE VIEW public.genotyping_protocolsXplots AS
SELECT public.materialized_genoview.genotyping_protocol_id,
    public.stock.stock_id AS plot_id
    FROM public.materialized_genoview
    JOIN public.materialized_phenoview USING(accession_id)
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plot'))
  GROUP BY public.materialized_genoview.genotyping_protocol_id, public.stock.stock_id;
ALTER VIEW genotyping_protocolsXplots OWNER TO web_usr;

CREATE VIEW public.genotyping_protocolsXtrial_designs AS
SELECT public.materialized_genoview.genotyping_protocol_id,
    trialdesign.value AS trial_design_id
    FROM public.materialized_genoview
    JOIN public.materialized_phenoview USING(accession_id)
   JOIN public.projectprop trialdesign ON materialized_phenoview.trial_id = trialdesign.project_id AND trialdesign.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'design' )
  GROUP BY public.materialized_genoview.genotyping_protocol_id, trialdesign.value;
ALTER VIEW genotyping_protocolsXtrial_designs OWNER TO web_usr;

CREATE VIEW public.genotyping_protocolsXtrial_types AS
SELECT public.materialized_genoview.genotyping_protocol_id,
    trialterm.cvterm_id AS trial_type_id
    FROM public.materialized_genoview
    JOIN public.materialized_phenoview USING(accession_id)
   JOIN projectprop trialprop ON materialized_phenoview.trial_id = trialprop.project_id AND trialprop.type_id IN (SELECT cvterm_id from cvterm JOIN cv USING(cv_id) WHERE cv.name = 'project_type' )
   JOIN cvterm trialterm ON trialprop.type_id = trialterm.cvterm_id
  GROUP BY public.materialized_genoview.genotyping_protocol_id, trialterm.cvterm_id;
ALTER VIEW genotyping_protocolsXtrial_types OWNER TO web_usr;

CREATE VIEW public.genotyping_protocolsXtrials AS
SELECT public.materialized_genoview.genotyping_protocol_id,
    public.materialized_phenoview.trial_id
   FROM public.materialized_genoview
   JOIN public.materialized_phenoview USING(accession_id)
  GROUP BY public.materialized_genoview.genotyping_protocol_id, public.materialized_phenoview.trial_id;
ALTER VIEW genotyping_protocolsXtrials OWNER TO web_usr;

CREATE VIEW public.genotyping_protocolsXyears AS
SELECT public.materialized_genoview.genotyping_protocol_id,
    public.materialized_phenoview.year_id
   FROM public.materialized_genoview
   JOIN public.materialized_phenoview USING(accession_id)
  GROUP BY public.materialized_genoview.genotyping_protocol_id, public.materialized_phenoview.year_id;
ALTER VIEW genotyping_protocolsXyears OWNER TO web_usr;

CREATE VIEW public.locationsXplants AS
SELECT public.materialized_phenoview.location_id,
    public.stock.stock_id AS plant_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plant'))
  GROUP BY public.materialized_phenoview.location_id, public.stock.stock_id
  ALTER VIEW locationsXplants OWNER TO web_usr;

CREATE VIEW public.locationsXplots AS
SELECT public.materialized_phenoview.location_id,
    public.stock.stock_id AS plot_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plot'))
  GROUP BY public.materialized_phenoview.location_id, public.stock.stock_id;
ALTER VIEW locationsXplots OWNER TO web_usr;

CREATE VIEW public.locationsXtrial_designs AS
SELECT public.materialized_phenoview.location_id,
    trialdesign.value AS trial_design_id
   FROM public.materialized_phenoview
   JOIN public.projectprop trialdesign ON materialized_phenoview.trial_id = trialdesign.project_id AND trialdesign.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'design' )
  GROUP BY public.materialized_phenoview.location_id, trialdesign.value;
ALTER VIEW locationsXtrial_designs OWNER TO web_usr;

CREATE VIEW public.locationsXtrial_types AS
SELECT public.materialized_phenoview.location_id,
    trialterm.cvterm_id AS trial_type_id
   FROM public.materialized_phenoview
   JOIN projectprop trialprop ON materialized_phenoview.trial_id = trialprop.project_id AND trialprop.type_id IN (SELECT cvterm_id from cvterm JOIN cv USING(cv_id) WHERE cv.name = 'project_type' )
   JOIN cvterm trialterm ON trialprop.type_id = trialterm.cvterm_id
  GROUP BY public.materialized_phenoview.location_id, trialterm.cvterm_id;
ALTER VIEW locationsXtrial_types OWNER TO web_usr;

CREATE VIEW public.locationsXtrials AS
SELECT public.materialized_phenoview.location_id,
    public.materialized_phenoview.trial_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.location_id, public.materialized_phenoview.trial_id;
ALTER VIEW locationsXtrials OWNER TO web_usr;

CREATE VIEW public.locationsXyears AS
SELECT public.materialized_phenoview.location_id,
    public.materialized_phenoview.year_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.location_id, public.materialized_phenoview.year_id;
ALTER VIEW locationsXyears OWNER TO web_usr;

CREATE VIEW public.plantsXplots AS
SELECT plant.stock_id AS plant_id,
    plot.stock_id AS plot_id
   FROM public.materialized_phenoview
   JOIN stock plot ON(public.materialized_phenoview.stock_id = plot.stock_id AND plot.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plot'))
   JOIN stock_relationship plant_relationship ON plot.stock_id = plant_relationship.subject_id
   JOIN stock plant ON plant_relationship.object_id = plant.stock_id AND plant.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plant')
  GROUP BY plant.stock_id, plot.stock_id;
ALTER VIEW plantsXplots OWNER TO web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('plantsXplots', FALSE, CURRENT_TIMESTAMP) ON CONFLICT DO NOTHING;

CREATE VIEW public.plantsXtrials AS
SELECT public.stock.stock_id AS plant_id,
    public.materialized_phenoview.trial_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plant'))
  GROUP BY public.stock.stock_id, public.materialized_phenoview.trial_id;
ALTER VIEW plantsXtrials OWNER TO web_usr;

CREATE VIEW public.plantsXtrial_designs AS
SELECT public.stock.stock_id AS plant_id,
    trialdesign.value AS trial_design_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plant'))
   JOIN public.projectprop trialdesign ON materialized_phenoview.trial_id = trialdesign.project_id AND trialdesign.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'design' )
  GROUP BY stock.stock_id, trialdesign.value;
ALTER VIEW plantsXtrial_designs OWNER TO web_usr;

CREATE VIEW public.plantsXtrial_types AS
SELECT public.stock.stock_id AS plant_id,
    trialterm.cvterm_id AS trial_type_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plant'))
   JOIN projectprop trialprop ON materialized_phenoview.trial_id = trialprop.project_id AND trialprop.type_id IN (SELECT cvterm_id from cvterm JOIN cv USING(cv_id) WHERE cv.name = 'project_type' )
   JOIN cvterm trialterm ON trialprop.type_id = trialterm.cvterm_id
  GROUP BY public.stock.stock_id, trialterm.cvterm_id;
ALTER VIEW plantsXtrial_types OWNER TO web_usr;

CREATE VIEW public.plantsXyears AS
SELECT public.stock.stock_id AS plant_id,
    public.materialized_phenoview.year_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plant'))
  GROUP BY public.stock.stock_id, public.materialized_phenoview.year_id;
ALTER VIEW plantsXyears OWNER TO web_usr;

CREATE VIEW public.plotsXtrials AS
SELECT public.stock.stock_id AS plot_id,
    public.materialized_phenoview.trial_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plot'))
  GROUP BY public.stock.stock_id, public.materialized_phenoview.trial_id;
ALTER VIEW plotsXtrials OWNER TO web_usr;

CREATE VIEW public.plotsXtrial_designs AS
SELECT public.stock.stock_id AS plot_id,
    trialdesign.value AS trial_design_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plot'))
   JOIN public.projectprop trialdesign ON materialized_phenoview.trial_id = trialdesign.project_id AND trialdesign.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'design' )
  GROUP BY stock.stock_id, trialdesign.value;
ALTER VIEW plotsXtrial_designs OWNER TO web_usr;

CREATE VIEW public.plotsXtrial_types AS
SELECT public.stock.stock_id AS plot_id,
    trialterm.cvterm_id AS trial_type_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plot'))
   JOIN projectprop trialprop ON materialized_phenoview.trial_id = trialprop.project_id AND trialprop.type_id IN (SELECT cvterm_id from cvterm JOIN cv USING(cv_id) WHERE cv.name = 'project_type' )
   JOIN cvterm trialterm ON trialprop.type_id = trialterm.cvterm_id
  GROUP BY public.stock.stock_id, trialterm.cvterm_id;
ALTER VIEW plotsXtrial_types OWNER TO web_usr;

CREATE VIEW public.plotsXyears AS
SELECT public.stock.stock_id AS plot_id,
    public.materialized_phenoview.year_id
   FROM public.materialized_phenoview
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plot'))
  GROUP BY public.stock.stock_id, public.materialized_phenoview.year_id;
ALTER VIEW plotsXyears OWNER TO web_usr;

CREATE VIEW public.trial_designsXtrial_types AS
SELECT trialdesign.value AS trial_design_id,
    trialterm.cvterm_id AS trial_type_id
   FROM public.materialized_phenoview
   JOIN public.projectprop trialdesign ON materialized_phenoview.trial_id = trialdesign.project_id AND trialdesign.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'design' )
   JOIN projectprop trialprop ON materialized_phenoview.trial_id = trialprop.project_id AND trialprop.type_id IN (SELECT cvterm_id from cvterm JOIN cv USING(cv_id) WHERE cv.name = 'project_type' )
   JOIN cvterm trialterm ON trialprop.type_id = trialterm.cvterm_id
  GROUP BY trialdesign.value, trialterm.cvterm_id;
ALTER VIEW trial_designsXtrial_types OWNER TO web_usr;

CREATE VIEW public.trial_designsXtrials AS
SELECT trialdesign.value AS trial_design_id,
    public.materialized_phenoview.trial_id
   FROM public.materialized_phenoview
   JOIN public.projectprop trialdesign ON materialized_phenoview.trial_id = trialdesign.project_id AND trialdesign.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'design' )
  GROUP BY trialdesign.value, public.materialized_phenoview.trial_id;
ALTER VIEW trial_designsXtrials OWNER TO web_usr;

CREATE VIEW public.trial_designsXyears AS
SELECT trialdesign.value AS trial_design_id,
    public.materialized_phenoview.year_id
   FROM public.materialized_phenoview
   JOIN public.projectprop trialdesign ON materialized_phenoview.trial_id = trialdesign.project_id AND trialdesign.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'design' )
  GROUP BY trialdesign.value, public.materialized_phenoview.year_id;
ALTER VIEW trial_designsXyears OWNER TO web_usr;

CREATE VIEW public.trial_typesXtrials AS
SELECT trialterm.cvterm_id AS trial_type_id,
    public.materialized_phenoview.trial_id
   FROM public.materialized_phenoview
   JOIN projectprop trialprop ON materialized_phenoview.trial_id = trialprop.project_id AND trialprop.type_id IN (SELECT cvterm_id from cvterm JOIN cv USING(cv_id) WHERE cv.name = 'project_type' )
   JOIN cvterm trialterm ON trialprop.type_id = trialterm.cvterm_id
  GROUP BY trialterm.cvterm_id, public.materialized_phenoview.trial_id;
ALTER VIEW trial_typesXtrials OWNER TO web_usr;

CREATE VIEW public.trial_typesXyears AS
SELECT trialterm.cvterm_id AS trial_type_id,
    public.materialized_phenoview.year_id
   FROM public.materialized_phenoview
   JOIN projectprop trialprop ON materialized_phenoview.trial_id = trialprop.project_id AND trialprop.type_id IN (SELECT cvterm_id from cvterm JOIN cv USING(cv_id) WHERE cv.name = 'project_type' )
   JOIN cvterm trialterm ON trialprop.type_id = trialterm.cvterm_id
  GROUP BY trialterm.cvterm_id, public.materialized_phenoview.year_id;
ALTER VIEW trial_typesXyears OWNER TO web_usr;

CREATE VIEW public.trialsXyears AS
SELECT public.materialized_phenoview.trial_id,
    public.materialized_phenoview.year_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.trial_id, public.materialized_phenoview.year_id;
ALTER VIEW trialsXyears OWNER TO web_usr;


CREATE VIEW public.accessionsxgenotyping_projects AS
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
  GROUP BY accessions.accession_id, genotyping_project_id;
 ALTER VIEW public.accessionsxgenotyping_projects OWNER TO web_usr;

CREATE VIEW public.trialsxgenotyping_projects AS
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
  GROUP BY trials.trial_id, nd_experiment_project.project_id;
 ALTER VIEW public.trialsxgenotyping_projects OWNER TO web_usr;

CREATE VIEW public.genotyping_projectsxaccessions AS
 SELECT nd_experiment_project.project_id AS genotyping_project_id,
    materialized_genoview.accession_id
   FROM ((nd_experiment_project
     JOIN nd_experiment_genotype ON ((nd_experiment_project.nd_experiment_id = nd_experiment_genotype.nd_experiment_id)))
     JOIN materialized_genoview ON ((nd_experiment_genotype.genotype_id = materialized_genoview.genotype_id)))
  WHERE (nd_experiment_project.project_id IN ( SELECT genotyping_projects.genotyping_project_id
           FROM genotyping_projects))
  GROUP BY genotyping_project_id, materialized_genoview.accession_id;
 ALTER VIEW public.genotyping_projectsxaccessions OWNER TO web_usr;

CREATE VIEW public.genotyping_projectsxtraits AS
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
  GROUP BY nd_experiment_project.project_id, materialized_phenoview.trait_id;
 ALTER VIEW public.genotyping_projectsxtraits OWNER TO web_usr;

CREATE VIEW public.genotyping_projectsxtrials AS
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
  GROUP BY nd_experiment_project.project_id, materialized_phenoview.trial_id;
 ALTER VIEW public.genotyping_projectsxtrials OWNER TO web_usr;


EOSQL

print "You're done!\n";
}


####
1; #
####
