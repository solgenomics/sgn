
use strict;

use Data::Dumper;
use Test::More qw | no_plan |;
use lib 't/lib';
use SGN::Test::Fixture;
use CXGN::People::Wiki;

my $f = SGN::Test::Fixture->new();

my $wiki = CXGN::People::Wiki->new( { people_schema => $f->people_schema(), page_name => 'TestPage' } );

$wiki->sp_person_id(41);

$wiki->new_page('TestPage');

$wiki->page_content('BLA BLA BLA');


my $id = $wiki->store_page();

ok($id, "page id returned");

my $page_data = $wiki->retrieve_page('TestPage');
print STDERR Dumper($page_data);
is($page_data->{page_content}, "BLA BLA BLA", "page content test");
is($page_data->{page_version}, 1, "page version test");
is($page_data->{sp_person_id}, 41, "page owner test");

$wiki->page_content('ANOTHER BLA BLA BLA!');
$id = $wiki->store_page();

$page_data = $wiki->retrieve_page('TestPage');
is($page_data->{page_content}, "ANOTHER BLA BLA BLA!", "page content test after new store");
is($page_data->{page_version}, 2, "page version test after new store");
is($page_data->{sp_person_id}, 41, "page owner test after new store");

$wiki->delete('TestPage');

eval {
    $page_data = $wiki->retrieve_page('TestPage');
};

like($@, qr/The page with name TestPage does not exist/, "page deletion test");

print STDERR "DELETED PAGE: ".Dumper($page_data);

done_testing();
