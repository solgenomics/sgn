
use strict;

# BEGIN {
# 	our $WAIT_TEST = shift;
# 	our $TESTS = 4;
# 	$TESTS++ if $WAIT_TEST;

# 	#require CXGN::Class::Exporter;
# 	#CXGN::Class::Exporter::VERBOSE = 0;
# 	#our $DBH = CXGN::DB::Connection->new();
# }

our $WAIT_TEST=0;
our $TESTS=7;

use Test::More tests=>7;

BEGIN { 
    use_ok( 'CXGN::Login' );
    use_ok( 'CXGN::DB::Connection' );
    use_ok( 'CXGN::Apache::Spoof' );
}



use CXGN::Apache::Spoof;
#use Data::Dumper;
use CXGN::DB::Connection;
#use CXGN::Login;

CXGN::DB::Connection->verbose(0);

diag("Making the database connection...");
my $dbh = CXGN::DB::Connection->new();

diag("Success!");

diag("Creating login object...");
my $login = CXGN::Login->new($dbh);

diag("checking some stuff...");
my $info = $login->get_login_status();
delete($info->{detailed});
#diag(Dumper($info));
ok(keys %$info, "Aggregate data fetched");

# The following only works because of CXGN::Apache::Spoof,
# which holds onto set cookies as a package variable.
# Thus, CXGN::Apache::Spoof couldn't really handle two scripts
# at once

#diag("logging in a user...");
$login->login_user("ccarpita", "esculentum");
ok($login->has_session(), "Test user logged in");

$info = $login->login_user("blahdee", "blorpblorp");
ok($info->{incorrect_password}, "Incorrect password reported correctly");

$login->logout_user();
ok(!$login->has_session(), "Test user logged out");

if($WAIT_TEST){
	$login->login_user('ccarpita', 'esculentum');
	sleep 20;
	ok($login->has_session(), "Session persists");
	$login->logout_user();
}

