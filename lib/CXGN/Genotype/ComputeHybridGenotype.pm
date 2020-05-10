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
