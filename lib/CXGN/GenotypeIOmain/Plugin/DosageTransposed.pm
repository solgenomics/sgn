
package CXGN::GenotypeIOmain::Plugin::DosageTransposed;

use Moose::Role;
use Data::Dumper;


has 'file' => (isa => 'Str',
	       is => 'rw',
    );

has 'fh' => ( isa => 'FileHandle',
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



    my $header = <$F>;
    chomp($header);
    #print STDERR "HEADER = $header\n";
    my @markers = split /\t/, $header;
    shift(@markers); # remove first column header (for accession column)

    my @accessions;
    while (<$F>) { 
	chomp;
	my @fields = split /\t/;
	push @accessions, $fields[0];
    }

    $self->accessions(\@accessions);
    $self->markers(\@markers);
    #print STDERR Dumper(\@markers);
    close($F);
    
    #open($F, "<", $args->{file}) || die "Can't open file $args->{file}\n";
    my $fh = IO::File->new($args->{file});
    my $ignore_first_line = <$fh>;
    $self->current(1);
    $self->fh($fh);
}

sub next {
    my $self = shift;

    my %genotype;
    my $line;
    my $fh = $self->fh();
    if ( defined($line = <$fh>) ) { 
	chomp($line);

	my @fields = split /\t/, $line;
	
	my @scores = @fields[ 1..$#fields ];

	for(my $n=0; $n< (@{$self->markers()}); $n++) { 	    
	    $genotype{$self->markers()->[$n]} = $scores[$n];
	}
	return (\%genotype, \%genotype, $fields[0]);
    }
    return undef;

}

sub summary_stats { 
    my $self = shift;


}


sub close { 
    my $self = shift;
    close($self->fh());
}

1;
