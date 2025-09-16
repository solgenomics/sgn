

=head1 NAME

CXGN::VectorViewer - a class to work with vectors

=head1 DESCRIPTION

This class implements a viewer/editor for circular vector sequences.

For data input, a genbank record can be used using the parse_genbank() function. It can also detect restriction sites in the sequence using the restricton_analysis() function.

All data is stored in object properties, including:

   feature_table: the features with columns name, start_coord, end_coord, direction

   restriction_table: restriction_enzyme_name, coord

   vector_sequence: the full sequence of the vector

   vector_length: the length of the vector, in case sequence is not provided. Should match sequence length otherwise

   vector_name: the name of the vector


=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>

=head1 METHODS

This class implements the following methods:

=cut


package CXGN::VectorViewer;

use Moose;

use Bio::SeqIO;
use Bio::Restriction::Analysis;

has 'feature_table' => ( isa => 'ArrayRef',
			 is => 'rw',
    );

has 'restriction_table' => ( isa => 'ArrayRef',
			     is => 'rw',
    );

has 'vector_name' => ( isa => 'Str',
			   is => 'rw',
    );

has 'vector_sequence' => ( isa => 'Str',
			   is => 'rw',
    );

has 'vector_length' => (isa => 'Int',
			is => 'rw',
    );


=head2 parse_genbank

 Usage:        $vv->parse_genbank($genbank_string)
 Desc:         parses the genbank record in the string
 Ret:
 Args:
 Side Effects: modifies the internal drawing commands.
 Example:

=cut

sub parse_genbank {
    my $self = shift;
    my $string = shift;

    my $feature_table = [];

    # get a string into $string somehow, with its format in $format, 
    # say from a web form.

    my $format = "genbank";

    my $stringfh = IO::String->new($string); 
    open($stringfh, "<", $string) or die "Could not open data for reading: $!";

    my $seqio = Bio::SeqIO-> new(-fh     => $stringfh,
				 -format => $format,
	);
    
    my $s = $seqio->next_seq();
    my @commands = ();
    my @features = $s -> get_SeqFeatures();
    foreach my $f (@features) { 
	my $dir = "F";
	if ($f->strand() != 1) { $dir = "R"; }
	my $name;
	if ($f->primary_tag() eq "gene") {
	    foreach my $tag ($f->all_tags()) { 
		($name) = $f->each_tag_value("gene");
	    }

	    push @$feature_table, [ "FEATURE",  $name, $f->start(), $f->end(), $dir ];
	}
	else {
	    print STDERR "IGNORING TAG: ".$f->primary_tag()."\n";
	}

    }
    $self->feature_table($feature_table);
    $self->vector_sequence($s->seq());
}

=head2 restriction_analysis

 Usage:        my $vv->restriction_analysis($ra_type)
 Desc:         performs the restriction analysis on the sequence.
               $ra_type can be any of the following:
               "all": all enzymes are shown. Usually overwhelming.
               "unique": the restriction enzymes that cut the sequence
                         only once are shown.
               "popular6bp": Popular 6bp restriction enzymes are shown
               "popular4bp": Popular 4bp restriction enzymes are shown
 Ret:
 Args:
 Side Effects: adds the restriction enzymes found to the drawing 
               commands.
 Example:

=cut

sub restriction_analysis {
    my $self = shift;
    my $ra_type = shift;

    my $seq = Bio::Seq->new( -seq=>$self->get_sequence());
    $seq->is_circular(1);
    if (!$seq->is_circular()) { die "It is not circular!"; }
    my $ra = Bio::Restriction::Analysis->new($seq);
    my $cutters;
    if ($ra_type eq "unique") { 
	$cutters = $ra->unique_cutters();
    }
    else {
	$cutters = $ra->cutters();
    }
    foreach my $c ($cutters->each_enzyme()) {
	my $enzyme = $c->name();
	if ($ra_type eq "popular6bp") { 
	    if (!(grep /^$enzyme$/, ($self->popular_6bp_enzymes()))) { 
		next();
	    }
	}
	if ($ra_type eq "popular4bp") {
	    if (!(grep /^$enzyme$/, ($self->popular_4bp_enzymes()))) { 
		next();
	    }
	}
		
	my @fragments = $ra ->fragment_maps($c->name());
	foreach my $f (@fragments) { 
	    $self->add_command( "FEATURE",  $c->name(), $f->{start}, $f->{end}, "F", "gray");
	}
	
    }
}


=head2 popular_6bp_enzymes

 Usage:        my @enzymes = $vv->popular_6bp_enzymes()
 Desc:         returns a list of popular 6bp enzymes
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub popular_6bp_enzymes { 
    return qw | ClaI EcoRI EcoRV SmaI SmaIII HindIII BamHI KpnI SalI ScaI SphI PstI NotI XbaI XhoI SacI |;
}

=head2 popular_4bp_enzymes

 Usage:        my @enzymes = $vv->popular_4bp_enzymes()
 Desc:         returns a list of popular 4bp enzymes
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub popular_4bp_enzymes { 
    return qw | MboI AluI HaeIII Sau3A TaqI |;

}

1;

