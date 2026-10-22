#test the "one of" stockprop match type in CXGN::Stock::Search

use strict;

use lib 't/lib';

use Test::More;
use SGN::Test::Fixture;
use SGN::Model::Cvterm;
use CXGN::Stock::Search;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema();

my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
my @stocks = map { $schema->resultset('Stock::Stock')->find({ uniquename => $_, type_id => $accession_type_id }) } ('test_accession1', 'test_accession2');
is(scalar(grep { defined } @stocks), 2, 'found the two accessions used in this test');

my @values = ('one-of-test-a', 'one-of-test-b');
my @props;
for my $i (0, 1) {
    push @props, values %{ $stocks[$i]->create_stockprops({ notes => $values[$i] }, { autocreate => 1 }) };
}

sub found {
    my $value = shift;
    my $search = CXGN::Stock::Search->new({
        bcs_schema => $schema,
        people_schema => $f->people_schema(),
        phenome_schema => $f->phenome_schema(),
        stock_type_name => 'accession',
        stockprops_values => { notes => { matchtype => 'one of', value => $value } },
        minimal_info => 1,
        display_pedigree => 0,
    });
    my ($result, $records_total) = $search->search();
    return [ sort map { $_->{uniquename} } @$result ];
}

is_deeply(found($values[0]), [ $stocks[0]->uniquename() ], 'one value finds its accession');
my $both = eval { found("$values[0], $values[1]") };
is($@, '', 'two values do not raise an SQL error');
is_deeply($both, [ sort map { $_->uniquename() } @stocks ], 'two values find both accessions');

$_->delete() for @props;

$f->clean_up_db();

done_testing();
