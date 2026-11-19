# Trait and treatment values in a trial upload are dated with the timestamp given in their cell
# ("value,YYYY-MM-DD HH:MM:SS-0000"), or left without a collection date; never with the upload time.

use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use File::Temp qw(tempfile);
use JSON;
use CXGN::Trait::Treatment;
use SGN::Model::Cvterm;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema();
my $dbh = $schema->storage->dbh();

my $treatment = CXGN::Trait::Treatment->new({
    bcs_schema => $schema,
    name => 'collect date test treatment',
    definition => 'A treatment used to test collection dates in trial uploads.',
    format => 'numeric'
});
$treatment->store(encode_json(['Experimental treatment ontology|EXPERIMENT_TREATMENT:0000000']));
my ($treatment_name) = $dbh->selectrow_array(
    "SELECT cvterm.name || '|' || db.name || ':' || dbxref.accession FROM cvterm JOIN dbxref USING(dbxref_id) JOIN db USING(db_id) WHERE cvterm_id = ?",
    undef, $treatment->cvterm_id());
my $trait_name = 'dry matter content percentage|CO_334:0000092';
# The only fixture trait with a trait_format, which StorePhenotypes needs to reject non-numeric values
my $numeric_trait_name = 'fresh root weight|CO_334:0000012';
my $trial_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'Preliminary Yield Trial', 'project_type')->cvterm_id();

my $mech = Test::WWW::Mechanize->new;
$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username" => "janedoe", "password" => "secretpw", "grant_type" => "password" ]);

sub upload_trial {
    my ($trial_name, $trait, @rows) = @_;
    my ($fh, $filename) = tempfile('collect_date_test_XXXX', SUFFIX => '.csv', TMPDIR => 1, UNLINK => 1);
    print $fh join(',', 'plot_name', 'accession_name', 'plot_number', 'block_number', qq{"$trait"}, qq{"$treatment_name"}) . "\n";
    print $fh join(',', map { qq{"$_"} } @$_) . "\n" for @rows;
    close($fh);
    $mech->post('http://localhost:3010/ajax/trial/upload_trial_file',
        Content_Type => 'form-data',
        Content => [
            trial_upload_breeding_program => 'test',
            trial_upload_location => 'test_location',
            trial_upload_name => $trial_name,
            trial_upload_year => '2025',
            trial_upload_description => 'Collection date test',
            trial_upload_trial_type => $trial_type_id,
            trial_upload_design_method => 'RCBD',
            trial_upload_trial_stock_type => 'accession',
            upload_trial_trial_will_be_genotyped => 'no',
            upload_trial_trial_will_be_crossed => 'no',
            upload_trial_ignore_warnings => 1,
            trial_uploaded_file => [ $filename ]
        ]
    );
    return decode_json($mech->content);
}

sub collect_dates {
    my ($plot_name, $term) = @_;
    my ($cvterm_name) = split /\|/, $term;
    return $dbh->selectcol_arrayref(
        "SELECT phenotype.collect_date FROM phenotype JOIN nd_experiment_phenotype USING(phenotype_id) JOIN nd_experiment_stock USING(nd_experiment_id)
         JOIN stock USING(stock_id) JOIN cvterm ON (phenotype.cvalue_id = cvterm.cvterm_id) WHERE stock.uniquename = ? AND cvterm.name = ?",
        undef, $plot_name, $cvterm_name);
}

my $response = upload_trial('collect_date_test_trial', $trait_name,
    [ 'collect_date_test_plot1', 'test_accession1', 1, 1, '30,2025-06-15 10:30:00-0500', '1,2025-05-01 08:00:00+0000' ],
    [ 'collect_date_test_plot2', 'test_accession2', 2, 1, '31', '1' ],
);
ok($response->{success}, 'trial with trait and treatment values uploads') or diag(explain $response);

is_deeply(collect_dates('collect_date_test_plot1', $trait_name), ['2025-06-15 10:30:00'], 'trait value with a timestamp is dated with it');
is_deeply(collect_dates('collect_date_test_plot1', $treatment_name), ['2025-05-01 08:00:00'], 'treatment value with a timestamp is dated with it');
is_deeply(collect_dates('collect_date_test_plot2', $trait_name), [undef], 'trait value without a timestamp has no collection date');
is_deeply(collect_dates('collect_date_test_plot2', $treatment_name), [undef], 'treatment value without a timestamp has no collection date');

my ($stored_value) = $dbh->selectrow_array(
    "SELECT phenotype.value FROM phenotype JOIN nd_experiment_phenotype USING(phenotype_id) JOIN nd_experiment_stock USING(nd_experiment_id)
     JOIN stock USING(stock_id) WHERE stock.uniquename = 'collect_date_test_plot1' AND phenotype.cvalue_id = ?", undef, $treatment->cvterm_id());
is($stored_value, '1', 'the timestamp is not stored as part of the value');

$response = upload_trial('collect_date_test_bad_timestamp', $trait_name,
    [ 'collect_date_test_bad_plot1', 'test_accession1', 1, 1, '30,2025-06-15', '1' ],
);
like($response->{error_string} // '', qr/Bad timestamp/, 'a malformed timestamp is rejected');
ok(!$schema->resultset('Project::Project')->find({ name => 'collect_date_test_bad_timestamp' }), 'trial with a malformed timestamp is not created');

# A value that fails verification (text in a numeric trait) refuses the whole upload instead of leaving a trial without values
$response = upload_trial('invalid_value_test_trial', $numeric_trait_name,
    [ 'invalid_value_test_plot1', 'test_accession1', 1, 1, '30', '1' ],
    [ 'invalid_value_test_plot2', 'test_accession2', 2, 1, 'not a number', '1' ],
);
like($response->{error} // '', qr/trial was not saved.*trait\/treatment values are invalid/s, 'an invalid trait value is reported as a trait/treatment value error') or diag(explain $response);
ok(!$schema->resultset('Project::Project')->find({ name => 'invalid_value_test_trial' }), 'trial with an invalid trait value is not created');
ok(!$schema->resultset('Stock::Stock')->find({ uniquename => $_ }), "$_ is not created") for qw(invalid_value_test_plot1 invalid_value_test_plot2);

# The multiple trial upload refuses all trials in the file when a value is invalid
my ($multi_fh, $multi_file) = tempfile('invalid_value_multi_XXXX', SUFFIX => '.csv', TMPDIR => 1, UNLINK => 1);
print $multi_fh join(',', qw(trial_name breeding_program location year design_type description accession_name plot_number block_number plot_name), qq{"$numeric_trait_name"}) . "\n";
print $multi_fh join(',', map { qq{"$_"} } @$_) . "\n" for (
    [ 'invalid_value_multi_trial1', 'test', 'test_location', 2025, 'RCBD', 'multi test', 'test_accession1', 1, 1, 'invalid_value_multi_plot1', '30' ],
    [ 'invalid_value_multi_trial2', 'test', 'test_location', 2025, 'RCBD', 'multi test', 'test_accession2', 1, 1, 'invalid_value_multi_plot2', 'not a number' ],
);
close($multi_fh);
my $config = $f->config;
my $multi_output = `perl bin/upload_multiple_trial_design.pl -H "$config->{dbhost}" -D "$config->{dbname}" -U "$config->{dbuser}" -P "$config->{dbpass}" -w "$config->{basepath}" -i "$multi_file" -un janedoe -iw 2>&1`;
# The web upload reports the script's "ERROR:" lines to the user
like($multi_output, qr/^ERROR: The trials were not saved because some trait\/treatment values are invalid/m, 'multiple trial upload reports the invalid value') or diag($multi_output);
ok(!$schema->resultset('Project::Project')->find({ name => $_ }), "$_ is not created") for qw(invalid_value_multi_trial1 invalid_value_multi_trial2);

# A valid multiple trial upload stores its values with the timestamps given in the cells; a file without value columns stores none
sub upload_multi {
    my ($header, @rows) = @_;
    my ($fh, $file) = tempfile('valid_multi_XXXX', SUFFIX => '.csv', TMPDIR => 1, UNLINK => 1);
    print $fh join(',', map { qq{"$_"} } @$header) . "\n";
    print $fh join(',', map { qq{"$_"} } @$_) . "\n" for @rows;
    close($fh);
    my $output = `perl bin/upload_multiple_trial_design.pl -H "$config->{dbhost}" -D "$config->{dbname}" -U "$config->{dbuser}" -P "$config->{dbpass}" -w "$config->{basepath}" -i "$file" -un janedoe -iw 2>&1`;
    return $output;
}

# The web upload treats the job as failed when the script prints "ERROR:" lines (the exit code is not used)
sub multi_upload_ok {
    my ($label, $output) = @_;
    my @errors = $output =~ m/^(ERROR: .*)$/mg;
    ok(!@errors, $label) or diag(join("\n", @errors));
}
my @multi_columns = qw(trial_name breeding_program location year design_type description accession_name plot_number block_number plot_name);

my $output = upload_multi([ @multi_columns, $numeric_trait_name ],
    [ 'valid_multi_trial', 'test', 'test_location', 2025, 'RCBD', 'multi test', 'test_accession1', 1, 1, 'valid_multi_plot1', '12,2025-07-01 09:00:00+0000' ],
    [ 'valid_multi_trial', 'test', 'test_location', 2025, 'RCBD', 'multi test', 'test_accession2', 2, 1, 'valid_multi_plot2', '13' ],
);
multi_upload_ok('valid multiple trial upload succeeds', $output);
is_deeply(collect_dates('valid_multi_plot1', $numeric_trait_name), ['2025-07-01 09:00:00'], 'multiple trial upload: value with a timestamp is dated with it');
is_deeply(collect_dates('valid_multi_plot2', $numeric_trait_name), [undef], 'multiple trial upload: value without a timestamp has no collection date');

$output = upload_multi([ @multi_columns ],
    [ 'valid_multi_no_values', 'test', 'test_location', 2025, 'RCBD', 'multi test', 'test_accession1', 1, 1, 'valid_multi_no_values_plot1' ],
);
multi_upload_ok('multiple trial upload without value columns succeeds', $output);
ok($schema->resultset('Project::Project')->find({ name => 'valid_multi_no_values' }), 'trial without value columns is created');

$f->clean_up_db();

done_testing();
