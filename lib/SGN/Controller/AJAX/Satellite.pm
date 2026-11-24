=head1 NAME

SGN::Controller::AJAX::Satellite - backend of the Satellite page (/breeders/satellite)

=head1 DESCRIPTION

Sentinel-2 and Landsat 8/9 images of the field of a research station
(Breedbase location) or of a trial for a date range. The server only searches
the catalogues (CXGN::Satellite); the browser reads the images from the
public buckets.

  GET /ajax/satellite/locations   locations with coordinates
  GET /ajax/satellite/trials      trials of a location with planting / harvest dates
  GET /ajax/satellite/field       plot polygons (plot_geo_json) of a trial, or its drawn field
  POST /ajax/satellite/trial_field     save / remove the drawn field of a trial
  GET|POST /ajax/satellite/location_fields  the production fields drawn for a farm
  GET /ajax/satellite/sources     the satellites this server offers (never a key)
  GET /ajax/satellite/scenes      satellite scenes of an area and date range
  GET /ajax/satellite/landsat_token  a fresh read token for the Landsat images

Configuration (sgn.conf, all optional):

  satellite_stac_url     https://earth-search.aws.element84.com/v1   (Sentinel-2)
  satellite_landsat_stac_url   https://planetarycomputer.microsoft.com/api/stac/v1
  satellite_landsat_token_url  https://planetarycomputer.microsoft.com/api/sas/v1/token/landsat-c2-l2
  satellite_planet_api_key     (empty)  key of the organisation's Planet account, for
                               PlanetScope 3 m images (paid). Prepared only: PlanetScope is
                               offered once its search is written (see CXGN::Satellite).
  satellite_max_days     731     longest date range of a search

=head1 AUTHOR

Chris Simoes

=cut

package SGN::Controller::AJAX::Satellite;

use Moose;
use JSON;
use CXGN::Satellite;
use CXGN::Satellite::Fields;
use CXGN::Trial;
use Try::Tiny;
use CXGN::BreedersToolbox::Projects;
use SGN::Model::Cvterm;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default => 'application/json',
    stash_key => 'rest',
    map => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
);

sub _fail {
    my ($c, $msg) = @_;
    $c->stash->{rest} = { error => $msg };
    return;
}

sub _schema { return shift->dbic_schema('Bio::Chado::Schema') }

sub _login {
    my $c = shift;
    return 1 if $c->user;
    $c->res->status(401);
    _fail($c, 'You must be logged in.');
    return 0;
}

sub _satellite {
    my $c = shift;
    my %args;
    $args{stac_url} = $c->config->{satellite_stac_url} if $c->config->{satellite_stac_url};
    $args{landsat_stac_url} = $c->config->{satellite_landsat_stac_url} if $c->config->{satellite_landsat_stac_url};
    $args{landsat_token_url} = $c->config->{satellite_landsat_token_url} if $c->config->{satellite_landsat_token_url};
    $args{planet_api_key} = $c->config->{satellite_planet_api_key} if $c->config->{satellite_planet_api_key};
    $args{max_days} = $c->config->{satellite_max_days} if ($c->config->{satellite_max_days} // '') =~ /^\d+$/;
    return CXGN::Satellite->new(\%args);
}

sub _fields { return CXGN::Satellite::Fields->new({ schema => _schema(shift) }) }

# Editing a location: as /ajax/location/store (submitter or curator)
sub _can_edit_location {
    my $c = shift;
    return $c->user && ($c->user->check_roles('curator') || $c->user->check_roles('submitter')) ? 1 : 0;
}

# Editing a trial: as TrialMetadata (curator, or submitter in the trial's breeding program)
sub _can_edit_trial {
    my ($c, $trial_id) = @_;
    return 0 if !$c->user;
    return 1 if $c->user->check_roles('curator');
    return 0 if !$c->user->check_roles('submitter');
    my $programs = try { CXGN::Trial->new({ bcs_schema => _schema($c), trial_id => $trial_id })->get_breeding_programs() } || [];
    return (@$programs && $c->user->check_roles($programs->[0][1])) ? 1 : 0;
}

sub _json_param {
    my ($c, $name) = @_;
    my $v = $c->req->param($name);
    return if !defined $v || $v eq '';
    my $data = try { decode_json($v) };
    return $data;
}

sub _id {
    my $v = shift;
    return (defined $v && $v =~ /^\d+$/) ? $v : undef;
}

sub _type_id {
    my ($schema, $name, $cv) = @_;
    my $row = SGN::Model::Cvterm->get_cvterm_row($schema, $name, $cv);
    return $row ? $row->cvterm_id : -1;
}

=head2 locations

All locations with coordinates, country, program and trial count.

=cut

sub locations :Path('/ajax/satellite/locations') Args(0) {
    my ($self, $c) = @_;
    return if !_login($c);
    my $features = CXGN::BreedersToolbox::Projects->new({ schema => _schema($c) })->get_location_geojson_data();
    my @out;
    foreach my $f (@$features) {
        my $p = $f->{properties};
        my ($trials) = ($p->{Trials} // '') =~ />(\d+) trials</;
        push @out, {
            id => $p->{Id},
            name => $p->{Name},
            abbreviation => $p->{Abbreviation},
            country => $p->{Country},
            program => $p->{Program},
            type => $p->{Type},
            lat => $p->{Latitude},
            lon => $p->{Longitude},
            trials => ($trials // 0) + 0,
        };
    }
    @out = sort { lc($a->{name} // '') cmp lc($b->{name} // '') } @out;
    $c->stash->{rest} = { locations => \@out };
}

=head2 trials

Param: location_id. Trials of the location with year, planting and harvest
dates (YYYY-MM-DD).

=cut

sub trials :Path('/ajax/satellite/trials') Args(0) {
    my ($self, $c) = @_;
    return if !_login($c);
    my $location_id = _id($c->req->param('location_id')) // return _fail($c, 'No location given.');
    my $schema = _schema($c);
    my $q = "SELECT p.project_id, p.name, yr.value, pd.value, hd.value
        FROM project p
        JOIN projectprop loc ON (loc.project_id = p.project_id AND loc.type_id = ? AND loc.value = ?)
        LEFT JOIN projectprop yr ON (yr.project_id = p.project_id AND yr.type_id = ?)
        LEFT JOIN projectprop pd ON (pd.project_id = p.project_id AND pd.type_id = ?)
        LEFT JOIN projectprop hd ON (hd.project_id = p.project_id AND hd.type_id = ?)
        ORDER BY yr.value DESC NULLS LAST, p.name";
    my $h = $schema->storage->dbh->prepare($q);
    $h->execute(_type_id($schema, 'project location', 'project_property'), $location_id,
        _type_id($schema, 'project year', 'project_property'),
        _type_id($schema, 'project_planting_date', 'project_property'),
        _type_id($schema, 'project_harvest_date', 'project_property'));
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

=head2 field

Param: trial_id. The plot polygons (or points) of the trial from the plot
GPS coordinates (plot_geo_json): { plots => [ring...], bbox => [w,s,e,n], count }.
No coordinates: { plots => [], count => 0 }.

=cut

sub field :Path('/ajax/satellite/field') Args(0) {
    my ($self, $c) = @_;
    return if !_login($c);
    my $trial_id = _id($c->req->param('trial_id')) // return _fail($c, 'No trial given.');
    my $schema = _schema($c);
    my $geo_type = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot_geo_json', 'stock_property');
    if (!$geo_type) {
        $c->stash->{rest} = { plots => [], count => 0 };
        return;
    }
    my $q = "SELECT DISTINCT ON (sp.stock_id) sp.value
        FROM nd_experiment_project nep
        JOIN nd_experiment_stock nes ON (nes.nd_experiment_id = nep.nd_experiment_id)
        JOIN stockprop sp ON (sp.stock_id = nes.stock_id AND sp.type_id = ?)
        WHERE nep.project_id = ?
        ORDER BY sp.stock_id, sp.rank";
    my $h = $schema->storage->dbh->prepare($q);
    $h->execute($geo_type->cvterm_id, $trial_id);
    my @values;
    while (my ($v) = $h->fetchrow_array) { push @values, $v }
    my $geom = _satellite($c)->field_geometry(@values);
    my $out = $geom ? { %$geom, count => scalar @{ $geom->{plots} } } : { plots => [], count => 0 };
    # no plot coordinates: the field drawn for the trial, if any
    if (!$out->{count}) {
        my $ring = try { _fields($c)->trial_field($trial_id) };
        $out->{drawn} = $ring if $ring;
    }
    $out->{can_edit} = _can_edit_trial($c, $trial_id);
    $c->stash->{rest} = $out;
}

=head2 trial_field

POST. Params: trial_id, ring (JSON [[lon, lat], ...]; empty removes the drawn
field). Curator, or submitter in the trial's breeding program.

=cut

sub trial_field :Path('/ajax/satellite/trial_field') Args(0) {
    my ($self, $c) = @_;
    return if !_login($c);
    return _fail($c, 'Use POST to save a trial field.') if $c->req->method ne 'POST';
    my $trial_id = _id($c->req->param('trial_id')) // return _fail($c, 'No trial given.');
    if (!_can_edit_trial($c, $trial_id)) {
        $c->res->status(403);
        return _fail($c, 'You need to be a curator, or a submitter in the breeding program of this trial, to save its field.');
    }
    my $raw = $c->req->param('ring');
    my $ring = _json_param($c, 'ring');
    return _fail($c, 'The field is not valid.') if defined $raw && $raw ne '' && !$ring;
    $c->stash->{rest} = try { _fields($c)->store_trial_field($trial_id, $ring) } catch { +{ error => "$_" } };
}

=head2 location_fields

GET: Param location_id. { fields => [ { name, ring, area_ha } ], can_edit }.
POST: Params location_id, fields (JSON [ { name, ring } ], [] removes all).
Saving needs the submitter or curator role (as editing a location).

=cut

sub location_fields :Path('/ajax/satellite/location_fields') Args(0) {
    my ($self, $c) = @_;
    return if !_login($c);
    my $location_id = _id($c->req->param('location_id')) // return _fail($c, 'No location given.');
    my $fields = _fields($c);
    if ($c->req->method eq 'POST') {
        if (!_can_edit_location($c)) {
            $c->res->status(403);
            return _fail($c, 'You need to be a submitter or a curator to save the fields of a location.');
        }
        my $list = _json_param($c, 'fields');
        return _fail($c, 'The fields are not valid.') if ref $list ne 'ARRAY';
        my $res = try { $fields->store_location_fields($location_id, $list) } catch { +{ error => "$_" } };
        $res->{can_edit} = 1 if !$res->{error};
        $c->stash->{rest} = $res;
        return;
    }
    $c->stash->{rest} = { fields => (try { $fields->location_fields($location_id) } catch { [] }), can_edit => _can_edit_location($c) };
}

=head2 sources

The satellites this server offers: { sources => [ { id, name, res, revisit,
since, paid } ] }.

=cut

sub sources :Path('/ajax/satellite/sources') Args(0) {
    my ($self, $c) = @_;
    return if !_login($c);
    my $sat = _satellite($c);
    foreach my $id ($sat->source_without_search) {
        $c->log->warn("Satellite: a key is set for '$id' in the configuration, but its search is not written yet: not offered.");
    }
    $c->stash->{rest} = { sources => $sat->sources };
}

=head2 scenes

Params: west, south, east, north (degrees), start, end (YYYY-MM-DD),
sources (comma-separated: sentinel2, landsat; default sentinel2).

=cut

sub scenes :Path('/ajax/satellite/scenes') Args(0) {
    my ($self, $c) = @_;
    return if !_login($c);
    my $r = $c->req;
    my $res = _satellite($c)->scenes({
        bbox => [ map { scalar $r->param($_) } qw(west south east north) ],
        start => scalar $r->param('start'),
        end => scalar $r->param('end'),
        sources => [ grep { length } split /\s*,\s*/, scalar($r->param('sources')) // 'sentinel2' ],
    });
    $c->stash->{rest} = $res;
}

=head2 landsat_token

A fresh read token for the Landsat images (they expire after about an hour):
{ token, expiry }.

=cut

sub landsat_token :Path('/ajax/satellite/landsat_token') Args(0) {
    my ($self, $c) = @_;
    return if !_login($c);
    $c->stash->{rest} = _satellite($c)->landsat_token();
}

1;
