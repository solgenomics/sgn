package main;

use strict;
use warnings;
use lib 't/lib';
use Test::More;
use Storable qw(dclone);
use SGN::Test::Fixture;
use CXGN::Stock;
use CXGN::Phenotypes::PhenotypeMatrix;
use CXGN::Phenotypes::Search::MaterializedViewTable;

{
    package Local::PedigreeQueryCounter;
    use parent 'DBIx::Class::Storage::Statistics';
    our $in_pedigree = 0;
    sub query_start {
        $_[0]->{total}++;
        $_[0]->{pedigree}++ if $in_pedigree;
    }
    sub query_end { return }
}

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema();
my %args = (
    bcs_schema => $schema,
    search_type => 'MaterializedViewTable',
    data_level => 'plot',
    trial_list => [137],
    include_pedigree_parents => 1,
);

# Fixture trial 137 has repeated test_accession4/5 plots. The former has
# both parents; the latter has only a female parent. No pedigree is invented.
my $search = CXGN::Phenotypes::Search::MaterializedViewTable->new(\%args);
my @source = $search->search();
my $source_rows = $source[0];
die('Trial 137 has no materialized plot rows; refresh fixture matviews')
    unless @$source_rows;
my %ids = map { $_->{germplasm_stock_id} => 1 } @$source_rows;
ok($ids{38843} && $ids{38844}, 'fixture trial contains both pedigree accessions');
cmp_ok(scalar(@$source_rows), '>', scalar(keys %ids), 'fixture repeats accessions');

# availableGermplasmSeedlotUniquenames joins hash keys, so its order is not defined;
# compare that cell as a sorted list.
sub sorted_seedlots {
    my ($rows) = @_;
    my ($col) = grep { $rows->[0][$_] eq 'availableGermplasmSeedlotUniquenames' } 0 .. $#{$rows->[0]};
    return $rows unless defined $col;
    return [ $rows->[0], map {
        my @r = @$_;
        $r[$col] = join ' AND ', sort split / AND /, ($r[$col] // '');
        \@r;
    } @{$rows}[1 .. $#$rows] ];
}

my @parent_fields = qw(mother mother_id father father_id);
my @parent_headers = qw(
    germplasmPedigreeFemaleParentName germplasmPedigreeFemaleParentDbId
    germplasmPedigreeMaleParentName germplasmPedigreeMaleParentDbId
);

# The reference deliberately executes the legacy code for EVERY source row,
# before any instrumentation, rather than sharing the candidate's cache.
my @expected;
for my $row (@$source_rows) {
    my $parents = CXGN::Stock->new({
        schema => $schema, stock_id => $row->{germplasm_stock_id},
    })->get_parents();
    push @expected, [@{$parents}{@parent_fields}];
}
ok(scalar(grep { defined($_->[1]) && defined($_->[3]) } @expected),
    'reference covers an accession with both parents');
ok(scalar(grep { defined($_->[1]) && !defined($_->[3]) } @expected),
    'reference covers an accession with a missing male parent');

my $original_new = CXGN::Stock->can('new');
my $original_parents = CXGN::Stock->can('get_parents');

sub measured_matrix {
    my ($repeat, $include) = @_;
    my $storage = $schema->storage();
    my ($old_debug, $old_debugobj) = ($storage->debug(), $storage->debugobj());
    my $counter = Local::PedigreeQueryCounter->new();
    @{$counter}{qw(total pedigree)} = (0, 0);
    my ($constructions, $calls) = (0, 0);
    my (@matrix, $error);
    {
        no warnings 'redefine';
        # Replay actual fixture search results to vary only accession reuse.
        # Parent resolution, stock construction, SQL, and matrix code are real.
        local *CXGN::Phenotypes::Search::MaterializedViewTable::search = sub {
            my $copy = dclone(\@source);
            $copy->[0] = [map { @{dclone($source_rows)} } 1 .. $repeat];
            return @$copy;
        };
        local *CXGN::Stock::new = sub {
            $constructions++;
            local $Local::PedigreeQueryCounter::in_pedigree = 1;
            return $original_new->(@_);
        };
        local *CXGN::Stock::get_parents = sub {
            $calls++;
            local $Local::PedigreeQueryCounter::in_pedigree = 1;
            return $original_parents->(@_);
        };
        eval {
            $storage->debugobj($counter);
            $storage->debug(1);
            @matrix = CXGN::Phenotypes::PhenotypeMatrix->new({
                %args, include_pedigree_parents => $include,
            })->get_phenotype_matrix();
            1;
        } or $error = $@ || 'Matrix construction failed';
    }
    $storage->debug($old_debug);
    $storage->debugobj($old_debugobj);
    die $error if defined $error;
    return (\@matrix, $constructions, $calls, $counter->{pedigree}, $counter->{total});
}

sub check_rows {
    my ($matrix, $repeat, $label) = @_;
    my @header = @{$matrix->[0]};
    my %col;
    @col{@header} = (0 .. $#header);
    for my $name (@parent_headers) {
        ok(exists($col{$name}), "$label has $name");
    }
    is(scalar(@$matrix) - 1, scalar(@expected) * $repeat, "$label row count");
    for my $i (1 .. $#$matrix) {
        my $row = $matrix->[$i];
        is_deeply([@{$row}[@col{@parent_headers}]],
            $expected[($i - 1) % @expected], "$label row $i matches legacy parents including undef");
    }
}

my ($single, $single_new, $single_calls, $single_sql, $single_total) = measured_matrix(1, 1);
check_rows($single, 1, 'Fixture');
is($single_new, scalar(keys %ids), 'one Stock construction per distinct accession');
is($single_calls, scalar(keys %ids), 'one get_parents call per distinct accession');
cmp_ok($single_sql, '>', 0, 'counter observes actual pedigree SQL');

my ($repeated, $repeat_new, $repeat_calls, $repeat_sql, $repeat_total) = measured_matrix(3, 1);
check_rows($repeated, 3, 'Repeated fixture');
is($repeat_new, $single_new, 'repeated accessions add no Stock constructions');
is($repeat_calls, $single_calls, 'repeated accessions add no get_parents calls');
is($repeat_sql, $single_sql, 'repeated accessions add no pedigree SQL statements');
# Every full row is preserved too, not just the parent columns.
is_deeply(sorted_seedlots($repeated), sorted_seedlots([$single->[0], (map { @{$single}[1 .. $#$single] } 1 .. 3)]),
    'repetition preserves every matrix cell and row order');
diag("Matrix DBIC statements: fixture=$single_total repeated=$repeat_total; pedigree=$single_sql/$repeat_sql");

my ($disabled, $disabled_new, $disabled_calls, $disabled_sql) = measured_matrix(1, 0);
is($disabled_new, 0, 'disabled flag constructs no Stock objects');
is($disabled_calls, 0, 'disabled flag calls no get_parents');
is($disabled_sql, 0, 'disabled flag runs no pedigree SQL');
my %remove = map { $_ => 1 } @parent_headers;
my @keep = grep { !$remove{$single->[0][$_]} } 0 .. $#{$single->[0]};
is_deeply(sorted_seedlots([map { [@{$_}[@keep]] } @$single]), sorted_seedlots($disabled),
    'enabling parents changes only the four pedigree columns');

# A second call above must create all distinct accessions again: the cache
# belongs to one matrix invocation, not to the process, schema, or Stock API.
# This test writes no fixture data and does not refresh shared materialized views.
done_testing();
