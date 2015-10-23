#!/usr/bin/perl -w

=head1

gen_trial_jbrowse.pl - creates jbrowse instances that include base tracks and accession vcf tracks for each trial name supplied

=head1 SYNOPSIS

    gen_trial_jbrowse.pl -v [absolute path through base instance to dir containing vcfs] -n [list of trial names]

=head1 COMMAND-LINE OPTIONS
 
 -v absolute path through base instance to dir containing vcfs
 -n list of trial names 

=head1 DESCRIPTION

Takes a directory containing individual vcf files, including filtered and imputed versions, and creates jbrowse instances by symlinking to all necessary files in a base instance,  then generating a uniq tracks.conf file and appending dataset info to jbrowse.conf. Should be run from /data/json/trials dir in jbrowse instance

=head1 AUTHOR

Bryan Ellerbrock (bje24@cornell.edu) - Oct 2015

=cut

use strict;
use File::Slurp;
use Getopt::Std;

our ($opt_v, $opt_n);

getopts('v:n:');

my $vcf_dir_path = $opt_v;
my $link_path = $vcf_dir_path;
    $link_path =~ s:(.+)/.+/.+:$1:;
my $url_path = $vcf_dir_path;
$url_path =~ s:.+(/.+/.+/.+/.+/.+/.+/.+$):$1:;
my $names = $opt_n;
my ($mod_file, $out, $header,$track_1,$track_2,$track_3, $filt_test, $imp_test);
my @files = ` dir -GD -1 --hide *.tbi $vcf_dir_path ` ; 

open (CONF, ">>", "../../../jbrowse.conf") || die "Can't open conf file jbrowse.conf!\n";
open (NAMES, "<", $names) || die "Can't open names file $names! \n";

while (<NAMES>) {
    chomp (my $name = $_);
    $out = "$name/tracks.conf";
    $header = "[general]\ndataset_id = $name\n";

    for my $file (@files) {
	chomp $file;
	$_ = $file;
	$_ =~ s/([^.]+)_2015_V6.*/$1/s;
	#print STDERR "processed filename = $_ \n";
        #next if !m/$name/;
	$filt_test = $name . "_filtered";
	$imp_test = $name . "_imputed";
	if ($_ eq $filt_test) {
	    print STDERR "File = $file \n" ;
	    my $path = $url_path . "/" . $file ; 
	    $mod_file = $file;
	    $mod_file =~ s/([^.]+)_.+_.+_.+.*/$1/s;
	    my $key = $mod_file . "_2015_filtered_SNPs" ; 
	    #print STDERR "Key = $key \n";
	    
	    $track_2 = '
[ tracks . ' . $key . ' ]
    hooks.modify = function( track, feature, div ) { div.style.backgroundColor = track.config.variantIsHeterozygous(feature);}
variantIsHeterozygous = function( feature ) {
    var genotypes = feature.get(\'genotypes\');
    for( var sampleName in genotypes ) {
        try {
            var gtString = genotypes[sampleName].GT.values[0];
            if( ! /^1([\|\/]1)*$/.test( gtString) && ! /^0([\|\/]0)*$/.test( gtString ) )
                return \'red\';
        } catch(e) {} 
    }
    if( /^1([\|\/]1)*$/.test( gtString) )
                return \'blue\';
  }
key = ' . $key  .'
storeClass = JBrowse/Store/SeqFeature/VCFTabix
urlTemplate = ' . $path .'
category = VCF
type = JBrowse/View/Track/HTMLVariants
metadata.Description = Homozygous reference: Green	Heterozygous: Red		Homozygous alternate: Blue	Filtered to remove SNPs with a depth of 0 and SNPs with 2 or more alt alleles.
label = ' . $key  . '
' ;
	} elsif ($_ eq $imp_test) {
	    print STDERR "File = $file \n" ;
	    my $path = $url_path . "/" . $file ; 
	    $mod_file = $file;
            $mod_file =~ s/([^.]+)_.+_.+_.+.*/$1/s;
	    my $key = $mod_file . "_2015_imputed_SNPs" ; 
	    #print STDERR "Key = $key \n";
	    
	    $track_3 = '
[ tracks . ' . $key . ' ]
hooks.modify = function( track, feature, div ) { div.style.backgroundColor = track.config.variantIsHeterozygous(feature);  div.style.opacity = track.config.variantIsImputed(feature) ? \'0.33\' : \'1.0\'; }
variantIsHeterozygous = function( feature ) {
    var genotypes = feature.get(\'genotypes\');
    for( var sampleName in genotypes ) {
        try {
            var gtString = genotypes[sampleName].GT.values[0];
            if( ! /^1([\|\/]1)*$/.test( gtString) && ! /^0([\|\/]0)*$/.test( gtString ) )
                return \'red\';
        } catch(e) {} 
    }
        if( /^1([\|\/]1)*$/.test( gtString) )
                return \'blue\';
  }
variantIsImputed = function( feature ) {
    var genotypes = feature.get(\'genotypes\');
    for( var sampleName in genotypes ) {
        try {
            var dpString = genotypes[sampleName].DP.values[0];
            if( /^0$/.test( dpString) )
                return true;
        } catch(e) {}
    }
    return false;
  }
key = ' . $key  .'
storeClass = JBrowse/Store/SeqFeature/VCFTabix
urlTemplate = ' . $path .'
category = VCF
type = JBrowse/View/Track/HTMLVariants
metadata.Description = Homozygous reference: Green	Heterozygous: Red		Homozygous alternate: Blue	Values imputed with GLMNET are shown at 1/3 opacity.
label = ' . $key  . '
' ;
	} else {
	next;    
	}
}

next if !$track_2;
    `sudo rm -r $name; sudo mkdir $name`;
    `sudo ln -sf $link_path/data_files $name/data_files`;
    `sudo ln -sf $link_path/seq $name/seq`;
    `sudo ln -sf $link_path/tracks $name/tracks`;
    `sudo ln -sf $link_path/trackList.json $name/trackList.json`;
    `sudo ln -sf $link_path/readme $name/readme`;
my $dataset = "[datasets.$name]\n" . "url  = ?data=data/json/trials/$name\n" . "name = $name\n\n";
print CONF $dataset;
    open (OUT, ">", $out) || die "Can't open out file $out! \n";
    print OUT $header;
my $json = $track_2 . $track_3;
print OUT $json;   

}

