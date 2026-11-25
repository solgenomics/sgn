package CXGN::Satellite::Reference;

=head1 NAME

CXGN::Satellite::Reference - public average yield of a crop around a point,
the reference that turns the relative yield index into approximate kg/ha when
no field of known yield exists

=head1 SYNOPSIS

  my $ref = CXGN::Satellite::Reference->new({ cache_dir => $dir });
  my $r = $ref->lookup({ lon => -44.18, lat => -19.47, species => 'Zea mays', country => 'Brazil', year => 2026 });
  # { source, level, area, crop, unit => 'kg/ha', value, years => { 2021 => 5100, ... }, basis, url, citation } or { error }

=head1 DESCRIPTION

Brazil (the point inside a Brazilian state): IBGE Producao Agricola Municipal
(PAM, SIDRA table 1612, variable 112 average yield in kg/ha) of the
municipality holding the point, or of its state when the municipality has no
value for the crop. The municipality and state are found from the IBGE
boundaries (servicodados.ibge.gov.br malhas, kept in the cache).

Other countries: FAOSTAT Production - Crops and livestock products, element
5412 Yield (kg/ha), national value; the bulk file (about 35 MB) is downloaded
once and only its yields of the known crops are kept in the cache
(B<faostat_prepare>).

The value is the one of the season's year when published, otherwise the mean
of the last 5 published years.

The reference assumes the fields average like the region: an approximation to
show with a warning, never a calibration.

=head1 AUTHOR

Chris Simoes

=cut

use Moose;
use JSON;
use Try::Tiny;
use LWP::UserAgent;
use URI;
use File::Path qw(make_path);
use File::Spec;

has 'cache_dir' => (isa => 'Str', is => 'rw', required => 1);
has 'timeout' => (isa => 'Int', is => 'rw', default => 30);
has 'ua' => (is => 'rw', lazy => 1, default => sub {
    my $ua = LWP::UserAgent->new(timeout => shift->timeout, agent => 'Breedbase satellite');
    $ua->env_proxy;
    return $ua;
});
has 'sidra_url' => (isa => 'Str', is => 'rw', default => 'https://apisidra.ibge.gov.br/values');
has 'ibge_mesh_url' => (isa => 'Str', is => 'rw', default => 'https://servicodados.ibge.gov.br/api/v3/malhas');
has 'faostat_url' => (isa => 'Str', is => 'rw', default => 'https://bulks-faostat.fao.org/production/Production_Crops_Livestock_E_All_Data_(Normalized).zip');
# the regional statistics of the site, in order of preference (sgn.conf satellite_regional_statistics:
# ibge, nass, eurostat, harveststat, fao; FAOSTAT is always the last fallback), and the USDA NASS key
has 'providers' => (isa => 'ArrayRef', is => 'rw', default => sub { [] });
has 'nass_key' => (isa => 'Maybe[Str]', is => 'rw');
has 'nass_url' => (isa => 'Str', is => 'rw', default => 'https://quickstats.nass.usda.gov/api/api_GET/');
has 'tiger_url' => (isa => 'Str', is => 'rw', default => 'https://tigerweb.geo.census.gov/arcgis/rest/services/TIGERweb/State_County/MapServer');
has 'eurostat_url' => (isa => 'Str', is => 'rw', default => 'https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/apro_cpshr');
has 'gisco_url' => (isa => 'Str', is => 'rw', default => 'https://gisco-services.ec.europa.eu/distribution/v2');
has 'harveststat_url' => (isa => 'Str', is => 'rw', default => 'https://raw.githubusercontent.com/HarvestStat/HarvestStat-Africa/main/public');

# species -> IBGE PAM product (table 1612, classification 81) and FAOSTAT item
my %CROPS = (
    'Zea mays' => [ 2711, 56, 'maize' ],
    'Nicotiana tabacum' => [ 2703, 826, 'tobacco' ],
    'Glycine max' => [ 2713, 236, 'soybean' ],
    'Manihot esculenta' => [ 2708, 125, 'cassava' ],
    'Oryza sativa' => [ 2692, 27, 'rice' ],
    'Triticum aestivum' => [ 2716, 15, 'wheat' ],
    'Sorghum bicolor' => [ 2714, 83, 'sorghum' ],
    'Saccharum officinarum' => [ 2696, 156, 'sugarcane' ],
    'Phaseolus vulgaris' => [ 2702, 176, 'dry beans' ],
    'Gossypium hirsutum' => [ 2689, 328, 'seed cotton' ],
    'Solanum tuberosum' => [ 2695, 116, 'potato' ],
    'Ipomoea batatas' => [ 2694, 122, 'sweet potato' ],
    'Arachis hypogaea' => [ 2691, 242, 'groundnut' ],
    'Helianthus annuus' => [ 109179, 267, 'sunflower' ],
    'Avena sativa' => [ 2693, 75, 'oats' ],
    'Hordeum vulgare' => [ 2699, 44, 'barley' ],
    'Solanum lycopersicum' => [ 2715, 388, 'tomato' ],
);

=head2 crop

Species (or 'Genus species subsp. ...') -> { ibge, fao, name } or undef.

=cut

sub crop {
    my ($self, $species) = @_;
    $species //= '';
    my ($k) = grep { $species eq $_ || index($species, "$_ ") == 0 } keys %CROPS;
    return if !$k;
    return { species => $k, ibge => $CROPS{$k}[0], fao => $CROPS{$k}[1], name => $CROPS{$k}[2] };
}

sub _cache {
    my ($self, $name) = @_;
    my $dir = File::Spec->catdir($self->cache_dir, 'reference');
    make_path($dir) if !-d $dir;
    return File::Spec->catfile($dir, $name);
}

# a url, kept in the cache for max_age days
sub _get_cached {
    my ($self, $url, $name, $max_age) = @_;
    my $f = $self->_cache($name);
    if (-e $f && -s $f && -M $f < $max_age) {
        open my $fh, '<', $f or die "Cannot read $f: $!\n";
        local $/;
        return scalar <$fh>;
    }
    my $res = $self->ua->get($url);
    die "Could not reach $url: " . $res->status_line . "\n" if !$res->is_success;
    my $body = $res->decoded_content;
    open my $out, '>', "$f.tmp" or die "Cannot write $f: $!\n";
    print $out $body;
    close $out;
    rename "$f.tmp", $f;
    return $body;
}

# ray casting; a GeoJSON geometry (Polygon or MultiPolygon, outer rings)
sub _inside {
    my ($lon, $lat, $geom) = @_;
    my @polys = $geom->{type} eq 'Polygon' ? ($geom->{coordinates}) : $geom->{type} eq 'MultiPolygon' ? @{ $geom->{coordinates} } : ();
    foreach my $poly (@polys) {
        my $ring = $poly->[0];
        my $in = 0;
        for (my ($i, $j) = (0, $#$ring); $i <= $#$ring; $j = $i++) {
            my ($xi, $yi) = @{ $ring->[$i] };
            my ($xj, $yj) = @{ $ring->[$j] };
            $in = !$in if (($yi > $lat) != ($yj > $lat)) && ($lon < ($xj - $xi) * ($lat - $yi) / (($yj - $yi) || 1e-12) + $xi);
        }
        if ($in) {
            # not in a hole
            my $hole = 0;
            foreach my $h (@{ $poly }[ 1 .. $#$poly ]) { $hole = 1 if _inside($lon, $lat, { type => 'Polygon', coordinates => [ $h ] }) }
            return 1 if !$hole;
        }
    }
    return 0;
}

=head2 brazil_unit

Point -> { uf => 'MG', uf_code => 31, mun_code => 3167202 } (mun_code undef
when no municipality holds it), or undef outside Brazil.

=cut

sub brazil_unit {
    my ($self, $lon, $lat) = @_;
    my $states = decode_json($self->_get_cached($self->ibge_mesh_url . '/paises/BR?formato=application/vnd.geo%2Bjson&intrarregiao=UF&qualidade=minima', 'br_states.json', 365));
    my ($st) = grep { _inside($lon, $lat, $_->{geometry}) } @{ $states->{features} || [] };
    return if !$st;
    my $uf = $st->{properties}{codarea};
    my $muns = decode_json($self->_get_cached($self->ibge_mesh_url . "/estados/$uf?formato=application/vnd.geo%2Bjson&intrarregiao=municipio&qualidade=intermediaria", "br_mun_$uf.json", 365));
    my ($m) = grep { _inside($lon, $lat, $_->{geometry}) } @{ $muns->{features} || [] };
    return { uf_code => $uf + 0, mun_code => ($m ? $m->{properties}{codarea} + 0 : undef) };
}

# SIDRA PAM average yield of a crop for a territory (n6 municipality, n3 state)
sub _sidra {
    my ($self, $level, $code, $product) = @_;
    my $url = $self->sidra_url . "/t/1612/$level/$code/v/112/p/last%206/c81/$product";
    my $rows = decode_json($self->_get_cached($url, "sidra_${level}_${code}_$product.json", 30));
    my (%years, $name);
    foreach my $r (@{ $rows }[ 1 .. $#$rows ]) {
        $name //= $r->{D1N};
        my $v = $r->{V} // '';
        next if $v !~ /^\d+(\.\d+)?$/ || $v == 0;    # '-', '...', 'X': not produced / not published
        $years{ $r->{D3N} } = $v + 0;
    }
    return { name => $name, years => \%years };
}

=head2 brazil_states

[ { code => 31, uf => 'MG', name => 'Minas Gerais' }, ... ]

=cut

my @UF = (
    [ 11, 'RO', 'Rondonia' ], [ 12, 'AC', 'Acre' ], [ 13, 'AM', 'Amazonas' ], [ 14, 'RR', 'Roraima' ], [ 15, 'PA', 'Para' ], [ 16, 'AP', 'Amapa' ],
    [ 17, 'TO', 'Tocantins' ], [ 21, 'MA', 'Maranhao' ], [ 22, 'PI', 'Piaui' ], [ 23, 'CE', 'Ceara' ], [ 24, 'RN', 'Rio Grande do Norte' ],
    [ 25, 'PB', 'Paraiba' ], [ 26, 'PE', 'Pernambuco' ], [ 27, 'AL', 'Alagoas' ], [ 28, 'SE', 'Sergipe' ], [ 29, 'BA', 'Bahia' ],
    [ 31, 'MG', 'Minas Gerais' ], [ 32, 'ES', 'Espirito Santo' ], [ 33, 'RJ', 'Rio de Janeiro' ], [ 35, 'SP', 'Sao Paulo' ], [ 41, 'PR', 'Parana' ],
    [ 42, 'SC', 'Santa Catarina' ], [ 43, 'RS', 'Rio Grande do Sul' ], [ 50, 'MS', 'Mato Grosso do Sul' ], [ 51, 'MT', 'Mato Grosso' ],
    [ 52, 'GO', 'Goias' ], [ 53, 'DF', 'Distrito Federal' ],
);
my %UF = map { $_->[0] => $_ } @UF;

sub brazil_states { return [ map { { code => $_->[0], uf => $_->[1], name => $_->[2] } } @UF ] }

# the municipalities of a state (IBGE mesh): { code => GeoJSON geometry }
sub _municipalities {
    my ($self, $uf) = @_;
    my $muns = decode_json($self->_get_cached($self->ibge_mesh_url . "/estados/$uf?formato=application/vnd.geo%2Bjson&intrarregiao=municipio&qualidade=intermediaria", "br_mun_$uf.json", 365));
    return { map { $_->{properties}{codarea} => $_->{geometry} } @{ $muns->{features} || [] } };
}

# area in km2 of the outer rings of a geometry (local plane)
sub _area_km2 {
    my $geom = shift;
    my @polys = $geom->{type} eq 'Polygon' ? ($geom->{coordinates}) : $geom->{type} eq 'MultiPolygon' ? @{ $geom->{coordinates} } : ();
    my $a = 0;
    foreach my $poly (@polys) {
        my $ring = $poly->[0];
        my $k = cos(($ring->[0][1] // 0) * 3.14159265358979 / 180) * 111.32;
        my $s = 0;
        for (my ($i, $j) = (0, $#$ring); $i <= $#$ring; $j = $i++) {
            $s += ($ring->[$j][0] * $k) * ($ring->[$i][1] * 110.574) - ($ring->[$i][0] * $k) * ($ring->[$j][1] * 110.574);
        }
        $a += abs($s) / 2;
    }
    return $a;
}

# IBGE PAM (Brazil): every municipality of the states (uf codes), maize split by crop season
# (table 839: 1st crop = summer, 2nd crop = safrinha), other crops one value per year (table 1612)
sub _ibge_yields {
    my ($self, $args) = @_;
    my $crop = $self->crop($args->{species}) or return { error => 'IBGE has no yield statistics for this crop.' };
    my @ufs = grep { $UF{$_} } map { $_ + 0 } grep { /^\d+$/ } @{ $args->{units} || $args->{uf_codes} || [] };
    my @years = sort { $a <=> $b } grep { /^(19|20)\d\d$/ } @{ $args->{years} || [] };
    return { error => 'Choose at least one state.' } if !@ufs;
    return { error => 'Choose at least one year.' } if !@years;
    my $maize = $crop->{name} eq 'maize';
    # crops other than maize have one value per year: taken as the summer season
    my ($table, %season) = $maize ? (839, 114253 => 'summer', 114254 => 'safrinha') : (1612, $crop->{ibge} => 'summer');
    my $url = $self->sidra_url . "/t/$table/n6/in%20n3%20" . join(',', sort { $a <=> $b } @ufs) . '/v/109,112/p/' . join(',', @years) . '/c81/' . join(',', sort keys %season);
    my $name = "sidra_t${table}_" . join('-', sort { $a <=> $b } @ufs) . '_' . join('-', @years) . '_' . join('-', sort keys %season) . '.json';
    my $data = try { decode_json($self->_get_cached($url, $name, 30)) } catch { return { error => "IBGE SIDRA: $_" } };
    return $data if ref $data eq 'HASH';
    my %rows;
    foreach my $r (@{ $data }[ 1 .. $#$data ]) {
        my $v = $r->{V} // '';
        next if $v !~ /^\d+(\.\d+)?$/ || $v == 0;
        my $k = join('|', $r->{D1C}, $r->{D3N}, $r->{D4C});
        $rows{$k} //= { mun_code => $r->{D1C} + 0, name => $r->{D1N}, year => $r->{D3N} + 0, season => $season{ $r->{D4C} } // 'year' };
        $rows{$k}{ $r->{D2C} eq '109' ? 'planted_ha' : 'yield' } = $v + 0;
    }
    my %area;
    foreach my $uf (@ufs) {
        my $muns = try { $self->_municipalities($uf) } || {};
        $area{$_} = _area_km2($muns->{$_}) for keys %$muns;
    }
    my @out;
    foreach my $r (values %rows) {
        next if !$r->{yield} || !$r->{planted_ha};
        $r->{uf} = $UF{ int($r->{mun_code} / 100000) }[1] // '';
        $r->{area_km2} = $area{ $r->{mun_code} } // undef;
        $r->{share} = $r->{area_km2} ? $r->{planted_ha} / ($r->{area_km2} * 100) : undef;
        $r->{mun_code} = $r->{mun_code} + 0;
        $r->{code} = $r->{mun_code};
        $r->{unit} = $r->{uf};
        $r->{season_label} = $maize ? { summer => 'Summer (1st crop)', safrinha => 'Safrinha (2nd crop)' }->{ $r->{season} } : 'Summer (main season, assumed)';
        # sowing windows (R/satellite/standards/seasons.json, Brazil); the PAM year is the harvest year
        my $y = $r->{year};
        $r->{sow} = $r->{season} eq 'summer' ? [ ($y - 1) . '-08-01', ($y - 1) . '-12-31' ]
                  : [ "$y-01-01", "$y-04-30" ];
        push @out, $r;
    }
    @out = sort { ($b->{share} // 0) <=> ($a->{share} // 0) || $a->{name} cmp $b->{name} || $a->{year} <=> $b->{year} || $a->{season} cmp $b->{season} } @out;
    return { provider => 'ibge', crop => $crop->{name}, table => $table, seasons => ($maize ? 1 : 0), rows => \@out,
             url => "https://sidra.ibge.gov.br/tabela/$table",
             citation => $maize ? 'IBGE - Producao Agricola Municipal (PAM), table 839, maize 1st and 2nd crop, average yield (kg/ha)'
                                : 'IBGE - Producao Agricola Municipal (PAM), table 1612, average yield (kg/ha)' };
}

=head2 sample_squares

Args: provider, region code, number of squares, square size (m), seed.
Centres [ [ lon, lat ], ... ] of squares lying inside the region (centre and
corners), drawn at random (the same for the same seed); fewer when the region
is too small or too irregular, none when its boundary is unknown.

=cut

sub sample_squares {
    my ($self, @args) = @_;
    unshift @args, 'ibge' if ($args[0] // '') =~ /^\d{7}$/;    # (municipality code, ...): IBGE
    my ($provider, $code, $n, $size_m, $seed) = @args;
    my $geom = try { $self->region_geometry($provider, $code) } or return [];
    my @polys = $geom->{type} eq 'Polygon' ? ($geom->{coordinates}) : @{ $geom->{coordinates} };
    my @pts = map { @{ $_->[0] } } @polys;
    my ($x0, $x1) = (sort { $a <=> $b } map { $_->[0] } @pts)[0, -1];
    my ($y0, $y1) = (sort { $a <=> $b } map { $_->[1] } @pts)[0, -1];
    srand($seed // 1);
    my @out;
    for (my $try = 0; $try < 600 && @out < $n; $try++) {
        my ($x, $y) = ($x0 + rand($x1 - $x0), $y0 + rand($y1 - $y0));
        my $dy = $size_m / 2 / 110574;
        my $dx = $size_m / 2 / (111320 * cos($y * 3.14159265358979 / 180));
        next if grep { !_inside($_->[0], $_->[1], $geom) } ([ $x, $y ], [ $x - $dx, $y - $dy ], [ $x + $dx, $y - $dy ], [ $x - $dx, $y + $dy ], [ $x + $dx, $y + $dy ]);
        # not overlapping a square already drawn
        next if grep { abs($_->[0] - $x) < 2 * $dx && abs($_->[1] - $y) < 2 * $dy } @out;
        push @out, [ sprintf('%.6f', $x) + 0, sprintf('%.6f', $y) + 0 ];
    }
    return \@out;
}

=head2 faostat_prepare

Downloads the FAOSTAT bulk file and keeps the yields of the known crops in
the cache (faostat_yield.json: { area name (lower case) => { item => { year => kg/ha } } }).

=cut

sub faostat_prepare {
    my $self = shift;
    my $zip = $self->_cache('faostat.zip');
    my $out = $self->_cache('faostat_yield.json');
    return $out if -e $out && -M $out < 120;
    my $res = $self->ua->mirror($self->faostat_url, $zip);
    die "Could not download FAOSTAT: " . $res->status_line . "\n" if !$res->is_success && $res->code != 304;
    my %items = map { $CROPS{$_}[1] => 1 } keys %CROPS;
    my %data;
    open my $csv, '-|', 'unzip', '-p', $zip, 'Production_Crops_Livestock_E_All_Data_(Normalized).csv' or die "Cannot read the FAOSTAT file: $!\n";
    while (my $l = <$csv>) {
        next if index($l, '"5412"') < 0;
        my @f = map { s/^"|"$//gr } split /","/, $l =~ s/[\r\n]+$//r;
        # Area Code, M49, Area, Item Code, CPC, Item, Element Code, Element, Year Code, Year, Unit, Value, Flag, Note
        next if ($f[6] // '') ne '5412' || !$items{ $f[3] } || ($f[10] // '') ne 'kg/ha' || ($f[11] // '') !~ /^\d+(\.\d+)?$/ || $f[11] == 0;
        $data{ lc $f[2] }{ $f[3] }{ $f[9] } = $f[11] + 0;
    }
    close $csv;
    die "The FAOSTAT file has no yields.\n" if !%data;
    open my $o, '>', "$out.tmp" or die "Cannot write $out: $!\n";
    print $o encode_json(\%data);
    close $o;
    rename "$out.tmp", $out;
    unlink $zip;
    return $out;
}

sub _pick {
    my ($years, $year) = @_;
    my @y = sort { $a <=> $b } keys %$years;
    return if !@y;
    if ($year && exists $years->{$year}) {
        return ($years->{$year}, "$year");
    }
    my @last = @y > 5 ? @y[-5 .. -1] : @y;
    my $mean = 0;
    $mean += $years->{$_} for @last;
    $mean /= @last;
    return ($mean, @last > 1 ? "mean of $last[0]-$last[-1]" : "$last[0]");
}

=head2 Regional statistics providers

The site chooses its sources (sgn.conf satellite_regional_statistics, a
comma separated list in order of preference); FAOSTAT (national) is always
the last fallback:

  ibge         Brazil, IBGE PAM, municipalities (maize: summer / safrinha)
  nass         USA, USDA NASS Quick Stats, counties (needs satellite_nass_api_key)
  eurostat     Europe, Eurostat apro_cpshr, NUTS 2 regions (EU standard humidity)
  harveststat  Sub-Saharan Africa, HarvestStat Africa (FEWS NET admin units, seasons with planting month)
  fao          FAOSTAT, national

Every provider gives, for the training page: its units to choose (states,
countries), the yield of its regions per year and season with the sowing
window of that season (rows: { code, name, unit, year, season, planted_ha,
yield (kg/ha), area_km2, share, sow => [ from, to ] }), and the boundary of
each region (sample squares); for the index reference, the region holding a
point (B<lookup>).

=cut

our %PROVIDER = (
    ibge => { label => 'IBGE PAM (Brazil)', level => 'municipality', unit_label => 'State', units_max => 6,
              url => 'https://sidra.ibge.gov.br/tabela/1612' },
    nass => { label => 'USDA NASS (USA)', level => 'county', unit_label => 'State', units_max => 6,
              url => 'https://quickstats.nass.usda.gov' },
    eurostat => { label => 'Eurostat (Europe)', level => 'NUTS 2 region', unit_label => 'Country', units_max => 8,
                  url => 'https://ec.europa.eu/eurostat/databrowser/view/apro_cpshr/default/table' },
    harveststat => { label => 'HarvestStat Africa', level => 'admin unit', unit_label => 'Country', units_max => 8,
                     url => 'https://github.com/HarvestStat/HarvestStat-Africa' },
    fao => { label => 'FAOSTAT (national)', level => 'country', unit_label => 'Country', units_max => 40,
             url => 'https://www.fao.org/faostat/en/#data/QCL' },
);

# species -> [ NASS commodity, class / utilization (or undef), unit, kg/ha per unit ]
my %NASS_CROP = (
    'Zea mays' => [ 'CORN', 'GRAIN', 'BU / ACRE', 62.77 ], 'Glycine max' => [ 'SOYBEANS', undef, 'BU / ACRE', 67.25 ],
    'Triticum aestivum' => [ 'WHEAT', undef, 'BU / ACRE', 67.25 ], 'Sorghum bicolor' => [ 'SORGHUM', 'GRAIN', 'BU / ACRE', 62.77 ],
    'Hordeum vulgare' => [ 'BARLEY', undef, 'BU / ACRE', 53.80 ], 'Avena sativa' => [ 'OATS', undef, 'BU / ACRE', 35.87 ],
    'Oryza sativa' => [ 'RICE', undef, 'LB / ACRE', 1.1209 ], 'Nicotiana tabacum' => [ 'TOBACCO', undef, 'LB / ACRE', 1.1209 ],
    'Solanum tuberosum' => [ 'POTATOES', undef, 'CWT / ACRE', 112.09 ], 'Arachis hypogaea' => [ 'PEANUTS', undef, 'LB / ACRE', 1.1209 ],
    'Helianthus annuus' => [ 'SUNFLOWER', undef, 'LB / ACRE', 1.1209 ],
);
# species -> Eurostat apro_cpshr crop code
my %EUROSTAT_CROP = (
    'Zea mays' => 'C1500', 'Triticum aestivum' => 'C1110', 'Hordeum vulgare' => 'C1300', 'Avena sativa' => 'C1410',
    'Sorghum bicolor' => 'C1700', 'Oryza sativa' => 'C2000', 'Solanum tuberosum' => 'R1000', 'Helianthus annuus' => 'I1120',
    'Glycine max' => 'I1130', 'Nicotiana tabacum' => 'I3000',
);
# species -> HarvestStat products
my %HVSTAT_CROP = (
    'Zea mays' => [ 'Maize', 'Maize (Yellow)' ], 'Sorghum bicolor' => [ 'Sorghum', 'Sorghum (Red)' ], 'Glycine max' => [ 'Soybean' ],
    'Oryza sativa' => [ 'Rice' ], 'Triticum aestivum' => [ 'Wheat' ], 'Manihot esculenta' => [ 'Cassava' ], 'Nicotiana tabacum' => [ 'Tobacco' ],
    'Arachis hypogaea' => [ 'Groundnuts (In Shell)' ], 'Phaseolus vulgaris' => [ 'Beans (mixed)' ],
);
my @US_STATES = (
    [ '01', 'AL', 'Alabama' ], [ '04', 'AZ', 'Arizona' ], [ '05', 'AR', 'Arkansas' ], [ '06', 'CA', 'California' ], [ '08', 'CO', 'Colorado' ],
    [ '09', 'CT', 'Connecticut' ], [ '10', 'DE', 'Delaware' ], [ '12', 'FL', 'Florida' ], [ '13', 'GA', 'Georgia' ], [ '16', 'ID', 'Idaho' ],
    [ '17', 'IL', 'Illinois' ], [ '18', 'IN', 'Indiana' ], [ '19', 'IA', 'Iowa' ], [ '20', 'KS', 'Kansas' ], [ '21', 'KY', 'Kentucky' ],
    [ '22', 'LA', 'Louisiana' ], [ '23', 'ME', 'Maine' ], [ '24', 'MD', 'Maryland' ], [ '25', 'MA', 'Massachusetts' ], [ '26', 'MI', 'Michigan' ],
    [ '27', 'MN', 'Minnesota' ], [ '28', 'MS', 'Mississippi' ], [ '29', 'MO', 'Missouri' ], [ '30', 'MT', 'Montana' ], [ '31', 'NE', 'Nebraska' ],
    [ '32', 'NV', 'Nevada' ], [ '33', 'NH', 'New Hampshire' ], [ '34', 'NJ', 'New Jersey' ], [ '35', 'NM', 'New Mexico' ], [ '36', 'NY', 'New York' ],
    [ '37', 'NC', 'North Carolina' ], [ '38', 'ND', 'North Dakota' ], [ '39', 'OH', 'Ohio' ], [ '40', 'OK', 'Oklahoma' ], [ '41', 'OR', 'Oregon' ],
    [ '42', 'PA', 'Pennsylvania' ], [ '44', 'RI', 'Rhode Island' ], [ '45', 'SC', 'South Carolina' ], [ '46', 'SD', 'South Dakota' ],
    [ '47', 'TN', 'Tennessee' ], [ '48', 'TX', 'Texas' ], [ '49', 'UT', 'Utah' ], [ '50', 'VT', 'Vermont' ], [ '51', 'VA', 'Virginia' ],
    [ '53', 'WA', 'Washington' ], [ '54', 'WV', 'West Virginia' ], [ '55', 'WI', 'Wisconsin' ], [ '56', 'WY', 'Wyoming' ],
);
my %US_STATE = map { $_->[0] => $_ } @US_STATES;
my %US_COUNTRY = map { $_ => 1 } ('united states', 'united states of america', 'usa', 'us');

=head2 provider_list

The site's providers in order, FAOSTAT last: [ { id, label, level,
unit_label, units_max, available, why } ] (NASS is not available without its
key).

=cut

sub provider_list {
    my $self = shift;
    my %seen;
    my @ids = grep { $PROVIDER{$_} && !$seen{$_}++ } (map { lc } @{ $self->providers || [] }), 'fao';
    return [ map {
        my $p = $PROVIDER{$_};
        my $ok = $_ ne 'nass' || ($self->nass_key // '') =~ /\S/;
        { id => $_, label => $p->{label}, level => $p->{level}, unit_label => $p->{unit_label}, units_max => $p->{units_max}, url => $p->{url},
          available => ($ok ? 1 : 0), ($ok ? () : (why => 'needs satellite_nass_api_key in sgn_local.conf (free key from quickstats.nass.usda.gov)')) }
    } @ids ];
}

=head2 ready, prepare

ready(provider): its large files (HarvestStat data and boundaries, the
FAOSTAT bulk file, the NUTS and country boundaries) are in the cache.
prepare(provider): downloads them (minutes: run it in the background).

=cut

my %FILES = (harveststat => [ 'hvstat_africa.json', 'hvstat_africa_boundary.geojson' ], fao => [ 'faostat_yield.json', 'gisco_countries.geojson' ],
             eurostat => [ 'nuts2_2021.geojson', 'gisco_countries.geojson' ]);

sub ready {
    my ($self, $p) = @_;
    return !grep { !-e $self->_cache($_) } @{ $FILES{$p} || [] };
}

sub prepare {
    my ($self, $p) = @_;
    if ($p eq 'harveststat') { $self->_hvstat_rows; $self->_hvstat_geo }
    elsif ($p eq 'fao') { $self->faostat_prepare; $self->_gisco_countries }
    elsif ($p eq 'eurostat') { $self->_nuts2; $self->_gisco_countries }
    return 1;
}

=head2 units

Provider -> [ { code, uf (short), name } ]: what the training page offers
to choose (states, countries).

=cut

sub units {
    my ($self, $provider) = @_;
    return $self->brazil_states if $provider eq 'ibge';
    return [ map { { code => $_->[0], uf => $_->[1], name => $_->[2] } } @US_STATES ] if $provider eq 'nass';
    if ($provider eq 'eurostat') {
        my %names = map { $_->{properties}{CNTR_ID} => $_->{properties}{NAME_ENGL} } @{ $self->_gisco_countries->{features} || [] };
        my %c = map { $_->{properties}{CNTR_CODE} => 1 } @{ $self->_nuts2->{features} || [] };
        return [ sort { $a->{name} cmp $b->{name} } map { { code => $_, uf => $_, name => $names{ $_ eq 'EL' ? 'GR' : $_ eq 'UK' ? 'GB' : $_ } // $_ } } keys %c ];
    }
    if ($provider eq 'harveststat') {
        my %c;
        $c{ $_->[1] } //= $_->[0] for map { [ $_->{country}, $_->{country_code} ] } @{ $self->_hvstat_rows };
        return [ sort { $a->{name} cmp $b->{name} } map { { code => $_, uf => $_, name => $c{$_} } } keys %c ];
    }
    if ($provider eq 'fao') {
        return [ sort { $a->{name} cmp $b->{name} } map { { code => $_->{properties}{CNTR_ID}, uf => $_->{properties}{CNTR_ID}, name => $_->{properties}{NAME_ENGL} } }
                 grep { $_->{properties}{CNTR_ID} } @{ $self->_gisco_countries->{features} || [] } ];
    }
    return [];
}

=head2 regional_yields

Args: { provider (default ibge), species, units => [ codes ], years => [ harvest years ] }.
{ provider, crop, seasons (1 when split by crop season), rows => [ { code,
name, unit, year, season, season_label, planted_ha, yield (kg/ha),
area_km2, share, sow => [ from, to ] } ] (the largest share of the area
planted first), url, citation } or { error }.

=cut

sub regional_yields {
    my ($self, $args) = @_;
    my $p = $args->{provider} // 'ibge';
    return $self->_ibge_yields($args) if $p eq 'ibge';
    my $crop = $self->crop($args->{species}) // { species => $args->{species} // '', name => lc($args->{species} // '') };
    my @units = grep { /^[A-Za-z0-9]{1,6}$/ } @{ $args->{units} || [] };
    my @years = sort { $a <=> $b } grep { /^(19|20)\d\d$/ } @{ $args->{years} || [] };
    return { error => 'Choose at least one ' . lc($PROVIDER{$p}{unit_label} // 'unit') . '.' } if !@units;
    return { error => 'Choose at least one year.' } if !@years;
    my $res = try {
        $p eq 'nass' ? $self->_nass_yields($crop, \@units, \@years)
      : $p eq 'eurostat' ? $self->_eurostat_yields($crop, \@units, \@years)
      : $p eq 'harveststat' ? $self->_hvstat_yields($crop, \@units, \@years)
      : $p eq 'fao' ? $self->_fao_yields($crop, \@units, \@years)
      : { error => "Unknown source $p." };
    } catch { +{ error => "$PROVIDER{$p}{label}: $_" } };
    return $res if $res->{error};
    my @rows = sort { ($b->{share} // 0) <=> ($a->{share} // 0) || $a->{name} cmp $b->{name} || $a->{year} <=> $b->{year} } @{ $res->{rows} };
    return { provider => $p, crop => $crop->{name}, seasons => ($res->{seasons} ? 1 : 0), rows => \@rows, url => $PROVIDER{$p}{url}, citation => $res->{citation} };
}

# a row: share of the region planted with the crop, sowing window by latitude when the source has none
sub _finish_row {
    my ($self, $r, $geom) = @_;
    $r->{area_km2} = $geom ? _area_km2($geom) : undef;
    $r->{share} = ($r->{area_km2} && $r->{planted_ha}) ? $r->{planted_ha} / ($r->{area_km2} * 100) : undef;
    # no season reported: the summer (main) season, sown in the spring of its hemisphere
    if (!$r->{season}) { $r->{season} = 'summer'; $r->{season_label} = 'Summer (main season, assumed)' }
    if (!$r->{sow}) {
        my $lat = $geom ? _centre_lat($geom) : 45;
        my $y = $r->{year};
        # harvest year Y: north of the equator sown March-June of Y, south of it October-December of Y-1
        $r->{sow} = $lat >= 0 ? [ "$y-03-15", "$y-06-30" ] : [ ($y - 1) . '-10-01', ($y - 1) . '-12-31' ];
        $r->{sow_basis} = 'summer of its hemisphere (the source gives no sowing dates)';
    }
    return $r;
}

sub _centre_lat {
    my $geom = shift;
    my @polys = $geom->{type} eq 'Polygon' ? ($geom->{coordinates}) : @{ $geom->{coordinates} };
    my @y = sort { $a <=> $b } map { $_->[1] } map { @{ $_->[0] } } @polys;
    return @y ? ($y[0] + $y[-1]) / 2 : 0;
}

# --- USDA NASS: county yields and area planted (Quick Stats API, key needed); county boundaries from Census TIGERweb
sub _nass_get {
    my ($self, %q) = @_;
    die "no USDA NASS key (satellite_nass_api_key)\n" if ($self->nass_key // '') !~ /\S/;
    my $uri = URI->new($self->nass_url);
    $uri->query_form(key => $self->nass_key, source_desc => 'SURVEY', format => 'JSON', %q);
    my $name = 'nass_' . join('_', map { my $v = $q{$_}; $v =~ s/[^A-Za-z0-9]+/-/g; $v } sort keys %q) . '.json';
    my $body = try { $self->_get_cached($uri->as_string, $name, 30) } catch { my $e = $_; $e =~ s/key=[^&\s]+/key=.../g; die $e };
    my $d = decode_json($body);
    return $d->{data} || [];
}

sub _nass_yields {
    my ($self, $crop, $units, $years) = @_;
    my $c = $NASS_CROP{ $crop->{species} } or return { error => "USDA NASS: $crop->{name} is not set up." };
    my @rows;
    foreach my $fips (grep { $US_STATE{$_} } @$units) {
        my %base = (commodity_desc => $c->[0], agg_level_desc => 'COUNTY', state_fips_code => $fips, year__GE => $years->[0], year__LE => $years->[-1],
                    ($c->[1] ? (util_practice_desc => $c->[1]) : ()));
        my $y = $self->_nass_get(%base, statisticcat_desc => 'YIELD', unit_desc => $c->[2]);
        my $ar = try { $self->_nass_get(%base, statisticcat_desc => 'AREA PLANTED', unit_desc => 'ACRES', util_practice_desc => 'ALL UTILIZATION PRACTICES') } || [];
        my %area = map { ("$_->{county_code}|$_->{year}" => ($_->{Value} =~ s/,//gr)) } grep { ($_->{prodn_practice_desc} // '') =~ /ALL/ } @$ar;
        my $counties = $self->_us_counties($fips);
        my %want = map { $_ => 1 } @$years;
        foreach my $r (grep { ($_->{prodn_practice_desc} // '') =~ /ALL/ && $want{ $_->{year} } && ($_->{county_code} // '') =~ /^\d{3}$/ } @$y) {
            my $v = $r->{Value} =~ s/,//gr;
            next if $v !~ /^\d+(\.\d+)?$/;
            my $code = "$fips$r->{county_code}";
            my $ac = $area{"$r->{county_code}|$r->{year}"};
            push @rows, $self->_finish_row({ code => $code, name => ucfirst(lc $r->{county_name}) . " - $US_STATE{$fips}[1]", unit => $US_STATE{$fips}[1],
                year => $r->{year} + 0, yield => $v * $c->[3], planted_ha => (defined $ac && $ac =~ /^\d+$/ ? $ac * 0.404686 : undef) }, $counties->{$code});
        }
    }
    return { rows => \@rows, citation => "USDA NASS Quick Stats, $c->[0] yield by county ($c->[2] converted to kg/ha)" };
}

sub _us_counties {
    my ($self, $fips) = @_;
    my $url = $self->tiger_url . "/1/query?where=STATE%3D%27$fips%27&outFields=GEOID,NAME&returnGeometry=true&outSR=4326&f=geojson";
    my $d = decode_json($self->_get_cached($url, "us_counties_$fips.json", 365));
    return { map { $_->{properties}{GEOID} => $_->{geometry} } @{ $d->{features} || [] } };
}

sub _us_states_geo {
    my $self = shift;
    my $url = $self->tiger_url . "/0/query?where=1%3D1&outFields=STATE,STUSAB,NAME&returnGeometry=true&outSR=4326&maxAllowableOffset=0.01&f=geojson";
    my $d = decode_json($self->_get_cached($url, 'us_states.json', 365));
    return { map { $_->{properties}{STATE} => $_->{geometry} } @{ $d->{features} || [] } };
}

# --- Eurostat: NUTS 2 yields (t/ha, EU standard humidity) and areas (1000 ha); boundaries GISCO NUTS 2021
sub _eurostat_get {
    my ($self, $code, $country) = @_;
    # yield, area and production (many countries publish only area and production by region: yield = production / area)
    my $url = $self->eurostat_url . "?format=JSON&lang=EN&crops=$code&strucpro=YLD_HUMD_EU_T_HA&strucpro=AR_THS_HA&strucpro=HPRD_HUMD_EU_THS_T&geoLevel=nuts2";
    my $d = decode_json($self->_get_cached($url, "eurostat3_$code.json", 30));
    # JSON-stat: value index = position in the dimensions (freq, crops, strucpro, geo, time)
    my @ids = @{ $d->{id} }; my @size = @{ $d->{size} };
    my %pos = map { my $k = $_; $k => $d->{dimension}{$k}{category}{index} } @ids;
    my $label = $d->{dimension}{geo}{category}{label};
    my %out;
    foreach my $g (keys %{ $pos{geo} }) {
        next if $country && index($g, $country) != 0;
        foreach my $t (keys %{ $pos{time} }) {
            foreach my $sp (keys %{ $pos{strucpro} }) {
                my %at = (freq => 0, crops => 0, strucpro => $pos{strucpro}{$sp}, geo => $pos{geo}{$g}, time => $pos{time}{$t});
                my $i = 0;
                for my $k (0 .. $#ids) { $i = $i * $size[$k] + ($at{ $ids[$k] } // 0) }
                my $v = $d->{value}{$i};
                $out{$g}{$t}{$sp} = $v if defined $v;
            }
        }
        next if !$out{$g};
        foreach my $t (grep { /^\d{4}$/ } keys %{ $out{$g} }) {
            my $v = $out{$g}{$t};
            $v->{YLD_HUMD_EU_T_HA} //= $v->{HPRD_HUMD_EU_THS_T} / $v->{AR_THS_HA} if $v->{AR_THS_HA} && defined $v->{HPRD_HUMD_EU_THS_T};
        }
        $out{$g}{name} = $label->{$g};
    }
    return \%out;
}

sub _nuts2 {
    my $self = shift;
    return $self->{_nuts2} //= decode_json($self->_get_cached($self->gisco_url . '/nuts/geojson/NUTS_RG_10M_2021_4326_LEVL_2.geojson', 'nuts2_2021.geojson', 365));
}

sub _eurostat_yields {
    my ($self, $crop, $units, $years) = @_;
    my $code = $EUROSTAT_CROP{ $crop->{species} } or return { error => "Eurostat: $crop->{name} is not set up." };
    my %geo = map { $_->{properties}{NUTS_ID} => $_->{geometry} } @{ $self->_nuts2->{features} || [] };
    my @rows;
    foreach my $cc (@$units) {
        my $data = $self->_eurostat_get($code, $cc);
        foreach my $g (keys %$data) {
            foreach my $y (@$years) {
                my $v = $data->{$g}{$y} or next;
                next if !$v->{YLD_HUMD_EU_T_HA};
                push @rows, $self->_finish_row({ code => $g, name => "$data->{$g}{name} ($g)", unit => $cc, year => $y + 0,
                    yield => $v->{YLD_HUMD_EU_T_HA} * 1000, planted_ha => ($v->{AR_THS_HA} ? $v->{AR_THS_HA} * 1000 : undef) }, $geo{$g});
            }
        }
    }
    return { rows => \@rows, citation => "Eurostat apro_cpshr, crop production in EU standard humidity by NUTS 2 region ($code), yield (t/ha x 1000)" };
}

# --- HarvestStat Africa: admin-unit yields (t/ha) with season, planting and harvest months; FEWS NET boundaries
sub _hvstat_rows {
    my $self = shift;
    return $self->{_hvstat} if $self->{_hvstat};
    my $json = $self->_cache('hvstat_africa.json');
    if (!-e $json || -M $json > 120) {
        my $csv = $self->_cache('hvstat_africa_data.csv');
        my $res = $self->ua->mirror($self->harveststat_url . '/hvstat_africa_data_v1.2.csv', $csv);
        die "Could not download HarvestStat Africa: " . $res->status_line . "\n" if !$res->is_success && $res->code != 304;
        my %want = map { $_ => 1 } map { @$_ } values %HVSTAT_CROP;
        open my $fh, '<', $csv or die "Cannot read $csv: $!\n";
        my $head = <$fh>; chomp $head;
        my @h = split /,/, $head;
        my @rows;
        while (my $l = <$fh>) {
            chomp $l;
            my %r; @r{@h} = split /,/, $l, -1;    # no quoted commas in this file
            next if !$want{ $r{product} } || ($r{qc_flag} // '') eq '1' || ($r{yield} // '') !~ /^\d+(\.\d+)?$/ || $r{yield} == 0;
            push @rows, { map { $_ => $r{$_} } qw(fnid country country_code admin_1 admin_2 product season_name planting_year planting_month harvest_year harvest_month crop_production_system area yield) };
        }
        close $fh;
        open my $o, '>', "$json.tmp" or die "Cannot write $json: $!\n"; print $o encode_json(\@rows); close $o;
        rename "$json.tmp", $json;
    }
    open my $fh, '<', $json or die "Cannot read $json: $!\n";
    local $/;
    return $self->{_hvstat} = decode_json(<$fh>);
}

sub _hvstat_geo {
    my $self = shift;
    return $self->{_hvstat_geo} if $self->{_hvstat_geo};
    my $gj = $self->_cache('hvstat_africa_boundary.geojson');
    if (!-e $gj) {
        my $gpkg = $self->_cache('hvstat_africa_boundary.gpkg');
        my $res = $self->ua->mirror($self->harveststat_url . '/hvstat_africa_boundary_v1.2.gpkg', $gpkg);
        die "Could not download the HarvestStat boundaries: " . $res->status_line . "\n" if !$res->is_success && $res->code != 304;
        # GeoPackage -> GeoJSON (GDAL), simplified to about 1 km
        system('ogr2ogr', '-f', 'GeoJSON', '-simplify', '0.01', "$gj.tmp", $gpkg) == 0 or die "ogr2ogr could not read the HarvestStat boundaries\n";
        rename "$gj.tmp", $gj;
    }
    my $d = do { open my $fh, '<', $gj or die "Cannot read $gj: $!\n"; local $/; decode_json(<$fh>) };
    return $self->{_hvstat_geo} = { map { $_->{properties}{fnid} => $_->{geometry} } @{ $d->{features} || [] } };
}

sub _hvstat_yields {
    my ($self, $crop, $units, $years) = @_;
    my $products = $HVSTAT_CROP{ $crop->{species} } or return { error => "HarvestStat Africa: $crop->{name} is not set up." };
    my %prod = map { $_ => 1 } @$products;
    my %cc = map { $_ => 1 } @$units;
    my %yr = map { $_ => 1 } @$years;
    my $geo = $self->_hvstat_geo;
    my (%best, @rows);
    foreach my $r (@{ $self->_hvstat_rows }) {
        next if !$prod{ $r->{product} } || !$cc{ $r->{country_code} } || !$yr{ $r->{harvest_year} };
        # one value per unit, season and year: all production systems first
        my $k = join('|', $r->{fnid}, $r->{season_name}, $r->{harvest_year});
        my $rank = $r->{crop_production_system} =~ /^All|^none/ ? 0 : 1;
        next if $best{$k} && $best{$k}[0] <= $rank;
        $best{$k} = [ $rank, $r ];
    }
    my $days = sub { my ($y, $m) = @_; return (31, (($y % 4 == 0 && $y % 100) || $y % 400 == 0) ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31)[ $m - 1 ] };
    foreach my $b (values %best) {
        my $r = $b->[1];
        my ($py, $pm) = ($r->{planting_year}, $r->{planting_month});
        my $sow = ($py =~ /^\d{4}$/ && $pm =~ /^\d{1,2}$/) ? [ sprintf('%04d-%02d-01', $py, $pm), sprintf('%04d-%02d-%02d', $py, $pm, $days->($py, $pm)) ] : undef;
        my $season = lc($r->{season_name} // 'main'); $season =~ s/[^a-z0-9]+/_/g;
        push @rows, $self->_finish_row({ code => $r->{fnid}, name => join(' - ', grep { $_ && $_ ne 'none' } $r->{admin_2}, $r->{admin_1}, $r->{country_code}),
            unit => $r->{country_code}, year => $r->{harvest_year} + 0, season => $season, season_label => $r->{season_name},
            yield => $r->{yield} * 1000, planted_ha => ($r->{area} =~ /^\d+(\.\d+)?$/ ? $r->{area} + 0 : undef), sow => $sow }, $geo->{ $r->{fnid} });
    }
    return { rows => \@rows, seasons => 1, citation => 'HarvestStat Africa v1.2 (Lee et al. 2025, Scientific Data), harmonized subnational crop statistics from FEWS NET, yield (t/ha x 1000)' };
}

# --- FAOSTAT: national yields; country boundaries GISCO
sub _gisco_countries {
    my $self = shift;
    return $self->{_gisco} //= decode_json($self->_get_cached($self->gisco_url . '/countries/geojson/CNTR_RG_10M_2020_4326.geojson', 'gisco_countries.geojson', 365));
}

# FAOSTAT area name -> GISCO country (by name, without the bracketed parts, with a few aliases)
my %FAO_ALIAS = ('united states of america' => 'united states', 'viet nam' => 'vietnam', 'russian federation' => 'russia', 'united republic of tanzania' => 'tanzania',
    'republic of korea' => 'south korea', "democratic people's republic of korea" => 'north korea', "lao people's democratic republic" => 'laos',
    'syrian arab republic' => 'syria', 'republic of moldova' => 'moldova', 'turkiye' => 'turkey', 'czechia' => 'czech republic',
    'united kingdom of great britain and northern ireland' => 'united kingdom', 'netherlands (kingdom of the)' => 'netherlands', 'china, mainland' => 'china',
    );
sub _norm_country { my $n = lc(shift // ''); $n = $FAO_ALIAS{$n} // $n; $n =~ s/\s*\(.*?\)//g; $n =~ s/^the //; return $n }

sub _fao_yields {
    my ($self, $crop, $units, $years) = @_;
    return { error => 'FAOSTAT: this crop is not set up.' } if !$crop->{fao};
    my $file = $self->faostat_prepare();
    my $data = do { open my $fh, '<', $file or die; local $/; decode_json(<$fh>) };
    my %by_name = map { _norm_country($_) => $data->{$_} } keys %$data;
    my %feat = map { $_->{properties}{CNTR_ID} => $_ } @{ $self->_gisco_countries->{features} || [] };
    my @rows;
    foreach my $cc (@$units) {
        my $f = $feat{$cc} or next;
        my $yrs = (($by_name{ _norm_country($f->{properties}{NAME_ENGL}) } || {})->{ $crop->{fao} }) || {};
        foreach my $y (@$years) {
            next if !$yrs->{$y};
            push @rows, $self->_finish_row({ code => $cc, name => $f->{properties}{NAME_ENGL}, unit => $cc, year => $y + 0, yield => $yrs->{$y} }, $f->{geometry});
        }
    }
    return { rows => \@rows, citation => 'FAO. FAOSTAT: Production - Crops and livestock products, Yield (kg/ha), national' };
}

=head2 region_geometry

Provider, region code -> GeoJSON geometry of the region (or undef).

=cut

sub region_geometry {
    my ($self, $p, $code) = @_;
    return $self->_municipalities(int($code / 100000))->{$code} if $p eq 'ibge';
    return $self->_us_counties(substr($code, 0, 2))->{$code} if $p eq 'nass';
    if ($p eq 'eurostat') { my ($f) = grep { $_->{properties}{NUTS_ID} eq $code } @{ $self->_nuts2->{features} || [] }; return $f && $f->{geometry} }
    return $self->_hvstat_geo->{$code} if $p eq 'harveststat';
    if ($p eq 'fao') { my ($f) = grep { ($_->{properties}{CNTR_ID} // '') eq $code } @{ $self->_gisco_countries->{features} || [] }; return $f && $f->{geometry} }
    return;
}

=head2 lookup

Args: { lon, lat, species, country (name), year (of the season), no_download }.
The reference of the first of the site's sources that covers the point (the
region holding it, or its state / country), FAOSTAT national otherwise: {
source, level, area, crop, unit => 'kg/ha', value, years, basis, url,
citation } or { error }. no_download: do not fetch large files now ({
pending => 1 }).

=cut

sub lookup {
    my ($self, $q) = @_;
    my $crop = $self->crop($q->{species}) or return { error => 'No public yield statistics are known for this crop.' };
    return { error => 'No coordinates.' } if !defined $q->{lon} || !defined $q->{lat};
    my @tried;
    foreach my $p (map { $_->{id} } grep { $_->{available} } @{ $self->provider_list }) {
        my $r = try {
            $p eq 'ibge' ? $self->_ibge_lookup($crop, $q)
          : $p eq 'nass' ? $self->_nass_lookup($crop, $q)
          : $p eq 'eurostat' ? $self->_eurostat_lookup($crop, $q)
          : $p eq 'harveststat' ? ($q->{no_download} && !-e $self->_cache('hvstat_africa.json') ? undef : $self->_hvstat_lookup($crop, $q))
          : $p eq 'fao' ? $self->_fao_lookup($crop, $q) : undef;
        } catch { +{ error => "$PROVIDER{$p}{label}: $_" } };
        return $r if $r && !$r->{error};
        push @tried, $r->{error} if $r && $r->{error};
    }
    return { error => join(' ', @tried) || 'No regional statistics for this place.' };
}

# a reference from a region's yields by year
sub _ref {
    my ($self, $p, $level, $area, $code, $crop, $years, $year, $citation) = @_;
    return if !%$years;
    my ($value, $basis) = _pick($years, $year);
    return { source => $PROVIDER{$p}{label}, provider => $p, level => $level, area => $area, area_code => $code, crop => $crop->{name}, unit => 'kg/ha',
             value => $value, basis => $basis, years => $years, url => $PROVIDER{$p}{url}, citation => $citation };
}

sub _ibge_lookup {
    my ($self, $crop, $q) = @_;
    my $br = $self->brazil_unit($q->{lon}, $q->{lat}) or return;    # not in Brazil
    my ($level, $res, $code);
    if ($br->{mun_code}) {
        $res = $self->_sidra('n6', $br->{mun_code}, $crop->{ibge});
        ($level, $code) = ('municipality', $br->{mun_code}) if %{ $res->{years} };
    }
    if (!$level) {
        $res = $self->_sidra('n3', $br->{uf_code}, $crop->{ibge});
        ($level, $code) = ('state', $br->{uf_code}) if %{ $res->{years} };
    }
    return { error => "IBGE has no $crop->{name} yield for this municipality or its state." } if !$level;
    return $self->_ref('ibge', $level, $res->{name}, $code + 0, $crop, $res->{years}, $q->{year},
        'IBGE - Producao Agricola Municipal (PAM), table 1612, average yield (kg/ha)');
}

sub _nass_lookup {
    my ($self, $crop, $q) = @_;
    return if !$US_COUNTRY{ lc($q->{country} // '') };
    my $c = $NASS_CROP{ $crop->{species} } or return { error => "USDA NASS: $crop->{name} is not set up." };
    my $states = $self->_us_states_geo;
    my ($fips) = grep { _inside($q->{lon}, $q->{lat}, $states->{$_}) } keys %$states;
    return if !$fips || !$US_STATE{$fips};
    my $counties = $self->_us_counties($fips);
    my ($geoid) = grep { _inside($q->{lon}, $q->{lat}, $counties->{$_}) } keys %$counties;
    my $y1 = ($q->{year} // (localtime)[5] + 1900);
    my %q = (commodity_desc => $c->[0], state_fips_code => $fips, year__GE => $y1 - 6, year__LE => $y1, statisticcat_desc => 'YIELD', unit_desc => $c->[2],
             ($c->[1] ? (util_practice_desc => $c->[1]) : ()));
    foreach my $lvl ($geoid ? ([ 'COUNTY', substr($geoid, 2) ]) : (), [ 'STATE', undef ]) {
        my $rows = $self->_nass_get(%q, agg_level_desc => $lvl->[0]);
        my %years = map { ($_->{year} => ($_->{Value} =~ s/,//gr) * $c->[3]) } grep { ($_->{prodn_practice_desc} // '') =~ /ALL/ && $_->{Value} =~ /^[\d,.]+$/ && (!$lvl->[1] || ($_->{county_code} // '') eq $lvl->[1]) } @$rows;
        my $name = $lvl->[1] ? ((map { ucfirst(lc $_->{county_name}) } grep { ($_->{county_code} // '') eq $lvl->[1] } @$rows)[0] // $geoid) . " - $US_STATE{$fips}[1]" : $US_STATE{$fips}[2];
        my $r = $self->_ref('nass', lc $lvl->[0], $name, ($lvl->[1] ? $geoid : $fips), $crop, \%years, $q->{year}, "USDA NASS Quick Stats, $c->[0] yield ($c->[2] converted to kg/ha)");
        return $r if $r;
    }
    return { error => "USDA NASS has no $crop->{name} yield for this county or its state." };
}

sub _eurostat_lookup {
    my ($self, $crop, $q) = @_;
    my $code = $EUROSTAT_CROP{ $crop->{species} } or return;
    my ($f) = grep { _inside($q->{lon}, $q->{lat}, $_->{geometry}) } @{ $self->_nuts2->{features} || [] };
    return if !$f;    # not in a NUTS 2 region
    my $g = $f->{properties}{NUTS_ID};
    my $data = $self->_eurostat_get($code, $f->{properties}{CNTR_CODE});
    my %years = map { ($_ => $data->{$g}{$_}{YLD_HUMD_EU_T_HA} * 1000) } grep { /^\d{4}$/ && $data->{$g}{$_}{YLD_HUMD_EU_T_HA} } keys %{ $data->{$g} || {} };
    return $self->_ref('eurostat', 'NUTS 2 region', ($data->{$g}{name} // $f->{properties}{NAME_LATN}) . " ($g)", $g, $crop, \%years, $q->{year},
        "Eurostat apro_cpshr, crop production in EU standard humidity by NUTS 2 region ($code)") // { error => "Eurostat has no $crop->{name} yield for $g." };
}

sub _hvstat_lookup {
    my ($self, $crop, $q) = @_;
    my $products = $HVSTAT_CROP{ $crop->{species} } or return;
    my $geo = $self->_hvstat_geo;
    my ($fnid) = grep { _inside($q->{lon}, $q->{lat}, $geo->{$_}) } keys %$geo;
    return if !$fnid;
    my %prod = map { $_ => 1 } @$products;
    my %by_season;
    foreach my $r (grep { $_->{fnid} eq $fnid && $prod{ $_->{product} } } @{ $self->_hvstat_rows }) {
        $by_season{ $r->{season_name} }{ $r->{harvest_year} } //= $r->{yield} * 1000;
    }
    return { error => "HarvestStat Africa has no $crop->{name} yield for this unit." } if !%by_season;
    # the main season (the one with the most years)
    my ($s) = sort { keys %{ $by_season{$b} } <=> keys %{ $by_season{$a} } } keys %by_season;
    my ($row) = grep { $_->{fnid} eq $fnid } @{ $self->_hvstat_rows };
    return $self->_ref('harveststat', "admin unit, $s season", join(' - ', grep { $_ && $_ ne 'none' } $row->{admin_2}, $row->{admin_1}, $row->{country}), $fnid, $crop,
        $by_season{$s}, $q->{year}, 'HarvestStat Africa v1.2 (FEWS NET), yield (t/ha x 1000)');
}

sub _fao_lookup {
    my ($self, $crop, $q) = @_;
    my $country = lc($q->{country} // '');
    return { error => 'The country of this location is not known (set it in Manage > Locations).' } if !$country;
    my $file = $self->_cache('faostat_yield.json');
    if (!-e $file) {
        return { pending => 1, source => 'FAOSTAT', level => 'country', crop => $crop->{name} } if $q->{no_download};
        $self->faostat_prepare();
    }
    my $data = do { open my $fh, '<', $file or die; local $/; decode_json(<$fh>) };
    my ($k) = grep { _norm_country($_) eq _norm_country($country) } keys %$data;
    my $years = (($data->{ $k // $country } || {})->{ $crop->{fao} }) || {};
    return $self->_ref('fao', 'country', $q->{country}, undef, $crop, $years, $q->{year}, 'FAO. FAOSTAT: Production - Crops and livestock products, Yield (kg/ha)')
        // { error => "FAOSTAT has no $crop->{name} yield for $q->{country}." };
}

1;
