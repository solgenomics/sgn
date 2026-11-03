use strict;
use warnings;
use Test::More;
use SGN::Controller::AJAX::DroneImagery::DroneImagery;
use SGN::Controller::AJAX::DroneImagery::DroneImageryAnalytics;
use CXGN::DroneImagery::DesignFactors;
use CXGN::DroneImagery::DroneImageryAnalyticsRunSimulation;

# Execute owning methods and the real namespace prerequisite. Actor/schema
# probes establish the early refusal boundary; no DB persistence is inferred.
my $missing=CXGN::DroneImagery::DesignFactors::r_package_error('asreml_grm_multivariate_spatial_genetic_blups');
plan skip_all=>'This refusal qualification requires an unavailable ASReml namespace.' unless defined $missing;

{ package PrerequisiteActor;
  sub get_object {$_[0]} sub get_sp_person_id {41}
  sub get_username {'janedoe'} sub get_user_type {'curator'}
  package PrerequisiteRequest;
  sub param {$_[0]->{$_[1]}} sub params {$_[0]}
  package PrerequisiteSchema;
  our $access=0;
  sub AUTOLOAD {$access++;die 'Model/data access happened before the engine prerequisite.'}
  sub DESTROY {}
  package PrerequisiteContext;
  sub user {bless {},'PrerequisiteActor'}
  sub req {$_[0]->{request}} sub stash {$_[0]->{stash}}
  sub dbic_schema {bless {},'PrerequisiteSchema'}
  sub tempfile {$_[0]->{input_calls}++;die 'Input created before refusal.'}
  sub tempfiles_subdir {$_[0]->{input_calls}++;die 'Input directory created before refusal.'}
  sub path_to {die 'Model path resolved before refusal.'}
  sub detach {die 'Unexpected authentication refusal.'}
}

my @models=qw(asreml_grm_univariate_spatial_genetic_blups asreml_grm_multivariate_spatial_genetic_blups asreml_grm_univariate_pure_spatial_genetic_blups);
for my $entry (
 ['SGN::Controller::AJAX::DroneImagery::DroneImagery','drone_imagery_calculate_statistics_POST'],
 ['SGN::Controller::AJAX::DroneImagery::DroneImageryAnalytics','drone_imagery_calculate_analytics_POST']
) {
  my ($class,$method)=@$entry;
  my $controller=$class->new;
  for my $model (@models) {
    my $context=bless {input_calls=>0,stash=>{},request=>bless({statistics_select=>$model,field_trial_id_list=>'[1]'},'PrerequisiteRequest')},'PrerequisiteContext';
    my $result=eval {$controller->$method($context);1};
    ok($result,"$method returns a controlled refusal for $model");
    diag($@) unless $result;
    like($context->stash->{rest}{error}||'',qr/licensed ASReml R package.*not loadable/,"$method names the actual licensed-package prerequisite");
    is($context->{input_calls},0,"$method creates no phenotype input before refusal");
    is_deeply([sort keys %{$context->stash->{rest}}],['error'],"$method returns no model/results or bogus success");
  }
}
is($PrerequisiteSchema::access,0,'both owning entrypoints touch no model/data handles before their prerequisite refusal');

for my $model (@models) {
    my @arguments; $arguments[7]=$model;
    eval {CXGN::DroneImagery::DroneImageryAnalyticsRunSimulation::perform_drone_imagery_analytics(@arguments)};
    like($@,qr/licensed ASReml R package.*not loadable/,'direct Simulation invocation refuses before dereferencing input/model arguments');
}
done_testing;
