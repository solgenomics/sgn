use strict;
use warnings;
use lib 't/lib';
use Test::More;
use File::Temp qw(tempfile);
use SGN::Test::Fixture;
use SGN::Model::Cvterm;
use CXGN::Trial;
use CXGN::Trial::TrialCreate;
use CXGN::Trial::TrialLayout;
use CXGN::Trial::AccessionChange;

# Synthetic factor/identity contracts through actual TrialCreate/AccessionChange.
# This is not acceptance of an agricolae Alpha/Lattice randomization or a model.
# The first edit must snapshot recorded design membership before assigning
# accession occurrence numbers. Every fixture is inside an outer rollback.
my $f=SGN::Test::Fixture->new;
my $s=$f->bcs_schema;my $dbh=$s->storage->dbh;
$s->storage->auto_savepoint(1);
my $serial=0;
my %term;
sub term {my($name,$cv)=@_;return $term{"$cv/$name"} ||= SGN::Model::Cvterm->get_cvterm_row($s,$name,$cv)->cvterm_id}
sub property {
 my($id,$name,@set)=@_;
 my $type=term($name,'stock_property');
 my $rs=$s->resultset('Stock::Stockprop')->search({stock_id=>$id,type_id=>$type});
 if (@set) {$rs->delete;$s->resultset('Stock::Stockprop')->create({stock_id=>$id,type_id=>$type,value=>$set[0],rank=>0}) if defined($set[0])}
 my $row=$rs->first;return $row ? $row->value : undef;
}
sub values_for {my($ids,$name)=@_;return [map {property($_,$name)} @$ids]}
sub germplasm {my($id)=@_;return $s->resultset('Stock::StockRelationship')->find({subject_id=>$id,type_id=>term('plot_of','stock_relationship')})->object_id}
sub create_layout {
 my($kind)=@_;my $prefix='audit_all_design_'.++$serial;
 my @stocks=map {$s->resultset('Stock::Stock')->find({uniquename=>"test_accession$_"})->stock_id} 1..3;
 my @accessions=qw(test_accession1 test_accession2 test_accession3 test_accession1 test_accession2 test_accession3);
 my %design=map {my $i=$_;($i=>{plot_name=>"${prefix}_plot_$i",plot_number=>$i,stock_name=>$accessions[$i-1],rep_number=>$i<=3 ? 10:30,block_number=>$i<=3 ? 10:30,row_number=>$i<=3 ? 1:2,col_number=>1+($i-1)%3})} 1..6;
 my $created=CXGN::Trial::TrialCreate->new({chado_schema=>$s,dbh=>$dbh,owner_id=>41,operator=>'janedoe',program=>'test',trial_location=>'test_location',trial_name=>$prefix,trial_description=>'Rollback-only occurrence/design-factor service contract',trial_year=>2031,design_type=>$kind,design=>\%design})->save_trial;
 die 'Native trial fixture setup failed' if !$created->{trial_id};
 my @plots=map {$s->resultset('Stock::Stock')->find({uniquename=>"${prefix}_plot_$_"})->stock_id} 1..6;
 # This suite tests conversion of existing records, independently of whether
 # the current forward creation path already captures and normalizes fields.
 for my $i (0..$#plots) {
  property($plots[$i],'replicate',$i<3 ? 10:30);
  property($plots[$i],'design_replicate',undef);
 }
 $s->resultset('Project::Projectprop')->search({project_id=>$created->{trial_id},type_id=>term('accession_occurrence_version','project_property')})->delete;
 CXGN::Trial::TrialLayout->new({schema=>$s,trial_id=>$created->{trial_id},experiment_type=>'field_layout'})->generate_and_cache_layout;

 return {prefix=>$prefix,trial=>$created->{trial_id},plots=>\@plots,stocks=>\@stocks};
}
sub service {return CXGN::Trial::AccessionChange->new({schema=>$s,trial_id=>$_[0]{trial}})}
sub merge_change {my($x)=@_;return [{plot_id=>$x->{plots}[1],new_stock_id=>$x->{stocks}[0]}]}
sub apply {my($x,$changes)=@_;return service($x)->apply($changes,{curator=>1,rename_plots=>'none'})}
sub scenario {
 my($name,$code)=@_;
 return if $ENV{AUDIT_OCCURRENCE_CASE} && index($name,$ENV{AUDIT_OCCURRENCE_CASE})<0;
 subtest $name=>sub {$s->txn_begin;my $ran=eval {$code->();1};my $error=$@;$s->txn_rollback;ok($ran,'actual owner scenario completed and rolled back') or diag($error)};
}
my $tx=0;END {eval{$s->txn_rollback if $tx} if $s}
$s->txn_begin;$tx=1;
my $ran=eval {
 # Supply the proposed standard stock property inside this rollback only, so
 # baseline failure measures the service contract rather than missing schema.
 my $design_term=$s->resultset('Cv::Cvterm')->search({'me.name'=>'design_replicate','cv.name'=>'stock_property'},{join=>'cv'})->first;
 if (!$design_term) {
  my $rep=$s->resultset('Cv::Cvterm')->find(term('replicate','stock_property'));
  my $xref=$s->resultset('General::Dbxref')->create({db_id=>$rep->dbxref->db_id,accession=>'audit_design_replicate_contract_'.$$});
  $design_term=$s->resultset('Cv::Cvterm')->create({name=>'design_replicate',cv_id=>$rep->cv_id,dbxref_id=>$xref->dbxref_id,definition=>'Recorded design replication before accession occurrence renumbering'});
 }
 $term{'stock_property/design_replicate'}=$design_term->cvterm_id;
 my $version=$s->resultset('Cv::Cvterm')->search({'me.name'=>'accession_occurrence_version','cv.name'=>'project_property'},{join=>'cv'})->first;
 if (!$version) {
  my $template=SGN::Model::Cvterm->get_cvterm_row($s,'design','project_property');
  my $xref=$s->resultset('General::Dbxref')->create({db_id=>$template->dbxref->db_id,accession=>'audit_occurrence_version_contract_'.$$});
  $version=$s->resultset('Cv::Cvterm')->create({name=>'accession_occurrence_version',cv_id=>$template->cv_id,dbxref_id=>$xref->dbxref_id});
 }

 # This covers every accepted field design through the common native store.
 # Randomization validity is covered separately by actual agricolae generators.
 for my $kind (qw(CRD Alpha MAD Lattice Augmented RCBD RRC DRRC URDD ARC p-rep splitplot stripplot greenhouse Westcott)) {
  scenario "$kind native store and common correction preserve physical design"=>sub {
   my $x=create_layout($kind);
   apply($x,merge_change($x));
   is_deeply(values_for($x->{plots},'replicate'),[1,2,1,3,1,2],'all planned accession occurrences use the same contract');
   is_deeply(values_for($x->{plots},'design_replicate'),[10,10,10,30,30,30],'recorded physical replication survives correction');
   is_deeply(values_for($x->{plots},'block'),[10,10,10,30,30,30],'recorded physical blocks survive correction');
  };
 }
 scenario 'RCBD merge snapshots design membership and numbers all planned occurrences'=>sub {
  my $x=create_layout('RCBD');my $svc=service($x);
  my $preview=$svc->plan(merge_change($x),{curator=>1,rename_plots=>'none'});
  is_deeply($preview->{errors},[],'merge preview is valid');
  ok(@{$preview->{replicates}}>0,'non-CRD preview contains the required occurrence renumbering');
  apply($x,merge_change($x));
  is_deeply(values_for($x->{plots},'replicate'),[1,2,1,3,1,2],'both affected and initially noncontiguous unaffected accession occurrences are 1..N');
  is_deeply(values_for($x->{plots},'design_replicate'),[10,10,10,30,30,30],'recorded design group survives the first correction');
  is_deeply(values_for($x->{plots},'block'),[10,10,10,30,30,30],'actual block membership is preserved');
  apply($x,[{plot_id=>$x->{plots}[4],new_stock_id=>$x->{stocks}[2]}]);
  is_deeply(values_for($x->{plots},'design_replicate'),[10,10,10,30,30,30],'second correction never snapshots occurrence numbers over design groups');
  is_deeply(values_for($x->{plots},'replicate'),[1,2,1,3,2,3],'later merge renumbers the affected final accession occurrences');
 };
 scenario 'Missing, zero and noncontiguous recorded replicas keep their distinct provenance'=>sub {
  my $x=create_layout('CRD');
  property($x->{plots}[0],'replicate',undef);property($x->{plots}[1],'replicate','0');property($x->{plots}[2],'replicate','80');
  apply($x,merge_change($x));
  is_deeply(values_for($x->{plots},'replicate'),[1,2,1,3,1,2],'missing/zero old occurrence properties do not create gaps or exclude a plot');
  is_deeply(values_for($x->{plots},'design_replicate'),[undef,0,80,30,30,30],'missing and scalar zero are not replaced by a guessed design group');
  is($s->resultset('Stock::Stockprop')->search({stock_id=>$x->{plots}[0],type_id=>term('design_replicate','stock_property')})->count,1,'a nullable snapshot row records the original missing value');
  apply($x,[{plot_id=>$x->{plots}[4],new_stock_id=>$x->{stocks}[2]}]);
  is(property($x->{plots}[0],'design_replicate'),undef,'recorded missing design replica remains missing after another correction');
  is(property($x->{plots}[1],'design_replicate'),'0','recorded zero remains zero after another correction');
 };
 scenario 'No-op and status-only requests do not renumber legacy occurrences'=>sub {
  my $x=create_layout('RCBD');my $before=values_for($x->{plots},'replicate');
  apply($x,[{plot_id=>$x->{plots}[1],new_stock_id=>$x->{stocks}[1]}]);
  is_deeply(values_for($x->{plots},'replicate'),$before,'same-accession no-op does not force normalization');
  apply($x,[{plot_id=>$x->{plots}[1],rejected=>1}]);
  is_deeply(values_for($x->{plots},'replicate'),$before,'status-only update does not force normalization');
  is(property($x->{plots}[1],'rejected'),'1','status action itself still applies');
 };
 scenario 'A swap counts the final trial state and keeps recorded design groups'=>sub {
  my $x=create_layout('RCBD');
  apply($x,[{plot_id=>$x->{plots}[0],new_stock_id=>$x->{stocks}[1]},{plot_id=>$x->{plots}[1],new_stock_id=>$x->{stocks}[0]}]);
  is(germplasm($x->{plots}[0]),$x->{stocks}[1],'first plot has the other accession');
  is(germplasm($x->{plots}[1]),$x->{stocks}[0],'second plot has the other accession');
  is_deeply(values_for($x->{plots},'replicate'),[1,1,1,2,2,2],'swap occurrence numbers derive from final memberships');
  is_deeply(values_for($x->{plots},'design_replicate'),[10,10,10,30,30,30],'swap does not exchange fixed physical design membership');
 };
 scenario 'Unplanted, rejected and check positions remain in the planned occurrence sequence'=>sub {
  my $x=create_layout('RCBD');
  property($x->{plots}[0],'not_planted','1');property($x->{plots}[3],'rejected','1');property($x->{plots}[5],'is a control','1');
  apply($x,merge_change($x));
  is_deeply(values_for($x->{plots},'replicate'),[1,2,1,3,1,2],'statuses and checks do not compress or renumber other planned positions');
  is(property($x->{plots}[0],'not_planted'),'1','unplanted status remains');
  is(property($x->{plots}[3],'rejected'),'1','rejection remains');
  is(property($x->{plots}[5],'is a control'),'1','unrelated check remains');
 };
 scenario 'Occurrence ordering is numeric by plot number and stable by plot ID'=>sub {
  my $x=create_layout('RCBD');
  property($x->{plots}[0],'plot number','10');property($x->{plots}[1],'plot number','2');property($x->{plots}[3],'plot number','1');
  apply($x,merge_change($x));
  is_deeply(values_for($x->{plots},'replicate'),[3,2,1,1,1,2],'physical numeric order wins over lexical order and prior design replica');
 };
 scenario 'Children inherit field occurrences while an external sampling project keeps its factors'=>sub {
  my $x=create_layout('RCBD');
  my(undef,$temp)=tempfile(TMPDIR=>1,UNLINK=>1);
  my $config={(map {$_=>$f->config->{$_}} qw(basepath dbhost dbname dbuser dbpass)),temp_file_nd_experiment_id=>$temp,user_id=>41,metadata_hash=>{archived_file=>'none',archived_file_type=>'new stock treatment auto inheritance',operator=>'janedoe',date=>'2031-01-01'}};
  my $trial=CXGN::Trial->new({bcs_schema=>$s,trial_id=>$x->{trial},metadata_schema=>$f->metadata_schema,phenome_schema=>$f->phenome_schema});
  die 'Native plant creation failed' if !$trial->create_plant_entities(1,1,undef,undef,undef,undef,$config);
  die 'Native tissue creation failed' if !$trial->create_tissue_samples(['leaf'],0,0,undef,undef,$config);
  my @plants=map {$_->object_id} $s->resultset('Stock::StockRelationship')->search({'me.subject_id'=>$x->{plots}[1],'me.type_id'=>term('plant_of','stock_relationship'),'object.type_id'=>term('plant','stock_type')},{join=>'object'})->all;
  my @samples=map {$_->subject_id} $s->resultset('Stock::StockRelationship')->search({'me.object_id'=>$x->{plots}[1],'me.type_id'=>term('tissue_sample_of','stock_relationship'),'subject.type_id'=>term('tissue_sample','stock_type')},{join=>'subject'})->all;
  die 'Missing native field descendants' if !@plants || !@samples;
  my $source_name=$s->resultset('Stock::Stock')->find($x->{plots}[1])->uniquename;
  my $sample_name="$x->{prefix}_external_sample";
  my $external=CXGN::Trial::TrialCreate->new({chado_schema=>$s,dbh=>$dbh,owner_id=>41,operator=>'janedoe',program=>'test',trial_location=>'test_location',trial_name=>"$x->{prefix}_sampling",trial_description=>'Separate native sampling layout',trial_year=>2031,design_type=>'sampling_trial',is_sampling_trial=>1,sampling_trial_facility=>'audit',sampling_trial_sample_type=>'leaf',sampling_trial_from_field_trial=>[$x->{trial}],design=>{1=>{plot_name=>$sample_name,plot_number=>1,stock_name=>$source_name,rep_number=>77,block_number=>9,row_number=>1,col_number=>1}}})->save_trial;
  die 'Native external sampling layout failed' if !$external->{trial_id};
  my $external_sample=$s->resultset('Stock::Stock')->find({uniquename=>$sample_name})->stock_id;
  property($external_sample,'design_replicate',77);
  my $plan=apply($x,merge_change($x));
  is_deeply(values_for([@plants,@samples],'replicate'),[(2) x (@plants+@samples)],'native in-trial descendants share their parent occurrence');
  is_deeply(values_for([@plants,@samples],'design_replicate'),[(10) x (@plants+@samples)],'native descendants preserve the source physical design group');
  is(property($external_sample,'replicate'),77,'external sample local replica is not overwritten by field occurrence');
  is(property($external_sample,'design_replicate'),77,'external sample recorded design membership stays local');
  is(property($external_sample,'block'),9,'external sample local block stays local');
  my $external_accession=$s->resultset('Stock::StockRelationship')->find({subject_id=>$external_sample,object_id=>$x->{stocks}[0],type_id=>term('tissue_sample_of','stock_relationship')});
  ok($external_accession,'external sample accession still follows the corrected source identity');
  ok((grep {$_==$external->{trial_id}} @{$plan->{affected_project_ids}}),'external project is included in cache invalidation scope');
 };
 scenario 'A design-membership edit invalidates an earlier preview'=>sub {
  my $x=create_layout('RCBD');my $svc=service($x);my $changes=merge_change($x);my $options={curator=>1,rename_plots=>'none'};
  my $preview=$svc->plan($changes,$options);is_deeply($preview->{errors},[],'preview valid');
  my $digest=$svc->plan_digest($preview);property($x->{plots}[2],'design_replicate','99');
  isnt($svc->plan_digest($svc->plan($changes,$options)),$digest,'digest notices changed recorded design membership');
  my $saved=eval {$svc->apply($changes,{%$options,plan_digest=>$digest});1};
  ok(!$saved,'stale preview is refused');
  is(germplasm($x->{plots}[1]),$x->{stocks}[1],'stale apply did not change accession');
  is(property($x->{plots}[2],'design_replicate'),'99','concurrent metadata remains intact');
 };
 1;
};
my $error=$@;$s->txn_rollback;$tx=0;
ok($ran,'all occurrence/design contracts completed and all fixtures rolled back') or diag($error);
done_testing;
