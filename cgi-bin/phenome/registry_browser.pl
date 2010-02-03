use strict;
use warnings;

use CXGN::Scrap::AjaxPage;

my $doc = CXGN::Scrap::AjaxPage->new();
$doc->send_http_header();
my ($registry_name) = $doc->get_encoded_arguments("registry_name");

my $dbh = CXGN::DB::Connection->new();

my $registry_query = $dbh->prepare("SELECT registry_id, symbol, name FROM phenome.registry WHERE symbol ilike '$registry_name%' OR name ilike '%$registry_name%'");
$registry_query->execute();

my ($registry_id, $symbol, $name) = $registry_query->fetchrow_array();
my $available_registers;

while($symbol){
    $available_registers .= "$registry_id*$symbol--$name|";
    ($registry_id, $symbol, $name) = $registry_query->fetchrow_array();
}

print "$available_registers";
