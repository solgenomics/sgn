#!/usr/bin/perl -w

use strict;

# removes all iotw images >= a certain age

# set how long to keep old images
my $days		= 32;
my $limit		= $days * 24 * 60 * 60;

# directory to search
my $dir			= "/soldb/website/sgn/html/img/feature/iotw"; 

# get list of all iotw images
opendir(DIR, $dir);
my @files = grep(/\.jpg$/, readdir(DIR));
closedir(DIR);

foreach my $file (@files) {
	my $filetime = (stat($dir."/".$file))[9];
	my $expiry   = $filetime+$limit;
	if ($expiry<time) {
		print "$file is old, and will be deleted.\n";
		unlink "$dir/$file";		
	}
}
