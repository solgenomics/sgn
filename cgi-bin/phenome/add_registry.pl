use strict;
use warnings;

use CXGN::Scrap::AjaxPage;
use CXGN::DB::Connection;
use CXGN::Login;


my $dbh = CXGN::DB::Connection->new();

my ( $person_id, $user_type ) =
    CXGN::Login->new($dbh)->has_session();

if ( grep { /^$user_type$/ } ('curator', 'submitter', 'sequencer') ) {
    my $doc = CXGN::Scrap::AjaxPage->new();
    $doc->send_http_header();
    
    my $response = undef;
    
    my ($registry_symbol, $registry_name, $registry_description, $sp_person_id, $locus_id) = $doc->get_encoded_arguments('registry_symbol', 'registry_name', 'registry_description', 'sp_person_id', 'locus_id');
    
    
    print STDERR "registry symbol: $registry_symbol registry name: $registry_name\n";
   
    my %args = $doc->get_all_encoded_arguments();
    foreach my $key (keys %args) {
	print STDERR "hash key $key, value = " . $args{$key} . " \n\n";
    }
    
   
#query to make sure we can't insert 2 of the same registries. There is a constraint on the database but this is required to give user feedback
#I've changed the query to search only for existing registered symbols. There may be multiple symbols in the database, but users shouldn't be allowed to store more duplicates.   
    my $registry_exists = $dbh->prepare("SELECT symbol, name FROM phenome.registry WHERE symbol ilike ? ");
    $registry_exists->execute($registry_symbol);
    
    if(!$registry_exists->fetchrow_array()){
	my $registry_query = $dbh->prepare("INSERT INTO phenome.registry (symbol, name, description, sp_person_id, status) VALUES (?, ?, ?, ?, 'registered')");
	
	$registry_query->execute($registry_symbol, $registry_name, $registry_description, $sp_person_id);
	
	my $registry_id = $dbh->last_insert_id('registry', 'phenome');
	
	my $locus_registry_insert = $dbh->prepare("INSERT INTO phenome.locus_registry (locus_id, registry_id, sp_person_id) VALUES (?, ?, ?)");
	$locus_registry_insert->execute($locus_id, $registry_id, $sp_person_id);
	$response = "success";
    }
    
    else{
	$response = "already exists";
    }

    print "$response";
}
