
use strict;

use Test::More qw| no_plan |;

use Data::Dumper;
use CXGN::Access;

use lib 't/lib';

use SGN::Test::Fixture;

my $f = SGN::Test::Fixture->new();

my $a = CXGN::Access->new( { people_schema => $f->people_schema() });

print STDERR "THIS TEST NEEDS TO BE (RE-)IMPLEMENTED!\n";

ok(1);
# my $resource_id = $a->add_resource("test_resource");

# ok($resource_id, "add resource test");

# my $resource_id2 = $a->add_resource("test_resource");

# is($resource_id, $resource_id2, "test adding the same resource again");

# my $access_level_id = $a->add_access_level("full_access");

# ok($access_level_id, "add access level test");

# my $access_level_id2 = $a->add_access_level("full_access"); # add again

# is($access_level_id, $access_level_id2, "check same access_level id after repeated add");

# my @privileges = $a->check_role('user', 'test_resource');

# print STDERR "PRIVILEGES: ".Dumper(\@privileges);

# is_deeply( \@privileges, [], "privileges check before privilege add");

# my $grant = $a->grant(40, 'full_access', 'test_resource');

# is($grant, 0, "check no grant before privilege add");

# my $info = $a->add_privilege('test_resource', 'submitter', 'full_access');

# is($info->{success}, 1, "check add privilege function");
# my $privilege_id = $info->{privilege_id};

# @privileges = $a->check_role('submitter', 'test_resource');

# is_deeply( \@privileges, [ 'full_access' ], "privileges check after privilege add");

# $grant = $a->grant(40, 'full_access', 'test_resource');

# is($grant, 1, "check no grant before privilege add");

# my $result = $a->delete_privilege($privilege_id);
# ok($result->{success} == 1, "privilege delete ok");

# $result = $a->delete_access_level($access_level_id);
# ok($result->{success} == 1, "access level delete ok");

# $result = $a->delete_resource($resource_id);
# ok($result->{success} == 1, "resource delete ok");

done_testing();

