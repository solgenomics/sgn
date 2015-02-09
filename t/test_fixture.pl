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
my $nocleanup;
my $noserver;
my $noparallel = 0;
GetOptions(
    "carpalways" => \( my $carpalways = 0 ),
    "verbose" => \$verbose ,
    "nocleanup" => \$nocleanup,
    "noserver" => \$noserver,
    "noparallel" => \$noparallel,
    );

require Carp::Always if $carpalways;

my @prove_args = @ARGV;
@prove_args = ( 't' ) unless @prove_args;

#my $parallel = (grep /^-j\d*$/, @ARGV) ? 1 : 0;

$ENV{SGN_CONFIG_LOCAL_SUFFIX} = 'fixture';
my $conf_file_base = 'sgn_local.conf'; # which conf file the sgn_fixture.conf should be based on

# get some defaults from sgn_local.conf
#
my $cfg = Config::Any->load_files({files=> [$conf_file_base], use_ext=>1 });

my $config = $cfg->[0]->{$conf_file_base};
my $db_user_password = $config->{dbpass};
my $dbhost = $config->{dbhost};
my $db_postgres_password = $config->{DatabaseConnection}->{sgn_test}->{password};
my $test_dsn = $config->{DatabaseConnection}->{sgn_test}->{dsn};
my $catalyst_server_port = 3010;

# load the database fixture
#
my $now = DateTime->now();
my $dbname = join "_", map { $now->$_ } (qw | year month day hour minute |);
$dbname = 'test_db_'.$dbname;
$dbname .= $$;

print STDERR "# Writing a .pgpass file... ";
# format = hostname:port:database:username:password
open(my $PGPASS, ">", "$ENV{HOME}/.pgpass") || die "Can't open .pgpass for writing.";
print $PGPASS "$dbhost:5432:$dbname:web_usr:$db_user_password\n";
print $PGPASS "$dbhost:5432:*:postgres:$db_postgres_password\n";
close($PGPASS);
system("chmod 0600 $ENV{HOME}/.pgpass");
print "Done.\n";

print STDERR "# Loading database fixture... ";
my $database_fixture_dump = $ENV{DATABASE_FIXTURE_PATH} || '../cxgn_fixture.sql';
system("createdb -h $config->{dbhost} -U postgres -T template0 -E SQL_ASCII --no-password $dbname");
system("cat $database_fixture_dump | psql -h $config->{dbhost} -U postgres $dbname > /dev/null");

print STDERR "Done.\n";

print STDERR "# Creating sgn_fixture.conf file... ";
$config->{dbname} = $dbname;
$test_dsn =~ s/dbname=(.*)$/dbname=$dbname/;
$config->{DatabaseConnection}->{sgn_test}->{dsn} = $test_dsn;

my $new_conf = hash2config($config);

open(my $NEWCONF, ">", "sgn_fixture.conf") || die "Can't open sgn_fixture.conf for writing";
print $NEWCONF $new_conf;
close($NEWCONF);

print STDERR "Done.\n";

# start the test web server
#
my $server_pid;
my $logfile;
if ($noserver) { 
    print STDERR "# [ --noserver option: not starting web server]\n";
}
else { 
    $server_pid = fork;
    $logfile  = "logfile.$$.txt";

    unless( $server_pid ) {
    
	# web server process
	#
	$ENV{SGN_TEST_MODE} = 1;
	@ARGV = (
	    -p => $catalyst_server_port,
	    ( $noparallel ? () : ('--fork') ),
	    );
	
	if (!$verbose) { 
	    print STDERR "# [Server logfile at $logfile]\n";
	    open (STDERR, ">$logfile") || die "can't open logfile.";
	}
	Catalyst::ScriptRunner->run('SGN', 'Server');
	
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
    $ENV{SGN_TEST_SERVER} = "http://localhost:$catalyst_server_port";
    if(! $noparallel ) {
        $ENV{SGN_PARALLEL_TESTING} = 1;
        $ENV{SGN_SKIP_LEAK_TEST}   = 1;
    }

    # now run the tests against it
    #
    my $app = App::Prove->new;
    $app->process_args(
        '-lr',
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
    print STDERR "# Removing test database ($dbname)... ";
    system("dropdb -h $config->{dbhost} -U postgres --no-password $dbname");
    print STDERR "Done.\n";

    if ($noserver) { 
	print STDERR "# [ --noserver option: No logfile to remove]\n";
    }
    else { 
	print STDERR "# Delete server logfile... ";
	close($logfile);
	unlink $logfile;
	print STDERR "Done.\n";
	
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

    our %replace = ( 
	blast_db_path => $hash->{basepath}."t/data/blast" ,
	cluster_shared_bindir => '/usr/bin',
	cluster_shared_tempdir => '/tmp',
	);
 
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
	    if (exists($replace{$k})) { 
		$s .= "$k $replace{$k}\n";
		delete $replace{$k};
	    }
	    else { 
		$s .= "$k $hash->{$k}\n";
	    }
	}
    }

    # if nothing matched the replace keys, add them here
    #
    foreach my $k (keys %replace) { 
	# only do this on the top-level (check for key there)
	if (exists($hash->{dbname})) { 
	    $s .= "$k $replace{$k}\n";
	}
    }
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

=head1 AUTHORS

    Robert Buels (initial script)
    Lukas Mueller <lam87@cornell.edu> (fixture implementation)
    
=cut
