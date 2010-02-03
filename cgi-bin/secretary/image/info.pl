#!/usr/bin/perl

use CXGN::Scrap;
use CXGN::Image::GDImage;
use GD::Image;

#defaults
my $DOC_ROOT="/data/local/website/sgn";
my $IMG_SRC = "/documents/img/external.png";

my $scrap = CXGN::Scrap->new();
my $im;

my ($source, $analyze) = $scrap->get_encoded_arguments('src', 'analyze');

my $test = "text/html"; ##properly prints stack trace if something is going wrong
my $header_type = "image/png";

if($source =~ /\.png/i) { 
	$im = GD::Image->newFromPng($DOC_ROOT . $source) or die;
}
elsif($source =~ /\.jpe?g/i) {
	#need to force palette, so pass 0 for [truecolor]
	$im = GD::Image->newFromJpeg($DOC_ROOT . $source, 0) or die;
	$header_type = "image/jpeg";
}
elsif($source =~ /\.gif/i) {
	$im = GD::Image->newFromGif($DOC_ROOT . $source) or die;
	$header_type = "image/gif";
}
else { die "Only supported image types: Gif, Jpeg, Png"; }

$scrap->{request}->send_http_header($test);

$source ||= $IMG_SRC;
unless (-f $DOC_ROOT . $source) { 
	print "Source file '$source' not found, using default '$IMG_SRC'<br>";
	$source = $IMG_SRC;
}

my $imgh = CXGN::Image::GDImage->new();
$imgh->{image} = $im;
if($analyze) { $imgh->_get_image_info() }

print "<IMG src='$source' width=200 height=200 \\>";
print "<br>";
my $max_index = $im->colorsTotal;
my $trans_index = $im->transparent;
my $i = 0;


my @rgb;
while($i < $max_index) {
	my ($r, $g, $b) = $im->rgb($i);
	my $string = "Red: $r  Green: $g  Blue: $b";
	if($analyze) { $string .= " &nbsp;&nbsp;Pixel Count: " . $imgh->{index}->{$i}->{count}}
	$rgb[$i] = $string;
	$i++;
}

my $j = 0;
while ($j < $max_index) {
	print "<br>Index: $j &nbsp;&nbsp; $rgb[$j]";
	if($j == $trans_index) { print " (transparent)"; }
	$j++;
}

#print $im->png;

# my $im = GD::Image->new(100, 100);
# 
# $white = $im->colorAllocate(255,255,255);
# $black = $im->colorAllocate(0,0,0);       
# $red = $im->colorAllocate(255,0,0);      
# $blue = $im->colorAllocate(0,0,255);
# 
# 
# $im->transparent($white);
# $im->rectangle(0, 0, 99, 99, $black);
# $im->arc(50, 50, 95, 75, 0, 360, $blue);
# $im->fill(50, 50, $red);
# 
# print $im->png;

