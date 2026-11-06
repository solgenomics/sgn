use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use CXGN::DroneImagery::DesignFactors;

# Parser/contract fixtures based on observed original program output. These
# are not solver or statistical acceptance; actual native fits run separately.
my $dir=tempdir(CLEANUP=>1);
sub put {my ($name,$text)=@_;open(my $f,'>',"$dir/$name") or die $!;print $f $text;close $f;}
put('parameters.txt',"OPTION conv_crit 1e-12\nOPTION hetres_pos 7 8\nOPTION hetres_pol .001 .001\n");
put('training.dat',"1 1001 1 10 1 1 .707106781186547 -1.22474487139159 1.2\n");
put('solutions',"trait/effect level solution\n1 1 1 .5\n");put('yhat_residual',"1.0 .2\n");
sub log_text {
 my ($g0,$g1,$convergence,$delta)=@_;
 $convergence//= '1e-13';$delta//= '1e-8';
 return " In round 10 convergence= $convergence\n delta convergence= $delta\nFinal Estimates\n new R\n 1 -th trait: 1 -th coefficient = $g0\n 1 -th trait: 2 -th coefficient = $g1\n * FINISHED (AIREMLF90): fixture\n";
}
sub error {CXGN::DroneImagery::DesignFactors::native_fit_error($_[0]||'airemlf90_grm_random_regression_dap_blups',"$dir/parameters.txt","$dir/training.dat","$dir/native.log",$dir)}
put('native.log',log_text('.5','.1'));
is(error(),undef,'complete converged finite residual-variance result meets the parser contract');
put('native.log',log_text('28341815','.2194'));
like(error(),qr/residual-variance estimation failed numerically/,'observed overflow is a named refusal despite finite coefficients and Final Estimates');
put('native.log',log_text('-1324521498','692381589'));
like(error(),qr/residual-variance estimation failed numerically/,'observed residual underflow is refused before saving outputs');
put('native.log',log_text('.5','.1','.1','.1'));
like(error(),qr/did not report convergence/,'maximum-round or unconverged finite output is not success');
put('native.log',"+++ EM-REML does not work with heterogeneous residual variance\n");
like(error(),qr/complete final variance result/,'native exit-zero unsupported mode is not a completed variance fit');
put('native.log',log_text('0','0'));put('parameters.txt',"OPTION conv_crit 1e-12\nOPTION hetres_pos 7 8\nOPTION hetres_pol 0 0\n");
like(error(),qr/inactive at zero initialization/,'zero-masked residual parameters cannot masquerade as a free heterogeneous fit');
put('parameters.txt',"OPTION conv_crit 1e-12\nOPTION solv_method FSPAK\n");put('native.log'," * solving method (default=PCG):FSPAK\n");
is(error('blupf90_grm_random_regression_dap_blups'),undef,'original direct BLUP solver has its own completion contract');
put('solutions',"trait/effect level solution\n1 1 1 NaN\n");
like(error('blupf90_grm_random_regression_dap_blups'),qr/nonfinite or incomplete/,'nonfinite native solution fields are refused');
like(CXGN::DroneImagery::DesignFactors::native_variance_design_error('airemlf90_grm_random_regression_dap_blups',2,2),qr/not separately identifiable/,'saturated PE plus free residual variance is an explicit AIREML design refusal');
is(CXGN::DroneImagery::DesignFactors::native_variance_design_error('airemlf90_grm_random_regression_dap_blups',4,2),undef,'the actual four-time two-coefficient variance design passes the necessary nonsaturation check');
is(CXGN::DroneImagery::DesignFactors::native_variance_design_error('blupf90_grm_random_regression_dap_blups',2,2),undef,'fixed-covariance BLUP does not inherit an unrelated variance-estimation restriction');
my @basis=([1/sqrt(2),-sqrt(3/2)],[1/sqrt(2),sqrt(3/2)]);
my $unit=CXGN::DroneImagery::DesignFactors::native_residual_start(1,\@basis);
is_deeply($unit->{coefficients},[.001,.001],'declared unit variance starts activate intended free zero coefficients without time-coordinate reuse');
my $scaled=CXGN::DroneImagery::DesignFactors::native_residual_start(4,\@basis);
ok(abs($scaled->{coefficients}[0]-sqrt(2)*log(4))<1e-12&&$scaled->{coefficients}[1]==.001,'declared R and supplied normalized intercept determine the constant log-variance start');
ok(abs($scaled->{initial_variance_range}[0]-4*exp(-.001*sqrt(3/2)))<1e-12&&abs($scaled->{initial_variance_range}[1]-4*exp(.001*sqrt(3/2)))<1e-12,'provenance records the actual observed-time initial variance range');
eval {CXGN::DroneImagery::DesignFactors::native_residual_start(1,[[1,0],[2,1]])};
like($@,qr/intercept is not constant/,'initialization cannot guess an intercept from varying covariates');
my $blup=CXGN::DroneImagery::DesignFactors::native_solver_settings('blupf90_grm_random_regression_dap_blups');
my $ai=CXGN::DroneImagery::DesignFactors::native_solver_settings('airemlf90_grm_random_regression_dap_blups');
ok(grep($_ eq 'OPTION solv_method FSPAK',@{$blup->{parameter_options}}),'saved-coefficient BLUP paths select the documented original direct solver');
ok(!grep(/solv_method/,@{$ai->{parameter_options}}),'AIREML retains its supported default instead of receiving a BLUP-only option');

done_testing;
