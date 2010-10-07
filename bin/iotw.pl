#!/usr/bin/perl -w
# This script will parse the text files in this directory to determinr/set
# the new image of the week.
# * It will create/update the simlink img/feature to the current image
# * It will put the description for the image into img/feature/desc.txt
# It should be run weekly from cron
#

use strict;
use SGN::Context;
use Image::Size;

my $c = SGN::Context->new;

BEGIN {
	$ENV{'PROJECT_NAME'} = "SGN";
}

# debug status (greater for modified operation, more verbose output)
my $debug = 0;

# file setup
my $cfg = $c->config;
my $webpath = $cfg->{'static_datasets_url'}."/images/iotw/";
my $fullpath = $cfg->{'static_datasets_path'}."/images/iotw/";
my $file = $fullpath . "iotw.txt";
my $temp = "$file.tmp";
my $bak = "$file.orig";

$debug and die "The index file $file will be updated.\n";

# get today's date
my $year = (localtime)[5]+1900;
my $month = sprintf("%02d", (localtime)[4]+1 % 100);
my $day = sprintf("%02d", (localtime)[3]+1 % 100);
my $now = "$year$month$day";

# read file of images
my $image = ""; # set image line to NULL for now...
my $previous = ""; # placeholder for the previous line in a file
open(IMAGES, "< $file") or die "Can't open $file file: $!\n";
open(TEMP, "> $temp") or die "Can't open $temp file: $!\n";

# parse bookkeeping line
my $tracking = <IMAGES>;
my ($curr, $date) = split(/::/, $tracking);
chomp ($curr, $date);

$curr++; # increment the index of the picture to display
print "Image index updated to $curr, date updated from $date to $now\n";
print TEMP "${curr}::${now}\n";
while (<IMAGES>) { # go through the file
	if ($_) { # to make sure we don't get a blank line
		$previous = $_;
	}
	if ($. == $curr) { # while we're doing this, set the image
		$image = $_;
	}
	print TEMP $_;
}

# close files
close(TEMP) or die "Can't close $temp file: $!\n";
close(IMAGES) or die "Can't close $file file: $!\n";

rename($file, $bak) or die "Can't rename $file to $bak: $!\n";
rename($temp, $file) or die "Can't rename $temp to $file: $!\n";

# chmod the file so new images can be added without an error
my $chmod = `chmod 777 $file`;
if (!$chmod) {
	print $chmod;
}

# we've run out of images, just use the last one in the file for now
if (!$image) {
	print "We've run out of images (Week #", $curr-1, ")- using the most recent one available...\n";
	$image = $previous;
}

my $text;
($image, $text) = split(/::/,  $image);
chop($text = $text);

my $desired_x = 200;
my ($size_x, $size_y) = imgsize($fullpath.$image);
my $scaled_y = sprintf( '%0.0f', $size_y * $desired_x / $size_x );
my $outdesc = $fullpath . "desc.txt";
open DESC, ">$outdesc" or die "Couldn't open $outdesc: $!\n";
print DESC <<"EOF";
<img width="$desired_x" height="$scaled_y" hspace="0" vspace="0" border="0" src="$webpath$image" alt="IOTW, week $curr">
<br />
$text

EOF
close(DESC);
