use strict;
use warnings;
use lib 't/lib';

use Test::More;
use SGN::Test::Fixture;
use CXGN::Stock::StockLookup;
use CXGN::Stock::Seedlot;

my $fixture = SGN::Test::Fixture->new();
my $schema = $fixture->bcs_schema();
my $dbh = $fixture->dbh();
my $lookup = CXGN::Stock::StockLookup->new({ schema => $schema });

my $ids = $dbh->selectcol_arrayref(
    'SELECT DISTINCT stock_id FROM phenome.stock_owner ORDER BY stock_id LIMIT 2'
);
my ($owner_count) = $dbh->selectrow_array(
    'SELECT count(DISTINCT stock_id) FROM phenome.stock_owner'
);
my ($unowned_id) = $dbh->selectrow_array(
    'SELECT stock_id FROM public.stock WHERE NOT EXISTS '
    . '(SELECT 1 FROM phenome.stock_owner WHERE stock_owner.stock_id = stock.stock_id) LIMIT 1'
);
die "Fixture needs at least three owned stocks and one unowned stock\n"
    unless @$ids == 2 && $owner_count > 2 && defined $unowned_id;

my $all = $lookup->get_owner_hash_lookup();
is(scalar keys %$all, $owner_count, 'no argument returns all owned stocks');
my $selected = $lookup->get_owner_hash_lookup($ids);
is_deeply([sort { $a <=> $b } keys %$selected], $ids, 'only requested owned stocks are returned');
for my $id (@$ids) {
    is_deeply($selected->{$id}, $all->{$id}, "owners for stock $id match the complete map");
}
my $unowned = $lookup->get_owner_hash_lookup([$unowned_id]);
ok(!exists $unowned->{$unowned_id}, 'unowned stock has no entry');
is_deeply($unowned, {}, 'unowned stock returns an empty map');
is_deeply($lookup->get_owner_hash_lookup([]), {}, 'empty list returns an empty map');

my ($seedlots) = CXGN::Stock::Seedlot->list_seedlots(
    $schema, $fixture->people_schema(), $fixture->phenome_schema()
);
ok(@$seedlots, 'fixture contains seedlots returned by list_seedlots');
my $owners_query = $dbh->prepare(
    'SELECT sp_person_id, first_name, last_name FROM sgn_people.sp_person '
    . 'JOIN phenome.stock_owner USING(sp_person_id) WHERE stock_id = ? '
    . 'GROUP BY sp_person_id, first_name, last_name ORDER BY sp_person_id'
);
for my $seedlot (@$seedlots) {
    $owners_query->execute($seedlot->{seedlot_stock_id});
    my @owners;
    while (my ($id, $first, $last) = $owners_query->fetchrow_array()) {
        push @owners, '<a href="/solpeople/personal-info.pl?sp_person_id='.$id.'">'.$first.' '.$last.'</a>';
    }
    is($seedlot->{owners_string}, join(', ', @owners),
        "seedlot $seedlot->{seedlot_stock_id} owners match SQL");
}

done_testing();
