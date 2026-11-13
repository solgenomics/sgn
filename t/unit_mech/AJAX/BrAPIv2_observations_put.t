# BrAPI v2 PUT /observations/{observationDbId} and the bulk PUT /observations
# (keyed by observationDbId) must update exactly the observation they name.

use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use SGN::Model::Cvterm;
use Test::More;
use LWP::UserAgent;
use JSON;

my $f = SGN::Test::Fixture->new();
my $dbh = $f->bcs_schema->storage->dbh();
my $ua = LWP::UserAgent->new;

my $resp = $ua->post('http://localhost:3010/brapi/v2/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ]);
my $access_token = decode_json($resp->content)->{access_token};
ok($access_token, 'logged in');
$ua->default_header("Content-Type" => "application/json");
$ua->default_header('Authorization'=> 'Bearer ' . $access_token);

my $dry_matter = 70741;     # single value trait
my $harvest_index = 70668;  # set to repeated ("multiple") below
my ($tp1, $tp2, $tp3) = (39998, 39999, 40000);

sub observation_ids {
    my ($unit, $variable) = @_;
    my $ids = $dbh->selectcol_arrayref("SELECT phenotype.phenotype_id FROM phenotype JOIN nd_experiment_phenotype USING (phenotype_id) JOIN nd_experiment_stock USING (nd_experiment_id) WHERE nd_experiment_stock.stock_id = ? AND phenotype.cvalue_id = ? ORDER BY phenotype.phenotype_id", undef, $unit, $variable);
    return @$ids;
}

sub observation_row {
    my $id = shift;
    return $dbh->selectrow_hashref("SELECT value, operator, uniquename, to_char(collect_date, 'YYYY-MM-DD HH24:MI:SS') AS collect_date FROM phenotype WHERE phenotype_id = ?", undef, $id) || {};
}

sub put_json {
    my ($url, $body) = @_;
    my $r = $ua->put($url, Content => encode_json($body));
    my $content = eval { decode_json($r->content) } || {};
    return ($r->code, $content);
}

sub stored_ids {
    my $content = shift;
    return [ map { $_->{observationDbId} } @{$content->{result}->{data} || []} ];
}

my ($obs1) = observation_ids($tp1, $dry_matter);
my ($obs2) = observation_ids($tp2, $dry_matter);
ok($obs1 && $obs2, "fixture has dry matter observations on $tp1 and $tp2");
my %original = ($obs1 => observation_row($obs1), $obs2 => observation_row($obs2));

# 1. Single value trait: a body for another plot is refused and nothing changes
my ($code, $content) = put_json("http://localhost:3010/brapi/v2/observations/$obs1", { observationUnitDbId => "$tp2", observationVariableDbId => "$dry_matter", value => "77", observationTimeStamp => "2026-11-11T10:05:00Z" });
is($code, 400, 'PUT with the unit of another plot is refused');
is(observation_row($obs2)->{value}, $original{$obs2}->{value}, 'the other plot keeps its value');
is(observation_row($obs1)->{value}, $original{$obs1}->{value}, 'the named observation keeps its value');

# 2. A body for another variable is refused and nothing is added
my @tp1_harvest_index = observation_ids($tp1, $harvest_index);
($code, $content) = put_json("http://localhost:3010/brapi/v2/observations/$obs1", { observationUnitDbId => "$tp1", observationVariableDbId => "$harvest_index", value => "0.3", observationTimeStamp => "2026-11-11T10:05:00Z" });
is($code, 400, 'PUT with another variable is refused');
is_deeply([ observation_ids($tp1, $harvest_index) ], \@tp1_harvest_index, 'no harvest index observation is added or changed');

# 3. Matching body updates the named observation
($code, $content) = put_json("http://localhost:3010/brapi/v2/observations/$obs1", { observationUnitDbId => "$tp1", observationVariableDbId => "$dry_matter", value => "34", observationTimeStamp => "2026-11-11T10:00:00Z", collector => "janedoe" });
is($code, 200, 'PUT with matching unit and variable succeeds');
is_deeply(stored_ids($content), [ "$obs1" ], 'response names the updated observation');
is(observation_row($obs1)->{value}, '34', 'value updated');

# 4. Only the time changes: the time is updated, not skipped as an identical value
($code, $content) = put_json("http://localhost:3010/brapi/v2/observations/$obs1", { observationUnitDbId => "$tp1", observationVariableDbId => "$dry_matter", value => "34", observationTimeStamp => "2026-11-11T11:00:00Z", collector => "janedoe" });
is($code, 200, 'time-only PUT succeeds');
is(observation_row($obs1)->{collect_date}, '2026-11-11 11:00:00', 'time-only change is stored');

# 5. Only the collector changes
($code, $content) = put_json("http://localhost:3010/brapi/v2/observations/$obs1", { observationUnitDbId => "$tp1", observationVariableDbId => "$dry_matter", value => "34", observationTimeStamp => "2026-11-11T11:00:00Z", collector => "johndoe" });
is($code, 200, 'collector-only PUT succeeds');
is(observation_row($obs1)->{operator}, 'johndoe', 'collector-only change is stored');
is(observation_row($obs2)->{value}, $original{$obs2}->{value}, 'the other plot is still unchanged');

# Repeated trait
my $trait_repeat_type_id = SGN::Model::Cvterm->get_cvterm_row($f->bcs_schema, 'trait_repeat_type', 'trait_property')->cvterm_id();
$f->bcs_schema->resultset('Cv::Cvtermprop')->create({ cvterm_id => $harvest_index, type_id => $trait_repeat_type_id, value => 'multiple' });

my $r = $ua->post('http://localhost:3010/brapi/v2/observations', Content => encode_json([
    { observationUnitDbId => "$tp3", observationVariableDbId => "$harvest_index", value => "0.51", observationTimeStamp => "2026-11-01T08:00:00Z" },
    { observationUnitDbId => "$tp3", observationVariableDbId => "$harvest_index", value => "0.52", observationTimeStamp => "2026-11-02T08:00:00Z" },
]));
is($r->code, 200, 'POST of two repeated observations succeeds');
my %posted = map { $_->{value} => $_->{observationDbId} } @{(eval { decode_json($r->content) } || {})->{result}->{data} || []};
my ($obs_a, $obs_b) = ($posted{'0.51'}, $posted{'0.52'});
ok($obs_a && $obs_b, 'both repeated observations stored');
my @tp3_ids = observation_ids($tp3, $harvest_index);

# 6. Same time (ISO 8601 with Z): the named observation is updated, no new row
($code, $content) = put_json("http://localhost:3010/brapi/v2/observations/$obs_a", { observationUnitDbId => "$tp3", observationVariableDbId => "$harvest_index", value => "0.55", observationTimeStamp => "2026-11-01T08:00:00Z" });
is($code, 200, 'repeated trait PUT at the same time succeeds');
is_deeply(stored_ids($content), [ "$obs_a" ], 'response names the updated repeated observation');
is(observation_row($obs_a)->{value}, '0.55', 'repeated observation updated');
is_deeply([ observation_ids($tp3, $harvest_index) ], \@tp3_ids, 'no new repeated observation added');

# 7. Other time: the named observation gets the new value and time, no new row
($code, $content) = put_json("http://localhost:3010/brapi/v2/observations/$obs_a", { observationUnitDbId => "$tp3", observationVariableDbId => "$harvest_index", value => "0.56", observationTimeStamp => "2026-11-01T09:00:00Z" });
is($code, 200, 'repeated trait PUT with another time succeeds');
is_deeply([ @{observation_row($obs_a)}{qw(value collect_date)} ], [ '0.56', '2026-11-01 09:00:00' ], 'value and time of the named observation updated');
is_deeply([ observation_ids($tp3, $harvest_index) ], \@tp3_ids, 'still no new repeated observation');

# 8. Bulk PUT keyed by observationDbId (as Field Book sends corrections)
($code, $content) = put_json("http://localhost:3010/brapi/v2/observations", { $obs_b => { observationUnitDbId => "$tp3", observationVariableDbId => "$harvest_index", value => "0.60", observationTimeStamp => "2026-11-02T08:00:00Z" } });
is($code, 200, 'bulk PUT succeeds');
is_deeply(stored_ids($content), [ "$obs_b" ], 'bulk response names the updated observation');
is(observation_row($obs_b)->{value}, '0.60', 'bulk PUT updates the named observation');
is_deeply([ observation_ids($tp3, $harvest_index) ], \@tp3_ids, 'bulk PUT adds no new observation');

# 9. Time not in ISO 8601 form
($code, $content) = put_json("http://localhost:3010/brapi/v2/observations/$obs_b", { observationUnitDbId => "$tp3", observationVariableDbId => "$harvest_index", value => "0.65", observationTimeStamp => "2026-11-02 08:00:00" });
is($code, 200, 'PUT with a non-ISO time succeeds');
is(observation_row($obs_b)->{value}, '0.65', 'PUT with a non-ISO time updates the named observation');
is_deeply([ observation_ids($tp3, $harvest_index) ], \@tp3_ids, 'PUT with a non-ISO time adds no new observation');

# 10. Bulk PUT with one wrong entry stores nothing
($code, $content) = put_json("http://localhost:3010/brapi/v2/observations", {
    $obs_a => { observationUnitDbId => "$tp3", observationVariableDbId => "$harvest_index", value => "0.70", observationTimeStamp => "2026-11-01T09:00:00Z" },
    $obs_b => { observationUnitDbId => "$tp2", observationVariableDbId => "$harvest_index", value => "0.71", observationTimeStamp => "2026-11-02T08:00:00Z" },
});
is($code, 400, 'bulk PUT with a body for another plot is refused');
is(observation_row($obs_a)->{value}, '0.56', 'the matching entry of a refused bulk PUT is not stored');
is_deeply([ observation_ids($tp3, $harvest_index) ], \@tp3_ids, 'refused bulk PUT adds nothing');

# restore the fixture observations changed above
foreach my $id ($obs1, $obs2) {
    my $row = $original{$id};
    $dbh->do("UPDATE phenotype SET value = ?, operator = ?, uniquename = ?, collect_date = ? WHERE phenotype_id = ?", undef, @{$row}{qw(value operator uniquename collect_date)}, $id);
    is_deeply(observation_row($id), $row, "fixture observation $id restored");
}

$f->clean_up_db();

done_testing();
