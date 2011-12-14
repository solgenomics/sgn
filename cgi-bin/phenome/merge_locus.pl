use strict;
use warnings;

use CXGN::Scrap::AjaxPage;
use CXGN::Login;
use CXGN::People::Person;
use CXGN::Phenome::Locus;
use CXGN::Feed;
use CXGN::Contact;
use CatalystX::GlobalContext '$c';

use JSON;

my %error = ();
my $json = JSON->new();

my $dbh = $c->dbc->dbh;
my($login_person_id,$login_user_type)=CXGN::Login->new($dbh)->verify_session();

#print STDERR "merge_locus.pl:login_person_id= $login_person_id\n";

if ($login_user_type eq 'curator') {
    my $doc = CXGN::Scrap::AjaxPage->new();
    $doc->send_http_header();
    my ($merged_locus_id, $locus_id) = $doc->get_encoded_arguments("merged_locus_id", "locus_id");
    print STDERR "merge_locus.pl:merged_locus_id=$merged_locus_id, locus_id = $locus_id\n ";

    my $locus= CXGN::Phenome::Locus->new($dbh, $locus_id);
    
    if ($merged_locus_id && $locus_id ) {
	
	my $fail = $locus->merge_locus($merged_locus_id, $login_person_id);
   
	if ($fail) { 
	    warn "merging locus  failed! . $fail";
	    my $message=  "merging locus failed!\n $fail ";
	    CXGN::Contact::send_email('Merging locus failed' ,$message, 'sgn-bugs@sgn.cornell.edu');
	    $error{"error"} =  $message;
	   
	}
    
	else  { 
	    $error{reload} = 1;
	    my $subject="[New locus merged] locus $locus_id";
	    my $person= CXGN::People::Person->new($dbh, $login_person_id);
	    my $user=$person->get_first_name()." ".$person->get_last_name();
	    my $user_link = qq |http://www.sgn.cornell.edu/solpeople/personal-info.pl?sp_person_id=$login_person_id|;
	    my $locus_link = qq |http://www.sgn.cornell.edu/phenome/locus_display.pl?locus_id=$locus_id|;
	   
	    my $fdbk_body="curator $user ($user_link) merged locus $merged_locus_id with locus $locus_id ($locus_link) \n ";
	    CXGN::Contact::send_email($subject,$fdbk_body, 'sgn-db-curation@sgn.cornell.edu');
	    CXGN::Feed::update_feed($subject,$fdbk_body);
	}
    }
    my $jobj = $json->encode(\%error);
    print  $jobj;
}


