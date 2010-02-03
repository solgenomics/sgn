#!/usr/bin/perl

######################################################################
#
#  Program  :  $Id$
#  Author   :  $Author$
#  Date     :  $Date$
#  CHECKOUT TAG : $Name : $
#
#  This page lists all the known RFLP markers in the SGN database.
#
######################################################################

use strict;
use CXGN::Page;
use CXGN::DB::Connection;

# Set static values.
our $rflp_page = '/search/markers/markerinfo.pl?marker_id=';
our $map_page = '/cview/view_chromosome.pl';
our $mapviewer_top = '/cview/index.pl';
our $direct_search = '/search/direct_search.pl'; 

# Create a new SGN page and connect to the DB.
our $page = CXGN::Page->new( "RFLP Markers List", "Robert Ahrens");
my $dbh = CXGN::DB::Connection->new();

# Initialize the count for rflp_id.
my $sth = $dbh->prepare("SELECT rflp_id FROM rflp_markers ORDER BY rflp_id DESC");
$sth->execute;
my ($max_rflp_id) = $sth->fetchrow_array;
my @num_fwd_unigenes;
my @num_rev_unigenes;
for (my $i=0; $i<=$max_rflp_id; $i++) {
    $num_fwd_unigenes[$i] = 0;
    $num_rev_unigenes[$i] = 0;
}

# Get rflp unigene_association information.
$sth = $dbh->prepare("SELECT r.rflp_id, fwd_rua.rflp_unigene_assoc_id FROM rflp_markers AS r LEFT JOIN rflp_unigene_associations AS fwd_rua ON r.forward_seq_id=fwd_rua.rflp_seq_id");
$sth->execute;
while (my ($rflp_id, $rug_id) = $sth->fetchrow_array) {
    if ($rug_id) { $num_fwd_unigenes[$rflp_id] ++; }
} 
$sth = $dbh->prepare("SELECT r.rflp_id, rev_rua.rflp_unigene_assoc_id FROM rflp_markers AS r LEFT JOIN rflp_unigene_associations AS rev_rua ON r.reverse_seq_id=rev_rua.rflp_seq_id");
$sth->execute;
while (my ($rflp_id, $rug_id) = $sth->fetchrow_array) {
    if ($rug_id) { $num_rev_unigenes[$rflp_id] ++; }
} 

# Query the DB for RFLP information.
$sth = $dbh->prepare("SELECT r.rflp_id, r.marker_id, r.rflp_name, r.library_name, r.insert_size, r.vector, r.cutting_site, r.drug_resistance, fs.fasta_sequence, rs.fasta_sequence, ml.marker_id FROM rflp_markers AS r LEFT JOIN rflp_sequences AS fs ON r.forward_seq_id=fs.seq_id LEFT JOIN rflp_sequences AS rs ON r.reverse_seq_id=rs.seq_id LEFT JOIN marker_experiment AS ml ON r.marker_id=ml.marker_id ORDER BY r.marker_prefix, r.marker_suffix");
$sth->execute;
my @rflplist;
my $old_rflp_id=0;
while (my ($rflp_id, $mrkr_id, $rflp_name, $library_name, $insert_size, $vector, $cut_site, $drug_resist, $fwd_seq, $rev_seq, $mapped) = $sth->fetchrow_array) {
    if ($rflp_id == $old_rflp_id) {
	# Redundant case: We are viewing another location for an RFLP marker we
	# have already added to the list.  So skip this entry.
	next;
    } else {
	# This is a new RFLP marker so add it to the list.  And update $old_rflp_id to 
	# reflect that this is the marker we're working on now.
	$old_rflp_id = $rflp_id;

        unless (defined($fwd_seq)) {$fwd_seq='';}
        unless (defined($rev_seq)) {$rev_seq='';}

	push @rflplist, "<tr><td><a href=\"$rflp_page" . $mrkr_id . "\">" . $rflp_name . 
	    "</a></td><td align=\"center\">" .
		# Removed from the previous line, as NO lib info is currently in db:
		# ($library_name || "unknown") . "</td><td align=\"center\">" .
		($insert_size || "0") . "</td><td align=\"center\">" .
		    $vector . "</td><td align=\"center\">" . $cut_site . 
			"</td><td align=\"center\">" . $drug_resist . "</td><td align=\"center\">" .
			    (length $fwd_seq) . "</td><td align=\"center\">" .
				(length $rev_seq) . "</td><td>" .
				    ($mapped ? "mapped" : "unmapped") .
					"</td><td align=\"center\">" . ($num_fwd_unigenes[$rflp_id] || "0") ."/" . ($num_rev_unigenes[$rflp_id] || "0") . "</td></tr>\n";
    }
}
$sth->finish;

# Print the page.
$page->header("Restriction Fragment Length Polymorphism Markers on SGN");
 
print "<center><h2>Restriction Fragment Length Polymorphism Markers on SGN</h2></center>\n";
print "\n<table summary=\"\" width=\"100%\" align=\"center\" border=\"2\">\n<tr>\n";
print "<td><b>RFLP<br />Marker</b></td>\n";
# NO library info in db at this time.  Therefore, DON'T show it on the table.
#print "<td><b>Library</b></td>\n";
print "<td><b>Insert<br />size</b></td>\n";
print "<td><b>Vector</b></td>\n";
print "<td><b>Cutting<br />Site</b></td>\n";
print "<td><b>Drug<br />Resistance</b></td>\n";
print "<td><b>Forward<br />sequence<br />length (bp)</b></td>\n";
print "<td><b>Reverse<br />sequence<br />length (bp)</b></td>\n";
print "<td><b>Mapped</b></td>\n";
print "<td><b>Unigne matches<br />fwd / rev</b></td>\n";
print "</tr>\n";

print @rflplist;

print "</table>\n\n";
print "<br /><br />\n";

$page->footer;
