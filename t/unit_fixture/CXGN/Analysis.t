
use strict;
use Test::More 'no_plan';
use Data::Dumper;
use lib 't/lib';
use SGN::Test::Fixture;
use CXGN::Analysis;

print STDERR "Starting test...\n";
my $t = SGN::Test::Fixture->new();
my $schema = $t->bcs_schema();
my $dbh = $t->dbh();
my $people_schema = $t->people_schema();


eval { 
my $ds = CXGN::Dataset->new( { schema => $t->bcs_schema(), people_schema => $t->people_schema() });
$ds->name("ephemeral dataset");
$ds->accessions( [ 'test_accession1', 'test_accession2', 'test_accession4' ] );
$ds->store();

print STDERR "Creating new Analysis object...\n";
my $a = CXGN::Analysis->new({ bcs_schema => $schema,  people_schema => $people_schema, name => "test_analysis2" });

print STDERR "Accession test...\n";

$a->accession_names( [ 'test_accession1', 'test_accession2', 'test_accession4' ] );
#$a->nd_geolocation_id(23); # test location
$a->metadata()->dataset_id($ds->sp_dataset_id());
$a->user_id(41);
$a->set_year(2020);

print STDERR Dumper($a->accession_names());

#ok($a->nd_geolocation_id() == 23, "nd_geolocation_id test");

print STDERR "Design test...\n";
my $project_id = $a->create_and_store_analysis_design();

my $q = "select * from nd_experiment_project join nd_experiment_stock using(nd_experiment_id) join stock using(stock_id) where project_id=?";

my $h = $dbh->prepare($q);

$h->execute($project_id);

my $rows = $h->fetchall_arrayref();

print STDERR "STORED: ".Dumper($rows);

print STDERR "RETRIEVING Analysis... with trial_id = $project_id\n";
my $a2 = CXGN::Analysis->new( { bcs_schema => $t->bcs_schema, people_schema => $t->people_schema(), trial_id => $project_id });

is($a2->name(), "test_analysis2", "analysis name test");
is($a2->metadata()->dataset_id(), 1);

print STDERR Dumper($a2->metadata()->to_json());

my $row = $t->bcs_schema()->resultset("NaturalDiversity::NdGeolocation")->find( { description => '[Computation]' });

is($a2->nd_geolocation_id(), $row->nd_geolocation_id(), "nd_geolocation_id test after save");

print STDERR "DESIGN: ".Dumper($a2->design()->get_design());

print STDERR "ACCESSIONS: ".Dumper($a2->accession_names())."\n";

my $dataref = $a2->get_phenotype_matrix();
print STDERR "Phenotype Matrix: ".Dumper($dataref);

$ds->delete();
};

print STDERR "Rolling back...\n";
$dbh->rollback();

done_testing();

