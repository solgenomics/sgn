
#!/usr/bin/perl -w

use strict;
use warnings;

use CXGN::Scrap::AjaxPage;
use CXGN::Phenome::Locus;
use CXGN::Transcript::Unigene;
use CXGN::DB::Connection;
use CXGN::Login;
use CXGN::People::Person;
use CXGN::Feed;
use JSON;



my %error = ();
my $json = JSON->new();

my $dbh = CXGN::DB::Connection->new();
my $doc = CXGN::Scrap::AjaxPage->new();
$doc->send_http_header();

my ($type, $locus_id, $unigene_id, $sp_person_id, $locus_unigene_id) = $doc->get_encoded_arguments("type", "locus_id", "unigene_id", "sp_person_id", "locus_unigene_id");

my $locus= CXGN::Phenome::Locus->new($dbh, $locus_id);

$unigene_id =~/(\d+)/;
$unigene_id =$1;
$unigene_id =~ s/\s//;
my $unigene_link = qq |http://www.sgn.cornell.edu/search/unigene.pl?unigene_id=SGN-U$unigene_id|;

my($login_person_id, $login_user_type)=CXGN::Login->new($dbh)->verify_session();

if ($login_user_type eq 'curator' || $login_user_type eq 'submitter' || $login_user_type eq 'sequencer') {
    
    my $person= CXGN::People::Person->new($dbh, $login_person_id);
    my $user=$person->get_first_name()." ".$person->get_last_name();
    my $user_link = qq |http://www.sgn.cornell.edu/solpeople/personal-info.pl?sp_person_id=$sp_person_id|;
    
    if (length($unigene_id)>1) {
	if ($type eq 'associate') {
	    eval {
		my $id = $locus->add_unigene($unigene_id, $sp_person_id);
	    };
	    
	    if ($@) { 
		$error{"error"} =  $@;
		CXGN::Contact::send_email('unigene_browser.pl died',"locus-unigene association failed (locus_id = $locus_id, unigene_id = $unigene_id , person_id = $sp_person_id . $@", 'sgn-bugs@sgn.cornell.edu');
	    }
	    else  { 
		my $subject="[New unigene associated] locus $locus_id";
		my $fdbk_body="$user ($user_link) has associated\n unigene $unigene_link\n with locus http://www.sgn.cornell.edu/phenome/locus_display.pl?locus_id=$locus_id"; 
		CXGN::Contact::send_email($subject,$fdbk_body, 'sgn-db-curation@sgn.cornell.edu');
		CXGN::Feed::update_feed($subject,$fdbk_body);
	    }
	}
	
	elsif ($type eq 'browse') {
	    
	    my $organism = $locus->get_common_name();
	    my $unigene = CXGN::Transcript::Unigene->new($dbh, $unigene_id);
	    my $available_unigenes = "";
	    
	    if (defined($unigene)) { 
		my $build_nr = $unigene->get_build_nr();
		my $nr_members = $unigene->get_nr_members();
		my $unigene_build = $unigene->get_unigene_build();
		my $unigene_organism = $unigene_build->get_common_name();
		my $build_status = $unigene_build->get_status();
		
		if (($unigene_organism eq $organism) && ($build_status eq "C")) {
		    
		    $available_unigenes .="$unigene_id*$unigene_id -- $unigene_organism -- build $build_nr -- $nr_members members|";
		    $error{"response"} = $available_unigenes;
		}
	    }
	}
    }elsif ($locus_unigene_id && $type eq 'obsolete') {
	
	eval { 
	    $locus->obsolete_unigene($locus_unigene_id);
	};
	
	if ($@) {
	    $error{"error"} =  $@;
	    CXGN::Contact::send_email('unigene_browser.pl died',"Obsoleting unigene faild. $@", 'sgn-bugs@sgn.cornell.edu');
	}else {  
	    $error{"response"} = "Obsoleting locus_unigene $locus_unigene_id succeeded!";
	    my $subject="[Locus-unigene obsoleted] locus $locus_id";
	    my $fdbk_body="$user ($user_link) has obsoleted\n unigene $unigene_link\n link from locus http://www.sgn.cornell.edu/phenome/locus_display.pl?locus_id=$locus_id"; 
	    CXGN::Contact::send_email($subject,$fdbk_body, 'sgn-db-curation@sgn.cornell.edu');
	    CXGN::Feed::update_feed($subject,$fdbk_body);
	}
    }
    
    my $jobj = $json->encode(\%error);
    print $jobj;
}


