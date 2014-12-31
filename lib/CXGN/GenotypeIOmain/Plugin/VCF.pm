
package CXGN::GenotypeIOmain::Plugin::VCF;

use Moose::Role;
use Data::Dumper;

sub init { 
    my $self = shift;
    my $args = shift;

    open(my $F, "<", $args->{file}) || die "Can't open file $args->{file}\n";

    my $header = <$F>;
    
    chomp($header);
 
   my @fields = split /\t/, $header;
    chomp(@fields);
    return { 
	count => scalar(@fields) - 9,
	header => \@fields,
    };
}

sub next {
    my $self = shift;
    my $file = shift;
    my $current = shift;

    #print STDERR "VCF NEXT CALLED\n";
    open(my $F, "<", $file) || die "Can't open file $file\n";

    my $header = <$F>;
    chomp($header);
    my @header = split /\t/, $header;

    my %genotype;
    my %rawscores;

    while (<$F>) { 
	chomp;
	my @fields = split /\t/;
	
	my $score = $fields[$current+9];
	if (defined($score)) { 
	    $score =~ s/([0-9.]\/[0-9.])\:.*/$1/;
	    $genotype{ $fields[2] } = $score;
	    $rawscores{ $fields[2] } = $fields[$current+9];
	}
    }
    close($F);
    return \%genotype, \%rawscores;
}


sub close { 
    my $self  = shift;
    # not really needed
}

1;
