use strict;
use lib 't/lib';

use Test::More;
use SGN::Test::Fixture;

use Data::Dumper;
use CXGN::Trial;
use CXGN::Trial::TrialLayoutDownload;
use Test::WWW::Mechanize;
use LWP::UserAgent;
use JSON;

my $test = SGN::Test::Fixture->new();
my $schema = $test->bcs_schema;

my $mech = Test::WWW::Mechanize->new;

$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ]);
my $response = decode_json $mech->content;
print STDERR Dumper $response;
is($response->{'metadata'}->{'status'}->[2]->{'message'}, 'Login Successfull');
my $sgn_session_id = $response->{access_token};
print STDERR $sgn_session_id."\n";

my $trial_id = $schema->resultset('Project::Project')->find({name=>'test_trial'})->project_id();

my $file = $test->config->{basepath}."/t/data/trial/field_coord_upload.csv";
print STDERR "Upload file path: $file \n";
my $ua = LWP::UserAgent->new;
$response = $ua->post(
        'http://localhost:3010/ajax/breeders/trial/coordsupload',
        Content_Type => 'form-data',
        Content => [
            trial_coordinates_uploaded_file => [ $file, 'coords_upload', Content_Type => 'application/octet-stream', ],
            "trial_coordinates_upload_trial_id"=>$trial_id,
            "sgn_session_id"=>$sgn_session_id
        ]
    );

sleep(20);

#print STDERR Dumper $response;
ok($response->is_success);
my $message = $response->decoded_content;
my $message_hash = decode_json $message;
print STDERR Dumper $message_hash;

my $trial_layout_download = CXGN::Trial::TrialLayoutDownload->new({
    schema => $schema,
    trial_id => $trial_id,
    data_level => 'plot_fieldMap',
    selected_columns => {
               'accession_name' => 1,
               'col_number' => 1,
               'row_number' => 1
             },
});
my $output = $trial_layout_download->get_layout_output();
my %hash = %{$output->{output}};
print STDERR Dumper \%hash;

is_deeply(\%hash, {
          '4' => {
                   '3' => 'test_accession5',
                   '1' => 'test_accession3',
                   '2' => 'test_accession1'
                 },
          '2' => {
                   '3' => 'test_accession4',
                   '2' => 'test_accession1',
                   '1' => 'test_accession3'
                 },
          '1' => {
                   '3' => 'test_accession3',
                   '1' => 'test_accession4',
                   '2' => 'test_accession5'
                 },
          '3' => {
                   '3' => 'test_accession2',
                   '2' => 'test_accession1',
                   '1' => 'test_accession5'
                 },
          '5' => {
                   '2' => 'test_accession4',
                   '1' => 'test_accession2',
                   '3' => 'test_accession2'
                 }
        });

my $trial_layout = CXGN::Trial::TrialLayout->new({
   schema => $schema,
   trial_id => $trial_id,
   experiment_type => 'field_layout'
});
my $tl = $trial_layout->get_design();

#Remove row_number and col_number so tests downstream don't fail
foreach (values %$tl) {
    my $stock = CXGN::Stock->new({
        schema => $schema,
        stock_id => $_->{plot_id}
    });
    $stock->_remove_stockprop('row_number', $_->{row_number});
    $stock->_remove_stockprop('col_number', $_->{col_number});
}
$trial_layout->generate_and_cache_layout();


done_testing();

       