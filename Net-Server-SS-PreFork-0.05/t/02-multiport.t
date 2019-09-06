use strict;
use warnings;

use LWP::Simple;
use Test::TCP;
use Test::More tests => 2;

use Server::Starter qw(start_server);

my $another_port = empty_port(20000);

test_tcp(
    server => sub {
        my $port = shift;
        start_server(
            port => [ $port, $another_port ],
            exec => [ $^X, qw(t/01-httpd.pl) ],
        );
    },
    client => sub {
        my $port = shift;
        sleep 1;
        like get("http://127.0.0.1:$port/"), qr/^\d+$/, 'check port 1';
        like get("http://127.0.0.1:$another_port/"), qr/^\d+$/, 'check port 2';
    },
);
