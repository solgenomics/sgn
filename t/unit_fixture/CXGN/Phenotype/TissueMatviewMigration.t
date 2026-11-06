use strict;use warnings;use lib 't/lib';use lib 'db/00212';
use Test::More;use File::Temp qw(tempfile);
use SGN::Test::Fixture;use SGN::Model::Cvterm;use CXGN::Trial;use CXGN::Trial::TrialCreate;
use CXGN::Phenotypes::SearchFactory;use CXGN::Phenotypes::PhenotypeMatrix;

# Exercise actual patch SQL with its one schema constructor redirected to the
# fixture rollback transaction. Cold bootstrap separately qualifies the real
# cloned-connection first-DDL lifecycle; this test must not commit global DDL.
my $f=SGN::Test::Fixture->new;my $s=$f->bcs_schema;my $dbh=$s->storage->dbh;
$s->storage->auto_savepoint(1);my $prefix='audit_tissue_matview_migration_'.$$;
sub term {SGN::Model::Cvterm->get_cvterm_row($s,@_)->cvterm_id}
sub metadata {
 my $row=$dbh->selectrow_hashref(q{SELECT c.oid,pg_get_userbyid(c.relowner) AS owner,c.reloptions,c.reltablespace,obj_description(c.oid,'pg_class') AS comment,pg_get_viewdef(c.oid,true) AS definition FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relname='materialized_phenotype_jsonb_table'});
 $row->{indexes}=$dbh->selectall_arrayref('SELECT c.relname,pg_get_indexdef(i.indexrelid) FROM pg_index i JOIN pg_class c ON c.oid=i.indexrelid WHERE i.indrelid=? ORDER BY c.relname',undef,$row->{oid});
 $row->{acl}=$dbh->selectall_arrayref(q{SELECT a.grantee,a.grantor,a.privilege_type,a.is_grantable FROM pg_class c CROSS JOIN LATERAL aclexplode(COALESCE(c.relacl,acldefault('r',c.relowner))) a WHERE c.oid=? ORDER BY a.grantee,a.grantor,a.privilege_type,a.is_grantable},undef,$row->{oid});
 return $row;
}
sub predicate_types {my($definition)=@_;my($types)=$definition=~/\bstock_relationship\.type_id\s*=\s*ANY\s*\(ARRAY\[([\d,\s]+)\]\)/;die 'Unknown actual materialized predicate shape' if !defined($types);return [split /\s*,\s*/,$types]}
{package TissueMigrationContext;sub dbh {$_[0]{dbh}}} ## no critic (Modules::RequireFilenameMatchesPackage) -- This test embeds its named test double beside the assertions.
sub run_patch {
 my $connects=0;{no warnings 'redefine';local *Bio::Chado::Schema::connect=sub {++$connects;return $s};IncludeTissueSamplesInPhenotypeMatview::patch(bless({dbh=>$dbh},'TissueMigrationContext'))}
 is($connects,1,'actual patch uses the rollback schema seam once');ok(!$dbh->{AutoCommit},'actual DDL method preserves the enclosing fixture transaction');
}
my $tx=0;END {eval{$s->txn_rollback if $tx} if $s}
$s->txn_begin;$tx=1;
my $ok=eval {
 require IncludeTissueSamplesInPhenotypeMatview;
 $s->resultset('Cv::Cvterm')->create_with({name=>'design_replicate',cv=>'stock_property',definition=>'Recorded design group'});
 $s->resultset('Cv::Cvterm')->create_with({name=>'accession_occurrence_version',cv=>'project_property',definition=>'Whole-field occurrence cutover'});
 my $made=CXGN::Trial::TrialCreate->new({chado_schema=>$s,dbh=>$dbh,owner_id=>41,operator=>'janedoe',program=>'test',trial_location=>'test_location',trial_name=>$prefix,trial_description=>'Actual native tissue matview migration contract',trial_year=>2031,design_type=>'CRD',design=>{1=>{plot_name=>"${prefix}_plot",stock_name=>'test_accession1',plot_number=>1,rep_number=>1,block_number=>9,row_number=>1,col_number=>1}}})->save_trial;
 my $trial=$made->{trial_id};die 'Native trial creation failed' if !$trial;
 my(undef,$tmp)=tempfile(TMPDIR=>1,UNLINK=>1);my $config={(map {$_=>$f->config->{$_}} qw(basepath dbhost dbname dbuser dbpass)),temp_file_nd_experiment_id=>$tmp,user_id=>41,metadata_hash=>{archived_file=>'none',archived_file_type=>'new stock treatment auto inheritance',operator=>'janedoe',date=>'2031-01-01'}};
 my $t=CXGN::Trial->new({bcs_schema=>$s,trial_id=>$trial,metadata_schema=>$f->metadata_schema,phenome_schema=>$f->phenome_schema});
 ok($t->create_plant_entities(1,1,undef,undef,undef,undef,$config),'actual native plant created');ok($t->create_tissue_samples(['leaf'],0,0,undef,undef,$config),'actual native tissue created');
 my $sample=$s->resultset('Stock::Stock')->search({'me.uniquename'=>{-like=>"${prefix}%leaf"},'me.type_id'=>term('tissue_sample','stock_type')})->first;die 'Missing actual native tissue' if !$sample;
 my $unit=$sample->stock_id;my $type=term('phenotyping_experiment','experiment_type');
 my $e=$s->resultset('NaturalDiversity::NdExperiment')->create({type_id=>$type,nd_geolocation_id=>$s->resultset('NaturalDiversity::NdGeolocation')->first->nd_geolocation_id});$e->create_related('nd_experiment_projects',{project_id=>$trial});$e->create_related('nd_experiment_stocks',{stock_id=>$unit,type_id=>$type});
 my $p=$s->resultset('Phenotype::Phenotype')->create({uniquename=>$prefix.'_measurement',cvalue_id=>70666,observable_id=>70666,value=>17,operator=>'janedoe'});$e->create_related('nd_experiment_phenotypes',{phenotype_id=>$p->phenotype_id});
 my $before=metadata();my $tissue=term('tissue_sample_of','stock_relationship');my $was_current=grep {$_==$tissue} @{predicate_types($before->{definition})};
 run_patch();my $after=metadata();
 ok((grep {$_==$tissue} @{predicate_types($after->{definition})}),'actual materialized predicate includes tissue_sample_of');
 for my $name (qw(plot_of plant_of subplot_of analysis_of)) {my $id=term($name,'stock_relationship');ok((grep {$_==$id} @{predicate_types($after->{definition})}),"existing $name predicate is retained")}
 if ($was_current) {is($after->{oid},$before->{oid},'already-current migration leaves the relation OID unchanged')}
 else {isnt($after->{oid},$before->{oid},'legacy predicate is rebuilt rather than silently treated as current')} # codespell:ignore isnt
 is_deeply($after->{indexes},$before->{indexes},'all actual index names and definitions are preserved');
 is($after->{owner},$before->{owner},'materialized owner is preserved');is_deeply($after->{acl},$before->{acl},'effective grants, grant options and grantors are preserved');
 is_deeply($after->{reloptions},$before->{reloptions},'storage options are preserved');is($after->{reltablespace},$before->{reltablespace},'tablespace metadata is preserved');is($after->{comment},$before->{comment},'materialized comment is preserved');
 # An already-current patch is deliberately not a refresh command. Refresh the
 # newly created fixture before asserting actual positive analytical outputs.
 $dbh->do('SELECT refresh_materialized_phenotype_jsonb_table()');
 is($dbh->selectrow_array('SELECT count(*) FROM materialized_phenotype_jsonb_table WHERE observationunit_stock_id=?',undef,$unit),1,'real refreshed materialized view retains the actual native tissue unit');
 my($rows)=CXGN::Phenotypes::SearchFactory->instantiate('MaterializedViewTable',{bcs_schema=>$s,data_level=>'tissue_sample',trial_list=>[$trial],trait_list=>[70666]})->search;
 is(scalar(@$rows),1,'actual materialized tissue search returns the measured native unit');is($rows->[0]{observations}[0]{value},17,'actual materialized tissue search retains the phenotype value');
 my @matrix=CXGN::Phenotypes::PhenotypeMatrix->new({bcs_schema=>$s,search_type=>'MaterializedViewTable',data_level=>'tissue_sample',trial_list=>[$trial],trait_list=>[70666]})->get_phenotype_matrix;
 is(scalar(@matrix)-1,1,'supported tissue matrix includes one actual data row');is($matrix[0][39],SGN::Model::Cvterm::get_trait_from_cvterm_id($s,70666,'extended'),'default matrix trait position stays39');is($matrix[1][39],17,'actual matrix tissue value is not silently omitted');
 my $first=metadata();run_patch();my $second=metadata();
 is_deeply($second,$first,'rerun leaves OID, definition, indexes, grants, owner and storage metadata unchanged');
 is($dbh->selectrow_array('SELECT value FROM phenotype WHERE phenotype_id=?',undef,$p->phenotype_id),17,'migration and rerun preserve the raw phenotype');
 1;
};my $error=$@;$s->txn_rollback;$tx=0;ok($ok,'actual migration/native tissue/matrix checks completed and all fixture changes rolled back') or diag($error);done_testing;
