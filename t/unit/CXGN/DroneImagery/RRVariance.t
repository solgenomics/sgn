use strict;
use warnings;
use Test::More;
use POSIX qw(isfinite);
use File::Temp qw(tempdir);
use JSON::PP qw(encode_json decode_json);
use CXGN::DroneImagery::NativeResults;

# Parser/projection regressions use the retained successful original AI25
# final estimates. These are not substitute solver fits or field acceptance.
my $dir = tempdir(CLEANUP=>1);
my @basis = ([1/sqrt(2),-sqrt(3/2)],[1/sqrt(2),-sqrt(3/2)/3],
             [1/sqrt(2),sqrt(3/2)/3],[1/sqrt(2),sqrt(3/2)]);
my @times = (10,20,30,40);
my @g = ([3.4571,1.0859],[1.0859,3.2138]);
my @pe = ([1.7555,.21822],[.21822,.81314]);
my @gamma = (.428060364519184,-.167654794904670);
my @expected_g = (4.668416028060961,1.637238676020318,2.8911279906463494,8.43008397193905);
my @expected_pe = (1.7194918727723203,.8872839575907725,1.139262709075893,2.4754281272276812);
my @expected_r = (1.6619950809844621,1.4493702763336085,1.2639473016220069,1.1022461322435968);
my @expected_share = (.5799344462418339,.411998690735504,.5460792246192598,.7020531067895197);

sub put {
    my ($name,$text) = @_;
    open(my $handle,'>',"$dir/$name") or die $!;
    print $handle $text;
    close($handle);
}
sub covariance_text { return join("\n",map {join(' ',@$_)} @{$_[0]}); }
sub parameters {
    my ($kg,$kp,$qg,$qp) = @_;
    $kg //= 'diagonal'; $kp //= 'diagonal'; $qg //= \@g; $qp //= \@pe;
    put('parameters',join("\n",'DATAFILE','data','NUMBER_OF_TRAITS',1,'NUMBER_OF_EFFECTS',5,
        'OBSERVATION(S)',9,'WEIGHT(S)','',
        'EFFECTS: POSITION_IN_DATAFILE NUMBER_OF_LEVELS TYPE_OF_EFFECT',
        '5 4 cross','7 2 cov 1','8 2 cov 1','7 2 cov 6','8 2 cov 6',
        'RANDOM_RESIDUAL VALUES',1,'RANDOM_GROUP','2 3','RANDOM_TYPE',$kg,'FILE',
        $kg eq 'diagonal' ? '' : 'K','(CO)VARIANCES',covariance_text($qg),
        'RANDOM_GROUP','4 5','RANDOM_TYPE',$kp,'FILE',$kp eq 'diagonal' ? '' : 'L',
        '(CO)VARIANCES',covariance_text($qp),'OPTION conv_crit 1e-12',
        'OPTION missing -999','OPTION hetres_pos 7 8','OPTION hetres_pol .001 .001','OPTION residual',''));
}
# Independent closed-form 2x2 eigensystems for ordinary parser fixtures.
# The actual boundary fixture below preserves the ORIGINAL printed tokens.
sub spectral_text {
    my ($matrix,$provided) = @_;
    if ($provided) {
        return join("\n",' eigenvectors',map(join(' ',@$_),@{$provided->{vectors}}),
            ' eigenvalues',join(' ',@{$provided->{values}}));
    }
    my ($a,$b,$d)=($matrix->[0][0],$matrix->[0][1],$matrix->[1][1]);
    my $difference=sqrt(($a-$d)**2+4*$b*$b);
    my @values=(($a+$d-$difference)/2,($a+$d+$difference)/2);
    my @first=($b,$values[0]-$a);
    my $norm=sqrt($first[0]**2+$first[1]**2);
    @first=$norm ? map {$_/$norm} @first : (1,0);
    my @vectors=([$first[0],-$first[1]],[$first[1],$first[0]]);
    return join("\n",' eigenvectors',map(join(' ',map {sprintf('%.16e',$_)} @$_),@vectors),
        ' eigenvalues',join(' ',map {sprintf('%.16e',$_)} @values));
}
sub native_log {
    my ($qg,$qp,$se,$provided) = @_;
    $qg //= \@g; $qp //= \@pe; $se //= .18314; $provided //= {};
    put('native.log',join("\n",' In round 8 convergence= 4.37e-15',' delta convergence= 1e-8',
        'Final Estimates',' Genetic variance(s) for effect  2',covariance_text($qg),
        ' correlations','1 .32577','.32577 1',spectral_text($qg,$provided->{2}),
        ' Genetic variance(s) for effect  4',covariance_text($provided->{4} ? ($provided->{4}{raw_tokens} || $qp) : $qp),' correlations',
        '1 .18265','.18265 1',spectral_text($qp,$provided->{4}),' new R',
        " 1 -th trait: 1 -th coefficient = $gamma[0]",
        " 1 -th trait: 2 -th coefficient = $gamma[1]",' SE for R',$se,
        ' * FINISHED (AIREMLF90): retained-parser-fixture',''));
}
sub data {
    my @rows;
    for my $unit (1..2) {
        for my $i (0..3) {push @rows,join(' ',$unit,1000+$unit,1,$times[$i],$i+1,$unit,@{$basis[$i]},50+$unit);}
    }
    put('data',join("\n",@rows)."\n");
}
sub summary {
    my %extra = @_;
    return CXGN::DroneImagery::NativeResults::summarize(
        parameter_file=>"$dir/parameters",data_file=>"$dir/data",log_file=>"$dir/native.log",
        cwd=>$dir,backend=>'airemlf90',time_scale=>'DAP',kernel_origin=>'genotypic_identity',
        unit_metadata=>{1=>{plot_id=>1001,genotype_id=>101,genotype_factor=>1},
                        2=>{plot_id=>1002,genotype_id=>102,genotype_factor=>2}},%extra);
}
sub near {
    my ($actual,$expected,$label) = @_;
    ok(defined($actual) && abs($actual-$expected)<1e-9,$label)
        or diag('actual='.(defined($actual)?$actual:'undef')." expected=$expected");
}
sub refusal {
    my ($pattern,$label,%extra) = @_;
    eval {summary(%extra)};
    like($@,qr/Native RR variance summary: .*?$pattern/s,$label);
}

put('solutions',"trait/effect level solution\n1 1 1 .5\n");
put('yhat_residual',"1 .2\n" x 8);
parameters(); native_log(); data();
my $actual = summary();
is_deeply([$actual->{version},$actual->{time_scale},$actual->{covariance_source}],[2,'DAP','estimated'],
    'estimated native RR contract archives version, actual time units and covariance source');
is_deeply($actual->{genetic_covariance},[map {@$_} @g],'full final genetic covariance retains signed off-diagonal elements');
is_deeply($actual->{env_covariance},[map {@$_} @pe],'full final permanent covariance remains available');
is_deeply($actual->{residual}{gamma},\@gamma,'final log-variance coefficients are distinct from printed uncertainty');
is_deeply($actual->{residual}{printed_se_for_R},[.18314],'legacy printed SE is preserved only as a separate diagnostic');
is_deeply([map {[$_->{plot_id},$_->{genotype_id},$_->{weight}]} @{$actual->{reference_units}}],
    [[1001,101,.5],[1002,102,.5]],'fixed reference uses equal physical-plot weights and actual identities');
is_deeply([map {$_->{time}} @{$actual->{by_time}}],\@times,'actual numeric DAP values are not replaced by coefficient order');
for my $i (0..3) {
    near($actual->{by_time}[$i]{genetic_base_variance},$expected_g[$i],"date $times[$i] full quadratic genetic projection matches independent oracle");
    near($actual->{by_time}[$i]{permanent_base_variance},$expected_pe[$i],"date $times[$i] permanent projection matches independent oracle");
    near($actual->{by_time}[$i]{residual_variance},$expected_r[$i],"date $times[$i] residual is exp(actual basis times final gamma)");
    near($actual->{by_time}[$i]{genetic_share},$expected_share[$i],"date $times[$i] identity special case matches independent individual-observation ratio");
}
is($actual->{covariance_readback}{genetic}{source},'raw_nominal','ordinary valid printed covariance remains the preferred unchanged representation');
# Captured immutable4 RCBD Final section: native positive eigenvalues coexist
# with a slightly indefinite rounded covariance matrix. No seed/model changes.
my @rounded_pe=([1.1817,-.47782],[-.47782,.19320]);
my $provided_pe={raw_tokens=>[['1.1817','-0.47782'],['-0.47782','0.19320']],
    vectors=>[['-0.37485','-0.92708'],['-0.92708','0.37485']],
    values=>['0.13544E-05','1.3749']};
native_log(undef,\@rounded_pe,undef,{4=>$provided_pe});
my $boundary=summary();
is($boundary->{covariance_readback}{permanent}{source},'reported_spectral_approximation','only rounding-indefinite covariance uses the actual reported eigensystem');
is($boundary->{covariance_readback}{permanent}{approximate},1,'spectral readback is explicitly approximate rather than unprinted full precision');
is_deeply($boundary->{raw_env_covariance},[1.1817,-.47782,-.47782,.19320],'all raw indefinite printed entries remain available without clipping');
is_deeply($boundary->{covariance_readback}{permanent}{raw_tokens},$provided_pe->{raw_tokens},'native trailing-zero precision and exact covariance tokens are retained');
is_deeply($boundary->{covariance_readback}{permanent}{eigenvalue_tokens},$provided_pe->{values},'raw reported positive eigenvalue tokens are retained');
my @spectral_expected=(1.1816955663775206,-.4777991924806136,-.4777991924806136,.1931918312613409);
for my $i (0..3) {near($boundary->{env_covariance}[$i],$spectral_expected[$i],"native spectral entry $i matches an independently retained Decimal interval oracle");}
ok(abs($boundary->{env_covariance}[1]-$boundary->{raw_env_covariance}[1])>5e-6,'valid representation difference exceeds raw-Q half-ULP alone and therefore requires propagated V/lambda bounds');
like($boundary->{covariance_readback}{permanent}{note},qr/representation precision, not estimator SE or confidence intervals/,'serialization uncertainty is never labelled a statistical interval');
my $bad_values={%$provided_pe,values=>['-0.00001','1.3749']};
native_log(undef,\@rounded_pe,undef,{4=>$bad_values});
refusal('negative reported eigenvalues','a negative native eigenvalue is refused rather than clipped');
my $bad_vectors={%$provided_pe,vectors=>[['0.500000','0.000000'],['0.000000','0.500000']]};
native_log(undef,\@rounded_pe,undef,{4=>$bad_vectors});
refusal('inconsistent with orthogonality','invalid native eigenvectors cannot be silently normalized');
my $bad_raw={%$provided_pe,raw_tokens=>[['10.0000','0.00000'],['0.00000','20.0000']]};
native_log(undef,\@rounded_pe,undef,{4=>$bad_raw});
refusal('disagree beyond their serialization precision','a covariance/eigensystem mismatch is refused without a nearest-PD repair');
native_log();
native_log(undef,undef,1000000);
near(summary()->{by_time}[0]{genetic_share},$expected_share[0],'changing printed SE cannot change a variance denominator');
native_log();
like(summary(kernel_origin=>'unknown')->{quantity_label},qr/model genetic variance share/,'identity shape alone does not declare broad-sense biological origin');
like(summary()->{quantity_label},qr/broad-sense/,'explicit genotypic identity origin has its qualified H2 label');

put('K',"1 1 2\n1 2 .4\n2 2 1\n");
put('L',"1 1 .5\n1 2 .1\n2 2 1.5\n");
parameters('user_file_inv','user_file_inv');
my $nonunit = summary(kernel_origin=>'additive_marker');
near($nonunit->{by_time}[0]{units}[0]{genetic_share},.7873486968674615,'nonunit Kii and Ljj enter the exact physical-observation denominator');
near($nonunit->{by_time}[0]{genetic_share},1.5*$expected_g[0]/(1.5*$expected_g[0]+$expected_pe[0]+$expected_r[0]),'single curve is ratio of equal-weight mean marginal variances');
ok(abs($nonunit->{by_time}[0]{genetic_share}-
    ($nonunit->{by_time}[0]{units}[0]{genetic_share}+$nonunit->{by_time}[0]{units}[1]{genetic_share})/2)>1e-3,
    'aggregate is explicitly distinct from mean of per-unit ratios');
like($nonunit->{quantity_label},qr/additive genetic h2/,'additive marker covariance is not labelled broad-sense H2');
like(summary(kernel_origin=>'phenotypic_similarity')->{definition}{interpretation},qr/biological heritability is not established/,'phenotypic similarity does not become unqualified biological heritability');
my @scaled_g = map {[map {$_/3} @$_]} @g;
my @scaled_pe = map {[map {$_/4} @$_]} @pe;
put('K',"1 1 6\n1 2 1.2\n2 2 3\n");put('L',"1 1 2\n1 2 .4\n2 2 6\n");
parameters('user_file_inv','user_file_inv',\@scaled_g,\@scaled_pe);
native_log(\@scaled_g,\@scaled_pe);
my $scaled = summary(kernel_origin=>'additive_marker');
for my $i (0..3) {near($scaled->{by_time}[$i]{genetic_share},$nonunit->{by_time}[$i]{genetic_share},"date $times[$i] equivalent K/QG and L/QPE scaling preserves the actual variance share");}

# Fixed-covariance BLUP has no AIREML Final Estimates. Read its actual supplied
# matrices rather than silently constructing empty covariance arrays for CV2.
parameters();put('native.log'," * solving method (default=PCG):FSPAK\n");
my $fixed = summary(backend=>'blupf90',kernel_origin=>'genotypic_identity',time_scale=>'GDD');
is_deeply([$fixed->{covariance_source},$fixed->{time_scale},$fixed->{residual}{model}],['supplied','GDD','homogeneous'],'fixed-covariance BLUP readback preserves supplied/estimated distinction and actual units');
is_deeply($fixed->{genetic_covariance},[map {@$_} @g],'BLUP retains complete declared QG for result and CV2 transfer');
is_deeply($fixed->{env_covariance},[map {@$_} @pe],'BLUP retains complete declared QPE for result and CV2 transfer');
near($fixed->{by_time}[0]{residual_variance},1,'BLUP uses its declared homogeneous residual instead of ignored heteroresidual options');
near($fixed->{by_time}[0]{genetic_share},$expected_g[0]/($expected_g[0]+$expected_pe[0]+1),'supplied BLUP share uses the same complete quadratic model');

parameters('user_file_inv','user_file_inv');native_log();
put('K',"1 1 2\n1 2 .4\n2 2 1\n");put('L',"1 1 0\n1 2 1\n2 2 0\n");
refusal('covariance matrix is invalid','zero-diagonal reciprocal-distance covariance is refused, not repaired',kernel_origin=>'unknown');
put('L',"1 1 .5\n1 2 .1\n2 2 1.5\n");
put('K',"1 1 1.00000000000001\n1 2 -1\n2 2 1.00000000000001\n");
refusal('native inverse precision','technically positive but numerically singular kernel is refused at actual backend precision',kernel_origin=>'unknown');
for my $scale (1e-4,1,1e4) {
    put('K',join("\n","1 1 ".($scale*(1+1e-10)),"1 2 ".(-$scale),"2 2 ".($scale*(1+1e-10)),''));
    refusal('native inverse precision',"native operational-zero rank refusal is invariant at kernel scale $scale",kernel_origin=>'unknown');
}
put('K',"1 1 1.00000001\n1 2 -1\n2 2 1.00000001\n");
my $near_supported=summary(kernel_origin=>'unknown');
is($near_supported->{native_kernel_relative_tolerance},1e-10,'documented independent DENSEOP precision is archived separately from OPTIONtol');
ok(defined($near_supported->{by_time}[0]{genetic_share}),'the independently successful original-native positive boundary remains supported');
put('L',"1 1 .5\n1 2 .1\n2 2 1.5\n");put('K',"1 1 1\n1 2 .4\n",);
refusal('kernel diagonal is missing','incomplete kernel identity metadata is a named refusal',kernel_origin=>'unknown');
my @large_g = map {[map {$_*1e100} @$_]} @g;
put('K',"1 1 1e250\n1 2 0\n2 2 1e250\n");
parameters('user_file_inv','diagonal',\@large_g);native_log(\@large_g);
refusal('projected marginal covariance is negative or nonfinite','finite valid matrix entries cannot overflow into a saved Inf/NaN variance share',kernel_origin=>'unknown');
parameters();native_log();data();
refusal('no explicit identity metadata','missing physical plot mapping cannot become a guessed biological identity',unit_metadata=>{});
refusal('outside|disagree','inconsistent native versus external genotype mapping is refused',unit_metadata=>{1=>{plot_id=>1001,genotype_id=>101,genotype_factor=>2},2=>{plot_id=>1002,genotype_id=>102}});
put('native.log',"+++ EM-REML does not work with heterogeneous residual variance\n");
refusal('complete final variance result','exit-zero unsupported native mode has no variance summary');
native_log();
data();
open(my $data_handle,'<',"$dir/data") or die $!;
my @input_rows=<$data_handle>;close($data_handle);
for my $i (0..$#input_rows) {
    my @values=split ' ',$input_rows[$i];
    $values[-1]=0 if $i==0;
    $values[-1]=-999 if $i>=4;
    $input_rows[$i]=join(' ',@values)."\n";
}
put('data',join('',@input_rows));
my $mask=CXGN::DroneImagery::NativeResults::observation_mask("$dir/data","$dir/parameters");
is_deeply($mask,[1,1,1,1,0,0,0,0],'actual declared missing code preserves observed zero and marks only missing native rows');
my $partial=summary();
is_deeply([map {[$_->{plot_id},$_->{weight}]} @{$partial->{reference_units}}],[[1001,1]],'all-missing physical plot does not expand fitted-reference weights');
is($partial->{excluded_units}[0]{plot_id},1002,'all-missing plot identity remains explicitly archived as excluded');
is_deeply([map {$_->{observed_records}} @{$partial->{by_time}}],[1,1,1,1],'per-date actual observed counts remain separate from fixed reference weights');
data();
my $roundtrip = decode_json(encode_json(summary()));
is_deeply($roundtrip->{by_time},summary()->{by_time},'JSON roundtrip retains per-date/per-physical-unit values and exact aggregation definition');
like($roundtrip->{definition}{scale},qr/not entry-mean/,'persisted definition prevents entry-mean or selection-reliability interpretation');

my $large_product=CXGN::DroneImagery::NativeResults::_interval_product([9e307,9e307],[1,1]);
ok(!grep(!isfinite($_),@$large_product),'finite large products retain finite serialization bounds without sum-first overflow');
my $large_sum=CXGN::DroneImagery::NativeResults::_interval_sum([9e307,9e307],[0,0]);
ok(!grep(!isfinite($_),@$large_sum),'finite large sums retain finite outward precision bounds');
ok(!CXGN::DroneImagery::NativeResults::_contains([9e307,9e307],1e308),'large interval consistency does not become unconditional through infinite roundoff');
eval {CXGN::DroneImagery::NativeResults::_interval_product([1e308,1e308],[2,2])};
like($@,qr/precision bounds overflowed/,'genuinely unrepresentable interval products have a named refusal');
done_testing;
