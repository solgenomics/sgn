use strict;
use warnings;
use lib 't/lib';
use Test::More;
use SGN::Test::Fixture;
use SGN::Model::Cvterm;
use CXGN::Phenotypes::SearchFactory;

my $f=SGN::Test::Fixture->new;
my $s=$f->bcs_schema;my $dbh=$s->storage->dbh;
$s->storage->auto_savepoint(1);
my $trial=$s->resultset('Project::Project')->find({name=>'test_trial'})->project_id;
my $plot=$s->resultset('Stock::Stock')->find({uniquename=>'test_trial211'})->stock_id;
my $type=SGN::Model::Cvterm->get_cvterm_row($s,'phenotyping_experiment','experiment_type')->cvterm_id;
my $tx=0;END {eval{$s->txn_rollback if $tx} if $s}
$s->txn_begin;$tx=1;
my $ran=eval {
 my @cases=(['0','legacy_must_not_replace_zero','0'],['janedoe','legacy_must_not_replace_stored','janedoe'],[undef,'legacy_collector','legacy_collector'],[undef,'0','0']);
 my $number=0;
 for my $case (@cases) {
  my $experiment=$s->resultset('NaturalDiversity::NdExperiment')->create({type_id=>$type,nd_geolocation_id=>$s->resultset('NaturalDiversity::NdGeolocation')->first->nd_geolocation_id});
  $experiment->create_related('nd_experiment_projects',{project_id=>$trial});
  $experiment->create_related('nd_experiment_stocks',{stock_id=>$plot,type_id=>$type});
  my $name='audit_operator_read_'.$$.'_'.++$number.' date: 2030-11-03 10:00:00+0000  operator = '.$case->[1];
  my $phenotype=$s->resultset('Phenotype::Phenotype')->create({uniquename=>$name,cvalue_id=>70666,observable_id=>70666,value=>20+$number,collect_date=>'2030-11-03 10:00:00',operator=>$case->[0]});
  $experiment->create_related('nd_experiment_phenotypes',{phenotype_id=>$phenotype->phenotype_id});
  push @$case,$phenotype->phenotype_id;
 }
 $dbh->do('SELECT refresh_materialized_phenotype_jsonb_table()');
 for my $engine (qw(Native MaterializedViewTable)) {
  for my $case (@cases) {
   my $id=$case->[3];
   my($rows)=CXGN::Phenotypes::SearchFactory->instantiate($engine,{bcs_schema=>$s,data_level=>'plot',trial_list=>[$trial],plot_list=>[$plot],trait_list=>[70666],observation_id_list=>[$id],include_timestamp=>1})->search;
   my @observations=$engine eq 'Native' ? @$rows : map {@{$_->{observations}||[]}} @$rows;
   my @found=grep {defined($_->{phenotype_id}) && $_->{phenotype_id}==$id} @observations;
   is(scalar(@found),1,"$engine finds exact observation $id");
   my $label=defined($case->[0]) ? "stored operator '$case->[0]' overrides its legacy name" : "NULL operator falls back to legacy '$case->[1]'";
   is(@found ? $found[0]{operator} : undef,$case->[2],"$engine $label");
  }
 }
 1;
};
my $error=$@;$s->txn_rollback;$tx=0;
ok($ran,'both actual read engines completed and all synthetic observations/cache changes rolled back') or diag($error);
done_testing;
