#!/usr/bin/perl -w

=head1

gen_accession_jbrowse.pl - creates jbrowse instances that include base tracks and accession vcf tracks for each accession name supplied

=head1 SYNOPSIS

    gen_accession_jbrowse.pl -v [absolute path through base instance to dir containing vcfs] -b [absolute path to base instance] -u [path from base jbrowse dir to dir containing vcfs] -d [name of database to search for trials] -h [db host]

=head1 COMMAND-LINE OPTIONS
 
 -v absolute path through base instance to dir containing vcfs
 -b absolute path to base instance
 -u path from base jbrowse dir to dir containing vcfs
 -h database hostname
 -d database name

=head1 DESCRIPTION

Takes a directory containing individual vcf files, including filtered and imputed versions, and creates or updates jbrowse instances by symlinking to all necessary files in a base instance,  then generating a uniq tracks.conf file and appending dataset info to jbrowse.conf. Should be run from /data/json/accessions dir in jbrowse instance.
=head1 AUTHOR

Bryan Ellerbrock (bje24@cornell.edu) - Oct 2015

=cut

use strict;
use File::Slurp;
use Getopt::Std;
use Bio::Chado::Schema;
use CXGN::DB::InsertDBH;

our ($opt_v, $opt_b, $opt_u, $opt_h, $opt_d);

#-----------------------------------------------------------------------
# define paths & array of vcf_file names. Open file handles to read accession lists and append datasets to jbrowse.conf 
#-----------------------------------------------------------------------

getopts('v:b:u:h:d:');

my $vcf_dir_path = $opt_v;
my $dbhost = $opt_h;
my $dbname = $opt_d;
my $link_path = $opt_b;
my $url_path = $opt_u;

my ($file_type,$out,$header,@tracks,$imp_track,$filt_track,$h,$q,$dbh);
my @files = ` dir -GD -1 --hide *.tbi $vcf_dir_path ` ; 

open (CONF, ">>", "../../../jbrowse.conf") || die "Can't open conf file jbrowse.conf!\n";

open (LOG, ">>", "gen_accession.log") || die "Can't open log file!\n";

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


$q = "SELECT distinct(stock.stock_id), stock.uniquename from stock where type_id = 76392 order by stock.uniquename";

$h=$dbh->prepare($q);

$h->execute();

#-----------------------------------------------------------------------
# for each accession name, locate matching indiv vcf files and construct necessary text for tracks.conf
#-----------------------------------------------------------------------

#print STDERR "fetchrow array = $h->fetchrow_array \n";

while (my ($id, $name) = $h->fetchrow_array) {
    chomp $id;
    chomp $name;
    print LOG "id = $id and name = $name \n";
    $out = "$id/tracks.conf";
    $header = "[general]\ndataset_id = Accession_$id\n";

    for my $file (@files) {
	chomp $file;
	$_ = $file;
        next if !m/filtered/ && !m/imputed/;
	$_ =~ s/([^.]+)_2015_V6.*/$1/s;
        next if ($_ ne $name);
	print STDERR "Matched vcf file basename $_ to accession name $name !\n";
	print LOG "Matched vcf file basename $_ to accession name $name !\n";
	$file_type = $file;
	$file_type =~ s/.+_([imputedflr]+).vcf.gz/$1/s;
	print LOG "filetype = $file_type \n";
	if ($file_type eq 'filtered') {                            #Handle filtered vcf files
	    print LOG "Working on filtered file $file \n" ;
	    print STDERR "Working on filtered file $file \n" ;
	    my $path = $url_path . "/" . $file ; 
	    my $key = $file;
	    $key =~ s/(.+).vcf.gz/$1/s;
      	    print LOG "Key = $key \n";
	    
	    $filt_track = '
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
push @tracks, $filt_track;

	} elsif ($file_type eq 'imputed') {                        #Handle imputed vcf files

	    print STDERR "Working on imputed file $file \n" ;
            print LOG "Working on imputed file $file \n" ;
	    my $path = $url_path . "/" . $file ; 
	    my $key = $file;
            $key =~ s/(.+).vcf.gz/$1/s;
      	    print LOG "Key = $key \n";
	    
	    $imp_track = '
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
push @tracks, $imp_track

	} else {

	next;    

	}
}

#-----------------------------------------------------------------------
# if matching vcf files were not found, skip to next accession name
#-----------------------------------------------------------------------

next unless (@tracks);    

#-----------------------------------------------------------------------
# unless it already exisits, create dir for new jbrowse instance and create symlinks to files in base jbrowse instance
#-----------------------------------------------------------------------

unless (-d $id) {
    `sudo mkdir -p $id`;
    `sudo ln -sf $link_path/data_files $id/data_files`;
    `sudo ln -sf $link_path/seq $id/seq`;
    `sudo ln -sf $link_path/tracks $id/tracks`;
    `sudo ln -sf $link_path/trackList.json $id/trackList.json`;
    `sudo ln -sf $link_path/readme $id/readme`;
    `sudo touch $id/tracks.conf && sudo chmod a+wrx $id/tracks.conf`;

#-----------------------------------------------------------------------
# also append dataset info to jbrowse.conf, and create and populate accession specific tracks.conf file
#-----------------------------------------------------------------------

my $dataset = "[datasets.Accession_$id]\n" . "url  = ?data=data/json/accessions/$id\n" . "name = $name\n\n";
print CONF $dataset;
open (OUT, ">", $out) || die "Can't open out file $out! \n";
print OUT $header;
print OUT join ("\n", @tracks), "\n";   
undef @tracks;
}

#-----------------------------------------------------------------------                                                                                            
# if we are just adding a new track, append to tracks.conf
#-----------------------------------------------------------------------   

open (OUT, ">>", $out) || die "Can't open out file $out! \n";
print OUT join ("\n", @tracks), "\n";
undef @tracks;
}

