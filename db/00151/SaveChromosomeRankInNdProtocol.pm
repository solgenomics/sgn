#!/usr/bin/env perl


=head1 NAME

 SaveChromosomeRankInNdProtocol

=head1 SYNOPSIS

mx-run SaveChromosomeRankInNdProtocol [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION
This patch saves the genotypeprop rank of the chromosomes in the nd_protocolprop JSONb.
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

Alex Ogbonna<aco46@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package SaveChromosomeRankInNdProtocol;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;
use SGN::Model::Cvterm;
use JSON;
use Data::Dumper;

extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch saves the genotypeprop rank of the chromosomes in the nd_protocolprop JSONb

has '+prereq' => (
	default => sub {
        [],
    },

  );

sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";
    my $schema = Bio::Chado::Schema->connect( sub { $self->dbh->clone } );


    my $vcf_map_details_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'vcf_map_details', 'protocol_property')->cvterm_id();
    my $vcf_map_details_markers_array_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'vcf_map_details_markers_array', 'protocol_property')->cvterm_id();
    my $geno_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'genotyping_experiment', 'experiment_type')->cvterm_id();

    my $q = "SELECT nd_protocol.nd_protocol_id, nd_experiment_stock.stock_id, prop.value, markers_array.value
        FROM nd_protocol
        JOIN nd_protocolprop AS prop ON(prop.nd_protocol_id=nd_protocol.nd_protocol_id AND prop.type_id=$vcf_map_details_id)
        JOIN nd_protocolprop AS markers_array ON(markers_array.nd_protocol_id=nd_protocol.nd_protocol_id AND markers_array.type_id=$vcf_map_details_markers_array_cvterm_id)
        JOIN nd_experiment_protocol ON(nd_protocol.nd_protocol_id=nd_experiment_protocol.nd_protocol_id)
        JOIN nd_experiment ON(nd_experiment.nd_experiment_id=nd_experiment_protocol.nd_experiment_id AND nd_experiment.type_id=$geno_cvterm_id)
        JOIN nd_experiment_stock ON(nd_experiment.nd_experiment_id=nd_experiment_stock.nd_experiment_id)
        ;";
    print STDERR Dumper $q;
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute();
    my %protocols_hash;
    while (my ($nd_protocol_id, $stock_id, $prop_json, $markers_array_json) = $h->fetchrow_array()) {
        my $prop = $prop_json ? decode_json $prop_json : undef;
        my $markers_array = $markers_array_json ? decode_json $markers_array_json : [];
        if ($prop && scalar(@$markers_array)>0) {
            # print STDERR Dumper $prop;
            my %unique_chromosomes;
            foreach (@$markers_array) {
                # print STDERR Dumper $_;
                $unique_chromosomes{$_->{chrom}}->{marker_count}++;
            }
            $protocols_hash{$nd_protocol_id} = {
                chroms => \%unique_chromosomes,
                stock_id => $stock_id
            };
        }
    }
    print STDERR Dumper \%protocols_hash;

    print "You're done!\n";
}


####
1; #
####
