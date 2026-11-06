use strict;
use warnings;
use lib 't/lib';
use Test::More;
use SGN::Test::Fixture;
use SGN::Model::Cvterm;
use CXGN::Trial::AccessionChange;
use CXGN::Trial::Download;
use CXGN::Fieldbook::DownloadTrial;
use Spreadsheet::ParseExcel;
use Spreadsheet::ParseXLSX;
use File::Temp qw(tempdir);

my $f=SGN::Test::Fixture->new;
my $s=$f->bcs_schema;
$s->storage->auto_savepoint(1);
my $dir=tempdir(CLEANUP=>1);
my $trial=$s->resultset('Project::Project')->find({name=>'test_trial'})->project_id;
my $rejected=$s->resultset('Stock::Stock')->find({uniquename=>'test_trial214'});
my $valid=$s->resultset('Stock::Stock')->find({uniquename=>'test_trial215'});
my $trait_id=70666;
my $trait_name=SGN::Model::Cvterm::get_trait_from_cvterm_id($s,$trait_id,'extended');
my $tag='fieldbook_literal_'.time().'_'.$$;
my @files;
sub cv {SGN::Model::Cvterm->get_cvterm_row($s,$_[0],$_[1])->cvterm_id}
sub inspect {
    my ($file,$label)=@_;
    my $parser=$file =~ /\.xlsx$/ ? Spreadsheet::ParseXLSX->new : Spreadsheet::ParseExcel->new;
    my $book=$parser->parse($file) or die "Cannot read $label workbook";
    my ($sheet)=$book->worksheets;
    my (undef,$max_col)=$sheet->col_range;
    my (undef,$max_row)=$sheet->row_range;
    my @header=map {my$c=$sheet->get_cell(0,$_);$c?$c->value:''} 0..$max_col;
    my ($plot_col)=grep {$header[$_] eq 'plot_name'} 0..$#header;
    my ($number_col)=grep {$header[$_] eq 'plot_number'} 0..$#header;
    my ($reason_col)=grep {$header[$_] eq 'reject_reason'} 0..$#header;
    my ($trait_col)=grep {$header[$_] eq $trait_name} 0..$#header;
    die "Incomplete $label header" if grep {!defined($_)} ($plot_col,$number_col,$reason_col,$trait_col);
    my %row;
    for my $r(1..$max_row){my$c=$sheet->get_cell($r,$plot_col);$row{$c->value}=$r if$c;}
    die "Missing $label control rows" if !exists($row{$rejected->uniquename}) || !exists($row{$valid->uniquename});
    my $reason=$sheet->get_cell($row{$rejected->uniquename},$reason_col);
    my $number=$sheet->get_cell($row{$valid->uniquename},$number_col);
    my $measurement=$sheet->get_cell($row{$valid->uniquename},$trait_col);
    is($reason->value,'=1+1',"$label retains formula-looking rejection reason literally");
    is($reason->type,'Text',"$label rejection reason is a text cell");
    is($number->value,15,"$label plot number retained");
    is($number->type,'Numeric',"$label plot number stays numeric");
    is($measurement->value,12.5,"$label measurement retained");
    is($measurement->type,'Numeric',"$label measurement stays numeric");
}

$s->txn_begin;
my $ran=eval {
    my $type=cv('phenotyping_experiment','experiment_type');
    my $experiment=$s->resultset('NaturalDiversity::NdExperiment')->create({type_id=>$type,nd_geolocation_id=>$s->resultset('NaturalDiversity::NdGeolocation')->first->nd_geolocation_id});
    $s->resultset('NaturalDiversity::NdExperimentProject')->create({nd_experiment_id=>$experiment->nd_experiment_id,project_id=>$trial});
    $s->resultset('NaturalDiversity::NdExperimentStock')->create({nd_experiment_id=>$experiment->nd_experiment_id,stock_id=>$valid->stock_id,type_id=>$type});
    my $phenotype=$s->resultset('Phenotype::Phenotype')->create({uniquename=>$tag,cvalue_id=>$trait_id,observable_id=>$trait_id,value=>12.5,operator=>'janedoe'});
    $s->resultset('NaturalDiversity::NdExperimentPhenotype')->create({nd_experiment_id=>$experiment->nd_experiment_id,phenotype_id=>$phenotype->phenotype_id});
    CXGN::Trial::AccessionChange->new({schema=>$s,trial_id=>$trial})->apply([{plot_id=>$rejected->stock_id,rejected=>1,reject_reason=>'=1+1'}],{rename_plots=>'none',curator=>1});
    my $columns={plot_name=>1,plot_number=>1,rejected=>1,reject_reason=>1};
    for my $extension ('xls','xlsx') {
        my $fieldbook=CXGN::Fieldbook::DownloadTrial->new({bcs_schema=>$s,metadata_schema=>$f->metadata_schema,phenome_schema=>$f->phenome_schema,trial_id=>$trial,tempfile=>"$dir/fieldbook.$extension",archive_path=>"$dir/archive",user_id=>41,user_name=>'janedoe',data_level=>'plots',selected_columns=>$columns,include_measured=>'true',include_treatments=>'false',all_stats=>'false',use_synonyms=>'false'})->download;
        die join('; ',@{$fieldbook->{error_messages}}) if$fieldbook->{error_messages};
        push@files,$fieldbook;
        inspect($fieldbook->{file},"Field Book $extension");
        my $layout="$dir/layout.$extension";
        CXGN::Trial::Download->new({bcs_schema=>$s,trial_id=>$trial,filename=>$layout,format=>'TrialLayoutExcel',data_level=>'plots',selected_columns=>$columns,include_measured=>'true',include_treatments=>'false'})->download;
        inspect($layout,"trial layout $extension");
    }
    1;
};
my $error=$@;
$s->txn_rollback;
my $cleaned=eval {
    for my$r(@files){
        my$file=$f->metadata_schema->resultset('MdFiles')->find({file_id=>$r->{file_id}}) or die 'Missing generated file metadata';
        my$metadata_id=$file->get_column('metadata_id');
        $f->phenome_schema->resultset('NdExperimentMdFiles')->search({file_id=>$r->{file_id}})->delete;
        $f->metadata_schema->resultset('MdFiles')->search({file_id=>$r->{file_id}})->delete;
        $f->metadata_schema->resultset('MdMetadata')->search({metadata_id=>$metadata_id})->delete;
    }
    1;
};
my $cleanup_error=$@;
ok($ran,'actual workbook scenarios completed; fixture transaction rolled back') or diag("$error");
ok($cleaned,'only this test generated-file metadata removed') or diag("$cleanup_error");
is($s->resultset('Phenotype::Phenotype')->search({uniquename=>$tag})->count,0,'synthetic numeric observation removed by rollback');
done_testing;
