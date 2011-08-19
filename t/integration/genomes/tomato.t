use Test::Most;

use lib 't/lib';

use SGN::Test::WWW::Mechanize skip_cgi => 1;


my $mech = SGN::Test::WWW::Mechanize->new;
$mech->get_ok('/organism/Solanum_lycopersicum/genome');
$mech->html_lint_ok;
$mech->dbh_leak_ok;

done_testing;

