#!/usr/bin/perl -w

use strict;
use SGN::I18N ();
use CatalystX::GlobalContext qw( $c );
my SGN::I18N $ui_i18n = SGN::I18N::translate($c);
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
    $marker_id || &local_abort((SGN::I18N::translate($ui_i18n, "genotype.marker.no_field_detected_for", "No %{field} detected for ", {field => "marker_id"}, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . ("" . "$ssr_name") . ".\n"));
    $ssr_id || &local_abort((SGN::I18N::translate($ui_i18n, "genotype.marker.no_field_detected_for", "No %{field} detected for ", {field => "ssr_id"}, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . ("" . "$ssr_name") . ".\n"));
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
	"</a></td><td align='center'>" . ($est_trace ? "<a href='$est_page$est_trace'>$est_trace</a>" : SGN::I18N::translate($ui_i18n, "cross.pages.unknown", "unknown", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')})) . "</td>" .
	    "<td>" . ($unigene_matches[$ssr_id] ? "<a href='$ssr_page$ssr_id'>$unigene_matches[$ssr_id]</a>" : "0") . "</td>" . 
		"<td>" . join("<br />", @repeat_motifs) .
		    "</td><td align='center'>" . join("<br />", @repeat_numbers) .
			("</td><td><b>" . SGN::I18N::translate($ui_i18n, "genotype.marker.fwd_5_3", "fwd (5'->3'):", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . "</b> ") . ($start_primer || SGN::I18N::translate($ui_i18n, "cross.pages.unknown", "unknown", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')})) . ("<br /><b>" . SGN::I18N::translate($ui_i18n, "genotype.marker.rev_5_3", "rev (5'->3'):", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . "</b> ") . ($end_primer || SGN::I18N::translate($ui_i18n, "cross.pages.unknown", "unknown", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')})) .
			    "</td><td align='center'>" . ($pcr_length || SGN::I18N::translate($ui_i18n, "cross.pages.unknown", "unknown", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')})) .
				("</td><td>" . SGN::I18N::translate($ui_i18n, "genotype.marker.low", "low:", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . " ") . $ann_low . ("<br />" . SGN::I18N::translate($ui_i18n, "genotype.marker.high", "high:", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . " ") . $ann_high .
				    "</td><td align='center'>" . ($mapped ? SGN::I18N::translate($ui_i18n, "genotype.marker.mapped", "mapped", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) : "not mapped") . "</td></tr>\n";
    
}
$locs_sth->finish;
$repeats_sth->finish;
 
# Print the page.
$page->header( SGN::I18N::translate($ui_i18n, "genotype.marker.ssr_markers", "SSR Markers", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) );

print "<table summary=\"\" border=\"2\" width=\"710\" align=\"center\">\n";
print ("<tr>\n<td width=\"60\"><b>" . SGN::I18N::translate($ui_i18n, "genotype.marker.ssr_name", "SSR name", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . "</b></td>\n");
print ("<td width=\"60\" align=\"center\"><b>" . SGN::I18N::translate($ui_i18n, "genotype.marker.est_trace", "EST trace", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . "</b></td>\n");
print ("<td width=\"100\" align=\"center\"><b>" . SGN::I18N::translate($ui_i18n, "genotype.marker.unigene_blast_matches", "Unigene BLAST matches", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . "</b></td>\n");
print ("<td width=\"120\" align=\"center\"><b>" . SGN::I18N::translate($ui_i18n, "genotype.marker.repeat_motifs", "Repeat motifs", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . "</b></td>\n");
print ("<td width=\"35\" align=\"center\"><b>" . SGN::I18N::translate($ui_i18n, "phenotype.repeat_number", "Repeat number", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . "</b></td>\n");
print ("<td width=\"50\" align=\"center\"><b>" . SGN::I18N::translate($ui_i18n, "genotype.marker.pcr_primers", "PCR primers", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . "</b></td>\n");
print ("<td width=\"35\" align=\"center\"><b>" . SGN::I18N::translate($ui_i18n, "genotype.marker.pcr_product_length", "PCR product length", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . "</b></td>\n");
print ("<td width=\"50\" align=\"center\"><b>" . SGN::I18N::translate($ui_i18n, "genotype.marker.annealing_temperature", "Annealing temperature", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . "</b></td>\n");
print ("<td width=\"50\" align=\"center\"><b>" . SGN::I18N::translate($ui_i18n, "genotype.marker.mapped_879a69", "Mapped", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . "</b></td>\n</tr>\n");

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
	$errstrn = SGN::I18N::translate($ui_i18n, "genotype.marker.error_reading_ssr_data_140275", "Error reading SSR data", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')});
    }
    $page->header( SGN::I18N::translate($ui_i18n, "genotype.marker.error_reading_ssr_data", "Error reading SSR data.", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) ,SGN::I18N::translate($ui_i18n, "genotype.marker.error_reading_ssr_data", "Error reading SSR data.", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) );
    if ($errstrn) {
	print "$errstrn\n";
    } else {
	print ("<I>" . SGN::I18N::translate($ui_i18n, "genotype.marker.there_has_been_an_error_generating_data", "There has been an error generating data.", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . "<br />" . SGN::I18N::translate($ui_i18n, "genotype.marker.please_email_robert_ahrens_at", "Please email Robert Ahrens at", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . " <a href='mailto:ra97\@cornell.edu'>ra97\@cornell.edu</a> " . SGN::I18N::translate($ui_i18n, "genotype.marker.to_let_him_know_you_are_experiencing_difficulties", "to let him know you are experiencing difficulties.", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . "</I>");
    }
    $page->footer();
    exit;

}




