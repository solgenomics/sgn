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

# This test needs committed, private fixtures because the writers use separate
# connections. Cleanup deletes only IDs created here; never use global max-ID cleanup.
# Release both independently verified objects before store(), so the project
# lock must serialize a fresh lookup inside the actual write transaction.
my $f=SGN::Test::Fixture->new;
my $s=$f->bcs_schema;my $dbh=$s->storage->dbh;
my $dir=tempdir(CLEANUP=>1);
my $prefix="audit_store_concurrency_$$";
my($trial,$trait,$xref,$plot,$plot_name,$trait_name);
my @children;
sub touch {open(my $h,'>',$_[0]) or die "$!";close($h)}
sub await_file {my($path,$seconds)=@_;my $until=time+$seconds;until(-f $path){die "Barrier timeout $path\n" if time>$until;sleep .025}}
sub cleanup {
 return unless defined($trial) || defined($trait);
 # Every stock/experiment below belongs to this newly-created, private project.
 $s->txn_do(sub {
  if ($trial) {
   my $ids=$dbh->selectcol_arrayref('SELECT DISTINCT nd_experiment_id FROM nd_experiment_project WHERE project_id=?',undef,$trial);
   my $stocks=defined($plot) ? [$plot] : []; # never include linked germplasm stocks
   my $phenotypes=$dbh->selectcol_arrayref('SELECT DISTINCT phenotype_id FROM nd_experiment_phenotype WHERE nd_experiment_id=ANY(?)',undef,$ids);
   $dbh->do('DELETE FROM phenotype WHERE phenotype_id=ANY(?)',undef,$phenotypes) if @$phenotypes;
   $dbh->do('DELETE FROM nd_experiment WHERE nd_experiment_id=ANY(?)',undef,$ids) if @$ids;
   $dbh->do('DELETE FROM phenome.stock_owner WHERE stock_id=ANY(?)',undef,$stocks) if @$stocks;
   $dbh->do('DELETE FROM stock WHERE stock_id=ANY(?)',undef,$stocks) if @$stocks;
   $dbh->do('DELETE FROM phenome.project_owner WHERE project_id=?',undef,$trial);
   $dbh->do('DELETE FROM project WHERE project_id=?',undef,$trial);
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
 my $template=$s->resultset('Cv::Cvterm')->find(70741);
 my $dbxref=$s->resultset('General::Dbxref')->create({db_id=>$template->dbxref->db_id,accession=>$prefix});$xref=$dbxref->dbxref_id;
 my $variable=$s->resultset('Cv::Cvterm')->create({name=>$prefix,cv_id=>$template->cv_id,dbxref_id=>$xref,definition=>'Temporary independent repeated numeric observation'});$trait=$variable->cvterm_id;
 for my $r ($template->cvterm_relationship_subjects->search({'type.name'=>'VARIABLE_OF'},{join=>'type'})->all) {$s->resultset('Cv::CvtermRelationship')->create({subject_id=>$trait,object_id=>$r->object_id,type_id=>$r->type_id})}
 for my $pair (['trait_repeat_type','multiple'],['trait_format','numeric']) {$variable->create_related('cvtermprops',{type_id=>SGN::Model::Cvterm->get_cvterm_row($s,$pair->[0],'trait_property')->cvterm_id,value=>$pair->[1]})}
 $trait_name=SGN::Model::Cvterm::get_trait_from_cvterm_id($s,$trait,'extended');
 ok($trial && $plot && $trait,'created committed private trial, plot and repeated numeric variable');
 for my $number (1..2) {
  my $pid=fork();die 'fork failed' unless defined($pid);
  if (!$pid) {
   # Never let a child destructor close a parent-owned libpq connection.
   for my $schema ($f->bcs_schema,$f->metadata_schema,$f->phenome_schema,$f->people_schema,$f->sgn_schema) {$schema->storage->dbh->{InactiveDestroy}=1}
   $f->dbh->{InactiveDestroy}=1;
   my $worked=eval {
    my $child=SGN::Test::Fixture->new;
    my $class='CXGN::Phenotypes::StorePhenotypes';
    my $store=$class->new({basepath=>$child->config->{basepath},dbhost=>$child->config->{dbhost},dbname=>$child->config->{dbname},dbuser=>$child->config->{dbuser},dbpass=>$child->config->{dbpass},temp_file_nd_experiment_id=>"$dir/exp_$number",bcs_schema=>$child->bcs_schema,metadata_schema=>$child->metadata_schema,phenome_schema=>$child->phenome_schema,user_id=>41,stock_list=>[$plot_name],trait_list=>[$trait_name],values_hash=>{$plot_name=>{$trait_name=>[[($ENV{AUDIT_IDENTICAL_VALUES} ? 73 : 72+$number),'2030-11-03 10:00:00','janedoe','']]}},has_timestamps=>1,overwrite_values=>0,metadata_hash=>{operator=>'janedoe',date=>'2030-11-03_12:00:00'},composable_validation_check_name=>$child->config->{composable_validation_check_name}});
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
 await_file("$dir/ready_1",20);await_file("$dir/ready_2",20);
 pass('both independent writers verified their objects before start');touch("$dir/start");
 for my $number (1..2) {
  await_file("$dir/result_$number",30);open(my $in,'<',"$dir/result_$number") or die $!;local $/;my $result=JSON::decode_json(<$in>);close($in);
  ok($result->{ok},"actual writer $number finished without storage error") or diag($result->{error});
 }
 waitpid($_,0) for @children;@children=();
 my $rows=$dbh->selectall_arrayref('SELECT DISTINCT phenotype_id,value,collect_date FROM phenotype JOIN nd_experiment_phenotype USING(phenotype_id) JOIN nd_experiment_stock USING(nd_experiment_id) WHERE stock_id=? AND cvalue_id=? AND collect_date=?',{Slice=>{}},$plot,$trait,'2030-11-03 10:00:00');
 is(scalar(@$rows),1,'two concurrent same-key writes keep one unit-variable-time observation');
 diag(JSON::encode_json({trial=>$trial,stock=>$plot,trait=>$trait,rows=>$rows}));
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
}
done_testing;
