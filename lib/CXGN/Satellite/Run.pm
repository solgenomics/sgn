package CXGN::Satellite::Run;

=head1 NAME

CXGN::Satellite::Run - the request of a Satellite page model run (step 5):
checks what the page sends and adds what comes from the database

=head1 SYNOPSIS

  my $run = CXGN::Satellite::Run->new({ schema => $schema });
  my ($request, $error) = $run->build_request($from_page);
  my $info = $run->trial_info([ $trial_id, ... ]);

=head1 DESCRIPTION

The page sends the sites (square, drawn examples of each class, drawn fields
to estimate, the trial of the plots), the classes, the calibration fields it
drew (with their yield and season) and the ids of the calibration trials, the
yield trait and the settings. B<build_request> keeps only known settings
within their ranges, checks every ring, and turns each calibration trial into
a field: its outline (the field drawn for it, or the convex hull of its plot
coordinates), its yield (mean of the trait over its plots) and its season
(planting date to harvest date, or planting date + season_days). The result is
the request read by bin/satellite_models.pl.

=head1 AUTHOR

Chris Simoes

=cut

use Moose;
use JSON;
use Try::Tiny;
use SGN::Model::Cvterm;
use CXGN::Satellite::Fields;

has 'schema' => (isa => 'Bio::Chado::Schema', is => 'rw', required => 1);

my $NUM = qr/^-?\d+(\.\d+)?([eE][-+]?\d+)?$/;
my %LIMITS = (
    sites => 20, labels => 400, targets => 300, calibration => 300, classes => 12, plots => 5000,
);
# setting => [ default, min, max ] (numbers) or [ default, [ allowed ] ] / bool
my %SETTINGS = (
    min_scene_clear => [ 10, 0, 90 ],
    min_field_clear => [ 50, 10, 100 ],
    period_days => [ 30, 7, 120 ],
    ntree => [ 300, 50, 1000 ],
    pixels_per_area => [ 300, 20, 2000 ],
    cv_folds => [ 5, 2, 10 ],
    min_patch_ha => [ 0.5, 0.05, 100 ],
    min_confidence => [ 50, 0, 95 ],
    min_dates => [ 4, 1, 30 ],
    min_fields => [ 8, 5, 100 ],
    level => [ 90, 50, 99 ],
    season_days => [ 150, 60, 365 ],
);
my %BOOL = (smooth => 1, balance => 1);
my @MODELS = qw(linear lasso random_forest);
my @PREDICTORS = qw(ndvi_auc ndvi_max ndre_max peak_day);

=head2 settings

Known settings within their ranges (defaults for the rest).

=cut

sub settings {
    my ($self, $in) = @_;
    $in = {} if ref $in ne 'HASH';
    my %out;
    foreach my $k (keys %SETTINGS) {
        my ($def, $min, $max) = @{ $SETTINGS{$k} };
        my $v = $in->{$k};
        $v = $def if !defined $v || $v !~ $NUM;
        $v = $min if $v < $min;
        $v = $max if $v > $max;
        $out{$k} = $v + 0;
    }
    foreach my $k (keys %BOOL) {
        $out{$k} = defined $in->{$k} ? ($in->{$k} && $in->{$k} ne 'false' ? JSON::true : JSON::false) : ($BOOL{$k} ? JSON::true : JSON::false);
    }
    $out{yield_model} = (grep { ($in->{yield_model} // '') eq $_ } @MODELS) ? $in->{yield_model} : 'linear';
    my %p = map { $_ => 1 } grep { defined } (ref $in->{predictors} eq 'ARRAY' ? @{ $in->{predictors} } : ());
    my @pred = grep { $p{$_} } @PREDICTORS;
    $out{predictors} = @pred ? \@pred : [ 'ndvi_auc', 'ndre_max' ];
    return \%out;
}

sub _date {
    my $v = shift // return;
    return "$1-$2-$3" if $v =~ /(\d{4})[-\/](\d\d)[-\/](\d\d)/;
    return;
}

sub _add_days {
    my ($date, $days) = @_;
    require Time::Local;
    my ($y, $m, $d) = split /-/, $date;
    my @t = gmtime(Time::Local::timegm(0, 0, 12, $d, $m - 1, $y) + $days * 86400);
    return sprintf('%04d-%02d-%02d', $t[5] + 1900, $t[4] + 1, $t[3]);
}

sub _span_days {
    my ($from, $to) = @_;
    require Time::Local;
    my @t = map { my ($y, $m, $d) = split /-/; Time::Local::timegm(0, 0, 12, $d, $m - 1, $y) } $from, $to;
    return ($t[1] - $t[0]) / 86400;
}

sub _type_id {
    my ($self, $name, $cv) = @_;
    my $row = SGN::Model::Cvterm->get_cvterm_row($self->schema, $name, $cv);
    return $row ? $row->cvterm_id : -1;
}

sub _dbh { return shift->schema->storage->dbh }

# convex hull of [lon, lat] points (monotone chain), counter-clockwise, open
sub convex_hull {
    my ($self, @pts) = @_;
    my %seen;
    @pts = sort { $a->[0] <=> $b->[0] || $a->[1] <=> $b->[1] } grep { !$seen{"$_->[0],$_->[1]"}++ } @pts;
    return \@pts if @pts < 3;
    my $cross = sub { my ($o, $a, $b) = @_; ($a->[0] - $o->[0]) * ($b->[1] - $o->[1]) - ($a->[1] - $o->[1]) * ($b->[0] - $o->[0]) };
    my (@lower, @upper);
    foreach my $p (@pts) { pop @lower while @lower >= 2 && $cross->($lower[-2], $lower[-1], $p) <= 0; push @lower, $p }
    foreach my $p (reverse @pts) { pop @upper while @upper >= 2 && $cross->($upper[-2], $upper[-1], $p) <= 0; push @upper, $p }
    pop @lower; pop @upper;
    return [ @lower, @upper ];
}

=head2 trial_plots

Plots of a trial with GPS coordinates: [ { id, name, ring } ] (a ring of one
point for a point).

=cut

sub trial_plots {
    my ($self, $trial_id) = @_;
    my $q = "SELECT DISTINCT ON (s.stock_id) s.stock_id, s.uniquename, sp.value
        FROM nd_experiment_project nep
        JOIN nd_experiment_stock nes ON (nes.nd_experiment_id = nep.nd_experiment_id)
        JOIN stock s ON (s.stock_id = nes.stock_id)
        JOIN stockprop sp ON (sp.stock_id = s.stock_id AND sp.type_id = ?)
        WHERE nep.project_id = ?
        ORDER BY s.stock_id, sp.rank";
    my $h = $self->_dbh->prepare($q);
    $h->execute($self->_type_id('plot_geo_json', 'stock_property'), $trial_id);
    my @out;
    while (my ($id, $name, $v) = $h->fetchrow_array) {
        my $g = try { decode_json($v) } or next;
        $g = $g->{geometry} if ref $g eq 'HASH' && $g->{geometry};
        next if ref $g ne 'HASH';
        my $ring = ($g->{type} // '') eq 'Polygon' ? ($g->{coordinates} || [])->[0] : ($g->{type} // '') eq 'Point' ? [ $g->{coordinates} ] : undef;
        next if ref $ring ne 'ARRAY';
        my @pts = map { [ $_->[0] + 0, $_->[1] + 0 ] } grep { ref $_ eq 'ARRAY' && ($_->[0] // '') =~ $NUM && ($_->[1] // '') =~ $NUM && abs($_->[0]) <= 180 && abs($_->[1]) <= 90 } @$ring;
        push @out, { id => $id + 0, name => $name, ring => \@pts } if @pts;
    }
    return \@out;
}

=head2 trial_info

For calibration: [ { trial_id, name, year, species, planting, harvest,
plots_with_coordinates, drawn_field (0/1), traits => [ { id, name, mean, n } ] } ]
(numeric traits measured on the trial's plots).

=cut

sub trial_info {
    my ($self, $ids) = @_;
    my @ids = grep { /^\d+$/ } @{ $ids || [] };
    return [] if !@ids;
    my $dbh = $self->_dbh;
    my $fields = CXGN::Satellite::Fields->new({ schema => $self->schema });
    my $prop = sub {
        my ($id, $name) = @_;
        my ($v) = $dbh->selectrow_array("SELECT value FROM projectprop WHERE project_id = ? AND type_id = ? LIMIT 1", undef, $id, $self->_type_id($name, 'project_property'));
        return $v;
    };
    my $traits_q = $dbh->prepare("SELECT c.cvterm_id, c.name || '|' || db.name || ':' || x.accession, avg(ph.value::numeric), count(*)
        FROM nd_experiment_project nep
        JOIN nd_experiment_phenotype nph ON (nph.nd_experiment_id = nep.nd_experiment_id)
        JOIN phenotype ph ON (ph.phenotype_id = nph.phenotype_id)
        JOIN cvterm c ON (c.cvterm_id = ph.cvalue_id)
        JOIN public.dbxref x ON (x.dbxref_id = c.dbxref_id)
        JOIN public.db ON (db.db_id = x.db_id)
        WHERE nep.project_id = ? AND ph.value ~ '^-?[0-9]+([.][0-9]+)?([eE][-+]?[0-9]+)?\$'
        GROUP BY 1, 2 ORDER BY 2");
    my $species_q = $dbh->prepare("SELECT o.species FROM nd_experiment_project nep
        JOIN nd_experiment_stock nes ON (nes.nd_experiment_id = nep.nd_experiment_id)
        JOIN stock s ON (s.stock_id = nes.stock_id) JOIN public.organism o ON (o.organism_id = s.organism_id)
        WHERE nep.project_id = ? GROUP BY 1 ORDER BY count(*) DESC LIMIT 1");
    my @out;
    foreach my $id (@ids) {
        my $p = $self->schema->resultset('Project::Project')->find({ project_id => $id }) or next;
        $traits_q->execute($id);
        my @traits;
        while (my ($tid, $tname, $mean, $n) = $traits_q->fetchrow_array) {
            next if $tname =~ /\|SATIDX:/;    # the satellite indices themselves
            push @traits, { id => $tid + 0, name => $tname, mean => $mean + 0, n => $n + 0 };
        }
        $species_q->execute($id);
        my ($species) = $species_q->fetchrow_array;
        push @out, {
            trial_id => $id + 0, name => $p->name, year => $prop->($id, 'project year'),
            species => $species, planting => _date($prop->($id, 'project_planting_date')), harvest => _date($prop->($id, 'project_harvest_date')),
            plots_with_coordinates => scalar @{ $self->trial_plots($id) }, drawn_field => ($fields->trial_field($id) ? 1 : 0),
            traits => \@traits,
        };
    }
    return \@out;
}

=head2 trial_calibration

Args: trial id, trait cvterm id, season days. { id, name, source => 'trial',
ring, yield, n, start, end } or { error }.

=cut

sub trial_calibration {
    my ($self, $trial_id, $trait_id, $season_days) = @_;
    my $info = $self->trial_info([ $trial_id ])->[0] or return { error => "Trial $trial_id does not exist." };
    my ($t) = grep { $_->{id} == $trait_id } @{ $info->{traits} };
    return { error => "$info->{name}: no value of the yield trait." } if !$t;
    return { error => "$info->{name}: no planting date." } if !$info->{planting};
    my $ring = CXGN::Satellite::Fields->new({ schema => $self->schema })->trial_field($trial_id);
    if (!$ring) {
        my @pts = map { @{ $_->{ring} } } @{ $self->trial_plots($trial_id) };
        my $hull = $self->convex_hull(@pts);
        return { error => "$info->{name}: no field (no plot coordinates and no drawn field)." } if @$hull < 3;
        $ring = $hull;
    }
    my @ring = map { [ $_->[0] + 0, $_->[1] + 0 ] } @$ring;
    pop @ring if @ring > 3 && $ring[0][0] == $ring[-1][0] && $ring[0][1] == $ring[-1][1];
    my $end = $info->{harvest} && $info->{harvest} gt $info->{planting} ? $info->{harvest} : _add_days($info->{planting}, $season_days);
    return { id => "trial_$trial_id", name => $info->{name}, source => 'trial', trial_id => $trial_id + 0, ring => \@ring,
             yield => $t->{mean}, n => $t->{n}, start => _add_days($info->{planting}, -10), end => $end,
             end_from => ($info->{harvest} && $info->{harvest} gt $info->{planting} ? 'harvest date' : "planting + $season_days days") };
}

sub _ring {
    my ($self, $r, $what) = @_;
    return (undef, "$what: not a list of points") if ref $r ne 'ARRAY' || @$r < 3 || @$r > 1000;
    my @pts;
    foreach my $p (@$r) {
        return (undef, "$what: a point is not [longitude, latitude]") if ref $p ne 'ARRAY' || ($p->[0] // '') !~ $NUM || ($p->[1] // '') !~ $NUM || abs($p->[0]) > 180 || abs($p->[1]) > 90;
        push @pts, [ $p->[0] + 0, $p->[1] + 0 ];
    }
    return (\@pts, undef);
}

=head2 build_request

The page request -> ( request for bin/satellite_models.pl, undef ) or
( undef, error message ).

=cut

sub build_request {
    my ($self, $in) = @_;
    return (undef, 'The request is not valid.') if ref $in ne 'HASH';
    my $settings = $self->settings($in->{settings});
    my %models = map { $_ => ($in->{models} || {})->{$_} ? JSON::true : JSON::false } qw(crop_map yield indices);
    return (undef, 'Choose at least one model.') if !grep { $models{$_} } keys %models;
    my ($start, $end) = map { _date(($in->{dates} || {})->{$_}) } qw(start end);
    return (undef, 'The dates are not valid.') if !$start || !$end || $start gt $end;

    my @classes;
    # crop map from a stored crop curve (proof of concept: maize only): no examples needed
    my $method = ($in->{crop_map_method} // '') eq 'standard' ? 'standard' : 'examples';
    if ($models{crop_map} && $method eq 'standard') {
        return (undef, 'The crop standard exists only for maize (Zea mays); choose maize, or draw examples.') if ($in->{crop} // '') !~ /^Zea mays\b/;
        return (undef, 'The maize standard needs dates (step 3) covering a whole season: at least 4 months, best 12.') if _span_days($start, $end) < 120;
        @classes = ({ id => 'crop', name => 'Maize' }, { id => 'other', name => 'Not maize' });
    }
    elsif ($models{crop_map}) {
        my %seen;
        foreach my $k (@{ $in->{classes} || [] }) {
            my $id = $k->{id} // ''; my $name = $k->{name} // '';
            return (undef, 'A class has no name.') if $id !~ /^[A-Za-z0-9_]{1,40}$/ || $name !~ /\S/ || length($name) > 60;
            return (undef, "Two classes are called $name.") if $seen{lc $name}++;
            push @classes, { id => $id, name => $name };
        }
        return (undef, 'Drawing examples needs at least 2 classes: the crop and what is around it (e.g. Forest, Pasture, or one "Other" class).'
            . (($in->{crop} // '') =~ /^Zea mays\b/ ? ' For maize you can choose "Maize standard: no drawing" instead.' : '')) if @classes < 2;
        return (undef, "At most $LIMITS{classes} classes.") if @classes > $LIMITS{classes};
    }
    my %class_ok = map { $_->{id} => 1 } @classes;

    my @sites;
    my $sites = $in->{sites} || [];
    return (undef, 'No location.') if ref $sites ne 'ARRAY' || !@$sites;
    return (undef, "At most $LIMITS{sites} locations.") if @$sites > $LIMITS{sites};
    my ($n_labels, $n_targets) = (0, 0);
    my %label_classes;
    foreach my $s (@$sites) {
        my $name = $s->{name} // 'location';
        my ($lon, $lat) = @{ $s->{center} || [] };
        my $size = $s->{size_m};
        return (undef, "$name: no area.") if ($lon // '') !~ $NUM || ($lat // '') !~ $NUM || ($size // '') !~ $NUM || $size < 100 || $size > 10000;
        my $dlat = $size / 2 / 110574;
        my $dlon = $size / 2 / (111320 * cos($lat * 3.14159265358979 / 180));
        my $country;
        if (($s->{id} // '') =~ /^\d+$/) {
            ($country) = $self->_dbh->selectrow_array("SELECT p.value FROM nd_geolocationprop p WHERE p.nd_geolocation_id = ? AND p.type_id IN
                (SELECT cvterm_id FROM cvterm WHERE name = 'country_name') LIMIT 1", undef, $s->{id});
        }
        my $site = { id => $s->{id}, name => $name, country => $country, center => [ $lon + 0, $lat + 0 ], size_m => $size + 0,
                     bbox => [ $lon - $dlon, $lat - $dlat, $lon + $dlon, $lat + $dlat ], labels => [], targets => [] };
        # images hidden by the user in step 4 (still cloudy): left out
        my @hidden = grep { defined $_ && /^[A-Za-z0-9_]{1,100}$/ } @{ ref $s->{exclude_scenes} eq 'ARRAY' ? $s->{exclude_scenes} : [] };
        $site->{exclude_scenes} = [ @hidden[0 .. ($#hidden > 1999 ? 1999 : $#hidden)] ] if @hidden;
        if ($models{crop_map}) {
            foreach my $l (@{ $s->{labels} || [] }) {
                return (undef, "$name: an example has an unknown class.") if !$class_ok{ $l->{class} // '' };
                my ($ring, $err) = $self->_ring($l->{ring}, "$name: an example");
                return (undef, $err) if $err;
                push @{ $site->{labels} }, { class => $l->{class}, ring => $ring };
                $label_classes{ $l->{class} }++;
                $n_labels++;
            }
        }
        if ($models{yield}) {
            my $k = 0;
            foreach my $t (@{ $s->{targets} || [] }) {
                $k++;
                my ($ring, $err) = $self->_ring($t->{ring}, "$name: a field to estimate");
                return (undef, $err) if $err;
                push @{ $site->{targets} }, { id => "drawn_" . ($s->{id} // 0) . "_$k", name => substr($t->{name} // "Field $k", 0, 100), ring => $ring };
                $n_targets++;
            }
        }
        if ($models{indices} && ($s->{plots_trial_id} // '') =~ /^\d+$/) {
            my $plots = $self->trial_plots($s->{plots_trial_id});
            return (undef, "$name: too many plots.") if @$plots > $LIMITS{plots};
            my $p = $self->schema->resultset('Project::Project')->find({ project_id => $s->{plots_trial_id} });
            $site->{plots} = { trial_id => $s->{plots_trial_id} + 0, trial_name => ($p ? $p->name : ''), list => $plots } if @$plots;
        }
        push @sites, $site;
    }
    return (undef, "At most $LIMITS{labels} examples.") if $n_labels > $LIMITS{labels};
    return (undef, "At most $LIMITS{targets} fields to estimate.") if $n_targets > $LIMITS{targets};
    if ($models{crop_map} && $method ne 'standard') {
        my @missing = map { $_->{name} } grep { !$label_classes{ $_->{id} } } @classes;
        return (undef, 'Draw examples of every class on the map (missing: ' . join(', ', @missing) . ').') if @missing;
    }
    if ($models{indices}) {
        return (undef, 'Vegetation indices per plot need a location whose field is a trial with plot coordinates.') if !grep { $_->{plots} } @sites;
    }

    my (@calib, @skipped);
    my $yield = {};
    if ($models{yield}) {
        my $y = $in->{yield} || {};
        # calibrated: estimates in the unit of the known yields; index: no known yield,
        # a relative index of the season curve (100 = the mean of the fields estimated)
        my $mode = ($y->{mode} // '') eq 'index' ? 'index' : 'calibrated';
        $yield = { mode => $mode, trait => substr($y->{trait_name} // '', 0, 200), unit => substr($y->{unit} // '', 0, 40), per_ha => ($y->{per_ha} ? JSON::true : JSON::false) };
        # index: optionally scaled to approximate kg/ha by the public average yield of the region
        $yield = { mode => 'index', per_ha => JSON::false, reference => ($y->{reference} ? JSON::true : JSON::false) } if $mode eq 'index';
        my ($cs, $ce) = map { _date(($y->{season} || {})->{$_}) } qw(start end);
        $yield->{season} = { start => $cs // $start, end => $ce // $end };
        return (undef, 'The crop season is not valid.') if $yield->{season}{start} gt $yield->{season}{end};
        return (undef, 'Draw the fields to estimate, or run the crop map so its areas of the crop are estimated.') if !$n_targets && !$models{crop_map};
        if ($mode eq 'calibrated') {
            my $k = 0;
            foreach my $c (@{ $in->{calibration} || [] }) {
                $k++;
                my ($ring, $err) = $self->_ring($c->{ring}, "calibration field $k");
                return (undef, $err) if $err;
                return (undef, "Calibration field " . ($c->{name} // $k) . ": the yield is not a number.") if ($c->{yield} // '') !~ $NUM;
                my ($cs1, $ce1) = (_date($c->{start}), _date($c->{end}));
                return (undef, "Calibration field " . ($c->{name} // $k) . ": the season dates are not valid.") if !$cs1 || !$ce1 || $cs1 gt $ce1;
                push @calib, { id => "drawn_$k", name => substr($c->{name} // "Field $k", 0, 100), source => 'drawn', site => $c->{site} // '',
                               ring => $ring, yield => $c->{yield} + 0, start => $cs1, end => $ce1 };
            }
            my @trial_ids = grep { /^\d+$/ } @{ $in->{calibration_trials} || [] };
            if (@trial_ids) {
                my $trait_id = ($y->{trait_id} // '') =~ /^\d+$/ ? $y->{trait_id} : return (undef, 'Choose the yield trait of the calibration trials.');
                foreach my $tid (@trial_ids) {
                    my $tc = $self->trial_calibration($tid, $trait_id, $settings->{season_days});
                    if ($tc->{error}) { push @skipped, $tc->{error}; next }
                    push @calib, $tc;
                }
            }
            return (undef, "At most $LIMITS{calibration} calibration fields.") if @calib > $LIMITS{calibration};
            if (@calib < $settings->{min_fields}) {
                my $why = @skipped ? ' Not usable: ' . join(' ', @skipped) : '';
                return (undef, "The yield model needs at least $settings->{min_fields} calibration fields (fields you drew with their yield, or trials); there are " . scalar(@calib) . ".$why"
                    . ' Without known yields, choose the relative yield index.');
            }
        }
    }

    my $crop_class = $in->{crop_class} // '';
    $crop_class = '' if !$class_ok{$crop_class};
    return ({
        dates => { start => $start, end => $end }, crop => substr($in->{crop} // '', 0, 100), crop_class => ($method eq 'standard' && $models{crop_map} ? 'crop' : $crop_class),
        crop_map_method => $method, ($method eq 'standard' ? (standard => 'maize') : ()),
        models => \%models, settings => $settings, classes => \@classes, sites => \@sites,
        calibration => \@calib, calibration_skipped => \@skipped, yield => $yield,
    }, undef);
}

1;
