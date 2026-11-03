use strict;
use warnings;
use lib 't/lib';
use Test::More;
use File::Temp;
use File::Path qw(make_path);
use File::Slurp qw(read_file);
use Encode qw(decode_utf8);
use JSON qw(encode_json);
use HTTP::Response;
use Text::CSV;
use SGN::Test::Fixture;
use SGN::Model::Cvterm;
use CXGN::Trial;
use CXGN::Trial::TrialCreate;
use CXGN::Trial::TrialLayout;
use CXGN::Trial::DesignReplication;
use SGN::Controller::AJAX::TrialMetadata;
use SGN::Controller::AJAX::CrossWishlist;
use SGN::Controller::StockBarcode;
use SGN::Controller::Barcode;

# Actual owning controllers, native field ordering, barcode images/PDFs and
# CrossWishlist files. The Catalyst context supplies request/response plumbing.
# ONA transport is an explicit local fixture: no network and no ONA acceptance.
my$f=SGN::Test::Fixture->new;my$s=$f->bcs_schema;my$dbh=$s->storage->dbh;
$s->storage->auto_savepoint(1);
my$dir=$ENV{AUDIT_LABEL_ORDER_ARTIFACTS} || File::Temp::tempdir(CLEANUP=>1);
$dir.='/run_'.$$ if $ENV{AUDIT_LABEL_ORDER_ARTIFACTS};
make_path($dir);
my$prefix='audit_rep_label_order_'.$$;
my$metadata=CXGN::Metadata::Schema->connect(sub{$dbh});
my$phenome=CXGN::Phenome::Schema->connect(sub{$dbh});
for my$entry([$metadata,'metadata'],[$phenome,'phenome']){
    my($schema,$namespace)=@$entry;
    for my$name($schema->sources){my$source=$schema->source($name);my$table=$source->name;die"Unexpected source $name"if ref($table)||$table!~/^[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)?$/;$source->name("$namespace.$table")if$table!~/\./;}
    $schema->storage->dbh;
}
{
    package RepLabelReq;
    sub param {$_[0]{params}{$_[1]}}
    sub upload {undef}
    package RepLabelResponse;
    sub content_type {$_[0]{content_type}=$_[1] if@_>1;$_[0]{content_type}}
    sub body {$_[0]{body}=$_[1] if@_>1;$_[0]{body}}
    sub headers {$_[0]}
    sub push_header {$_[0]{$_[1]}=$_[2]}
    package RepLabelDbc;
    sub dbh {$_[0]{dbh}}
    package RepLabelUser;
    sub get_object {$_[0]{object}}
    package RepLabelContext;
    sub req {$_[0]{req}}
    sub res {$_[0]{res}}
    sub stash {$_[0]{stash}}
    sub config {$_[0]{config}}
    sub dbc {$_[0]{dbc}}
    sub user {$_[0]{user}}
    sub dbic_schema {$_[0]{schemas}{$_[1]} || die"Unsupported schema $_[1]"}
    sub path_to {$_[1]}
    sub tempfiles_subdir {my($self,$subdir)=@_;File::Path::make_path("$self->{dir}/$subdir");return"$self->{dir}/$subdir"}
    sub tempfile {
        my($self,%args)=@_;my$template=$args{TEMPLATE};$template=join('/',@$template)if ref($template)eq'ARRAY';
        my$file=File::Temp->new(TEMPLATE=>"$self->{dir}/$template",SUFFIX=>$args{SUFFIX}//'',UNLINK=>0);
        push@{$self->{files}},$file;return($file,$file->filename);
    }
    sub forward {
        my($self,$path,$args)=@_;
        push@{$self->{forwards}},{path=>$path,args=>[@$args]};
        my%method=('/barcode/barcode_tempfile_jpg'=>'barcode_tempfile_jpg','/barcode/phenotyping_qrcode_jpg'=>'phenotyping_qrcode_jpg','/barcode/barcode_qrcode_jpg'=>'barcode_qrcode_jpg');
        my$method=$method{$path}or die"Unqualified barcode route $path";
        return SGN::Controller::Barcode->new->$method($self,@$args);
    }
    sub detach {die"REPLICATION_LABEL_DETACHED\n"}
    package RepLabelTransport;
    sub credentials {1}
    sub get {
        my($self,$url)=@_;push@{$self->{calls}},$url;
        return HTTP::Response->new(200,'OK',['Content-Type'=>'application/json'],'{"temp_token":"local-no-network-fixture"}')if$url eq'https://api.ona.io/api/v1/user.json';
        return HTTP::Response->new(200,'OK',['Content-Type'=>'application/json'],'[]')if$url=~m{^https://api\.ona\.io/api/v1/(?:metadata\?xform=0|data/0)$};
        die"Unexpected external request $url";
    }
    sub post {die'Unexpected external POST'}
    sub delete {die'Unexpected external DELETE'}
}
my$config={%{$f->config},project_name=>$prefix,identifier_prefix=>'AUDIT:',archive_path=>"$dir/archive",main_production_site_url=>'https://example.invalid',odk_crossing_data_service_name=>'NULL',odk_crossing_data_test_form_name=>'local-unused-form',odk_crossing_data_separate_wishlist_by_location=>0,odk_crossing_data_service_username=>'local-fixture',odk_crossing_data_service_password=>'local-fixture'};
# The fixture's generic Catalyst::Authentication::User does not implement the
# application's get_object adapter. Wrap the actual committed fixture account.
my$person=CXGN::People::Person->new($f->dbh,41);
my$user=bless{object=>$person},'RepLabelUser';
is($person->get_sp_person_id,41,'authenticated native harness resolves the real fixture account');
is($person->get_username,'janedoe','authenticated native harness has the actual fixture username');
ok(defined($person->get_user_type),'authenticated native harness has the actual fixture user role');
sub context {
    my($params)=@_;
    return bless{req=>bless({params=>$params},'RepLabelReq'),res=>bless({},'RepLabelResponse'),stash=>{},config=>$config,user=>$user,dbc=>bless({dbh=>$dbh},'RepLabelDbc'),dir=>$dir,files=>[],forwards=>[],schemas=>{'Bio::Chado::Schema'=>$s,'CXGN::Metadata::Schema'=>$metadata,'CXGN::Phenome::Schema'=>$phenome,'CXGN::People::Schema'=>$f->people_schema}},'RepLabelContext';
}
sub scenario {
    my($name,$body)=@_;
    return if $ENV{AUDIT_LABEL_ORDER_CASE} && index($name,$ENV{AUDIT_LABEL_ORDER_CASE})<0;
    subtest($name=>$body);
}
sub term {SGN::Model::Cvterm->get_cvterm_row($s,@_)->cvterm_id}
sub ensure_term {
    my($name,$cv,$template_name)=@_;return if$s->resultset('Cv::Cvterm')->search({'me.name'=>$name,'cv.name'=>$cv},{join=>'cv'})->count;
    my$template=SGN::Model::Cvterm->get_cvterm_row($s,$template_name,$cv);my$xref=$s->resultset('General::Dbxref')->create({db_id=>$template->dbxref->db_id,accession=>$prefix.'_'.$name});
    $s->resultset('Cv::Cvterm')->create({name=>$name,cv_id=>$template->cv_id,dbxref_id=>$xref->dbxref_id});
}
sub csv_rows {
    my($text)=@_;open(my$in,'<',\$text)or die$!;my$csv=Text::CSV->new({binary=>1});my$header=$csv->getline($in)or die'Actual CSV header cannot be parsed';my@rows;
    while(my$row=$csv->getline($in)){push@rows,$row}die'Actual CSV contains a malformed record: '.$csv->error_diag if!$csv->eof;close$in;
    return($header,\@rows);
}
sub pdf_file {
    my($c,$label)=@_;my$path=$c->stash->{file};ok(defined($path)&&-s$path,"$label actual PDF exists");return if!$path||!-s$path;
    my$bytes=read_file($path,binmode=>':raw');like($bytes,qr/^%PDF-/,"$label has an actual PDF header");like($bytes,qr/%%EOF\s*$/,"$label PDF closes completely");diag("$label artifact: $path");
}
my($trial,@plots,@accessions,@artifact_ids);
my@tags=('0','01','group, "A"',undef);
my$tx=0;END{eval{$s->txn_rollback if$tx}if$s}
$s->txn_begin;$tx=1;
my$ran=eval{
    ensure_term('design_replicate','stock_property','replicate');ensure_term('accession_occurrence_version','project_property','design');
    my$template=$s->resultset('Stock::Stock')->find({uniquename=>'test_accession1'});
    for my$i(1,2){push@accessions,$s->resultset('Stock::Stock')->create({name=>"${prefix}_accession_$i",uniquename=>"${prefix}_accession_$i",type_id=>$template->type_id,organism_id=>$template->organism_id})}
    my%design=map{my$i=$_;($i=>{plot_name=>"${prefix}_plot_$i",stock_name=>$accessions[($i-1)%2]->uniquename,plot_number=>$i,rep_number=>$tags[$i-1],block_number=>1,row_number=>1,col_number=>$i})}1..4;
    my$created=CXGN::Trial::TrialCreate->new({chado_schema=>$s,dbh=>$dbh,owner_id=>41,operator=>'janedoe',program=>'test',trial_location=>'test_location',trial_name=>$prefix,trial_description=>'Rollback-only actual physical-label and ordered-file fixture',trial_year=>2031,design_type=>'RCBD',design=>\%design})->save_trial;
    $trial=$created->{trial_id};die encode_json($created)if!$trial;
    @plots=map{$s->resultset('Stock::Stock')->find({uniquename=>"${prefix}_plot_$_"})}1..4;
    scenario 'Actual native ordered plots keep physical tags and separate counters'=>sub{
        my$r=CXGN::Trial->get_sorted_plots($s,[$trial],'by_row_zigzag','bottom_left');ok(!$r->{error},'native ordering succeeds')or die$r->{error};
        my%by_name=map{$_->{plot_name}=>$_}grep{$_->{type}eq'plot'}@{$r->{plots}};
        for my$i(0..$#plots){my$p=$by_name{$plots[$i]->uniquename};is($p->{rep_number},$tags[$i],'ordered public replica is recorded physical tag');is($p->{design_rep_number},$tags[$i],'explicit physical alias agrees');is($p->{accession_occurrence},int($i/2)+1,'native ordered counter remains accession occurrence')}
    };
    scenario 'Actual order controller returns parsable physical tags in all four CSV formats'=>sub{
        for my$type(qw(planting collection harvest harvestmaster)){
            my$c=context({trial_ids=>"$trial",type=>$type,order=>'by_row_zigzag',start=>'bottom_left'});
            SGN::Controller::AJAX::TrialMetadata->new->get_trial_plot_order($c);
            ok(!$c->stash->{rest}{error},"$type controller succeeds")or die$c->stash->{rest}{error};
            my($header,$rows)=csv_rows(decode_utf8($c->res->body));my%column=map{$header->[$_]=>$_}0..$#$header;my%by_name=map{$_->[$column{plot_name}]=>$_}@$rows;
            for my$i(0..$#plots){is($by_name{$plots[$i]->uniquename}[$column{rep_number}],$tags[$i],"$type actual replica cell retains tag")if defined($tags[$i]);}
            is($by_name{$plots[3]->uniquename}[$column{rep_number}],'',"$type unknown physical group never falls back to occurrence2");
        }
    };
    scenario 'Real barcode image and PDF generation uses physical plot tags'=>sub{
        my$c=context({stock_names=>join("\n",map{$_->uniquename}@plots),select_barcode_type=>'1D',select_print_format=>'',label_rows=>10,label_cols=>1,page_format=>'letter',tops_margin=>12,left_margin=>10,bottom_margin=>12,right_margin=>10,text_margin=>'',enable_fieldbook_2d_barcode=>''});
        SGN::Controller::StockBarcode->new->download_pdf_labels($c);pdf_file($c,'stock plot labels');
        my%found=map{$_->[1]=>$_} @{$c->stash->{found}};
        for my$i(0..$#plots){my$legend=$found{$plots[$i]->uniquename}[3];my$tag=$tags[$i]//'';like($legend,qr/^rep:\Q$tag\E blk:/,'actual label legend uses physical group, including unknown');}
        is(scalar@{$c->{forwards}},4,'all four actual barcode images rendered');
        my($leading)=grep{$_->{args}[0]eq$plots[1]->uniquename}@{$c->{forwards}};like($leading->{args}[1],qr/rep:01 blk:/,'actual Code128 renderer receives leading-zero physical legend');
    };
    scenario 'Actual plot phenotyping QR PDF retains the physical group text'=>sub{
        my$c=context({stock_names_2=>$plots[1]->uniquename,select_barcode_text=>''});SGN::Controller::StockBarcode->new->download_qrcode($c);pdf_file($c,'plot phenotyping QR labels');
        is($c->stash->{found}[0][3],'rep:01 block:1 plot:2','actual QR-PDF human-readable legend retains physical tag');
        is($c->{forwards}[0]{path},'/barcode/phenotyping_qrcode_jpg','actual phenotyping QR generator used');
    };
    scenario 'Real native plant labels use the parent plot physical group'=>sub{
        my$parent=$plots[1];my$field=term('field_layout','experiment_type');
        my$experiment=$s->resultset('NaturalDiversity::NdExperimentStock')->search({stock_id=>$parent->stock_id,type_id=>$field})->first->nd_experiment;
        CXGN::Trial->new({bcs_schema=>$s,trial_id=>$trial})->_save_plant_entry($s,term('accession','stock_type'),term('cross','stock_type'),term('family_name','stock_type'),$parent->organism_id,$parent->uniquename,$parent->stock_id,$prefix.'_plant',term('plant','stock_type'),1,term('plant_index_number','stock_property'),term('block','stock_property'),term('plot number','stock_property'),term('replicate','stock_property'),term('row_number','stock_property'),undef,term('col_number','stock_property'),undef,term('plant_of','stock_relationship'),$experiment,$field,term('plot_of','stock_relationship'),undef,undef,undef,term('plant_of_subplot','stock_relationship'));
        $s->resultset('Project::Projectprop')->find_or_create({project_id=>$trial,type_id=>term('project_has_plant_entries','project_property'),value=>1,rank=>0});
        CXGN::Trial::TrialLayout->new({schema=>$s,trial_id=>$trial,experiment_type=>'field_layout'})->generate_and_cache_layout;
        my$c=context({stock_names=>$prefix.'_plant',select_barcode_type=>'1D',select_print_format=>'',label_rows=>10,label_cols=>1,page_format=>'letter',tops_margin=>12,left_margin=>10,bottom_margin=>12,right_margin=>10,text_margin=>'',enable_fieldbook_2d_barcode=>''});
        SGN::Controller::StockBarcode->new->download_pdf_labels($c);pdf_file($c,'plant labels');
        like($c->stash->{found}[0][3],qr/^rep:01 blk:/,'actual plant label legend resolves parent physical tag');
        like($c->{forwards}[0]{args}[1],qr/rep:01 blk:/,'real plant barcode image renderer receives parent physical tag');
    };
    scenario 'Actual CrossWishlist producer quotes physical groups without any external request'=>sub{
        my @calls;
        no warnings 'redefine';
        local *LWP::UserAgent::new = sub {bless {calls=>\@calls}, 'RepLabelTransport'};
        my$c=context({crosses=>encode_json([{female_id=>$accessions[0]->uniquename,male_id=>$accessions[1]->uniquename,priority=>1}]),female_trial_id=>"$trial",male_trial_id=>"$trial",form_id=>'0',form_name=>'local-form',selected_plot_ids=>encode_json([{cross_female_accession_name=>$accessions[0]->uniquename,female_plot_id=>$plots[2]->stock_id,male_genotypes_string=>$accessions[1]->uniquename}])});
        my$ok=eval{SGN::Controller::AJAX::CrossWishlist->new->create_cross_wishlist_submit_POST($c);1};my$error=$@;
        ok($ok||$error eq"REPLICATION_LABEL_DETACHED\n",'owning producer completes to local-file response')or die$error;
        like($c->stash->{rest}{success}//'',qr/cross wishlist file can be downloaded/,'controller returns its actual local artifact links');
        my@wishlist=glob("$dir/download/cross_wishlist_*.csv");my($wishlist)=grep{$_!~/accession_info/}@wishlist;die'No actual wishlist CSV'if!$wishlist;
        my($header,$rows)=csv_rows(scalar(read_file($wishlist)));my%column=map{$header->[$_]=>$_}0..$#$header;
        is($rows->[0][$column{FemaleRepNumber}],$tags[2],'actual wishlist physical tag survives comma and quote');
        my($info)=glob("$dir/download/cross_wishlist_accession_info_*.csv");die'No actual germplasm information CSV'if!$info;
        ($header,$rows)=csv_rows(scalar(read_file($info)));%column=map{$header->[$_]=>$_}0..$#$header;
        my($quoted)=grep{$_->[$column{PlotID}]==$plots[2]->stock_id}@$rows;is($quoted->[$column{PlotRepNumber}],$tags[2],'actual germplasm-info physical tag also retains quotes');
        my($zero)=grep{$_->[$column{PlotID}]==$plots[0]->stock_id}@$rows;is($zero->[$column{PlotRepNumber}],'0','actual germplasm-info retains zero physical group');
        is(scalar@calls,3,'only three explicitly local fixture GET responses used; no ONA write attempted');
        @artifact_ids=@{$dbh->selectcol_arrayref('SELECT file_id FROM metadata.md_files WHERE dirname LIKE ?',undef,"$dir/%")};is(scalar@artifact_ids,2,'both actual files are archived with metadata inside the rollback');
        diag("CrossWishlist artifacts: $wishlist ; $info");
    };
    1;
};
my$error=$@;$s->txn_rollback;$tx=0;
ok($ran,'actual label/order controller scenarios completed and synthetic fixture rolled back')or diag($error);
is($s->resultset('Project::Project')->search({name=>$prefix})->count,0,'synthetic project removed by rollback');
for my$id(@artifact_ids){ok(!$f->metadata_schema->resultset('MdFiles')->find($id),'own artifact metadata removed by rollback')}
diag("Artifact directory: $dir");
done_testing;
