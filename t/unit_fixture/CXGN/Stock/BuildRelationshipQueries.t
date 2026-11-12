package main;

use strict;
use warnings;
use lib 't/lib';
use Test::More;
use SGN::Test::Fixture;
use CXGN::Stock;

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

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema();
my $accession = $schema->resultset('Stock::Stock')->find({ uniquename => 'UG120003' })
    or die 'Fixture accession UG120003 not found';
my $id = $accession->stock_id();
my $dbh = $schema->storage->dbh();

sub sorted_rows {
    my ($rows) = @_;
    return [sort { join("\t", @$a) cmp join("\t", @$b) } @$rows];
}

sub check_relationships {
    my ($stock, $label) = @_;
    for my $side (qw(object subject)) {
        my $sql = "SELECT s.stock_id, s.uniquename, t.name FROM stock_relationship r "
            . "JOIN stock s ON s.stock_id = r.${side}_id "
            . "JOIN cvterm t ON t.cvterm_id = r.type_id WHERE r.${side}_id = ?";
        my $expected = $dbh->selectall_arrayref($sql, undef, $id);
        my $actual = $side eq 'object' ? $stock->objects() : $stock->subjects();
        is_deeply(sorted_rows($actual), sorted_rows($expected), "$label ${side}s match SQL");
    }
}

sub measured_stock {
    # Count every statement executed through DBI, by DBIx::Class or directly.
    # New statement handles inherit ChildCallbacks, so the statement cache is
    # cleared first.
    my $count = 0;
    my $old_callbacks = $dbh->{Callbacks};
    $dbh->{CachedKids} = {};
    $dbh->{Callbacks} = { ChildCallbacks => { execute => sub { $count++; return; } } };
    my ($stock, $error);
    eval {
        $stock = CXGN::Stock->new(schema => $schema, stock_id => $id);
        1;
    } or $error = $@ || 'Constructor failed';
    $dbh->{Callbacks} = $old_callbacks;
    $dbh->{CachedKids} = {};
    die $error if defined $error;
    return ($stock, $count);
}

my ($stock, $before) = measured_stock();
check_relationships($stock, 'Before');
my $sequences = sequence_values($schema->storage->dbh);
$schema->txn_begin();
my $error;
eval {
    my $plot_type = $schema->resultset('Cv::Cvterm')->find(
        { 'me.name' => 'plot', 'cv.name' => 'stock_type' }, { join => 'cv' })
        or die 'plot cvterm not found';
    my $rel_type = $schema->resultset('Cv::Cvterm')->find(
        { 'me.name' => 'plot_of', 'cv.name' => 'stock_relationship' }, { join => 'cv' })
        or die 'plot_of cvterm not found';
    my $accession_type = $schema->resultset('Cv::Cvterm')->find(
        { 'me.name' => 'accession', 'cv.name' => 'stock_type' }, { join => 'cv' })
        or die 'accession cvterm not found';
    my $female_parent_type = $schema->resultset('Cv::Cvterm')->find(
        { 'me.name' => 'female_parent', 'cv.name' => 'stock_relationship' }, { join => 'cv' })
        or die 'female_parent cvterm not found';
    for my $i (1 .. 50) {
        # incoming link: the plot is the subject, the accession the object
        my $plot = $schema->resultset('Stock::Stock')->create({
            uniquename => "relq_plot_${i}_$$", organism_id => $accession->organism_id(),
            type_id => $plot_type->cvterm_id(),
        });
        $schema->resultset('Stock::StockRelationship')->create({
            subject_id => $plot->stock_id(), object_id => $id, type_id => $rel_type->cvterm_id(),
        });
        # outgoing link: the accession is the female parent (subject) of the offspring (object)
        my $offspring = $schema->resultset('Stock::Stock')->create({
            uniquename => "relq_offspring_${i}_$$", organism_id => $accession->organism_id(),
            type_id => $accession_type->cvterm_id(),
        });
        $schema->resultset('Stock::StockRelationship')->create({
            subject_id => $id, object_id => $offspring->stock_id(), type_id => $female_parent_type->cvterm_id(),
        });
    }
    my ($after_stock, $after) = measured_stock();
    check_relationships($after_stock, 'After');
    diag("Constructor queries: before=$before, after=$after");
    is($after, $before, 'constructor query count does not grow with the number of relationships');
    1;
} or $error = $@ || 'Relationship test failed';
$schema->txn_rollback();
restore_sequences($schema->storage->dbh, $sequences);
die $error if defined $error;
is_deeply(sequence_values($schema->storage->dbh), $sequences, 'sequences are back where they were');

done_testing();
