=head1 NAME

DAS::GUS::Segment - DAS-style access to a GUS database

=head1 SYNOPSIS

  # Get a Bio::Das::SegmentI object from a DAS::GUS database

  $segment = $das->segment( -name  => 'Landmark',
   						    -start => $start,
							-stop  => $stop );

=head1 AUTHOR

Name:	Haiming Wang
Email:	hwang@uga.edu

=cut

package DAS::GUS::Segment;

use strict;
use Bio::Root::Root;
use Bio::Das::SegmentI;
use DAS::GUS::Segment::Feature;

use constant DEBUG => 1;

use vars '@ISA', '$VERSION';
@ISA = qw(Bio::Root::Root Bio::SeqI Bio::Das::SegmentI);
$VERSION = 0.11;

use overload '""' => 'asString';

our $dlm = ";;"; 	     # separate attributes $tag=$value pairs

=head2 new

	Title	: new
	Usage	: $segment = $db->segment(-name  => 'AAEL01000015',
									  -start => $start,
									  -stop  => $stop );
	Function: Create a segment object 
	Returns	: a new DAS::GUS::Segment object 
	Args	: see below

This method creates a new DAS::GUS::Segment object 
accoring to a segment name, such as contig 'AAEL0100015'. Generally 
this is called automatically by the DAS::GUS module.

There are five positional arguments:

  $factory		a DAS::GUS adaptor to use for database access
  $start		start of the desired segment relative to source sequence
  $stop			stop of the desired segment relative to source sequence
  $srcfeature_id 	ID of the source sequence
  $class		type of the sequence, i.e. chromosome, contig
  $name  		name of the segment 
  $atts			attributes of the segment

=cut

sub new {
    my $self = shift;
    my ( $name, $factory, $start, $stop, $atts ) = @_;

    my $query = $factory->parser->getSQL("Segment.pm", "new:Segment");
    die "Couldn't find Segment.pm sql for new:Segment\n" unless $query;
    $query =~ s/(\$\w+)/eval $1/eg;
    my $sth = $factory->dbh->prepare($query);
    $sth->execute();

    my $hashref = $sth->fetchrow_hashref;
    warn "END or STARTM of $name could not be determined by sql: $query\n" 
      unless exists $$hashref{'END'} && exists $$hashref{'STARTM'};
    my $length  = $$hashref{'END'} - $$hashref{'STARTM'} + 1;

    $stop = ($stop && ($stop < $length)) ? int($stop) : $length;
    $start = ($start && ($start > 0)) ? int($start) : 1;

    return bless { factory 		 => $factory,
		   start   		 => $start,
		   end     		 => $stop,
		   srcfeature_id         => $$hashref{'SRCFEATURE_ID'},
		   length 		 => $length,
		   class   		 => $$hashref{'TYPE'},
		   name    		 => $$hashref{'NAME'},
		   atts    		 => $$hashref{'ATTS'},
		 }, ref $self || $self;
}

=head2 name

  Title		: name
  Usage		: $segname = $seg->name();
  Function	: Return the name of the segment
  Returns	: see avove
  Args		: none
  Status	: public

=cut

sub name { 
	my $self = shift; 
    return $self->{'name'} = shift if @_;
	return $self->{'name'};
}

=head2 class

	Title	: class
	Usage	: $obj->class($newval)
	Function: Return the segment class
	Returns	: value of class (a scalar)
	Args	: on set, new value (a scalar or undef, optional)

=cut

sub class { 
	my $self = shift; 
	
	return $self->{'class'} = shift if @_; 
	return $self->{'class'};
}

*type = \&class;

=head2 attributes

	Title	: attributes
	Usage	: $obj->attributes($newval)
	Function: Return the segment attributes
	Returns	: attributes string for gff3 dump
	Args	: 

=cut

sub attributes {
	my $self = shift; 

	return $self->{'atts'} = shift if @_; 
	return $self->{'atts'};
}

=head2 seq_id

	Title	: seq_id
	Usage	: $ref = $s->seq_id
	Function: return the ID of the landmark, aliased to name() for 
			  backward compatibility
	Return	: a string
	Args	: none
	Status	: public

=cut

*seq_id = \&name;

=head2 start

	Title	: start
	Usage	: $s->start
	Function: start of segment
	Returns : integer
	Args	: none
	Status	: Public

=cut

sub start { 
	my $self = shift; 
	return $self->{'start'} = shift if @_; 
	return $self->{'start'};

} 

=head2 low

	Title	: low
	Usage	: $s->low
	Function: start of segment; 
			  Alias of start for backward compatibility
	Returns : integer
	Args	: none
	Status	: Public

=cut

*low = \&start;

=head2 end

	Title	: end
	Usage	: $s->end
	Function: end of segment; 
	Returns : integer
	Args	: none
	Status	: Public

=cut

sub end { 
	my $self = shift; 
	return $self->{'end'} = shift if @_; 
	return $self->{'end'};
}

=head2 high

	Title	: high
	Usage	: $s->high
	Function: end of segment; 
			  Alias of end for backward compatibility.
	Returns : integer
	Args	: none
	Status	: Public

=cut

*high = \&end;

=head2 stop

	Title	: stop
	Usage	: $s->stop
	Function: end of segment; 
			  Alias of end for backward compatibility.
	Returns : integer
	Args	: none
	Status	: Public

=cut

*stop = \&end;

=head2 length

	Title	: length
	Usage	: $s->length
	Function: length of segment; 
	Returns : integer
	Args	: none
	Status	: Public

=cut

sub length {
	#shift->{length};
	abs($_[0]->{start} - $_[0]->{end}) + 1
}

=head2 features

	Title	: features
	Usage	: @features = $s->features(@args)
	Function: get features that overlap this segment
	Returns : a list of Bio::SeqFeatureI objects
	Args	: see below
	Status	: public

This method will find all features that intersect the segment in a variety
of ways and returns a list of Bio::SeqFeatureI objects. The feature locations 
will use coordinates relative to the reference sequence in effect at the
time that features() was called.

The returned list can be limited to certain types, attributes or 
range intersection modes. Types of range intersection are one of:

	"overlaps"		the default
	"contains"		return features completely contained within the segment
	"contained_in"	retunr features that completely contain the segment

Two types of argument lists are accepts. In the positional argument form,
the arguments are treated as a list of feature types. In the named 
parameter form, the arguments are a series of -name=E<gt>value pairs.

	Argument		Description
   -------------------------------------
   -types			An array reference to type names in the format "method:source"

	-attributes		A hashref containing a set of attributes to match

	-rangetype		One of "overlaps", "contains", or "contained_in".

	-iterator		Return an iterator across the features.

	-callback		A callback to invoke on each feature

The -attributes argument is a hashref containing one or more attributes to
match against:

	-attributes => { Gene => 'abc-1',
					 Note => 'confirmed' }

Attribute matching is simple string matching, and multiple attributes are ANDed 
together. More complex filtering can be performed using the -callback 
option (see below)

If -iterator is true, then the method returns an object reference that implements
the next_seq() method. Each call to next_seq() returns a new Bio::SeqFeatureI object.

If -callback is passed a code reference, the code reference will be invoked on 
each feture returned. The code will be passed two arguments consisting of the 
current feature and the segment object itself, and must return a true value. If 
the code returns a false value, feature retrieval will be aborted.

-callback and -iterator are mutually exclusive options. If -iterator is defined, 
then -callback is ignored.

=cut

sub features { 

  my $self = shift;
  my ($sql, @features, $base_start, $rend);

  my ($type, $types,$attributes,$rangetype,$iterator,$callback,$start,
      $stop,$feature_id,$factory) = $self->_rearrange([qw(TYPE
							  TYPES
							  ATTRIBUTES
							  RANGETYPE
							  ITERATOR
							  CALLBACK
							  START
							  STOP
							  FEATURE_ID
							  FACTORY
                                                         )
						      ], @_);
  $types ||= $type;

  my $srcfeature_id = $self->srcfeature_id;
  my $segname = $self->name;
  $base_start = $self->start;
  $rend = $self->end;
  $factory ||= $self->factory;

  ###########################################################
  #
  # You can write queries from here to retrieve TOP level
  # features (such as gene, blast...) from GUS.
  #
  # NOTE: a query name MUST follow the format in the conf file,
  # for example: in conf file, a gene track like,
  #
  # [Gene]
  # feature  = gene:Genbank
  #
  # Your gene query name MUST be gene:Genbank
  #
  ###########################################################

  foreach my $typeHash ( _getUniqueTypes($types) ) {
    my @types = keys(%$typeHash);
    my $type = shift @types;
    my $typeString = $typeHash->{$type};

    $sql = $factory->parser->getSQL("Segment.pm", $type);

    warn "Couldn't find Segment.pm sql for $type\n" unless $sql;
    next unless $sql;

    $sql =~ s/(\$\w+)/eval $1/eg;

    my $sth = $factory->dbh->prepare($sql);
    $sth->execute()
      or $self->throw("getting feature query failed");

    my @tempfeats = ();

    while (my $featureRow = $sth->fetchrow_hashref) {
			push @tempfeats, $self->_makeFeature($featureRow, $factory);
    }

	  # filter out blastx. it is used by cryptodb
    if($typeString =~ /blastx/i) { 
        warn "filtering blastx results for feature type: $type";
        @tempfeats = _blastx_filter(\@tempfeats);
    }

    push(@features, @tempfeats);

	my $bulkSubFeatureSql = $factory->parser->getSQL("Feature.pm", "$type:bulksubfeatures");
	if($bulkSubFeatureSql) {
	  $bulkSubFeatureSql =~ s/(\$\w+)/eval $1/eg;
  	  $self->_addBulkSubFeatures(\@features, $bulkSubFeatureSql, $factory) 
	} 
	
	my $bulkAttributeSql = $factory->parser->getSQL("Feature.pm", "$type:bulkAttribute");
    next unless $bulkAttributeSql;
	$bulkAttributeSql =~ s/(\$\w+)/eval $1/eg;
	$self->_addBulkAttribute(\@features, $bulkAttributeSql, $factory);

  }

  if($iterator) {
    return DAS::GUSIterator->new(\@features);
  } elsif ( wantarray ) {
    return @features;
  } else {
    return \@features;
  }
}

sub _addBulkAttribute {

  my($self, $features, $bulkAttributeSql, $factory) = @_;
  my %featuresById;
  map { $featuresById{$_->feature_id} = $_ } @$features;
  my $sth = $factory->dbh->prepare($bulkAttributeSql);
  $sth->execute()
    or $self->throw("getting bulk attribute query failed");

  my @bulkAtts;
  while (my $featureRow = $sth->fetchrow_hashref) {
    my $feature = $featuresById{$$featureRow{'FEATURE_ID'}};
    if ($feature) { 
	  $feature->bulkAttributes($featureRow);
    } 
  } 
}

sub _addBulkSubFeatures {
  my ($self, $features, $subFeatureSql, $factory) = @_;

  my %featuresById;
  map { $featuresById{$_->feature_id} = $_ } @$features;
  my $sth = $factory->dbh->prepare($subFeatureSql);
  $sth->execute()
    or $self->throw("getting bulk subfeature query failed");

  while (my $featureRow = $sth->fetchrow_hashref) {
    my $feature = $featuresById{$$featureRow{'PARENT_ID'}};
    if ($feature) {
      $feature->_addSubFeatureFromRow($featureRow);
    } else {
      $self->warn("sub feature [" . $$featureRow{'FEATURE_ID'} . "]'s parent feature ["
		  . $$featureRow{'PARENT_ID'} . "] could not be found. bulk subfeature query is:\n"
		  . $subFeatureSql);
    }
  }
}

=head2 _getUniqueTypes

    Title   : _getUniqueTypes
    Usage   : $segment->_getUniqueTypes()
    Function: filter out the duplicate types and return an array of
              unique feature types in 'type_source' format
    Returns : an array of feature types
    Args    : array ref
    Status  : Private

For example, in the config file

[Gene]
feature  = gene:Genbank

[BLASTX]
feature  = match:WU_BLASTX

_getUniqeTypes will subsitute ':' with '_'
and return [ gene_Genbank, match_WU_BLASTX ], the latter can be used to
find the corresponding element in SQL xml files.

=cut

sub _getUniqueTypes() {

    my $types = shift;
    my @uniqtypes = ();

    my %seen;
    for my $type (@{$types || []}) {
	push(@uniqtypes, { $type => $type }) unless $seen{$type}++;
    }

    return @uniqtypes;
}

sub _makeFeature() {

	my ($self, $featureRow, $factory) = @_;

	my $type = $$featureRow{'TYPE'};
	my $source = $$featureRow{'SOURCE'};
	my $feature_id = $$featureRow{'FEATURE_ID'};
	my $unique_name = "$type.$feature_id";
	$type .= ":$source";

	my $feat = DAS::GUS::Segment::Feature->new(
					$factory,
					$self,  					# parent 
					$self->seq_id,
					$$featureRow{'STARTM'},		# start
					$$featureRow{'END'},		# end
					$$featureRow{'TYPE'}.':'.$$featureRow{'SOURCE'}, # type
					$$featureRow{'SCORE'},		# score
					$$featureRow{'STRAND'},		# strand
					$$featureRow{'PHASE'},		# phase
					$$featureRow{'NAME'},		# group
					$$featureRow{'ATTS'},		# attributes
					$unique_name,
					$$featureRow{'FEATURE_ID'},	# feature_id
				);

	$feat->source($source);

	# if this is mRNA .. then get the exons ....
	# depending on the type, build sub_feature here

	$feat;
}

# filter out the blastx output. First, sort the blastx data using sql
# by e-value, match length and start. 
# Second, filter features with overlap > 5 

sub _blastx_filter {

	my $feats = shift;
	my $counter = 0;
	#my $idx = -1;
	my $old_end = 2000000;


	my @newfeats = ();
	foreach my $f(@$feats) {
	my $name = $f->name;

		#$idx = $idx + 1;
		my $start = $f->start;
		my $end = $f->end;

		if($start <= $old_end) {
			$counter = $counter + 1; # find one;
		} else {
			$old_end = $end;
			push(@newfeats, $f);
			$counter = 0;
			next;
		}

		if($counter >= 5) {
			#splice(@$feats, $idx, 1);
			#$idx = $idx - 1; 	# reset index
		} else {
			push(@newfeats, $f);
			$old_end = $end;
		}
			
	}

	return @newfeats;
}

=head2 get_all_SeqFeature, get_SeqFeatures, top_SeqFeatures, all_SeqFeatures

	Title	: get_all_SeqFeature, get_SeqFeatures, top_SeqFeatures, 
			  all_SeqFeatures
	Usage	: $s->get_all_SeqFeature()
	Function: get the sequence string fro this segment
			  Several aliases of features() for backword compatibility
	Returns	: a string
	Args	: none
	Status	: Public

=cut

*get_all_SeqFeature = *get_SeqFeatures = *top_SeqFeatures = *all_SeqFeatures = \&features;

=head2 seq

	Title	: seq
	Usage	: $s->seq
	Function: get the sequence string for this segment
	Returns	: a string
	Args	: none
	Status	: Public

=cut

sub seq {

  my $self = shift;
  return $self->{'seq'} = shift if @_;
  return $self->{'seq'} if( $self->{'seq'});

  my ($ref, $class, $base_start, $stop, $strand)
    = @{$self}{qw(sourceseq class start end strand)};

  my $srcfeature_id = $self->{srcfeature_id};
  my $has_start = defined $base_start;
  my $has_stop = defined $stop;
	$strand ||= 0;
  
  my $reversed;
  if($has_start && $has_stop && ($base_start > $stop)) {
    $reversed++;
    ($base_start, $stop) = ($stop, $base_start);

  } elsif( $strand < 0) {
    $reversed++;
  }

  my $seqQuery = $self->factory->parser->getSQL("Segment.pm", "get_sequence");

  warn "Couldn't find Segment.pm sql for get_sequence\n" unless $seqQuery;
  return unless $seqQuery;

  $seqQuery =~ s/(\$\w+)/eval $1/eg;

  my $sth = $self->factory->dbh->prepare($seqQuery);
  $sth->execute();
  my ($seq) = $sth->fetchrow_array();

  if (!$has_start && !$has_stop) {
    # do nothing, sequence is already complete
  } elsif (!$has_start) {
    $seq = substr($seq, 0, $stop - 1);
  } elsif(!$has_stop) {
    $seq = substr($seq, $base_start - 1);
  } else {  # has both start and stop
    $seq = substr($seq, $base_start - 1, $stop - $base_start + 1);
  }

  if($reversed) {
    $seq = reverse $seq;
    $seq =~ tr/gatcGATC/ctagCTAG/;
  }

  return $seq;
}

*protein = *dna = \&seq;


=head2 secondary_structure_encodings

	Title	: secondary_structure_encodings
	Usage	: $s->secondary_structure_encodings
	Function: get the secondary structure prediction scores for segment
	Returns	: hash ref { secondary_structure_type => string of 0-9 one digit per base }
	Args	: none
	Status	: Public

=cut

sub secondary_structure_encodings {

  my $self = shift;

  my $srcfeature_id = $self->{srcfeature_id};

  my $strucQuery = $self->factory->parser->getSQL("Segment.pm", "get_2d_struc");

  warn "Couldn't find Segment.pm sql for get_2d_struc\n" unless $strucQuery;
  return unless $strucQuery;

  $strucQuery =~ s/(\$\w+)/eval $1/eg;

  my $sth = $self->factory->dbh->prepare($strucQuery);
  $sth->execute();

  my $encodings = undef;
  while (my ($type, $encoding) = $sth->fetchrow_array()) {
    $encodings = {} unless defined($encodings);
    $type = 'helix' if $type =~ /^h$/i;
    $type = 'coil' if $type =~ /^c$/i;
    $type = 'strand' if $type =~ /^e$/i;
    $encodings->{$type} = $encoding;
  }

  unless ($encodings && $encodings->{helix}) {
    warn "no structure encodings retrieved by sql: $strucQuery\n";
  }

  return $encodings;
}

=head2 factory
	
	Title	: factory
	Usage	: $factory = $s->factory
	Function: return the segment factory
	Returns : a Bio::DasI object
	Args	: see below
	Status	: Public

This method returns a Bio::DasI object that can be used to fetch more segments.
This is typically the Bio::DasI object from which the segments was originally
generated.

=cut

sub factory { shift->{factory} }

=head2 srcfeature_id

	Title	: srcfeature_id
	Usage	: $obj->srcfeature_id($newval)
	Function:
	Returns : value of srcfeature_id (a scalar)
	Args	: on set, new value (a scalar or undef, optional)

=cut

sub srcfeature_id {

	my $self = shift;
	return $self->{'srcfeature_id'} = shift if @_;
	return $self->{'srcfeature_id'};

}

=head2 alphabet

	Title	: alphabet
	Usage	: $obj->alphabet($newval)
	Function:
	Returns	: scalar 'dna'
	Args	: on set, new value ( a scalar or undef, optional )
	Status	: Public

=cut

sub alphabet {
    return 'dna';
}

=head2 display_id, display_name, accession_number, desc

	Title	: display_id, display_name, accession_number, desc
	Usage	: $s->display_name()
	Function: Alias of name()
			  Several aliases for name; it may be that these could do something
			  better than just giving back the name.
	Returns	: string
	Args	: none
	Status	: Public

=cut

*display_id = *display_name = *accession_number = *desc = \&name;

=head2 get_feature_stream

	Title	: get_feature_stream
	Usage	:
	Function:
	Returns	:
	Args	:
	Status	:

=cut

sub get_feature_stream {
	my $self = shift;
	my @args = @_;

	my $features = $self->features(@args);
	return DAS::GUSIterator->new($features); 
}

sub get_seq_stream {
	my @features = shift->features(@_);
	return DAS::GUSIterator->new(\@features); 
}

=head2 clone

	Title	: clone
	Usage	: $copy = $s->clone
	Function: make a copy of this segment
	Returns	: a Bio::DB::GFF::Segment object
	Args	: none
	Status	: Public

=cut

sub clone {
	my $self = shift;
	my %h = %$self;
	return bless \%h, ref($self);
}

=head2 sourceseq

	Title	: sourceseq
	Usage	: $obj->sourceseq($newval)
	Function: get feature name according to a feature_id
	Returns	: value of sourceseq(a scalar)
	Args	: on set, new value ( a scalar or undef, optional )
	Status	: Public

=cut

sub sourceseq {
	my $self = shift;
	return $self->name;
}

=head2 abs_ref

	Title	: abs_ref
	Usage	: $obj->abs_ref()
	Function: Alisas of sourceseq
			  Alias of sourceseq for backward compatibility
	Returns	: value of sourceseq ( a scalar )
	Args	: none
	Status	: Public

=cut

*abs_ref = \&sourceseq;

=head2 abs_start

	Title	: abs_start
	Usage	: $obj->abs_start()
	Function: Alias of start
	Returns	: value of start ( a scalar )
	Args	: none
	Status	: Public

=cut

*abs_start = \&start;

=head2 abs_end

	Title	: abs_end
	Usage	: $obj->abs_end()
	Function: Alias of end
	Returns	: value of end ( a scalar )
	Args	: none
	Status	: Public

=cut

*abs_end = \&end;

=head2 asString
	
	Title	: asString
	Usage	: $s->asString
	Function: human-readable string for segment
			  Returns a human-readable string representing this sequence. 
			  Format is: sourceseq:start,stop
	Returns	: a string
	Args	: none
	Status	: Public

=cut

sub asString {
    my $self = shift;
    my $label = $self->refseq;
    my $start = $self->start;
    my $stop  = $self->stop;
    return "$label:$start,$stop";
}

# implement SeqI abstract method.
# required by BatchDumper plugin. don't yet know what, if anything, needs 
# to happen here. This is sufficient at the moment to quash execptions.
# -mheiges
sub primary_seq {
    my $self = shift;
}

1;
