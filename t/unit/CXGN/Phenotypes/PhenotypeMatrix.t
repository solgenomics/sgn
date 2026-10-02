use strict;
use warnings;
use Test::More;
use Test::MockModule;
use CXGN::Phenotypes::PhenotypeMatrix;
use CXGN::BrAPI::v2::ObservationTables;

my %trait_names = (101 => 'Measured trait|CO:0000101', 102 => 'Unmeasured trait|CO:0000102');
my $schema = bless {}, 'Bio::Chado::Schema';
my ($search_type, $empty_result);
my $native_data = [
    { obsunit_stock_id => 1, trial_name => 'trial', trial_description => 'trial',
      trait_name => $trait_names{101}, phenotype_value => '0' },
    { obsunit_stock_id => 2, trial_name => 'trial', trial_description => 'trial' },
];
my $matview_data = [
    { observationunit_stock_id => 1, trial_name => 'trial', trial_description => 'trial',
      observations => [{ trait_id => 101, trait_name => $trait_names{101}, value => '0' }] },
    { observationunit_stock_id => 2, trial_name => 'trial', trial_description => 'trial',
      observations => [] },
];

# Exercise real matrix construction and BrAPI responses; mock database lookups.
my $factory_mock = Test::MockModule->new('CXGN::Phenotypes::SearchFactory');
$factory_mock->redefine(instantiate => sub {
    $search_type = $_[1];
    return bless {}, 'PhenotypeMatrixTest::Search';
});
sub PhenotypeMatrixTest::Search::search {
    return $empty_result ? [] : $native_data if $search_type eq 'Native';
    return ([], {}, {}) if $empty_result;
    return ($matview_data, { $trait_names{101} => 101 }, {});
}
my $matrix_mock = Test::MockModule->new('CXGN::Phenotypes::PhenotypeMatrix');
$matrix_mock->redefine(retrieve_trait_repeat_types => sub { {} });
my $projects_mock = Test::MockModule->new('CXGN::BreedersToolbox::Projects');
$projects_mock->redefine(new => sub { bless {}, $_[0] });
$projects_mock->redefine(get_related_treatments => sub {
    return { treatment_names => [], treatment_details => {} };
});
my $cvterm_mock = Test::MockModule->new('SGN::Model::Cvterm');
$cvterm_mock->redefine(get_trait_from_cvterm_id => sub { $trait_names{$_[1]} });
$cvterm_mock->redefine(get_cvterm_row_from_trait_name => sub {
    my ($id) = grep { $trait_names{$_} eq $_[2] } keys %trait_names;
    return bless { id => $id }, 'PhenotypeMatrixTest::Cvterm';
});
sub PhenotypeMatrixTest::Cvterm::cvterm_id { $_[0]->{id} }
my $transform_mock = Test::MockModule->new('CXGN::List::Transform');
$transform_mock->redefine(transform => sub { { transform => $_[3] } });

for my $type (qw(Native MaterializedViewTable)) {
    subtest $type => sub {
        my $matrix = CXGN::Phenotypes::PhenotypeMatrix->new(
            bcs_schema => $schema, search_type => $type, data_level => 'all',
            trial_list => [139], trait_list => [102, 101, 102],
        );
        my $trait_start = $type eq 'Native' ? 30 : 39;
        $empty_result = 0;
        my @data = $matrix->get_phenotype_matrix;
        is_deeply([@{$data[0]}[$trait_start .. $#{$data[0]}]],
            [@trait_names{101, 102}, 'notes'],
            'selected unmeasured trait has a named column, without duplicate columns');
        is(scalar @data, 3, 'observation units with and without data are retained');
        is($data[1][$trait_start], '0', 'measured zero is preserved');
        is($data[1][$trait_start + 1], undef, 'selected unmeasured trait is empty on a measured unit');
        is_deeply([@{$data[2]}[$trait_start .. $trait_start + 1]], [undef, undef],
            'both trait cells are empty on an unphenotyped unit');
        is(scalar @{$data[1]}, scalar @{$data[0]}, 'measured row aligns with headers');
        is(scalar @{$data[2]}, scalar @{$data[0]}, 'unphenotyped row aligns with headers');

        $empty_result = 1;
        @data = $matrix->get_phenotype_matrix;
        is_deeply([@{$data[0]}[$trait_start .. $#{$data[0]}]],
            [@trait_names{101, 102}, 'notes'], 'selected columns remain when the search returns no data');
        is(scalar @data, 1, 'an empty search does not invent observation units');

        $empty_result = 0;
        $matrix->trait_list([]);
        @data = $matrix->get_phenotype_matrix;
        is_deeply([@{$data[0]}[$trait_start .. $#{$data[0]}]],
            [$trait_names{101}, 'notes'], 'without a selection, headers come from observed traits');
    };
}

for my $method (qw(search search_observationunit_tables)) {
    subtest $method => sub {
        my $api = bless {
            bcs_schema => $schema, page_size => 2, page => 0, status => [],
        }, 'CXGN::BrAPI::v2::ObservationTables';
        my $response = $api->$method({ studyDbIds => [139], observationVariableDbIds => [101, 102] });
        is_deeply($response->{result}{observationVariables}, [map {
            { observationVariableDbId => "$_", observationVariableName => $trait_names{$_} }
        } (101, 102)], 'BrAPI lists the selected trait even without observations');
        is($response->{pagination}{totalCount}, 2, 'BrAPI counts both units');
        is($response->{result}{data}[0][30], '0', 'BrAPI keeps the zero value');
        is($response->{result}{data}[0][31], undef, 'BrAPI leaves the selected trait empty');
        is_deeply([@{$response->{result}{data}[1]}[30, 31]], [undef, undef],
            'BrAPI retains the row with all trait values empty');
    };
}

done_testing;
