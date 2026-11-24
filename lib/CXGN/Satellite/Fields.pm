package CXGN::Satellite::Fields;

=head1 NAME

CXGN::Satellite::Fields - fields drawn on the Satellite page: the production
fields of a farm (location) and the field of a trial without plot coordinates

=head1 SYNOPSIS

  my $f = CXGN::Satellite::Fields->new({ schema => $schema });
  my $fields = $f->location_fields($location_id);    # [ { name, ring, area_ha } ]
  $f->store_location_fields($location_id, [ { name => 'North', ring => [ [lon, lat], ... ] } ]);
  my $ring = $f->trial_field($trial_id);              # [ [lon, lat], ... ] or undef
  $f->store_trial_field($trial_id, $ring);            # undef removes it

=head1 DESCRIPTION

Farm fields are kept in the nd_geolocationprop location_fields_geo_json (a
GeoJSON FeatureCollection of named polygons), a trial field in the
projectprop trial_field_geo_json (a GeoJSON Polygon); both terms come from
db patch AddSatelliteTerms. Coordinates are WGS84 longitude, latitude.

A ring is accepted when it has 3 to 1000 distinct points inside the valid
longitude / latitude range and encloses an area between 0.01 ha and 10000 ha;
it is stored closed (first point repeated at the end).

=head1 AUTHOR

Chris Simoes

=cut

use Moose;
use JSON;
use Try::Tiny;
use SGN::Model::Cvterm;

has 'schema' => (isa => 'Bio::Chado::Schema', is => 'rw', required => 1);

my $MAX_FIELDS = 500;
my $MAX_POINTS = 1000;
my $MAX_NAME = 100;

sub _type_id {
    my ($self, $name, $cv) = @_;
    my $row = SGN::Model::Cvterm->get_cvterm_row($self->schema, $name, $cv);
    die "The term $name ($cv) is missing: run the db patch AddSatelliteTerms.\n" if !$row;
    return $row->cvterm_id;
}

=head2 area_ha

Area of a ring ([lon, lat] points) in hectares (local equal-area
approximation, good for fields up to tens of km).

=cut

sub area_ha {
    my ($self, $ring) = @_;
    my @p = @$ring;
    return 0 if @p < 3;
    my $lat0 = 0;
    $lat0 += $_->[1] for @p;
    $lat0 /= @p;
    my $kx = 111320 * cos($lat0 * 3.14159265358979 / 180);
    my $ky = 110574;
    my $a = 0;
    for my $i (0 .. $#p) {
        my ($x1, $y1) = ($p[$i][0] * $kx, $p[$i][1] * $ky);
        my ($x2, $y2) = ($p[($i + 1) % @p][0] * $kx, $p[($i + 1) % @p][1] * $ky);
        $a += $x1 * $y2 - $x2 * $y1;
    }
    return abs($a) / 2 / 10000;
}

=head2 clean_ring

A ring from the page ([[lon, lat], ...]) -> ( closed ring, undef ) or
( undef, error message ).

=cut

sub clean_ring {
    my ($self, $ring) = @_;
    return (undef, 'A field must be a list of points.') if ref $ring ne 'ARRAY';
    my @pts;
    foreach my $p (@$ring) {
        return (undef, 'A field point must be [longitude, latitude].') if ref $p ne 'ARRAY' || @$p < 2;
        my ($lon, $lat) = @$p;
        return (undef, 'A field point is not a number.') if grep { !defined $_ || $_ !~ /^-?\d+(\.\d+)?([eE][-+]?\d+)?$/ } $lon, $lat;
        return (undef, 'A field point is outside the valid longitude / latitude range.') if abs($lon) > 180 || abs($lat) > 90;
        push @pts, [ $lon + 0, $lat + 0 ];
    }
    pop @pts if @pts > 1 && $pts[0][0] == $pts[-1][0] && $pts[0][1] == $pts[-1][1];
    my %seen;
    my $distinct = grep { !$seen{"$_->[0],$_->[1]"}++ } @pts;
    return (undef, 'A field needs at least 3 different points.') if $distinct < 3;
    return (undef, "A field can have at most $MAX_POINTS points.") if @pts > $MAX_POINTS;
    my $ha = $self->area_ha(\@pts);
    return (undef, 'A field is smaller than 0.01 ha (100 m2).') if $ha < 0.01;
    return (undef, 'A field is larger than 10000 ha.') if $ha > 10000;
    return ([ @pts, [ @{ $pts[0] } ] ], undef);
}

=head2 location_fields

Fields drawn for a location: [ { name, ring (closed), area_ha } ].

=cut

sub location_fields {
    my ($self, $location_id) = @_;
    my $prop = $self->schema->resultset('NaturalDiversity::NdGeolocationprop')->search({
        nd_geolocation_id => $location_id, type_id => $self->_type_id('location_fields_geo_json', 'nd_geolocation_property') })->first;
    return [] if !$prop;
    my $fc = try { decode_json($prop->value) } || {};
    my @out;
    foreach my $f (@{ $fc->{features} || [] }) {
        my $ring = (($f->{geometry} || {})->{coordinates} || [])->[0];
        next if ref $ring ne 'ARRAY';
        push @out, { name => ($f->{properties} || {})->{name} // '', ring => $ring, area_ha => sprintf('%.2f', $self->area_ha([ @$ring[0 .. $#$ring - 1] ])) + 0 };
    }
    return \@out;
}

=head2 store_location_fields

Replaces the fields of a location with [ { name, ring } ] (an empty list
removes them). Returns { fields } or { error }.

=cut

sub store_location_fields {
    my ($self, $location_id, $fields) = @_;
    return { error => 'Fields must be a list.' } if ref $fields ne 'ARRAY';
    return { error => "At most $MAX_FIELDS fields per location." } if @$fields > $MAX_FIELDS;
    my $loc = $self->schema->resultset('NaturalDiversity::NdGeolocation')->find({ nd_geolocation_id => $location_id });
    return { error => 'This location does not exist.' } if !$loc;
    my (@features, %names);
    my $n = 0;
    foreach my $f (@$fields) {
        $n++;
        return { error => "Field $n is not valid." } if ref $f ne 'HASH';
        my $name = $f->{name} // '';
        $name =~ s/^\s+|\s+$//g;
        $name = "Field $n" if $name eq '';
        return { error => "Field name '$name' is longer than $MAX_NAME characters." } if length($name) > $MAX_NAME;
        return { error => "Two fields are called '$name'." } if $names{lc $name}++;
        my ($ring, $err) = $self->clean_ring($f->{ring});
        return { error => "Field '$name': $err" } if $err;
        push @features, { type => 'Feature', properties => { name => $name }, geometry => { type => 'Polygon', coordinates => [ $ring ] } };
    }
    my $type_id = $self->_type_id('location_fields_geo_json', 'nd_geolocation_property');
    my $rs = $self->schema->resultset('NaturalDiversity::NdGeolocationprop');
    my $prop = $rs->search({ nd_geolocation_id => $location_id, type_id => $type_id })->first;
    if (!@features) {
        $prop->delete if $prop;
    } else {
        my $value = encode_json({ type => 'FeatureCollection', features => \@features });
        if ($prop) { $prop->update({ value => $value }) }
        else { $rs->create({ nd_geolocation_id => $location_id, type_id => $type_id, value => $value, rank => 0 }) }
    }
    return { fields => $self->location_fields($location_id) };
}

=head2 trial_field

The drawn field of a trial: closed ring or undef.

=cut

sub trial_field {
    my ($self, $trial_id) = @_;
    my $prop = $self->schema->resultset('Project::Projectprop')->search({
        project_id => $trial_id, type_id => $self->_type_id('trial_field_geo_json', 'project_property') })->first;
    return if !$prop;
    my $g = try { decode_json($prop->value) } || {};
    $g = $g->{geometry} if $g->{geometry};
    my $ring = ($g->{coordinates} || [])->[0];
    return ref $ring eq 'ARRAY' ? $ring : undef;
}

=head2 store_trial_field

Sets (ring) or removes (undef) the drawn field of a trial. Returns
{ ring, area_ha } / { removed => 1 } or { error }.

=cut

sub store_trial_field {
    my ($self, $trial_id, $ring) = @_;
    my $trial = $self->schema->resultset('Project::Project')->find({ project_id => $trial_id });
    return { error => 'This trial does not exist.' } if !$trial;
    my $type_id = $self->_type_id('trial_field_geo_json', 'project_property');
    my $rs = $self->schema->resultset('Project::Projectprop');
    my $prop = $rs->search({ project_id => $trial_id, type_id => $type_id })->first;
    if (!defined $ring) {
        $prop->delete if $prop;
        return { removed => 1 };
    }
    my ($clean, $err) = $self->clean_ring($ring);
    return { error => $err } if $err;
    my $value = encode_json({ type => 'Polygon', coordinates => [ $clean ] });
    if ($prop) { $prop->update({ value => $value }) }
    else { $rs->create({ project_id => $trial_id, type_id => $type_id, value => $value, rank => 0 }) }
    return { ring => $clean, area_ha => sprintf('%.2f', $self->area_ha([ @$clean[0 .. $#$clean - 1] ])) + 0 };
}

1;
