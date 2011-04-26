#!/usr/bin/env perl
use strict;
use warnings;
use LWP::Simple;
use App::Prove;

use Catalyst::ScriptRunner;

use lib 'lib';
use SGN::Devel::MyDevLibs;

my @test_paths = @ARGV;
@test_paths = ('t') unless @test_paths;

if( my $server_pid = fork ) {

    # testing process
    sleep 1 until get 'http://localhost:3003';
    $ENV{SGN_TEST_SERVER}='http://localhost:3003';
    my $app = App::Prove->new;
    $app->process_args(
        '-lr',
        ( map { -I => $_ } @INC ),
        @test_paths
        );
    exit( $app->run ? 0 : 1 );

    END { kill 15, $server_pid if $server_pid }

} else {

    # server process
    $ENV{SGN_TEST_MODE} = 1;
    @ARGV = ( -p => 3003 );
    Catalyst::ScriptRunner->run('SGN', 'Server');
    exit;

}

