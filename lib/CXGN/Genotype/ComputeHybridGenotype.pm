package CXGN::Genotype::ComputeHybridGenotype;

=head1 NAME

CXGN::Genotype::GRM - an object to handle fetching a GRM for stocks

=head1 USAGE

my $geno = CXGN::Genotype::ComputeHybridGenotype->new({
    parental_genotypes=>\@parental_genotypes,
    marker_objects=>\@marker_objects
});
my $hybrid_genotype = $geno->get_hybrid_genotype();

=head1 DESCRIPTION


=head1 AUTHORS

 Nicolas Morales <nm529@cornell.edu>

=cut

use strict;
use warnings;
use Moose;
use Data::Dumper;
use SGN::Model::Cvterm;
use JSON;
use POSIX;
use List::Util qw(sum);

has 'parental_genotypes' => (
    isa => 'ArrayRef[HashRef]',
    is => 'rw',
    required => 1
);

has 'marker_objects' => (
    isa => 'ArrayRef[HashRef]',
    is => 'rw',
    required => 1
);

sub get_hybrid_genotype {
    my $self = shift;
    my $parental_genotypes = $self->parental_genotypes();
    my $marker_objects = $self->marker_objects();

    # print STDERR Dumper $parental_genotypes;

    # If there are more than one genotype for the parents given, will average them
    if (scalar(@$parental_genotypes)>2) {
        my %parental_genotypes;
        my @parental_genotypes_averaged;
        foreach my $g (@$parental_genotypes) {
            my $geno = $g->{selected_genotype_hash};
            my $parent = $g->{germplasmName};
            push @{$parental_genotypes{$parent}}, $geno;
        }
        while (my ($parent, $genos) = each %parental_genotypes) {
            my %averaged_parent_geno;
            foreach my $m (@$marker_objects) {
                my $marker_name = $m->{name};
                my @avg_ds;
                foreach my $g (@$genos) {
                    my $ds = $g->{$marker_name}->{DS} ne 'NA' ? $g->{$marker_name}->{DS} : undef;
                    if (defined($ds)) {
                        push @avg_ds, $ds;
                    }
                }
                my $avg_ds_val;
                if (scalar(@avg_ds) > 0) {
                    $avg_ds_val = sum(@avg_ds)/scalar(@avg_ds);
                }
                else {
                    $avg_ds_val = 'NA';
                }
                $averaged_parent_geno{$marker_name} = {DS => $avg_ds_val};
            }
            push @parental_genotypes_averaged, {
                selected_genotype_hash => \%averaged_parent_geno
            }
        }
        $parental_genotypes = \@parental_genotypes_averaged;
    }

    my @progeny_genotype;
    # If both parents are genotyped, calculate progeny genotype as a average of parent dosage
    if ($parental_genotypes->[0] && $parental_genotypes->[1]) {
        my $parent1_genotype = $parental_genotypes->[0]->{selected_genotype_hash};
        my $parent2_genotype = $parental_genotypes->[1]->{selected_genotype_hash};
        foreach my $m (@$marker_objects) {
            if ($parent1_genotype->{$m->{name}}->{DS} ne 'NA' || $parent2_genotype->{$m->{name}}->{DS} ne 'NA') {
                my $p1 = $parent1_genotype->{$m->{name}}->{DS} ne 'NA' ? $parent1_genotype->{$m->{name}}->{DS} : 0;
                my $p2 = $parent2_genotype->{$m->{name}}->{DS} ne 'NA' ? $parent2_genotype->{$m->{name}}->{DS} : 0;
                push @progeny_genotype, ($p1 + $p2) / 2;
            }
            else {
                push @progeny_genotype, 'NA';
            }
        }
    }
    elsif ($parental_genotypes->[0]) {
        my $parent1_genotype = $parental_genotypes->[0]->{selected_genotype_hash};
        foreach my $m (@$marker_objects) {
            if ($parent1_genotype->{$m->{name}}->{DS} ne 'NA') {
                my $val = $parent1_genotype->{$m->{name}}->{DS};
                push @progeny_genotype, $val/2;
            }
            else {
                push @progeny_genotype, 'NA';
            }
        }
    }
    return \@progeny_genotype;
}

1;
