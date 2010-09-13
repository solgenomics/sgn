use Test::More tests => 1;
use Carp;
use lib 't/lib';
use SGN::Test;
use SGN::Test::WWW::Mechanize;
use autodie qw/:all/;

my $mech = SGN::Test::WWW::Mechanize->new;
$mech->with_test_level( local => sub {
   my $conns1  = SGN::Test::db_connection_count($mech);
   my $dbh     = DBI->connect(@{ $mech->context->dbc_profile }{qw{ dsn user password attributes }});
   my $conns2  = SGN::Test::db_connection_count($mech);
   is($conns1+1, $conns2, "SGN::Test can count db connections");
}, 1);
