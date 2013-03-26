#!/usr/bin/perl

# basic script to load maps


# copy and edit this file as necessary
# common changes include the following:
# specified linkage groups
# different column headings
# "pos" field versus separate "chromosome" and "position" fields

=head1 NAME

load_map_data.pl - a script to load maps into the SGN database.

=head1 DESCRIPTION

usage: load_map_data -H dbhost -D dbname [-r] [-n "map name"] [-i map_id] <map file>

example: load_map_data.pl -H devel -D sandbox -r -i 9 map-file.csv

Options:

=over 5

=item -H

The hostname of the server hosting the database.

=item -D

the name of the database

=item -r

(optional) if present, rollback after the script terminates. Database should not be affected. Good for test runs.

=item -i

(optional) the map_id. If not present, will insert a brand new map (confirm dialog).

=item -v 

add data to map version provided. Conflicts with -i and -n.

=item -n

required if -i is not used. Provides the map name.

=item -l

specify name of linkage groups as a comma separated list:
1,2,3,4,5,6,7,8,9,10,11,12
default is names from one to twelve. 

=item -f

force to 'unknown' protocol type if no protocol is provided.

=back

The tab-delimited map file has the following columns:

 MARKER
 CONFIDENCE
 LINKAGE_GROUP
 POSITION (must be a float! 0.0 )
 PROTOCOL


=head1 AUTHORS

John Binns, Adri Mills, Lukas Mueller, Naama Menda (among others).

Current maintainer: Lukas Mueller/Naama Menda.

=cut

use strict;

use Getopt::Std;
use CXGN::Tools::List qw | str_in |;
use CXGN::Tools::File::Spreadsheet;
use CXGN::Tools::Text;
use CXGN::Marker::Modifiable;
use CXGN::Marker::Tools;
use CXGN::Marker::Location;
use CXGN::Map::Version;
use CXGN::DB::Connection;
use CXGN::DB::InsertDBH;
use Data::Dumper;


our ($opt_H, $opt_D, $opt_i, $opt_r, $opt_n, $opt_f, $opt_v, $opt_l);

getopts('H:D:i:rn:fv:l:');

my $map_id;
my $map_file;
# specify linkage groups
# example: my $linkage_groups = ['1','2','3','4','5'];

my $linkage_groups;
if ($opt_l) { 
    $linkage_groups = [ split /\s*\,\s*/, $opt_l ];
}
else {
    $linkage_groups = [ qw | 1 2 3 4 5 6 7 8 9 10 11 12 | ];
}

$map_id = $opt_i;
my $map_version_id = $opt_v;
$map_file = shift;

if (!$opt_H && !$opt_D) {
    die "-H and -D parameters are required.\n";
}
 my $dbh = CXGN::DB::InsertDBH->new({
                                             dbname => $opt_D,
                                             dbhost => $opt_H,
                                             dbargs => {AutoCommit => 0,
                                                        RaiseError => 1}
                                            });

eval {
    if (!$map_id && !$map_version_id) {
	print "No map_id was provided. Insert a new map? ";
	my $key = <STDIN>;
	if ($key =~ /Y/i) {
	    print "Inserting a new map...\n";

	    my $map = CXGN::Map->new_map($dbh, $opt_n);

	    $map_id = $map->get_map_id();

	    print "New map_id: $map_id\n";

	}
	else {
	    exit();
	}
    }

    # we are creating a new map version every time we run this script, 
    # as long as the transaction goes through
    my $new_map_version;

    if ($map_id) { 
	$new_map_version = CXGN::Map::Version->
	    #new($dbh,{map_id=>$map_id});
	    new($dbh,{map_id=>$map_id},$linkage_groups);
	# saving the new map version
	$map_version_id = $new_map_version->insert_into_database();
	print "map version = " . $new_map_version->as_string() . "\n";
	# make an object to give us the values from the spreadsheet
    }
    elsif ($map_version_id) { 
	$new_map_version = CXGN::Map::Version->
	    new($dbh, {map_version_id=>$map_version_id});
    }
    my $ss = CXGN::Tools::File::Spreadsheet->new($map_file);
    my @markers = $ss->row_labels(); # row labels are the marker names
    my @columns = $ss->column_labels(); # column labels are the headings for the data columns
    # make sure the spreadsheet is how we expect it to be
    @columns = qw | MARKER MARKER_ID LINKAGE_GROUP POSITION CONFIDENCE PROTOCOL | # modify columns as necessary
	or die"Column headings are not as expected";

    # for all the (uncleaned) marker names in the spreadsheet
    #
    for my $dirty_marker_name(@markers) {

	# clean it, meaning, get the subscript if it's there,
	# and convert the name into a canonical form so we can find it
	# if it already exists with a different spelling or something
	#
        my ($marker_name,$subscript) = ($dirty_marker_name, "");
	    #CXGN::Marker::Tools::clean_marker_name($dirty_marker_name);

	# get as many IDs as you can for a marker with a name like this
	#
        my @marker_ids =  CXGN::Marker::Tools::marker_name_to_ids($dbh,$marker_name);
	# if we get more than one, our script needs to be made smarter
	# so it can differentiate between them, or maybe one of them
	# needs to be deleted from the database
	#
        if (@marker_ids>1) { die "Too many IDs found for marker '$marker_name'" }
	# just get the first ID in the list (if the list is longer than 1, 
	# we've already died)
	#
        my ($marker_id) = @marker_ids;
        my $marker;

        if($marker_id) {   
            # if we have found an existing marker
	    # make a modifiable marker object from it
	    #
            print "Found existing marker: $marker_id, $marker_name\n";
            $marker = CXGN::Marker::Modifiable->new($dbh,$marker_id);
        }
        else { 
            # if we are making a new marker
	    # make a modifiable marker object and start to populate it
	    #
	    print "Loading new marker id from marker $marker_name\n";
            $marker = CXGN::Marker::Modifiable->new($dbh);
            $marker->set_marker_name($marker_name); #give it a name


	    # marker must exist before locations can be added for it. 
	    # this is a db constraint. if you didn't do this, this script 
	    # would die later.
	    #
            my $inserts = $marker->store_new_data();

	    # if any data was inserted for this marker (presumably it was, 
	    # because we're making a new one)
	    #
            if ($inserts and @{$inserts}) { print"New marker inserted: $marker_name\n" }
            else { die "Oops, I thought I was inserting some new data" }
            $marker_id=$marker->marker_id();
	 
        }
	
        print $marker->get_name()."\n";

        my $loc=$marker->new_location(); #create a new location object
        
	# some files have pos which contains chromsome and position 
	#my $pos=$ss->value_at($dirty_marker_name,'Position') 
	    # get position from spreadsheet
	    #or die "No position found for $marker_name";
	# extract linkage group name and cm position from string like '01.035'
	#my ($chromosome,$position) = 
	    #CXGN::Marker::Tools::lg_name_and_position($pos);

#	foreach my $me (@{$marker->current_mapping_experiments}) { 
#	    print $me->{protocol}."\n";
#	}

	my $chromosome=$ss->value_at($dirty_marker_name,'LINKAGE_GROUP');	    # get chromosome from spreadsheet
	if (!defined($chromosome)) {  die"No chromosome found for $marker_name"; }

	if (! str_in($chromosome, @$linkage_groups)) { 
	    print STDERR "$marker_name skipped because linkage_group is $chromosome...\n";
	    next;
	}
	
	# some have separate fields for chromsome and position
	#
	my $position = $ss->value_at($dirty_marker_name,'POSITION');
	    # get position from spreadsheet
	     if (!defined($position)) { 
		 print STDERR "No position found for $marker_name\n";
		 next;
	 }

	my $confidence;
	
	# get confidence from spreadsheet
	#
        $confidence = $ss->value_at($dirty_marker_name,'CONFIDENCE') or $confidence='uncalculated';
	if ($confidence=~/^(\d+)$/) { 
	    if ($confidence == 0) { $confidence = "I"; }
	    elsif ($confidence == 1) { $confidence = "I(LOD2)"; }
	    elsif ($confidence == 2) { $confidence = "CF(LOD3)"; }
	    elsif ($confidence == 3) { $confidence = "F(LOD3)"; }
	    else { $confidence = "uncalculated"; }
	}
	# get protocol from spreadsheet
	#
        my $protocols_string=uc($ss->value_at($dirty_marker_name,'PROTOCOL'));
	
	# some entries have been mapped to the same location by more than 
	# one method separated in the spreadsheet by plus signs 
	#
        my @protocols=split(/\+/,$protocols_string);
        if (@protocols) {
            print "Protocols found: ".CXGN::Tools::Text::list_to_string(@protocols)."\n";
        }
        else { 
	    if ($opt_f) { 
		print STDERR "Protocols not found for '$dirty_marker_name'";
		@protocols = ('unknown' x scalar(@protocols));
	    }
	    else { 
		die "no protocol found for $dirty_marker_name. Use -f to force protocol to unknown.";
	    }
	}
        for my $protocol(@protocols) {
	    $protocol = uc($protocol); 
            unless ($protocol eq 'AFLP' or $protocol eq 'CAPS' or $protocol eq 'RAPD' 
		    or $protocol eq 'SNP' or $protocol eq 'SSR' 
		    or $protocol eq 'RFLP' or $protocol eq 'PCR' or $protocol eq 'DCAPS' or $protocol =~/DArt/i or $protocol =~ /OPA/i or $protocol =~ /INDEL/i or $protocol =~ /ASPE/i or  $protocol =~ /qtl/i )
	    {
                print STDERR "UNKNOWN protocol ($protocol)\n! ";
                $protocol = 'unknown';
            }

            if ($protocol eq 'DCAPS') { $protocol = 'dCAPS' }
            print "Protocol = $protocol\n";
	 
	    # set the marker_id that will be at this location
	    #
            $loc->marker_id($marker_id); 
	    
	    # set the map_version_id this location is found on
	    # (this must be done before calling function lg_name)
	    #
	    $loc->map_version_id($map_version_id);
	    
	    # set the linkage group name for this marker location 
	    # (the map_version_id must be already set for this to work, 
	    # else how would it be able to know different linkage groups on 
	    # different map versions from each other, when they all have the same names?)
	    #
            $loc->lg_name($chromosome);

	    #set the position of the marker on this linkage group
	    #
            $loc->position($position);

	    # set the confidence with which this marker is mapped at this position
	    #
            $loc->confidence($confidence);

	    # set the subscript for this location, because the same marker 
	    # can be mapped to multiple locations, and these locations must be distinguishable
	    #
            $loc->subscript($subscript);
	    
            # this method call represents the insertion into the
	    # marker_experiment table. this is currently a troublesome 
	    # issue because this marker was probably mapped here via a
	    # PCR or RFLP experiment. where is this experiment data? 
	    # well, it's in another spreadsheet, to be loaded later, 
	    # or maybe it has already been loaded. if it was previously 
	    # loaded, it was matched up with an old map version. how can we
            # match that existing PCR/RFLP data up with this new map 
	    # version? well, it will have to be done later by some other script.
	    #
            print "Adding new experiment , marker_name = $marker_name, location = " . $loc->position . " protocol = '". $protocol . "'\n";
	    $marker->add_experiment({location=>$loc,protocol=>$protocol});
        }

	# store whatever new data you have (in this case, the new data
	# is the location we just assigned the marker)	
	#
	print "Storing new marker data...\n";
        my $inserts = $marker->store_new_data();


	# if any data was inserted for this marker (presumably it was,
	# since we're adding locations on a brand new map version)
	#
        if ($inserts and @{$inserts}) { 
	    print "New marker data inserted:\n";#.Dumper($inserts);
	    print $loc->as_string();
	}

        else { die "Oops, I thought I was inserting some new data" }
    }
    
    # deprecate the old map version and make the new one we just made the current one 
    #
    $new_map_version->set_current();
    
};


if ($@) {
    print $@;
    print "Failed; rolling back.\n";
    $dbh->rollback();
}
else { 
    print"Succeeded.\n";
    if (!$opt_r) {
        print"Committing.\n";
        $dbh->commit();
    }
    else {
        print"Rolling back.\n";
        $dbh->rollback();
    }
}
