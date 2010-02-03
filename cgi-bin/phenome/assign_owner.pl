use strict;
use warnings;

use CXGN::Scrap::AjaxPage;
use CXGN::Login;
use CXGN::People::Person;
use CXGN::Feed;

my $dbh = CXGN::DB::Connection->new();
my($login_person_id,$login_user_type)=CXGN::Login->new($dbh)->verify_session();

if ($login_user_type eq 'curator') {
    my $doc = CXGN::Scrap::AjaxPage->new();
    $doc->send_http_header();
    my ($user_info, $object_type, $object_id, $sp_person_id) = $doc->get_encoded_arguments("user_info", "object_type", "object_id", "sp_person_id");
    

    
    #query for retreiving user information
    if ($user_info) {
	#print STDERR "getting user info $user_info...\n " ;
	my $user_query = $dbh->prepare("SELECT sp_person_id, first_name, last_name, user_type FROM sgn_people.sp_person 
                                     WHERE (first_name ilike '%$user_info%' OR last_name ilike '%$user_info%')
                                     ORDER BY last_name
                                    ");
	$user_query->execute();
	
	my ($sp_person_id, $first_name, $last_name, $user_type) = $user_query->fetchrow_array();
	my $users;
	
	while($first_name){
	    $users .= "$sp_person_id*$last_name, $first_name [$user_type]|";
	    ($sp_person_id, $first_name, $last_name, $user_type) = $user_query->fetchrow_array();
	}
	
	print "$users";
	
    }
    
    #setting the new object owner. Only curators can do this.
    #if the user has a 'user' account it will be updated to a 'submitter' first
    if ($object_type && $object_id ) {
	print STDERR "assigning owner : $object_type, $object_id .. sp_person_id = $sp_person_id ... \n";
	my $new_user_type= CXGN::People::Person->new($dbh, $sp_person_id)->get_user_type();
	
	eval{
	    
	    if ($new_user_type eq 'user' || !$new_user_type) {
		my $user_query = $dbh->prepare("UPDATE sgn_people.sp_person SET user_type ='submitter'
                                        WHERE sp_person_id= ?");
		$user_query->execute($sp_person_id);
	    }
	    my $query;
	    if ($object_type eq 'locus') {
		$query = $dbh->prepare("INSERT INTO phenome.locus_owner (sp_person_id, locus_id, granted_by)
                                        VALUES (?,?,?)");
		$query->execute($sp_person_id, $object_id, $login_person_id);
		
		#if the current owner of the locus is a logged-in SGN curator, do an obsolete..
		if ($login_user_type eq 'curator') {
		    my $remove_curator_query="UPDATE phenome.locus_owner SET obsolete='t', modified_date= now() 
                                          WHERE locus_id=? AND sp_person_id IN (SELECT sp_person_id FROM sgn_people.sp_person WHERE user_type = 'curator')";
		    my $remove_curator_sth=$dbh->prepare($remove_curator_query);
		    $remove_curator_sth->execute($object_id);
		}
		
	    }elsif ($object_type eq 'individual') {
		$query = $dbh->prepare("UPDATE phenome.individual SET sp_person_id= ?
                                         WHERE indvidual_id= ?");
		$query->execute($sp_person_id, $object_id); 
		
	    }else {exit() ; }   
	    
	};
	
	
	if ($@) { 
	    warn "assigning locus owner failed! . $@";
	    my $message=  "assigning locus owner failed! $@";
	    return $message;
            #my $content = "MochiKit.Logging.logDebug(\"$message\");\n";
	}
    
	else  { 
	    my $subject="[New locus owner assigned] $object_type $object_id";
	    my $person= CXGN::People::Person->new($dbh, $login_person_id);
	    my $user=$person->get_first_name()." ".$person->get_last_name();
	    my $user_link = qq |http://www.sgn.cornell.edu/solpeople/personal-info.pl?sp_person_id=$login_person_id|;
	    my $locus_link = qq |http://www.sgn.cornell.edu/phenome/locus_display.pl?locus_id=$object_id|;
	    my $owner= CXGN::People::Person->new($dbh, $sp_person_id);
	    my $owner_name=$owner->get_first_name()." ".$owner->get_last_name();
	    my $owner_link = qq |http://www.sgn.cornell.edu/solpeople/personal-info.pl?sp_person_id=$sp_person_id|;
	    my $fdbk_body="curator $user ($user_link) has assigned a new owner ($owner_name, $owner_link) for $object_type $locus_link \n ";
	    CXGN::Contact::send_email($subject,$fdbk_body, 'sgn-db-curation@sgn.cornell.edu');
	    CXGN::Feed::update_feed($subject,$fdbk_body);
	}
 
    }
}


