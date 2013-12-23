#!/usr/bin/env perl
use strict;
use warnings;

use DateTime;
use LWP::Simple;
use App::Prove;
use Data::Dumper;

use Pod::Usage;
use Getopt::Long;
use File::Slurp;
use Config::Any;

use Catalyst::ScriptRunner;

use lib 'lib';
use SGN::Devel::MyDevLibs;

my $verbose = 0;
GetOptions(
    "carpalways" => \( my $carpalways = 0 ),
    "verbose" => \$verbose ,
    );

require Carp::Always if $carpalways;

my @prove_args = @ARGV;
@prove_args = ( 't' ) unless @prove_args;

my $parallel = (grep /^-j\d*$/, @ARGV) ? 1 : 0;

$ENV{SGN_CONFIG_LOCAL_SUFFIX} = 'testing';
my $conf_file_base = 'sgn_testing.conf';

# get some defaults from sgn_local.conf
#
my $cfg = Config::Any->load_files({files=> [$conf_file_base], use_ext=>1 });
#print STDERR Data::Dumper::Dumper($cfg);
my $config = $cfg->[0]->{$conf_file_base};
my $db_user_password = $config->{dbpass};
my $dbhost = $config->{dbhost};
my $db_postgres_password = $config->{DatabaseConnection}->{sgn_test}->{password};
my $catalyst_server_port = 3010;

# load the database fixture
#
my $now = DateTime->now();
my $dbname = join "_", map { $now->$_ } (qw | year month day hour minute |);
$dbname = 'test_db_'.$dbname;
$dbname .= $$;

print STDERR "Writing a .pgpass file... ";
# hostname:port:database:username:password
open(my $PGPASS, ">", "$ENV{HOME}/.pgpass") || die "Can't open .pgpass for writing.";
print $PGPASS "$dbhost:5432:$dbname:web_usr:$db_user_password\n";
print $PGPASS "$dbhost:5432:*:postgres:$db_postgres_password\n";
close($PGPASS);
system("chmod 0600 $ENV{HOME}/.pgpass");
print "Done.\n";

print STDERR "Loading database fixture... ";
my $database_fixture_dump = $ENV{DATABASE_FIXTURE_PATH} || '../cxgn_fixture.sql';
system("createdb -h $config->{dbhost} -U postgres -T template0 -E SQL_ASCII --no-password $dbname");

system("cat $database_fixture_dump | psql -h $config->{dbhost} -U postgres $dbname > /dev/null");

print STDERR "Done.\n";

print STDERR "Creating sgn_fixture.conf file... ";

system("grep -v dbname \"$conf_file_base\" > sgn_fixture.conf");
system("echo \"dbname $dbname\" >> sgn_fixture.conf");

print STDERR "Done.\n";

# start the test web server
#
my $server_pid = fork;
unless( $server_pid ) {
    # web server process
    
    $ENV{SGN_TEST_MODE} = 1;
@ARGV = (
    -p => $catalyst_server_port,
    ( $parallel ? ('--fork') : () ),
    );

if (!$verbose) { 
    my $logfile = "logfile.$$.txt";
    print STDERR "Redirecting server STDERR to file $logfile..\n";
    open (STDERR, ">$logfile") || die "can't open logfile.";
}
Catalyst::ScriptRunner->run('SGN', 'Server');

exit;
}
print STDERR  "$0: starting web server with PID $server_pid... ";


# wait for the test server to start
{

    local $SIG{CHLD} = sub {
        waitpid $server_pid, 0;
        die "\nTest server failed to start.  Aborting.\n";
    };
    sleep 1 until !kill(0, $server_pid) || get "http://localhost:$catalyst_server_port";
    print STDERR "Done.\n";
}

my $prove_pid = fork;
unless( $prove_pid ) {
    # test harness process


    # set up env vars for prove and the tests
    $ENV{SGN_TEST_SERVER} = "http://localhost:$catalyst_server_port";
    if( $parallel ) {
        $ENV{SGN_PARALLEL_TESTING} = 1;
        $ENV{SGN_SKIP_LEAK_TEST}   = 1;
    }

    # now run the tests against it
    my $app = App::Prove->new;
    $app->process_args(
        '-lr',
        ( map { -I => $_ } @INC ),
        @prove_args
        );
    exit( $app->run ? 0 : 1 );
}

$SIG{CHLD} = 'IGNORE';
$SIG{INT}  = sub { kill 15, $server_pid, $prove_pid };
$SIG{KILL} = sub { kill 9, $server_pid, $prove_pid };

warn "$0: prove started with PID $prove_pid.\n";
waitpid $prove_pid, 0;
warn "$0: prove finished, stopping web server PID $server_pid.\n";
END { kill 15, $server_pid if $server_pid }
waitpid $server_pid, 0;

__END__

=head1 NAME

test_all.pl - start a dev server and run tests against it

=head1 SYNOPSIS

t/test_all.pl --carpalways -- -v -j5 t/mytest.t  t/mydiroftests/

=head1 OPTIONS

  --carpalways   Load Carp::Always in both the server and the test process
                 to force backtraces of all warnings and errors

=cut
