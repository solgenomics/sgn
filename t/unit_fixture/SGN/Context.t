use Test::Most;
use Carp;

use lib 't/lib';
use SGN::Test 'with_test_level';

$SIG{__DIE__} = \&Carp::confess;

use_ok 'SGN::Context';

my $c = SGN::Context->new;

#### test dbh() method
can_ok( $c->dbc, 'dbh', 'run','txn' );
can_ok( $c->dbc->dbh, 'selectall_arrayref', 'prepare', 'ping' );

ok( $c->dbc->dbh->ping, 'dbh looks live' );

throws_ok {
    $c->dbc('nonexistent connection profile');
} qr/not defined/, 'throws for nonexistent connection profile';

like( $c->dbc->dbh->{private_search_path_string},
      qr/\S/,
      'private_search_path has something in it',
     );

# test dbic_schema method

my $schema = $c->dbic_schema('Test::Schema');
can_ok( $schema, 'resultset', 'storage' );
ok( $schema->storage->dbh->ping, 'dbic storage is connected' );
is( search_path( $schema->storage->dbh), search_path( $c->dbc->dbh ), 'schema and dbc should have same search path' );

# test tempfile method
with_test_level( local => sub {
    my ($tempfile, $temp_uri) =
        $c->tempfile( TEMPLATE => [ 'foobar','noggin-XXXXX' ],
                      SUFFIX => '.foo' );

    can_ok( $tempfile, 'filename', 'print' );
    can_ok( $temp_uri, 'path' );
    unlike( $temp_uri, qr/X{5}/, 'temp_uri got its Xs replaced' );
    unlike( $temp_uri, qr/X{5}/, 'temp_uri got its Xs replaced' );
    like( "$tempfile", qr/\.foo$/, 'tempfile name has suffix' );
    like( "$temp_uri", qr/\.foo$/, 'tempfile uri has suffix' );
});

done_testing;


sub search_path {
    my ($dbh) = @_;
    my ($sp) = $dbh->selectrow_array('show search_path');
    return $sp;
}

package Test::Schema;

use base 'DBIx::Class::Schema';

