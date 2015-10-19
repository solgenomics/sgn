
package CXGN::Genotype::SNP;

use Moose;

use Math::BigInt;

sub BUILD { 
    my $self = shift;
    my $args = shift;
    
    if ($args->{vcf_string}) { 
	#print STDERR "Building SNP from vcf_string $args->{vcf_string}...\n";
	$self->from_vcf_string($args->{vcf_string});
	
	#print STDERR "Counts: ".$self->ref_count().", ".$self->alt_count()."\n";
    }
}

has 'id' => (isa => 'Str',
	     is => 'rw',
    );

has 'format' => ( isa => 'Str',
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

    my @ids;
    if ($self->format()) { 
	@ids = split ":", $self->format();
    }
    if (!@ids) { 
	# usual order... but this is just guesswork
	#print STDERR "(Guessing the format order...)\n";
	@ids = ( 'GT', 'AD', 'DP', 'GQ', 'PL' );
    }
    
    my @values = split /\:/, $raw;
    
    my %fields;
    for(my $i=0; $i<@ids; $i++) { 
	 $fields{$ids[$i]} = $values[$i];
     }

     #my ($allele, $counts) = split /\:/, $raw;
     my ($a1, $a2) = ("","");
     if (!exists($fields{GT})) { 
	 print STDERR "No allele calls found for snp ".$self->id()."\n";
     }
     else { 
	 ($a1, $a2) = split /\//, $fields{GT};
     }
     $self->ref_allele($a1);
     $self->alt_allele($a2);

     my ($c1, $c2);
     if (!exists($fields{AD})) { 
	 $c1 = 0;
	 #print STDERR "C1: $c1\n";
	 $c2 = 0;
	 #print STDERR "C2: $c2\n";
     }
     else { 
	 my @counts = split /\,/, $fields{AD};
	 # print STDERR "FIELDS: $fields{AD}\n"; 
	 if (@counts > 2) { 
	     #print STDERR "Multiple alleles found for SNP ".$self->id()."\n";
	 }
	 ($c1, $c2) = @counts;
     }
    if (!defined($c1)) { $c1=0; }
    if (!defined($c2)) { $c2=0; }
     $self->ref_count($c1);
     $self->alt_count($c2);
     
    # debug
    #if ($self->id() eq "1002:250060174") { 
	#print STDERR $self->id().": ".$fields{GT}.", ".$fields{AD}."\n";
    #}

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
