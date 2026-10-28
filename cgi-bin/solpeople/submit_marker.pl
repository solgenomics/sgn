use strict;
use SGN::I18N ();
use CatalystX::GlobalContext qw( $c );
my SGN::I18N $ui_i18n = SGN::I18N::translate($c);

use CXGN::DB::Connection;
use CXGN::Page;
use CXGN::Login;
use CXGN::Page::FormattingHelpers qw/ blue_section_html page_title_html /;
use CXGN::People;
use CXGN::People::Person;

my $page=CXGN::Page->new("SGN|Marker submission","Lukas");
my $dbh = CXGN::DB::Connection->new();

my ($action) = $page -> get_encoded_arguments("action");

my $id = CXGN::Login->new($dbh)->verify_session();

my $person = CXGN::People::Person->new($dbh, $id);
my $firstname = $person->get_first_name();
my $lastname = $person ->get_last_name();
my $person_id = $person->get_sp_person_id();

if (!$action) { 
    display_form();
}
elsif ($action eq "check") { 
    check_entry();
}
elsif ($action eq "submit") { 
    submit_entry();
}

sub check_entry { 
}

sub submit_entry { 
}

sub display_form { 
    
    $page->header();
    
    print page_title_html(SGN::I18N::translate($ui_i18n, "genotype.marker.submit_marker_to_sgn", "Submit Marker to SGN", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}));
    
    print (qq~\x20\x20\x20\x20
    <center>
	
	<form action="submit_marker.pl">
	<table>
	
	<tr><td>~ . SGN::I18N::translate($ui_i18n, "genotype.marker.marker_name_80702e", "Marker name:", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~</td><td><input name="marker_name" /></td></tr>
	<tr><td>~ . SGN::I18N::translate($ui_i18n, "genotype.marker.marker_type", "Marker type:", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~</td><td><input type="radio" name="marker_type" value="ssr" /> SSR<br />
	<input type="radio" name="marker_type" value="caps" /> CAPS</td></tr>
	<tr><td>~ . SGN::I18N::translate($ui_i18n, "genotype.marker.5_primer_seq", "5' primer seq:", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~ </td><td><input name="5primer" size="40" /></td></tr>
	<tr><td>~ . SGN::I18N::translate($ui_i18n, "genotype.marker.3_primer_seq", "3' primer seq:", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~ </td><td><input name="3primer" size="40" /></td></tr>
	
	<tr><td>~ . SGN::I18N::translate($ui_i18n, "genotype.marker.annealing_temp", "Annealing temp:", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~ </td><td><input name="temp" size="5" />&deg;C</td></tr>
	<tr><td>~ . SGN::I18N::translate($ui_i18n, "genotype.marker.mg_conc", "Mg conc", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~</td><td><input name="mgconc" size="5" /> mM</td></tr>
	
	<tr><td>~ . SGN::I18N::translate($ui_i18n, "genotype.marker.enzyme", "Enzyme", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~</td><td><input name="enzyme" /></td></tr>
	<tr><td>~ . SGN::I18N::translate($ui_i18n, "genotype.marker.band_sizes", "Band sizes:", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~ </td><td>&nbsp;</td></tr>
	<!--  a complete list should be generated from the database -->
	<tr><td>S. lycopersicum LA925</td><td><input name="band-size-1" size="5" /></td></tr>
	<tr><td>S. pennellii LA716</td><td><input name="band-size-3" size="5" /></td></tr>
	<tr><td>etc.</td><td>etc.</td></tr>
	<tr><td colspan="2"></td><td></td></tr>
	<tr><td>~ . SGN::I18N::translate($ui_i18n, "genotype.marker.submitter_info", "Submitter info:", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~</td><td><b>$firstname $lastname</b></td></tr>
	</table>
	<br />
	<input type="hidden" name="person_id" value="$person_id" />
	<input type="submit" value="~ . SGN::I18N::translate($ui_i18n, "genotype.marker.submit_marker", "Submit Marker", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~" /> &nbsp;\x20
    </form>
	</center>


~);

$page->footer();
}

