##tests for stock ajax functions
## Naama Medna, April 2011

## Test a function for fetching populations *phenotyped* with a cvterm 

use Modern::Perl;
use lib 't/lib';
use Test::More;
use SGN::Test::WWW::Mechanize;

my $mech = SGN::Test::WWW::Mechanize->new();
my $schema = $mech->context->dbic_schema('Bio::Chado::Schema' , 'sgn_chado');

# instantiate a cvterm object #
#
my $db_name = 'SP';
my $accession = '0000139';
my $cvterm = $schema->resultset("General::Db")->search( { 'me.name' => $db_name } )->
    search_related('dbxrefs', { accession => $accession} )->
    search_related('cvterm')->first;

my $cvterm_id = $cvterm->cvterm_id;
$mech->get_ok('/ajax/cvterm/phenotyped_stocks?cvterm_id='.$cvterm_id);
$mech->content_contains('html');

$mech->content_contains('QTL');

done_testing();




