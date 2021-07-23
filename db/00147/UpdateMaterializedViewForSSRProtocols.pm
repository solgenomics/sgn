#!/usr/bin/env perl

=head1 NAME
UpdatMaterializedViewForSSRProtocols.pm

=head1 SYNOPSIS

mx-run UpdatMaterializedViewForSSRProtocols [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch updates wizard materialized view to include SSR protocols:

=head1 AUTHOR

Titima Tantikanjana <tt15@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

package UpdateMaterializedViewForSSRProtocols;

use Moose;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch updates the public.genotyping_protocols to include SSR protocols

sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    $self->dbh->do(<<EOSQL);
--do your SQL here

DROP VIEW IF EXISTS public.genotyping_protocols CASCADE;
CREATE VIEW public.genotyping_protocols AS
SELECT nd_protocol.nd_protocol_id AS genotyping_protocol_id,
    nd_protocol.name AS genotyping_protocol_name
    FROM nd_protocol
    WHERE nd_protocol.type_id IN (SELECT cvterm_id from cvterm where cvterm.name = 'genotyping_experiment' OR cvterm.name = 'pcr_marker_protocol')
GROUP BY public.nd_protocol.nd_protocol_id, public.nd_protocol.name;
ALTER VIEW genotyping_protocols OWNER TO web_usr;


EOSQL

print "You're done!\n";
}


####
1; #
####
