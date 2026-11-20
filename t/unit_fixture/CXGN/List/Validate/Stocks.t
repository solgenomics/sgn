
use strict;
use warnings;

use lib 't/lib';

use Test::More qw | no_plan |;
use SGN::Test::Fixture;
use SGN::Model::Cvterm;
use Data::Dumper;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema();

BEGIN {
    use_ok('CXGN::List::Validate');
};

my $organism = $schema->resultset('Organism::Organism')->find_or_create({
    genus   => 'Test_genus',
    species => 'Test_genus test_species',
});

# The 'stocks' validator plugin is used for genotype uploads where the
# observation units are a mix of stock types. It must match the stock
# types that can actually be genotyped (accession, tissue_sample, plant,
# plot, subplot), but must NOT match unrelated stock types like
# populations or crosses, which the upload dialog explicitly warns
# against treating as genotyped samples.
my %genotyping_stock_types = (
    accession     => 'test_stocks_plugin_accession_1',
    tissue_sample => 'test_stocks_plugin_tissue_sample_1',
    plant         => 'test_stocks_plugin_plant_1',
    plot          => 'test_stocks_plugin_plot_1',
    subplot       => 'test_stocks_plugin_subplot_1',
);

foreach my $stock_type (keys %genotyping_stock_types) {
    my $type_id = SGN::Model::Cvterm->get_cvterm_row($schema, $stock_type, 'stock_type')->cvterm_id();
    my $name = $genotyping_stock_types{$stock_type};
    $schema->resultset('Stock::Stock')->find_or_create({
        organism_id => $organism->organism_id,
        name        => $name,
        uniquename  => $name,
        type_id     => $type_id,
    });
}

my %non_genotyping_stock_types = (
    population => 'test_stocks_plugin_population_1',
    cross      => 'test_stocks_plugin_cross_1',
);

foreach my $stock_type (keys %non_genotyping_stock_types) {
    my $type_id = SGN::Model::Cvterm->get_cvterm_row($schema, $stock_type, 'stock_type')->cvterm_id();
    my $name = $non_genotyping_stock_types{$stock_type};
    $schema->resultset('Stock::Stock')->find_or_create({
        organism_id => $organism->organism_id,
        name        => $name,
        uniquename  => $name,
        type_id     => $type_id,
    });
}

my @all_names = (values(%genotyping_stock_types), values(%non_genotyping_stock_types), 'test_stocks_plugin_does_not_exist_1');

my $list_validator = CXGN::List::Validate->new();
my $results = $list_validator->validate($schema, 'stocks', \@all_names);
my %missing = map { $_ => 1 } @{$results->{missing}};

foreach my $stock_type (sort keys %genotyping_stock_types) {
    my $name = $genotyping_stock_types{$stock_type};
    ok(!$missing{$name}, "stocks validator matches $stock_type stock ($name)");
}

foreach my $stock_type (sort keys %non_genotyping_stock_types) {
    my $name = $non_genotyping_stock_types{$stock_type};
    ok($missing{$name}, "stocks validator does not match $stock_type stock ($name)");
}

ok($missing{'test_stocks_plugin_does_not_exist_1'}, "stocks validator reports a truly nonexistent name as missing");

done_testing();
