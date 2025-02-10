
use strict;
use warnings;
use Test::More;
use Test::Warn;
use Data::Dumper;

use lib 't/lib';
use SGN::Test::Fixture;



BEGIN { $ENV{SGN_SKIP_CGI} = 1 } #< don't need to compile all the CGIs
use SGN::Test::WWW::Mechanize;
use SGN::Test qw/ request /;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema();

my $mech = SGN::Test::WWW::Mechanize->new;

# check homepage when not logged in
# with personalized_homepage assumed set to 1
#
$mech->get_ok('/');

$mech->content_like( qr/What is Breedbase/, 'check homepage contents');
$mech->content_lacks( 'Welcome back', 'check user welcome message missing.');

# login
#
$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ], 'login with brapi call');

$mech->get_ok('/');
$mech->content_like( qr/Welcome back/, 'check user welcome message present');

done_testing();
