
use strict;

use Test::More qw | no_plan |;

use lib 't/lib';

use SGN::Test::Fixture;

use CXGN::Stock::Seedlot::ParseUpload;

my $f = SGN::Test::Fixture->new();

# create some data in the fixture
#


my $spu = CXGN::Stock::Seedlot::ParseUpload->new( { chado_schema => $f->chado_schema() } );
$spu->filename('t/data/seedlot_create_accessions_test_file.xls');

$spu->load_plugin('CreateMissingAccessionsForSeedlotsXLS');

$spu->parse();

ok(1, "dummy test");

done_testing();
