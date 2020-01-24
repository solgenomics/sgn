
use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;

#Needed to update IO::Socket::SSL
use Data::Dumper;
use JSON;
local $Data::Dumper::Indent = 0;

my $f = SGN::Test::Fixture->new();
my $mech = Test::WWW::Mechanize->new;
my $response;

$mech->get_ok('http://localhost:3010/ajax/user/login?username=janedoe&password=secretpw');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is($response->{message}, 'Login successful');

$mech->get_ok('http://localhost:3010/ajax/user/new?first_name=testfirst&last_name=testlast&username=testusername&password=testpass&confirm_password=testpass&email_address=test@testcassavabase.com');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'error' => 'Account creation failed for the following reason(s): \'Organization\' is required.\''});

$mech->get_ok('http://localhost:3010/ajax/user/new?first_name=testfirst&last_name=testlast&username=testusername&password=testpass&confirm_password=testpass&email_address=test@testcassavabase.com&organization=testorg');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'message' => ' <table summary="" width="80%" align="center">
<tr><td><p>Account was created with username "testusername". To continue, you must confirm that SGN staff can reach you via email address "test@testcassavabase.com". An email has been sent with a URL to confirm this address. Please check your email for this message and use the link to confirm your email address.</p></td></tr>
<tr><td><br /></td></tr>
</table>
'});

#confirm account is still in cgi-bin, so test lacking here. will do manually
my $q = "update sgn_people.sp_person set disabled = default where username = 'testusername';";
my $sth = $f->bcs_schema->storage->dbh->prepare($q);
$sth->execute;
my $email = 'test@testcassavabase.com';
my $q = "update sgn_people.sp_person set private_email='$email' where username = 'testusername';";
my $sth = $f->bcs_schema->storage->dbh->prepare($q);
$sth->execute;

$mech->get_ok('http://localhost:3010/ajax/user/reset_password?password_reset_email=test@testcassavabase.com');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is($response->{message}, 'Reset link sent. Please check your email and click on the link.');
is(scalar(@{$response->{reset_links}}), 1);
is(scalar(@{$response->{reset_tokens}}), 1);
my $token = $response->{reset_tokens}->[0];

$mech->get_ok('http://localhost:3010/ajax/user/process_reset_password?token='.$token.'&new_password=testpasschange&confirm_password=testpasschange');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is($response->{message}, 'The password was successfully updated.');

$mech->get_ok('http://localhost:3010/ajax/user/login?username=testusername&password=testpasschange');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is($response->{message}, 'Login successful');

done_testing;
