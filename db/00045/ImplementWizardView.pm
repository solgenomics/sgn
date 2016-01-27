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

CREATE OR REPLACE FUNCTION pc_chartonum(chartoconvert character varying)              
  RETURNS numeric AS
$BODY$
SELECT CASE WHEN trim($1) SIMILAR TO '[0-9]+' 
        THEN CAST($1 AS numeric) 
    ELSE NULL END;
$BODY$
  LANGUAGE 'sql' IMMUTABLE STRICT;

CREATE MATERIALIZED VIEW materialized_fullview AS
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
     LEFT JOIN nd_experiment_stock ON stock_relationship.subject_id = nd_experiment_stock.stock_id
     LEFT JOIN nd_experiment ON nd_experiment_stock.nd_experiment_id = nd_experiment.nd_experiment_id
     LEFT JOIN nd_geolocation ON nd_experiment.nd_geolocation_id = nd_geolocation.nd_geolocation_id
     LEFT JOIN nd_experiment_protocol ON nd_experiment.nd_experiment_id = nd_experiment_protocol.nd_experiment_id
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
GRANT ALL ON materialized_fullview to web_usr;

CREATE UNIQUE INDEX unqmeasurement_idx ON materialized_fullview(trial_id, trait_id, plot_id, phenotype_id) WITH (fillfactor =100);
CREATE INDEX trait_id_idx ON materialized_fullview(trait_id) WITH (fillfactor =100);

CREATE INDEX trial_id_idx ON materialized_fullview(trial_id) WITH (fillfactor =100);
CREATE INDEX genotyping_protocol_id_idx ON materialized_fullview(genotyping_protocol_id) WITH (fillfactor =100);
CREATE INDEX accession_id_idx ON materialized_fullview(accession_id) WITH (fillfactor =100);
CREATE INDEX plot_id_idx ON materialized_fullview(plot_id) WITH (fillfactor =100);

CREATE INDEX breed_prog_X_accessions_idx ON materialized_fullview(breeding_program_id,accession_id) WITH (fillfactor=100);
CREATE INDEX breed_prog_X_plots_idx ON materialized_fullview(breeding_program_id,plot_id) WITH (fillfactor=100);
CREATE INDEX breed_prog_X_trials_idx ON materialized_fullview(breeding_program_id,trial_id) WITH (fillfactor=100);
CREATE INDEX location_X_accessions_idx ON materialized_fullview(location_id,accession_id) WITH (fillfactor=100);
CREATE INDEX location_X_plots_idx ON materialized_fullview(location_id,plot_id) WITH (fillfactor=100);
CREATE INDEX location_X_trials_idx ON materialized_fullview(location_id,trial_id) WITH (fillfactor=100);

CREATE INDEX breed_prog_X_location_X_trials_idx ON materialized_fullview(breeding_program_id,location_id,trial_id) WITH (fillfactor =100);
CREATE INDEX breed_prog_X_year_X_trials_idx ON materialized_fullview(breeding_program_id,year_id,trial_id) WITH (fillfactor =100);
CREATE INDEX location_X_year_X_trials_idx ON materialized_fullview(location_id,year_id,trial_id) WITH (fillfactor =100);
CREATE INDEX years_X_trials_idx ON materialized_fullview(year_id,trial_id) WITH (fillfactor =100);

CREATE MATERIALIZED VIEW accessions AS
SELECT materialized_fullview.accession_id,
    materialized_fullview.accession_name
   FROM materialized_fullview
  GROUP BY materialized_fullview.accession_id, materialized_fullview.accession_name;
GRANT ALL ON accessions to web_usr;
CREATE MATERIALIZED VIEW accessionsXbreeding_programs AS
SELECT materialized_fullview.accession_id,
    materialized_fullview.breeding_program_id
   FROM materialized_fullview
  GROUP BY materialized_fullview.accession_id, materialized_fullview.breeding_program_id;
GRANT ALL ON accessionsXbreeding_programs to web_usr;
CREATE MATERIALIZED VIEW accessionsXlocations AS
SELECT materialized_fullview.accession_id,
    materialized_fullview.location_id
   FROM materialized_fullview
  GROUP BY materialized_fullview.accession_id, materialized_fullview.location_id;
GRANT ALL ON accessionsXlocations to web_usr;
CREATE MATERIALIZED VIEW accessionsXgenotyping_protocols AS
SELECT materialized_fullview.accession_id,
    materialized_fullview.genotyping_protocol_id
   FROM materialized_fullview
  GROUP BY materialized_fullview.accession_id, materialized_fullview.genotyping_protocol_id;
GRANT ALL ON accessionsXgenotyping_protocols to web_usr;
CREATE MATERIALIZED VIEW accessionsXplots AS
SELECT materialized_fullview.accession_id,
    materialized_fullview.plot_id
   FROM materialized_fullview
  GROUP BY materialized_fullview.accession_id, materialized_fullview.plot_id;
GRANT ALL ON accessionsXplots to web_usr;
CREATE MATERIALIZED VIEW accessionsXtraits AS
SELECT materialized_fullview.accession_id,
    materialized_fullview.trait_id
   FROM materialized_fullview
  GROUP BY materialized_fullview.accession_id, materialized_fullview.trait_id;
GRANT ALL ON accessionsXtraits to web_usr;
CREATE MATERIALIZED VIEW accessionsXtrials AS
SELECT materialized_fullview.accession_id,
    materialized_fullview.trial_id
   FROM materialized_fullview
  GROUP BY materialized_fullview.accession_id, materialized_fullview.trial_id;
GRANT ALL ON accessionsXtrials to web_usr;
CREATE MATERIALIZED VIEW accessionsXyears AS
SELECT materialized_fullview.accession_id,
    materialized_fullview.year_id
   FROM materialized_fullview
  GROUP BY materialized_fullview.accession_id, materialized_fullview.year_id;
GRANT ALL ON accessionsXyears to web_usr;

CREATE MATERIALIZED VIEW breeding_programs AS
SELECT materialized_fullview.breeding_program_id,
    materialized_fullview.breeding_program_name
   FROM materialized_fullview
  GROUP BY materialized_fullview.breeding_program_id, materialized_fullview.breeding_program_name;
GRANT ALL ON breeding_programs to web_usr;
CREATE MATERIALIZED VIEW breeding_programsXlocations AS
SELECT materialized_fullview.breeding_program_id,
    materialized_fullview.location_id
   FROM materialized_fullview
  GROUP BY materialized_fullview.breeding_program_id, materialized_fullview.location_id;
GRANT ALL ON breeding_programsXlocations to web_usr;
CREATE MATERIALIZED VIEW breeding_programsXgenotyping_protocols AS
SELECT materialized_fullview.breeding_program_id,
    materialized_fullview.genotyping_protocol_id
   FROM materialized_fullview
  GROUP BY materialized_fullview.breeding_program_id, materialized_fullview.genotyping_protocol_id;
GRANT ALL ON breeding_programsXgenotyping_protocols to web_usr;
CREATE MATERIALIZED VIEW breeding_programsXplots AS
SELECT materialized_fullview.breeding_program_id,
    materialized_fullview.plot_id
   FROM materialized_fullview
  GROUP BY materialized_fullview.breeding_program_id, materialized_fullview.plot_id;
GRANT ALL ON breeding_programsXplots to web_usr;
CREATE MATERIALIZED VIEW breeding_programsXtraits AS
SELECT materialized_fullview.breeding_program_id,
    materialized_fullview.trait_id
   FROM materialized_fullview
  GROUP BY materialized_fullview.breeding_program_id, materialized_fullview.trait_id;
GRANT ALL ON breeding_programsXtraits to web_usr;
CREATE MATERIALIZED VIEW breeding_programsXtrials AS
SELECT materialized_fullview.breeding_program_id,
    materialized_fullview.trial_id
   FROM materialized_fullview
  GROUP BY materialized_fullview.breeding_program_id, materialized_fullview.trial_id;
GRANT ALL ON breeding_programsXtrials to web_usr;
CREATE MATERIALIZED VIEW breeding_programsXyears AS
SELECT materialized_fullview.breeding_program_id,
    materialized_fullview.year_id
   FROM materialized_fullview
  GROUP BY materialized_fullview.breeding_program_id, materialized_fullview.year_id;
GRANT ALL ON breeding_programsXyears to web_usr;

CREATE MATERIALIZED VIEW genotyping_protocols AS
SELECT materialized_fullview.genotyping_protocol_id,
    materialized_fullview.genotyping_protocol_name
   FROM materialized_fullview
  GROUP BY materialized_fullview.genotyping_protocol_id, materialized_fullview.genotyping_protocol_name;
GRANT ALL ON genotyping_protocols to web_usr;
CREATE MATERIALIZED VIEW genotyping_protocolsXlocations AS
SELECT materialized_fullview.genotyping_protocol_id,
    materialized_fullview.location_id
   FROM materialized_fullview
  GROUP BY materialized_fullview.genotyping_protocol_id, materialized_fullview.location_id;
GRANT ALL ON genotyping_protocolsXlocations to web_usr;
CREATE MATERIALIZED VIEW genotyping_protocolsXplots AS
SELECT materialized_fullview.genotyping_protocol_id,
    materialized_fullview.plot_id
   FROM materialized_fullview
  GROUP BY materialized_fullview.genotyping_protocol_id, materialized_fullview.plot_id;
GRANT ALL ON genotyping_protocolsXplots to web_usr;
CREATE MATERIALIZED VIEW genotyping_protocolsXtraits AS
SELECT materialized_fullview.genotyping_protocol_id,
    materialized_fullview.trait_id
   FROM materialized_fullview
  GROUP BY materialized_fullview.genotyping_protocol_id, materialized_fullview.trait_id;
GRANT ALL ON genotyping_protocolsXtraits to web_usr;
CREATE MATERIALIZED VIEW genotyping_protocolsXtrials AS
SELECT materialized_fullview.genotyping_protocol_id,
    materialized_fullview.trial_id
   FROM materialized_fullview
  GROUP BY materialized_fullview.genotyping_protocol_id, materialized_fullview.trial_id;
GRANT ALL ON genotyping_protocolsXtrials to web_usr;
CREATE MATERIALIZED VIEW genotyping_protocolsXyears AS
SELECT materialized_fullview.genotyping_protocol_id,
    materialized_fullview.year_id
   FROM materialized_fullview
  GROUP BY materialized_fullview.genotyping_protocol_id, materialized_fullview.year_id;
GRANT ALL ON genotyping_protocolsXyears to web_usr;

CREATE MATERIALIZED VIEW locations AS
SELECT materialized_fullview.location_id,
    materialized_fullview.location_name
   FROM materialized_fullview
  GROUP BY materialized_fullview.location_id, materialized_fullview.location_name;
GRANT ALL ON locations to web_usr;
CREATE MATERIALIZED VIEW locationsXplots AS
SELECT materialized_fullview.location_id,
    materialized_fullview.plot_id
   FROM materialized_fullview
  GROUP BY materialized_fullview.location_id, materialized_fullview.plot_id;
GRANT ALL ON locationsXplots to web_usr;
CREATE MATERIALIZED VIEW locationsXtraits AS
SELECT materialized_fullview.location_id,
    materialized_fullview.trait_id
   FROM materialized_fullview
  GROUP BY materialized_fullview.location_id, materialized_fullview.trait_id;
GRANT ALL ON locationsXtraits to web_usr;
CREATE MATERIALIZED VIEW locationsXtrials AS
SELECT materialized_fullview.location_id,
    materialized_fullview.trial_id
   FROM materialized_fullview
  GROUP BY materialized_fullview.location_id, materialized_fullview.trial_id;
GRANT ALL ON locationsXtrials to web_usr;
CREATE MATERIALIZED VIEW locationsXyears AS
SELECT materialized_fullview.location_id,
    materialized_fullview.year_id
   FROM materialized_fullview
  GROUP BY materialized_fullview.location_id, materialized_fullview.year_id;
GRANT ALL ON locationsXyears to web_usr;

CREATE MATERIALIZED VIEW plots AS
SELECT materialized_fullview.plot_id,
    materialized_fullview.plot_name
   FROM materialized_fullview
  GROUP BY materialized_fullview.plot_id, materialized_fullview.plot_name;
GRANT ALL ON plots to web_usr;
CREATE MATERIALIZED VIEW plotsXtraits AS
SELECT materialized_fullview.plot_id,
    materialized_fullview.trait_id
   FROM materialized_fullview
  GROUP BY materialized_fullview.plot_id, materialized_fullview.trait_id;
GRANT ALL ON plotsXtraits to web_usr;
CREATE MATERIALIZED VIEW plotsXtrials AS
SELECT materialized_fullview.plot_id,
    materialized_fullview.trial_id
   FROM materialized_fullview
  GROUP BY materialized_fullview.plot_id, materialized_fullview.trial_id;
GRANT ALL ON plotsXtrials to web_usr;
CREATE MATERIALIZED VIEW plotsXyears AS
SELECT materialized_fullview.plot_id,
    materialized_fullview.year_id
   FROM materialized_fullview
  GROUP BY materialized_fullview.plot_id, materialized_fullview.year_id;
GRANT ALL ON plotsXyears to web_usr;

CREATE MATERIALIZED VIEW traits AS
SELECT materialized_fullview.trait_id,
    materialized_fullview.trait_name
   FROM materialized_fullview
  GROUP BY materialized_fullview.trait_id, materialized_fullview.trait_name;
GRANT ALL ON traits to web_usr;
CREATE MATERIALIZED VIEW traitsXtrials AS
SELECT materialized_fullview.trait_id,
    materialized_fullview.trial_id
   FROM materialized_fullview
  GROUP BY materialized_fullview.trait_id, materialized_fullview.trial_id;
GRANT ALL ON traitsXtrials to web_usr;
CREATE MATERIALIZED VIEW traitsXyears AS
SELECT materialized_fullview.trait_id,
    materialized_fullview.year_id
   FROM materialized_fullview
  GROUP BY materialized_fullview.trait_id, materialized_fullview.year_id;
GRANT ALL ON traitsXyears to web_usr;

CREATE MATERIALIZED VIEW trials AS
SELECT materialized_fullview.trial_id,
    materialized_fullview.trial_name
   FROM materialized_fullview
  GROUP BY materialized_fullview.trial_id, materialized_fullview.trial_name;
GRANT ALL ON trials to web_usr;
CREATE MATERIALIZED VIEW trialsXyears AS
SELECT materialized_fullview.trial_id,
    materialized_fullview.year_id
   FROM materialized_fullview
  GROUP BY materialized_fullview.trial_id, materialized_fullview.year_id;
GRANT ALL ON trialsXyears to web_usr;

CREATE MATERIALIZED VIEW years AS
SELECT materialized_fullview.year_id,
    materialized_fullview.year_name
   FROM materialized_fullview
  GROUP BY materialized_fullview.year_id, materialized_fullview.year_name;
GRANT ALL ON years to web_usr;

INSERT INTO dbxref (db_id, accession) VALUES(288,'breeding_programs');
INSERT INTO cvterm (cv_id, name, definition, dbxref_id) VALUES(50, 'breeding_programs', 'breeding_programs', (SELECT dbxref_id FROM dbxref WHERE accession = 'breeding_programs');

--
SELECT * from public.stock;

EOSQL

print "You're done!\n";
}


####
1; #
####
