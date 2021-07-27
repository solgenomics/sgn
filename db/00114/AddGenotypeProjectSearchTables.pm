#!/usr/bin/env perl


=head1 NAME

 AddGenotypeProjectSearchTables.pm

=head1 SYNOPSIS

mx-run AddGenotypeProjectSearchTables [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch adds materialized views related to genotyping projects for the search wizard.

=head1 AUTHOR

David Waring<djw64@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddGenotypeProjectSearchTables;

use Moose;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch adds materialized views related to genotyping projects for the search wizard

sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    $self->dbh->do(<<EOSQL);

-- ADD genotyping_projects

DROP MATERIALIZED VIEW IF EXISTS public.genotyping_projects CASCADE;
CREATE MATERIALIZED VIEW public.genotyping_projects AS 
 SELECT project.project_id AS genotyping_project_id,
    project.name AS genotyping_project_name
   FROM (project
     JOIN projectprop USING (project_id))
  WHERE ((projectprop.type_id = ( SELECT cvterm.cvterm_id
           FROM cvterm
          WHERE ((cvterm.name)::text = 'design'::text))) AND (projectprop.value = 'genotype_data_project'::text))
  GROUP BY project.project_id, project.name
 WITH DATA;
CREATE UNIQUE INDEX genotyping_projects_idx ON public.genotyping_projects(genotyping_project_id, genotyping_project_name) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.genotyping_projects OWNER TO web_usr;


-- ADD accessionsxgenotyping_projects

DROP MATERIALIZED VIEW IF EXISTS public.accessionsxgenotyping_projects CASCADE;
CREATE MATERIALIZED VIEW public.accessionsxgenotyping_projects AS
 SELECT accessions.accession_id,
    nd_experiment_project.project_id AS genotyping_project_id
   FROM (((accessions
     JOIN materialized_genoview ON ((accessions.accession_id = materialized_genoview.accession_id)))
     JOIN nd_experiment_genotype ON ((materialized_genoview.genotype_id = nd_experiment_genotype.genotype_id)))
     JOIN nd_experiment_project ON ((nd_experiment_genotype.nd_experiment_id = nd_experiment_project.nd_experiment_id)))
  WHERE (nd_experiment_project.project_id IN ( SELECT projectprop.project_id
           FROM projectprop
          WHERE ((projectprop.type_id = ( SELECT cvterm.cvterm_id
                   FROM cvterm
                  WHERE ((cvterm.name)::text = 'design'::text))) AND (projectprop.value = 'genotype_data_project'::text))))
  GROUP BY accessions.accession_id, genotyping_project_id
 WITH DATA;
CREATE UNIQUE INDEX accessionsxgenotyping_projects_idx ON public.accessionsxgenotyping_projects(accession_id, genotyping_project_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.accessionsxgenotyping_projects OWNER TO web_usr;


-- ADD breeding_programsxgenotyping_projects

DROP MATERIALIZED VIEW IF EXISTS public.breeding_programsxgenotyping_projects CASCADE;
CREATE MATERIALIZED VIEW public.breeding_programsxgenotyping_projects AS 
 SELECT breeding_programs.breeding_program_id,
    project_relationship.subject_project_id AS genotyping_project_id
   FROM (breeding_programs
     JOIN project_relationship ON ((breeding_programs.breeding_program_id = project_relationship.object_project_id)))
  WHERE ((project_relationship.type_id = ( SELECT cvterm.cvterm_id
           FROM cvterm
          WHERE ((cvterm.name)::text = 'breeding_program_trial_relationship'::text))) AND (project_relationship.subject_project_id IN ( SELECT genotyping_projects.genotyping_project_id
           FROM genotyping_projects)))
 WITH DATA;
CREATE UNIQUE INDEX breeding_programsxgenotyping_projects_idx ON public.breeding_programsxgenotyping_projects(breeding_program_id, genotyping_project_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.breeding_programsxgenotyping_projects OWNER TO web_usr;


-- ADD genotyping_protocolsxgenotyping_projects

DROP MATERIALIZED VIEW IF EXISTS public.genotyping_protocolsxgenotyping_projects CASCADE;
CREATE MATERIALIZED VIEW public.genotyping_protocolsxgenotyping_projects AS
 SELECT genotyping_protocols.genotyping_protocol_id,
    nd_experiment_project.project_id AS genotyping_project_id
   FROM ((genotyping_protocols
     JOIN nd_experiment_protocol ON ((genotyping_protocols.genotyping_protocol_id = nd_experiment_protocol.nd_protocol_id)))
     JOIN nd_experiment_project ON ((nd_experiment_protocol.nd_experiment_id = nd_experiment_project.nd_experiment_id)))
  GROUP BY genotyping_protocols.genotyping_protocol_id, nd_experiment_project.project_id
 WITH DATA;
CREATE UNIQUE INDEX genotyping_protocolsxgenotyping_projects_idx ON public.genotyping_protocolsxgenotyping_projects(genotyping_protocol_id, genotyping_project_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.genotyping_protocolsxgenotyping_projects OWNER TO web_usr;


-- ADD locationsxgenotyping_projects

DROP MATERIALIZED VIEW IF EXISTS public.locationsxgenotyping_projects CASCADE;
CREATE MATERIALIZED VIEW public.locationsxgenotyping_projects AS
 SELECT projectprop.value AS location_id,
    projectprop.project_id AS genotyping_project_id
   FROM projectprop
  WHERE ((projectprop.type_id = ( SELECT cvterm.cvterm_id
           FROM cvterm
          WHERE ((cvterm.name)::text = 'project location'::text))) AND (projectprop.value IN ( SELECT (locations.location_id)::text AS location_id
           FROM locations)) AND (projectprop.project_id IN ( SELECT project.project_id
           FROM (project
             JOIN projectprop projectprop_1 USING (project_id))
          WHERE ((projectprop_1.type_id = ( SELECT cvterm.cvterm_id
                   FROM cvterm
                  WHERE ((cvterm.name)::text = 'design'::text))) AND (projectprop_1.value = 'genotype_data_project'::text)))))
 WITH DATA;
CREATE UNIQUE INDEX locationsxgenotyping_projects_idx ON public.locationsxgenotyping_projects(location_id, genotyping_project_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.locationsxgenotyping_projects OWNER TO web_usr;


-- ADD trialsxgenotyping_projects

DROP MATERIALIZED VIEW IF EXISTS public.trialsxgenotyping_projects CASCADE;
CREATE MATERIALIZED VIEW public.trialsxgenotyping_projects AS
 SELECT trials.trial_id,
    nd_experiment_project.project_id AS genotyping_project_id
   FROM ((((trials
     JOIN materialized_phenoview ON ((trials.trial_id = materialized_phenoview.trial_id)))
     JOIN materialized_genoview ON ((materialized_phenoview.accession_id = materialized_genoview.accession_id)))
     JOIN nd_experiment_genotype ON ((materialized_genoview.genotype_id = nd_experiment_genotype.genotype_id)))
     JOIN nd_experiment_project ON ((nd_experiment_genotype.nd_experiment_id = nd_experiment_project.nd_experiment_id)))
  WHERE (nd_experiment_project.project_id IN ( SELECT projectprop.project_id
           FROM projectprop
          WHERE ((projectprop.type_id IN ( SELECT cvterm.cvterm_id
                   FROM cvterm
                  WHERE ((cvterm.name)::text = 'design'::text))) AND (projectprop.value = 'genotype_data_project'::text))))
  GROUP BY trials.trial_id, nd_experiment_project.project_id
 WITH DATA;
CREATE UNIQUE INDEX trialsxgenotyping_projects_idx ON public.trialsxgenotyping_projects(trial_id, genotyping_project_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.trialsxgenotyping_projects OWNER TO web_usr;


-- ADD genotyping_projectsxaccessions

DROP MATERIALIZED VIEW IF EXISTS public.genotyping_projectsxaccessions CASCADE;
CREATE MATERIALIZED VIEW public.genotyping_projectsxaccessions AS 
 SELECT nd_experiment_project.project_id AS genotyping_project_id,
    materialized_genoview.accession_id
   FROM ((nd_experiment_project
     JOIN nd_experiment_genotype ON ((nd_experiment_project.nd_experiment_id = nd_experiment_genotype.nd_experiment_id)))
     JOIN materialized_genoview ON ((nd_experiment_genotype.genotype_id = materialized_genoview.genotype_id)))
  WHERE (nd_experiment_project.project_id IN ( SELECT genotyping_projects.genotyping_project_id
           FROM genotyping_projects))
  GROUP BY genotyping_project_id, materialized_genoview.accession_id
 WITH DATA;
CREATE UNIQUE INDEX genotyping_projectsxaccessions_idx ON public.genotyping_projectsxaccessions(genotyping_project_id, accession_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.genotyping_projectsxaccessions OWNER TO web_usr;


-- ADD genotyping_projectsxbreeding_programs

DROP MATERIALIZED VIEW IF EXISTS public.genotyping_projectsxbreeding_programs CASCADE;
CREATE MATERIALIZED VIEW public.genotyping_projectsxbreeding_programs AS 
 SELECT project_relationship.subject_project_id AS genotyping_project_id,
    project_relationship.object_project_id AS breeding_program_id
   FROM project_relationship
  WHERE ((project_relationship.type_id = ( SELECT cvterm.cvterm_id
           FROM cvterm
          WHERE ((cvterm.name)::text = 'breeding_program_trial_relationship'::text))) AND (project_relationship.subject_project_id IN ( SELECT genotyping_projects.genotyping_project_id
           FROM genotyping_projects)))
 WITH DATA;
CREATE UNIQUE INDEX genotyping_projectsxbreeding_programs_idx ON public.genotyping_projectsxbreeding_programs(genotyping_project_id, breeding_program_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.genotyping_projectsxbreeding_programs OWNER TO web_usr;


-- ADD genotyping_projectsxgenotyping_protocols

DROP MATERIALIZED VIEW IF EXISTS public.genotyping_projectsxgenotyping_protocols CASCADE;
CREATE MATERIALIZED VIEW public.genotyping_projectsxgenotyping_protocols AS
 SELECT genotyping_projects.genotyping_project_id,
    nd_experiment_protocol.nd_protocol_id AS genotyping_protocol_id
   FROM ((genotyping_projects
     JOIN nd_experiment_project ON ((genotyping_projects.genotyping_project_id = nd_experiment_project.project_id)))
     JOIN nd_experiment_protocol ON ((nd_experiment_project.nd_experiment_id = nd_experiment_protocol.nd_experiment_id)))
     GROUP BY genotyping_projects.genotyping_project_id, nd_experiment_protocol.nd_protocol_id
 WITH DATA;
CREATE UNIQUE INDEX genotyping_projectsxgenotyping_protocols_idx ON public.genotyping_projectsxgenotyping_protocols(genotyping_project_id, genotyping_protocol_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.genotyping_projectsxgenotyping_protocols OWNER TO web_usr;


-- ADD genotyping_projectsxlocations

DROP MATERIALIZED VIEW IF EXISTS public.genotyping_projectsxlocations CASCADE;
CREATE MATERIALIZED VIEW public.genotyping_projectsxlocations AS 
 SELECT projectprop.project_id AS genotyping_project_id,
    (projectprop.value)::integer AS location_id
   FROM projectprop
  WHERE ((projectprop.type_id = ( SELECT cvterm.cvterm_id
           FROM cvterm
          WHERE ((cvterm.name)::text = 'project location'::text))) AND (projectprop.project_id IN ( SELECT genotyping_projects.genotyping_project_id
           FROM genotyping_projects)))
 WITH DATA;
CREATE UNIQUE INDEX genotyping_projectsxlocations_idx ON public.genotyping_projectsxlocations(genotyping_project_id, location_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.genotyping_projectsxlocations OWNER TO web_usr;


-- ADD genotyping_projectsxtraits

DROP MATERIALIZED VIEW IF EXISTS public.genotyping_projectsxtraits CASCADE;
CREATE MATERIALIZED VIEW public.genotyping_projectsxtraits AS
 SELECT nd_experiment_project.project_id AS genotyping_project_id,
    materialized_phenoview.trait_id
   FROM (((nd_experiment_project
     JOIN nd_experiment_genotype ON ((nd_experiment_genotype.nd_experiment_id = nd_experiment_project.nd_experiment_id)))
     JOIN materialized_genoview ON ((materialized_genoview.genotype_id = nd_experiment_genotype.genotype_id)))
     JOIN materialized_phenoview ON ((materialized_genoview.accession_id = materialized_phenoview.accession_id)))
  WHERE (nd_experiment_project.project_id IN ( SELECT projectprop.project_id
           FROM projectprop
          WHERE ((projectprop.type_id IN ( SELECT cvterm.cvterm_id
                   FROM cvterm
                  WHERE ((cvterm.name)::text = 'design'::text))) AND (projectprop.value = 'genotype_data_project'::text))))
  GROUP BY nd_experiment_project.project_id, materialized_phenoview.trait_id
 WITH DATA;
CREATE UNIQUE INDEX genotyping_projectsxtraits_idx ON public.genotyping_projectsxtraits(genotyping_project_id, trait_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.genotyping_projectsxtraits OWNER TO web_usr;


-- ADD genotyping_projectsxtrials

DROP MATERIALIZED VIEW IF EXISTS public.genotyping_projectsxtrials CASCADE;
CREATE MATERIALIZED VIEW public.genotyping_projectsxtrials AS
 SELECT nd_experiment_project.project_id AS genotyping_project_id,
    materialized_phenoview.trial_id
   FROM (((nd_experiment_project
     JOIN nd_experiment_genotype ON ((nd_experiment_genotype.nd_experiment_id = nd_experiment_project.nd_experiment_id)))
     JOIN materialized_genoview ON ((materialized_genoview.genotype_id = nd_experiment_genotype.genotype_id)))
     JOIN materialized_phenoview ON ((materialized_phenoview.accession_id = materialized_genoview.accession_id)))
  WHERE (nd_experiment_project.project_id IN ( SELECT projectprop.project_id
           FROM projectprop
          WHERE ((projectprop.type_id IN ( SELECT cvterm.cvterm_id
                   FROM cvterm
                  WHERE ((cvterm.name)::text = 'design'::text))) AND (projectprop.value = 'genotype_data_project'::text))))
  GROUP BY nd_experiment_project.project_id, materialized_phenoview.trial_id
 WITH DATA;
CREATE UNIQUE INDEX genotyping_projectsxtrials_idx ON public.genotyping_projectsxtrials(genotyping_project_id, trial_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.genotyping_projectsxtrials OWNER TO web_usr;


-- ADD genotyping_projectsxyears

DROP MATERIALIZED VIEW IF EXISTS public.genotyping_projectsxyears CASCADE;
CREATE MATERIALIZED VIEW public.genotyping_projectsxyears AS 
 SELECT projectprop.project_id AS genotyping_project_id,
    projectprop.value AS year_id
   FROM projectprop
  WHERE ((projectprop.project_id IN ( SELECT project.project_id
           FROM (project
             JOIN projectprop projectprop_1 USING (project_id))
          WHERE ((projectprop_1.type_id = ( SELECT cvterm.cvterm_id
                   FROM cvterm
                  WHERE ((cvterm.name)::text = 'design'::text))) AND (projectprop_1.value = 'genotype_data_project'::text)))) AND (projectprop.type_id = ( SELECT cvterm.cvterm_id
           FROM cvterm
          WHERE ((cvterm.name)::text = 'project year'::text))))
 WITH DATA;
CREATE UNIQUE INDEX genotyping_projectsxyears_idx ON public.genotyping_projectsxyears(genotyping_project_id, year_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.genotyping_projectsxyears OWNER TO web_usr;


-- UPDATE refresh_materialized_views function

CREATE OR REPLACE FUNCTION public.refresh_materialized_views()
 RETURNS void AS '
REFRESH MATERIALIZED VIEW public.materialized_phenoview;
REFRESH MATERIALIZED VIEW public.materialized_genoview;
REFRESH MATERIALIZED VIEW public.accessions;
REFRESH MATERIALIZED VIEW public.breeding_programs;
REFRESH MATERIALIZED VIEW public.genotyping_projects;
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
REFRESH MATERIALIZED VIEW public.accessionsxgenotyping_projects;
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
REFRESH MATERIALIZED VIEW public.breeding_programsxgenotyping_projects;
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
REFRESH MATERIALIZED VIEW public.genotyping_projectsxaccessions;
REFRESH MATERIALIZED VIEW public.genotyping_projectsxbreeding_programs;
REFRESH MATERIALIZED VIEW public.genotyping_projectsxgenotyping_protocols;
REFRESH MATERIALIZED VIEW public.genotyping_projectsxtraits;
REFRESH MATERIALIZED VIEW public.genotyping_projectsxtrials;
REFRESH MATERIALIZED VIEW public.genotyping_projectsxyears;
REFRESH MATERIALIZED VIEW public.genotyping_protocolsxgenotyping_projects;
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
REFRESH MATERIALIZED VIEW public.locationsxgenotyping_projects;
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
REFRESH MATERIALIZED VIEW public.seedlotsXtrait_components;
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
REFRESH MATERIALIZED VIEW public.trialsxgenotyping_projects;
REFRESH MATERIALIZED VIEW public.trialsXyears;
UPDATE public.matviews SET currently_refreshing=FALSE, last_refresh=CURRENT_TIMESTAMP;'
    LANGUAGE SQL;


-- UPDATE refresh_materialized_views_concurrently function

CREATE OR REPLACE FUNCTION public.refresh_materialized_views_concurrently()
 RETURNS void AS '
REFRESH MATERIALIZED VIEW CONCURRENTLY public.materialized_phenoview;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.materialized_genoview;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.accessions;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.breeding_programs;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.genotyping_projects;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.genotyping_protocols;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.locations;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.plants;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.plots;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.seedlots;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.trait_components;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.traits;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.trial_designs;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.trial_types;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.trials;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.years;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.accessionsXbreeding_programs;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.accessionsXlocations;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.accessionsxgenotyping_projects;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.accessionsXgenotyping_protocols;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.accessionsXplants;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.accessionsXplots;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.accessionsXseedlots;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.accessionsXtrait_components;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.accessionsXtraits;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.accessionsXtrial_designs;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.accessionsXtrial_types;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.accessionsXtrials;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.accessionsXyears;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.breeding_programsXlocations;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.breeding_programsxgenotyping_projects;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.breeding_programsXgenotyping_protocols;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.breeding_programsXplants;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.breeding_programsXplots;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.breeding_programsXseedlots;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.breeding_programsXtrait_components;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.breeding_programsXtraits;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.breeding_programsXtrial_designs;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.breeding_programsXtrial_types;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.breeding_programsXtrials;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.breeding_programsXyears;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.genotyping_projectsxaccessions;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.genotyping_projectsxbreeding_programs;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.genotyping_projectsxgenotyping_protocols;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.genotyping_projectsxtraits;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.genotyping_projectsxtrials;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.genotyping_projectsxyears;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.genotyping_protocolsxgenotyping_projects;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.genotyping_protocolsXlocations;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.genotyping_protocolsXplants;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.genotyping_protocolsXplots;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.genotyping_protocolsXseedlots;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.genotyping_protocolsXtrait_components;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.genotyping_protocolsXtraits;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.genotyping_protocolsXtrial_designs;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.genotyping_protocolsXtrial_types;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.genotyping_protocolsXtrials;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.genotyping_protocolsXyears;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.locationsxgenotyping_projects;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.locationsXplants;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.locationsXplots;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.locationsXseedlots;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.locationsXtrait_components;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.locationsXtraits;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.locationsXtrial_designs;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.locationsXtrial_types;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.locationsXtrials;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.locationsXyears;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.plantsXplots;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.plantsXseedlots;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.plantsXtrait_components;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.plantsXtraits;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.plantsXtrial_designs;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.plantsXtrial_types;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.plantsXtrials;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.plantsXyears;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.plotsXseedlots;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.plotsXtrait_components;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.plotsXtraits;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.plotsXtrial_designs;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.plotsXtrial_types;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.plotsXtrials;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.plotsXyears;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.seedlotsXtrait_components;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.seedlotsXtraits;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.seedlotsXtrial_designs;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.seedlotsXtrial_types;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.seedlotsXtrials;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.seedlotsXyears;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.trait_componentsXtraits;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.trait_componentsXtrial_designs;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.trait_componentsXtrial_types;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.trait_componentsXtrials;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.trait_componentsXyears;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.traitsXtrial_designs;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.traitsXtrial_types;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.traitsXtrials;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.traitsXyears;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.trial_designsXtrial_types;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.trial_designsXtrials;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.trial_designsXyears;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.trial_typesXtrials;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.trial_typesXyears;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.trialsxgenotyping_projects;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.trialsXyears;
UPDATE public.matviews SET currently_refreshing=FALSE, last_refresh=CURRENT_TIMESTAMP;'
    LANGUAGE SQL;



EOSQL

print "You're done!\n";
}


####
1; #
####
