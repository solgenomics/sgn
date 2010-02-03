#!/usr/bin/perl -w

use strict;
use CXGN::Page;
use CXGN::DB::Connection;

# Set defaults.
my $contig_page='/search/unigene.pl?type=legacy&';
my $est_page='/search/est.pl?request_type=automatic&amp;request_from=1&amp;request_id=';
my $ssr_page='/search/markers/markerinfo.pl?marker_id=';

# Initialization.
our $page = CXGN::Page->new( "SSR Markers", "Robert Ahrens");
my $dbh = CXGN::DB::Connection->new();

# Get the unigene BLAST match count.
my $unigene_sth = $dbh->prepare("SELECT DISTINCT ssr_id, unigene_id FROM ssr_primer_unigene_matches");
my @unigene_matches;
$unigene_sth->execute;
while (my ($ssr_id, $unigene_id) = $unigene_sth->fetchrow_array) {
    $unigene_matches[$ssr_id] ++;
}
$unigene_sth->finish;

# Read the marker values from the database.
my @ssr_list;
my $ssr_sth = $dbh->prepare("SELECT s.ssr_id, s.marker_id, s.ssr_name, et.trace_name, s.start_primer, s.end_primer, s.pcr_product_ln, s.ann_high, s.ann_low FROM ssr AS s LEFT JOIN seqread AS et ON s.est_read_id=et.read_id");
my $repeats_sth = $dbh->prepare("SELECT repeat_motif, reapeat_nr FROM ssr_repeats WHERE ssr_id=?");
my $locs_sth = $dbh->prepare("SELECT loc_id FROM marker_locations WHERE marker_id=?");
$ssr_sth->execute;
while (my ($ssr_id, $marker_id, $ssr_name, $est_trace, $start_primer, $end_primer, $pcr_length, $ann_high, $ann_low) = $ssr_sth->fetchrow_array) {
    $ann_high ||= "n/a";
    $ann_low ||= "n/a";
    $marker_id || &local_abort("No marker_id detected for $ssr_name.\n");
    $ssr_id || &local_abort("No ssr_id detected for $ssr_name.\n");
    # Get the repeat motifs.
    my @repeat_motifs=();
    my @repeat_numbers=();
    $repeats_sth->execute($ssr_id);
    while (my ($motif, $r_nr) = $repeats_sth->fetchrow_array) {
	push @repeat_motifs, $motif;
	push @repeat_numbers, $r_nr;
    }
    # Get map locations.
    $locs_sth->execute($marker_id);
    my ($mapped) = $locs_sth->fetchrow_array;
    # Add the row of the table.

    unless (defined($ssr_page)) {$ssr_page='';}
    unless (defined($marker_id)) {$marker_id='';}
    unless (defined($ssr_name)) {$ssr_name='';}
    unless (defined($est_trace)) {$est_trace='';}
    unless (defined($est_page)) {$est_page='';}
    unless (defined($ssr_id)) {$ssr_id='';}
    unless (defined($start_primer)) {$start_primer='';}
    unless (defined($end_primer)) {$end_primer='';}
    unless (defined($pcr_length)) {$pcr_length='';}
    unless (defined($ann_low)) {$ann_low='';}
    unless (defined($ann_high)) {$ann_high='';}
    unless (defined($mapped)) {$mapped='';}

    push @ssr_list, "<tr><td><a href='$ssr_page$marker_id'>" . $ssr_name . 
	"</a></td><td align='center'>" . ($est_trace ? "<a href='$est_page$est_trace'>$est_trace</a>" : "unknown") . "</td>" .  
	    "<td>" . ($unigene_matches[$ssr_id] ? "<a href='$ssr_page$ssr_id'>$unigene_matches[$ssr_id]</a>" : "0") . "</td>" . 
		"<td>" . join("<br />", @repeat_motifs) .
		    "</td><td align='center'>" . join("<br />", @repeat_numbers) .
			"</td><td><b>fwd (5'->3'):</b> " . ($start_primer || "unknown") . "<br /><b>rev (5'->3'):</b> " . ($end_primer || "unknown") .
			    "</td><td align='center'>" . ($pcr_length || "unknown") .
				"</td><td>low: " . $ann_low . "<br />high: " . $ann_high .
				    "</td><td align='center'>" . ($mapped ? "mapped" : "not mapped") . "</td></tr>\n";
    
}
$locs_sth->finish;
$repeats_sth->finish;
 
# Print the page.
$page->header( "SSR Markers" );

print "<table summary=\"\" border=\"2\" width=\"710\" align=\"center\">\n";
print "<tr>\n<td width=\"60\"><b>SSR name</b></td>\n";
print "<td width=\"60\" align=\"center\"><b>EST trace</b></td>\n";
print "<td width=\"100\" align=\"center\"><b>Unigene BLAST matches</b></td>\n";
print "<td width=\"120\" align=\"center\"><b>Repeat motifs</b></td>\n";
print "<td width=\"35\" align=\"center\"><b>Repeat number</b></td>\n";
print "<td width=\"50\" align=\"center\"><b>PCR primers</b></td>\n";
print "<td width=\"35\" align=\"center\"><b>PCR product length</b></td>\n";
print "<td width=\"50\" align=\"center\"><b>Annealing temperature</b></td>\n";
print "<td width=\"50\" align=\"center\"><b>Mapped</b></td>\n</tr>\n";

print @ssr_list;

print "</table>\n";
$page->footer;


######################################################################
#
#  Subroutines for this program.
#
######################################################################


sub local_abort {

    my ($errstrn) = @_;
    if (not $errstrn) {
	$errstrn = "Error reading SSR data"; 
    }
    $page->header( "Error reading SSR data." ,"Error reading SSR data." );
    if ($errstrn) {
	print "$errstrn\n";
    } else {
	print "<I>There has been an error generating data.<br />Please email Robert Ahrens at <a href='mailto:ra97\@cornell.edu'>ra97\@cornell.edu</a> to let him know you are experiencing difficulties.</I>";
    }
    $page->footer();
    exit;

}




