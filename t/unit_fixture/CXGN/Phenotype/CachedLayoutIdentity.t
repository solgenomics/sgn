use strict;
use warnings;
use lib 't/lib';
use Test::More;
use File::Temp qw(tempdir);
use SGN::Test::Fixture;
use SGN::Model::Cvterm;
use CXGN::Trial::TrialCreate;
use CXGN::Trial::AccessionChange;
use CXGN::Phenotypes::SearchFactory;
use CXGN::Phenotypes::PhenotypeMatrix;
use CXGN::Dataset::File;

my $f=SGN::Test::Fixture->new;my $s=$f->bcs_schema;my $dbh=$s->storage->dbh;
$s->storage->auto_savepoint(1);my $dir=tempdir(CLEANUP=>1);
my $prefix='audit_cached_layout_'.$$;my(@stocks,@plots,$trial,$clean_trial,$clean_plot,$phenotype);
sub term {SGN::Model::Cvterm->get_cvterm_row($s,@_)->cvterm_id}
sub measurement {
 my($project,$unit,$value,$suffix)=@_;my $type=term('phenotyping_experiment','experiment_type');
 my $e=$s->resultset('NaturalDiversity::NdExperiment')->create({type_id=>$type,nd_geolocation_id=>$s->resultset('NaturalDiversity::NdGeolocation')->first->nd_geolocation_id});
 $e->create_related('nd_experiment_projects',{project_id=>$project});$e->create_related('nd_experiment_stocks',{stock_id=>$unit,type_id=>$type});
 my $p=$s->resultset('Phenotype::Phenotype')->create({uniquename=>"${prefix}_measurement_$suffix",cvalue_id=>70666,observable_id=>70666,value=>$value,operator=>'janedoe'});
 $e->create_related('nd_experiment_phenotypes',{phenotype_id=>$p->phenotype_id});return $p->phenotype_id;
}
sub search_rows {
 my(%options)=@_;my($rows)=CXGN::Phenotypes::SearchFactory->instantiate('MaterializedViewTable',{bcs_schema=>$s,data_level=>'plot',trial_list=>[$trial],plot_list=>[$plots[1]],trait_list=>[70666],%options})->search;return $rows;
}
sub matrix {
 my @rows=CXGN::Phenotypes::PhenotypeMatrix->new({bcs_schema=>$s,search_type=>'MaterializedViewTable',data_level=>'plot',trial_list=>[$trial],plot_list=>[$plots[1]],trait_list=>[70666]})->get_phenotype_matrix;return \@rows;
}
sub fails {
 my($code,$pattern,$label)=@_;my $ok=eval {$code->();1};my $error=$@;ok(!$ok,$label);like($error,$pattern,"$label: explicit diagnostic");
}
sub nested {
 my($name,$code)=@_;subtest $name=>sub {$s->txn_begin;my $ok=eval {$code->();1};my $error=$@;$s->txn_rollback;ok($ok,'nested fixture restored') or diag($error)};
}
sub set_prop {
 my($name,$value)=@_;my $type=term($name,'stock_property');$s->resultset('Stock::Stockprop')->search({stock_id=>$plots[1],type_id=>$type})->delete;
 $s->resultset('Stock::Stockprop')->create({stock_id=>$plots[1],type_id=>$type,value=>$value,rank=>0});
}
my $tx=0;END {eval{$s->txn_rollback if $tx} if $s}
$s->txn_begin;$tx=1;
my $ran=eval {
 $s->resultset('Cv::Cvterm')->create_with({name=>'design_replicate',cv=>'stock_property',definition=>'Recorded design group'});
 $s->resultset('Cv::Cvterm')->create_with({name=>'accession_occurrence_version',cv=>'project_property',definition=>'Occurrence cutover version'});
 my $template=$s->resultset('Stock::Stock')->find({uniquename=>'test_accession1'});
 for my $i (1..3) {push @stocks,$s->resultset('Stock::Stock')->create({name=>"${prefix}_stock_$i",uniquename=>"${prefix}_stock_$i",organism_id=>$template->organism_id,type_id=>$template->type_id})->stock_id}
 my %design=map {my $i=$_;($i=>{plot_name=>"${prefix}_plot_$i",stock_name=>"${prefix}_stock_$i",plot_number=>$i,rep_number=>9,block_number=>9,row_number=>1,col_number=>$i})} 1..3;
 my $created=CXGN::Trial::TrialCreate->new({chado_schema=>$s,dbh=>$dbh,owner_id=>41,operator=>'janedoe',program=>'test',trial_location=>'test_location',trial_name=>$prefix,trial_description=>'Rollback-only cached identity consistency regression',trial_year=>2031,design_type=>'RCBD',design=>\%design})->save_trial;
 $trial=$created->{trial_id};die 'Native fixture creation failed' if !$trial;
 @plots=map {$s->resultset('Stock::Stock')->find({uniquename=>"${prefix}_plot_$_"})->stock_id} 1..3;
 $phenotype=measurement($trial,$plots[1],23.5,'B');measurement($trial,$plots[2],7.5,'C');
 my $other=CXGN::Trial::TrialCreate->new({chado_schema=>$s,dbh=>$dbh,owner_id=>41,operator=>'janedoe',program=>'test',trial_location=>'test_location',trial_name=>"${prefix}_clean",trial_description=>'Independent clean scope',trial_year=>2031,design_type=>'CRD',design=>{1=>{plot_name=>"${prefix}_clean_plot",stock_name=>"${prefix}_stock_3",plot_number=>1,rep_number=>1,block_number=>1,row_number=>1,col_number=>1}}})->save_trial;
 $clean_trial=$other->{trial_id};die 'Clean scope creation failed' if !$clean_trial;
 $clean_plot=$s->resultset('Stock::Stock')->find({uniquename=>"${prefix}_clean_plot"})->stock_id;measurement($clean_trial,$clean_plot,11,'clean');
 $dbh->do('SELECT refresh_materialized_phenotype_jsonb_table()');
 diag('ACTUAL_LAYOUT_COLUMN_TYPES '.join(',',map {join(':',@$_)} @{$dbh->selectall_arrayref(q{SELECT attname,format_type(atttypid,atttypmod) FROM pg_attribute WHERE attrelid='public.materialized_phenotype_jsonb_table'::regclass AND attname IN ('block','plot_number','row_number','col_number') ORDER BY attname})}));
 is(search_rows(accession_list=>[$stocks[1]])->[0]{germplasm_stock_id},$stocks[1],'fresh old-accession filter is positive');
 is(scalar(@{search_rows(accession_list=>[$stocks[0]])}),0,'fresh unrelated accession filter does not widen the selected unit');
 CXGN::Trial::AccessionChange->new({schema=>$s,trial_id=>$trial})->apply([{plot_id=>$plots[1],new_stock_id=>$stocks[0]}],{curator=>1,rename_plots=>'none'});
 # Actual committed-service state while post-commit materialized refresh is pending.
 my $refresh=qr/(?:cache.*stale|refresh.*analytical|analytical.*refresh)/i;
 fails(sub {search_rows()},$refresh,'stale cached B identity is not returned with live A occurrence');
 fails(sub {search_rows(accession_list=>[$stocks[0]])},$refresh,'new A-only filter cannot silently omit the still-cached B row');
 fails(sub {search_rows(accession_list=>[$stocks[1]])},$refresh,'old B-only filter cannot return the previous identity');
 fails(sub {search_rows(accession_list=>[$stocks[0]],limit=>1,offset=>1000)},$refresh,'validation happens before an empty pagination window');
 fails(sub {search_rows(plot_list=>[ @plots[1,2] ],limit=>1,order_by=>'observationunit_stock_id DESC')},$refresh,'an off-page stale unit is still checked in the requested scope');
 is(search_rows(plot_list=>[$plots[2]],accession_list=>[$stocks[2]])->[0]{germplasm_stock_id},$stocks[2],'unaffected unit and accession retain a positive result');
 is(scalar(@{search_rows(trait_list=>[70741],accession_list=>[$stocks[0]])}),0,'unrequested trait scope is not poisoned by unrelated cached observations');
 is(search_rows(trial_list=>[$clean_trial],plot_list=>[$clean_plot],accession_list=>[$stocks[2]])->[0]{germplasm_stock_id},$stocks[2],'independent trial scope remains usable');
 fails(sub {matrix()},$refresh,'default analytical matrix refuses stale germplasm');
 my $dataset=CXGN::Dataset::File->new({schema=>$s,people_schema=>$f->people_schema,accessions=>[ @stocks[0,1] ],trials=>[$trial],traits=>[70666],data_level=>'plot',quotes=>0,file_name=>"$dir/dataset"});
 my $file="$dir/existing.tsv";open(my $out,'>',$file) or die $!;print $out "PREEXISTING DATA\n";close($out);
 fails(sub {$dataset->retrieve_phenotypes($file)},$refresh,'Dataset::File refuses stale identity before replacing an existing file');
 open(my $in,'<',$file) or die $!;my $content=do {local $/;<$in>};close($in);is($content,"PREEXISTING DATA\n",'failed cached read never truncates or overwrites an existing output');
 my $new_file="$dir/not-created.tsv";fails(sub {$dataset->retrieve_phenotypes($new_file)},$refresh,'failed new dataset export reports refresh prerequisite');ok(!-e $new_file,'failed export does not create a misleading output file');
 $dbh->do('SELECT refresh_materialized_phenotype_jsonb_table()');
 my $after=search_rows(accession_list=>[$stocks[0]]);is(scalar(@$after),1,'real refresh restores the new A-only result');is($after->[0]{germplasm_stock_id},$stocks[0],'refreshed identity is A');is($after->[0]{obsunit_accession_occurrence},2,'refreshed identity and live occurrence agree');
 is(scalar(@{search_rows(accession_list=>[$stocks[1]])}),0,'after real refresh the old B filter correctly returns no row');
 is(matrix()->[1][17],$stocks[0],'actual default matrix models corrected accession A after real refresh');
 my $export=$dataset->retrieve_phenotypes($file);my($exported)=grep {$_->[21] && $_->[21] eq "$plots[1]"} @$export;is($exported->[17],$stocks[0],'actual Dataset::File contains corrected A identity after refresh');
 nested('Live identity labels and new unit-name scope require refresh'=>sub {
  $s->resultset('Stock::Stock')->find($stocks[0])->update({uniquename=>"${prefix}_renamed_A",name=>"${prefix}_renamed_A"});
  fails(sub {search_rows(accession_list=>[$stocks[0]])},$refresh,'same ID with renamed live germplasm is not emitted under its old label');
 });
 nested('Unit label consistency includes a query by the new live name'=>sub {
  my $name="${prefix}_renamed_plot";$s->resultset('Stock::Stock')->find($plots[1])->update({uniquename=>$name,name=>$name});
  fails(sub {search_rows()},$refresh,'cached unit label is checked against its live stock');
  fails(sub {search_rows(observation_unit_names_list=>[$name])},$refresh,'new unit-name filter cannot turn stale labeling into silent omission');
 });
 nested('Ambiguous live primary germplasm is refused before filters'=>sub {
  $s->resultset('Stock::StockRelationship')->create({subject_id=>$plots[1],object_id=>$stocks[1],type_id=>term('plot_of','stock_relationship'),rank=>0});
  fails(sub {search_rows(accession_list=>[$stocks[1]])},qr/ambiguous.*live.*germplasm|live.*germplasm.*ambiguous/i,'a newly matched alternative identity is explicitly ambiguous');
 });
 nested('Legacy field child blocks resolve through all physical source plots'=>sub {
  my($field)=$dbh->selectrow_array('SELECT ne.nd_experiment_id FROM nd_experiment ne JOIN nd_experiment_project nep USING(nd_experiment_id) WHERE nep.project_id=? AND ne.type_id=?',undef,$trial,term('field_layout','experiment_type'));
  my @samples;
  for my $which (0..1) {
   my $name="${prefix}_block_sample_$which";
   my $sample=$s->resultset('Stock::Stock')->create({name=>$name,uniquename=>$name,organism_id=>$template->organism_id,type_id=>term('tissue_sample','stock_type')});
   my @parents=$which ? @plots[0,1] : ($plots[1]);
   $sample->create_related('stock_relationship_subjects',{object_id=>$_,type_id=>term('tissue_sample_of','stock_relationship')}) for @parents;
   $sample->create_related('stock_relationship_subjects',{object_id=>$stocks[0],type_id=>term('tissue_sample_of','stock_relationship')});
   $sample->create_related('nd_experiment_stocks',{nd_experiment_id=>$field,type_id=>term('field_layout','experiment_type')});
   $sample->create_related('stockprops',{type_id=>term('design_replicate','stock_property'),value=>9,rank=>0});
   $sample->create_related('stockprops',{type_id=>term('replicate','stock_property'),value=>$which ? undef:2,rank=>0});
   $sample->create_related('stockprops',{type_id=>term('block','stock_property'),value=>'01',rank=>0}) if $which;
   push @samples,$sample->stock_id;measurement($trial,$sample->stock_id,14.5+$which,"block_child_$which");
  }
  $dbh->do('SELECT refresh_materialized_phenotype_jsonb_table()');
  my $child_row=sub {
   my($id)=@_;my $rows=search_rows(plot_list=>[$id],data_level=>'tissue_sample');
   is(scalar(@$rows),1,'actual refreshed materialized tissue unit is present');
   die 'The tissue materialized-view predicate prerequisite is not installed' if @$rows!=1;
   return $rows->[0];
  };
  my $single=$child_row->($samples[0]);
  is($single->{obsunit_block},9,'legacy child without an own block uses its single field source');
  is($single->{obsunit_block_raw},undef,'legacy missing raw block remains separately unknown');
  is($s->resultset('Stock::Stockprop')->search({stock_id=>$samples[0],type_id=>term('block','stock_property')})->count,0,'analytical fallback does not fabricate a stored historical block');
  is($child_row->($samples[1]){obsunit_block},9,'pooled field sources with identical blocks resolve unanimously');
  set_prop('block','0');
  is($child_row->($samples[0])->{obsunit_block},'0','single-source child resolves the live parent zero block');
  my $pool=$child_row->($samples[1]);
  is($pool->{obsunit_block},undef,'different pooled source blocks never choose an arbitrary parent');
  is($pool->{obsunit_block_raw},'01','own historical block remains available for audit');
  $dbh->do('SELECT refresh_materialized_phenotype_jsonb_table()');
  is($child_row->($samples[1]){obsunit_block},undef,'real refresh cannot replace pooled block unknown with its stale own label');
 });
 nested('Live physical scalars retain exact text and NULL despite old cached geometry'=>sub {
  set_prop('block','0');set_prop('row_number','01');set_prop('col_number',undef);set_prop('plot number','02');set_prop('is a control','0');
  my $old=$dbh->selectrow_arrayref('SELECT block,row_number,col_number,plot_number FROM materialized_phenotype_jsonb_table WHERE observationunit_stock_id=?',undef,$plots[1]);
  is_deeply($old,[9,1,2,2],'control materialized geometry has genuinely not been refreshed');
  my $live=search_rows()->[0];is_deeply([@{$live}{qw(obsunit_block obsunit_row_number obsunit_col_number obsunit_plot_number obsunit_is_a_control)}],['0','01',undef,'02','0'],'analytical rich result projects exact live scalar values');
  my $m=matrix();is_deeply([@{$m->[1]}[24..28]],['0','02','01',undef,'test'],'matrix physical metadata does not reuse stale block/coordinates');
  is($m->[0][39],SGN::Model::Cvterm::get_trait_from_cvterm_id($s,70666,'extended'),'default trait position remains 39');
  $dbh->do('SELECT refresh_materialized_phenotype_jsonb_table()');
  is_deeply([@{search_rows()->[0]}{qw(obsunit_block obsunit_row_number obsunit_col_number obsunit_plot_number)}],['0','01',undef,'02'],'real refresh preserves the same zero/leading-zero/NULL metadata');
  $s->resultset('Stock::Stockprop')->create({stock_id=>$plots[1],type_id=>term('row_number','stock_property'),value=>'999',rank=>1});
  $dbh->do('SELECT refresh_materialized_phenotype_jsonb_table()');is(search_rows()->[0]{obsunit_row_number},'01','alternate row rank is ignored exactly as in the actual view');
  $s->resultset('Stock::Stockprop')->create({stock_id=>$plots[1],type_id=>term('block','stock_property'),value=>'00',rank=>1});
  fails(sub {search_rows()},qr/ambiguous live layout property block/i,'conflicting live scalar values get a specific unsupported-metadata diagnostic');
 });
 is($dbh->selectrow_array('SELECT value FROM phenotype WHERE phenotype_id=?',undef,$phenotype),'23.5','all cache checks retain the original phenotype value');
 1;
};
my $error=$@;$s->txn_rollback;$tx=0;
ok($ran,'actual cached/live identity and scalar contracts completed; all fixture/cache changes rolled back') or diag($error);
done_testing;
