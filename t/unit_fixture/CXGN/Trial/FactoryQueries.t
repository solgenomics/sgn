package main;

use strict;
use warnings;
use lib 't/lib';
use Test::More;
use SGN::Test::Fixture;
use CXGN::Trial;

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

sub measured_trial {
    my ($schema, $id) = @_;
    # Count the statement executes on this handle (DBIx::Class or direct DBI).
    # New statement handles inherit ChildCallbacks, so the statement cache is
    # cleared first.
    my $dbh = $schema->storage->dbh;
    my $count = 0;
    my $old_callbacks = $dbh->{Callbacks};
    $dbh->{CachedKids} = {};
    $dbh->{Callbacks} = { ChildCallbacks => { execute => sub { $count++; return; } } };
    my $trial;
    my $ok = eval {
        $trial = CXGN::Trial->new({ bcs_schema => $schema, trial_id => $id });
        1;
    };
    my $error = $@;
    $dbh->{Callbacks} = $old_callbacks;
    $dbh->{CachedKids} = {};
    die $error unless $ok;
    return ($trial, $count);
}

sub attributes {
    my ($trial) = @_;
    return [$trial->get_name, $trial->get_description,
        $trial->get_location, $trial->get_year];
}

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;
my $dbh = $schema->storage->dbh;
my ($id) = $dbh->selectrow_array('SELECT project_id FROM project WHERE name = ?',
    undef, 'test_trial');
die "Fixture trial test_trial not found\n" unless defined $id;
my ($plate_id) = $dbh->selectrow_array('SELECT project_id FROM project WHERE name = ?',
    undef, 'test_genotyping_project');
die "Fixture project test_genotyping_project not found\n" unless defined $plate_id;
my ($type_id) = $dbh->selectrow_array(
    "SELECT cvterm_id FROM cvterm JOIN cv USING (cv_id) " .
    "WHERE cv.name = 'project_property' AND cvterm.name = 'project_planting_date'"
);
die "Fixture project_planting_date term not found\n" unless defined $type_id;

my $sequences = sequence_values($dbh);
$schema->txn_begin;
my $ok = eval {
    my ($trial, $before) = measured_trial($schema, $id);
    isa_ok($trial, 'CXGN::PhenotypingTrial');
    my ($db_name, $db_description) = $dbh->selectrow_array(
        'SELECT name, description FROM project WHERE project_id = ?', undef, $id);
    is($trial->get_name, $db_name, 'name comes from the project row');
    is($trial->get_description, $db_description, 'description comes from the project row');
    my $original = attributes($trial);
    my ($rank) = $dbh->selectrow_array(
        'SELECT COALESCE(MAX(rank), -1) FROM projectprop WHERE project_id = ? AND type_id = ?',
        undef, $id, $type_id
    );
    for (1..10) {
        $schema->resultset('Project::Projectprop')->create({
            project_id => $id, type_id => $type_id, rank => ++$rank, value => 'test'
        });
    }
    $schema->resultset('Project::Projectprop')->create({
        project_id => $id, type_id => $type_id, rank => ++$rank, value => undef
    });
    my ($after_trial, $after) = measured_trial($schema, $id);
    isa_ok($after_trial, 'CXGN::PhenotypingTrial');
    is_deeply(attributes($after_trial), $original, 'trial attributes are unchanged');
    diag("Factory queries: before=$before, after=$after");
    cmp_ok($before, '>', 0, 'counter sees statements');
    is($after, $before, 'factory query count does not grow with the number of trial properties');

    my ($plate_rank) = $dbh->selectrow_array(
        'SELECT COALESCE(MAX(rank), -1) FROM projectprop WHERE project_id = ? AND type_id = ?',
        undef, $plate_id, $type_id
    );
    $schema->resultset('Project::Projectprop')->create({
        project_id => $plate_id, type_id => $type_id, rank => ++$plate_rank, value => 'genotyping_plate'
    });
    my ($plate, $plate_before) = measured_trial($schema, $plate_id);
    isa_ok($plate, 'CXGN::GenotypingTrial');
    for (1..10) {
        $schema->resultset('Project::Projectprop')->create({
            project_id => $plate_id, type_id => $type_id, rank => ++$plate_rank, value => 'test'
        });
    }
    $schema->resultset('Project::Projectprop')->create({
        project_id => $plate_id, type_id => $type_id, rank => ++$plate_rank, value => 'genotyping_plate'
    });
    my ($plate_after_trial, $plate_after) = measured_trial($schema, $plate_id);
    isa_ok($plate_after_trial, 'CXGN::GenotypingTrial');
    diag("Plate factory queries: before=$plate_before, after=$plate_after");
    cmp_ok($plate_before, '>', 0, 'counter sees statements');
    is($plate_after, $plate_before, 'factory query count does not grow with plate properties');

    # a project without properties, and one whose type marker comes after
    # ordinary properties
    my $empty = $schema->resultset('Project::Project')->create({
        name => "factory_test_empty_$$", description => 'factory test' });
    my $empty_trial = CXGN::Trial->new({ bcs_schema => $schema, trial_id => $empty->project_id });
    isa_ok($empty_trial, 'CXGN::PhenotypingTrial');
    is($empty_trial->get_name, "factory_test_empty_$$", 'project without properties keeps its name');
    my $late = $schema->resultset('Project::Project')->create({
        name => "factory_test_late_marker_$$", description => 'factory test' });
    for my $i (0 .. 2) {
        $schema->resultset('Project::Projectprop')->create({
            project_id => $late->project_id, type_id => $type_id, rank => $i, value => 'test' });
    }
    $schema->resultset('Project::Projectprop')->create({
        project_id => $late->project_id, type_id => $type_id, rank => 3, value => 'genotyping_plate' });
    isa_ok(CXGN::Trial->new({ bcs_schema => $schema, trial_id => $late->project_id }),
        'CXGN::GenotypingTrial');
    1;
};
my $error = $@;
$schema->txn_rollback;
restore_sequences($dbh, $sequences);
die $error unless $ok;
is_deeply(sequence_values($dbh), $sequences, 'sequences are back where they were');

done_testing();
