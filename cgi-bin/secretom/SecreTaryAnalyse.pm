
=head1 NAME

SecreTaryAnalyse 
    - an object to analyse a protein sequence. Calculate and
store various quantities used by the SecreTary algorithm.

=head1 DESCRIPTION

=head1 AUTHOR

Tom York (tly2@cornell.edu)

=cut

use strict;

#use CXGN::Secretome::TMpred;
use TMpred;

package SecreTaryAnalyse;

=head2 function new()

Synopsis:
    my $limits = [$min_score, $min_tmh_length, $max_tmh_length, $min_beg, $max_beg];       
    my $S = SecreTaryAnalyse($limits, $protein_sequence, $sequence_id)
	Arguments: $limits is an array ref holding some parameters describing which solutions will be found by tmpred ($min_tmh_length, $max_tmh_length), and which will be kept in the TMpred object.		 
	Returns:	an instance of a SecreTaryAnalyse object
	Side effects:	creates the object.
	Description:	Does the analysis of the protein (e.g TMpred, AI22, Gravy22), stores them and returns the object.

=cut

sub new {
    my $class = shift;
    my $self = bless {}, $class;

    $self->set_sequence_id( shift || ">A_protein_sequence" );
    my $sequence     = shift;
    my $limits       = shift || [ 100, 500, 17, 40, 0, 40 ];
    my $trunc_length = shift @$limits;

    #   $trunc_length = 400;
    $self->set_sequence( substr( $sequence, 0, $trunc_length ) );

    #   print "limits: ", join( ";  ", @$limits ), "\n";
    $self->set_limits($limits);    # array ref; specifies which tmhs to keep.

    my $tmpred =
      TMpred->new( $self->get_limits(), $self->get_sequence(),
        $self->get_sequence_id() );

    $tmpred->setup();

    $self->set_TMpred($tmpred);
    $self->Sequence22_AAcomposition();

    return $self;
}

sub new1 {
        my $class = shift;
        my $self = bless {}, $class;

        $self->set_sequence_id( shift || ">A_protein_sequence" );
        my $sequence     = shift;
        my $limits       = shift || [ 100, 500, 17, 40, 0, 40 ];
        my $trunc_length = shift @$limits;

        #   $trunc_length = 400;
        $self->set_sequence( substr( $sequence, 0, $trunc_length ) );

        #   print "limits: ", join( ";  ", @$limits ), "\n";
        $self->set_limits($limits);   # array ref; specifies which tmhs to keep.

        return $self;
    }

    sub Sequence22_AAcomposition {
        my $self = shift;
        $self->set_AI22( $self->AliphaticIndex(22) );
        $self->set_Gravy22( $self->Gravy(22) );
        $self->set_nDRQPEN22( $self->nDRQPEN(22) );
        $self->set_nNitrogen22( $self->nNitrogen(22) );
        $self->set_nOxygen22( $self->nOxygen(22) );
    }

    sub set_TMpred {    # set the TMpred object
        my $self = shift;
        $self->{TMpred} = shift;
    }

    sub get_TMpred {
        my $self = shift;
        return $self->{TMpred};
    }

    sub set_limits {
        my $self = shift;
        $self->{limits} = shift;
    }

    sub get_limits {
        my $self = shift;
        return $self->{limits};
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

    sub print {
        my $self = shift;
        print $self->get_AI22(),        ", ";
        print $self->get_Gravy22(),     ", ";
        print $self->get_nDRQPEN22(),   ", ";
        print $self->get_nNitrogen22(), ", ";
        print $self->get_nOxygen22(),   "\n";
    }

    sub AliphaticIndex {
        my $self         = shift;
        my $trunc_length = shift;
        my $sequence     = $self->get_sequence();
        $sequence = substr( $sequence, 0, $trunc_length )
          if ( defined $trunc_length );
        my $nA = ( $sequence =~ tr/A// );
        my $nV = ( $sequence =~ tr/V// );
        my $nL = ( $sequence =~ tr/L// );
        my $nI = ( $sequence =~ tr/I// );
        my $nX = ( $sequence =~ tr/X// );
        my $L  = 22 - $nX;
        return 100.0 * ( 1.0 * $nA + 2.9 * $nV + 3.9 * ( $nL + $nI ) ) / $L;
    }

    sub Gravy {
        my $self         = shift;
        my $trunc_length = shift;
        my $sequence     = $self->get_sequence();
        $sequence = substr( $sequence, 0, $trunc_length )
          if ( defined $trunc_length );

      # Kyte and Doolittle hydropathy index: (from Wikipedia "Hydropathy index")
        my %Hydropaths = (
            "A" => 1.80,
            "R" => -4.50,
            "N" => -3.50,
            "D" => -3.50,
            "C" => 2.5,
            "E" => -3.50,
            "Q" => -3.50,
            "G" => -0.40,
            "H" => -3.20,
            "I" => 4.50,
            "L" => 3.80,
            "K" => -3.90,
            "M" => 1.90,
            "F" => 2.80,
            "P" => -1.60,
            "S" => -0.80,
            "T" => -0.70,
            "W" => -0.90,
            "Y" => -1.30,
            "V" => 4.20
        );

        my $sum_h = 0;
        my $count = 0;

        while ($sequence) {
            my $char = chop $sequence;
            if ( defined $Hydropaths{$char} ) {
                $sum_h += $Hydropaths{$char};
                $count++;
            }
        }

        if ( $count > 0 ) {
            return $sum_h / $count;
        }
        else {
            return -10000.0;
        }
    }

    sub nDRQPEN {
        my $self         = shift;
        my $trunc_length = shift;
        my $sequence     = $self->get_sequence();
        $sequence = substr( $sequence, 0, $trunc_length )
          if ( defined $trunc_length );
        my $count = 0;
        while ($sequence) {
            my $c = chop $sequence;
            $count++ if ( $c =~ /[DRQPEN]/ );
        }
        return $count;
    }

    sub nNitrogen {
        my $self         = shift;
        my $trunc_length = shift;
        my $sequence     = $self->get_sequence();
        $sequence = substr( $sequence, 0, $trunc_length )
          if ( defined $trunc_length );
        my $count = 0;
        while ($sequence) {
            my $c = chop $sequence;
            $count += N_in_aa($c);
        }
        return $count;
    }

    sub nOxygen {
        my $self         = shift;
        my $trunc_length = shift;
        my $sequence     = $self->get_sequence();
        $sequence = substr( $sequence, 0, $trunc_length )
          if ( defined $trunc_length );

        my $count = 0;
        while ($sequence) {
            my $c = chop $sequence;
            $count += O_in_aa($c);
        }
        return $count;
    }

    sub N_in_aa {
        my $aa    = shift;
        my %Nhref = (
            "H" => 3,
            "K" => 2,
            "N" => 2,
            "O" => 3,
            "Q" => 2,
            "R" => 4,
            "W" => 2
        );
        if ( exists $Nhref{$aa} ) {
            return $Nhref{$aa};
        }
        else {
            return 1;
        }
    }

    sub O_in_aa {
        my $aa    = shift;
        my %Ohref = (
            "D"  => 3,
            "E", => 3,
            "N"  => 2,
            "O"  => 3,
            "Q"  => 2,
            "S"  => 2,
            "T"  => 2,
            "Y"  => 2
        );
        if ( exists $Ohref{$aa} ) {
            return $Ohref{$aa};
        }
        else {
            return 1;
        }
    }

    1;
