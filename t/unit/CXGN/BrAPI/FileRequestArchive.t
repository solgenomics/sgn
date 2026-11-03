use strict;
use warnings;
use utf8;
use Test::More;
use Bio::Chado::Schema;
use CXGN::BrAPI::FileRequest;
use File::Temp qw(tempdir);
use File::Path qw(make_path);
use Text::CSV;
use JSON qw(decode_json);

# FileRequest only requires the schema's type; archiving does not query it.
# Use the public lazy connection constructor and forbid any accidental DB query.
# No class or application method is replaced; this archiver only needs its type.
my $schema=Bio::Chado::Schema->connect(sub {die 'Archive unit test must not query a database'});
my $dir=tempdir(CLEANUP=>1);
make_path("$dir/input","$dir/archive");
my @legacy=qw(observationDbId observationUnitDbId observationVariableDbId value observationTimeStamp collector);
sub archive {
    my ($data)=@_;
    my $result=CXGN::BrAPI::FileRequest->new({schema=>$schema,user_id=>41,user_type=>'curator',format=>'observations',data=>$data,tempfiles_subdir=>"$dir/input",archive_path=>"$dir/archive"})->get_path;
    die $result->{error_message} if $result->{error_message};
    my $path=$result->{archived_filename_with_path};
    die 'No actual archived request file' if !$path || !-f $path;
    return $path;
}
sub bytes {open(my$fh,'<:raw',$_[0])or die$!;local$/;my$x=<$fh>;close$fh;return$x;}
sub table {
    open(my$fh,'<:encoding(UTF-8)',$_[0])or die$!;
    my $csv=Text::CSV->new({binary=>1});
    my $header=$csv->getline($fh);
    my $row=$csv->getline($fh);
    my $error=''.$csv->error_diag;
    close$fh;
    return($header,$row,$error);
}
sub record {return{observationDbId=>'101',observationUnitDbId=>'201',observationVariableDbId=>'301',value=>$_[0],observationTimeStamp=>'2026-11-03T10:00:00Z',collector=>'janedoe'};}

subtest 'Serial archives retain separate identities and original bytes' => sub {
    my $first=archive([record('first')]);
    my $original=bytes($first);
    my $second=archive([record('second')]);
    isnt($first,$second,'consecutive archive paths are unique, including within one second'); # codespell:ignore isnt
    is(bytes($first),$original,'a later request cannot overwrite the first archived input');
};
subtest 'Quoted Unicode text stays within its original CSV cells' => sub {
    my $value='first, "quoted" зразок';
    my $collector='Jane "A", Доу';
    my $data=record($value);$data->{collector}=$collector;
    my ($header,$row,$error)=table(archive([$data]));
    is_deeply([@$header[0..5]],\@legacy,'the six existing columns keep their order');
    ok($row && @$row==@$header,'actual archived record is valid CSV') or diag($error);
    if ($row) {
        my %col=map {$header->[$_]=>$_} 0..$#$header;
        is($row->[$col{value}],$value,'quotes, comma and Unicode value preserved');
        is($row->[$col{collector}],$collector,'collector text preserved');
    }
};
subtest 'Accepted metadata and all original request keys remain recoverable' => sub {
    my $data=record('12');
    $data->{additionalInfo}={label=>'metadata, "quoted" зразок',zero=>0};
    $data->{externalReferences}=[{referenceID=>'source,id "A"',referenceSource=>'audit'}];
    $data->{studyDbId}='401';
    $data->{observationVariableName}='Optional variable name';
    my ($header,$row)=table(archive([$data]));
    ok($row,'metadata request has a complete actual CSV record');
    my %col=map {$header->[$_]=>$_} 0..$#$header;
    for my $name(qw(additionalInfo externalReferences requestJSON)) {
        ok(exists($col{$name}),"$name archived");
    }
    if ($row && exists($col{additionalInfo}) && exists($col{externalReferences}) && exists($col{requestJSON})) {
        is_deeply(decode_json($row->[$col{additionalInfo}]),$data->{additionalInfo},'additionalInfo round trip');
        is_deeply(decode_json($row->[$col{externalReferences}]),$data->{externalReferences},'externalReferences round trip');
        is_deeply(decode_json($row->[$col{requestJSON}]),$data,'full incoming record retained, including optional keys');
    }
};
subtest 'Zero and empty scalar fields retain their distinct values' => sub {
    my $data=record(0);$data->{collector}='';$data->{observationTimeStamp}='';
    my ($header,$row)=table(archive([$data]));
    my %col=map {$header->[$_]=>$_} 0..$#$header;
    is($row->[$col{value}],'0','zero is retained');
    is($row->[$col{collector}],'','empty collector retained');
    is($row->[$col{observationTimeStamp}],'','empty timestamp retained');
};
is_deeply([glob("$dir/input/*")],[],'temporary input files removed after archive copy');
done_testing;
