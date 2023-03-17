#!/usr/bin/env perl


=head1 NAME

PatchMissingMaterializedViews.pm

=head1 SYNOPSIS

mx-run PatchMissingMaterializedViews [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

Patches missing materialized views in the case that UpdateWizardMaterializedViewsForGenoProtocols wasn't able to run because of conflicts with later migrations.

=head1 AUTHOR

Chris Tucker (ct447@cornell.edu)

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package PatchMissingMaterializedViews;

use Moose;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
Patches missing materialized views in the case that UpdateWizardMaterializedViewsForGenoProtocols wasn't able to run because of conflicts with later migrations.


sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    $self->dbh->do(<<EOSQL);
--do your SQL here
DROP MATERIALIZED VIEW IF EXISTS public.genotyping_projectsxaccessions CASCADE;
CREATE MATERIALIZED VIEW public.genotyping_projectsxaccessions AS
 SELECT nd_experiment_project.project_id AS genotyping_project_id,
    materialized_genoview.accession_id
   FROM ((nd_experiment_project
     JOIN nd_experiment_genotype ON ((nd_experiment_project.nd_experiment_id = nd_experiment_genotype.nd_experiment_id)))
     JOIN materialized_genoview ON ((nd_experiment_genotype.genotype_id = materialized_genoview.genotype_id)))
  WHERE (nd_experiment_project.project_id IN ( SELECT genotyping_projects.genotyping_project_id
           FROM genotyping_projects))
  GROUP BY nd_experiment_project.project_id, materialized_genoview.accession_id
 WITH DATA;
CREATE UNIQUE INDEX genotyping_projectsxaccessions_idx ON public.genotyping_projectsxaccessions(genotyping_project_id, accession_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW public.genotyping_projectsxaccessions OWNER TO web_usr;

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

CREATE MATERIALIZED VIEW public.trait_componentsXtraits AS
SELECT traits.trait_id,
trait_component.cvterm_id AS trait_component_id
FROM traits
JOIN cvterm_relationship ON(traits.trait_id = cvterm_relationship.object_id AND cvterm_relationship.type_id = (SELECT cvterm_id from cvterm where name = 'contains'))
JOIN cvterm trait_component ON(cvterm_relationship.subject_id = trait_component.cvterm_id)
GROUP BY 1,2
WITH DATA;
CREATE UNIQUE INDEX trait_componentsXtraits_idx ON public.trait_componentsXtraits(trait_component_id, trait_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW trait_componentsXtraits OWNER TO web_usr;
INSERT INTO matviews (mv_name, currently_refreshing, last_refresh) VALUES ('trait_componentsXtraits', FALSE, CURRENT_TIMESTAMP);

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

EOSQL

    print "You're done!\n";
}


####
1; #
####
