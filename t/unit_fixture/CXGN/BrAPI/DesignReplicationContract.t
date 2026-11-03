use strict;
use warnings;
use lib 't/lib';
use Test::More;
use JSON qw(encode_json decode_json);
use File::Temp qw(tempdir);
use Text::CSV;
use Spreadsheet::ParseExcel;
use Spreadsheet::ParseXLSX;
use Scalar::Util qw(refaddr);
use SGN::Test::Fixture;
use SGN::Model::Cvterm;
use CXGN::Trial;
use CXGN::Trial::TrialCreate;
use CXGN::Trial::TrialLayout;
use CXGN::Trial::TrialLayoutDownload;
use CXGN::Trial::Download;
use CXGN::Trial::DesignReplication;
use CXGN::Fieldbook::DownloadTrial;
use CXGN::Phenotypes::CreateSpreadsheet;
use CXGN::Phenotypes::DataCollectorSpreadsheet;
use CXGN::BrAPI::v1::ObservationUnits;
use CXGN::BrAPI::v1::Studies;
use CXGN::BrAPI::v2::ObservationUnits;

# Public native creation, owning BrAPI models, cached layout and actual files.
# No randomization/model or external Field Book device acceptance is claimed.
my $f=SGN::Test::Fixture->new;
my $s=$f->bcs_schema;my $dbh=$s->storage->dbh;
$s->storage->auto_savepoint(1);
# The archived file link references this rollback-only trial's experiment.
# Use the platform's shared-DBH schema connection pattern, rather than separate
# fixture connections which cannot see the uncommitted synthetic experiment.
my $archive_metadata=CXGN::Metadata::Schema->connect(sub {$dbh});
my $archive_phenome=CXGN::Phenome::Schema->connect(sub {$dbh});
# Core BCS readers change search_path on this shared handle. Qualify only these
# dedicated test schema sources, so archive FK visibility and table ownership
# both hold without relying on the caller's current search_path.
for my $entry ([$archive_metadata,'metadata'],[$archive_phenome,'phenome']) {
    my($schema,$namespace)=@$entry;
    for my $name ($schema->sources) {
        my$source=$schema->source($name);my$table=$source->name;
        die "Unexpected archive source name $name" if ref($table) || $table!~/^[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)?$/;
        $source->name("$namespace.$table") if $table!~/\./;
    }
}
is(refaddr($archive_metadata->storage->dbh),refaddr($dbh),'artifact metadata shares the real rollback DBH');
is(refaddr($archive_phenome->storage->dbh),refaddr($dbh),'artifact experiment link shares the real rollback DBH');
my $dir=tempdir(CLEANUP=>1);
my $prefix='audit_design_dto_'.$$;
my ($trial,@plots,@files,@refresh);
{package DesignDtoDbc;sub dbh {$_[0]{dbh}}} ## no critic (Modules::RequireFilenameMatchesPackage) -- This test embeds its named test double beside the assertions.
{package DesignDtoClear;sub clear_cached_analyses_result {1}}
{package DesignDtoContext;sub dbc {$_[0]{dbc}}sub config {$_[0]{config}}sub controller {$_[0]{clear}}}
my $context=bless {dbc=>bless({dbh=>$dbh},'DesignDtoDbc'),config=>$f->config,clear=>bless({},'DesignDtoClear')},'DesignDtoContext';
sub term {SGN::Model::Cvterm->get_cvterm_row($s,@_)->cvterm_id}
sub api {
    my ($version,$studies)=@_;
    my $class=$studies ? 'CXGN::BrAPI::v1::Studies' : 'CXGN::BrAPI::v'.$version.'::ObservationUnits';
    return $class->new({bcs_schema=>$s,metadata_schema=>$f->metadata_schema,phenome_schema=>$f->phenome_schema,people_schema=>$f->people_schema,context=>$context,page=>0,page_size=>100,status=>[]});
}
sub prop {
    my($id,$name,@set)=@_;my $type=term($name,'stock_property');
    my $rs=$s->resultset('Stock::Stockprop')->search({stock_id=>$id,type_id=>$type});
    if(@set){$rs->delete;$s->resultset('Stock::Stockprop')->create({stock_id=>$id,type_id=>$type,value=>$set[0],rank=>0}) if defined($set[0])}
    my $r=$rs->first;return $r ? $r->value : undef;
}
sub dto {api($_[0])->detail($_[1],$context)->{result}}
sub clone {decode_json(encode_json($_[0]))}
sub put {api(2)->observationunits_update($_[0],$context,41)}
sub physical {
    my($unit)=@_;
    my($relation)=grep {($_->{levelName}//'') eq 'rep'} @{$unit->{observationUnitPosition}{observationLevelRelationships}};
    return $relation ? $relation->{levelCode} : undef;
}
sub design {CXGN::Trial::TrialLayout->new({schema=>$s,trial_id=>$trial,experiment_type=>'field_layout'})->get_design}
sub scenario {
    my($name,$body)=@_;
    return if $ENV{AUDIT_DESIGN_DTO_CASE} && index($name,$ENV{AUDIT_DESIGN_DTO_CASE})<0;
    subtest $name=>sub {$s->txn_begin;@refresh=();my $ok=eval{$body->();1};my$error=$@;$s->txn_rollback;ok($ok,'owning model scenario completed and rolled back')or diag($error)};
}
sub ensure_term {
    my($name,$cv,$template_name)=@_;
    return if $s->resultset('Cv::Cvterm')->search({'me.name'=>$name,'cv.name'=>$cv},{join=>'cv'})->count;
    my $template=SGN::Model::Cvterm->get_cvterm_row($s,$template_name,$cv);
    my $xref=$s->resultset('General::Dbxref')->create({db_id=>$template->dbxref->db_id,accession=>$prefix.'_'.$name});
    $s->resultset('Cv::Cvterm')->create({name=>$name,cv_id=>$template->cv_id,dbxref_id=>$xref->dbxref_id});
}
sub workbook_row {
    my($path)=@_;my$parser=$path=~/\.xlsx$/ ? Spreadsheet::ParseXLSX->new : Spreadsheet::ParseExcel->new;
    my $book=$parser->parse($path)or die "Cannot parse actual workbook $path";my($sheet)=$book->worksheets;
    my(undef,$max_col)=$sheet->col_range;my(undef,$max_row)=$sheet->row_range;
    my %column=map {my$c=$sheet->get_cell(0,$_);($c ? $c->value : '')=>$_} 0..$max_col;
    my $plot_name=$s->resultset('Stock::Stock')->find($plots[1])->uniquename;
    for my $row(1..$max_row) {
        my$c=$sheet->get_cell($row,$column{plot_name});next if!$c||$c->value ne $plot_name;
        return ($sheet->get_cell($row,$column{rep_number}),$sheet->get_cell($row,$column{accession_occurrence}),$sheet->get_cell($row,$column{plot_number}),$sheet->get_cell($row,$column{block_number}));
    }
    die 'Actual workbook omitted the leading-zero control plot';
}
my $tx=0;END{eval{$s->txn_rollback if$tx}if$s}
$s->txn_begin;$tx=1;
my $ran=eval {
    ensure_term('design_replicate','stock_property','replicate');
    ensure_term('accession_occurrence_version','project_property','design');
    my @groups=('0','01',undef,'01');
    my %layout=map {my$i=$_;($i=>{plot_name=>"${prefix}_plot_$i",plot_number=>$i,stock_name=>$i<3?'test_accession1':'test_accession2',rep_number=>$groups[$i-1],block_number=>'01',row_number=>1,col_number=>$i})}1..4;
    my $created=CXGN::Trial::TrialCreate->new({chado_schema=>$s,dbh=>$dbh,owner_id=>41,operator=>'janedoe',program=>'test',trial_location=>'test_location',trial_name=>$prefix,trial_description=>'Rollback-only physical group/occurrence DTO and file contract',trial_year=>2031,design_type=>'RCBD',design=>\%layout})->save_trial;
    $trial=$created->{trial_id};die encode_json($created)if!$trial;
    @plots=map {$s->resultset('Stock::Stock')->find({uniquename=>"${prefix}_plot_$_"})->stock_id}1..4;
    no warnings 'redefine';
    local *CXGN::BreederSearch::refresh_matviews_after_change=sub{push@refresh,1;return {}};
    local *CXGN::BreederSearch::refresh_matviews=sub{return {}};

    scenario 'Native creation and public v1/v2 distinguish exact tags and counters'=>sub {
        my$record=CXGN::Trial::DesignReplication::read($s,\@plots);
        is_deeply([map{$record->{$_}{value}}@plots],\@groups,'native design tags preserve zero, leading zero and recorded unknown');
        is_deeply([map{$record->{$_}{occurrence}}@plots],[1,2,1,2],'native field counters are canonical accession occurrences');
        ok(!grep({!$record->{$_}{occurrence_ready}}@plots),'whole native field is explicitly ready');
        for my$i(0..$#plots){
            my$v2=dto(2,$plots[$i]);is(physical($v2),$groups[$i],'v2 standard rep is physical tag');
            is($v2->{additionalInfo}{designReplicate},$groups[$i],'v2 explicit alias retains exact tag or null');
            is($v2->{additionalInfo}{accessionOccurrence},$record->{$plots[$i]}{occurrence},'v2 operational alias is separate');
            is(dto(1,$plots[$i])->{replicate},$groups[$i],'v1 standard flat replicate has same physical meaning');
        }
        my$cached=design();is($cached->{2}{design_rep_number},'01','cache stores physical group separately');is($cached->{2}{rep_number},2,'cache retains raw occurrence under its internal key');
    };
    scenario 'Complete GET PUT echoes cannot change groups or counters'=>sub {
        for my$version(1,2){
            my$body=clone(dto($version,$plots[1]));my$r=api($version)->observationunits_update([$body],$context,41);
            ok(defined($r->{result}),"v$version complete echo accepted")or diag(encode_json($r));
            is(prop($plots[1],'replicate'),2,'counter preserved');is(prop($plots[1],'design_replicate'),'01','physical group preserved');
        }
        is(scalar@refresh,0,'unchanged DTO echoes trigger no analytical refresh');
    };
    scenario 'Aliases conflict and counter writes fail atomically'=>sub {
        my$r=put([{observationUnitDbId=>"$plots[1]",additionalInfo=>{designReplicate=>'1'},observationUnitPosition=>{observationLevelRelationships=>[{levelName=>'rep',levelCode=>'01'}]}}]);
        is($r->{http_code},400,'different exact tags are conflicting aliases');
        $r=put([{observationUnitDbId=>"$plots[1]",additionalInfo=>{accessionOccurrence=>99}}]);
        is($r->{http_code},400,'counter cannot be changed through additionalInfo');
        $r=api(1)->observationunits_update([{observationUnitDbId=>"$plots[1]",replicate=>'1',observationUnitPosition=>{observationLevelRelationships=>[{levelName=>'rep',levelCode=>'01'}]}}],$context,41);
        is($r->{http_code},400,'flat and nested v1 group aliases cannot silently override each other');
        is(prop($plots[1],'design_replicate'),'01','invalid aliases left physical tag intact');is(prop($plots[1],'replicate'),2,'invalid requests left counter intact');
    };
    scenario 'Intentional group edit and explicit clear preserve counters and nullable snapshot'=>sub {
        my$r=put([{observationUnitDbId=>"$plots[1]",additionalInfo=>{designReplicate=>'0'}}]);
        ok(defined($r->{result}),'intentional physical group edit accepted')or diag(encode_json($r));
        is(physical(dto(2,$plots[1])),'0','new zero tag reads back literally');is(prop($plots[1],'replicate'),2,'group edit does not renumber accession occurrences');
        $r=put([{observationUnitDbId=>"$plots[1]",additionalInfo=>{designReplicate=>undef}}]);
        ok(defined($r->{result}),'explicit group clear accepted')or diag(encode_json($r));
        my$record=CXGN::Trial::DesignReplication::read($s,[$plots[1]])->{$plots[1]};
        ok($record->{recorded},'clear keeps a snapshot row');is($record->{value},undef,'clear reads as unknown, never counter fallback');is($record->{occurrence},2,'clear leaves operational counter intact');
    };
    scenario 'Legacy readiness is separate from recorded group presence'=>sub {
        $s->resultset('Project::Projectprop')->search({project_id=>$trial,type_id=>term('accession_occurrence_version','project_property')})->delete;
        prop($plots[1],'replicate',27);
        my$body=dto(2,$plots[1]);is(physical($body),'01','snapshot group remains physical before cutover');ok(!exists($body->{additionalInfo}{accessionOccurrence}),'legacy raw number is not advertised as an occurrence');
        my$r=put([clone($body)]);ok(defined($r->{result}),'legacy GET echo accepted')or diag(encode_json($r));is(prop($plots[1],'replicate'),27,'echo does not silently normalize a legacy field');
        prop($plots[1],'design_replicate',undef);CXGN::Trial::DesignReplication::mark_occurrences_ready($s,$trial);
        is(physical(dto(2,$plots[1])),undef,'missing snapshot after cutover never exposes counter as group');
    };
    scenario 'Explicit layout column selection is exact and caller input is unchanged'=>sub {
        for my $mode ('absent','false','true') {
            my $columns={plot_name=>1,rep_number=>1};
            $columns->{accession_occurrence}=$mode eq 'true' ? 1:0 if $mode ne 'absent';
            my $before=clone($columns);
            my $path="$dir/selected-$mode.csv";
            CXGN::Trial::Download->new({bcs_schema=>$s,trial_id=>$trial,filename=>$path,format=>'TrialLayoutCSV',data_level=>'plots',selected_columns=>$columns,include_measured=>'false',include_treatments=>'false'})->download;
            open(my $in,'<:encoding(UTF-8)',$path)or die$!;
            my $csv=Text::CSV->new({binary=>1});my $header=$csv->getline($in);close($in);
            my @expected=('plot_name','rep_number');push @expected,'accession_occurrence' if $mode eq 'true';
            is_deeply($header,\@expected,"actual CSV honors $mode independent counter selection");
            is_deeply($columns,$before,"actual export does not mutate caller $mode column map");
        }
    };
    scenario 'Actual layout CSV XLS XLSX and Field Book retain exact physical tags'=>sub {
        my$columns={plot_name=>1,plot_number=>1,rep_number=>1,accession_occurrence=>1,block_number=>1};
        my$csv_file="$dir/layout.csv";
        CXGN::Trial::Download->new({bcs_schema=>$s,trial_id=>$trial,filename=>$csv_file,format=>'TrialLayoutCSV',data_level=>'plots',selected_columns=>$columns,include_measured=>'false',include_treatments=>'false'})->download;
        open(my$in,'<:encoding(UTF-8)',$csv_file)or die$!;my$csv=Text::CSV->new({binary=>1});my$header=$csv->getline($in);my@rows;while(my$row=$csv->getline($in)){push@rows,$row}close$in;
        my%col=map{$header->[$_]=>$_}0..$#$header;
        is($rows[0][$col{rep_number}],'0','actual CSV zero group retained');is($rows[1][$col{rep_number}],'01','actual CSV leading-zero group retained');is($rows[1][$col{accession_occurrence}],2,'actual CSV has separate counter column');
        for my$extension(qw(xls xlsx)){
            my$path="$dir/layout.$extension";
            CXGN::Trial::Download->new({bcs_schema=>$s,trial_id=>$trial,filename=>$path,format=>'TrialLayoutExcel',data_level=>'plots',selected_columns=>$columns,include_measured=>'false',include_treatments=>'false'})->download;
            my($tag,$occ,$number,$block)=workbook_row($path);
            is($tag->value,'01',"actual layout $extension exact group");is($tag->type,'Text',"actual layout $extension group is text");is($occ->value,2,"actual layout $extension separate counter");is($number->type,'Numeric',"actual layout $extension plot number stays numeric");is($block->value,'01',"actual layout $extension exact block tag");is($block->type,'Text',"actual layout $extension block is text");
        }
        my$out=CXGN::Fieldbook::DownloadTrial->new({bcs_schema=>$s,metadata_schema=>$archive_metadata,phenome_schema=>$archive_phenome,trial_id=>$trial,tempfile=>"$dir/fieldbook.xlsx",archive_path=>"$dir/archive",user_id=>41,user_name=>'janedoe',data_level=>'plots',selected_columns=>$columns,include_measured=>'false',include_treatments=>'false',all_stats=>'false',use_synonyms=>'false'})->download;
        die encode_json($out)if$out->{error_messages};push@files,$out;
        my($tag,$occ,$number,$block)=workbook_row($out->{file});is($tag->value,'01','actual archived Field Book exact physical tag');is($tag->type,'Text','actual Field Book group is text');is($occ->value,2,'actual Field Book counter is separate');is($number->type,'Numeric','actual Field Book numeric field stays numeric');is($block->value,'01','actual Field Book exact block tag');is($block->type,'Text','actual Field Book block tag is text');
        ok($archive_metadata->resultset('MdFiles')->find({file_id=>$out->{file_id}}),'actual archived artifact has file metadata');
        my$link=$archive_phenome->resultset('NdExperimentMdFiles')->find({file_id=>$out->{file_id}});
        ok($link,'actual archived artifact is associated with its real synthetic field experiment');
    };
    scenario 'Actual v1 study-layout downloadable file preserves its metadata prefix'=>sub {
        my$file=File::Temp->new(DIR=>$dir,SUFFIX=>'.csv',UNLINK=>1);
        my$r=api(1,1)->studies_layout({study_id=>$trial,format=>'csv',file_path=>$file,file_uri=>'native-layout.csv',main_production_site_url=>''});
        ok(defined($r->{result}) && @{$r->{datafiles}||[]}==1,'owning study-layout model generated its downloadable CSV')or diag(encode_json($r));
        open(my$in,'<:encoding(UTF-8)',$file->filename)or die$!;my$csv=Text::CSV->new({binary=>1});my$header=$csv->getline($in);$csv->getline($in);my$row=$csv->getline($in);close$in;
        is_deeply([@$header[0..10]],[qw(studyDbId observationUnitDbId observationUnitName observationLevel replicate blockNumber X Y entryType germplasmName germplasmDbId)],'original study-layout metadata prefix remains unchanged');
        is($header->[11],'accession_occurrence','new counter is explicit after existing metadata');is($row->[4],'01','actual study-layout file retains exact physical tag');is($row->[11],2,'actual study-layout file has independent occurrence');
    };
    scenario 'Legacy collection spreadsheets preserve physical tags and positional metadata'=>sub {
        for my$module(qw(CreateSpreadsheet DataCollectorSpreadsheet)){
            my$class='CXGN::Phenotypes::'.$module;my$path="$dir/$module.xls";
            ok($class->new({schema=>$s,trial_id=>$trial,trait_list=>[],filename=>$path})->create,"actual $module producer completes");
            my$book=Spreadsheet::ParseExcel->new->parse($path)or die"Cannot parse $module";my($sheet)=$book->worksheets;
            is($sheet->get_cell(7,5)->value,'01',"$module keeps physical tag in existing column5");is($sheet->get_cell(7,5)->type,'Text',"$module group remains text");is($sheet->get_cell(7,3)->value,'01',"$module keeps exact physical block tag");is($sheet->get_cell(7,3)->type,'Text',"$module physical block is text");
            is($sheet->get_cell(7,2)->value,2,"$module plot number retains its column2");is($sheet->get_cell(7,2)->type,'Numeric',"$module actual plot number stays numeric");
            my(undef,$max_col)=$sheet->col_range;is($max_col,5,"$module six-column collection prefix is unchanged");
        }
        for my$case(['ExcelBasic',8,9],['DataCollectorExcel',2,6]){
            my($format,$row,$width)=@$case;my$path="$dir/$format.xls";
            CXGN::Trial::Download->new({bcs_schema=>$s,trial_id=>$trial,trial_list=>[$trial],filename=>$path,format=>$format,data_level=>'plots',trait_list=>[]})->download;
            my$book=Spreadsheet::ParseExcel->new->parse($path)or die"Cannot parse $format";
            my$sheet=$format eq 'DataCollectorExcel' ? $book->worksheet('Field Book') : $book->worksheet(0);
            is($sheet->get_cell($row,5)->value,'01',"$format existing replica slot is physical tag");is($sheet->get_cell($row,5)->type,'Text',"$format replica tag is a text cell");is($sheet->get_cell($row,3)->value,'01',"$format keeps exact physical block tag");is($sheet->get_cell($row,3)->type,'Text',"$format physical block is text");
            my(undef,$max_col)=$sheet->col_range;is($max_col,$width-1,"$format keeps its positional metadata width");
        }
    };
    scenario 'Actual BrAPI POST child inherits group and rejects a different explicit group'=>sub {
        my$germplasm=$s->resultset('Stock::Stock')->find({uniquename=>'test_accession1'})->stock_id;
        my$body={studyDbId=>"$trial",observationUnitName=>$prefix.'_plant',germplasmDbId=>"$germplasm",additionalInfo=>{observationUnitParent=>"$plots[1]"},observationUnitPosition=>{observationLevel=>{levelName=>'plant',levelCode=>'2'},observationLevelRelationships=>[{levelName=>'rep',levelCode=>'01'}]}};
        my$r=api(2)->observationunits_store([$body],$context,41);ok(defined($r->{result}),'native POST child created')or die encode_json($r);
        my$id=$s->resultset('Stock::Stock')->find({uniquename=>$prefix.'_plant'})->stock_id;
        my$child=dto(2,$id);is(physical($child),'01','new child physical group follows parent');is($child->{additionalInfo}{accessionOccurrence},2,'new child counter follows parent');
        $r=put([{observationUnitDbId=>"$id",additionalInfo=>{designReplicate=>'different'}}]);is($r->{http_code},400,'child physical metadata edit must go through parent');
        $r=put([{observationUnitDbId=>"$plots[1]",additionalInfo=>{designReplicate=>undef}}]);ok(defined($r->{result}),'parent group can be cleared')or die encode_json($r);
        is(physical(dto(2,$id)),undef,'cleared parent group propagates as unknown to child');is(prop($id,'replicate'),2,'parent group clear preserves child occurrence');
        my$out=CXGN::Trial::TrialLayoutDownload->new({schema=>$s,trial_id=>$trial,data_level=>'plants',selected_columns=>{plant_name=>1,rep_number=>1,accession_occurrence=>1},include_measured=>'false',include_treatments=>'false'})->get_layout_output;
        die encode_json($out)if$out->{error_messages};my%col=map{$out->{output}[0][$_]=>$_}0..$#{$out->{output}[0]};
        is($out->{output}[1][$col{rep_number}],undef,'child layout uses actual NULL physical metadata');is($out->{output}[1][$col{accession_occurrence}],2,'child layout keeps actual occurrence separately');
    };
    scenario 'Pooled descendants retain unknown metadata until their parent groups agree'=>sub {
        # This intentionally exercises supported structural ancestry and actual
        # field membership, not an unqualified public pooled-creation endpoint.
        my$parent=$s->resultset('Stock::Stock')->find($plots[0]);
        my$sample=$s->resultset('Stock::Stock')->create({name=>$prefix.'_pooled',uniquename=>$prefix.'_pooled',organism_id=>$parent->organism_id,type_id=>term('tissue_sample','stock_type')});
        my$id=$sample->stock_id;
        my$accession=$s->resultset('Stock::Stock')->find({uniquename=>'test_accession1'})->stock_id;
        for my$source($plots[0],$plots[1],$accession){$s->resultset('Stock::StockRelationship')->create({subject_id=>$id,object_id=>$source,type_id=>term('tissue_sample_of','stock_relationship'),rank=>0})}
        my$field=term('field_layout','experiment_type');
        my$membership=$s->resultset('NaturalDiversity::NdExperimentStock')->search({stock_id=>$plots[0],type_id=>$field})->first;
        $s->resultset('NaturalDiversity::NdExperimentStock')->create({stock_id=>$id,nd_experiment_id=>$membership->nd_experiment_id,type_id=>$field});
        prop($id,'tissue_sample_index_number',1);prop($id,'plot number',1);prop($id,'block',1);
        CXGN::Trial::DesignReplication::set($s,$id,undef);
        my$r=put([{observationUnitDbId=>"$plots[0]",additionalInfo=>{designReplicate=>'C'}}]);
        ok(defined($r->{result}),'parent grouping metadata may differ for a biologically coherent pool')or die encode_json($r);
        is(prop($plots[0],'design_replicate'),'C','intentional parent metadata edit persists');
        is(prop($id,'design_replicate'),undef,'different final parent groups give an explicitly unknown pooled group');
        $r=put([map{{observationUnitDbId=>"$_",additionalInfo=>{designReplicate=>'C'}}} @plots[0,1]]);
        ok(defined($r->{result}),'bulk agreeing parent metadata accepted atomically')or die encode_json($r);
        is(prop($id,'design_replicate'),'C','pooled child receives unanimous final group');
        is(prop($id,'replicate'),undef,'pooled descendant has no arbitrary parent occurrence');
        $r=put([{observationUnitDbId=>"$plots[0]",additionalInfo=>{designReplicate=>undef}}]);
        ok(defined($r->{result}),'unknown parent membership is allowed')or die encode_json($r);
        my$record=CXGN::Trial::DesignReplication::read($s,[$id])->{$id};ok($record->{recorded},'unknown pooled membership is recorded');is($record->{value},undef,'one unknown parent makes pooled design membership unknown');
    };
    1;
};
my$error=$@;$s->txn_rollback;$tx=0;
my$clean=eval{
    for my$out(@files){
        die 'Own artifact metadata survived rollback' if $f->metadata_schema->resultset('MdFiles')->find({file_id=>$out->{file_id}});
        die 'Own artifact association survived rollback' if $f->phenome_schema->resultset('NdExperimentMdFiles')->find({file_id=>$out->{file_id}});
    }1;
};my$cleanup_error=$@;
ok($ran,'all native DTO and artifact scenarios completed; synthetic layout rolled back')or diag($error);
ok($clean,'own generated artifact metadata and links removed by the same rollback')or diag($cleanup_error);
is($s->resultset('Project::Project')->search({name=>$prefix})->count,0,'own synthetic project removed by rollback');
done_testing;
