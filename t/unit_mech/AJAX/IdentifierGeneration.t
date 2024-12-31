
use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use CXGN::List;

#Needed to update IO::Socket::SSL
use Data::Dumper;
use JSON;
local $Data::Dumper::Indent = 0;

my $mech = Test::WWW::Mechanize->new;
my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;

my $response;

$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ]);
$response = decode_json $mech->content;
print STDERR Dumper $response;
is($response->{'metadata'}->{'status'}->[2]->{'message'}, 'Login Successfull');

$mech->get_ok('http://localhost:3010/ajax/breeders/new_identifier_generation?identifier_name=test_identifier_generation&identifier_prefix=ACTLNG&num_digits=6&current_number=1&description=test');
$response = decode_json $mech->content;
print STDERR Dumper $response;
my $new_list_id = $response->{new_list_id};
like($new_list_id, qr/\d+/, "list id is numeric check");

is_deeply($response, {'success' => 'Stored test_identifier_generation!','new_list_id' => $new_list_id}, 'test create identifier generation list entry');

$mech->get_ok('http://localhost:3010/ajax/breeders/identifier_generation_list');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'data' => [['test_identifier_generation','test','ACTLNG','6',1,'ACTLNG000001','<button class="btn btn-primary" name="identifier_generation_history" data-list_id="'.$new_list_id.'">View</button>','<div class="form-group"><label class="col-sm-4 control-label">Next Count: </label><div class="col-sm-8"> <input type="number" class="form-control" id="identifier_generation_next_numbers_'.$new_list_id.'" placeholder="EG: 100" /></div></div><button class="btn btn-primary" name="identifier_generation_download" data-list_id="'.$new_list_id.'">Download Next</button>']]}, 'test identifier generation list');

$mech->get_ok('http://localhost:3010/ajax/breeders/identifier_generation_download?list_id='.$new_list_id.'&next_number=5');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response->{identifiers}, ['ACTLNG000001','ACTLNG000002','ACTLNG000003','ACTLNG000004','ACTLNG000005'], 'test identifier generation download');

$mech->get_ok('http://localhost:3010/ajax/breeders/identifier_generation_download?list_id='.$new_list_id.'&next_number=10');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response->{identifiers}, ['ACTLNG000006','ACTLNG000007','ACTLNG000008','ACTLNG000009','ACTLNG000010','ACTLNG000011','ACTLNG000012','ACTLNG000013','ACTLNG000014','ACTLNG000015'], 'test identifier generation download 2');

$mech->get_ok('http://localhost:3010/ajax/breeders/identifier_generation_history?list_id='.$new_list_id);
$response = decode_json $mech->content;
print STDERR Dumper $response;
my $records = $response->{records};
my @data;
foreach (@$records){
    ok($_->{timestamp});
    push @data, [$_->{type}, $_->{username}, $_->{next_number}];
}
print STDERR Dumper \@data;
is_deeply(\@data, [['identifier_instantiation','janedoe','0'],['identifier_download','janedoe','5'],['identifier_download','janedoe','10']], 'test identifier generation history');

CXGN::List::delete_list($schema->storage->dbh, $new_list_id);

done_testing();
