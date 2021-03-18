
=head1 NAME

CXGN::Phenotypes::File - a class to parse out information from the files that phenotype searching returns

=head1 DESCRIPTION

=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>

=cut
    
package CXGN::Phenotypes::File;

use Moose;
use Data::Dumper;
use File::Slurp qw | slurp |;

has 'file' => (is => 'rw', isa => 'Str');

has 'factors' => ( is => 'rw', isa => 'ArrayRef' );

has 'traits' => ( is => 'rw', isa => 'ArrayRef' );

has 'levels' => ( is => 'rw', isa => 'HashRef' );

has 'remove_quotes' => (is => 'rw', isa => 'Bool', default => sub { return 1; } );

our $FACTOR_COUNT = 38; # number of columns in the file before traits columns start

sub BUILD {
    my $self = shift;
    my @lines = slurp($self->file());
    
    my $header = $lines[0];
    chomp($header);
    
    my @keys = split("\t", $header);

    if ($self->remove_quotes()) {
	foreach my $k (@keys) { 
	    print STDERR "Removing quotes from $k...";
	    $k=~ s/^\"(.*)\"$/$1/;
	    print STDERR "Now $k...\n";
	}
    }
    
    
    my @data = ();
    my %line = ();
    my %levels = ();
    
    for (my $i=1; $i<@lines; $i++) { 
	my @fields = split /\t/, $lines[$i];
	for(my $n=0; $n <@keys; $n++) {
	    if ($self->remove_quotes()) {
		print STDERR "Removing quotes from $fields[$n]...";
		$fields[$n]=~ s/^\"(.*)\"$/$1/;
		print STDERR "Now $fields[$n]...\n"; 
	    }
	    
	    if (exists($fields[$n]) && defined($fields[$n])) {
		$line{$keys[$n]}=$fields[$n];
		if ($n<39) { 
		    $levels{$keys[$n]}->{fields}->{$fields[$n]}++;
		    $levels{$keys[$n]}->{distinct} = scalar(keys(%{$levels{$keys[$n]}->{fields}}));
		} 
	    }
	}	
	push @data, \%line;
    }
    $self->factors( [ @keys[0..$FACTOR_COUNT] ] );
    $self->traits( [ @keys[ $FACTOR_COUNT+1..scalar(@keys) ] ] );
    
    $self->levels(\%levels);
    
}

sub distinct_levels_for_factor {
    my $self = shift;
    my $factor = shift;

    print STDERR "LEVELS: ".Dumper($self->levels());
    return $self->levels()->{$factor}->{distinct};
}


1;
