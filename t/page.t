use CXGN::DB::Connection { verbose => 1 };
use Test::More tests => 2;

$ENV{PROJECT_NAME} = "SGN";
$ENV{SERVERNAME} = "localhost";

use CXGN::Apache::Spoof;

use CXGN::Cookie;
use CXGN::Page;
use CXGN::Login;

my $dbh = CXGN::DB::Connection->new();
my $login = CXGN::Login->new($dbh);
$login->login_user("ccarpita", "esculentum");

my $page = CXGN::Page->new();
my $header = $page->get_header();

