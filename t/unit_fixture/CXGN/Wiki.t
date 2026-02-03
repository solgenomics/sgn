
use strict;

use lib 't/lib';
use SGN::Test::Fixture;
use CXGN::People::Wiki;

my $f = SGN::Test::Fixture->new();

my $wiki = CXGN::People::Wiki->new( { people_schema => $f->people_schema() } );

$wiki->new_page('TEST PAGE');

$wiki->page_content('BLA BLA BLA');

$wiki->store();

ok(1);
