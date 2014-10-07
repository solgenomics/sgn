
use strict;

use Test::More qw | no_plan |;

use lib 't/lib';

use SGN::Test::Fixture;

my $fix = SGN::Test::Fixture->new();

is(ref($fix->config()), "HASH", 'hashref check');

#my $q = "SELECT count(*) FROM stock";
#my $h = $fix->dbh()->prepare($q);
#$h->execute();
#my $stock_count = $h->fetchrow_array();
#ok($stock_count, "dbh test");

#my $rs = $fix->bcs_schema->resultset("Stock::Stock")->search( {} );
#ok($rs->count(), "bcs schema test");

BEGIN {use_ok('CXGN::Trial::TrialCreate');}
BEGIN {use_ok('CXGN::Trial::TrialLayout');}
ok(my $chado_schema = $fix->bcs_schema);
ok(my $phenome_schema = $fix->phenome_schema);
ok(my $dbh = $fix->dbh);
ok(my $trial_create = CXGN::Trial::TrialCreate->new({
    chado_schema => $chado_schema,
    phenome_schema => $phenome_schema,
    dbh => $dbh,
    user_name => "test_user",
    design => "",	
    program => "test_program",
    trial_year => "2015",
    trial_description => "test description",
    trial_location => "test_location",
    trial_name => "test_trial_name",
    design_type => "test_design_type",
						    }));

