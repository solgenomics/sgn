#!/usr/bin/perl -w

=head1

gen_trial_jbrowse.pl - creates jbrowse instances that include base tracks and accession vcf tracks for each trial name supplied

=head1 SYNOPSIS

    gen_trial_jbrowse.pl -v [absolute path through base instance to dir containing vcfs] -d [name of database to search for trials] -h [db host]

=head1 COMMAND-LINE OPTIONS
 
 -v absolute path through base instance to dir containing vcfs
 -n list of trial names 

=head1 DESCRIPTION

Takes a directory containing individual vcf files, including filtered and imputed versions, and creates jbrowse instances by symlinking to all necessary files in a base instance,  then generating a uniq tracks.conf file and appending dataset info to jbrowse.conf. Should be run from /data/json/trials dir in jbrowse instance.
=head1 AUTHOR

Bryan Ellerbrock (bje24@cornell.edu) - Oct 2015

=cut

use strict;
use File::Slurp;
use Getopt::Std;
use Bio::Chado::Schema;
use CXGN::DB::InsertDBH;
use CXGN::Trial::TrialLayout;
use Data::Dumper;

our ($opt_v, $opt_h, $opt_d);

#-----------------------------------------------------------------------
# define paths & array of vcf_file names. Open file handles to read trial lists and append datasets to jbrowse.conf 
#-----------------------------------------------------------------------

getopts('v:h:d:');

my $vcf_dir_path = $opt_v;
my $dbhost = $opt_h;
my $dbname = $opt_d;
my $link_path = $vcf_dir_path;
    $link_path =~ s:(.+)/.+/.+:$1:;
my $url_path = $vcf_dir_path;
$url_path =~ s:.+(/.+/.+/.+/.+/.+/.+/.+$):$1:;
my $accessions_found;
my ($mod_file, $out, $header,$track_1,$track_2,$track_3, $filt_test, $imp_test,$h,$q,$dbh);
my @files = ` dir -GD -1 --hide *.tbi $vcf_dir_path ` ; 
my $trial_name;
my $trial_id;
my $accession_name;
my @accession_names;
my @conf_info;
#my $schema= "Bio::Chado::Schema";
my $schema= Bio::Chado::Schema->connect( sub { $dbh->get_actual_dbh() });

open (CONF, ">>", "../../../jbrowse.conf") || die "Can't open conf file jbrowse.conf!\n";

#-----------------------------------------------------------------------
# connect to database and extract trial names and ids
#-----------------------------------------------------------------------

# store database handle and schema

$dbh = CXGN::DB::InsertDBH->new( { dbhost=>$dbhost,
				      dbname=>$dbname,
				      dbargs => {AutoCommit => 0,
						 RaiseError => 1}
				    }
    );


# prepare and execute sql to extract trial names and ids

$q = "SELECT distinct(project.project_id), project.name FROM project LEFT JOIN projectprop AS year ON (project.project_id = year.project_id) LEFT JOIN projectprop AS location ON (project.project_id = location.project_id) LEFT JOIN project_relationship ON (project.project_id = project_relationship.subject_project_id) LEFT JOIN project as program ON (project_relationship.object_project_id=program.project_id) LEFT JOIN projectprop as project_type ON (project.project_id=project_type.project_id) LEFT JOIN cvterm AS type_cvterm ON (project_type.type_id = type_cvterm.cvterm_id) WHERE (year.type_id=76395 OR year.type_id IS NULL) and (location.type_id=76920 OR location.type_id IS NULL) and (project_type.type_id in (76919,76918) OR project_type.type_id IS NULL)  ORDER BY project.name";

$h=$dbh->prepare($q);

$h->execute();

#-----------------------------------------------------------------------
# for each trial name, prepare conf file output
#-----------------------------------------------------------------------

while ($trial_id, $trial_name= $h->fetchrow_array) {
   
    chomp $trial_name;
    print STDERR "trial name = $trial_name \n";
    chomp $trial_id;
    print STDERR "trial id = $trial_id \n";

    $out = "$trial_name/tracks.conf";
    $header = "[general]\ndataset_id = $trial_name\n";

#-----------------------------------------------------------------------
# extract list of accessions associated with trial from database
#-----------------------------------------------------------------------

my $trial_layout = CXGN::Trial::TrialLayout->new({schema => $schema, trial_id => $trial_id} );
my $accession_names_ref = $trial_layout->get_accession_names();
my $control_names_ref = $trial_layout->get_control_names();

    for my $accession (@$accession_names_ref) {
	print STDERR " Trial $trial_name contains accession $accession \n";
	push (@accession_names, $accession);
    }
    for my $control (@$control_names_ref) {
	print STDERR " Trial $trial_name contains control $control \n";
	push (@accession_names, $control);
    }

#-----------------------------------------------------------------------
# for each accession, locate matching indiv vcf files and construct necessary text for tracks.conf
#-----------------------------------------------------------------------

    for my $accession_name (@accession_names) {
	print "Working on trial $trial_name and accession $accession_name! \n";

    for my $file (@files) {
	chomp $file;
	$_ = $file;
	$_ =~ s/([^.]+)_2015_V6.*/$1/s;
	#print STDERR "processed filename = $_ \n";
        #next if !m/$accession_name/;
	$filt_test = $accession_name . "_filtered";
	$imp_test = $accession_name . "_imputed";
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
# if matching vcf files not found, skip to next trial name
#-----------------------------------------------------------------------

next if !$track_2;
$accessions_found++;    
my $track_info = $track_2 . $track_3;
push (@conf_info, $track_info);
print STDERR "Pushed accession $accession_name track info @conf_info, moving onto next accession. Current accessions found = $accessions_found\n";
}
#-----------------------------------------------------------------------
# create dir for new jbrowse instance; create symlinks to files in base jbrowse instance
#-----------------------------------------------------------------------
if ($accessions_found < 2) {
print STDERR "$accessions_found accessions in this trial have vcf files. Skipping it and moving onto next trial \n";
@conf_info='';
@accession_names='';
$accessions_found = 0;
next;
}
    `sudo rm -r $trial_name; sudo mkdir $trial_name`;
    `sudo ln -sf $link_path/data_files $trial_name/data_files`;
    `sudo ln -sf $link_path/seq $trial_name/seq`;
    `sudo ln -sf $link_path/tracks $trial_name/tracks`;
    `sudo ln -sf $link_path/trackList.json $trial_name/trackList.json`;
    `sudo ln -sf $link_path/readme $trial_name/readme`;

#-----------------------------------------------------------------------
# append dataset info to jbrowse.conf, and create and populate trial specific tracks.conf file
#-----------------------------------------------------------------------

my $dataset = "[datasets.$trial_name]\n" . "url  = ?data=data/json/trials/$trial_name\n" . "name = $trial_name\n\n";
print CONF $dataset;
    open (OUT, ">", $out) || die "Can't open out file $out! \n";
    print OUT $header;
print STDERR "Yes!! $accessions_found accessions in this trial have vcf files. Printing track info to tracks.conf and moving onto next trial \n";
for my $accession_tracks (@conf_info) {
print OUT $accession_tracks
}
@conf_info='';
@accession_names='';
$accessions_found = 0;
next;
}
