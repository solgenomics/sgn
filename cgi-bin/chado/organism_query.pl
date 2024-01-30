use Bio::Chado::Schema;
use strict;
use warnings;
use JSON;
use CXGN::Scrap::AjaxPage;

use CatalystX::GlobalContext '$c';

my $doc = CXGN::Scrap::AjaxPage->new();
$doc->send_http_header();

my ($species) = $doc->get_encoded_arguments("species");

my $json = JSON->new();

my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $sp_person_id);

my $org_rs = $schema->resultset("Organism::Organism")->search({species=>{'ilike'=>'%'.$species.'%'}});

my %species;

while (my $org = $org_rs->next){
    $species{$org->organism_id()}=$org->species();
}

my $jobj = $json->encode(\%species);
print "$jobj";
