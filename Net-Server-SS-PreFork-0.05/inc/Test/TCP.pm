#line 1
package Test::TCP;
use strict;
use warnings;
use 5.00800;
our $VERSION = '0.16';
use base qw/Exporter/;
use IO::Socket::INET;
use Test::SharedFork;
use Test::More ();
use Config;
use POSIX;
use Time::HiRes ();

# process does not die when received SIGTERM, on win32.
my $TERMSIG = $^O eq 'MSWin32' ? 'KILL' : 'TERM';

our @EXPORT = qw/ empty_port test_tcp wait_port /;

sub empty_port {
    my $port = shift || 10000;
    $port = 19000 unless $port =~ /^[0-9]+$/ && $port < 19000;

    while ( $port++ < 20000 ) {
        my $sock = IO::Socket::INET->new(
            Listen    => 5,
            LocalAddr => '127.0.0.1',
            LocalPort => $port,
            Proto     => 'tcp',
            (($^O eq 'MSWin32') ? () : (ReuseAddr => 1)),
        );
        return $port if $sock;
    }
    die "empty port not found";
}

sub test_tcp {
    my %args = @_;
    for my $k (qw/client server/) {
        die "missing madatory parameter $k" unless exists $args{$k};
    }
    my $port = $args{port} || empty_port();

    if ( my $pid = Test::SharedFork->fork() ) {
        # parent.
        wait_port($port);

        my $sig;
        my $err;
        {
            local $SIG{INT}  = sub { $sig = "INT"; die "SIGINT received\n" };
            local $SIG{PIPE} = sub { $sig = "PIPE"; die "SIGPIPE received\n" };
            eval {
                $args{client}->($port, $pid);
            };
            $err = $@;

            # cleanup
            kill $TERMSIG => $pid;
            while (1) {
                my $kid = waitpid( $pid, 0 );
                if ($^O ne 'MSWin32') { # i'm not in hell
                    if (WIFSIGNALED($?)) {
                        my $signame = (split(' ', $Config{sig_name}))[WTERMSIG($?)];
                        if ($signame =~ /^(ABRT|PIPE)$/) {
                            Test::More::diag("your server received SIG$signame");
                        }
                    }
                }
                if ($kid == 0 || $kid == -1) {
                    last;
                }
            }
        }

        if ($sig) {
            kill $sig, $$; # rethrow signal after cleanup
        }
        if ($err) {
            die $err; # rethrow exception after cleanup.
        }
    }
    elsif ( $pid == 0 ) {
        # child
        $args{server}->($port);
        exit;
    }
    else {
        die "fork failed: $!";
    }
}

sub _check_port {
    my ($port) = @_;

    my $remote = IO::Socket::INET->new(
        Proto    => 'tcp',
        PeerAddr => '127.0.0.1',
        PeerPort => $port,
    );
    if ($remote) {
        close $remote;
        return 1;
    }
    else {
        return 0;
    }
}

sub wait_port {
    my $port = shift;

    my $retry = 100;
    while ( $retry-- ) {
        return if _check_port($port);
        Time::HiRes::sleep(0.1);
    }
    die "cannot open port: $port";
}

1;
__END__

=encoding utf8

#line 241
