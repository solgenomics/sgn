
=head1 NAME

SGN::Controller::AJAX::Weather - backend of the Weather page (/breeders/weather)

=head1 DESCRIPTION

Observed weather of real stations near the research stations (Breedbase
locations): airports, national weather service stations (SYNOP), CoCoRaHS
(USA), IDEAM (Colombia), INMET, ANA and CEMADEN (Brazil). See CXGN::Weather.

  GET  /ajax/weather/config          defaults (range, unit) and what the user may do
  GET  /ajax/weather/locations       locations with coordinates and their weather station
  GET  /ajax/weather/nearby          stations within a range of a location
  POST /ajax/weather/save_station    link a station to a location (with the range used)
  POST /ajax/weather/clear_station   remove that link
  GET  /ajax/weather/daily           daily summary of a station between two dates
  GET  /ajax/weather/trials          trials of a location with planting / harvest dates

Configuration (sgn.conf / sgn_local.conf):

  weather_station_range         200       default search range
  weather_station_range_unit    km        km or mi
  weather_station_max_range_km  500       largest range a user can ask for
  weather_station_networks      airport,synop,cocorahs,ideam,inmet,ana,cemaden
  weather_station_role          curator,submitter   roles that may link stations
  weather_max_days              400       longest date range of a daily request
  inmet_api_token                         free INMET token (Brazilian stations)
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
use CXGN::BreedersToolbox::Projects;
use SGN::Model::Cvterm;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default => 'application/json',
    stash_key => 'rest',
    map => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
);

my $PROP = 'weather_station';    # nd_geolocationprop holding the linked station (JSON)

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
    my %args = (inmet_token => _conf($c, 'inmet_api_token', undef));
    my $dir = _conf($c, 'weather_cache_dir', undef);
    $args{cache_dir} = $dir if $dir;
    return CXGN::Weather->new(\%args);
}

sub _networks {
    my $c = shift;
    my @n = grep { /^(airport|synop|cocorahs|ideam|inmet|ana|cemaden)$/ } split /\s*,\s*/, _conf($c, 'weather_station_networks', 'airport,synop,cocorahs,ideam,inmet,ana,cemaden');
    return @n ? \@n : ['airport'];
}

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
    my %enabled = map { $_ => 1 } @{_networks($c)};
    $c->stash->{rest} = {
        range => _conf($c, 'weather_station_range', 200) + 0,
        unit => _conf($c, 'weather_station_range_unit', 'km') eq 'mi' ? 'mi' : 'km',
        max_range_km => _conf($c, 'weather_station_max_range_km', 500) + 0,
        max_days => _conf($c, 'weather_max_days', 400) + 0,
        networks => { map { $_ => $nets->{$_} } grep { $enabled{$_} } keys %$nets },
        can_save => _can_save($c),
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
    my $res = try { $wx->nearby_stations($loc->{lat}, $loc->{lon}, $km, \@nets) } catch { { error => "$_" } };
    return _fail($c, $res->{error}) if $res->{error};
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

    my $res = try { _weather($c)->station_daily($network, $id, $slat, $slon, $selev, $start, $end) } catch { { error => "$_" } };
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

1;
