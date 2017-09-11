use Test::More;
use Carp;
use lib 't/lib';

use_ok( 'SGN::Test' );
use_ok( 'SGN::Test::WWW::Mechanize' );

my $mech = SGN::Test::WWW::Mechanize->new;
$mech->with_test_level( local => sub {
   my $conns1  = $mech->_db_connection_count($mech);
   like $conns1, qr/^\d+$/, 'counted some connections';
   unless( $ENV{SGN_PARALLEL_TESTING} ) {
       my $dbh     = DBI->connect(@{ $mech->context->dbc_profile }{qw{ dsn user password attributes }});
       my $conns2  = $mech->_db_connection_count($mech);
       is($conns1+1, $conns2, "SGN::Test can count db connections correctly");
   }
}, 1);


done_testing;
