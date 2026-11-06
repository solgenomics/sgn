use strict;
use warnings;
use utf8;
use lib 't/lib';
use Test::More;
use Test::WWW::Mechanize;
use JSON;
use File::Path qw(make_path);
use File::Spec;
use Spreadsheet::WriteExcel;
use SGN::Test::Fixture;
use SGN::Model::Cvterm;
use CXGN::Stock;
use CXGN::Stock::Accession;
use CXGN::Pedigree::AddGrafts;

my $f=SGN::Test::Fixture->new;
my $s=$f->bcs_schema;
my $seed=$s->resultset('Stock::Stock')->find({uniquename=>'test_accession1'});
my %type=map{$_=>SGN::Model::Cvterm->get_cvterm_row($s,$_,'stock_type')->cvterm_id}qw(accession cross population);
my %role=map{$_=>SGN::Model::Cvterm->get_cvterm_row($s,$_.'_parent','stock_relationship')->cvterm_id}qw(female male);
my @made;
sub row {
    my($name,$kind,$exact)=@_;
    my$r=$s->resultset('Stock::Stock')->create({name=>$exact//'protocol_'.$name,uniquename=>$exact//'protocol_'.$name,
        organism_id=>$seed->organism_id,type_id=>$type{$kind||'accession'}});
    push @made,$r;return$r;
}
sub model {CXGN::Stock->new(schema=>$s,stock_id=>$_[0]->stock_id)}
sub snapshot {
    return [map{[$_->type_id,$_->subject_id,$_->value]}$s->resultset('Stock::StockRelationship')->search({
        object_id=>$_[0]->stock_id,type_id=>{-in=>[values%role]}},{order_by=>'type_id'})->all];
}
my$mech=Test::WWW::Mechanize->new(timeout=>20);
$mech->post_ok('http://localhost:3010/brapi/v1/token',[username=>'janedoe',password=>'secretpw',grant_type=>'password']);
sub post {
    my($path,$params)=@_;
    $mech->post('http://localhost:3010'.$path,$params);
    return eval{decode_json($mech->content)}||{http_status=>$mech->status};
}
my($mother,$father)=map{row($_)}qw(mother father);

subtest 'request validation rejects malformed data without writes' => sub {
    for my $json ('null','[]','{}','{"pedigrees":{}}','{"pedigrees":[]}',
        '{"pedigrees":[{"progeny name":[],"female parent accession":"x","type":"open"}]}') {
        ok(post('/ajax/pedigrees/upload_store',[pedigree_data=>$json,overwrite_pedigrees=>'false'])->{error},'malformed pedigree JSON returns an error object');
    }
    $mech->get('http://localhost:3010/ajax/pedigrees/upload_store');
    like(decode_json($mech->content)->{error},qr/POST/,'GET cannot mutate pedigree data');
    my$c=row('false_flags');
    model($c)->add_parents($mother->uniquename,$father->uniquename,'biparental');
    my$before=snapshot($c);
    for my$flag(qw(false FALSE 0 off no)) {
        my$other=row('other_'.$flag);
        my$payload={pedigrees=>[{'progeny name'=>$c->uniquename,'female parent accession'=>$other->uniquename,
            'male parent accession'=>$father->uniquename,type=>'biparental'}]};
        ok(post('/ajax/pedigrees/upload_store',[pedigree_data=>encode_json($payload),overwrite_pedigrees=>$flag])->{error},"$flag cannot replace an existing mother");
        is_deeply(snapshot($c),$before,'saved pair is unchanged');
    }
};

subtest 'IDs disambiguate names and preserve renamed stored parents' => sub {
    my$name='protocol_shared_parent';
    my$m=row('shared_mother','accession',$name);
    my$p=row('shared_population','population',$name);
    $mech->get_ok('http://localhost:3010/ajax/stock/pedigree_parent_autocomplete?parent_type=male&term=protocol_shared_parent');
    my$matches=decode_json($mech->content);
    is(scalar(grep{$_->{value}eq$name}@$matches),2,'male suggestions retain both same-label identities');
    ok(grep({$_->{id}==$p->stock_id&&$_->{label}=~/population/}@$matches),'population suggestion identifies its type');
    $mech->get_ok('http://localhost:3010/ajax/stock/pedigree_parent_autocomplete?parent_type=female&term=protocol_shared_parent');
    is(scalar(@{decode_json($mech->content)}),1,'female suggestions exclude a population with the same label');
    my$c=row('ids');
    is_deeply(post('/ajax/stock/add_stock_parents',[stock_id=>$c->stock_id,female_parent=>$name,male_parent=>$name,
        cross_type=>'biparental',female_parent_id=>$m->stock_id,male_parent_id=>$p->stock_id]),{success=>1},'different selected IDs disambiguate identical labels');
    $m->update({uniquename=>'protocol_renamed_mother',name=>'protocol_renamed_mother'});
    is_deeply(post('/ajax/stock/add_stock_parents',[stock_id=>$c->stock_id,female_parent=>$name,male_parent=>$name,
        cross_type=>'biparental',female_parent_id=>$m->stock_id,male_parent_id=>$p->stock_id]),{success=>1},'recorded identity survives a renamed readonly label');
    my$st=SGN::Model::Cvterm->get_cvterm_row($s,'stock_synonym','stock_property')->cvterm_id;
    $s->resultset('Stock::Stockprop')->create({stock_id=>$m->stock_id,type_id=>$st,value=>'protocol_mother_alias'});
    my$selfed=row('self_alias');
    is_deeply(post('/ajax/stock/add_stock_parents',[stock_id=>$selfed->stock_id,female_parent=>$m->uniquename,
        male_parent=>'protocol_mother_alias',cross_type=>'self',female_parent_id=>$m->stock_id,male_parent_id=>$m->stock_id]),{success=>1},'self validates resolved identity rather than label spelling');
};

subtest 'numeric zero remains a valid recorded parent name' => sub {
    my$zero=$s->resultset('Stock::Stock')->find({uniquename=>'0',type_id=>$type{accession},organism_id=>$seed->organism_id});
    $zero=row('numeric','accession','0') unless$zero;
    is(CXGN::Stock->new(schema=>$s,uniquename=>'0')->stock_id,$zero->stock_id,'stock lookup by zero name is not treated as missing');
    my$c=row('numeric_import');
    my$payload={pedigrees=>[{'progeny name'=>$c->uniquename,'female parent accession'=>$mother->uniquename,
        'male parent accession'=>'0',type=>'biparental'}]};
    is_deeply(post('/ajax/pedigrees/upload_store',[pedigree_data=>encode_json($payload),overwrite_pedigrees=>'false']),{success=>1},'import retains male label zero');
    is($s->resultset('Stock::StockRelationship')->find({object_id=>$c->stock_id,type_id=>$role{male}})->subject_id,$zero->stock_id,'zero resolved to the intended parent');
    my$b=row('numeric_brapi_model');
    my$a=CXGN::Stock::Accession->new(schema=>$s,stock_id=>$b->stock_id,mother_accession=>'0',
        father_accession=>$father->uniquename,main_production_site_url=>'http://localhost:3010');
    is($a->store,$b->stock_id,'BrAPI accession model retains a zero-named mother');
    is($s->resultset('Stock::StockRelationship')->find({object_id=>$b->stock_id,type_id=>$role{female}})->subject_id,$zero->stock_id,'mother zero is stored');
    like(model($b)->get_pedigree_string('Parents'),qr{^0/},'pedigree string displays zero rather than NA');
};

my$archive=File::Spec->catdir($f->config->{archive_path},'cross_upload');
make_path($archive);
my$source=$s->resultset('Stock::Stock')->search({type_id=>$type{cross}})->first;
my$alias='protocol_cross_alias';
my$st=SGN::Model::Cvterm->get_cvterm_row($s,'stock_synonym','stock_property')->cvterm_id;
my$alias_row=$s->resultset('Stock::Stockprop')->create({stock_id=>$source->stock_id,type_id=>$st,value=>$alias});
my@files;
sub workbook {
    my($name,$child,$cross)=@_;
    my$file=File::Spec->catfile($archive,$name.'.xls');push@files,$file;
    my$book=Spreadsheet::WriteExcel->new($file);my$sheet=$book->add_worksheet;
    $sheet->write_row(0,0,['cross_unique_id','progeny_name']);
    $sheet->write_row(1,0,[$cross||$source->uniquename,$child->uniquename]);$book->close;return$file;
}
subtest 'cross upload authorization and metadata share one transaction' => sub {
    my$child=row('cross_upload');
    my$file=workbook('protocol_cross_good',$child,$alias);
    my$anon=Test::WWW::Mechanize->new;
    $anon->post('http://localhost:3010/ajax/cross/store_upload_existing_progenies',[archived_file_name=>$file,user_id=>41,overwrite_pedigrees=>'true']);
    ok(decode_json($anon->content)->{error},'anonymous cross upload cannot use a forged user ID');
    is(scalar(@{snapshot($child)}),0,'anonymous request stores no parental links');
    $mech->get('http://localhost:3010/ajax/cross/store_upload_existing_progenies?archived_file_name='.$file);
    like(decode_json($mech->content)->{error},qr/POST/,'cross upload rejects GET');
    ok(post('/ajax/cross/store_upload_existing_progenies',[archived_file_name=>'/etc/passwd',overwrite_pedigrees=>'true'])->{error},'store cannot open a file outside the verified archive');
    is_deeply(post('/ajax/cross/store_upload_existing_progenies',[archived_file_name=>$file,user_id=>40,overwrite_pedigrees=>'true']),{success=>1},'cross synonym stores both pedigree and file log');
    my$mdfile=$f->metadata_schema->resultset('MdFiles')->search({basename=>'protocol_cross_good.xls'},{order_by=>{-desc=>'file_id'}})->first;
    ok($mdfile,'file log exists');
    is($f->metadata_schema->resultset('MdMetadata')->find($mdfile->get_column('metadata_id'))->create_person_id,41,'actual session is the author, not client user_id');
    ok($f->phenome_schema->resultset('NdExperimentMdFiles')->search({file_id=>$mdfile->file_id})->count,'canonical cross ID resolves its experiment');

    my$target=row('cross_rollback');
    model($target)->add_parents($mother->uniquename,$father->uniquename,'biparental');
    my$before=snapshot($target);
    my$bad=workbook('protocol_cross_fail',$target);
    my$dbh=$s->storage->dbh;
    $dbh->do(q{CREATE FUNCTION public.parentage_metadata_failure() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN
        IF EXISTS(SELECT 1 FROM metadata.md_files WHERE file_id=NEW.file_id AND basename='protocol_cross_fail.xls') THEN
            RAISE EXCEPTION 'test metadata failure'; END IF; RETURN NEW; END $$});
    $dbh->do(q{CREATE TRIGGER parentage_metadata_failure BEFORE INSERT ON phenome.nd_experiment_md_files FOR EACH ROW EXECUTE PROCEDURE public.parentage_metadata_failure()});
    my$result=post('/ajax/cross/store_upload_existing_progenies',[archived_file_name=>$bad,overwrite_pedigrees=>'true']);
    $dbh->do('DROP TRIGGER parentage_metadata_failure ON phenome.nd_experiment_md_files');
    $dbh->do('DROP FUNCTION public.parentage_metadata_failure()');
    ok($result->{error},'metadata failure is a failed upload');
    is_deeply(snapshot($target),$before,'parent changes rolled back with metadata failure');
    is($f->metadata_schema->resultset('MdFiles')->search({basename=>'protocol_cross_fail.xls'})->count,0,'failed upload left no file log');
    my$left=row('two_cross_labels_left');
    my$right=row('two_cross_labels_right');
    my$two=File::Spec->catfile($archive,'protocol_two_cross_labels.xls');push@files,$two;
    my$book=Spreadsheet::WriteExcel->new($two);my$sheet=$book->add_worksheet;
    $sheet->write_row(0,0,['cross_unique_id','progeny_name']);
    $sheet->write_row(1,0,[$source->uniquename,$left->uniquename]);
    $sheet->write_row(2,0,[$alias,$right->uniquename]);$book->close;
    my$two_result=post('/ajax/cross/store_upload_existing_progenies',[archived_file_name=>$two,overwrite_pedigrees=>'true']);
    is_deeply($two_result,{success=>1},'two labels for one cross are one canonical group') or diag($two_result->{error}//$two_result->{http_status}//'no result');
    my$two_log=$f->metadata_schema->resultset('MdFiles')->search({basename=>'protocol_two_cross_labels.xls'},{order_by=>{-desc=>'file_id'}})->first;
    ok($two_log,'two-label file log exists');
    is($f->phenome_schema->resultset('NdExperimentMdFiles')->search({file_id=>$two_log->file_id})->count,1,'one file/cross journal link despite the alias') if$two_log;
    my$retry=workbook('protocol_cross_retry',$target);
    is_deeply(post('/ajax/cross/store_upload_existing_progenies',[archived_file_name=>$retry,overwrite_pedigrees=>'true']),{success=>1},'a later upload still works after rollback');
};

subtest 'legacy graph reads terminate without rewriting historical cycles' => sub {
    my$c=row('legacy_cycle');
    $s->resultset('Stock::StockRelationship')->create({object_id=>$c->stock_id,subject_id=>$c->stock_id,type_id=>$role{female},value=>'self'});
    $mech->get_ok('http://localhost:3010/ajax/pedigrees/get_full?stock_id='.$c->stock_id);
    is(scalar(@{decode_json($mech->content)}),1,'visited IDs bound the legacy cycle read');
    is($s->resultset('Stock::StockRelationship')->search({object_id=>$c->stock_id})->count,1,'reading did not repair or delete history');
    $mech->get('http://localhost:3010/ajax/pedigrees/get_full?stock_id=missing');
    ok(decode_json($mech->content)->{error},'invalid graph ID returns a domain error');
};

subtest 'legacy cross generator uses the common transaction boundary' => sub {
    my$name='protocol_legacy_cross';
    $mech->post('http://localhost:3010/stock/cross/generate',[cross_name=>$name,maternal=>$mother->uniquename,
        paternal=>$father->uniquename,prefix=>'P',suffix=>'',progeny_number=>2,visible_to_role=>'']);
    my@children=$s->resultset('Stock::Stock')->search({uniquename=>{-in=>['P'.$name.'-1','P'.$name.'-2']}})->all;
    is(scalar(@children),2,'legacy generator creates the requested complete batch');
    for my$child(@children) {
        push@made,$child;
        is($child->organism_id,$mother->organism_id,'legacy child inherits recorded maternal organism');
        is(scalar(@{snapshot($child)}),2,'legacy child has both parent roles');
    }
};

subtest 'a graft-name collision cannot append a different composition' => sub {
    my@parts=map{row($_,'accession',$_)}qw(protocol_graft_A+B protocol_graft_C protocol_graft_A B+protocol_graft_C);
    my$first=CXGN::Pedigree::AddGrafts->new(schema=>$s,scion=>$parts[0]->uniquename,rootstock=>$parts[1]->uniquename)->add_grafts;
    ok(!$first->{errors}{error},'first graft composition is stored');
    my$graft=$s->resultset('Stock::Stock')->find({uniquename=>'protocol_graft_A+B+protocol_graft_C'});
    return unless$graft;push@made,$graft;
    my$count=$s->resultset('Stock::StockRelationship')->search({object_id=>$graft->stock_id})->count;
    my$second=CXGN::Pedigree::AddGrafts->new(schema=>$s,scion=>$parts[2]->uniquename,rootstock=>$parts[3]->uniquename)->add_grafts;
    ok($second->{errors}{error},'colliding name is an error');
    is($s->resultset('Stock::StockRelationship')->search({object_id=>$graft->stock_id})->count,$count,'existing scion and rootstock are unchanged');
};

subtest 'native cross API propagates model rollbacks' => sub {
    my$trial_name='protocol_failure_trial';
    my$trial_result=post('/ajax/cross/add_crossingtrial',[crossingtrial_name=>$trial_name,crossingtrial_program_id=>134,
        crossingtrial_location=>'test_location',year=>2025,project_description=>'Parentage API failure regression']);
    ok($trial_result->{success},'create an owned crossing trial');
    my$trial=$s->resultset('Project::Project')->find({name=>$trial_name});
    return unless$trial;
    my@common=(crossing_trial_id=>$trial->project_id,cross_type=>'biparental',maternal=>$mother->uniquename,
        paternal=>$father->uniquename,prefix=>'P',suffix=>'');
    my$dbh=$s->storage->dbh;
    $dbh->do(q{CREATE FUNCTION public.parentage_cross_failure() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN
        IF NEW.uniquename IN('protocol_reject_cross','protocol_reject_progenyP001') THEN
            RAISE EXCEPTION 'test cross/progeny insert failure'; END IF; RETURN NEW; END $$});
    $dbh->do(q{CREATE TRIGGER parentage_cross_failure BEFORE INSERT ON stock FOR EACH ROW EXECUTE PROCEDURE public.parentage_cross_failure()});
    my$cross_error=post('/ajax/cross/add_cross',[cross_name=>'protocol_reject_cross',@common]);
    my$progeny_error=post('/ajax/cross/add_cross',[cross_name=>'protocol_reject_progeny',progeny_number=>1,@common]);
    $dbh->do('DROP TRIGGER parentage_cross_failure ON stock');
    $dbh->do('DROP FUNCTION public.parentage_cross_failure()');
    like($cross_error->{error}//'',qr/cross could not be created/,'failed cross factory is not API success');
    is($s->resultset('Stock::Stock')->search({uniquename=>'protocol_reject_cross'})->count,0,'failed cross did not persist');
    like($progeny_error->{error}//'',qr/progenies could not be added/,'failed progeny factory is not API success');
    is($s->resultset('Stock::Stock')->search({uniquename=>'protocol_reject_progenyP001'})->count,0,'failed progeny did not persist');
    ok($s->resultset('Stock::Stock')->find({uniquename=>'protocol_reject_progeny'}),'explicit partial-result message corresponds to a saved cross');
    like(post('/ajax/cross/add_cross',[cross_name=>'protocol_fractional',progeny_number=>'1.5',@common])->{error}//'',
        qr/progeny number/,'fractional counts reject before writing');
    my@invalid=@common;
    for(my$i=0;$i<@invalid;$i+=2){$invalid[$i+1]='not_a_cross_type'if$invalid[$i]eq'cross_type'}
    like(post('/ajax/cross/add_cross',[cross_name=>'protocol_invalid_type',@invalid])->{error}//'',
        qr/Unsupported cross type/,'invalid type is a domain error rather than a constructor crash');
};

$alias_row->delete;
my@ids=map{$_->stock_id}@made;
$f->phenome_schema->resultset('StockOwner')->search({stock_id=>{-in=>\@ids}})->delete;
$s->resultset('Stock::StockRelationship')->search({-or=>[object_id=>{-in=>\@ids},subject_id=>{-in=>\@ids}]})->delete;
$_->delete for reverse@made;
unlink@files;
$f->clean_up_db;
done_testing;
