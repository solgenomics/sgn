use strict;
use warnings;
use lib 't/lib';
use Test::More;
use Test::WWW::Mechanize;
use JSON;
use IO::Handle;
use POSIX qw(_exit);
use Time::HiRes qw(time usleep);
use Bio::Chado::Schema;
use SGN::Test::Fixture;
use SGN::Model::Cvterm;
use CXGN::Stock;
use CXGN::Pedigree::AddPedigrees;
use CXGN::Pedigree::AddProgeniesExistingAccessions;

my $f = SGN::Test::Fixture->new;
my $schema = $f->bcs_schema;
my $seed = $schema->resultset('Stock::Stock')->find({uniquename => 'test_accession1'});
my $at = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id;
my $ct = SGN::Model::Cvterm->get_cvterm_row($schema, 'cross', 'stock_type')->cvterm_id;
my $ft = SGN::Model::Cvterm->get_cvterm_row($schema, 'female_parent', 'stock_relationship')->cvterm_id;
my $mt = SGN::Model::Cvterm->get_cvterm_row($schema, 'male_parent', 'stock_relationship')->cvterm_id;
my $father = $schema->resultset('Stock::Stock')->find({uniquename => 'test_accession2'});
my @created;
for my $kind (qw(child cross)) {
    push @created, $schema->resultset('Stock::Stock')->create({
        name => 'parentage_concurrent_'.$kind, uniquename => 'parentage_concurrent_'.$kind,
        type_id => $kind eq 'cross' ? $ct : $at, organism_id => $seed->organism_id,
    });
}
my ($child, $cross) = @created;
$schema->resultset('Stock::StockRelationship')->create({
    subject_id => $seed->stock_id, object_id => $cross->stock_id, type_id => $ft, value => 'open',
});
sub pedigree {
    my ($s, $type) = @_;
    return CXGN::Pedigree::AddPedigrees->new(schema => $s)->generate_pedigrees([{
        'progeny name' => $child->uniquename, 'female parent accession' => 'test_accession1',
        'male parent accession' => $type eq 'open' ? '' : 'test_accession2', type => $type,
    }]);
}
sub reset_pair {
    # Give every interleaving the same mother-only starting state, including
    # when this test is run against an older overwrite implementation.
    $schema->resultset('Stock::StockRelationship')->search({
        object_id => $child->stock_id, type_id => {-in => [$ft, $mt]},
    })->delete;
    my $r = CXGN::Pedigree::AddPedigrees->new(schema => $schema, pedigrees => pedigree($schema, 'open'))->add_pedigrees(1);
    die $r->{error} if $r->{error};
}
my $mech = Test::WWW::Mechanize->new;
$mech->post_ok('http://localhost:3010/brapi/v1/token', [username => 'janedoe', password => 'secretpw', grant_type => 'password']);

# Hold the same child-row lock used by the paired save, then run another writer
# in a separate process/connection. PostgreSQL must report that writer waiting
# for the lock; after release it must finish normally. No timing-only inference.
sub waits_for_child {
    my ($name, $action, $http) = @_;
    reset_pair();
    $schema->txn_begin;
    $schema->resultset('Stock::Stock')->find($child->stock_id, {for => 'update'});
    pipe(my $reader, my $writer) or die $!;
    my $pid = fork;
    die 'fork failed' unless defined $pid;
    if (!$pid) {
        close $reader;
        $writer->autoflush(1);
        my $cfg = $f->config;
        my $s = Bio::Chado::Schema->connect('dbi:Pg:dbname='.$cfg->{dbname}.';host='.$cfg->{dbhost}, $cfg->{dbuser}, $cfg->{dbpass});
        my ($backend) = $s->storage->dbh->selectrow_array('SELECT pg_backend_pid()');
        print $writer "$backend\n";
        my $result = eval { $action->($s) };
        $result = {error => "$@"} if $@;
        $s->storage->disconnect;
        print $writer encode_json($result)."\n";
        close $writer;
        _exit(0); # Do not destroy inherited handles belonging to the parent.
    }
    close $writer;
    my $backend = <$reader>;
    chomp $backend;
    my $waiting = 0;
    my $deadline = time + 5;
    while (time < $deadline) {
        my ($count) = $http
            ? $f->dbh->selectrow_array(q{SELECT count(*) FROM pg_stat_activity WHERE datname = current_database() AND wait_event_type = 'Lock' AND query ILIKE '%FOR UPDATE%'})
            : $f->dbh->selectrow_array(q{SELECT count(*) FROM pg_stat_activity WHERE pid = ? AND wait_event_type = 'Lock'}, undef, $backend);
        if ($count) { $waiting = 1; last; }
        usleep(50000);
    }
    ok($waiting, "$name waits while the paired save is in progress");
    # Complete the in-flight paired save by adding a father. An overwrite that
    # deleted roles before waiting for the child lock would miss this new row.
    $schema->resultset('Stock::StockRelationship')->create({
        subject_id => $father->stock_id, object_id => $child->stock_id, type_id => $mt,
    });
    $schema->txn_commit;
    my $line = <$reader>;
    close $reader;
    waitpid $pid, 0;
    my $result = eval { decode_json($line) } || {error => 'worker returned no JSON'};
    ok(!$result->{error}, "$name completes after the lock is released") or diag($result->{error});
    if (!$http) {
        is($schema->resultset('Stock::StockRelationship')->search({object_id => $child->stock_id, type_id => $mt})->count,
            0, "$name replaces the complete committed pair, including the concurrent father");
    }
}
waits_for_child('pedigree upload overwrite', sub {
    my $s = shift;
    return CXGN::Pedigree::AddPedigrees->new(schema => $s, pedigrees => pedigree($s, 'open'))->add_pedigrees(1);
});
waits_for_child('copy cross pedigree overwrite', sub {
    my $s = shift;
    return CXGN::Pedigree::AddProgeniesExistingAccessions->new(chado_schema => $s,
        cross_name => $cross->uniquename, progeny_names => [$child->uniquename])->add_progenies_existing_accessions(1);
});
waits_for_child('role-specific HTTP removal', sub {
    $mech->post('http://localhost:3010/ajax/stock/parent/remove', [
        stock_id => $child->stock_id, parent_id => $seed->stock_id, parent_type => 'female',
    ]);
    return decode_json($mech->content);
}, 1);

my @ids = map {$_->stock_id} @created;
$schema->resultset('Stock::StockRelationship')->search({-or => [object_id => {-in => \@ids}, subject_id => {-in => \@ids}]})->delete;
$_->delete for reverse @created;
$f->clean_up_db;
done_testing;
