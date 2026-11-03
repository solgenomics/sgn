use strict;
use warnings;
use utf8;
use lib 't/lib';
use Test::More;
use SGN::Test::Fixture;
use SGN::Model::Cvterm;
use CXGN::Fieldbook::DownloadTrial;
use CXGN::Trial;
use CXGN::Trial::AccessionChange;
use CXGN::Trial::TrialLayout;
use CXGN::Trial::Download;
use CXGN::File::Parse;
use Spreadsheet::Read;
use File::Temp qw(tempdir);
use Digest::MD5 qw(md5_hex);
use Encode qw(decode_utf8);

my $f = SGN::Test::Fixture->new;
my $schema = $f->bcs_schema;
$schema->storage->auto_savepoint(1);
my $dir = tempdir(CLEANUP => 1);
my $trial = $schema->resultset('Project::Project')->find({name=>'test_trial'})->project_id;
my @files;
sub contents {
    open(my $fh, '<:raw', $_[0]) or die $!;
    local $/; my $body = <$fh>; close $fh; return $body;
}
sub fieldbook {
    my ($name, $cols, $level) = @_;
    my $r = CXGN::Fieldbook::DownloadTrial->new({
        bcs_schema=>$schema, metadata_schema=>$f->metadata_schema, phenome_schema=>$f->phenome_schema,
        trial_id=>$trial, tempfile=>"$dir/$name", archive_path=>"$dir/archive", user_id=>41, user_name=>'janedoe',
        data_level=>$level || 'plots', selected_columns=>$cols, include_treatments=>'false', include_measured=>'false', all_stats=>'false',
    })->download;
    die join('; ', @{$r->{error_messages}}) if $r->{error_messages};
    push @files, $r;
    return $r;
}
sub names_in {
    my ($file, $header) = @_;
    my $book = ReadData($file);
    die 'Cannot parse actual Field Book workbook' if !$book || !$book->[1];
    my $sheet = $book->[1];
    my ($col) = grep {($sheet->{cell}[$_][1] // '') eq $header} 1..$sheet->{maxcol};
    die "Missing $header" if !defined $col;
    return [map {$sheet->{cell}[$col][$_]} 2..$sheet->{maxrow}];
}
sub row_for_plot {
    my ($file, $plot_name) = @_;
    my $sheet = ReadData($file)->[1];
    my %col = map {($sheet->{cell}[$_][1] // '') => $_} 1..$sheet->{maxcol};
    my ($row) = grep {($sheet->{cell}[$col{plot_name}][$_] // '') eq $plot_name} 2..$sheet->{maxrow};
    die "No downloaded child row for $plot_name" if !defined $row;
    return {map {$_ => $sheet->{cell}[$col{$_}][$row]} keys %col};
}

$schema->txn_begin;
my $ran = eval {
    my $plot = $schema->resultset('Stock::Stock')->find({uniquename=>'test_trial215'});
    my $acc = $schema->resultset('Stock::Stock')->find({uniquename=>'test_accession2'});
    my $unicode_acc = $schema->resultset('Stock::Stock')->find({uniquename=>'test_accession3'});
    my $numeric_plot_name = '000'.time().$$;
    my $numeric_accession_name = '000'.time().($$+1);
    my $unicode_name = "artifact_A\x{a0}B, \"зразок\"";
    $plot->update({name=>$numeric_plot_name,uniquename=>$numeric_plot_name});
    $acc->update({name=>$numeric_accession_name,uniquename=>$numeric_accession_name});
    $unicode_acc->update({name=>$unicode_name,uniquename=>$unicode_name});
    CXGN::Trial::TrialLayout->new({schema=>$schema,trial_id=>$trial,experiment_type=>'field_layout'})->generate_and_cache_layout;

    my $first = fieldbook('first.xls', {plot_name=>1,accession_name=>1});
    my $before = contents($first->{file});
    my $second = fieldbook('second.xls', {plot_name=>1,plot_number=>1});
    isnt($first->{file}, $second->{file}, 'each generated file ID has a separate archived path');
    is(contents($first->{file}), $before, 'a later export cannot replace the first artifact');
    my $metadata = $f->metadata_schema->resultset('MdFiles')->find({file_id=>$first->{file_id}});
    is(md5_hex(contents($first->{file})), $metadata->md5checksum, 'saved checksum still names the actual first file');
    ok((grep {defined($_) && $_ eq $numeric_plot_name} @{names_in($first->{file},'plot_name')}), 'XLS plot name retains leading zeroes');
    ok((grep {defined($_) && $_ eq $numeric_accession_name} @{names_in($first->{file},'accession_name')}), 'XLS accession identity stays text');
    ok((grep {defined($_) && $_ eq $unicode_name} @{names_in($first->{file},'accession_name')}), 'XLS Unicode, internal NBSP, commas and quotes retained');

    my $xlsx = fieldbook('third.xlsx', {plot_name=>1,accession_name=>1});
    ok((grep {defined($_) && $_ eq $numeric_plot_name} @{names_in($xlsx->{file},'plot_name')}), 'XLSX plot name retains leading zeroes');
    ok((grep {defined($_) && $_ eq $numeric_accession_name} @{names_in($xlsx->{file},'accession_name')}), 'XLSX accession identity stays text');

    my $csv = "$dir/layout.csv";
    CXGN::Trial::Download->new({bcs_schema=>$schema,trial_id=>$trial,filename=>$csv,format=>'TrialLayoutCSV',data_level=>'plots',selected_columns=>{plot_name=>1,accession_name=>1}})->download;
    my $bytes = contents($csv);
    my $decoded = eval {decode_utf8($bytes,1)};
    ok(defined($decoded), 'actual layout CSV is valid UTF-8');
    my $parsed = CXGN::File::Parse->new(file=>$csv,required_columns=>[qw(plot_name accession_name)],optional_columns=>[],unique_only_columns=>['plot_name'])->parse;
    is_deeply($parsed->{errors}, [], 'actual layout CSV parses without errors');
    ok((grep {$_->{accession_name} eq $unicode_name} @{$parsed->{data}}), 'CSV producer/parser round trip retains exact Unicode identity');

    # Qualify all child dimensions through the platform's public creation
    # methods, including the required indexes/properties/layout membership.
    my $trial_object = CXGN::Trial->new({bcs_schema=>$schema,trial_id=>$trial,metadata_schema=>$f->metadata_schema,phenome_schema=>$f->phenome_schema});
    my $config = {map {$_=>$f->config->{$_}} qw(basepath dbhost dbname dbuser dbpass)};
    $config->{user_id}=41;$config->{temp_file_nd_experiment_id}="$dir/unused";
    $config->{metadata_hash}={operator=>'janedoe',date=>'2026-11-02'};
    die 'Plant setup failed' if !$trial_object->create_plant_entities(1,0,undef,undef,undef,undef,$config);
    die 'Tissue setup failed' if !$trial_object->create_tissue_samples(['leaf'],0,0,undef,undef,$config);
    die 'Subplot setup failed' if !$trial_object->create_subplot_entities(1,0,undef,undef,$config);
    my $rejected_plot = $schema->resultset('Stock::Stock')->find({uniquename=>'test_trial214'});
    my $reason = 'trampled, then "rain"';
    CXGN::Trial::AccessionChange->new({schema=>$schema,trial_id=>$trial})->apply([{plot_id=>$rejected_plot->stock_id,rejected=>1,reject_reason=>$reason}],{rename_plots=>'none',curator=>1});
    for my $level (qw(plants subplots field_trial_tissue_samples)) {
        my $r=fieldbook("status-$level.xls", {plot_name=>1,plant_name=>1,subplot_name=>1,tissue_sample_name=>1}, $level);
        my $marked=row_for_plot($r->{file},$rejected_plot->uniquename);
        is($marked->{rejected},1,"$level automatically exports inherited rejection");
        is($marked->{reject_reason},$reason,"$level exports its parent reason");
        my $valid=row_for_plot($r->{file},$numeric_plot_name);
        is($valid->{rejected},0,"$level normalizes the valid control flag to zero");
    }
    1;
};
my $error = $@;
$schema->txn_rollback;
# Remove only file records produced by this test; substantive fixture rows were
# rolled back. Archive files themselves belong to the temporary directory.
my $cleaned = eval {
    for my $r (@files) {
        my $file = $f->metadata_schema->resultset('MdFiles')->find({file_id=>$r->{file_id}})
            or die "Generated file record $r->{file_id} is missing";
        # metadata_id is also a relationship accessor in this schema. Bind its
        # scalar column value, never the related ORM object.
        my $metadata_id = $file->get_column('metadata_id');
        $f->phenome_schema->resultset('NdExperimentMdFiles')->search({file_id=>$r->{file_id}})->delete;
        $file->delete;
        my $metadata = $f->metadata_schema->resultset('MdMetadata')->find({metadata_id=>$metadata_id})
            or die "Generated metadata record $metadata_id is missing";
        $metadata->delete;
    }
    1;
};
my $cleanup_error = $@;
ok($ran, 'artifact scenarios completed and synthetic fixture changes restored') or diag("$error");
ok($cleaned, 'only this test generated-file records were removed') or diag("$cleanup_error");
done_testing;
