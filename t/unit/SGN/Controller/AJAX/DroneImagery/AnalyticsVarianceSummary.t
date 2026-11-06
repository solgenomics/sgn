use strict;
use warnings;
use Test::More;
use JSON qw(encode_json decode_json);
use SGN::Controller::AJAX::DroneImagery::DroneImageryAnalytics;

sub fitted {
    my ($g,$p,$r,$share)=@_;
    return {version=>2,estimand_id=>'rr_observation_marginal_genetic_share',time_scale=>'DAP',kernel_origin=>'genotypic_identity',quantity_label=>'Observation-scale broad-sense genotypic H2',covariance_source=>'estimated',definition=>{scale=>'Individual observation after fixed-effect adjustment'},reference_units=>[{plot_id=>1001,genotype_id=>101,weight=>.5},{plot_id=>1002,genotype_id=>102,weight=>.5}],genetic_covariance=>[$g],env_covariance=>[$p],genetic_correlation=>[1],env_correlation=>[1],by_time=>[{time=>0,mean_genetic_variance=>$g,mean_permanent_variance=>$p,residual_variance=>$r,genetic_share=>$share,genetic_share_range=>[$share-.01,$share+.01]}]};
}
my $first=fitted(8,1,1,.8);
my $second=fitted(1,1,2,.25);
my $runs=[map {{statistics_select=>'AIREML fixture',original=>{native_variance_summary=>$_}}} ($first,$second)];
my $before=decode_json(encode_json($runs));
my $actual=SGN::Controller::AJAX::DroneImagery::DroneImageryAnalytics::_native_variance_averages($runs);
my ($point)=grep {($_->{metric} // '') eq 'genetic_share'} @{$actual->{display}};
ok(abs($point->{mean}-.525)<1e-12,'actual aggregation averages each fitted observation-scale share');
ok(abs($point->{mean}-9/14)>0.1,'a ratio of averaged components is not substituted for the run-mean share');
ok(abs($point->{std}-(.55/sqrt(2)))<1e-12,'uncertainty field is explicitly sample SD across fitted runs');
is_deeply([$point->{time},$point->{time_scale},$point->{n},$point->{reference_count}],[0,'DAP',2,2],'literal time zero, actual units, runs and physical reference count survive aggregation');
is_deeply($point->{per_unit_range},[.24,.81],'saved range spans physical units across actual fitted summaries');
ok(!grep({$_->{level}=~/^(?:h2_coeff|env2_coeff|residual_1$)/}@{$actual->{display}}),'no unsupported coefficient-wise H2 or scalar SE residual is created');
is_deeply($runs,$before,'aggregation preserves raw fitted per-unit/covariance metadata');
my $single=SGN::Controller::AJAX::DroneImagery::DroneImageryAnalytics::_native_variance_averages([$runs->[0]]);
my ($one)=grep {($_->{metric} // '') eq 'genetic_share'} @{$single->{display}};
ok(!defined($one->{std}),'one run does not invent zero uncertainty');
for my $change ('time_scale','weight','genotype') {
    my $changed=decode_json(encode_json($runs));
    $changed->[1]{original}{native_variance_summary}{time_scale}='GDD' if $change eq 'time_scale';
    $changed->[1]{original}{native_variance_summary}{reference_units}[0]{weight}=.25 if $change eq 'weight';
    $changed->[1]{original}{native_variance_summary}{reference_units}[0]{genotype_id}=999 if $change eq 'genotype';
    eval {SGN::Controller::AJAX::DroneImagery::DroneImageryAnalytics::_native_variance_averages($changed)};
    like($@,qr/different reference plots, weights, units or estimands/,'incomparable '.$change.' cannot be silently averaged');
}
done_testing;
