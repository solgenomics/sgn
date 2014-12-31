
package CXGN::GenotypeIOmain::Plugin::VCF;

use Moose::Role;
use Data::Dumper;

sub init { 
    my $self = shift;
    my $args = shift;

    open(my $F, "<", $args->{file}) || die "Can't open file $args->{file}\n";

    my $header = "";
    while (<$F>) { 
	chomp();

	if (m/\#CHROM/) { 	
	    $header = $_;
	    last();
	}
    }
    
    close($F);

    if ($header) { 	
	my @fields = split /\t/, $header;
	
    
	return { 
	    count => scalar(@fields) - 9,
	    header => \@fields,
	};
    }
    else { 
	return { 
	    count => 0,
	    header => '',
	}
    }
}

sub next {
    my $self = shift;
    my $file = shift;
    my $current = shift;

    #print STDERR "VCF NEXT CALLED\n";
    open(my $F, "<", $file) || die "Can't open file $file\n";

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
    close($F);
    return (\@markers, \%rawscores);
}


sub close { 
    my $self  = shift;
    # not really needed
}

1;
