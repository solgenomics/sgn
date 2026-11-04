#!/usr/bin/perl -w
use strict;
use SGN::I18N ();
use JSON ();
use CatalystX::GlobalContext '$c';

use warnings;

use CXGN::DB::Connection;
use CXGN::Page;
use CXGN::Login;
use CXGN::Contact;
use CXGN::People;

    my SGN::I18N $ui_people_i18n = SGN::I18N::translate($c);
    my %ui_people_text = (
        username => SGN::I18N::translate($ui_people_i18n, 'community.people.username', 'Username', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
        timestamp => SGN::I18N::translate($ui_people_i18n, 'community.people.timestamp', 'Timestamp:', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
        time_restraint_in_hours => SGN::I18N::translate($ui_people_i18n, 'community.people.time_restraint_in_hours', 'Time restraint (in hours):', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
        obtain_user_info_on_id_number => SGN::I18N::translate($ui_people_i18n, 'community.people.obtain_user_info_on_id_number', 'Obtain user info on id number:', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
        submit => SGN::I18N::translate($ui_people_i18n, 'community.people.submit', 'Submit', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
    );
    my %ui_people_js = (
        cannot_create_xmlhttp => JSON->new->ascii->allow_nonref->encode(SGN::I18N::translate($ui_people_i18n, 'community.people.cannot_create_xmlhttp', 'Giving up :( Cannot create an XMLHTTP instance')),
        http_error_prefix => JSON->new->ascii->allow_nonref->encode(SGN::I18N::translate($ui_people_i18n, 'community.people.http_error_prefix', 'Error ')),
    );

my $page=CXGN::Page->new(SGN::I18N::translate($ui_people_i18n, 'community.people.sgn_stats', 'SGN Stats', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),"johnathon");
my $dbh = CXGN::DB::Connection->new("sgn_people");

my $logged_in_person_id=CXGN::Login->new($dbh)->verify_session();
my $logged_in_user=CXGN::People::Person->new($dbh, $logged_in_person_id);
my $logged_in_username=$logged_in_user->get_first_name()." ".$logged_in_user->get_last_name();
my $logged_in_user_type=$logged_in_user->get_user_type();

my $user_table;
my ($time_to_check) = $page->get_encoded_arguments("hours");

sub epoch_to_minutes{
    my $people_logged_in = $_[0];
    for my $person(@$people_logged_in){
	$person->[2] = int($person->[2]/60);
    }	
    return $people_logged_in;
}

$page->header(SGN::I18N::translate($ui_people_i18n, 'community.people.sgn_stats', 'SGN Stats', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }), SGN::I18N::translate($ui_people_i18n, 'community.people.sgn_stats', 'SGN Stats', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }));
print <<html;

<script type='text/javascript' language='javascript'>
    function lookup_person(id){
        if(id > 0){
	    if(window.XMLHttpRequest){
		http_request = new XMLHttpRequest();
	    }
	    else if(window.ActiveXObject){
		http_request = new ActiveXObject("Microsoft.XMLHTTP");
	    }
	    if (!http_request) {
		alert($ui_people_js{cannot_create_xmlhttp});
            return false;
	    }
	    http_request.onreadystatechange = function() { writeData(http_request); };
	    http_request.open('GET', 'get_person.pl?id='+id, true);
	    http_request.send("id="+id);
	}
	function writeData(http_request){
	    if(http_request.readyState == 4){
		if(http_request.status == 200){
		    var table = document.getElementById("idnumbers");
		    table.innerHTML += http_request.responseText;
		}
		else{
		    alert($ui_people_js{http_error_prefix} + http_request.status);
	    }
	    }
	}
    }
</script>
<br />
    <form method="get" action="stats.pl" name="time" id="time"><label for="minutes">$ui_people_text{time_restraint_in_hours} &nbsp&nbsp&nbsp&nbsp&nbsp&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</label>
<input type="text" size="5" name="hours" id="hours" value="$time_to_check" />
<input type="submit" id="submit" value="$ui_people_text{submit}" /></form>
<form id="lookup" name="lookup" action="javascript:lookup_person(document.lookup.number.value)">
<span id="request" name="request"
    style="cursor: pointer; text-decoration: underline"
    onclick="javascript:lookup_person(document.lookup.number.value)">
        $ui_people_text{obtain_user_info_on_id_number}
</span>
<input type="text" size="5" name="number" />
<input type="submit" id="sumbitnum" value="$ui_people_text{submit}" />
</form>

<script type="text/javascript" language="javascript">document.time.hours.focus();</script>
$user_table

<table style="width: 45%" name="idnumbers" id="idnumbers"><tr><th>$ui_people_text{username}:</th><th>$ui_people_text{timestamp}</th></tr></table>
html

$page->footer();

