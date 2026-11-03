use strict;
use warnings;
use lib 't/lib';
use Test::More;
use JSON qw(encode_json decode_json);
use SGN::Test::Fixture;
use SGN::Model::Cvterm;
use CXGN::Trial;
use CXGN::Trial::TrialLayout;
use CXGN::Trial::AccessionChange;
use CXGN::BrAPI::v2::ObservationUnits;
use CXGN::BrAPI::v1::ObservationUnits;

my $f=SGN::Test::Fixture->new;
my $s=$f->bcs_schema;
my $dbh=$s->storage->dbh;
$s->storage->auto_savepoint(1);
my $trial=$s->resultset('Project::Project')->find({name=>'test_trial'})->project_id;
my @plots=map {$s->resultset('Stock::Stock')->find({uniquename=>"test_trial2$_"})->stock_id} (10,11,12);
my $prefix='unit_atomic_final_';
my(@refresh,@clear);
{package UnitAtomicDbc;sub dbh {$_[0]{dbh}}} ## no critic (Modules::RequireFilenameMatchesPackage) -- This test embeds its named test double beside the assertions.
{package UnitAtomicClear;sub clear_cached_analyses_result {push @{$_[0]{calls}},$_[2];return 1}}
{package UnitAtomicContext;
 sub dbc {$_[0]{dbc}}
 sub config {$_[0]{config}}
 sub controller {$_[0]{clear}}
}
my $context=bless {dbc=>bless({dbh=>$dbh},'UnitAtomicDbc'),config=>$f->config,clear=>bless({calls=>\@clear},'UnitAtomicClear')},'UnitAtomicContext';
sub term {SGN::Model::Cvterm->get_cvterm_row($s,@_)->cvterm_id}
sub api {CXGN::BrAPI::v2::ObservationUnits->new({bcs_schema=>$s,metadata_schema=>$f->metadata_schema,phenome_schema=>$f->phenome_schema,people_schema=>$f->people_schema,context=>$context,page=>0,page_size=>10,status=>[]})}
sub api_v1 {CXGN::BrAPI::v1::ObservationUnits->new({bcs_schema=>$s,metadata_schema=>$f->metadata_schema,phenome_schema=>$f->phenome_schema,people_schema=>$f->people_schema,context=>$context,page=>0,page_size=>10,status=>[]})}
sub value {
 my($stock,$name,@value)=@_;
 my $type=term($name,'stock_property');my $rs=$s->resultset('Stock::Stockprop')->search({stock_id=>$stock,type_id=>$type});
 if(@value){$rs->delete;$s->resultset('Stock::Stockprop')->create({stock_id=>$stock,type_id=>$type,value=>$value[0],rank=>0}) if defined($value[0])}
 my $row=$rs->first;return $row?$row->value:undef;
}
sub accession {($dbh->selectrow_array('SELECT object_id FROM stock_relationship WHERE subject_id=? AND type_id=?',undef,$_[0],term('plot_of','stock_relationship')))[0]}
sub request_unit {my($id,%extra)=@_;return {observationUnitDbId=>"$id",%extra}}
sub scenario {
 my($name,$code)=@_;
 subtest $name=>sub {
  $s->txn_begin;@refresh=();@clear=();
  my $ok=eval {$code->();1};my $err=$@;$s->txn_rollback;
  ok($ok,'owning API model executed; scenario rolled back') or diag($err);
 };
}
sub layout {CXGN::Trial::TrialLayout->new({schema=>$s,trial_id=>$trial,experiment_type=>'field_layout'})->get_design}
sub child {
 my($parent,$name)=@_;
 my $p=$s->resultset('Stock::Stock')->find($parent);
 my $field=term('field_layout','experiment_type');
 my $e=$s->resultset('NaturalDiversity::NdExperimentStock')->search({stock_id=>$parent,type_id=>$field})->first->nd_experiment;
 CXGN::Trial->new({bcs_schema=>$s,trial_id=>$trial})->_save_plant_entry($s,term('accession','stock_type'),term('cross','stock_type'),term('family_name','stock_type'),$p->organism_id,$p->uniquename,$parent,$name,term('plant','stock_type'),1,term('plant_index_number','stock_property'),term('block','stock_property'),term('plot number','stock_property'),term('replicate','stock_property'),term('row_number','stock_property'),undef,term('col_number','stock_property'),undef,term('plant_of','stock_relationship'),$e,$field,term('plot_of','stock_relationship'),undef,undef,undef,term('plant_of_subplot','stock_relationship'));
 $s->resultset('Project::Projectprop')->find_or_create({project_id=>$trial,type_id=>term('project_has_plant_entries','project_property'),value=>1,rank=>0});
 return $s->resultset('Stock::Stock')->find({uniquename=>$name})->stock_id;
}
my $tx=0;
END {eval {$s->txn_rollback if $tx} if $s;}
$s->txn_begin;$tx=1;
my $all=eval {
 my $template=$s->resultset('Stock::Stock')->find({uniquename=>'test_accession1'});
 my $new=$s->resultset('Stock::Stock')->create({name=>$prefix.'new_accession',uniquename=>$prefix.'new_accession',type_id=>$template->type_id,organism_id=>$template->organism_id});
 no warnings 'redefine';
 local *CXGN::BreederSearch::refresh_matviews=sub {push @refresh,[@_];return {message=>'captured after successful API transaction'}};
 scenario 'One invalid combined identity/status request changes nothing'=>sub {
  my $old=accession($plots[0]);
  my $r=api()->observationunits_update([request_unit($plots[0],germplasmDbId=>''.$new->stock_id,additionalInfo=>{notPlanted=>JSON::true,rejected=>JSON::true})],$context,41);
  is($r->{http_code},400,'incompatible statuses rejected');is(accession($plots[0]),$old,'identity did not change');
  is(scalar @refresh,0,'no external refresh on failure');is(scalar @clear,0,'no filesystem cache clearing on failure');
 };
 scenario 'A late bulk metadata error rolls back germplasm, controls and references'=>sub {
  my $old=accession($plots[0]);my $control=value($plots[0],'is a control');
  my $r=api()->observationunits_update([
   request_unit($plots[0],germplasmDbId=>''.$new->stock_id,additionalInfo=>{control=>JSON::false},externalReferences=>[{referenceSource=>$prefix.'reference',referenceId=>'audit-ref'}]),
   request_unit($plots[1],observationUnitPosition=>{geoCoordinates=>'invalid object'}),
  ],$context,41);
  is($r->{http_code},400,'late invalid coordinate object rejected');
  is(accession($plots[0]),$old,'first record identity rolled back');is(value($plots[0],'is a control'),$control,'first record control rolled back');
  is(($dbh->selectrow_array('SELECT count(*) FROM db WHERE name=?',undef,$prefix.'reference'))[0],0,'external-reference rows rolled back too');
  is(scalar @refresh,0,'bulk failure starts no external refresh');is(scalar @clear,0,'bulk failure clears no caches');
 };
 scenario 'Explicit TEST clears a check and the layout cache follows the final properties'=>sub {
  value($plots[2],'is a control',1);CXGN::Trial::TrialLayout->new({schema=>$s,trial_id=>$trial,experiment_type=>'field_layout'})->generate_and_cache_layout;
  my $r=api()->observationunits_update([request_unit($plots[2],observationUnitPosition=>{entryType=>'TEST'})],$context,41);
  ok(defined($r->{result}),'update succeeded') or diag(encode_json($r));ok(!value($plots[2],'is a control'),'check false persisted');
  my($cached)=grep {$_->{plot_id}==$plots[2]} values %{layout()};ok(!$cached->{is_a_control},'cached layout has the same false control');
  is(scalar @refresh,1,'one refresh after successful request');is(scalar @clear,1,'one affected-project cache clear');
 };
 scenario 'Full GET readback cannot overwrite inferred control after germplasm changes'=>sub {
  value($plots[0],'is a control',1);CXGN::Trial::TrialLayout->new({schema=>$s,trial_id=>$trial,experiment_type=>'field_layout'})->generate_and_cache_layout;
  my $body=decode_json(encode_json(api()->detail($plots[0],$context)->{result}));
  $body->{germplasmDbId}=''.$new->stock_id;$body->{germplasmName}=$new->uniquename;
  my $r=api()->observationunits_update([$body],$context,41);
  ok(defined $r->{result},'full object accepted') or diag(encode_json($r));
  is(accession($plots[0]),$new->stock_id,'requested germplasm persisted');ok(!value($plots[0],'is a control'),'old entryType CHECK did not undo service inference');
 };
 scenario 'Inherited child status roundtrips but cannot be changed on the child'=>sub {
  my $id=child($plots[0],$prefix.'plant');
  CXGN::Trial::AccessionChange->new({schema=>$s,trial_id=>$trial})->apply([{plot_id=>$plots[0],rejected=>1,reject_reason=>'flooded'}],{curator=>1,rename_plots=>'none'});
  my $body=decode_json(encode_json(api()->detail($id,$context)->{result}));
  ok($body->{additionalInfo}{rejected},'child inherits rejection');is($body->{additionalInfo}{rejectReason},'flooded','child inherits reason');
  my $r=api()->observationunits_update([$body],$context,41);ok(defined $r->{result},'unchanged inherited status accepted') or diag(encode_json($r));
  is(value($id,'is a control'),undef,'readback did not create a new child check marker');
  is(scalar @refresh,0,'unchanged readback starts no refresh worker');is(scalar @clear,0,'unchanged readback clears no analysis cache');
  $body->{additionalInfo}{rejected}=JSON::false;
  $r=api()->observationunits_update([$body],$context,41);is($r->{http_code},400,'changing inherited status is refused');is(value($plots[0],'rejected'),1,'parent rejection preserved');
 };
 scenario 'A POST persists plot status and refuses an unsown parent before creating children'=>sub {
  my $r=api()->observationunits_store([{studyDbId=>"$trial",observationUnitName=>$prefix.'posted',germplasmDbId=>''.$template->stock_id,additionalInfo=>{notPlanted=>JSON::true},observationUnitPosition=>{observationLevel=>{levelName=>'plot',levelCode=>'99101'},observationLevelRelationships=>[]}}],$context,41);
  ok(defined $r->{result},'new plot created with its status') or diag(encode_json($r));
  my $created=$s->resultset('Stock::Stock')->find({uniquename=>$prefix.'posted'});
  ok($created,'new plot exists');is(value($created->stock_id,'not_planted'),1,'notPlanted persisted');
  my $bad=api()->observationunits_store([{studyDbId=>"$trial",observationUnitName=>$prefix.'unsown_child',germplasmDbId=>''.$template->stock_id,additionalInfo=>{observationUnitParent=>''.$created->stock_id},observationUnitPosition=>{observationLevel=>{levelName=>'plant',levelCode=>'plant_1'}}}],$context,41);
  is($bad->{http_code},400,'unsown parent refused');is($s->resultset('Stock::Stock')->search({uniquename=>$prefix.'unsown_child'})->count,0,'no unsown child created');
 };
 scenario 'Generic coordinate/control changes use the same program authorization'=>sub {
  my($john)=$dbh->selectrow_array('SELECT sp_person_id FROM sgn_people.sp_person WHERE username=?',undef,'johndoe');
  $dbh->do("DELETE FROM sgn_people.sp_person_roles WHERE sp_person_id=? AND sp_role_id NOT IN (SELECT sp_role_id FROM sgn_people.sp_roles WHERE name IN ('submitter','user'))",undef,$john);
  my $old=value($plots[0],'row_number');
  my $r=api()->observationunits_update([request_unit($plots[0],additionalInfo=>{control=>JSON::true},observationUnitPosition=>{positionCoordinateY=>'99'})],$context,$john);
  is($r->{http_code},403,'submitter outside target program refused');is(value($plots[0],'row_number'),$old,'coordinate unchanged');
  is(scalar @refresh,0,'unauthorized request starts no refresh');
 };
 scenario 'Advertised v1 GET/PUT shares atomic writes and preserves flat zero-valued metadata'=>sub {
  value($plots[2],'is a control',1);
  my $original_occurrence=value($plots[2],'replicate');
  my $r=api_v1()->observationunits_update([{observationUnitDbId=>"$plots[2]",observationLevel=>'plot',X=>0,Y=>0,replicate=>0,blockNumber=>0,entryType=>'TEST',additionalInfo=>{range=>0}}],$context,41);
  ok(defined $r->{result},'v1 flat update is accepted') or diag(encode_json($r));
  my $flat=api_v1()->detail($plots[2],$context)->{result};
  is_deeply([@{$flat}{qw(X Y replicate blockNumber)}],[0,0,0,0],'v1 flat coordinate/factor aliases preserve zero');
  is($flat->{additionalInfo}{range},0,'range zero roundtrips from its actual property');is($flat->{entryType},'test','false control roundtrips through flat v1 aliases');
  my($cached)=grep {$_->{plot_id}==$plots[2]} values %{layout()};
  is_deeply([@{$cached}{qw(row_number col_number design_rep_number range_number)}],[0,0,0,0],'canonical stored layout preserves physical group and coordinate zero through cache generation');
  is($cached->{rep_number},$original_occurrence,'editing the physical group leaves the operational occurrence unchanged');
  my $type=term('phenotyping_experiment','experiment_type');
  my $e=$s->resultset('NaturalDiversity::NdExperiment')->create({type_id=>$type,nd_geolocation_id=>$s->resultset('NaturalDiversity::NdGeolocation')->first->nd_geolocation_id});
  $e->create_related('nd_experiment_projects',{project_id=>$trial});$e->create_related('nd_experiment_stocks',{stock_id=>$plots[2],type_id=>$type});
  my $p=$s->resultset('Phenotype::Phenotype')->create({uniquename=>$prefix.'timestamp',cvalue_id=>70666,observable_id=>70666,value=>8,collect_date=>'2026-11-02 10:00:00',operator=>'janedoe'});
  $e->create_related('nd_experiment_phenotypes',{phenotype_id=>$p->phenotype_id});
  my $v2=api()->detail($plots[2],$context)->{result};my $v1=api_v1()->detail($plots[2],$context)->{result};
  is($v2->{observations}[0]{observationTimeStamp},'2026-11-02T10:00:00Z','v2 included observation has one ISO UTC suffix');
  is($v1->{observations}[0]{observationTimeStamp},'2026-11-02T10:00:00Z','v1 included observation uses the same timestamp mapping');
 };
 scenario 'Unknown unit reads and writes are controlled not-found errors'=>sub {
  is(api()->detail(2147483000,$context)->{http_code},404,'GET unknown unit returns404');
  is(api()->observationunits_update([request_unit(2147483000,additionalInfo=>{control=>JSON::false})],$context,41)->{http_code},404,'PUT unknown unit returns404');
 };
 scenario 'A saved mutation with pending analytics is successful and explicitly warned'=>sub {
  value($plots[2],'is a control',1);
  local *CXGN::BreederSearch::refresh_matviews_after_change=sub {return {refresh_pending=>1,error=>'another refresh is busy'}};
  my $r=api()->observationunits_update([request_unit($plots[2],observationUnitPosition=>{entryType=>'TEST'})],$context,41);
  is($r->{http_code},200,'committed change does not invite automatic failure retry');ok(defined $r->{result},'live successful DTO is retained');
  ok(!value($plots[2],'is a control'),'requested change really persisted');ok($r->{refresh_pending},'pending refresh is explicit');
  ok(grep({$_->{messageType} eq 'WARNING' && $_->{message}=~/Changes saved/} @{$r->{status}}),'metadata warning distinguishes saved data from pending analytics');
  is(scalar @clear,1,'all affected caches are still cleared on pending refresh');
 };
 1;
};
my $error=$@;$s->txn_rollback;$tx=0;
ok($all,'unit write scenarios completed; fixture changes rolled back') or diag($error);
done_testing;
