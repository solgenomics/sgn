
package CXGN::GenotypeIOmain::Plugin::Dosage;

use Moose::Role;
use Data::Dumper;

sub init { 
    my $self = shift;
    my $args = shift;

    open(my $F, "<", $args->{file}) || die "Can't open file $args->{file}\n";

    my $header = <$F>;

    my @fields = split /\t/, $header;

    return { 
	count => scalar(@fields)-1,
	header => \@fields,
    };
}

sub next {
    my $self = shift;
    my $file = shift;
    my $current = shift;

    open(my $F, "<", $file) || die "Can't open file $file\n";

    my $header = <$F>;
    chomp($header);
    my @header = split /\t/, $header;

    my %genotypes;

    while (<$F>) { 
	chomp;
	my @fields = split /\t/;
	
	my $score = $fields[$current+1];
	$genotypes{ $fields[2] } = $score;
    }
    
    return \%genotypes;    
}

1;
