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
use CXGN::Job;
use CXGN::Phenotypes::StorePhenotypes;
use File::Path qw(make_path);
use DateTime;
use File::Slurp qw(read_file write_file);
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

{ crops => [ { species, accessions } ] }: the species of the accessions, most first.

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
    $c->stash->{rest} = { crops => \@crops };
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
    my ($req, $err) = try { CXGN::Satellite::Run->new({ schema => $schema })->build_request($in) } catch { (undef, "$_") };
    return _fail($c, $err) if $err;
    $req->{settings}{cores} = ($c->config->{satellite_cores} // '') =~ /^\d+$/ ? $c->config->{satellite_cores} + 0 : 6;
    $req->{stac_url} = $c->config->{satellite_stac_url} if $c->config->{satellite_stac_url};

    my $dir = _work_dir($c);
    my $run_id = sprintf('sat_%d_%06d', time(), int(rand(1_000_000)));
    my $base = "$dir/$run_id";
    write_file("$base.request.json", encode_json($req));
    my $basepath = $c->config->{basepath};
    my $cmd = join(' ', 'perl', '-I' . _shell_quote("$basepath/lib"), _shell_quote("$basepath/bin/satellite_models.pl"), _shell_quote($base))
        . ' > ' . _shell_quote("$base.log") . ' 2>&1';
    my @names = map { $_->{name} } @{ $req->{sites} };
    my $label = join(' + ', grep { $req->{models}{$_} } qw(crop_map yield indices));
    $label =~ s/crop_map/crop map/; $label =~ s/indices/plot indices/;
    my %meta = (sp_person_id => _person_id($c), created => time(), cmd => $cmd, name => "Satellite $label: " . join(', ', @names[0 .. ($#names > 2 ? 2 : $#names)]) . (@names > 3 ? ' ...' : ''),
                models => $req->{models}, sites => [ map { { id => $_->{id}, name => $_->{name} } } @{ $req->{sites} } ]);
    my $job;
    try {
        $job = CXGN::Job->new({ _job_args($c,
            schema => $schema, people_schema => $c->dbic_schema('CXGN::People::Schema', undef, _person_id($c)),
            sp_person_id => _person_id($c), name => $meta{name}, job_type => 'satellite_analysis', cmd => $cmd,
            results_page => "/breeders/satellite?run=$run_id",
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
    $c->stash->{rest} = { run_id => $run_id, job_id => $meta{job_id}, skipped => $req->{calibration_skipped} };
}

=head2 status

Param run_id. { status => running | done | failed, progress, error, seconds }.

=cut

sub status :Path('/ajax/satellite/status') Args(0) {
    my ($self, $c) = @_;
    return if !_login($c);
    my ($run_id, $meta) = _my_run($c) or return;
    my $base = _work_dir($c) . "/$run_id";
    my @log = -e "$base.log" ? read_file("$base.log") : ();
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
    my ($progress) = reverse grep { /^\[satellite\]/ } @log;
    $progress //= @log ? '' : 'Waiting in the job queue';
    $progress =~ s/^\[satellite\]\s*//; chomp $progress;
    my $seconds = time() - ($meta->{created} // time());
    my $exit = -e "$base.exit" ? read_file("$base.exit") : undef;
    if (!defined $exit) {
        $c->stash->{rest} = { status => 'running', progress => $progress, seconds => $seconds };
        return;
    }
    chomp $exit;
    if ($exit eq '0' && -e "$base.results.json") {
        $c->stash->{rest} = { status => 'done', seconds => $seconds };
        return;
    }
    my @err = grep { /^Error|error in:|^\s{4}\S|Execution halted|failed/ } @log;
    my $msg = join('', @err[ ($#err > 8 ? $#err - 8 : 0) .. $#err ]) || "The run ended (code $exit) without results.";
    $msg = 'The run was stopped by the system (probably out of memory: try a smaller area or a shorter period).' if $exit =~ /^(137|9)$/;
    $c->stash->{rest} = { status => 'failed', error => $msg, progress => $progress, seconds => $seconds };
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
    return _fail($c, 'Unknown file.') if $name !~ /^(fields\.csv|indices\.csv|site\d{1,2}\.map\.tif)$/;
    my $path = _work_dir($c) . "/$run_id.$name";
    return _fail($c, 'This file does not exist.') if !-e $path;
    my $type = $name =~ /\.csv$/ ? 'text/csv' : 'image/tiff';
    $c->res->content_type($type);
    $c->res->header('Content-Disposition', qq{attachment; filename="$run_id.$name"});
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
        CXGN::Satellite::Reference->new({ cache_dir => _work_dir($c), timeout => 12 })->lookup({
            lon => $lon + 0, lat => $lat + 0, species => scalar $r->param('species'), country => scalar $r->param('country'), year => $year, no_download => 1 })
    } catch { +{ error => "$_" } };
    $c->stash->{rest} = $res;
}

1;
