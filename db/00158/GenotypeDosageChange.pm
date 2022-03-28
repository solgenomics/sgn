#!/usr/bin/env perl


=head1 NAME

 GenotypeDosageChange

=head1 SYNOPSIS

mx-run GenotypeDosageChange [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION
This patch changes calculated dosage from REF to ALT
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

Nick Morales<nm529@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package GenotypeDosageChange;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;
use SGN::Model::Cvterm;
use JSON;
use Data::Dumper;

extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch changes calculated dosage from REF to ALT

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

    # GETS MARKER INFORMATION FOR ALL PROTOCOLS LOADED UNDER vcf_map_details

    my %protocol_geno_check;
    while (my ($nd_protocol_id, $markers_array_json) = $h->fetchrow_array()) {
        my $markers_array = $markers_array_json ? decode_json $markers_array_json : [];
        if (scalar(@$markers_array)>0) {
            foreach (@$markers_array) {
                $protocol_geno_check{$nd_protocol_id}->{$_->{name}}++;
            }
        }
    }
    # print STDERR Dumper \%protocol_geno_check;

    # GETS STOCKS GENOTYPED UNDER ALL PROTOCOLS

    my %protocols_hash;
    my %protocols_all_stock_ids;
    while (my($nd_protocol_id, $marker_check) = each %protocol_geno_check) {
        $h1_1->execute($nd_protocol_id);

        while (my ($stock_id) = $h1_1->fetchrow_array()) {
            if ($stock_id) {
                $protocols_hash{$nd_protocol_id} = {
                    marker_check => $marker_check,
                    stock_id => $stock_id
                };
                $protocols_all_stock_ids{$nd_protocol_id}->{$stock_id}++;
            }
        }
    }
    # print STDERR Dumper \%protocols_hash;
    # print STDERR Dumper \%protocols_all_stock_ids;

    # CHECK IF THE GENOTYPING PROTOCOL WAS SAVED UNDER THE OLD DOSAGE SCHEME

    my $q2 = "SELECT genotypeprop.genotypeprop_id, genotype.genotype_id, genotypeprop.value
        FROM genotypeprop
        JOIN genotype ON(genotypeprop.genotype_id=genotype.genotype_id)
        JOIN nd_experiment_genotype ON(genotype.genotype_id=nd_experiment_genotype.genotype_id)
        JOIN nd_experiment ON(nd_experiment.nd_experiment_id=nd_experiment_genotype.nd_experiment_id AND nd_experiment.type_id=$geno_cvterm_id)
        JOIN nd_experiment_stock ON(nd_experiment.nd_experiment_id=nd_experiment_stock.nd_experiment_id)
        JOIN nd_experiment_protocol ON(nd_experiment.nd_experiment_id=nd_experiment_protocol.nd_experiment_id)
        WHERE stock_id=? AND genotypeprop.type_id=$snp_vcf_cvterm_id AND nd_protocol_id=?;";
    my $h2 = $schema->storage->dbh()->prepare($q2);

    my %protocol_to_change;
    while (my($nd_protocol_id, $o) = each %protocols_hash) {
        my $stock_id = $o->{stock_id};
        my $check_marker_obj = $o->{marker_check};

        $h2->execute($stock_id, $nd_protocol_id);
        my %check_geno_all_chrom;
        while (my ($genotypeprop_id, $genotype_id, $check_geno_all_json) = $h2->fetchrow_array()) {
            my $check_geno_all = decode_json $check_geno_all_json;
            # print STDERR Dumper $check_geno_all;
            while (my($k,$v) = each %$check_geno_all) {
                $check_geno_all_chrom{$k} = $v;
            }
        }

        while (my($check_marker_name, $p) = each %$check_marker_obj) {
            print STDERR Dumper $check_marker_name;
            my $check_geno = $check_geno_all_chrom{$check_marker_name};
            print STDERR Dumper $check_geno;

            if ($check_geno) {
                my $check_ds = $check_geno->{DS};
                my $check_gt = $check_geno->{GT};
                if ($check_ds ne 'NA' && $check_gt ne './.' && $check_gt ne 'NA/NA' && $check_gt ne 'NA') {

                    my @gts = split '/', $check_gt;
                    if (scalar(@gts) <= 1) {
                        @gts = split '|', $check_gt;
                    }
                    print STDERR Dumper \@gts;

                    if (scalar(@gts) > 0) {
                        my $old_ds = 0;
                        my $new_ds = 0;
                        foreach my $gt (@gts) {
                            if ($gt eq '0' || $gt == 0) {
                                $old_ds++;
                            }
                            if ($gt ne '0' && $gt != 0) {
                                $new_ds++;
                            }
                        }
                        print STDERR Dumper [$old_ds, $new_ds, $check_ds];
                        if ($check_ds == $old_ds) {
                            $protocol_to_change{$nd_protocol_id}++;
                        }

                        last;
                    }
                }
            }
        }

    }

    # UPDATE GENOTYPING PROTOCOLS TO NEW DOSAGE SCHEME
    print STDERR "GENOTYPING PROTOCOLS TO CHANGE DS IN:\n";
    print STDERR Dumper \%protocol_to_change;

    my $coderef = sub {
        my $q3 = "SELECT genotypeprop.value, genotypeprop.genotypeprop_id, genotypeprop.rank
            FROM genotypeprop
            JOIN genotype ON(genotype.genotype_id=genotypeprop.genotype_id)
            JOIN nd_experiment_genotype ON(genotype.genotype_id=nd_experiment_genotype.genotype_id)
            JOIN nd_experiment ON(nd_experiment_genotype.nd_experiment_id=nd_experiment.nd_experiment_id AND nd_experiment.type_id=$geno_cvterm_id)
            JOIN nd_experiment_protocol ON(nd_experiment.nd_experiment_id=nd_experiment_protocol.nd_experiment_id)
            JOIN nd_protocol ON(nd_protocol.nd_protocol_id=nd_experiment_protocol.nd_protocol_id)
            JOIN nd_protocolprop ON(nd_protocol.nd_protocol_id=nd_protocolprop.nd_protocol_id)
            JOIN nd_experiment_stock ON(nd_experiment.nd_experiment_id=nd_experiment_stock.nd_experiment_id)
            WHERE nd_protocol.nd_protocol_id=? AND nd_protocolprop.type_id=$vcf_map_details_id AND genotypeprop.type_id=$snp_vcf_cvterm_id AND nd_experiment_stock.stock_id=?
            ORDER BY genotypeprop.genotypeprop_id ASC;";
        my $h3 = $schema->storage->dbh()->prepare($q3);

        my $q4 = "UPDATE genotypeprop SET value=? WHERE genotypeprop_id=?;";
        my $h4 = $schema->storage->dbh()->prepare($q4);

        foreach my $nd_protocol_id (sort keys %protocol_to_change) {

            my @stock_ids = sort keys %{$protocols_all_stock_ids{$nd_protocol_id}};
            print STDERR "STOCKS IN $nd_protocol_id: ".scalar(@stock_ids)."\n";

            foreach my $stock_id (@stock_ids) {

                $h3->execute($nd_protocol_id, $stock_id);
                while (my($prop_json, $genotypeprop_id, $rank) = $h3->fetchrow_array()) {
                    if ($prop_json) {
                        my $prop = decode_json $prop_json;

                        while (my($marker_name,$v) = each %$prop) {
                            if ($marker_name ne 'CHROM') {
                                my $ds = $v->{DS};
                                my $gt = $v->{GT};

                                if ($ds ne 'NA') {
                                    if ($ds == 2) {
                                        $v->{DS} = 0;
                                    }
                                    elsif ($ds == 0) {
                                        $v->{DS} = 2;
                                    }
                                }
                            }
                        }

                        my $prop_save = encode_json $prop;
                        $h4->execute($prop_save, $genotypeprop_id);
                    }
                }
                print STDERR "$nd_protocol_id $stock_id \n";
            }
        }
    };

    try {
        $schema->txn_do($coderef);
        print "You're done!\n";
    } catch {
        my $transaction_error =  $_;
        print STDERR Dumper $transaction_error;
    };

}


####
1; #
####
