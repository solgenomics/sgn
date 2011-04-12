##tests for stock ajax functions
## Naama Medna, April 2011

## Test a function for fetching stocks annotated with a cvterm , or any of its recursive child terms

use Modern::Perl;
use lib 't/lib';
use Test::More;
use SGN::Test::WWW::Mechanize;

my $mech = SGN::Test::WWW::Mechanize->new();
$mech->with_test_level( local => sub {
    my $schema = $mech->context->dbic_schema('Bio::Chado::Schema' , 'sgn_chado');
    # instantiate a cvterm object #
    # 'flower color'
    my $db_name = 'SP';
    my $accession = '0000009';
    my $cvterm = $schema->resultset("General::Db")->search( { 'me.name' => $db_name } )->
        search_related('dbxrefs', { accession => $accession} )->
        search_related('cvterm')->first;
    my $cvterm_id = $cvterm->cvterm_id;
    $mech->get_ok('/ajax/cvterm/recursive_stocks?cvterm_id='.$cvterm_id);
    $mech->content_contains('html');
    $mech->content_contains('Stock name');
});
done_testing();




