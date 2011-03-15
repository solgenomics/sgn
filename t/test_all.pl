#!/usr/bin/env perl
use strict;
use warnings;
use LWP::Simple;

use lib 'lib';
use Catalyst::ScriptRunner;

my $server_pid;
if( $server_pid = fork ) {
    sleep 1 until get 'http://localhost:3000';
    $ENV{SGN_TEST_SERVER}='http://localhost:3000';
    system("prove -lr t");
} else {
    $ENV{SGN_TEST_MODE} = 1;
    Catalyst::ScriptRunner->run('SGN', 'Server');
    exit;
}

END { kill 15, $server_pid if $server_pid }
