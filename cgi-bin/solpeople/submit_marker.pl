use strict;

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
    
    print page_title_html("Submit Marker to SGN");
    
    print <<HTML;
    
    <center>
	
	<form action="submit_marker.pl">
	<table>
	
	<tr><td>Marker name:</td><td><input name="marker_name" /></td></tr>
	<tr><td>Marker type:</td><td><input type="radio" name="marker_type" value="ssr" /> SSR<br />
	<input type="radio" name="marker_type" value="caps" /> CAPS</td></tr>
	<tr><td>5' primer seq: </td><td><input name="5primer" size="40" /></td></tr>
	<tr><td>3' primer seq: </td><td><input name="3primer" size="40" /></td></tr>
	
	<tr><td>Annealing temp: </td><td><input name="temp" size="5" />&deg;C</td></tr>
	<tr><td>Mg conc</td><td><input name="mgconc" size="5" /> mM</td></tr>
	
	<tr><td>Enzyme</td><td><input name="enzyme" /></td></tr>
	<tr><td>Band sizes: </td><td>&nbsp;</td></tr>
	<!--  a complete list should be generated from the database -->
	<tr><td>S. lycopersicum LA925</td><td><input name="band-size-1" size="5" /></td></tr>
	<tr><td>S. pennellii LA716</td><td><input name="band-size-3" size="5" /></td></tr>
	<tr><td>etc.</td><td>etc.</td></tr>
	<tr><td colspan="2"></td><td></td></tr>
	<tr><td>Submitter info:</td><td><b>$firstname $lastname</b></td></tr>
	</table>
	<br />
	<input type="hidden" name="person_id" value="$person_id" />
	<input type="submit" value="Submit Marker" /> &nbsp; 
    </form>
	</center>


HTML

$page->footer();
}

