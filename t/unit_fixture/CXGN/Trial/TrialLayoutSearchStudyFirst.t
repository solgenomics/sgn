use strict;
use warnings;

use lib 't/lib';

use Test::More;
use JSON;
use SGN::Test::Fixture;
use CXGN::Trial::TrialLayoutSearch;
use CXGN::BrAPI::v2::ObservationUnits;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema();

sub search_layout {
    my (%args) = @_;
    return CXGN::Trial::TrialLayoutSearch->new({
        bcs_schema => $schema,
        data_level => 'all',
        experiment_type => 'field_layout',
        include_observations => 0,
        %args,
    })->search();
}

sub compare_by_units {
    my ($label, $rows, $observations, %filters) = @_;
    my @ids = map { $_->{obsunit_stock_id} } @$rows;
    ok(@ids, "$label has observation units");
    return unless @ids;

    my ($by_units, $unit_observations) = search_layout(
        observation_unit_id_list => \@ids,
        %filters,
    );
    # A unit can have several rows: order them by their whole content too.
    my $json = JSON->new->canonical(1);
    my $order = sub { $_[0]->{obsunit_stock_id} <=> $_[1]->{obsunit_stock_id}
        || $json->encode($_[0]) cmp $json->encode($_[1]) };
    my @study_sorted = sort { $order->($a, $b) } @$rows;
    my @unit_sorted = sort { $order->($a, $b) } @$by_units;
    is_deeply(\@study_sorted, \@unit_sorted, "$label returns the same full rows and counts");
    is_deeply($observations, $unit_observations, "$label returns the same observations");
}

# These checks also pass on master: the statement count is unchanged, so a fixture
# test cannot demonstrate the reduced work inside PostgreSQL.
my %trial_rows;
for my $trial_id (137, 139) {
    my ($rows, $observations) = search_layout(trial_list => [$trial_id]);
    $trial_rows{$trial_id} = $rows;
    compare_by_units("trial $trial_id", $rows, $observations);
}

my ($both, $both_observations) = search_layout(trial_list => [137, 139]);
compare_by_units('two trials', $both, $both_observations);
is(scalar(@$both), scalar(@{$trial_rows{137}}) + scalar(@{$trial_rows{139}}),
    'two trials contain both individual results');

my ($accession) = map { $_->{germplasm_stock_id} }
    grep { defined $_->{germplasm_stock_id} } @{$trial_rows{137}};
ok(defined $accession, 'trial 137 has an accession');
if (defined $accession) {
    my ($rows, $observations) = search_layout(trial_list => [137], accession_list => [$accession]);
    compare_by_units('trial and accession', $rows, $observations, accession_list => [$accession]);
    ok(!scalar(grep { !defined $_->{germplasm_stock_id} || $_->{germplasm_stock_id} != $accession } @$rows),
        'accession filter excludes other accessions');
}

my ($plots, $plot_observations) = search_layout(trial_list => [137], data_level => 'plot');
compare_by_units('trial and plot level', $plots, $plot_observations, data_level => 'plot');
ok(!scalar(grep { $_->{obsunit_type_name} ne 'plot' } @$plots), 'plot filter returns only plots');

subtest 'BrAPI sorts the study plots numerically when configured' => sub {
    local $f->config->{brapi_ou_order_plot_num} = 1;
    my $brapi = CXGN::BrAPI::v2::ObservationUnits->new(
        bcs_schema => $schema, metadata_schema => $f->metadata_schema,
        phenome_schema => $f->phenome_schema, people_schema => $f->people_schema,
        context => $f, page => 0, page_size => 4, status => [],
    );
    my @expected = sort {
        $a->{plot_number} <=> $b->{plot_number}
            || $a->{obsunit_stock_id} <=> $b->{obsunit_stock_id}
    } @$plots;
    my $response = $brapi->search({studyDbId => [137], observationUnitLevelName => ['plot']}, $f);
    is_deeply([map { $_->{observationUnitDbId} } @{$response->{result}{data}}],
        [map { $_->{obsunit_stock_id} } @expected[0 .. 3]], 'first page follows numeric plot order');
};

my $page_size = 2;
my ($page, $page_observations) = search_layout(trial_list => [137], limit => $page_size, offset => $page_size);
ok(@{$trial_rows{137}} >= 2 * $page_size, 'trial has a second page');
if (@{$trial_rows{137}} >= 2 * $page_size) {
    my @expected = @{$trial_rows{137}}[$page_size .. 2 * $page_size - 1];
    is_deeply($page, \@expected, 'second page matches the default unlimited order');
    is($page->[0]->{full_count}, scalar(@{$trial_rows{137}}), 'page reports the unlimited count');
}
is_deeply($page_observations, undef, 'page observations are absent when not requested');

my %tied_order = (trial_list => [137], order_by => 'project.project_id');
my ($tied_rows) = search_layout(%tied_order);
my @expected_ids = sort { $a <=> $b } map { $_->{obsunit_stock_id} } @$tied_rows;
my ($first_tied_page) = search_layout(%tied_order, limit => $page_size);
my ($second_tied_page) = search_layout(%tied_order, limit => $page_size, offset => $page_size);
is_deeply(
    [map { $_->{obsunit_stock_id} } @$first_tied_page, @$second_tied_page],
    [@expected_ids[0 .. 2 * $page_size - 1]],
    'consecutive pages use observation unit IDs to break ties',
);

my ($missing, $missing_observations) = search_layout(trial_list => [-1]);
is_deeply($missing, [], 'unknown trial returns no units');
is_deeply($missing_observations, undef, 'unknown trial has no observations');

done_testing();
