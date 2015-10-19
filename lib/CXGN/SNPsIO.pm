
=head NAME

CXGN::SNPsIO;

=head DESCRIPTION

=head AUTHOR

=cut

package CXGN::SNPsIO;

use Moose;

use Data::Dumper;
use IO::File;
use CXGN::Genotype::SNP;

has 'file' => ( isa => 'Str',
		is  => 'rw',
		required => 1,
    );

has 'fh' => (isa => 'FileHandle',
	     is => 'rw',
    );

has 'header' => ( isa => 'Str',
		  is  => 'rw',
    );

has 'accessions'  => ( isa => 'ArrayRef',
		  is  => 'rw',
    );
 
has 'ignore_accessions' => (isa => 'HashRef',
			    is => 'rw',
    );

has 'valid_accessions' => (isa => 'ArrayRef',
			   is => 'rw',
    );

has 'filter' => ( isa => 'Str',
		  is  => 'rw',
    );



sub BUILD { 
    my $self = shift;
    my $args = shift;

    my $fh = IO::File->new($args->{file});
    
    while (<$fh>) { 
	chomp;

	if (m/^\#\#/) { 
	    next;
	}

	if (m/^\#CHROM/) { 
	    chomp($_);
	    #print STDERR "found header $_\n";
	    $self->header($_);
	    # CHROM  POS     ID      REF     ALT     QUAL    FILTER  INFO    FORMAT SNPS..
	    my @fields = split /\s+/, $_;
	    chomp(@fields);
	    my @accessions = @fields[9..$#fields];
	    $self->accessions(\@accessions);
	    print STDERR "ACCESSIONS: ".join("|", @accessions)."\n";
	    last;
	}
    }
    $self->fh($fh);
}

sub next_line { 
    my $self = shift;
    
    my $line = "";
    my $fh = $self->fh();
    if ($line = <$fh>) { 
	chomp($line);
	return $line;
    }
    else { 
	if (! $self->header() ) {
	    die "Header not seen. This file may have format problems.\n";
	}
	return undef;
    }
}

sub next { 
    my $self = shift;
    my $line = $self->next_line();
    
    if (defined($line)) { 
	
	my ($chr, $position, $snp_id, $ref_allele, $alt_allele, $qual, $filter, $info, $format,  @snps) = split /\t/, $line;
	#print STDERR "Processing $snp_id\n";
	my $snps = CXGN::SNPs->new( );
	$snps->raw($line);
	$snps->id($snp_id);
	$snps->chr($chr);
	$snps->position($position);
	$snps->ref_allele($ref_allele);
	$snps->alt_allele($alt_allele);
	$snps->qual($qual);
	$snps->filter($filter);
	my $depth = $info;
	$depth =~ s/DP=(\d+)/$1/i;
	if ($depth eq ".") { $depth=0; }
	$snps->depth($depth);
	$snps->info($info);
	$snps->format($format);
	$snps->accessions($self->accessions());
	$snps->valid_accessions($self->accessions());
	#print STDERR "ACCESSIONS: ".(join ",", @{$self->{accessions}})."\n";
	my %snp_objects = ();
	for(my $n=0; $n<@snps; $n++) { 
	    my $snp = CXGN::Genotype::SNP->new( { id=>$snp_id, format => $format, vcf_string => $snps[$n] } );
	    
	    my $accession = $self->accessions()->[$n]."\n";
	    chomp($accession);
	    #print "ACCESSION: $accession\n";
	    #if ($accession =~ m/1002:250060174/) { print STDERR "Saw accession 1002:250060174" }
	    $snp->accession($accession);
	    $snp_objects{$accession} = $snp;
	}
	#print STDERR Dumper(\%snp_objects);
	$snps->snps(\%snp_objects);
	return $snps;
    }
    else { 
	#print STDERR "LINE NOT DEFINED.\n";
	return undef;
    }
}

sub close { 
    my $self = shift;
    close($self->fh());
}

sub total_accessions { 
    my $self = shift;
    return scalar(@{$self->accessions});
}


__PACKAGE__->meta->make_immutable;

1;
