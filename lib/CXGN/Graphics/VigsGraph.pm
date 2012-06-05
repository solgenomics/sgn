
package CXGN::Graphics::VigsGraph;

use Moose;
use GD::Image;
use Data::Dumper;

has 'bwafile' => ( is=>'rw' );
has 'fragment_size' => (is => 'rw', isa=>'Int', default=>21);
has 'matches' => (is=>'rw', isa=>'Ref');
has 'seq_window_size' => (is=>'rw', isa=>'Int', default=>100);
has 'query_seq' => (is=>'rw', isa=>'Str');
has 'step_size' => (is=>'rw', isa=>'Int', default=>4);
has 'width' => (is=>'rw', isa=>'Int', default=>700);
has 'height'=> (is=>'rw', isa=>'Int', default=>700);


sub parse { 
    my $self = shift;
    
    warn("Parsing file ".$self->bwafile()."\n");

    open(my $F, "<", $self->bwafile()) || die "Can't open file ".$self->bwafile();

    my $matches = {};

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
		
	    my $ms = CXGN::Graphics::VigsGraph::MatchSegment->new();
	    $ms->start($start_coord);
	    $ms->end($end_coord);
	    $ms->id($subject);
	    
	    print STDERR "PARSING: $start_coord, $end_coord, $subject\n";

	    push @{$matches->{$subject}}, $ms;
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
	    if ( ($m->start() > $start) && ( $m->start() < $end) || ($m->end() > $start ) && ($m->end() < $end)) { 
		#print STDERR "Match found for sequence $s: $m->[0], $m->[1] ($start, $end)\n";
		push @{$interval->{$s}}, $m;
	    }

	}
    }
    return $interval;
}


sub sort_keys { 
    $b->[1] <=> $a->[1];
}

sub get_best_vigs_seqs { 
    my $self = shift;
    my $coverage = shift;
    
    my @scores = ();
    my @off_matches = ();
    my @ids = ();

    my $max_score = -100;
    for (my $i=0; $i<length($self->query_seq())-$self->seq_window_size(); $i=$i+$self->step_size()) { 
	my $interval = $self->matches_in_interval($i, $i+$self->seq_window_size-1);
	
	my @subjects = $self->subjects_by_match_count($interval);
	
	my $maximize = 0;
	for (my $c =0; $c<$coverage; $c++) { 
	    if (!defined($subjects[$c]->[1])) { last; }
	    if (!$maximize) { $maximize = $subjects[$c]->[1];}
	    else { 
		$maximize *= $subjects[$c]->[1];
	    }
	}
	my $minimize = 0;
	foreach my $c ($coverage..@subjects-1) { 
	    if (!defined($subjects[$c]->[1])) { next; }
	    $minimize += $subjects[$c]->[1];

	}
	

	my $score = $maximize - $minimize **2; 
	if ($score > $max_score) { $max_score = $score; }
	
	push @scores, $score;
	push @off_matches, $minimize;
	push @ids, $subjects[$coverage];

	#print STDERR "START: $i END: ".($i+$self->seq_window_size())." MAX: $maximize MIN: $minimize SCORE: $score\nMAX SCORE NOW: $max_score\n";
	
    }

    my @suggested_segments = ();
    foreach my $i (0..@scores-1) { 
       
	if (!exists($off_matches[$i]) || !defined($off_matches[$i])) { next; }
	#print STDERR "SCORE: $scores[$i]\n";
	if ( ($scores[$i] == $max_score) && ($off_matches[$i]==0)) { 
	    #print "SUGGESTED SEQUENCE IS IN INTERVAL $i\n";
	    
	    my $interval = CXGN::Graphics::VigsGraph::MatchSegment->new();
	    $interval->start($i*  $self->step_size());
	    $interval->end($i * $self->step_size() + $self->seq_window_size());
	    $interval->offsite_matches($off_matches[$i]);
	    $interval->score($scores[$i]);
	    $interval->id($ids[$i]);
			  
	    push @suggested_segments, $interval;
	}
    }

    return @suggested_segments;

#     my $best = 0;
#     foreach my $i (0..@$interval_matches-1) { 
# 	if (!defined($minimize[$i])) { 
# 	    $optimum[$i] = $maximize[$i];
# 	}
# 	else { 
# 	    $optimum[$i] = $maximize[$i] - ($minimize[$i] **2);
# 	}
# 	print "SEGMENT OPTIMUM: $optimum[$i]\n";
# 	if ($optimum[$i] > $best) { $best = $optimum[$i]; }
#     }
    
}

sub subjects_by_match_count { 
    my $self = shift;
    my $matches = shift;
    my @counts = ();
    foreach my $s (keys %$matches) { 
	push @counts, [ $s, scalar(@{$matches->{$s}}) ];
    }
    #print Dumper(\@counts);
    my @sorted = sort sort_keys @counts;
    
    return @sorted;
}

sub render { 
    my $self = shift;
    my $filename = shift;
    my $coverage = shift;

    my $image = GD::Image->new($self->width, $self->height);
    my $white = $image->colorAllocate(255,255,255);
    my $red   = $image->colorResolve(180, 0, 0);
    my $color = $image->colorResolve(0, 0, 0);    
    my $blue = $image->colorResolve(0, 0, 180);

    $image->filledRectangle(0, 0, $self->width, $self->height, $white);

    my $x_len = length($self->query_seq());

    my $x_scale = $self->width / $x_len;
    warn "X-scale: $x_scale\n";
    my $glyph_height = 3;


    my $matches = $self->matches();
    my $offset = 10;
    my $track_height = 0;
    my @sorted = $self->subjects_by_match_count($self->matches);
    
    #print Dumper(\@sorted);

    for (my $track=0; $track< @sorted; $track++) {
	my $max_tracks =0;
	my $current_track = 0;

	if ($track < $coverage) { $color = $blue; }
	else { $color = $red; }
	    

	my @tracks = ();
	#print STDERR "Processing $sorted->[0]\n";
	foreach my $i (@{$matches->{$sorted[$track]->[0]}}) { 
	    my $t = 0;
	    my $MAXTRACKS = $self->fragment_size();
	    while ($t <= $MAXTRACKS) { 

		if (!exists($tracks[$t]) || $tracks[$t]->{end} <= $i->start()) { 
		    $tracks[$t]->{end} = $i->end();
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
	    $image->rectangle($i->start() *  $x_scale, $offset + $current_track * $glyph_height, $i->end() * $x_scale, $offset + ($current_track+1)*$glyph_height, $red);

	}
	#print STDERR "Done with $sorted->[0] - drawing red line.. at ".($offset + $max_tracks * $glyph_height)."\n";

	$offset += 10;

	$image->line(0, $offset + ($max_tracks+1) * $glyph_height, $self->width, $offset + ($max_tracks+1) * $glyph_height, $red);
	
	$offset += $max_tracks * $glyph_height + 10;	

    }
    # draw vertical grid of seq_window_size in size
    for (my $x=0; $x < length($self->query_seq()); $x += $self->seq_window_size()) { 
	$image->line($x * $x_scale, 0, $x * $x_scale, $self->height, $red);
    }
    
    my @suggested_sequences = $self->get_best_vigs_seqs($coverage);
    foreach my $s (@suggested_sequences) { 
	$image->line($s->start * $x_scale, 0, $s->start * $x_scale, $self->height(), $color);
	$image->line($s->end * $x_scale, 0, $s->end * $x_scale, $self->height(), $color);
    }


    open(my $F, ">", $filename) || die "Can't open file $filename.";
    print $F $image->png();
    close($F);
}
    

package CXGN::Graphics::VigsGraph::MatchSegment;

use Moose;

has 'start' => (is => 'rw', isa=>'Int');
has 'end'   => (is => 'rw', isa=>'Int');
has 'id'    => (is => 'rw');
has 'score' => (is => 'rw', isa=>'Int');
has 'matches' => (is => 'rw', isa=>'Int');
has 'offsite_matches' => (is => 'rw', isa=>'Int');


	
1;
