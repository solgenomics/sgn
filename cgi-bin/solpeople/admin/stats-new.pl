#!/usr/bin/perl -w
use strict;
use CXGN::Page;
use CXGN::Login;
use CXGN::Contact;
use CXGN::People;

my $page=CXGN::Page->new("SGN Stats","johnathon");
my $logged_in_person_id=CXGN::Login->new()->verify_session();
my $logged_in_user=CXGN::People::Person->new($logged_in_person_id);
my $logged_in_person_id=$logged_in_user->get_sp_person_id();
my $logged_in_username=$logged_in_user->get_first_name()." ".$logged_in_user->get_last_name();
my $logged_in_user_type=$logged_in_user->get_user_type();
my $dbh = CXGN::DB::Connection->new("sgn_people");
my $user_table;
my @column_names_arr;
my @table_columns = ("password", "last_access_time", "last_name");
my ($time_to_check) = $page->get_encoded_arguments("hours");
#print STDERR "Time: '$time_to_check'\n";
if($logged_in_user_type eq 'curator'){
    find_recently_active_users();
    my $column_namesref = find_sp_person_column_names();
    foreach my $column(@$column_namesref){
	push @column_names_arr, @$column[0];
    }

}

else
{
   $page->message_page('Sorry, but you are not authorized to view statistics.');
}

#Finds the columns in the sp_person table.
sub find_sp_person_column_names{
    my $dbh2 = CXGN::DB::Connection->new();
    my $sth = $dbh2->prepare("select column_name from information_schema.columns where table_schema = 'sgn_people' and table_name = 'sp_person'");
    $sth->execute();
    return $sth->fetchall_arrayref;
}

#Change the epoch time into minutes
sub epoch_to_minutes{
    my $people_logged_in = $_[0];
    for my $person(@$people_logged_in){
	$person->[2] = int($person->[2]/60);
    }	
    return $people_logged_in;
}

#Query the database for recently active users and then generate a table with their username, id, minutes since last action, and timestamp.
sub find_recently_active_users{
    if($time_to_check <= 0){
	$time_to_check = 24;#THIS IS THE DEFAULT TIME
    }
    my $people_logged_in;
    $people_logged_in = $dbh->selectall_arrayref("select sp_person_id, username, extract(epoch from current_timestamp - last_access_time), last_access_time from sp_person where extract(epoch from current_timestamp - last_access_time) <= ? order by last_access_time DESC", undef, $time_to_check*60*60);
    $user_table = "<table align='left' style='width: 100%'><tr><th>ID:</th><th>Username:</th><th>Mins since last action:</th><th>Timestamp:</th></tr><tr><td>";
    $people_logged_in = epoch_to_minutes($people_logged_in);
    for my $row(@$people_logged_in){
	$user_table .="<tr><td align='center'>";
	for my $cell(@$row){
	    $user_table .="$cell</td><td align='center'>";
	}
	$user_table .= "</tr>";
    }
    $user_table .="</table>";
}


#HTML Printing Start Here
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
<script type="text/javascript" language="javascript">document.time.hours.focus();</script>
$user_table
<table align='left' style='width:100%'><tr><th>ID</th><th>Username</th><th>$table_columns[0]</th><th>$table_columns[1]</th><th>$table_columns[2]</th></tr>
<tr><td><input type='text' size='5' name='id1' id='id1' /></td></tr></table>

html

$page->footer();


#<form id="lookup" name="lookup" action="javascript:lookup_person(document.lookup.number.value)">
#<span id="request" name="request"
#    style="cursor: pointer; text-decoration: underline"
#    onclick="javascript:lookup_person(document.lookup.number.value)">
#        Obtain user info on id number:
#</span>
#<input type="text" size="5" name="number" />
#<input type="submit" id="sumbitnum" value="Submit" />
#</form>
