
use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use LWP::UserAgent;
use CXGN::List;

use Data::Dumper;
use JSON::XS;
use SGN::Model::Cvterm;
local $Data::Dumper::Indent = 0;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;

my $mech = Test::WWW::Mechanize->new;

$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ]);
my $response = JSON::XS->new->decode($mech->content);
print STDERR "\n\nResponse from token call: ".Dumper $response;
is($response->{'metadata'}->{'status'}->[2]->{'message'}, 'Login Successfull');
my $sgn_session_id = $response->{access_token};
print STDERR "\n\nsgn_session_id = $sgn_session_id\n";

my $breeding_program_id = $schema->resultset('Project::Project')->find({name=>'test'})->project_id();

my $file = $f->config->{basepath}."/t/data/stock/test_grafts.csv";
my $ua = LWP::UserAgent->new;
$response = $ua->post(
        'http://localhost:3010/ajax/grafts/upload_verify',
        Content_Type => 'form-data',
        Content => [
            graft_uploaded_file => [ $file, 'graft_uploaded_file', Content_Type => 'text/html', ],
            sgn_session_id => $sgn_session_id,
        ]
    );

print STDERR Dumper $response;
ok($response->is_success);

my $message = $response->decoded_content;
print STDERR "MESSAGE: $message\n";
my $message_hash = JSON::XS->new->decode($message);

print STDERR "Uploaded filename: $message_hash->{archived_filename_with_path}\n";
is_deeply($message_hash->{'success'}, 1);
my $added_grafts = $message_hash->{'added_grafts'};

#$file = $f->config->{basepath}."/t/data/stock/test_grafts.csv";
$ua = LWP::UserAgent->new;
$response = $ua->post(
    "http://localhost:3010/ajax/grafts/upload_store?archived_filename=$message_hash->{archived_filename_with_path}&sgn_session_id=$sgn_session_id"
    );

print STDERR Dumper $response;
ok($response->is_success);
my $message = $response->decoded_content;
my $message_hash = JSON::XS->new()->decode($message);

is_deeply($message_hash->{'success'}, 1);
my $added_grafts = $message_hash->{'added_grafts'};

# check if grafted accessions were created using List validation
#
my $graft_list_id = CXGN::List::create_list($f->dbh(), 'test_graft_list', 'test_desc', 41);
my $graft_list = CXGN::List->new( { dbh => $f->dbh(), list_id => $graft_list_id } );
$graft_list->type("accessions");
$graft_list->add_bulk( [ 'test_accession1+test_accession2', 'test_accession3+test_accession4' ]);
my $items = $graft_list->elements();
my $items_list = $items->[0];

print STDERR "ITEMS ".Dumper($items_list);
my $validation = CXGN::List::Validate->new();
$validation->validate($schema, 'accessions', $items_list);

print STDERR Dumper($validation);

# clean up
#
$f->clean_up_db();

done_testing();
