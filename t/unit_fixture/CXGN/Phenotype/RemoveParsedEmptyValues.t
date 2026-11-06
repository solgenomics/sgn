use strict;
use warnings;

use lib 't/lib';
use Test::More;
use File::Temp qw(tempdir);
use Text::CSV;
use Excel::Writer::XLSX;
use SGN::Test::Fixture;
use SGN::Model::Cvterm;
use CXGN::Trial::TrialCreate;
use CXGN::Phenotypes::ParseUpload;
use CXGN::Phenotypes::StorePhenotypes;

my $f = SGN::Test::Fixture->new;
END { $f->clean_up_db() if $f; }
my $schema = $f->bcs_schema;
my $directory = tempdir(CLEANUP => 1);
my $name = "parsed_empty_$$";
my %design = map { $_ => {
    plot_name => "${name}_$_", plot_number => $_,
    stock_name => 'test_accession1', block_number => 1, rep_number => 1,
    row_number => 1, col_number => $_,
} } 1 .. 2;
my $created = CXGN::Trial::TrialCreate->new({
    chado_schema => $schema, dbh => $f->dbh, owner_id => 41,
    operator => 'janedoe', program => 'test', trial_location => 'test_location',
    trial_name => $name, trial_description => 'Synthetic parsed missing-marker regression',
    trial_year => 2030, design_type => 'CRD', design => \%design,
})->save_trial;
ok($created->{trial_id}, 'created an independent synthetic trial') or BAIL_OUT('trial setup failed');
my ($plot, $neighbor) = ("${name}_1", "${name}_2");
my $single_id = 70741;
my $single_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $single_id, 'extended');

# A separate temporary trait avoids changing the repeat type of fixture traits.
my $template = $schema->resultset('Cv::Cvterm')->find($single_id);
my $xref = $schema->resultset('General::Dbxref')->create({
    db_id => $template->dbxref->db_id, accession => "990$$",
});
my $multiple = $schema->resultset('Cv::Cvterm')->create({
    name => "Synthetic repeated marker $$", cv_id => $template->cv_id,
    dbxref_id => $xref->dbxref_id,
    definition => 'Temporary trait created and removed by a regression test',
});
# The upload validator accepts variables linked to an underlying trait.
for my $relationship ($template->cvterm_relationship_subjects->search(
    {'type.name' => 'VARIABLE_OF'}, {join => 'type'})->all) {
    $schema->resultset('Cv::CvtermRelationship')->create({
        subject_id => $multiple->cvterm_id, object_id => $relationship->object_id,
        type_id => $relationship->type_id,
    });
}
my $repeat_type = SGN::Model::Cvterm->get_cvterm_row($schema, 'trait_repeat_type', 'trait_property')->cvterm_id;
$multiple->create_related('cvtermprops', {type_id => $repeat_type, value => 'multiple'});
my $multiple_id = $multiple->cvterm_id;
my $multiple_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $multiple_id, 'extended');
my $sequence = 0;

sub upload_file {
    my ($unit, $trait, $value, $overwrite, $remove, $timestamps, $extension, $image_id) = @_;
    $extension ||= 'csv';
    my $file = "$directory/upload_".(++$sequence).".$extension";
    my @rows = (['observationUnitName', $trait], [$unit, $value]);
    if ($extension eq 'xlsx') {
        my $book = Excel::Writer::XLSX->new($file);
        my $sheet = $book->add_worksheet;
        $sheet->write_row(0, 0, $rows[0]);
        $sheet->write_row(1, 0, $rows[1]);
        $book->close;
    }
    else {
        my $csv = Text::CSV->new({binary => 1, eol => "\n"});
        open(my $out, '>', $file) or die "Cannot write $file: $!";
        $csv->print($out, $_) or die $csv->error_diag for @rows;
        close $out or die "Cannot close $file: $!";
    }
    my $parser = CXGN::Phenotypes::ParseUpload->new;
    my $type = 'phenotype spreadsheet simple generic';
    my $validated = $parser->validate($type, $file, $timestamps, 'plots', $schema);
    is($validated, 1, "$extension input '$value' validates");
    my $parsed = $parser->parse($type, $file, $timestamps, 'plots', $schema);
    ok(!$parsed->{error}, "$extension input '$value' parses") or diag $parsed->{error};
    # Associated-image parsing is covered separately. Supply its image metadata
    # shape here to exercise the shared storage guard without uploading files.
    if (defined($image_id) && $parsed->{data}{$unit}{$trait}) {
        $_->[4] = $image_id for @{$parsed->{data}{$unit}{$trait}};
    }
    my $store = CXGN::Phenotypes::StorePhenotypes->new(
        basepath => $f->config->{basepath}, dbhost => $f->config->{dbhost},
        dbname => $f->config->{dbname}, dbuser => $f->config->{dbuser}, dbpass => $f->config->{dbpass},
        temp_file_nd_experiment_id => "$directory/experiment_$sequence",
        bcs_schema => $schema, metadata_schema => $f->metadata_schema,
        phenome_schema => $f->phenome_schema, user_id => 41,
        stock_list => $parsed->{units}, trait_list => $parsed->{variables},
        values_hash => $parsed->{data}, has_timestamps => $timestamps,
        overwrite_values => $overwrite, remove_values => $remove,
        metadata_hash => {archived_file => undef, archived_file_type => 'new stock phenotypes',
            operator => 'janedoe', date => '2030-05-20_12:00:00'},
        composable_validation_check_name => $f->config->{composable_validation_check_name},
    );
    my ($warning, $error) = $store->verify;
    return ($error, undef) if $error;
    my ($store_error, $success) = $store->store;
    return ($store_error, $success);
}

sub upload_ok {
    my @args = @_;
    my ($error, $success) = upload_file(@args);
    ok(!$error, "parsed '$args[2]' stores (overwrite=$args[3], remove=$args[4])") or diag $error;
    return $success || '';
}

sub observations {
    my ($unit, $trait_id) = @_;
    return $f->dbh->selectall_arrayref(q{
        SELECT DISTINCT phenotype.phenotype_id, phenotype.value, phenotype.collect_date
        FROM phenotype JOIN nd_experiment_phenotype USING(phenotype_id)
        JOIN nd_experiment_stock USING(nd_experiment_id) JOIN stock USING(stock_id)
        WHERE stock.uniquename=? AND phenotype.cvalue_id=?
        ORDER BY phenotype.collect_date, phenotype.phenotype_id
    }, undef, $unit, $trait_id);
}

sub values_for {
    return [map { $_->[1] } @{observations(@_)}];
}

upload_ok($neighbor, $single_name, '99', 1, 0, 0);
my $neighbor_before = observations($neighbor, $single_id);
for my $marker ('.', 'NA', '') {
    for my $flags ([0,0], [0,1], [1,0], [1,1]) {
        my ($overwrite, $remove) = @$flags;
        upload_ok($plot, $single_name, '42', 1, 0, 0);
        my $message = upload_ok($plot, $single_name, $marker, $overwrite, $remove, 0);
        my $deletes = $overwrite && $remove;
        is_deeply(values_for($plot, $single_id), $deletes ? [] : ['42'],
            "'$marker' removes only when both flags are enabled");
        like($message, qr/@{[$deletes ? 1 : 0]} previously stored values removed/,
            'removal count reflects the database result');
        is_deeply(observations($neighbor, $single_id), $neighbor_before,
            'neighboring plot observation is untouched');
    }
}

for my $marker ('.', 'NA', '') {
    upload_ok($plot, $single_name, '42', 1, 0, 0, 'xlsx');
    upload_ok($plot, $single_name, $marker, 1, 1, 0, 'xlsx');
    is_deeply(values_for($plot, $single_id), [], "XLSX '$marker' reaches deletion");
}
upload_ok($plot, $single_name, '0', 1, 1, 0, 'xlsx');
is_deeply(values_for($plot, $single_id), ['0'], 'measured zero is stored, not removed');

for my $marker ('.', 'NA') {
    for my $flags ([0,0], [0,1], [1,0]) {
        upload_ok($plot, $single_name, $marker, @$flags, 0, 'csv', 987654321);
        is_deeply(values_for($plot, $single_id), ['0'],
            "image metadata does not make '$marker' overwrite an existing zero");
    }
    upload_ok($plot, $single_name, $marker, 1, 1, 0, 'csv', 987654321);
    is_deeply(values_for($plot, $single_id), [], "'$marker' can remove with image metadata and both flags");
    upload_ok($plot, $single_name, $marker, 1, 0, 0, 'csv', 987654321);
    is_deeply(values_for($plot, $single_id), [], "'$marker' with image metadata does not create a missing observation");
    upload_ok($plot, $single_name, '0', 1, 0, 0);
}

my ($t1, $t2, $t3) = ('2030-05-20 09:00:00', '2030-05-20 10:00:00', '2030-05-20 11:00:00');
for my $marker ('.', 'NA') {
    upload_ok($plot, $multiple_name, "10,$t1|20,$t2", 1, 0, 1);
    my $before = observations($plot, $multiple_id);
    is(scalar @$before, 2, 'two timestamped observations are stored');
    for my $flags ([0,0], [0,1], [1,0]) {
        upload_ok($plot, $multiple_name, "$marker,$t1", @$flags, 1);
        is_deeply(observations($plot, $multiple_id), $before, 'disabled removal preserves both IDs and timestamps');
    }
    upload_ok($plot, $multiple_name, "$marker,$t1", 1, 1, 1);
    is_deeply(observations($plot, $multiple_id), [$before->[1]],
        'only the matching timestamp is removed; neighboring observation ID is unchanged');
    upload_ok($plot, $multiple_name, "$marker,$t3", 1, 1, 1);
    is_deeply(observations($plot, $multiple_id), [$before->[1]], 'unmatched timestamp removes nothing');
    my ($missing_time_error) = upload_file($plot, $multiple_name, $marker, 1, 1, 0);
    like($missing_time_error || '', qr/timestamp is required/, 'repeated-trait removal without timestamp is rejected');
    is_deeply(observations($plot, $multiple_id), [$before->[1]], 'rejected missing timestamp leaves data unchanged');
    upload_ok($plot, $multiple_name, "$marker,$t2", 1, 1, 1);
}

$f->clean_up_db();
is_deeply($f->get_db_stats(), $f->dbstats_start(), 'synthetic fixture rows are fully cleaned up');
undef $f;

done_testing();
