use strict;use warnings;use lib 't/lib';
use Test::More;use JSON qw(encode_json);
use SGN::Test::Fixture;use SGN::Model::Cvterm;use Bio::Chado::Schema;
use CXGN::Trial::TrialCreate;use CXGN::Trial::TrialLayout;use CXGN::Trial::AccessionChange;use CXGN::Trial::DesignReplication;
use CXGN::Phenotypes::SearchFactory;use CXGN::Trial::TrialLayoutSearch;use CXGN::BrAPI::v2::ObservationUnits;

# Private committed fixtures are necessary for the independent writer to see
# the same rows. Cleanup targets captured IDs; never use global fixture cleanup.
my$f=SGN::Test::Fixture->new;my$s=$f->bcs_schema;my$dbh=$s->storage->dbh;$s->storage->auto_savepoint(1);
my$c=$f->config;my$writer=Bio::Chado::Schema->connect("dbi:Pg:dbname=$c->{dbname};host=$c->{dbhost}",$c->{dbuser},$c->{dbpass});$writer->storage->auto_savepoint(1);
my$prefix='audit_read_snapshot_'.$$;my($trial,$target,$phenotype,@plots,@stocks);
{package SnapshotContext;sub config {$_[0]{config}}}
my$context=bless({config=>$c},'SnapshotContext');
sub term{SGN::Model::Cvterm->get_cvterm_row($s,@_)->cvterm_id}
sub change{my($new)=@_;CXGN::Trial::AccessionChange->new({schema=>$writer,trial_id=>$trial})->apply([{plot_id=>$target,new_stock_id=>$new}],{curator=>1,rename_plots=>'none'})}
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
  my$r=CXGN::Trial::TrialCreate->new({chado_schema=>$s,dbh=>$dbh,owner_id=>41,operator=>'janedoe',program=>'test',trial_location=>'test_location',trial_name=>$prefix,trial_year=>2031,trial_description=>'Private committed two-connection read consistency fixture',design_type=>'CRD',design=>\%layout})->save_trial;$trial=$r->{trial_id};die'Native fixture failed'if!$trial;
  @plots=map{$s->resultset('Stock::Stock')->find({uniquename=>"${prefix}_plot_$_"})->stock_id}1..2;$target=$plots[1];
  my$type=term('phenotyping_experiment','experiment_type');my$e=$s->resultset('NaturalDiversity::NdExperiment')->create({type_id=>$type,nd_geolocation_id=>$s->resultset('NaturalDiversity::NdGeolocation')->first->nd_geolocation_id});$e->create_related('nd_experiment_projects',{project_id=>$trial});$e->create_related('nd_experiment_stocks',{stock_id=>$target,type_id=>$type});
  my$p=$s->resultset('Phenotype::Phenotype')->create({uniquename=>$prefix.'_measurement',cvalue_id=>70666,observable_id=>70666,value=>17,operator=>'janedoe'});$phenotype=$p->phenotype_id;$e->create_related('nd_experiment_phenotypes',{phenotype_id=>$phenotype});
 });
 ok($trial&&$target&&$phenotype,'private native fixture committed for independent connections');
 my$original=\&CXGN::Trial::DesignReplication::read;
 for my$kind(qw(Native TrialLayoutSearch BrAPIUnit)){
  change($stocks[1]);
  my($armed,$hooks)=(1,0);my$boundary=$kind eq'Native'?'CXGN::Phenotypes::Search::Native::search':'CXGN::Trial::TrialLayoutSearch::search';
  no warnings 'redefine';local*CXGN::Trial::DesignReplication::read=sub{
   my$caller=(caller(1))[3]//'';
   if($armed&&$caller eq$boundary){$armed=0;++$hooks;change($stocks[0])}
   return$original->(@_);
  };
  my$pair;
  if($kind eq'Native'){
   my($rows)=CXGN::Phenotypes::SearchFactory->instantiate('Native',{bcs_schema=>$s,data_level=>'plot',trial_list=>[$trial],plot_list=>[$target],trait_list=>[70666]})->search;
   my($row)=grep{defined($_->{phenotype_id})&&$_->{phenotype_id}==$phenotype}@$rows;die'Native measured row missing'if!$row;$pair=[$row->{accession_stock_id},$row->{obsunit_accession_occurrence}];
  }elsif($kind eq'TrialLayoutSearch'){
   my($rows)=CXGN::Trial::TrialLayoutSearch->new({bcs_schema=>$s,data_level=>'plot',trial_list=>[$trial],observation_unit_id_list=>[$target]})->search;die'Layout expected one row'if@$rows!=1;$pair=[$rows->[0]{germplasm_stock_id},$rows->[0]{accession_occurrence}];
  }else{
   my$r=CXGN::BrAPI::v2::ObservationUnits->new({bcs_schema=>$s,metadata_schema=>$f->metadata_schema,phenome_schema=>$f->phenome_schema,people_schema=>$f->people_schema,context=>$context,page=>0,page_size=>10,status=>[]})->detail($target,$context);die'Unit detail failed '.encode_json($r)if!$r->{result};$pair=[$r->{result}{germplasmDbId},$r->{result}{additionalInfo}{accessionOccurrence}];
  }
  is($hooks,1,"$kind hook fired once at the actual pre-enrichment boundary");
  is_deeply(current_pair(),[$stocks[0],2],"$kind independent actual service correction committed A plus occurrence2");
  my$coherent=($pair->[0]==$stocks[1]&&defined($pair->[1])&&$pair->[1]==1)||($pair->[0]==$stocks[0]&&defined($pair->[1])&&$pair->[1]==2);
  ok($coherent,"$kind read never combines the old B identity with new A occurrence")or diag(encode_json({reader=>$kind,returned=>$pair,live=>current_pair()}));
  ok($dbh->{AutoCommit},"$kind reader leaves its connection outside an owned transaction");
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
