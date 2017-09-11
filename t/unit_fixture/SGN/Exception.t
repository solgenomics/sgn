use strict;
use warnings;

use Test::More;

use SGN::Exception;

{
    my $e = SGN::Exception->new( public_message => 'foo foo foo', notify => 0, is_client_error => 1 );
    ok( ! $e->is_server_error, 'is not a server error' );
    ok( $e->is_client_error, 'IS a client error' );
    is( $e->http_status, 400, 'right http status' );
    ok( ! $e->notify, 'notify off' );
}

{
    my $e = SGN::Exception->new( public_message => 'foo foo foo', notify => 0, is_server_error => 1 );
    ok( $e->is_server_error, 'IS a server error' );
    ok( ! $e->is_client_error, 'is NOT a client error' );
    is( $e->http_status, 500, 'right http status' );
    ok( ! $e->notify, 'notify off' );
}

done_testing;
