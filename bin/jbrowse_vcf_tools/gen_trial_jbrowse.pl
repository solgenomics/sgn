#!/usr/bin/perl -w

=head1

gen_trial_jbrowse.pl - creates jbrowse instances that include base tracks and accession vcf tracks for each trial name supplied

=head1 SYNOPSIS

    gen_trial_jbrowse.pl -v [absolute path through base instance to dir containing vcfs] -b [absolute path to base instance] -d [name of database to search for trials] -h [db host]

=head1 COMMAND-LINE OPTIONS
 
 -v absolute path through base instance to dir containing vcfs
 -b absolute path to base instance                                                        
 -h database hostname                                                                     
 -d database name   

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

our ($opt_v, $opt_b, $opt_h, $opt_d);

#-----------------------------------------------------------------------
# define paths & array of vcf_file names. Open file handles to read trial lists and append datasets to jbrowse.conf 
#-----------------------------------------------------------------------

getopts('v:b:h:d:');

my $vcf_dir_path = $opt_v;
my $dbhost = $opt_h;
my $dbname = $opt_d;
my $link_path = $opt_b;
my $url_path = $opt_v;
$url_path =~ s:$link_path/(.+):$1:;
print STDERR "url path = $url_path \n";

my $accessions_found = 0;
my ($file_type, $out, $header,@tracks,$imp_track,$filt_track,$h,$q,$dbh,%accession,%control);
my @files = ` dir -GD -1 --hide *.tbi $vcf_dir_path ` ; 
my $accession_name;
my @accession_names;
my @conf_info;
my $schema= Bio::Chado::Schema->connect( sub { $dbh->get_actual_dbh() });

open (CONF, ">>", "../../../jbrowse.conf") || die "Can't open conf file jbrowse.conf!\n";

open (LOG, ">>", "gen_trial.log") || die "Can't open log file!\n";

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

$q = "SELECT distinct(project.project_id), project.name FROM project LEFT JOIN projectprop AS year ON (project.project_id = year.project_id) LEFT JOIN projectprop AS location ON (project.project_id = location.project_id) LEFT JOIN project_relationship ON (project.project_id = project_relationship.subject_project_id) LEFT JOIN project as program ON (project_relationship.object_project_id=program.project_id) LEFT JOIN projectprop as project_type ON (project.project_id=project_type.project_id) LEFT JOIN cvterm AS type_cvterm ON (project_type.type_id = type_cvterm.cvterm_id) WHERE (year.type_id=76395 OR year.type_id IS NULL) and (location.type_id=76920 OR location.type_id IS NULL) and (project_type.type_id in (76919,76918) OR project_type.type_id IS NULL)";

$h=$dbh->prepare($q);

$h->execute();

#-----------------------------------------------------------------------
# for each trial name, prepare conf file output
#-----------------------------------------------------------------------

while (my ($trial_id, $trial_name) = $h->fetchrow_array) {
   
    chomp $trial_name;
    print STDERR "trial name = $trial_name \n";
    chomp $trial_id;
    print STDERR "trial id = $trial_id \n";

    $out = "$trial_id/tracks.conf";
    $header = "[general]\ndataset_id = Trial_$trial_id\n";

#-----------------------------------------------------------------------
# extract list of accessions associated with trial from database
#-----------------------------------------------------------------------

my $trial_layout = CXGN::Trial::TrialLayout->new({schema => $schema, trial_id => $trial_id, experiment_type=>'field_layout'} );
my $accession_names_ref = $trial_layout->get_accession_names();
my $control_names_ref = $trial_layout->get_control_names();

    for my $accession (@$accession_names_ref) {
#	print STDERR "Trial $trial_name contains accession";
	print Dumper($accession);
	my %accession_hash = %$accession;
	push (@accession_names, $accession_hash{'accession_name'});
    }
    for my $control (@$control_names_ref) {
#	print STDERR " Trial $trial_name contains control";
	print Dumper($control);
	my %control_hash = %$control;
	push (@accession_names, $control_hash{'accession_name'});
    }
    print STDERR " Trial $trial_name contains accessions @$accession_names_ref \n";
    print STDERR " Trial $trial_name contains controls @$control_names_ref \n";

#-----------------------------------------------------------------------
# for each accession, locate matching indiv vcf files and construct necessary text for tracks.conf
#-----------------------------------------------------------------------

    for my $accession_name (@accession_names) {
	print STDERR "Working on trial $trial_name and accession $accession_name! \n";
	print LOG "Working on trial $trial_name and accession $accession_name! \n";

    for my $file (@files) {
	chomp $file;
       	$_ = $file;
	next if !m/filtered/ && !m/imputed/;
        $_ =~ s/([^.]+)_2015_V6.*/$1/s;
        next if ($_ ne $accession_name);
        print STDERR "Matched vcf file basename $_ to accession name $accession_name !\n";
	print LOG "Matched vcf file basename $_ to accession name $accession_name !\n";
	$file_type = $file;
        $file_type =~ s/.+_([imputedflr]+).vcf.gz/$1/s;
        if ($file_type eq 'filtered') {                            #Handle filtered vcf files                                                                  
	    print STDERR "Working on filtered file $file \n" ;
	    my $path = $url_path . "/" . $file ;
	    my $key = $file;
            $key =~ s/(.+).vcf.gz/$1/s;

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
category = Diversity/NEXTGEN/Unimputed
type = JBrowse/View/Track/HTMLVariants
metadata.Description = Homozygous reference: Green	Heterozygous: Red		Homozygous alternate: Blue	Filtered to remove SNPs with a depth of 0 and SNPs with 2 or more alt alleles.
metadata.Link = <a href=ftp://cassavabase.org/jbrowse/diversity/igdBuildWithV6_\
hapmap_20150404_vcfs/' . $file . '>Download VCF File</a>                                
metadata.Provider = NEXTGEN Cassava project                                     
metadata.Accession = ' . $accession_name . '
label = ' . $key  . '
' ;
push @tracks, $filt_track;

	} elsif ($file_type eq 'imputed') {                        #Handle imputed vcf files
            print STDERR "Working on imputed file $file \n" ;
            my $path = $url_path . "/" . $file ;
            my $key = $file;
            $key =~ s/(.+).vcf.gz/$1/s;
	    
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
category = Diversity/NEXTGEN/Imputed
type = JBrowse/View/Track/HTMLVariants
metadata.Description = Homozygous reference: Green	Heterozygous: Red		Homozygous alternate: Blue	Values imputed with GLMNET are shown at 1/3 opacity.
metadata.Link = <a href=ftp://cassavabase.org/jbrowse/diversity/igdBuildWithV6_\
hapmap_20150404_vcfs/' . $file . '>Download VCF File</a>                                
metadata.Provider = NEXTGEN Cassava project                                     
metadata.Accession = ' . $accession_name .'
label = ' . $key  . '
' ;
push @tracks, $imp_track;

	} else {

	next;    

	}
}

#-----------------------------------------------------------------------
# if matching vcf files were not found, skip to next trial name
#-----------------------------------------------------------------------

next unless (@tracks);

#-----------------------------------------------------------------------
# otherwise increment count, save the new tracks, and move on to next accession
#----------------------------------------------------------------------- 

$accessions_found++;    
foreach my $value (@tracks) {
push (@conf_info, $value);
}
undef @tracks;
print STDERR "Saved accession $accession_name track info, moving onto next accession. Current accessions found = $accessions_found\n";
print LOG "Saved accession $accession_name track info, moving onto next accession. Current accessions found = $accessions_found\n";

}

#-----------------------------------------------------------------------
# once all accessions have been searched, check count and only proceed if we've found at least 2
#-----------------------------------------------------------------------
if ($accessions_found < 2) {
print STDERR "$accessions_found accessions in this trial have vcf files. Skipping it and moving onto next trial \n";
undef @conf_info;
undef @accession_names;
$accessions_found = 0;
next;
}

#-----------------------------------------------------------------------         
# if 2 or more have been found, set up jbrowse instance, unless it already exisits
#-----------------------------------------------------------------------   

print STDERR "Woo! $accessions_found accessions in this trial have vcf files. Setting up jbrowse instance, then moving onto next trial \n";
print LOG "Woo! $accessions_found accessions in this trial have vcf files. Setting up jbrowse instance, then moving onto next trial \n";


unless (-d $trial_id) {

    `sudo mkdir -p $trial_id`;
    `sudo ln -sf $link_path/data_files $trial_id/data_files`;
    `sudo ln -sf $link_path/seq $trial_id/seq`;
    `sudo ln -sf $link_path/tracks $trial_id/tracks`;
    `sudo ln -sf $link_path/trackList.json $trial_id/trackList.json`;
    `sudo ln -sf $link_path/readme $trial_id/readme`;
    `sudo touch $trial_id/tracks.conf && sudo chmod a+wrx $trial_id/tracks.conf`;

#-----------------------------------------------------------------------
# then append dataset info to jbrowse.conf, and create and populate trial specific tracks.conf file
#-----------------------------------------------------------------------

my $dataset = "[datasets.Trial_$trial_id]\n" . "url  = ?data=data/json/trials/$trial_id\n" . "name = $trial_name\n\n";
print CONF $dataset;
open (OUT, ">", $out) || die "Can't open out file $out! \n";
print OUT $header;
print OUT join ("\n", @conf_info), "\n";
undef @conf_info;                     # reset arrays to be used for next trial
undef @accession_names;
$accessions_found = 0;
next;
}

#-----------------------------------------------------------------------       
# if instance already exists, just append tracks to tracks.conf                      
#----------------------------------------------------------------------- 

open (OUT, ">>", $out) || die "Can't open out file $out! \n";
print OUT join ("\n", @conf_info), "\n";
undef @conf_info;                   # reset arrays to be used for next trial                                                                                        
undef @accession_names;
$accessions_found = 0;
next;
}
