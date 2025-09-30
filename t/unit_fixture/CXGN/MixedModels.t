
use strict;
use Test::More qw | no_plan |;
use File::Slurp;
use File::Temp qw | tempfile |;
use File::Basename qw | basename dirname |;
use CXGN::Dataset;
use CXGN::Dataset::File;
use CXGN::MixedModels;
use lib 't/lib';

use SGN::Test::Fixture;

my $f = SGN::Test::Fixture->new();

my $dir = Cwd::cwd();

# create tempfile 
my ($fh, $tempfile) = tempfile( "mixedmodelsXXXXXX", DIR => $dir."/static/documents/tempfiles/", UNLINK => 0 );

my $job_finish_log = $f->config->{job_finish_log} ? $f->config->{job_finish_log} : '/home/production/volume/logs/job_finish.log';

my $job_config = {
    schema => $f->bcs_schema(),
    people_schema => $f->people_schema(),
    name => 'unit_fixture mixed model test',
    user => 41,
    finish_logfile => $job_finish_log
};

print STDERR "Using tempfile $tempfile\n";
close($fh);

ok(-e $tempfile, "temp file created test");

# create dataset
my $ds = CXGN::Dataset->new( { people_schema => $f->people_schema(), schema => $f->bcs_schema() });

$ds->years( [ "2014", "2015" ]);

$ds->store();


my $dsf = CXGN::Dataset::File->new( { people_schema => $f->people_schema(), schema => $f->bcs_schema(), sp_dataset_id => $ds->sp_dataset_id(), quotes => 0 });

$dsf->file_name($tempfile);
$dsf->retrieve_phenotypes();

ok( -e $tempfile."_phenotype.txt", "phenotype file exists test");

my $pheno_tempfile = $tempfile."_phenotype.txt";

my $file_size =  `ls -al $pheno_tempfile`;
print STDERR "file size: $file_size\n";
ok($file_size =~ /167672/, 'phenotype file size test');

my $mm = CXGN::MixedModels->new();

$mm->tempfile($pheno_tempfile);

is($mm->engine(), "lme4", "test engine default setting");

my $SYSTEM_MODE = $ENV{SYSTEM};

foreach my $engine ("lme4", "sommer") { 

    $mm->engine($engine);
    
    $mm->dependent_variables( [ "dry matter content percentage|CO_334:0000092" ]); #, "fresh root weight|CO_334:0000012" ] );

    $mm->fixed_factors( [ "replicate" ]  );

    $mm->random_factors( [ "germplasmName" ] );

    my ($model_string, $error) = $mm->generate_model();

    print STDERR "MODEL STRING: $model_string ERROR: $error\n";

    if ($engine eq "lme4") { 
	is($model_string, "replicate + (1|germplasmName)", "model string test for BLUPs");
    }
    else {
	print STDERR "MODEL STRING: $model_string\n";
    }
    
    print STDERR "RUNNING MODEL\n";
    eval {
    $mm->run_model($f->config->{backend}, $f->config->{cluster_host}, dirname($pheno_tempfile), $job_config );
    };
    if ($@) {
        print STDERR "ERROR RUNNING MODEL: $@\n";
    }


    print STDERR "Using tempfile base ".$mm->tempfile()."\n";

  SKIP: { 
      skip "Skip if run under git", 3 unless $SYSTEM_MODE ne "GITACTION";
      
      ok( -e $mm->tempfile().".params", "check existence of parmams file");
      ok( -e $mm->tempfile().".adjustedBLUPs", "check existence of adjustedBLUPs result file");
      ok( -e $mm->tempfile().".BLUPs", "check existence of BLUPs result file");
    };
    #    is( scalar(my @a = read_file($mm->tempfile().".adjustedBLUPs")), 413, "check number of lines in adjustedBLUEs file...");

}




# from package "emmeans"

# # An error caused by it - is captured in matrix structure build for the base package,
#
# https://github.com/cran/Matrix/blob/master/R/AllClass.R
# because that error is not from "emmeans" code  and it happens only on gitaction with Slurm running
#
#     invalid class "corMatrix" object: 'sd' slot has non-finite entries
#
# It only happens, at least for me, in gitaction build.  Neither on local R system or in any alternative docker build that error not exist
# It makes no sense to try repair error which is not an error but very specific problem with gitaction workflow environment
### END OF ERROR ON GITACTION EXPLANATION

$mm->engine('lme4');
$mm->dependent_variables( [ "fresh root weight|CO_334:0000012" ] );	
    	
$mm->fixed_factors([ "germplasmName" ]);
    
$mm->random_factors([ "replicate" ]);

my ($model_string, $error) = $mm->generate_model();

print STDERR "MODEL STRING = $model_string\n";

is($model_string, "germplasmName + (1|replicate)", "model string test for BLUEs");

$mm->run_model($f->config->{backend}, $f->config->{cluster_host}, dirname($pheno_tempfile), $job_config);

sleep(2);

 SKIP: { 
     skip "Skip if run under git", 2 unless $SYSTEM_MODE ne "GITACTION"; 
     ok( -e $mm->tempfile() . ".adjustedBLUPs", "check existence of adjustedBLUEs result file");
     ok( -e $mm->tempfile() . ".BLUPs", "check existence of BLUEs result file");
     #    is(scalar(my @a = read_file($mm->tempfile() . ".adjustedBLUEs")), 413, "check number of lines in adjustedBLUPs file...");
};

# cleanup for next test :-)
unlink($mm->tempfile() . ".adjustedBLUEs");
unlink($mm->tempfile() . ".BLUEs");

$ds->delete();

# phew, we're done!
#
done_testing();