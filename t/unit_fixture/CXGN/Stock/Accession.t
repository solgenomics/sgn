#test all functions in CXGN::Stock::Accession

use strict;

use lib 't/lib';

use Test::More;
use Data::Dumper;
use SGN::Test::Fixture;
use CXGN::Stock::Accession;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema();

my $main_production_site_url = 'http://localhost';
my $stock1_uniquename = 'stock1testuniquename';
my $stock1_name = 'stock1testname';
my $stock1_org_name = 'stock1testorg';
my $stock1_pop_name = 'stock1testpop';
my $stock1_desc = 'stock1testdesc';
my $species = 'Manihot esculenta';
my $stock1_accession_number = 'stock1testacc';
my $stock1_pui = "$main_production_site_url/stock/123";
my $stock1_pedigree = "test_accession1/test_accession2";
my $stock1_source = "stock1testsource";
my $stock1_synonyms = ["stock1testsyn", "stock2testsyn2"];
my $stock1_inst = "stock1testinst";
my $stock1_inst_name = "stock1testinstname";
my $stock1_bio = "stock1testbio";
my $stock1_country = "stock1testcountry";
my $stock1_storage = "stock1teststorage";
my $stock1_date = "stock1testdate";
my $stock1donors = [
    { 'donorGermplasmName'=>'stock1_donor1', 'donorAccessionNumber' => 'stock1_donor1', 'donorInstituteCode'=>'stock1_donorinst1', 'germplasmPUI'=>'stock1_donorpui1' },
    { 'donorGermplasmName'=>'stock1_donor2', 'donorAccessionNumber' => 'stock1_donor2', 'donorInstituteCode'=>'stock1_donorinst2', 'germplasmPUI'=>'stock1_donorpui2' }
];

my $stock1 = CXGN::Stock::Accession->new({
    schema=>$schema,
    #main_production_site_url=>$main_production_site_url,
    type=>'accession',
    species=>$species,
    #genus=>$_->{genus},
    name=>$stock1_name,
    uniquename=>$stock1_uniquename,
    organization_name=>$stock1_org_name,
    population_name=>$stock1_pop_name,
    description=>$stock1_desc,
    accessionNumber=>$stock1_accession_number,
    germplasmPUI=>$stock1_pui,
    #pedigree=>$stock1_pedigree,
    germplasmSeedSource=>$stock1_source,
    synonyms=>$stock1_synonyms,
    #commonCropName=>$_->{commonCropName},
    instituteCode=>$stock1_inst,
    instituteName=>$stock1_inst_name,
    biologicalStatusOfAccessionCode=>$stock1_bio,
    countryOfOriginCode=>$stock1_country,
    typeOfGermplasmStorageCode=>$stock1_storage,
    #speciesAuthority=>$_->{speciesAuthority},
    #subtaxa=>$_->{subtaxa},
    #subtaxaAuthority=>$_->{subtaxaAuthority},
    donors=>$stock1donors,
    acquisitionDate=>$stock1_date
});
my $stock_id1 = $stock1->store();

my $s = CXGN::Stock::Accession->new(schema=>$schema, stock_id=>$stock_id1);
is($s->uniquename, $stock1_uniquename);
is($s->name, $stock1_name);
is($s->organization_name, $stock1_org_name);
is($s->population_name, $stock1_pop_name);
is($s->description, $stock1_desc);
is($s->type, 'accession');
is($s->accessionNumber, $stock1_accession_number);
is($s->germplasmPUI, $stock1_pui);
is($s->germplasmSeedSource, $stock1_source);
print STDERR Dumper $s->synonyms;
is_deeply($s->synonyms, $stock1_synonyms);
is($s->instituteCode, $stock1_inst);
is($s->instituteName, $stock1_inst_name);
is($s->biologicalStatusOfAccessionCode, $stock1_bio);
is($s->countryOfOriginCode, $stock1_country);
is($s->typeOfGermplasmStorageCode, $stock1_storage);
is($s->acquisitionDate, $stock1_date);
print STDERR Dumper $s->donors;
is_deeply($s->donors, $stock1donors);

done_testing();
