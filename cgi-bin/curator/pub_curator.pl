use strict;
use warnings;

use CXGN::Scrap::AjaxPage;
use CXGN::DB::Connection;
use CXGN::Login;
use CXGN::People::Person;
use CXGN::Chado::Publication;
use CXGN::Feed;
use JSON;

my $dbh = CXGN::DB::Connection->new();
my($login_person_id,$login_user_type)=CXGN::Login->new($dbh)->verify_session();

if ($login_user_type eq 'curator' || $login_user_type eq 'submitter' || $login_user_type eq 'sequencer') {

    
    my $doc = CXGN::Scrap::AjaxPage->new();
    my ($pub_id, $stat, $curator_id, $action) = $doc->get_encoded_arguments("pub_id", "stat", "curator_id", "action");
    my $pub=CXGN::Chado::Publication->new($dbh, $pub_id);
    my %error = ();
 
    my $json = JSON->new();
    #Assign a new curator
    if ($action eq 'assign_curator') {
	$error{"error"} = "Storing pub_curator works!";
	eval {
	    $pub->set_curator_id($curator_id);
	    $pub->store_pub_curator();
	};
	if ($@) {
	    $error{"error"} = $@; 
	}
	
	my $jobj = $json->objToJson(\%error);
	print STDERR "JSON FORMAT: $jobj\n";

        print "Content-Type: text/plain\n\n";
	print  $jobj;
	
    #Change the pub_curator status	
    } elsif ($action eq 'change_stat') {
	$error{"error"} = "Updating pub_curator status to $stat!";
	eval {
	    
	    $pub->set_status($stat);
	    $pub->set_curated_by($login_person_id);
	    $pub->store_pub_curator();
	    
	};
	if ($@) { 
	    $error{"error"} = $@; 
	    warn "pub_curator update failed! (pub_id= $pub_id, status=$stat, assigned_curator=$curator_id,  login_person_id=$login_person_id)"; }
	else  { 
	    
	    #my $subject="[New pub_curator info stored] pub $pub_id";
	    #my $username= $self->get_user()->get_first_name()." ".$self->get_user()->get_last_name();
	    #my $fdbk_body="user $login_person_id has updated pub_curator status =$stat.  \n "; 
	    #CXGN::Contact::send_email($subject,$fdbk_body, 'sgn-db-curation@sgn.cornell.edu');
	    #CXGN::Feed::update_feed($subject,$fdbk_body);
	}
	my $jobj = $json->objToJson(\%error);
	print STDERR "JSON FORMAT: $jobj\n";
	
        print "Content-Type: text/plain\n\n";
	print  $jobj;
    }
}
