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
my $trial_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'Preliminary Yield Trial', 'project_type')->cvterm_id();

my $mech = Test::WWW::Mechanize->new;
$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username" => "janedoe", "password" => "secretpw", "grant_type" => "password" ]);

sub upload_trial {
    my ($trial_name, @rows) = @_;
    my ($fh, $filename) = tempfile('collect_date_test_XXXX', SUFFIX => '.csv', TMPDIR => 1, UNLINK => 1);
    print $fh join(',', 'plot_name', 'accession_name', 'plot_number', 'block_number', qq{"$trait_name"}, qq{"$treatment_name"}) . "\n";
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

my $response = upload_trial('collect_date_test_trial',
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

$response = upload_trial('collect_date_test_bad_timestamp',
    [ 'collect_date_test_bad_plot1', 'test_accession1', 1, 1, '30,2025-06-15', '1' ],
);
like($response->{error_string} // '', qr/Bad timestamp/, 'a malformed timestamp is rejected');
ok(!$schema->resultset('Project::Project')->find({ name => 'collect_date_test_bad_timestamp' }), 'trial with a malformed timestamp is not created');

$f->clean_up_db();

done_testing();
