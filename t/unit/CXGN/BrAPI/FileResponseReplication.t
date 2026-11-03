use strict;
use warnings;
use utf8;
use Test::More;
use CXGN::BrAPI::FileResponse;
use File::Temp;
use Text::CSV;
use Spreadsheet::ParseExcel;

my @header=qw(observationUnitName replicate accession_occurrence numericYield reject_reason blockNumber);
my @rows=(['unit1','0',1,0,'=1+1','0'],['unit2','01',2,12.5,'ordinary text','01']);
sub output {
    my ($format,$data)=@_;
    my $file=File::Temp->new(SUFFIX=>'.'.$format,UNLINK=>1);
    CXGN::BrAPI::FileResponse->new({absolute_file_path=>$file,absolute_file_uri=>'local-test',format=>$format,data=>$data})->get_datafiles;
    $file->flush; # XLS owns the caller's open File::Temp handle, not its filename.
    return $file;
}
for my $format(qw(csv tsv)) {
    subtest "$format exact design tags and numeric controls"=>sub {
        my $file=output($format,[\@header,@rows]);
        open(my$fh,'<:encoding(UTF-8)',$file->filename)or die$!;
        my $csv=Text::CSV->new({binary=>1,sep_char=>$format eq'csv'?',':"\t"});
        my $h=$csv->getline($fh);my $first=$csv->getline($fh);my $second=$csv->getline($fh);close$fh;
        is_deeply($h,\@header,'metadata width/order unchanged');
        is($first->[1],'0','zero group is not missing');
        is($second->[1],'01','numeric-looking group tag remains exact');
        is($first->[5],'0','zero physical block tag is retained');
        is($second->[5],'01','leading-zero physical block tag remains exact');
        is($first->[3],'0','real zero measurement is not missing');
        is($second->[3],'12.5','numeric measurement retained');
        is($first->[4],'=1+1','formula-looking text retained literally');
        my $text="репліка, \"A\"\tline\nnext";
        my $quoted=output($format,[\@header,['unit, "А"',$text,1,2.5,'text']]);
        open($fh,'<:encoding(UTF-8)',$quoted->filename)or die$!;
        $csv->getline($fh);my $row=$csv->getline($fh);close$fh;
        ok($row && @$row==@header,'actual file has a complete quoted Unicode record');
        is($row->[1],$text,'quotes, separators, Unicode and newline preserve the group tag') if$row;
    };
}
subtest 'XLS group tags are text and measurements remain numeric'=>sub {
    my $file=output('xls',[\@header,@rows]);
    my $book=Spreadsheet::ParseExcel->new->parse($file->filename)or die'Cannot parse XLS';
    my($sheet)=$book->worksheets;
    is($sheet->get_cell(1,1)->value,'0','zero design tag retained');
    is($sheet->get_cell(1,1)->type,'Text','zero design tag is text');
    is($sheet->get_cell(2,1)->value,'01','leading-zero design tag retained');
    is($sheet->get_cell(2,1)->type,'Text','leading-zero tag is text');
    is($sheet->get_cell(1,3)->value,0,'actual zero measurement retained');
    is($sheet->get_cell(1,3)->type,'Numeric','actual zero measurement stays numeric');
    is($sheet->get_cell(2,3)->value,12.5,'actual numeric measurement retained');
    is($sheet->get_cell(2,3)->type,'Numeric','actual measurement stays numeric');
    is($sheet->get_cell(1,2)->type,'Numeric','operational occurrence stays numeric');
    is($sheet->get_cell(1,4)->value,'=1+1','literal text is not a formula cache');
    is($sheet->get_cell(1,5)->value,'0','zero block tag is retained');
    is($sheet->get_cell(2,5)->value,'01','leading-zero block tag is retained');
    is($sheet->get_cell(2,5)->type,'Text','physical block tags stay text');
};
subtest 'Existing non-layout callers keep their row widths and numeric values'=>sub {
    my $file=output('xls',[[qw(marker markerprofileDbId genotype)],['m1',73,0,12.5]]);
    my $book=Spreadsheet::ParseExcel->new->parse($file->filename)or die'Cannot parse marker XLS';
    my($sheet)=$book->worksheets;
    is($sheet->get_cell(1,2)->value,0,'marker genotype zero remains present');
    is($sheet->get_cell(1,2)->type,'Numeric','genotype numeric cell remains numeric');
    is($sheet->get_cell(1,3)->value,12.5,'existing XLS ragged-row extra cell is preserved');
    for my$format(qw(csv tsv)){
        my$out=output($format,[[qw(marker markerprofileDbId genotype)],['m1',73,0,12.5]]);
        open(my$in,'<:encoding(UTF-8)',$out->filename)or die$!;
        my$csv=Text::CSV->new({binary=>1,sep_char=>$format eq'csv'?',':"\t"});$csv->getline($in);my$row=$csv->getline($in);close$in;
        is_deeply($row,['m1',73,0],"$format retains its existing header-width contract and zero genotype");
    }
};
done_testing;
