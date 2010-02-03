#!/usr/bin/perl


=head1 NAME

transform.pl

=cut

=head1 SYNOPSIS

Transform any site image on the fly using many of the techniques in CXGN::Image::GDImage.  Returns a binary image file with the proper headers set.

=cut

=head1 USAGE

In the page script, use this image tag, for example:
<IMG SRC='secretary/image/transform.pl?source=/documents/img/pepper.jpg&transform= greyscale,adjust_brightness:20, adjust_contrast:20|128'>

'transform' parameter takes comma-separated commands, each being a subroutine in CXGN::Image::GDImage.  If the subroutine takes parameters, use a colon to identify the first parameter, and separate parameters with a pipe.

=cut

use CXGN::Scrap;
use GD::Image;
use CXGN::Image::GDImage;

#defaults
my $DOC_ROOT="/data/local/website/sgn";
my $IMG_SRC = "/documents/img/pepper.png";

my $scrap = CXGN::Scrap->new();

my ($source, $transform) = $scrap->get_encoded_arguments('src', 'op');
$source ||= $IMG_SRC;
unless (-f $DOC_ROOT . $source) { 
	#die "Source file '$source' not found, using default '$IMG_SRC'<br>";
	$source = $IMG_SRC;
}

my $header_type = "image/png";
my $imgh = CXGN::Image::GDImage->new();
if($source =~ /\.png/i) { 
	$imgh->{image} = GD::Image->newFromPng($DOC_ROOT . $source) or die;
}
elsif($source =~ /\.jpe?g/i) {
	#need to force palette, so pass 0 for [truecolor]
	$imgh->{image} = GD::Image->newFromJpeg($DOC_ROOT . $source, 0) or die;
	$header_type = "image/jpeg";
}
elsif($source =~ /\.gif/i) {
	$imgh->{image} = GD::Image->newFromGif($DOC_ROOT . $source) or die;
	$header_type = "image/gif";
}
else { die "Only supported image types: Gif, Jpeg, Png"; }

my $test = "text/html"; ## properly prints stack trace if something is going wrong

$scrap->{request}->send_http_header($header_type);

$transform =~ s/\s+//g;  #spaces should have no effect on transform command string
my @routines = split /,/, $transform;

#if(!@routines) { push(@routines, "adjust_brightness:60") }

foreach my $routine (@routines){
	if($routine eq "greyscale"){
		$imgh->greyscale();
	}
	elsif($routine =~ /^adjust_brightness/) {
		my ($delta) = $routine =~ /:(-?\d+)/;
		$delta = int($delta);
		$imgh->adjust_brightness($delta);
	}
	elsif($routine =~ /^adjust_contrast/) {
		my ($delta) = $routine =~ /:(-?\d+)/;
		$delta = int($delta);
		my ($midpoint) = $routine =~ /\|(\d+)/;
		$midpoint ||= 127;
		$imgh->adjust_contrast($delta, $midpoint);
	}
	elsif($routine =~ /^invert/) {
		my ($midpoint) = $routine =~ /:([\d\.]+)/;
		$midpoint ||= 127.5;
		$imgh->invert($midpoint);
	}
	elsif($routine =~ /^adjust_hue:/) {
		my ($dr, $dg, $db) = map{ int($_) } $routine =~ /:(-?[\d\.]+)\|(-?[\d\.]+)\|(-?[\d\.]+)/;
		$imgh->adjust_hue($dr, $dg, $db);
	}
	elsif($routine =~ /^adjust_hue_absolute/) {
		my ($r, $g, $b) = map{ int($_) } $routine =~ /:(\d+)\|(\d+)\|(\d+)/;
		$imgh->adjust_hue_absolute($r, $g, $b);
	}
	elsif($routine =~ /^make_color_transparent/) {
		#don't use this method on large images!  Has to do pixel-by pixel index-test operations.	
		my ($r, $g, $b) = map{ int($_) } $routine =~ /:(\d+)\|(\d+)\|(\d+)/;
		my ($tolerance) = map{ int($_) } $routine =~ /:\d+\|\d+\|\d+\|(\d+)$/;
		$tolerance ||= 0;
		$imgh->make_color_transparent($r, $g, $b, $tolerance);
	}
	elsif($routine =~ /^color_balance/) {
		my ($partial) = map { int($_) } $routine =~ /:(\d+)/;
		$partial ||= 100;
		$imgh->color_balance($partial);
	}
	elsif($routine =~ /^auto_level_color/){
		my ($color) = $routine =~ /:(\w+)/;
		$imgh->auto_level_color($color);
	}
	elsif($routine =~ /^auto_levels/) {
		$imgh->auto_levels();
	}
}

print $imgh->{image}->png;

