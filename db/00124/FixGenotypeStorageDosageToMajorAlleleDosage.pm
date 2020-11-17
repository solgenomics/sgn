#!/usr/bin/env perl


=head1 NAME

 FixGenotypeStorageDosageToMajorAlleleDosage

=head1 SYNOPSIS

mx-run FixGenotypeStorageDosageToMajorAlleleDosage [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION
This patch fixes the genotype storage error of loading dosage as minor allele dosage, when it should be major allele dosage
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR


=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package FixGenotypeStorageDosageToMajorAlleleDosage;

use Moose;
use Bio::Chado::Schema;
use CXGN::People::Schema;
use Try::Tiny;
use CXGN::Genotype::Search;
use JSON;
use Scalar::Util qw(looks_like_number);
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch fixes the genotype storage error of loading dosage as minor allele dosage, when it should be major allele dosage

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

    my $update_q = "UPDATE genotypeprop SET value = ? WHERE genotypeprop_id = ?;";
    my $h_update = $schema->storage->dbh()->prepare($update_q);

    # Restricting search to "NEW" genotyping protocols which have nd_protocolprop information. Old genotyping protocols only had the DS value and shuold be assumed to be stored correctly.
    my $geno_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'genotyping_experiment', 'experiment_type')->cvterm_id();
    my $vcf_map_details_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'vcf_map_details', 'protocol_property')->cvterm_id();
    my $q = "SELECT nd_protocol_id FROM nd_protocol JOIN nd_protocolprop USING(nd_protocol_id) WHERE nd_protocol.type_id=$geno_cvterm_id AND nd_protocolprop.type_id=$vcf_map_details_id ORDER BY nd_protocol_id ASC;";
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute();
    while (my ($protocol_id) = $h->fetchrow_array()) {
        my $genotypes_search = CXGN::Genotype::Search->new({
            bcs_schema=>$schema,
            people_schema=>$people_schema,
            protocol_id_list=>[$protocol_id],
            protocolprop_top_key_select=>[],
            protocolprop_marker_hash_select=>[]
        });
        $genotypes_search->init_genotype_iterator();
        while (my ($count, $genotype_data) = $genotypes_search->get_next_genotype_info) {
            #my $m_hash = $genotype_data->{selected_protocol_hash}->{markers};
            my $g_hash = $genotype_data->{selected_genotype_hash};

            while (my ($k, $v) = each %$g_hash) {
                my $gt_dosage_val = 'NA';
                my $gt_dosage = 0;
                if (exists($v->{GT})) {
                    my $gt = $v->{GT};
                    my $separator = '/';
                    my @alleles = split (/\//, $gt);
                    if (scalar(@alleles) <= 1){
                        @alleles = split (/\|/, $gt);
                        if (scalar(@alleles) > 1) {
                            $separator = '|';
                        }
                    }

                    foreach (@alleles) {
                        if (looks_like_number($_)) {
                            if ($_ eq '0' || $_ == 0) {
                                $gt_dosage++;
                            }
                            $gt_dosage_val = $gt_dosage;
                        }
                    }
                }
                if (exists($v->{GT}) ) {
                    $v->{DS} = $gt_dosage_val;
                }
            }

            my $genotypeprop_id = $genotype_data->{markerProfileDbId};
            print STDERR "CHECKING genotypeprop_id $genotypeprop_id\n";
            $h_update->execute(encode_json($g_hash), $genotypeprop_id);
        }
    }

    print "You're done!\n";
}


####
1; #
####
