#! /usr/bin/perl

use strict;
use warnings;

use lib qw(blib/lib lib);

my $server = MyServer->new()->run();

package MyServer;

use base qw(HTTP::Server::Simple::CGI);

sub net_server { 'Net::Server::SS::PreFork' };

sub handle_request {
    print "HTTP/1.0 200 OK\r\nContent-Type: text/plain\r\n\r\n" . getppid;
}

1;
