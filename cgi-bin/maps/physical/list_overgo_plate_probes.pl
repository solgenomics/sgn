#!/usr/bin/perl -w

######################################################################
#
#  Program: $Id$
#  Author:  $Author$
#  Date:    $Date$
#  CHECKOUT TAG: $Name$
#
#  This is a script to list all the probes used in the wells of
#  an overgo plate.
#
#  At this stage, we only offer simple functionality -- showing 
#  which probes have been matched and which have not, and linking
#  to other pages as appropriate.
#  
#  Funkier functionality (funktionality?) could be added to, eg.
#  colour-code the probes which are instrumental in conflicted matches
#  (such as those listed in tentative_overgo_associations) or to
#  deal with multiple overgo_versions, etc.
# 
######################################################################

use strict;
use CXGN::Page;
use CXGN::DB::Physical;
use CXGN::DB::Connection;
use CXGN::Page::FormattingHelpers qw/page_title_html info_section_html/;

my $map_id = CXGN::DB::Physical::get_current_map_id();

# Presets.
our $physical_dir = '/maps/physical/';
our $baclist_page = $physical_dir . 'list_bacs_by_plate.pl?by_plate=';
our $overgo_stats_page = $physical_dir . 'overgo_stats.pl';
our $overgo_process_page = $physical_dir . 'overgo_process_explained.pl';
our $physical_map_page = '/cview/map.pl?map_id=9&amp;physical=1';
our $marker_details_page = '/search/markers/markerinfo.pl?marker_id=';
our $this_page = '/maps/physical/list_overgo_plate_probes.pl?plate_no=';
our $plate_width = 600; 
our $well_width = 50; 
our $well_height = 30;
our $sgnblue = '#ccccff';
our $highlight_color = '#dd4400';

# Create the page.
our $page = CXGN::Page->new( "List overgo plate probes", "Robert Ahrens");

my %params;
($params{'plate_no'},$params{'plate_id'},$params{'highlightwell'},$params{'overgo_version'})=$page->get_encoded_arguments('plate_no','plate_id','highlightwell','overgo_version');

if (!$params{'plate_no'} && !$params{'plate_id'}) {
    &list_all_plates($page);
}
my ($highlight_row, $highlight_col);
if ($params{'highlightwell'} =~ /^([A-z])(\d+)$/) {
    $highlight_row = uc $1;
    $highlight_col = uc $2;
}

# Connect to the db.
my $dbh = CXGN::DB::Connection->new('physical');

# Get overgo_version.
my $overgo_version = $params{'overgo_version'} || CXGN::DB::Physical::get_current_overgo_version($dbh);

# Count marker <--> BAC associations from overgo_associations.
# NB - We're ignoring tentative associations in this iteration.  If you
# want them, this is where you should add them.
my @bac_assocs_by_probe_id;
my $oa_sth = $dbh->prepare("SELECT overgo_probe_id, bac_id FROM overgo_associations inner join oa_plausibility as oap using(overgo_assoc_id) WHERE overgo_version=? and oap.plausible=1 AND oap.map_id=?");
$oa_sth->execute($overgo_version, $map_id);
while (my ($op_id, $bac_id) = $oa_sth->fetchrow_array) {
    $bac_assocs_by_probe_id[$op_id] ++;
}
$oa_sth->finish;

# Get the overgo_plate_id.
my $plate_id = $params{'plate_id'} || CXGN::DB::Physical::get_plate_id($dbh, $params{'plate_no'});
my $plate_no = $params{'plate_no'} || CXGN::DB::Physical::get_plate_number_by_plate_id($dbh, $params{'plate_id'});

# Get the plate information.
my %plate;
my $sgn = $dbh->qualify_schema('sgn');
my $plate_sth = $dbh->prepare("SELECT ma.alias, ma.marker_id, pm.overgo_probe_id, pm.overgo_plate_row, pm.overgo_plate_col FROM probe_markers AS pm LEFT JOIN $sgn.marker_alias AS ma ON pm.marker_id=ma.marker_id WHERE pm.overgo_plate_id=? AND ma.preferred=true ORDER BY pm.overgo_plate_row, pm.overgo_plate_col");
$plate_sth->execute($plate_id);
while (my ($mrkr, $mrid, $probeid, $row, $col) = $plate_sth->fetchrow_array) {
    if (($row eq $highlight_row) && ($col == $highlight_col)) {
	$plate{$row}{$col} = "<td width=\"$well_width\" height=\"$well_height\" bgcolor=\"$highlight_color\"><a href=\"$marker_details_page$mrid\"><b>$mrkr (" . ($bac_assocs_by_probe_id[$probeid] || "0") . ")</b></a></td>\n";
    } else {
	$plate{$row}{$col} = "<td width=\"$well_width\" height=\"$well_height\"" . ($bac_assocs_by_probe_id[$probeid] ? " bgcolor='$sgnblue'><a href='$marker_details_page$mrid'>$mrkr ($bac_assocs_by_probe_id[$probeid])</a>" : "><a href=\"$marker_details_page$mrid\">$mrkr</a>") . "</td>\n";
    }
}
$plate_sth->finish;

# Print the page.
$page->header("Overgo probes on plate $plate_no.");
# Start the table and give the title.
print page_title_html(qq|Overgo probes on <a href="$baclist_page$plate_no">plate $plate_no</a>|);

print <<EOHTML;
<p>
Markers which have been successfully and <a href=\"/maps/physical/overgo_process_explained.pl#plausible\">plausibly</a> matched to BACs are displayed against a <span style='background-color:$sgnblue'><b>blue</b></span> background with the number of BACs matched listed in parentheses.  Markers that are unmatched or not plausibly matched are displayed against a <b>white</b> background.
</p>

<table summary="" border="2" align="center" width="$plate_width">
EOHTML

my $row = 'A';
my $last_row = CXGN::DB::Physical::get_last_row();
while ($row ne $last_row) {
    print "<tr>\n";
    for (my $col=1; $col<=12; $col++) {
	#print "<td>$row:$col</td>\n";
	print ($plate{$row}{$col} || "<td width=\"$well_width\" height=\"$well_height\"><font color=\"#cccccc\">empty</font></td>\n");
    }
    print "</tr>\n";
    $row ++;
}
print "</table><br /><br />\n";

print info_section_html(title => 'Related Pages', contents => <<EOHTML);
<ul>
<li><a href="$baclist_page$plate_no">List all BACs which matched plate $plate_no</a></li>
<li><a href="$overgo_stats_page">Overview of all processed Overgo plates.</a></li>
<li><a href="$overgo_process_page">About the Overgo Plating process</a></li>
<li><a href="$physical_map_page">Overview of the Physical map</a></li>
</ul>
EOHTML
$page->footer;


######################################################################
#
#  Subroutines
#
######################################################################


sub list_all_plates ($) {

    my ($page) = @_;

    # Connect to the db.
    my $dbh = CXGN::DB::Connection->new('physical');
    my $sth = $dbh->prepare("SELECT DISTINCT plate_number, plate_size, empty_wells FROM overgo_plates ORDER BY plate_number");
    my @plates;
    $sth->execute;
    while (my ($pn, $ps, $ew) = $sth->fetchrow_array) {
	push @plates, "<tr>\n<td align=\"center\"><a href=\"$this_page$pn\">Plate $pn</a></td>\n";
	push @plates,  "<td align=\"center\">" . ($ps - $ew) . "</td></tr>\n";
    }
    $sth->finish;

    # Throw an error if no pages are found.
    if (@plates == 0) {
	$page->error_page("No overgo plates found in the physical database.\n");
    }

    # Print the page.
    $page->header("Overgo plates on SGN");
    print "<center><h2>Overgo plates on SGN</h2></center>\n";
    print "\nThis is a complete list of the \"designs\" (that is to say, the probe placements) of the overgo plates involved in SGN's <a href=\"$overgo_process_page\">Physical mapping project</a>.  The links below reveal the designs of the individual plates, as well as how many BACs have been successfully <i>anchored</i> against them.\n";
    print "\n<table summary=\"\" border=\"0\" width=\"80%\" align=\"center\">\n<tr>\n";
    print "<td width=\"50%\" align=\"center\"><b>Overgo probe plate</b></td>\n";
    print "<td width=\"50%\" align=\"center\"><b>Number of probes on plate</b></td>\n";
    print "</tr>\n";
    print @plates;
    print "</table>\n";
    print "\n<center>\n";
    print "<h3>Links</h3>\n";
    print "\n<a href=\"$overgo_process_page\">Explanation of the overgo plating process</a><br />\n";
    print "\n<a href=\"$physical_map_page\">Overview of the tomato physical map</a><br />\n";
    print "\n<a href=\"$overgo_stats_page\">View the progress of the overgo plating project</a><br />\n";
    print "</center>\n";
    $page->footer;
    exit;

}
