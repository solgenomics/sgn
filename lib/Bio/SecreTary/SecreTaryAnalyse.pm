
=head1 NAME

Bio::SecreTary::SecreTaryAnalyse - an object to analyse a protein
sequence. Calculate and store various quantities used by the SecreTary
algorithms to predict signal peptides.

=head1 DESCRIPTION



=head1 AUTHOR

Tom York (tly2@cornell.edu)

=cut

package Bio::SecreTary::SecreTaryAnalyse;
use strict;
use warnings;
use Bio::SecreTary::TMpred;
use Bio::SecreTary::Cleavage;
use Bio::SecreTary::AAComposition;

=head2 function new()

Synopsis:
    my $STA_obj = Bio::SecreTary::SecreTaryAnalyse->new($sequence_id, $protein_sequence, $tmpred_obj, $trunc_length)
	Arguments: $tmpred_obj is an instance of TMpred, $trunc_length an optional length to truncate sequence to (default is 100).
	Returns:	an instance of a SecreTaryAnalyse object
	Side effects:	creates the object.
	Description:	Does the analysis of the protein (e.g TMpred, AI22, Gravy22), stores them and returns the object.

=cut

sub new {
    my $class        = shift;
    my $self         = bless {}, $class;
    my $sequence_id  = shift;
    my $sequence     = shift;
    my $tmpred_obj   = shift;
    my $trunc_length = shift || 100;

    $sequence = substr( $sequence, 0, $trunc_length );

    $self->set_sequence_id($sequence_id);
    $self->set_sequence($sequence);

    my ($outstring, $long_output) = 
	$tmpred_obj->run_tmpred( $sequence, $sequence_id);
 #   $tmpred_obj->run_tmpred($sequence, {'sequence_id'=> $sequence_id, 'version' => 'perl'});

    $self->set_tmpred_good_solutions($outstring);

    $self->Sequence22_AAcomposition();

    # do the cleavage site calculation
    my $cleavage_obj = Bio::SecreTary::Cleavage->new();
    my $sp_length    = $cleavage_obj->cleavage($sequence);

    # $hstart is the 0-based number of first AA of h region, i.e. the length of
    # the n region. cstart is the 0-based number of first AA of the c region
    # i.e. post-hydrophobic cleavage region
    my ( $typical, $hstart, $cstart ) =
      $cleavage_obj->subdomain( substr( $sequence, 0, $sp_length ) );

    $self->set_cleavage( [ $sp_length, $hstart, $cstart, $typical ] );
    return $self;
  }


=head2 function Sequence22_AAcomposition

Synopsis: $STA_obj->Sequence22_AAcomposition();
	Arguments: $STA_obj is an instance of SecreTaryAnalyse.
	Side effects:	Creates the object.
	Description:	Calculates 5 quantities (AI, Gravy, nDRQPEN, nNitrogren and nOxygen) for the sequence consisting of the first 22 amino acids. These are stored in the SecreTaryAnalyse object.

=cut

sub Sequence22_AAcomposition {
  my $self = shift;

    $self->set_AI22( $self->AliphaticIndex(22) );
    $self->set_Gravy22( $self->Gravy(22) );
    $self->set_nDRQPEN22( $self->nDRQPEN(22) );
    $self->set_nNitrogen22( $self->nNitrogen(22) );
    $self->set_nOxygen22( $self->nOxygen(22) );
}


=head2 function AliphaticIndex

Synopsis: $STA_obj->AliphaticIndex($length);
	Description: Truncates the sequence to length $length, calculates
and returns the aliphatic index of the truncated sequence.

=cut


sub AliphaticIndex {
    my $self         = shift;
    my $trunc_length = shift || undef;
    my $sequence     = $self->get_sequence();
$sequence = substr($sequence, 0, $trunc_length) if(defined $trunc_length);
   return Bio::SecreTary::AAComposition::AliphaticIndex($sequence);
}

=head2 function Gravy

Synopsis: $STA_obj->Gravy($length);
	Description: Truncates the sequence to length $length, calculates
and returns the "Gravy" index of the truncated sequence.

=cut

sub Gravy {
    my $self         = shift;
    my $trunc_length = shift;
    my $sequence     = $self->get_sequence();
    $sequence = substr( $sequence, 0, $trunc_length )
      if ( defined $trunc_length );

   return  Bio::SecreTary::AAComposition::Gravy($sequence);
}

=head2 function nDRQPEN

Synopsis: $STA_obj->nDRQPEN($length);
	Description: Truncates the sequence to length $length, calculates
and returns the number of amino acids in this truncated sequence which are DRQPE or N.

=cut

sub nDRQPEN {
    my $self         = shift;
    my $trunc_length = shift;
    my $sequence     = $self->get_sequence();
    $sequence = substr( $sequence, 0, $trunc_length )
      if ( defined $trunc_length );

   return  Bio::SecreTary::AAComposition::nDRQPEN($sequence);
}


=head2 function nGASDRQPEN

Synopsis: $STA_obj->nGASDRQPEN($length);
	Description: Truncates the sequence to length $length, calculates
and returns the number of amino acids in this truncated sequence which are GASDRQPE or N.

=cut

sub nGASDRQPEN {
    my $self         = shift;
    my $beg = shift || 0; # zero-based
    my $length = shift;
    my $sequence   = $self->get_sequence();
  $sequence = substr( $sequence, $beg, $length) if(defined $length);
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
  my $sequence     = $self->get_sequence();
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
    my $sequence     = $self->get_sequence();
    $sequence = substr( $sequence, 0, $trunc_length )
      if ( defined $trunc_length );

 return Bio::SecreTary::AAComposition::nOxygen($sequence);
}

sub set_tmpred_good_solutions {
    my $self = shift;
    $self->{tmpred_good_solutions} = shift;
}

sub get_tmpred_good_solutions {
    my $self = shift;
    return $self->{tmpred_good_solutions};
}

sub set_sequence {
    my $self = shift;
    $self->{sequence} = shift;
}

sub get_sequence {
    my $self = shift;
    return $self->{sequence};
}

sub set_sequence_id {
    my $self = shift;
    $self->{sequence_id} = shift;
}

sub get_sequence_id {
    my $self = shift;
    return $self->{sequence_id};
}

sub set_cleavage {
    my $self = shift;
    $self->{cleavage} = shift;
}

sub get_cleavage {
    my $self = shift;
    return $self->{cleavage};
}

sub set_AI22 {
    my $self = shift;
    $self->{AI22} = shift;
}

sub get_AI22 {
    my $self = shift;
    return $self->{AI22};
}

sub set_Gravy22 {
    my $self = shift;
    $self->{Gravy22} = shift;
}

sub get_Gravy22 {
    my $self = shift;
    return $self->{Gravy22};
}

sub set_nDRQPEN22 {
    my $self = shift;
    $self->{nDRQPEN22} = shift;
}

sub get_nDRQPEN22 {
    my $self = shift;
    return $self->{nDRQPEN22};
}

sub set_nNitrogen22 {
    my $self = shift;
    $self->{nNitrogen22} = shift;
}

sub get_nNitrogen22 {
    my $self = shift;
    return $self->{nNitrogen22};
}

sub set_nOxygen22 {
    my $self = shift;
    $self->{nOxygen22} = shift;
}

sub get_nOxygen22 {
    my $self = shift;
    $self->{nOxygen22};
}

# sub print22 {
#     my $self = shift;
#     print $self->get_AI22(),        ", ";
#     print $self->get_Gravy22(),     ", ";
#     print $self->get_nDRQPEN22(),   ", ";
#     print $self->get_nNitrogen22(), ", ";
#     print $self->get_nOxygen22(),   "\n";
# }

1;
