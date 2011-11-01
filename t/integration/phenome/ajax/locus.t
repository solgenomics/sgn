##tests for locus ajax functions 
## Naama Medna, Feb 2011

use Modern::Perl;

use lib 't/lib';
use Test::More;

use SGN::Test::Data qw/create_test/;
use SGN::Test::WWW::Mechanize skip_cgi => 1;

my $mech = SGN::Test::WWW::Mechanize->new();

my $dbh = $mech->context->dbc->dbh;
my $schema = $mech->context->dbic_schema('CXGN::Phenome::Schema');


# instantiate an new locus object and save to database
my $locus = $schema->resultset('Locus')->find_or_create(
    {
        locus_name => 'testing_locus_111222',
        locus_symbol => 'testing_111222',
        common_name_id=>1,
    });
# now we need a temp allele for this locus
my $allele = $locus->create_related('alleles' , {allele_symbol => 'test_allele111222' } );

my $locus_id = $locus->locus_id();
diag("created temporaty test locus  $locus_id");
my $term = 'testing';
$mech->get_ok("/ajax/locus/autocomplete?term=$term");


$mech->content_contains($term);
$mech->content_contains($locus->locus_name);
$mech->content_contains($locus->locus_symbol);

# delete test locus and allele objects we created
END {
    if( $mech && $locus_id  ) {
        my $write_dbh = $mech->context->dbc('sgn_test')->dbh;
        $write_dbh->do( "DELETE FROM phenome.$_ WHERE locus_id = ?", undef, $locus_id )
            for "allele", "locus";
    }
}


done_testing();

