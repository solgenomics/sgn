use strict;use warnings;use lib 't/lib';
use Test::More;use JSON qw(encode_json);
use SGN::Test::Fixture;use SGN::Model::Cvterm;use Bio::Chado::Schema;
use CXGN::Trial::TrialCreate;use CXGN::Trial::TrialLayout;
use CXGN::Phenotypes::SearchFactory;

# Private committed fixtures are necessary for the independent writer to see
# the same rows. Cleanup targets captured IDs; never use global fixture cleanup.
my$f=SGN::Test::Fixture->new;my$s=$f->bcs_schema;my$dbh=$s->storage->dbh;$s->storage->auto_savepoint(1);
my$c=$f->config;my$writer=Bio::Chado::Schema->connect("dbi:Pg:dbname=$c->{dbname};host=$c->{dbhost}",$c->{dbuser},$c->{dbpass});$writer->storage->auto_savepoint(1);
my$prefix='audit_read_snapshot_'.$$;my($trial,$target,$phenotype,@plots,@stocks);
{package SnapshotContext;sub config {$_[0]{config}}}
my$context=bless({config=>$c},'SnapshotContext');
sub term{SGN::Model::Cvterm->get_cvterm_row($s,@_)->cvterm_id}
# Both values are ordinary legacy metadata in this independent PR. The later
# accession service is not required to reproduce a two-statement read race.
sub change {
 my ($new)=@_;my $label=$new==$stocks[0] ? 2:1;
 $writer->txn_do(sub {
  $writer->storage->dbh->do('UPDATE stock_relationship SET object_id=? WHERE subject_id=? AND type_id=?',undef,$new,$target,term('plot_of','stock_relationship'));
  $writer->storage->dbh->do('UPDATE stockprop SET value=? WHERE stock_id=? AND type_id=?',undef,$label,$target,term('replicate','stock_property'));
  CXGN::Trial::TrialLayout->new({schema=>$writer,trial_id=>$trial,experiment_type=>'field_layout'})->generate_and_cache_layout;
 });
}
sub current_pair{my($stock,$counter)=$writer->storage->dbh->selectrow_array('SELECT r.object_id,p.value FROM stock_relationship r LEFT JOIN stockprop p ON p.stock_id=r.subject_id AND p.type_id=? WHERE r.subject_id=? AND r.type_id=?',undef,term('replicate','stock_property'),$target,term('plot_of','stock_relationship'));return[$stock,$counter]}
sub cleanup{
 return unless$trial;eval{$s->txn_rollback}if!$dbh->{AutoCommit};
 $s->txn_do(sub{
  my$experiments=$dbh->selectcol_arrayref('SELECT nd_experiment_id FROM nd_experiment_project WHERE project_id=?',undef,$trial);
  my$phenotypes=$dbh->selectcol_arrayref('SELECT DISTINCT phenotype_id FROM nd_experiment_phenotype WHERE nd_experiment_id=ANY(?)',undef,$experiments);
  $dbh->do('DELETE FROM phenotype WHERE phenotype_id=ANY(?)',undef,$phenotypes)if@$phenotypes;
  $dbh->do('DELETE FROM nd_experiment WHERE nd_experiment_id=ANY(?)',undef,$experiments)if@$experiments;
  $dbh->do('DELETE FROM phenome.stock_owner WHERE stock_id=ANY(?)',undef,\@plots);$dbh->do('DELETE FROM stock WHERE stock_id=ANY(?)',undef,\@plots);
  $dbh->do('DELETE FROM phenome.project_owner WHERE project_id=?',undef,$trial);$dbh->do('DELETE FROM project WHERE project_id=?',undef,$trial);
 });
}
my$ran=eval{
 die'Expected AutoCommit fixture reader'if!$dbh->{AutoCommit};
 @stocks=map{$s->resultset('Stock::Stock')->find({uniquename=>"test_accession$_"})->stock_id}(1,2);
 $s->txn_do(sub{
  my%layout=map{my$i=$_;($i=>{plot_name=>"${prefix}_plot_$i",stock_name=>"test_accession$i",plot_number=>$i,rep_number=>9,block_number=>9,row_number=>1,col_number=>$i})}1..2;
  my$r=CXGN::Trial::TrialCreate->new({chado_schema=>$s,dbh=>$dbh,owner_id=>41,operator=>'janedoe',program=>'test',trial_location=>'test_location',trial_name=>$prefix,trial_year=>2031,trial_description=>'Private generic read consistency fixture',design_type=>'CRD',design=>\%layout})->save_trial;$trial=$r->{trial_id};die'Native fixture failed'if!$trial;
  @plots=map{$s->resultset('Stock::Stock')->find({uniquename=>"${prefix}_plot_$_"})->stock_id}1..2;$target=$plots[1];
  my$type=term('phenotyping_experiment','experiment_type');my$e=$s->resultset('NaturalDiversity::NdExperiment')->create({type_id=>$type,nd_geolocation_id=>$s->resultset('NaturalDiversity::NdGeolocation')->first->nd_geolocation_id});$e->create_related('nd_experiment_projects',{project_id=>$trial});$e->create_related('nd_experiment_stocks',{stock_id=>$target,type_id=>$type});
  my$p=$s->resultset('Phenotype::Phenotype')->create({uniquename=>$prefix.'_measurement',cvalue_id=>70666,observable_id=>70666,value=>17,operator=>'janedoe'});$phenotype=$p->phenotype_id;$e->create_related('nd_experiment_phenotypes',{phenotype_id=>$phenotype});
 });
 ok($trial&&$target&&$phenotype,'private native fixture committed for independent generic reader/writer connections');
 change($stocks[1]);
 my $get_design=CXGN::Trial::TrialLayout::AbstractLayout->can('get_design');
 my ($armed,$hooks)=(1,0);
 {
  no warnings 'redefine';
  local *CXGN::Trial::TrialLayout::AbstractLayout::get_design=sub {
   my $layout=$get_design->(@_);
   if ($armed) {$armed=0;++$hooks;change($stocks[0]);}
   return $layout;
  };
  my ($rows)=CXGN::Phenotypes::SearchFactory->instantiate('Native',{bcs_schema=>$s,data_level=>'plot',trial_list=>[$trial],plot_list=>[$target],trait_list=>[70666]})->search;
  my ($row)=grep {defined($_->{phenotype_id})&&$_->{phenotype_id}==$phenotype} @$rows;
  die 'Native measured row missing' if !$row;
  is($hooks,1,'independent writer committed between actual layout and observation reads');
  is_deeply(current_pair(),[$stocks[0],2],'independent identity and metadata changes are committed');
  is_deeply([$row->{accession_stock_id},$row->{rep}],[$stocks[1],1],
   'Native returns one old snapshot instead of the new identity with old layout metadata');
  ok($dbh->{AutoCommit},'actual Native read restores its owned connection');
 }
 if (!$ENV{AUDIT_SNAPSHOT_BASELINE}) {
  require CXGN::DB::ReadSnapshot;
  my $cache_type=term('trial_layout_json','project_property');
  $writer->storage->dbh->do('DELETE FROM projectprop WHERE project_id=? AND type_id=?',undef,$trial,$cache_type);
  my($cache_rows)=CXGN::Phenotypes::SearchFactory->instantiate('Native',{bcs_schema=>$s,data_level=>'plot',trial_list=>[$trial],plot_list=>[$target],trait_list=>[70666]})->search;
  ok((grep {defined($_->{phenotype_id})&&$_->{phenotype_id}==$phenotype} @$cache_rows),'owned snapshot permits actual native layout-cache regeneration');
  is($dbh->selectrow_array('SELECT count(*) FROM projectprop WHERE project_id=? AND type_id=?',undef,$trial,$cache_type),1,'native cache write committed inside the reader-owned snapshot');
  ok($dbh->{AutoCommit},'cache-regenerating read restored AutoCommit');
  my $block=term('block','stock_property');my $first=$plots[0];my $attempts=0;my @states;
  local $dbh->{RaiseError}=1;local $dbh->{PrintError}=0;
  my $previous=$dbh->{HandleError};
  local $dbh->{HandleError}=sub {push @states,$dbh->state;return $previous ? $previous->(@_) : 0};
  my $result=CXGN::DB::ReadSnapshot::run($s,sub {
   ++$attempts;
   $dbh->selectrow_array('SELECT value FROM stockprop WHERE stock_id=? AND type_id=?',undef,$first,$block);
   $writer->storage->dbh->do('UPDATE stockprop SET value=? WHERE stock_id=? AND type_id=?',undef,'31',$first,$block) if $attempts==1;
   $dbh->do('UPDATE stockprop SET value=? WHERE stock_id=? AND type_id=?',undef,'32',$first,$block);
   return $dbh->selectrow_array('SELECT value FROM stockprop WHERE stock_id=? AND type_id=?',undef,$first,$block);
  });
  ok((grep {defined($_)&&$_ eq '40001'} @states),'real PostgreSQL conflicting update raised SQLSTATE40001');
  is($attempts,2,'the real serialization failure caused exactly one retry');is($result,32,'retried writable read transaction completed');ok($dbh->{AutoCommit},'real retry restored AutoCommit');
  my $other_attempts=0;my $other_ok=eval {CXGN::DB::ReadSnapshot::run($s,sub {++$other_attempts;$dbh->do('SELECT 1/0')});1};
  ok(!$other_ok,'real nonserialization SQL error stays explicit');is($other_attempts,1,'division-by-zero error is not retried');ok($dbh->{AutoCommit},'nonretry error cleanup restored AutoCommit');
  $s->txn_begin;my $isolation=$dbh->selectrow_array('SHOW transaction_isolation');
  my $caller_result=CXGN::DB::ReadSnapshot::run($s,sub {
   is($dbh->selectrow_array('SHOW transaction_isolation'),$isolation,'real caller-owned isolation is unchanged');
   $dbh->do('UPDATE stockprop SET value=? WHERE stock_id=? AND type_id=?',undef,'41',$first,$block);return 'caller';
  });
  is($caller_result,'caller','real caller-owned result is returned');ok(!$dbh->{AutoCommit},'helper does not commit caller-owned work');$s->txn_rollback;
  is($dbh->selectrow_array('SELECT value FROM stockprop WHERE stock_id=? AND type_id=?',undef,$first,$block),32,'caller can still roll back its own writes');
 }
 1;
};my$error=$@;my$clean=eval{cleanup();1};my$cleanup_error=$@;
ok($ran,'actual two-connection reader qualifications completed')or diag$error;ok($clean,'only the private committed fixture was removed')or diag$cleanup_error;
is($dbh->selectrow_array('SELECT count(*) FROM project WHERE name=?',undef,$prefix),0,'no private trial remains');
is($dbh->selectrow_array('SELECT count(*) FROM stock WHERE stock_id=ANY(?)',undef,\@plots),0,'no private plot remains');
done_testing;
