use strict;
use warnings;

use Test::More;
use lib 't/lib';
use SGN::Test::Fixture;
use SGN::Model::Cvterm;
use CXGN::Phenotypes::SearchFactory;

# The Native phenotype search with exclude_phenotype_outlier must leave out
# the values marked as outliers and nothing else: a plot without any value
# stays in the result, as it does without the option.

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema();
my $dbh = $schema->storage->dbh();

# This fixture trial has plots with values and plots without any value.
my $trial_id = $schema->resultset('Project::Project')->find({ name => 'CASS_6Genotypes_Sampling_2015' })->project_id();

sub search {
    my $exclude = shift;
    my $search = CXGN::Phenotypes::SearchFactory->instantiate('Native', {
        bcs_schema => $schema,
        data_level => 'plot',
        trial_list => [$trial_id],
        exclude_phenotype_outlier => $exclude,
    });
    my $rows = $search->search();
    my (%units, %values);
    foreach my $row (@$rows) {
        $units{ $row->{obsunit_stock_id} } = 1;
        $values{ $row->{phenotype_id} } = $row->{obsunit_stock_id} if $row->{phenotype_id};
    }
    return (\%units, \%values);
}

$schema->txn_begin();

my ($all_units, $all_values) = search(0);
my %measured = map { $_ => 1 } values %$all_values;
my @unmeasured = grep { !$measured{$_} } keys %$all_units;
cmp_ok(scalar(keys %measured), '>=', 1, 'the trial has plots with values');
cmp_ok(scalar(@unmeasured), '>=', 1, 'the trial has plots without any value');

# Mark one value as an outlier.
my ($outlier_value) = sort { $a <=> $b } keys %$all_values;
my $outlier_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'phenotype_outlier', 'phenotype_property')->cvterm_id();
$dbh->do("INSERT INTO phenotypeprop (phenotype_id, type_id, value) VALUES (?, ?, '1')", undef, $outlier_value, $outlier_type_id);

my ($kept_units, $kept_values) = search(1);
ok(!$kept_values->{$outlier_value}, 'the marked value is left out with the option');
is(scalar(keys %$kept_values), scalar(keys %$all_values) - 1, 'every other value stays');
is_deeply([sort keys %$kept_units], [sort keys %$all_units], 'the plots without any value stay in the result');

$schema->txn_rollback();

done_testing();
