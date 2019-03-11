#!/usr/bin/env perl


=head1 NAME

 ChangeGenotypepropGTKeyToNucleotides.pm

=head1 SYNOPSIS

mx-run ThisPackageName [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION
This patch converts the genotypeprop GT key from the VCF representation of '0/1' to the nucleotide representation of 'C/T' using the nd_protocolprop 'ref' and 'alt' information in the database.
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

Bryan Ellerbrock

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package ChangeGenotypepropGTKeyToNucleotides;

use Moose;
use Bio::Chado::Schema;
use SGN::Model::Cvterm;
use Try::Tiny;
use JSON;
use Scalar::Util qw(looks_like_number);
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
Allows addition of a link to the raw data file for genotyping plates

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


    print STDERR "INSERTING CV TERMS...\n";

    my $protocol_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "vcf_map_details", "protocol_property")->cvterm_id();
    my $genotype_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "vcf_snp_genotyping", "genotype_property")->cvterm_id();

    my $q = "SELECT nd_protocolprop.nd_protocol_id, nd_protocolprop.value, genotypeprop.genotypeprop_id FROM nd_protocolprop JOIN nd_protocol using(nd_protocol_id) JOIN nd_experiment_protocol USING(nd_protocol_id) JOIN nd_experiment USING(nd_experiment_id) JOIN nd_experiment_genotype USING(nd_experiment_id) JOIN genotype USING(genotype_id) JOIN genotypeprop USING (genotype_id) WHERE nd_protocolprop.type_id = $protocol_type_id AND genotypeprop.type_id=$genotype_type_id;";

    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute();
    while (my ($protocol_id, $protocolprop_value, $genotypeprop_id) = $h->fetchrow_array()) {

        my $protocolprop_hash = decode_json $protocolprop_value;
        my $markers_hash = $protocolprop_hash->{'markers'};

        my $q2 = "SELECT genotypeprop_id, value FROM genotypeprop WHERE genotypeprop_id = $genotypeprop_id;";
        my $h2 = $schema->storage->dbh()->prepare($q2);
        $h2->execute();
        while (my ($genotypeprop_id, $genotypeprop_value) = $h2->fetchrow_array()) {
            print STDERR "Updating genotypeprop_id $genotypeprop_id\n";
            my $genotypeprop_hash = decode_json $genotypeprop_value;
            my %new_genotypeprop_hash;
            while (my ($marker_name, $geno) = each %$genotypeprop_hash) {
                my $gt = $geno->{'GT'};
                if ($gt) {
                    my $marker_info = $markers_hash->{$marker_name};
                    my $ref = $marker_info->{'ref'};
                    my $alt = $marker_info->{'alt'};
                    my @separated_alts = split ',', $alt;
                    
                    my @nucleotide_genotype;
                    my $separator = '/';
                    my @alleles = split (/\//, $gt);
                    if (scalar(@alleles) < 1){
                        @alleles = split (/\|/, $gt);
                        if (scalar(@alleles) > 0) {
                            $separator = '|';
                        }
                    }
                    foreach (@alleles) {
                        if (looks_like_number($_)) {
                            my $index = $_ + 0;
                            if ($index == 0) {
                                push @nucleotide_genotype, $ref; #Using Reference Allele
                            } else {
                                push @nucleotide_genotype, $separated_alts[$index-1]; #Using Alternate Allele
                            }
                        } else {
                            push @nucleotide_genotype, $_;
                        }
                    }
                    $geno->{'GT'} = join $separator, @nucleotide_genotype;
                }
                $new_genotypeprop_hash{$marker_name} = $geno;
            }
            my $new_genotypeprop_string = encode_json \%new_genotypeprop_hash;
            my $q3 = "UPDATE genotypeprop SET value = '$new_genotypeprop_string' WHERE genotypeprop_id = $genotypeprop_id;";
            my $h3 = $schema->storage->dbh()->prepare($q3);
            $h3->execute();
        }
    }

print "You're done!\n";
}


####
1; #
####
