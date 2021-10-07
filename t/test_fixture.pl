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

use File::Basename qw(dirname);
use Cwd qw(abs_path);

use Catalyst::ScriptRunner;

use lib 'lib';
use SGN::Devel::MyDevLibs;

my $verbose = 0;
my $nocleanup;
my $noserver;
my $dumpupdatedfixture;
my $noparallel = 0;
my $list_config = "";
my $logfile = "logfile.$$.txt";
my $print_environment;
# relative to `sgn/ (or parent of wherever this script is located)
my $fixture_path = 't/data/fixture/cxgn_fixture.sql';

GetOptions(
    "carpalways"         => \(my $carpalways = 0),
    "verbose"            => \$verbose,
    "nocleanup"          => \$nocleanup,
    "dumpupdatedfixture" => \$dumpupdatedfixture,
    "noserver"           => \$noserver,
    "noparallel"         => \$noparallel,
    "fixture_path"       => \$fixture_path,
    "list_config"        => \$list_config,
    "logfile=s"            => \$logfile,
    "env"                => \$print_environment,
    );

require Carp::Always if $carpalways;

if ($print_environment) { print STDERR "CURRENT ENV: ".Dumper(\%ENV); }

my @prove_args = @ARGV;
if(@prove_args){
    @prove_args = map {abs_path($_)} @prove_args;
}

#Change cwd to `sgn/` (or parent of wherever this script is located)
my $sgn_dir = abs_path(dirname(abs_path($0))."/../");
print STDERR "####### ".$sgn_dir." #######";
chdir($sgn_dir);
@prove_args = ( 't' ) unless @prove_args;

#my $parallel = (grep /^-j\d*$/, @ARGV) ? 1 : 0;

$ENV{SGN_CONFIG_LOCAL_SUFFIX} = 'fixture';
#my $conf_file_base = 'sgn_local.conf'; # which conf file the sgn_fixture.conf should be based on
# relative to `sgn/`
my $conf_file_base = $ENV{SGN_TEST_CONF} || 'sgn_test.conf';
my $template_file = 'sgn_fixture_template.conf';
# get some defaults from sgn_local.conf
#
my $cfg = Config::Any->load_files({files=> [$conf_file_base, $template_file], use_ext=>1 });

my $config = $cfg->[0]->{$conf_file_base};
my $template = $cfg->[1]->{$template_file};

if ($list_config) {
    print STDERR Dumper($cfg);
}

my $db_user_password = $config->{dbpass};
my $dbhost = $config->{dbhost} || 'localhost';
my $dbport = $config->{dbport} || '5432';
my $db_postgres_password = $config->{DatabaseConnection}->{sgn_test}->{password};
print STDERR "Using $dbhost:$dbport\n";
my $test_dsn = $config->{DatabaseConnection}->{sgn_test}->{dsn};
my $catalyst_server_port = 3010;

# replace the keys in the sgn local file with what's in the template
#
foreach my $k (keys %{$template}) {
    #print STDERR "Replacing key $k : $config->{$k} with $template->{$k}\n";
    $config->{$k} = $template->{$k};
}

# load the database fixture
#
my $dbname;

if ($ENV{TEST_DB_NAME}) { $dbname = $ENV{TEST_DB_NAME}; }

else {
    my $now = DateTime->now();
    $dbname = join "_", map { $now->$_ } (qw | year month day hour minute |);
    $dbname = 'test_db_'.$dbname;
    $dbname .= $$;
}

print STDERR "# Writing a .pgpass file... ";
# format = hostname:port:database:username:password
open(my $PGPASS, ">", "$ENV{HOME}/.pgpass") || die "Can't open .pgpass for writing.";
print $PGPASS "$dbhost:$dbport:$dbname:web_usr:$db_user_password\n";
print $PGPASS "$dbhost:$dbport:*:postgres:$db_postgres_password\n";
close($PGPASS);
system("chmod 0600 $ENV{HOME}/.pgpass");
print STDERR "Done.\n";

# load fixture only if no TEST_DB_NAME env var was provided
if (! $ENV{TEST_DB_NAME}) {
    my $database_fixture_dump = $ENV{DATABASE_FIXTURE_PATH} || $fixture_path;
    print STDERR "# Loading database fixture... $database_fixture_dump ... ";
    system("createdb -h $config->{dbhost} -U postgres -T template0 -E SQL_ASCII --no-password $dbname");
    # will emit an error if web_usr role already exists, but that's OK
    system("psql -h $config->{dbhost} -U postgres $dbname -c \"CREATE USER web_usr PASSWORD '$db_user_password'\"");
    system("cat $database_fixture_dump | psql -h $config->{dbhost} -U postgres $dbname > /dev/null");

    print STDERR "Done.\n";
}

print STDERR "# Creating sgn_fixture.conf file... ";
$config->{dbname} = $dbname;
$test_dsn =~ s/dbname=(.*)$/dbname=$dbname/;
$config->{DatabaseConnection}->{sgn_test}->{dsn} = $test_dsn;

#print STDERR Dumper($config);

my $new_conf = hash2config($config);

open(my $NEWCONF, ">", "sgn_fixture.conf") || die "Can't open sgn_fixture.conf for writing";
print $NEWCONF $new_conf;
close($NEWCONF);

#run fixture and db patches.
system("t/data/fixture/patches/run_fixture_and_db_patches.pl -u postgres -p $db_postgres_password -h $dbhost -d $dbname -e janedoe -s 145");

# run the materialized views creation script
#
print STDERR "Running matview refresh with -H $dbhost -D $dbname -U postgres -P $db_postgres_password -m fullview\n";
system("perl bin/refresh_matviews.pl -H $dbhost -D $dbname -U postgres -P $db_postgres_password -m fullview");

if ($dumpupdatedfixture){
    print STDERR "Dumping new updated fixture with all patches run on it to t/data/fixture/cxgn_fixture.sql\n";
    system("pg_dump -U postgres $dbname > t/data/fixture/cxgn_fixture.sql");
}

print STDERR "Done.\n";

# start the test web server
#
my $server_pid;
if ($noserver) {
    print STDERR "# [ --noserver option: not starting web server]\n";
}
else {
    $server_pid = fork;

    unless( $server_pid ) {

	# web server process
	#
	#$ENV{SGN_TEST_MODE} = 1;
	@ARGV = (
	    -p => $catalyst_server_port,
	    ( $noparallel ? () : ('--fork') ),
	    );

	if (!$verbose) {
	    print STDERR "# [Server logfile at $logfile]\n";
	    open (STDERR, ">$logfile") || die "can't open logfile.";
	}
	Catalyst::ScriptRunner->run('SGN', 'Server');

	if (!$nocleanup) {
	    print STDERR "# Removing test database ($dbname)... ";

	    if ($noserver) {
		print STDERR "# [ --noserver option: No logfile to remove]\n";
	    }
	    else {
		print STDERR "# Delete server logfile... ";
		close($logfile);
		unlink $logfile;
		print STDERR "Done.\n";

	    }
	}
	exit;
    }
    print STDERR  "# Starting web server (PID=$server_pid)... ";
}


# wait for the test server to start
#
{
    local $SIG{CHLD} = sub {
        waitpid $server_pid, 0;
        die "\nTest server failed to start.  Aborting.\n";
    };
    print STDERR "Done.\n";

    if (!$noserver) {
	sleep 1 until !kill(0, $server_pid) || get "http://localhost:$catalyst_server_port";
    }
}

my $prove_pid = fork;
unless( $prove_pid ) {

    # test harness process
    #
    print STDERR "# Starting tests... \n";

    # set up env vars for prove and the tests
    #
    $ENV{SGN_TEST_SERVER} ||= "http://localhost:$catalyst_server_port";
    if(! $noparallel ) {
        $ENV{SGN_PARALLEL_TESTING} = 1;
        $ENV{SGN_SKIP_LEAK_TEST}   = 1;
    }

    # now run the tests against it
    #
    my $app = App::Prove->new;

    my $v = $verbose ? 'v' : '';

    $app->process_args(
        '-lr'.$v,
        ( map { -I => $_ } @INC ),
        @prove_args
        );
    exit( $app->run ? 0 : 1 );
}

#$SIG{CHLD} = 'IGNORE';  # problematic
$SIG{INT}  = sub { kill 15, $server_pid, $prove_pid };
$SIG{KILL} = sub { kill 9, $server_pid, $prove_pid };

print STDERR "# Start prove (PID $prove_pid)... \n";
waitpid $prove_pid, 0;
print STDERR "# Prove finished, stopping web server PID $server_pid... ";

END { kill 15, $server_pid if $server_pid }
waitpid $server_pid, 0;
sleep(3);
print STDERR "Done.\n";

if (!$nocleanup) {
    if ($ENV{TEST_DB_NAME}) {
	print STDERR "Not removing test database (TEST_DB_NAME = $ENV{TEST_DB_NAME} is set.\n";
    }
    else {
	print STDERR "# Removing test database ($dbname)... ";
	system("dropdb -h $config->{dbhost} -U postgres --no-password $dbname");
	print STDERR "Done.\n";
    }

    if ($noserver) {
	print STDERR "# [ --noserver option: No logfile to remove]\n";
    }
    else {
	# print STDERR "# Delete server logfile... ";
	# close($logfile);
	# unlink $logfile;
	# print STDERR "Done.\n";

	print STDERR "# Delete fixture conf file... ";
	unlink "sgn_fixture.conf";
	print STDERR "Done.\n";
    }
}
else {
    print STDERR "# --nocleanup option: not removing db or files.\n";
}
print STDERR "# Test run complete.\n\n";



sub hash2config {
    my $hash = shift;

    my $s = "";
    foreach my $k (keys(%$hash)) {
	if (ref($hash->{$k}) eq "ARRAY") {
	    foreach my $v (@{$hash->{$k}}) {
		$s .= "$k $v\n";
	    }
	}
	elsif (ref($hash->{$k}) eq "HASH") {
	    foreach my $n (keys(%{$hash->{$k}})) {
		if (ref($hash->{$k}->{$n}) eq "HASH") {
		    $s .= "<$k $n>\n";
		    $s .= hash2config($hash->{$k}->{$n});
		}
		else {
		    $s .= "<$k>\n";
		    $s .= hash2config($hash->{$k});
		}
		$s .= "</$k>\n";
	    }
	}
	else {
	    $s .= "$k $hash->{$k}\n";
	}
    }

    # if nothing matched the replace keys, add them here
    #

#    if (exists($hash->{dbname})) {
#	$s .= "dbname $dbname\n";
 #  }

    return $s;
}



__END__

=head1 NAME

test_fixture.pl - start a dev server and run tests against it

=head1 SYNOPSIS

t/test_fixture.pl --carpalways -- -v -j5 t/mytest.t  t/mydiroftests/

=head1 OPTIONS

  -v             verbose - the output of the server is not re-directed to file,
                 but rather output to the screen.

  --carpalways   Load Carp::Always in both the server and the test process
                 to force backtraces of all warnings and errors

  --nocleanup    Do not clean up database and logfile

  --noserver     Do not start webserver (if running unit_fixture tests only)

  --noparallel   Do not run the server in parallel mode.

  --fixture_path specify a path to the fixture different from the default
                 (t/data/fixture/cxgn_fixture.pl). Note: You can also set the env
                 variable DATABASE_FIXTURE_PATH, which will overrule this
                 option.

  --list_config  lists the configuration information

  -- -v          options specified after two dashes will be passed to prove
                 directly, such -v will run prove in verbose mode.

By default, the configuration will be taken from the file sgn_test.conf. To use another configuration file, set the environment variable SGN_TEST_CONF to the name of the file you would like to use.

To use an existing database as the fixture, set the environment variable TEST_DB_NAME to the name of the database you would like to use.

=head1 AUTHORS

    Robert Buels (initial script)
    Lukas Mueller <lam87@cornell.edu> (fixture implementation)

=cut
