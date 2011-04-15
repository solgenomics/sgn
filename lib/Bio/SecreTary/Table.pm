package Bio::SecreTary::Table;
use strict;
use warnings;
use Carp;
use Moose;
use namespace::autoclean;

=head2 function new

  Synopsis : my $table_obj =  Bio::SecreTary::Table->new(
        label => 'io_center',
        marked_position => 10,    # zero-based here
        table => [ [ 56.22, 63.83 ],[ 56.55, 56.78 ] ] );

=cut


has label => (isa => 'Str', is => 'rw', required => 1 );
has marked_position => (isa => 'Int', is => 'rw', required => 1 );
has table => (isa => 'ArrayRef[ArrayRef[Num]]', is => 'rw', required => 1 );

# scale using aa frequency vector
# the matrix should have 20 rows.
# i.e. it is a ref to an array of 20 array refs.
# each column is first normalized to sum to 1, then
#
sub scale {
    my $self = shift;
    my $v    = shift;
    my $m    = $self->table();
    ( scalar @$m == scalar @$v )
      || croak( "in Table::scale, sizes of m, v dont match:", scalar @$m, "  ", scalar @$v, "\n" );

    my $ncols  = scalar @{$m->[0]};
    my @sums   = ( (0) x $ncols );

    foreach my $row (@$m) {    # get the sums of each col; $row is an array ref
        for ( my $jcol = 0 ; $jcol < scalar @$row ; $jcol++ ) {
            $sums[$jcol] += $row->[$jcol];
        }
    }
    foreach my $row (@$m) {    # do something about elements which are zero
        for ( my $jcol = 0 ; $jcol < scalar @$row ; $jcol++ ) {
            my $element = $row->[$jcol];
            if ( $element == 0 ) {
                $row->[$jcol] = 1 / $sums[$jcol]
                  ; # slavish imitation of pascal code - probably should be changed.
                 # $sums[$jcol] += $row->[$jcol]; # so sum reflects changed val of element
            }
        }
    }
    my $irow = 0;
    foreach my $row (@$m) {    # 
        for ( my $jcol = 0 ; $jcol < scalar @$row ; $jcol++ ) {
            my $element = $row->[$jcol]/$sums[$jcol]; # normalize col sum to 1.
            $row->[$jcol] = log( $element / $v->[$irow] );
        }
        $irow++;
    }
    return $m;
}

sub add_row{
    my $self = shift;
    my $new_row = shift; # array ref
    my $rows = $self->table(); # ref to array of array refs
    push @$rows, $new_row;
    return $self->table($rows);
}
sub table_as_string {
    my $self = shift;
    my $string = $self->label() . "\n";
    $string .= $self->marked_position . "\n";
    my $m = $self->table();
    foreach (@$m) {
        $string .=  join( ', ', @$_ ) . "\n";
    }
    return $string;
}

__PACKAGE__->meta->make_immutable;

1;
