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
use Scalar::Util qw(looks_like_number);

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

    my $q2 = "SELECT genotypeprop.genotypeprop_id, genotype.genotype_id, genotypeprop.value
        FROM genotypeprop
        JOIN genotype ON(genotypeprop.genotype_id=genotype.genotype_id)
        JOIN nd_experiment_genotype ON(genotype.genotype_id=nd_experiment_genotype.genotype_id)
        JOIN nd_experiment ON(nd_experiment.nd_experiment_id=nd_experiment_genotype.nd_experiment_id AND nd_experiment.type_id=$geno_cvterm_id)
        JOIN nd_experiment_stock ON(nd_experiment.nd_experiment_id=nd_experiment_stock.nd_experiment_id)
        JOIN nd_experiment_protocol ON(nd_experiment.nd_experiment_id=nd_experiment_protocol.nd_experiment_id)
        WHERE stock_id=? AND genotypeprop.type_id=$snp_vcf_cvterm_id AND nd_protocol_id=?;";
    my $h2 = $schema->storage->dbh()->prepare($q2);

    # Distinct GT in localhost, cassavabase, cassava-test, musabase, musabase-test, sweetpotatobase
    # ""
    # "0|1"
    # "0|0"
    # "1/1"
    # "NA"
    # "1|0"
    # "0/0"
    # "1/0"
    # "1|1"
    # "0/1"
    # "4/1"
    # "0/5"
    # "2/2"
    # "0/4"
    # "1/5"
    # "5/5"
    # "0/2"
    # "4/4"
    # "3/2"
    # "2/5"
    # "4/3"
    # "2/4"
    # "1/3"
    # "4/5"
    # "3/3"
    # "1/0"
    # "2/0"
    # "3/1"
    # "./."
    # "0/3"
    # "1/2"
    # "3/0"
    # "4/2"
    # "3/4"
    # "2/3"
    # "4/0"
    # "3/5"
    # "1/4"
    # "2/1"
    # "1/1/1/1"
    # "0/0/0"
    # "0/1/1"
    # "0/1/1/1"
    # "-/-/-"
    # "0/0/0/0"
    # "0/0/1/1"
    # "0/0/1"
    # "1/1/1"
    # "-/-"
    # "-/-/-/-"
    # "0/0/0/1"
    # "1/2/2"
    # "3/3/3"
    # "0/0/2"
    # "2/2/2"
    # "././."
    # "1/1/2"
    # "0/1/2"
    # "0/0/0/1"
    # "0/2/2"
    # "././.\n"

    # Distinct DS in localhost, cassavabase, cassava-test, musabase
    # ""
    # "2"
    # "4"
    # "1"
    # "NA"
    # "3"
    # "0"
    # "0.019"
    # "0.026"
    # "0.038"
    # "1.865"
    # "0.825"
    # "0.889"
    # "1.926"
    # "0.999"
    # "0.928"
    # "0.017"
    # "0.938"
    # "0.525"
    # "0.915"
    # "0.002"
    # "1.859"
    # "1.856"
    # "0.913"
    # 2
    # "0.943"
    # "0.891"
    # "0.003"
    # "0.027"
    # "1.779"
    # 1
    # "0.032"
    # "0.048"
    # "0.945"
    # "0.484"
    # "0.305"
    # "0.466"
    # "1.87"
    # "0.858"
    # "0.932"
    # "1.876"
    # "0.985"
    # "1.721"
    # "0.481"
    # "0.848"
    # "0.692"
    # "0.001"
    # "0.031"
    # "1.104"
    # "0.939"
    # "0.042"
    # "0.034"
    # "0.897"
    # 0
    # "0.974"
    # "0.033"
    # "0.87"
    # "0.475"
    # "0.286"
    # "0.005"
    # "0.958"
    # "1.932"
    # "0.935"
    # "0.029"
    # "0.004"
    # "0.901"
    # "0.559"
    # "0.892"
    # "0.028"
    # "0.679"
    # "0.364"
    # "0.03"
    # null
    # 'A/C' # Lots of allele combos... like "CTAATTATAAAACTAT/CTAATTATAAAACTAT"

    my %protocol_to_change;
    foreach my $nd_protocol_id (sort keys %protocols_hash) {
        my $o = $protocols_hash{$nd_protocol_id};
        my $check_marker_obj = $o->{marker_check};

        CHECK: foreach my $stock_id (sort keys %{$protocols_all_stock_ids{$nd_protocol_id}}) {
            print STDERR Dumper [$nd_protocol_id, $stock_id];

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
                # print STDERR Dumper $check_marker_name;
                my $check_geno = $check_geno_all_chrom{$check_marker_name};
                # print STDERR Dumper $check_geno;

                if ($check_geno) {
                    my $check_ds = $check_geno->{DS};
                    my $check_gt = $check_geno->{GT};

                    # Check genotype call with DS set and not equal to 1 (e.g. 0 or 2) and has GT defined and not equal to NA
                    if (defined($check_gt) && defined($check_ds) && looks_like_number($check_ds) && $check_ds ne '1' && $check_ds ne '' && $check_gt ne '' && $check_gt ne 'NA') {
                        chomp($check_gt);
                        chomp($check_ds);

                        my @gts = split '/', $check_gt;
                        if (scalar(@gts) <= 1) {
                            @gts = split '|', $check_gt;
                        }
                        # print STDERR Dumper \@gts;

                        if (scalar(@gts) > 0) {
                            my $old_ds = 0;
                            my $new_ds = 0;
                            my $has_calls = 0;
                            foreach my $gt (@gts) {
                                # Check that call is defined and is not 'NA', '.', or '-'
                                if (looks_like_number($gt)) {
                                    if ($gt eq '0') {
                                        $old_ds++;
                                    }
                                    else {
                                        $new_ds++;
                                    }
                                    $has_calls = 1;
                                }
                            }

                            if ($has_calls) {
                                print STDERR Dumper [$old_ds, $new_ds, $check_ds];
                                if ($check_ds == $old_ds) {
                                    print STDERR Dumper $check_geno;
                                    $protocol_to_change{$nd_protocol_id}++;
                                }

                                last CHECK;
                            }
                        }
                    }
                }
            }
        }
        print STDERR "End Protocol Check $nd_protocol_id.....\n";
    }

    print STDERR "GENOTYPING PROTOCOLS TO CHANGE DS IN:\n";
    print STDERR Dumper \%protocol_to_change;

    my $nd_protocol_id;
    my $coderef = sub {
        my $start_time = time();

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

        my $genotypeprop_rs = $schema->resultset('Genetic::Genotypeprop');

        my @stock_ids = sort keys %{$protocols_all_stock_ids{$nd_protocol_id}};
        my $total_stocks = scalar(@stock_ids);
        print STDERR "STOCKS IN $nd_protocol_id: ".$total_stocks."\n";

        my $stock_count = 1;
        foreach my $stock_id (@stock_ids) {

            $h3->execute($nd_protocol_id, $stock_id);
            while (my($prop_json, $genotypeprop_id, $rank) = $h3->fetchrow_array()) {
                if ($prop_json) {
                    my $prop = decode_json $prop_json;

                    while (my($marker_name,$v) = each %$prop) {
                        if ($marker_name ne 'CHROM') {

                            my $gt = $v->{GT};
                            # Check that GT is defined and is not NA
                            if (defined($gt) && $gt ne '' && $gt ne 'NA') {

                                my @gts = split '/', $gt;
                                if (scalar(@gts) <= 1) {
                                    @gts = split '|', $gt;
                                }
                                # print STDERR Dumper \@gts;

                                my $alt_ds = 0;
                                my $has_calls;
                                foreach my $gt (@gts) {
                                    # Check that call is defined and is not 'NA', '.', or '-'
                                    if (looks_like_number($gt)) {
                                        if ($gt ne '0') {
                                            $alt_ds++;
                                        }
                                        $has_calls = 1;
                                    }
                                }
                                if ($has_calls) {
                                    $v->{DS} = $alt_ds;
                                }
                                else {
                                    $v->{DS} = "NA";
                                }

                                chomp($gt);
                                $v->{GT} = $gt;
                            }
                            else {
                                # GT is "NA"
                                $v->{DS} = "NA";
                            }

                        }
                    }

                    my $prop_save = encode_json $prop;

                    my $row = $genotypeprop_rs->find({genotypeprop_id=>$genotypeprop_id});
                    $row->value($prop_save);
                    $row->update();
                }
            }
            my $end_time = time();
            my $seconds_passed = $end_time - $start_time;
            print STDERR "$nd_protocol_id:$stock_id ($stock_count"."/"."$total_stocks) $seconds_passed"."s. ";
            $stock_count++;
        }

        my $end_time = time();
        my $seconds_passed = $end_time - $start_time;
        print STDERR "Protocol $nd_protocol_id completed $seconds_passed seconds\n";
    };

    foreach my $nd_protocol_id_ref (sort keys %protocol_to_change) {
        $nd_protocol_id = $nd_protocol_id_ref;
        try {
            $schema->txn_do($coderef);
            print "You're done protocol $nd_protocol_id!\n";
        } catch {
            my $transaction_error =  $_;
            print STDERR Dumper $transaction_error;
        };
    }

    print "You're done!\n";
}


####
1; #
####
