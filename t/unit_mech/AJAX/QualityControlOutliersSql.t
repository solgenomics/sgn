
=head1 NAME

t/unit_mech/AJAX/QualityControlOutliersSql.t - Quality Control store and restore of outlier marks bind their values

=head1 DESCRIPTION

store_outliers and restore_outliers put the trait name, the operator's
name and the trial names into the SQL text. With a quote in the trait
name the mark must still be stored and removed, and a restore with
anything but a list of trial names is refused before any query.

=cut

use strict;
use warnings;
use Test::More;
use Catalyst::Test 'SGN';
use JSON::PP qw(decode_json encode_json);
use Test::WWW::Mechanize;
use URI;

my (undef, $context) = ctx_request('/');
ok($context, 'fixture provides a Catalyst context') or BAIL_OUT('No fixture context');
my $dbh = $context->dbic_schema('Bio::Chado::Schema', undef)->storage->dbh;
my ($database) = $dbh->selectrow_array('SELECT current_database()');
BAIL_OUT('Refusing a non-fixture database')
    unless defined($database) && $database =~ /\Atest_db_[0-9_]+\z/;
my $server = $ENV{SGN_TEST_SERVER} || 'http://localhost:3010';
BAIL_OUT('Refusing HTTP requests outside the disposable fixture')
    unless URI->new($server)->host =~ /\A(?:localhost|127\.0\.0\.1|test_breedbase)\z/;

# A trait the controller can resolve ("name|DB:accession"), a fixture trial, and the
# name the controller records as operator for janedoe (a curator in the fixture).
my ($trait_db, $trait_accession) = $dbh->selectrow_array(q{
    SELECT db.name, dbxref.accession FROM cvterm
    JOIN dbxref USING (dbxref_id) JOIN db USING (db_id)
    WHERE cvterm.cvterm_id = 70741});
ok($trait_db, 'fixture trait 70741 exists') or BAIL_OUT('No fixture trait');
my $trial = 'Kasese solgs trial';
my ($trial_id) = $dbh->selectrow_array('SELECT project_id FROM project WHERE name = ?', undef, $trial);
ok($trial_id, "fixture trial '$trial' exists") or BAIL_OUT('No fixture trial');
my ($first, $last) = $dbh->selectrow_array(
    'SELECT first_name, last_name FROM sgn_people.sp_person WHERE username = ?', undef, 'janedoe');

my $marker = "qcsqltest it's";                       # a quote in the trait name
my $trait = "$marker|$trait_db:$trait_accession";
my $stored = "$marker|$first $last";
my $count_sql = q{
    SELECT count(*) FROM projectprop
    WHERE project_id = ? AND value = ?
      AND type_id = (SELECT cvterm_id FROM cvterm WHERE name = 'validated_phenotype')};
END {
    $dbh->do("DELETE FROM projectprop WHERE value LIKE 'qcsqltest%'") if $dbh;
}

my $browser = Test::WWW::Mechanize->new(autocheck => 0);
$browser->post("$server/ajax/user/login", { username => 'janedoe', password => 'secretpw' });
my $login = eval { decode_json($browser->content) } || {};
ok($browser->status == 200 && !$login->{error}, 'fixture curator signs in') or BAIL_OUT('Fixture login failed');

# Store: a plot name that matches nothing, so no phenotype gets an outlier mark.
$browser->post("$server/ajax/qualitycontrol/storeoutliers", {
    outliers => encode_json([{ trait => $trait, studyName => $trial, plotName => 'qcsqltest-no-such-plot', value => 1 }]),
    othertraits => '[]',
    trait => $trait,
});
is($browser->status, 200, 'store answers');
is(($dbh->selectrow_array($count_sql, undef, $trial_id, $stored))[0], 1,
   'the validated-trait mark is stored with the quote as data');

# Restore with the list the page sends: data_restore's quoted trial names.
$browser->post("$server/ajax/qualitycontrol/restoreoutliers", {
    outliers => encode_json("'$trial'"),
    trait => $trait,
});
is($browser->status, 200, 'restore answers');
unlike($browser->content, qr/Failed to store data/, 'restore runs its queries without an SQL error');
is(($dbh->selectrow_array($count_sql, undef, $trial_id, $stored))[0], 0, 'restore removes that mark');

# A JSON list of names works too.
$dbh->do(q{INSERT INTO projectprop (project_id, type_id, value, rank)
    VALUES (?, (SELECT cvterm_id FROM cvterm WHERE name = 'validated_phenotype'), ?, 9999)},
    undef, $trial_id, $stored);
$browser->post("$server/ajax/qualitycontrol/restoreoutliers", {
    outliers => encode_json([$trial]), trait => $trait,
});
is($browser->status, 200, 'restore with a JSON list answers');
is(($dbh->selectrow_array($count_sql, undef, $trial_id, $stored))[0], 0, 'and removes the mark');

# Anything that is not a list of trial names is refused before any query.
my ($props_before) = $dbh->selectrow_array('SELECT count(*) FROM projectprop');
for my $bad ("'x') OR 1=1 --", "'$trial',", '') {
    $browser->post("$server/ajax/qualitycontrol/restoreoutliers", {
        outliers => encode_json($bad), trait => $trait,
    });
    is($browser->status, 400, "restore refuses outliers " . encode_json($bad));
}
is(($dbh->selectrow_array('SELECT count(*) FROM projectprop'))[0], $props_before, 'nothing was deleted');

done_testing();
