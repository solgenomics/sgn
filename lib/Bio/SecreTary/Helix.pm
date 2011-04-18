package Bio::SecreTary::Helix;
use Moose;
use namespace::autoclean;

has center => (
    isa     => 'ArrayRef[Maybe[Num]]',
    is      => 'rw',
    default => sub { [ undef, undef ] }
);
has nterm => (
    isa     => 'ArrayRef[Maybe[Num]]',
    is      => 'rw',
    default => sub { [ undef, undef ] }
);
has cterm => (
    isa     => 'ArrayRef[Maybe[Num]]',
    is      => 'rw',
    default => sub { [ undef, undef ] }
);
has sh_nterm => (
    isa     => 'ArrayRef[Maybe[Num]]',
    is      => 'rw',
    default => sub { [ undef, undef ] }
);
has sh_cterm => (
    isa     => 'ArrayRef[Maybe[Num]]',
    is      => 'rw',
    default => sub { [ undef, undef ] }
);
has score => ( isa => 'Maybe[Num]', is => 'rw', default => undef );
has nt_in => ( isa => 'Bool',       is => 'rw', default => undef );

sub get_descriptor_string {
    my $self   = shift;
    my $string = '';
    my $offset = 1;       # add this to 0-based positions to get unit-based
    if (0) {
        $string .= 'nt_in: ' . $self->nt_in() . "\n";
        $string .= 'score: ' . $self->score() . "\n";
        $string .= 'center: ' . join( ', ', @{ $self->center() } ) . "\n";
        $string .= 'nterm: ' . join( ', ', @{ $self->nterm() } ) . "\n";
        $string .= 'cterm: ' . join( ', ', @{ $self->cterm() } ) . "\n";
        $string .= 'sh_nterm: ' . join( ', ', @{ $self->sh_nterm() } ) . "\n";
        $string .= 'sh_cterm: ' . join( ', ', @{ $self->sh_cterm() } ) . "\n";
    }
    else {
        my $npos       = $self->nterm()->[0] + $offset;
        my $npos_core  = $self->sh_nterm()->[0] + $offset;
        my $cpos       = $self->cterm()->[0] + $offset;
        my $cpos_core  = $self->sh_cterm()->[0] + $offset;
        my $center_pos = $self->center()->[0] + $offset;
        $string .=
            $npos . '  ('
          . $npos_core . ')    '
          . $cpos . '  ('
          . $cpos_core . ')    '
          . $self->score() . '     '
          . $center_pos;
    }

    return $string;
}

sub short_description {
    my $self = shift;
    my $npos = $self->nterm()->[0] + 1;
    my $cpos = $self->cterm()->[0] + 1;
    return '[' . $self->score() . ",$npos,$cpos]";
}

__PACKAGE__->meta->make_immutable;

1;
