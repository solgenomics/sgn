use strict;
use warnings;

use Test::More;

use lib 't/lib';

use aliased 'SGN::Test::WWW::Mechanize' => 'Mech';

my $mech = Mech->new;

$mech->get_ok('/');
$mech->submit_form_ok({
    form_name => 'quicksearch',
    fields    => {
        term => 'nonexistent_thing',
    },
},
'quick search for a nonexistent term goes OK');

$mech->content_contains('0 EST identifiers');


done_testing;
