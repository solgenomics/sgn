package Bio::SecreTary::Helix;

use strict;
use warnings;

sub new {
    my $class = shift;
    my $self = bless {}, $class;

    $self->{center}   = [ undef, undef ];    # [position, score]
    $self->{nterm}    = [ undef, undef ];
    $self->{cterm}    = [ undef, undef ];
    $self->{sh_nterm} = [ undef, undef ];
    $self->{sh_cterm} = [ undef, undef ];
    $self->{score}    = undef; # overall score
    $self->{nt_in}    = undef; # TRUE for in-to-out orientation
    return $self;
}

sub set_center {
    my $self = shift;
    return $self->{center} = shift;
}

sub get_center {
    my $self = shift;
    return $self->{center};
}

sub set_nterm {
    my $self = shift;
    return $self->{nterm} = shift;
}

sub get_nterm {
    my $self = shift;
    return $self->{nterm};
}

sub set_cterm {
    my $self = shift;
    return $self->{cterm} = shift;
}

sub get_cterm {
    my $self = shift;
    return $self->{cterm};
}

sub set_sh_cterm {
    my $self = shift;
    return $self->{sh_cterm} = shift;
}

sub get_sh_cterm {
    my $self = shift;
    return $self->{sh_cterm};
}

sub set_sh_nterm {
    my $self = shift;
    return $self->{sh_nterm} = shift;
}

sub get_sh_nterm {
    my $self = shift;
    return $self->{sh_nterm};
}

sub set_score {
    my $self = shift;
    return $self->{score} = shift;
}

sub get_score {
    my $self = shift;
    return $self->{score};
}

sub set_nt_in {
    my $self = shift;
    return $self->{nt_in} = shift;
}

sub get_nt_in {
    my $self = shift;
    return $self->{nt_in};
}

sub get_descriptor_string {
    my $self   = shift;
    my $string = '';
    my $offset = 1;       # add this to 0-based positions to get unit-based
    if (0) {
        $string .= 'nt_in: ' . $self->get_nt_in() . "\n";
        $string .= 'score: ' . $self->get_score() . "\n";
        $string .= 'center: ' . join( ', ', @{ $self->get_center() } ) . "\n";
        $string .= 'nterm: ' . join( ', ', @{ $self->get_nterm() } ) . "\n";
        $string .= 'cterm: ' . join( ', ', @{ $self->get_cterm() } ) . "\n";
        $string .=
          'sh_nterm: ' . join( ', ', @{ $self->get_sh_nterm() } ) . "\n";
        $string .=
          'sh_cterm: ' . join( ', ', @{ $self->get_sh_cterm() } ) . "\n";
    }
    else {
        my $npos       = $self->get_nterm()->[0] + $offset;
        my $npos_core  = $self->get_sh_nterm()->[0] + $offset;
        my $cpos       = $self->get_cterm()->[0] + $offset;
        my $cpos_core  = $self->get_sh_cterm()->[0] + $offset;
        my $center_pos = $self->get_center()->[0] + $offset;
        $string .=
            $npos . '  ('
          . $npos_core . ')    '
          . $cpos . '  ('
          . $cpos_core . ')    '
          . $self->get_score() . '     '
          . $center_pos;
    }

    return $string;
}

sub short_description{
    my $self = shift;
      my $npos       = $self->get_nterm()->[0] + 1;
         my $cpos       = $self->get_cterm()->[0] + 1;
         return '[' . $self->get_score() . ",$npos,$cpos]";
}


1;
