#!/usr/bin/env perl


=head1 NAME

AddSeedlotViews.pm

=head1 SYNOPSIS

mx-run AddSeedlotViews [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch updates the materialized views to include seedlots

=head1 AUTHOR

Bryan Ellerbrock<bje24@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package UpdateMaterializedPhenoview;

use Moose;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch updates the materialized views to include seedlots.

sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    $self->dbh->do(<<EOSQL);
--do your SQL here

-- REDEFINE materialized_phenoview, adding seedlot:

DROP MATERIALIZED VIEW IF EXISTS public.materialized_phenoview CASCADE;
CREATE MATERIALIZED VIEW public.materialized_phenoview AS
SELECT
  breeding_program.project_id AS breeding_program_id,
  nd_experiment.nd_geolocation_id AS location_id,
  projectprop.value AS year_id, trial.project_id AS trial_id,
  accession.stock_id AS accession_id,
  seedlot.stock_id AS seedlot_id,
  stock.stock_id AS stock_id,
  phenotype.phenotype_id as phenotype_id,
  phenotype.cvalue_id as trait_id
  FROM stock accession
     LEFT JOIN stock_relationship ON accession.stock_id = stock_relationship.object_id AND stock_relationship.type_id IN (SELECT cvterm_id from cvterm where cvterm.name = 'plot_of' OR cvterm.name = 'plant_of')
     LEFT JOIN stock ON stock_relationship.subject_id = stock.stock_id AND stock.type_id IN (SELECT cvterm_id from cvterm where cvterm.name = 'plot' OR cvterm.name = 'plant')
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


UPDATE matviews set mv_dependents = '{"accessionsXbreeding_programs","accessionsXlocations","accessionsXplants","accessionsXplots","accessionsXseedlots","accessionsXtrait_components","accessionsXtraits","accessionsXtrials","accessionsXtrial_designs","accessionsXtrial_types","accessionsXyears","breeding_programsXgenotyping_protocols","breeding_programsXlocations","breeding_programsXplants","breeding_programsXplots","breeding_programsXseedlots","breeding_programsXtrait_components","breeding_programsXtraits","breeding_programsXtrials","breeding_programsXtrial_designs","breeding_programsXtrial_types","breeding_programsXyears","genotyping_protocolsXlocations","genotyping_protocolsXplants","genotyping_protocolsXplots","genotyping_protocolsXseedlots","genotyping_protocolsXtrait_components","genotyping_protocolsXtraits","genotyping_protocolsXtrials","genotyping_protocolsXtrial_designs","genotyping_protocolsXtrial_types","genotyping_protocolsXyears","locationsXplants","locationsXplots","locationsXseedlots","locationsXtrait_components","locationsXtraits","locationsXtrials","locationsXtrial_designs","locationsXtrial_types","locationsXyears","plantsXplots","plantsXseedlots","plantsXtrait_components","plantsXtraits","plantsXtrials","plantsXtrial_designs","plantsXtrial_types","plantsXyears","plotsXseedlots","plotsXtrait_components","plotsXtraits","plotsXtrials","plotsXtrial_designs","plotsXtrial_types","plotsXyears","seedlotsXtrait_components","seedlotsXtraits","seedlotsXtrial_designs","seedlotsXtrial_types","seedlotsXtrials","seedlotsXyears","trait_componentsXtraits","trait_componentsXtrial_designs","trait_componentsXtrial_types","trait_componentsXtrials","trait_componentsXyears","traitsXtrials","traitsXtrial_designs","traitsXtrial_types","traitsXyears","trial_designsXtrials","trial_typesXtrials","trialsXyears","trial_designsXtrial_types","trial_designsXyears","trial_typesXyears"}' WHERE mv_name = 'materialized_phenoview';

--add seedlots view, and all seedlot binary views

DROP MATERIALIZED VIEW IF EXISTS public.seedlots CASCADE;
CREATE MATERIALIZED VIEW public.seedlots AS
SELECT 
WITH DATA;
CREATE UNIQUE INDEX seedlots_idx ON public.seedlots(seedlot_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW seedlots OWNER TO web_usr;

CREATE MATERIALIZED VIEW public.accessionsXseedlots AS
SELECT
WITH DATA;
CREATE UNIQUE INDEX accessionsXseedlots_idx ON public.accessionsXseedlots(accession_id, trait_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW accessionsXseedlots OWNER TO web_usr;

CREATE MATERIALIZED VIEW public.breeding_programsXseedlots AS
SELECT
WITH DATA;
CREATE UNIQUE INDEX breeding_programsXseedlots_idx ON public.breeding_programsXseedlots(breeding_program_id, trait_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW breeding_programsXseedlots OWNER TO web_usr;

CREATE MATERIALIZED VIEW public.genotyping_protocolsXseedlots AS
SELECT 
WITH DATA;
CREATE UNIQUE INDEX genotyping_protocolsXseedlots_idx ON public.genotyping_protocolsXseedlots(genotyping_protocol_id, trait_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW genotyping_protocolsXseedlots OWNER TO web_usr;

CREATE MATERIALIZED VIEW public.locationsXseedlots AS
SELECT 
WITH DATA;
CREATE UNIQUE INDEX locationsXseedlots_idx ON public.locationsXseedlots(location_id, trait_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW locationsXseedlots OWNER TO web_usr;

CREATE MATERIALIZED VIEW public.plantsXseedlots AS
SELECT
WITH DATA;
CREATE UNIQUE INDEX plantsXseedlots_idx ON public.plantsXseedlots(plant_id, trait_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW plantsXseedlots OWNER TO web_usr;

CREATE MATERIALIZED VIEW public.plotsXseedlots AS
SELECT
WITH DATA;
CREATE UNIQUE INDEX plotsXseedlots_idx ON public.plotsXseedlots(plot_id, trait_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW plotsXseedlots OWNER TO web_usr;

CREATE MATERIALIZED VIEW public.seedlotsXtrait_components AS
SELECT
WITH DATA;
CREATE UNIQUE INDEX seedlotsXtrait_components_idx ON public.seedlotsXtrait_components(trait_id, trial_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW seedlotsXtrait_components OWNER TO web_usr;

CREATE MATERIALIZED VIEW public.seedlotsXtraits AS
SELECT
WITH DATA;
CREATE UNIQUE INDEX seedlotsXtraits_idx ON public.seedlotsXtraits(trait_id, trial_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW seedlotsXtraits OWNER TO web_usr;

CREATE MATERIALIZED VIEW public.seedlotsXtrials AS
SELECT
WITH DATA;
CREATE UNIQUE INDEX seedlotsXtrials_idx ON public.seedlotsXtrials(trait_id, trial_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW seedlotsXtrials OWNER TO web_usr;

CREATE MATERIALIZED VIEW public.seedlotsXtrial_designs AS
SELECT
WITH DATA;
CREATE UNIQUE INDEX seedlotsXtrial_designs_idx ON public.seedlotsXtrial_designs(trait_id, trial_design_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW seedlotsXtrial_designs OWNER TO web_usr;

CREATE MATERIALIZED VIEW public.seedlotsXtrial_types AS
SELECT
WITH DATA;
CREATE UNIQUE INDEX seedlotsXtrial_types_idx ON public.seedlotsXtrial_types(trait_id, trial_type_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW seedlotsXtrial_types OWNER TO web_usr;

CREATE MATERIALIZED VIEW public.seedlotsXyears AS
SELECT
WITH DATA;
CREATE UNIQUE INDEX seedlotsXyears_idx ON public.seedlotsXyears(trait_id, year_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW seedlotsXyears OWNER TO web_usr;



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
REFRESH MATERIALIZED VIEW public.locationsXplants;
REFRESH MATERIALIZED VIEW public.locationsXplots;
REFRESH MATERIALIZED VIEW public.locationsXseedlots;
REFRESH MATERIALIZED VIEW public.locationsXtrait_components;
REFRESH MATERIALIZED VIEW public.locationsXtraits;
REFRESH MATERIALIZED VIEW public.locationsXtrial_designs;
REFRESH MATERIALIZED VIEW public.locationsXtrial_types;
REFRESH MATERIALIZED VIEW public.locationsXtrials;
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
REFRESH MATERIALIZED VIEW public.seedlotsXtrait_components;s
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
REFRESH MATERIALIZED VIEW public.locationsXplants;
REFRESH MATERIALIZED VIEW public.locationsXplots;
REFRESH MATERIALIZED VIEW public.locationsXseedlots;
REFRESH MATERIALIZED VIEW public.locationsXtrait_components;
REFRESH MATERIALIZED VIEW public.locationsXtraits;
REFRESH MATERIALIZED VIEW public.locationsXtrial_designs;
REFRESH MATERIALIZED VIEW public.locationsXtrial_types;
REFRESH MATERIALIZED VIEW public.locationsXtrials;
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
REFRESH MATERIALIZED VIEW public.seedlotsXtrait_components;s
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
REFRESH MATERIALIZED VIEW public.trial_designsXtrial_types;
REFRESH MATERIALIZED VIEW public.trial_designsXtrials;
REFRESH MATERIALIZED VIEW public.trial_designsXyears;
REFRESH MATERIALIZED VIEW public.trial_typesXtrials;
REFRESH MATERIALIZED VIEW public.trial_typesXyears;
REFRESH MATERIALIZED VIEW public.trialsXyears;
UPDATE public.matviews SET currently_refreshing=FALSE, last_refresh=CURRENT_TIMESTAMP;'
    LANGUAGE SQL;

ALTER FUNCTION public.refresh_materialized_views_concurrently() OWNER TO web_usr;
--

EOSQL

print "You're done!\n";
}


####
1; #
####
