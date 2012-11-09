#!/usr/bin/perl

# basic script to load pcr marker information

# usage: load_marker_data <dbhost> <dbname> <COMMIT|ROLLBACK> <map_id> <map file>
# example: load_marker_data.pl db-devel sandbox COMMIT 9 marker-file.csv

# copy and edit this file as necessary
# common changes include the following:
# experiment_type_id
# accession_id
# different column headings

use strict;

use CXGN::Tools::File::Spreadsheet;
use CXGN::Tools::Text;
use CXGN::Marker::Modifiable;
use CXGN::Marker::Tools;
use CXGN::Marker::Location;
use CXGN::Marker::PCR::Experiment;
use CXGN::Map::Version;
use CXGN::DB::Connection;
use CXGN::DB::InsertDBH;
use Data::Dumper;
#CXGN::DB::Connection->verbose(0);

my ($map_id, $map_file);

unless ($ARGV[0]) { 
    print "Usage: load_marker_data <dbhost> <dbname> "
	. "<COMMIT|ROLLBACK> <map_id> <marker file>\n" and exit();
}
unless ($ARGV[0] eq 'db-devel' or $ARGV[0] eq 'db') {
    die "First argument must be valid database host";
}
unless ($ARGV[1] eq 'sandbox' or $ARGV[1] eq 'cxgn') { 
    die "Second argument must be valid database name";
}
unless ($ARGV[2] eq 'COMMIT' or $ARGV[2] eq 'ROLLBACK') { 
    die "Third argument must be either COMMIT or ROLLBACK";
}
unless ($map_id=$ARGV[3]) { 
    die "Fourth argument must be the map_id"; 
}
unless ($map_file=$ARGV[4]) { 
    die "Fifth argument must be the marker file"; 
}

my $dbh=CXGN::DB::InsertDBH::connect
    ({dbhost=>$ARGV[0],dbname=>$ARGV[1],dbschema=>'sgn'});

eval {
    
    # parameters for this specific instance
    my $experiment_type_id = 1; # 'mapping'

#    my $accession_id = '88x87'; # parent1 x parent2

    # make an object to give us the values from the spreadsheet
    my $ss = CXGN::Tools::File::Spreadsheet->new($map_file);
    my @markers = $ss->row_labels(); # row labels are the marker names
    my @columns = $ss->column_labels(); # column labels are the headings for the data columns

    # make sure the spreadsheet is how we expect it to be
    @columns = qw | marker protocol temp fwd rev pd | 
	or die"Column headings are not as expected";
    
    for my $marker_name (@markers) {
	
	print "marker: $marker_name\n";
	
        my @marker_ids =  CXGN::Marker::Tools::marker_name_to_ids($dbh,$marker_name);
        if (@marker_ids>1) { die "Too many IDs found for marker '$marker_name'" }
	# just get the first ID in the list (if the list is longer than 1, we've already died)
        my $marker_id = @marker_ids[0];        

	if(!$marker_id) {
	    $marker_id = CXGN::Marker::Tools::insert_marker($dbh,$marker_name);
	    print "marker added: $marker_id\n";
	}
	else {  print "marker_id found: $marker_id\n" }

        # clean this up?
	my $annealing_temp = 
	    ((grep {/temp/} @columns) && ($ss->value_at($marker_name,'temp'))) 
	    ? $ss->value_at($marker_name,'temp') : 55;
	print "temp: $annealing_temp\n";

	my $fwd = $ss->value_at($marker_name,'fwd') 
	    or die "No foward primer found for $marker_name";
	print "fwd: $fwd\n";
	
	my $primer_id_fwd = CXGN::Marker::Tools::get_sequence_id($dbh,$fwd);   

	print "primer_id_fwd: $primer_id_fwd\n";

	my $rev=$ss->value_at($marker_name,'rev') 
	    or die"No reverse primer found for $marker_name";
	print "rev: $rev\n";
	my $primer_id_rev = CXGN::Marker::Tools::get_sequence_id($dbh,$rev);
	print "primer_id_rev: $primer_id_rev\n";
	
	my $protocol =  $ss->value_at($marker_name,'protocol');
	my ($pd, $primer_id_pd);
	if (($protocol eq 'dCAPS') && ($pd = $ss->value_at($marker_name,'pd'))) {
	    print "pd: $pd\n";
	    $primer_id_pd = CXGN::Marker::Tools::get_sequence_id($dbh,$pd);
	    print "primer_id_pd: $primer_id_pd\n";
	}

	# check if data already in pcr_experiment and marker_experiment, and if not, add it
	# there's a lot of stuff to check here.. I know these aren't in the database so will come back later

	my $names = ["marker_id", "annealing_temp", "primer_id_fwd", 
		     "primer_id_rev", "experiment_type_id", "map_id","primer_id_pd","accession_id"];
	my @fields = ($marker_id,$annealing_temp,$primer_id_fwd,
		      $primer_id_rev,$experiment_type_id,$map_id,$primer_id_pd,$accession_id);


        # does this check if pcr_experiment already exists?
	my $pcr_experiment_id = CXGN::Marker::Tools::insert($dbh,"pcr_experiment","pcr_experiment_id",$names,@fields);
	print "pcr experiment added: $pcr_experiment_id\n";

        # check for existing marker_experiment and update if found
	my $q = "SELECT marker_experiment_id FROM marker_experiment "
	    . "JOIN marker_location USING (location_id) JOIN map_version "
	    . "USING (map_version_id) WHERE rflp_experiment_id is null "
	    . "AND map_id = ? AND marker_id = ? AND protocol = ?";

	my $sth = $dbh->prepare($q);
	$sth->execute($map_id,$marker_id,$protocol);
	my @exp_id;
	while (my $id = $sth->fetchrow_array()) { push (@exp_id,$id) }

	if (@exp_id) {
	    if (@exp_id > 1) { print join(', ', @exp_id) and exit() }
            # this really should not be the case
            # update
            my $marker_experiment_id = $exp_id[0];            

	    my $u = "UPDATE marker_experiment set pcr_experiment_id = ? where marker_experiment_id = ?";
	    $sth = $dbh->prepare($u);
	    $sth->execute($pcr_experiment_id,$marker_experiment_id);

	    print "UPDATE $marker_experiment_id\n";
	}

        # if not loading map and experiments together, may want to match other protocols

        # if not, insert new marker_experiment
	else {
	    my $names = ["marker_id", "pcr_experiment_id", "protocol"];
	    my @fields = ($marker_id, $pcr_experiment_id, $protocol);
	    # 'SSR' or 'unknown'?
	    
	    my $marker_experiment_id = CXGN::Marker::Tools::insert
		($dbh,"marker_experiment","marker_experiment_id",$names,@fields);
#	    print "marker experiment added: $marker_experiment_id\n";
            print "ADD $marker_experiment_id\n";
	}

    }
};

if ($@) {
    print $@;
    print "Failed; rolling back.\n";
    $dbh->rollback();
}
else { 
    print"Succeeded.\n";
    if ($ARGV[2] eq 'COMMIT') {
        print"Committing.\n";
        $dbh->commit();
    }
    else {
        print"Rolling back.\n";
        $dbh->rollback();
    }
}
