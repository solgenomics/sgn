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
  GROUP BY stock_relationship.subject_id, cvterm.cvterm_id, plot.uniquename, accession.uniquename, stock_relationship.object_id, (((cvterm.name::text || '|'::text) || db.name::text) || ':'::text) || dbxref.accession::text, trial.name, project_relationship.subject_project_id, breeding_program.name, project_relationship.object_project_id, projectprop.value, nd_experiment.nd_geolocation_id, nd_geolocation.description, nd_experiment_protocol.nd_protocol_id, nd_protocol.name;
GRANT ALL ON public.materialized_fullview to web_usr;

CREATE UNIQUE INDEX unqmeasurement_idx ON public.materialized_fullview(trial_id, trait_id, plot_id, genotyping_protocol_id) WITH (fillfactor =100);
CREATE INDEX accession_id_idx ON public.materialized_fullview(accession_id) WITH (fillfactor =100);
CREATE INDEX breeding_program_id_idx ON public.materialized_fullview(breeding_program_id) WITH (fillfactor =100);
CREATE INDEX genotyping_protocol_id_idx ON public.materialized_fullview(genotyping_protocol_id) WITH (fillfactor =100);
CREATE INDEX location_id_idx ON public.materialized_fullview(location_id) WITH (fillfactor =100);
CREATE INDEX plot_id_idx ON public.materialized_fullview(plot_id) WITH (fillfactor =100);
CREATE INDEX trait_id_idx ON public.materialized_fullview(trait_id) WITH (fillfactor =100);
CREATE INDEX trial_id_idx ON public.materialized_fullview(trial_id) WITH (fillfactor =100);
CREATE INDEX year_id_idx ON public.materialized_fullview(year_id) WITH (fillfactor =100);

CREATE MATERIALIZED VIEW public.accessions AS
SELECT public.materialized_fullview.accession_id,
    public.materialized_fullview.accession_name
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.accession_id, public.materialized_fullview.accession_name;
GRANT ALL ON public.accessions to web_usr;
CREATE MATERIALIZED VIEW public.accessionsXbreeding_programs AS
SELECT public.materialized_fullview.accession_id,
    public.materialized_fullview.breeding_program_id
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.accession_id, public.materialized_fullview.breeding_program_id;
GRANT ALL ON public.accessionsXbreeding_programs to web_usr;
CREATE MATERIALIZED VIEW public.accessionsXlocations AS
SELECT public.materialized_fullview.accession_id,
    public.materialized_fullview.location_id
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.accession_id, public.materialized_fullview.location_id;
GRANT ALL ON public.accessionsXlocations to web_usr;
CREATE MATERIALIZED VIEW public.accessionsXgenotyping_protocols AS
SELECT public.materialized_fullview.accession_id,
    public.materialized_fullview.genotyping_protocol_id
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.accession_id, public.materialized_fullview.genotyping_protocol_id;
GRANT ALL ON public.accessionsXgenotyping_protocols to web_usr;
CREATE MATERIALIZED VIEW public.accessionsXplots AS
SELECT public.materialized_fullview.accession_id,
    public.materialized_fullview.plot_id
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.accession_id, public.materialized_fullview.plot_id;
GRANT ALL ON public.accessionsXplots to web_usr;
CREATE MATERIALIZED VIEW public.accessionsXtraits AS
SELECT public.materialized_fullview.accession_id,
    public.materialized_fullview.trait_id
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.accession_id, public.materialized_fullview.trait_id;
GRANT ALL ON public.accessionsXtraits to web_usr;
CREATE MATERIALIZED VIEW public.accessionsXtrials AS
SELECT public.materialized_fullview.accession_id,
    public.materialized_fullview.trial_id
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.accession_id, public.materialized_fullview.trial_id;
GRANT ALL ON public.accessionsXtrials to web_usr;
CREATE MATERIALIZED VIEW public.accessionsXyears AS
SELECT public.materialized_fullview.accession_id,
    public.materialized_fullview.year_id
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.accession_id, public.materialized_fullview.year_id;
GRANT ALL ON public.accessionsXyears to web_usr;

CREATE MATERIALIZED VIEW public.breeding_programs AS
SELECT public.materialized_fullview.breeding_program_id,
    public.materialized_fullview.breeding_program_name
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.breeding_program_id, public.materialized_fullview.breeding_program_name;
GRANT ALL ON public.breeding_programs to web_usr;
CREATE MATERIALIZED VIEW public.breeding_programsXlocations AS
SELECT public.materialized_fullview.breeding_program_id,
    public.materialized_fullview.location_id
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.breeding_program_id, public.materialized_fullview.location_id;
GRANT ALL ON public.breeding_programsXlocations to web_usr;
CREATE MATERIALIZED VIEW public.breeding_programsXgenotyping_protocols AS
SELECT public.materialized_fullview.breeding_program_id,
    public.materialized_fullview.genotyping_protocol_id
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.breeding_program_id, public.materialized_fullview.genotyping_protocol_id;
GRANT ALL ON public.breeding_programsXgenotyping_protocols to web_usr;
CREATE MATERIALIZED VIEW public.breeding_programsXplots AS
SELECT public.materialized_fullview.breeding_program_id,
    public.materialized_fullview.plot_id
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.breeding_program_id, public.materialized_fullview.plot_id;
GRANT ALL ON public.breeding_programsXplots to web_usr;
CREATE MATERIALIZED VIEW public.breeding_programsXtraits AS
SELECT public.materialized_fullview.breeding_program_id,
    public.materialized_fullview.trait_id
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.breeding_program_id, public.materialized_fullview.trait_id;
GRANT ALL ON public.breeding_programsXtraits to web_usr;
CREATE MATERIALIZED VIEW public.breeding_programsXtrials AS
SELECT public.materialized_fullview.breeding_program_id,
    public.materialized_fullview.trial_id
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.breeding_program_id, public.materialized_fullview.trial_id;
GRANT ALL ON public.breeding_programsXtrials to web_usr;
CREATE MATERIALIZED VIEW public.breeding_programsXyears AS
SELECT public.materialized_fullview.breeding_program_id,
    public.materialized_fullview.year_id
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.breeding_program_id, public.materialized_fullview.year_id;
GRANT ALL ON public.breeding_programsXyears to web_usr;

CREATE MATERIALIZED VIEW public.genotyping_protocols AS
SELECT public.materialized_fullview.genotyping_protocol_id,
    public.materialized_fullview.genotyping_protocol_name
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.genotyping_protocol_id, public.materialized_fullview.genotyping_protocol_name;
GRANT ALL ON public.genotyping_protocols to web_usr;
CREATE MATERIALIZED VIEW public.genotyping_protocolsXlocations AS
SELECT public.materialized_fullview.genotyping_protocol_id,
    public.materialized_fullview.location_id
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.genotyping_protocol_id, public.materialized_fullview.location_id;
GRANT ALL ON public.genotyping_protocolsXlocations to web_usr;
CREATE MATERIALIZED VIEW public.genotyping_protocolsXplots AS
SELECT public.materialized_fullview.genotyping_protocol_id,
    public.materialized_fullview.plot_id
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.genotyping_protocol_id, public.materialized_fullview.plot_id;
GRANT ALL ON public.genotyping_protocolsXplots to web_usr;
CREATE MATERIALIZED VIEW public.genotyping_protocolsXtraits AS
SELECT public.materialized_fullview.genotyping_protocol_id,
    public.materialized_fullview.trait_id
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.genotyping_protocol_id, public.materialized_fullview.trait_id;
GRANT ALL ON public.genotyping_protocolsXtraits to web_usr;
CREATE MATERIALIZED VIEW public.genotyping_protocolsXtrials AS
SELECT public.materialized_fullview.genotyping_protocol_id,
    public.materialized_fullview.trial_id
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.genotyping_protocol_id, public.materialized_fullview.trial_id;
GRANT ALL ON public.genotyping_protocolsXtrials to web_usr;
CREATE MATERIALIZED VIEW public.genotyping_protocolsXyears AS
SELECT public.materialized_fullview.genotyping_protocol_id,
    public.materialized_fullview.year_id
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.genotyping_protocol_id, public.materialized_fullview.year_id;
GRANT ALL ON public.genotyping_protocolsXyears to web_usr;

CREATE MATERIALIZED VIEW public.locations AS
SELECT public.materialized_fullview.location_id,
    public.materialized_fullview.location_name
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.location_id, public.materialized_fullview.location_name;
GRANT ALL ON public.locations to web_usr;
CREATE MATERIALIZED VIEW public.locationsXplots AS
SELECT public.materialized_fullview.location_id,
    public.materialized_fullview.plot_id
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.location_id, public.materialized_fullview.plot_id;
GRANT ALL ON public.locationsXplots to web_usr;
CREATE MATERIALIZED VIEW public.locationsXtraits AS
SELECT public.materialized_fullview.location_id,
    public.materialized_fullview.trait_id
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.location_id, public.materialized_fullview.trait_id;
GRANT ALL ON public.locationsXtraits to web_usr;
CREATE MATERIALIZED VIEW public.locationsXtrials AS
SELECT public.materialized_fullview.location_id,
    public.materialized_fullview.trial_id
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.location_id, public.materialized_fullview.trial_id;
GRANT ALL ON public.locationsXtrials to web_usr;
CREATE MATERIALIZED VIEW public.locationsXyears AS
SELECT public.materialized_fullview.location_id,
    public.materialized_fullview.year_id
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.location_id, public.materialized_fullview.year_id;
GRANT ALL ON public.locationsXyears to web_usr;

CREATE MATERIALIZED VIEW public.plots AS
SELECT public.materialized_fullview.plot_id,
    public.materialized_fullview.plot_name
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.plot_id, public.materialized_fullview.plot_name;
GRANT ALL ON public.plots to web_usr;
CREATE MATERIALIZED VIEW public.plotsXtraits AS
SELECT public.materialized_fullview.plot_id,
    public.materialized_fullview.trait_id
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.plot_id, public.materialized_fullview.trait_id;
GRANT ALL ON public.plotsXtraits to web_usr;
CREATE MATERIALIZED VIEW public.plotsXtrials AS
SELECT public.materialized_fullview.plot_id,
    public.materialized_fullview.trial_id
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.plot_id, public.materialized_fullview.trial_id;
GRANT ALL ON public.plotsXtrials to web_usr;
CREATE MATERIALIZED VIEW public.plotsXyears AS
SELECT public.materialized_fullview.plot_id,
    public.materialized_fullview.year_id
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.plot_id, public.materialized_fullview.year_id;
GRANT ALL ON public.plotsXyears to web_usr;

CREATE MATERIALIZED VIEW public.traits AS
SELECT public.materialized_fullview.trait_id,
    public.materialized_fullview.trait_name
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.trait_id, public.materialized_fullview.trait_name;
GRANT ALL ON public.traits to web_usr;
CREATE MATERIALIZED VIEW public.traitsXtrials AS
SELECT public.materialized_fullview.trait_id,
    public.materialized_fullview.trial_id
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.trait_id, public.materialized_fullview.trial_id;
GRANT ALL ON public.traitsXtrials to web_usr;
CREATE MATERIALIZED VIEW public.traitsXyears AS
SELECT public.materialized_fullview.trait_id,
    public.materialized_fullview.year_id
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.trait_id, public.materialized_fullview.year_id;
GRANT ALL ON public.traitsXyears to web_usr;

CREATE MATERIALIZED VIEW public.trials AS
SELECT public.materialized_fullview.trial_id,
    public.materialized_fullview.trial_name
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.trial_id, public.materialized_fullview.trial_name;
GRANT ALL ON public.trials to web_usr;
CREATE MATERIALIZED VIEW public.trialsXyears AS
SELECT public.materialized_fullview.trial_id,
    public.materialized_fullview.year_id
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.trial_id, public.materialized_fullview.year_id;
GRANT ALL ON public.trialsXyears to web_usr;

CREATE MATERIALIZED VIEW public.years AS
SELECT public.materialized_fullview.year_id,
    public.materialized_fullview.year_name
   FROM public.materialized_fullview
  GROUP BY public.materialized_fullview.year_id, public.materialized_fullview.year_name;
GRANT ALL ON public.years to web_usr;

--
SELECT * from public.stock;

EOSQL

print "You're done!\n";
}


####
1; #
####
