use strict;
use warnings;

use Test::More;

use lib 't/lib';
use SGN::Test::WWW::Mechanize;

my $urlbase = "/tools/wait.pl";
my $mech = SGN::Test::WWW::Mechanize->new;
$mech->get_ok($urlbase);
$mech->content_like(qr/Job not found/);

done_testing;
