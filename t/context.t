use Test::Most tests => 6;

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
