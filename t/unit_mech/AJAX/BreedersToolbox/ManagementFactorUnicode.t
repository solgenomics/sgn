# Management factors (trial page, Management Regime, "Add management factor") with non-ASCII text:
# the trial page table reads them as typed, edit and remove work, BrAPI v2 /events reads them,
# and a regime written as characters (SQL, an import) is read too.

use strict;
use warnings;
use utf8;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use Encode ();
use JSON ();
use URI;
use SGN::Model::Cvterm;

binmode(Test::More->builder->$_, ':encoding(UTF-8)') for qw(output failure_output todo_output);

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;
my $dbh = $schema->storage->dbh;
my $server = 'http://localhost:3010';

my $mech = Test::WWW::Mechanize->new(autocheck => 0);
$mech->post_ok("$server/brapi/v1/token", [ username => 'janedoe', password => 'secretpw', grant_type => 'password' ], 'login');

my $trial_id = $schema->resultset('Project::Project')->find({ name => 'test_trial' })->project_id();
my $regime_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'management_regime', 'project_property')->cvterm_id();
my ($saved_regime) = $dbh->selectrow_array(
    'SELECT value FROM projectprop WHERE project_id = ? AND type_id = ?', undef, $trial_id, $regime_type_id);

sub set_regime {
    my ($value) = @_;
    $dbh->do('DELETE FROM projectprop WHERE project_id = ? AND type_id = ?', undef, $trial_id, $regime_type_id);
    $dbh->do('INSERT INTO projectprop (project_id, type_id, value) VALUES (?, ?, ?)', undef, $trial_id, $regime_type_id, $value)
        if defined $value;
}

my $text = JSON->new;   # what JSON.parse does with a JavaScript string

# The page sends the fields with jQuery.ajax: GET, UTF-8 percent-encoded.
sub edit_factor {
    my ($action, $factor) = @_;
    my $uri = URI->new("$server/ajax/breeders/trial/$trial_id/edit_management_factor_details");
    my %query = (%$factor, completions => $text->encode($factor->{completions} || []), action => $action);
    $uri->query_form(map { $_ => Encode::encode('UTF-8', $query{$_} // '') } sort keys %query);
    $mech->get($uri);
    my $response = eval { JSON::decode_json($mech->content) } || {};
    ok($response->{success}, "$action management factor") or diag $mech->content;
}

# The page reads the table with fetch(...).json() and JSON.parse(result.data).
sub table_rows {
    $mech->get("$server/ajax/breeders/trial/$trial_id/get_management_regime");
    is($mech->status, 200, 'get_management_regime answers') or diag $mech->content;
    my $response = eval { JSON::decode_json($mech->content) } || {};
    return eval { $text->decode($response->{data}) } || [];
}

sub event_descriptions {
    $mech->get("$server/brapi/v2/events?studyDbId=$trial_id&pageSize=1000");
    my $response = eval { JSON::decode_json($mech->content) } || {};
    return [map { $_->{eventDescription} } grep { $_->{eventDbId} eq 'ManagementFactor' } @{ $response->{result}{data} || [] }];
}

set_regime(undef);
my $factor = {
    type => 'Fungicide',
    description => 'T3 BBCH 60–65: Ревікер 0,7 л/га, Müller',
    schedule => 'один раз',
    start_date => '2026-06-15',
    end_date => '2026-06-15',
    completions => [],
};

edit_factor('add', $factor);
my $rows = table_rows();
is($rows->[0]{description}, $factor->{description}, 'trial page shows the description as typed');
is($rows->[0]{schedule}, $factor->{schedule}, 'trial page shows the schedule as typed');
is_deeply(event_descriptions(), [$factor->{description}], 'BrAPI v2 events show the description as typed');

# edit: the page adds the edited factor, then removes the old row as it shows it
my $edited = { %{ $rows->[0] }, description => 'T3 BBCH 61–65: Ревікер 0,7 л/га' };
edit_factor('add', $edited);
edit_factor('remove', $rows->[0]);
is_deeply([map { $_->{description} } @{ table_rows() }], [$edited->{description}], 'edit leaves only the edited factor');

edit_factor('remove', table_rows()->[0]);
is_deeply(table_rows(), [], 'remove deletes the factor');

# a regime written as characters
set_regime($text->encode([{ %$factor, description => 'Гербіцид 0,6 л/га' }]));
is(table_rows()->[0]{description}, 'Гербіцид 0,6 л/га', 'a regime written as characters is shown');
is_deeply(event_descriptions(), ['Гербіцид 0,6 л/га'], 'a regime written as characters is in BrAPI v2 events');
edit_factor('add', { %$factor, description => 'T1' });
is(scalar @{ table_rows() }, 2, 'a factor can be added to a regime written as characters');

set_regime($saved_regime);
$f->clean_up_db();

done_testing();
