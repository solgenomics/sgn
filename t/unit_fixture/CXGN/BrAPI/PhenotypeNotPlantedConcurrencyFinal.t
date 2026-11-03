use strict;
use warnings;
use lib 't/lib';
use Test::More;
use File::Temp qw(tempdir);
use Time::HiRes qw(time sleep);
use POSIX ();
use JSON ();
use SGN::Test::Fixture;
use SGN::Model::Cvterm;
use CXGN::Trial::TrialCreate;
use CXGN::Phenotypes::StorePhenotypes;
use CXGN::Trial::AccessionChange;

# This test needs committed, private fixtures because the writers use separate
# connections. Cleanup deletes only IDs created here; never use global max-ID cleanup.
# AUDIT_FORCE_PRELOCK_BARRIER=1 qualifies the old implementation deterministically:
# the real Store status snapshot completes, then AccessionChange commits the unplanted status before Store resumes.
# The normal regression releases the verified object before store(), so project
# locking can serialize a fresh lookup without a barrier inside the critical section.
my $f=SGN::Test::Fixture->new;
my $s=$f->bcs_schema;my $dbh=$s->storage->dbh;
my $dir=tempdir(CLEANUP=>1);
my $prefix="audit_store_status_concurrency_$$";
my($trial,$sampling_trial,$sample,$trait,$xref,$plot,$plot_name,$unit,$unit_name,$trait_name);
my @children;
our($barrier_dir,$writer_number);
sub touch {open(my $h,'>',$_[0]) or die "$!";close($h)}
sub await_file {my($path,$seconds)=@_;my $until=time+$seconds;until(-f $path){die "Barrier timeout $path\n" if time>$until;sleep .025}}
{
 package AuditStoreSnapshotBarrier;
 our @ISA=('CXGN::Phenotypes::StorePhenotypes');
 sub not_planted_units {
  my $self=shift;my $value=$self->SUPER::not_planted_units(@_);
  if ($ENV{AUDIT_FORCE_PRELOCK_BARRIER} && (caller(1))[3] eq 'CXGN::Phenotypes::StorePhenotypes::store') {
   main::touch("$main::barrier_dir/snapshot_$main::writer_number");
   main::await_file("$main::barrier_dir/snapshots_released",20);
  }
  return $value;
 }
}
sub cleanup {
 return unless defined($trial) || defined($trait);
 # Every stock/experiment below belongs to this newly-created, private project.
 $s->txn_do(sub {
  if ($trial) {
   my @projects=grep {defined} ($trial,$sampling_trial);
   my $ids=$dbh->selectcol_arrayref('SELECT DISTINCT nd_experiment_id FROM nd_experiment_project WHERE project_id=ANY(?)',undef,\@projects);
   my $stocks=[grep {defined} ($plot,$sample)]; # never include linked germplasm stocks
   my $phenotypes=$dbh->selectcol_arrayref('SELECT DISTINCT phenotype_id FROM nd_experiment_phenotype WHERE nd_experiment_id=ANY(?)',undef,$ids);
   $dbh->do('DELETE FROM phenotype WHERE phenotype_id=ANY(?)',undef,$phenotypes) if @$phenotypes;
   $dbh->do('DELETE FROM nd_experiment WHERE nd_experiment_id=ANY(?)',undef,$ids) if @$ids;
   $dbh->do('DELETE FROM phenome.stock_owner WHERE stock_id=ANY(?)',undef,$stocks) if @$stocks;
   $dbh->do('DELETE FROM stock WHERE stock_id=ANY(?)',undef,$stocks) if @$stocks;
   $dbh->do('DELETE FROM phenome.project_owner WHERE project_id=ANY(?)',undef,\@projects);
   $dbh->do('DELETE FROM project WHERE project_id=ANY(?)',undef,\@projects);
  }
  if ($trait) {
   $dbh->do('DELETE FROM cvterm_relationship WHERE subject_id=? OR object_id=?',undef,$trait,$trait);
   $dbh->do('DELETE FROM cvtermprop WHERE cvterm_id=?',undef,$trait);
   $dbh->do('DELETE FROM cvterm WHERE cvterm_id=?',undef,$trait);
  }
  $dbh->do('DELETE FROM dbxref WHERE dbxref_id=?',undef,$xref) if $xref;
 });
}
my $ran=eval {
 my $created=CXGN::Trial::TrialCreate->new({chado_schema=>$s,dbh=>$dbh,owner_id=>41,operator=>'janedoe',program=>'test',trial_location=>'test_location',trial_name=>$prefix,trial_description=>'Isolated concurrent store regression',trial_year=>2030,design_type=>'CRD',design=>{1=>{plot_name=>"${prefix}_1",plot_number=>1,stock_name=>'test_accession1',block_number=>1,rep_number=>1,row_number=>1,col_number=>1}}})->save_trial;
 $trial=$created->{trial_id};die 'Trial creation failed' unless $trial;
 $plot_name="${prefix}_1";$plot=$s->resultset('Stock::Stock')->find({uniquename=>$plot_name})->stock_id;
 $unit=$plot;$unit_name=$plot_name;
 if ($ENV{AUDIT_EXTERNAL_SAMPLE}) {
  my $sample_name="${prefix}_sample";
  my $sampling=CXGN::Trial::TrialCreate->new({chado_schema=>$s,dbh=>$dbh,owner_id=>41,operator=>'janedoe',program=>'test',trial_location=>'test_location',trial_name=>"${prefix}_sampling",trial_description=>'Native sampling project of the independently stored source plot',trial_year=>2030,design_type=>'sampling_trial',is_sampling_trial=>1,sampling_trial_facility=>'audit',sampling_trial_sample_type=>'leaf',sampling_trial_from_field_trial=>[$trial],design=>{1=>{plot_name=>$sample_name,plot_number=>1,stock_name=>$plot_name,block_number=>1,rep_number=>1,row_number=>1,col_number=>1}}})->save_trial;
  $sampling_trial=$sampling->{trial_id};die 'Native sampling trial creation failed' if !$sampling_trial;
  $sample=$s->resultset('Stock::Stock')->find({uniquename=>$sample_name})->stock_id;
  $unit=$sample;$unit_name=$sample_name;
  my $memberships=$dbh->selectcol_arrayref(q{SELECT DISTINCT project_id FROM nd_experiment_stock JOIN nd_experiment_project USING(nd_experiment_id) JOIN nd_experiment USING(nd_experiment_id) JOIN cvterm ON(cvterm_id=nd_experiment.type_id) WHERE stock_id=? AND cvterm.name IN ('field_layout','sampling_layout')},undef,$sample);
  is_deeply([sort {$a<=>$b} @$memberships],[$sampling_trial],'native external sample belongs only to its separate sampling layout');
 }
 my $template=$s->resultset('Cv::Cvterm')->find(70741);
 my $dbxref=$s->resultset('General::Dbxref')->create({db_id=>$template->dbxref->db_id,accession=>$prefix});$xref=$dbxref->dbxref_id;
 my $variable=$s->resultset('Cv::Cvterm')->create({name=>$prefix,cv_id=>$template->cv_id,dbxref_id=>$xref,definition=>'Temporary independent repeated numeric observation'});$trait=$variable->cvterm_id;
 for my $r ($template->cvterm_relationship_subjects->search({'type.name'=>'VARIABLE_OF'},{join=>'type'})->all) {$s->resultset('Cv::CvtermRelationship')->create({subject_id=>$trait,object_id=>$r->object_id,type_id=>$r->type_id})}
 for my $pair (['trait_repeat_type','multiple'],['trait_format','numeric']) {$variable->create_related('cvtermprops',{type_id=>SGN::Model::Cvterm->get_cvterm_row($s,$pair->[0],'trait_property')->cvterm_id,value=>$pair->[1]})}
 $trait_name=SGN::Model::Cvterm::get_trait_from_cvterm_id($s,$trait,'extended');
 ok($trial && $plot && $trait,'created committed private trial, plot and repeated numeric variable');
 $barrier_dir=$dir;
 for my $number (1..1) {
  my $pid=fork();die 'fork failed' unless defined($pid);
  if (!$pid) {
   $writer_number=$number;
   # Never let a child destructor close a parent-owned libpq connection.
   for my $schema ($f->bcs_schema,$f->metadata_schema,$f->phenome_schema,$f->people_schema,$f->sgn_schema) {$schema->storage->dbh->{InactiveDestroy}=1}
   $f->dbh->{InactiveDestroy}=1;
   my $worked=eval {
    my $child=SGN::Test::Fixture->new;
    my $class=$ENV{AUDIT_FORCE_PRELOCK_BARRIER} ? 'AuditStoreSnapshotBarrier' : 'CXGN::Phenotypes::StorePhenotypes';
    my $store=$class->new({basepath=>$child->config->{basepath},dbhost=>$child->config->{dbhost},dbname=>$child->config->{dbname},dbuser=>$child->config->{dbuser},dbpass=>$child->config->{dbpass},temp_file_nd_experiment_id=>"$dir/exp_$number",bcs_schema=>$child->bcs_schema,metadata_schema=>$child->metadata_schema,phenome_schema=>$child->phenome_schema,user_id=>41,stock_list=>[$unit_name],trait_list=>[$trait_name],values_hash=>{$unit_name=>{$trait_name=>[[($ENV{AUDIT_IDENTICAL_VALUES} ? 73 : 72+$number),'2030-11-03 10:00:00','janedoe','']]}},has_timestamps=>1,overwrite_values=>0,metadata_hash=>{operator=>'janedoe',date=>'2030-11-03_12:00:00'},composable_validation_check_name=>$child->config->{composable_validation_check_name}});
    my($warning,$error)=$store->verify;die "Verify: $error" if $error;
    touch("$dir/ready_$number");await_file("$dir/start",20);
    my($store_error,$success)=$store->store;die "Store: $store_error" if $store_error;
    1;
   };
   open(my $out,'>',"$dir/result_$number.tmp") or POSIX::_exit(3);print $out JSON::encode_json({ok=>$worked ? 1:0,error=>"$@"});close($out) or POSIX::_exit(3);
   rename("$dir/result_$number.tmp","$dir/result_$number") or POSIX::_exit(3);
   POSIX::_exit($worked ? 0:1);
  }
  push @children,$pid;
 }
 await_file("$dir/ready_1",20);
 pass('independent writer verified its object before start');touch("$dir/start");
 if ($ENV{AUDIT_FORCE_PRELOCK_BARRIER}) {
  await_file("$dir/snapshot_1",20);
  pass('old Store not-planted snapshot held before its transaction');
 }
 my $status_applied=eval {CXGN::Trial::AccessionChange->new({schema=>$s,trial_id=>$trial})->apply([{plot_id=>$plot,not_planted=>1}],{curator=>1});1};
 my $status_error="$@"; # DBIx::Class may throw a blessed exception; diagnostics use text.
 touch("$dir/snapshots_released") if $ENV{AUDIT_FORCE_PRELOCK_BARRIER};
 await_file("$dir/result_1",30);open(my $in,'<',"$dir/result_1") or die $!;local $/;my $result=JSON::decode_json(<$in>);close($in);
 ok($result->{ok},'actual writer finished without storage error') or diag($result->{error});
 waitpid($_,0) for @children;@children=();
 my $rows=$dbh->selectall_arrayref('SELECT DISTINCT phenotype_id,value,collect_date FROM phenotype JOIN nd_experiment_phenotype USING(phenotype_id) JOIN nd_experiment_stock USING(nd_experiment_id) WHERE stock_id=? AND cvalue_id=? AND collect_date=?',{Slice=>{}},$unit,$trait,'2030-11-03 10:00:00');
 my $not_planted=$dbh->selectrow_array(q{SELECT count(*) FROM stockprop JOIN cvterm ON(cvterm_id=type_id) WHERE stock_id=? AND cvterm.name='not_planted' AND value='1'},undef,$plot);
 ok(!($not_planted && @$rows),'not-planted status and raw observations never coexist after the race');
 if ($status_applied) {
  is($not_planted,1,'successful status action persists not-planted');
  is(scalar(@$rows),0,'writer skips the now unplanted plot');
 } else {
  like($status_error,qr/were stored.*not planted|already.*phenotype/is,'status action refuses the measurements saved first');
  is($not_planted,0,'refused status did not mark the planted plot');
  is(scalar(@$rows),1,'the accepted raw measurement remains intact');
 }
 diag(JSON::encode_json({trial=>$trial,sampling_trial=>$sampling_trial,source_plot=>$plot,target_stock=>$unit,trait=>$trait,status_applied=>$status_applied ? 1:0,status_error=>$status_error,not_planted=>$not_planted,rows=>$rows}));
 1;
};
my $error=$@;
if (@children) {kill 'TERM',@children;waitpid($_,0) for @children}
my $clean=eval {cleanup();1};my $cleanup_error=$@;
ok($ran,'concurrency scenario completed') or diag($error);
ok($clean,'only the private committed fixture was removed') or diag($cleanup_error);
if ($clean) {
 is($dbh->selectrow_array('SELECT count(*) FROM project WHERE name=?',undef,$prefix),0,'no synthetic project remains');
 is($dbh->selectrow_array('SELECT count(*) FROM stock WHERE uniquename=?',undef,"${prefix}_1"),0,'no synthetic stock remains');
 is($dbh->selectrow_array('SELECT count(*) FROM cvterm WHERE name=?',undef,$prefix),0,'no synthetic variable remains');
 is($dbh->selectrow_array('SELECT count(*) FROM project WHERE name=?',undef,"${prefix}_sampling"),0,'no synthetic sampling project remains');
 is($dbh->selectrow_array('SELECT count(*) FROM stock WHERE uniquename=?',undef,"${prefix}_sample"),0,'no synthetic external sample remains');
}
done_testing;
