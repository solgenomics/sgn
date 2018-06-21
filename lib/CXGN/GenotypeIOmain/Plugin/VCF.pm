
package CXGN::GenotypeIOmain::Plugin::VCF;

use Moose::Role;
use Data::Dumper;

use CXGN::Genotype::SNP;

has 'file' => ( isa => 'Str',
		is => 'rw',
    );

has 'fh' => (isa => 'FileHandle',
	     is => 'rw',
    );

has 'current' => (isa => 'Int',
		  is => 'rw',
    );

has 'markers' => (isa => 'ArrayRef',
		  is => 'rw',
    );

has 'header' => (isa => 'ArrayRef',
		 is => 'rw',
    );

has 'accessions' => (isa => 'ArrayRef',
		     is => 'rw',
    );

sub init { 
    my $self = shift;
    my $args = shift;

    $self->file($args->{file});
	
	my $F;
	open($F, "<", $args->{file}) || die "Can't open file $args->{file}\n";
	
		#my $first_line = <$F>;
		#if ($first_line =~ /^\s*#/) {
		#	chomp($first_line);
		#}

		my $header = <$F>;
		chomp($header);
		#print STDERR "HEADER = $header\n";
		my @fields = split /\t/, $header;
		my @observation_unit_names = @fields[9..$#fields];

		my @markers;
		while (<$F>) { 
		chomp;
			my @values = split /\t/;
			if ($values[2] eq '.') {
				push @markers, $values[0]."_".$values[1];
			} else {
				push @markers, $values[2];
			}
		}

		$self->header(\@fields);
		$self->observation_unit_names(\@observation_unit_names);
		$self->markers(\@markers);
		
    close($F);
	
	my $fh = IO::File->new($args->{file});
    my $ignore_first_line = <$fh>;
    $self->current(1);
    $self->fh($fh);
}

sub next {
    my $self = shift;

	#print STDERR "VCF NEXT CALLED\n";
	my $line;
	my $fh = $self->fh();
	if ( defined($line = <$fh>) ) { 
		
		chomp($line);
		my @fields = split /\t/, $line;
	
		my @marker_info = @fields[ 0..8 ];
		my @values = @fields[ 9..$#fields ];

		#$self->current( $self->current()+1 );
		return (\@marker_info, \@values);
    }
    return undef;
}


sub close { 
    my $self  = shift;
    # not really needed
}

sub summary_stats { 
    my $self = shift;
#    my $file = shift;

    open(my $F, "<", $self->file) || die "Can't open file ".$self->file();

    my %stats = ();

    my $header = "";
    my @accessions = ();
    
    while (<$F>) { 
	chomp;
	
        # find header line
	#
	if (m/^\#CHROM/) { 
	    $header = $_;
	    
	    my @fields = split /\s+/, $header;
	    @accessions = @fields[9..$#fields];
	    
	    
	    next;
	}
	
	if (! $header) { 
	    next; 
	}

	my @fields = split /\s+/;
	my @snps = @fields[9..$#fields];
	
	#print Dumper(\@snps);
	
	for(my $n = 0; $n<@snps; $n++) { 
	    my $snp = CXGN::Genotype::SNP->new( { id=>$fields[2], format=>$fields[8], vcf_string=> $snps[$n] });
	    
	    if ($snp->good_call()) { 
		$stats{$accessions[$n]}++;
	    }
	    
	}
    }
    return \%stats;
}

1;
