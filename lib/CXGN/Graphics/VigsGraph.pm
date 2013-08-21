
package CXGN::Graphics::VigsGraph;

use Moose;
use GD::Image;
use Data::Dumper;

has 'bwafile' => ( is=>'rw' );
has 'fragment_size' => (is => 'rw', isa=>'Int', default=>21);
has 'matches' => (is=>'rw', isa=>'Ref');
has 'seq_window_size' => (is=>'rw', isa=>'Int', default=>100);
has 'seq_fragment' => (is=>'rw', isa=>'Int', default=>300);
has 'query_seq' => (is=>'rw', isa=>'Str');
has 'step_size' => (is=>'rw', isa=>'Int', default=>4);
has 'width' => (is=>'rw', isa=>'Int', default=>700);
has 'height'=> (is=>'rw', isa=>'Int', default=>3600);
has 'font' => (is =>'rw', isa=>'GD::Font');
has 'ruler_height' => (is => 'ro', isa=>'Int', default=>20);
has 'expr_hash' => (is => 'rw', default=>undef);
has 'link_url' => (is => 'rw', isa=>'Str');

sub parse { 
    my $self = shift;
    my $mm = shift || 0;
    # warn("Parsing file ".$self->bwafile()."\n");

    open(my $bt2_fh, "<", $self->bwafile()) || die "Can't open file ".$self->bwafile();

    my $matches = {};
    
    # parse Bowtie2 file
    while (my $line = <$bt2_fh>) { 
	my ($seq_id, $code, $subject, $scoord) = (split /\t/, $line);
	
	# get perfect matches 
	if ($line =~ /XM:i:(\d+)/) { 
	    my $mm_found = $1;

	    if ($mm_found <= $mm) {
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
	# print  $s."\n";
	foreach my $m (@{$matches->{$s}}) { 
	    # print STDERR "checking coords $m->[0], $m->[1] (start, end = $start, $end)\n";
	    if ( ($m->start() > $start) && ( $m->start() < $end) || ($m->end() > $start ) && ($m->end() < $end)) { 
		# print STDERR "Match found for sequence $s: $m->[0], $m->[1] ($start, $end)\n";
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
    # print Dumper(@match_counts);
    my @target_scores;

    # array with target subject names, coverage is the number of target subjects
    my @target_keys = ();
    foreach my $k (1..$coverage) { 
	my $e = shift @match_counts;
	push @target_keys, $e->[0]; 
    }

#    print STDERR "TARGET KEYS: ".join(",", @target_keys);
#    print STDERR "\n";
   
    # foreach match (blue squares in the graph), saves in $s_targets the coverage in each position
    foreach my $s (@target_keys) { 
	if (! defined($matches->{$s})) { 
	    next; 
	}
	my %s_targets = ();
	foreach my $m (@{$matches->{$s}}) { 
	    # print STDERR "m: ".$m->start()."\n";
	    foreach my $n ($m->start()-1 .. $m->end()) { 
		$s_targets{$n} = 1;
                # print STDERR "m: ".$m->start()." - ". $m->end()." $n\n";
	    }   
	}

	# when the position is not mapped over the targets we get 0, 
        # if it is mapped we get the number of targets where mapped in that position
	foreach my $pos (sort keys %s_targets) {
	    $target_scores[$pos]++;
	}
	%s_targets = ();	
    }

    return @target_scores;
}

sub off_target_graph { 
    my $self = shift;
    my $coverage = shift;

    my @off_targets = ();

    my $matches = $self->matches();
    my @match_counts = $self->subjects_by_match_count($matches);
    my %off_t_counts;

    my @coverage_keys = ();
    foreach my $k (0..$coverage-1) { 
	shift @match_counts;
    }
    @coverage_keys = map { $_->[0] } @match_counts;
    
    foreach my $s (@coverage_keys) { 
	foreach my $m (@{$matches->{$s}}) {
	    foreach my $n ($m->start()-1 .. $m->end()) {
		$off_t_counts{$n} = 1;
	    }
	}
	
	foreach my $pos (sort keys %off_t_counts) {
	    $off_targets[$pos]++;
	}
	%off_t_counts = ();
    }

    return @off_targets;
}

sub longest_vigs_sequence { 
    my $self = shift;
    my $coverage = shift;

    my @best_region;    
    my @targets = $self->target_graph($coverage);
    my @off_targets = $self->off_target_graph($coverage);
    my $seq_fragment = $self->seq_fragment();
    my $start = undef;
    my $end = undef;
    my $score = 0;
    my @window_sum = [];
    my $window_score = 0;
    my $best_score = -9999;
    my $best_start = 1;
    my $best_end = 1;

    # @targets contains the coverage of target at every position. Same thing for off_targets
    # $window sum[position] contain the score for each position. 
    # It will be positive when there are more targets than off_targets, and negative in the opposite case.
    for (my $i=0; $i<@targets; $i++) {
        
	$window_sum[$i] = 0;
	if (defined($targets[$i]) && $targets[$i]>0) {
	    $window_sum[$i] += $targets[$i];
	}
	else {
	    $window_sum[$i] += 0;
	    $targets[$i] = 0;
	}

	if (defined($off_targets[$i]) && $off_targets[$i]>0) {
	    $window_sum[$i] -= $off_targets[$i];
	}
	else {
	    $window_sum[$i] += 0;
	    $off_targets[$i] = 0;
	}

#	print "$i: $window_sum[$i]\tt:$targets[$i]\tot:$off_targets[$i]\n";

	if ($i+1 >= $seq_fragment) {
	    $window_score = 0;
	    for (my $e=($i-$seq_fragment+1); $e<=$i; $e++) {
#		print "$e\t";
		if ($window_sum[$e] && $window_sum[$e] =~ /^[\d+-\.]+$/) { 
		    $window_score += $window_sum[$e];
		}
	    }
#	    print "\ntest: ".($i+1-$seq_fragment)."-".($i).": $window_score\n";

	    if ($window_score > $best_score) {
		$best_score = $window_score;
		$best_start = $i-$seq_fragment+1;
		$best_end = $i;
	    }
#	    print "best: $best_start-$best_end: $best_score\n";
	    $window_score = 0;
	}
    }

    @best_region = ($coverage, $best_score, \@window_sum, $seq_fragment, $best_start, $best_end);
    return @best_region;
}



sub sort_keys { 
    $b->[1] <=> $a->[1];
}

sub get_best_coverage { 
    my $self = shift;
    my @subjects = $self->subjects_by_match_count($self->matches);
    
    # print Dumper(\@subjects);
    
    # detect a high gap in the number of reads mapped between subjects
    for (my $i=1; $i<@subjects; $i++) {
	if ($subjects[$i-1]->[1] * 0.5 > $subjects[$i]->[1]) { 
	    # print STDERR "COVERAGE: $i\n";
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
    # print Dumper(\@counts);
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
    my $expr_hash = shift;

    my $image = GD::Image->new($self->width, $self->height);
    my $white = $image->colorAllocate(255,255,255);
    my $red   = $image->colorResolve(180, 0, 0);
    my $red2  = $image->colorResolve(255, 0, 0);
    my $color = $image->colorResolve(0, 0, 0);    
    my $color2;
    my $blue  = $image->colorResolve(0, 0, 180);
    my $blue2 = $image->colorResolve(0, 100, 255);
    my $grey  = $image->colorResolve(200,200,200);
    my $yellow = $image->colorResolve(255, 255, 0);
    my $black  = $image->colorResolve(0, 0, 0);
    
    my $font = GD::Font->Small();
    $self->font($font);
    $image->filledRectangle(0, 0, $self->width, $self->height, $white);
   
    my $x_len = length($self->query_seq());

    my $x_scale = $self->width / $x_len;
    #warn "X-scale: $x_scale\n";
    my $glyph_height = 3;
    
    my @track_heights = ();
    my @track_names = ();

    my $matches = $self->matches();
    my $offset = $self->ruler_height + 10;
    my $track_height = 0;
    my @sorted = $self->subjects_by_match_count($self->matches);

    # print Dumper(\@sorted);

    # hightlight the best region
    my $r = $self->{regions};

    my ($start, $end) = ($$r[0], $$r[1]);
#   print STDERR "\nLONGEST REGION: $start, $end\n";
    $image->filledRectangle($start * $x_scale, 0, $end * $x_scale, $self->height, $yellow);

    $self->draw_ruler($image, $x_len, $x_scale);
    
    
    # save offset for names
    my @offset_val;

    # draw squares
    for (my $track=0; $track< @sorted; $track++) {
	my $max_tracks =0;
	my $current_track = 0;

	if ($track < $coverage) {
	    $color = $blue;
	    $color2 = $blue2;
	}
	else { 
	    $color = $red;
	    $color2 = $red2;
	}

	my @tracks = ();
	# print STDERR "Processing $sorted->[0]\n";
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
	    }

	    $image->rectangle($i->start() *  $x_scale, (15+$offset + $current_track*$glyph_height), $i->end() * $x_scale, (15+$offset + ($current_track+1)*$glyph_height), $color);
	    $image->fill(($i->start() *  $x_scale)+1, (15+$offset + $current_track * $glyph_height)+1, $color2);
      	    $image->fill(($i->end() * $x_scale)-1, (15+$offset + ($current_track+1)*$glyph_height)-1, $color2);
	}
	#print STDERR "Done with $sorted->[0] - drawing red line.. at ".($offset + $max_tracks * $glyph_height)."\n";

	$offset += 20;
	# horizontal lines
	$image->line(0, $offset + ($max_tracks+1) * $glyph_height, $self->width, $offset + ($max_tracks+1) * $glyph_height, $grey);
	
	push @track_heights, $offset + ($max_tracks+1) * $glyph_height;
	push @track_names, $sorted[$track]->[0];
	push(@offset_val, $offset);
	$offset += $max_tracks * $glyph_height + 10;
    }

    # draw vertical grid of seq_window_size in size
    for (my $x=0; $x < length($self->query_seq()); $x += $self->seq_window_size()) { 
        $image->line($x * $x_scale, 15, $x * $x_scale, $self->height, $grey);
    }

    # print subject names
    for (my $track=0; $track< @sorted; $track++) {

	my $subject_msg = "$sorted[$track]->[0]";
	if (defined($$expr_hash{"header"})) {
	    for (my $i=0; $i<length($$expr_hash{"header"}); $i++) {
		if (defined($$expr_hash{$track_names[$track]}[$i])) {
		    $$expr_hash{"header"}[$i+1] =~ s/\s+/_/g;
		    my $col_value = $$expr_hash{$track_names[$track]}[$i];
		    if (($col_value =~ /^\d+\.(\d+)$/) && (length($1) > 5)) {
			$col_value = sprintf("%.6f",$col_value);
		    }
		    $subject_msg = "$subject_msg    $$expr_hash{'header'}[$i+1]: $col_value";
		}
	    }
	}
	$image->string(GD::Font->MediumBold(), 5, ($offset_val[$track] - 25), $subject_msg, $black);
    }

    # adjust image height
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
	
	if ($coords && $track_names[$i]) {
	    $image_map .= qq { <area shape="rect" coords="$coords" alt="$track_names[$i]" />\n };
	}
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
    if ($seq_length > 4000) {	   
        $self->write_ticks($image, $seq_length, $scale, 500);
    }
    elsif ($seq_length < 200) { 
        $self->write_ticks($image, $seq_length, $scale, 10);
    }
    elsif ($seq_length < 1400) { 
        $self->write_ticks($image, $seq_length, $scale, 100);
    }
    else {
        $self->write_ticks($image, $seq_length, $scale, 200);
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
