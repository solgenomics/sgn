use strict;
use warnings;

use CXGN::Scrap::AjaxPage;
use CXGN::DB::Connection;
use CXGN::Login;
use CXGN::Phenome::Locus;
use CXGN::Feed;

my $dbh = CXGN::DB::Connection->new();
my($login_person_id,$login_user_type)=CXGN::Login->new($dbh)->verify_session();

if ($login_user_type eq 'curator' || $login_user_type eq 'submitter' || $login_user_type eq 'sequencer') {

    
    my $doc = CXGN::Scrap::AjaxPage->new();
    my ($locus_id, $unigene_id, $sp_person_id) = $doc->get_encoded_arguments("locus_id", "unigene_id", "sp_person_id");
    
    eval {
	my $locus=CXGN::Phenome::Locus->new($dbh, $locus_id);
	$locus->add_unigene($unigene_id, $sp_person_id);
	
    };
    if ($@) { warn "locus-unigene association failed! (locus_id= $locus_id, unigene_id=$unigene_id person_id=$sp_person_id)"; }
    else  { 
	
	my $subject="[New unigene associated] locus $locus_id";
	#my $username= $self->get_user()->get_first_name()." ".$self->get_user()->get_last_name();
   	my $fdbk_body="user $login_person_id has associated unigene $unigene_id with locus $locus_id  \n "; 
        CXGN::Contact::send_email($subject,$fdbk_body, 'sgn-db-curation@sgn.cornell.edu');
	CXGN::Feed::update_feed($subject,$fdbk_body);
    }
}
