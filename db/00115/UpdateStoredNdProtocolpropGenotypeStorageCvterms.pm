#!/usr/bin/env perl


=head1 NAME

 UpdateStoredNdProtocolpropGenotypeStorageCvterms

=head1 SYNOPSIS

mx-run UpdateStoredNdProtocolpropGenotypeStorageCvterms [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION
This patch converts the old single nd_protocolprop storage into the new three value nd_protocolprop genotype storage: one for each of the cvterms: vcf_map_details, vcf_map_details_markers, vcf_map_details_markers_array
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR


=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package UpdateStoredNdProtocolpropGenotypeStorageCvterms;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;
use SGN::Model::Cvterm;
use JSON;
use Data::Dumper;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch converts the old single nd_protocolprop storage into the new three value nd_protocolprop genotype storage: one for each of the cvterms: vcf_map_details, vcf_map_details_markers, vcf_map_details_markers_array

has '+prereq' => (
	default => sub {
        ['AddNdProtocolpropGenotypeStorageCvterms'],
    },

);

sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";
    my $schema = Bio::Chado::Schema->connect( sub { $self->dbh->clone } );

    my $vcf_map_details_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'vcf_map_details', 'protocol_property')->cvterm_id();
    my $vcf_map_details_markers_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'vcf_map_details_markers', 'protocol_property')->cvterm_id();
    my $vcf_map_details_markers_array_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'vcf_map_details_markers_array', 'protocol_property')->cvterm_id();

    my $q = "SELECT nd_protocolprop_id, nd_protocol_id, value FROM nd_protocolprop WHERE type_id = $vcf_map_details_cvterm_id;";
    my $h = $schema->storage->dbh()->prepare($q);
    
    my $update_protocolprop_sql = "UPDATE nd_protocolprop SET value = ? WHERE nd_protocolprop_id = ?;";
    my $new_protocolprop_sql = "INSERT INTO nd_protocolprop (nd_protocol_id, type_id, value) VALUES (?, ?, ?);";
    my $h_protocolprop_update = $schema->storage->dbh()->prepare($update_protocolprop_sql);
    my $h_protocolprop = $schema->storage->dbh()->prepare($new_protocolprop_sql);
    
    $h->execute();
    while (my ($nd_protocolprop_id, $nd_protocol_id, $old_value) = $h->fetchrow_array()) {
        my $old_value = decode_json $old_value;
        print STDERR Dumper $old_value;
        my $new_vcf_map_details_markers = $old_value->{markers};
        my $new_vcf_map_details_markers_array = $old_value->{markers_array};

        if ($new_vcf_map_details_markers) {
            my $nd_protocolprop_markers_json_string = encode_json $new_vcf_map_details_markers;
            $h_protocolprop->execute($nd_protocol_id, $vcf_map_details_markers_cvterm_id, $nd_protocolprop_markers_json_string);
        }
        if ($new_vcf_map_details_markers_array) {
            my $nd_protocolprop_markers_array_json_string = encode_json $new_vcf_map_details_markers_array;
            $h_protocolprop->execute($nd_protocol_id, $vcf_map_details_markers_array_cvterm_id, $nd_protocolprop_markers_array_json_string);
        }

        delete($old_value->{markers});
        delete($old_value->{markers_array});

        my $nd_protocol_json_string = encode_json $old_value;
        $h_protocolprop_update->execute($nd_protocol_json_string, $nd_protocolprop_id);
    }

    print "You're done!\n";
}


####
1; #
####
