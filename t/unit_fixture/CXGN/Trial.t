
use strict;
use lib 't/lib';

use Test::More qw | no_plan |;
use SGN::Test::Fixture;

use CXGN::Trial;

my $f = SGN::Test::Fixture->new();

my $trial = CXGN::Trial->new( { bcs_schema => $f->bcs_schema(),
				trial_id => 137 });

my $desc = $trial->get_description();
ok($desc == "test_trial", "get trial description test");
