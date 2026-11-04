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
use CXGN::Trial::DesignReplication;
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
 scenario 'Unsupported additional information cannot partially change identity'=>sub {
  my $old=accession($plots[0]);
  for my $info ({notPlanted=>JSON::true},{notPlanted=>JSON::false},{rejected=>JSON::true},{rejected=>JSON::false},{rejectReason=>'unsupported reason'}) {
   my $r=api()->observationunits_update([request_unit($plots[0],germplasmDbId=>''.$new->stock_id,additionalInfo=>$info)],$context,41);
   is($r->{http_code},400,'unsupported additionalInfo field is refused');
   like(join(' ',map {$_->{message}//''} @{$r->{status}||[]}),qr/Unsupported observation-unit additionalInfo field/,'the unsupported field contract is explicit');
   is(accession($plots[0]),$old,'identity did not change');
  }
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
 scenario 'Tissue creation preserves a plant parent while enforcing study, germplasm and level'=>sub {
  my $germplasm=accession($plots[0]);
  my $plot_type=term('plot','stock_type');
  my $plot_count=$s->resultset('Stock::Stock')->search({type_id=>$plot_type})->count;
  my $plot_rows=sub {$dbh->selectall_arrayref(
   'SELECT sp.stock_id,sp.type_id,sp.value,sp.rank FROM stockprop sp
    JOIN stock st ON st.stock_id=sp.stock_id WHERE st.type_id=? ORDER BY sp.stock_id,sp.type_id,sp.rank',
   undef,$plot_type)};
  my $original_plot_metadata=$plot_rows->();
  my $version_rows=sub {$dbh->selectall_arrayref(
   'SELECT value,rank FROM projectprop WHERE project_id=? AND type_id=? ORDER BY rank',
   undef,$trial,term('accession_occurrence_version','project_property'))};
  my $original_versions=$version_rows->();
  my $plant_name=$prefix.'sample_parent';
  my $created=api()->observationunits_store([{studyDbId=>"$trial",germplasmDbId=>"$germplasm",
   observationUnitName=>$plant_name,additionalInfo=>{observationUnitParent=>"$plots[0]"},
   observationUnitPosition=>{observationLevel=>{levelName=>'plant',levelCode=>'1'},observationLevelRelationships=>[]}}],$context,41);
  ok(defined($created->{result}),'the parent plant is created through the owning BrAPI writer') or diag(encode_json($created));
  my $parent=$created->{result}{data}[0]{observationUnitDbId};
  ok($parent,'the new parent identity comes from the API DTO');
  return if !$parent;
  is(scalar @{$created->{result}{data}},1,'the creation response returns only the requested plant');
  my @constructed=grep {($_->{message}//'') eq 'Observation Units search result constructed'} @{$created->{status} || []};
  is(scalar @constructed,1,'creation reports one final response read');
  is($created->{result}{data}[0]{observationUnitName},$plant_name,'the DTO returns the exact requested plant name');
  is($s->resultset('Stock::Stock')->find($parent)->type->name,'plant','the returned ID belongs to the created plant level');
  my $root_parents=$dbh->selectcol_arrayref(
   'SELECT r.subject_id FROM stock_relationship r JOIN stock p ON p.stock_id=r.subject_id
    WHERE r.object_id=? AND r.type_id=? AND p.type_id=? ORDER BY r.subject_id',
   undef,$parent,term('plant_of','stock_relationship'),$plot_type);
  is_deeply($root_parents,[$plots[0]],'the exact returned plant has the requested existing root plot');
  my $request={studyDbId=>"$trial",germplasmDbId=>"$germplasm",observationUnitName=>$prefix.'plant_tissue',
   additionalInfo=>{observationUnitParent=>"$parent"},
   observationUnitPosition=>{observationLevel=>{levelName=>'tissue_sample',levelCode=>'1'},observationLevelRelationships=>[]}};
  my $r=api()->observationunits_store([$request],$context,41);
  ok(defined($r->{result}),'a tissue sample can be collected from a plant') or diag(encode_json($r));
  my $id=$r->{result}{data}[0]{observationUnitDbId};
  ok($id,'the created tissue sample has its own returned ID');
  return if !$id;
  my $parents=$dbh->selectcol_arrayref('SELECT object_id FROM stock_relationship WHERE subject_id=? AND type_id=? ORDER BY object_id',undef,$id,term('tissue_sample_of','stock_relationship'));
  is_deeply($parents,[sort {$a<=>$b} ($parent,$plots[0],$germplasm)],'native storage preserves the plant, root plot and germplasm ancestry');
  my $groups=CXGN::Trial::DesignReplication::read($s,[$id,$parent]);
  is_deeply([@{$groups->{$id}}{qw(value block occurrence)}],[@{$groups->{$parent}}{qw(value block occurrence)}],
   'the tissue sample inherits its actual parent design, block and occurrence');
  my $root_request={%$request,observationUnitName=>$prefix.'plot_tissue',
   additionalInfo=>{observationUnitParent=>"$plots[0]"}};
  my $root_result=api()->observationunits_store([$root_request],$context,41);
  ok(defined($root_result->{result}),'a tissue sample can still be collected directly from the existing plot') or diag(encode_json($root_result));
  my $root_id=$root_result->{result}{data}[0]{observationUnitDbId};
  ok($root_id,'the direct-plot tissue sample has a distinct returned identity');
  is($s->resultset('Stock::Stock')->search({type_id=>$plot_type})->count,$plot_count,
   'plant and tissue creation fabricate no field plots');
  is($s->resultset('Stock::Stock')->search({uniquename=>$plant_name,type_id=>$plot_type})->count,0,
   'the plant name is never reused for a placeholder plot');
  is_deeply($plot_rows->(),$original_plot_metadata,'all original plot properties, including replicate and design tags, are unchanged');
  is_deeply($version_rows->(),$original_versions,'child creation does not normalize or mark the whole field layout');
  my $untrusted={%$request,observationUnitName=>$prefix.'client_internal_marker',
   additionalInfo=>{observationUnitParent=>"$parent",_existing_parent_stock_id=>"$plots[1]"}};
  my $untrusted_result=api()->observationunits_store([$untrusted],$context,41);
  ok(defined($untrusted_result->{result}),'ordinary additionalInfo cannot configure the internal native parent')
   or diag(encode_json($untrusted_result));
  my $untrusted_id=$untrusted_result->{result}{data}[0]{observationUnitDbId};
  if ($untrusted_id) {
   my $actual=$dbh->selectcol_arrayref(
    'SELECT r.object_id FROM stock_relationship r JOIN stock st ON st.stock_id=r.object_id WHERE r.subject_id=? AND r.type_id=? AND st.type_id=? ORDER BY r.object_id',
    undef,$untrusted_id,term('tissue_sample_of','stock_relationship'),term('plant','stock_type'));
   is_deeply($actual,[$parent],'a user-supplied internal-looking metadata key cannot redirect the real plant parent');
  }
  for my $case (
   ['plant_of_plant',{observationUnitPosition=>{observationLevel=>{levelName=>'plant',levelCode=>'1'},observationLevelRelationships=>[]}}],
   ['different_study',{studyDbId=>'165'}],
   ['different_germplasm',{germplasmDbId=>''.$new->stock_id}],
  ) {
   my $invalid={%$request,%{$case->[1]},observationUnitName=>$prefix.$case->[0]};
   my $bad=api()->observationunits_store([$invalid],$context,41);
   is($bad->{http_code},400,"$case->[0] remains a controlled rejection");
   is($s->resultset('Stock::Stock')->search({uniquename=>$invalid->{observationUnitName}})->count,0,
    "$case->[0] creates no partial stock");
  }
 };
 scenario 'BrAPI literal plot codes roundtrip without weakening child indexes'=>sub {
  for my $code ('Plot_123','007') {
   my $r=api()->observationunits_update([request_unit($plots[0],observationUnitPosition=>{
    observationLevel=>{levelName=>'plot',levelCode=>$code}})],$context,41);
   ok(defined($r->{result}),"literal plot code $code is accepted") or diag(encode_json($r));
   is(value($plots[0],'plot number'),$code,"literal plot code $code is stored without coercion");
   is($r->{result}{data}[0]{observationUnitDbId},$plots[0],'changing the plot code preserves its stock identity');
   is($r->{result}{data}[0]{observationUnitPosition}{observationLevel}{levelCode},$code,
    "literal plot code $code roundtrips through the owning DTO");
  }
  my $parent=child($plots[1],$prefix.'numbered_plant');
  my $old_index=value($parent,'plant_index_number');
  my $bad=api()->observationunits_update([request_unit($parent,observationUnitPosition=>{
   observationLevel=>{levelName=>'plant',levelCode=>'Plant_ABC'}})],$context,41);
  is($bad->{http_code},400,'a literal label does not become a child numeric index');
  is(value($parent,'plant_index_number'),$old_index,'the invalid child index leaves its raw value intact');
 };
 scenario 'An invalid stored layout reports its native cause and rolls child writes back'=>sub {
  my $germplasm=accession($plots[0]);
  $s->resultset('Stock::Stockprop')->search({stock_id=>$plots[0],type_id=>term('plot number','stock_property')})->delete;
  my $name=$prefix.'invalid_native_layout';
  my $r=api()->observationunits_store([{studyDbId=>"$trial",germplasmDbId=>"$germplasm",observationUnitName=>$name,
   additionalInfo=>{observationUnitParent=>"$plots[0]"},
   observationUnitPosition=>{observationLevel=>{levelName=>'plant',levelCode=>'1'},observationLevelRelationships=>[]}}],$context,41);
  ok(($r->{http_code} || 0)>=400,'the invalid stored layout is a controlled refusal');
  like(join(' ',map {$_->{message}//''} @{$r->{status} || []}),qr/no plot number stockprop found/,
   'the actual native data error reaches the caller');
  is($s->resultset('Stock::Stock')->search({uniquename=>$name})->count,0,'the failed native layout rebuild retains no partial child');
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
