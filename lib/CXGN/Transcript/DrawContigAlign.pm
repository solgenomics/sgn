=head1 NAME

CXGN::Transcript::DrawContigAlign - draws alignment graphs of unigenes.

=head1 SYNOPSIS

This should be instantiated (without arguments), have alignment data fed to it, and instructed where to put the image and imagemap.

 $imageProgam = CXGN::Transcript::DrawContigAlign->new();
 $imageProgram->addAlignment('SGN-E1199194', 'SGN-U508096', '+', 0, 477, 0, 0, 1);
 $imageProgram->addAlignment('SGN-E1189844', 'SGN-U508096', '+', 75, 760, 30, 0, 0);
 #add more alignments
 $imageProgram->writeImageToFile('Image.png', 'Mapfile', 'http://some.domain.name/some/url/thingie/', 'Image name');

=head1 DESCRIPTION

DrawContigAlign receives information about sequences stored in a unigene and produces a graph of the aligned sequences.

=head1 AUTHORS

Rafael Lizarralde <xarbiogeek@gmail.com> (July 2009)

Paraphrased from a C script (draw_contigalign.c) of unknown origin.

=head1 MEMBER FUNCTIONS

This class implements the following functions:

=head2 constructor C<new>

=over 10

=item Usage:

$imageProgram = CXGN::Transcript::DrawContigAlign->new();

=item Ret:

a CXGN::Transcript::DrawContigAlign object

=item Args:

none

=back

=cut

package CXGN::Transcript::DrawContigAlign;

use Moose;
use MooseX::Method::Signatures;

use GD;
use CXGN::Transcript::DrawContigAlign::Pane;
use CXGN::Transcript::DrawContigAlign::ContigAlign;
use CXGN::Transcript::DrawContigAlign::DepthData;

use constant Pane        => 'CXGN::Transcript::DrawContigAlign::Pane';
use constant ContigAlign => 'CXGN::Transcript::DrawContigAlign::ContigAlign';
use constant DepthData   => 'CXGN::Transcript::DrawContigAlign::DepthData';

#The list of sequences to be aligned
has contigAligns => (is => 'rw', isa => 'ArrayRef', default => sub { my @array = (); return \@array; });

=head2 mutator C<addAlignment>

=over 10

=item Usage:

$imageProgram->addAlignment('SGN-E1189844', 'SGN-U508096', '+', 75, 760, 30, 0, 0);

=item Desc:

adds alignment data to the list of data that will be incorporated in the graph

=item Ret:

nothing

=item Args:

=over 18

=item Str  $sourceID

the source ID tag of the segment in a Unigene

=item Str  $sequenceID

the sequence ID tag of the Unigene

=item Str  $strand

an identifier determining whether it is complementary or not (if not, it should be '+')

=item Int  $startLoc

the starting base pair of the segment

=item Int  $endLoc

the ending base pair of the segment

=item Int  $startTrim

the number of base pairs that have been trimmed (do not match) at the start

=item Int  $endTrim

the number of base pairs that have been trimmed (do not match) at the end

=item Bool $highlight

whether or not the segment should be highlighted

=back

=back

=cut

#Adds a sequence to the list of contiguous alignments
method addAlignment (Str $sourceID!, Str $sequenceID!, Str $strand!,
	             Int $startLoc!, Int $endLoc!, Int $startTrim!, Int $endTrim!, Bool $highlight?) {
    my @contigs = @{ $self->contigAligns };
    my $contig = ContigAlign->new($sourceID, $sequenceID, $strand,
				  $startLoc, $endLoc, $startTrim, $endTrim, $highlight);
    push @contigs, $contig;
    $self->contigAligns( [ @contigs ] );
}

=head2 accessor C<writeImageToFile>

=over 10

=item Usage:

$imageProgram->writeImageToFile('Image.png', 'Mapfile', 'http://some.domain.name/some/url/thingie/', 'Image name');

=item Desc:

produces an image file and map file with the alignment information

=item Ret:

nothing

=item Args:

=over 20

=item Str $imageFilename

the path of the image file

=item Str $mapFilename

the path of the map file

=item Str $linkBasename

the url stub for the EST pages

=item Str $imageName

the name for the image

=back

=back

=cut

#Constants
my ($HISTOGRAM, $ALIGN, $INFO, $LEGEND) = (0..3);
my ($BORDERWIDTH, $PAD, $HISTOGRAMWIDTH) = (5, 10, 350);
my $XTICS = 10;
my ($BLACK, $BLUE, $RED, $YELLOW, $LIGHTGRAY, $DARKGRAY, $FRONTSHADE, $BACKSHADE);

#Creates the image based on the currently-possessed data and stores it in an image and map file
method writeImageToFile (Str $imageFilename!, Str $mapFilename!, Str $linkBasename!, Str $imageName) {
    $self->contigAligns( [ sort { $a->compare($b) } @{ $self->contigAligns } ] );
    $imageName = '(Unspecified)' if(!defined($imageName));

    my @depths = @{ $self->computeDepths() };
    my $yMax = $self->computeYMax(\@depths);
    my $yScale = $self->computeYScale($yMax);
    my $xMax = $self->computeXMax(\@depths);
    my $xScale = $self->computeXScale($xMax);

    my $font = &gdSmallFont;
    my $textHeight = $font->height;
    #makes the font height odd so the center is an integer, to match up with lines
    $textHeight++ if($textHeight%2 == 0);

    my @panes = $self->computePanes($font, $textHeight, $yMax);

    #space needed for the histogram, plus labels (3), plus each segment, plus the border, plus padding for each pane
    my $imageHeight = $panes[$ALIGN]->south + $PAD + $BORDERWIDTH;
    #the rightmost edge of a right pane, plus the padding and the border
    my $imageWidth  = $panes[$INFO]->east + $PAD + $BORDERWIDTH;
    #the width and height, and a true value to use a 24-bit color scheme (RGB 0-255)
    my $image = GD::Image->new($imageWidth + 1,$imageHeight + 1);

    $self->setColors($image);
    $self->drawBorder($image, $imageWidth, $imageHeight);
    $self->drawGrayBars($image, \@panes, $textHeight);
    $self->drawHighlight($image, \@panes, $textHeight);
    $self->drawHistogram(\@depths, $image, $panes[$HISTOGRAM], $font, $textHeight, $xMax, $xScale, $yMax, $yScale);
    $self->drawAlignments($image, $panes[$ALIGN], $font, $textHeight, $xMax, $xScale);
    $self->drawInfo($image, $panes[$INFO], $font, $textHeight, $mapFilename, $imageName, $linkBasename);
    $self->drawLegend($image, $panes[$LEGEND], $font, $imageName, $depths[$#depths]->position);

    #prints the image
    my $IMAGEFILE;
    open $IMAGEFILE, ">" . $imageFilename;
    print $IMAGEFILE $image->png;
    close $IMAGEFILE;
}

#Calculates the total depth in each region of the sequence
method computeDepths {
    my @contigAligns = @{ $self->contigAligns };
    my %depthHash;

    #adds all the positions using a hash to eliminate duplicates
    for my $est (@contigAligns) {
	$depthHash{$est->start} = CXGN::Transcript::DrawContigAlign::DepthData->new($est->start);
	$depthHash{$est->end  } = CXGN::Transcript::DrawContigAlign::DepthData->new($est->end  );
    }
    my @depths = sort { $a->compare($b) } values %depthHash;
    
    #increments the depths of each position for each sequence that covers it
    for my $est (@contigAligns) {
	for my $depth (@depths) {
	    $depth->increment if($depth->position >= $est->start and $depth->position < $est->end);
	}
    }
    
    return \@depths;
}

#This probably needs to be rewritten to be more intelligent--60 is way bigger than most unigenes
method computeYMax (ArrayRef $depthList!) {
    my @depths = @{ $depthList };

    my $maxDepth = 0;
    for my $depth (@depths) { $maxDepth = $depth->depth if($depth->depth > $maxDepth); }
    
    return 60 if($maxDepth < 60);
    return $self->roundTo($maxDepth, 30);
}

#This probably needs to be rewritten to be more intelligent--60 is way bigger than most unigenes
method computeYScale (Int $maxDepth!) {
    return (($maxDepth <= 60) ? 15 : 20); 
}

#Calculates the total length of the aligned sequence, rounded up to the next 100
method computeXMax (ArrayRef $depthList!) {
    my @depths = @{ $depthList };
    my $xMax = $depths[$#depths]->position;
    return $self->roundTo($xMax, 100);
}

#Calculates the distance between tics on the x-axis
method computeXScale (Int $xMax!) {
    return $xMax / $XTICS;
}

#Computes the dimensions of the panes, which are arranged like this:
#     --------------------------------
#    |                     |          |
#    |      Histogram      | Legend   |
#    |                     |          |
#    |--------------------------------|
#    |                     |          |
#    |      Sequence       | Sequence |
#    |      Alignment      |   Info   |
#    |                     |          |
#     --------------------------------
method computePanes (Ref $font!, Int $textHeight!, Int $histogramHeight!) {
    my $sequences = @{ $self->contigAligns };

    #the 4*width accounts for the depth tic labels
    my $histogram = Pane->new($BORDERWIDTH+$PAD,
                              $BORDERWIDTH+(2 * $PAD)+$histogramHeight+(3 * $textHeight),
			      $BORDERWIDTH+$PAD, $BORDERWIDTH+$PAD+$HISTOGRAMWIDTH+(4 * $font->width)+$textHeight);

    my $alignment = Pane->new($histogram->south + $PAD,
                              $histogram->south + $PAD + ($sequences * $textHeight),
			      $histogram->west, $histogram->east);

    my $info      = Pane->new($alignment->north, $alignment->south,
			      $alignment->east, $alignment->east + (48 * $font->width));

    my $legend    = Pane->new($histogram->north, $histogram->south,
                                                                 $info->west, $info->east);

    return ($histogram, $alignment, $info, $legend);
}


#Initializes the colors that are used in the graph
method setColors (Ref $image!) {
    #sets the background to white
    my $bg = 255;
    $image->colorAllocate($bg, $bg, $bg);

    $BLACK      = $image->colorResolve(0, 0, 0);
    $BLUE       = $image->colorResolve(0, 0, 255);
    $RED        = $image->colorResolve(255, 0, 0);
    $YELLOW     = $image->colorResolve(255, 255, 100);
    $LIGHTGRAY  = $image->colorResolve(200, 200, 200);
    $FRONTSHADE = $image->colorResolve($bg - 50, $bg - 50, $bg - 50);
    $BACKSHADE  = $image->colorResolve($bg - 100, $bg - 100, $bg - 100);
}

#Draws the bevel border
method drawBorder (Ref $image!, Int $width!, Int $height!) {
    for my $i (0..($BORDERWIDTH-1)) {
	#draws a lighter border on the north and west sides
	$image->line($i, $i, $width - ($i + 1), $i, $FRONTSHADE);
	$image->line($i, $i, $i, $height - ($i + 1), $FRONTSHADE);

	#draws a darker border on the south and east sides
	$image->line($i, $height - $i, $width - $i, $height - $i, $BACKSHADE);
	$image->line($width - $i, $i, $width - $i, $height - $i, $BACKSHADE);
    }
}

#Draws the gray bars in the alignment pane as a visual aid
method drawGrayBars (Ref $image!, ArrayRef $paneList!, Int $textHeight!) {
    my @panes = @{ $paneList };
    my $sequences = @{ $self->contigAligns };

    if($sequences > 6) {
	for(my $i = 0; $i < $sequences; $i += 6) {
	    my $width = ( ($i < $sequences - 3) ? 3 : ($sequences - $i) );
	    $image->filledRectangle($panes[$ALIGN]->west, $panes[$ALIGN]->north + ($i * $textHeight),
				    $panes[$INFO]->east, $panes[$ALIGN]->north + (($i + $width) * $textHeight),
				    $LIGHTGRAY);
	}
    }
}

#Draws the highlight
method drawHighlight (Ref $image!, ArrayRef $paneList!, Int $textHeight!) {
    my @panes = @{ $paneList };
    my @contigAligns = @{ $self->contigAligns };
    
    for my $i (0..(@contigAligns - 1)) {
	if($contigAligns[$i]->highlight) {
	    $image->filledRectangle($panes[$ALIGN]->west, $panes[$ALIGN]->north + ($i * $textHeight),
				    $panes[$INFO]->east, $panes[$ALIGN]->north + (($i+1) * $textHeight), $YELLOW);
	}
    }
}

#Draws everything in the histogram pane of the image
method drawHistogram (ArrayRef $depthList!, Ref $image!, Object $pane!, Ref $font!,
		      Int $textHeight!, Int $xMax!, Int $xScale!, Int $yMax!, Int $yScale!) {
    my @depths = @{ $depthList };
    #defines the place where the histogram is drawn, instead of the axis labels and such
    my $grid = Pane->new($pane->north + (3 * $textHeight), $pane->south - $PAD,
		      $self->round($pane->west + ($font->height * 1.5) + ($font->width * 4)), $pane->east - $PAD);

    $self->prepareGraph($image, $font, $grid, $xMax, $xScale, $yMax, $yScale);
    my $unitsPerPixel = $xMax/($grid->east - $grid->west);

    my $darkGray = $image->colorResolve(128, 128, 128);
    for my $i (0..(@depths - 2)) {
	my $left = $grid->west + $self->round($depths[$i]->position/$unitsPerPixel);
        $left++ if $left == $grid->west;
	my $right = $grid->west + $self->round($depths[$i+1]->position/$unitsPerPixel);
	my $top = $grid->north + 1;
	my $bottom = $grid->north + $depths[$i]->depth + 1;
	$image->filledRectangle($left, $top, $right, $bottom, $darkGray);
    }
}

#Prepares the grid and axes for the histogram
method prepareGraph (Ref $image!, Ref $font!, Object $pane!,
                     Int $xMax!, Int $xScale!, Int $yMax!, Int $yScale!) {
    my ($x, $y, $label);

    #draws the surrounding rectangle
    $image->rectangle($pane->west, $pane->north, $pane->east, $pane->south, $BLACK);

    #draws the gridlines and tic marks
    my $unitsPerPixel = $xMax / ($pane->east - $pane->west);
    for my $i (0..$XTICS) {
	#draws vertical gridlines
	$x = $pane->west + $self->round(($i * $xScale)/$unitsPerPixel);
	if($i > 0 and $i < $XTICS) {
	    for($y = $pane->north; $y < $pane->south; $y += 3) {
		$image->setPixel($x, $y, $BLACK);
	    }
	}

	#draws horizontal tic marks
	$image->line($x, $pane->north, $x, $pane->north - 3, $BLACK);
	$image->line($x, $pane->south, $x, $pane->south + 1, $BLACK);

	#draws the corresponding x-axis label
	$label = $i * $xScale;
	$x -= (length($label) * $font->width) / 2;
	$y = $pane->north - 4 - $font->height;
	$image->string($font, $x, $y, $label, $BLACK);
    }

    #draws the x-axis description
    $label = 'position (bp)';
    $x = $pane->west + ($pane->east - $pane->west)/2 - (length($label) * $font->width)/2;
    $y = $pane->north - 5 - (2 * $font->height);
    $image->string($font, $x, $y, $label, $BLACK);

    for(my $i = 0; $i <= $yMax; $i += $yScale) {
	#draws horizontal gridlines
	$y = $i + $pane->north;
	if($i > 0 and $i < $yMax) {
	    for($x = $pane->west; $x < $pane->east; $x += 3) {
		$image->setPixel($x, $y, $BLACK);
	    }
	}
	
	#draws vertical tic marks
	$image->line($pane->west, $y, $pane->west - 3, $y, $BLACK);
	$image->line($pane->east, $y, $pane->east + 3, $y, $BLACK);

	#draws the corresponding y-axis label
	$label = $i;
	$x = $pane->west - (length($label) * $font->width) - 4;
	$y -= $font->height / 2;
	$image->string($font, $x, $y, $label, $BLACK);
    }

    #draws the y-axis description
    $label = "Depth";
    $x = $pane->west - (4 * $font->width) - $font->height - 1;
    $y -= $font->height / 2;
    $image->stringUp($font, $x, $y, $label, $BLACK);
}

#Draws the alignment of the sequences
method drawAlignments (Ref $image!, Object $pane!, Ref $font!,
                       Int $textHeight!,  Int $xMax!, Int $xScale!) {
    my @contigAligns = @{ $self->contigAligns };

    #computes the left and right bounds of the histogram above
    my $west = $pane->west + (1.5 * $font->height) + (4 * $font->width);
    my $east = $pane->east - $PAD;
    my $unitsPerPixel = $xMax / ($east - $west);
    my ($x, $y);

    #draws the dotted lines corresponding to histogram depth changes
    for my $i (0..$XTICS) {
	$x = $west + $self->round(($i * $xScale) / $unitsPerPixel);
	for($y = $pane->north; $y < $pane->south; $y += 3) {
	    $image->setPixel($x, $y, $BLACK);
	}
    }
    
    #draws the lines for each sequence
    for my $i (0..(@contigAligns - 1)) {
	$y = $pane->north + $self->round($textHeight * ($i + .5));
	
	my $contigAlign = $contigAligns[$i];
	
	#the beginning and end of the matching sequence, excluding trim
	my $startCover = $west + $self->round($contigAlign->start / $unitsPerPixel);
	my $endCover   = $west + $self->round($contigAlign->end   / $unitsPerPixel);
	my ($start, $end);

	#draws a black line if it's the same strand, or a blue one if it's the complementary strand
	$image->line($startCover, $y, $endCover, $y, (($contigAlign->strand eq '+') ? $BLACK : $BLUE));

	#draws a leading red segment if the sequence was trimmed
	if($contigAlign->startTrim > 0) {
	    if($contigAlign->startLoc < 0) {#This should never happen
		$self->drawDottedLine($image, $west - 18, $y, $RED);
		my $label = $contigAlign->startLoc . "bp";
		$x = $west - ((length($label) + 1) * &gdTinyFont->width);
		$image->string(&gdTinyFont, $x, $y - &gdTinyFont->height, $label, $RED);
		$start = $west;
	    } else {#This should always happen
		$start = $west + $self->round($contigAlign->startLoc / $unitsPerPixel);
	    }
	    $image->line($start, $y, $startCover - 1, $y, $RED);
	}
	
	if($contigAlign->endTrim > 0) {
	    if($contigAlign->endLoc > $xMax) {#This should never happen
		$self->drawDottedLine($image, $east, $y, $RED);
		my $label = ($contigAlign->endLoc - $xMax) . "bp";
		$x = $east + &gdTinyFont->width;
		$image->string(&gdTinyFont, $x, $y - &gdTinyFont->height, $label, $RED);
		$end = $east;
	    } else {#This should always happen
		$end = $west + $self->round($contigAlign->endLoc / $unitsPerPixel);
	    }
	    $image->line($endCover + 1, $y, $end, $y, $RED);
	}
    }
}

#This should never be called
method drawDottedLine(Ref $image!, Int $x!, Int $y!, Int $color!) {
    for(my $i = 0; $i < 18; $i += 6) {
	$image->line($x + $i, $y, $x + $i + 2, $y, $color);
    }
}

#Draws the info for each of the aligned sequences
method drawInfo (Ref $image!, Object $pane!, Ref $font!,
                 Int $textHeight!, Str $mapFilename!, Str $imageName!, Str $linkBasename!) {
    my @contigAligns = @{ $self->contigAligns };
    
    my $west = $pane->west + (2 * $font->width);

    my $MAPFILE;
    open $MAPFILE, ">" . $mapFilename;

    print $MAPFILE "<map name=\"contigmap_$imageName\">";

    #draws the info for each strand in the alignment
    for my $i (0..(@contigAligns - 1)) {
	my $y = $pane->north + ($i * $textHeight);
	my $contigAlign = $contigAligns[$i];

	my $total = $contigAlign->endLoc - $contigAlign->startLoc;
	my $used  = $total - ($contigAlign->startTrim + $contigAlign->endTrim);

	#sets the source ID to a 30-character string
	my $sourceID = $contigAlign->sourceID;
	$sourceID = substr($sourceID, 0, 26) . '... ' if(length($sourceID) > 29);
	$sourceID = sprintf("%-30.30s", $sourceID);

	#round down to avoid displaying 100% where there it's not a complete match
	my $percent = $self->round((($used * 100) / $total ) - .5);
	
	#set the base pair count to a 6-digit string (to even out 3-digit and 4-digit numbers)
	my $bpCount = sprintf('%-6.6s', $total . 'bp');

	my $label = "$sourceID $bpCount ($percent%)";

	$image->string($font, $west, $y, $label, (($contigAlign->strand eq '+') ? $BLACK : $BLUE));

#die $label . "\n" . $contigAlign->sequenceID . "\n" . $linkBasename;

	printf $MAPFILE "<area coords=\"%d,%d,%d,%d\" href=\"%s%s\">\n",
	($west, $y, $west + (length($label) * $font->width), $y + $font->height,
	 $linkBasename, $contigAlign->sequenceID);
    }

    print $MAPFILE "</map>\n";
    close $MAPFILE;
}

#Draws the legend for the graph
method drawLegend (Ref $image!, Object $pane!,
                   Ref $font!, Str $imageName!, Int $length!) {
    my $north = $pane->north + $PAD;
    my $west  = $pane->west + (5 * $PAD);
    my $line  = $font->height;
    my $label;

    $label = "Alignment Image: $imageName";
    $image->string($font, $west, $north, $label, $BLACK);

    my @labels = ("Alignment Image: $imageName", "Given Strand",
		  "Reverse Complement Strand", "Trimmed (non-matching) Sequence");
    my @colors = ($BLACK, $BLACK, $BLUE, $RED);

    for my $i (0..($#labels)) {
	$image->string($font, $west + 20, $north + (($i + 1.5) * $line), $labels[$i], $colors[$i]);
	$image->line($west, $north + (($i + 2) * $line), $west + 15, $north + (($i + 2) * $line), $colors[$i]);
    }

    $label = "Highlighted Strand";
    $image->filledRectangle($west, $north + ((@labels + 1.5) * $line),
			    $pane->east, $north + ((@labels + 2.5) * $line),
			    $YELLOW);
    $image->string($font, $west + 20, $north + ((@labels + 1.5) * $line), $label, $BLACK);

    $label = "Total Length: $length base pairs";
    $image->string($font, $west + 20, $north + (7 * $line), $label, $BLACK);
}

#returns the number rounded to the nearest integer
method round (Num $num!) {
    $num += .5;
    $num =~ s/(\d*)\.\d*/$1/;
    return $num;
}

#returns the number rounded up to the next multiple of block
method roundTo (Int $num!, Int $block!) { return $num + $block - ($num % $block); }
                                                                                                                ###########
no Moose;                                                                                                       #  Here   #
__PACKAGE__->meta->make_immutable;                                                                              #   be    #
return 1;                                                                                                       # dragons #
                                                                                                                ###########
=head1 SEE ALSO

CXGN::Transcript::Unigene calls this module.

This has been written with Moose, a postmodern object-orientation system for Perl, and uses the Moose extension MooseX::Method::Signatures.

=cut
