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

Nick Morales<nm529@cornell.edu>

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
    my $snp_vcf_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'vcf_snp_genotyping', 'genotype_property')->cvterm_id();

    my $q = "SELECT nd_protocol.nd_protocol_id, markers_array.value
        FROM nd_protocol
        JOIN nd_protocolprop AS markers_array ON(markers_array.nd_protocol_id=nd_protocol.nd_protocol_id AND markers_array.type_id=$vcf_map_details_markers_array_cvterm_id)
        ;";
    # print STDERR Dumper $q;
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute();

    my $q1_1 = "SELECT nd_experiment_stock.stock_id
	FROM nd_protocol
	JOIN nd_experiment_protocol ON(nd_protocol.nd_protocol_id=nd_experiment_protocol.nd_protocol_id)
	JOIN nd_experiment ON(nd_experiment.nd_experiment_id=nd_experiment_protocol.nd_experiment_id AND nd_experiment.type_id=$geno_cvterm_id)
	JOIN nd_experiment_stock ON(nd_experiment.nd_experiment_id=nd_experiment_stock.nd_experiment_id)
	WHERE nd_protocol.nd_protocol_id=?
	;";
    my $h1_1 = $schema->storage->dbh()->prepare($q1_1);

    my %protocols_hash;
    while (my ($nd_protocol_id, $markers_array_json) = $h->fetchrow_array()) {
        my $markers_array = $markers_array_json ? decode_json $markers_array_json : [];
        if (scalar(@$markers_array)>0) {
            my %unique_chromosomes;
            foreach (@$markers_array) {
                # print STDERR Dumper $_;
                $unique_chromosomes{$_->{chrom}}->{marker_count}++;
            }

	    $h1_1->execute($nd_protocol_id);
	    my ($stock_id) = $h1_1->fetchrow_array();

            $protocols_hash{$nd_protocol_id} = {
                chroms => \%unique_chromosomes,
                stock_id => $stock_id
            };
        }
    }
    print STDERR Dumper \%protocols_hash;

    my $q2 = "SELECT genotypeprop.genotypeprop_id, genotype.genotype_id, genotypeprop.rank, genotypeprop.value->>'CHROM'
        FROM genotypeprop
        JOIN genotype ON(genotypeprop.genotype_id=genotype.genotype_id)
        JOIN nd_experiment_genotype ON(genotype.genotype_id=nd_experiment_genotype.genotype_id)
        JOIN nd_experiment ON(nd_experiment.nd_experiment_id=nd_experiment_genotype.nd_experiment_id AND nd_experiment.type_id=$geno_cvterm_id)
        JOIN nd_experiment_stock ON(nd_experiment.nd_experiment_id=nd_experiment_stock.nd_experiment_id)
        JOIN nd_experiment_protocol ON(nd_experiment.nd_experiment_id=nd_experiment_protocol.nd_experiment_id)
        WHERE stock_id=? AND genotypeprop.type_id=$snp_vcf_cvterm_id AND nd_protocol_id=?;";
    my $h2 = $schema->storage->dbh()->prepare($q2);

    my %protocol_chrom_rank;
    while (my($nd_protocol_id, $o) = each %protocols_hash) {
        my $chroms = $o->{chroms};
        my $stock_id = $o->{stock_id};
        $h2->execute($stock_id, $nd_protocol_id);
        while (my ($genotypeprop_id, $genotype_id, $rank, $chrom) = $h2->fetchrow_array()) {
            print STDERR "$nd_protocol_id, $stock_id, $genotype_id, $genotypeprop_id, $rank, $chrom \n";
            $protocol_chrom_rank{$nd_protocol_id}->{$chrom} = $rank;
        }
    }
    print STDERR Dumper \%protocol_chrom_rank;

    my %protocol_chrom_rank_result;
    while (my($nd_protocol_id, $o) = each %protocols_hash) {
        my $chroms = $o->{chroms};
        my %chromosomes;
        while (my($chrom,$p) = each %$chroms) {
            my $marker_count = $p->{marker_count};
            my $rank = $protocol_chrom_rank{$nd_protocol_id}->{$chrom} || 0;
            $chromosomes{$chrom} = {
                rank => $rank,
                marker_count => $marker_count
            };
        }
        $protocol_chrom_rank_result{$nd_protocol_id} = \%chromosomes;
    }
    print STDERR Dumper \%protocol_chrom_rank_result;

    my $q3 = "SELECT value,nd_protocolprop_id FROM nd_protocolprop WHERE nd_protocol_id=? AND type_id=$vcf_map_details_id;";
    my $h3 = $schema->storage->dbh()->prepare($q3);

    my $q4 = "UPDATE nd_protocolprop SET value=? WHERE nd_protocolprop_id=?;";
    my $h4 = $schema->storage->dbh()->prepare($q4);

    while (my($nd_protocol_id,$chroms) = each %protocol_chrom_rank_result) {
        $h3->execute($nd_protocol_id);
        my ($prop_json, $nd_protocolprop_id) = $h3->fetchrow_array();
        my $prop = decode_json $prop_json;
        $prop->{chromosomes} = $chroms;
        my $prop_save = encode_json $prop;
        $h4->execute($prop_save, $nd_protocolprop_id);
        # print STDERR Dumper $prop_save;
    }

    print "You're done!\n";
}


####
1; #
####
