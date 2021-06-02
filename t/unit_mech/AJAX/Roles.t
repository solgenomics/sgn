
=head1 NAME

t/unit_mech/AJAX/Roles.t - quick test for retrieve role function.

A more extensive test of the functionality will be implemented in selenium.

=head1 AUTHOR

Lukas Mueller

=cut

use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;

use Data::Dumper;
use JSON::XS;
local $Data::Dumper::Indent = 0;

my $f = SGN::Test::Fixture->new();
my $mech = Test::WWW::Mechanize->new;
my $response;

$mech->get_ok('http://localhost:3010/ajax/user/login?username=janedoe&password=secretpw');


$response = decode_json $mech->content;

print STDERR Dumper $response;
is($response->{message}, 'Login successful');

$mech->get_ok('http://localhost:3010/ajax/roles/list', 'get /ajax/roles/list');

print STDERR "MECH CONTENT : ".$mech->content()."\n\n\n";
$response = $mech->content;

print STDERR Dumper $response;

ok($response =~ m/Fred Sanger/, 'user name test for Freddy');
ok($response =~ m/curator/, 'user role test curator Freddy'); 
ok($response =~ m/Jane Doe/, 'user name test Jane');
ok($response =~ m/John Doe/, 'user name test John');
ok($response =~ m/curator/, 'check curator role present (for Freddy)');

# delete a role
print STDERR "Deleting role...\n";
$mech->get_ok('http://localhost:3010/ajax/roles/delete/association/71', 'delete role association');

$mech->get_ok('http://localhost:3010/ajax/roles/list', 'get updated role list after delete');
$response = $mech->content;

print STDERR "After deletion: $response\n";
ok($response !~ m/submitter/, 'check if curator role disappeared');

$mech->get_ok('http://localhost:3010/ajax/people/add_person_role?sp_role_id=4&sp_person_id=40');
$response = $mech->content();

$mech->get_ok('http://localhost:3010/ajax/roles/list', 'get updated roles after insert.');
$response = $mech->content();

print STDERR Dumper "AFTER INSERT :". $response;
ok($response =~ m/user/, 'check if curator role has re-appeared');

done_testing;
