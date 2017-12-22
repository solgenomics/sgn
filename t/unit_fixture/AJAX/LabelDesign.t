
use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use Data::Dumper;
use JSON;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;

my $mech = Test::WWW::Mechanize->new;

$mech->get_ok("http://localhost:3010//tools/label_designer/retrieve_longest_fields?data_type=Trials&value=139");
my $response = decode_json $mech->content;

my $expected_response = (
    "accession_name" => "UG120054",
    "trial_name" => "Kasese solgs trial",
    "year" => "2014",
    "plot_number" => "35667",
    "rep_number" => "1",
    "block_number" => "10",
    "accession_id" => 38926,
    "plot_id" => 39295,
    "plot_name" => "KASESE_TP2013_1000",
    "pedigree_string" => "NA/NA"
);

is($response, $expected_response, 'retrieve longest fields test');

my $download_type = 'pdf';
my $data_type = 'Trials';
my $value = 139;
my $selected_columns = encode_json {'plot_name'=>1,'block_number'=>1,'plot_number'=>1,'rep_number'=>1,'row_number'=>1,'col_number'=>1,'accession_name'=>1,'is_a_control'=>1,'pedigree'=>1,'location_name'=>1,'trial_name'=>1,'year'=>1,'synonyms'=>1,'tier'=>1,'seedlot_name'=>1,'seed_transaction_operator'=>1,'num_seed_per_plot'=>1};

my $design_json = encode_json {
   "page_format" => "US Letter PDF",
   "page_width" => 611,
   "page_height" => 790.7,
   "left_margin" => 13.68,
   "top_margin" => 36.7,
   "horizontal_gap" => 10,
   "vertical_gap" => 0,
   "number_of_columns" => 3,
   "number_of_rows" => 10,
   "copies_per_plot" => "1",
   "sort_order" => "plot_number",
   "label_format" => "1\" x 2 5/8\"",
   "label_width" => 189,
   "label_height" => 72,
   "label_elements" => [
      {
         "x" => 113.5,
         "y" => 105.5,
         "height" => 125,
         "width" => 125,
         "value" => "{plot_name}",
         "type" => "QRCode",
         "font" => "Courier",
         "size" => "5"
      },
      {
         "x" => 343,
         "y" => 111,
         "height" => 56.140625,
         "width" => 241.21875,
         "value" => "{accession_name}",
         "type" => "PDFText",
         "font" => "Courier-Bold",
         "size" => "50"
     },
     {
         "x" => 323,
         "y" => 167,
         "height" => 38,
         "width" => 242,
         "value" => "{trial_name}",
         "type" => "Code128",
         "font" => "Courier",
         "size" => "1"
      },
      {
         "x" => 323,
         "y" => 90,
         "height" => 26.640625,
         "width" => 146.53125,
         "value" => "Plot =>  {plot_number}",
         "type" => "PDFText",
         "font" => "Courier",
         "size" => "23"
      },
      {
         "x" => 318,
         "y" => 121,
         "height" => 26.640625,
         "width" => 159.84375,
         "value" => "NIR: 17-{Number:0001:1}",
         "type" => "PDFText",
         "font" => "Courier",
         "size" => "23"
      }
   ]
};

$mech->post_ok('http://localhost:3010/tools/label_designer/download', [ 'download_type' => $download_type, 'data_type' => $data_type, 'value'=> $value, 'design_json' => $design_json ]);
$response = decode_json $mech->content;
print STDERR Dumper $response;
is($response->{'filename'}, '');


done_testing;
