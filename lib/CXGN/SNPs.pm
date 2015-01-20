
=head1 NAME

CXGN::SNPs - deal with collections of SNPs

=head1 SYNOPSYS

 my $snps = CXGN::SNPs->new( { file => $file });
 my $allele_feq = $snps->allele_freq();
 my $dosage = $snps->calculate_snp_dosage($snp); # provide a CXGN::Genotype::SNP object
 # etc

=head1 AUTHOR
    
Lukas Mueller <lam87@cornell.edu>

=head1 METHODS

=cut

package CXGN::SNPs;

use Moose;

use Data::Dumper;
use Math::BigInt;

=head2 accessors id()

The id of the SNP.

=cut

has 'id' => ( isa => 'Str',
	      is => 'rw',
    );

=head2 accessors accessions()

All the accessions parsed in the SNP

=cut

has 'accessions' => ( isa => 'ArrayRef',
		       is  => 'rw',
    );

=head2 accessors depth()

The total depth of the SNP (usually from VCF file)

=cut

has 'depth' => ( isa => 'Int',
		 is => 'rw',
    );

=head2 accessors ignore_accessions()

A hashref with accessions that have not passed some quality check and that should be ignored.

=cut

has 'ignore_accessions' => (isa => 'HashRef',
			    is => 'rw',
    );

=head2 accessors valid_accessions()

A ArrayRef of valid accessions (the complement set to ignore_accessions)

=cut

has 'valid_accessions' => (isa => 'ArrayRef',
			   is => 'rw',
    );


has 'scores'  => ( isa => 'HashRef',
		       is  => 'rw',
    );

#has 'bad_clones'  => ( isa => 'ArrayRef',
#		       is  => 'rw',
 #   );

=head2 accessors snps()

An HashRef of CXGN::Genotype::SNP objects that represent the SNP calls, with genotype ids as the hash key.

=cut

has 'snps' => ( isa => 'HashRef',
		is  => 'rw',
    );

=head2 accessors maf()

The minor allele frequency of the SNP set.

=cut

has 'maf'  => ( isa => 'Num',
		is  => 'rw',
		default => sub { 0.999 },
    );

=head2 accessors allele_freq()

The allele frequency of the SNP set.

=cut

has 'allele_freq' => ( isa => 'Num',
		       is  => 'rw',
    );



has 'chr' => ( isa => 'Str',
	       is => 'rw',
    );

has 'position' => (isa => 'Int',
		   is => 'rw',
    );

=head2 accessors ref_allele()

reference allele nucleotide

=cut

has 'ref_allele' => ( isa => 'Str',
		   is  => 'rw',
    );

=head2 accessors alt_allele()

alternative allele nucleotide

=cut 

has 'alt_allele' => ( isa => 'Str',
		   is  => 'rw',
    );



has 'qual' => ( isa => 'Str',
		is  => 'rw',
    );

has 'filter' => ( isa => 'Str',
		  is => 'rw',
    );

has 'info' => ( isa => 'Str',
		is => 'rw',
    );

has 'format' => ( isa => 'Str',
		  is => 'rw',
    );

has 'pAA' => ( isa => 'Num',
	       is => 'rw',
	      );

has 'pAB' => ( isa => 'Num',
	       is => 'rw',
    );

has 'pBB' => ( isa => 'Num',
	       is => 'rw',
    );

=head2 get_score

 Usage:        $ms->get_score('XYZ');
 Desc:         gets the marker score associated with XYZ
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_score { 
    my $self = shift;
    my $accession = shift;
    
    if (exists($self->scores()->{$accession})) { 
	return $self->scores->{$accession};
    }
    else { 
	warn "accession $accession has no associated score.\n";
	return undef;
    }
}

sub snp_stats { 
    my $self = shift;

    my $good_snps = 0;
    my $invalid_snps = 0;
    
    print STDERR Dumper($self->snps());
    foreach my $a (@{$self->valid_accessions}) { 
	my $snp = $self->snps()->{$a};
	if ($snp->good_call()) { 
	    $good_snps++;
	}
	else { 
	    $invalid_snps++;
	}
    }
    return ($good_snps, $invalid_snps);
}

sub calculate_allele_frequency_using_counts { 
    my $self = shift;
    
    my $total_c1 = 0;
    my $total_c2 = 0;
    
    foreach my $k (@{$self->valid_accessions()}) {
	my $s = $self->snps->{$k};
	$total_c1 += $s->ref_count();
	$total_c2 += $s->alt_count();
    }

    if ($total_c1 + $total_c2 == 0) { 
	return undef;
    }
    
    my $allele_freq = $total_c1 / ($total_c1 + $total_c2);
    
    my $pAA = $allele_freq **2;
    my $pAB = $allele_freq * (1 - $allele_freq) * 2 ;
    my $pBB = (1 - $allele_freq) **2;
    
    $self->allele_freq($allele_freq);
    $self->pAA($pAA);
    $self->pAB($pAB);
    $self->pBB($pBB);
    
    return $allele_freq;
}

# sub calculate_dosages { 
#     my $self = shift;
    
#     foreach my $k (keys %{$self->snps()}) { 
# 	my $s = $self->snps()->{$k};
# 	$s->calculate_snp_dosage($s, $self->error_probability());

#     }
#     #print STDERR Dumper($self->snps());
# }

=head2 function calculate_snp_dosage()

$snps->calculate_snp_dosage($snp)
Calculates the SNP dosage of SNP $snp
$snp is a CXGN::Genotype::SNP object

=cut
 
sub calculate_snp_dosage { 
    my $self = shift;
    my $snp = shift;
    my $strict_dosage_filter = shift;

    my $error_probability = 0.001;
    my $c1 = $snp->ref_count();
    my $c2 = $snp->alt_count();

    #print STDERR "counts: $c1, $c2\n";
    
    my $n = $c1 + $c2;

    my $N1 = Math::BigInt->new($n);
    my $N2 = Math::BigInt->new($n);

 #   print STDERR "$N1 bnok $c1 is: ". $N1->bnok($c1)."\n";

    my $Nbnokc1 = $N1->bnok($c1)->numify();
    my $Nbnokc2 = $N2->bnok($c2)->numify();
    
#    print STDERR "NBnokc1: $Nbnokc1, NBnokc2 $Nbnokc2\n";

    my $pDAA = $Nbnokc1 * ((1-$error_probability) ** $c1) * ($error_probability ** $c2);
    my $pDAB = $Nbnokc1 * (0.5 ** $c1) * (0.5 ** $c2);
    my $pDBB = $Nbnokc2 * ((1-$error_probability) ** $c2) * ($error_probability ** $c1);

 #   print STDERR "pDAA: $pDAA pDAB $pDAB, pDBB $pDBB\n";

    my $pSAA = $pDAA * $self->pAA;
    my $pSAB = $pDAB * $self->pAB;
    my $pSBB = $pDBB * $self->pBB;

    if ($pSAA + $pSAB + $pSBB == 0) { 
	return "NA";
    }
    
    my $x = 1 / ($pSAA + $pSAB + $pSBB);

    my $dosage = ($pSAB  + 2 * $pSBB) * $x;

    if ($strict_dosage_filter) { 
	if ( ($dosage > 0.1) && ($dosage < 0.9) ) { 
	    $dosage = "NA";
	}
	if ( ($dosage > 1.1) && ($dosage < 1.9) ) { 
	    $dosage = "NA";
	}
    }

    $snp->dosage($dosage);

    return $dosage;
}

=head2 function hardy_weinberg_filter

 $snps->hardy_weinberg_filter();
 returns a hash with the following keys:
   monomorphic   - 1 if the SNP is monomorphic
   allele_freq   - the allele frequency derived from counts
   chi           - the chi square value for hardy weinberg distribution
   scored_marker_fraction - the fraction of markers that were successfully scored
   heterozygote_count - the number of heterozygote SNPs in the set

=cut
   

sub hardy_weinberg_filter { 
    my $self = shift;
    my $dosages = shift; # ignored clones already removed
    
    my %classes = ( AA => 0, AB => 0, BB => 0, NA => 0);
    
    foreach my $d (@$dosages) { 
	if (! defined($d) || $d eq "NA") { 
	    $classes{NA}++;
	}
	elsif ( ($d >= 0) && ($d <= 0.1) ) { 
	    $classes{AA}++;
	}
	elsif ( ($d >=0.9) && ($d <= 1.1) ) { 
	    $classes{AB}++;
	}

	elsif (($d >=1.9) && ($d <= 2.0)) { 
	    $classes{BB}++;
	}
	else { 
	    #print STDERR "Dosage outlier: $d\n";
	}

    }

    print STDERR "Class counts: AA: $classes{AA}, BB: $classes{BB}, AB: $classes{AB}, NA: $classes{NA}\n";
 
    if ( ( ($classes{AA} ==0) && ($classes{AB} ==0)) ||
	( ($classes{BB} == 0) && ($classes{AB} ==0)) ) { 
	return ( monomorphic => 1);
    }

    my $total = $classes{AA} + $classes{AB} + $classes{BB};

    my %score = ();
    
    $score{total} = $total; 

    $score{scored_marker_fraction} = $total / (@$dosages);
    
    #print STDERR "AA  $classes{AA}, AB $classes{AB}, BB $classes{BB} Total: $total\n";
    my $allele_freq = (2 * $classes{AA} + $classes{AB}) / (2 * $total);

    $score{heterozygote_count} = $classes{AB};

    $score{allele_freq} = $allele_freq;
    
    my $expected = $allele_freq * (1-$allele_freq) * 2 * $total;

    #print STDERR "TOTAL: $total\n";
    my $x = ($classes{AB} - $expected)**2 / $expected;

    # only do the chi square test if the number of heterozygotes is larger than expected
    #
    if ($classes{AB} > $expected) { 
	$score{chi} = $x;
    }
    else { 
	$score{chi} = 0;
    }

    return %score;
}


__PACKAGE__->meta->make_immutable;


1;
