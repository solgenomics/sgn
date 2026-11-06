use strict;
use warnings;
use lib 't/lib';
use Test::More;
use SGN::Test::Fixture;
use SGN::Model::Cvterm;
use CXGN::BrAPI::v1::ObservationUnits;

my $f=SGN::Test::Fixture->new;
my $s=$f->bcs_schema;my $dbh=$s->storage->dbh;
$s->storage->auto_savepoint(1);
my $trial=$s->resultset('Project::Project')->find({name=>'test_trial'})->project_id;
my $plot=$s->resultset('Stock::Stock')->find({uniquename=>'test_trial211'})->stock_id;
sub term {SGN::Model::Cvterm->get_cvterm_row($s,@_)->cvterm_id}
sub listing {
 my(%bounds)=@_;
 my $api=CXGN::BrAPI::v1::ObservationUnits->new({bcs_schema=>$s,metadata_schema=>$f->metadata_schema,phenome_schema=>$f->phenome_schema,people_schema=>$f->people_schema,context=>{},page=>0,page_size=>10,status=>[]});
 return $api->search({observationLevel=>['plot'],studyDbIds=>[$trial],observationUnitNames=>['test_trial211'],%bounds});
}
sub values_for {
 my $r=listing(@_);die 'search failed' if !defined($r->{result});
 return [sort {$a<=>$b} map {0+$_->{value}} @{$r->{result}{data}[0]{observations}||[]}];
}
my $tx=0;END {eval{$s->txn_rollback if $tx} if $s;}
$s->txn_begin;$tx=1;
my $ran=eval {
 my $n=0;
 for my $pair ([9,'2026-11-02 09:00:00'],[10,'2026-11-02 10:00:00'],[11,'2026-11-02 11:00:00'],[12,undef]) {
  my $type=term('phenotyping_experiment','experiment_type');
  my $e=$s->resultset('NaturalDiversity::NdExperiment')->create({type_id=>$type,nd_geolocation_id=>$s->resultset('NaturalDiversity::NdGeolocation')->first->nd_geolocation_id});
  $e->create_related('nd_experiment_projects',{project_id=>$trial});$e->create_related('nd_experiment_stocks',{stock_id=>$plot,type_id=>$type});
  my $p=$s->resultset('Phenotype::Phenotype')->create({uniquename=>'v1_unit_dates_final_'.++$n,cvalue_id=>70666,observable_id=>70666,value=>$pair->[0],collect_date=>$pair->[1],operator=>'janedoe'});
  $e->create_related('nd_experiment_phenotypes',{phenotype_id=>$p->phenotype_id});
 }
 $dbh->do('SELECT refresh_materialized_phenotype_jsonb_table()');
 is_deeply(values_for(),[9,10,11,12],'unbounded listing preserves dated and undated values');
 is_deeply(values_for(observationTimeStampRangeStart=>['2026-11-02T09:30:00Z']),[10,11],'v1 unit start-only bound uses complete UTC time');
 is_deeply(values_for(observationTimeStampRangeEnd=>['2026-11-02T10:30:00Z']),[9,10],'v1 unit end-only bound uses complete UTC time');
 is_deeply(values_for(observationTimeStampRangeStart=>['2026-11-02T11:30:00+02:00'],observationTimeStampRangeEnd=>['2026-11-02T12:30:00+02:00']),[10],'offset interval selects the same instant');
 is_deeply(values_for(observationTimeStampRangeStart=>['2026-11-02'],observationTimeStampRangeEnd=>['2026-11-02']),[9,10,11],'date-only upper includes the full day');
 is_deeply(values_for(observationTimeStampRangeStart=>['2026-11-02T10:00:00Z'],observationTimeStampRangeEnd=>['2026-11-02T10:00:00Z']),[10],'exact bounds are inclusive');
 is(listing(observationTimeStampRangeStart=>['invalid date'])->{http_code},400,'invalid bound is a controlled validation response');
 is(($dbh->selectrow_array('SELECT 1'))[0],1,'invalid bound did not abort the fixture transaction');
 1;
};
my $error=$@;$s->txn_rollback;$tx=0;
ok($ran,'actual grouped v1 unit date queries executed and rolled back') or diag($error);
done_testing;
