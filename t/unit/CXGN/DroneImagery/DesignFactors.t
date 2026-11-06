use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use File::Basename qw(dirname);
use CXGN::DroneImagery::DesignFactors;

is(CXGN::DroneImagery::DesignFactors::fixed_terms('CRD'),'1','CRD has no fixed occurrence/block covariate');
is(CXGN::DroneImagery::DesignFactors::fixed_terms('RCBD'),'block','RCBD uses the physical block');
for my $design ('Alpha','Lattice') {
    is(CXGN::DroneImagery::DesignFactors::fixed_terms($design),'replicate/block',"$design retains replicate and nested blocks");
}
is(CXGN::DroneImagery::DesignFactors::group_key('CRD',undef,undef),undef,'CRD accepts missing tags without inventing a blocking group');
my @keys=map {CXGN::DroneImagery::DesignFactors::group_key('Alpha',$_,'B')} ('01','1','0','NA');
my $codes=CXGN::DroneImagery::DesignFactors::category_codes(\@keys);
is(scalar(keys %$codes),4,'numeric matrix category bijection preserves 01, 1, 0 and literal NA');
is_deeply([sort values %$codes],[1,2,3,4],'matrix group codes are explicit category indices');
isnt(CXGN::DroneImagery::DesignFactors::group_key('RCBD','x','B','Trial1'),CXGN::DroneImagery::DesignFactors::group_key('RCBD','x','B','Trial2'),'blocks from different trials are distinct fixed categories'); # codespell:ignore isnt
for my $bad (['Alpha',undef,'B'],['Lattice','1',undef],['RCBD','999',undef]) {
    eval {CXGN::DroneImagery::DesignFactors::group_key(@$bad)};
    like($@,qr/Recorded.*metadata is missing/,'missing required recorded metadata is refused instead of using occurrences');
}
eval {CXGN::DroneImagery::DesignFactors::fixed_terms(undef)};
like($@,qr/Declare studyDesign/,'unknown design does not infer a model from occurrence labels');
eval {CXGN::DroneImagery::DesignFactors::validate_rows('Alpha',[{obsunit_rep=>undef,obsunit_block=>'B',obsunit_accession_occurrence=>5}])};
like($@,qr/design replication metadata is missing/,'rich occurrence value cannot fill a missing design tag');

my @spaced_groups=map {CXGN::DroneImagery::DesignFactors::group_key('Alpha',$_,'Block A')} ('Rep 01','Rep 1','NA');
my $spaced_codes=CXGN::DroneImagery::DesignFactors::category_codes(\@spaced_groups);
for my $tag ('Rep 01','Rep 1','NA') {
    my $code=CXGN::DroneImagery::DesignFactors::numeric_group_code('Alpha',$tag,'Block A',$spaced_codes);
    my @row=(1,1001,$code,10,1,1,1,42);
    my @parsed=split /\s+/,join(' ',@row);
    is(scalar(@parsed),8,"recorded tag '$tag' cannot shift numeric F90 columns");
    like($parsed[2],qr/^\d+$/,'F90 legacy metadata column is an explicit numeric category');
}
is(CXGN::DroneImagery::DesignFactors::numeric_group_code('CRD',undef,undef,{}),0,'CRD numeric metadata column does not create a blocking group');

like(CXGN::DroneImagery::DesignFactors::native_executable_error('blupf90_grm_random_regression_dap_blups',[]),qr/executable blupf90 was not found/,'unavailable BLUPF90 is a named runtime prerequisite');
like(CXGN::DroneImagery::DesignFactors::native_executable_error('airemlf90_grm_random_regression_dap_blups',[]),qr/executable airemlf90 was not found/,'unavailable AIREMLF90 is a named runtime prerequisite');
is(CXGN::DroneImagery::DesignFactors::native_executable_error('lmer_germplasmname_replicate',[]),undef,'R model engines do not require an F90 executable');

is(CXGN::DroneImagery::DesignFactors::r_package_error('lmer_germplasmname_replicate'),undef,'unrelated R models do not require a licensed ASReml package');
my $asreml_error=CXGN::DroneImagery::DesignFactors::r_package_error('asreml_grm_multivariate_spatial_genetic_blups');
if(defined($asreml_error)) {
    like($asreml_error,qr/licensed ASReml R package.*not loadable/,'unavailable ASReml is an explicit named runtime prerequisite');
} else {
    pass('ASReml namespace is loadable; license and fit acceptance remain separate');
}
is(CXGN::DroneImagery::DesignFactors::r_package_error('asreml_grm_multivariate_spatial_genetic_blups'),$asreml_error,'ASReml namespace check is stable when reused by equivalent callers');

is(CXGN::DroneImagery::DesignFactors::cnn_design('cnn_prediction',['CRD','RCBD']),undef,'ordinary CNN prediction does not require one design model across trials');
is(CXGN::DroneImagery::DesignFactors::cnn_design('cnn_prediction_mixed_model',['RCBD','RCBD']),'RCBD','optional CNN mixed-model evaluation resolves its declared design');
eval {CXGN::DroneImagery::DesignFactors::cnn_design('cnn_prediction_mixed_model',['CRD','RCBD'])};
like($@,qr/one supported studyDesign/,'optional CNN evaluation refuses an ambiguous mixed-design formula');

my $directory_root=tempdir(CLEANUP=>1);
my $first=CXGN::DroneImagery::DesignFactors::working_directory($directory_root,'blupf90_grm_random_regression_dap_blups');
my $second=CXGN::DroneImagery::DesignFactors::working_directory($directory_root,'airemlf90_grm_random_regression_dap_blups');
isnt($first,$second,'independent F90 requests cannot share fixed solutions/residual files'); # codespell:ignore isnt
ok(-d $first&&-d $second&&dirname($first) eq $directory_root&&dirname($second) eq $directory_root,'F90 working directories remain inside the owned project root');
is(CXGN::DroneImagery::DesignFactors::working_directory($directory_root,'sommer_grm_genetic_blups'),$directory_root,'engines with existing unique output paths retain their normal directory');

ok(CXGN::DroneImagery::DesignFactors::validate_genotype_names([{germplasm_stock_id=>101,germplasm_uniquename=>'G1'},{germplasm_stock_id=>101,germplasm_uniquename=>'G1'}]),'repeated observations preserve consistent genotype identity');
eval {CXGN::DroneImagery::DesignFactors::validate_genotype_names([{germplasm_stock_id=>101,germplasm_uniquename=>'Shared'},{germplasm_stock_id=>102,germplasm_uniquename=>'Shared'}])};
like($@,qr/name maps to multiple known germplasm IDs/,'name-keyed genetic output refuses distinct known IDs sharing one name');
eval {CXGN::DroneImagery::DesignFactors::validate_genotype_names([{germplasm_stock_id=>101,germplasm_uniquename=>'Old'},{germplasm_stock_id=>101,germplasm_uniquename=>'New'}])};
like($@,qr/ID maps to multiple genotype names/,'name-keyed genetic output refuses conflicting names for one known ID');
ok(CXGN::DroneImagery::DesignFactors::validate_genotype_names([{germplasm_uniquename=>'G1'},{germplasm_uniquename=>'G2'}]),'legacy name-only rows do not invent a known-ID conflict');

is(CXGN::DroneImagery::DesignFactors::native_observation(0),0,'a measured numeric zero remains an observed native value');
is(CXGN::DroneImagery::DesignFactors::native_observation(undef),-999,'absent native observation uses the shared explicit missing code');
is(CXGN::DroneImagery::DesignFactors::native_observation(''),-999,'empty native observation uses the same missing code');
eval {CXGN::DroneImagery::DesignFactors::native_observation(-999)};
like($@,qr/reserved native missing-observation code/,'a real measured sentinel collision is a named refusal');
my $missing_options=CXGN::DroneImagery::DesignFactors::native_solver_settings('blupf90_grm_random_regression_dap_blups')->{parameter_options};
ok(grep($_ eq 'OPTION missing -999',@$missing_options),'all native solver settings declare the explicit observation missing code');
is(CXGN::DroneImagery::DesignFactors::native_inverse_tolerance('blupf90'),1e-12,'original BLUP inverse precision has its documented explicit default');
is(CXGN::DroneImagery::DesignFactors::native_inverse_tolerance('airemlf90'),1e-14,'original AIREML inverse precision remains separate from model convergence');
done_testing;
