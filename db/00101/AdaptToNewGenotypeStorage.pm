#!/usr/bin/env perl


=head1 NAME

 AdaptToNewGenotypeStorage

=head1 SYNOPSIS

mx-run AdaptToNewGenotypeStorage [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION
This patch adapts to the new genotype storage by changing nd_protocolprop.value to JSONB and by changing the 'snp genotyping' values in genotypeprop to {'markername1' : {'DS' : '1'}, 'markername2' : {'DS' : '0'}, ... } and by changing the type of these genotypeprops to 'vcf_snp_genotyping'
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR


=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AdaptToNewGenotypeStorage;

use Moose;
use Bio::Chado::Schema;
use Try::Tiny;
use SGN::Model::Cvterm;
use JSON;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch adapts to the new genotype storage by changing nd_protocolprop.value to JSONB and by changing the 'snp genotyping' values in genotypeprop to {'markername1' : {'DS' : '1'}, 'markername2' : {'DS' : '0'}, ... } and by changing the type of these genotypeprops to 'vcf_snp_genotyping'

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

    my $snp_genotyping_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'snp genotyping', 'genotype_property')->cvterm_id();
    my $vcf_snp_genotyping_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'vcf_snp_genotyping', 'genotype_property')->cvterm_id();

    my $coderef = sub {
        my $sql = <<SQL;
ALTER TABLE nd_protocolprop ALTER COLUMN value TYPE JSONB USING value::JSON;
SQL
        $schema->storage->dbh->do($sql);

        my $q = "SELECT genotypeprop_id, value FROM genotypeprop WHERE type_id = $snp_genotyping_cvterm_id ORDER BY genotypeprop_id ASC;";
        my $update1_q = "UPDATE genotypeprop SET value = ? WHERE genotypeprop_id = ?;";
        my $update2_q = "UPDATE genotypeprop SET type_id = $vcf_snp_genotyping_cvterm_id WHERE genotypeprop_id = ?;";

        my $h = $schema->storage->dbh()->prepare($q);
        my $h_update1 = $schema->storage->dbh()->prepare($update1_q);
        my $h_update2 = $schema->storage->dbh()->prepare($update2_q);

        $h->execute();
        while (my ($genotypeprop_id, $json_val) = $h->fetchrow_array()) {
            my $val = decode_json $json_val;
            my %new_val;
            while (my ($marker_name, $dosage_value) = each %$val) {
                $new_val{$marker_name} = {'DS' => $dosage_value};
            }
            my $genotypeprop_json = encode_json \%new_val;
            $h_update1->execute($genotypeprop_json, $genotypeprop_id);
            $h_update2->execute($genotypeprop_id);
        }
    };

    my $transaction_error;
    try {
        $schema->txn_do($coderef);
    } catch {
        $transaction_error =  $_;
    };
    if ($transaction_error){
        print STDERR "ERROR: $transaction_error\n";
    } else {
        print "You're done!\n";
    }
}


####
1; #
####
