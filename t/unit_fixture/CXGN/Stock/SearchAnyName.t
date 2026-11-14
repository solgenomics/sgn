# Test the name search contract for each source and match type.
use strict;
use warnings;

use lib 't/lib';

use Test::More;
use SGN::Test::Fixture;
use SGN::Model::Cvterm;
use CXGN::Stock::Search;

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
my $accession_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
my $tissue_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'tissue_sample', 'stock_type')->cvterm_id();
my $synonym_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stock_synonym', 'stock_property')->cvterm_id();
my $organization_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'organization', 'stock_property')->cvterm_id();
my $date_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'acquisition date', 'stock_property')->cvterm_id();
my $organism_id = $schema->resultset('Organism::Organism')->first()->organism_id();
my $suffix = time() . $$;
my $prefix = 'fanyname' . $suffix;
my $id_prefix = 'fstockid' . $suffix;

my $sequences = sequence_values($dbh);
$schema->txn_begin();
my $error;
eval {
    my %groups;
    for my $mode (qw(exactly starts_with ends_with contains)) {
        my $token = $prefix . $mode;
        my %value = (
            exactly => $token,
            starts_with => $token . 'suffix',
            ends_with => 'prefix' . $token,
            contains => 'prefix' . $token . 'suffix',
        );
        my $match = $value{$mode};
        for my $kind (qw(name unique description synonym all multiple nonsynonym obsolete other)) {
            my $stock = $schema->resultset('Stock::Stock')->create({
                organism_id => $organism_id,
                name => $kind eq 'name' || $kind eq 'all' || $kind eq 'obsolete' || $kind eq 'other'
                    ? $match : $id_prefix . $mode . 'stock' . $kind,
                uniquename => $kind eq 'unique' ? $match : $kind eq 'all' ? uc($match) : $id_prefix . $mode . 'id' . $kind,
                description => $kind eq 'description' || $kind eq 'all' ? $match : undef,
                type_id => $kind eq 'other' ? $tissue_id : $accession_id,
                is_obsolete => $kind eq 'obsolete' ? 1 : 0,
            });
            $groups{$mode}{$kind} = $stock;
            if ($kind eq 'synonym' || $kind eq 'all' || $kind eq 'multiple') {
                $schema->resultset('Stock::Stockprop')->create({
                    stock_id => $stock->stock_id(), type_id => $synonym_id, value => $match, rank => 0,
                });
            }
            if ($kind eq 'multiple') {
                $schema->resultset('Stock::Stockprop')->create({
                    stock_id => $stock->stock_id(), type_id => $synonym_id, value => uc($match), rank => 1,
                });
            }
            if ($kind eq 'nonsynonym' || $kind eq 'name') {
                $schema->resultset('Stock::Stockprop')->create({
                    stock_id => $stock->stock_id(), type_id => $organization_id,
                    value => $kind eq 'nonsynonym' ? $match : 'F8 filter value', rank => 0,
                });
            }
        }
    }

    for my $dated ([ name => '1801-01-01' ], [ unique => '1802-02-02' ]) {
        $schema->resultset('Stock::Stockprop')->create({
            stock_id => $groups{contains}{$dated->[0]}->stock_id(),
            type_id => $date_id, value => $dated->[1], rank => 0,
        });
    }

    my @wildcard_stocks;
    for my $name ($prefix . "quote'percent%under_score", $prefix . "quote'percentXYZunderXscore") {
        push @wildcard_stocks, $schema->resultset('Stock::Stock')->create({
            organism_id => $organism_id, name => $name,
            uniquename => $id_prefix . 'wildcard' . scalar(@wildcard_stocks),
            type_id => $accession_id, is_obsolete => 0,
        });
    }

    sub search_names {
        my ($mode, $extra) = @_;
        my $search = CXGN::Stock::Search->new({
            bcs_schema => $schema,
            people_schema => $f->people_schema(),
            phenome_schema => $f->phenome_schema(),
            match_name => $prefix . $mode,
            match_type => $mode,
            stock_type_id => $accession_id,
            minimal_info => 1,
            %{$extra || {}},
        });
        my ($rows, $count) = $search->search();
        return ([ map { $_->{uniquename} } @$rows ], $count);
    }

    # These checks also pass on master: the contract is the same; PostgreSQL saves the work.
    for my $mode (qw(exactly starts_with ends_with contains)) {
        my @expected = map { $_->uniquename() }
            sort { $a->stock_id() cmp $b->stock_id() }
            @{$groups{$mode}}{qw(name unique description synonym all multiple)};
        my ($names, $count) = search_names($mode);
        is_deeply($names, \@expected, "$mode returns exactly the matching accessions once");
        is($count, scalar @expected, "$mode returns the full count");
    }

    # A unique missing token must not return any accessions.
    my ($missing, $missing_count) = search_names('exactly', { match_name => $prefix . 'missing' });
    is_deeply($missing, [], 'missing name returns no accessions');
    is($missing_count, 0, 'missing name count');

    # The quote is data; percent and underscore retain ILIKE wildcard semantics.
    my ($wildcards, $wildcard_count) = search_names('exactly', {
        match_name => $prefix . "quote'percent%under_score",
    });
    my @wildcard_expected = map { $_->uniquename() }
        sort { $a->stock_id() cmp $b->stock_id() } @wildcard_stocks;
    is_deeply($wildcards, \@wildcard_expected, 'quote and wildcards follow ILIKE semantics');
    is($wildcard_count, 2, 'quote and wildcards count');

    # Exact and bounded dates exercise the retained stockprop joins.
    my ($dated, $dated_count) = search_names('contains', { acquisition_date => '1801-01-01' });
    is_deeply($dated, [ $groups{contains}{name}->uniquename() ], 'name and acquisition date intersect');
    is($dated_count, 1, 'name and acquisition date count');
    my ($bounded, $bounded_count) = search_names('contains', {
        min_acquisition_date => '1801-06-01', max_acquisition_date => '1802-12-31',
    });
    # Each bound accepts the property or the creation date: the stock created today
    # with the older property date is inside the range as well.
    my @bounded_expected = map { $_->uniquename() }
        sort { $a->stock_id() cmp $b->stock_id() } @{$groups{contains}}{qw(name unique)};
    is_deeply($bounded, \@bounded_expected, 'name and date range intersect');
    is($bounded_count, 2, 'name and date range count');
    my ($date_only, $date_only_count) = search_names('exactly', {
        match_name => undef, acquisition_date => '1801-01-01',
        stock_id_list => [ map { '' . $_->stock_id() } @{$groups{contains}}{qw(name unique)} ],
    });
    is_deeply($date_only, [ $groups{contains}{name}->uniquename() ], 'acquisition date without name');
    is($date_only_count, 1, 'acquisition date without name count');

    # Find an existing accession represented by multiple trial plots.
    my ($trial_name, $accession_name, $accession_unique) = $dbh->selectrow_array(q{
        SELECT p.name, s.name, s.uniquename
        FROM stock s
        JOIN stock_relationship sr ON sr.object_id = s.stock_id
        JOIN nd_experiment_stock es ON es.stock_id = sr.subject_id
        JOIN nd_experiment_project ep ON ep.nd_experiment_id = es.nd_experiment_id
        JOIN project p ON p.project_id = ep.project_id
        WHERE s.type_id = ? AND NOT s.is_obsolete AND s.name IS NOT NULL
          AND strpos(s.name, '%') = 0 AND strpos(s.name, '_') = 0
          AND strpos(s.name, chr(92)) = 0
        GROUP BY p.name, s.stock_id, s.name, s.uniquename
        HAVING count(DISTINCT sr.subject_id) > 1
        ORDER BY s.stock_id, p.name LIMIT 1
    }, undef, $accession_id);
    die 'Fixture lacks an accession in multiple trial plots' unless defined $trial_name;
    my ($trial, $trial_count) = search_names('exactly', {
        match_name => $accession_name, trial_name_list => [ $trial_name ],
    });
    is_deeply($trial, [ $accession_unique ], 'trial with multiple plots returns the accession once');
    is($trial_count, 1, 'trial with multiple plots count');

    # Obsolete inclusion adds exactly the obsolete matching accession.
    my @with_obsolete = map { $_->uniquename() }
        sort { $a->stock_id() cmp $b->stock_id() }
        @{$groups{contains}}{qw(name unique description synonym all multiple obsolete)};
    my ($obsolete, $obsolete_count) = search_names('contains', { include_obsolete => 1 });
    is_deeply($obsolete, \@with_obsolete, 'obsolete inclusion returns all matching accessions');
    is($obsolete_count, 7, 'obsolete inclusion count');

    my ($unpaged) = search_names('contains');
    my %stocks_by_name = map { $_->uniquename() => $_ } values %{$groups{contains}};
    my @ordered = sort { $a->name() cmp $b->name() } map { $stocks_by_name{$_} } @$unpaged;
    my @page = sort { $a->stock_id() cmp $b->stock_id() } @ordered[2, 3];
    my ($page_names, $page_count) = search_names('contains', { limit => 3, offset => 2 });
    is_deeply($page_names, [ map { $_->uniquename() } @page ], 'page matches the corresponding unpaged stocks');
    is($page_count, 6, 'paging retains the full count');

    my ($filtered, $filtered_count) = search_names('contains', {
        stockprops_values => { organization => { matchtype => 'exactly', value => 'F8 filter value' } },
    });
    is_deeply($filtered, [ $groups{contains}{name}->uniquename() ], 'name and property filters intersect');
    is($filtered_count, 1, 'property filter count');

    my ($other, $other_count) = search_names('contains', { stock_type_name => 'tissue_sample' });
    is_deeply($other, [ $groups{contains}{other}->uniquename() ], 'name and stock type filters intersect');
    is($other_count, 1, 'other stock type count');
    1;
} or $error = $@ || 'Unknown test failure';
$schema->txn_rollback();
restore_sequences($dbh, $sequences);
die $error if $error;
is_deeply(sequence_values($dbh), $sequences, 'sequences are back where they were');

done_testing();
