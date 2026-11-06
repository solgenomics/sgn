use strict;
use warnings;
use lib 't/lib';
use Test::More;
use File::Temp qw(tempdir);
use JSON ();
use SGN::Test::Fixture;
use SGN::Model::Cvterm;
use CXGN::Phenotypes::ParseUpload::Plugin::Observations;
use CXGN::Phenotypes::StorePhenotypes;
use CXGN::Phenotypes::SearchFactory;
use CXGN::BrAPI::v2::ExternalReferences;

# All fixture changes, including materialized rows, are in one rollback transaction.
# This exercises real owning parser/store methods; HTTP authorization is separate.
my $f=SGN::Test::Fixture->new;
my $s=$f->bcs_schema; my $dbh=$s->storage->dbh;
$s->storage->auto_savepoint(1);
my $dir=tempdir(CLEANUP=>1);
my $plot_name='test_trial211';
my $plot=$s->resultset('Stock::Stock')->find({uniquename=>$plot_name})->stock_id;
my $trial=$s->resultset('Project::Project')->find({name=>'test_trial'})->project_id;
my $plugin=CXGN::Phenotypes::ParseUpload::Plugin::Observations->new;
my($trait,$trait_name,$serial);
sub parse_obs { return $plugin->parse($_[0],1,'stocks',$s,undef,'janedoe',undef,undef,undef) }
sub obs {my($value,$hour,%extra)=@_;return {observationUnitDbId=>"$plot",observationVariableDbId=>"$trait",value=>"$value",observationTimeStamp=>"2030-11-03T${hour}:00:00Z",%extra}}
sub owner_store {
 my($parsed,$overwrite)=@_;
 die $parsed->{error} if $parsed->{error};
 my $store=CXGN::Phenotypes::StorePhenotypes->new({
  basepath=>$f->config->{basepath},dbhost=>$f->config->{dbhost},dbname=>$f->config->{dbname},dbuser=>$f->config->{dbuser},dbpass=>$f->config->{dbpass},
  temp_file_nd_experiment_id=>"$dir/experiment_".++$serial,bcs_schema=>$s,metadata_schema=>$f->metadata_schema,phenome_schema=>$f->phenome_schema,user_id=>41,
  stock_list=>$parsed->{units},trait_list=>$parsed->{variables},values_hash=>$parsed->{data},has_timestamps=>1,overwrite_values=>$overwrite||0,
  metadata_hash=>{operator=>'janedoe',date=>'2030-11-03_12:00:00'},composable_validation_check_name=>$f->config->{composable_validation_check_name},
 });
 my($warning,$error)=$store->verify; die "verify: $error" if $error;
 my($store_error,$success,$details)=$store->store; die "store: $store_error" if $store_error;
 return $details;
}
sub rows {
 return $dbh->selectall_arrayref(q{SELECT DISTINCT p.phenotype_id,p.value,p.collect_date,p.operator FROM phenotype p JOIN nd_experiment_phenotype USING(phenotype_id) JOIN nd_experiment_stock USING(nd_experiment_id) WHERE stock_id=? AND p.cvalue_id=? ORDER BY p.phenotype_id},{Slice=>{}},$plot,$trait);
}
sub search_value {
 my($engine,$value)=@_;
 my($rows)=CXGN::Phenotypes::SearchFactory->instantiate($engine,{bcs_schema=>$s,data_level=>'plot',trial_list=>[$trial],plot_list=>[$plot],trait_list=>[$trait]})->search;
 my @values=$engine eq 'Native' ? (map {$_->{phenotype_value}} @$rows) : (map {map {$_->{value}} @{$_->{observations}||[]}} @$rows);
 return scalar grep {defined($_)&&"$_" eq "$value"} @values;
}
my $tx=0;END {eval{$s->txn_rollback if $tx} if $s}
$s->txn_begin;$tx=1;
my $ran=eval {
 # A new legal repeated-measure variable avoids touching existing fixture trait policy.
 my $template=$s->resultset('Cv::Cvterm')->find(70741);
 my $xref=$s->resultset('General::Dbxref')->create({db_id=>$template->dbxref->db_id,accession=>"audit_parser_store_review_$$"});
 my $variable=$s->resultset('Cv::Cvterm')->create({name=>"audit_parser_store_review_$$",cv_id=>$template->cv_id,dbxref_id=>$xref->dbxref_id,definition=>'Rollback-only observation identity regression'});
 for my $relationship ($template->cvterm_relationship_subjects->search({'type.name'=>'VARIABLE_OF'},{join=>'type'})->all) {
  $s->resultset('Cv::CvtermRelationship')->create({subject_id=>$variable->cvterm_id,object_id=>$relationship->object_id,type_id=>$relationship->type_id});
 }
 my $repeat=SGN::Model::Cvterm->get_cvterm_row($s,'trait_repeat_type','trait_property')->cvterm_id;
 $variable->create_related('cvtermprops',{type_id=>$repeat,value=>'multiple'});
 $trait=$variable->cvterm_id;$trait_name=SGN::Model::Cvterm::get_trait_from_cvterm_id($s,$trait,'extended');
 subtest 'Text zero collector survives parser and actual storage' => sub {
  my $p=parse_obs([obs(17,'09',collector=>'0')]);
  ok(!$p->{error},'valid collector zero parses') or BAIL_OUT($p->{error});
  is($p->{data}{$plot_name}{$trait_name}[0][2],'0','parser preserves explicit scalar collector zero');
  # Also isolate StorePhenotypes from the parser defaulting bug.
  $p->{data}{$plot_name}{$trait_name}[0][2]='0';
  owner_store($p);
  is(rows()->[0]{operator},'0','real StorePhenotypes preserves collector zero');
 };
 subtest 'An omitted cell collector falls back to the upload operator' => sub {
  my $p=parse_obs([obs(51,'16'),obs(52,'17')]);
  die $p->{error} if $p->{error};
  $p->{data}{$plot_name}{$trait_name}[0][2]='audit_explicit_collector';
  $p->{data}{$plot_name}{$trait_name}[1][2]=undef;
  owner_store($p);
  my($first)=grep {$_->{value} eq '51'} @{rows()};
  my($second)=grep {$_->{value} eq '52'} @{rows()};
  is($first->{operator},'audit_explicit_collector','explicit per-cell collector is recorded');
  is($second->{operator},'janedoe','next cell without collector uses the upload operator, without carry-over');
 };
 subtest 'Malformed falsy references reach the public validator' => sub {
  for my $bad (0,JSON::false) {
   ok(CXGN::BrAPI::v2::ExternalReferences::validate_payload($bad)->{error},'shared reference validator rejects malformed scalar');
   my $p=parse_obs([obs(18,'10',externalReferences=>$bad)]);
   ok($p->{error},'observation parser rejects malformed scalar instead of silently omitting it');
  }
 };
 subtest 'Sub-microsecond input cannot create duplicate stored time keys' => sub {
  my $p=parse_obs([obs(51,'15',observationTimeStamp=>'2030-11-03T15:00:00.1234561Z'),obs(52,'15',observationTimeStamp=>'2030-11-03T15:00:00.1234562Z')]);
  ok($p->{error},'unsupported sub-microsecond instants are refused before database precision is lost');
  if (!$p->{error}) {my $ok=eval {owner_store($p);1};diag($@) if !$ok;}
  my $count=$dbh->selectrow_array(q{SELECT count(DISTINCT phenotype_id) FROM phenotype JOIN nd_experiment_phenotype USING(phenotype_id) JOIN nd_experiment_stock USING(nd_experiment_id) WHERE stock_id=? AND cvalue_id=? AND collect_date='2030-11-03 15:00:00.123456'},undef,$plot,$trait);
  cmp_ok($count,'<=',1,'fractional instants do not collapse into two rows of one PostgreSQL key');
 };
 # Seed two distinct legal times via the real parser and StorePhenotypes.
 owner_store(parse_obs([obs(21,'10'),obs(22,'11')]));
 my($a)=grep {$_->{value} eq '21'} @{rows()};
 my($b)=grep {$_->{value} eq '22'} @{rows()};
 ok($a && $b && $a->{phenotype_id}!=$b->{phenotype_id},'qualified repeated variable has two independently stored observations');
 subtest 'An existing ID cannot move onto another stored unit-variable-time key' => sub {
  my $p=parse_obs([obs(23,'11',observationDbId=>"$a->{phenotype_id}")]);
  ok($p->{error},'parser rejects an update colliding with the other observation time');
  diag('parser accepted collision; exercising actual write under a nested rollback') if !$p->{error};
  $s->txn_begin;
  my $worked=eval {owner_store($p,1) if !$p->{error};1};my $error=$@;
  my $count=$dbh->selectrow_array(q{SELECT count(DISTINCT phenotype_id) FROM phenotype JOIN nd_experiment_phenotype USING(phenotype_id) JOIN nd_experiment_stock USING(nd_experiment_id) WHERE stock_id=? AND cvalue_id=? AND collect_date='2030-11-03 11:00:00'},undef,$plot,$trait);
  cmp_ok($count,'<=',1,'storage retains at most one observation for the destination time key');
  $s->txn_rollback;
  diag($error) if !$worked;
 };
 subtest 'One existing observation ID cannot appear twice in a request' => sub {
  my $p=parse_obs([obs(31,'12',observationDbId=>"$a->{phenotype_id}"),obs(32,'13',observationDbId=>"$a->{phenotype_id}")]);
  ok($p->{error},'parser rejects repeated existing ID even when requested times differ');
 };
 subtest 'Low-level store needs the API after-store materialized refresh hook' => sub {
  $dbh->do('SELECT refresh_materialized_phenotype_jsonb_table()');
  owner_store(parse_obs([obs(47,'14')]));
  is(search_value('Native',47),1,'real owner write is immediately visible in Native');
  is(search_value('MaterializedViewTable',47),0,'low-level store alone leaves persisted materialized JSON stale (qualified boundary)');
  $dbh->do('SELECT refresh_materialized_phenotype_jsonb_table()');
  is(search_value('MaterializedViewTable',47),1,'explicit standard refresh restores analytical parity');
 };
 1;
};
my $error=$@;$s->txn_rollback;$tx=0;
ok($ran,'real parser/storage regression completed; all fixture mutations rolled back') or diag($error);
done_testing;
