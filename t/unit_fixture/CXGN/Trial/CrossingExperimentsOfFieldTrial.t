# Tests get_crossing_experiments_from_field_trial: a crossing experiment is
# linked to a field trial when one of its crosses used a plot or a plant of the
# trial as the female or the male parent.
#
# The test runs in a transaction that is rolled back at the end, and every case
# in a savepoint that is rolled back after it, so the fixture does not change
# for other tests (reading the trial layout caches it).

use strict;
use warnings;

use lib 't/lib';
use Test::More;
use SGN::Test::Fixture;
use SGN::Model::Cvterm;
use CXGN::Trial;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;
$schema->storage->auto_savepoint(1);

sub cvterm_id { return SGN::Model::Cvterm->get_cvterm_row($schema, $_[0], $_[1])->cvterm_id(); }

my $trial_id = $schema->resultset('Project::Project')->find({ name => 'test_trial' })->project_id();
my $plot = $schema->resultset('Stock::Stock')->find({ uniquename => 'test_trial21' });

sub crossing_experiments_of_trial {
    my $trial = CXGN::Trial->new({ bcs_schema => $schema, trial_id => $trial_id });
    # sorted: the query has no ORDER BY
    return [ sort map { $_->[1] } @{ $trial->get_crossing_experiments_from_field_trial() } ];
}

# A crossing experiment with one cross that has the given parent, as the
# crossing tools store it.
sub add_crossing_experiment {
    my ($name, $parent_id, $relationship) = @_;
    my $cross_experiment = cvterm_id('cross_experiment', 'experiment_type');

    my $project = $schema->resultset('Project::Project')->create({ name => $name, description => 'test crossing experiment' });
    my $experiment = $schema->resultset('NaturalDiversity::NdExperiment')->create({
        nd_geolocation_id => $schema->resultset('NaturalDiversity::NdGeolocation')->search({})->first->nd_geolocation_id,
        type_id => $cross_experiment,
    });
    $experiment->create_related('nd_experiment_projects', { project_id => $project->project_id });

    my $cross = $schema->resultset('Stock::Stock')->create({
        organism_id => $plot->organism_id,
        name => "${name}_cross",
        uniquename => "${name}_cross",
        type_id => cvterm_id('cross', 'stock_type'),
    });
    $experiment->create_related('nd_experiment_stocks', { stock_id => $cross->stock_id, type_id => $cross_experiment });
    $schema->resultset('Stock::StockRelationship')->create({
        subject_id => $parent_id,
        object_id => $cross->stock_id,
        type_id => cvterm_id($relationship, 'stock_relationship'),
    });
}

$schema->txn_begin();
my $before = crossing_experiments_of_trial();

foreach my $relationship (qw(female_plot_of male_plot_of female_plant_of male_plant_of)) {
    subtest "a cross with $relationship a stock of the field trial" => sub {
        $schema->txn_begin();
        my $ok = eval {
            my $parent_id = $plot->stock_id;
            if ($relationship =~ /plant/) {
                CXGN::Trial->new({ bcs_schema => $schema, trial_id => $trial_id })->create_plant_entities(1);
                $parent_id = $schema->resultset('Stock::StockRelationship')->search({
                    subject_id => $plot->stock_id,
                    type_id => cvterm_id('plant_of', 'stock_relationship'),
                })->first->object_id;
            }

            my $name = "crossing_experiment_$relationship";
            add_crossing_experiment($name, $parent_id, $relationship);

            my $after = crossing_experiments_of_trial();
            is(scalar(@$after), scalar(@$before) + 1, 'the trial has one more crossing experiment');
            ok((grep { $_ eq $name } @$after), "it is $name");
            1;
        };
        my $error = $@;
        $schema->txn_rollback();
        ok($ok, 'ran') or diag($error);
    };
}

is_deeply(crossing_experiments_of_trial(), $before, 'every case is rolled back');
$schema->txn_rollback();

done_testing();
