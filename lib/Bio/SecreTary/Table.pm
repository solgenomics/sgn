package Table;

sub new {
    my $class = shift;
    my $self = bless {}, $class;

  #  print "in Table->new. class: $class \n";
    $self->set_label(shift);
    $self->set_marked_position(shift);
    $self->set_table(shift);
#    $self->set_aa_freqs(shift);
    return $self;
}

# scale using aa frequency vector
# the matrix should have 20 rows.
# i.e. it is a ref to an array of 20 array refs.
# each column is first normalized to sum to 1, then
#
sub scale {
    my $self = shift;
    my $v    = shift;
    my $m    = $self->get_table();
    ( scalar @$m == scalar @$v )
      || die "in Table::scale, sizes of m, v dont match:", scalar @$m, "  ", scalar @$v, "\n";
   # my $irow   = 0;
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
}

sub add_row{
    my $self = shift;
    my $new_row = shift; # array ref
    my $rows = $self->get_table(); # ref to array of array refs
    push @$rows, $new_row;
    $self->set_table($rows);
}
sub print {
    my $self = shift;
    print $self->get_label(), "\n";
    print $self->get_marked_position, "\n";
    my $m = $self->get_table();
    foreach (@$m) {
        print join( ", ", @$_ ), "\n";
    }
}

sub set_table {
    my $self = shift;
    $self->{table} = shift;
}

sub get_table {
    my $self = shift;
    return $self->{table};
}

sub set_label {
    my $self = shift;
    $self->{label} = shift;
}

sub get_label {
    my $self = shift;
    return $self->{label};
}

sub set_marked_position {
    my $self = shift;
    $self->{marked_position} = shift;
}

sub get_marked_position {
    my $self = shift;
    return $self->{marked_position};
}

sub set_column_explanation {
    my $self = shift;
    $self->{column_explanation} = shift;
}

sub get_column_explanation {
    my $self = shift;
    return $self->{column_explanation};
}

1;
