
=head1 NAME

Bio::SecreTary::SecreTaryAnalyse

=head1 DESCRIPTION

Bio::SecreTary::SecreTaryAnalyse - an object to analyse a protein
sequence. Calculate and store various quantities used by the SecreTary
algorithms to predict signal peptides.

=head1 AUTHOR

Tom York (tly2@cornell.edu)

=cut

package Bio::SecreTary::SecreTaryAnalyse;
use Moose;
use namespace::autoclean;
use Bio::SecreTary::TMpred;
use Bio::SecreTary::TMpred_Cinline;
use Bio::SecreTary::Cleavage;
use Bio::SecreTary::AAComposition;

has sequence_id => (
		    isa     => 'Str',
		    is      => 'ro',
		    required => 1 );
has sequence => (
		 isa     => 'Str',
		 is      => 'ro',
		 required => 1,
		 writer => '_set_sequence' );
has tmpred_obj => (
		   isa => 'Object',
		   is => 'ro' ,
		   required => 1);
has cleavage_predictor => (
isa => 'Object',
			   is => 'ro',
			   required => 1);

has tmpred_good_solutions => (
			      isa => 'Str',
			      is => 'ro',
			      default => undef,
			      writer => '_set_tmpred_good_solutions' );
has trunc_length => (
		     isa => 'Int',
		     is => 'ro',
		     default => 100 );
has cleavage_prediction => (
			    isa => 'ArrayRef',
			    is => 'rw',
			    default => sub { [undef, undef, undef, undef] }, 
			    writer => '_set_cleavage_prediction' );
has AI22 => (
	     isa => 'Num',
	     is => 'ro',
	     default => undef,
	     writer => '_set_AI22' );
has Gravy22 => (
		isa => 'Num',
		is => 'ro',
		default => undef,
		writer => '_set_Gravy22' );
has nDRQPEN22 => (
		  isa => 'Int',
		  is => 'ro',
		  default => undef,
		  writer => '_set_nDRQPEN22' );
has nNitrogen22 => (
		    isa => 'Int',
		    is => 'ro',
		    default => undef,
		    writer => '_set_nNitrogen22' );
has nOxygen22 => (
		  isa => 'Int',
		  is => 'ro',
		  default => undef,
		  writer => '_set_nOxygen22' );
has candidate_solutions => (
			    isa => 'ArrayRef',
			    is => 'ro',
			    default => undef,
			    writer => '_set_candidate_solutions' );


=head2 function BUILD

Synopsis:
    my $STA_obj = Bio::SecreTary::SecreTaryAnalyse->new({
                sequence_id => $id,
                sequence => $sequence,
                tmpred_obj => $TMpred_obj,
                cleavage_predictor => $cleavage_predictor_obj,
                trunc_length => 100
                });

	Arguments: $TMpred_obj is an instance of TMpred, $trunc_length an optional length to truncate sequence to (default is 100).
	Returns:	an instance of a SecreTaryAnalyse object
	Side effects:	creates the object.
	Description:	This is the Moose Builder which is automatically called after new creates object and sets attributes according to its arguments and defaults. BUILD then does the analysis of the protein (TMpred, AI22, Gravy22, etc.), stores the results in the object and returns it.       .

=cut

sub BUILD {
    my $self     = shift;

    $self->_set_sequence(substr( $self->sequence(), 0, $self->trunc_length() ));

# TMpred
    my ( $outstring, $long_output ) =
      $self->tmpred_obj()->run_tmpred( $self->sequence(), $self->sequence_id() );
    $self->_set_tmpred_good_solutions($outstring);

# AI22, Gravy22, nDRQPEN22, etc.
    $self->sequence22_AAcomposition();

# do the cleavage site calculation
    my $cleavage_predictor_obj = $self->cleavage_predictor();  #Bio::SecreTary::Cleavage->new(); # Should avoid doing this for each sequence
    my $sp_length = $cleavage_predictor_obj->cleavage_fast($self->sequence());

# subdomains (n, h, c)
    # $hstart is the 0-based number of first AA of h region, i.e. the length of
    # the n region. cstart is the 0-based number of first AA of the c region
    # i.e. post-hydrophobic cleavage region
    my ( $typical, $hstart, $cstart ) =
      $cleavage_predictor_obj->subdomain( substr( $self->sequence(), 0, $sp_length ) );
    $self->_set_cleavage_prediction( [ $sp_length, $hstart, $cstart, $typical ] );

    my @candidate_solutions = ();
    my $tmpred_good_solns   = $self->tmpred_good_solutions();
    while ( $tmpred_good_solns =~ s/^ ( \( \S+? \) ) //xms )
    {    # soln in () -> $1
        my $soln = $1;
        $soln =~ s/ \s //gxms;    # delete whitespace
        $soln =~ s/ ^[(]//xms;
        $soln =~ s/ [)]$ //xms;
        my ( $tmpred_score, $beg, $end ) = split( ',', $soln );
        my $nGASDRQPENtm = $self->nGASDRQPEN( $beg - 1, $end + 1 - $beg )
          ;                       # beg,end are unit based
        push @candidate_solutions, "$tmpred_score,$beg,$end,$nGASDRQPENtm";
    }

    $self->_set_candidate_solutions(\@candidate_solutions);
    return $self;
}

=head2 function sequence22_AAcomposition

Synopsis: $STA_obj->sequence22_AAcomposition();
	Arguments: 
	Side effects:
	Description:	Calculates 5 quantities (AI, Gravy, nDRQPEN, nNitrogren and nOxygen) for the sequence consisting of the first 22 amino acids. These are stored in the SecreTaryAnalyse object.

=cut

sub sequence22_AAcomposition {
    my $self = shift;

    $self->_set_AI22( $self->aliphatic_index(22) );
    $self->_set_Gravy22( $self->gravy(22) );
    $self->_set_nDRQPEN22( $self->nDRQPEN(22) );
    $self->_set_nNitrogen22( $self->nNitrogen(22) );
    $self->_set_nOxygen22( $self->nOxygen(22) );
}

sub aa22string {    # has
    my $self      = shift;
    my $separator = shift || ' ';
    my $result    = $self->AI22();
    $result .= $separator . $self->Gravy22();
    $result .= $separator . $self->nDRQPEN22();
    $result .= $separator . $self->nNitrogen22();
    $result .= $separator . $self->nOxygen22();

    return $result;
}

=head2 function aliphatic_index

Synopsis: $STA_obj->aliphatic_index($length);
	Description: Truncates the sequence to length $length, calculates
and returns the aliphatic index of the truncated sequence.

=cut

sub aliphatic_index {
    my $self         = shift;
    my $trunc_length = shift || undef;
    my $sequence     = $self->sequence();
    $sequence = substr( $sequence, 0, $trunc_length )
      if ( defined $trunc_length );
    return Bio::SecreTary::AAComposition::aliphatic_index($sequence);
}

=head2 function gravy

Synopsis: $STA_obj->gravy($length);
	Description: Truncates the sequence to length $length, calculates
and returns the "gravy" index of the truncated sequence.

=cut

sub gravy {
    my $self         = shift;
    my $trunc_length = shift;
    my $sequence     = $self->sequence();
    $sequence = substr( $sequence, 0, $trunc_length )
      if ( defined $trunc_length );

    return Bio::SecreTary::AAComposition::gravy($sequence);
}

=head2 function nDRQPEN

Synopsis: $STA_obj->nDRQPEN($length);
	Description: Truncates the sequence to length $length, calculates
and returns the number of amino acids in this truncated sequence which are DRQPE or N.

=cut

sub nDRQPEN {
    my $self         = shift;
    my $trunc_length = shift;
    my $sequence     = $self->sequence();
    $sequence = substr( $sequence, 0, $trunc_length )
      if ( defined $trunc_length );

    return Bio::SecreTary::AAComposition::nDRQPEN($sequence);
}

=head2 function nGASDRQPEN

Synopsis: $STA_obj->nGASDRQPEN($beg, $length);
	Description: takes substr($sequence, $beg, $length) and calculates
and returns the number of amino acids in this truncated sequence which are GASDRQPE or N.

=cut

sub nGASDRQPEN {
    my $self     = shift;
    my $beg      = shift || 0;              # zero-based
    my $length   = shift;
    my $sequence = $self->sequence();
    $sequence = substr( $sequence, $beg, $length ) if ( defined $length );
    return Bio::SecreTary::AAComposition::nGASDRQPEN($sequence);
}

=head2 function nNitrogen

Synopsis: $STA_obj->nNitrogen($length);
	Description: Truncates the sequence to length $length, calculates
and returns the number of Nitrogen atoms in this truncated sequence.

=cut

sub nNitrogen {
    my $self         = shift;
    my $trunc_length = shift;
    my $sequence     = $self->sequence();
    $sequence = substr( $sequence, 0, $trunc_length )
      if ( defined $trunc_length );

    return Bio::SecreTary::AAComposition::nNitrogen($sequence);
}

=head2 function nOxygen

Synopsis: $STA_obj->nOxygen($length);
	Description: Truncates the sequence to length $length, calculates
and returns the number of Oxygen atoms in this truncated sequence.

=cut

sub nOxygen {
    my $self         = shift;
    my $trunc_length = shift;
    my $sequence     = $self->sequence();
    $sequence = substr( $sequence, 0, $trunc_length )
      if ( defined $trunc_length );

    return Bio::SecreTary::AAComposition::nOxygen($sequence);
}

__PACKAGE__->meta->make_immutable;

1;
