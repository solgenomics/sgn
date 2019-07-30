#!/usr/bin/env perl

=head1 NAME

UpdateMaterializedViewsTissueSamplePhenotypingGenotyping.pm

=head1 SYNOPSIS

mx-run UpdateMaterializedViewsTissueSamplePhenotypingGenotyping [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch updates materialized views so that the materialized_phenotype table includes tissue samples that were phenotyped, and the genotype materialized view includes tissue samples that were genotyped

=head1 AUTHOR

Nicolas Morales<nm529@cornell.edu>
Bryan Ellerbrock<bje24@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package UpgradeGenotypeStorage;

use Moose;
use CXGN::BreederSearch;
use Try::Tiny;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch converts genotypeprop values to jsonb, and fixes genotype related materialized views.

sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    $self->dbh->do(<<EOSQL);

--do your SQL here

-- REDEFINE materialized_phenoview, adding tissue samples:

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
     LEFT JOIN stock_relationship ON accession.stock_id = stock_relationship.object_id AND stock_relationship.type_id IN (SELECT cvterm_id from cvterm where cvterm.name = 'plot_of' OR cvterm.name = 'plant_of' OR cvterm.name = 'tissue_sample_of')
     LEFT JOIN stock ON stock_relationship.subject_id = stock.stock_id AND stock.type_id IN (SELECT cvterm_id from cvterm where cvterm.name = 'plot' OR cvterm.name = 'plant' OR cvterm.name = 'tissue_sample')
     LEFT JOIN stock_relationship seedlot_relationship ON stock.stock_id = seedlot_relationship.subject_id AND seedlot_relationship.type_id IN (SELECT cvterm_id from cvterm where cvterm.name = 'seed transaction')
     LEFT JOIN stock seedlot ON seedlot_relationship.object_id = seedlot.stock_id AND seedlot.type_id IN (SELECT cvterm_id from cvterm where cvterm.name = 'seedlot')
     LEFT JOIN nd_experiment_stock ON(stock.stock_id = nd_experiment_stock.stock_id AND nd_experiment_stock.type_id IN (SELECT cvterm_id from cvterm where cvterm.name IN ('phenotyping_experiment', 'field_layout')))
     LEFT JOIN nd_experiment ON(nd_experiment_stock.nd_experiment_id = nd_experiment.nd_experiment_id AND nd_experiment.type_id IN (SELECT cvterm_id from cvterm where cvterm.name IN ('phenotyping_experiment', 'field_layout')))
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

-- REDEFINE materialized_genoview, adding tissue samples

DROP MATERIALIZED VIEW IF EXISTS public.materialized_genoview CASCADE;
CREATE MATERIALIZED VIEW public.materialized_genoview AS
 SELECT stock.stock_id AS stock_id,
    stock_type.name AS stock_type,
    nd_experiment_protocol.nd_protocol_id AS genotyping_protocol_id,
    nd_experiment_genotype.genotype_id AS genotype_id
   FROM stock
     JOIN cvterm AS stock_type ON (stock_type.cvterm_id = stock.type_id)
     LEFT JOIN nd_experiment_stock ON stock.stock_id = nd_experiment_stock.stock_id
     LEFT JOIN nd_experiment_protocol ON nd_experiment_stock.nd_experiment_id = nd_experiment_protocol.nd_experiment_id
     LEFT JOIN nd_protocol ON nd_experiment_protocol.nd_protocol_id = nd_protocol.nd_protocol_id
     LEFT JOIN nd_experiment_genotype ON nd_experiment_stock.nd_experiment_id = nd_experiment_genotype.nd_experiment_id
  WHERE stock.type_id IN (SELECT cvterm_id from cvterm where cvterm.name = 'accession' OR cvterm.name = 'tissue_sample')
  GROUP BY 1,2,3,4
  WITH DATA;

CREATE UNIQUE INDEX unq_geno_idx ON public.materialized_genoview(stock_id,genotype_id) WITH (fillfactor=100);
CREATE INDEX stock_id_geno_idx ON public.materialized_genoview(stock_id) WITH (fillfactor=100);
CREATE INDEX genotyping_protocol_id_idx ON public.materialized_genoview(genotyping_protocol_id) WITH (fillfactor=100);
CREATE INDEX genotype_id_idx ON public.materialized_genoview(genotype_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW materialized_genoview OWNER TO web_usr;

DROP MATERIALIZED VIEW IF EXISTS public.genotyping_protocolsXseedlots CASCADE;
CREATE MATERIALIZED VIEW public.genotyping_protocolsXseedlots AS
SELECT public.materialized_genoview.genotyping_protocol_id,
public.stock.stock_id AS seedlot_id
FROM public.materialized_genoview
LEFT JOIN stock_relationship seedlot_relationship ON materialized_genoview.stock_id = seedlot_relationship.subject_id AND seedlot_relationship.type_id IN (SELECT cvterm_id from cvterm where cvterm.name = 'collection_of')
LEFT JOIN stock ON seedlot_relationship.object_id = stock.stock_id AND stock.type_id IN (SELECT cvterm_id from cvterm where cvterm.name = 'seedlot')
  GROUP BY 1,2
WITH DATA;
CREATE UNIQUE INDEX genotyping_protocolsXseedlots_idx ON public.genotyping_protocolsXseedlots(genotyping_protocol_id, seedlot_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW genotyping_protocolsXseedlots OWNER TO web_usr;

DROP MATERIALIZED VIEW IF EXISTS public.genotyping_protocolsXtraits CASCADE;
CREATE MATERIALIZED VIEW public.genotyping_protocolsXtraits AS
SELECT public.materialized_genoview.genotyping_protocol_id,
    public.materialized_phenoview.trait_id
   FROM public.materialized_genoview
   LEFT JOIN public.materialized_phenoview ON(public.materialized_phenoview.stock_id = public.materialized_genoview.stock_id)
  GROUP BY public.materialized_genoview.genotyping_protocol_id, public.materialized_phenoview.trait_id
  WITH DATA;
CREATE UNIQUE INDEX genotyping_protocolsXtraits_idx ON public.genotyping_protocolsXtraits(genotyping_protocol_id, trait_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW genotyping_protocolsXtraits OWNER TO web_usr;

DROP MATERIALIZED VIEW IF EXISTS public.genotyping_protocolsXtrait_components CASCADE;
CREATE MATERIALIZED VIEW public.genotyping_protocolsXtrait_components AS
SELECT public.materialized_genoview.genotyping_protocol_id,
trait_component.cvterm_id AS trait_component_id
FROM public.materialized_genoview
JOIN public.materialized_phenoview USING(stock_id)
JOIN cvterm trait ON(materialized_phenoview.trait_id = trait.cvterm_id)
JOIN cvterm_relationship ON(trait.cvterm_id = cvterm_relationship.object_id AND cvterm_relationship.type_id = (SELECT cvterm_id from cvterm where name = 'contains'))
JOIN cvterm trait_component ON(cvterm_relationship.subject_id = trait_component.cvterm_id)
GROUP BY 1,2
WITH DATA;
CREATE UNIQUE INDEX genotyping_protocolsXtrait_components_idx ON public.genotyping_protocolsXtrait_components(genotyping_protocol_id, trait_component_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW genotyping_protocolsXtrait_components OWNER TO web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('genotyping_protocolsXtrait_components', FALSE, CURRENT_TIMESTAMP);

DROP MATERIALIZED VIEW IF EXISTS public.accessionsXgenotyping_protocols CASCADE;
CREATE MATERIALIZED VIEW public.accessionsXgenotyping_protocols AS
SELECT public.materialized_genoview.stock_id,
    public.materialized_genoview.genotyping_protocol_id
   FROM public.materialized_genoview
   WHERE public.materialized_genoview.stock_type = 'accession'
  GROUP BY public.materialized_genoview.stock_id, public.materialized_genoview.genotyping_protocol_id
  WITH DATA;
CREATE UNIQUE INDEX accessionsXgenotyping_protocols_idx ON public.accessionsXgenotyping_protocols(stock_id, genotyping_protocol_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW accessionsXgenotyping_protocols OWNER TO web_usr;

DROP MATERIALIZED VIEW IF EXISTS public.breeding_programsXgenotyping_protocols CASCADE;
CREATE MATERIALIZED VIEW public.breeding_programsXgenotyping_protocols AS
SELECT public.materialized_phenoview.breeding_program_id,
    public.materialized_genoview.genotyping_protocol_id
   FROM public.materialized_phenoview
   JOIN public.materialized_genoview USING(stock_id)
  GROUP BY public.materialized_phenoview.breeding_program_id, public.materialized_genoview.genotyping_protocol_id
WITH DATA;
CREATE UNIQUE INDEX breeding_programsXgenotyping_protocols_idx ON public.breeding_programsXgenotyping_protocols(breeding_program_id, genotyping_protocol_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW breeding_programsXgenotyping_protocols OWNER TO web_usr;

DROP MATERIALIZED VIEW IF EXISTS public.genotyping_protocolsXlocations CASCADE;
CREATE MATERIALIZED VIEW public.genotyping_protocolsXlocations AS
SELECT public.materialized_genoview.genotyping_protocol_id,
    public.materialized_phenoview.location_id
   FROM public.materialized_genoview
   JOIN public.materialized_phenoview USING(stock_id)
  GROUP BY public.materialized_genoview.genotyping_protocol_id, public.materialized_phenoview.location_id
WITH DATA;
CREATE UNIQUE INDEX genotyping_protocolsXlocations_idx ON public.genotyping_protocolsXlocations(genotyping_protocol_id, location_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW genotyping_protocolsXlocations OWNER TO web_usr;

DROP MATERIALIZED VIEW IF EXISTS public.genotyping_protocolsXplants CASCADE;
CREATE MATERIALIZED VIEW public.genotyping_protocolsXplants AS
SELECT public.materialized_genoview.genotyping_protocol_id,
    public.stock.stock_id AS plant_id
   FROM public.materialized_genoview
   JOIN public.materialized_phenoview USING(stock_id)
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plant'))
  GROUP BY public.materialized_genoview.genotyping_protocol_id, public.stock.stock_id
  WITH DATA;
CREATE UNIQUE INDEX genotyping_protocolsXplants_idx ON public.genotyping_protocolsXplants(genotyping_protocol_id, plant_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW genotyping_protocolsXplants OWNER TO web_usr;

DROP MATERIALIZED VIEW IF EXISTS public.genotyping_protocolsXplots CASCADE;
CREATE MATERIALIZED VIEW public.genotyping_protocolsXplots AS
SELECT public.materialized_genoview.genotyping_protocol_id,
    public.stock.stock_id AS plot_id
    FROM public.materialized_genoview
    JOIN public.materialized_phenoview USING(stock_id)
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plot'))
  GROUP BY public.materialized_genoview.genotyping_protocol_id, public.stock.stock_id
WITH DATA;
CREATE UNIQUE INDEX genotyping_protocolsXplots_idx ON public.genotyping_protocolsXplots(genotyping_protocol_id, plot_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW genotyping_protocolsXplots OWNER TO web_usr;

DROP MATERIALIZED VIEW IF EXISTS public.genotyping_protocolsXtrial_designs CASCADE;
CREATE MATERIALIZED VIEW public.genotyping_protocolsXtrial_designs AS
SELECT public.materialized_genoview.genotyping_protocol_id,
    trialdesign.value AS trial_design_id
    FROM public.materialized_genoview
    JOIN public.materialized_phenoview USING(stock_id)
   JOIN public.projectprop trialdesign ON materialized_phenoview.trial_id = trialdesign.project_id AND trialdesign.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'design' )
  GROUP BY public.materialized_genoview.genotyping_protocol_id, trialdesign.value
WITH DATA;
CREATE UNIQUE INDEX genotyping_protocolsXtrial_designs_idx ON public.genotyping_protocolsXtrial_designs(genotyping_protocol_id, trial_design_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW genotyping_protocolsXtrial_designs OWNER TO web_usr;

DROP MATERIALIZED VIEW IF EXISTS public.genotyping_protocolsXtrial_types CASCADE;
CREATE MATERIALIZED VIEW public.genotyping_protocolsXtrial_types AS
SELECT public.materialized_genoview.genotyping_protocol_id,
    trialterm.cvterm_id AS trial_type_id
    FROM public.materialized_genoview
    JOIN public.materialized_phenoview USING(stock_id)
   JOIN projectprop trialprop ON materialized_phenoview.trial_id = trialprop.project_id AND trialprop.type_id IN (SELECT cvterm_id from cvterm JOIN cv USING(cv_id) WHERE cv.name = 'project_type' )
   JOIN cvterm trialterm ON trialprop.type_id = trialterm.cvterm_id
  GROUP BY public.materialized_genoview.genotyping_protocol_id, trialterm.cvterm_id
WITH DATA;
CREATE UNIQUE INDEX genotyping_protocolsXtrial_types_idx ON public.genotyping_protocolsXtrial_types(genotyping_protocol_id, trial_type_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW genotyping_protocolsXtrial_types OWNER TO web_usr;

DROP MATERIALIZED VIEW IF EXISTS public.genotyping_protocolsXtrials CASCADE;
CREATE MATERIALIZED VIEW public.genotyping_protocolsXtrials AS
SELECT public.materialized_genoview.genotyping_protocol_id,
    public.materialized_phenoview.trial_id
   FROM public.materialized_genoview
   JOIN public.materialized_phenoview USING(stock_id)
  GROUP BY public.materialized_genoview.genotyping_protocol_id, public.materialized_phenoview.trial_id
WITH DATA;
CREATE UNIQUE INDEX genotyping_protocolsXtrials_idx ON public.genotyping_protocolsXtrials(genotyping_protocol_id, trial_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW genotyping_protocolsXtrials OWNER TO web_usr;

DROP MATERIALIZED VIEW IF EXISTS public.genotyping_protocolsXyears CASCADE;
CREATE MATERIALIZED VIEW public.genotyping_protocolsXyears AS
SELECT public.materialized_genoview.genotyping_protocol_id,
    public.materialized_phenoview.year_id
   FROM public.materialized_genoview
   JOIN public.materialized_phenoview USING(stock_id)
  GROUP BY public.materialized_genoview.genotyping_protocol_id, public.materialized_phenoview.year_id
WITH DATA;
CREATE UNIQUE INDEX genotyping_protocolsXyears_idx ON public.genotyping_protocolsXyears(genotyping_protocol_id, year_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW genotyping_protocolsXyears OWNER TO web_usr;

--

EOSQL

print "You're done!\n";
}


####
1; #
####
