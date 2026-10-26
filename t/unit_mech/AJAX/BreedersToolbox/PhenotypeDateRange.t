use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use JSON qw(decode_json);
use URI;
use CXGN::Trial::TrialCreate;
use CXGN::Phenotypes::Search::Native;
use CXGN::Phenotypes::PhenotypeMatrix;
use SGN::Model::Cvterm;

# Use a separate synthetic trial so the HTTP server sees committed data,
# without changing any observations or layouts in the shared fixture.
my $f = SGN::Test::Fixture->new;
END { $f->clean_up_db() if $f; }
my $schema = $f->bcs_schema;
my $trial_name = "date_boundary_$$";
my %design;
for my $i (1 .. 6) {
    $design{$i} = {
        plot_name => "${trial_name}_plot_$i", plot_number => $i,
        stock_name => 'test_accession1',
        block_number => 1, rep_number => 1, row_number => 1, col_number => $i,
        plant_names => ["${trial_name}_plant_$i"],
    };
}
my $creator = CXGN::Trial::TrialCreate->new({
    chado_schema => $schema, dbh => $f->dbh, owner_id => 41,
    operator => 'janedoe', program => 'test', trial_location => 'test_location',
    trial_name => $trial_name, trial_year => 2030, design_type => 'CRD',
    trial_description => 'Synthetic phenotype date-boundary regression',
    trial_has_plant_entries => 1, design => \%design,
});
my $saved = $creator->save_trial;
my $trial_id = $saved->{trial_id};
ok($trial_id, 'created a synthetic trial with plots and plants') or BAIL_OUT('trial setup failed');

my $trait_id = 70773;
my $trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $trait_id, 'extended');
my $experiment_type = SGN::Model::Cvterm->get_cvterm_row(
    $schema, 'phenotyping_experiment', 'experiment_type')->cvterm_id;
my $location = $schema->resultset('NaturalDiversity::NdGeolocation')
    ->find({ description => 'test_location' })->nd_geolocation_id;
my @measurements = (
    ['2030-05-19 23:59:59.999999', '64', 1],
    ['2030-05-20 00:00:00', '0', 2],
    ['2030-05-20 12:00:00', '2', 3],
    ['2030-05-20 23:59:59.999999', '8', 4],
    ['2030-05-21 00:00:00', '16', 5],
    [undef, '32', 6],
    ['2030-05-20 18:00:00', '6', 3],
);
my %ids;
for my $level (qw(plot plant)) {
    for my $i (0 .. $#measurements) {
        my ($date, $value, $unit) = @{$measurements[$i]};
        my $stock = $schema->resultset('Stock::Stock')
            ->find({ uniquename => "${trial_name}_${level}_$unit" });
        my $experiment = $schema->resultset('NaturalDiversity::NdExperiment')->create({
            type_id => $experiment_type, nd_geolocation_id => $location,
        });
        my $phenotype = $schema->resultset('Phenotype::Phenotype')->create({
            uniquename => "${trial_name}_${level}_observation_$i",
            cvalue_id => $trait_id, value => $value, collect_date => $date,
        });
        $schema->resultset('NaturalDiversity::NdExperimentStock')->create({
            nd_experiment_id => $experiment->nd_experiment_id,
            stock_id => $stock->stock_id, type_id => $experiment_type,
        });
        $schema->resultset('NaturalDiversity::NdExperimentProject')->create({
            nd_experiment_id => $experiment->nd_experiment_id, project_id => $trial_id,
        });
        $schema->resultset('NaturalDiversity::NdExperimentPhenotype')->create({
            nd_experiment_id => $experiment->nd_experiment_id,
            phenotype_id => $phenotype->phenotype_id,
        });
        push @{$ids{$level}}, $phenotype->phenotype_id;
    }
}

my $mech = Test::WWW::Mechanize->new;
$mech->post_ok('http://localhost:3010/brapi/v1/token', {
    username => 'janedoe', password => 'secretpw', grant_type => 'password',
}, 'log in with the standard fixture user');

for my $level (qw(plot plant)) {
    my %search_args = (
        bcs_schema => $schema, data_level => $level,
        trial_list => [$trial_id], trait_list => [$trait_id],
    );
    for my $case (
        ['one day', '2030-05-20', '2030-05-20', 0, [1,2,3,6]],
        ['two days', '2030-05-19', '2030-05-20', 0, [0,1,2,3,6]],
        ['include undated', '2030-05-20', '2030-05-20', 1, [1,2,3,5,6]],
        ['calendar days in timestamps', '2030-05-20 09:00:00', '2030-05-20 18:00:00', 0, [1,2,3,6]],
        ['no date filter', undef, undef, 0, [0,1,2,3,4,5,6]],
    ) {
        my ($name, $start, $end, $dateless, $indices) = @$case;
        my $rows = CXGN::Phenotypes::Search::Native->new({
            %search_args, start_date => $start, end_date => $end,
            include_dateless_items => $dateless, include_timestamp => 1,
        })->search;
        is_deeply(
            [sort {$a <=> $b} map { $_->{phenotype_id} }
                grep { defined($_->{phenotype_id}) } @$rows],
            [sort {$a <=> $b} @{$ids{$level}}[@$indices]],
            "$level: $name returns the expected observations",
        );
        if ($name eq 'one day') {
            my ($zero) = grep { $_->{phenotype_id} == $ids{$level}[1] } @$rows;
            is($zero->{phenotype_value}, '0', "$level: a measured zero is preserved");
        }
    }

    for my $aggregation (['average', [0,4,8]], ['first', [0,2,8]], ['last', [0,6,8]]) {
        my ($method, $expected) = @$aggregation;
        my @matrix = CXGN::Phenotypes::PhenotypeMatrix->new({
            %search_args, search_type => 'Native',
            start_date => '2030-05-20', end_date => '2030-05-20',
            include_dateless_items => 0, include_timestamp => 1,
            repetitive_measurements => $method,
        })->get_phenotype_matrix;
        is_deeply(matrix_values(\@matrix, $trait_name), $expected,
            "$level: $method aggregation still applies after date filtering");
    }

    for my $dateless (0, 1) {
        my $url = URI->new("http://localhost:3010/ajax/breeders/trial/$trial_id/trait_phenotypes");
        $url->query_form(display => $level, trait => $trait_id,
            start_date => '2030-05-20', end_date => '2030-05-20',
            include_dateless_items => $dateless);
        $mech->get_ok($url, "$level: histogram data endpoint responds (undated=$dateless)");
        my $response = decode_json($mech->content);
        is($response->{status}, 'success', "$level: histogram request succeeds");
        is_deeply(matrix_values($response->{data}, $trait_name),
            $dateless ? [0,4,8,32] : [0,4,8],
            "$level: histogram has three distinct in-range units and optional undated unit");
    }
}

# Matrix cells may carry timestamps, while the histogram uses their numeric
# values. Locate the trait by header rather than assuming a metadata width.
sub matrix_values {
    my ($matrix, $name) = @_;
    my ($index) = grep { defined($matrix->[0][$_]) && $matrix->[0][$_] eq $name }
        0 .. $#{$matrix->[0]};
    return [] unless defined $index;
    my @values = map { (split /,/, $_->[$index])[0] }
        grep { defined($_->[$index]) && $_->[$index] ne '' } @$matrix[1 .. $#$matrix];
    return [sort {$a <=> $b} map { 0 + $_ } @values];
}

done_testing();
