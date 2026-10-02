use strict;
use warnings;
use Test::More;
use Test::MockModule;
use CXGN::Phenotypes::Search::Native;

my (%type_ids, %units, @unit_queries, @search_queries);
my $schema = bless {}, 'Bio::Chado::Schema';
my $schema_mock = Test::MockModule->new('Bio::Chado::Schema');
$schema_mock->redefine(storage => sub { bless {}, 'NativeTest::Storage' });
$schema_mock->redefine(resultset => sub { bless {}, 'NativeTest::ResultSet' });
sub NativeTest::Storage::dbh { bless {}, 'NativeTest::DBH' }
sub NativeTest::ResultSet::search { shift }
sub NativeTest::ResultSet::next { return }
sub NativeTest::DBH::prepare {
    return bless { sql => $_[1] }, 'NativeTest::Statement';
}
sub NativeTest::Statement::execute {
    my ($self, @bind) = @_;
    $self->{rows} = [];
    if ($self->{sql} =~ /^SELECT (?:DISTINCT )?stock.uniquename, stock.stock_id/) {
        push @unit_queries, [$self->{sql}, @bind];
        my $trial_id = shift @bind;
        my %selected_types = map { $_ => 1 } @bind;
        $self->{rows} = [map { [$_->[1], $_->[0]] }
            grep { $selected_types{$type_ids{$_->[2]}} } @{$units{$trial_id} || []}];
    } else {
        push @search_queries, [$self->{sql}, @bind];
    }
    return 1;
}
sub NativeTest::Statement::fetchrow_array {
    my $row = shift @{$_[0]->{rows}};
    return $row ? @$row : ();
}

my $cvterm_mock = Test::MockModule->new('SGN::Model::Cvterm');
$cvterm_mock->redefine(get_cvterm_row => sub {
    my ($class, $schema, $name) = @_;
    $type_ids{$name} ||= 1 + scalar keys %type_ids;
    return bless { id => $type_ids{$name} }, 'NativeTest::Cvterm';
});
sub NativeTest::Cvterm::cvterm_id { $_[0]->{id} }
my $stock_mock = Test::MockModule->new('CXGN::Stock::StockLookup');
$stock_mock->redefine(get_synonym_hash_lookup => sub { {} });
my $layout_mock = Test::MockModule->new('CXGN::Trial::TrialLayout');
$layout_mock->redefine(new => sub { bless {}, 'NativeTest::Layout' });
sub NativeTest::Layout::get_design { { 1 => { plot_id => 9000 } } }
my $project_mock = Test::MockModule->new('CXGN::Project');
# Exercise the real shared lookup without the database-backed constructor.
$project_mock->redefine(new => sub { bless $_[1], $_[0] });

sub run_search {
    my (%args) = @_;
    @unit_queries = ();
    @search_queries = ();
    my $search = CXGN::Phenotypes::Search::Native->new(
        bcs_schema => $schema, data_level => 'all', trial_list => [139], %args,
    );
    is_deeply($search->search, [], 'search executes successfully');
    is(scalar @search_queries, 1, 'one phenotype query');
    return $search_queries[0];
}

%units = (
    139 => [
        [101, 'plot', 'plot'], [102, 'plant', 'plant'],
        [103, 'analysis', 'analysis_instance'], [104, 'subplot', 'subplot'],
        [105, 'tissue', 'tissue_sample'], [101, 'plot', 'plot'],
    ],
    140 => [[106, 'other plot', 'plot'], [101, 'plot', 'plot']],
);
my $query = run_search(trial_list => [139, 140], plot_list => []);
is(scalar @unit_queries, 2, 'one shared lookup per trial for all five types');
is_deeply([@{$unit_queries[0]}[1 .. 6]],
    [139, @type_ids{qw(plot plant analysis_instance subplot tissue_sample)}],
    'trial and all stock types are bound to the shared lookup');
like($query->[0], qr/observationunit.stock_id = ANY\(\?::integer\[\]\)/,
    'unit restriction uses a bound PostgreSQL array');
is_deeply($query->[1], [101 .. 106], 'all levels and trials included, with duplicate IDs removed');
unlike($query->[0], qr/\b10[1-6]\b/, 'observation unit IDs are not embedded in query text');

for my $filter (qw(plot_list plant_list subplot_list)) {
    my $ids = [102];
    my $query = run_search($filter => $ids);
    is(scalar @unit_queries, 0, "$filter bypasses prefetch");
    is_deeply($ids, [102], 'caller filter is unchanged');
    like($query->[0], qr/observationunit.stock_id in \(102\)/, 'explicit filter is retained');
    is(scalar @$query, 1, 'no unused bind values');
}

%units = ();
$query = run_search;
like($query->[0], qr/1 = 0/, 'trial with no units cannot trigger an unrestricted search');
is(scalar @$query, 1, 'empty prefetch needs no binds');

$query = run_search(trial_list => []);
is(scalar @unit_queries, 0, 'search without a trial does not prefetch units');
is(scalar @$query, 1, 'search without a trial needs no unit binds');

%units = (139 => [[101, 'plot', 'plot'], [102, 'plant', 'plant']]);
my $project = CXGN::Project->new({ bcs_schema => $schema, trial_id => 139 });
is_deeply($project->get_observation_units_direct('plot'), [[101, 'plot']],
    'shared helper preserves single-type callers and column order');
my $before = scalar @unit_queries;
is_deeply($project->get_observation_units_direct([]), [], 'empty types return no units');
is(scalar @unit_queries, $before, 'empty types need no query');

done_testing;
