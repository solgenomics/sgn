#!/usr/bin/env perl

=head1 NAME

AddProtocolToMaterializedViews.pm

=head1 SYNOPSIS

mx-run AddProtocolToMaterializedViews [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch:
- Adds a new protocols view based on nd_protocol
- Adds cross-reference views between protocols and other search wizard categories

=head1 AUTHOR

Ben Maza

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

package AddProtocolToMaterializedViews;

use Moose;
extends 'CXGN::Metadata::Dbpatch';

has '+description' => ( default => <<'' );
This patch adds HDP protocol to the search wizard materialized views

sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    $self->dbh->do(<<EOSQL);
--do your SQL here

-- Add protocols view
DROP VIEW IF EXISTS public.protocols CASCADE;
CREATE VIEW public.protocols AS
SELECT
    nd_protocol.nd_protocol_id AS protocol_id,
    nd_protocol.name AS protocol_name
FROM nd_protocol
GROUP BY nd_protocol.nd_protocol_id, nd_protocol.name;
ALTER VIEW public.protocols OWNER TO web_usr;

-- accessionsXprotocols
DROP VIEW IF EXISTS public.accessionsXprotocols CASCADE;
CREATE VIEW public.accessionsXprotocols AS
SELECT DISTINCT
    stock.stock_id AS accession_id,
    nd_experiment_protocol.nd_protocol_id AS protocol_id
FROM stock
JOIN cvterm stock_type ON stock_type.cvterm_id = stock.type_id AND stock_type.name = 'accession'
JOIN nd_experiment_stock ON stock.stock_id = nd_experiment_stock.stock_id
JOIN nd_experiment_protocol ON nd_experiment_stock.nd_experiment_id = nd_experiment_protocol.nd_experiment_id
GROUP BY 1, 2;
ALTER VIEW public.accessionsXprotocols OWNER TO web_usr;

-- breeding_programsXprotocols
DROP VIEW IF EXISTS public.breeding_programsXprotocols CASCADE;
CREATE VIEW public.breeding_programsXprotocols AS
SELECT DISTINCT
    public.materialized_phenoview.breeding_program_id,
    nd_experiment_protocol.nd_protocol_id AS protocol_id
FROM public.materialized_phenoview
JOIN nd_experiment_project ON materialized_phenoview.trial_id = nd_experiment_project.project_id
JOIN nd_experiment_protocol ON nd_experiment_project.nd_experiment_id = nd_experiment_protocol.nd_experiment_id
GROUP BY 1, 2;
ALTER VIEW public.breeding_programsXprotocols OWNER TO web_usr;

-- locationsXprotocols
DROP VIEW IF EXISTS public.locationsXprotocols CASCADE;
CREATE VIEW public.locationsXprotocols AS
SELECT DISTINCT
    public.materialized_phenoview.location_id,
    nd_experiment_protocol.nd_protocol_id AS protocol_id
FROM public.materialized_phenoview
JOIN nd_experiment_project ON materialized_phenoview.trial_id = nd_experiment_project.project_id
JOIN nd_experiment_protocol ON nd_experiment_project.nd_experiment_id = nd_experiment_protocol.nd_experiment_id
GROUP BY 1, 2;
ALTER VIEW public.locationsXprotocols OWNER TO web_usr;

-- trialsXprotocols
DROP VIEW IF EXISTS public.trialsXprotocols CASCADE;
CREATE VIEW public.trialsXprotocols AS
SELECT DISTINCT
    nd_experiment_project.project_id AS trial_id,
    nd_experiment_protocol.nd_protocol_id AS protocol_id
FROM nd_experiment_project
JOIN nd_experiment_protocol ON nd_experiment_project.nd_experiment_id = nd_experiment_protocol.nd_experiment_id
GROUP BY 1, 2;
ALTER VIEW public.trialsXprotocols OWNER TO web_usr;

-- protocolsXtrials  <- ADDED
DROP VIEW IF EXISTS public.protocolsXtrials CASCADE;
CREATE VIEW public.protocolsXtrials AS
SELECT DISTINCT
    nd_experiment_protocol.nd_protocol_id AS protocol_id,
    nd_experiment_project.project_id AS trial_id
FROM nd_experiment_protocol
JOIN nd_experiment_project ON nd_experiment_protocol.nd_experiment_id = nd_experiment_project.nd_experiment_id
GROUP BY 1, 2;
ALTER VIEW public.protocolsXtrials OWNER TO web_usr;

-- yearsXprotocols
DROP VIEW IF EXISTS public.yearsXprotocols CASCADE;
CREATE VIEW public.yearsXprotocols AS
SELECT DISTINCT
    public.materialized_phenoview.year_id,
    nd_experiment_protocol.nd_protocol_id AS protocol_id
FROM public.materialized_phenoview
JOIN nd_experiment_project ON materialized_phenoview.trial_id = nd_experiment_project.project_id
JOIN nd_experiment_protocol ON nd_experiment_project.nd_experiment_id = nd_experiment_protocol.nd_experiment_id
GROUP BY 1, 2;
ALTER VIEW public.yearsXprotocols OWNER TO web_usr;

-- protocolsXtraits
DROP VIEW IF EXISTS public.protocolsXtraits CASCADE;
CREATE VIEW public.protocolsXtraits AS
SELECT DISTINCT
    nd_experiment_protocol.nd_protocol_id AS protocol_id,
    phenotype.cvalue_id AS trait_id
FROM nd_experiment_protocol
JOIN nd_experiment_phenotype ON nd_experiment_protocol.nd_experiment_id = nd_experiment_phenotype.nd_experiment_id
JOIN phenotype ON nd_experiment_phenotype.phenotype_id = phenotype.phenotype_id
GROUP BY 1, 2;
ALTER VIEW public.protocolsXtraits OWNER TO web_usr;

-- protocolsXtrait_components
DROP VIEW IF EXISTS public.protocolsXtrait_components CASCADE;
CREATE VIEW public.protocolsXtrait_components AS
SELECT DISTINCT
    nd_experiment_protocol.nd_protocol_id AS protocol_id,
    trait_component.cvterm_id AS trait_component_id
FROM nd_experiment_protocol
JOIN nd_experiment_phenotype ON nd_experiment_protocol.nd_experiment_id = nd_experiment_phenotype.nd_experiment_id
JOIN phenotype ON nd_experiment_phenotype.phenotype_id = phenotype.phenotype_id
JOIN cvterm trait ON phenotype.cvalue_id = trait.cvterm_id
JOIN cvterm_relationship ON trait.cvterm_id = cvterm_relationship.object_id
    AND cvterm_relationship.type_id = (SELECT cvterm_id FROM cvterm WHERE name = 'contains')
JOIN cvterm trait_component ON cvterm_relationship.subject_id = trait_component.cvterm_id
GROUP BY 1, 2;
ALTER VIEW public.protocolsXtrait_components OWNER TO web_usr;

-- protocolsXtrial_designs
DROP VIEW IF EXISTS public.protocolsXtrial_designs CASCADE;
CREATE VIEW public.protocolsXtrial_designs AS
SELECT DISTINCT
    nd_experiment_protocol.nd_protocol_id AS protocol_id,
    trialdesign.value AS trial_design_id
FROM nd_experiment_protocol
JOIN nd_experiment_project ON nd_experiment_protocol.nd_experiment_id = nd_experiment_project.nd_experiment_id
JOIN projectprop trialdesign ON nd_experiment_project.project_id = trialdesign.project_id
    AND trialdesign.type_id = (SELECT cvterm_id FROM cvterm WHERE cvterm.name = 'design')
GROUP BY 1, 2;
ALTER VIEW public.protocolsXtrial_designs OWNER TO web_usr;

-- protocolsXtrial_types
DROP VIEW IF EXISTS public.protocolsXtrial_types CASCADE;
CREATE VIEW public.protocolsXtrial_types AS
SELECT DISTINCT
    nd_experiment_protocol.nd_protocol_id AS protocol_id,
    trialterm.cvterm_id AS trial_type_id
FROM nd_experiment_protocol
JOIN nd_experiment_project ON nd_experiment_protocol.nd_experiment_id = nd_experiment_project.nd_experiment_id
JOIN projectprop trialprop ON nd_experiment_project.project_id = trialprop.project_id
    AND trialprop.type_id IN (SELECT cvterm_id FROM cvterm JOIN cv USING(cv_id) WHERE cv.name = 'project_type')
JOIN cvterm trialterm ON trialprop.type_id = trialterm.cvterm_id
GROUP BY 1, 2;
ALTER VIEW public.protocolsXtrial_types OWNER TO web_usr;

-- protocolsXplots
DROP VIEW IF EXISTS public.protocolsXplots CASCADE;
CREATE VIEW public.protocolsXplots AS
SELECT DISTINCT
    nd_experiment_protocol.nd_protocol_id AS protocol_id,
    nd_experiment_stock.stock_id AS plot_id
FROM nd_experiment_protocol
JOIN nd_experiment_stock ON nd_experiment_protocol.nd_experiment_id = nd_experiment_stock.nd_experiment_id
JOIN stock ON nd_experiment_stock.stock_id = stock.stock_id
    AND stock.type_id = (SELECT cvterm_id FROM cvterm WHERE cvterm.name = 'plot')
GROUP BY 1, 2;
ALTER VIEW public.protocolsXplots OWNER TO web_usr;

-- protocolsXplants
DROP VIEW IF EXISTS public.protocolsXplants CASCADE;
CREATE VIEW public.protocolsXplants AS
SELECT DISTINCT
    nd_experiment_protocol.nd_protocol_id AS protocol_id,
    nd_experiment_stock.stock_id AS plant_id
FROM nd_experiment_protocol
JOIN nd_experiment_stock ON nd_experiment_protocol.nd_experiment_id = nd_experiment_stock.nd_experiment_id
JOIN stock ON nd_experiment_stock.stock_id = stock.stock_id
    AND stock.type_id = (SELECT cvterm_id FROM cvterm WHERE cvterm.name = 'plant')
GROUP BY 1, 2;
ALTER VIEW public.protocolsXplants OWNER TO web_usr;

-- protocolsXsubplots
DROP VIEW IF EXISTS public.protocolsXsubplots CASCADE;
CREATE VIEW public.protocolsXsubplots AS
SELECT DISTINCT
    nd_experiment_protocol.nd_protocol_id AS protocol_id,
    nd_experiment_stock.stock_id AS subplot_id
FROM nd_experiment_protocol
JOIN nd_experiment_stock ON nd_experiment_protocol.nd_experiment_id = nd_experiment_stock.nd_experiment_id
JOIN stock ON nd_experiment_stock.stock_id = stock.stock_id
    AND stock.type_id = (SELECT cvterm_id FROM cvterm WHERE cvterm.name = 'subplot')
GROUP BY 1, 2;
ALTER VIEW public.protocolsXsubplots OWNER TO web_usr;

-- protocolsXtissue_sample
DROP VIEW IF EXISTS public.protocolsXtissue_sample CASCADE;
CREATE VIEW public.protocolsXtissue_sample AS
SELECT DISTINCT
    nd_experiment_protocol.nd_protocol_id AS protocol_id,
    nd_experiment_stock.stock_id AS tissue_sample_id
FROM nd_experiment_protocol
JOIN nd_experiment_stock ON nd_experiment_protocol.nd_experiment_id = nd_experiment_stock.nd_experiment_id
JOIN stock ON nd_experiment_stock.stock_id = stock.stock_id
    AND stock.type_id = (SELECT cvterm_id FROM cvterm WHERE cvterm.name = 'tissue_sample')
GROUP BY 1, 2;
ALTER VIEW public.protocolsXtissue_sample OWNER TO web_usr;

-- protocolsXseedlots
DROP VIEW IF EXISTS public.protocolsXseedlots CASCADE;
CREATE VIEW public.protocolsXseedlots AS
SELECT DISTINCT
    nd_experiment_protocol.nd_protocol_id AS protocol_id,
    seedlot.stock_id AS seedlot_id
FROM nd_experiment_protocol
JOIN nd_experiment_stock ON nd_experiment_protocol.nd_experiment_id = nd_experiment_stock.nd_experiment_id
JOIN stock_relationship seedlot_relationship ON nd_experiment_stock.stock_id = seedlot_relationship.subject_id
    AND seedlot_relationship.type_id IN (SELECT cvterm_id FROM cvterm WHERE cvterm.name = 'collection_of')
JOIN stock seedlot ON seedlot_relationship.object_id = seedlot.stock_id
    AND seedlot.type_id IN (SELECT cvterm_id FROM cvterm WHERE cvterm.name = 'seedlot')
GROUP BY 1, 2;
ALTER VIEW public.protocolsXseedlots OWNER TO web_usr;

-- protocolsXorganisms
DROP VIEW IF EXISTS public.protocolsXorganisms CASCADE;
CREATE VIEW public.protocolsXorganisms AS
SELECT DISTINCT
    nd_experiment_protocol.nd_protocol_id AS protocol_id,
    stock.organism_id
FROM nd_experiment_protocol
JOIN nd_experiment_stock ON nd_experiment_protocol.nd_experiment_id = nd_experiment_stock.nd_experiment_id
JOIN stock ON nd_experiment_stock.stock_id = stock.stock_id
WHERE stock.organism_id IS NOT NULL
GROUP BY 1, 2;
ALTER VIEW public.protocolsXorganisms OWNER TO web_usr;

-- protocolsXgenotyping_protocols
DROP VIEW IF EXISTS public.protocolsXgenotyping_protocols CASCADE;
CREATE VIEW public.protocolsXgenotyping_protocols AS
SELECT DISTINCT
    nd_experiment_protocol.nd_protocol_id AS protocol_id,
    public.materialized_genoview.genotyping_protocol_id
FROM nd_experiment_protocol
JOIN nd_experiment_stock ON nd_experiment_protocol.nd_experiment_id = nd_experiment_stock.nd_experiment_id
JOIN public.materialized_genoview ON nd_experiment_stock.stock_id = public.materialized_genoview.accession_id
GROUP BY 1, 2;
ALTER VIEW public.protocolsXgenotyping_protocols OWNER TO web_usr;

-- protocolsXgenotyping_projects
DROP VIEW IF EXISTS public.protocolsXgenotyping_projects CASCADE;
CREATE VIEW public.protocolsXgenotyping_projects AS
SELECT DISTINCT
    nd_experiment_protocol.nd_protocol_id AS protocol_id,
    public.materialized_genoview.genotyping_project_id
FROM nd_experiment_protocol
JOIN nd_experiment_stock ON nd_experiment_protocol.nd_experiment_id = nd_experiment_stock.nd_experiment_id
JOIN public.materialized_genoview ON nd_experiment_stock.stock_id = public.materialized_genoview.accession_id
GROUP BY 1, 2;
ALTER VIEW public.protocolsXgenotyping_projects OWNER TO web_usr;

EOSQL

print "You're done!\n";
}

####
1; #
####