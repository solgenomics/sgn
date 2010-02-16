######################################################################
#
#  This is the first cos_list page to take advantage of the new
#  SGN database.  It offers reduced functionality from its 
#  predecessor because much of this functionality is now of
#  increased complexity and is folded into the individual EST
#  and unigene pages.  So instead this page just links to them.
#
######################################################################

use strict;
use CXGN::Page;
use CXGN::DB::Connection;

# Set static values.
my $at_page='http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?cmd=Retrieve&amp;db=Nucleotide&amp;dopt=GenBank&amp;list_uids=';
my $map_link='/search/markers/markerinfo.pl?marker_id=';
my $est_read_page='/search/est.pl?request_from=0&amp;request_type=automatic&amp;search=Search&amp;request_id=';
my $cos_page='/search/markers/markerinfo.pl?marker_id=';

# Create a new SGN webpage.
our $page = CXGN::Page->new( "COS Marker List", "Robert Ahrens");

# Read data on the COS markers collection in from the sgn database.
my $dbh = CXGN::DB::Connection->new();
my $cos_sth = $dbh->prepare("SELECT c.cos_id, c.cos_marker_id, c.marker_id, c.est_read_id, c.at_match, c.at_position, c.bac_id, ml.marker_id, s.trace_name FROM cos_markers AS c LEFT JOIN marker_experiment AS ml inner join marker_location using(location_id) ON c.marker_id=ml.marker_id LEFT JOIN seqread AS s ON c.est_read_id=s.read_id");
$cos_sth->execute;
my @cos_list;
my $old_cos_mrkr_id=0;
while (my ($cos_id, $cos_mrkr_id, $mrkr_id, $est_read_id, $at_match, $at_posn, $bac_id, $mapped, $trace_name) = $cos_sth->fetchrow_array) {
    if ($cos_mrkr_id == $old_cos_mrkr_id) {
	# Skipping multiple mapped versions of the same marker.
	next;
    } else {
	$at_match =~ s/\.\S+//;
	push @cos_list, "<tr>\n<td><a href='$cos_page$mrkr_id'>$cos_id</a></td>\n" . 
	    ($trace_name ? "<td><a href='$est_read_page$trace_name'>$trace_name</a></td>\n" : "<td>No trace</td>\n") .
		"<td><a href=\"$at_page$bac_id\">$at_match</a></td>\n" .
		    "<td>$at_posn</td>\n" .
			($mapped ? "<td>mapped</td>\n"
			 : "<td>not mapped</td>\n") .
			     "</tr>\n";
	$old_cos_mrkr_id = $cos_mrkr_id;
    }
}

$cos_sth->finish;

# Print the page.
$page->header("Conserved Ortholog Set Markers on SGN");

print "<center><h2>Conserved Ortholog Set Markers available on SGN</h2></center>\n";
print "\n<table summary=\"\" width=\"90%\" align=\"center\" border=\"2\">\n<tr>\n";
print "<td><b>CU ID \#</b></td>\n";
print "<td><b>Tomato EST Read</b></td>\n";
print "<td><b>A.t. Best BAC match</b></td>\n";
print "<td><b>A.t. position</b></td>\n";
print "<td><b>Mapped</b></td>\n";
print "</tr>\n";

print @cos_list;

print "</table>\n\n";
print "<br /><br />\n";

$page->footer();


