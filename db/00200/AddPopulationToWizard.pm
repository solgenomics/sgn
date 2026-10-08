#!/usr/bin/env perl


=head1 NAME

AddPopulationToWizard.pm


=head1 SYNOPSIS

mx-run AddPopulationUser [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch:
 - Add populations to materilized view

=head1 AUTHOR

Chris Simoes <ccs263@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

package AddPopulationToWizard;

use Moose;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch updates the materialized_phenoview by adding tissue sample to the view


sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    $self->dbh->do(<<EOSQL);
--do your SQL here

-- ADDING Populations searh --

DROP VIEW IF EXISTS public.populations CASCADE;
CREATE VIEW public.populations AS
  SELECT stock.stock_id AS population_id,
  stock.uniquename AS population_name
  FROM stock
  WHERE stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'population') AND is_obsolete = 'f'
  GROUP BY 1,2;
ALTER VIEW populations OWNER TO web_usr;

DROP VIEW IF EXISTS public.accessionsXpopulations CASCADE;
CREATE VIEW public.accessionsXpopulations AS
SELECT s2.stock_id as accession_id,
    stock.stock_id AS population_id
   FROM stock
   JOIN stock_relationship sr on sr.object_id = stock.stock_id
   JOIN stock s2 on s2.stock_id = sr.subject_id
   WHERE stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'population') AND stock.is_obsolete = 'f'
   AND s2.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'accession') AND s2.is_obsolete = 'f'
  GROUP BY 1,2;
ALTER VIEW public.accessionsXpopulations OWNER TO web_usr;

DROP VIEW IF EXISTS public.populationsXaccessions_ids CASCADE;
CREATE VIEW public.populationsXaccessions_ids AS
SELECT ap.population_id,
    stock.stock_id AS accessions_id_id
   FROM accessionsXpopulations ap
   join stock on stock.stock_id = ap.accession_id
   WHERE stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'accession') AND is_obsolete = 'f'
  GROUP BY 1,2;
ALTER VIEW public.populationsXaccessions_ids OWNER TO web_usr;

DROP VIEW IF EXISTS public.populationsXseedlots CASCADE;
CREATE VIEW public.populationsXseedlots AS
SELECT ap.population_id,
    s.stock_id as seedlot_id
FROM accessionsXpopulations ap
JOIN stock_relationship sr on sr.subject_id = ap.accession_id
JOIN stock s on s.stock_id = sr.object_id 
WHERE sr.type_id = (SELECT cvterm_id FROM cvterm WHERE cvterm.name = 'collection_of')
AND s.type_id = (SELECT cvterm_id FROM cvterm WHERE cvterm.name = 'seedlot')
GROUP BY 1,2;
ALTER VIEW public.populationsXseedlots OWNER TO web_usr;

DROP VIEW IF EXISTS public.breeding_programsXpopulations CASCADE;
CREATE VIEW public.breeding_programsXpopulations AS
SELECT mp.breeding_program_id,
       ap.population_id
   from accessionsXpopulations ap 
   join public.materialized_phenoview mp on mp.accession_id = ap.accession_id
  GROUP BY 1,2;
ALTER VIEW public.breeding_programsXpopulations OWNER TO web_usr;

DROP VIEW IF EXISTS public.genotyping_protocolsXpopulations CASCADE;
CREATE VIEW public.genotyping_protocolsXpopulations AS
SELECT ap.population_id,
    mg.genotyping_protocol_id
   FROM public.accessionsXpopulations ap
   JOIN public.materialized_genoview mg on mg.accession_id = ap.accession_id
  GROUP BY 1,2;
 ALTER VIEW public.genotyping_protocolsXpopulations OWNER TO web_usr;

DROP VIEW IF EXISTS public.populationsXlocations CASCADE;
CREATE VIEW public.populationsXlocations AS
select ap.population_id, 
    mp.location_id
   FROM public.accessionsXpopulations ap
   join public.materialized_phenoview mp on mp.accession_id = ap.accession_id
  GROUP BY 1,2;
  ALTER VIEW populationsXlocations OWNER TO web_usr;

DROP VIEW IF EXISTS public.populationsXplants CASCADE;
CREATE VIEW public.populationsXplants AS
SELECT ap.population_id, 
    public.stock.stock_id AS plant_id
   FROM public.accessionsXpopulations ap 
   JOIN public.materialized_phenoview on public.materialized_phenoview.accession_id = ap.accession_id
   JOIN  public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plant'))
  GROUP BY 1,2;
  ALTER VIEW public.populationsXplants OWNER TO web_usr;

DROP VIEW IF EXISTS public.populationsXtissue_sample CASCADE;
CREATE VIEW public.populationsXtissue_sample AS
select ap.population_id, 
    public.stock.stock_id AS tissue_sample_id
   FROM public.accessionsXpopulations ap
   join public.materialized_phenoview on public.materialized_phenoview.accession_id = ap.accession_id 
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'tissue_sample'))
  GROUP BY 1,2;
ALTER view populationsXtissue_sample OWNER TO web_usr;

DROP VIEW IF EXISTS public.populationsXplots CASCADE;
CREATE VIEW public.populationsXplots AS
SELECT ap.population_id,
    public.stock.stock_id AS plot_id
   FROM public.accessionsxpopulations ap
   join public.materialized_phenoview on public.materialized_phenoview.accession_id = ap.accession_id
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'plot'))
  GROUP BY 1,2;
ALTER VIEW public.populationsXplots OWNER TO web_usr;

DROP VIEW IF EXISTS public.populationsXsubplots CASCADE;
CREATE VIEW public.populationsXsubplots AS
SELECT ap.population_id,
    public.stock.stock_id AS subplot_id
   FROM public.accessionsXpopulations ap
   join public.materialized_phenoview on public.materialized_phenoview.accession_id = ap.accession_id
   JOIN public.stock ON(public.materialized_phenoview.stock_id = public.stock.stock_id AND public.stock.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'subplot'))
  GROUP BY 1,2;
ALTER VIEW public.populationsXsubplots OWNER TO web_usr;

DROP VIEW IF EXISTS public.populationsXtrial_designs CASCADE;
CREATE VIEW public.populationsXtrial_designs AS
SELECT ap.population_id,
    trialdesign.value AS trial_design_id
   FROM public.accessionsXpopulations ap
   join public.materialized_phenoview on public.materialized_phenoview.accession_id = ap.accession_id
   JOIN public.projectprop trialdesign ON materialized_phenoview.trial_id = trialdesign.project_id AND trialdesign.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'design' )
  GROUP BY 1,2;
ALTER VIEW public.populationsXtrial_designs OWNER TO web_usr;

DROP VIEW IF EXISTS public.populationsXtrial_types CASCADE;
CREATE VIEW public.populationsXtrial_types AS
SELECT ap.population_id,
    trialterm.cvterm_id AS trial_type_id
   FROM public.accessionsXpopulations ap
   join public.materialized_phenoview on public.materialized_phenoview.accession_id = ap.accession_id
   JOIN projectprop trialprop ON materialized_phenoview.trial_id = trialprop.project_id AND trialprop.type_id IN (SELECT cvterm_id from cvterm JOIN cv USING(cv_id) WHERE cv.name = 'project_type' )
   JOIN cvterm trialterm ON trialprop.type_id = trialterm.cvterm_id
  GROUP BY 1,2;
ALTER VIEW public.populationsXtrial_types OWNER TO web_usr;

DROP VIEW IF EXISTS public.populationsXtrials CASCADE;
CREATE VIEW public.populationsXtrials AS
SELECT ap.population_id,
    public.materialized_phenoview.trial_id
   FROM public.accessionsxpopulations ap
   join public.materialized_phenoview on public.materialized_phenoview.accession_id = ap.accession_id
  GROUP BY 1,2;
ALTER VIEW public.populationsXtrials OWNER TO web_usr;

DROP VIEW IF EXISTS public.populationsXyears CASCADE;
CREATE VIEW public.populationsXyears AS
SELECT ap.population_id,
      public.materialized_phenoview.year_id
   FROM public.accessionsXpopulations ap
   join public.materialized_phenoview on public.materialized_phenoview.accession_id = ap.accession_id
  GROUP BY 1,2;
ALTER VIEW public.populationsXyears OWNER TO web_usr;

DROP VIEW IF EXISTS public.populationsXgenotyping_projects CASCADE;
CREATE VIEW public.populationsXgenotyping_projects AS 
    SELECT ap.population_id,
           genotyping_project_id
    FROM public.accessionsXpopulations ap
    join materialized_genoview on materialized_genoview.accession_id = ap.accession_id
    GROUP BY 1,2;
ALTER VIEW public.populationsXgenotyping_projects OWNER TO web_usr;

DROP VIEW IF EXISTS public.populationsXorganisms CASCADE;
CREATE VIEW public.populationsXorganisms AS
select ap.population_id,
       s.organism_id
from public.accessionsXpopulations ap
join stock s on s.stock_id = ap.accession_id
group by 1,2;
ALTER VIEW public.populationsXorganisms OWNER TO web_usr;


DROP VIEW IF EXISTS public.populationsXtraits CASCADE;
CREATE VIEW public.populationsXtraits as
SELECT ap.population_id,
    public.materialized_phenoview.trait_id
   FROM public.accessionsXpopulations ap
   join public.materialized_phenoview on public.materialized_phenoview.accession_id = ap.accession_id
  GROUP BY 1,2;
ALTER VIEW public.populationsXtraits OWNER TO web_usr;

DROP VIEW IF EXISTS public.populationsXtrait_components CASCADE;
CREATE VIEW public.populationsXtrait_components AS
SELECT ap.population_id,
    trait_component.cvterm_id AS trait_component_id
   FROM public.accessionsXpopulations ap
   join public.materialized_phenoview on public.materialized_phenoview.accession_id = ap.accession_id
   JOIN cvterm trait ON(materialized_phenoview.trait_id = trait.cvterm_id)
   JOIN cvterm_relationship ON(trait.cvterm_id = cvterm_relationship.object_id AND cvterm_relationship.type_id = (SELECT cvterm_id from cvterm where name = 'contains'))
   JOIN cvterm trait_component ON(cvterm_relationship.subject_id = trait_component.cvterm_id)
  GROUP BY 1,2;
ALTER VIEW public.populationsXtrait_components OWNER TO web_usr;

-- ADDING User --



EOSQL

print "You're done!\n";
}


####
1; #
####