use strict;
use warnings;

use CXGN::Scrap::AjaxPage;
use CXGN::DB::Connection;
use CXGN::Login;
use CXGN::Contact;
use CXGN::People::Person;

use CXGN::Phenome::LocusgroupMember;
use CXGN::Phenome::Locus;
use CXGN::Chado::Cvterm;
use CXGN::Feed;
use CXGN::Tools::Organism;

use JSON;


my $doc = CXGN::Scrap::AjaxPage->new();
$doc->send_http_header();

my ($type, $locus_name, $object_id, $organism, $subject_id,  $relationship_id, $evidence_id, $reference_id, $lgm_id) = $doc->get_encoded_arguments("type", "locus_name", "object_id", "organism", "locus_id", "locus_relationship_id", "locus_evidence_code_id", "locus_reference_id", "lgm_id");



my $dbh = CXGN::DB::Connection->new();
my $schema=  $c->dbic_schema('CXGN::Phenome::Schema');

my ($login_person_id, $login_user_type)=CXGN::Login->new($dbh)->verify_session();

if ($login_user_type eq 'curator' || $login_user_type eq 'submitter' || $login_user_type eq 'sequencer') {

    if ($type eq 'organism') {
        my ($organism_names_ref, $organism_ids_ref)=CXGN::Tools::Organism::get_existing_organisms($dbh);
	my $list;
	foreach (@$organism_names_ref) {
	    $list .=  "$_|";
	}
	print $list;
    }
    
    if ($type eq 'browse locus') {
	
	if (!$organism) {  ($locus_name, $organism) = split(/,\s*/,  $locus_name); }
	
	$locus_name =~ /(\w+)/;
	$locus_name =$1;
	if (($locus_name) && ($organism)) {
	    
	    my $locus_query = "SELECT locus_id, locus_symbol, locus_name, common_name FROM phenome.locus 
                                   JOIN sgn.common_name USING (common_name_id) 
                                   WHERE (locus_symbol ILIKE '$locus_name%' OR locus_name ILIKE '%$locus_name%') AND (locus_id != $object_id) AND (common_name ILIKE '$organism%') AND locus.obsolete='f'"; 
   

	    my $sth = $dbh->prepare($locus_query);
	    
	    $sth->execute();
	    
	    
	    my ($obj_id, $symbol, $name, $obj_organism) = $sth->fetchrow_array();
	    my $available_loci;
	    
	    
	    while($symbol) {
		
		
		$available_loci .= "$obj_id*$obj_organism -- $symbol -- $name|";
		($obj_id, $symbol, $name, $obj_organism) = $sth->fetchrow_array();
	    }
	    
	    print "$available_loci";
	    
	}
    }
    
    
    ##############the following is used in locus2locus association
    elsif ($type eq 'locus_relationship') {
	
	my $locusrelationship_query = $dbh->prepare("SELECT distinct(cvterm.cvterm_id), cvterm.name 
                                       FROM public.cvterm 
                                       JOIN public.cv USING (cv_id) 
                                       WHERE cv.name ='Locus Relationship' AND
                                       cvterm.is_obsolete = 0; 
                                      ");
	$locusrelationship_query->execute();
	
	my ($cvterm_id, $cvterm_name) = $locusrelationship_query->fetchrow_array();
	my $available_locusrelationships;
	
	while($cvterm_name){
	    $available_locusrelationships .= "$cvterm_id*$cvterm_name|";
	    ($cvterm_id, $cvterm_name) = $locusrelationship_query->fetchrow_array();    
	}
	
	print "$available_locusrelationships";
    }
##################

    elsif ($type eq 'locus_evidence_code') {
	
	my $evidence_code_query = $dbh->prepare("SELECT distinct(cvterm.cvterm_id), cvterm.name 
                                       FROM public.cvterm_relationship
                                       
                                      JOIN public.cvterm ON (cvterm.cvterm_id= cvterm_relationship.subject_id)
                                       WHERE
                                       object_id= (select cvterm_id from cvterm where name = 'evidence_code') AND
                                       cvterm.is_obsolete = 0 
                                       ORDER BY cvterm.name;
                                      ");
	$evidence_code_query->execute();
	
	my ($cvterm_id, $cvterm_name) = $evidence_code_query->fetchrow_array();
	my $available_evidence_codes;
	
	while($cvterm_name){
	    $available_evidence_codes.= "$cvterm_id*$cvterm_name|";
	    ($cvterm_id, $cvterm_name) = $evidence_code_query->fetchrow_array();    
	}
	
	
	print "$available_evidence_codes";
    }
    
    
    
    
    elsif ($type eq 'locus_reference') {
	
	my $reference_query = $dbh->prepare("SELECT dbxref.dbxref_id, accession, title 
                                          FROM public.dbxref 
                                          JOIN pub_dbxref USING (dbxref_id)
                                          JOIN pub USING (pub_id)
                                          JOIN phenome.locus_dbxref USING (dbxref_id)
                                          WHERE locus_id= ? 
                                          AND phenome.locus_dbxref.obsolete = 'f'" 
					    );
	$reference_query->execute($object_id);
	
	my ($dbxref_id, $accession, $title) = $reference_query->fetchrow_array();
	my $available_reference=undef;
	
	while($accession){
	    $available_reference .= "$dbxref_id*$accession: $title|";
	    ($dbxref_id, $accession, $title) = $reference_query->fetchrow_array();
	}
	
	print "$available_reference";
	
    }
    
    
    elsif ($type eq 'associate locus') {
	my %error = ();
	my $json = JSON->new();
	
	
	eval {
	    my $cvterm=CXGN::Chado::Cvterm->new($dbh, $relationship_id);
	    my $relationship=$cvterm->get_cvterm_name();
	
	    if (!$reference_id) {$reference_id = undef};
	    
	    my %directional_rel = 
		('Downstream'=>1,
		 'Inhibition'=>1,
		 'Activation'=>1
		);
	    my $directional= $directional_rel{$relationship};
	    
	    my $lgm=CXGN::Phenome::LocusgroupMember->new($schema);
	    $lgm->set_locus_id($subject_id);
	    $lgm->set_evidence_id($evidence_id);
	    $lgm->set_reference_id($reference_id);
	    $lgm->set_sp_person_id($login_person_id);
	    
	    my $a_lgm=CXGN::Phenome::LocusgroupMember->new($schema);
	    $a_lgm->set_locus_id($object_id);
	    $a_lgm->set_evidence_id($evidence_id);
	    $a_lgm->set_reference_id($reference_id);
	    $a_lgm->set_sp_person_id($login_person_id);
	    
	    if ($directional) { 
		$lgm->set_direction('subject');
		$a_lgm->set_direction('object')
	    }
	    
	    my $locusgroup= $lgm->find_or_create_group($relationship_id, $a_lgm);
 	    my $lg_id= $locusgroup->get_locusgroup_id();
	    $lgm->set_locusgroup_id($lg_id);
	    $a_lgm->set_locusgroup_id($lg_id);
	    
	    my $lgm_id= $lgm->store();
	    my $algm_id=$a_lgm->store();
	    
	    $error{"response"} = "Associated locus $subject_id ($relationship) with locus $object_id!";
	};
	if ($@) { 
	    $error{"error"} = "Associateing locus $subject_id  with locus $object_id  failed! " . $@; 
	    CXGN::Contact::send_email('locus_browser.pl died',$error{"error"}, 'sgn-bugs@sgn.cornell.edu');
	    
	}else  {
	    
	    my $person = CXGN::People::Person->new($dbh, $login_person_id);
	    
	    
	    my $user_link = qq |http://www.sgn.cornell.edu/solpeople/personal-info.pl?sp_person_id=$login_person_id |;
	    my $subject_locus_link= qq |http://www.sgn.cornell.edu/phenome/locus_display.pl?locus_id=$subject_id |;
	    my $object_locus_link= qq |http://www.sgn.cornell.edu/phenome/locus_display.pl?locus_id=$object_id |;
	    my $subject="[New locus2locus association created]";
	    my $username= $person->get_first_name()." ".$person->get_last_name();
	    my $fdbk_body="$username ($user_link) has associated locus $object_locus_link  \n to locus $subject_locus_link \n "; 
	    
	    CXGN::Contact::send_email($subject,$fdbk_body, 'sgn-db-curation@sgn.cornell.edu');
	    CXGN::Feed::update_feed($subject,$fdbk_body);
	}
	
	my $jobj = $json->objToJson(\%error); # replaced by 'encode' but not on the old version of JSON in Rubisco! 

	print STDERR "JSON FORMAT: $jobj\n";
	
	print  $jobj;
	
#########
    }   
    elsif ($type eq 'obsolete') {
	my %error = ();
	my $json = JSON->new();
	
	my $lgm=CXGN::Phenome::LocusgroupMember->new($schema, $lgm_id);
	eval {
	    $lgm->obsolete_lgm();
	};
	
	if ($@) {
	    $error{"error"} = "Obsoleting locus group member $lgm_id failed! " . $@;
	    CXGN::Contact::send_email('locus_browser.pl died',$error{"error"}, 'sgn-bugs@sgn.cornell.edu');
	    
	}else {
	    $error{"response"} = "Obsoleting locus group member $lgm_id succeeded!";
		    
	    my $person = CXGN::People::Person->new($dbh, $login_person_id);
	    
	    my $user_link = qq |http://www.sgn.cornell.edu/solpeople/personal-info.pl?sp_person_id=$login_person_id |;
	    
	    my $subject="[A locus group member has been obsoleted]";
	    my $username= $person->get_first_name()." ".$person->get_last_name();
	    my $fdbk_body="$username ($user_link) has obsoleted locus group member $lgm_id \n "; 
	    
	    CXGN::Contact::send_email($subject,$fdbk_body, 'sgn-db-curation@sgn.cornell.edu');
	    CXGN::Feed::update_feed($subject,$fdbk_body);
	}
	my $jobj = $json->objToJson(\%error);
	print STDERR "JSON FORMAT: $jobj\n";
	
	print  $jobj;
	
    }
}
