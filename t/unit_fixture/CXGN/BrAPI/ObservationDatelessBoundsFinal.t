use strict;
use warnings;
use lib 't/lib';
use Test::More;
use SGN::Test::Fixture;
use SGN::Model::Cvterm;
use CXGN::BrAPI::JSONResponse;
use CXGN::Phenotypes::SearchFactory;
use CXGN::BrAPI::v1::Observations;
use CXGN::BrAPI::v2::Observations;

my $f=SGN::Test::Fixture->new;
my $s=$f->bcs_schema;my $dbh=$s->storage->dbh;
$s->storage->auto_savepoint(1);
my $trial=$s->resultset('Project::Project')->find({name=>'test_trial'})->project_id;
my $plot=$s->resultset('Stock::Stock')->find({uniquename=>'test_trial211'})->stock_id;
my @ids;
sub read_observations {
 my($version,%bounds)=@_;
 my $class="CXGN::BrAPI::${version}::Observations";
 my $model=$class->new({bcs_schema=>$s,metadata_schema=>$f->metadata_schema,phenome_schema=>$f->phenome_schema,people_schema=>$f->people_schema,context=>undef,page=>0,page_size=>10,status=>[]});
 return $model->search({observationDbIds=>[map {"$_"} @ids],observationLevel=>['plot'],studyDbIds=>[$trial],%bounds});
}
sub returned_ids {
 my($response)=@_;
 die 'Observation search failed' if !defined($response->{result});
 return [sort {$a<=>$b} map {0+$_->{observationDbId}} @{$response->{result}{data}||[]}];
}
my $tx=0;END {eval{$s->txn_rollback if $tx} if $s}
$s->txn_begin;$tx=1;
my $ran=eval {
 my $type=SGN::Model::Cvterm->get_cvterm_row($s,'phenotyping_experiment','experiment_type')->cvterm_id;
 for my $i (0..1) {
  my $experiment=$s->resultset('NaturalDiversity::NdExperiment')->create({type_id=>$type,nd_geolocation_id=>$s->resultset('NaturalDiversity::NdGeolocation')->first->nd_geolocation_id});
  $experiment->create_related('nd_experiment_projects',{project_id=>$trial});
  $experiment->create_related('nd_experiment_stocks',{stock_id=>$plot,type_id=>$type});
  my $p=$s->resultset('Phenotype::Phenotype')->create({uniquename=>'audit_dateless_bounds_'.$$.'_'.$i,cvalue_id=>70666,observable_id=>70666,value=>11+$i,collect_date=>$i ? undef : '2030-11-03 10:00:00',operator=>'janedoe'});
  $experiment->create_related('nd_experiment_phenotypes',{phenotype_id=>$p->phenotype_id});push @ids,$p->phenotype_id;
 }
 for my $version (qw(v1 v2)) {
  subtest "$version date filters require a known observation date" => sub {
   my $unbounded=read_observations($version);
   is_deeply(returned_ids($unbounded),[sort {$a<=>$b} @ids],'unbounded read preserves dated and undated observations');
   is($unbounded->{pagination}{totalCount},2,'unbounded pagination counts both exact requested IDs');
   is_deeply(returned_ids(read_observations($version,observationTimeStampRangeStart=>['2030-11-04T00:00:00Z'])),[],'start-only bound excludes earlier and undated observations');
   is_deeply(returned_ids(read_observations($version,observationTimeStampRangeEnd=>['2030-11-02T23:59:59Z'])),[],'end-only bound excludes later and undated observations');
   my $outside=read_observations($version,observationTimeStampRangeStart=>['2030-11-04T00:00:00Z'],observationTimeStampRangeEnd=>['2030-11-05T00:00:00Z']);
   is_deeply(returned_ids($outside),[],'outside interval cannot match an observation without a date');
   is($outside->{pagination}{totalCount},0,'bounded pagination excludes undated observations too');
   is_deeply(returned_ids(read_observations($version,observationTimeStampRangeStart=>['2030-11-03'],observationTimeStampRangeEnd=>['2030-11-03'])),[$ids[0]],'matching date-only interval returns just the dated control');
  };
 }
 1;
};
my $error=$@;$s->txn_rollback;$tx=0;
ok($ran,'both actual API models completed and all exact-ID fixtures rolled back') or diag($error);
done_testing;
