#!/usr/bin/env perl

=head1 NAME

AddInstanceToMaterializedViews.pm

=head1 SYNOPSIS

mx-run AddInstanceToMaterializedViews [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch:
- Adds a new instances view based on metadata.md_files
- Adds cross-reference views between instances and other search wizard categories
  including protocols, trials, accessions, breeding programs, locations, and years

=head1 AUTHOR

Ben Maza

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

package AddInstanceToMaterializedViews;

use Moose;
extends 'CXGN::Metadata::Dbpatch';

has '+description' => ( default => <<'' );
This patch adds instance file ids to the search wizard materialized views

sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    $self->dbh->do(<<EOSQL);
--do your SQL here

-- Add instances view
-- instances are files in metadata.md_files connected to protocols
-- via nd_experiment_protocol and phenome.nd_experiment_md_files
DROP VIEW IF EXISTS public.instances CASCADE;
CREATE VIEW public.instances AS
SELECT
    m.file_id AS instance_id,
    m.file_id::text AS instance_name
FROM metadata.md_files m
GROUP BY m.file_id, m.basename;
ALTER VIEW public.instances OWNER TO web_usr;

-- instancesXprotocols
-- connects instances to protocols via the experiment chain
DROP VIEW IF EXISTS public.instancesXprotocols CASCADE;
CREATE VIEW public.instancesXprotocols AS
SELECT DISTINCT
    ef.file_id AS instance_id,
    ep.nd_protocol_id AS protocol_id
FROM phenome.nd_experiment_md_files ef
JOIN nd_experiment_protocol ep ON ef.nd_experiment_id = ep.nd_experiment_id
GROUP BY 1, 2;
ALTER VIEW public.instancesXprotocols OWNER TO web_usr;

-- protocolsXinstances
DROP VIEW IF EXISTS public.protocolsXinstances CASCADE;
CREATE VIEW public.protocolsXinstances AS
SELECT DISTINCT
    ep.nd_protocol_id AS protocol_id,
    ef.file_id AS instance_id
FROM nd_experiment_protocol ep
JOIN phenome.nd_experiment_md_files ef ON ep.nd_experiment_id = ef.nd_experiment_id
GROUP BY 1, 2;
ALTER VIEW public.protocolsXinstances OWNER TO web_usr;

-- instancesXtrials
-- connects instances to trials via experiment chain
DROP VIEW IF EXISTS public.instancesXtrials CASCADE;
CREATE VIEW public.instancesXtrials AS
SELECT DISTINCT
    ef.file_id AS instance_id,
    ep.project_id AS trial_id
FROM phenome.nd_experiment_md_files ef
JOIN nd_experiment_project ep ON ef.nd_experiment_id = ep.nd_experiment_id
GROUP BY 1, 2;
ALTER VIEW public.instancesXtrials OWNER TO web_usr;

-- trialsXinstances
DROP VIEW IF EXISTS public.trialsXinstances CASCADE;
CREATE VIEW public.trialsXinstances AS
SELECT DISTINCT
    ep.project_id AS trial_id,
    ef.file_id AS instance_id
FROM nd_experiment_project ep
JOIN phenome.nd_experiment_md_files ef ON ep.nd_experiment_id = ef.nd_experiment_id
GROUP BY 1, 2;
ALTER VIEW public.trialsXinstances OWNER TO web_usr;

-- instancesXaccessions
-- connects instances to accessions via experiment stock chain
DROP VIEW IF EXISTS public.instancesXaccessions CASCADE;
CREATE VIEW public.instancesXaccessions AS
SELECT DISTINCT
    ef.file_id AS instance_id,
    stock.stock_id AS accession_id
FROM phenome.nd_experiment_md_files ef
JOIN nd_experiment_stock nes ON ef.nd_experiment_id = nes.nd_experiment_id
JOIN stock ON nes.stock_id = stock.stock_id
    AND stock.type_id = (SELECT cvterm_id FROM cvterm WHERE cvterm.name = 'accession')
GROUP BY 1, 2;
ALTER VIEW public.instancesXaccessions OWNER TO web_usr;

-- accessionsXinstances
DROP VIEW IF EXISTS public.accessionsXinstances CASCADE;
CREATE VIEW public.accessionsXinstances AS
SELECT DISTINCT
    stock.stock_id AS accession_id,
    ef.file_id AS instance_id
FROM nd_experiment_stock nes
JOIN stock ON nes.stock_id = stock.stock_id
    AND stock.type_id = (SELECT cvterm_id FROM cvterm WHERE cvterm.name = 'accession')
JOIN phenome.nd_experiment_md_files ef ON nes.nd_experiment_id = ef.nd_experiment_id
GROUP BY 1, 2;
ALTER VIEW public.accessionsXinstances OWNER TO web_usr;

-- instancesXtissue_sample
DROP VIEW IF EXISTS public.instancesXtissue_sample CASCADE;
CREATE VIEW public.instancesXtissue_sample AS
SELECT DISTINCT
    ef.file_id AS instance_id,
    nes.stock_id AS tissue_sample_id
FROM phenome.nd_experiment_md_files ef
JOIN nd_experiment_stock nes ON ef.nd_experiment_id = nes.nd_experiment_id
JOIN stock ON nes.stock_id = stock.stock_id
    AND stock.type_id = (SELECT cvterm_id FROM cvterm WHERE cvterm.name = 'tissue_sample')
GROUP BY 1, 2;
ALTER VIEW public.instancesXtissue_sample OWNER TO web_usr;

-- tissue_sampleXinstances
DROP VIEW IF EXISTS public.tissue_sampleXinstances CASCADE;
CREATE VIEW public.tissue_sampleXinstances AS
SELECT DISTINCT
    nes.stock_id AS tissue_sample_id,
    ef.file_id AS instance_id
FROM nd_experiment_stock nes
JOIN stock ON nes.stock_id = stock.stock_id
    AND stock.type_id = (SELECT cvterm_id FROM cvterm WHERE cvterm.name = 'tissue_sample')
JOIN phenome.nd_experiment_md_files ef ON nes.nd_experiment_id = ef.nd_experiment_id
GROUP BY 1, 2;
ALTER VIEW public.tissue_sampleXinstances OWNER TO web_usr;

-- instancesXbreeding_programs
-- connects instances to breeding programs via trial chain in matview
DROP VIEW IF EXISTS public.instancesXbreeding_programs CASCADE;
CREATE VIEW public.instancesXbreeding_programs AS
SELECT DISTINCT
    ef.file_id AS instance_id,
    mpv.breeding_program_id
FROM phenome.nd_experiment_md_files ef
JOIN nd_experiment_project ep ON ef.nd_experiment_id = ep.nd_experiment_id
JOIN public.materialized_phenoview mpv ON ep.project_id = mpv.trial_id
WHERE mpv.breeding_program_id IS NOT NULL
GROUP BY 1, 2;
ALTER VIEW public.instancesXbreeding_programs OWNER TO web_usr;

-- breeding_programsXinstances
DROP VIEW IF EXISTS public.breeding_programsXinstances CASCADE;
CREATE VIEW public.breeding_programsXinstances AS
SELECT DISTINCT
    mpv.breeding_program_id,
    ef.file_id AS instance_id
FROM public.materialized_phenoview mpv
JOIN nd_experiment_project ep ON mpv.trial_id = ep.project_id
JOIN phenome.nd_experiment_md_files ef ON ep.nd_experiment_id = ef.nd_experiment_id
WHERE mpv.breeding_program_id IS NOT NULL
GROUP BY 1, 2;
ALTER VIEW public.breeding_programsXinstances OWNER TO web_usr;

-- instancesXlocations
-- connects instances to locations via trial chain in matview
DROP VIEW IF EXISTS public.instancesXlocations CASCADE;
CREATE VIEW public.instancesXlocations AS
SELECT DISTINCT
    ef.file_id AS instance_id,
    mpv.location_id
FROM phenome.nd_experiment_md_files ef
JOIN nd_experiment_project ep ON ef.nd_experiment_id = ep.nd_experiment_id
JOIN public.materialized_phenoview mpv ON ep.project_id = mpv.trial_id
WHERE mpv.location_id IS NOT NULL
GROUP BY 1, 2;
ALTER VIEW public.instancesXlocations OWNER TO web_usr;

-- locationsXinstances
DROP VIEW IF EXISTS public.locationsXinstances CASCADE;
CREATE VIEW public.locationsXinstances AS
SELECT DISTINCT
    mpv.location_id,
    ef.file_id AS instance_id
FROM public.materialized_phenoview mpv
JOIN nd_experiment_project ep ON mpv.trial_id = ep.project_id
JOIN phenome.nd_experiment_md_files ef ON ep.nd_experiment_id = ef.nd_experiment_id
WHERE mpv.location_id IS NOT NULL
GROUP BY 1, 2;
ALTER VIEW public.locationsXinstances OWNER TO web_usr;

-- instancesXyears
-- connects instances to years via trial chain in matview
DROP VIEW IF EXISTS public.instancesXyears CASCADE;
CREATE VIEW public.instancesXyears AS
SELECT DISTINCT
    ef.file_id AS instance_id,
    mpv.year_id
FROM phenome.nd_experiment_md_files ef
JOIN nd_experiment_project ep ON ef.nd_experiment_id = ep.nd_experiment_id
JOIN public.materialized_phenoview mpv ON ep.project_id = mpv.trial_id
WHERE mpv.year_id IS NOT NULL
GROUP BY 1, 2;
ALTER VIEW public.instancesXyears OWNER TO web_usr;

-- yearsXinstances
DROP VIEW IF EXISTS public.yearsXinstances CASCADE;
CREATE VIEW public.yearsXinstances AS
SELECT DISTINCT
    mpv.year_id,
    ef.file_id AS instance_id
FROM public.materialized_phenoview mpv
JOIN nd_experiment_project ep ON mpv.trial_id = ep.project_id
JOIN phenome.nd_experiment_md_files ef ON ep.nd_experiment_id = ef.nd_experiment_id
WHERE mpv.year_id IS NOT NULL
GROUP BY 1, 2;
ALTER VIEW public.yearsXinstances OWNER TO web_usr;

-- instancesXtraits
-- connects instances to traits via phenotype observations in same experiment
DROP VIEW IF EXISTS public.instancesXtraits CASCADE;
CREATE VIEW public.instancesXtraits AS
SELECT DISTINCT
    ef.file_id AS instance_id,
    phenotype.cvalue_id AS trait_id
FROM phenome.nd_experiment_md_files ef
JOIN nd_experiment_phenotype nep ON ef.nd_experiment_id = nep.nd_experiment_id
JOIN phenotype ON nep.phenotype_id = phenotype.phenotype_id
WHERE phenotype.cvalue_id IS NOT NULL
GROUP BY 1, 2;
ALTER VIEW public.instancesXtraits OWNER TO web_usr;

-- traitsXinstances
DROP VIEW IF EXISTS public.traitsXinstances CASCADE;
CREATE VIEW public.traitsXinstances AS
SELECT DISTINCT
    phenotype.cvalue_id AS trait_id,
    ef.file_id AS instance_id
FROM nd_experiment_phenotype nep
JOIN phenotype ON nep.phenotype_id = phenotype.phenotype_id
JOIN phenome.nd_experiment_md_files ef ON nep.nd_experiment_id = ef.nd_experiment_id
WHERE phenotype.cvalue_id IS NOT NULL
GROUP BY 1, 2;
ALTER VIEW public.traitsXinstances OWNER TO web_usr;

-- instancesXorganisms
-- connects instances to organisms via stock in the experiment
DROP VIEW IF EXISTS public.instancesXorganisms CASCADE;
CREATE VIEW public.instancesXorganisms AS
SELECT DISTINCT
    ef.file_id AS instance_id,
    stock.organism_id
FROM phenome.nd_experiment_md_files ef
JOIN nd_experiment_stock nes ON ef.nd_experiment_id = nes.nd_experiment_id
JOIN stock ON nes.stock_id = stock.stock_id
WHERE stock.organism_id IS NOT NULL
GROUP BY 1, 2;
ALTER VIEW public.instancesXorganisms OWNER TO web_usr;

-- organismsXinstances
DROP VIEW IF EXISTS public.organismsXinstances CASCADE;
CREATE VIEW public.organismsXinstances AS
SELECT DISTINCT
    stock.organism_id,
    ef.file_id AS instance_id
FROM nd_experiment_stock nes
JOIN stock ON nes.stock_id = stock.stock_id
JOIN phenome.nd_experiment_md_files ef ON nes.nd_experiment_id = ef.nd_experiment_id
WHERE stock.organism_id IS NOT NULL
GROUP BY 1, 2;
ALTER VIEW public.organismsXinstances OWNER TO web_usr;

EOSQL

print "You're done!\n";
}

####
1; #
####