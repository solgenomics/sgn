
use strict;
use Test::More qw | no_plan |;
use File::Slurp;
use File::Temp qw | tempfile |;
use CXGN::Dataset;
use CXGN::Dataset::File;
use CXGN::MixedModels;
use lib 't/lib';

use SGN::Test::Fixture;

my $f = SGN::Test::Fixture->new();

my $dir = Cwd::cwd();

# create tempfile 
my ($fh, $tempfile) = tempfile( "mixedmodelsXXXXXX", DIR => $dir."/static/documents/tempfiles/", UNLINK => 0 );

print STDERR "Using tempfile $tempfile\n";
close($fh);

ok(-e $tempfile, "temp file created test");

# create dataset
my $ds = CXGN::Dataset->new( { people_schema => $f->people_schema(), schema => $f->bcs_schema() });

$ds->years( [ "2014", "2015" ]);

$ds->store();


my $dsf = CXGN::Dataset::File->new( { people_schema => $f->people_schema(), schema => $f->bcs_schema(), sp_dataset_id => $ds->sp_dataset_id(), file_name => $tempfile, quotes => 0 });

#$dsf->file_name($tempfile);
$dsf->retrieve_phenotypes();

ok( -e $tempfile."_phenotype.txt", "phenotype file exists test");

my $pheno_tempfile = $tempfile."_phenotype.txt";
print STDERR "file size: ". `ls -al $pheno_tempfile`;

my $mm = CXGN::MixedModels->new();

$mm->tempfile($pheno_tempfile);

is($mm->engine(), "lme4", "engine test if engine not set");

$mm->dependent_variables( [ "dry matter content percentage|CO_334:0000092", "fresh root weight|CO_334:0000012" ] );

$mm->fixed_factors( [ "replicate" ]  );

$mm->random_factors( [ "germplasmName" ] );

my ($model_string, $error) = $mm->generate_model();

is($model_string, "replicate + (1|germplasmName)", "model string test for BLUPs");

$mm->run_model("Slurm", "localhost", "/tmp");

print STDERR "Using tempfile base ".$mm->tempfile()."\n";

ok( -e $mm->tempfile().".params", "check existence of parmams file");
ok( -e $mm->tempfile().".adjustedBLUPs", "check existence of adjustedBLUPs result file");
ok( -e $mm->tempfile().".BLUPs", "check existence of BLUPs result file");

is( scalar(my @a = read_file($mm->tempfile().".adjustedBLUPs")), 413, "check number of lines in adjustedBLUEs file...");


$mm->fixed_factors( [ "germplasmName" ]  );

$mm->random_factors( [ "replicate" ] );

my $model_string = $mm->generate_model();

print STDERR "MODEL STRING = $model_string\n";

is("germplasmName + (1|replicate)", $model_string, "model string test for BLUEs");

$mm->run_model("Slurm", "localhost", "/tmp");

sleep(10);

ok( -e $mm->tempfile().".adjustedBLUEs", "check existence of adjustedBLUEs result file");
ok( -e $mm->tempfile().".BLUEs", "check existence of BLUEs result file");
is( scalar(my @a = read_file($mm->tempfile().".adjustedBLUEs")), 413, "check number of lines in adjustedBLUPs file...");


# cleanup for next test :-)
#
unlink($mm->tempfile().".params");
unlink($mm->tempfile().".adjustedBLUPs");
unlink($mm->tempfile().".BLUPs");
unlink($mm->tempfile().".adjustedBLUEs");
unlink($mm->tempfile().".BLUEs");

$ds->delete();

# phew, we're done!
#
done_testing();
