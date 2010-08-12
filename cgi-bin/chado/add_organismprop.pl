use Bio::Chado::Schema;
use strict;
use warnings;
use JSON;
use CXGN::Scrap::AjaxPage;
use Try::Tiny;
use CXGN::Login;


my $dbh = $c->dbc->dbh;

my %status;
my $json = JSON->new();
my $doc = CXGN::Scrap::AjaxPage->new();

$doc->send_http_header();

my ( $person_id, $user_type ) =
    CXGN::Login->new($dbh)->has_session();

my ($species, $prop_name, $prop_value) = $doc->get_encoded_arguments("species", "prop_name", "prop_value");

#if (!$prop_name || !$prop_value) { die "Must pass prop_name and prop_value! \n"; }
    
    
if ( grep { /^$user_type$/ } ('curator', 'submitter', 'sequencer') ) {
    
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    
    try{
	my $org = $schema->resultset('Organism::Organism')->find({species=>$species});
	$org->create_organismprops({$prop_name=>$prop_value},{autocreate=>1});
	$status{"pass"} = "Success, the object was added to the table.";
	
    }catch{
	$status{"fail"} = "Error: The organism does not exist. Please select an organism from the suggestion list.";
    };
} else { 
    $status{"fail"} = 'You don\'t have the right privileges for adding a new organism to the sol100 project. Please contact sgn-feedback@solgenomics.net for more info.';
}
my $jobj = $json->encode(\%status);
print "$jobj";
