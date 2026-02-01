
use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use LWP::UserAgent;
use CXGN::List;
use CXGN::Stock::Seedlot;
use JSON;
use Data::Dumper;
use JSON::XS;
use SGN::Model::Cvterm;
local $Data::Dumper::Indent = 0;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;
my $phenome_schema = $f->phenome_schema;
my $json = JSON->new->allow_nonref;

my $mech = Test::WWW::Mechanize->new;

my $rs = $f->bcs_schema()->resultset('NaturalDiversity::NdExperiment')->search({});

my $max_nd_experiment_id = $rs->get_column('nd_experiment_id')->max();

print STDERR "MAX ND EXPERIMENT ID = $max_nd_experiment_id\n";

$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ]);
my $response = JSON::XS->new->decode($mech->content);
print STDERR Dumper $response;
is($response->{'metadata'}->{'status'}->[2]->{'message'}, 'Login Successfull');
my $sgn_session_id = $response->{access_token};


### Upload XLS file autogenerating uniquename

my $file = $f->config->{basepath}."/t/data/stock/vector_upload_no_uniquename.xls";
my $ua = LWP::UserAgent->new;
$response = $ua->post(
        'http://localhost:3010/ajax/vectors/verify_vectors_file',
        Content_Type => 'form-data',
        Content => [
            new_vectors_upload_file => [ $file, 'new_vectors_upload_file.xls', Content_Type => 'text/html', ],
            sgn_session_id => $sgn_session_id,
            fuzzy_check_upload_vectors => 1,
            autogenerate_uniquename => 1,
        ]
    );


ok($response->is_success);
my $message = $response->decoded_content;
my $message_hash = JSON::XS->new->decode($message);
is_deeply($message_hash->{'success'}, 1);

my $verified_vectors = $message_hash->{'full_data'};
my $data;
while (my ($key, $value) = each %{$verified_vectors}) {
    push @$data, $value;
}

$mech->post_ok('http://localhost:3010/ajax/create_vector_construct', [ 'data'=>$json->encode($data)]);

my $response = JSON::XS->new->decode($mech->content);
print STDERR Dumper $response;
is($response->{'success'}, 1);

my $ids = $response->{'added'};
my @stock_ids;

foreach (@$ids) {
    push @stock_ids,$_->[0];
}

### Upload XLS file with uniquename

my $file = $f->config->{basepath}."/t/data/stock/vector_upload_with_uniquename.xls";
my $ua = LWP::UserAgent->new;
$response = $ua->post(
        'http://localhost:3010/ajax/vectors/verify_vectors_file',
        Content_Type => 'form-data',
        Content => [
            new_vectors_upload_file => [ $file, 'new_vectors_upload_file.xls', Content_Type => 'text/html', ],
            sgn_session_id => $sgn_session_id,
            fuzzy_check_upload_vectors => 1,
            autogenerate_uniquename => 0,
        ]
    );

ok($response->is_success);
my $message = $response->decoded_content;
my $message_hash = JSON::XS->new->decode($message);
is_deeply($message_hash->{'success'}, 1);

my $verified_vectors = $message_hash->{'full_data'}; print STDERR "\n\nverified:" . Dumper \$verified_vectors;
my $data;
while (my ($key, $value) = each %{$verified_vectors}) {
    push @$data, $value;
}

$mech->post_ok('http://localhost:3010/ajax/create_vector_construct', [ 'data'=>$json->encode($data)]);

my $response = JSON::XS->new->decode($mech->content);
is($response->{'success'}, 1);

my $ids2 = $response->{'added'};

foreach (@$ids2) {
    push @stock_ids,$_->[0];
}


### Upload XLSX file autogenerating uniquename

my $file = $f->config->{basepath}."/t/data/stock/vector_upload_no_uniquename.xlsx";
my $ua = LWP::UserAgent->new;
$response = $ua->post(
        'http://localhost:3010/ajax/vectors/verify_vectors_file',
        Content_Type => 'form-data',
        Content => [
            new_vectors_upload_file => [ $file, 'new_vectors_upload_file.xlsx', Content_Type => 'text/html', ],
            sgn_session_id => $sgn_session_id,
            fuzzy_check_upload_vectors => 1,
            autogenerate_uniquename => 1,
        ]
    );


ok($response->is_success);
my $message = $response->decoded_content;
my $message_hash = JSON::XS->new->decode($message);
is_deeply($message_hash->{'success'}, 1);

my $verified_vectors = $message_hash->{'full_data'};
my $data;
while (my ($key, $value) = each %{$verified_vectors}) {
    push @$data, $value;
}

$mech->post_ok('http://localhost:3010/ajax/create_vector_construct', [ 'data'=>$json->encode($data) ]);

my $response = JSON::XS->new->decode($mech->content);
print STDERR Dumper $response;
is($response->{'success'}, 1);

my $ids3 = $response->{'added'};
my @stock_ids;

foreach (@$ids3) {
    push @stock_ids,$_->[0];
}

### Upload XLSX file with uniquename

my $file = $f->config->{basepath}."/t/data/stock/vector_upload_with_uniquename.xlsx";
my $ua = LWP::UserAgent->new;
$response = $ua->post(
        'http://localhost:3010/ajax/vectors/verify_vectors_file',
        Content_Type => 'form-data',
        Content => [
            new_vectors_upload_file => [ $file, 'new_vectors_upload_file.xlsx', Content_Type => 'text/html', ],
            sgn_session_id => $sgn_session_id,
            fuzzy_check_upload_vectors => 1,
            autogenerate_uniquename => 0,
        ]
    );

ok($response->is_success);
my $message = $response->decoded_content;
my $message_hash = JSON::XS->new->decode($message);
is_deeply($message_hash->{'success'}, 1);

my $verified_vectors = $message_hash->{'full_data'}; print STDERR "\n\nverified:" . Dumper \$verified_vectors;
my $data;
while (my ($key, $value) = each %{$verified_vectors}) {
    push @$data, $value;
}

$mech->post_ok('http://localhost:3010/ajax/create_vector_construct', [ 'data'=>$json->encode($data)]);

my $response = JSON::XS->new->decode($mech->content);
is($response->{'success'}, 1);

my $ids4 = $response->{'added'};

foreach (@$ids4) {
    push @stock_ids,$_->[0];
}

#Clean up
# Delete stocks created
my $dbh = $schema->storage->dbh;
my $q = "delete from phenome.stock_owner where stock_id=?";
my $h = $dbh->prepare($q);

foreach (@stock_ids){
    my $row  = $schema->resultset('Stock::Stock')->find({stock_id=>$_});
    $h->execute($_);
    $row->delete();
}

$f->clean_up_db();

done_testing();
