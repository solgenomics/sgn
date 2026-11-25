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
  GET /ajax/satellite/crops       species of the accessions (the crop of the models)
  GET /ajax/satellite/trial_info  calibration trials: species, dates, numeric traits
  POST /ajax/satellite/run        start the models (background job)
  GET /ajax/satellite/status      progress of a run
  GET /ajax/satellite/results     results of a finished run
  GET /ajax/satellite/file        a file of a run (map GeoTIFF, csv)
  POST /ajax/satellite/save_indices    store a run's plot indices as phenotypes
  GET /ajax/satellite/runs        the user's earlier model runs
  GET /ajax/satellite/datasets    datasets to calibrate the yield model on
  GET /ajax/satellite/dataset_info     trials and traits of a dataset (>= 8 trials, >= 1 trait)
  GET /ajax/satellite/models      saved trained yield models
  POST /ajax/satellite/save_model save a run's trained model (Breedbase analysis model)
  GET /ajax/satellite/reference   public average yield of the crop around a point (IBGE PAM / FAOSTAT)
  GET /ajax/satellite/sources     the satellites this server offers (never a key)
  GET /ajax/satellite/scenes      satellite scenes of an area and date range
  GET /ajax/satellite/landsat_token  a fresh read token for the Landsat images

Configuration (sgn.conf, all optional):

  satellite_stac_url     https://earth-search.aws.element84.com/v1   (Sentinel-2)
  satellite_landsat_stac_url   https://planetarycomputer.microsoft.com/api/stac/v1
  satellite_landsat_token_url  https://planetarycomputer.microsoft.com/api/sas/v1/token/landsat-c2-l2
  satellite_cores              6   parallel image reads of a model run
  satellite_planet_api_key     (empty)  key of the organisation's Planet account, for
                               PlanetScope 3 m images (paid). Prepared only: PlanetScope is
                               offered once its search is written (see CXGN::Satellite).
  satellite_max_days     731     longest date range of a search
  satellite_regional_statistics  (empty = fao)  public yield statistics used to train
                               models and as the regional reference of the yield index: a
                               comma separated list in order of preference, FAOSTAT always the
                               last fallback: ibge (Brazil, municipalities), nass (USA,
                               counties), eurostat (Europe, NUTS 2), harveststat (Sub-Saharan
                               Africa, admin units), fao (national)
  satellite_nass_api_key       (empty)  USDA NASS Quick Stats key, needed by nass (free,
                               quickstats.nass.usda.gov/api)

=head1 AUTHOR

Chris Simoes

=cut

package SGN::Controller::AJAX::Satellite;

use Moose;
use JSON;
use CXGN::Satellite;
use CXGN::Satellite::Fields;
use CXGN::Satellite::Run;
use CXGN::Satellite::Reference;
use CXGN::Dataset;
use CXGN::AnalysisModel::SaveModel;
use CXGN::AnalysisModel::GetModel;
use CXGN::Job;
use CXGN::Phenotypes::StorePhenotypes;
use File::Path qw(make_path);
use DateTime;
use File::Slurp qw(read_file write_file);
use Encode;
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


# ---------------------------------------------------------------------------
# Models (step 5) and results (step 6)
# ---------------------------------------------------------------------------

sub _work_dir {
    my $c = shift;
    my $dir = ($c->config->{cluster_shared_tempdir} // '/tmp') . '/satellite';
    make_path($dir) if !-d $dir;
    return $dir;
}

# sgn.conf available_seasons ("summer,safrinha"), as TrialAllocation reads it
sub _season_names {
    my $c = shift;
    return grep { /^[A-Za-z][A-Za-z0-9_-]{0,39}$/ } map { s/^\s+|\s+$//gr } split /,/, ($c->config->{available_seasons} // '');
}

# the regional statistics of the site (sgn.conf satellite_regional_statistics: a comma separated list
# of ibge, nass, eurostat, harveststat, fao, in order of preference; FAOSTAT is always the fallback)
sub _stat_providers {
    my $c = shift;
    return [ grep { /^(ibge|nass|eurostat|harveststat|fao)$/ } map { lc s/^\s+|\s+$//gr } split /,/, ($c->config->{satellite_regional_statistics} // '') ];
}

sub _reference {
    my ($c, $timeout) = @_;
    return CXGN::Satellite::Reference->new({ cache_dir => _work_dir($c), timeout => $timeout // 18, providers => _stat_providers($c),
        nass_key => $c->config->{satellite_nass_api_key} });
}

sub _valid_run { my $r = shift // ''; return $r =~ /^sat_\d+_\d+$/ }

sub _meta {
    my ($c, $run_id) = @_;
    my $f = _work_dir($c) . "/$run_id.meta.json";
    return if !-e $f;
    return try { decode_json(read_file($f)) };
}

sub _write_meta {
    my ($c, $run_id, $meta) = @_;
    write_file(_work_dir($c) . "/$run_id.meta.json", encode_json($meta));
}

sub _person_id { my $c = shift; return $c->user ? $c->user->get_object->get_sp_person_id : undef }

# the run of the user asking (or an error already in the stash)
sub _my_run {
    my $c = shift;
    my $run_id = $c->req->param('run_id');
    return _fail($c, 'Invalid run.') if !_valid_run($run_id);
    my $meta = _meta($c, $run_id) or return _fail($c, 'This run does not exist (any more).');
    return _fail($c, 'This run belongs to another user.') if ($meta->{sp_person_id} // -1) != (_person_id($c) // -2);
    return ($run_id, $meta);
}

sub _shell_quote { my $s = shift; $s =~ s/'/'\\''/g; return "'$s'" }

sub _job_args {
    my ($c, %args) = @_;
    return (dbhost => $c->config->{dbhost}, dbname => $c->config->{dbname}, dbuser => $c->config->{dbuser},
            dbpass => $c->config->{dbpass}, basepath => $c->config->{basepath}, %args);
}

# Slurm with no usable node (down / invalid, e.g. after the container was
# recreated) would keep the run queued for ever: then it is started on the web
# server (as the Analysis Pipeline does)
sub _slurm_ready {
    my $c = shift;
    return 1 if lc($c->config->{backend} // '') ne 'slurm';
    my $out = `timeout 5 sinfo -h -o %t 2>/dev/null` // '';
    return scalar(grep { /^\s*(idle|mix|mixed|alloc|allocated|comp|completing)\s*$/ } split /\n/, $out);
}

sub _start_local {
    my ($job, $cmd) = @_;
    my $finish = try { $job->generate_finish_timestamp_cmd() } catch { '' };
    system('setsid nohup bash -c ' . _shell_quote("($cmd$finish)") . ' > /dev/null 2>&1 < /dev/null &');
    $job->update_status('submitted');
}

=head2 crops

{ crops => [ { species, accessions } ], preferred }: the species of the
accessions, most first; preferred is the site's species (sgn.conf
preferred_species), the default crop of the page.

=cut

sub crops :Path('/ajax/satellite/crops') Args(0) {
    my ($self, $c) = @_;
    return if !_login($c);
    my $schema = _schema($c);
    my $h = $schema->storage->dbh->prepare("SELECT o.species, count(*) FROM stock s JOIN public.organism o ON (o.organism_id = s.organism_id)
        WHERE s.type_id = ? AND NOT s.is_obsolete GROUP BY 1 ORDER BY 2 DESC LIMIT 50");
    $h->execute(_type_id($schema, 'accession', 'stock_type'));
    my @crops;
    while (my ($sp, $n) = $h->fetchrow_array) { push @crops, { species => $sp, accessions => $n + 0 } }
    # the site's species (sgn.conf preferred_species) is the default crop
    my $preferred = $c->config->{preferred_species} // '';
    $preferred =~ s/^\s+|\s+$//g;
    push @crops, { species => $preferred, accessions => 0 } if $preferred ne '' && !grep { $_->{species} eq $preferred } @crops;
    # named seasons apply only to the countries of R/satellite/standards/seasons.json (Brazil)
    my $sj = try { decode_json(read_file($c->config->{basepath} . '/R/satellite/standards/seasons.json')) } || {};
    $c->stash->{rest} = { crops => \@crops, preferred => $preferred, seasons => [ _season_names($c) ], season_countries => [ sort keys %{ $sj->{countries} || {} } ] };
}

=head2 trial_info

Param trial_ids (comma separated, at most 200). See CXGN::Satellite::Run trial_info.

=cut

sub trial_info :Path('/ajax/satellite/trial_info') Args(0) {
    my ($self, $c) = @_;
    return if !_login($c);
    my @ids = grep { /^\d+$/ } split /,/, ($c->req->param('trial_ids') // '');
    return _fail($c, 'No trial given.') if !@ids;
    return _fail($c, 'At most 200 trials.') if @ids > 200;
    $c->stash->{rest} = { trials => CXGN::Satellite::Run->new({ schema => _schema($c) })->trial_info(\@ids) };
}

=head2 run

POST. Param request (JSON, see CXGN::Satellite::Run build_request). Starts
bin/satellite_models.pl as a background job: { run_id, job_id, skipped }.

=cut

sub run :Path('/ajax/satellite/run') Args(0) {
    my ($self, $c) = @_;
    return if !_login($c);
    return _fail($c, 'Use POST to start a run.') if $c->req->method ne 'POST';
    my $in = _json_param($c, 'request') or return _fail($c, 'The request is not valid.');
    my $schema = _schema($c);
    my $y = ref $in->{yield} eq 'HASH' ? $in->{yield} : {};
    # calibration from a dataset: its trials (>= 8) and the chosen trait (one of its traits)
    if (($in->{calibration_dataset_id} // '') =~ /^\d+$/ && ($y->{mode} // '') ne 'index' && ($y->{mode} // '') ne 'saved') {
        my ($ds, $err) = _dataset($c, $in->{calibration_dataset_id});
        return _fail($c, $err) if $err;
        my @trials = map { $_->[0] } @{ $ds->retrieve_trials() || [] };
        my %traits = map { $_->[0] => $_->[1] } @{ $ds->retrieve_traits() || [] };
        return _fail($c, 'The dataset "' . $ds->name . '" has ' . scalar(@trials) . ' trial(s); calibrating needs at least 8.') if @trials < 8;
        return _fail($c, 'The dataset "' . $ds->name . '" has no trait.') if !%traits;
        return _fail($c, 'Choose the trait of the dataset to train on.') if ($y->{trait_id} // '') !~ /^\d+$/ || !$traits{ $y->{trait_id} };
        $y->{trait_name} //= $traits{ $y->{trait_id} };
        my %seen;
        $in->{calibration_trials} = [ grep { !$seen{$_}++ } @trials, grep { /^\d+$/ } @{ $in->{calibration_trials} || [] } ];
        $in->{calibration_dataset} = { id => $ds->sp_dataset_id, name => $ds->name };
    }
    # a saved trained model: the user's own or a public one, and its file
    if (($y->{mode} // '') eq 'saved') {
        my $mid = ($y->{saved_model_id} // '') =~ /^\d+$/ ? $y->{saved_model_id} : return _fail($c, 'Choose a saved model.');
        my $m = _satellite_models($c)->{$mid} or return _fail($c, 'This saved model does not exist or is not yours.');
        my $file = $m->{model_files}{satellite_yield_model_rds} or return _fail($c, 'The saved model has no model file.');
        $y->{saved_model} = { id => $mid + 0, name => $m->{model_name}, file => $file };
        my $p = $m->{model_properties} || {};
        $y->{trait_name} = $p->{trait} // ''; $y->{unit} = $p->{unit} // ''; $y->{per_ha} = $p->{per_ha} ? 1 : 0;
    }
    $in->{yield} = $y if $in->{yield};
    my ($req, $err) = try { CXGN::Satellite::Run->new({ schema => $schema })->build_request($in) } catch { (undef, "$_") };
    return _fail($c, $err) if $err;
    $req->{settings}{cores} = ($c->config->{satellite_cores} // '') =~ /^\d+$/ ? $c->config->{satellite_cores} + 0 : 6;
    # the site's crop seasons (sgn.conf available_seasons): names of the seasons found, split of long periods
    $req->{season_names} = [ _season_names($c) ];
    $req->{stac_url} = $c->config->{satellite_stac_url} if $c->config->{satellite_stac_url};
    $req->{statistics} = { providers => _stat_providers($c), nass_key => $c->config->{satellite_nass_api_key} };

    my @names = map { $_->{name} } @{ $req->{sites} };
    my $label = join(' + ', grep { $req->{models}{$_} } qw(crop_map yield indices));
    $label =~ s/crop_map/crop map/; $label =~ s/indices/plot indices/;
    _launch($c, $req, { model_used => (($req->{yield} || {})->{saved_model} || {})->{name}, name => "Satellite $label: " . join(', ', @names[0 .. ($#names > 2 ? 2 : $#names)]) . (@names > 3 ? ' ...' : ''),
                        sites => [ map { { id => $_->{id}, name => $_->{name} } } @{ $req->{sites} } ] });
}

# writes the request, starts bin/satellite_models.pl as a job (Slurm, or here when no node
# can take it), with the email at the end when asked; { run_id, job_id, skipped, notify }
sub _launch {
    my ($c, $req, $extra) = @_;
    my $schema = _schema($c);
    my $dir = _work_dir($c);
    my $run_id = sprintf('sat_%d_%06d', time(), int(rand(1_000_000)));
    my $base = "$dir/$run_id";
    write_file("$base.request.json", encode_json($req));
    my $basepath = $c->config->{basepath};
    my $cmd = join(' ', 'perl', '-I' . _shell_quote("$basepath/lib"), _shell_quote("$basepath/bin/satellite_models.pl"), _shell_quote($base))
        . ' > ' . _shell_quote("$base.log") . ' 2>&1';
    # email when the run ends (address from the account, never from the request)
    my ($notify_email, $site_url);
    if ($c->req->param('notify')) {
        my $person = $c->user->get_object;
        my $email = $person->get_contact_email() || $person->get_private_email();
        if ($email && $email =~ /^[^\s@]+@[^\s@]+$/) {
            ($site_url = $c->req->base . '') =~ s{/+$}{};
            $notify_email = $email;
            $cmd .= '; perl -I' . _shell_quote("$basepath/lib") . ' ' . _shell_quote("$basepath/bin/satellite_notify.pl") . ' ' . _shell_quote($base)
                . ' >> ' . _shell_quote("$base.log") . ' 2>&1';
        }
    }
    my %meta = (sp_person_id => _person_id($c), created => time(), cmd => $cmd, models => $req->{models},
                dates => $req->{dates}, notify_email => $notify_email, site_url => $site_url, kind => ($req->{train} ? 'train' : 'analysis'), %$extra);
    my $job;
    try {
        $job = CXGN::Job->new({ _job_args($c,
            schema => $schema, people_schema => $c->dbic_schema('CXGN::People::Schema', undef, _person_id($c)),
            sp_person_id => _person_id($c), name => $meta{name}, job_type => 'satellite_analysis', cmd => $cmd,
            results_page => ($req->{train} ? "/breeders/satellite/train?run=$run_id" : "/breeders/satellite?run=$run_id"),
            cxgn_tools_run_config => { backend => $c->config->{backend}, submit_host => $c->config->{cluster_host}, temp_base => $dir,
                                       queue => $c->config->{web_cluster_queue}, do_cleanup => 0, max_cluster_jobs => 1_000_000_000 },
        ) });
        if (_slurm_ready($c)) { $job->submit() }
        else {
            print STDERR "Satellite: no Slurm node available, starting run $run_id on the web server\n";
            $job->store();
            _start_local($job, $cmd);
            $meta{started_locally} = 1;
        }
    } catch {
        $c->stash->{rest} = { error => "Could not start the run: $_" };
    };
    return if $c->stash->{rest};
    $meta{job_id} = $job->sp_job_id();
    _write_meta($c, $run_id, \%meta);
    $c->stash->{rest} = { run_id => $run_id, job_id => $meta{job_id}, skipped => $req->{calibration_skipped}, notify => ($notify_email ? $notify_email =~ s/^(.).*(@.*)$/$1***$2/r : '') };
}

=head2 status

Param run_id. { status => running | done | failed, progress, error, seconds }.

=cut

sub status :Path('/ajax/satellite/status') Args(0) {
    my ($self, $c) = @_;
    return if !_login($c);
    my ($run_id, $meta) = _my_run($c) or return;
    my $base = _work_dir($c) . "/$run_id";
    # the log is UTF-8 (R and the runner print place names)
    my @log = -e "$base.log" ? map { Encode::decode('UTF-8', $_) } read_file("$base.log") : ();
    # still queued and no node can take it: start it here
    if (!@log && !$meta->{started_locally} && $meta->{cmd} && !_slurm_ready($c) && time() - ($meta->{created} // time()) > 5) {
        try {
            my $job = CXGN::Job->new({ _job_args($c, schema => _schema($c), people_schema => $c->dbic_schema('CXGN::People::Schema', undef, _person_id($c)), sp_job_id => $meta->{job_id}) });
            try { $job->cancel() };
            _start_local($job, $meta->{cmd});
            $meta->{started_locally} = 1;
            _write_meta($c, $run_id, $meta);
        } catch { print STDERR "Satellite: could not start run $run_id locally: $_" };
    }
    my @lines = map { my $l = $_; $l =~ s/^\[satellite\]\s*//; chomp $l; $l } grep { /^\[satellite\]/ } @log;
    my $progress = @lines ? $lines[-1] : (@log ? '' : 'Waiting in the job queue');
    $progress =~ s/^\d\d:\d\d:\d\d\s+//;
    my @recent = @lines > 60 ? @lines[-60 .. -1] : @lines;
    my $seconds = time() - ($meta->{created} // time());
    my $exit = -e "$base.exit" ? read_file("$base.exit") : undef;
    if (!defined $exit) {
        $c->stash->{rest} = { status => 'running', progress => $progress, seconds => $seconds, log => \@recent, log_lines => scalar @lines, notify => ($meta->{notify_email} ? 1 : 0) };
        return;
    }
    chomp $exit;
    if ($exit eq '0' && -e "$base.results.json") {
        $c->stash->{rest} = { status => 'done', seconds => $seconds, log => \@recent };
        return;
    }
    my @err = grep { /^Error|error in:|^\s{4}\S|Execution halted|failed/ } @log;
    my $msg = join('', @err[ ($#err > 8 ? $#err - 8 : 0) .. $#err ]) || "The run ended (code $exit) without results.";
    $msg = 'The run was stopped by the system (probably out of memory: try a smaller area or a shorter period).' if $exit =~ /^(137|9)$/;
    $c->stash->{rest} = { status => 'failed', error => $msg, progress => $progress, seconds => $seconds, log => \@recent };
}

=head2 results

Param run_id. The results of R/satellite/satellite_models.R plus the run name
and sites; csv / map files are given as names for /ajax/satellite/file.

=cut

sub results :Path('/ajax/satellite/results') Args(0) {
    my ($self, $c) = @_;
    return if !_login($c);
    my ($run_id, $meta) = _my_run($c) or return;
    my $f = _work_dir($c) . "/$run_id.results.json";
    return _fail($c, 'The run has no results (yet).') if !-e $f;
    my $res = try { decode_json(read_file($f)) } or return _fail($c, 'The results cannot be read.');
    $res->{run_id} = $run_id;
    $res->{name} = $meta->{name};
    $res->{saved_indices} = $meta->{saved_indices} || {};
    $res->{saved_model_entry} = $meta->{saved_model} if $meta->{saved_model};
    $res->{can_save_model} = -e _work_dir($c) . "/$run_id.model.rds" ? 1 : 0;
    $c->stash->{rest} = $res;
}

=head2 file

Params run_id, name (fields.csv, indices.csv, siteN.map.tif). The file as a download.

=cut

sub file :Path('/ajax/satellite/file') Args(0) {
    my ($self, $c) = @_;
    return if !_login($c);
    my ($run_id, $meta) = _my_run($c) or return;
    my $name = $c->req->param('name') // '';
    return _fail($c, 'Unknown file.') if $name !~ /^(fields\.csv|indices\.csv|site\d{1,2}\.map\.tif|log)$/;
    my $path = _work_dir($c) . "/$run_id.$name";
    return _fail($c, 'This file does not exist.') if !-e $path;
    my $type = $name =~ /\.csv$/ ? 'text/csv' : $name eq 'log' ? 'text/plain' : 'image/tiff';
    $name .= '.txt' if $name eq 'log';
    $c->res->content_type($type);
    $c->res->header('Content-Disposition', qq{attachment; filename="$run_id.$name"});
    $c->res->header('Content-Type', $type);
    $c->res->body(scalar read_file($path, binmode => ':raw'));
    $c->stash->{rest} = undef;
    $c->detach();
}

=head2 save_indices

POST. Params run_id, trial_id. Stores the run's NDVI / NDRE / EVI of the
trial's plots as the satellite time-series traits (one value per image date),
for a curator or a submitter in the trial's breeding program. Values already
stored for the same plot, trait and date are kept.

=cut

sub save_indices :Path('/ajax/satellite/save_indices') Args(0) {
    my ($self, $c) = @_;
    return if !_login($c);
    return _fail($c, 'Use POST to save.') if $c->req->method ne 'POST';
    my ($run_id, $meta) = _my_run($c) or return;
    my $trial_id = _id($c->req->param('trial_id')) // return _fail($c, 'No trial given.');
    if (!_can_edit_trial($c, $trial_id)) {
        $c->res->status(403);
        return _fail($c, 'You need to be a curator, or a submitter in the breeding program of this trial, to store its phenotypes.');
    }
    my $csv = _work_dir($c) . "/$run_id.indices.csv";
    return _fail($c, 'This run has no plot indices.') if !-e $csv;
    my $schema = _schema($c);
    my %trait = map {
        my $row = $schema->resultset('Cv::Cvterm')->search({ 'me.name' => "satellite $_", 'db.name' => 'SATIDX' }, { join => { dbxref => 'db' }, prefetch => { dbxref => 'db' } })->first;
        $row ? (lc($_) => $row->name . '|SATIDX:' . $row->dbxref->accession) : ()
    } qw(NDVI NDRE EVI);
    return _fail($c, 'The satellite traits are missing: run the db patch AddSatelliteTerms.') if keys %trait < 3;
    my @lines = read_file($csv);
    my $head = shift @lines;
    $head =~ s/["\r\n]//g;
    my @cols = split /,/, $head;
    my %ix = map { $cols[$_] => $_ } 0 .. $#cols;
    my (%values, %plots);
    my $n = 0;
    foreach my $l (@lines) {
        $l =~ s/[\r\n]//g;
        my @v = map { s/^"|"$//gr } split /,(?=(?:[^"]*"[^"]*")*[^"]*$)/, $l;
        next if ($v[$ix{trial_id}] // '') ne $trial_id;
        my $plot = $v[$ix{plot_name}];
        my $date = $v[$ix{date}];
        next if !$plot || $date !~ /^\d{4}-\d\d-\d\d$/;
        foreach my $k (qw(ndvi ndre evi)) {
            my $x = $v[$ix{$k}];
            next if !defined $x || $x !~ /^-?\d+(\.\d+)?([eE][-+]?\d+)?$/;
            push @{ $values{$plot}{ $trait{$k} } }, [ sprintf('%.4f', $x), "$date 00:00:00" ];
            $plots{$plot} = 1;
            $n++;
        }
    }
    return _fail($c, 'This run has no index of this trial.') if !$n;
    my $user_id = _person_id($c);
    $c->tempfiles_subdir('/delete_nd_experiment_ids');
    my $tmp = $c->config->{basepath} . '/' . $c->tempfile(TEMPLATE => 'delete_nd_experiment_ids/fileXXXX');
    my $store = CXGN::Phenotypes::StorePhenotypes->new(
        basepath => $c->config->{basepath}, dbhost => $c->config->{dbhost}, dbname => $c->config->{dbname},
        dbuser => $c->config->{dbuser}, dbpass => $c->config->{dbpass}, temp_file_nd_experiment_id => $tmp,
        bcs_schema => $schema, metadata_schema => $c->dbic_schema('CXGN::Metadata::Schema'),
        phenome_schema => $c->dbic_schema('CXGN::Phenome::Schema'), user_id => $user_id,
        stock_list => [ sort keys %plots ], trait_list => [ sort values %trait ], values_hash => \%values,
        has_timestamps => 1, overwrite_values => 0,
        metadata_hash => { archived_file => 'none', archived_file_type => 'satellite indices (Sentinel-2)', operator => $user_id,
                           date => DateTime->now->strftime('%Y-%m-%d_%H:%M:%S') },
        composable_validation_check_name => $c->config->{composable_validation_check_name},
    );
    my ($verify_error, $verify_warning) = $store->verify();
    return _fail($c, "The values could not be stored: $verify_error") if $verify_error;
    my ($store_error, $store_success) = $store->store();
    return _fail($c, "The values could not be stored: $store_error") if $store_error;
    $meta->{saved_indices}{$trial_id} = { values => $n, plots => scalar keys %plots, by => $user_id, at => time() };
    _write_meta($c, $run_id, $meta);
    $c->stash->{rest} = { success => 1, values => $n, plots => scalar keys %plots };
}

=head2 reference

Params lon, lat, species, country, year. The public average yield used to
turn the yield index into approximate kg/ha (CXGN::Satellite::Reference);
never downloads FAOSTAT here ({ pending => 1 }: it is fetched by the run).

=cut

sub reference :Path('/ajax/satellite/reference') Args(0) {
    my ($self, $c) = @_;
    return if !_login($c);
    my $r = $c->req;
    my ($lon, $lat) = map { scalar $r->param($_) } qw(lon lat);
    return _fail($c, 'No coordinates.') if ($lon // '') !~ /^-?\d+(\.\d+)?$/ || ($lat // '') !~ /^-?\d+(\.\d+)?$/;
    my $year = ($r->param('year') // '') =~ /^(\d{4})$/ ? $1 : undef;
    my $res = try {
        _reference($c, 12)->lookup({
            lon => $lon + 0, lat => $lat + 0, species => scalar $r->param('species'), country => scalar $r->param('country'), year => $year, no_download => 1 })
    } catch { +{ error => "$_" } };
    $c->stash->{rest} = $res;
}

=head2 runs

The user's earlier model runs, newest first (at most 40): { runs => [ { run_id,
name, created, status (done / failed / running), dates } ] }.

=cut

sub runs :Path('/ajax/satellite/runs') Args(0) {
    my ($self, $c) = @_;
    return if !_login($c);
    my $me = _person_id($c) // -1;
    my $dir = _work_dir($c);
    my @out;
    opendir(my $dh, $dir) or return _fail($c, 'Cannot read the runs.');
    my @metas = grep { /^sat_\d+_\d+\.meta\.json$/ } readdir($dh);
    closedir($dh);
    foreach my $f (@metas) {
        my $m = try { decode_json(read_file("$dir/$f")) } or next;
        next if ($m->{sp_person_id} // -2) != $me;
        (my $run_id = $f) =~ s/\.meta\.json$//;
        my $exit = -e "$dir/$run_id.exit" ? read_file("$dir/$run_id.exit") : undef;
        my $status = !defined $exit ? 'running' : ($exit =~ /^\s*0\s*$/ && -e "$dir/$run_id.results.json") ? 'done' : 'failed';
        $status = 'failed' if $status eq 'running' && time() - ($m->{created} // 0) > 6 * 3600;    # lost (server restarted)
        # the trained model of the run: the one it used, or the one saved from it
        my $used = $m->{model_used};
        if (!defined $used && -e "$dir/$run_id.request.json") {
            my $rq = try { decode_json(read_file("$dir/$run_id.request.json")) } || {};
            $used = (($rq->{yield} || {})->{saved_model} || {})->{name};
        }
        push @out, { run_id => $run_id, name => $m->{name}, created => $m->{created}, status => $status, dates => $m->{dates}, kind => ($m->{kind} // 'analysis'),
                     model_used => $used, model_saved => ($m->{saved_model} ? $m->{saved_model}{name} : undef) };
    }
    @out = sort { ($b->{created} // 0) <=> ($a->{created} // 0) } @out;
    splice(@out, 40) if @out > 40;
    $c->stash->{rest} = { runs => \@out };
}

# ---------------------------------------------------------------------------
# Calibration datasets and saved trained models
# ---------------------------------------------------------------------------

# a dataset the user may use: own or public
sub _dataset {
    my ($c, $id) = @_;
    my $people = $c->dbic_schema('CXGN::People::Schema', undef, _person_id($c));
    my $ds = try { CXGN::Dataset->new({ schema => _schema($c), people_schema => $people, sp_dataset_id => $id }) };
    return (undef, 'This dataset does not exist.') if !$ds;
    return (undef, 'This dataset is private to another user.') if ($ds->sp_person_id // -1) != (_person_id($c) // -2) && !$ds->is_public;
    return ($ds, undef);
}

# the user's saved satellite yield models: { id => { model_name, model_description, model_properties, model_files } }
sub _satellite_models {
    my $c = shift;
    return try { CXGN::AnalysisModel::GetModel::get_models_by_user(_schema($c), _person_id($c), 'satellite_yield_model') } || {};
}

=head2 datasets

{ datasets => [ { id, name, description, owner, mine, public } ] }: the user's
datasets and the public ones (to calibrate the yield model).

=cut

sub datasets :Path('/ajax/satellite/datasets') Args(0) {
    my ($self, $c) = @_;
    return if !_login($c);
    my $me = _person_id($c);
    my $list = try { CXGN::Dataset->get_datasets_by_user($c->dbic_schema('CXGN::People::Schema', undef, $me), $me) } || [];
    my @out = map { { id => $_->[0] + 0, name => $_->[1], description => $_->[2], owner => $_->[3]{owner_name}, mine => (($_->[3]{owner_id} // -1) == $me ? 1 : 0), public => ($_->[4] ? 1 : 0) } } @$list;
    @out = sort { $b->{mine} <=> $a->{mine} || lc($a->{name} // '') cmp lc($b->{name} // '') } @out;
    $c->stash->{rest} = { datasets => \@out };
}

=head2 dataset_info

Param dataset_id. { id, name, trials => [ { id, name } ], traits => [ { id, name } ],
ok, problems => [...] }: calibrating needs at least 8 trials and 1 trait.

=cut

sub dataset_info :Path('/ajax/satellite/dataset_info') Args(0) {
    my ($self, $c) = @_;
    return if !_login($c);
    my $id = _id($c->req->param('dataset_id')) // return _fail($c, 'No dataset given.');
    my ($ds, $err) = _dataset($c, $id);
    return _fail($c, $err) if $err;
    my @trials = map { { id => $_->[0] + 0, name => $_->[1] } } @{ (try { $ds->retrieve_trials() }) || [] };
    my @traits = map { { id => $_->[0] + 0, name => $_->[1] } } @{ (try { $ds->retrieve_traits() }) || [] };
    my @problems;
    push @problems, 'it has ' . scalar(@trials) . ' trial(s); at least 8 are needed' if @trials < 8;
    push @problems, 'it has no trait' if !@traits;
    # where each trial's field comes from (plots, drawn, or only its location's coordinates)
    my $fields = $c->req->param('fields') && @trials <= 400
        ? try { CXGN::Satellite::Run->new({ schema => _schema($c) })->field_sources([ map { $_->{id} } @trials ]) } : undef;
    $c->stash->{rest} = { id => $id + 0, name => $ds->name, trials => \@trials, traits => \@traits, ok => (@problems ? 0 : 1), problems => \@problems,
                          outliers => scalar(@{ $ds->outliers() || [] }),
                          ($fields ? (fields => $fields) : ()) };
}

=head2 models

{ models => [ { id, name, description, properties } ] }: the user's saved
satellite yield models.

=cut

sub models :Path('/ajax/satellite/models') Args(0) {
    my ($self, $c) = @_;
    return if !_login($c);
    my $all = _satellite_models($c);
    my @out = map { { id => $_ + 0, name => $all->{$_}{model_name}, description => $all->{$_}{model_description}, properties => $all->{$_}{model_properties} } } keys %$all;
    @out = sort { $b->{id} <=> $a->{id} } @out;
    $c->stash->{rest} = { models => \@out };
}

# ---------------------------------------------------------------------------
# Training a yield model (/breeders/satellite/train)
# ---------------------------------------------------------------------------

=head2 train_regions

Params species, ufs (comma separated IBGE state codes), years (comma
separated). Without ufs: { states => [ { code, uf, name } ] }. Otherwise the
IBGE PAM yields of the municipalities of those states (see
CXGN::Satellite::Reference regional_yields).

=cut

sub train_regions :Path('/ajax/satellite/train_regions') Args(0) {
    my ($self, $c) = @_;
    return if !_login($c);
    my $ref = _reference($c);
    my $providers = $ref->provider_list;
    my $p = $c->req->param('provider') // '';
    my ($prov) = grep { $_->{id} eq $p } @$providers;
    ($prov) = grep { $_->{available} } @$providers if !$prov;
    return _fail($c, $prov->{why} ? "$prov->{label}: $prov->{why}" : 'Unknown source.') if !$prov || !$prov->{available};
    # large files (HarvestStat, FAOSTAT, NUTS boundaries): downloaded in the background the first time
    if (!$ref->ready($prov->{id})) {
        my $lib = $c->config->{basepath} . '/lib';
        my $code = 'use CXGN::Satellite::Reference; CXGN::Satellite::Reference->new({ cache_dir => $ARGV[0], timeout => 600 })->prepare($ARGV[1])';
        my $flag = _work_dir($c) . "/reference/preparing_$prov->{id}";
        if (!-e $flag || -M $flag > 0.02) {
            make_path(_work_dir($c) . '/reference');
            write_file($flag, time());
            my $cmd = 'perl -I' . _shell_quote($lib) . ' -e ' . _shell_quote($code) . ' ' . _shell_quote(_work_dir($c)) . ' ' . _shell_quote($prov->{id})
                . '; rm -f ' . _shell_quote($flag);
            system('setsid nohup sh -c ' . _shell_quote($cmd) . ' > /dev/null 2>&1 < /dev/null &');
        }
        $c->stash->{rest} = { providers => $providers, provider => $prov->{id}, pending => 1,
            message => "Downloading the $prov->{label} data the first time (a few minutes); try again shortly." };
        return;
    }
    my @units = grep { /^[A-Za-z0-9]{1,6}$/ } split /,/, ($c->req->param('units') // $c->req->param('ufs') // '');
    if (!@units) {
        my $list = try { $ref->units($prov->{id}) } catch { $c->stash->{rest} = { error => "$prov->{label}: $_" }; undef } or return;
        $c->stash->{rest} = { providers => $providers, provider => $prov->{id}, units => $list, states => $list };
        return;
    }
    my @years = grep { /^\d{4}$/ } split /,/, ($c->req->param('years') // '');
    my $max = $prov->{units_max} // 6;
    return _fail($c, "At most $max at a time.") if @units > $max;
    return _fail($c, 'At most 8 years.') if @years > 8;
    my $res = try { $ref->regional_yields({ provider => $prov->{id}, species => scalar $c->req->param('species'), units => \@units, years => \@years }) } catch { +{ error => "$_" } };
    $c->stash->{rest} = $res;
}

=head2 train_run

POST. Param request (JSON): { crop, trait_name, unit, per_ha, settings,
regions => { ufs, years, keys => [ "mun_code|year|season" ] },
dataset_id, trait_id }. The municipalities' yields are read again from IBGE
here (never taken from the page); the dataset gives the trials. Starts the
training job: { run_id, job_id, skipped, notify }.

=cut

sub train_run :Path('/ajax/satellite/train_run') Args(0) {
    my ($self, $c) = @_;
    return if !_login($c);
    return _fail($c, 'Use POST to start a run.') if $c->req->method ne 'POST';
    my $in = _json_param($c, 'request') or return _fail($c, 'The request is not valid.');
    my $ref = _reference($c);
    my $r = ref $in->{regions} eq 'HASH' ? $in->{regions} : {};
    my %want = map { $_ => 1 } grep { /^[A-Za-z0-9]{1,12}\|\d{4}\|[a-z0-9_]{1,40}$/ } @{ ref $r->{keys} eq 'ARRAY' ? $r->{keys} : [] };
    my @rows;
    if (%want) {
        my ($prov) = grep { $_->{id} eq ($r->{provider} // 'ibge') && $_->{available} } @{ $ref->provider_list };
        return _fail($c, 'This source of regional statistics is not set up on this site.') if !$prov;
        my $res = try { $ref->regional_yields({ provider => $prov->{id}, species => $in->{crop}, units => $r->{units} || $r->{ufs}, years => $r->{years} }) } catch { +{ error => "$_" } };
        return _fail($c, $res->{error}) if $res->{error};
        @rows = grep { $want{"$_->{code}|$_->{year}|$_->{season}"} } @{ $res->{rows} };
        $in->{trait_name} = "Grain yield, $prov->{label} regional average" if !$in->{dataset_id};
        $in->{unit} = 'kg/ha';
        $in->{region_provider} = $prov->{id};
        $in->{region_provider_label} = $prov->{label};
    }
    $in->{region_rows} = \@rows;
    if (($in->{dataset_id} // '') =~ /^\d+$/) {
        my ($ds, $err) = _dataset($c, $in->{dataset_id});
        return _fail($c, $err) if $err;
        my @trials = map { $_->[0] } @{ $ds->retrieve_trials() || [] };
        my %traits = map { $_->[0] => $_->[1] } @{ $ds->retrieve_traits() || [] };
        return _fail($c, 'The dataset "' . $ds->name . '" has ' . scalar(@trials) . ' trial(s); training needs at least 8.') if @trials < 8;
        return _fail($c, 'Choose the trait of the dataset to train on.') if ($in->{trait_id} // '') !~ /^\d+$/ || !$traits{ $in->{trait_id} };
        $in->{trait_name} = $traits{ $in->{trait_id} } if !@rows;
        $in->{calibration_trials} = \@trials;
        # outliers: removed (only when every trial is validated for the trait in Phenotype Quality Control) or kept
        return _fail($c, 'Choose to remove the outliers or to continue with the values as they are.') if ($in->{outliers} // '') !~ /^(remove|keep)$/;
        if ($in->{outliers} eq 'remove') {
            my $run = CXGN::Satellite::Run->new({ schema => _schema($c) });
            (my $short = $traits{ $in->{trait_id} }) =~ s/\|.*//;
            my @not = grep { my $t = $_; !grep { $_ eq $short } @{ $run->validated_traits($t) } } @trials;
            return _fail($c, scalar(@not) . ' trial(s) of the dataset are not validated for this trait: validate them in Phenotype Quality Control (/tools/qualitycontrol) to remove the outliers, or continue with the values as they are.') if @not;
        }
        $in->{dataset_outliers} = $ds->outliers() || [];
    }
    my ($req, $err) = try { CXGN::Satellite::Run->new({ schema => _schema($c) })->build_training_request($in, $ref) } catch { (undef, "$_") };
    return _fail($c, $err) if $err;
    $req->{settings}{cores} = ($c->config->{satellite_cores} // '') =~ /^\d+$/ ? $c->config->{satellite_cores} + 0 : 6;
    $req->{season_names} = [ _season_names($c) ];
    $req->{stac_url} = $c->config->{satellite_stac_url} if $c->config->{satellite_stac_url};
    my $n_reg = grep { ($_->{kind} // '') eq 'region' } @{ $req->{calibration} };
    my $n_tri = @{ $req->{calibration} } - $n_reg;
    my $name = substr($in->{name} // '', 0, 120);
    # the model name given on the page (the saved model takes it too)
    $name = 'Yield model: ' . join(' + ', ($n_reg ? "$n_reg municipality-seasons (IBGE)" : ()), ($n_tri ? "$n_tri trials" : ())) if $name !~ /\S/;
    _launch($c, $req, { name => $name, sites => [] });
}

=head2 save_model

POST. Params run_id, name, description. Saves the run's trained yield model
(<run>.model.rds, with its calibration fields as training data) as a Breedbase
analysis model of type satellite_yield_model.

=cut

sub save_model :Path('/ajax/satellite/save_model') Args(0) {
    my ($self, $c) = @_;
    return if !_login($c);
    return _fail($c, 'Use POST to save.') if $c->req->method ne 'POST';
    my ($run_id, $meta) = _my_run($c) or return;
    my $name = $c->req->param('name') // '';
    $name =~ s/^\s+|\s+$//g;
    return _fail($c, 'Give the model a name.') if $name eq '' || length($name) > 200;
    my $base = _work_dir($c) . "/$run_id";
    return _fail($c, 'This run has no trained model (it needs a calibrated yield).') if !-e "$base.model.rds";
    my $res = try { decode_json(read_file("$base.results.json")) } || {};
    my $y = $res->{yield} || {};
    # training data: the calibration fields of the run
    my @cal = grep { $_->{used} } @{ $y->{calibration} || [] };
    my $csv = "name,source,observed,season_start,season_end,clear_dates,ndvi_auc,ndvi_max,ndre_max,peak_day\n"
        . join('', map { my $r = $_; join(',', map { my $v = $r->{$_} // ''; $v =~ s/[",\n]/ /g; $v } qw(name source observed start end n_dates ndvi_auc ndvi_max ndre_max peak_day)) . "\n" } @cal);
    write_file("$base.training.csv", $csv);
    my $user_id = _person_id($c);
    my $role = $c->user->check_roles('curator') ? 'curator' : $c->user->check_roles('submitter') ? 'submitter' : 'user';
    my $schema = _schema($c);
    my $type = SGN::Model::Cvterm->get_cvterm_row($schema, 'satellite_yield_model', 'protocol_type') or return _fail($c, 'The model type is missing: run the db patch AddSatelliteTerms.');
    my %props = (crop => $res->{crop}, trait => $y->{trait}, unit => $y->{unit}, per_ha => ($y->{per_ha} ? 1 : 0), model => $y->{model},
                 predictors => $y->{predictors}, metrics => $y->{metrics}, season_mode => $y->{season_mode}, run_id => $run_id,
                 dates => $res->{dates}, calibration_fields => scalar @cal, method => 'Sentinel-2 season curve features (Breedbase satellite page)');
    my $archive = $c->config->{archive_path};
    my ($metadata, $phenome) = ($c->dbic_schema('CXGN::Metadata::Schema'), $c->dbic_schema('CXGN::Phenome::Schema'));
    my $saved = try {
        CXGN::AnalysisModel::SaveModel->new({ bcs_schema => $schema, metadata_schema => $metadata, phenome_schema => $phenome, archive_path => $archive,
            model_name => $name, model_description => scalar($c->req->param('description')) // '', model_language => 'R',
            model_type_cvterm_id => $type->cvterm_id, model_properties => \%props, application_name => 'Breedbase satellite', application_version => '1',
            is_public => 0, user_id => $user_id, user_role => $role })->save_model();
    } catch { +{ error => "$_" } };
    return _fail($c, $saved->{error}) if $saved->{error};
    my $stored = try {
        CXGN::AnalysisModel::GetModel->new({ bcs_schema => $schema, metadata_schema => $metadata, phenome_schema => $phenome, nd_protocol_id => $saved->{nd_protocol_id} })
            ->store_analysis_model_files({ archived_model_file_type => 'satellite_yield_model_rds', model_file => "$base.model.rds",
                archived_training_data_file_type => 'satellite_yield_model_training_data', archived_training_data_file => "$base.training.csv",
                archived_auxiliary_files => [], archive_path => $archive, user_id => $user_id, user_role => $role });
    } catch { +{ error => "$_" } };
    return _fail($c, "The model was created but its files could not be stored: $stored->{error}") if ref $stored eq 'HASH' && $stored->{error};
    $meta->{saved_model} = { id => $saved->{nd_protocol_id}, name => $name };
    _write_meta($c, $run_id, $meta);
    $c->stash->{rest} = { success => 1, model_id => $saved->{nd_protocol_id}, name => $name };
}

1;
