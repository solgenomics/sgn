use strict;use warnings;use lib 't/lib';use Test::More;use JSON ();use SGN::Test::Fixture;use SGN::Model::Cvterm;use CXGN::BrAPI::v1::Observations;use CXGN::BrAPI::v2::Observations;
my$f=SGN::Test::Fixture->new;my$s=$f->bcs_schema;my$dbh=$s->storage->dbh;$s->storage->auto_savepoint(1);
my$plot=$s->resultset('Stock::Stock')->find({uniquename=>'test_trial211'})->stock_id;my$trial=$s->resultset('Project::Project')->find({name=>'test_trial'})->project_id;
sub term {SGN::Model::Cvterm->get_cvterm_row($s,@_)->cvterm_id}
$s->txn_begin;my$ok=eval{
 my$type=term('phenotyping_experiment','experiment_type');my$e=$s->resultset('NaturalDiversity::NdExperiment')->create({type_id=>$type,nd_geolocation_id=>$s->resultset('NaturalDiversity::NdGeolocation')->first->nd_geolocation_id});
 $e->create_related('nd_experiment_projects',{project_id=>$trial});$e->create_related('nd_experiment_stocks',{stock_id=>$plot,type_id=>$type});
 my$p=$s->resultset('Phenotype::Phenotype')->create({uniquename=>"raw_rejection_contract_$$",cvalue_id=>70666,observable_id=>70666,value=>19,collect_date=>'2030-11-03 10:00:00',operator=>'janedoe'});$e->create_related('nd_experiment_phenotypes',{phenotype_id=>$p->phenotype_id});
 $s->resultset('Stock::Stockprop')->search({stock_id=>$plot,type_id=>term('rejected','stock_property')})->delete;
 $s->resultset('Stock::Stockprop')->find_or_create({stock_id=>$plot,type_id=>term('rejected','stock_property'),value=>1,rank=>0});
 for my$v(qw(v1 v2)) {
  my$class="CXGN::BrAPI::${v}::Observations";
  for my$c([undef,0,'default'],['true',1,'query true'],[JSON::true,1,'JSON true'],[JSON::false,0,'JSON false']) {
   my$m=$class->new({bcs_schema=>$s,metadata_schema=>$f->metadata_schema,phenome_schema=>$f->phenome_schema,people_schema=>$f->people_schema,context=>undef,page=>0,page_size=>100,status=>[]});
   my$r=$m->search({observationDbIds=>[$p->phenotype_id],defined($c->[0])?(includeRejected=>$c->[0]):()});
   is(scalar@{$r->{result}{data}},$c->[1],"$v $c->[2] returns the intended raw/rejected data set");
   if($c->[1]) {ok($r->{result}{data}[0]{additionalInfo}{rejected},"$v explicit raw observation is flagged")}
  }
 }
 is($s->resultset('Phenotype::Phenotype')->find($p->phenotype_id)->value,19,'read policy never deletes or changes the raw measurement');1;
};my$error=$@;$s->txn_rollback;ok($ok,'read contracts completed and fixture rolled back')or diag($error);done_testing;
