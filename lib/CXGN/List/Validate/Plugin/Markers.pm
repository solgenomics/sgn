
package CXGN::List::Validate::Plugin::Markers;

use Moose;
use Data::Dumper;
use JSON;

sub name {
    return "markers";
}

sub validate {
    my $self = shift;
    my $schema = shift;
    my $list = shift;
    my $s = shift;
    my $protocol_id = shift;

    print STDERR "PROTOCOL ID =".Dumper($protocol_id)."\n";
    my $vcf_map_details_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'vcf_map_details', 'protocol_property')->cvterm_id();
    print STDERR "TYPE ID =".Dumper($vcf_map_details_type_id)."\n";

    my $q = "SELECT value,nd_protocolprop_id FROM nd_protocolprop WHERE nd_protocol_id=? AND type_id=?";
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute($protocol_id, $vcf_map_details_type_id);

    my @info = $h->fetchrow_array();
    my $protocol_info = $info[0];
#    print STDERR "PROTOCOL INFO =".Dumper($protocol_info)."\n";
    my $protocol_info_hash = decode_json $protocol_info;
    my $marker_names = $protocol_info_hash->{'marker_names'};
    print STDERR "MARKER NAMES =".Dumper($marker_names)."\n";

    my @missing = ();
    foreach my $name (@$list) {
        if ($name ~~ @$marker_names) {
            next;
        } else {
            push @missing, $name;
        }

    }
    print STDERR "MISSING =".Dumper(\@missing)."\n";    
    return { missing => \@missing };
}

1;
