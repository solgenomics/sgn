use Test::Most;
use Carp;
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

# test jsan functions
can_ok( $c->new_jsan, 'uris' );
my $uris = $c->js_import_uris('CXGN.Page.Toolbar');
cmp_ok( scalar(@$uris), '>=', 1, 'got at least 1 URI to include for CXGN.Page.Toolbar' );

done_testing;


sub search_path {
    my ($dbh) = @_;
    my ($sp) = $dbh->selectrow_array('show search_path');
    return $sp;
}

package Test::Schema;

use base 'DBIx::Class::Schema';

