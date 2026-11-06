use strict;
use warnings;
use lib 't/lib';
use Test::More;
use JSON qw(encode_json);
use IO::Select;
use POSIX qw(WNOHANG);
use Time::HiRes qw(time sleep);
use SGN::Test::Fixture;
use SGN::Model::Cvterm;
use Bio::Chado::Schema;
use CXGN::Trial::TrialCreate;
use CXGN::Trial::AccessionChange;
use CXGN::Stock::Seedlot;
use CXGN::Stock::Seedlot::Transaction;

# Real simultaneous correction processes operate on different private trials.
# Writer A pauses after calculating a shared lot's count. Writer B starts while
# that transaction remains open. With common seedlot locks B must wait; without
# them it commits a stale cache before A resumes. No app hotpatch is used.
my $f = SGN::Test::Fixture->new;
my $schema = $f->bcs_schema;
my $dbh = $schema->storage->dbh;
my $config = $f->config;
my $peer = Bio::Chado::Schema->connect(
    "dbi:Pg:dbname=$config->{dbname};host=$config->{dbhost}",
    $config->{dbuser}, $config->{dbpass},
);
$schema->storage->auto_savepoint(1);
$peer->storage->auto_savepoint(1);
$peer->storage->dbh->do(q{SET statement_timeout='5s'});
my $prefix = 'audit_shared_seedlot_' . $$;
my (@trials, @plots, @lots, @germplasm, @transactions);
sub term { SGN::Model::Cvterm->get_cvterm_row($schema, @_)->cvterm_id }
sub lot { CXGN::Stock::Seedlot->new(schema => $_[0], seedlot_id => $_[1]) }
sub apply_change {
    my ($connection, $i) = @_;
    return CXGN::Trial::AccessionChange->new({schema => $connection, trial_id => $trials[$i]})->apply(
        [{plot_id => $plots[$i], new_stock_id => $germplasm[1], seedlot_name => $prefix . '_lot_C'}],
        {curator => 1, rename_plots => 'none', seedlots => 'follow'},
    );
}
sub cleanup {
    eval { $schema->txn_rollback } if !$dbh->{AutoCommit};
    my @ids = (@plots, @lots);
    $schema->txn_do(sub {
        my $experiments = $dbh->selectcol_arrayref(
            'SELECT nd_experiment_id FROM nd_experiment_project WHERE project_id=ANY(?)', undef, \@trials,
        );
        $dbh->do('DELETE FROM nd_experiment WHERE nd_experiment_id=ANY(?)', undef, $experiments) if @$experiments;
        $dbh->do('DELETE FROM phenome.stock_owner WHERE stock_id=ANY(?)', undef, \@ids) if @ids;
        $dbh->do('DELETE FROM stock WHERE stock_id=ANY(?)', undef, \@ids) if @ids;
        $dbh->do('DELETE FROM phenome.project_owner WHERE project_id=ANY(?)', undef, \@trials) if @trials;
        $dbh->do('DELETE FROM project WHERE project_id=ANY(?)', undef, \@trials) if @trials;
    });
}
my $ok = eval {
    die 'The fixture connection must initially use AutoCommit' if !$dbh->{AutoCommit};
    @germplasm = map { $schema->resultset('Stock::Stock')->find({uniquename => "test_accession$_"})->stock_id } (1, 2);
    $schema->txn_do(sub {
        for my $i (0 .. 1) {
            my $name = "${prefix}_trial_$i";
            my $created = CXGN::Trial::TrialCreate->new({
                chado_schema => $schema, dbh => $dbh, owner_id => 41, operator => 'janedoe',
                program => 'test', trial_location => 'test_location', trial_name => $name,
                trial_year => 2031, trial_description => 'Private shared-lot concurrency qualification',
                design_type => 'CRD', design => {1 => {
                    plot_name => "${prefix}_plot_$i", stock_name => 'test_accession1',
                    plot_number => 1, rep_number => 7, block_number => 7, row_number => 1, col_number => 1,
                }},
            })->save_trial;
            die 'Native trial creation failed' if !$created->{trial_id};
            push @trials, $created->{trial_id};
            push @plots, $schema->resultset('Stock::Stock')->find({uniquename => "${prefix}_plot_$i"})->stock_id;
        }
        for my $i (0 .. 1) {
            my $suffix = $i ? 'C' : 'A';
            my $name = "${prefix}_lot_$suffix";
            my $stock = $schema->resultset('Stock::Stock')->create({
                name => $name, uniquename => $name, type_id => term('seedlot', 'stock_type'),
                organism_id => $schema->resultset('Stock::Stock')->find($germplasm[$i])->organism_id,
            });
            push @lots, $stock->stock_id;
            $schema->resultset('Stock::StockRelationship')->create({
                subject_id => $germplasm[$i], object_id => $lots[$i], type_id => term('collection_of', 'stock_relationship'),
            });
            push @transactions, CXGN::Stock::Seedlot::Transaction->new(
                schema => $schema, from_stock => [$lots[$i], $name], to_stock => [$lots[$i], $name],
                amount => 100, weight_gram => 50, factor => 1, operator => 'janedoe',
                timestamp => '2031-01-01', description => 'Private numeric opening balance',
            )->store;
        }
        for my $i (0 .. 1) {
            push @transactions, CXGN::Stock::Seedlot::Transaction->new(
                schema => $schema, from_stock => [$lots[0], "${prefix}_lot_A"],
                to_stock => [$plots[$i], "${prefix}_plot_$i"], amount => 10, weight_gram => 5,
                operator => 'janedoe', timestamp => '2031-01-02', description => 'Private planting packet',
            )->store;
        }
        for my $id (@lots) {
            my $seedlot = lot($schema, $id);
            $seedlot->set_current_count_property;
            $seedlot->set_current_weight_property;
        }
    });
    is_deeply([map { lot($schema, $_)->current_count } @lots], [80, 100], 'both committed private lots have known initial seed balances');
    is_deeply([map { lot($schema, $_)->current_weight } @lots], [40, 50], 'both committed private lots have known initial weight balances');
    if (!$ENV{AUDIT_SEEDLOT_BASELINE}) {
        subtest 'public paired cache refresh discards stale transactions' => sub {
            $schema->txn_begin;
            my $case_ok = eval {
                my $stale = lot($schema, $lots[0]);
                is_deeply([$stale->current_count, $stale->current_weight], [80, 40], 'one existing object has loaded the original transaction list');
                my $transaction = CXGN::Stock::Seedlot::Transaction->new(schema => $schema, transaction_id => $transactions[2]);
                $transaction->amount(20); $transaction->weight_gram(10); $transaction->store;
                my $raw_before = $dbh->selectall_arrayref('SELECT stock_relationship_id,value FROM stock_relationship WHERE stock_relationship_id=ANY(?) ORDER BY stock_relationship_id', undef, \@transactions);
                is_deeply($stale->recalculate_current_properties, {count => 70, weight_gram => 35}, 'paired recount reads changed committed/own transaction values rather than the old object array');
                is_deeply([$stale->get_current_count_property, $stale->get_current_weight_property], [70, 35], 'both cached properties are replaced by the same fresh transaction list');
                is_deeply($dbh->selectall_arrayref('SELECT stock_relationship_id,value FROM stock_relationship WHERE stock_relationship_id=ANY(?) ORDER BY stock_relationship_id', undef, \@transactions), $raw_before, 'cache recount never rewrites raw transaction values or provenance');
                $transaction->amount(10); $transaction->weight_gram(5); $transaction->store;
                is($stale->set_current_weight_property, 40, 'public weight setter keeps its scalar return and refreshes a stale object');
                is($stale->get_current_count_property, 80, 'public weight setter also preserves the paired current count');
                is($stale->set_current_count_property, 80, 'public count setter preserves its scalar return');
                is_deeply(CXGN::Stock::Seedlot::lock_for_recount($schema, [$lots[1], $lots[0], $lots[1]]), [sort {$a <=> $b} @lots], 'caller-transaction helper accepts and canonicalizes all participating lots');
                1;
            };
            my $case_error = $@; $schema->txn_rollback;
            ok($case_ok, 'stale-object and caller-owned transaction case rolled back') or diag($case_error);
        };
        subtest 'unknown and known zero balances keep their existing meanings' => sub {
            $schema->txn_begin;
            my $case_ok = eval {
                for my $id (@transactions[0, 2, 3]) {
                    my $transaction = CXGN::Stock::Seedlot::Transaction->new(schema => $schema, transaction_id => $id);
                    $transaction->amount('NA'); $transaction->weight_gram('NA'); $transaction->store;
                }
                my $seedlot = lot($schema, $lots[0]);
                is_deeply($seedlot->recalculate_current_properties, {count => 'NA', weight_gram => 'NA'}, 'all unknown quantities remain unknown for both dimensions');
                is_deeply([$seedlot->get_current_count_property, $seedlot->get_current_weight_property], ['NA', 'NA'], 'unknown cache values are stored explicitly');
                my $opening = CXGN::Stock::Seedlot::Transaction->new(schema => $schema, transaction_id => $transactions[0]);
                $opening->amount(0); $opening->weight_gram(0); $opening->store;
                is_deeply($seedlot->recalculate_current_properties, {count => 0, weight_gram => 0}, 'a known zero contribution remains zero alongside unknown contributions');
                is_deeply([$seedlot->get_current_count_property, $seedlot->get_current_weight_property], [0, 0], 'both zero cache values are retained');
                is($seedlot->set_current_count_property, 0, 'public scalar count setter preserves zero');
                is($seedlot->set_current_weight_property, 0, 'public scalar weight setter preserves zero');
                1;
            };
            my $case_error = $@; $schema->txn_rollback;
            ok($case_ok, 'unknown/zero mutation controls rolled back') or diag($case_error);
        };
    }
    pipe(my $ready_read, my $ready_write) or die "ready pipe: $!";
    pipe(my $release_read, my $release_write) or die "release pipe: $!";
    my @pids;
    my @statuses;
    my $run_worker = sub {
        my ($index, $with_barrier) = @_;
        my $pid = fork();
        die "fork: $!" if !defined($pid);
        if (!$pid) {
            $dbh->{InactiveDestroy} = 1;
            $peer->storage->dbh->{InactiveDestroy} = 1;
            close $ready_read;
            close $release_write;
            my $connection = Bio::Chado::Schema->connect(
                "dbi:Pg:dbname=$config->{dbname};host=$config->{dbhost}",
                $config->{dbuser}, $config->{dbpass},
            );
            $connection->storage->auto_savepoint(1);
            $connection->storage->dbh->do(q{SET statement_timeout='12s'});
            $connection->storage->dbh->selectrow_array(q{SELECT set_config('application_name',?,false)}, undef, "${prefix}_writer_$index");
            my $ran = eval {
                local $SIG{ALRM} = sub { die 'worker timed out' };
                alarm 20;
                my $original = \&CXGN::Stock::Seedlot::current_count;
                my $armed = $with_barrier;
                no warnings 'redefine';
                local *CXGN::Stock::Seedlot::current_count = sub {
                    my ($self) = @_;
                    my $value = $original->(@_);
                    my $in_recount = 0;
                    for my $depth (1 .. 16) {
                        my @frame = caller($depth);
                        last if !@frame;
                        $in_recount = 1 if ($frame[3] // '') =~ /^CXGN::Stock::Seedlot::(?:set_current_count_property|recalculate_current_properties)$/;
                    }
                    if ($armed && $self->seedlot_id == $lots[0] && $in_recount) {
                        $armed = 0;
                        die 'writer did not own a real transaction' if $connection->storage->dbh->{AutoCommit};
                        syswrite($ready_write, 'R', 1) == 1 or die "barrier ready: $!";
                        my $release;
                        sysread($release_read, $release, 1) == 1 or die 'barrier release missing';
                    }
                    return $value;
                };
                my $plan = apply_change($connection, $index);
                die 'worker did not move exactly one actual planting transaction'
                    if scalar(grep { $_->{type} eq 'seedlot' } @{$plan->{seedlots}}) != 1;
                die 'worker transaction did not commit' if !$connection->storage->dbh->{AutoCommit};
                die 'writer A calculation barrier did not fire' if $with_barrier && $armed;
                alarm 0;
                1;
            };
            my $error = $@;
            print STDERR "Private seedlot writer $index failed: $error\n" if !$ran;
            eval { $connection->storage->disconnect };
            POSIX::_exit($ran ? 0 : 1);
        }
        $pids[$index] = $pid;
        return $pid;
    };
    my $parallel_ok = eval {
        $run_worker->(0, 1);
        close $ready_write;
        close $release_read;
        my $select = IO::Select->new($ready_read);
        die 'writer A failed to reach calculation barrier' if !$select->can_read(10);
        my $ready;
        die 'writer A closed the barrier without reaching it' if sysread($ready_read, $ready, 1) != 1;
        is($ready, 'R', 'writer A paused after calculating under its actual transaction');
        $run_worker->(1, 0);
        my $deadline = time() + 5;
        my $blocked;
        while (time() < $deadline) {
            my $done = waitpid($pids[1], WNOHANG);
            if ($done == $pids[1]) { $statuses[1] = $?; last }
            $blocked = $dbh->selectrow_hashref(q{
                SELECT wait_event_type,query FROM pg_stat_activity
                WHERE application_name=? AND wait_event_type='Lock'
            }, undef, "${prefix}_writer_1");
            last if $blocked;
            sleep 0.02;
        }
        diag(defined($statuses[1]) ? 'Writer B completed while writer A was paused' : 'Writer B is still active at writer A release');
        if (!$ENV{AUDIT_SEEDLOT_BASELINE}) {
            ok($blocked, 'independent writer B actually waits on the shared seedlot row lock');
            like($blocked ? $blocked->{query} : '', qr/FOR NO KEY UPDATE/i, 'wait is the compatible seedlot row lock, rather than a global or project lock');
        }
        syswrite($release_write, 'G', 1) == 1 or die "release writer A: $!";
        close $release_write;
        local $SIG{ALRM} = sub { die 'waiting for correction workers timed out' };
        alarm 25;
        for my $index (0 .. 1) {
            next if defined($statuses[$index]);
            waitpid($pids[$index], 0) == $pids[$index] or die 'worker disappeared';
            $statuses[$index] = $?;
        }
        alarm 0;
        1;
    };
    my $parallel_error = $@;
    if (!$parallel_ok) {
        kill 'TERM', grep { defined($_) && $_ > 0 } @pids;
        waitpid($_, 0) for grep { defined($_) && $_ > 0 } @pids;
        die $parallel_error;
    }
    is_deeply(\@statuses, [0, 0], 'both independent real service correction processes exited successfully');
    die 'a real service writer failed' if grep { $_ != 0 } @statuses;
    ok($dbh->{AutoCommit} && $peer->storage->dbh->{AutoCommit}, 'both actual correction transactions committed');
    is_deeply($dbh->selectcol_arrayref('SELECT r.object_id FROM stock_relationship r WHERE r.subject_id=ANY(?) AND r.type_id=? ORDER BY r.subject_id', undef, \@plots, term('plot_of', 'stock_relationship')), [$germplasm[1], $germplasm[1]], 'both private plot identities are corrected to C');
    is_deeply($dbh->selectcol_arrayref('SELECT r.object_id FROM stock_relationship r WHERE r.subject_id=ANY(?) AND r.type_id=? ORDER BY r.subject_id', undef, \@plots, term('seed transaction', 'stock_relationship')), [$lots[1], $lots[1]], 'both original planting transactions now reference the C seedlot');
    my @fresh;
    for my $i (0 .. 1) {
        my $fresh = lot($schema, $lots[$i]);
        my ($count, $weight) = ($fresh->current_count, $fresh->current_weight);
        push @fresh, [$count, $weight];
        my $cached = [$fresh->get_current_count_property, $fresh->get_current_weight_property];
        my $sql = $dbh->selectrow_arrayref(q{
            SELECT SUM((value::jsonb->>'amount')::numeric *
                       CASE WHEN (value::jsonb->>'factor') IS NOT NULL THEN (value::jsonb->>'factor')::numeric
                            WHEN subject_id=? THEN 1 ELSE -1 END),
                   SUM((value::jsonb->>'weight_gram')::numeric *
                       CASE WHEN (value::jsonb->>'factor') IS NOT NULL THEN (value::jsonb->>'factor')::numeric
                            WHEN subject_id=? THEN 1 ELSE -1 END)
            FROM stock_relationship WHERE type_id=? AND (subject_id=? OR object_id=?)
        }, undef, $lots[$i], $lots[$i], term('seed transaction', 'stock_relationship'), $lots[$i], $lots[$i]);
        is_deeply([$count, $weight], $sql, ($i ? 'new C' : 'old A') . ' fresh class totals match independent committed SQL sums');
        diag(encode_json({lot => $i ? 'new_C' : 'old_A', cached => $cached, fresh => [$count, $weight], sql => $sql}));
        is_deeply($cached, [$count, $weight], ($i ? 'new C' : 'old A') . ' cached seed count AND weight equal fresh committed class totals');
    }
    is_deeply(\@fresh, [[100, 50], [80, 40]], 'fresh committed transaction totals retain both inventory conservation controls');
    1;
};
my $error = $@;
my $clean = eval { cleanup(); 1 };
my $cleanup_error = $@;
ok($ok, 'two real service processes and the controlled calculation interleaving completed') or diag($error);
ok($clean, 'only captured private trial, plot and seedlot IDs were removed') or diag($cleanup_error);
is($dbh->selectrow_array('SELECT count(*) FROM project WHERE project_id=ANY(?)', undef, \@trials), 0, 'no private trial remains');
is($dbh->selectrow_array('SELECT count(*) FROM stock WHERE stock_id=ANY(?)', undef, [@plots, @lots]), 0, 'no private plot or seedlot remains');
done_testing;
