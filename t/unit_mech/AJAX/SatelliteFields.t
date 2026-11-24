# Satellite page: fields drawn on the map and saved with a farm (location) or a
# trial (/ajax/satellite/location_fields, /ajax/satellite/trial_field), and the
# drawn trial field returned by /ajax/satellite/field. Who may save them.

use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use JSON;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;
my $base = 'http://localhost:3010';

my $loc_id = $schema->resultset('NaturalDiversity::NdGeolocation')->find({ description => 'test_location' })->nd_geolocation_id;
my $trial_id = $schema->resultset('Project::Project')->find({ name => 'test_trial' })->project_id;

END {
    local $?;
    # leave the fixture as found
    eval {
        foreach my $t ([ 'NaturalDiversity::NdGeolocationprop', 'location_fields_geo_json' ], [ 'Project::Projectprop', 'trial_field_geo_json' ]) {
            my $type = $schema->resultset('Cv::Cvterm')->find({ name => $t->[1] });
            $schema->resultset($t->[0])->search({ type_id => $type->cvterm_id })->delete if $type;
        }
        1;
    } or diag("could not remove the test fields: $@");
    eval { $f->clean_up_db(); 1 } or diag("clean_up_db failed: $@");
}

sub login {
    my ($user, $pw) = @_;
    my $m = Test::WWW::Mechanize->new(autocheck => 0);
    $m->post("$base/brapi/v1/token", [ username => $user, password => $pw, grant_type => 'password' ]);
    is($m->status, 200, "$user logged in");
    return $m;
}
sub answer { my $m = shift; return decode_json($m->content) }

# a field about 1 ha (100 m x 100 m) near Ithaca, and a 30 m one
my $ring = [ [-76.4700, 42.4500], [-76.4688, 42.4500], [-76.4688, 42.4509], [-76.4700, 42.4509] ];
my $small = [ [-76.4680, 42.4500], [-76.46765, 42.4500], [-76.46765, 42.45027], [-76.4680, 42.45027] ];

# ------------------------------------------------------------ logged out
my $anon = Test::WWW::Mechanize->new(autocheck => 0);
$anon->get("$base/ajax/satellite/location_fields?location_id=$loc_id");
is($anon->status, 401, 'farm fields need login');

# ------------------------------------------------------------ farm fields (submitter)
my $john = login('johndoe', 'secretpw');
$john->get("$base/ajax/satellite/location_fields?location_id=$loc_id");
my $r = answer($john);
is_deeply($r->{fields}, [], 'no field yet');
is($r->{can_edit}, 1, 'a submitter can save farm fields');

$john->post("$base/ajax/satellite/location_fields", [ location_id => $loc_id, fields => encode_json([ { name => 'North', ring => $ring }, { name => '', ring => $small } ]) ]);
$r = answer($john);
ok(!$r->{error}, 'two fields saved') or diag($r->{error});
is(scalar @{ $r->{fields} }, 2, 'two fields returned');
is($r->{fields}[0]{name}, 'North', 'name kept');
is($r->{fields}[1]{name}, 'Field 2', 'an empty name gets a default');
is_deeply($r->{fields}[0]{ring}[0], $r->{fields}[0]{ring}[-1], 'ring stored closed');
cmp_ok(abs($r->{fields}[0]{area_ha} - 0.99), '<', 0.05, 'area in hectares') or diag($r->{fields}[0]{area_ha});

$john->get("$base/ajax/satellite/location_fields?location_id=$loc_id");
is_deeply([ map { $_->{name} } @{ answer($john)->{fields} } ], [ 'North', 'Field 2' ], 'fields read back');

$john->post("$base/ajax/satellite/location_fields", [ location_id => $loc_id, fields => encode_json([ { name => 'A', ring => $ring }, { name => 'a', ring => $small } ]) ]);
like(answer($john)->{error}, qr/Two fields are called/, 'duplicate names refused');
$john->post("$base/ajax/satellite/location_fields", [ location_id => $loc_id, fields => encode_json([ { name => 'Line', ring => [ [-76.47, 42.45], [-76.46, 42.45] ] } ]) ]);
like(answer($john)->{error}, qr/at least 3 different points/, 'a line is not a field');
$john->post("$base/ajax/satellite/location_fields", [ location_id => $loc_id, fields => encode_json([ { name => 'Bad', ring => [ [-76.47, 95], [-76.46, 42.45], [-76.46, 42.46] ] } ]) ]);
like(answer($john)->{error}, qr/outside the valid/, 'latitude out of range refused');
$john->post("$base/ajax/satellite/location_fields", [ location_id => $loc_id, fields => 'not json' ]);
like(answer($john)->{error}, qr/not valid/, 'unreadable fields refused');
$john->get("$base/ajax/satellite/location_fields?location_id=$loc_id");
is(scalar @{ answer($john)->{fields} }, 2, 'refused saves changed nothing');

# a plain user can read but not save
my $fred = login('freddy', 'atgc');
$fred->get("$base/ajax/satellite/location_fields?location_id=$loc_id");
$r = answer($fred);
is(scalar @{ $r->{fields} }, 2, 'a user sees the farm fields');
is($r->{can_edit}, 0, 'a user cannot save them');
$fred->post("$base/ajax/satellite/location_fields", [ location_id => $loc_id, fields => '[]' ]);
is($fred->status, 403, 'save refused to a user');
like(answer($fred)->{error}, qr/submitter or a curator/, 'refusal says why');

$john->post("$base/ajax/satellite/location_fields", [ location_id => $loc_id, fields => '[]' ]);
is_deeply(answer($john)->{fields}, [], 'an empty list removes the fields');

# ------------------------------------------------------------ trial field
my $jane = login('janedoe', 'secretpw');
$jane->get("$base/ajax/satellite/field?trial_id=$trial_id");
$r = answer($jane);
is($r->{count}, 0, 'test_trial has no plot coordinates');
ok(!$r->{drawn}, 'no drawn field yet');
is($r->{can_edit}, 1, 'a curator can save the trial field');

$jane->get("$base/ajax/satellite/trial_field?trial_id=$trial_id&ring=" . encode_json($ring));
like(answer($jane)->{error}, qr/Use POST/, 'saving needs POST');

$jane->post("$base/ajax/satellite/trial_field", [ trial_id => $trial_id, ring => encode_json($ring) ]);
$r = answer($jane);
ok(!$r->{error}, 'trial field saved') or diag($r->{error});
is(scalar @{ $r->{ring} }, 5, 'ring closed');
$jane->get("$base/ajax/satellite/field?trial_id=$trial_id");
is_deeply(answer($jane)->{drawn}, $r->{ring}, 'drawn field returned with the trial');

$fred->get("$base/ajax/satellite/field?trial_id=$trial_id");
is(answer($fred)->{can_edit}, 0, 'a user cannot edit the trial field');
$fred->post("$base/ajax/satellite/trial_field", [ trial_id => $trial_id, ring => '' ]);
is($fred->status, 403, 'trial field change refused to a user');

$john->get("$base/ajax/satellite/field?trial_id=$trial_id");
is(answer($john)->{can_edit}, 1, "a submitter in the trial's breeding program can edit its field");

$jane->post("$base/ajax/satellite/trial_field", [ trial_id => $trial_id, ring => '' ]);
is(answer($jane)->{removed}, 1, 'trial field removed');
$jane->get("$base/ajax/satellite/field?trial_id=$trial_id");
ok(!answer($jane)->{drawn}, 'no drawn field after removal');

$jane->post("$base/ajax/satellite/trial_field", [ trial_id => 999999999, ring => encode_json($ring) ]);
like(answer($jane)->{error}, qr/does not exist/, 'unknown trial');

done_testing();
