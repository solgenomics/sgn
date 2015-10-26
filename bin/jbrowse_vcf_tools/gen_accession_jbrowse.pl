#!/usr/bin/perl -w

=head1

gen_accession_jbrowse.pl - creates jbrowse instances that include base tracks and accession vcf tracks for each accession name supplied

=head1 SYNOPSIS

    gen_accession_jbrowse.pl -v [absolute path through base instance to dir containing vcfs] -d [name of database to search for trials] -h [db host]

=head1 COMMAND-LINE OPTIONS
 
 -v absolute path through base instance to dir containing vcfs
 -h database hostname
 -d database name

=head1 DESCRIPTION

Takes a directory containing individual vcf files, including filtered and imputed versions, and creates jbrowse instances by symlinking to all necessary files in a base instance,  then generating a uniq tracks.conf file and appending dataset info to jbrowse.conf. Should be run from /data/json/accessions dir in jbrowse instance.
=head1 AUTHOR

Bryan Ellerbrock (bje24@cornell.edu) - Oct 2015

=cut

use strict;
use File::Slurp;
use Getopt::Std;
use Bio::Chado::Schema;
use CXGN::DB::InsertDBH;

our ($opt_v, $opt_h, $opt_d);

#-----------------------------------------------------------------------
# define paths & array of vcf_file names. Open file handles to read accession lists and append datasets to jbrowse.conf 
#-----------------------------------------------------------------------

getopts('v:h:d:');

my $vcf_dir_path = $opt_v;
my $dbhost = $opt_h;
my $dbname = $opt_d;
my $link_path = $vcf_dir_path;
    $link_path =~ s:(.+)/.+/.+:$1:;
my $url_path = $vcf_dir_path;
$url_path =~ s:.+(/.+/.+/.+/.+/.+/.+/.+$):$1:;

my ($mod_file, $out, $header,$track_1,$track_2,$track_3,$filt_test,$imp_test,$h,$q,$dbh);
my @files = ` dir -GD -1 --hide *.tbi $vcf_dir_path ` ; 

open (CONF, ">>", "../../../jbrowse.conf") || die "Can't open conf file jbrowse.conf!\n";

#-----------------------------------------------------------------------                                                                                             
# connect to database and extract unique acccesion names                                                                                                            
#-----------------------------------------------------------------------                                                                                             

#my $schema= Bio::Chado::Schema->connect( sub { $dbh->get_actual_dbh() });

$dbh = CXGN::DB::InsertDBH->new( { dbhost=>$dbhost,
                                      dbname=>$dbname,
				   dbargs => {AutoCommit => 0,
					      RaiseError => 1}
				 }
    );

$q = "SELECT distinct(stock.uniquename) from stock where type_id = 76392 limit 1000";

$h=$dbh->prepare($q);

$h->execute();

#-----------------------------------------------------------------------
# for each accession name, locate matching indiv vcf files and construct necessary text for tracks.conf
#-----------------------------------------------------------------------

#print STDERR "fetchrow array = $h->fetchrow_array \n";

while (my @names = $h->fetchrow_array) {
    print STDERR "names = @names \n";
    my $name = $names[0];
    chomp ($name);
    print STDERR "name = $name \n";
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
	if ($_ eq $filt_test) {                            #Handle filtered vcf files
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
	} elsif ($_ eq $imp_test) {                        #Handle imputed vcf files
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

#-----------------------------------------------------------------------
# if matching vcf files not found, skip to next accession name
#-----------------------------------------------------------------------

next if !$track_2;    

#-----------------------------------------------------------------------
# create dir for new jbrowse instance; create symlinks to files in base jbrowse instance
#-----------------------------------------------------------------------

    `sudo rm -r $name; sudo mkdir $name`;
    `sudo ln -sf $link_path/data_files $name/data_files`;
    `sudo ln -sf $link_path/seq $name/seq`;
    `sudo ln -sf $link_path/tracks $name/tracks`;
    `sudo ln -sf $link_path/trackList.json $name/trackList.json`;
    `sudo ln -sf $link_path/readme $name/readme`;

#-----------------------------------------------------------------------
# append dataset info to jbrowse.conf, and create and populate accession specific tracks.conf file
#-----------------------------------------------------------------------

my $dataset = "[datasets.$name]\n" . "url  = ?data=data/json/accessions/$name\n" . "name = $name\n\n";
print CONF $dataset;
    open (OUT, ">", $out) || die "Can't open out file $out! \n";
    print OUT $header;
my $json = $track_2 . $track_3;
print OUT $json;   

}

