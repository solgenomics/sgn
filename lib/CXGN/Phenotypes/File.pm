
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
	    #print STDERR "Removing quotes from $k...";
	    $k=~ s/^\"(.*)\"$/$1/;
	    #print STDERR "Now $k...\n";
	}
    }
    
    
    my @data = ();
    my %line = ();
    my %levels = ();
    
    for (my $i=1; $i<@lines; $i++) { 
	my @fields = split /\t/, $lines[$i];
	for(my $n=0; $n <@keys; $n++) {
	    if ($self->remove_quotes()) {
		#print STDERR "Removing quotes from $fields[$n]...";
		$fields[$n]=~ s/^\"(.*)\"$/$1/;
		#print STDERR "Now $fields[$n]...\n"; 
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

    #print STDERR "LEVELS: ".Dumper($self->levels());
    return $self->levels()->{$factor}->{distinct};
}

=head2 make_R_variable_name

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub make_R_variable_name {
    my $name = shift;
    $name =~ s/\s/\_/g;
    $name =~ s/\//\_/g;
    $name =~ tr/ /./;
    $name =~ tr/\//./;
    $name =~ s/\:/\_/g;
    $name =~ s/\|/\_/g;
    $name =~ s/\-/\_/g;

    return $name;
}


sub convert_file_headers_back_to_breedbase_traits {
    my $self = shift;
    my $file = shift || $self->file().".matrix";
    
    my $conversion_matrix = $self->read_conversion_matrix($file);

    open(my $F, "<", $file) ||  die "Can't open $file\n";

    print STDERR "Opening ".$self->file().".original_traits for writing...\n";
    open(my $G, ">", $file.".original_traits") || die "Can't open $file.original_traits";
    
    my $header = <$F>;
    chomp($header);
    
    my @fields = split /\t/, $header;
    
    foreach my $f (@fields) {
	if ($conversion_matrix->{$f}) {
	    print STDERR "Converting $f to $conversion_matrix->{$f}...\n";
	    $f = $conversion_matrix->{$f};
	}
    }

    
    print $G join("\t", @fields)."\n";
    while(<$F>) {
	chomp;

	# replace NA or . with undef throughout the file
	# (strings are not accepted by store phenotypes routine
	# used in analysis storage).
	#
	my @fields = split /\t/;
	foreach my $f (@fields) {
	    if ($f eq "NA" || $f eq '.') { $f = undef; }
	}
	my $line = join("\t", @fields);
	print $G "$line\n";
    }
    close($G);

    print STDERR "move file $file.original_traits back to $file...\n";
    move($file.".original_traits", $file);
}


sub read_conversion_matrix {
    my $self = shift;
    my $file = shift;

    my $conversion_file = $file;
    
    open(my $F, "<", $conversion_file) || die "Can't open file $conversion_file";

    my %conversion_matrix;
    
    while (<$F>) {
	chomp;
	my ($new, $old) = split "\t";
	$conversion_matrix{$new} = $old;
    }
    return \%conversion_matrix;
}

sub clean_file {
    my $self = shift;
    my $file = shift || $self->file();

    open(my $PF, "<", $file) || die "Can't open pheno file ".$file."_phenotype.txt";
    open(my $CLEAN, ">", $file.".clean") || die "Can't open ".$file.".clean for writing";

    open(my $TRAITS, ">", $file.".traits") || die "Can't open ".$file.".traits for writing";

    
    my $header = <$PF>;
    chomp($header);

    my @fields = split /\t/, $header;

    my @file_traits = @fields[ 39 .. @fields-1 ];
    my @other_headers = @fields[ 0 .. 38 ];

    print STDERR "FIELDS: ".Dumper(\@file_traits);

    foreach my $t (@file_traits) {
	my $R_t = make_R_variable_name($t);
	print $TRAITS "$R_t\t$t\n";
	$t = $R_t;
    }

    print STDERR "FILE TRAITS: ".Dumper(\@file_traits);

    my @new_header = (@other_headers, @file_traits);
    print $CLEAN join("\t", @new_header)."\n";

    while(<$PF>) {
	print $CLEAN $_;
    }

    close($PF);
    print STDERR "moving $file to $file.before_clean...\n";
    move($file, $file.".before_clean");

    print STDERR "moving $file.clean to $file...\n";
    move($file.".clean", $file);

    return $file;
}


1;
