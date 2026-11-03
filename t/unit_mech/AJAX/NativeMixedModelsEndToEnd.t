use strict;use warnings;use lib 't/lib';use Test::More;use Test::WWW::Mechanize;use JSON::XS qw(encode_json decode_json);use SGN::Test::Fixture;use SGN::Model::Cvterm;use CXGN::Dataset::File;use File::Path qw(make_path);use File::Temp qw(tempdir);use Scalar::Util qw(looks_like_number);use Digest::MD5 qw(md5_hex);use File::Slurp qw(read_file write_file);use Cwd qw(getcwd);
# Actual HTTP, Catalyst context, native Job/Tsp, real R and immutable run files.
my$f=SGN::Test::Fixture->new;my$s=$f->bcs_schema;my$root=getcwd;my$tag="audit_http_model_$$";my$work="$root/static/documents/tempfiles/$tag";make_path($work);
my$before=$f->people_schema->resultset('SpJob')->get_column('sp_job_id')->max || 0;
my@owned_jobs;END {eval{$_->delete for @owned_jobs};}
# Choose a qualified existing fixture rather than assuming its lowest project
# ID has enough independent repeated numeric observations after other tests.
my $candidates=$s->storage->dbh->selectcol_arrayref(q{
 SELECT nep.project_id FROM nd_experiment_project nep
 JOIN nd_experiment_phenotype nph USING(nd_experiment_id)
 JOIN phenotype ph USING(phenotype_id)
 JOIN nd_experiment_stock nes USING(nd_experiment_id)
 JOIN stock u ON u.stock_id=nes.stock_id
 JOIN cvterm ut ON ut.cvterm_id=u.type_id AND ut.name='plot'
 JOIN stock_relationship gr ON gr.subject_id=u.stock_id
 JOIN cvterm rt ON rt.cvterm_id=gr.type_id AND rt.name='plot_of'
 GROUP BY nep.project_id,ph.cvalue_id
 HAVING count(DISTINCT u.stock_id)>=16 AND count(DISTINCT gr.object_id)>=8
 ORDER BY nep.project_id
});
my ($trial,$trait,@accessions);
my %seen_trial;
for my $candidate (grep {!$seen_trial{$_}++} @$candidates) {
 my $all=CXGN::Dataset::File->new({schema=>$s,people_schema=>$f->people_schema,file_name=>"$work/candidate_$candidate",quotes=>0});
 $all->trials([$candidate]);
 my $matrix=$all->retrieve_phenotypes;
 next unless @$matrix>1;
 my @header=@{$matrix->[0]};my %column;@column{@header}=(0..$#header);
 next unless exists($column{germplasmDbId}) && exists($column{replicate});
 my %groups=map {defined($_->[$column{replicate}]) && length($_->[$column{replicate}]) ? ($_->[$column{replicate}]=>1):()} @$matrix[1..$#$matrix];
 next unless keys(%groups)>1;
 my @traits=grep {$header[$_]=~/\|CO_/} 39..$#header;
 @traits=sort {($header[$b]=~/fresh root weight/i)<=>($header[$a]=~/fresh root weight/i)} @traits;
 for my $index (@traits) {
  my %count;
  for my $row (@$matrix[1..$#$matrix]) {
   my $value=$row->[$index];next unless defined($value) && $value ne '' && looks_like_number($value) && $value !~ /inf|nan/i;
   $count{$row->[$column{germplasmDbId}]}++;
  }
  my @ids=sort {$a<=>$b} grep {$count{$_}>=2} keys %count;
  if (@ids>=8) {$trial=$candidate;$trait=$header[$index];@accessions=@ids[0..7];last;}
 }
 last if defined($trait);
}
BAIL_OUT('No qualified repeated numeric fixture')unless$trait;
my$trait_id=SGN::Model::Cvterm->get_cvterm_row_from_trait_name($s,$trait)->cvterm_id;my$producer=CXGN::Dataset::File->new({schema=>$s,people_schema=>$f->people_schema,file_name=>"$work/prepared",quotes=>0});$producer->trials([$trial]);$producer->accessions(\@accessions);$producer->traits([$trait_id]);my$selected=$producer->retrieve_phenotypes;ok(@$selected>8,'actual dataset producer prepared a small repeated numeric input');
my$base=$ENV{SGN_TEST_SERVER}||'http://localhost:3010';my$m=Test::WWW::Mechanize->new(timeout=>180);$m->post("$base/ajax/user/login",[username=>'janedoe',password=>'secretpw',goto_url=>'/']);my$session=eval{decode_json($m->content)}||{};ok($m->success&&!$session->{error},'native Ajax session login');$m->post("$base/brapi/v1/token",[username=>'janedoe',password=>'secretpw',grant_type=>'password']);is($m->status,200,'native HTTP fixture login');my$token=eval{decode_json($m->content)->{access_token}};BAIL_OUT('No fixture token')unless$token;$m->add_header(Authorization=>"Bearer $token");
my@responses;
for my$kind(qw(random fixed)){
 my$r=$m->post("$base/ajax/mixedmodels/run",[tempfile=>"static/documents/tempfiles/$tag/prepared_phenotype.txt",engine=>'lme4','dependent_variables[]'=>$trait,'fixed_factors[]'=>($kind eq'random'?'replicate':'germplasmName'),'random_factors[]'=>($kind eq'random'?'germplasmName':'replicate')]);
 is($r->code,200,"real HTTP $kind model completes through the native queue")or diag(substr($r->decoded_content,0,3000));my$j=eval{decode_json($r->decoded_content)}||{};ok(!$j->{error},"$kind backend returns a successful model")or diag($j->{error}//'No JSON response');
 my$key=$kind eq'random'?'adjusted_blups_data':'adjusted_blues_data';is(scalar(keys%{$j->{$key}||{}}),8,"$kind HTTP output retains all eight computed genotypes");
 ok($j->{input_file}&&-s$j->{input_file},"$kind HTTP response names the actual nonempty training file");push@responses,$j;
}
isnt($responses[0]{input_file},$responses[1]{input_file},'separate real HTTP requests have separate immutable input/output namespaces');
my$rows=$f->people_schema->resultset('SpJob')->search({sp_job_id=>{'>'=>$before},sp_person_id=>41},{order_by=>'sp_job_id'});@owned_jobs=$rows->all;is(scalar@owned_jobs,2,'real HTTP requests created two native job records');for my$job(@owned_jobs){is($job->status,'finished','native job metadata confirms real completion')}
my$dir='/tmp/pr6384-http-native-models';make_path($dir);write_file("$dir/response.json",encode_json({scope=>'Actual HTTP/Catalyst/Job/Tsp/R; no scheduling adapter',trial=>$trial,trait=>$trait,responses=>\@responses,jobs=>[map{{id=>$_->sp_job_id,status=>$_->status}}@owned_jobs]}));
$_->delete for@owned_jobs;@owned_jobs=();done_testing;
