##tests for locus ajax functions 
## Naama Medna, Feb 2011

use Modern::Perl;

use lib 't/lib';
use Test::More;


BEGIN { $ENV{SGN_SKIP_CGI} = 1 } #< can skip compiling cgis, not using them here
use SGN::Test::Data qw/create_test/;
use SGN::Test::WWW::Mechanize;


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

#$allele->delete;
#$locus->delete;
# hard delete the temp locus and its allele object
#
my @queries = ("DELETE FROM phenome.allele WHERE locus_id = ?", "DELETE FROM phenome.locus WHERE locus_id=?");
foreach my $q (@queries)  {
    my $sth = $dbh->prepare($q);
    my $success = $sth->execute($locus_id);
    ok($success, "Hard delete of temp locus $locus_id test object ($q)");
}


done_testing();

