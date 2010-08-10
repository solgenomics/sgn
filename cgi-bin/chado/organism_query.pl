use Bio::Chado::Schema;
use strict;
use warnings;
use JSON;
use CXGN::Scrap::AjaxPage;

my $doc = CXGN::Scrap::AjaxPage->new();
$doc->send_http_header();

my ($species) = $doc->get_encoded_arguments("species");

my $json = JSON->new();

my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

my $org_rs = $schema->resultset("Organism::Organism")->search({species=>{'ilike'=>'%'.$species.'%'}});

my %species;

while (my $org = $org_rs->next){
    $species{$org->organism_id()}=$org->species();
}

my $jobj = $json->encode(\%species);
print "$jobj";
