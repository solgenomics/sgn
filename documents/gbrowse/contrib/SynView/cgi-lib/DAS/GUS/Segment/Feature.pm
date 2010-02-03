=head1 NAME

DAS::GUS::Segment::Feature 
			-- a relative segment identified by a feature type

=head1 SYNOPSIS

See L<DAS::GUS>.

=head1 DESCRIPTION

DAS::GUS::Segment::Feature is a stretch of sequence that
corresponding to a single annotation in a GUS database. 

It inherits from Bio::SeqFeatureI and so has the familiar start(),
stop(), primary_tag() and location() methods (it implements 
Bio::LocationI too)

=head1 API

The remainder of this document describes the public and private
methods implemented by this module.

=cut

=head1 AUTHOR 

Name:  Haiming Wang
Email: hwang@uga.edu

=cut

package DAS::GUS::Segment::Feature;

use strict;
use warnings;
use DAS::GUS::Segment;
use Bio::SeqFeatureI;
use Bio::Root::Root;
use Bio::LocationI;
use Data::Dumper;
use URI::Escape;

use vars qw($VERSION @ISA $AUTOLOAD %CONSTANT_TAGS);
@ISA = qw(DAS::GUS::Segment Bio::SeqFeatureI Bio::Root::Root);

$VERSION = '0.10';
%CONSTANT_TAGS = ();

use constant DEBUG => 0;
use overload '""'  => 'asString';

our $dlm = ";;"; 	 # separate attributes $tag=$value pairs

=head2 new

	Title	: new
	Usage	: $f = DAS::GUS::Segment::Feature->new(@args);
	Function: create a new feature object
	Returns	: new DAS::GUS::Segment::Feature object
	Args	: see below
	Status	: Internal

This method is called by DAS::GUS::Segment to create a new 
feature using information obtained from the GUS database.

The 12 arguments are positional:

	$factory	a DAS::GUS adaptor object
	$parent		the parent feature object (if it exists)
	$srcseq		the source sequence
	$start		start of this feature
	$stop		stop of this feature
	$type		this feature's type (gene, arm, exon, etc)
	$score		the feature's score
	$strand		this feature's strand (relative to the source sequence,
				which has its own strandness!)
	$phase		this feature's phase (often with respect to the previous
				feature in a group of related features)
	$group		this feature's group information ??
	$atts		feature's attributes in $tag=$value format, use ? as delimiter
	$uniquename this feature's internal unique database name ??
	$feature_id	the feature's feature_id

This is called when creating a feature from scratch. It does not have
an inherited coordinate system.

=cut

sub new {
	my $package = shift;
	my ($factory,
		$parent,
		$srcseq,
		$start,
		$end,
		$type,
		$score,
		$strand,
		$phase,
		$group,
		$atts,
		$uniquename,
		$feature_id) = @_;
	
	my $self = bless { }, $package;

	$self->factory($factory);
	$self->parent($parent) if $parent;
	$self->seq_id($srcseq);
	$self->start($start);
	$self->end($end);
	$self->score($score);
	$self->strand($strand);
	$self->phase($phase);
	$self->type($type);
	$self->group($group);
	$self->attributes(undef, $atts);
	$self->uniquename($uniquename);
	$self->absolute(1);
	$self->feature_id($feature_id);

	$self->srcfeature_id($parent->srcfeature_id() )
			if (defined $parent && $parent->can('srcfeature_id'));
	
	return $self;
}

#######################################################################
# Methods below are accessors for data that is drawn directly from the
# GUS database and can be considered "primary" accessors for this class.
#######################################################################

=head2 feature_id
	
	Title	: feature_id
	Usage	: $obj->feature_id($newval)
	Function: holds feature_id
	Returns	: value of feature_id (a scalar)
	Args	: on set, new value (a scalar or undef, optional)

=cut

sub feature_id {
	my $self = shift;

	return $self->{'feature_id'} = shift if @_;
	return $self->{'feature_id'};
}

=head2 group
	
	Title	: group
	Usage	: $group = $f->group([$new_group]);
	Function: Returns a feature name -- this is here to maintain backward
			  compatibility with GFF and gbrowse.
	Returns	: value of group (a scalar)
	Args	: 

=cut

sub group {
	my $self = shift;

	return $self->{'group'} = shift if @_;
	return $self->{'group'};
}

=head2 srcfeature_id
	
	Title	: srcfeature_id
	Usage	: $obj->srcfeature_id($newval)
	Function:
	Returns	: value of srcfeature_id (a scalar)
	Args	:

=cut

sub srcfeature_id {
	my $self = shift;

	return $self->{'srcfeature_id'} = shift if @_;
	return $self->{'srcfeature_id'};
}

=head2 strand
	
	Title	: strand
	Usage	: $obj->strand()
	Function: Returns the strand of the feature. Unlike the other methods,
			  the strand cannont be changed once the object is 
			  createed (due to coordinate considerations).
	Returns	: -1, 0 or 1 ???
	Args	:

=cut

sub strand {
	my $self = shift;

	return $self->{'strand'} = shift if @_;
	return $self->{'strand'} || 0;
}

sub phase {
	my $self = shift;
	return $self->{'phase'} = shift if defined($_[0]);
	return $self->{'phase'};
}

sub type {
	my $self = shift;

	return $self->{'type'} = shift if @_;
	return $self->{'type'};
}

sub uniquename {
	my $self = shift;
	return $self->{'uniquename'} = shift if @_;
	return $self->{'uniquename'};
}

##########################################################################
# ISA Bio::SeqFeatureI
##########################################################################

=head1 SeqFeatureI methods

DAS::GUS::Segment::Feature implements the Bio::SeqFeatureI
interface. Methods described below, L<Bio::SeqFeatureI> for more details.

=cut

=head2 attach_seq()
	
	Title	: attach_seq
	Usage	: $sf->attch_seq($seq)
	Function: Attaches a Bio::Seq object to this feature. This Bio::Seq
			  object is for the *entire* sequence: ie from 1 to 10000
	Returns	: TURE on success
	Args	: a Bio::PrimarySeqI compliant object

=cut

sub attach_seq {
	my ($self) = @_;
	$self->throw_not_implemented();
}

=head2 display_name()

	Title	: display_name
	Function: aliased to uniquename() for Bio::SeqFeatureI compatibility

=cut

*display_name = \&group;
*display_id = \&uniquename;

=head2 entire_seq()
	
	Title	: entire_seq
	Usage	: $whole_seq = $sf->entire_seq()
	Function: gives the entire sequence that this seqfeature is attached to
	Returns	: a Bio::PrimarySeqI compliant object, or undef is there is no
			  sequence attached
	Args	: none

=cut

sub entire_seq {
	my $self = shift;
	$self->SUPER::seq();
}

=head2 get_all_tags()
	
	Title	: get_all_tags
	Function: aliased to all_tags() for Bio::SeqFeatureI compatibility

=cut

*get_all_tags = \&all_tags;

=head2 get_SeqFeatures()
	
	Title	: get_SeqFeatures
	Function: aliased to sub_SeqFeature() for Bio::SeqFeatureI compatibility

=cut

*get_SeqFeatures = \&sub_SeqFeature;

=head2 get_tag_values()
	
	Title	: get_tag_values
	Usage	:
	Function:
	Returns	:
	Args	:

=cut

sub get_tag_values {
  my $self = shift;
  my $tag = shift;

  return $self->$tag() if $CONSTANT_TAGS{$tag};

  return $self->attributes($tag);
}

=head2 get_tagset_values()
	
	Title	: get_tagset_values
	Usage	:
	Function:
	Returns	:
	Args	:

=cut

sub get_tagset_values {
	my ($self, %arg) = @_;

	$self->throw_not_implemented();
}

=head2 gff_string()
	
	Title	: gff_string
	Usage	: $string = $feature->gff_string
	Function: return GFF3 representation of feature
	Returns	: a string
	Args	: none
	Status  : Public

=cut

sub gff_string { 

	my $self = shift; 
	my ($recurse,$parent) = @_; 
	my ($start,$stop) = ($self->start,$self->stop); 

	# the defined() tests prevent uninitialized variable warnings, 
	# when dealing with clone objects whose endpoints may be undefined 
	($start,$stop) = ($stop,$start) 
		if defined($start) && defined($stop) && $start > $stop;

	my $strand = ('-','.','+')[$self->strand+1]; 
	my $ref = $self->refseq; 
	my $n   = ref($ref) ? $ref->name : $ref; 
	my $phase = $self->phase; 
	$phase = '.' unless defined $phase;

	my ($class,$name) = ('',''); 
	my @group; 
	if (my $g = $self->group) { 
		$name = $self->id;
    push @group,[ID => $name] if !defined($parent) || $name ne $parent;

		my $display_name = $self->name;
		push @group,[Name => $display_name] if $name !~ /$display_name$/;
	}

	push @group,[Parent => $parent] if defined $parent && $parent ne '';

	my @attributes = $self->attributes;

	while (@attributes) { 
		push @group,[shift(@attributes),shift(@attributes)] 
	}

	my $pattern = "^a-zA-Z0-9,. :^*!+_?-";

	my $group_field = join ';',map {join '=', uri_escape($_->[0], $pattern), uri_escape($_->[1], $pattern)} grep {$_->[0] =~ /\S/ and $_->[1] =~ /\S/} @group;

	my $type = $self->method;
	$type =~ s/:\S+//;

  my $string = join("\t",$n,$self->source||'.',$type||'.',$start||'.',$stop||'.', $self->score||'.',$strand||'.',$phase||'.',$group_field);

	$string .= "\n";

  if ($recurse) { 
		foreach ($self->sub_SeqFeature) {
      $string .= $_->gff_string(1,$name);
    }
	}
  $string;
}

=head2 has_tag()
	
	Title	: has_tag
	Usage	:
	Function:
	Returns	:
	Args	:

=cut

sub has_tag {
	my $self = shift;
	my $tag = shift;

	my %tags = map {$_=>1} ( $self->all_tags );
	return $tags{$tag};
}

=head2 primary_tag()
	
	Title	: primary_tag
	Usage	:
	Function: aliased to type() for Bio::SeqFeatureI compatibility
	Returns	:
	Args	:

=cut

*primary_tag = \&type;

=head2 seq_id()
	
	Title	: seq_id
	Usage	: $obj->seq_id($newval)
	Function:
	Returns	: value of seq_id (a scalar)
	Args	:

=cut

sub seq_id {
	my $self = shift;

	return $self->{'seq_id'} = shift if @_;
	return $self->{'seq_id'};
}

=head2 source_tag()
	
	Title	: source_tag
	Usage	:
	Function: aliased to source() for Bio::SeqFeatureI compatibility
	Returns	:
	Args	:

=cut

*source_tag = \&source;

###########################################################################
# get/set and theire composite, alphabetical
###########################################################################

=head1 other get/setters

=cut

=head2 abs_strand()
	
	Title	: abs_strand
	Usage	: $obj->abs_strand($newval)
	Function: aliased to strand() for backward compatibility
	Returns	:
	Args	:

=cut

*abs_strand = \&strand;

=head2 class()
	
	Title	: class 
	Usage	:
	Function: aliased to type() for backward compatibility
	Returns	:
	Args	:

=cut

*class = \&type;

=head2 db_id()
	
	Title	: db_id
	Usage	:
	Function: aliased to uniquename() for backward compatibility
	Returns	:
	Args	:

=cut

*db_id = \&uniquename;

=head2 factory()
	
	Title	: factory
	Usage	: $obj->factory($newval)
	Function: 
	Returns	: value of factory (a scalar)
	Args	:

=cut

sub factory {
	my $self = shift;

	return $self->{'factory'} = shift if @_;
	return $self->{'factory'};
}

=head2 id()
	
	Title	: id
	Usage	:
	Function:
	Returns	:
	Args	:

=cut

*id = \&uniquename;

=head2 info()
	
	Title	: info
	Usage	:
	Function:
	Returns	:
	Args	:

=cut

*info = \&uniquename;

=head2 length()
	
	Title	: length
	Usage	: $obj->length()
	Function: convenience for end - start + 1
	Returns	: length of feature in basepairs
	Args	: none

=cut

sub length {
	my ($self) = @_;
	my $len = $self->end() - $self->start() + 1;
	return $len;
}

=head2 method()
	
	Title	: method
	Usage	:
	Function:
	Returns	:
	Args	:

=cut

*method = \&type;

=head2  name
	
	Title	: name
	Usage	:
	Function:
	Returns	:
	Args	:

=cut

*name = \&group;

=head2 parent()
	
	Title	: parent
	Usage	: $obj->parent($newval)
	Function:
	Returns	:
	Args	:

=cut

sub parent {
	my $self = shift;

	return $self->{'parent'} = shift if @_;
	return $self->{'parent'};
}

=head2 score()
	
	Title	: score
	Usage	: $obj->score($newval)
	Function:
	Returns	:
	Args	:

=cut


sub score {
	my $self = shift;

	return $self->{'score'} = shift if @_;
	return $self->{'score'};
}

###########################################################################
# other methods
###########################################################################

=head1 Other methods

=cut

=head2 all_tags()
	
	Title	: all_tags
	Usage	:
	Function:
	Returns	:
	Args	:

=cut

sub all_tags {
	my $self = shift;
	my $atts = $self->attributes;
	my @tags = keys %{$atts || {}};
	@tags;
}

=head2 source()
	
	Title	: source
	Usage	: $source = $f->source([$newsource])
	Function: get or set the feature source
	Returns	: a string
	Args	: a new source (optional)
	Status	: Public

=cut

sub source {
	my $self = shift;

	return $self->{'source'} = $_[0] if defined $_[0];
	return $self->{'source'} if defined $self->{'source'};

	$self->{'source'} = 'unknown source';
	return $self->{'source'};

}

=head2 segments()

	Title	: segments
	Function: aliased to sub_SeqFeature() for compatibility

=cut

*segments = \&sub_SeqFeature;

=head2 subfeatures

	Title	: subfeatures
	Usage	: $obj->subfeatures($newval)
	Function: returns a list of subfeatures
	Returns	: value of subfeatures (a scalar)

=cut

sub subfeatures {
	my $self = shift;
	my $f = $self->{'subfeatures'};

	return $self->{'subfeatures'} = shift if @_;
	return $self->{'subfeatures'};
}

=head2 sub_SeqFeature()

	Title	: sub_SeqFeature
	Usage	: @feat = $feature->sub_SeqFeature([$type])
	Function: get subfeatures
	Returns	: a list of DAS::GUS::Segment::Feature objects
	Args	: a feature method (optional)
	Status	: Public

This method returns a list of any subfeatures that belong to the main 
feature. For those features that contain heterogeneous subfeatures, 
you can retrieve a subset of the subfeatures by providing a method name 
to filter on.

This method may also be called as segments() or get_SeqFeatures().

=cut

sub sub_SeqFeature {

  my ($self, $type) = @_;

  $type ||= $self->type;

	if ($self->{acquiredSubFeaturesByBulk}) {
		my $subfeats = $self->subfeatures or return;
		return @{$subfeats};
	}

  my $query = $self->factory->parser->getSQL("Feature.pm", "$type:subfeatures");
  return unless $query;

  my $parent_id = $self->feature_id();

  {
    no strict qw(refs vars);
    my $attr = $self->attributes();
    for my $var (keys %$attr) {
      ${__PACKAGE__ . "::$var"} = $attr->{$var};
    }
    # $query =~ s/(\$\w+)/eval "$1"/eg;
    $query = eval qq{"$query"};

  }

  my $sth = $self->factory->dbh->prepare($query);
  $sth->execute or $self->throw("subfeature query failed");

  my $counter = 0;
  while (my $hashref = $sth->fetchrow_hashref) {
    my $source = $$hashref{'SOURCE'};
    my $feature_id = $$hashref{'FEATURE_ID'};
    my $name = $$hashref{'NAME'};
    my $type = $$hashref{'TYPE'};
    my $unique_name = "$type.$feature_id";
    $type = $type. ":$source";



		# note: this is a temporary solution for EST. later this 
		# should be handled by GUS. Current there is no proper plugin to 
		# load data into proper tables 

		my($ts, $bs);
		my(@tstarts, @blocksizes);

		if( $type =~ /^block/i ) { # if this is an EST feature (blat) 

			$ts = $$hashref{'TSTARTS'}; 
			$bs = $$hashref{'BLOCKSIZES'}; 
			$ts =~ s/,/ /g; 
			$bs =~ s/,/ /g; 

			@tstarts = split /\s+/, $ts; 
			@blocksizes = split /\s+/, $bs;

			my $counter = 0; 
			foreach my $t (@tstarts) { 
				$feature_id = $$hashref{'FEATURE_ID'}; 
				$feature_id = $feature_id . ".$counter"; 
				$unique_name = "block.$feature_id"; 
				my $end = $t + $blocksizes[$counter]; 
				my $feat = DAS::GUS::Segment::Feature->new( $self->factory, 
																																 $self, 
																																 $self->ref, 
																																 $t, # start 
																																 $end, #end 
																																 $type, 
																																 $$hashref{'SCORE'},   # score 
																																 $$hashref{'STRAND'},  # strand 
																																 $$hashref{'PHASE'},   # phase 
																																 $$hashref{'NAME'},    # group 
																																 $$hashref{'ATTS'},    # attributes 
																																 $unique_name, 
																																 $feature_id); 


        #warn "5 tstart $t | $end | $feature_id \n" if DEBUG;
				$self->add_subfeature($feat); 
				$feat->source($source); 
				$counter = $counter + 1; 
			} 
			if($counter <= 1 ) { 
				return; 
			} 

			my $subfeats = $self->subfeatures or return; 
			return @{$subfeats}; 
		} 
		# end temporary solution for EST features





    my $feat = DAS::GUS::Segment::Feature->new($self->factory, 
							    $self,
							    $self->ref,
							    $$hashref{'STARTM'},# start
							    $$hashref{'END'},	# stop
							    $type,
							    $$hashref{'SCORE'},	# score
							    $$hashref{'STRAND'},# strand
							    $$hashref{'PHASE'},	# phase
							    $$hashref{'NAME'},	# group
							    $$hashref{'ATTS'},	# attributes
							    $unique_name,
							    $feature_id
							   );
    $counter++;
    $self->add_subfeature($feat);
    $feat->source($source);
    #print "<pre>subquery: $query</pre>";
  }

  my $subfeats = $self->subfeatures or return;

  return @{$subfeats};
}

=head2 add_subfeature()

	Title	: add_subfeature
	Usage	: $feature->add_subfeature($feature)
	Function: This method adds a new subfeature to the object.
			  It is used internally by aggreagators, but is
			  available for public use as well.
	Returns	: nothing
	Args	: a DAS::GUS::Segment::Feature object
	Status	: Public

=cut

sub add_subfeature {

	my $self = shift;
	my $subfeature = shift;
	push @{$self->{subfeatures}}, $subfeature;
}

=head2 location()

	Title	: location
	Usage	: my $location = $seqfeature->location()
	Function: returns a location object suitable for identifying location
			  of feature on sequence or parent feature
	Returns	: Bio::LocationI object
	Args	: none

=cut

sub location {
	my $self = shift;
	require Bio::Location::Split unless Bio::Location::Split->can('new');
	require Bio::Location::Simple unless Bio::Location::Simple->can('new');

	my $location;

	if(my @segments = $self->sub_SeqFeature) {
		$location = Bio::Location::Split->new(-seq_id => $self->seq_id);
		foreach(@segments) {
			$location->add_sub_Location($_->location);
		}
	}
	else {
		$location = Bio::Location::Simple->new(-start  => $self->start,
											   -end    => $self->stop,
											   -strand => $self->strand,
											   -seq_id => $self->seq_id);
   }
   $location;
}

*merged_segments = \&sub_SeqFeature;

=head2 clone()

	Title	: clone
	Usage	: $feature = $f->clone
	Function: make a copy of the feature
			  This method returns a copy of the feature.
	Returns	: a new DAS::GUS::Segment::Feature object
	Args	: none
	Status	: Public

=cut

sub clone {
	my $self = shift;
	my $clone = $self->SUPER::clone;

	if( ref(my $t = $clone->type) ) {
		my $type = $t->can('clone') ? $t->clone : bless {%$t}, ref $t;
		$clone->type($type);
	}

	if( ref(my $g = $clone->group) ) {
		my $group = $g->can('clone') ? $g->clone : bless {%$g}, ref $g;
		$clone->group($group);
	}

	if(my $merged = $self->{merged_segs}) {
		$clone->{merged_segs} = {%$merged};
	}

	$clone;
}

=head2 sub_types()

	Title	: sub_types
	Usage	: @methods = $feature->sub_types
	Function: get methods of all sub_seqfeatures
	Returns	: a list of method name
	Args	: none
	Status	: Public

For those features that contain subfeatures, this method will return a 
unique list of method names of thoese subfeatures, suitable for use 
with sub_SeqFeature()

=cut

sub sub_types {
	my $self = shift;
	my $subfeat = $self->subfeatures or return;
	return keys %$subfeat;
}

=head2 Autogenerated Methods

	Title	: AUTOLOAD
	Usage	: @subfeat = $feature->Method
	Function: Return subfeatures using autogenerated methods
	Returns	: a list of DAS::GUS::Segment::Feature objects
	Args	: none
	Status	: Public

Any method that begins with an initial capital letter will be passed 
to AUTOLOAD and treated as a call to sub_SeqFeature with the method
name used as the method argument. For instance, this call:

	@exons = $feature->Exon;

is equivalent to this call:

	@exons = $feature->sub_SeqFeature('exon');

=cut

sub AUTOLOAD {
	my ($pack, $func_name) = $AUTOLOAD=~/(.+)::([^:]+)$/;
	my $sub = $AUTOLOAD;
	my $self = $_[0];

	# ignore DESTROY calls
	return if $func_name eq 'DESTROY';

	# fetch subfeatures if func_name has an initial cap
	return $self->sub_SeqFeature($func_name) if $func_name =~ /^[A-Z]/;

}

=head2 adjust_bounds()

 Title   : adjust_bounds
 Usage   : $feature->adjust_bounds
 Function: adjust the bounds of a feature
 Returns : ($start,$stop,$strand)
 Args    : none
 Status  : Public

This method adjusts the boundaries of the feature to enclose all its
subfeatures.  It returns the new start, stop and strand of the
enclosing feature.

=cut

# adjust a feature so that its boundaries are synched with its subparts' boundaries.
# this works recursively, so subfeatures can contain other features
sub adjust_bounds { 
  my $self = shift;
  my $g = $self->{group};

  if (my $subfeat = $self->subfeatures) {
    for my $list (values %$subfeat) {
      for my $feat (@$list) {

	# fix up our bounds to hold largest subfeature
	my($start,$stop,$strand) = $feat->adjust_bounds;
	$self->{strand} = $strand unless defined $self->{strand};
	if ($start <= $stop) {
	  $self->{start} = $start if !defined($self->{start}) || $start < $self->{start};
	  $self->{stop}  = $stop  if !defined($self->{stop})  || $stop  > $self->{stop};
	} else {
	  $self->{start} = $start if !defined($self->{start}) || $start > $self->{start};
	  $self->{stop}  = $stop  if !defined($self->{stop})  || $stop  < $self->{stop};
	}

      }
    }
  }

  ( $self->start(),$self->stop(),$self->strand() );
}

=head2 sort_features()

 Title   : sort_features
 Usage   : $feature->sort_features
 Function: sort features
 Returns : nothing
 Args    : none
 Status  : Public

This method sorts subfeatures in ascending order by their start
position.  For reverse strand features, it sorts subfeatures in
descending order.  After this is called sub_SeqFeature will return the
features in order.

This method is called internally by merged_segments().

=cut

# sort features
sub sort_features { 
  my $self = shift;
  return if $self->{sorted}++;
  my $strand = $self->strand or return;
  my $subfeat = $self->subfeatures or return;
  for my $type (keys %$subfeat) {
      $subfeat->{$type} = [map { $_->[0] }
			   sort {$a->[1] <=> $b->[1] }
			   map { [$_,$_->start] }
			   @{$subfeat->{$type}}] if $strand > 0;
      $subfeat->{$type} = [map { $_->[0] }
			   sort {$b->[1] <=> $a->[1]}
			   map { [$_,$_->start] } @{$subfeat->{$type}}] if $strand < 0; } }

=head2 asString()

 Title   : asString
 Usage   : $string = $feature->asString
 Function: return human-readabled representation of feature
 Returns : a string
 Args    : none
 Status  : Public

This method returns a human-readable representation of the feature and
is called by the overloaded "" operator.

=cut

sub asString { 
  my $self = shift;
  my $type = $self->type;
  my $name = $self->name;

  return "$type($name)" if $name;
  return $type;
}

=head2 attributes

  Title	  : attributes
  Usage	  : @attributes = $feature->attributes($name)
  Function: get the "attributes" on a particular feature
  Returns : an array of string
  Args	  : feature ID
  Status  : Public

Two attributes have special meaning: "Note" is for backward 
compatibility and is used for unstructured text remarks. 
"Alias" is considered as a synonym for the feature name.

  @gene_names = $feature->attributes('Gene');
  @aliases    = $feature->attributes('Alias');

If no name is provided, then attributes() returns a flattened hash, of
attributes=E<gt>value pairs. This lets you do:

  %attributes = $db->attributes;

=cut

sub attributes {

  my $self = shift;
  my $tag = shift;

  return $self->{'atts'} = shift if @_;

  my $atts = $self->{'atts'};

  # attribute delimiter $name=$value;$name=$value
  my @pairs = ();
  if ($atts) { @pairs = split(/$dlm/, $atts); }

  if (wantarray && !$tag) {
    my @result;
    foreach my $tag_value (@pairs) {
      my @values = split(/=/, $tag_value, 2);
      push @result, @values;
    }

    return @result;
  }

  my %result;
  foreach my $tag_value (@pairs) {
    my ($tag, $value) = split(/=/, $tag_value, 2);
    push @{$result{$tag}}, $value;
  }

  if ($tag) {
    return @{$result{$tag} || []} if exists $result{$tag};
    my $type = $self->type();
    my $name = $self->name();
    my $feature_id = $self->feature_id();
    my $sql = $self->factory->parser->getSQL("Feature.pm", "$type:attribute:$tag");
    return unless $sql;
    $sql =~ s/(\$\w+)/eval "$1"/eg;
	#return @{$self->factory->dbh->selectcol_arrayref($sql)};
	return @{$self->factory->dbh->selectall_arrayref($sql)};
  }

  return \%result;
}

sub bulkAttributes { 
  my $self = shift; 
  my $atts = shift; 
  if($atts) { 
    if($self->{'bulkAtts'}) { 
      my $array = $self->{'bulkAtts'}; 
      push @$array, $atts; 
      return $self->{'bulkAtts'} = $array; 
    } else { 
      return $self->{'bulkAtts'} = [$atts]; 
    } 
  } 
  return $self->{'bulkAtts'}; 
}

=head2 notes

 Title   : notes
 Usage   : @notes = $feature->notes
 Function: get the "notes" on a particular feature
 Returns : an array of string
 Args	 : feature ID
 Status  : Public

=cut

sub notes {
  my $self = shift;
  $self->attributes('Note');
}

=head2 aliases

 Title   : aliases
 Usage	 : @aliases = $feature->aliaes
 Function: get the "aliases" on a particular feature
 Returns : an array of string
 Args	 : feature ID
 Status  : Public

This method will return a list of attributes of type 'Alias'.

=cut

sub aliases {
  my $self = shift;
  $self->attributes('Alias');
}

sub protein {
  my $self = shift;
  my $id = shift; # protein na_feature_id

  my $query = $self->factory->parser->getSQL("Feature.pm", "protein:seq");
  $query =~ s/(\$\w+)/eval $1/eg;

  my $sth = $self->factory->dbh->prepare($query);
  $sth->execute or $self->throw("protein query failed");

  while (my $hashref = $sth->fetchrow_hashref) {
    return [ $$hashref{'SOURCE_ID'},
	     $$hashref{'PROTEIN_ID'},
	     $$hashref{'SEQUENCE'}
	   ];
  }
}

sub _addSubFeatureFromRow {
  my ($self, $rowHashref) = @_;

  my $source = $$rowHashref{'SOURCE'};
  my $feature_id = $$rowHashref{'FEATURE_ID'};
  my $name = $$rowHashref{'NAME'};
  my $type = $$rowHashref{'TYPE'};
  my $unique_name = "$type.$feature_id";
  $type = $type. ":$source";

  my $subfeat = DAS::GUS::Segment::Feature->new($self->factory,
				    $self,
				    $self->ref,
				    $$rowHashref{'STARTM'}, # start
				    $$rowHashref{'END'}, # stop
				    $type,
				    $$rowHashref{'SCORE'}, # score
				    $$rowHashref{'STRAND'}, # strand
				    $$rowHashref{'PHASE'}, # phase
				    $$rowHashref{'NAME'}, # group
				    $$rowHashref{'ATTS'}, # attributes
				    $unique_name,
				    $feature_id
				   );

  $self->add_subfeature($subfeat);
  $subfeat->source($source);
  $self->{acquiredSubFeaturesByBulk} = 1;
}

1;
