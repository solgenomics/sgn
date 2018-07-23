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

    # open(my $F, "<", $args->{file}) || die "Can't open file $args->{file}\n";

    # # gather accession names (encoded in line starting with #CHROM)
    # #
    # my $header = "";
    # while (<$F>) { 
    # 	chomp();

    # 	if (m/\#CHROM/) { 	
    # 	    $header = $_;
    # 	    last();
    # 	}
    # }
    
    # close($F);

    # gather marker names
    #
    my @markers = ();
    my @accessions = ();
    
    open(my $F, "<", $args->{file}) || die "Can't open file $args->{file}\n";

    my $header_seen = 0;
    while (<$F>){ 
	chomp;
	if ($header_seen) { 
	    my @fields = split /\t/;
	    push @markers, $fields[2];
	}
	if (m/^\#CHROM/) { 
	    $header_seen=1;
	    my @fields = split /\t/;
	    @accessions = @fields[9..$#fields];
	}

    }

    $self->markers(\@markers);
    $self->accessions(\@accessions);
}

sub next {
    my $self = shift;
    #my $file = shift;
    my $current = shift;

    #print STDERR "VCF NEXT CALLED\n";
    open(my $F, "<", $self->file) || die "Can't open file $self->file\n";

    print STDERR "Zooming to header...\n";
    while (<$F>) { 
	chomp;
	if (m/\#CHROM/) { 
	    last();
	}
    }

    my @markers = ();;
    my %rawscores = ();

    print STDERR "Starting genotype parsing...\n";
    my $lines_parsed = 0;
    while (<$F>) { 
	chomp;
	my @fields = split /\t/;
	
	#my $score = $fields[$current+9];
	#if (defined($score)) { 
	    #$score =~ s/([0-9.]\/[0-9.])\:.*/$1/;
	    #$genotype{ $fields[2] } = $score;
	    $rawscores{ $fields[2] } = $fields[$current+9];
	#}
	push @markers, $fields[2];
	$lines_parsed++;
	if ($lines_parsed % 500 ==0) { print STDERR "$lines_parsed         \r"; }
    }
    
    my $genotype = $self->accessions()->[$self->current()];

    close($F);
    $self->current( $self->current()+1 );
    return (\@markers, \%rawscores, $genotype);
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
