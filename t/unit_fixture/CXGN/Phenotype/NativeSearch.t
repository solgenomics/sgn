use strict;
use warnings;

use lib 't/lib';

use Test::More;
use SGN::Test::Fixture;
use CXGN::Phenotypes::Search::Native;

my $fixture = SGN::Test::Fixture->new();

my $search = CXGN::Phenotypes::Search::Native->new(
    bcs_schema => $fixture->bcs_schema,
    data_level => 'all',
    trial_list => [137],
);

# This is the Search Wizard download case that previously searched the global
# phenotype join: a trial-scoped all-level search with no explicit unit lists.
ok(!defined($search->plot_list), 'search has no explicit plot list');
ok(!defined($search->plant_list), 'search has no explicit plant list');
ok(!defined($search->subplot_list), 'search has no explicit subplot list');

my $dbh = $fixture->bcs_schema->storage->dbh;
my $dbh_class = ref($dbh);
my $original_selectcol_arrayref = $dbh->can('selectcol_arrayref');
my $trial_observationunit_prefilters = 0;
my $data;

{
    no strict 'refs';
    no warnings 'redefine';

    local *{"${dbh_class}::selectcol_arrayref"} = sub {
        my ($handle, $query, @args) = @_;
        $trial_observationunit_prefilters++
            if $query =~ /WHERE nd_experiment_project\.project_id IN/;
        return $original_selectcol_arrayref->($handle, $query, @args);
    };

    $data = $search->search();
}

is(
    $trial_observationunit_prefilters,
    1,
    'trial observation units are resolved before the phenotype join',
);
ok(@$data > 0, 'trial-only all-level Native search returns observations');

my %trial_ids = map { $_->{trial_id} => 1 } @$data;
is_deeply(
    [sort { $a <=> $b } keys %trial_ids],
    [137],
    'trial-only all-level Native search remains scoped to the requested trial',
);

my %observation_levels = map { $_->{obsunit_type_name} => 1 } @$data;
ok($observation_levels{plot}, 'all-level search includes plots');

$fixture->clean_up_db();

done_testing();
