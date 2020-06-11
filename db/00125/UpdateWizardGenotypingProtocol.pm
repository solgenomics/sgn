#!/usr/bin/env perl


=head1 NAME

UpdateMatViews.pm

=head1 SYNOPSIS

mx-run UpdateWizardGenotypingProtocol [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch updates the index genotyping_protocol materialized view to only show genotyping protocols

=head1 AUTHOR

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package UpdateWizardGenotypingProtocol;

use Moose;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch updates the genotyping protocol materialized view to only show genotyping protocols


sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    $self->dbh->do(<<EOSQL);
--do your SQL here
DROP MATERIALIZED VIEW IF EXISTS public.genotyping_protocols CASCADE;
CREATE MATERIALIZED VIEW public.genotyping_protocols AS
SELECT nd_protocol.nd_protocol_id AS genotyping_protocol_id,
    nd_protocol.name AS genotyping_protocol_name
   FROM nd_protocol
   WHERE nd_protocol.type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'genotyping_experiment')
  GROUP BY public.nd_protocol.nd_protocol_id, public.nd_protocol.name
WITH DATA;
CREATE UNIQUE INDEX genotyping_protocols_idx ON public.genotyping_protocols(genotyping_protocol_id) WITH (fillfactor=100);
ALTER MATERIALIZED VIEW genotyping_protocols OWNER TO web_usr;

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

EOSQL

print "You're done!\n";
}


####
1; #
####
