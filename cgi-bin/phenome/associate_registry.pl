use strict;
use warnings;

use CXGN::Scrap::AjaxPage;
use CXGN::DB::Connection;
use CXGN::Login;
use CXGN::Feed;

my $dbh = CXGN::DB::Connection->new();
my($login_person_id,$login_user_type)=CXGN::Login->new($dbh)->verify_session();

if ($login_user_type eq 'curator' || $login_user_type eq 'submitter') {

    
    my $doc = CXGN::Scrap::AjaxPage->new();
    my ($locus_id, $registry_id, $sp_person_id) = $doc->get_encoded_arguments("locus_id", "registry_id", "sp_person_id");
    
    eval {
	my $registry_query = $dbh->prepare("INSERT INTO phenome.locus_registry (locus_id, registry_id, sp_person_id) VALUES (?, ?, ?)");
	
	$registry_query->execute($locus_id, $registry_id, $sp_person_id);
    };
    if ($@) { warn "locus-registry association failed!"; }
    else  { 
	
	my $subject="[New registry associated] locus $locus_id";
   	my $fdbk_body="user $login_person_id has associated registry $registry_id with locus $locus_id  \n "; 
        CXGN::Contact::send_email($subject,$fdbk_body, 'sgn-db-curation@sgn.cornell.edu');
	CXGN::Feed::update_feed($subject,$fdbk_body);
    }
}






