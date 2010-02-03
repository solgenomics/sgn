use strict;
use warnings;

use CXGN::Scrap::AjaxPage;
use CXGN::DB::Connection;
use CXGN::Login;
use CXGN::Contact;
use CXGN::People::Person;


use CXGN::Phenome::Locus;
use CXGN::Chado::Cvterm;
use CXGN::Feed;

use JSON;


my $doc = CXGN::Scrap::AjaxPage->new();
$doc->send_http_header();
my %response = ();
my $json = JSON->new();

my ($locus_id) = $doc->get_encoded_arguments("locus_id");

my $dbh = CXGN::DB::Connection->new();
my ($login_person_id, $login_user_type)=CXGN::Login->new($dbh)->verify_session();

if ($login_user_type eq 'curator' || $login_user_type eq 'submitter' || $login_user_type eq 'sequencer') {

    
    if ($locus_id) {
	my $jobj;
	my $available_cvterms;
	eval{
	    my $locus = CXGN::Phenome::Locus->new($dbh, $locus_id);
	   	    
	    my $locus_pub_ranks=$locus->get_locus_pub(); # this sets cvterm_ranks
	    my $cvterm_total_ranks=$locus->get_cvterm_ranks();
	    
	    my @sorted_cvterms = sort{$cvterm_total_ranks->{$b} <=> $cvterm_total_ranks->{$a}} keys %$cvterm_total_ranks;
	    foreach my $cvterm_id (@sorted_cvterms) { 
		my $rank= $cvterm_total_ranks->{$cvterm_id};
		my $cvterm=CXGN::Chado::Cvterm->new($dbh, $cvterm_id);
		my $dbxref_id=$cvterm->get_dbxref_id();
		my $db_name=$cvterm->get_db_name();
		my $cv_name=$cvterm->get_cv_name();
		my $accession= $cvterm->get_accession();
		my $cvterm_name= $cvterm->get_cvterm_name();
		
		$available_cvterms .="$dbxref_id*$cv_name:$db_name:$accession--$cvterm_name ($rank)|";
		$response{$dbxref_id}= "$cv_name:$db_name:$accession--$cvterm_name ($rank)";
	    }
	    
	};
    	if ($@) { 
	    $response{"error"} = "get_locus_cvterms  failed! " . $@;
	}
	$jobj = $json->objToJson(\%response); # replaced by 'encode' but not on the old version of JSON in Rubisco! 
	#print STDERR $jobj;
	print $jobj;
    }
}        
