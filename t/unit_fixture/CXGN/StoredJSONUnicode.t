# Tests reading JSON metadata (additional info, external references, geo
# json) that contains non-ASCII text back from the database.
#
# The web server opens its database handles with pg_enable_utf8 (see
# SGN::Role::Site::DBConnector), so every value comes back as a Perl
# character string. JSON written as characters (to_json, SQL) must be
# readable, and JSON written with encode_json must keep working.

use strict;
use warnings;
use utf8;

use lib 't/lib';

use Test::More;
use Test::WWW::Mechanize;
use SGN::Test::Fixture;
use DBI;
use Encode;
use JSON;
use SGN::Model::Cvterm;
use CXGN::Trial;
use CXGN::Trial::Search;
use CXGN::Trial::TrialLayout;
use CXGN::Cross;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema();

my $dsn = 'dbi:Pg:database='.$f->config->{dbname}.";host=".$f->config->{dbhost}.";port=5432";
my $dbh = DBI->connect($dsn, $f->config->{dbuser}, $f->config->{dbpass}, { AutoCommit => 1, RaiseError => 1, PrintError => 0, pg_enable_utf8 => 1 });

# later fixture tests depend on the ids the database hands out, so the
# sequences used by the rows created here are put back at the end
my @sequences = qw(
    public.project_project_id_seq
    public.projectprop_projectprop_id_seq
    public.project_relationship_project_relationship_id_seq
    phenome.project_owner_project_owner_id_seq
    public.stockprop_stockprop_id_seq
    public.phenotypeprop_phenotypeprop_id_seq
    sgn_people.list_list_id_seq
    sgn_people.list_item_list_item_id_seq
    sgn_people.listprop_listprop_id_seq
);
my %sequence_values = map { $_ => [ $dbh->selectrow_array("SELECT last_value, is_called FROM $_") ] } @sequences;

my $info = { note => 'Висота рослини', unit => '°C', collector => 'Müller' };
my $geo_json = { type => 'Feature', geometry => { type => 'Point', coordinates => [ 30.5, 50.25 ] }, properties => { name => 'Ділянка 103' } };
my $references = [ { referenceID => 'ділянка-103', referenceSource => 'Польовий журнал' } ];

# JSON as written by to_json() or by SQL
sub as_characters { return JSON->new->canonical->encode(shift); }

sub cvterm_id {
    my ($name, $cv) = @_;
    return SGN::Model::Cvterm->get_cvterm_row($schema, $name, $cv)->cvterm_id();
}

my $project_additional_info_type_id = cvterm_id('project_additional_info', 'project_property');
my $stock_additional_info_type_id = cvterm_id('stock_additional_info', 'stock_property');
my $plot_geo_json_type_id = cvterm_id('plot_geo_json', 'stock_property');
my $cross_additional_info_type_id = cvterm_id('cross_additional_info', 'stock_property');
my $phenotype_additional_info_type_id = cvterm_id('phenotype_additional_info', 'phenotype_property');
my $phenotype_external_references_type_id = cvterm_id('phenotype_external_references', 'phenotype_property');

my $trial_id = 137;        # test_trial
my $cross_trial_id = 145;  # cross_test1
my $cross_id = 41248;
my $accession_id = 41281;
my $plot_id = 41284;       # CASS_6Genotypes_103
my $phenotype_id = 740338; # measured on CASS_6Genotypes_103


## how the values come back from PostgreSQL

$dbh->do("CREATE TEMP TABLE stored_json_unicode (id serial, value text)");
my $characters = as_characters($info);
my $octets = encode_json($info);
$dbh->do("INSERT INTO stored_json_unicode (id, value) VALUES (1, ?), (2, ?)", undef, $characters, $octets);
my ($characters_read) = $dbh->selectrow_array("SELECT value FROM stored_json_unicode WHERE id = 1");
my ($octets_read) = $dbh->selectrow_array("SELECT value FROM stored_json_unicode WHERE id = 2");
is($characters_read, $characters, "JSON written as characters is read back as the same characters");
is($octets_read, Encode::decode('iso-8859-1', $octets), "JSON written with encode_json is read back with one character per UTF-8 octet");
ok(!eval { decode_json($characters_read); 1 }, "decode_json cannot read JSON written as characters");
is_deeply(decode_json($octets_read), $info, "decode_json can read JSON written with encode_json");


## CXGN::Project::get_additional_info

my $trial = CXGN::Trial->new({ bcs_schema => $schema, trial_id => $trial_id });
$trial->set_additional_info($info);
is_deeply($trial->get_additional_info(), $info, "get_additional_info reads additional info written with encode_json");

$dbh->do("UPDATE projectprop SET value = ? WHERE project_id = ? AND type_id = ?", undef, as_characters($info), $trial_id, $project_additional_info_type_id);
my $trial_info = eval { $trial->get_additional_info() };
is($@, '', "get_additional_info does not die on additional info written as characters");
is_deeply($trial_info, $info, "get_additional_info reads additional info written as characters");


## CXGN::Trial::Search

my $trial_search = CXGN::Trial::Search->new({ bcs_schema => $schema, trial_id_list => [ $trial_id ] });
my ($trials) = eval { $trial_search->search() };
is($@, '', "trial search does not die on additional info written as characters");
is_deeply($trials->[0]->{additional_info}, $info, "trial search returns the additional info");

my $mech = Test::WWW::Mechanize->new();
$mech->get_ok('http://localhost:3010/ajax/search/trials', "trial search page loads");
my $search_page = eval { decode_json($mech->content()) } || {};
ok((grep { $_->[0] =~ /test_trial</ } @{$search_page->{data} || []}), "trial search page lists test_trial");


## CXGN::Cross::get_cross_additional_info_trial

$dbh->do("INSERT INTO stockprop (stock_id, type_id, value, rank) VALUES (?, ?, ?, 0)", undef, $cross_id, $cross_additional_info_type_id, as_characters($info));
my $cross = CXGN::Cross->new({ schema => $schema, trial_id => $cross_trial_id });
my $crosses = eval { $cross->get_cross_additional_info_trial() };
is($@, '', "get_cross_additional_info_trial does not die on additional info written as characters");
my ($cross_row) = grep { $_->[0] == $cross_id } @{$crosses || []};
is_deeply($cross_row->[3], $info, "get_cross_additional_info_trial returns the additional info");


## BrAPI v2

$mech->post_ok('http://localhost:3010/brapi/v2/token', [ "username" => "janedoe", "password" => "secretpw", "grant_type" => "password" ]);
my $access_token = decode_json($mech->content())->{access_token};
$mech->default_header("Content-Type" => "application/json");
$mech->default_header("Authorization" => "Bearer $access_token");

sub brapi_result {
    my $url = shift;
    $mech->get_ok($url, "GET $url");
    my $response = eval { decode_json($mech->content()) } || {};
    return $response->{result} || {};
}

# lists store additionalInfo with to_json and read it back
$mech->post('http://localhost:3010/brapi/v2/lists', Content => encode_json([ { listName => 'unicode additional info list', listType => 'germplasm', data => [ 'test_accession1' ], additionalInfo => $info } ]));
ok($mech->success(), "POST lists with non-ASCII additionalInfo");
my $list_response = eval { decode_json($mech->content()) } || {};
my $list = $list_response->{result}->{data}->[0] || {};
is_deeply($list->{additionalInfo}, $info, "POST lists returns the additionalInfo");
my ($list_id) = $dbh->selectrow_array("SELECT list_id FROM sgn_people.list WHERE name = ?", undef, 'unicode additional info list');
is_deeply(brapi_result("http://localhost:3010/brapi/v2/lists/$list_id")->{additionalInfo}, $info, "GET lists/{listDbId} returns the additionalInfo");
is_deeply(brapi_result("http://localhost:3010/brapi/v2/lists?listDbId=$list_id")->{data}->[0]->{additionalInfo}, $info, "GET lists returns the additionalInfo");

# trials store additionalInfo with encode_json
$mech->post('http://localhost:3010/brapi/v2/trials', Content => encode_json([ { trialName => 'unicode additional info trial', trialDescription => 'unicode additional info trial', programDbId => '134', programName => 'test', commonCropName => 'Cassava', active => 'true', additionalInfo => $info } ]));
ok($mech->success(), "POST trials with non-ASCII additionalInfo");
my ($folder_id) = $dbh->selectrow_array("SELECT project_id FROM project WHERE name = ?", undef, 'unicode additional info trial');
is_deeply(brapi_result("http://localhost:3010/brapi/v2/trials/$folder_id")->{additionalInfo}, $info, "GET trials/{trialDbId} returns additionalInfo written with encode_json");

$dbh->do("UPDATE projectprop SET value = ? WHERE project_id = ? AND type_id = ?", undef, as_characters($info), $folder_id, $project_additional_info_type_id);
is_deeply(brapi_result("http://localhost:3010/brapi/v2/trials/$folder_id")->{additionalInfo}, $info, "GET trials/{trialDbId} returns additionalInfo written as characters");
is_deeply(brapi_result("http://localhost:3010/brapi/v2/trials?trialDbId=$folder_id")->{data}->[0]->{additionalInfo}, $info, "GET trials returns additionalInfo written as characters");

# studies
my $study_info = brapi_result("http://localhost:3010/brapi/v2/studies/$trial_id")->{additionalInfo} || {};
is_deeply({ map { $_ => $study_info->{$_} } keys %$info }, $info, "GET studies/{studyDbId} returns additionalInfo written as characters");

# germplasm
$dbh->do("INSERT INTO stockprop (stock_id, type_id, value, rank) VALUES (?, ?, ?, 0)", undef, $accession_id, $stock_additional_info_type_id, as_characters($info));
is_deeply(brapi_result("http://localhost:3010/brapi/v2/germplasm/$accession_id")->{additionalInfo}, $info, "GET germplasm/{germplasmDbId} returns additionalInfo written as characters");
is_deeply(brapi_result("http://localhost:3010/brapi/v2/germplasm?germplasmDbId=$accession_id")->{data}->[0]->{additionalInfo}, $info, "GET germplasm returns additionalInfo written as characters");

# observations and observation units
$dbh->do("INSERT INTO phenotypeprop (phenotype_id, type_id, value, rank) VALUES (?, ?, ?, 0), (?, ?, ?, 0)", undef,
    $phenotype_id, $phenotype_additional_info_type_id, as_characters($info),
    $phenotype_id, $phenotype_external_references_type_id, as_characters($references));
$dbh->do("INSERT INTO stockprop (stock_id, type_id, value, rank) VALUES (?, ?, ?, 0), (?, ?, ?, 0)", undef,
    $plot_id, $stock_additional_info_type_id, as_characters($info),
    $plot_id, $plot_geo_json_type_id, as_characters($geo_json));

my $observation = brapi_result("http://localhost:3010/brapi/v2/observations/$phenotype_id");
is_deeply($observation->{additionalInfo}, $info, "GET observations/{observationDbId} returns additionalInfo written as characters");
is_deeply($observation->{externalReferences}, $references, "GET observations/{observationDbId} returns externalReferences written as characters");

my $observation_unit = brapi_result("http://localhost:3010/brapi/v2/observationunits/$plot_id");
is_deeply($observation_unit->{additionalInfo}, $info, "GET observationunits/{observationUnitDbId} returns additionalInfo written as characters");
is_deeply($observation_unit->{observationUnitPosition}->{geoCoordinates}, $geo_json, "GET observationunits/{observationUnitDbId} returns geoCoordinates written as characters");
my ($unit_observation) = grep { $_->{observationDbId} eq $phenotype_id } @{$observation_unit->{observations} || []};
is_deeply($unit_observation->{additionalInfo}, $info, "GET observationunits/{observationUnitDbId} returns observation additionalInfo written as characters");


## CXGN::Trial::TrialLayout::AbstractLayout (field map / layout download), same plot_geo_json row

my ($plot_trial_id) = $dbh->selectrow_array("SELECT project_id FROM nd_experiment_stock JOIN nd_experiment_project USING (nd_experiment_id) WHERE stock_id = ?", undef, $plot_id);
my $design = eval {
    my $layout = CXGN::Trial::TrialLayout->new({ schema => $schema, trial_id => $plot_trial_id, experiment_type => 'field_layout' });
    $layout->get_design();
};
is($@, '', "trial layout design does not die on plot_geo_json written as characters");
my ($plot_design) = grep { $_->{plot_id} == $plot_id } values %{$design || {}};
is_deeply($plot_design->{plot_geo_json}, $geo_json, "trial layout design returns plot_geo_json written as characters");


## clean up

$dbh->do("DELETE FROM phenotypeprop WHERE phenotype_id = ? AND type_id IN (?, ?)", undef, $phenotype_id, $phenotype_additional_info_type_id, $phenotype_external_references_type_id);
$dbh->do("DELETE FROM stockprop WHERE stock_id IN (?, ?, ?) AND type_id IN (?, ?, ?)", undef, $cross_id, $accession_id, $plot_id, $cross_additional_info_type_id, $stock_additional_info_type_id, $plot_geo_json_type_id);
$dbh->do("DELETE FROM projectprop WHERE project_id = ? AND type_id = ?", undef, $trial_id, $project_additional_info_type_id);
if ($list_id) {
    # list_item cascades from this delete (list_item_list_id_fkey is ON
    # DELETE CASCADE); listprop does not, so it is removed first.
    # This has to be explicit: list_list_id_seq (see @sequences below) is
    # far behind sgn_people.list's own max id in the fixture, so
    # clean_up_db()'s "delete anything with an id above the starting max"
    # sweep does not catch this row, and the setval below would otherwise
    # hand the same id to the next list created in a later fixture test.
    $dbh->do("DELETE FROM sgn_people.listprop WHERE list_id = ?", undef, $list_id);
    $dbh->do("DELETE FROM sgn_people.list WHERE list_id = ?", undef, $list_id);
}
$f->clean_up_db();

foreach my $sequence (@sequences) {
    $dbh->do("SELECT setval(?, ?, ?)", undef, $sequence, @{$sequence_values{$sequence}});
}
$dbh->disconnect();

done_testing();
