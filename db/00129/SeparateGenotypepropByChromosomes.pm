#!/usr/bin/env perl


=head1 NAME

 SeparateGenotypepropByChromosomes

=head1 SYNOPSIS

mx-run SeparateGenotypepropByChromosomes [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION
This patch separates the genotypeprop genotype storage into separate chromosomes
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR


=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package SeparateGenotypepropByChromosomes;

use Moose;
use Bio::Chado::Schema;
use CXGN::People::Schema;
use Try::Tiny;
use CXGN::Genotype::Search;
use JSON;
use Scalar::Util qw(looks_like_number);
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch separates the genotypeprop genotype storage into separate chromosomes

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
    my $people_schema = CXGN::People::Schema->connect( sub { $self->dbh->clone } );

    # Restricting search to "NEW" genotyping protocols which have nd_protocolprop information.
    my $geno_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'genotyping_experiment', 'experiment_type')->cvterm_id();
    my $vcf_map_details_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'vcf_map_details', 'protocol_property')->cvterm_id();
    my $vcf_snp_genotyping_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'vcf_snp_genotyping', 'genotype_property')->cvterm_id();
    my $vcf_map_details_markers_array_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'vcf_map_details_markers_array', 'protocol_property')->cvterm_id();

    my $q = "SELECT nd_protocol.nd_protocol_id, nd_protocolprop.nd_protocolprop_id, nd_protocolprop.value, genotype.genotype_id, genotypeprop.genotypeprop_id, genotypeprop.value
        FROM nd_protocol
        JOIN nd_protocolprop ON(nd_protocol.nd_protocol_id = nd_protocolprop.nd_protocol_id)
        JOIN nd_experiment_protocol ON(nd_protocolprop.nd_protocol_id = nd_experiment_protocol.nd_protocol_id)
        JOIN nd_experiment_genotype USING(nd_experiment_id)
        JOIN genotype ON(genotype.genotype_id = nd_experiment_genotype.genotype_id)
        JOIN genotypeprop ON(genotype.genotype_id = genotypeprop.genotype_id AND genotypeprop.type_id=$vcf_snp_genotyping_cvterm_id)
        WHERE nd_protocol.type_id=$geno_cvterm_id AND nd_protocolprop.type_id=$vcf_map_details_id
        ORDER BY nd_protocol_id ASC;";
    my $h = $schema->storage->dbh()->prepare($q);

    my $q2 = "SELECT value
        FROM nd_protocolprop
        WHERE nd_protocol_id=? AND type_id=$vcf_map_details_markers_array_cvterm_id;";
    my $h2 = $schema->storage->dbh()->prepare($q2);

    my $q3 = "UPDATE nd_protocolprop SET value = ? WHERE nd_protocolprop_id = ?;";
    my $h3 = $schema->storage->dbh()->prepare($q3);

    my $q4 = "DELETE FROM genotypeprop WHERE genotypeprop_id=?;";
    my $h4 = $schema->storage->dbh()->prepare($q4);

    my $q5 = "INSERT INTO genotypeprop (type_id, rank, value, genotype_id) VALUES (?,?,?,?);";
    my $h5 = $schema->storage->dbh()->prepare($q5);

    $h->execute();
    my %seen_protocols;
    while (my ($protocol_id, $protocolprop_id, $protocol_json, $genotype_id, $genotypeprop_id, $genotype_json) = $h->fetchrow_array()) {
        my $protocol = decode_json $protocol_json;
        my $genotype = decode_json $genotype_json;

        if (!exists($genotype->{CHROM})) {

            $h2->execute($protocol_id);
            my ($markers_array_json) = $h2->fetchrow_array();
            my $nd_protocolprop_markers_array = decode_json $markers_array_json;

            my %unique_chromosomes;
            foreach (@$nd_protocolprop_markers_array) {
                $unique_chromosomes{$_->{chrom}}->{$_->{name}}++;
            }
            my %chromosomes;
            my $chr_count = 0;
            my %chrom_map;
            my %chrom_name_map;
            foreach my $chr_name (sort keys %unique_chromosomes) {
                my $marker_count = scalar( keys %{$unique_chromosomes{$chr_name}} );
                $chromosomes{$chr_name} = {
                    rank => $chr_count,
                    marker_count => $marker_count
                };
                $chrom_map{$chr_count} = $unique_chromosomes{$chr_name};
                $chrom_name_map{$chr_count} = $chr_name;
                $chr_count++;
            }

            if (!exists($seen_protocols{$protocol_id})) {
                $protocol->{chromosomes} = \%chromosomes;
                $h3->execute(encode_json $protocol, $protocolprop_id);
                $seen_protocols{$protocol_id}++;
            }

            $h4->execute($genotypeprop_id);

            while (my ($rank, $chromosome_markers) = each %chrom_map) {
                my $chr_name = $chrom_name_map{$rank};
                my %geno = ('CHROM' => $chr_name);
                while (my ($marker_name, $g) = each %$genotype) {
                    if (exists($chromosome_markers->{$marker_name})) {
                        $geno{$marker_name} = $g;
                    }
                }
                $h5->execute($vcf_snp_genotyping_cvterm_id, $rank, encode_json \%geno, $genotype_id);
            }

        }
    }

    print "You're done!\n";
}


####
1; #
####
