package CXGN::DB::ReadSnapshot;
use strict;
use warnings;

=head1 NAME

CXGN::DB::ReadSnapshot - one consistent snapshot for multi-statement readers

=head1 DESCRIPTION

run($schema, $callback) starts a writable REPEATABLE READ transaction only when
AutoCommit says that the reader owns the transaction. Existing caller-owned
transactions retain their isolation, commit and rollback policy. No READ ONLY
flag is set because the normal trial layout reader may regenerate stored JSON.
Scalar, list and void callback context are preserved. A serialization failure
(SQLSTATE 40001) is retried once after rollback; other failures stay explicit.

=cut

sub run {
    my ($schema,$code)=@_;
    die "A read snapshot requires a callback.\n" if ref($code) ne 'CODE';
    my $context=wantarray;
    my $dbh=$schema->storage->dbh;
    if (!$dbh->{AutoCommit}) {
        return $code->() if defined($context);
        $code->();return;
    }
    for my $attempt (0..1) {
        my (@list,$scalar,$started);
        my $ok=eval {
            $schema->txn_begin;$started=1;
            $dbh=$schema->storage->dbh;
            $dbh->do('SET TRANSACTION ISOLATION LEVEL REPEATABLE READ');
            if (!defined($context)) {$code->()}
            elsif ($context) {@list=$code->()}
            else {$scalar=$code->()}
            $schema->txn_commit;
            1;
        };
        if ($ok) {
            return @list if $context;
            return $scalar if defined($context);
            return;
        }
        my $error=$@;
        # Rollback clears DBI state. Capture the failed statement/commit state
        # before any cleanup SQL, rather than inferring it from error wording.
        my $state=eval {$dbh->state} || '';
        my $rolled_back=1;my $rollback_error;
        if ($started) {
            $rolled_back=eval {$schema->txn_rollback;1};
            $rollback_error=$@;
        }
        die "$error\nRead transaction rollback failed: $rollback_error" if !$rolled_back;
        next if $attempt==0 && $state eq '40001';
        die $error;
    }
}

1;
