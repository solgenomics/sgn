
use strict;

use Test::More qw | no_plan |;
use lib 't/lib';
use SGN::Test::Fixture;
use CXGN::People::Wiki;

my $f = SGN::Test::Fixture->new();

my $wiki = CXGN::People::Wiki->new( { people_schema => $f->people_schema(), page_name => 'TestPage' } );

$wiki->new_page('TestPage');

$wiki->page_content('BLA BLA BLA');
$wiki->sp_person_id(41);

my $id = $wiki->store();

ok($id, "page id returned");

my $page = $wiki->retrieve_page('TestPage');

is($page->content(), "BLA BLA BLA", "page content test");

done_testing();
