
package CXGN::Graphics::VigsGraph;

use Moose;
use GD::Image;
use Data::Dumper;

has 'bwafile' => ( is=>'rw' );
has 'fragment_size' => (is => 'rw', isa=>'Int', default=>21);
has 'matches' => (is=>'rw', isa=>'Ref');
has 'seq_window_size' => (is=>'rw', isa=>'Int');
has 'query_seq' => (is=>'rw', isa=>'Str');

has 'width' => (is=>'rw', isa=>'Int', default=>1200);
has 'height'=> (is=>'rw', isa=>'Int', default=>1200);

sub parse { 
    my $self = shift;
    
    open(my $F, "<", $self->bwafile()) || die "Can't open file ".$self->bwafile();

    my $matches;

    while (<$F>) { 
	if (/^\@SQ/) { 
	    next;
	}

	my ($seq_id, $code, $subject, $scoord, $what, $match) = split /\t/;
	if ($match=~/(\d+)M/ and $1 == $self->fragment_size()) { 
	    my ($start_coord, $end_coord);
	    if ($seq_id=~/(\d+)/)  {
		$start_coord = $1;
		$end_coord = $start_coord+$self->fragment_size() -1;
	    }
		
	    push @{$matches->{$subject}}, [$start_coord, $end_coord];
	}
    }
    $self->matches($matches);
   
}
 
sub matches_in_interval { 
    my $self = shift;
    my $start = shift;
    my $end = shift;
    
    my $matches = $self->matches();
    my $interval = {};

    foreach my $s (keys(%$matches)) { 
	#print  $s."\n";
	foreach my $m (@{$matches->{$s}}) { 
#	    print STDERR "checking coords $m->[0], $m->[1] (start, end = $start, $end)\n";
	    if ( ($start > $m->[0]) && ($start < $m->[1]) || ($end > $m->[0]) && ($end < $m->[1])) { 
		#print STDERR "Match found for sequence $s: $m->[0], $m->[1] ($start, $end)\n";
		push @{$interval->{$s}}, [ $m->[0], $m->[1] ];
	    }
	}
    }
    return $interval;
}


sub scan { 
    my $self = shift;
    
    my $interval_matches;
    
    for (my $i=0; $i<length($self->query_seq())-$self->seq_window_size(); $i=$i+10) { 
	my $interval = $self->matches_in_interval($i, $i+$self->seq_window_size-1);
	push @$interval_matches, $interval;
	
    }
    return $interval_matches;
    
}


sub sort_keys { 
    $b->[1] <=> $a->[1];
}

sub get_best_vigs_seq { 
    my $self = shift;
    my $coverage = shift;

    my $im = $self->scan();

    #print Dumper($im);

    my @counts;


    foreach my $i (@$im) { 

	foreach my $s (keys(%$i)) { 
	    push @counts, [ $s, scalar(@{$i->{$s}}) ];    
	}
    }
    my @sorted = sort sort_keys @counts;
    return @sorted;
}

sub subjects_by_match_count { 
    my $self = shift;
    my $matches = shift;
    my @counts = ();
    foreach my $s (keys %$matches) { 
	push @counts, [ $s, scalar(@{$matches->{$s}}) ];
    }
    print Dumper(\@counts);
    my @sorted = sort sort_keys @counts;
    

    print "NOW SORTED...\n";
    print Dumper(\@sorted);
    return @sorted;
}

sub render { 
    my $self = shift;
    my $filename = shift;

    my $image = GD::Image->new($self->width, $self->height);
    my $white = $image->colorResolve(255, 255, 255);
    my $red   = $image->colorResolve(255, 0, 0);
    my $color = $image->colorResolve(0, 0, 0);    
    $image->rectangle(0, 0, $self->width, $self->height, $white);
    my $x_len = length($self->query_seq());

    my $x_scale = $self->width / $x_len;
    warn "X-scale: $x_scale\n";
    my $glyph_height = 3;


    my $matches = $self->matches();
    my $offset = 0;
    my $track_height = 0;
    my @sorted = $self->subjects_by_match_count($self->matches);
    
    print Dumper(\@sorted);

    foreach my $sorted (@sorted) {
	my $max_tracks =0;
	my $current_track = 0;
	my @tracks = ();
	print "Processing $sorted->[0]\n";
	foreach my $i (@{$matches->{$sorted->[0]}}) { 
	    my $t = 0;
	    my $MAXTRACKS = $self->fragment_size();
	    while ($t <= $MAXTRACKS) { 

		if ($tracks[$t]->{end} <= $i->[0]) { 
		    $tracks[$t]->{end} = $i->[1];
		    $current_track = $t;
		    last();
		}
		else { 
		    $t++;
		}
		if ($t > $max_tracks) { $max_tracks = $t; }
	
	#	if (!exists($tracks[$t]) && !defined($tracks[$t])) { 
	#	    $tracks[$t]->{end} = $i->[1];
	#	    $current_track = $t;
	#	    last();
	#	}
	
	    }
	    $image->rectangle($i->[0] *  $x_scale, $offset + $current_track * $glyph_height, $i->[1] * $x_scale, $offset + ($current_track+1)*$glyph_height, $color);

	}
	print "Done with $sorted->[0] - drawing red line.. at ".($offset + $max_tracks * $glyph_height)."\n";

	$image->line(0, $offset + ($max_tracks+1) * $glyph_height, $self->width, $offset + ($max_tracks+1) * $glyph_height, $red);
	
	$offset += $max_tracks * $glyph_height + 10;



	

    }
    
    open(my $F, ">", $filename) || die "Can't open file $filename.";
    print $F $image->png();
    close($F);
}
    
	
1;
