#!/usr/bin/env perl


=head1 NAME

 MarkerPositionSize.pm

=head1 SYNOPSIS

mx-run ThisPackageName [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

Change the sgn.marker_location.position type from numeric(8,5) to numeric(9,6)
to accomodate full genome location in bp

This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

 Naama Menda<nm249@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2012 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package MarkerPositionSize;

use Moose;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
Change the sgn.marker_location.position type from numeric(8,5) to numeric(9,6)
to accomodate full genome location in bp


sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    $self->dbh->do(<<EOSQL);
DROP VIEW sgn.marker_to_map;
ALTER TABLE sgn.marker_location ALTER COLUMN position TYPE numeric(9,6);

CREATE VIEW sgn.marker_to_map AS
SELECT m.marker_id, me.protocol, ml.location_id, linkage_group.lg_name, linkage_group.lg_order, ml."position", ml.confidence_id, ml.subscript, ml.map_version_id, map.map_id, map.parent_1, map.parent_2, map_version.current_version
   FROM marker m
   LEFT JOIN marker_experiment me USING (marker_id)
   LEFT JOIN marker_location ml USING (location_id)
   LEFT JOIN map_version USING (map_version_id)
   LEFT JOIN map USING (map_id)
   LEFT JOIN linkage_group USING (lg_id)
  WHERE map_version.current_version = true;

GRANT select ON sgn.marker_to_map TO web_usr;

EOSQL

print "You're done!\n";
}


####
1; #
####
