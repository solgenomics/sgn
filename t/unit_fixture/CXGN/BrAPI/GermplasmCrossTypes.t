package main;

use strict;
use warnings;
use lib 't/lib';
use Test::More;
use SGN::Test::Fixture;
use SGN::Model::Cvterm;
use CXGN::BrAPI::v2::Germplasm;

# Rolled-back inserts still move sequences. Put the moved ones back to their
# exact state, so later tests in the same database that expect fixed new ids
# are not affected.
sub sequence_values {
    my ($dbh) = @_;
    my $names = $dbh->selectcol_arrayref(
        "SELECT format('%I.%I', schemaname, sequencename) FROM pg_sequences");
    my %values;
    for my $name (@$names) {
        my ($last, $called) = $dbh->selectrow_array("SELECT last_value, is_called FROM $name");
        $values{$name} = [$last, $called ? 1 : 0];
    }
    return \%values;
}

sub restore_sequences {
    my ($dbh, $values) = @_;
    my $now = sequence_values($dbh);
    for my $name (sort keys %$values) {
        my ($last, $called) = @{ $values->{$name} };
        my ($now_last, $now_called) = @{ $now->{$name} };
        next if $now_last == $last && $now_called == $called;
        $dbh->do('SELECT setval(?::regclass, ?, ?)', undef, $name, $last, $called);
    }
    return;
}

{
    package Local::CrossTypeCounter;
    sub new { return bless { count => 0 }, shift }
    sub execute {
        my ($self, $sth) = @_;
        # any read of the relationship value, one row or many at a time
        $self->{count}++ if ($sth->{Statement} || '') =~ /\bvalue\s+FROM\s+stock_relationship\b/i;
        return;
    }
}

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema();
my $dbh = $schema->storage->dbh();
my $accession_type = SGN::Model::Cvterm->get_cvterm_row(
    $schema, 'accession', 'stock_type')->cvterm_id();
my $female_type = SGN::Model::Cvterm->get_cvterm_row(
    $schema, 'female_parent', 'stock_relationship')->cvterm_id();

sub measured_search {
    my ($ids) = @_;
    my $api = CXGN::BrAPI::v2::Germplasm->new({
        bcs_schema => $schema, people_schema => $f->people_schema(),
        phenome_schema => $f->phenome_schema(), metadata_schema => $f->metadata_schema(),
        context => undef, page_size => scalar(@$ids), page => 0, status => [],
    });
    my $counter = Local::CrossTypeCounter->new();
    my $old_callbacks = $dbh->{Callbacks};
    my %callbacks = %{$old_callbacks || {}};
    my %child_callbacks = %{$callbacks{ChildCallbacks} || {}};
    $child_callbacks{execute} = sub { $counter->execute($_[0]); return };
    $callbacks{ChildCallbacks} = \%child_callbacks;
    $dbh->{CachedKids} = {};
    my ($response, $search_error);
    eval {
        $dbh->{Callbacks} = \%callbacks;
        $response = $api->search({ germplasmDbIds => $ids }, undef);
        1;
    } or $search_error = $@ || 'Germplasm search failed';
    $dbh->{Callbacks} = $old_callbacks;
    $dbh->{CachedKids} = {};
    die $search_error if defined $search_error;
    return ($response, $counter->{count});
}

my $sequences = sequence_values($schema->storage->dbh);

$schema->txn_begin();
my $error;
eval {
    my $with_parent = $dbh->selectcol_arrayref(
        'SELECT s.stock_id FROM stock s WHERE s.type_id = ? AND EXISTS '
        . '(SELECT 1 FROM stock_relationship r WHERE r.object_id = s.stock_id '
        . 'AND r.type_id = ?) ORDER BY s.stock_id LIMIT 4',
        undef, $accession_type, $female_type,
    );
    my $without_parent = $dbh->selectcol_arrayref(
        'SELECT s.stock_id FROM stock s WHERE s.type_id = ? AND NOT EXISTS '
        . '(SELECT 1 FROM stock_relationship r WHERE r.object_id = s.stock_id '
        . 'AND r.type_id = ?) ORDER BY s.stock_id LIMIT 2',
        undef, $accession_type, $female_type,
    );
    die 'Fixture needs four accessions with female parents and two without'
        unless @$with_parent == 4 && @$without_parent == 2;
    my @small = ($with_parent->[0], $with_parent->[1], $without_parent->[0]);
    my @large = (@small, $with_parent->[2], $with_parent->[3], $without_parent->[1]);
    my $update = $dbh->prepare(
        'UPDATE stock_relationship SET value = ? WHERE object_id = ? AND type_id = ?'
    );
    $update->execute('test_cross_type', $small[0], $female_type);
    $update->execute(undef, $small[1], $female_type);
    # a second female link, added later but with a lower rank: the lowest rank wins
    $dbh->do(
        'INSERT INTO stock_relationship (subject_id, object_id, type_id, value, rank) '
        . 'SELECT ?, ?, ?, ?, coalesce(min(rank), 0) - 1 FROM stock_relationship '
        . 'WHERE object_id = ? AND type_id = ?',
        undef, $small[2], $small[0], $female_type, 'lowest_rank_value', $small[0], $female_type,
    );

    my ($small_response, $small_count) = measured_search(\@small);
    my ($large_response, $large_count) = measured_search(\@large);
    for my $case ([\@small, $small_response], [\@large, $large_response]) {
        my ($ids, $response) = @$case;
        my $rows = $response->{result}->{data};
        is_deeply([sort { $a <=> $b } map { $_->{germplasmDbId} } @$rows],
            [sort { $a <=> $b } @$ids], 'page of ' . scalar(@$ids) . ' contains the selected accessions');
        for my $row (@$rows) {
            my ($value) = $dbh->selectrow_array(
                'SELECT value FROM stock_relationship WHERE object_id = ? AND type_id = ? '
                . 'ORDER BY rank, stock_relationship_id LIMIT 1',
                undef, $row->{germplasmDbId}, $female_type,
            );
            $value = 'unknown' unless defined $value;
            is($row->{breedingMethodDbId}, $value,
                "germplasm $row->{germplasmDbId} cross type matches SQL");
        }
    }
    diag("Cross-type queries: page of 3 = $small_count, page of 6 = $large_count");
    cmp_ok($small_count, '>', 0, 'counter sees the cross-type query');
    is($large_count, $small_count, 'cross-type queries do not grow with the page size');
    1;
} or $error = $@ || 'Germplasm cross-type test failed';
$schema->txn_rollback();
restore_sequences($schema->storage->dbh, $sequences);
die $error if defined $error;
is_deeply(sequence_values($schema->storage->dbh), $sequences, 'sequences are back where they were');

done_testing();
