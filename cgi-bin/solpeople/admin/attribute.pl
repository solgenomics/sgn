
use strict;

use CXGN::DB::Connection;
use CXGN::Page;
use CXGN::Login;
use CXGN::People;
use CXGN::DB::Connection;

my $page = CXGN::Page->new("Make Attributions", "Lukas and John");
our $dbh = CXGN::DB::Connection-> new("sgn_people"); 

my($action, $data_type, $data_id, $attributed_to_id, $attributed_to_type, $role_id)=$page->get_encoded_arguments('action', 'data_type', 'data_id','attributed_to_id', 'attributed_to_type', 'role_id');

my $logged_in_person_id=CXGN::Login->new($dbh)->verify_session();
my $logged_in_user=CXGN::People::Person->new($dbh, $logged_in_person_id);
my $logged_in_person_id=$logged_in_user->get_sp_person_id();
my $logged_in_username=$logged_in_user->get_first_name()." ".$logged_in_user->get_last_name();
my $logged_in_user_type=$logged_in_user->get_user_type();

if($logged_in_user_type ne 'curator') { 
    $page->message_page("You don't have the necessary privileges to perform this action! ");
}



$page->header();
if ($action eq "verify") { verify( $data_type, $data_id, $attributed_to_id, $attributed_to_type, $role_id); }
elsif ($action eq "store" ) { store( $data_type, $data_id, $attributed_to_id, $attributed_to_type, $role_id); }
else { form(); }
$page->footer();


sub form { 
    
    my $schema = $dbh->qualify_schema("metadata");
    
    my $q = "SELECT $schema.roles.role_id, $schema.roles.role_name FROM $schema.roles";
    my $sth = $dbh->prepare($q);
    $sth->execute();
    my @roles = ();
    my @role_ids=();
    while (my ($role_id, $role) = $sth->fetchrow_array()) { 
	push @roles, $role;
	push @role_ids, $role_id;
    }

    my $role_select = "<select name=\"role_id\" >";
    for (my $i=0; $i<@roles; $i++) { 
	$role_select .= qq { <option value="$role_ids[$i]">$roles[$i]</option> };
    }
    $role_select .= "</select>";
	
    
    print <<HTML;
    
    <form>
	<table><tr>
	<td>Data type:</td>
	<td>
	<select name="data_type">
	<option value="bac">BAC</option>
	<option value="marker">Marker</option>
	</select>
	</td>
	<td>Data id:</td>
	<td> <input name="data_id" /></td>
	</tr>
	<tr>
	<td>Role type:</td>
	<td colspan="3">
	$role_select
	</td>
	</tr>

	<tr>
	<td>Attribution to</td>
	<td>
	<select name="attributed_to_type">
	<option value="person">Person</option>
	<option value="organization">Organization</option>
	<option value="project">Project</option>
	</select>
	</td>
	<td>id</td>
	<td> <input name="attributed_to_id" /></td>
	</tr></table>
	
	
	<br />
	<input type="hidden" name="action" value="verify" />
	<input type="submit" value="Submit" />
	
	</form>
	
	
HTML
	

}

sub verify { 
    my ($data_type, $data_id, $attributed_to_id, $attributed_to_type, $role_id) = @_; 
    
    
    if (!$attributed_to_type || !$attributed_to_id || !$data_type || !$data_id) { 
	$page->message_page("Need all data filled in!");
    }
    
    my $attributed_name = "";
    if ($attributed_to_type eq "person") { 
	
	my $p = CXGN::People::Person->new_person($dbh, $attributed_to_id);
	$attributed_name = $p->get_first_name()." ".$p->get_last_name();
    }
    elsif ($attributed_to_type eq "organization") { 
	my $p = CXGN::People::Organization->new($dbh, $attributed_to_id);
	$attributed_name = $p->get_name();
    }
    elsif ($attributed_to_type eq "project") { 
	my $p = CXGN::People::Project->new($dbh, $attributed_to_id);
	$attributed_name = $p->get_name();
    }

    my $q = "";
    if ($data_type eq "bac") { 
	my $schema = $dbh->qualify_schema("genomic");
	$q = "SELECT * FROM $schema.clone WHERE $schema.clone.clone_id=?";
    }
    if ($data_type eq "marker") { 
	my $schema = $dbh->qualify_schema("sgn");
	$q = "SELECT * FROM $schema.markers WHERE $schema.markers.marker_id=?";
    }
    my $sth = $dbh->prepare($q);
    $sth->execute($data_id);
    my ($hashref) = $sth->fetchrow_hashref();

    print qq { <div class="boxbgcolor2"><b>Database object</b><br /><br /> };
    foreach my $k (keys %$hashref) { 
	print "$k: $$hashref{$k}<br />\n" if (exists $$hashref{$k});
    }
    print "<br /></div><br />Attribute to : <br />";
    print "<b>$attributed_name</b><br /><br />";
    
    print <<HTML;
    <form>
<input type="hidden" name="role_id" value="$role_id" />
<input type="hidden" name="attributed_to_id" value="$attributed_to_id" />
<input type="hidden" name="attributed_to_type" value="$attributed_to_type" />
<input type="hidden" name="data_type" value="$data_type" />
<input type="hidden" name="data_id" value="$data_id" />
<input type="hidden" name="action" value="store" />

    <input type="submit" value="Store" /> 
    </form>

HTML
    
}

	
sub store { 
      my ($data_type, $data_id, $attributed_to_id, $attributed_to_type, $role_id) = @_;

      my $database_name="";
      my $table_name = "";
      
      if ($data_type eq "bac") { 
	  $database_name="genomic"; 
	  $table_name="clone";
      }
      elsif ($data_type eq "marker") { 
	  $database_name="sgn"; 
	  $table_name="markers";
      }
      my $person_id=undef;
      my $organization_id=undef;
      my $project_id=undef;
      
      if ($attributed_to_type eq "person") { 
	  $person_id = $attributed_to_id;
      }
      elsif ($attributed_to_type eq "organization") { 
	  $organization_id = $attributed_to_id;
      }
      elsif ($attributed_to_type eq "project") { 
	  $project_id=$attributed_to_id;
      }

      my $q = "SELECT attribution_id from metadata.attribution WHERE database_name=? AND table_name=? AND row_id=?";
      my $sth = $dbh->prepare($q);
      $sth->execute($database_name,$table_name, $data_id);
      my $attribution_id="";
      if ($attribution_id = ($sth->fetchrow_array())[0]) { 
	  print "The attribution is already in the database.\n";
	  
      }
      else { 
	  my $iq = "INSERT INTO metadata.attribution (database_name, table_name, row_id) VALUES (?, ?, ?)"; 

	  my $sth = $dbh->prepare($iq);
	  $sth->execute($database_name, $table_name, $data_id);
	  $attribution_id = $dbh->last_insert_id("attribution", "metadata");
      }

      my $q2 = "SELECT attribution_to_id FROM metadata.attribution_to WHERE 
                person_id=? AND organization_id =? AND project_id=?";

      my $sth2 = $dbh->prepare($q2);
      $sth2->execute($person_id, $organization_id, $project_id);

      my ($attributed_to_id) = ($sth2->fetchrow_array())[0];
      
      if (!$attributed_to_id) { 
	  my $iq2="INSERT INTO metadata.attribution_to (attribution_id, person_id, organiztion_id, project_id, role_id) VALUES (?, ?, ?, ?, ?)";


	  my $isth = $dbh->prepare($iq2);
	  $isth -> execute($attribution_id, $person_id, $organization_id, $project_id, $role_id);
      }
      else { 
	  print "The data object was already attributed to that entity in the database.";
      }
      print "All done!\n";
}
      

