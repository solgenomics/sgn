
=head1 NAME

SGN::Controller::AJAX::Weather - backend of the Weather page (/breeders/weather)

=head1 DESCRIPTION

Observed weather of real stations near the research stations (Breedbase
locations): airports, national weather service stations (SYNOP), CoCoRaHS
(USA), IDEAM (Colombia), INMET, ANA and CEMADEN (Brazil), DWD (Germany), JMA
AMeDAS (Japan), ECCC (Canada), USDA SCAN, ISU, CoAgMet and AZMet (USA), SMN
(Mexico), INTA (Argentina), SILO (Australia), IMS (Israel), regional councils
(New Zealand), and with free keys AEMET (Spain), Meteo-France and DMC (Chile).
See CXGN::Weather.
Plus the stations of research farms whose data users upload (network 'local',
see CXGN::Weather::Local).

  GET  /ajax/weather/config          defaults (range, unit) and what the user may do
  GET  /ajax/weather/locations       locations with coordinates and their weather station
  GET  /ajax/weather/nearby          stations within a range of a location
  POST /ajax/weather/save_station    link a station to a location (with the range used)
  POST /ajax/weather/clear_station   remove that link
  GET  /ajax/weather/daily           daily summary of a station between two dates
  GET  /ajax/weather/trials          trials of a location with planting / harvest dates
  GET  /ajax/weather/upload_template CSV template of the station data upload
  POST /ajax/weather/upload          upload a CSV / Excel file of station data (network 'local'); check_only=1 checks it
  POST /ajax/weather/upload_stations add stations from a CSV / Excel file (curators); check_only=1 checks it
  GET  /ajax/weather/local_stations  uploaded stations of a location
  POST /ajax/weather/delete_local_station   delete an uploaded station and its data
  GET  /ajax/weather/location_summary       linked and uploaded stations of a location (trial page)

Configuration (sgn.conf / sgn_local.conf):

  weather_station_range         200       default search range
  weather_station_range_unit    km        km or mi
  weather_station_max_range_km  500       largest range a user can ask for
  weather_station_networks      airport,synop,cocorahs,ideam,inmet,ana,cemaden,dwd,jma,eccc,scan,isusm,
                                coagmet,azmet,conagua,inta,silo,ims,hilltop,aemet,meteofrance,dmc
  weather_station_role          curator,submitter   roles that may link stations
  weather_max_days              400       longest date range of a daily request
  weather_upload_resolution     daily     daily = uploads with one row per day only; subdaily = also hourly / 15-min rows
  inmet                         0         1 = read INMET stations (Brazil) from the INMET historical files
                                          (portal.inmet.gov.br/dadoshistoricos, updated monthly, last 5 years)
  aemet_api_key                           free AEMET key (Spain)
  meteofrance_api_key                     free Meteo-France API key (France)
  dmc_api_key                             free DMC key of Chile, written e-mail:token
  silo_username                           e-mail address of the site admin, asked by SILO (Australia)
  weather_hilltop_servers                 Hilltop servers of New Zealand councils (default: the known ones)
  Every key may list several keys separated by commas: the next one is used when one is refused.
  weather_cache_dir                       default: <tmp>/breedbase_weather_cache

=head1 AUTHOR

Chris Simoes

=cut

package SGN::Controller::AJAX::Weather;

use Moose;
use JSON;
use Try::Tiny;
use POSIX qw(strftime);
use Time::Local qw(timegm);
use CXGN::Weather;
use CXGN::Weather::Local;
use CXGN::UploadFile;
use CXGN::BreedersToolbox::Projects;
use SGN::Model::Cvterm;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default => 'application/json',
    stash_key => 'rest',
    map => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
);

my $PROP = 'weather_station';
my $DEFAULT_NETWORKS = 'airport,synop,cocorahs,ideam,inmet,ana,cemaden,dwd,jma,eccc,scan,isusm,coagmet,azmet,conagua,inta,silo,ims,hilltop,aemet,meteofrance,dmc';    # nd_geolocationprop holding the linked station (JSON)

sub _fail {
    my ($c, $msg, $status) = @_;
    $c->response->status($status) if $status;
    $c->stash->{rest} = { error => $msg };
    return;
}

sub _schema { return shift->dbic_schema('Bio::Chado::Schema') }

sub _conf {
    my ($c, $key, $default) = @_;
    my $v = $c->config->{$key};
    $v = $v->[0] if ref($v) eq 'ARRAY';
    return (defined $v && $v ne '' && $v ne 'NULL') ? $v : $default;
}

sub _weather {
    my $c = shift;
    # the free key of each network that needs one: <network>_api_key
    my %keys;
    foreach my $k (keys %{$c->config}) {
        my ($n) = $k =~ /^(\w+?)_api_key$/ or next;
        my $v = _conf($c, $k, undef);
        $keys{$n} = $v if defined $v;
    }
    $keys{silo} //= _conf($c, 'silo_username', undef);
    my %args = (api_keys => \%keys, inmet_files => _conf($c, 'inmet', 0) ? 1 : 0);
    my $hilltop = _conf($c, 'weather_hilltop_servers', undef);
    $args{hilltop_servers} = $hilltop if $hilltop;
    my $dir = _conf($c, 'weather_cache_dir', undef);
    $args{cache_dir} = $dir if $dir;
    return CXGN::Weather->new(\%args);
}

# the networks of the configuration, plus the uploaded stations (always on)
sub _networks {
    my $c = shift;
    my $known = _weather($c)->networks();
    my @n = grep { $known->{$_} } split /\s*,\s*/, _conf($c, 'weather_station_networks', $DEFAULT_NETWORKS);
    return [ (@n ? @n : 'airport'), $CXGN::Weather::Local::NETWORK ];
}

sub _local { return CXGN::Weather::Local->new({ schema => _schema(shift) }) }

sub _resolution { return _conf(shift, 'weather_upload_resolution', 'daily') eq 'subdaily' ? 'subdaily' : 'daily' }

sub _person_id { my $c = shift; return $c->user ? $c->user->get_object->get_sp_person_id : undef }

sub _can_save {
    my $c = shift;
    return 0 if !$c->user;
    foreach my $role (split /\s*,\s*/, _conf($c, 'weather_station_role', 'curator,submitter')) {
        return 1 if $role ne '' && $c->user->check_roles($role);
    }
    return 0;
}

sub _login {
    my $c = shift;
    return 1 if $c->user;
    _fail($c, 'You must be logged in to use the weather tool.', 401);
    return 0;
}

sub _prop_type_id {
    my ($c, $create) = @_;
    my $schema = _schema($c);
    my $row = SGN::Model::Cvterm->get_cvterm_row($schema, $PROP, 'geolocation_property');
    if (!$row && $create) {
        $row = $schema->resultset('Cv::Cvterm')->create_with({ name => $PROP, cv => 'geolocation_property' });
    }
    return $row ? $row->cvterm_id : undef;
}

sub _location {
    my ($c, $id) = @_;
    return if !$id || $id !~ /^\d+$/;
    my $row = _schema($c)->resultset('NaturalDiversity::NdGeolocation')->find({ nd_geolocation_id => $id });
    return if !$row;
    return {
        id => $row->nd_geolocation_id,
        name => $row->description,
        lat => $row->latitude,
        lon => $row->longitude,
        elev => $row->altitude,
    };
}

sub _range_km {
    my ($c, $wx) = @_;
    my $unit = ($c->req->param('unit') // _conf($c, 'weather_station_range_unit', 'km')) eq 'mi' ? 'mi' : 'km';
    my $range = $c->req->param('range') // _conf($c, 'weather_station_range', 200);
    $range = 200 if $range !~ /^\d+(\.\d+)?$/ || $range <= 0;
    my $km = $wx->to_km($range, $unit);
    my $max = _conf($c, 'weather_station_max_range_km', 500);
    $km = $max if $km > $max;
    return ($km, $range, $unit);
}

sub _valid_date { my $d = shift; return defined $d && $d =~ /^\d{4}-\d\d-\d\d$/ }

=head2 weather_config

=cut

sub weather_config :Path('/ajax/weather/config') Args(0) {
    my ($self, $c) = @_;
    return if !_login($c);
    my $wx = _weather($c);
    my $nets = $wx->networks();
    $nets->{$CXGN::Weather::Local::NETWORK} = {
        label => 'Uploaded station',
        source => 'Stations of research farms, data uploaded by Breedbase users (CSV / Excel)',
        note => 'Daily values uploaded from the station of the farm.',
    };
    my %enabled = map { $_ => 1 } @{_networks($c)};
    $c->stash->{rest} = {
        range => _conf($c, 'weather_station_range', 200) + 0,
        unit => _conf($c, 'weather_station_range_unit', 'km') eq 'mi' ? 'mi' : 'km',
        max_range_km => _conf($c, 'weather_station_max_range_km', 500) + 0,
        max_days => _conf($c, 'weather_max_days', 400) + 0,
        networks => { map { $_ => $nets->{$_} } grep { $enabled{$_} } keys %$nets },
        can_save => _can_save($c),
        can_upload => _can_save($c),
        upload_resolution => _resolution($c),
        today => strftime('%Y-%m-%d', localtime),
    };
}

=head2 locations

All locations with their coordinates, programs, trial count and linked
weather station (if any).

=cut

sub locations :Path('/ajax/weather/locations') Args(0) {
    my ($self, $c) = @_;
    return if !_login($c);
    my $schema = _schema($c);
    my $features = CXGN::BreedersToolbox::Projects->new({ schema => $schema })->get_location_geojson_data();

    my %linked;
    if (my $type_id = _prop_type_id($c, 0)) {
        my $rs = $schema->resultset('NaturalDiversity::NdGeolocationprop')->search({ type_id => $type_id });
        while (my $p = $rs->next) {
            my $v = eval { decode_json($p->value) };
            $linked{$p->nd_geolocation_id} = $v if $v;
        }
    }

    my @out;
    foreach my $f (@$features) {
        my $p = $f->{properties};
        my ($trials) = ($p->{Trials} // '') =~ />(\d+) trials</;
        push @out, {
            id => $p->{Id},
            name => $p->{Name},
            abbreviation => $p->{Abbreviation},
            country => $p->{Country},
            country_code => $p->{Code},
            program => $p->{Program},
            type => $p->{Type},
            lat => $p->{Latitude},
            lon => $p->{Longitude},
            elev => $p->{Altitude},
            trials => ($trials // 0) + 0,
            station => $linked{$p->{Id}},
        };
    }
    @out = sort { lc($a->{name} // '') cmp lc($b->{name} // '') } @out;
    $c->stash->{rest} = { locations => \@out };
}

=head2 nearby

Params: location_id, range, unit (km|mi), networks (comma list, optional).

=cut

sub nearby :Path('/ajax/weather/nearby') Args(0) {
    my ($self, $c) = @_;
    return if !_login($c);
    my $loc = _location($c, $c->req->param('location_id'));
    return _fail($c, 'Location not found.') if !$loc;
    return _fail($c, 'This location has no latitude/longitude. Add them in Manage > Locations first.')
        if !defined $loc->{lat} || !defined $loc->{lon};
    my $wx = _weather($c);
    my ($km, $range, $unit) = _range_km($c, $wx);
    my %enabled = map { $_ => 1 } @{_networks($c)};
    my @nets = grep { $enabled{$_} } split /,/, ($c->req->param('networks') || join(',', keys %enabled));
    my $want_local = grep { $_ eq $CXGN::Weather::Local::NETWORK } @nets;
    @nets = grep { $_ ne $CXGN::Weather::Local::NETWORK } @nets;
    my $res = try { $wx->nearby_stations($loc->{lat}, $loc->{lon}, $km, \@nets) } catch { { error => "$_" } };
    return _fail($c, $res->{error}) if $res->{error};
    if ($want_local) {
        my $local = try { _local($c)->nearby_stations($wx, $loc->{lat}, $loc->{lon}, $km) } catch { push @{$res->{errors}}, "Uploaded stations: $_"; [] };
        $res->{stations} = [ sort { $a->{distance_km} <=> $b->{distance_km} } @$local, @{$res->{stations}} ];
    }
    $c->stash->{rest} = {
        location => $loc,
        range => $range + 0,
        unit => $unit,
        range_km => sprintf('%.1f', $km) + 0,
        stations => $res->{stations},
        warnings => $res->{errors},
    };
}

=head2 save_station

POST location_id, network, station_id, name, lat, lon, elev, distance_km,
range, unit. Needs one of the roles of weather_station_role.

=cut

sub save_station :Path('/ajax/weather/save_station') Args(0) {
    my ($self, $c) = @_;
    return if !_login($c);
    return _fail($c, 'You do not have permission to link weather stations (role needed: '
        . _conf($c, 'weather_station_role', 'curator,submitter') . ').', 403) if !_can_save($c);
    my $p = $c->req->params;
    my $loc = _location($c, $p->{location_id});
    return _fail($c, 'Location not found.') if !$loc;
    return _fail($c, 'Choose a weather station.') if !$p->{station_id} || $p->{station_id} !~ /^[A-Za-z0-9_-]{2,20}$/;
    return _fail($c, 'Unknown station network.') if !grep { $_ eq ($p->{network} // '') } @{_networks($c)};

    my $num = sub { my $v = shift; return (defined $v && $v =~ /^-?\d+(\.\d+)?$/) ? $v + 0 : undef };
    my $value = {
        network => $p->{network},
        station_id => uc($p->{station_id}),
        name => substr($p->{name} // '', 0, 200),
        lat => $num->($p->{lat}),
        lon => $num->($p->{lon}),
        elev => $num->($p->{elev}),
        distance_km => $num->($p->{distance_km}),
        range => $num->($p->{range}) // _conf($c, 'weather_station_range', 200) + 0,
        unit => ($p->{unit} // '') eq 'mi' ? 'mi' : 'km',
        rain_only => $p->{rain_only} ? 1 : 0,
        temp_network => undef,
        saved_by => $c->user->get_object->get_sp_person_id,
        saved_by_name => join(' ', grep { $_ } $c->user->get_object->get_first_name, $c->user->get_object->get_last_name),
        saved_date => strftime('%Y-%m-%d %H:%M', localtime),
    };
    # optional second station for temperature / ET0 (when the first one measures only rain)
    if ($p->{temp_station_id}) {
        return _fail($c, 'Unknown network of the temperature station.') if !grep { $_ eq ($p->{temp_network} // '') } @{_networks($c)};
        return _fail($c, 'Bad temperature station.') if $p->{temp_station_id} !~ /^[A-Za-z0-9_-]{2,20}$/;
        $value->{temp_network} = $p->{temp_network};
        $value->{temp_station_id} = uc($p->{temp_station_id});
        $value->{temp_name} = substr($p->{temp_name} // '', 0, 200);
        $value->{temp_lat} = $num->($p->{temp_lat});
        $value->{temp_lon} = $num->($p->{temp_lon});
        $value->{temp_elev} = $num->($p->{temp_elev});
        $value->{temp_distance_km} = $num->($p->{temp_distance_km});
    }
    else { delete $value->{temp_network}; }
    my $type_id = _prop_type_id($c, 1);
    my $rs = _schema($c)->resultset('NaturalDiversity::NdGeolocationprop');
    my $row = $rs->search({ nd_geolocation_id => $loc->{id}, type_id => $type_id })->first;
    if ($row) { $row->update({ value => encode_json($value) }); }
    else { $rs->create({ nd_geolocation_id => $loc->{id}, type_id => $type_id, value => encode_json($value), rank => 0 }); }
    $c->stash->{rest} = { success => 1, station => $value };
}

=head2 clear_station

=cut

sub clear_station :Path('/ajax/weather/clear_station') Args(0) {
    my ($self, $c) = @_;
    return if !_login($c);
    return _fail($c, 'You do not have permission to change weather stations.', 403) if !_can_save($c);
    my $loc = _location($c, $c->req->param('location_id'));
    return _fail($c, 'Location not found.') if !$loc;
    if (my $type_id = _prop_type_id($c, 0)) {
        _schema($c)->resultset('NaturalDiversity::NdGeolocationprop')
            ->search({ nd_geolocation_id => $loc->{id}, type_id => $type_id })->delete;
    }
    $c->stash->{rest} = { success => 1 };
}

sub _station_params {
    my $c = shift;
    my $network = $c->req->param('network') // 'airport';
    my $id = $c->req->param('station') // '';
    return () if !grep { $_ eq $network } @{_networks($c)};
    return () if $id !~ /^[A-Za-z0-9_-]{2,20}$/;
    return ($network, uc $id);
}

=head2 daily

Params: location_id, network, station, start, end (YYYY-MM-DD).

=cut

sub daily :Path('/ajax/weather/daily') Args(0) {
    my ($self, $c) = @_;
    return if !_login($c);
    my $loc = _location($c, $c->req->param('location_id'));
    return _fail($c, 'Location not found.') if !$loc;
    my ($network, $id) = _station_params($c);
    return _fail($c, 'Choose a weather station.') if !$id;
    my ($start, $end) = ($c->req->param('start'), $c->req->param('end'));
    return _fail($c, 'Choose the start and end dates.') if !_valid_date($start) || !_valid_date($end);
    return _fail($c, 'The start date must be before the end date.') if $start gt $end;
    my $days = _days_between($start, $end);
    my $max = _conf($c, 'weather_max_days', 400);
    return _fail($c, "The date range is too long ($days days). Choose at most $max days.") if $days > $max;

    # the station position (from the request, or the linked station) for ET0
    my $num = sub { my $v = shift; return (defined $v && $v =~ /^-?\d+(\.\d+)?$/) ? $v + 0 : undef };
    my $slat = $num->($c->req->param('lat')) // $loc->{lat};
    my $slon = $num->($c->req->param('lon')) // $loc->{lon};
    my $selev = $num->($c->req->param('elev')) // $loc->{elev};
    return _fail($c, 'The station position is unknown.') if !defined $slat || !defined $slon;

    my $res = try {
        $network eq $CXGN::Weather::Local::NETWORK
            ? _local($c)->station_daily(_weather($c), $id, $slat, $slon, $selev, $start, $end)
            : _weather($c)->station_daily($network, $id, $slat, $slon, $selev, $start, $end)
    } catch { { error => "$_" } };
    return _fail($c, $res->{error}) if $res->{error};
    $c->stash->{rest} = { network => $network, station => $id, start => $start, end => $end, %$res };
}

sub _days_between {
    my ($s, $e) = @_;
    my @a = split /-/, $s;
    my @b = split /-/, $e;
    return int((timegm(0, 0, 12, $b[2], $b[1] - 1, $b[0]) - timegm(0, 0, 12, $a[2], $a[1] - 1, $a[0])) / 86400) + 1;
}

=head2 trials

Param: location_id. Trials of the location with year, planting and harvest
dates (YYYY-MM-DD), to fill the date range with a crop season.

=cut

sub trials :Path('/ajax/weather/trials') Args(0) {
    my ($self, $c) = @_;
    return if !_login($c);
    my $loc = _location($c, $c->req->param('location_id'));
    return _fail($c, 'Location not found.') if !$loc;
    my $schema = _schema($c);
    my $id_of = sub {
        my ($name, $cv) = @_;
        my $row = SGN::Model::Cvterm->get_cvterm_row($schema, $name, $cv);
        return $row ? $row->cvterm_id : -1;
    };
    my $q = "SELECT p.project_id, p.name, yr.value, pd.value, hd.value
        FROM project p
        JOIN projectprop loc ON (loc.project_id = p.project_id AND loc.type_id = ? AND loc.value = ?)
        LEFT JOIN projectprop yr ON (yr.project_id = p.project_id AND yr.type_id = ?)
        LEFT JOIN projectprop pd ON (pd.project_id = p.project_id AND pd.type_id = ?)
        LEFT JOIN projectprop hd ON (hd.project_id = p.project_id AND hd.type_id = ?)
        ORDER BY yr.value DESC NULLS LAST, p.name";
    my $h = $schema->storage->dbh->prepare($q);
    $h->execute($id_of->('project location', 'project_property'), $loc->{id}, $id_of->('project year', 'project_property'),
        $id_of->('project_planting_date', 'project_property'), $id_of->('project_harvest_date', 'project_property'));
    my $date = sub {
        my $v = shift // return;
        return "$1-$2-$3" if $v =~ /(\d{4})[-\/](\d\d)[-\/](\d\d)/;
        return;
    };
    my @trials;
    while (my ($pid, $name, $year, $pd, $hd) = $h->fetchrow_array) {
        push @trials, { id => $pid, name => $name, year => $year, planting => scalar($date->($pd)), harvest => scalar($date->($hd)) };
    }
    $c->stash->{rest} = { trials => \@trials };
}

=head2 upload_template

Params: kind (data, the default, or stations), resolution (daily|subdaily,
default daily), location_id and station_name (optional: they fill the
example rows). A CSV file.

=cut

sub upload_template :Path('/ajax/weather/upload_template') Args(0) {
    my ($self, $c) = @_;
    return if !_login($c);
    my $loc = _location($c, scalar($c->req->param('location_id')));
    my $name = $loc ? $loc->{name} : 'name of a Breedbase location';
    $name =~ s/"/""/g;
    if (($c->req->param('kind') // '') eq 'stations') {
        # example rows at the position of the location (all columns are required)
        my ($lat, $lon, $elev) = $loc && defined $loc->{lat} ? (sprintf('%.5f', $loc->{lat}) + 0, sprintf('%.5f', $loc->{lon}) + 0, sprintf('%.0f', $loc->{elev} // 0) + 0) : ('-22.70000', '-47.62000', 580);
        my $csv = join(',', @{_local($c)->station_template_columns()}) . "\n"
            . join(',', qq{"$name"}, '"Farm station"', $lat, $lon, $elev, '"Automatic station (Davis Vantage Pro2) near the office: temperature, rain, humidity, wind, radiation"') . "\n"
            . join(',', qq{"$name"}, '"Rain gauge field 3"', $lat, $lon, $elev, '"Manual rain gauge read at 7 h, field 3"') . "\n";
        $c->res->content_type('text/csv');
        $c->res->header('Content-Disposition', 'attachment; filename="weather_stations_template.csv"');
        $c->res->body($csv);
        return;
    }
    my $res = (($c->req->param('resolution') // '') eq 'subdaily' && _resolution($c) eq 'subdaily') ? 'subdaily' : 'daily';
    my $cols = _local($c)->template_columns($res);
    my @ex = $res eq 'subdaily'
        ? (['2026-03-01', '00:00', '21.4', '0', '88', '1.2', '0'], ['2026-03-01', '01:00', '21.0', '0.4', '90', '0.8', '0'])
        : (['2026-03-01', '31.2', '19.8', '24.9', '12.4', '78', '1.9', '21.3'], ['2026-03-02', '30.5', '20.1', '24.6', '0', '74', '2.3', '23.8']);
    my $station = $c->req->param('station_name') // '';
    $station =~ s/^\s+|\s+$//g;
    $station = 'Farm station' if $station eq '';
    $station =~ s/"/""/g;
    my $csv = join(',', @$cols) . "\n" . join('', map { join(',', qq{"$name"}, qq{"$station"}, @$_) . "\n" } @ex);
    $c->res->content_type('text/csv');
    $c->res->header('Content-Disposition', 'attachment; filename="weather_station_' . $res . '_template.csv"');
    $c->res->body($csv);
}

=head2 upload

POST (multipart) weather_file (CSV, XLS or XLSX; location_name and
station_name required in every row), location_id and station_name
(optional: then every row must be of that location / station). check_only (1 =
check the file and say what would be stored, without storing it). Needs one
of the roles of weather_station_role. The stations must exist (curators add
them with upload_stations). Nothing is stored when the file has an error.
Days already stored for a station are replaced.

=cut

sub upload :Path('/ajax/weather/upload') Args(0) {
    my ($self, $c) = @_;
    return if !_login($c);
    return _fail($c, 'You do not have permission to upload weather data (role needed: '
        . _conf($c, 'weather_station_role', 'curator,submitter') . ').', 403) if !_can_save($c);
    my $upload = $c->req->upload('weather_file');
    return _fail($c, 'Choose a file to upload.') if !$upload;
    my $original = $upload->filename;
    my ($ext) = $original =~ /\.(csv|xlsx|xls|txt|tsv)$/i;
    return _fail($c, 'The file must be CSV, XLS or XLSX.') if !$ext;

    my $location_id = $c->req->param('location_id');
    return _fail($c, 'Location not found.') if $location_id && !_location($c, $location_id);
    my $check_only = $c->req->param('check_only') ? 1 : 0;

    my $local = _local($c);
    my $parsed = $local->parse_file($upload->tempname, {
        location_id => $location_id, station_name => scalar($c->req->param('station_name')), resolution => _resolution($c), type => lc($ext),
    });
    if (@{$parsed->{errors}}) {
        $c->stash->{rest} = { error => 'The file has errors: nothing was stored.', errors => $parsed->{errors}, warnings => $parsed->{warnings} };
        return;
    }
    # data go into existing stations: curators add stations first (upload_stations)
    my $new = $local->new_stations($parsed);
    if (@$new) {
        $c->stash->{rest} = { error => 'The file has stations that do not exist: nothing was stored.',
            errors => [ map { "The station '$_->{name}' does not exist at $_->{location_name}. Choose an existing station"
                . ($c->user->check_roles('curator') ? ', or add it first in the Add stations tab.' : ', or ask a curator to add it.') } @$new ],
            warnings => $parsed->{warnings} };
        return;
    }
    if ($check_only) {
        $c->stash->{rest} = { success => 1, check_only => 1, resolution => $parsed->{resolution}, rows => $parsed->{rows},
            warnings => $parsed->{warnings}, stations => $local->preview($parsed) };
        return;
    }

    # keep the file in the archive (what was uploaded, by whom)
    my $user = $c->user->get_object;
    my $archived = _archive($c, $upload, 'weather_station_upload');
    return _fail($c, 'The file could not be saved in the archive.') if !$archived;
    my $res = try { $local->store($parsed, { sp_person_id => $user->get_sp_person_id, archived_file => $archived }) } catch { { error => "$_" } };
    return _fail($c, 'The data could not be stored: ' . $res->{error}) if $res->{error};
    $c->stash->{rest} = { success => 1, resolution => $parsed->{resolution}, rows => $parsed->{rows}, warnings => $parsed->{warnings}, stations => $res->{stations} };
}

sub _archive {
    my ($c, $upload, $dir) = @_;
    my $user = $c->user->get_object;
    return try {
        CXGN::UploadFile->new({
            tempfile => $upload->tempname, subdirectory => $dir, archive_path => $c->config->{archive_path},
            archive_filename => $upload->filename, timestamp => strftime('%Y-%m-%d_%H:%M:%S', localtime), user_id => $user->get_sp_person_id,
            user_role => $c->user->check_roles('curator') ? 'curator' : 'submitter',
        })->archive();
    } catch { undef };
}

=head2 upload_stations

POST (multipart) stations_file (CSV, XLS or XLSX: location_name,
station_name, station_latitude, station_longitude, station_elevation,
description: all required), location_id (optional: then every row must be
of that location), check_only (1 = check without storing). Curators
only. Existing stations (same location and name) get the position and
description of the file.

=cut

sub upload_stations :Path('/ajax/weather/upload_stations') Args(0) {
    my ($self, $c) = @_;
    return if !_login($c);
    return _fail($c, 'Only curators can add weather stations.', 403) if !$c->user->check_roles('curator');
    my $upload = $c->req->upload('stations_file');
    return _fail($c, 'Choose a file to upload.') if !$upload;
    my ($ext) = $upload->filename =~ /\.(csv|xlsx|xls|txt|tsv)$/i;
    return _fail($c, 'The file must be CSV, XLS or XLSX.') if !$ext;
    my $location_id = $c->req->param('location_id');
    return _fail($c, 'Location not found.') if $location_id && !_location($c, $location_id);
    my $local = _local($c);
    my $parsed = $local->parse_stations_file($upload->tempname, { location_id => $location_id, type => lc($ext) });
    if (@{$parsed->{errors}}) {
        $c->stash->{rest} = { error => 'The file has errors: nothing was stored.', errors => $parsed->{errors}, warnings => $parsed->{warnings} };
        return;
    }
    my @list = map { { name => $_->{name}, location_name => $_->{location}{name}, exists => $_->{exists}, lat => $_->{lat}, lon => $_->{lon},
        elev => $_->{elev}, description => $_->{description} } } @{$parsed->{stations}};
    if ($c->req->param('check_only')) {
        $c->stash->{rest} = { success => 1, check_only => 1, warnings => $parsed->{warnings}, stations => \@list };
        return;
    }
    return _fail($c, 'The file could not be saved in the archive.') if !_archive($c, $upload, 'weather_stations_upload');
    my $res = try { $local->store_stations($parsed, { sp_person_id => _person_id($c) }) } catch { { error => "$_" } };
    return _fail($c, 'The stations could not be stored: ' . $res->{error}) if $res->{error};
    $c->stash->{rest} = { success => 1, warnings => $parsed->{warnings}, %$res };
}

=head2 local_stations

Param: location_id (optional). The uploaded stations with a summary of
their data, and whether the user may delete each one.

=cut

sub local_stations :Path('/ajax/weather/local_stations') Args(0) {
    my ($self, $c) = @_;
    return if !_login($c);
    my $id = $c->req->param('location_id');
    return _fail($c, 'Location not found.') if defined $id && $id ne '' && !_location($c, $id);
    my $list = _local($c)->stations($id ? { location_id => $id } : {});
    my $me = _person_id($c);
    my $curator = $c->user->check_roles('curator');
    $_->{can_delete} = ($curator || (_can_save($c) && defined $_->{sp_person_id} && $_->{sp_person_id} == $me)) ? 1 : 0 for @$list;
    $c->stash->{rest} = { stations => $list, upload_resolution => _resolution($c), can_upload => _can_save($c), can_create => $curator ? 1 : 0 };
}

=head2 delete_local_station

POST station_id ('L12'). Curators, or the user who created the station.

=cut

sub delete_local_station :Path('/ajax/weather/delete_local_station') Args(0) {
    my ($self, $c) = @_;
    return if !_login($c);
    my $local = _local($c);
    my ($st) = @{$local->stations({ station_id => $c->req->param('station_id') })};
    return _fail($c, 'Station not found.') if !$st;
    my $mine = _can_save($c) && defined $st->{sp_person_id} && $st->{sp_person_id} == _person_id($c);
    return _fail($c, 'Only curators and the user who uploaded the station can delete it.', 403) if !$c->user->check_roles('curator') && !$mine;
    $local->delete_station($st->{id});
    # the location may have it as its weather station
    if (my $type_id = _prop_type_id($c, 0)) {
        my $prop = _schema($c)->resultset('NaturalDiversity::NdGeolocationprop')->search({ nd_geolocation_id => $st->{location_id}, type_id => $type_id })->first;
        my $v = $prop ? eval { decode_json($prop->value) } : undef;
        $prop->delete if $v && ($v->{network} // '') eq $CXGN::Weather::Local::NETWORK && uc($v->{station_id} // '') eq uc($st->{id});
    }
    $c->stash->{rest} = { success => 1 };
}

=head2 location_summary

Param: location_id. The weather station saved for the location and the
stations uploaded there, for the Weather section of the trial page.

=cut

sub location_summary :Path('/ajax/weather/location_summary') Args(0) {
    my ($self, $c) = @_;
    return if !_login($c);
    my $loc = _location($c, $c->req->param('location_id'));
    return _fail($c, 'Location not found.') if !$loc;
    my $linked;
    if (my $type_id = _prop_type_id($c, 0)) {
        my $prop = _schema($c)->resultset('NaturalDiversity::NdGeolocationprop')->search({ nd_geolocation_id => $loc->{id}, type_id => $type_id })->first;
        $linked = $prop ? eval { decode_json($prop->value) } : undef;
    }
    $c->stash->{rest} = {
        location => $loc,
        has_coordinates => (defined $loc->{lat} && defined $loc->{lon}) ? 1 : 0,
        station => $linked,
        local_stations => _local($c)->stations({ location_id => $loc->{id} }),
        can_upload => _can_save($c),
        upload_resolution => _resolution($c),
        max_days => _conf($c, 'weather_max_days', 400) + 0,
        range => (($linked && $linked->{range}) || _conf($c, 'weather_station_range', 200)) + 0,
        unit => (($linked && $linked->{unit}) || _conf($c, 'weather_station_range_unit', 'km')) eq 'mi' ? 'mi' : 'km',
        today => strftime('%Y-%m-%d', localtime),
    };
}

1;
