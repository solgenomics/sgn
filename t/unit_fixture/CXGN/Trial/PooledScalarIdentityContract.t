use strict;
use warnings;
use lib 't/lib';
use Test::More;
use JSON qw(encode_json decode_json);
use SGN::Test::Fixture;
use SGN::Model::Cvterm;
use CXGN::Trial;
use CXGN::Trial::TrialCreate;
use CXGN::Trial::TrialLayout;
use CXGN::Trial::TrialLayoutSearch;
use CXGN::Trial::AccessionChange;
use CXGN::Trial::DesignReplication;
use CXGN::Phenotypes::SearchFactory;
use CXGN::BrAPI::v2::ObservationUnits;

# A pooled sample remains representable by one scalar germplasm identity.
# This tests native structural pooling, not a new public pool-creation API.
# Structural pool, actual field membership, one actual observation; all rollback.
my$f=SGN::Test::Fixture->new;my$s=$f->bcs_schema;my$dbh=$s->storage->dbh;
$s->storage->auto_savepoint(1);my$prefix='audit_pool_identity_contract_'.$$;
my($trial,$sample,$phenotype,@plots,@stocks);
{package PoolScalarDbc;sub dbh{$_[0]{dbh}}} ## no critic (Modules::RequireFilenameMatchesPackage) -- This test embeds its named test double beside the assertions.
{package PoolScalarClear;sub clear_cached_analyses_result{1}}
{package PoolScalarContext;sub dbc{$_[0]{dbc}}sub config{$_[0]{config}}sub controller{$_[0]{clear}}}
my$c=bless{dbc=>bless({dbh=>$dbh},'PoolScalarDbc'),config=>$f->config,clear=>bless({},'PoolScalarClear')},'PoolScalarContext';
sub term{SGN::Model::Cvterm->get_cvterm_row($s,@_)->cvterm_id}
sub api{CXGN::BrAPI::v2::ObservationUnits->new({bcs_schema=>$s,metadata_schema=>$f->metadata_schema,phenome_schema=>$f->phenome_schema,people_schema=>$f->people_schema,context=>$c,page=>0,page_size=>20,status=>[]})}
sub units{my($rows)=CXGN::Trial::TrialLayoutSearch->new({bcs_schema=>$s,data_level=>'tissue_sample',trial_list=>[$trial],observation_unit_id_list=>[$sample]})->search;return$rows}
sub observations{my($rows)=CXGN::Phenotypes::SearchFactory->instantiate('Native',{bcs_schema=>$s,data_level=>'tissue_sample',trial_list=>[$trial],plot_list=>[$sample],trait_list=>[70666]})->search;return[grep{defined($_->{phenotype_id})&&$_->{phenotype_id}==$phenotype}@$rows]}
sub dto{api()->search({observationUnitDbIds=>["$sample"],includeObservations=>'true'},$c)->{result}{data}}
sub sources{return$dbh->selectcol_arrayref(q{SELECT r.object_id FROM stock_relationship r JOIN stock g ON g.stock_id=r.object_id JOIN cvterm t ON t.cvterm_id=g.type_id WHERE r.subject_id=? AND r.type_id=? AND t.name IN ('accession','cross','family_name') ORDER BY r.object_id},undef,$sample,term('tissue_sample_of','stock_relationship'))}
sub raw_observations{return$dbh->selectrow_array('SELECT count(*) FROM phenotype WHERE phenotype_id=?',undef,$phenotype)}
sub facts {
 my$ids=[@plots,$sample];
 return {relationships=>$dbh->selectall_arrayref('SELECT stock_relationship_id,subject_id,object_id,type_id,rank FROM stock_relationship WHERE subject_id=ANY(?) ORDER BY stock_relationship_id',undef,$ids),
 properties=>$dbh->selectall_arrayref('SELECT stockprop_id,stock_id,type_id,value,rank FROM stockprop WHERE stock_id=ANY(?) ORDER BY stockprop_id',undef,$ids),
 cache=>$dbh->selectrow_array('SELECT value FROM projectprop WHERE project_id=? AND type_id=?',undef,$trial,term('trial_layout_json','project_property')),
 phenotype=>$dbh->selectall_arrayref('SELECT phenotype_id,uniquename,cvalue_id,observable_id,value,collect_date,operator FROM phenotype WHERE phenotype_id=?',undef,$phenotype)};
}
sub ensure_term{my($name,$cv,$template_name)=@_;return if$s->resultset('Cv::Cvterm')->search({'me.name'=>$name,'cv.name'=>$cv},{join=>'cv'})->count;my$t=SGN::Model::Cvterm->get_cvterm_row($s,$template_name,$cv);my$x=$s->resultset('General::Dbxref')->create({db_id=>$t->dbxref->db_id,accession=>$prefix.'_'.$name});$s->resultset('Cv::Cvterm')->create({name=>$name,cv_id=>$t->cv_id,dbxref_id=>$x->dbxref_id})}
my$tx=0;END{eval{$s->txn_rollback if$tx}if$s}
$s->txn_begin;$tx=1;
my$ran=eval{
 ensure_term('design_replicate','stock_property','replicate');ensure_term('accession_occurrence_version','project_property','design');
 @stocks=map{$s->resultset('Stock::Stock')->find({uniquename=>"test_accession$_"})->stock_id}(1,3);
 my%design=map{my$i=$_;($i=>{plot_name=>"${prefix}_plot_$i",stock_name=>'test_accession1',plot_number=>$i,rep_number=>9,block_number=>9,row_number=>1,col_number=>$i})}1..2;
 my$created=CXGN::Trial::TrialCreate->new({chado_schema=>$s,dbh=>$dbh,owner_id=>41,operator=>'janedoe',program=>'test',trial_location=>'test_location',trial_name=>$prefix,trial_description=>'Rollback-only pooled scalar germplasm owning-reader qualification',trial_year=>2031,design_type=>'RCBD',design=>\%design})->save_trial;
 $trial=$created->{trial_id};die encode_json($created)if!$trial;
 @plots=map{$s->resultset('Stock::Stock')->find({uniquename=>"${prefix}_plot_$_"})->stock_id}1..2;
 my$parent=$s->resultset('Stock::Stock')->find($plots[0]);
 my$stock=$s->resultset('Stock::Stock')->create({name=>$prefix.'_sample',uniquename=>$prefix.'_sample',type_id=>term('tissue_sample','stock_type'),organism_id=>$parent->organism_id});$sample=$stock->stock_id;
 for my$id(@plots,$stocks[0]){$s->resultset('Stock::StockRelationship')->create({subject_id=>$sample,object_id=>$id,type_id=>term('tissue_sample_of','stock_relationship'),rank=>0})}
 for my$pair(['tissue_sample_index_number',1],['plot number',1],['block',9],['replicate',undef]){$s->resultset('Stock::Stockprop')->create({stock_id=>$sample,type_id=>term($pair->[0],'stock_property'),value=>$pair->[1],rank=>0})}
 CXGN::Trial::DesignReplication::set($s,$sample,9);
 my$field=term('field_layout','experiment_type');my$membership=$s->resultset('NaturalDiversity::NdExperimentStock')->search({stock_id=>$plots[0],type_id=>$field})->first;
 $s->resultset('NaturalDiversity::NdExperimentStock')->create({stock_id=>$sample,nd_experiment_id=>$membership->nd_experiment_id,type_id=>$field});
 my$type=term('phenotyping_experiment','experiment_type');my$e=$s->resultset('NaturalDiversity::NdExperiment')->create({type_id=>$type,nd_geolocation_id=>$membership->nd_experiment->nd_geolocation_id});
 $e->create_related('nd_experiment_projects',{project_id=>$trial});$e->create_related('nd_experiment_stocks',{stock_id=>$sample,type_id=>$type});
 my$p=$s->resultset('Phenotype::Phenotype')->create({uniquename=>$prefix.'_observation',cvalue_id=>70666,observable_id=>70666,value=>23.5,operator=>'janedoe'});$phenotype=$p->phenotype_id;$e->create_related('nd_experiment_phenotypes',{phenotype_id=>$phenotype});
 CXGN::Trial::TrialLayout->new({schema=>$s,trial_id=>$trial,experiment_type=>'field_layout'})->generate_and_cache_layout;
 is_deeply(sources(),[$stocks[0]],'control pool has one recorded accession');is(raw_observations(),1,'one actual physical observation exists');
 is(scalar@{units()},1,'control actual TrialLayoutSearch returns one unit');is(scalar@{observations()},1,'control Native returns one measured row');is(scalar@{dto()},1,'control BrAPI search returns one DTO');
 subtest 'Divergent final source accessions are refused before mutation'=>sub{
  $s->txn_begin;
  my$before=facts();
  my$service=CXGN::Trial::AccessionChange->new({schema=>$s,trial_id=>$trial});my$changes=[{plot_id=>$plots[0],new_stock_id=>$stocks[1]}];
  my$plan=$service->plan($changes,{rename_plots=>'none',curator=>1});
  ok(@{$plan->{errors}}>0,'preview refuses a pooled unit with different final parent accessions');
  like(join(' ',@{$plan->{errors}}),qr/(?:pool|ambiguous|different.*(?:accession|germplasm)|multiple.*germplasm)/i,'preview explains the unresolved pooled biological identity');
  is_deeply(facts(),$before,'refused preview itself changes nothing');
  my$applied=eval{$service->apply($changes,{rename_plots=>'none',curator=>1});1};
  ok(!$applied,'apply refuses the same incompatible correction');
  my$after=facts();
  is_deeply($after->{relationships},$before->{relationships},'parent/source relationships and scalar child germplasm stay unchanged');
  is_deeply($after->{properties},$before->{properties},'all occurrence counters, recorded tags and status properties stay unchanged');
  is($after->{cache},$before->{cache},'stored layout cache stays unchanged');
  is_deeply($after->{phenotype},$before->{phenotype},'actual observation ID, value and metadata stay unchanged');
  is(scalar@{units()},1,'owning unit search still has one scalar unit');
  is(scalar@{observations()},1,'Native still returns the one original measured row');
  my$d=dto();is(scalar@$d,1,'BrAPI still returns one DTO');is(scalar@{$d->[0]{observations}},1,'DTO contains its observation once');
  $s->txn_rollback;
 };
 subtest 'All final parent accessions agree: positive correction remains representable'=>sub{
  $s->txn_begin;
  CXGN::Trial::AccessionChange->new({schema=>$s,trial_id=>$trial})->apply([map{{plot_id=>$_,new_stock_id=>$stocks[1]}}@plots],{rename_plots=>'none',curator=>1});
  is_deeply(sources(),[$stocks[1]],'unanimous final source identity gives one corrected accession');
  is(raw_observations(),1,'actual observation identity retained');is(scalar@{units()},1,'one owning unit-search row');is(scalar@{observations()},1,'one Native measured row');
  my$d=dto();is(scalar@$d,1,'one BrAPI DTO');is($d->[0]{germplasmDbId},$stocks[1],'DTO uses the unanimous corrected accession');
  is(scalar@{$d->[0]{observations}},1,'the actual phenotype appears once in the DTO');is($d->[0]{observations}[0]{observationDbId},$phenotype,'same original phenotype ID remains linked');is($d->[0]{observations}[0]{value},'23.5','original measured value preserved');
  my$before=facts();
  my$detail=api()->detail($sample,$c);my$echo=decode_json(encode_json($detail->{result}));my$put=api()->observationunits_update([$echo],$c,41);
  ok(defined($put->{result}),'complete unchanged GET PUT remains valid after coherent correction')or diag(encode_json($put));
  is_deeply(facts(),$before,'complete DTO echo changes no relationships, counters, cache or observations');
  $s->txn_rollback;
 };
 1;
};my$error=$@;$s->txn_rollback;$tx=0;
ok($ran,'owning pooled scalar-contract qualification completed and all synthetic rows rolled back')or diag($error);
is($s->resultset('Project::Project')->search({name=>$prefix})->count,0,'own synthetic trial removed');
done_testing;
