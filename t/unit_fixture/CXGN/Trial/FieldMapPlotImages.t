package main;

use strict;
use warnings;
use lib 't/lib';
use Test::More;
use SGN::Test::Fixture;
use CXGN::Trial::FieldMap;
use CXGN::Trial::TrialLayout;

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
my $dbh = $schema->storage->dbh();
my $trial_id = 139;
my $map = CXGN::Trial::FieldMap->new(
    bcs_schema => $schema, trial_id => $trial_id, experiment_type => 'field_layout',
);

my $sequences = sequence_values($schema->storage->dbh);

$schema->txn_begin();
my $error;
eval {
    my $layout = CXGN::Trial::TrialLayout->new({
        schema => $schema, trial_id => $trial_id, experiment_type => 'field_layout',
    });
    my $design = $layout->get_design();
    my @plots = map { $design->{$_}->{plot_id} } sort { $a <=> $b } keys %$design;
    die 'Fixture trial 139 must contain at least two plots' unless @plots >= 2;
    my @images;
    for my $obsolete ('f', 'f', 'f', 't') {
        my ($id) = $dbh->selectrow_array(
            'INSERT INTO metadata.md_image (name, obsolete) VALUES (?, ?) RETURNING image_id',
            undef, "fieldmap_plot_image_$$", $obsolete,
        );
        push @images, $id;
    }
    my $link = $dbh->prepare(
        'INSERT INTO phenome.stock_image (stock_id, image_id, display_order) VALUES (?, ?, ?)'
    );
    $link->execute($plots[0], $images[0], 20);
    $link->execute($plots[0], $images[1], 10);
    $link->execute($plots[0], $images[3], 1);
    $link->execute($plots[1], $images[2], 10);

    # Count the statement executes on this handle (DBIx::Class or direct DBI),
    # the single-stock lookups and the image queries among them. New statement
    # handles inherit ChildCallbacks, so the statement cache is cleared first.
    my $counter = { count => 0, stock_lookups => 0, image_queries => 0 };
    my $old_callbacks = $dbh->{Callbacks};
    $dbh->{CachedKids} = {};
    $dbh->{Callbacks} = { ChildCallbacks => { execute => sub {
        $counter->{count}++;
        my $sql = $_[0]->{Statement} || '';
        $counter->{stock_lookups}++ if $sql =~ /FROM stock me WHERE \( me\.stock_id = \?/;
        $counter->{image_queries}++ if $sql =~ /\bstock_image\b/;
        return;
    } } };
    my ($result, $call_error);
    eval {
        $result = $map->display_fieldmap();
        1;
    } or $call_error = $@ || 'display_fieldmap failed';
    $dbh->{Callbacks} = $old_callbacks;
    $dbh->{CachedKids} = {};
    die $call_error if defined $call_error;

    my %coords = map { $_->{plot_id} => $_->{plot_image_ids} } @{$result->{coords}};
    is(scalar(@{$result->{coords}}), scalar(@plots), 'all fixture plots are returned');
    for my $plot (@{$result->{coords}}) {
        my $expected = $dbh->selectcol_arrayref(
            q{SELECT DISTINCT image_id, cvterm.name, stock_image.display_order
              FROM phenome.stock_image JOIN stock USING(stock_id)
              JOIN cvterm ON(type_id=cvterm_id) JOIN metadata.md_image USING(image_id)
              WHERE stock_id = ? AND obsolete = 'f' ORDER BY stock_image.display_order ASC},
            undef, $plot->{plot_id},
        );
        is_deeply($plot->{plot_image_ids}, $expected, "plot $plot->{plot_id} images match SQL");
    }
    is_deeply($coords{$plots[0]}, [@images[1, 0]], 'images follow display order; obsolete omitted');
    is_deeply($coords{$plots[1]}, [$images[2]], 'second plot has its image');
    is($counter->{stock_lookups}, 0, 'no per-plot stock lookups');
    is($counter->{image_queries}, 1, 'the images of all plots are read with one query');
    diag("Statements: $counter->{count}; per-plot stock lookups: $counter->{stock_lookups}; "
        . "image queries: $counter->{image_queries}");
    1;
} or $error = $@ || 'FieldMap image test failed';
$schema->txn_rollback();
restore_sequences($schema->storage->dbh, $sequences);
die $error if defined $error;
is_deeply(sequence_values($schema->storage->dbh), $sequences, 'sequences are back where they were');

done_testing();
