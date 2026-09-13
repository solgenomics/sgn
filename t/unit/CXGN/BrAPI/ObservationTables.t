use strict;
use warnings;
use Test::More;
use Test::MockModule;
use CXGN::BrAPI::v2::ObservationTables;

my @matrix;
my %matrix_args;
my $matrix_mock = Test::MockModule->new('CXGN::Phenotypes::PhenotypeMatrix');
$matrix_mock->redefine(new => sub {
    my $class = shift;
    %matrix_args = @_;
    return bless {}, $class;
});
$matrix_mock->redefine(get_phenotype_matrix => sub { return @matrix });
my $transform_mock = Test::MockModule->new('CXGN::List::Transform');
$transform_mock->redefine(transform => sub { return { transform => [] } });
my $cvterm_mock = Test::MockModule->new('SGN::Model::Cvterm');
$cvterm_mock->redefine(get_cvterm_row_from_trait_name => sub {
    return bless {}, 'ObservationTablesTest::Cvterm';
});
sub ObservationTablesTest::Cvterm::cvterm_id { return 123 }

sub row {
    my ($id, @values) = @_;
    my @metadata = ('metadata') x 30;
    $metadata[21] = $id;
    return [@metadata, @values, 'a note', 'a treatment'];
}

for my $method (qw(search search_observationunit_tables)) {
    subtest $method => sub {
        # Use real pagination and response construction, with only the matrix
        # and trait lookup mocked so these regressions need no database.
        my $api = bless {
            bcs_schema => bless({}, 'Bio::Chado::Schema'),
            page_size => 1, page => 0, status => [],
        }, 'CXGN::BrAPI::v2::ObservationTables';
        my $zero = $method eq 'search' ? '0,2026-01-01T00:00:00Z' : '0';
        @matrix = (
            [('metadata') x 30, 'trait one', 'trait two', 'notes', 'treatment'],
            row(1, undef, ''), row(2, $zero, undef),
            row(3, '', undef), row(4, undef, 'measured'), row(5, undef, undef),
        );
        for my $page (0 .. 2) {
            $api->page($page);
            my $response = $api->$method({ studyDbIds => [139] });
            is($matrix_args{data_level}, 'all', 'study-only request defaults to all levels');
            is_deeply($matrix_args{trial_list}, [139], 'study filter reaches matrix');
            is_deeply($response->{pagination}, {
                pageSize => 1, currentPage => $page, totalCount => 2, totalPages => 2,
            }, "page $page counts only observed units");
            my @expected = $page < 2 ? ($page == 0 ? 2 : 4) : ();
            is_deeply([map { $_->[21] } @{$response->{result}{data}}], \@expected,
                'filtering precedes pagination, including a page beyond the end');
            is($response->{result}{data}[0][30], $zero, 'zero phenotype preserved') if $page == 0;
        }
        $api->page(0);
        for my $rows (
            [row(1, undef, ''), row(2, '', undef)],
            [],
        ) {
            @matrix = ($matrix[0], @$rows);
            my $response = $api->$method({ studyDbIds => [139] });
            is($response->{pagination}{totalCount}, 0, 'empty result has zero count');
            is($response->{pagination}{totalPages}, 0, 'empty result has zero pages');
            is_deeply($response->{result}{data}, [], 'empty result has no rows');
        }
        @matrix = ([('metadata') x 30, 'notes', 'treatment'], row(1));
        my $response = $api->$method({ studyDbIds => [139] });
        is($response->{pagination}{totalCount}, 0, 'notes and treatments alone do not count');
        is_deeply($response->{result}{observationVariables}, [], 'no phantom trait column');
    };
}

done_testing;
