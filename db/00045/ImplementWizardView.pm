#!/usr/bin/env perl


=head1 NAME

ImplementWizardView.pm

=head1 SYNOPSIS

mx-run ImplementWizardView [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch creates a materialized view, as well as indexes and recursive views to simplify and speed up the sort of filtering queries necessary for the wizard.

=head1 AUTHOR

Bryan Ellerbrock<bje24@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package ImplementWizardView;

use Moose;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
Description of this patch goes here


sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    $self->dbh->do(<<EOSQL);
--do your SQL here

CREATE MATERIALIZED VIEW public.materialized_fullview AS
 SELECT plot.uniquename AS plot_name,
    stock_relationship.subject_id AS plot_id,
    accession.uniquename AS accession_name,
    stock_relationship.object_id AS accession_id,
    nd_experiment.nd_geolocation_id AS location_id,
    nd_geolocation.description AS location_name,
    projectprop.value AS year_id,
    projectprop.value AS year_name,
    project_relationship.subject_project_id AS trial_id,
    trial.name AS trial_name,
    project_relationship.object_project_id AS breeding_program_id,
    breeding_program.name AS breeding_program_name,
    cvterm.cvterm_id AS trait_id,
    (((cvterm.name::text || '|'::text) || db.name::text) || ':'::text) || dbxref.accession::text AS trait_name,
    phenotype.phenotype_id,
    phenotype.value AS phenotype_value,
    nd_experiment_protocol.nd_protocol_id AS genotyping_protocol_id,
    nd_protocol.name AS genotyping_protocol_name
   FROM stock plot
     LEFT JOIN stock_relationship ON plot.stock_id = stock_relationship.subject_id
     LEFT JOIN stock accession ON stock_relationship.object_id = accession.stock_id
     LEFT JOIN nd_experiment_stock nd_experiment_plot ON stock_relationship.subject_id = nd_experiment_plot.stock_id
     LEFT JOIN nd_experiment ON nd_experiment_plot.nd_experiment_id = nd_experiment.nd_experiment_id
     LEFT JOIN nd_geolocation ON nd_experiment.nd_geolocation_id = nd_geolocation.nd_geolocation_id
     LEFT JOIN nd_experiment_stock nd_experiment_accession ON stock_relationship.object_id = nd_experiment_accession.stock_id
     LEFT JOIN nd_experiment_protocol ON nd_experiment_accession.nd_experiment_id = nd_experiment_protocol.nd_experiment_id
     LEFT JOIN nd_protocol ON nd_experiment_protocol.nd_protocol_id = nd_protocol.nd_protocol_id
     LEFT JOIN nd_experiment_project ON nd_experiment.nd_experiment_id = nd_experiment_project.nd_experiment_id
     LEFT JOIN project trial ON nd_experiment_project.project_id = trial.project_id
     LEFT JOIN project_relationship ON trial.project_id = project_relationship.subject_project_id
     LEFT JOIN project breeding_program ON project_relationship.object_project_id = breeding_program.project_id
     LEFT JOIN projectprop ON project_relationship.subject_project_id = projectprop.project_id
     LEFT JOIN nd_experiment_phenotype ON nd_experiment.nd_experiment_id = nd_experiment_phenotype.nd_experiment_id
     LEFT JOIN phenotype ON nd_experiment_phenotype.phenotype_id = phenotype.phenotype_id
     LEFT JOIN cvterm ON phenotype.cvalue_id = cvterm.cvterm_id
     LEFT JOIN dbxref ON cvterm.dbxref_id = dbxref.dbxref_id
     LEFT JOIN db ON dbxref.db_id = db.db_id
  WHERE plot.type_id = 76393 AND projectprop.type_id = 76395 AND db.db_id = 186
  GROUP BY stock_relationship.subject_id, cvterm.cvterm_id, plot.uniquename, accession.uniquename, stock_relationship.object_id, (((cvterm.name::text || '|'::text) || db.name::text) || ':'::text) || dbxref.accession::text, trial.name, project_relationship.subject_project_id, breeding_program.name, project_relationship.object_project_id, projectprop.value, nd_experiment.nd_geolocation_id, nd_geolocation.description, phenotype.phenotype_id, phenotype.value, nd_experiment_protocol.nd_protocol_id, nd_protocol.name;

CREATE UNIQUE INDEX materializedfullview_idx ON public.materialized_fullview(trial_id, plot_id, phenotype_id, genotyping_protocol_id) WITH (fillfactor=100);
CREATE INDEX accession_id_idx ON public.materialized_fullview(accession_id) WITH (fillfactor=100);
CREATE INDEX breeding_program_id_idx ON public.materialized_fullview(breeding_program_id) WITH (fillfactor=100);
CREATE INDEX genotyping_protocol_id_idx ON public.materialized_fullview(genotyping_protocol_id) WITH (fillfactor=100);
CREATE INDEX location_id_idx ON public.materialized_fullview(location_id) WITH (fillfactor=100);
CREATE INDEX phenotype_id_idx ON public.materialized_fullview(phenotype_id) WITH (fillfactor=100);
CREATE INDEX plot_id_idx ON public.materialized_fullview(plot_id) WITH (fillfactor=100);
CREATE INDEX trait_id_idx ON public.materialized_fullview(trait_id) WITH (fillfactor=100);
CREATE INDEX trial_id_idx ON public.materialized_fullview(trial_id) WITH (fillfactor=100);
CREATE INDEX year_id_idx ON public.materialized_fullview(year_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.materialized_fullview OWNER to web_usr;

CREATE TABLE public.matviews (
  mv_name NAME NOT NULL PRIMARY KEY
  , mv_dependents NAME ARRAY  
  , currently_refreshing BOOLEAN
  , last_refresh TIMESTAMP WITH TIME ZONE
);
ALTER TABLE public.matviews OWNER to web_usr;
INSERT INTO matviews (mv_name, mv_dependents, currently_refreshing, last_refresh) VALUES ('materialized_fullview', '{"accessions", "accessionsXbreeding_programs","accessionsXgenotyping_protocols","accessionsXlocations","accessionsXplots","accessionsXtraits","accessionsXtrials","accessionsXyears","breeding_programs","breeding_programsXgenotyping_protocols","breeding_programsXlocations","breeding_programsXplots","breeding_programsXtraits","breeding_programsXtrials","breeding_programsXyears","genotyping_protocols","genotyping_protocolsXlocations","genotyping_protocolsXplots","genotyping_protocolsXtraits","genotyping_protocolsXtrials","genotyping_protocolsXyears","locations","locationsXplots","locationsXtraits","locationsXtrials","locationsXyears","plots","plotsXtraits","plotsXtrials","plotsXyears","traits","traitsXtrials","traitsXyears","trials","trialsXyears","years"}', FALSE, CURRENT_TIMESTAMP);

CREATE MATERIALIZED VIEW public.accessions AS
SELECT public.materialized_fullview.accession_id,
    public.materialized_fullview.accession_name
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.accession_id, public.materialized_fullview.accession_name;
CREATE UNIQUE INDEX accessions_idx ON public.accessions(accession_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.accessions OWNER to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('accessions', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.accessionsXbreeding_programs AS
SELECT public.materialized_fullview.accession_id,
    public.materialized_fullview.breeding_program_id
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.accession_id, public.materialized_fullview.breeding_program_id;
CREATE UNIQUE INDEX accessionsXbreeding_programs_idx ON public.accessionsXbreeding_programs(accession_id, breeding_program_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.accessionsXbreeding_programs OWNER to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('accessionsXbreeding_programs', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.accessionsXgenotyping_protocols AS
SELECT public.materialized_fullview.accession_id,
    public.materialized_fullview.genotyping_protocol_id
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.accession_id, public.materialized_fullview.genotyping_protocol_id;
CREATE UNIQUE INDEX accessionsXgenotyping_protocols_idx ON public.accessionsXgenotyping_protocols(accession_id, genotyping_protocol_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.accessionsXgenotyping_protocols OWNER to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('accessionsXgenotyping_protocols', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.accessionsXlocations AS
SELECT public.materialized_fullview.accession_id,
    public.materialized_fullview.location_id
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.accession_id, public.materialized_fullview.location_id;
CREATE UNIQUE INDEX accessionsXlocations_idx ON public.accessionsXlocations(accession_id, location_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.accessionsXlocations OWNER to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('accessionsXlocations', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.accessionsXplots AS
SELECT public.materialized_fullview.accession_id,
    public.materialized_fullview.plot_id
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.accession_id, public.materialized_fullview.plot_id;
CREATE UNIQUE INDEX accessionsXplots_idx ON public.accessionsXplots(accession_id, plot_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.accessionsXplots OWNER to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('accessionsXplots', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.accessionsXtraits AS
SELECT public.materialized_fullview.accession_id,
    public.materialized_fullview.trait_id
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.accession_id, public.materialized_fullview.trait_id;
CREATE UNIQUE INDEX accessionsXtraits_idx ON public.accessionsXtraits(accession_id, trait_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.accessionsXtraits OWNER to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('accessionsXtraits', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.accessionsXtrials AS
SELECT public.materialized_fullview.accession_id,
    public.materialized_fullview.trial_id
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.accession_id, public.materialized_fullview.trial_id;
CREATE UNIQUE INDEX accessionsXtrials_idx ON public.accessionsXtrials(accession_id, trial_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.accessionsXtrials OWNER to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('accessionsXtrials', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.accessionsXyears AS
SELECT public.materialized_fullview.accession_id,
    public.materialized_fullview.year_id
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.accession_id, public.materialized_fullview.year_id;
CREATE UNIQUE INDEX accessionsXyears_idx ON public.accessionsXyears(accession_id, year_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.accessionsXyears OWNER to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('accessionsXyears', FALSE, CURRENT_TIMESTAMP);

CREATE MATERIALIZED VIEW public.breeding_programs AS
SELECT public.materialized_fullview.breeding_program_id,
    public.materialized_fullview.breeding_program_name
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.breeding_program_id, public.materialized_fullview.breeding_program_name;
CREATE UNIQUE INDEX breeding_programs_idx ON public.breeding_programs(breeding_program_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.breeding_programs OWNER to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('breeding_programs', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.breeding_programsXgenotyping_protocols AS
SELECT public.materialized_fullview.breeding_program_id,
    public.materialized_fullview.genotyping_protocol_id
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.breeding_program_id, public.materialized_fullview.genotyping_protocol_id;
CREATE UNIQUE INDEX breeding_programsXgenotyping_protocols_idx ON public.breeding_programsXgenotyping_protocols(breeding_program_id, genotyping_protocol_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.breeding_programsXgenotyping_protocols OWNER to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('breeding_programsXgenotyping_protocols', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.breeding_programsXlocations AS
SELECT public.materialized_fullview.breeding_program_id,
    public.materialized_fullview.location_id
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.breeding_program_id, public.materialized_fullview.location_id;
CREATE UNIQUE INDEX breeding_programsXlocations_idx ON public.breeding_programsXlocations(breeding_program_id, location_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.breeding_programsXlocations OWNER to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('breeding_programsXlocations', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.breeding_programsXplots AS
SELECT public.materialized_fullview.breeding_program_id,
    public.materialized_fullview.plot_id
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.breeding_program_id, public.materialized_fullview.plot_id;
CREATE UNIQUE INDEX breeding_programsXplots_idx ON public.breeding_programsXplots(breeding_program_id, plot_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.breeding_programsXplots OWNER to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('breeding_programsXplots', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.breeding_programsXtraits AS
SELECT public.materialized_fullview.breeding_program_id,
    public.materialized_fullview.trait_id
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.breeding_program_id, public.materialized_fullview.trait_id;
CREATE UNIQUE INDEX breeding_programsXtraits_idx ON public.breeding_programsXtraits(breeding_program_id, trait_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.breeding_programsXtraits OWNER to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('breeding_programsXtraits', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.breeding_programsXtrials AS
SELECT public.materialized_fullview.breeding_program_id,
    public.materialized_fullview.trial_id
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.breeding_program_id, public.materialized_fullview.trial_id;
CREATE UNIQUE INDEX breeding_programsXtrials_idx ON public.breeding_programsXtrials(breeding_program_id, trial_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.breeding_programsXtrials OWNER to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('breeding_programsXtrials', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.breeding_programsXyears AS
SELECT public.materialized_fullview.breeding_program_id,
    public.materialized_fullview.year_id
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.breeding_program_id, public.materialized_fullview.year_id;
CREATE UNIQUE INDEX breeding_programsXyears_idx ON public.breeding_programsXyears(breeding_program_id, year_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.breeding_programsXyears OWNER to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('breeding_programsXyears', FALSE, CURRENT_TIMESTAMP);

CREATE MATERIALIZED VIEW public.genotyping_protocols AS
SELECT public.materialized_fullview.genotyping_protocol_id,
    public.materialized_fullview.genotyping_protocol_name
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.genotyping_protocol_id, public.materialized_fullview.genotyping_protocol_name;
CREATE UNIQUE INDEX genotyping_protocols_idx ON public.genotyping_protocols(genotyping_protocol_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.genotyping_protocols OWNER to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('genotyping_protocols', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.genotyping_protocolsXlocations AS
SELECT public.materialized_fullview.genotyping_protocol_id,
    public.materialized_fullview.location_id
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.genotyping_protocol_id, public.materialized_fullview.location_id;
CREATE UNIQUE INDEX genotyping_protocolsXlocations_idx ON public.genotyping_protocolsXlocations(genotyping_protocol_id, location_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.genotyping_protocolsXlocations OWNER to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('genotyping_protocolsXlocations', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.genotyping_protocolsXplots AS
SELECT public.materialized_fullview.genotyping_protocol_id,
    public.materialized_fullview.plot_id
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.genotyping_protocol_id, public.materialized_fullview.plot_id;
CREATE UNIQUE INDEX genotyping_protocolsXplots_idx ON public.genotyping_protocolsXplots(genotyping_protocol_id, plot_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.genotyping_protocolsXplots OWNER to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('genotyping_protocolsXplots', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.genotyping_protocolsXtraits AS
SELECT public.materialized_fullview.genotyping_protocol_id,
    public.materialized_fullview.trait_id
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.genotyping_protocol_id, public.materialized_fullview.trait_id;
CREATE UNIQUE INDEX genotyping_protocolsXtraits_idx ON public.genotyping_protocolsXtraits(genotyping_protocol_id, trait_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.genotyping_protocolsXtraits OWNER to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('genotyping_protocolsXtraits', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.genotyping_protocolsXtrials AS
SELECT public.materialized_fullview.genotyping_protocol_id,
    public.materialized_fullview.trial_id
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.genotyping_protocol_id, public.materialized_fullview.trial_id;
CREATE UNIQUE INDEX genotyping_protocolsXtrials_idx ON public.genotyping_protocolsXtrials(genotyping_protocol_id, trial_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.genotyping_protocolsXtrials OWNER to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('genotyping_protocolsXtrials', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.genotyping_protocolsXyears AS
SELECT public.materialized_fullview.genotyping_protocol_id,
    public.materialized_fullview.year_id
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.genotyping_protocol_id, public.materialized_fullview.year_id;
CREATE UNIQUE INDEX genotyping_protocolsXyears_idx ON public.genotyping_protocolsXyears(genotyping_protocol_id, year_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.genotyping_protocolsXyears OWNER to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('genotyping_protocolsXyears', FALSE, CURRENT_TIMESTAMP);

CREATE MATERIALIZED VIEW public.locations AS
SELECT public.materialized_fullview.location_id,
    public.materialized_fullview.location_name
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.location_id, public.materialized_fullview.location_name;
CREATE UNIQUE INDEX locations_idx ON public.locations(location_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.locations OWNER to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('locations', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.locationsXplots AS
SELECT public.materialized_fullview.location_id,
    public.materialized_fullview.plot_id
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.location_id, public.materialized_fullview.plot_id;
CREATE UNIQUE INDEX locationsXplots_idx ON public.locationsXplots(location_id, plot_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.locationsXplots OWNER to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('locationsXplots', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.locationsXtraits AS
SELECT public.materialized_fullview.location_id,
    public.materialized_fullview.trait_id
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.location_id, public.materialized_fullview.trait_id;
CREATE UNIQUE INDEX locationsXtraits_idx ON public.locationsXtraits(location_id, trait_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.locationsXtraits OWNER to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('locationsXtraits', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.locationsXtrials AS
SELECT public.materialized_fullview.location_id,
    public.materialized_fullview.trial_id
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.location_id, public.materialized_fullview.trial_id;
CREATE UNIQUE INDEX locationsXtrials_idx ON public.locationsXtrials(location_id, trial_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.locationsXtrials OWNER to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('locationsXtrials', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.locationsXyears AS
SELECT public.materialized_fullview.location_id,
    public.materialized_fullview.year_id
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.location_id, public.materialized_fullview.year_id;
CREATE UNIQUE INDEX locationsXyears_idx ON public.locationsXyears(location_id, year_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.locationsXyears OWNER to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('locationsXyears', FALSE, CURRENT_TIMESTAMP);

CREATE MATERIALIZED VIEW public.plots AS
SELECT public.materialized_fullview.plot_id,
    public.materialized_fullview.plot_name
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.plot_id, public.materialized_fullview.plot_name;
CREATE UNIQUE INDEX plots_idx ON public.plots(plot_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.plots OWNER to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('plots', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.plotsXtraits AS
SELECT public.materialized_fullview.plot_id,
    public.materialized_fullview.trait_id
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.plot_id, public.materialized_fullview.trait_id;
CREATE UNIQUE INDEX plotsXtraits_idx ON public.plotsXtraits(plot_id, trait_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.plotsXtraits OWNER to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('plotsXtraits', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.plotsXtrials AS
SELECT public.materialized_fullview.plot_id,
    public.materialized_fullview.trial_id
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.plot_id, public.materialized_fullview.trial_id;
CREATE UNIQUE INDEX plotsXtrials_idx ON public.plotsXtrials(plot_id, trial_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.plotsXtrials OWNER to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('plotsXtrials', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.plotsXyears AS
SELECT public.materialized_fullview.plot_id,
    public.materialized_fullview.year_id
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.plot_id, public.materialized_fullview.year_id;
CREATE UNIQUE INDEX plotsXyears_idx ON public.plotsXyears(plot_id, year_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.plotsXyears OWNER to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('plotsXyears', FALSE, CURRENT_TIMESTAMP);

CREATE MATERIALIZED VIEW public.traits AS
SELECT public.materialized_fullview.trait_id,
    public.materialized_fullview.trait_name
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.trait_id, public.materialized_fullview.trait_name;
CREATE UNIQUE INDEX traits_idx ON public.traits(trait_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.traits OWNER to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('traits', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.traitsXtrials AS
SELECT public.materialized_fullview.trait_id,
    public.materialized_fullview.trial_id
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.trait_id, public.materialized_fullview.trial_id;
CREATE UNIQUE INDEX traitsXtrials_idx ON public.traitsXtrials(trait_id, trial_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.traitsXtrials OWNER to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('traitsXtrials', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.traitsXyears AS
SELECT public.materialized_fullview.trait_id,
    public.materialized_fullview.year_id
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.trait_id, public.materialized_fullview.year_id;
CREATE UNIQUE INDEX traitsXyears_idx ON public.traitsXyears(trait_id, year_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.traitsXyears OWNER to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('traitsXyears', FALSE, CURRENT_TIMESTAMP);

CREATE MATERIALIZED VIEW public.trials AS
SELECT public.materialized_fullview.trial_id,
    public.materialized_fullview.trial_name
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.trial_id, public.materialized_fullview.trial_name;
CREATE UNIQUE INDEX trials_idx ON public.trials(trial_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.trials OWNER to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('trials', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.trialsXyears AS
SELECT public.materialized_fullview.trial_id,
    public.materialized_fullview.year_id
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.trial_id, public.materialized_fullview.year_id;
CREATE UNIQUE INDEX trialsXyears_idx ON public.trialsXyears(trial_id, year_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.trialsXyears OWNER to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('trialsXyears', FALSE, CURRENT_TIMESTAMP);

CREATE MATERIALIZED VIEW public.years AS
SELECT public.materialized_fullview.year_id,
    public.materialized_fullview.year_name
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.year_id, public.materialized_fullview.year_name;
CREATE UNIQUE INDEX years_idx ON public.years(year_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.years OWNER to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('years', FALSE, CURRENT_TIMESTAMP);

CREATE OR REPLACE FUNCTION refresh_matview() RETURNS TRIGGER AS $$
DECLARE
    matview TEXT;
BEGIN
FOREACH matview IN ARRAY NEW.mv_dependents::text[] LOOP
UPDATE public.matviews
SET currently_refreshing=TRUE
WHERE mv_name=matview;

REFRESH MATERIALIZED VIEW CONCURRENTLY matview;
    
UPDATE public.matviews
SET currently_refreshing=TRUE, last_refresh=CURRENT_TIMESTAMP
WHERE mv_name=matview; 
END LOOP;
RETURN NEW;
END;
$$ language plpgsql;

CREATE TRIGGER refresh_dependent_matviews AFTER UPDATE ON matviews
    FOR EACH ROW WHEN(NEW.last_refresh IS DISTINCT FROM OLD.last_refresh) EXECUTE PROCEDURE refresh_matview();

--
SELECT * from public.stock;

EOSQL

print "You're done!\n";
}


####
1; #
####
