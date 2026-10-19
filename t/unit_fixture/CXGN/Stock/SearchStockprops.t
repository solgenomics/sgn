# Test that CXGN::Stock::Search requires a stock to match every stockprop filter
use strict;
use warnings;

use lib 't/lib';

use Test::More;
use SGN::Test::Fixture;
use SGN::Model::Cvterm;
use CXGN::Stock::Search;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema();
my $people_schema = $f->people_schema();
my $phenome_schema = $f->phenome_schema();

my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
my $organization_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'organization', 'stock_property')->cvterm_id();
my $country_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'country of origin', 'stock_property')->cvterm_id();

my $stock_1 = $schema->resultset('Stock::Stock')->find({ uniquename => 'test_accession1', type_id => $accession_type_id });
my $stock_2 = $schema->resultset('Stock::Stock')->find({ uniquename => 'test_accession2', type_id => $accession_type_id });
ok($stock_1 && $stock_2, 'found the two accessions used in this test');

# stock_1 has both properties, stock_2 has only the organization
my @created;
push @created, $stock_1->create_related('stockprops', { type_id => $organization_type_id, value => 'TestOrgFilter' });
push @created, $stock_1->create_related('stockprops', { type_id => $country_type_id, value => 'TestCountryFilter' });
push @created, $stock_2->create_related('stockprops', { type_id => $organization_type_id, value => 'TestOrgFilter' });

sub search_ids {
    my $stockprops_values = shift;
    my $search = CXGN::Stock::Search->new({
        bcs_schema => $schema,
        people_schema => $people_schema,
        phenome_schema => $phenome_schema,
        stock_type_id => $accession_type_id,
        stockprops_values => $stockprops_values,
        minimal_info => 1,
    });
    my ($result) = $search->search();
    return [ sort map { $_->{stock_id} } @$result ];
}

my $both = search_ids({
    'organization' => { matchtype => 'exactly', value => 'TestOrgFilter' },
    'country of origin' => { matchtype => 'exactly', value => 'TestCountryFilter' },
});
is_deeply($both, [ $stock_1->stock_id ], 'two different property filters: only the stock with both properties is found');

my $org_only = search_ids({
    'organization' => { matchtype => 'exactly', value => 'TestOrgFilter' },
});
is_deeply($org_only, [ sort { $a <=> $b } $stock_1->stock_id, $stock_2->stock_id ], 'one property filter: both stocks with that property are found');

my $country_only = search_ids({
    'country of origin' => { matchtype => 'contains', value => 'CountryFilter' },
});
is_deeply($country_only, [ $stock_1->stock_id ], 'one property filter with contains: matching stock is found');

my $wrong_value = search_ids({
    'organization' => { matchtype => 'exactly', value => 'TestOrgFilter' },
    'country of origin' => { matchtype => 'exactly', value => 'NoSuchCountry' },
});
is_deeply($wrong_value, [], 'second filter does not match: no stock is found');

my $one_of = search_ids({
    'organization' => { matchtype => 'one of', value => 'TestOrgFilter' },
    'country of origin' => { matchtype => 'exactly', value => 'TestCountryFilter' },
});
is_deeply($one_of, [ $stock_1->stock_id ], 'a one of filter combined with another filter');

$_->delete() for @created;

done_testing();
