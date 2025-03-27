use strict;
use warnings;

use Test::More;
use JSON;
use CXGN::DB::Connection;
use lib 't/lib';
use SGN::Test::WWW::Mechanize;
use SGN::Test::Fixture;
use File::Basename;
use CXGN::Image;
use CXGN::Stock;
use CXGN::Chado::Stock;
use Data::Dumper;

local $data::Dumper::Indent = 0;

my $m = SGN::Test::WWW::Mechanize->new;
my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;

my $test_file = 't/data/tv_test_1.png';

$m->post_ok('http://localhost:3010/brapi/v2/token', [
    "username" => "janedoe",
    "password" => "secretpw",
    "grant_type" => "password"
]);

my $response = decode_json $m->content;
is($response->{'metadata'}->{'status'}->[2]->{'message'}, 'Login Successfull', "Login successful");

my $sgn_session_id = $response->{access_token};
ok($sgn_session_id, "Received access token: $sgn_session_id");

# Use the session ID in subsequent requests
$m->add_header('Authorization' => "Bearer $sgn_session_id");

my $plot_id = $schema->resultset('Stock::Stock')->find({uniquename => 'test_trial212'})->stock_id();
ok($plot_id, "Fetched plot_id: $plot_id");

# Test image upload
$m->get_ok("/image/add?type=stock&type_id=$plot_id");

# Test image upload form
$m->get_ok("/image/add?action=new&type=stock&type_id=$plot_id");

my %form = (
    form_name => 'upload_image_form',
    fields => {
        file => $test_file,
        type => 'stock',
        type_id => $plot_id,
        refering_page => 'http://google.com',
    },
);

$m->submit_form_ok(\%form, "form submit test");
$m->content_like(qr/image\s+uploaded/, "content test 1", "check basic content");
$m->content_contains('http://google.com', "check referer");

my $store_form = {
    form_name => 'store_image',
};

$m->submit_form_ok($store_form, "Submitting the image for storage");
$m->content_contains('SGN Image');
$m->content_contains(basename($test_file));

my $uri = $m->uri();
my $image_id = "";
if ($uri =~ /\/(\d+)$/) {
    $image_id = $1;
}

diag "Image ID: $image_id";

$m->post_ok("/ajax/search/images?image_stock_uniquename=test_trial212");
my $search_response = eval { decode_json $m->content };

diag "Search response: " . Dumper($search_response);

my $image_found = grep { $_->[1] =~ /\/image\/view\/$image_id/ } @{$search_response->{data}};
ok($image_found, "Image returned in search results");

my $dbh = SGN::Test::Fixture->new()->dbh();

my $i = CXGN::Image->new(dbh => $dbh, image_id => $image_id, image_dir => $m->context->config->{'image_dir'});

$i->hard_delete();

my $sth = $dbh->prepare("SELECT COUNT(*) FROM metadata.md_image WHERE image_id = ?");
$sth->execute($image_id);
my ($count) = $sth->fetchrow_array();
ok($count == 0, "Image record deleted from metadata.md_image");

$f->clean_up_db();

done_testing();
