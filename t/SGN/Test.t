use Test::More tests => 1;
use Carp;
use lib 't/lib';
use SGN::Test;
use SGN::Context;
use DBI;
use autodie qw/:all/;

my $context = SGN::Context->new;
my $dsn     = $context->dbc_profile->{dsn};
my $conns1  = SGN::Test::db_connections();
my $dbh     = DBI->connect($dsn);
my $conns2  = SGN::Test::db_connections();
is($conns1+1, $conns2, "SGN::Test can count db connections");
