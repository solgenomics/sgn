
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
has 'height'=> (is=>'rw', isa=>'Int', default=>2400);
has 'font' => (is =>'rw', isa=>'GD::Font');
has 'ruler_height' => (is => 'ro', isa=>'Int', default=>20);

sub parse { 
    my $self = shift;
    
    # warn("Parsing file ".$self->bwafile()."\n");

    open(my $bt2_fh, "<", $self->bwafile()) || die "Can't open file ".$self->bwafile();

    my $matches = {};
    
    # parse Bowtie2 file
    while (my $line = <$bt2_fh>) { 
	my ($seq_id, $code, $subject, $scoord) = (split /\t/, $line);
	
	# get perfect matches 
	if ($line =~ /XM:i:0/) { 
	    my ($start_coord, $end_coord);
	    if ($seq_id=~/(\d+)/)  {
		$start_coord = $1;
		$end_coord = $start_coord+$self->fragment_size() -1;
	    }
	    
	    # new match sequence object
	    my $ms = CXGN::Graphics::VigsGraph::MatchSegment->new();
	    $ms->start($start_coord);
	    $ms->end($end_coord);
	    $ms->id($subject);

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

sub target_graph { 
    my $self = shift;
    my $coverage = shift;

    my $matches = $self->matches();
    my @match_counts = $self->subjects_by_match_count($matches);
    #print Dumper(@match_counts);
    my @targets = ();

    my @target_keys = ();
    foreach my $k (1..$coverage) { 
	my $e = shift @match_counts;
	#print Dumper($e);
	push @target_keys, $e->[0]; 
    }

#    print STDERR "TARGET KEYS: ".join(",", @target_keys);
#    print STDERR "\n";

#    print STDERR "TARGETS: ". join ", ", @targets;
#    print STDERR "SIZE =" .scalar(@targets)."\n";

    my @target_tracks = ();
    
    foreach my $s (@target_keys) { 
	if (! defined($matches->{$s})) { next; }
	my @s_targets = ();
	foreach my $m (@{$matches->{$s}}) { 
	    
	    foreach my $n ($m->start() .. $m->end()) { 
		$s_targets[$n]++;
	    }   
	}
	push @target_tracks, [ @s_targets ];
	
    }
    
 #   print STDERR "TARGET TRACKS: ".Dumper(@target_tracks);

    # multiply the different track scores
    #
    if (@target_tracks == 1) { 
       	@targets =  @{$target_tracks[0]}; }
    else { 

	for (my $t=1; $t< @target_tracks; $t++) { 
	    for (my $i = 0; $i< length($self->query_seq()); $i++) { 
		if (!defined($target_tracks[$t-1]->[$i])) { $target_tracks[$t-1]->[$i] = 0; }
		if (!defined($target_tracks[$t]->[$i])) { $target_tracks[$t]->[$i] = 0; }
		
		$targets[$i]  = $target_tracks[$t]->[$i] * $target_tracks[$t-1]->[$i];
	    }
	}
    }

  #  print STDERR "\n\nNEW TARESTsn". join ",", @targets;

    return @targets;
}

sub off_target_graph { 
    my $self = shift;
    my $coverage = shift;

    my @off_targets = ();

    my $matches = $self->matches();
    my @match_counts = $self->subjects_by_match_count($matches);
    
    my @coverage_keys = ();
    foreach my $k (0..$coverage-1) { 
	shift @match_counts;
    }
    @coverage_keys = map { $_->[0] } @match_counts;
    
    foreach my $s (@coverage_keys) { 
	foreach my $m (@{$matches->{$s}}) { 
	    foreach my $n ($m->start() .. $m->end()) { 
		$off_targets[$n]++;
	    }
	}
    }
    return @off_targets;
}

sub longest_vigs_sequence { 
    my $self  =shift;
    my $coverage = shift;

    my @regions = ();
#    foreach my $coverage (1..8) { 
	
	my @targets = $self->target_graph($coverage);
	my @off_targets = $self->off_target_graph($coverage);

	my $start = undef;
	my $end = undef;
	my $score = 0;
	
	for (my $i=0; $i<@targets; $i++) { 
	    if (!defined($off_targets[$i]) || $off_targets[$i]==0) { 
		
		if (defined($start)) { 
		    #print STDERR "extending...\n";
		    $score =$targets[$i];
		}
		else { 
		    #print STDERR "creating...\n";
		    $start = $i;
		    $score =$targets[$i];
		}
	    }
	    elsif ($off_targets[$i]!=0 || $i == @targets) { 
		if (defined($start)) { 
		    #print STDERR "ending...\n";
		    $end = $i;
		    my $length = $end - $start;
		    
		    push @regions, [ $coverage, $score * $length, $score, $length, $start, $end ];
		}
		$score = 0;
		$start = undef;
		$end = undef;
	    }
	}
 #   }
    my @sorted = sort sort_keys @regions;

    my @ten_best = @sorted[0..9];

  #  print STDERR "TEN BEST: ".Dumper(\@ten_best);

    return @sorted;
}



sub sort_keys { 
    $b->[1] <=> $a->[1];
}

sub get_best_coverage { 
    my $self = shift;
    my @subjects = $self->subjects_by_match_count($self->matches);
    
    
    for (my $i=1; $i<@subjects; $i++) {
	if ($subjects[$i-1]->[1] * 0.5 > $subjects[$i]->[1]) { 
	    #print STDERR "COVERAGE: $i\n";
	    return $i;
	}
    }
    return undef;

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

sub hilite_regions { 
    my $self = shift;
    my $regions = shift;
    my ($r, $g, $b) = @_; #optional color

    $self->{regions} = $regions;
    $self->{region_hilite}->{r} = $r;
    $self->{region_hilite}->{g} = $g;
    $self->{region_hilite}->{b} = $b;
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
    my $grey = $image->colorResolve(150,150,150);
    my $yellow = $image->colorResolve(255, 255, 0);
    my $black  = $image->colorResolve(0, 0, 0);

    my $font = GD::Font->Small();
    $self->font($font);

    $image->filledRectangle(0, 0, $self->width, $self->height, $white);

    #my @suggested_sequences = $self->get_best_vigs_seqs($coverage);
   
    my $x_len = length($self->query_seq());

    my $x_scale = $self->width / $x_len;
    #warn "X-scale: $x_scale\n";
    my $glyph_height = 3;
    
    my @track_heights = ();
    my @track_names = ();
    # hightlight the regions
    #
    foreach my $r (@{$self->{regions}}) { 
	my ($start, $end) = ($r->[0], $r->[1]);
	print STDERR "LONGEST REGION: $start, $end\n";
	$image->filledRectangle($start * $x_scale, 0, $end * $x_scale, $self->height, $yellow);
    }
    
    my $matches = $self->matches();
    my $offset = $self->ruler_height + 10;
    my $track_height = 0;
    my @sorted = $self->subjects_by_match_count($self->matches);
    
    #print Dumper(\@sorted);

    $self->draw_ruler($image, $x_len, $x_scale);
    
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
	    $image->rectangle($i->start() *  $x_scale, $offset + $current_track * $glyph_height, $i->end() * $x_scale, $offset + ($current_track+1)*$glyph_height, $color);
	    
	}
	#print STDERR "Done with $sorted->[0] - drawing red line.. at ".($offset + $max_tracks * $glyph_height)."\n";

	$offset += 10;

	$image->line(0, $offset + ($max_tracks+1) * $glyph_height, $self->width, $offset + ($max_tracks+1) * $glyph_height, $grey);

	push @track_heights, $offset + ($max_tracks+1)  * $glyph_height;
	push @track_names, $sorted[$track]->[0];
	
	$offset += $max_tracks * $glyph_height + 10;	

    }

    # draw vertical grid of seq_window_size in size
    #
    for (my $x=0; $x < length($self->query_seq()); $x += $self->seq_window_size()) { 
	$image->line($x * $x_scale, 15, $x * $x_scale, $self->height, $grey);
    }
    
    # adjust image height
    #
    if ($offset > 2400) { $offset = 2400; }
    my $cropped = GD::Image->new($image->width, $offset);
    $cropped->copy($image, 0, 0, 0, 0, $image->width(), $offset);

    $image = $cropped;

    open(my $F, ">", $filename) || die "Can't open file $filename.";
    print $F $image->png();
    close($F);

    my $image_map = qq { <map name="blabla" > };
    my $previous_height =0;
    for (my $i=0; $i<@track_heights; $i++) { 
	my $coords = join ",", (0, $previous_height, $self->width(), $track_heights[$i]);
	$previous_height = $track_heights[$i];
	
	$image_map .= qq { <area shape="rect" coords="$coords" href="$track_names[$i]" alt="$track_names[$i]" />\n };
    }

    $image_map .= qq{ </map> };

    return $image_map;
}

sub draw_ruler { 
    my $self = shift;
    my $image = shift;

    my $seq_length = shift;
    my $scale = shift;
    
    my $black = $image->colorResolve(0, 0, 0);

    $image->line(0, $self->ruler_height, $seq_length * $scale, $self->ruler_height, $black);

    # tick lines
    #
    if ($seq_length > 1000) { 
	foreach my $tick (int($seq_length / 1000)) { 
	    $image->line($tick * 1000 * $scale, 1, $tick * 1000 * $scale, 5, $black);
	}

    }
    
    if ($seq_length > 100 && $seq_length < 3000) { 
	foreach my $tick (0 .. int($seq_length / 100)) { 
	    $image->line($tick * 100 * $scale, 0, $tick * 100 * $scale, 5, $black);
	}
    }
    
    if ($seq_length > 10 && $seq_length < 200) { 
	foreach my $tick (0.. int($seq_length / 10)) { 
	    $image->line($tick * 10 * $scale, 1, $tick * 10 * $scale+1, 5, $black);
	}
    }
    
    # tick labels
    #
    if ($seq_length < 4000) { 
	$self->write_ticks($image, $seq_length, $scale, 200);
    }

    if ($seq_length < 1400) { 
	
	foreach my $tick (0 .. int($seq_length /100) ) { 
	    $self->write_ticks($image, $seq_length, $scale, 100); #$image->string($self->font(), $tick * 100 * $scale+1, 1, $tick * 100, $black);
	}
    }

    if ($seq_length < 200) { 
	foreach my $tick (0.. int($seq_length/10) ) { 
	    $self->write_ticks($image, $seq_length, $scale, 10); #$image->string($self->font(), $tick*10*$scale, 2, $tick * 10, $black);
	}
    }
}
    

sub write_ticks { 
    my $self =shift;
    my $image = shift;
    my $seq_length = shift;
    my $scale = shift;
    my $nucleotide_interval = shift;

    my $black = $image->colorAllocate(0,0,0);
    foreach my $tick (1..int($seq_length/$nucleotide_interval)) { 
	$image->string($self->font(), $tick * $nucleotide_interval * $scale + 2, 4, $tick * $nucleotide_interval, $black);
    }
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
