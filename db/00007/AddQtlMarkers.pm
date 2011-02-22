package AddQtlMarkers;

use Moose;
extends 'CXGN::Metadata::Dbpatch';

use Bio::Chado::Schema;

sub init_patch {
    my $self=shift;
    my $name = __PACKAGE__;
    print "dbpatch name is ':" .  $name . "\n\n";
    my $description = 'Adding QTL marker and map types, and flanking positions to marker_location';
    my @previous_requested_patches = (); #ADD HERE
    $self->name($name);
    $self->description($description);
    $self->prereq(\@previous_requested_patches);
}

sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    $self->dbh->do( <<'' );
    ALTER TABLE sgn.map DROP CONSTRAINT map_map_type_check;
    ALTER TABLE sgn.map ADD CONSTRAINT map_map_type_check CHECK
        (map_type = 'genetic'::text OR map_type = 'fish'::text OR map_type = 'sequence'::text OR map_type = 'QTL');
    
    ALTER TABLE sgn.marker_experiment DROP CONSTRAINT marker_experiment_protocol_check;
    ALTER TABLE sgn.marker_experiment ADD CONSTRAINT marker_experiment_protocol_check CHECK (protocol = 'AFLP'::text OR protocol = 'CAPS'::text OR protocol = 'RAPD'::text OR protocol = 'SNP'::text OR protocol = 'SSR'::text OR protocol = 'RFLP'::text OR protocol = 'PCR'::text OR protocol = 'dCAPS'::text OR protocol = 'DART'::text OR protocol = 'OPA'::text OR protocol = 'unknown'::text OR protocol = 'ASPE'::text OR protocol = 'INDEL'::text OR protocol = 'QTL'::text);

    ALTER TABLE sgn.marker_location ADD COLUMN position_north numeric(8,5);
    ALTER TABLE sgn.marker_location ADD COLUMN position_south numeric(8,5);

    print "You're done!\n";

}


####
1; #
####

