#!/usr/bin/env perl
use strict;
use warnings;
use LWP::Simple;
use App::Prove;

use Catalyst::ScriptRunner;

use lib 'lib';
use SGN::Devel::MyDevLibs;

my @test_args = @ARGV;
@test_args = ('t') unless @test_args;

if( my $server_pid = fork ) {

    # wait for the test server to start
    {
      local $SIG{CHLD} = sub {
          waitpid $server_pid, 0;
          die "\nTest server failed to start.  Aborting.\n";
      };
      sleep 1 until !kill(0, $server_pid) || get 'http://localhost:3003';
    }

    # now run the tests against it
    $ENV{SGN_TEST_SERVER} = 'http://localhost:3003';

    my $app = App::Prove->new;
    $app->process_args(
        '-lr',
        ( map { -I => $_ } @INC ),
        @test_args
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

