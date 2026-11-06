use strict;
use warnings;
use lib 't/lib';
use lib 'db/00211';
use Test::More;
use SGN::Test::Fixture;
use SGN::Model::Cvterm;
use CXGN::Trial::TrialCreate;
use CXGN::Trial::DesignReplication;
use AddDesignReplicationStockprop;

# Real independently cloned DBH, committed private records, exact-ID cleanup.
# No connection constructor or transaction method is replaced by this test.
my $fixture=SGN::Test::Fixture->new;
my $schema=$fixture->bcs_schema;
my $dbh=$schema->storage->dbh;
my $prefix='audit_design_clone_'.$$;
my ($trial,@plots);
my %types;
sub term {my($name,$cv)=@_;return $types{"$cv/$name"} ||= SGN::Model::Cvterm->get_cvterm_row($schema,$name,$cv)->cvterm_id}
{ package RealMigrationContext; sub dbh {$_[0]{dbh}} } ## no critic (Modules::RequireFilenameMatchesPackage) -- This test embeds its named test double beside the assertions.
sub patch {AddDesignReplicationStockprop::patch(bless({dbh=>$dbh},'RealMigrationContext'))}
sub property_rows {return $dbh->selectall_arrayref('SELECT stock_id,rank,value FROM stockprop WHERE stock_id=ANY(?) AND type_id=? ORDER BY stock_id,rank',undef,\@plots,term($_[0],'stock_property'))}
sub cleanup {
 return if !$trial;
 $schema->txn_do(sub {
  my $experiments=$dbh->selectcol_arrayref('SELECT nd_experiment_id FROM nd_experiment_project WHERE project_id=?',undef,$trial);
  $dbh->do('DELETE FROM nd_experiment WHERE nd_experiment_id=ANY(?)',undef,$experiments) if @$experiments;
  $dbh->do('DELETE FROM phenome.stock_owner WHERE stock_id=ANY(?)',undef,\@plots) if @plots;
  $dbh->do('DELETE FROM stock WHERE stock_id=ANY(?)',undef,\@plots) if @plots;
  $dbh->do('DELETE FROM phenome.project_owner WHERE project_id=?',undef,$trial);
  $dbh->do('DELETE FROM project WHERE project_id=?',undef,$trial);
 });
}
my $ran=eval {
 my %layout=map {$_=>{plot_name=>"${prefix}_P$_",plot_number=>$_,stock_name=>'test_accession1',rep_number=>$_,block_number=>$_,row_number=>1,col_number=>$_}} 1..2;
 my $created=CXGN::Trial::TrialCreate->new({chado_schema=>$schema,dbh=>$dbh,owner_id=>41,operator=>'janedoe',program=>'test',trial_location=>'test_location',trial_name=>$prefix,trial_description=>'Private committed migration lifecycle qualification',trial_year=>2031,design_type=>'RCBD',design=>\%layout})->save_trial;
 $trial=$created->{trial_id};die 'Private native trial creation failed' if !$trial;
 @plots=map {$schema->resultset('Stock::Stock')->find({uniquename=>"${prefix}_P$_"})->stock_id} 1..2;
 $schema->txn_do(sub {
  $schema->resultset('Stock::Stockprop')->search({stock_id=>{in=>\@plots},type_id=>term('design_replicate','stock_property')})->delete;
  $schema->resultset('Project::Projectprop')->search({project_id=>$trial,type_id=>term('accession_occurrence_version','project_property')})->delete;
  for my $i (0..1) {$schema->resultset('Stock::Stockprop')->find({stock_id=>$plots[$i],type_id=>term('replicate','stock_property'),rank=>0})->update({value=>$i ? undef:'01'})}
 });
 ok($dbh->{AutoCommit},'private legacy fixture committed before the independent migration');
 my $before=property_rows('replicate');
 patch();
 my $reader=SGN::Test::Fixture->new;
 isnt($reader->bcs_schema->storage->dbh->selectrow_array('SELECT pg_backend_pid()'),$dbh->selectrow_array('SELECT pg_backend_pid()'),'verification reader has an independent database connection'); # codespell:ignore isnt
 my $state=CXGN::Trial::DesignReplication::read($reader->bcs_schema,\@plots);
 is_deeply([map {$state->{$_}{value}} @plots],['01',undef],'real migration commit is visible to another connection with exact and NULL tags');
 is_deeply([map {$state->{$_}{recorded}} @plots],[1,1],'real migration commits explicit snapshot rows');
 is_deeply(property_rows('replicate'),$before,'real migration clone never rewrites legacy replicate values');
 ok(!(grep {$state->{$_}{occurrence_ready}} @plots),'migration commit does not falsely advertise normalized counters');
 my $snapshots=property_rows('design_replicate');patch();
 is_deeply(property_rows('design_replicate'),$snapshots,'real committed rerun is idempotent');
 # A corrupt single-valued property must roll back the migration, including its
 # snapshots, rather than silently choosing rank0 or leaving a partial cutover.
 $schema->resultset('Stock::Stockprop')->search({stock_id=>{in=>\@plots},type_id=>term('design_replicate','stock_property')})->delete;
 my $duplicate=$schema->resultset('Stock::Stockprop')->create({stock_id=>$plots[0],type_id=>term('replicate','stock_property'),value=>'other',rank=>1});
 my $saved=eval {patch();1};
 ok(!$saved,'real migration refuses duplicate single-valued replication rows');
 like($@,qr/multiple values for a single replication property/,'migration reports the ambiguous stock property');
 is_deeply(property_rows('design_replicate'),[],'failed independent migration leaves no partial private snapshots');
 $duplicate->delete;
 patch();
 is_deeply(property_rows('design_replicate'),$snapshots,'retry after correcting metadata commits the original complete snapshots');
 1;
};
my $error=$@;
my $clean=eval {cleanup();1};my $cleanup_error=$@;
ok($ran,'real migration lifecycle completed') or diag($error);
ok($clean,'exact-ID private fixture cleanup completed') or diag($cleanup_error);
if ($clean) {
 is($dbh->selectrow_array('SELECT count(*) FROM project WHERE name=?',undef,$prefix),0,'no private migration project remains');
 is($dbh->selectrow_array('SELECT count(*) FROM stock WHERE uniquename LIKE ?',undef,$prefix.'_P%'),0,'no private migration plots remain');
}
done_testing;
