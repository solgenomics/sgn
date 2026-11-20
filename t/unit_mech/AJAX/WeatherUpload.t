
# Upload of local weather station data (/ajax/weather/upload and friends) and
# the Weather section of the trial page. No request to the weather services.

use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use File::Temp qw(tempdir);
use HTTP::Request::Common qw(POST);
use JSON;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;
my $base = 'http://localhost:3010';
my $mech = Test::WWW::Mechanize->new;
my $dir = tempdir(CLEANUP => 1);

my $loc = $schema->resultset('NaturalDiversity::NdGeolocation')->find({ description => 'test_location' });
ok($loc, 'fixture location');
my $loc_id = $loc->nd_geolocation_id;
my ($old_lat, $old_lon, $old_alt) = ($loc->latitude, $loc->longitude, $loc->altitude);
$loc->update({ latitude => -22.70, longitude => -47.62, altitude => 580 });

# johndoe is the submitter of this test; earlier tests (Roles.t) may have removed that role
my $dbh = $schema->storage->dbh;
my ($submitter_role_id) = $dbh->selectrow_array("SELECT sp_role_id FROM sgn_people.sp_roles WHERE name = 'submitter'");
my ($john_id) = $dbh->selectrow_array("SELECT sp_person_id FROM sgn_people.sp_person WHERE username = 'johndoe'");
my ($john_is_submitter) = $dbh->selectrow_array('SELECT COUNT(*) FROM sgn_people.sp_person_roles WHERE sp_person_id = ? AND sp_role_id = ?', undef, $john_id, $submitter_role_id);
$dbh->do('INSERT INTO sgn_people.sp_person_roles (sp_person_id, sp_role_id) VALUES (?, ?)', undef, $john_id, $submitter_role_id) if !$john_is_submitter;

END {
    local $?;
    eval { $dbh->do('DELETE FROM sgn_people.sp_person_roles WHERE sp_person_id = ? AND sp_role_id = ?', undef, $john_id, $submitter_role_id) if $john_id && !$john_is_submitter; 1 }
        or diag("could not restore the roles of johndoe: $@");
    eval { $schema->storage->dbh->do('DELETE FROM local_weather_station WHERE nd_geolocation_id = ?', undef, $loc_id) if $loc_id; 1 }
        or diag("could not delete the test stations: $@");
    eval { $loc->update({ latitude => $old_lat, longitude => $old_lon, altitude => $old_alt }) if $loc; 1 }
        or diag("could not restore test_location: $@");
    eval { $f->clean_up_db(); 1 } or diag("clean_up_db failed: $@");
}

# POST a CSV to an upload endpoint ($what: data or stations), as $mech or as another user
sub send_file {
    my ($m, $what, $content, @fields) = @_;
    my $file = "$dir/$what.csv";
    open(my $fh, '>', $file) or die $!;
    print $fh $content;
    close($fh);
    my ($url, $field) = $what eq 'stations' ? ('upload_stations', 'stations_file') : ('upload', 'weather_file');
    $m->request(POST "$base/ajax/weather/$url", Content_Type => 'form-data', Content => [ @fields, $field => [ $file, "$what.csv" ] ]);
    return decode_json($m->content);
}
sub upload { my $m = ref($_[0]) ? shift : $mech; return send_file($m, 'data', @_) }
sub upload_stations { my $m = ref($_[0]) ? shift : $mech; return send_file($m, 'stations', @_) }

# logged out
$mech->get("$base/ajax/weather/local_stations");
is($mech->status, 401, 'needs login');

$mech->post_ok("$base/brapi/v1/token", [ username => 'janedoe', password => 'secretpw', grant_type => 'password' ]);
my $token = decode_json($mech->content)->{access_token};
$mech->cookie_jar->set_cookie(0, 'sgn_session_id', $token, '/', 'localhost', 3010, 0, 0, 86400, 0);

$mech->get_ok("$base/ajax/weather/config");
my $cfg = decode_json($mech->content);
is($cfg->{can_upload}, 1, 'curator can upload');
is($cfg->{upload_resolution}, 'daily', 'daily uploads by default');
ok($cfg->{networks}{local}, 'local network listed');

# template
$mech->get_ok("$base/ajax/weather/upload_template?location_id=$loc_id");
like($mech->content, qr/^location_name,station_name,date,tmax,tmin,tmean,rain_mm/, 'daily template');
like($mech->content, qr/"test_location"/, 'with the name of the location');
$mech->get_ok("$base/ajax/weather/upload_template?location_id=$loc_id&station_name=Rain%20gauge%202");
like($mech->content, qr/"test_location","Rain gauge 2"/, 'with the chosen station');
$mech->get_ok("$base/ajax/weather/upload_template?kind=stations&location_id=$loc_id");
like($mech->content, qr/^location_name,station_name,station_latitude,station_longitude,station_elevation,description\n"test_location","Farm station",-22\.7,-47\.62,580,"[^"]+"\n/,
    'stations template with the position of the location');
unlike($mech->content, qr/,,/, 'every example row has all the required values');

# stations: curators only, checked before they are added
my $head = "location_name,station_name,station_latitude,station_longitude,station_elevation,description\n";
my $r = upload_stations("station_name,station_latitude\nFarm station,-22.71\n", location_id => $loc_id);
like($r->{error} . join(' ', @{$r->{errors} || []}), qr/needs the columns location_name, station_longitude, station_elevation, description/, 'required columns');
$r = upload_stations($head . ",Farm station,-22.7,-47.62,580,Davis\n", location_id => $loc_id);
like(join(' ', @{$r->{errors}}), qr/location_name is empty/, 'empty location_name refused, also with the location of the form');
$r = upload_stations($head . "test_location,Farm station,95,-47.62,580,Davis\n");
like(join(' ', @{$r->{errors}}), qr/out of the range/, 'stations file checked');
$r = upload_stations($head . "test_location,Farm station,-22.7,,580,Davis\ntest_location,Rain gauge 2,-22.7,-47.62,580,\n");
my $errs = join(' ', @{$r->{errors}});
like($errs, qr/Row 2: station_longitude is empty/, 'empty longitude refused');
like($errs, qr/Row 3: description is empty/, 'empty description refused');
my $stations = $head . "test_location,Farm station,-22.7,-47.62,580,Davis Vantage Pro2\ntest_location,Rain gauge 2,-22.71,-47.63,575,manual gauge\n";
$r = upload_stations($stations, check_only => 1);
is($r->{check_only}, 1, 'stations: check only');
is(scalar @{$r->{stations}}, 2, 'two stations in the check');
is($r->{stations}[0]{exists}, 0, 'new station');
$mech->get_ok("$base/ajax/weather/local_stations?location_id=$loc_id");
is(scalar @{decode_json($mech->content)->{stations}}, 0, 'nothing stored by the check');
$r = upload_stations($stations);
is($r->{created}, 2, 'two stations added');
$r = upload_stations($head . "test_location,Farm station,-22.7,-47.62,581,moved\n", location_id => $loc_id);
is($r->{updated}, 1, 'existing station updated');

# errors: nothing stored
$r = upload("location_name,station_name,date,rain_mm\nNowhere Farm,S1,2026-03-01,1\n");
like($r->{error}, qr/nothing was stored/, 'file with errors refused');
like(join(' ', @{$r->{errors}}), qr/does not exist in the database/, 'unknown location reported');

$r = upload("date,rain_mm\n2026-03-01,1\n", location_id => $loc_id, station_name => 'Farm station');
like(join(' ', @{$r->{errors} || [ $r->{error} ]}), qr/needs the columns location_name, station_name/, 'location_name and station_name columns required');

$r = upload("location_name,station_name,date,time,temp\ntest_location,S1,2026-03-01,10:00,25\n");
like(join(' ', @{$r->{errors} || [ $r->{error} ]}), qr/daily data only/, 'sub-daily refused by the configuration');

# data go into existing stations only (also for curators)
$r = upload("location_name,station_name,date,rain_mm\ntest_location,Unknown gauge,2026-03-01,1\n", location_id => $loc_id, station_name => 'Unknown gauge');
like($r->{error}, qr/stations that do not exist/, 'data of an unknown station refused');
like(join(' ', @{$r->{errors}}), qr/'Unknown gauge' does not exist.*Add stations tab/, 'curator told to add it first');

# check first: nothing stored
my $good = "location_name,station_name,date,tmax,tmin,rain_mm\ntest_location,Farm station,2026-03-01,31,19,12.4\ntest_location,Farm station,2026-03-02,30,20,0\n";
$r = upload($good, location_id => $loc_id, station_name => 'Farm station', check_only => 1);
is($r->{check_only}, 1, 'data: check only');
is($r->{stations}[0]{new_days}, 2, 'two new days in the check');
is($r->{stations}[0]{replaced_days}, 0, 'none replaced');

# a good file, for the location of the form
$r = upload($good, location_id => $loc_id, station_name => 'Farm station');
is($r->{success}, 1, 'uploaded');
my ($st) = @{$r->{stations}};
is($st->{inserted}, 2, '2 days');
like($st->{id}, qr/^L\d+$/, 'station id');

$r = upload($good, location_id => $loc_id, station_name => 'Farm station', check_only => 1);
is($r->{stations}[0]{replaced_days}, 2, 'the check says which days would be replaced');

$mech->get_ok("$base/ajax/weather/local_stations?location_id=$loc_id");
my ($l) = grep { $_->{name} eq 'Farm station' } @{decode_json($mech->content)->{stations}};
is($l->{name}, 'Farm station', 'listed');
is($l->{days}, 2, 'with its days');
is($l->{can_delete}, 1, 'the uploader can delete it');
is(decode_json($mech->content)->{can_create}, 1, 'curators can add stations');

# a submitter loads data into existing stations, but cannot add a station
my $sub = Test::WWW::Mechanize->new;
$sub->post_ok("$base/brapi/v1/token", [ username => 'johndoe', password => 'secretpw', grant_type => 'password' ]);
$sub->cookie_jar->set_cookie(0, 'sgn_session_id', decode_json($sub->content)->{access_token}, '/', 'localhost', 3010, 0, 0, 86400, 0);
$sub->get_ok("$base/ajax/weather/local_stations?location_id=$loc_id");
my $sl = decode_json($sub->content);
is($sl->{can_create}, 0, 'submitters cannot add stations');
is($sl->{can_upload}, 1, 'but can upload');
$r = upload($sub, "location_name,station_name,date,rain_mm\ntest_location,New gauge,2026-03-03,1\n", location_id => $loc_id, station_name => 'New gauge');
like(join(' ', @{$r->{errors}}), qr/'New gauge' does not exist.*ask a curator/, 'submitter refused for a new station');
$r = upload($sub, "location_name,station_name,date,rain_mm\ntest_location,Another one,2026-03-03,1\n");
like($r->{error}, qr/do not exist/, 'also when the new station is in the file');
$sub->request(POST "$base/ajax/weather/upload_stations", Content_Type => 'form-data', Content => [ location_id => $loc_id ]);
is($sub->status, 403, 'submitters cannot add stations');
$r = upload($sub, "location_name,station_name,date,rain_mm\ntest_location,farm station,2026-03-03,1.5\n", location_id => $loc_id, station_name => 'farm station');
is($r->{success}, 1, 'submitter adds data to an existing station');
is($r->{stations}[0]{inserted}, 1, 'one day added');
$r = upload("location_name,station_name,date,rain_mm\ntest_location,Rain gauge 2,2026-03-04,1\n", location_id => $loc_id, station_name => 'Rain gauge 2');
my $r2 = upload("location_name,station_name,date,rain_mm\ntest_location,Farm station,2026-03-05,1\n", location_id => $loc_id, station_name => 'Rain gauge 2');
like(join(' ', @{$r2->{errors}}), qr/'Farm station' is not Rain gauge 2/, 'rows of another station than the one chosen refused');
is($r->{success}, 1, 'curator loads data into the second station');
$sub->post("$base/ajax/weather/delete_local_station", [ station_id => $r->{stations}[0]{id} ]);
is($sub->status, 403, 'delete refused (403)');
like(decode_json($sub->content)->{error}, qr/Only curators and the user who uploaded/, 'submitter cannot delete a station of someone else');
$mech->post_ok("$base/ajax/weather/delete_local_station", [ station_id => $r->{stations}[0]{id} ]);

# the uploaded station on the Weather page
$mech->get_ok("$base/ajax/weather/nearby?location_id=$loc_id&range=50&unit=km&networks=local");
my ($near) = grep { $_->{id} eq $st->{id} } @{decode_json($mech->content)->{stations}};
ok($near, 'uploaded station within the range');
is($near->{distance_km}, 0, 'at the location');

$mech->get_ok("$base/ajax/weather/daily?location_id=$loc_id&network=local&station=$st->{id}&start=2026-03-01&end=2026-03-31");
my $daily = decode_json($mech->content);
is(scalar @{$daily->{days}}, 3, 'daily data of the uploaded station (2 days of the curator, 1 of the submitter)');
is($daily->{days}[0]{rain}, 12.4, 'rain');

$mech->post_ok("$base/ajax/weather/save_station", [ location_id => $loc_id, network => 'local', station_id => $st->{id}, name => 'Farm station', distance_km => 0 ]);
is(decode_json($mech->content)->{success}, 1, 'uploaded station saved as the station of the location');

$mech->get_ok("$base/ajax/weather/location_summary?location_id=$loc_id");
my $sum = decode_json($mech->content);
is($sum->{station}{station_id}, $st->{id}, 'summary: linked station');
is(scalar @{$sum->{local_stations}}, 1, 'summary: uploaded stations');
is($sum->{max_days}, 400, 'summary: longest interval');
like($sum->{today}, qr/^\d{4}-\d\d-\d\d$/, 'summary: today');

# trial page section
my $trial_id = $schema->resultset('Project::Project')->find({ name => 'test_trial' })->project_id;
$mech->get_ok("$base/breeders/trial/$trial_id");
$mech->content_like(qr{/breeders/weather\?location_id=\d+&trial_id=$trial_id}, 'link to the Weather tool for the season of the trial');
$mech->content_contains('wx_upload_dialog', 'upload dialog');
$mech->content_contains('tw_station', 'station picker of the weather summary');
$mech->content_lacks('weather.rtbbase.org', 'no RTBbase lookup by default');

# delete: the link of the location goes too
$mech->post_ok("$base/ajax/weather/delete_local_station", [ station_id => $st->{id} ]);
is(decode_json($mech->content)->{success}, 1, 'deleted');
$mech->get_ok("$base/ajax/weather/location_summary?location_id=$loc_id");
$sum = decode_json($mech->content);
ok(!$sum->{station}, 'location link removed');
is(scalar @{$sum->{local_stations}}, 0, 'no uploaded station left');

done_testing();
