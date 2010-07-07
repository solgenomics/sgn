use Bio::Chado::Schema;
use strict;
use warnings;
use JSON;
use CXGN::Scrap::AjaxPage;
use Try::Tiny;

my $json = JSON->new();

my $doc = CXGN::Scrap::AjaxPage->new();
$doc->send_http_header();

my ($species) = $doc->get_encoded_arguments("species");

my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

my %status;

try{

print STDERR "In the beginning of the catch block\n\n"; 
    my $org = $schema->resultset('Organism::Organism')->find({species=>$species});
    $org->create_organismprops({'sol100'=>'1'},{autocreate=>1});
    $status{"pass"} = "Success, the object was added to the table.";

}catch{
    $status{"fail"} = "Error: The organism does not exist. Please select an organism from the suggestion list.";

};

my $jobj = $json->encode(\%status);
print "$jobj";
