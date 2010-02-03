use strict;
use warnings;

use CXGN::Scrap::AjaxPage;
use CXGN::Login;
#use JSON;

my $doc = CXGN::Scrap::AjaxPage->new();
$doc->send_http_header();
my ($individual_name, $locus_id, $type, $individual_allele_id, $allele_id) = $doc->get_encoded_arguments("individual_name", "locus_id", "type", "individual_allele_id", "allele_id");
print STDERR "my args are: $individual_name, $locus_id, $type, $individual_allele_id, $allele_id \n\n\n";
my $dbh = CXGN::DB::Connection->new();

my($login_person_id, $login_user_type)=CXGN::Login->new($dbh)->verify_session();

if ($login_user_type eq 'curator' || $login_user_type eq 'submitter' || $login_user_type eq 'sequencer') {

    if ($type eq 'browse') {
	my $individual_query = $dbh->prepare("SELECT individual_id, name, description FROM phenome.individual 
                                      WHERE individual_id NOT IN (SELECT individual_id FROM phenome.individual JOIN
                                      phenome.individual_allele USING(individual_id) JOIN phenome.allele USING(allele_id)
                                      WHERE locus_id = ? AND individual_allele.obsolete = 'f')
                                     AND  individual.name ilike '%$individual_name%'
                                    ");
	$individual_query->execute($locus_id);
	
	my ($individual_id, $name, $desc) = $individual_query->fetchrow_array();
	my $available_individuals;
	
	while($individual_id){
	    $available_individuals .= "$individual_id*$name--$desc|";
	    ($individual_id, $name, $desc) = $individual_query->fetchrow_array();
	}
	
	print "$available_individuals";
    }
    #search from the allele page. Fiter only the existing individuals associated with $allele.
    elsif ($type eq 'browse_allele') { 
		my $individual_query = $dbh->prepare("SELECT individual_id, name, description FROM phenome.individual 
                                      WHERE individual_id NOT IN (SELECT individual_id FROM phenome.individual JOIN
                                      phenome.individual_allele USING(individual_id)
                                      WHERE allele_id = ? AND individual_allele.obsolete = 'f')
                                     AND  individual.name ilike '%$individual_name%'
                                    ");
	$individual_query->execute($allele_id);
	
	my ($individual_id, $name, $desc) = $individual_query->fetchrow_array();
	my $available_individuals;
	
	while($individual_id){
	    $available_individuals .= "$individual_id*$name--$desc|";
	    ($individual_id, $name, $desc) = $individual_query->fetchrow_array();
	}
	
	print "$available_individuals";
	
    }
    #obsolete individual-allele association
    elsif ($type eq 'obsolete') {
	eval { 
	    my $query = "UPDATE phenome.individual_allele SET obsolete='t', modified_date= now() WHERE individual_allele_id = ? ";
	    my $sth= $dbh->prepare($query);
	    
	    $sth->execute($individual_allele_id);
	};
	
	if ($@) {
	    warn "individual-allele obsoletion failed! "#$page->message_page("An error occurred during the database operation");
	}
    }


}
