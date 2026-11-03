use strict;
use warnings;
use Test::More;
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

is(CXGN::DroneImagery::DesignFactors::cnn_design('cnn_prediction',['CRD','RCBD']),undef,'ordinary CNN prediction does not require one design model across trials');
is(CXGN::DroneImagery::DesignFactors::cnn_design('cnn_prediction_mixed_model',['RCBD','RCBD']),'RCBD','optional CNN mixed-model evaluation resolves its declared design');
eval {CXGN::DroneImagery::DesignFactors::cnn_design('cnn_prediction_mixed_model',['CRD','RCBD'])};
like($@,qr/one supported studyDesign/,'optional CNN evaluation refuses an ambiguous mixed-design formula');

ok(CXGN::DroneImagery::DesignFactors::validate_genotype_names([{germplasm_stock_id=>101,germplasm_uniquename=>'G1'},{germplasm_stock_id=>101,germplasm_uniquename=>'G1'}]),'repeated observations preserve consistent genotype identity');
eval {CXGN::DroneImagery::DesignFactors::validate_genotype_names([{germplasm_stock_id=>101,germplasm_uniquename=>'Shared'},{germplasm_stock_id=>102,germplasm_uniquename=>'Shared'}])};
like($@,qr/name maps to multiple known germplasm IDs/,'name-keyed genetic output refuses distinct known IDs sharing one name');
eval {CXGN::DroneImagery::DesignFactors::validate_genotype_names([{germplasm_stock_id=>101,germplasm_uniquename=>'Old'},{germplasm_stock_id=>101,germplasm_uniquename=>'New'}])};
like($@,qr/ID maps to multiple genotype names/,'name-keyed genetic output refuses conflicting names for one known ID');
ok(CXGN::DroneImagery::DesignFactors::validate_genotype_names([{germplasm_uniquename=>'G1'},{germplasm_uniquename=>'G2'}]),'legacy name-only rows do not invent a known-ID conflict');

done_testing;
