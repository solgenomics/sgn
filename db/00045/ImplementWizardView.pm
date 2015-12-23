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
    nd_experiment_protocol.nd_protocol_id
   FROM stock plot
     LEFT JOIN stock_relationship ON plot.stock_id = stock_relationship.subject_id
     LEFT JOIN stock accession ON stock_relationship.object_id = accession.stock_id
     LEFT JOIN nd_experiment_stock ON stock_relationship.subject_id = nd_experiment_stock.stock_id
     LEFT JOIN nd_experiment ON nd_experiment_stock.nd_experiment_id = nd_experiment.nd_experiment_id
     LEFT JOIN nd_geolocation ON nd_experiment.nd_geolocation_id = nd_geolocation.nd_geolocation_id
     LEFT JOIN nd_experiment_protocol ON nd_experiment.nd_experiment_id = nd_experiment_protocol.nd_experiment_id
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
  GROUP BY stock_relationship.subject_id, cvterm.cvterm_id, plot.uniquename, accession.uniquename, stock_relationship.object_id, (((cvterm.name::text || '|'::text) || db.name::text) || ':'::text) || dbxref.accession::text, trial.name, project_relationship.subject_project_id, breeding_program.name, project_relationship.object_project_id, projectprop.value, nd_experiment.nd_geolocation_id, nd_geolocation.description, nd_experiment_protocol.nd_protocol_id;
GRANT ALL ON materialized_fullview to web_usr;

CREATE UNIQUE INDEX unqmeasurement_idx ON materialized_fullview(trial_id, trait_id, plot_id) WITH (fillfactor =100);
CREATE INDEX trait_id_idx ON materialized_fullview(trait_id) WITH (fillfactor =100);
CREATE INDEX breeding_program_id_idx ON materialized_fullview(breeding_program_id) WITH (fillfactor =100);
CREATE INDEX trial_id_idx ON materialized_fullview(trial_id) WITH (fillfactor =100);
CREATE INDEX nd_protocol_id_idx ON materialized_fullview(nd_protocol_id) WITH (fillfactor =100);
CREATE INDEX year_idx ON materialized_fullview(year_id) WITH (fillfactor =100);
CREATE INDEX location_id_idx ON materialized_fullview(location_id) WITH (fillfactor =100);
CREATE INDEX accession_id_idx ON materialized_fullview(accession_id) WITH (fillfactor =100);
CREATE INDEX plot_id_idx ON materialized_fullview(plot_id) WITH (fillfactor =100);
CREATE INDEX trial_by_loc_by_breed_prog_idx ON materialized_fullview(breeding_program_id,location_id,trial_id) WITH (fillfactor =100);
CREATE INDEX trial_by_year_by_loc_idx ON materialized_fullview(location_id,year_id,trial_id) WITH (fillfactor =100);
CREATE INDEX trial_by_breed_prog_idx ON materialized_fullview(breeding_program_id,trial_id) WITH (fillfactor =100);
CREATE INDEX trial_by_year_idx ON materialized_fullview(year_id,trial_id) WITH (fillfactor =100);
CREATE INDEX year_by_breed_prog_idx ON materialized_fullview(breeding_program_id,year_id) WITH (fillfactor =100);

CREATE RECURSIVE VIEW accession_ids(accession_id) AS SELECT MIN(accession_id) FROM materialized_fullview UNION SELECT (SELECT m.accession_id FROM materialized_fullview m WHERE m.accession_id > accession_ids.accession_id ORDER BY accession_id LIMIT 1) FROM accession_ids WHERE accession_id IS NOT NULL;
CREATE VIEW accessions AS SELECT accession_id, (SELECT accession_name FROM materialized_fullview m WHERE accession_ids.accession_id = m.accession_id ORDER BY m.accession_id LIMIT 1) FROM accession_ids;
GRANT ALL ON accessions to web_usr;

CREATE RECURSIVE VIEW breeding_program_ids(breeding_program_id) AS SELECT MIN(breeding_program_id) FROM materialized_fullview UNION SELECT (SELECT m.breeding_program_id FROM materialized_fullview m WHERE m.breeding_program_id > breeding_program_ids.breeding_program_id ORDER BY breeding_program_id LIMIT 1) FROM breeding_program_ids WHERE breeding_program_id IS NOT NULL;
CREATE VIEW breeding_programs AS SELECT breeding_program_id, (SELECT breeding_program_name FROM materialized_fullview m WHERE breeding_program_ids.breeding_program_id = m.breeding_program_id ORDER BY m.breeding_program_id LIMIT 1) FROM breeding_program_ids;
GRANT ALL ON breeding_programs to web_usr;

CREATE RECURSIVE VIEW location_ids(location_id) AS SELECT MIN(location_id) FROM materialized_fullview UNION SELECT (SELECT m.location_id FROM materialized_fullview m WHERE m.location_id > location_ids.location_id ORDER BY location_id LIMIT 1) FROM location_ids WHERE location_id IS NOT NULL;
CREATE VIEW locations AS SELECT location_id, (SELECT location_name FROM materialized_fullview m WHERE location_ids.location_id = m.location_id ORDER BY m.location_id LIMIT 1) FROM location_ids;
GRANT ALL ON locations to web_usr;

CREATE RECURSIVE VIEW plot_ids(plot_id) AS SELECT MIN(plot_id) FROM materialized_fullview UNION SELECT (SELECT m.plot_id FROM materialized_fullview m WHERE m.plot_id > plot_ids.plot_id ORDER BY plot_id LIMIT 1) FROM plot_ids WHERE plot_id IS NOT NULL;
CREATE VIEW plots AS SELECT plot_id, (SELECT plot_name FROM materialized_fullview m WHERE plot_ids.plot_id = m.plot_id ORDER BY m.plot_id LIMIT 1) FROM plot_ids;
GRANT ALL ON plots to web_usr;

CREATE RECURSIVE VIEW trait_ids(trait_id) AS SELECT MIN(trait_id) FROM materialized_fullview UNION SELECT (SELECT m.trait_id FROM materialized_fullview m WHERE m.trait_id > trait_ids.trait_id ORDER BY trait_id LIMIT 1) FROM trait_ids WHERE trait_id IS NOT NULL;
CREATE VIEW traits AS SELECT trait_id, (SELECT trait_name FROM materialized_fullview m WHERE trait_ids.trait_id = m.trait_id ORDER BY m.trait_id LIMIT 1) FROM trait_ids;
GRANT ALL ON traits to web_usr;

CREATE RECURSIVE VIEW trial_ids(trial_id) AS SELECT MIN(trial_id) FROM materialized_fullview UNION SELECT (SELECT m.trial_id FROM materialized_fullview m WHERE m.trial_id > trial_ids.trial_id ORDER BY trial_id LIMIT 1) FROM trial_ids WHERE trial_id IS NOT NULL;
CREATE VIEW trials AS SELECT trial_id, (SELECT trial_name FROM materialized_fullview m WHERE trial_ids.trial_id = m.trial_id ORDER BY m.trial_id LIMIT 1) FROM trial_ids;
GRANT ALL ON trials to web_usr;

CREATE RECURSIVE VIEW year_ids(year_id) AS SELECT MIN(year_id) FROM materialized_fullview UNION SELECT (SELECT m.year_id FROM materialized_fullview m WHERE m.year_id > year_ids.year_id ORDER BY year_id LIMIT 1) FROM year_ids WHERE year_id IS NOT NULL;
CREATE VIEW years AS SELECT year_id, year_id AS year_name FROM year_ids;
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
