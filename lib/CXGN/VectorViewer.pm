

=head1 NAME

CXGN::VectorViewer - a class to work with vectors

=head1 DESCRIPTION

This class implements a viewer/editor for circular vector sequences.

For data input, a genbank record can be used using the parse_genbank() function. It can also detect restriction sites in the sequence using the restricton_analysis() function.

All data is stored in object properties, including:

   features: the features with columns name, start_coord, end_coord, direction

   restriction_table: restriction_enzyme_name, coord

   sequence: the full sequence of the vector

   vector_length: the length of the vector, in case sequence is not provided. Should match sequence length otherwise

   name: the name of the vector


=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>

=head1 METHODS

This class implements the following methods:

=cut


package CXGN::VectorViewer;

use Moose;

use Data::Dumper;
use IO::String;
use Bio::SeqIO;
use Bio::Restriction::Analysis;

has 'features' => ( isa => 'Maybe[ArrayRef]',
			 is => 'rw',
    );

has 're_sites' => ( isa => 'Maybe[ArrayRef]',
			     is => 'rw',
    );

has 'name' => ( isa => 'Maybe[Str]',
			   is => 'rw',
    );

has 'sequence' => ( isa => 'Maybe[Str]',
			   is => 'rw',
    );

has 'vector_length' => (isa => 'Int',
			is => 'rw',
    );

has 'metadata' => (isa => 'Maybe[ArrayRef]',
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

    
    my $features = [];
    
    # get a string into $string somehow, with its format in $format, 
    # say from a web form.
    
    my $format = "genbank";

    my $stringfh = IO::String->new($string); 
    
    my $seqio = Bio::SeqIO -> new(
	-fh     => $stringfh,
	-format => $format, );

    my $s = $seqio->next_seq();

    print STDERR "ID: ".$s->id();
    print STDERR "SEQUENCE : ".$s->seq();

    my @commands = ();
    my @features = $s -> get_SeqFeatures();

    foreach my $f (@features) {
	print STDERR "Processing primary tag: ".$f->primary_tag()." TAGS: ".join(",", $f->get_all_tags())."\n";
	
	my @all_tags = $f->get_all_tags();
	if (grep /note/, @all_tags) { 
	    my @notes = $f->get_tag_values('note');
	    
	    # parse the different note fields according to geneious
	    # naming conventions
	    #
	    foreach my $n (@notes) {
		print STDERR "NOTES: $n\n";
		if ($n eq "Geneious type: CDS+Stopp") {
		    print STDERR "Adding Geneious type: CDS+Stopp\n";
		    my @standard_names = $f->get_tag_values('standard_name');
		    if (exists($standard_names[0])) {
			print STDERR "Adding $standard_names[0]...\n";
			push @$features, [$standard_names[0], $f->start(), $f->end(), "pink", "F" ];
		    }
		}
	    }
	    
	}
    
	print STDERR "FEATURE OBJECT TYPE: ".ref($f)."\n";
	if (ref($f) eq "ARRAY") {
	    print STDERR Dumper($f);
	    next;
	}
	my $dir = "F";
	if ($f->can('strand')) { 
	    if ($f->strand() != 1) { $dir = "R"; }
	}
	my $name;
	if ( ($f->primary_tag() eq "gene")) { 
	    foreach my $tag ($f->all_tags()) { 
	   	($name) = $f->each_tag_value("gene");
	    }
	    
	    if ($name) {
		push @$features, [ $name, $f->start(), $f->end(), "lightblue", $dir ];
	    }
	}
	elsif ( $f->primary_tag() eq "repeat_region") {
	    foreach my $tag ($f->all_tags()) {
		my $name = "";
		if ($tag eq "standard_name") { 
		    ($name) = $f->each_tag_value("standard_name");
		}
		if ($name) {
		    push @$features, [ $name, $f->start(), $f->end(), "red", "" ];
		}
	    }
	}
	elsif ( $f->primary_tag() eq "CDS") {
	    foreach my $tag ($f->all_tags()) {
		my $name;
		if ($tag eq "standard_name") { 
		    ($name) = $f->each_tag_value("standard_name");
		}
	    
		if ($name) { push @$features, [ $name, $f->start(), $f->end(), "lightgreen", $dir ]; }
	    }
		
	}
	elsif ($f->primary_tag() eq "regulatory") {
	    foreach my $tag ($f->all_tags()) {
		if ($tag eq "standard_name") { 
		    ($name) = $f->each_tag_value("standard_name");
		}
	    }
	    push @$features, [ $name, $f->start(), $f->end(), "blue", "" ];
	}
    }
    
    print STDERR "ADDING VECTOR NAME ".$s->id()." and length ".length($s->seq())."\n";
    
    my $metadata = [ $s->id(), length($s->seq()) ];

    my @restriction_sites = $self->restriction_analysis("popular6bp", $s->seq());

    $self->re_sites(\@restriction_sites);
    $self->metadata($metadata);
    $self->features($features);
    $self->sequence($s->seq());
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
    my $seq = shift;

    my @restriction_sites;
    
    my $seq = Bio::Seq->new( -seq => $seq, -alphabet => "dna");
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

	my @coords;
	my @fragments = $ra ->fragment_maps($c->name());

#	print STDERR "FRAGMENTS FOR $enzyme: ".Dumper(\@fragments);
	
	for (my $i=0; $i < @fragments; $i++) {
	    #push @restriction_sites, { name => $enzyme, cutCoord => $fragments[$i]->{start} };
	    push @restriction_sites, [ $enzyme, $fragments[$i]->{start} ];
	 }

	#print STDERR "RESTRICTION SITES: ".Dumper(@restriction_sites);
    }
    return @restriction_sites;
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

