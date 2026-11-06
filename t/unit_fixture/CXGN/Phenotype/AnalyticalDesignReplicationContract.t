use strict;
use warnings;
use lib 't/lib';
use Test::More;
use File::Temp qw(tempdir);
use SGN::Test::Fixture;
use SGN::Model::Cvterm;
use CXGN::Trial::TrialCreate;
use CXGN::Phenotypes::SearchFactory;
use CXGN::Phenotypes::PhenotypeMatrix;
use CXGN::Dataset::File;

my $f=SGN::Test::Fixture->new;my $s=$f->bcs_schema;my $dbh=$s->storage->dbh;
$s->storage->auto_savepoint(1);
my $dir=tempdir(CLEANUP=>1);my $prefix='audit_design_projection_'.$$;
my($trial,$plot,$accession,$rep_type,$design_type,$version_type,$trait_name);
sub prop {
 my($type,$value,$remove)=@_;
 $s->resultset('Stock::Stockprop')->search({stock_id=>$plot,type_id=>$type})->delete;
 $s->resultset('Stock::Stockprop')->create({stock_id=>$plot,type_id=>$type,value=>$value,rank=>0}) if !$remove;
}
sub rich {
 my($engine)=@_;
 my($rows)=CXGN::Phenotypes::SearchFactory->instantiate($engine,{bcs_schema=>$s,data_level=>'plot',trial_list=>[$trial],plot_list=>[$plot],trait_list=>[70666]})->search;
 my @actual=$engine eq 'Native' ? grep {defined($_->{phenotype_id})} @$rows : @$rows;
 die "$engine did not return exactly one measured unit (got ".scalar(@actual).")" if @actual!=1;return $actual[0];
}
sub matrix {
 my($engine)=@_;my @rows=CXGN::Phenotypes::PhenotypeMatrix->new({bcs_schema=>$s,search_type=>$engine,data_level=>'plot',trial_list=>[$trial],plot_list=>[$plot],trait_list=>[70666]})->get_phenotype_matrix;
 return \@rows;
}
my $tx=0;END {eval{$s->txn_rollback if $tx} if $s}
$s->txn_begin;$tx=1;
my $ran=eval {
 my $rep=SGN::Model::Cvterm->get_cvterm_row($s,'replicate','stock_property');$rep_type=$rep->cvterm_id;
 my $design=$s->resultset('Cv::Cvterm')->search({'me.name'=>'design_replicate','cv.name'=>'stock_property'},{join=>'cv'})->first;
 if (!$design) {my $xref=$s->resultset('General::Dbxref')->create({db_id=>$rep->dbxref->db_id,accession=>'audit_design_projection_'.$$});$design=$s->resultset('Cv::Cvterm')->create({name=>'design_replicate',cv_id=>$rep->cv_id,dbxref_id=>$xref->dbxref_id})}
 $design_type=$design->cvterm_id;
 my $version=$s->resultset('Cv::Cvterm')->search({'me.name'=>'accession_occurrence_version','cv.name'=>'project_property'},{join=>'cv'})->first;
 if (!$version) {
  my $template=SGN::Model::Cvterm->get_cvterm_row($s,'design','project_property');
  my $xref=$s->resultset('General::Dbxref')->create({db_id=>$template->dbxref->db_id,accession=>'audit_occurrence_version_projection_'.$$});
  $version=$s->resultset('Cv::Cvterm')->create({name=>'accession_occurrence_version',cv_id=>$template->cv_id,dbxref_id=>$xref->dbxref_id});
 }
 $version_type=$version->cvterm_id;
 my $created=CXGN::Trial::TrialCreate->new({chado_schema=>$s,dbh=>$dbh,owner_id=>41,operator=>'janedoe',program=>'test',trial_location=>'test_location',trial_name=>$prefix,trial_description=>'One-unit analytical design-factor projection fixture',trial_year=>2031,design_type=>'RCBD',design=>{1=>{plot_name=>"${prefix}_plot",plot_number=>1,stock_name=>'test_accession1',rep_number=>9,block_number=>7,row_number=>1,col_number=>1}}})->save_trial;
 $trial=$created->{trial_id};die 'Native trial fixture setup failed' if !$trial;
 $plot=$s->resultset('Stock::Stock')->find({uniquename=>"${prefix}_plot"})->stock_id;
 $accession=$s->resultset('Stock::Stock')->find({uniquename=>'test_accession1'})->stock_id;
 prop($rep_type,9);prop($design_type,undef,1); # simulate an unmigrated legacy unit
 my $type=SGN::Model::Cvterm->get_cvterm_row($s,'phenotyping_experiment','experiment_type')->cvterm_id;
 my $e=$s->resultset('NaturalDiversity::NdExperiment')->create({type_id=>$type,nd_geolocation_id=>$s->resultset('NaturalDiversity::NdGeolocation')->first->nd_geolocation_id});
 $e->create_related('nd_experiment_projects',{project_id=>$trial});$e->create_related('nd_experiment_stocks',{stock_id=>$plot,type_id=>$type});
 my $p=$s->resultset('Phenotype::Phenotype')->create({uniquename=>"${prefix}_measurement",cvalue_id=>70666,observable_id=>70666,value=>23,operator=>'janedoe'});
 $e->create_related('nd_experiment_phenotypes',{phenotype_id=>$p->phenotype_id});
 $trait_name=SGN::Model::Cvterm::get_trait_from_cvterm_id($s,70666,'extended');
 $dbh->do('SELECT refresh_materialized_phenotype_jsonb_table()');
 my $dataset=CXGN::Dataset::File->new({schema=>$s,people_schema=>$f->people_schema,accessions=>[$accession],trials=>[$trial],traits=>[70666],data_level=>'plot',quotes=>0,file_name=>"$dir/design_projection"});
 for my $case (['legacy no row',9,undef,1,9,0],['recorded zero with stale cache',5,0,0,0,1],['recorded unknown with stale cache',2,undef,0,undef,1],['recorded group and zero occurrence',0,30,0,30,1]) {
  my($name,$occurrence,$group,$remove,$expected,$ready)=@$case;
  subtest $name=>sub {
   prop($rep_type,$occurrence);prop($design_type,$group,$remove);
   $s->resultset('Project::Projectprop')->search({project_id=>$trial,type_id=>$version_type})->delete;
   $s->resultset('Project::Projectprop')->create({project_id=>$trial,type_id=>$version_type,value=>'1',rank=>0}) if $ready;
   # No refresh or layout regeneration here: projection must use live rows.
   for my $engine (qw(Native MaterializedViewTable)) {
    my $row=rich($engine);
    my $legacy_key=$engine eq 'Native' ? 'rep':'obsunit_rep';
    is($row->{$legacy_key},$expected,"$engine legacy analytical replica is the physical group");
    is($row->{obsunit_rep},$expected,"$engine named analytical replica agrees");
    is($row->{obsunit_design_rep},$expected,"$engine explicit design group preserves zero/unknown");
    is($row->{obsunit_accession_occurrence},$ready ? $occurrence : undef,"$engine counter is live only after the project cutover");
    is($row->{obsunit_occurrence_ready},$ready,"$engine reports the explicit counter readiness state");
    is($row->{obsunit_design_rep_recorded},$remove ? 0:1,"$engine reports snapshot row presence independently of a NULL value");
    my $table=matrix($engine);is(scalar(@$table),2,"$engine matrix has one data row");
    is($table->[0][23],'replicate',"$engine existing replica column remains index23");
    is($table->[1][23],$expected,"$engine matrix replica retains physical design meaning");
    my $trait_index=$engine eq 'Native' ? 30:39;
    is($table->[0][$trait_index],$trait_name,"$engine trait start position remains $trait_index");
    is($table->[1][$trait_index],23,"$engine trait value remains in its original position");
    is($table->[1][24],7,"$engine actual block is unchanged");
   }
   my $file="$dir/".($remove ? 'legacy' : defined($group) ? "group_$group" : 'unknown').'.tsv';
   my $table=$dataset->retrieve_phenotypes($file);
   is($table->[0][23],'replicate','Dataset::File keeps the default replica header');
   is($table->[1][23],$expected,'Dataset::File in-memory replica is the physical group');
   open(my $in,'<',$file) or die $!;my @lines=<$in>;close($in);chomp @lines;
   my @header=split /\t/,$lines[0],-1;my @data=split /\t/,$lines[1],-1;
   is($header[39],$trait_name,'Dataset::File trait starts at original index39');
   is($data[23],defined($expected) ? "$expected" : '','Dataset::File serialized zero/unknown is not replaced with the counter');
   is($data[39],23,'Dataset::File serialized trait is unchanged');
  };
 }
 1;
};
my $error=$@;$s->txn_rollback;$tx=0;
ok($ran,'all actual analytical producers completed and all fixture/cache changes rolled back') or diag($error);
done_testing;
