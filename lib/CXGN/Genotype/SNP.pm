
package CXGN::Genotype::SNP;

use Moose;

use Math::BigInt;

sub BUILD { 
    my $self = shift;
    my $args = shift;
    
    if ($args->{vcf_string}) { 
	$self->from_vcf_string($args->{vcf_string});
    }
}

has 'id' => (isa => 'Str',
	     is => 'rw',
    );

has 'vcf_string' => ( isa => 'Str',
	       is  => 'rw',
    );
has 'accession' => (isa => 'Str',
		    is => 'rw',
    );

has 'ref_allele' => ( isa => 'Str',
		   is  => 'rw',
    );

has 'alt_allele' => ( isa => 'Str',
		   is  => 'rw',
    );

has 'ref_count' => ( isa => 'Int',
		  is  => 'rw',
    );

has 'alt_count' => ( isa => 'Int',
		  is  => 'rw',
    );

has 'dosage' => ( 
		  is  => 'rw',
    );


sub from_vcf_string { 
    my $self = shift;
    my $raw = shift;

    my ($allele, $counts) = split /\:/, $raw;
    
    my ($a1, $a2) = split /\//, $allele;

    $self->ref_allele($a1);
    $self->alt_allele($a2);

    my ($c1, $c2) = split /\,/, $counts;
    
    $self->ref_count($c1);
    $self->alt_count($c2);

    return ($c1, $c2);
}

sub good_call { 
    my $self = shift;
    my $call_sum_min = shift || 2;
    my ($c1, $c2) = ($self->ref_count(), $self->alt_count());
    if ( ($c1 + $c2) < $call_sum_min) { 
	return 0;
    }
    return 1;
}


__PACKAGE__->meta->make_immutable;

1;
