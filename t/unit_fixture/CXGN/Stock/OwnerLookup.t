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

subtest 'seedlot owners on consecutive pages' => sub {
    my @schemas = ($schema, $fixture->people_schema(), $fixture->phenome_schema());
    my $db = $schema->storage->dbh;
    $db->begin_work();
    my @page_ids;
    for my $offset (0, 1) {
        # BrAPI uses an inclusive end offset for a page of one.
        my ($page) = CXGN::Stock::Seedlot->list_seedlots(@schemas, $offset, $offset);
        is(scalar(@$page), 1, "page $offset has one seedlot");
        next unless @$page == 1;
        my $id = $page->[0]{seedlot_stock_id};
        push @page_ids, $id;
        $db->do(<<'SQL', undef, $id, $id);
INSERT INTO phenome.stock_owner (stock_id, sp_person_id)
SELECT ?, p.sp_person_id
FROM sgn_people.sp_person p
WHERE NOT EXISTS (
    SELECT 1 FROM phenome.stock_owner o WHERE o.stock_id = ? AND o.sp_person_id = p.sp_person_id
)
ORDER BY p.sp_person_id LIMIT 2
SQL
        my ($with_owners) = CXGN::Stock::Seedlot->list_seedlots(@schemas, $offset, $offset);
        is($with_owners->[0]{seedlot_stock_id}, $id, 'the owners do not change the page');
        my $query = $db->prepare($owners_query->{Statement});
        $query->execute($id);
        my @links;
        while (my ($person, $first, $last) = $query->fetchrow_array()) {
            push @links, qq{<a href="/solpeople/personal-info.pl?sp_person_id=$person">$first $last</a>};
        }
        cmp_ok(scalar(@links), '>=', 2, 'seedlot has multiple owners');
        is($with_owners->[0]{owners_string}, join(', ', @links), 'page has the owners of its own seedlot');
    }
    $db->rollback();
    isnt($page_ids[0], $page_ids[1], 'adjacent pages have different seedlots') if @page_ids == 2;
};

done_testing();
