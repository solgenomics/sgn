use strict;
use warnings;
use Test::More;
use Test::MockObject;
use CXGN::Pedigree::Upload;
use CXGN::People::Person;

my $person = Test::MockObject->new;
$person->set_always(get_sp_person_id => 41)->set_always(get_username => 'upload_test');
my $user = Test::MockObject->new;
my $role = 'submitter';
$user->set_always(get_object => $person)->mock(roles => sub { $role })
    ->mock(check_roles => sub { $_[1] eq $role });
my $request = Test::MockObject->new;
my $token;
$request->set_always(method => 'POST')->mock(param => sub { $token });
my $context = Test::MockObject->new;
my $config = {disable_login => 0};
my $active_user = $user;
my $dbc = Test::MockObject->new;
$dbc->set_always(dbh => 'test handle');
my $stash = {};
$context->set_always(req => $request)->set_always(config => $config)
    ->set_always(dbc => $dbc)->set_always(stash => $stash)->mock(user => sub { $active_user });

my $token_id = 41;
my $expired = 0;
my $lookups = 0;
{
    no warnings 'redefine';
    local *CXGN::Login::new = sub { 'CXGN::Login' };
    local *CXGN::Login::query_from_cookie = sub { $lookups++; return ($token_id, 'submitter', undef, $expired) };
    local *CXGN::People::Person::new = sub { $person };

    is_deeply(CXGN::Pedigree::Upload->authorize($context), {id => 41, name => 'upload_test', role => 'submitter'},
        'an authenticated submitter may proceed');
    $token = 'test-session';
    ok(CXGN::Pedigree::Upload->authorize($context), 'a matching unexpired token is accepted');
    $expired = 1;
    ok(!CXGN::Pedigree::Upload->authorize($context), 'an expired token is refused even with an authenticated user');
    $expired = 0;
    $token_id = 42;
    ok(!CXGN::Pedigree::Upload->authorize($context), 'a current token cannot change the authenticated actor');
    $token_id = 41;

    $config->{disable_login} = 1;
    $lookups = 0;
    ok(!CXGN::Pedigree::Upload->authorize($context), 'a valid token cannot bypass disabled login');
    is($lookups, 0, 'disabled login does not query the token');
    like($stash->{rest}{error}, qr/Log in/, 'disabled login returns the authorization error');
    $config->{disable_login} = 0;
    $config->{is_mirror} = 1;
    ok(!CXGN::Pedigree::Upload->authorize($context), 'nobody uploads to a mirror');
    $config->{is_mirror} = 0;
    @$config{qw(dbname production_server)} = ('sandbox_db', 1);
    ok(!CXGN::Pedigree::Upload->authorize($context), 'nobody uploads to the sandbox of a production server');
    @$config{qw(dbname production_server)} = ('cxgn', 1);

    $active_user = undef;
    is_deeply(CXGN::Pedigree::Upload->authorize($context), {id => 41, name => 'upload_test', role => 'submitter'},
        'a current token of a submitter is accepted without a cookie');
    ok(!CXGN::Pedigree::Upload->authorize($context, require_user => 1), 'a route that needs the signed-in user refuses a token alone');
    $expired = 1;
    ok(!CXGN::Pedigree::Upload->authorize($context), 'an expired token alone is refused');
    $expired = 0;
    $token = undef;
    ok(!CXGN::Pedigree::Upload->authorize($context), 'no user and no token is refused');
    $token = 'test-session';
    $active_user = $user;
    $role = 'user';
    ok(!CXGN::Pedigree::Upload->authorize($context), 'the Catalyst user must have a write role');
}

done_testing;
