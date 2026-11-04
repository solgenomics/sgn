use strict;
use warnings;
use lib 't/lib';
use Test::More;
use SGN::Test::Fixture;
use SGN::Test::OwnedTrialCleanup;
use SGN::Model::Cvterm;
use CXGN::Trial;
use CXGN::Trial::TrialCreate;
use JSON::XS qw(encode_json decode_json);
use LWP::UserAgent;
use HTTP::Request;
use Text::CSV;
use Digest::MD5 qw(md5_hex);
use File::Temp qw(tempdir);
use File::Copy qw(copy);
use File::Path qw(make_path);
use DateTime;
use CXGN::Phenotypes::ParseUpload;
use CXGN::BrAPI::FileRequest;
use CXGN::Phenotypes::StorePhenotypes;

# One synthetic experiment contains A and untouched B. Files are experiment-
# level history, so a file associated with that experiment does NOT assert that
# it supplied every cell. No application source changes or provenance redesign.
# Committed fixture rows must be visible to the real HTTP server. Clean the
# exact test-owned graph before another test uses the shared fixture.
my $f=SGN::Test::Fixture->new;
my $s=$f->bcs_schema;
my $dbh=$s->storage->dbh;
my $dir=tempdir('sgn-observation-provenance-XXXXXX',TMPDIR=>1,CLEANUP=>0);
my $tag='observation_file_provenance_'.$$.'_'.time();

my $owned = SGN::Test::OwnedTrialCleanup->new(
    schema => $s, label => 'provenance',
    trial_name => $tag.'_trial', stock_names => [$tag.'_plot'],
    %{SGN::Test::OwnedTrialCleanup->cutoffs($s)},
);

my $native=$ENV{AUDIT_NATIVE_PROVENANCE} ? 1 : 0;
my $base=$ENV{SGN_TEST_SERVER} || 'http://localhost:3010';
my $ua=LWP::UserAgent->new(timeout=>45);
my $login=$ua->post("$base/brapi/v1/token",[username=>'janedoe',password=>'secretpw',grant_type=>'password']);
my $token=eval{decode_json($login->decoded_content)->{access_token}};
ok($token,'fixture curator authenticated') or BAIL_OUT('HTTP server/login unavailable; no fixture writes made');
$ua->default_header(Authorization=>"Bearer $token");
sub cv {SGN::Model::Cvterm->get_cvterm_row($s,$_[0],$_[1])->cvterm_id}
my ($trait_a,$trait_b)=(70666,70741);
ok($s->resultset('Cv::Cvterm')->find($trait_a) && $s->resultset('Cv::Cvterm')->find($trait_b),'existing fixture variables are present') or BAIL_OUT('Missing trait precondition');
my $saved=CXGN::Trial::TrialCreate->new({chado_schema=>$s,dbh=>$f->dbh,owner_id=>41,design=>{1=>{stock_name=>'test_accession1',plot_name=>$tag.'_plot',plot_number=>1,block_number=>1,rep_number=>1,row_number=>1,col_number=>1}},program=>'test',trial_year=>'2026',trial_description=>'Disposable existing-observation file provenance regression',trial_location=>'test_location',trial_name=>$tag.'_trial',design_type=>'RCBD',operator=>'janedoe'})->save_trial;
my $trial=$saved->{trial_id};
ok($trial,'own one-plot trial created') or BAIL_OUT(encode_json($saved));
$owned->checkpoint('after_creation');
my $plot=$s->resultset('Stock::Stock')->find({uniquename=>$tag.'_plot'})->stock_id;
my $geo=$dbh->selectrow_array('SELECT ne.nd_geolocation_id FROM nd_experiment ne JOIN nd_experiment_project nep USING(nd_experiment_id) WHERE nep.project_id=? AND ne.type_id=?',undef,$trial,cv('field_layout','experiment_type'));
my $type=cv('phenotyping_experiment','experiment_type');
my $experiment=$s->resultset('NaturalDiversity::NdExperiment')->create({type_id=>$type,nd_geolocation_id=>$geo});
my $existing_experiment=$experiment->nd_experiment_id;
$s->resultset('NaturalDiversity::NdExperimentProject')->create({nd_experiment_id=>$existing_experiment,project_id=>$trial});
$s->resultset('NaturalDiversity::NdExperimentStock')->create({nd_experiment_id=>$existing_experiment,stock_id=>$plot,type_id=>$type});
my %observation;
for my $entry ([A=>$trait_a,'7'],[B=>$trait_b,'8.5']) {
    my ($name,$trait,$value)=@$entry;
    my $p=$s->resultset('Phenotype::Phenotype')->create({uniquename=>$tag.'_'.$name,cvalue_id=>$trait,observable_id=>$trait,value=>$value,operator=>'janedoe',collect_date=>'2026-11-03T08:00:00+00'});
    $observation{$name}=$p->phenotype_id;
    $s->resultset('NaturalDiversity::NdExperimentPhenotype')->create({nd_experiment_id=>$existing_experiment,phenotype_id=>$p->phenotype_id});
}
my $old_path="$dir/original-input.csv";
open(my $fh,'>:raw',$old_path) or die $!;
my $csv=Text::CSV->new({binary=>1,eol=>"\n",always_quote=>1});
$csv->print($fh,[qw(observationDbId observationUnitDbId observationVariableDbId value observationTimeStamp collector)]);
$csv->print($fh,[$observation{A},$plot,$trait_a,'7','2026-11-03T08:00:00Z','janedoe']);
$csv->print($fh,[$observation{B},$plot,$trait_b,'8.5','2026-11-03T08:00:00Z','janedoe']);
close $fh;
sub read_bytes {open(my $h,'<:raw',$_[0])or die$!;local$/;my$x=<$h>;close$h;return$x;}
my $md=$f->metadata_schema->resultset('MdMetadata')->create({create_person_id=>41});
my $old_file=$f->metadata_schema->resultset('MdFiles')->create({metadata_id=>$md->get_column('metadata_id'),basename=>'original-input.csv',dirname=>$dir,filetype=>'brapi observations',md5checksum=>md5_hex(read_bytes($old_path))});
my $old_file_id=$old_file->file_id;
$f->phenome_schema->resultset('NdExperimentMdFiles')->create({nd_experiment_id=>$existing_experiment,file_id=>$old_file_id});
my $project=CXGN::Trial->new({bcs_schema=>$s,trial_id=>$trial,metadata_schema=>$f->metadata_schema,phenome_schema=>$f->phenome_schema});
my $visible=sub {return {map {$_->[0]=>1} @{$project->get_phenotype_metadata}};};
ok($visible->()->{$old_file_id},'original two-cell input is visible in the owning project file-history method');
my $before_max=$dbh->selectrow_array('SELECT COALESCE(max(file_id),0) FROM metadata.md_files');
my $payload={observationDbId=>"$observation{A}",observationUnitDbId=>"$plot",observationVariableDbId=>"$trait_a",value=>'9',observationTimeStamp=>'2026-11-03T09:00:00Z',collector=>'janedoe'};
my ($status_code,$json);
if ($native) {
    # Execute the owning modules and normal validation/storage directly. This
    # deliberately excludes the HTTP authorization name/ID bridge, and is not
    # reported as an HTTP PUT acceptance result.
    make_path("$dir/native-temp","$dir/native-archive");
    my $parser=CXGN::Phenotypes::ParseUpload->new;
    my $validated=$parser->validate('brapi observations',[$payload],1,'stocks',$s,undef,undef);
    BAIL_OUT('Native parser validation precondition failed: '.encode_json($validated)) if !$validated || $validated->{error};
    my $parsed=$parser->parse('brapi observations',[$payload],1,'stocks',$s,undef,'janedoe',undef,undef);
    BAIL_OUT('Native parser precondition failed: '.encode_json($parsed)) if !$parsed || $parsed->{error};
    my $archive=CXGN::BrAPI::FileRequest->new({schema=>$s,user_id=>41,user_type=>'curator',format=>'observations',data=>[$payload],tempfiles_subdir=>"$dir/native-temp",archive_path=>"$dir/native-archive"})->get_path;
    BAIL_OUT('Native archive precondition failed') if $archive->{error_message} || !$archive->{archived_filename_with_path};
    my $now=DateTime->now;
    my $store=CXGN::Phenotypes::StorePhenotypes->new(
        (map {$_=>$f->config->{$_}} qw(basepath dbhost dbname dbuser dbpass)),
        temp_file_nd_experiment_id=>"$dir/delete-ids",bcs_schema=>$s,metadata_schema=>$f->metadata_schema,phenome_schema=>$f->phenome_schema,user_id=>41,
        stock_list=>$parsed->{units},trait_list=>$parsed->{variables},values_hash=>$parsed->{data},has_timestamps=>1,overwrite_values=>1,
        metadata_hash=>{archived_file=>$archive->{archived_filename_with_path},archived_file_type=>'brapi observations',operator=>'janedoe',date=>$now->ymd().'_'.$now->hms()},
        composable_validation_check_name=>$f->config->{composable_validation_check_name},allow_repeat_measures=>$f->config->{allow_repeat_measures},
    );
    my ($warning,$verification_error)=$store->verify;
    BAIL_OUT("Native storage verification failed: $verification_error") if $verification_error;
    my ($error,$success,$details)=$store->store;
    $status_code=$error ? 500 : 200;
    $json={execution_mode=>'native owning modules, not routed HTTP',metadata=>{status=>[$error ? {messageType=>'ERROR',message=>"$error"} : {messageType=>'INFO',message=>$success}]},result=>{data=>$details}};
} else {
    my $request=HTTP::Request->new(PUT=>"$base/brapi/v2/observations/$observation{A}");
    $request->header('Content-Type'=>'application/json');$request->content(encode_json($payload));
    my $response=$ua->request($request);
    $status_code=$response->code;
    $json=eval{decode_json($response->decoded_content)} || {};
    diag('HTTP response: '.encode_json($json));
}
$owned->checkpoint('after_http_store');
is($status_code,200,$native ? 'owning parse/archive/store pipeline accepted the existing-ID request' : 'real existing-ID PUT accepted');
ok(!(grep {($_->{messageType}//'') eq 'ERROR'} @{$json->{metadata}{status}||[]}), 'API response has no ERROR status');
my $a=$s->resultset('Phenotype::Phenotype')->find($observation{A});
my $b=$s->resultset('Phenotype::Phenotype')->find($observation{B});
is($a->value,'9','A updated in PostgreSQL');
is($b->value,'8.5','unrelated B retained');
my $phenotype_experiments=$dbh->selectcol_arrayref('SELECT nd_experiment_id FROM nd_experiment_phenotype WHERE phenotype_id=? ORDER BY nd_experiment_id',undef,$observation{A});
is_deeply($phenotype_experiments,[$existing_experiment],'A retains its actual existing experiment');
is_deeply($dbh->selectcol_arrayref('SELECT nd_experiment_id FROM nd_experiment_phenotype WHERE phenotype_id=? ORDER BY nd_experiment_id',undef,$observation{B}),[$existing_experiment],'B retains its original experiment');
my $new_files=$dbh->selectall_arrayref("SELECT f.file_id,f.basename,f.dirname,f.md5checksum,m.obsolete FROM metadata.md_files f JOIN metadata.md_metadata m USING(metadata_id) WHERE f.file_id>? AND f.filetype='brapi observations' ORDER BY f.file_id",{Slice=>{}},$before_max);
is(scalar(@$new_files),1,'one new archived API input registered') or BAIL_OUT('Cannot identify the one request archive; keep fixture for inspection');
my $new_file=$new_files->[0];
my $new_path=$new_file->{dirname}.'/'.$new_file->{basename};
my $new_bytes=read_bytes($new_path);
copy($new_path,"$dir/actual-put-input.csv") or die $!;
is(md5_hex($new_bytes),$new_file->{md5checksum},'new file metadata checksum names the actual archived request');
open($fh,'<:raw',$new_path) or die$!;
my $reader=Text::CSV->new({binary=>1});
my $header=$reader->getline($fh) or die 'Archived request has no CSV header';
my $input=$reader->getline($fh) or die 'Archived request has no observation record';
my %column=map {$header->[$_]=>$_} 0..$#$header;
is($input->[$column{observationDbId}],"$observation{A}",'archived input actually addresses A');
is($input->[$column{value}],'9','archived input contains the new value');
close $fh;
my $links=$dbh->selectall_arrayref('SELECT f.nd_experiment_id,array_agg(p.phenotype_id ORDER BY p.phenotype_id) FILTER(WHERE p.phenotype_id IS NOT NULL) AS phenotype_ids FROM phenome.nd_experiment_md_files f LEFT JOIN nd_experiment_phenotype p USING(nd_experiment_id) WHERE f.file_id=? GROUP BY f.nd_experiment_id ORDER BY f.nd_experiment_id',{Slice=>{}},$new_file->{file_id});
my %linked=map {$_->{nd_experiment_id}=>1} @$links;
ok($linked{$existing_experiment},'new request file is associated with the experiment that actually owns updated A');
ok($visible->()->{$new_file->{file_id}},'new input appears in the owning project phenotype file history');
ok($visible->()->{$old_file_id},'old input remains visible because experiment-level history still contains untouched B');
my ($old_active)=$dbh->selectrow_array('SELECT m.obsolete=0 FROM metadata.md_files f JOIN metadata.md_metadata m USING(metadata_id) WHERE f.file_id=?',undef,$old_file_id);
ok($old_active,'the shared old input is not blanket-obsoleted after updating only A');
my $report={scope=>'One existing-ID update; files are per-experiment many-file history, not authoritative per-cell ownership',execution_mode=>$native ? 'native ParseUpload/FileRequest/StorePhenotypes; HTTP auth bridge excluded' : 'real HTTP PUT',trial_id=>$trial,plot_id=>$plot,observation_ids=>\%observation,actual_observation_experiments=>$phenotype_experiments,old_file_id=>$old_file_id,new_file=>$new_file,new_file_links=>$links,request_status=>$status_code,response=>$json,own_temp_archive=>$dir,server_archive=>$new_path,retained_for_owned_volume_teardown=>0};
open($fh,'>:raw',"$dir/provenance.json") or die$!;print $fh encode_json($report);close$fh;
diag(encode_json($report));
diag('Own synthetic archive evidence retained at '.$dir.'; API used its normal configured archive without configuration changes.');
$owned->checkpoint('before_cleanup');
ok($owned->cleanup, 'test-owned committed observation data removed');
done_testing;
