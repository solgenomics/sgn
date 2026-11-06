use strict;use warnings;use lib 't/lib';
use Test::More;use JSON qw(encode_json decode_json);
use SGN::Test::Fixture;use SGN::Model::Cvterm;
use CXGN::Trial::TrialCreate;use CXGN::Trial::TrialLayout;use CXGN::Trial::DesignReplication;
use CXGN::BrAPI::v1::ObservationUnits;use CXGN::BrAPI::v2::ObservationUnits;
use CXGN::BrAPI::v2::Observations;use CXGN::BrAPI::JSONResponse;
use CXGN::Phenotypes::SearchFactory;

my $f=SGN::Test::Fixture->new;my $s=$f->bcs_schema;my $dbh=$s->storage->dbh;
$s->storage->auto_savepoint(1);my $prefix='audit_cross_study_pool_'.$$;
my(@trials,@plots,$pool,$phenotype,$old_stock,$new_stock);my(@refresh,@clear);
{package CrossPoolDbc;sub dbh {$_[0]{dbh}}} ## no critic (Modules::RequireFilenameMatchesPackage) -- This test embeds its named test double beside the assertions.
{package CrossPoolClear;sub clear_cached_analyses_result {push @{$_[0]{calls}},$_[2];return 1}}
{package CrossPoolContext;sub dbc {$_[0]{dbc}} sub config {$_[0]{config}} sub controller {$_[0]{clear}}}
my $context=bless({dbc=>bless({dbh=>$dbh},'CrossPoolDbc'),config=>$f->config,clear=>bless({calls=>\@clear},'CrossPoolClear')},'CrossPoolContext');
sub term {SGN::Model::Cvterm->get_cvterm_row($s,@_)->cvterm_id}
sub model {
 my($version)=@_;my $class="CXGN::BrAPI::${version}::ObservationUnits";
 return $class->new({bcs_schema=>$s,metadata_schema=>$f->metadata_schema,phenome_schema=>$f->phenome_schema,people_schema=>$f->people_schema,context=>$context,page=>0,page_size=>20,status=>[]});
}
sub primary {
 my($id)=@_;return $dbh->selectcol_arrayref('SELECT DISTINCT r.object_id FROM stock_relationship r JOIN stock g ON g.stock_id=r.object_id WHERE r.subject_id=? AND r.type_id=ANY(?) AND g.type_id=ANY(?) ORDER BY r.object_id',undef,$id,[map {term($_,'stock_relationship')} qw(plot_of plant_of subplot_of tissue_sample_of)],[map {term($_,'stock_type')} qw(accession cross family_name)]);
}
sub parents {return $dbh->selectcol_arrayref('SELECT r.object_id FROM stock_relationship r JOIN stock p ON p.stock_id=r.object_id WHERE r.subject_id=? AND r.type_id=? AND p.type_id=? ORDER BY r.object_id',undef,$pool,term('tissue_sample_of','stock_relationship'),term('plot','stock_type'))}
sub state {
 my @ids=(@plots,$pool);
 return {
  sources=>$dbh->selectall_arrayref('SELECT stock_relationship_id,subject_id,object_id,type_id,value,rank FROM stock_relationship WHERE subject_id=ANY(?) OR object_id=ANY(?) ORDER BY stock_relationship_id',undef,\@ids,\@ids),
  props=>$dbh->selectall_arrayref('SELECT stock_id,type_id,value,rank FROM stockprop WHERE stock_id=ANY(?) ORDER BY stock_id,type_id,rank',undef,\@ids),
  cache=>$dbh->selectall_arrayref('SELECT project_id,type_id,value,rank FROM projectprop WHERE project_id=ANY(?) ORDER BY project_id,type_id,rank',undef,\@trials),
  phenotype=>$dbh->selectrow_array('SELECT row_to_json(p)::text FROM phenotype p WHERE phenotype_id=?',undef,$phenotype),
  phenotype_links=>$dbh->selectall_arrayref('SELECT nd_experiment_id,phenotype_id FROM nd_experiment_phenotype WHERE phenotype_id=? ORDER BY nd_experiment_id',undef,$phenotype),
 };
}
sub request_parent {
 my($id,%extra)=@_;return {observationUnitDbId=>"$id",germplasmDbId=>"$new_stock",%extra};
}
sub rejected {
 my($version,$payload,$actor,$label)=@_;my $before=state();@refresh=();@clear=();
 my $result=model($version)->observationunits_update($payload,$context,$actor);
 ok(($result->{http_code}//0)>=400 && ($result->{http_code}//0)<500,"$label: controlled refusal") or diag(encode_json($result));
 is_deeply(state(),$before,"$label: exact source links, properties, stored caches and phenotype remain unchanged");
 is(scalar(@refresh),0,"$label: no post-write refresh scheduled");is(scalar(@clear),0,"$label: no analysis-cache clearing scheduled");
 return $result;
}
my $tx=0;END {eval{$s->txn_rollback if $tx} if $s}
$s->txn_begin;$tx=1;
my $all=eval {
 $s->resultset('Cv::Cvterm')->create_with({name=>'design_replicate',cv=>'stock_property',definition=>'Recorded physical design group'});
 $s->resultset('Cv::Cvterm')->create_with({name=>'accession_occurrence_version',cv=>'project_property',definition=>'Occurrence cutover version'});
 my $template=$s->resultset('Stock::Stock')->find({uniquename=>'test_accession1'});
 my @stocks=map {$s->resultset('Stock::Stock')->create({name=>"${prefix}_stock_$_",uniquename=>"${prefix}_stock_$_",organism_id=>$template->organism_id,type_id=>$template->type_id})->stock_id} qw(A C);
 ($old_stock,$new_stock)=@stocks;
 for my $i (0..1) {
  my $name="${prefix}_study_$i";my $made=CXGN::Trial::TrialCreate->new({chado_schema=>$s,dbh=>$dbh,owner_id=>41,operator=>'janedoe',program=>'test',trial_location=>'test_location',trial_name=>$name,trial_description=>'Native two-study coherent pooled batch fixture',trial_year=>2031,design_type=>'CRD',design=>{1=>{plot_name=>"${prefix}_plot_$i",plot_number=>1,stock_name=>"${prefix}_stock_A",rep_number=>9,block_number=>9,row_number=>1,col_number=>1}}})->save_trial;
  die 'Native study creation failed' if !$made->{trial_id};push @trials,$made->{trial_id};push @plots,$s->resultset('Stock::Stock')->find({uniquename=>"${prefix}_plot_$i"})->stock_id;
 }
 my $sample=$s->resultset('Stock::Stock')->create({name=>"${prefix}_pool",uniquename=>"${prefix}_pool",organism_id=>$template->organism_id,type_id=>term('tissue_sample','stock_type')});$pool=$sample->stock_id;
 $sample->create_related('stock_relationship_subjects',{object_id=>$_,type_id=>term('tissue_sample_of','stock_relationship')}) for @plots;
 $sample->create_related('stock_relationship_subjects',{object_id=>$old_stock,type_id=>term('tissue_sample_of','stock_relationship')});
 my $field=term('field_layout','experiment_type');my($layout)=$dbh->selectrow_array('SELECT ne.nd_experiment_id FROM nd_experiment ne JOIN nd_experiment_project nep USING(nd_experiment_id) WHERE nep.project_id=? AND ne.type_id=?',undef,$trials[0],$field);
 $sample->create_related('nd_experiment_stocks',{nd_experiment_id=>$layout,type_id=>$field});
 $sample->create_related('stockprops',{type_id=>term('replicate','stock_property'),value=>undef,rank=>0});
 $sample->create_related('stockprops',{type_id=>term('tissue_sample_index_number','stock_property'),value=>1,rank=>0});
 $sample->create_related('stockprops',{type_id=>term('tissue_type','stock_property'),value=>'leaf',rank=>0});
 CXGN::Trial::DesignReplication::set($s,$pool,undef);
 $s->resultset('Project::Projectprop')->find_or_create({project_id=>$trials[0],type_id=>term('project_has_tissue_sample_entries','project_property'),value=>1,rank=>0});
 my $type=term('phenotyping_experiment','experiment_type');my $e=$s->resultset('NaturalDiversity::NdExperiment')->create({type_id=>$type,nd_geolocation_id=>$s->resultset('NaturalDiversity::NdGeolocation')->first->nd_geolocation_id});$e->create_related('nd_experiment_projects',{project_id=>$trials[0]});$e->create_related('nd_experiment_stocks',{stock_id=>$pool,type_id=>$type});
 my $p=$s->resultset('Phenotype::Phenotype')->create({uniquename=>$prefix.'_measurement',cvalue_id=>70666,observable_id=>70666,value=>17,collect_date=>'2031-01-01 10:00:00',operator=>'janedoe'});$phenotype=$p->phenotype_id;$e->create_related('nd_experiment_phenotypes',{phenotype_id=>$phenotype});
 CXGN::Trial::TrialLayout->new({schema=>$s,trial_id=>$_,experiment_type=>'field_layout'})->generate_and_cache_layout for @trials;
 my $members=$dbh->selectcol_arrayref('SELECT DISTINCT nep.project_id FROM nd_experiment_stock nes JOIN nd_experiment ne USING(nd_experiment_id) JOIN nd_experiment_project nep USING(nd_experiment_id) WHERE nes.stock_id=? AND ne.type_id=? ORDER BY nep.project_id',undef,$pool,$field);
 is_deeply($members,[$trials[0]],'pooled tissue directly belongs only to study A');is_deeply(parents(),[sort {$a<=>$b} @plots],'pooled tissue has both actual physical plot parents');
 my($ordinary)=$dbh->selectrow_array('SELECT sp_person_id FROM sgn_people.sp_person WHERE username=?',undef,'freddy');die 'Committed ordinary actor fixture missing' if !$ordinary;
 no warnings 'redefine';local *CXGN::BreederSearch::refresh_matviews_after_change=sub {push @refresh,[@_];return {success=>1,message=>'captured post-write refresh'}};
 for my $version(qw(v1 v2)) {
  subtest "$version coherent two-study pooled update is atomic"=>sub {
   $s->txn_begin;my $ok=eval {
    # Warm actual DTO/cache readers before taking exact refusal snapshots.
    for my $id(@plots,$pool) {my $detail=model($version)->detail($id,$context);die 'Fixture detail failed: '.encode_json($detail) if !defined($detail->{result})}
    my $partial=rejected($version,[request_parent($plots[0],additionalInfo=>{control=>JSON::true},observationUnitPosition=>{positionCoordinateX=>'33'})],41,'partial divergent parent edit');
    like(join(' ',map {$_->{message}//''} @{$partial->{status}||[]}),qr/pooled.*multiple germplasm|one germplasm per unit/i,'partial refusal explains the scalar pooled identity contract');
    my %forged=map { ($_ => "$new_stock") } @plots;
    rejected($version,[request_parent($plots[0],_final_stock_by_plot=>\%forged,additionalInfo=>{_final_stock_by_plot=>\%forged})],41,'forged private final-germplasm context');
    my $unauthorized=rejected($version,[request_parent($plots[0]),request_parent($plots[1])],$ordinary,'unauthorized coherent batch');
    is($unauthorized->{http_code},403,'ordinary actor cannot mutate either actual study');
    @refresh=();@clear=();my $raw_before=$dbh->selectrow_array('SELECT row_to_json(p)::text FROM phenotype p WHERE phenotype_id=?',undef,$phenotype);
    my $result=model($version)->observationunits_update([request_parent($plots[0]),request_parent($plots[1])],$context,41);
    ok(defined($result->{result}),'coherent complete bulk edit succeeds') or die encode_json($result);
    my @warnings=grep {($_->{messageType}//'') eq 'WARNING'} @{$result->{status}||[]};
    ok(@warnings,'curator receives a WARNING for correcting the measured study');
    like(join(' ',map {$_->{message}//''} @warnings),qr/assay|measur|phenotyp|observat/i,'warning identifies the existing measured-data condition');
    like(join(' ',map {$_->{message}//''} @warnings),qr/values stay.*plot.*new accession/i,'service warning explains that retained values now count for the corrected accession');
    is_deeply(primary($plots[0]),[$new_stock],'first actual study plot has final C identity');is_deeply(primary($plots[1]),[$new_stock],'second actual study plot has final C identity');
    is_deeply(primary($pool),[$new_stock],'pooled child has one final scalar C identity');is_deeply(parents(),[sort {$a<=>$b} @plots],'both physical parents are preserved');
    is($dbh->selectrow_array('SELECT row_to_json(p)::text FROM phenotype p WHERE phenotype_id=?',undef,$phenotype),$raw_before,'the exact stored measurement is retained');
    is($dbh->selectrow_array('SELECT count(DISTINCT phenotype_id) FROM nd_experiment_phenotype JOIN nd_experiment_stock USING(nd_experiment_id) WHERE stock_id=?',undef,$pool),1,'one pooled measurement remains linked');
    is(scalar(@refresh),1,'one post-write refresh is scheduled for the atomic request');is(scalar(@clear),1,'one cache-clear request covers the committed closure');
    my %cleared=map {$_=>1} @{$clear[0]{trials}||[]};ok($cleared{$trials[0]}&&$cleared{$trials[1]},'both actual studies are in the cache-clear closure');
    # The advertised v1 listing uses name/study filters; its detail/PUT adapter
    # and v2 listing also accept the exact ID. Refresh only after successful
    # writes, never to hide a refused request.
    $dbh->do('SELECT refresh_materialized_phenotype_jsonb_table()');
    my $listing=model($version)->search({observationUnitDbIds=>[$pool],observationUnitNames=>["${prefix}_pool"],studyDbIds=>[$trials[0]],observationLevel=>['tissue_sample']},$context);
    my @dtos=@{$listing->{result}{data}||[]};is(scalar(@dtos),1,'actual reader returns exactly one pooled DTO');
    is($dtos[0]{germplasmDbId},"$new_stock",'pooled DTO has final scalar identity C');
    if ($version eq 'v1') {
     is(scalar(@{$dtos[0]{observations}||[]}),1,'v1 pooled DTO contains one observation, without duplicated phenotype IDs');
     is($dtos[0]{observations}[0]{observationDbId},"$phenotype",'v1 DTO retains the same measurement ID');
    } else {
     # BrAPI v2.1 ObservationUnit.observations is optional and must be
     # populated only when includeObservations is explicitly true.
     is(scalar(@{$dtos[0]{observations}||[]}),0,'v2 default unit listing does not embed unrequested observations');
     my $embedded=model($version)->search({observationUnitDbIds=>[$pool],studyDbIds=>[$trials[0]],observationLevel=>['tissue_sample'],includeObservations=>'true'},$context);
     my @included=@{$embedded->{result}{data}||[]};
     is(scalar(@included),1,'v2 explicit embedded listing retains exactly one pooled DTO');
     is(scalar(@{$included[0]{observations}||[]}),1,'v2 includeObservations=true returns one measurement without duplicated IDs');
     is($included[0]{observations}[0]{observationDbId},"$phenotype",'v2 explicit embedded listing retains the same measurement ID');
     my $observations=CXGN::BrAPI::v2::Observations->new({bcs_schema=>$s,metadata_schema=>$f->metadata_schema,phenome_schema=>$f->phenome_schema,people_schema=>$f->people_schema,context=>$context,page=>0,page_size=>20,status=>[]})->search({observationUnitDbIds=>[$pool],studyDbIds=>[$trials[0]],observationLevel=>['tissue_sample']});
     my @measured=@{$observations->{result}{data}||[]};
     is(scalar(@measured),1,'actual v2 Observations unit/study search has one preserved pooled measurement');
     is($measured[0]{observationDbId},"$phenotype",'actual v2 observation search retains the original measurement ID');
     is($measured[0]{value},'17','actual v2 observation search retains the original measured value');
     is($measured[0]{observationUnitDbId},"$pool",'actual v2 measurement belongs to the same physical pooled unit');
     is($measured[0]{studyDbId},"$trials[0]",'actual v2 measurement remains in its actual study');
     is($measured[0]{germplasmDbId},"$new_stock",'actual v2 measurement readback resolves the corrected scalar germplasm');
    }
    my @echo=map {decode_json(encode_json(model($version)->detail($_,$context)->{result}))} (@plots,$pool);
    my $echo_result=model($version)->observationunits_update(\@echo,$context,41);ok(defined($echo_result->{result}),'full current parent/child DTO echo remains valid') or diag(encode_json($echo_result));
    is_deeply(primary($pool),[$new_stock],'echo cannot undo the verified final scalar identity');
    my($fast)=CXGN::Phenotypes::SearchFactory->instantiate('MaterializedViewTable',{bcs_schema=>$s,data_level=>'tissue_sample',trial_list=>[$trials[0]],plot_list=>[$pool],trait_list=>[70666]})->search;
    is(scalar(@$fast),1,'real refreshed materialized reader has one coherent pooled unit');is($fast->[0]{germplasm_stock_id},$new_stock,'refreshed materialized identity is C');
    my($native)=CXGN::Phenotypes::SearchFactory->instantiate('Native',{bcs_schema=>$s,data_level=>'tissue_sample',trial_list=>[$trials[0]],plot_list=>[$pool],trait_list=>[70666]})->search;
    my @actual=grep {defined($_->{phenotype_id})&&$_->{phenotype_id}==$phenotype} @$native;is(scalar(@actual),1,'real live reader has exactly one instance of the pooled measurement');
    1;
   };my $error=$@;$s->txn_rollback;ok($ok,'actual versioned API scenario completed and rolled back') or diag($error);
  };
 }
 1;
};my $error=$@;$s->txn_rollback;$tx=0;ok($all,'all actual cross-study batch fixtures rolled back') or diag($error);done_testing;
