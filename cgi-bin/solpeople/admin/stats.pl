#!/usr/bin/perl -w
use strict;
use warnings;

use CXGN::DB::Connection;
use CXGN::Page;
use CXGN::Login;
use CXGN::Contact;
use CXGN::People;

my $page=CXGN::Page->new("SGN Stats","johnathon");
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

$page->header("SGN Stats", "SGN Stats");
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
		alert('Giving up :( Cannot create an XMLHTTP instance');
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
		    alert("Error " + http_request.status);
	    }
	    }
	}
    }
</script>
<br />
    <form method="get" action="stats.pl" name="time" id="time"><label for="minutes">Time restraint (in hours): &nbsp&nbsp&nbsp&nbsp&nbsp&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</label>
<input type="text" size="5" name="hours" id="hours" value="$time_to_check" />
<input type="submit" id="submit" value="Submit" /></form>
<form id="lookup" name="lookup" action="javascript:lookup_person(document.lookup.number.value)">
<span id="request" name="request"
    style="cursor: pointer; text-decoration: underline"
    onclick="javascript:lookup_person(document.lookup.number.value)">
        Obtain user info on id number:
</span>
<input type="text" size="5" name="number" />
<input type="submit" id="sumbitnum" value="Submit" />
</form>

<script type="text/javascript" language="javascript">document.time.hours.focus();</script>
$user_table

<table style="width: 45%" name="idnumbers" id="idnumbers"><tr><th>Username:</th><th>Timestamp:</th></tr></table>
html

$page->footer();

