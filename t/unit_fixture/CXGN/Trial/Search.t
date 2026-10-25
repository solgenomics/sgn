
# Tests that CXGN::Trial::Search treats filter values as data, so names
# containing a single quote can be searched for.

use strict;
use warnings;

use lib 't/lib';
use Test::More;
use SGN::Test::Fixture;
use CXGN::Trial::Search;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;

sub run_search {
    my $args = shift;
    my ($result, $total_count);
    my $ok = eval {
        my $trial_search = CXGN::Trial::Search->new({ bcs_schema => $schema, %$args });
        ($result, $total_count) = $trial_search->search();
        1;
    };
    diag("search died: $@") if !$ok;
    return $ok ? [ sort map { $_->{trial_id} } @$result ] : undef;
}

# Everything below runs inside a transaction that is rolled back at the
# end, so the rename of trial 137 never reaches the shared fixture
# database. txn_rollback() below always runs, even if an assertion dies
# first; if the process were to exit before that, the uncommitted
# transaction would still be discarded when the connection closes.
$schema->txn_begin();

eval {
    # trial 137 (test_trial) is a CRD field trial at test_location (23) in 2014
    my $trial = $schema->resultset("Project::Project")->find({ project_id => 137 });
    $trial->update({ name => "farmer's field trial" });

    my $crd_trials = run_search({ trial_design_list => ['CRD'] });
    ok($crd_trials && scalar(grep { $_ == 137 } @$crd_trials), "design filter finds trial 137");

    is_deeply(run_search({ trial_name_list => ["farmer's field trial"], trial_name_is_exact => 1 }), [137], "exact name containing a quote");

    is_deeply(run_search({ trial_name_list => ["farmer's"] }), [137], "partial name containing a quote");

    my $quoted_design_trials = run_search({ trial_design_list => ['CRD', "farmer's design"] });
    ok(defined $crd_trials && defined $quoted_design_trials, "both design searches returned a result, not two dead searches")
        or diag("crd_trials: " . (defined $crd_trials ? "defined" : "undef") . ", quoted_design_trials: " . (defined $quoted_design_trials ? "defined" : "undef"));
    is_deeply($quoted_design_trials, $crd_trials, "quote in trial_design_list is matched as a value");

    my $location_trials = run_search({ location_id_list => [23] });
    ok($location_trials && scalar(grep { $_ == 137 } @$location_trials), "location filter still works");

    my %quoted_filters = (
        program_list => ["farmer's program"],
        year_list => ["2014'"],
        trial_type_list => ["farmer's type"],
        folder_name_list => ["farmer's folder"],
        accession_name_list => ["farmer's accession"],
    );
    foreach my $filter (sort keys %quoted_filters) {
        is_deeply(run_search({ $filter => $quoted_filters{$filter} }), [], "quote in $filter returns no trials");
    }

    is_deeply(run_search({ externalReferenceSources => ["farmer's source"], externalReferenceIds => ["farmer's id"] }), [], "quote in external references returns no trials");

    1;
} or diag("test body died: $@");

$schema->txn_rollback();

done_testing();
