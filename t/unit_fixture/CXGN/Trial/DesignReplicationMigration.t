use strict;
use warnings;
use lib 't/lib';
use lib 'db/00211';
use Test::More;
use JSON ();
use SGN::Test::Fixture;
use SGN::Model::Cvterm;
use CXGN::Trial::TrialCreate;
use CXGN::Trial::DesignReplication;
use AddDesignReplicationStockprop;

# Execute the actual patch method/SQL in a rollback schema. Its connection
# constructor alone is redirected, so this does not test the independent cloned
# connection's commit lifecycle (the isolated migration runner owns that check).
my $f=SGN::Test::Fixture->new;my $s=$f->bcs_schema;my $dbh=$s->storage->dbh;
$s->storage->auto_savepoint(1);
my $prefix='audit_design_migration_'.$$;
my($trial,$external_trial,$external_sample,$field_experiment);
my(@plots,@pools);my $other_source;my %types;
sub term {my($name,$cv)=@_;return $types{"$cv/$name"} ||= SGN::Model::Cvterm->get_cvterm_row($s,$name,$cv)->cvterm_id}
sub prop {
 my($id,$name,$value,$remove)=@_;my $type=term($name,'stock_property');
 $s->resultset('Stock::Stockprop')->search({stock_id=>$id,type_id=>$type})->delete;
 $s->resultset('Stock::Stockprop')->create({stock_id=>$id,type_id=>$type,value=>$value,rank=>0}) if !$remove;
}
sub raw_rows {
 my($ids,$name)=@_;return $dbh->selectall_arrayref('SELECT stock_id,rank,value FROM stockprop WHERE stock_id=ANY(?) AND type_id=? ORDER BY stock_id,rank',undef,$ids,term($name,'stock_property'));
}
sub snapshot {
 my($ids)=@_;return CXGN::Trial::DesignReplication::read($s,$ids);
}
{package MigrationOwnerContext;sub dbh {$_[0]{dbh}}}
sub run_patch {
 my $connects=0;
 {
  no warnings 'redefine';
  local *Bio::Chado::Schema::connect=sub {++$connects;return $s};
  AddDesignReplicationStockprop::patch(bless({dbh=>$dbh},'MigrationOwnerContext'));
 }
 is($connects,1,'actual migration used the controlled rollback schema constructor');
 ok(!$dbh->{AutoCommit},'migration retained the enclosing fixture transaction');
}
sub pool {
 my($suffix,$parents)=@_;my $template=$s->resultset('Stock::Stock')->find({uniquename=>'test_accession1'});
 my $stock=$s->resultset('Stock::Stock')->create({name=>"${prefix}_$suffix",uniquename=>"${prefix}_$suffix",organism_id=>$template->organism_id,type_id=>term('tissue_sample','stock_type')});
 for my $parent (@$parents) {$stock->create_related('stock_relationship_subjects',{object_id=>$parent,type_id=>term('tissue_sample_of','stock_relationship')})}
 $stock->create_related('stock_relationship_subjects',{object_id=>$template->stock_id,type_id=>term('tissue_sample_of','stock_relationship')});
 $stock->create_related('nd_experiment_stocks',{nd_experiment_id=>$field_experiment,type_id=>term('field_layout','experiment_type')});
 prop($stock->stock_id,'replicate',77);return $stock->stock_id;
}
my $tx=0;END {eval{$s->txn_rollback if $tx} if $s}
$s->txn_begin;$tx=1;
my $ran=eval {
 $s->resultset('Cv::Cvterm')->create_with({name=>'design_replicate',cv=>'stock_property',definition=>'Recorded field design group'});
 $s->resultset('Cv::Cvterm')->create_with({name=>'accession_occurrence_version',cv=>'project_property',definition=>'Field occurrence cutover version'});
 my %layout=map {my $i=$_;($i=>{plot_name=>"${prefix}_plot_$i",plot_number=>$i,stock_name=>'test_accession'.(1+($i-1)%3),rep_number=>1,block_number=>$i<=4 ? 10:30,row_number=>1,col_number=>$i})} 1..7;
 my $created=CXGN::Trial::TrialCreate->new({chado_schema=>$s,dbh=>$dbh,owner_id=>41,operator=>'janedoe',program=>'test',trial_location=>'test_location',trial_name=>$prefix,trial_year=>2031,trial_description=>'Legacy metadata migration fixture',design_type=>'CRD',design=>\%layout})->save_trial;
 $trial=$created->{trial_id};die 'Native fixture creation failed' if !$trial;
 @plots=map {$s->resultset('Stock::Stock')->find({uniquename=>"${prefix}_plot_$_"})->stock_id} 1..7;
 ($field_experiment)=$dbh->selectrow_array('SELECT ne.nd_experiment_id FROM nd_experiment ne JOIN nd_experiment_project nep USING(nd_experiment_id) WHERE nep.project_id=? AND ne.type_id=?',undef,$trial,term('field_layout','experiment_type'));
 # Restore exact legacy states after the current forward creation hook.
 for my $id (@plots) {prop($id,'design_replicate',undef,1)}
 $s->resultset('Project::Projectprop')->search({project_id=>$trial,type_id=>term('accession_occurrence_version','project_property')})->delete;
 prop($plots[0],'replicate',0);prop($plots[1],'replicate',0);
 prop($plots[2],'replicate',undef,1);prop($plots[3],'replicate',undef);
 prop($plots[4],'replicate',30);prop($plots[5],'replicate',123);prop($plots[6],'replicate',55);
 prop($plots[5],'design_replicate',99);prop($plots[6],'design_replicate','NA');
 @pools=(pool('same_zero',[@plots[0,1]]),pool('conflicting_zero_unknown',[@plots[0,2]]),pool('all_unknown',[@plots[2,3]]));
 # A pool can have a source in another field trial even if the pooled stock
 # itself has direct membership only in this trial. Equal text labels are not
 # evidence that the two study-scoped physical groups are identical.
 my $source_trial=CXGN::Trial::TrialCreate->new({chado_schema=>$s,dbh=>$dbh,owner_id=>41,operator=>'janedoe',program=>'test',trial_location=>'test_location',trial_name=>"${prefix}_source_field",trial_year=>2031,trial_description=>'Second source field context',design_type=>'CRD',design=>{1=>{plot_name=>"${prefix}_other_source",plot_number=>1,stock_name=>'test_accession1',rep_number=>0,block_number=>0,row_number=>1,col_number=>1}}})->save_trial;
 die 'Second native source field failed' if !$source_trial->{trial_id};
 $other_source=$s->resultset('Stock::Stock')->find({uniquename=>"${prefix}_other_source"})->stock_id;
 prop($other_source,'replicate',0);prop($other_source,'design_replicate',undef,1);
 $s->resultset('Project::Projectprop')->search({project_id=>$source_trial->{trial_id},type_id=>term('accession_occurrence_version','project_property')})->delete;
 push @pools,pool('cross_field_equal_zero',[$plots[0],$other_source]);

 my $external_name="${prefix}_external";
 my $external=CXGN::Trial::TrialCreate->new({chado_schema=>$s,dbh=>$dbh,owner_id=>41,operator=>'janedoe',program=>'test',trial_location=>'test_location',trial_name=>"${prefix}_sampling",trial_year=>2031,trial_description=>'Independent local sampling factors',design_type=>'sampling_trial',is_sampling_trial=>1,sampling_trial_facility=>'audit',sampling_trial_sample_type=>'leaf',sampling_trial_from_field_trial=>[$trial],design=>{1=>{plot_name=>$external_name,plot_number=>1,stock_name=>"${prefix}_plot_1",rep_number=>88,block_number=>9,row_number=>1,col_number=>1}}})->save_trial;
 $external_trial=$external->{trial_id};die 'Native sampling fixture failed' if !$external_trial;
 $external_sample=$s->resultset('Stock::Stock')->find({uniquename=>$external_name})->stock_id;prop($external_sample,'design_replicate',undef,1);
 my @ids=(@plots,@pools,$external_sample,$other_source);my $before_rep=raw_rows(\@ids,'replicate');my $before_block=raw_rows(\@ids,'block');
 my $before_rel=$dbh->selectall_arrayref('SELECT subject_id,object_id,type_id,rank FROM stock_relationship WHERE subject_id=ANY(?) OR object_id=ANY(?) ORDER BY stock_relationship_id',undef,\@ids,\@ids);
 run_patch();
 is_deeply(raw_rows(\@ids,'replicate'),$before_rep,'migration never normalizes, inserts or rewrites occurrence properties');
 is_deeply(raw_rows(\@ids,'block'),$before_block,'migration preserves all physical blocks');
 my $read=snapshot(\@ids);
 is_deeply([map {$read->{$_}{value}} @plots],[0,0,undef,undef,30,99,'NA'],'legacy zero/absent/NULL/groups and existing snapshots are retained exactly');
 is_deeply([map {$read->{$_}{recorded}} @plots],[(1)x7],'every field plot has an explicit snapshot row including missing values');
 is_deeply([map {$read->{$_}{value}} @pools],[0,undef,undef,undef],'pooled descendants retain unanimous zero and record conflicting or cross-study groups as NULL');
 is_deeply([map {$read->{$_}{recorded}} @pools],[(1)x4],'pooled unknowns have explicit recorded rows');
 is($read->{$external_sample}{recorded},0,'external sampling project is not assigned the source field group');
 is($read->{$external_sample}{value},88,'external sampling local legacy group remains available');
 ok(!(grep {$read->{$_}{occurrence_ready}} @ids),'snapshot-only migration does not claim counter cutover');
 is($s->resultset('Project::Projectprop')->search({project_id=>$trial,type_id=>term('accession_occurrence_version','project_property')})->count,0,'migration leaves the field cutover marker absent');
 is_deeply($dbh->selectall_arrayref('SELECT subject_id,object_id,type_id,rank FROM stock_relationship WHERE subject_id=ANY(?) OR object_id=ANY(?) ORDER BY stock_relationship_id',undef,\@ids,\@ids),$before_rel,'migration preserves every source and germplasm relationship');
 my $first_snapshot=raw_rows(\@ids,'design_replicate');
 prop($plots[0],'replicate',808);prop($plots[2],'replicate',909);
 my $second_rep=raw_rows(\@ids,'replicate');run_patch();
 is_deeply(raw_rows(\@ids,'design_replicate'),$first_snapshot,'rerun cannot replace existing zero or NULL snapshots with later counters');
 is_deeply(raw_rows(\@ids,'replicate'),$second_rep,'rerun never rewrites changed operational values');
 my $version=term('accession_occurrence_version','project_property');
 $s->resultset('Project::Projectprop')->create({project_id=>$trial,type_id=>$version,value=>'1',rank=>0});
 prop($plots[2],'design_replicate',undef,1);
 my $missing=snapshot([$plots[2]])->{$plots[2]};
 is($missing->{value},undef,'a missing snapshot after cutover must not masquerade as counter909');
 ok($missing->{missing_after_cutover},'missing snapshot after cutover is explicitly identified');
 # A second field membership invalidates counter readiness independently of
 # whether both projects advertise a completed cutover.
 my $other=$s->resultset('Project::Project')->create({name=>"${prefix}_other_field",description=>'Second field-layout membership'});
 $other->create_related('projectprops',{type_id=>$version,value=>'1',rank=>0});
 my $e=$s->resultset('NaturalDiversity::NdExperiment')->create({type_id=>term('field_layout','experiment_type'),nd_geolocation_id=>$s->resultset('NaturalDiversity::NdGeolocation')->first->nd_geolocation_id});
 $e->create_related('nd_experiment_projects',{project_id=>$other->project_id});$e->create_related('nd_experiment_stocks',{stock_id=>$plots[0],type_id=>term('field_layout','experiment_type')});
 my $multiple=snapshot([$plots[0]])->{$plots[0]};
 is_deeply($multiple->{field_projects},[sort {$a<=>$b} ($trial,$other->project_id)],'resolver reports all distinct field memberships');
 is($multiple->{occurrence_ready},0,'multiple field layouts cannot expose a unique accession occurrence');
 is($multiple->{value},0,'membership ambiguity never overwrites an explicit recorded zero group');
 1;
};
my $error=$@;$s->txn_rollback;$tx=0;
ok($ran,'actual migration data checks completed and all fixture changes rolled back') or diag($error);
done_testing;
