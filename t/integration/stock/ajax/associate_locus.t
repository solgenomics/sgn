##tests for stock ajax functions
## Naama Medna, Feb 2011

## a simple test for the organism ajax functions
## Lukas Mueller, Jan 2011

use Modern::Perl;

use lib 't/lib';
use Test::More;
use SGN::Test::WWW::Mechanize;
use SGN::Test::Data  qw/create_test/;

my $mech = SGN::Test::WWW::Mechanize->new();


# instantiate a stock object and save to database
#

my $stock = create_test('Stock::Stock', {
    description => "LALALALA3475",
                        });
my $stock_id = $stock->stock_id;
$mech->get_ok('/ajax/stock/associate_locus');
$mech->content_contains('error');
$mech->content_contains('no allele found');

#try to add a locus while not logged in
my $schema = $mech->context->dbic_schema('CXGN::Phenome::Schema');

# instantiate an new locus object and save to database
my $locus = $schema->resultset('Locus')->find_or_create( 
    {
        locus_name => 'testing_locus_111224',
        locus_symbol => 'testing_111224',
        common_name_id=>1,
    });
# now we need a temp default allele for this locus
my $allele = $locus->find_or_create_related('alleles', {} );

my $locus_details = $locus->locus_name . " (".  $locus->locus_symbol . ")" ;
$mech->get_ok("/ajax/stock/associate_locus?object_id=$stock_id&loci=$locus_details");
$mech->content_contains('error');
$mech->content_contains('Must be logged');

# log in as a user. Still can't asociated locus

$mech->while_logged_in( { user_type=>'user' }, sub {
    $mech->get_ok("/ajax/stock/associate_locus?object_id=$stock_id&loci=$locus_details");
    $mech->content_contains('error');
    $mech->content_contains('No privileges');

                        } );
# log in as submitter

$mech->while_logged_in( { user_type=>'submitter' }, sub {
    $mech->get_ok("/ajax/stock/associate_locus?object_id=$stock_id&loci=$locus_details");
    $mech->content_contains('success');
    
# now check if the alleles are printed 
    $mech->get_ok("/stock/$stock_id/alleles");
    $mech->content_contains('html');
    $mech->content_contains($locus->locus_name);
# hard delete the temp locus and its allele object
    $locus->delete;
                        } );

done_testing();

