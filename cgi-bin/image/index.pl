use CatalystX::GlobalContext qw( $c );
use strict;
use warnings;

use CGI;
use CXGN::DB::Connection;
use CXGN::Login;

my $q = CGI->new();
my $dbh = CXGN::DB::Connection->new();
my $login = CXGN::Login->new($dbh);

my $person_id = $login->has_session();

my ($image_id, $size) = ($q->param("image_id"), $q->param("size"));


print $q->redirect("/image/view/$image_id", 301);
