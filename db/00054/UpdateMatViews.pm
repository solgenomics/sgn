#!/usr/bin/env perl


=head1 NAME

UpdateMatViews.pm

=head1 SYNOPSIS

mx-run UpdateMatViews [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch updates the index of materialized_fullview and the queries used to create the materialized view for each individual category. It adds views for new categories: trial type and trial design

=head1 AUTHOR

Bryan Ellerbrock<bje24@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package UpdateMatViews;

use Moose;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch updates the index of materialized_fullview and the queries used to create the materialized view for each individual category. It adds views for new categories: trial type and trial design


sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    $self->dbh->do(<<EOSQL);
--do your SQL here

DROP MATERIALIZED VIEW public.materialized_fullview CASCADE;
CREATE MATERIALIZED VIEW public.materialized_phenoview AS
 SELECT plot.uniquename AS plot_name,
    stock_relationship.subject_id AS plot_id,
    accession.uniquename AS accession_name,
    stock_relationship.object_id AS accession_id,
    nd_experiment.nd_geolocation_id AS location_id,
    nd_geolocation.description AS location_name,
    projectprop.value AS year_id,
    projectprop.value AS year_name,
    trial.project_id AS trial_id,
    trial.name AS trial_name,
    trialterm.cvterm_id AS trial_type_id,
    trialterm.name AS trial_type_name,
    trialdesign.value AS trial_design_id,
    trialdesign.value AS trial_design_value,
    project_relationship.object_project_id AS breeding_program_id,
    breeding_program.name AS breeding_program_name,
    cvterm.cvterm_id AS trait_id,
    (((cvterm.name::text || '|'::text) || db.name::text) || ':'::text) || dbxref.accession::text AS trait_name,
    phenotype.phenotype_id,
    phenotype.value AS phenotype_value
   FROM stock accession
     LEFT JOIN stock_relationship ON accession.stock_id = stock_relationship.object_id
     LEFT JOIN stock plot ON stock_relationship.subject_id = plot.stock_id
     LEFT JOIN nd_experiment_stock nd_experiment_plot ON stock_relationship.subject_id = nd_experiment_plot.stock_id
     LEFT JOIN nd_experiment_stock nd_experiment_accession ON accession.stock_id = nd_experiment_accession.stock_id
     LEFT JOIN nd_experiment ON nd_experiment_plot.nd_experiment_id = nd_experiment.nd_experiment_id
     LEFT JOIN nd_geolocation ON nd_experiment.nd_geolocation_id = nd_geolocation.nd_geolocation_id
     LEFT JOIN nd_experiment_project ON nd_experiment_plot.nd_experiment_id = nd_experiment_project.nd_experiment_id
     LEFT JOIN project trial ON nd_experiment_project.project_id = trial.project_id
     LEFT JOIN project_relationship ON trial.project_id = project_relationship.subject_project_id
     LEFT JOIN project breeding_program ON project_relationship.object_project_id = breeding_program.project_id
     LEFT JOIN projectprop ON trial.project_id = projectprop.project_id AND projectprop.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'project year' )
     LEFT JOIN projectprop trialdesign ON trial.project_id = trialdesign.project_id AND trialdesign.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'design' )
     LEFT JOIN projectprop trialprop ON trial.project_id = trialprop.project_id AND trialprop.type_id IN (SELECT cvterm_id from cvterm JOIN cv USING(cv_id) WHERE cv.name = 'project_type' )
     LEFT JOIN cvterm trialterm ON trialprop.type_id = trialterm.cvterm_id
     LEFT JOIN nd_experiment_phenotype ON nd_experiment_plot.nd_experiment_id = nd_experiment_phenotype.nd_experiment_id
     LEFT JOIN phenotype ON nd_experiment_phenotype.phenotype_id = phenotype.phenotype_id
     LEFT JOIN cvterm ON phenotype.cvalue_id = cvterm.cvterm_id
     LEFT JOIN dbxref ON cvterm.dbxref_id = dbxref.dbxref_id
     LEFT JOIN db ON dbxref.db_id = db.db_id
  WHERE accession.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'accession')
  GROUP BY stock_relationship.subject_id, cvterm.cvterm_id, plot.uniquename, accession.uniquename, stock_relationship.object_id, (((cvterm.name::text || '|'::text) || db.name::text) || ':'::text) || dbxref.accession::text, trial.name, trial.project_id, breeding_program.name, project_relationship.object_project_id, projectprop.value, trialdesign.value, trialterm.cvterm_id, trialterm.name, nd_experiment.nd_geolocation_id, nd_geolocation.description, phenotype.phenotype_id, phenotype.value;

CREATE UNIQUE INDEX unq_pheno_idx ON public.materialized_phenoview(accession_id,plot_id,phenotype_id) WITH (fillfactor=100);
CREATE INDEX accession_id_pheno_idx ON public.materialized_phenoview(accession_id) WITH (fillfactor=100);
CREATE INDEX breeding_program_id_idx ON public.materialized_phenoview(breeding_program_id) WITH (fillfactor=100);
CREATE INDEX location_id_idx ON public.materialized_phenoview(location_id) WITH (fillfactor=100);
CREATE INDEX plot_id_idx ON public.materialized_phenoview(plot_id) WITH (fillfactor=100);
CREATE INDEX trait_id_idx ON public.materialized_phenoview(trait_id) WITH (fillfactor=100);
CREATE INDEX trial_id_idx ON public.materialized_phenoview(trial_id) WITH (fillfactor=100);
CREATE INDEX trial_type_id_idx ON public.materialized_phenoview(trial_type_id) WITH (fillfactor=100);
CREATE INDEX trial_design_id_idx ON public.materialized_phenoview(trial_design_id) WITH (fillfactor=100);
CREATE INDEX year_id_idx ON public.materialized_phenoview(year_id) WITH (fillfactor=100);
GRANT SELECT ON materialized_phenoview to web_usr;

CREATE MATERIALIZED VIEW public.materialized_genoview AS
 SELECT stock.uniquename AS accession_name,
    stock.stock_id AS accession_id,
    nd_experiment_protocol.nd_protocol_id AS genotyping_protocol_id,
    nd_protocol.name AS genotyping_protocol_name,
    genotype.genotype_id AS genotype_id,
    genotype.uniquename AS genotype_name
   FROM stock
     LEFT JOIN nd_experiment_stock ON stock.stock_id = nd_experiment_stock.stock_id
     LEFT JOIN nd_experiment_protocol ON nd_experiment_stock.nd_experiment_id = nd_experiment_protocol.nd_experiment_id
     LEFT JOIN nd_protocol ON nd_experiment_protocol.nd_protocol_id = nd_protocol.nd_protocol_id
     LEFT JOIN nd_experiment_genotype ON nd_experiment_stock.nd_experiment_id = nd_experiment_genotype.nd_experiment_id
     LEFT JOIN genotype ON genotype.genotype_id = nd_experiment_genotype.genotype_id
  WHERE stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'accession')
  GROUP BY stock.uniquename, stock.stock_id, nd_experiment_protocol.nd_protocol_id, nd_protocol.name, genotype.genotype_id, genotype.uniquename;

CREATE UNIQUE INDEX unq_geno_idx ON public.materialized_genoview(accession_id,genotype_id) WITH (fillfactor=100);
CREATE INDEX accession_id_geno_idx ON public.materialized_genoview(accession_id) WITH (fillfactor=100);
CREATE INDEX genotyping_protocol_id_idx ON public.materialized_genoview(genotyping_protocol_id) WITH (fillfactor=100);
CREATE INDEX genotype_id_idx ON public.materialized_genoview(genotype_id) WITH (fillfactor=100);
GRANT SELECT ON materialized_genoview to web_usr;

DROP TABLE public.matviews;
CREATE TABLE public.matviews (
    mv_id SERIAL PRIMARY KEY
  , mv_name NAME NOT NULL
  , mv_dependents NAME ARRAY
  , currently_refreshing BOOLEAN
  , last_refresh TIMESTAMP WITH TIME ZONE
);
GRANT SELECT, UPDATE ON TABLE public.matviews to web_usr;

INSERT INTO matviews (mv_name, mv_dependents, currently_refreshing, last_refresh) VALUES ('materialized_phenoview', '{"accessionsXbreeding_programs","accessionsXlocations","accessionsXplots","accessionsXtraits","accessionsXtrials","accessionsXtrial_designs","accessionsXtrial_types","accessionsXyears","breeding_programsXgenotyping_protocols","breeding_programsXlocations","breeding_programsXplots","breeding_programsXtraits","breeding_programsXtrials","breeding_programsXtrial_designs","breeding_programsXtrial_types","breeding_programsXyears","genotyping_protocolsXlocations","genotyping_protocolsXplots","genotyping_protocolsXtraits","genotyping_protocolsXtrials","genotyping_protocolsXtrial_designs","genotyping_protocolsXtrial_types","genotyping_protocolsXyears","locationsXplots","locationsXtraits","locationsXtrials","locationsXtrial_designs","locationsXtrial_types","locationsXyears","plotsXtraits","plotsXtrials","plotsXtrial_designs","plotsXtrial_types","plotsXyears","traitsXtrials","traitsXtrial_designs","traitsXtrial_types","traitsXyears","trialsXtrial_designs","trialsXtrial_types","trialsXyears","trial_designsXtrial_types","trial_designsXyears","trial_typesXyears"}', FALSE, CURRENT_TIMESTAMP);
INSERT INTO matviews (mv_name, mv_dependents, currently_refreshing, last_refresh) VALUES ('materialized_genoview', '{"accessionsXgenotyping_protocols","breeding_programsXgenotyping_protocols","genotyping_protocolsXlocations","genotyping_protocolsXplots","genotyping_protocolsXtraits","genotyping_protocolsXtrials","genotyping_protocolsXtrial_designs","genotyping_protocolsXtrial_types","genotyping_protocolsXyears"}', FALSE, CURRENT_TIMESTAMP);

CREATE MATERIALIZED VIEW public.accessions AS
  SELECT stock.stock_id AS accession_id,
  stock.uniquename AS accession_name
  FROM stock
  WHERE stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'accession')
  GROUP BY stock.stock_id, stock.uniquename;
CREATE UNIQUE INDEX accessions_idx ON public.accessions(accession_id) WITH (fillfactor=100);
GRANT SELECT ON accessions to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('accessions', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.accessionsXbreeding_programs AS
SELECT public.materialized_phenoview.accession_id,
    public.materialized_phenoview.breeding_program_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.accession_id, public.materialized_phenoview.breeding_program_id;
CREATE UNIQUE INDEX accessionsXbreeding_programs_idx ON public.accessionsXbreeding_programs(accession_id, breeding_program_id) WITH (fillfactor=100);
GRANT SELECT ON accessionsXbreeding_programs to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('accessionsXbreeding_programs', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.accessionsXgenotyping_protocols AS
SELECT public.materialized_genoview.accession_id,
    public.materialized_genoview.genotyping_protocol_id
   FROM public.materialized_genoview
  GROUP BY public.materialized_genoview.accession_id, public.materialized_genoview.genotyping_protocol_id;
CREATE UNIQUE INDEX accessionsXgenotyping_protocols_idx ON public.accessionsXgenotyping_protocols(accession_id, genotyping_protocol_id) WITH (fillfactor=100);
GRANT SELECT ON accessionsXgenotyping_protocols to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('accessionsXgenotyping_protocols', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.accessionsXlocations AS
SELECT public.materialized_phenoview.accession_id,
    public.materialized_phenoview.location_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.accession_id, public.materialized_phenoview.location_id;
CREATE UNIQUE INDEX accessionsXlocations_idx ON public.accessionsXlocations(accession_id, location_id) WITH (fillfactor=100);
GRANT SELECT ON accessionsXlocations to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('accessionsXlocations', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.accessionsXplots AS
SELECT public.materialized_phenoview.accession_id,
    public.materialized_phenoview.plot_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.accession_id, public.materialized_phenoview.plot_id;
CREATE UNIQUE INDEX accessionsXplots_idx ON public.accessionsXplots(accession_id, plot_id) WITH (fillfactor=100);
GRANT SELECT ON accessionsXplots to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('accessionsXplots', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.accessionsXtraits AS
SELECT public.materialized_phenoview.accession_id,
    public.materialized_phenoview.trait_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.accession_id, public.materialized_phenoview.trait_id;
CREATE UNIQUE INDEX accessionsXtraits_idx ON public.accessionsXtraits(accession_id, trait_id) WITH (fillfactor=100);
GRANT SELECT ON accessionsXtraits to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('accessionsXtraits', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.accessionsXtrials AS
SELECT public.materialized_phenoview.accession_id,
    public.materialized_phenoview.trial_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.accession_id, public.materialized_phenoview.trial_id;
CREATE UNIQUE INDEX accessionsXtrials_idx ON public.accessionsXtrials(accession_id, trial_id) WITH (fillfactor=100);
GRANT SELECT ON accessionsXtrials to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('accessionsXtrials', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.accessionsXtrial_designs AS
SELECT public.materialized_phenoview.accession_id,
    public.materialized_phenoview.trial_design_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.accession_id, public.materialized_phenoview.trial_design_id;
CREATE UNIQUE INDEX accessionsXtrial_designs_idx ON public.accessionsXtrial_designs(accession_id, trial_design_id) WITH (fillfactor=100);
GRANT SELECT ON accessionsXtrial_designs to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('accessionsXtrial_designs', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.accessionsXtrial_types AS
SELECT public.materialized_phenoview.accession_id,
    public.materialized_phenoview.trial_type_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.accession_id, public.materialized_phenoview.trial_type_id;
CREATE UNIQUE INDEX accessionsXtrial_types_idx ON public.accessionsXtrial_types(accession_id, trial_type_id) WITH (fillfactor=100);
GRANT SELECT ON accessionsXtrial_types to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('accessionsXtrial_types', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.accessionsXyears AS
SELECT public.materialized_phenoview.accession_id,
    public.materialized_phenoview.year_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.accession_id, public.materialized_phenoview.year_id;
CREATE UNIQUE INDEX accessionsXyears_idx ON public.accessionsXyears(accession_id, year_id) WITH (fillfactor=100);
GRANT SELECT ON accessionsXyears to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('accessionsXyears', FALSE, CURRENT_TIMESTAMP);

CREATE MATERIALIZED VIEW public.breeding_programs AS
SELECT project.project_id AS breeding_program_id,
    project.name AS breeding_program_name
   FROM project join projectprop USING (project_id)
   WHERE projectprop.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'breeding_program')
  GROUP BY project.project_id, project.name;
CREATE UNIQUE INDEX breeding_programs_idx ON public.breeding_programs(breeding_program_id) WITH (fillfactor=100);
GRANT SELECT ON breeding_programs to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('breeding_programs', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.breeding_programsXgenotyping_protocols AS
SELECT public.materialized_phenoview.breeding_program_id,
    public.materialized_genoview.genotyping_protocol_id
   FROM public.materialized_phenoview
   JOIN public.materialized_genoview USING(accession_id)
  GROUP BY public.materialized_phenoview.breeding_program_id, public.materialized_genoview.genotyping_protocol_id;
CREATE UNIQUE INDEX breeding_programsXgenotyping_protocols_idx ON public.breeding_programsXgenotyping_protocols(breeding_program_id, genotyping_protocol_id) WITH (fillfactor=100);
GRANT SELECT ON breeding_programsXgenotyping_protocols to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('breeding_programsXgenotyping_protocols', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.breeding_programsXlocations AS
SELECT public.materialized_phenoview.breeding_program_id,
    public.materialized_phenoview.location_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.breeding_program_id, public.materialized_phenoview.location_id;
CREATE UNIQUE INDEX breeding_programsXlocations_idx ON public.breeding_programsXlocations(breeding_program_id, location_id) WITH (fillfactor=100);
GRANT SELECT ON breeding_programsXlocations to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('breeding_programsXlocations', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.breeding_programsXplots AS
SELECT public.materialized_phenoview.breeding_program_id,
    public.materialized_phenoview.plot_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.breeding_program_id, public.materialized_phenoview.plot_id;
CREATE UNIQUE INDEX breeding_programsXplots_idx ON public.breeding_programsXplots(breeding_program_id, plot_id) WITH (fillfactor=100);
GRANT SELECT ON breeding_programsXplots to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('breeding_programsXplots', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.breeding_programsXtraits AS
SELECT public.materialized_phenoview.breeding_program_id,
    public.materialized_phenoview.trait_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.breeding_program_id, public.materialized_phenoview.trait_id;
CREATE UNIQUE INDEX breeding_programsXtraits_idx ON public.breeding_programsXtraits(breeding_program_id, trait_id) WITH (fillfactor=100);
GRANT SELECT ON breeding_programsXtraits to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('breeding_programsXtraits', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.breeding_programsXtrials AS
SELECT public.materialized_phenoview.breeding_program_id,
    public.materialized_phenoview.trial_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.breeding_program_id, public.materialized_phenoview.trial_id;
CREATE UNIQUE INDEX breeding_programsXtrials_idx ON public.breeding_programsXtrials(breeding_program_id, trial_id) WITH (fillfactor=100);
GRANT SELECT ON breeding_programsXtrials to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('breeding_programsXtrials', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.breeding_programsXtrial_designs AS
SELECT public.materialized_phenoview.breeding_program_id,
    public.materialized_phenoview.trial_design_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.breeding_program_id, public.materialized_phenoview.trial_design_id;
CREATE UNIQUE INDEX breeding_programsXtrial_designs_idx ON public.breeding_programsXtrial_designs(breeding_program_id, trial_design_id) WITH (fillfactor=100);
GRANT SELECT ON breeding_programsXtrial_designs to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('breeding_programsXtrial_designs', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.breeding_programsXtrial_types AS
SELECT public.materialized_phenoview.breeding_program_id,
    public.materialized_phenoview.trial_type_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.breeding_program_id, public.materialized_phenoview.trial_type_id;
CREATE UNIQUE INDEX breeding_programsXtrial_types_idx ON public.breeding_programsXtrial_types(breeding_program_id, trial_type_id) WITH (fillfactor=100);
GRANT SELECT ON breeding_programsXtrial_types to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('breeding_programsXtrial_types', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.breeding_programsXyears AS
SELECT public.materialized_phenoview.breeding_program_id,
    public.materialized_phenoview.year_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.breeding_program_id, public.materialized_phenoview.year_id;
CREATE UNIQUE INDEX breeding_programsXyears_idx ON public.breeding_programsXyears(breeding_program_id, year_id) WITH (fillfactor=100);
GRANT SELECT ON breeding_programsXyears to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('breeding_programsXyears', FALSE, CURRENT_TIMESTAMP);

CREATE MATERIALIZED VIEW public.genotyping_protocols AS
SELECT nd_protocol.nd_protocol_id AS genotyping_protocol_id,
    nd_protocol.name AS genotyping_protocol_name
   FROM nd_protocol
  GROUP BY public.nd_protocol.nd_protocol_id, public.nd_protocol.name;
CREATE UNIQUE INDEX genotyping_protocols_idx ON public.genotyping_protocols(genotyping_protocol_id) WITH (fillfactor=100);
GRANT SELECT ON genotyping_protocols to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('genotyping_protocols', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.genotyping_protocolsXlocations AS
SELECT public.materialized_genoview.genotyping_protocol_id,
    public.materialized_phenoview.location_id
   FROM public.materialized_genoview
   JOIN public.materialized_phenoview USING(accession_id)
  GROUP BY public.materialized_genoview.genotyping_protocol_id, public.materialized_phenoview.location_id;
CREATE UNIQUE INDEX genotyping_protocolsXlocations_idx ON public.genotyping_protocolsXlocations(genotyping_protocol_id, location_id) WITH (fillfactor=100);
GRANT SELECT ON genotyping_protocolsXlocations to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('genotyping_protocolsXlocations', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.genotyping_protocolsXplots AS
SELECT public.materialized_genoview.genotyping_protocol_id,
    public.materialized_phenoview.plot_id
   FROM public.materialized_genoview
   JOIN public.materialized_phenoview USING(accession_id)
  GROUP BY public.materialized_genoview.genotyping_protocol_id, public.materialized_phenoview.plot_id;
CREATE UNIQUE INDEX genotyping_protocolsXplots_idx ON public.genotyping_protocolsXplots(genotyping_protocol_id, plot_id) WITH (fillfactor=100);
GRANT SELECT ON genotyping_protocolsXplots to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('genotyping_protocolsXplots', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.genotyping_protocolsXtraits AS
SELECT public.materialized_genoview.genotyping_protocol_id,
    public.materialized_phenoview.trait_id
   FROM public.materialized_genoview
   JOIN public.materialized_phenoview USING(accession_id)
  GROUP BY public.materialized_genoview.genotyping_protocol_id, public.materialized_phenoview.trait_id;
CREATE UNIQUE INDEX genotyping_protocolsXtraits_idx ON public.genotyping_protocolsXtraits(genotyping_protocol_id, trait_id) WITH (fillfactor=100);
GRANT SELECT ON genotyping_protocolsXtraits to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('genotyping_protocolsXtraits', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.genotyping_protocolsXtrials AS
SELECT public.materialized_genoview.genotyping_protocol_id,
    public.materialized_phenoview.trial_id
   FROM public.materialized_genoview
   JOIN public.materialized_phenoview USING(accession_id)
  GROUP BY public.materialized_genoview.genotyping_protocol_id, public.materialized_phenoview.trial_id;
CREATE UNIQUE INDEX genotyping_protocolsXtrials_idx ON public.genotyping_protocolsXtrials(genotyping_protocol_id, trial_id) WITH (fillfactor=100);
GRANT SELECT ON genotyping_protocolsXtrials to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('genotyping_protocolsXtrials', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.genotyping_protocolsXtrial_designs AS
SELECT public.materialized_genoview.genotyping_protocol_id,
    public.materialized_phenoview.trial_design_id
   FROM public.materialized_genoview
   JOIN public.materialized_phenoview USING(accession_id)
  GROUP BY public.materialized_genoview.genotyping_protocol_id, public.materialized_phenoview.trial_design_id;
CREATE UNIQUE INDEX genotyping_protocolsXtrial_designs_idx ON public.genotyping_protocolsXtrial_designs(genotyping_protocol_id, trial_design_id) WITH (fillfactor=100);
GRANT SELECT ON genotyping_protocolsXtrial_designs to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('genotyping_protocolsXtrial_designs', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.genotyping_protocolsXtrial_types AS
SELECT public.materialized_genoview.genotyping_protocol_id,
    public.materialized_phenoview.trial_type_id
   FROM public.materialized_genoview
   JOIN public.materialized_phenoview USING(accession_id)
  GROUP BY public.materialized_genoview.genotyping_protocol_id, public.materialized_phenoview.trial_type_id;
CREATE UNIQUE INDEX genotyping_protocolsXtrial_types_idx ON public.genotyping_protocolsXtrial_types(genotyping_protocol_id, trial_type_id) WITH (fillfactor=100);
GRANT SELECT ON genotyping_protocolsXtrial_types to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('genotyping_protocolsXtrial_types', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.genotyping_protocolsXyears AS
SELECT public.materialized_genoview.genotyping_protocol_id,
    public.materialized_phenoview.year_id
   FROM public.materialized_genoview
   JOIN public.materialized_phenoview USING(accession_id)
  GROUP BY public.materialized_genoview.genotyping_protocol_id, public.materialized_phenoview.year_id;
CREATE UNIQUE INDEX genotyping_protocolsXyears_idx ON public.genotyping_protocolsXyears(genotyping_protocol_id, year_id) WITH (fillfactor=100);
GRANT SELECT ON genotyping_protocolsXyears to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('genotyping_protocolsXyears', FALSE, CURRENT_TIMESTAMP);

CREATE MATERIALIZED VIEW public.locations AS
SELECT nd_geolocation.nd_geolocation_id AS location_id,
  nd_geolocation.description AS location_name
   FROM nd_geolocation
  GROUP BY public.nd_geolocation.nd_geolocation_id, public.nd_geolocation.description;
CREATE UNIQUE INDEX locations_idx ON public.locations(location_id) WITH (fillfactor=100);
GRANT SELECT ON locations to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('locations', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.locationsXplots AS
SELECT public.materialized_phenoview.location_id,
    public.materialized_phenoview.plot_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.location_id, public.materialized_phenoview.plot_id;
CREATE UNIQUE INDEX locationsXplots_idx ON public.locationsXplots(location_id, plot_id) WITH (fillfactor=100);
GRANT SELECT ON locationsXplots to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('locationsXplots', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.locationsXtraits AS
SELECT public.materialized_phenoview.location_id,
    public.materialized_phenoview.trait_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.location_id, public.materialized_phenoview.trait_id;
CREATE UNIQUE INDEX locationsXtraits_idx ON public.locationsXtraits(location_id, trait_id) WITH (fillfactor=100);
GRANT SELECT ON locationsXtraits to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('locationsXtraits', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.locationsXtrials AS
SELECT public.materialized_phenoview.location_id,
    public.materialized_phenoview.trial_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.location_id, public.materialized_phenoview.trial_id;
CREATE UNIQUE INDEX locationsXtrials_idx ON public.locationsXtrials(location_id, trial_id) WITH (fillfactor=100);
GRANT SELECT ON locationsXtrials to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('locationsXtrials', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.locationsXtrial_designs AS
SELECT public.materialized_phenoview.location_id,
    public.materialized_phenoview.trial_design_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.location_id, public.materialized_phenoview.trial_design_id;
CREATE UNIQUE INDEX locationsXtrial_designs_idx ON public.locationsXtrial_designs(location_id, trial_design_id) WITH (fillfactor=100);
GRANT SELECT ON locationsXtrial_designs to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('locationsXtrial_designs', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.locationsXtrial_types AS
SELECT public.materialized_phenoview.location_id,
    public.materialized_phenoview.trial_type_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.location_id, public.materialized_phenoview.trial_type_id;
CREATE UNIQUE INDEX locationsXtrial_types_idx ON public.locationsXtrial_types(location_id, trial_type_id) WITH (fillfactor=100);
GRANT SELECT ON locationsXtrial_types to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('locationsXtrial_types', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.locationsXyears AS
SELECT public.materialized_phenoview.location_id,
    public.materialized_phenoview.year_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.location_id, public.materialized_phenoview.year_id;
CREATE UNIQUE INDEX locationsXyears_idx ON public.locationsXyears(location_id, year_id) WITH (fillfactor=100);
GRANT SELECT ON locationsXyears to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('locationsXyears', FALSE, CURRENT_TIMESTAMP);

CREATE MATERIALIZED VIEW public.plots AS
SELECT stock.stock_id AS plot_id,
    stock.uniquename AS plot_name
   FROM stock
   WHERE stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plot')
  GROUP BY public.stock.stock_id, public.stock.uniquename;
CREATE UNIQUE INDEX plots_idx ON public.plots(plot_id) WITH (fillfactor=100);
GRANT SELECT ON plots to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('plots', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.plotsXtraits AS
SELECT public.materialized_phenoview.plot_id,
    public.materialized_phenoview.trait_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.plot_id, public.materialized_phenoview.trait_id;
CREATE UNIQUE INDEX plotsXtraits_idx ON public.plotsXtraits(plot_id, trait_id) WITH (fillfactor=100);
GRANT SELECT ON plotsXtraits to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('plotsXtraits', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.plotsXtrials AS
SELECT public.materialized_phenoview.plot_id,
    public.materialized_phenoview.trial_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.plot_id, public.materialized_phenoview.trial_id;
CREATE UNIQUE INDEX plotsXtrials_idx ON public.plotsXtrials(plot_id, trial_id) WITH (fillfactor=100);
GRANT SELECT ON plotsXtrials to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('plotsXtrials', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.plotsXtrial_designs AS
SELECT public.materialized_phenoview.plot_id,
    public.materialized_phenoview.trial_design_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.plot_id, public.materialized_phenoview.trial_design_id;
CREATE UNIQUE INDEX plotsXtrial_designs_idx ON public.plotsXtrial_designs(plot_id, trial_design_id) WITH (fillfactor=100);
GRANT SELECT ON plotsXtrial_designs to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('plotsXtrial_designs', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.plotsXtrial_types AS
SELECT public.materialized_phenoview.plot_id,
    public.materialized_phenoview.trial_type_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.plot_id, public.materialized_phenoview.trial_type_id;
CREATE UNIQUE INDEX plotsXtrial_types_idx ON public.plotsXtrial_types(plot_id, trial_type_id) WITH (fillfactor=100);
GRANT SELECT ON plotsXtrial_types to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('plotsXtrial_types', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.plotsXyears AS
SELECT public.materialized_phenoview.plot_id,
    public.materialized_phenoview.year_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.plot_id, public.materialized_phenoview.year_id;
CREATE UNIQUE INDEX plotsXyears_idx ON public.plotsXyears(plot_id, year_id) WITH (fillfactor=100);
GRANT SELECT ON plotsXyears to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('plotsXyears', FALSE, CURRENT_TIMESTAMP);

CREATE MATERIALIZED VIEW public.traits AS
SELECT   cvterm.cvterm_id AS trait_id,
  (((cvterm.name::text || '|'::text) || db.name::text) || ':'::text) || dbxref.accession::text AS trait_name
  FROM cvterm
  JOIN dbxref ON cvterm.dbxref_id = dbxref.dbxref_id
  JOIN db ON dbxref.db_id = db.db_id
  WHERE db.db_id =
(SELECT dbxref.db_id
   FROM stock
   JOIN nd_experiment_stock USING(stock_id)
   JOIN nd_experiment_phenotype USING(nd_experiment_id)
   JOIN phenotype USING(phenotype_id)
   JOIN cvterm ON phenotype.cvalue_id = cvterm.cvterm_id
   JOIN dbxref ON cvterm.dbxref_id = dbxref.dbxref_id LIMIT 1)
   GROUP BY public.cvterm.cvterm_id, trait_name;
CREATE UNIQUE INDEX traits_idx ON public.traits(trait_id) WITH (fillfactor=100);
GRANT SELECT ON traits to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('traits', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.traitsXtrials AS
SELECT public.materialized_phenoview.trait_id,
    public.materialized_phenoview.trial_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.trait_id, public.materialized_phenoview.trial_id;
CREATE UNIQUE INDEX traitsXtrials_idx ON public.traitsXtrials(trait_id, trial_id) WITH (fillfactor=100);
GRANT SELECT ON traitsXtrials to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('traitsXtrials', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.traitsXtrial_designs AS
SELECT public.materialized_phenoview.trait_id,
    public.materialized_phenoview.trial_design_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.trait_id, public.materialized_phenoview.trial_design_id;
CREATE UNIQUE INDEX traitsXtrial_designs_idx ON public.traitsXtrial_designs(trait_id, trial_design_id) WITH (fillfactor=100);
GRANT SELECT ON traitsXtrial_designs to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('traitsXtrial_designs', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.traitsXtrial_types AS
SELECT public.materialized_phenoview.trait_id,
    public.materialized_phenoview.trial_type_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.trait_id, public.materialized_phenoview.trial_type_id;
CREATE UNIQUE INDEX traitsXtrial_types_idx ON public.traitsXtrial_types(trait_id, trial_type_id) WITH (fillfactor=100);
GRANT SELECT ON traitsXtrial_types to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('traitsXtrial_types', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.traitsXyears AS
SELECT public.materialized_phenoview.trait_id,
    public.materialized_phenoview.year_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.trait_id, public.materialized_phenoview.year_id;
CREATE UNIQUE INDEX traitsXyears_idx ON public.traitsXyears(trait_id, year_id) WITH (fillfactor=100);
GRANT SELECT ON traitsXyears to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('traitsXyears', FALSE, CURRENT_TIMESTAMP);

CREATE MATERIALIZED VIEW public.trials AS
SELECT project.project_id AS trial_id,
    project.name AS trial_name
   FROM project join projectprop USING (project_id)
   WHERE projectprop.type_id IS DISTINCT FROM (SELECT cvterm_id from cvterm where cvterm.name = 'breeding_program')
   AND projectprop.type_id IS DISTINCT FROM (SELECT cvterm_id from cvterm where cvterm.name = 'trial_folder')
  GROUP BY public.project.project_id, public.project.name;
CREATE UNIQUE INDEX trials_idx ON public.trials(trial_id) WITH (fillfactor=100);
GRANT SELECT ON trials to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('trials', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.trialsXtrial_designs AS
SELECT public.materialized_phenoview.trial_id,
    public.materialized_phenoview.trial_design_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.trial_id, public.materialized_phenoview.trial_design_id;
CREATE UNIQUE INDEX trialsXtrial_designs_idx ON public.trialsXtrial_designs(trial_id, trial_design_id) WITH (fillfactor=100);
GRANT SELECT ON trialsXtrial_designs to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('trialsXtrial_designs', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.trialsXtrial_types AS
SELECT public.materialized_phenoview.trial_id,
    public.materialized_phenoview.trial_type_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.trial_id, public.materialized_phenoview.trial_type_id;
CREATE UNIQUE INDEX trialsXtrial_types_idx ON public.trialsXtrial_types(trial_id, trial_type_id) WITH (fillfactor=100);
GRANT SELECT ON trialsXtrial_types to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('trialsXtrial_types', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.trialsXyears AS
SELECT public.materialized_phenoview.trial_id,
    public.materialized_phenoview.year_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.trial_id, public.materialized_phenoview.year_id;
CREATE UNIQUE INDEX trialsXyears_idx ON public.trialsXyears(trial_id, year_id) WITH (fillfactor=100);
GRANT SELECT ON trialsXyears to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('trialsXyears', FALSE, CURRENT_TIMESTAMP);

CREATE MATERIALIZED VIEW public.trial_designs AS
SELECT projectprop.value AS trial_design_id,
  projectprop.value AS trial_design_name
   FROM projectprop
   JOIN cvterm ON(projectprop.type_id = cvterm.cvterm_id)
   WHERE cvterm.name = 'design'
   GROUP BY projectprop.value;
CREATE UNIQUE INDEX trial_designs_idx ON public.trial_designs(trial_design_id) WITH (fillfactor=100);
GRANT SELECT ON trial_designs to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('trial_designs', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.trial_designsXtrial_types AS
SELECT public.materialized_phenoview.trial_design_id,
    public.materialized_phenoview.trial_type_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.trial_design_id, public.materialized_phenoview.trial_type_id;
CREATE UNIQUE INDEX trial_designsXtrial_types_idx ON public.trial_designsXtrial_types(trial_design_id, trial_type_id) WITH (fillfactor=100);
GRANT SELECT ON trial_designsXtrial_types to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('trial_designsXtrial_types', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.trial_designsXyears AS
SELECT public.materialized_phenoview.trial_design_id,
    public.materialized_phenoview.year_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.trial_design_id, public.materialized_phenoview.year_id;
CREATE UNIQUE INDEX trial_designsXyears_idx ON public.trial_designsXyears(trial_design_id, year_id) WITH (fillfactor=100);
GRANT SELECT ON trial_designsXyears to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('trial_designsXyears', FALSE, CURRENT_TIMESTAMP);

CREATE MATERIALIZED VIEW public.trial_types AS
SELECT cvterm.cvterm_id AS trial_type_id,
  cvterm.name AS trial_type_name
   FROM cvterm
   JOIN cv USING(cv_id)
   WHERE cv.name = 'project_type'
   GROUP BY cvterm.cvterm_id;
CREATE UNIQUE INDEX trial_types_idx ON public.trial_types(trial_type_id) WITH (fillfactor=100);
GRANT SELECT ON trial_types to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('trial_types', FALSE, CURRENT_TIMESTAMP);
CREATE MATERIALIZED VIEW public.trial_typesXyears AS
SELECT public.materialized_phenoview.trial_type_id,
    public.materialized_phenoview.year_id
   FROM public.materialized_phenoview
  GROUP BY public.materialized_phenoview.trial_type_id, public.materialized_phenoview.year_id;
CREATE UNIQUE INDEX trial_typesXyears_idx ON public.trial_typesXyears(trial_type_id, year_id) WITH (fillfactor=100);
GRANT SELECT ON trial_typesXyears to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('trial_typesXyears', FALSE, CURRENT_TIMESTAMP);


CREATE MATERIALIZED VIEW public.years AS
SELECT projectprop.value AS year_id,
  projectprop.value AS year_name
   FROM projectprop
   WHERE projectprop.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'project year')
  GROUP BY public.projectprop.value;
CREATE UNIQUE INDEX years_idx ON public.years(year_id) WITH (fillfactor=100);
GRANT SELECT ON years to web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('years', FALSE, CURRENT_TIMESTAMP);


--

EOSQL

print "You're done!\n";
}


####
1; #
####
