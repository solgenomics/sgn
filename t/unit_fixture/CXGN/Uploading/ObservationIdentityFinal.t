use strict;
use warnings;
use lib 't/lib';
use Test::More;
use File::Temp qw(tempfile);
use SGN::Test::Fixture;
use SGN::Model::Cvterm;
use CXGN::Phenotypes::StorePhenotypes;
use CXGN::Phenotypes::ParseUpload;
use CXGN::TimeUtils;
use CXGN::BrAPI::v1::Observations;
use CXGN::BrAPI::v2::Observations;
{package ObservationRefreshDbc;sub dbh {$_[0]{dbh}}}
{package ObservationRefreshCache;sub clear_cached_analyses_result {push @{$_[0]{calls}},$_[2];return 1}}
{package ObservationRefreshContext;sub dbc {$_[0]{dbc}}sub config {$_[0]{config}}sub controller {$_[0]{cache}}}
my $f=SGN::Test::Fixture->new;my $s=$f->bcs_schema;$s->storage->auto_savepoint(1);
my @names=qw(test_trial210 test_trial211);my @units=map {$s->resultset('Stock::Stock')->find({uniquename=>$_})->stock_id} @names;
my $trait=70666;my $tn=SGN::Model::Cvterm::get_trait_from_cvterm_id($s,$trait,'extended');
my(undef,$temp)=tempfile(TMPDIR=>1,UNLINK=>1);
sub store_values {
 my($values,$overwrite)=@_;
 return CXGN::Phenotypes::StorePhenotypes->new(basepath=>$f->config->{basepath},dbhost=>$f->config->{dbhost},dbname=>$f->config->{dbname},dbuser=>$f->config->{dbuser},dbpass=>$f->config->{dbpass},bcs_schema=>$s,metadata_schema=>$f->metadata_schema,phenome_schema=>$f->phenome_schema,user_id=>41,temp_file_nd_experiment_id=>$temp,stock_list=>[sort keys %$values],trait_list=>[$tn],values_hash=>$values,has_timestamps=>1,overwrite_values=>$overwrite||0,metadata_hash=>{operator=>'janedoe',date=>'20261102'},composable_validation_check_name=>$f->config->{composable_validation_check_name});
}
sub parse_values {
 my($data)=@_;my $p=CXGN::Phenotypes::ParseUpload->new;my $v=$p->validate('brapi observations',$data,1,'stocks',$s,undef,undef);return $v if $v->{error};return $p->parse('brapi observations',$data,1,'stocks',$s,undef,'janedoe',undef,undef);
}
$s->txn_begin;my $ran=eval {
 my $seed=store_values({$names[0]=>{$tn=>[10,'2026-11-02T12:00:00+02:00','before']},$names[1]=>{$tn=>[11,'2026-11-02T10:00:00Z','before']}},0);
 my($warning,$error)=$seed->verify;ok(!$error,'valid seeds verify')or diag($error);my($err,undef,$details)=$seed->store;ok(!$err,'seeds stored')or diag($err);
 my %id=map {$_->{observationUnitDbId}=>$_->{observationDbId}} @$details;ok($id{$units[0]}&&$id{$units[1]},'two distinct supplied observation IDs');
 my $a=$s->resultset('Phenotype::Phenotype')->find($id{$units[0]});is(CXGN::TimeUtils::normalize_db_timestamp($a->get_column('collect_date')),'2026-11-02 10:00:00','stored offset converted to UTC');
 my $zero_id=parse_values([{observationDbId=>0,observationUnitDbId=>$units[0],observationVariableDbId=>$trait,value=>12}]);like($zero_id->{error},qr/positive integer/,'zero addressed ID cannot become an insert or another update');
 my $wrong=parse_values([{observationDbId=>$id{$units[0]},observationUnitDbId=>$units[1],observationVariableDbId=>$trait,value=>12}]);like($wrong->{error},qr/different observation unit or variable/,'foreign unit cannot be selected under addressed ID');
 $wrong=parse_values([{observationDbId=>$id{$units[0]},observationUnitDbId=>$units[0],observationVariableDbId=>70741,value=>12}]);like($wrong->{error},qr/different observation unit or variable/,'addressed ID cannot silently become another trait');
 my $parsed=parse_values([{observationDbId=>$id{$units[0]},observationUnitDbId=>$units[0],observationVariableDbId=>$trait,value=>10,collector=>'after',observationTimeStamp=>'2026-11-02T13:00:00+02:00'}]);ok(!$parsed->{error},'valid same-value metadata correction parses')or diag($parsed->{error});
 my $update=store_values($parsed->{data},1);my($e)= $update->store;ok(!$e,'metadata correction stores')or diag($e);
 $a->discard_changes;is($a->operator,'after','same-value PUT persists collector');is(CXGN::TimeUtils::normalize_db_timestamp($a->get_column('collect_date')),'2026-11-02 11:00:00','same-value PUT persists corrected instant');
 $parsed=parse_values([{observationDbId=>$id{$units[0]},observationUnitDbId=>$units[0],observationVariableDbId=>$trait,value=>13}]);$update=store_values($parsed->{data},1);($e)=$update->store;ok(!$e,'sparse valid update stores');$a->discard_changes;is($a->value,13,'addressed ID receives value');is($a->operator,'after','omitted collector retained');is(CXGN::TimeUtils::normalize_db_timestamp($a->get_column('collect_date')),'2026-11-02 11:00:00','omitted timestamp retained');
 my $other=$s->resultset('Phenotype::Phenotype')->find($id{$units[1]});is($other->value,11,'unrelated observation remains unchanged');
 my %read_args=(bcs_schema=>$s,metadata_schema=>$f->metadata_schema,phenome_schema=>$f->phenome_schema,people_schema=>$f->people_schema,page=>0,page_size=>100,status=>[]);
 my $v1=CXGN::BrAPI::v1::Observations->new(\%read_args);
 my $v2=CXGN::BrAPI::v2::Observations->new({%read_args,context=>undef});
 for my $model ($v1,$v2) {
  my $params={observationDbId=>$id{$units[0]}};
  my $r=$model->detail($params);
  is($r->{result}{observationDbId},$id{$units[0]},'advertised version reads the addressed stored ID');
  is($r->{result}{value},13,'readback sees the corrected value');
  is($r->{result}{collector},'after','readback sees corrected collector');
  is($r->{result}{observationTimeStamp},'2026-11-02T11:00:00Z','readback preserves the UTC instant');
  is($model->detail({observationDbId=>2147483000})->{http_code},404,'missing observation is HTTP404');
  my $found=$model->search({observationDbIds=>[values %id],collectors=>['after']})->{result}{data};
  is_deeply([map {$_->{observationDbId}} @$found],[$id{$units[0]}],'collector filtering precedes count and pagination');
  my $excluded=$model->search({observationDbIds=>[values %id],observationTimeStampRangeStart=>['2026-11-02T14:00:00+02:00']})->{result}{data};
  is(scalar @$excluded,0,'standalone offset start bound filters both API versions');
 }

 $parsed=parse_values([{observationDbId=>$id{$units[0]},observationUnitDbId=>$units[0],observationVariableDbId=>$trait,value=>14}]);
 my(@refresh_calls,@cache_calls);
 my $context=bless {dbc=>bless({dbh=>$s->storage->dbh},'ObservationRefreshDbc'),config=>$f->config,cache=>bless({calls=>\@cache_calls},'ObservationRefreshCache')},'ObservationRefreshContext';
 {
  no warnings 'redefine';
  local *CXGN::BreederSearch::refresh_matviews_after_change=sub {push @refresh_calls,[@_];return {success=>1}};
  my(@status,%result);
  CXGN::BrAPI::v2::Observations::refresh_after_store($s,$context,\@units,\@status,\%result);
  is(scalar @refresh_calls,1,'shared observation hook requests the standard materialized refresh');
  my $owner_trial=$s->resultset('Project::Project')->find({name=>'test_trial'})->project_id;
  is_deeply($cache_calls[0]{trials},[$owner_trial],'shared hook clears caches for the actual owning trial');
  ok(!$result{refreshPending},'completed refresh is not reported as pending');
 }
 {
  no warnings 'redefine';
  local *CXGN::BreederSearch::refresh_matviews_after_change=sub {return {refresh_pending=>1,error=>'busy'}};
  my(@status,%result);
  CXGN::BrAPI::v2::Observations::refresh_after_store($s,$context,\@units,\@status,\%result);
  ok($result{changesSaved} && $result{refreshPending},'a committed upload with pending analysis has explicit flags');
  ok(grep({$_->{WARNING} && $_->{WARNING}=~/Observations saved/} @status),'warning retains the successful write result');
  is(scalar @cache_calls,2,'cached results are cleared even when a refresh is pending');
 }
 my $unarchived=store_values($parsed->{data},1);
 $unarchived->metadata_hash->{archived_file}='/tmp/sgn-observation-regression-no-such-archive/input.csv';
 $unarchived->metadata_hash->{archived_file_type}='brapi observations';
 my($archive_error)=$unarchived->store;
 like($archive_error // '',qr/Can't open file/,'a missing archive prevents committing its observation update');
 $a->discard_changes;is($a->value,13,'failed archive registration rolls the value back too');
 for my $bad ('NaN','Inf','-Inf','1e999') {my $v=store_values({$names[0]=>{$tn=>[$bad,'2026-11-02T11:00:00Z','after']}},1);my(undef,$invalid)=$v->verify;like($invalid//'',qr/finite/,'nonfinite numeric input refused before writing');}
 1;
};my $error=$@;$s->txn_rollback;ok($ran,'scenario completed and fixture rolled back')or diag($error);done_testing;
