use strict;
use warnings;

use LWP::Simple;
use Test::TCP;
use Test::More tests => 3;

use Server::Starter qw(start_server);

test_tcp(
    server => sub {
        my $port = shift;
        start_server(
            port => $port,
            exec => [ $^X, qw(t/01-httpd.pl) ],
        );
    },
    client => sub {
        my ($port, $server_pid) = @_;
        sleep 1;
        my $worker_pid = get("http://127.0.0.1:$port/");
        like($worker_pid, qr/^\d+$/, 'send request and get pid');
        kill 'HUP', $server_pid;
        sleep 5;
        my $new_worker_pid = get("http://127.0.0.1:$port/");
        like($new_worker_pid, qr/^\d+$/, 'send request and get pid');
        isnt($worker_pid, $new_worker_pid, 'worker pid changed');
    },
);
