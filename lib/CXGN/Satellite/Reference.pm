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

=head2 regional_yields

Args: { species, uf_codes => [ 31, 52 ], years => [ 2023, 2024 ] }. The IBGE
PAM yield of every municipality of the states that grew the crop in those
years: { crop, table, seasons (1 when split by crop season), rows => [ {
mun_code, name, uf, year, season, planted_ha, yield, area_km2, share } ] }
(share = planted area / municipality area, the most first) or { error }.
Maize is split by crop season (table 839: 1st crop = summer, 2nd crop =
safrinha); other crops have one value per year (table 1612, season 'year').

=cut

sub regional_yields {
    my ($self, $args) = @_;
    my $crop = $self->crop($args->{species}) or return { error => 'IBGE has no yield statistics for this crop.' };
    my @ufs = grep { $UF{$_} } map { $_ + 0 } grep { /^\d+$/ } @{ $args->{uf_codes} || [] };
    my @years = sort { $a <=> $b } grep { /^(19|20)\d\d$/ } @{ $args->{years} || [] };
    return { error => 'Choose at least one state.' } if !@ufs;
    return { error => 'Choose at least one year.' } if !@years;
    my $maize = $crop->{name} eq 'maize';
    my ($table, %season) = $maize ? (839, 114253 => 'summer', 114254 => 'safrinha') : (1612, $crop->{ibge} => 'year');
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
        push @out, $r;
    }
    @out = sort { ($b->{share} // 0) <=> ($a->{share} // 0) || $a->{name} cmp $b->{name} || $a->{year} <=> $b->{year} || $a->{season} cmp $b->{season} } @out;
    return { crop => $crop->{name}, table => $table, seasons => ($maize ? 1 : 0), rows => \@out,
             url => "https://sidra.ibge.gov.br/tabela/$table",
             citation => $maize ? 'IBGE - Producao Agricola Municipal (PAM), table 839, maize 1st and 2nd crop, average yield (kg/ha)'
                                : 'IBGE - Producao Agricola Municipal (PAM), table 1612, average yield (kg/ha)' };
}

=head2 sample_squares

Args: municipality code, number of squares, square size (m), seed. Centres [
[ lon, lat ], ... ] of squares lying inside the municipality (centre and
corners), drawn at random (the same for the same seed); fewer when the
municipality is too small or too irregular.

=cut

sub sample_squares {
    my ($self, $mun_code, $n, $size_m, $seed) = @_;
    my $geom = $self->_municipalities(int($mun_code / 100000))->{$mun_code} or return [];
    my @polys = $geom->{type} eq 'Polygon' ? ($geom->{coordinates}) : @{ $geom->{coordinates} };
    my @pts = map { @{ $_->[0] } } @polys;
    my ($x0, $x1) = (sort { $a <=> $b } map { $_->[0] } @pts)[0, -1];
    my ($y0, $y1) = (sort { $a <=> $b } map { $_->[1] } @pts)[0, -1];
    srand($seed // 1);
    my @out;
    for (my $try = 0; $try < 400 && @out < $n; $try++) {
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

=head2 lookup

Args: { lon, lat, species, country (name), year (of the season), no_download }.
The reference, or { error } (unknown crop, no published value, source
unreachable). no_download: do not fetch FAOSTAT now ({ pending => 1 } when
it is not in the cache yet).

=cut

sub lookup {
    my ($self, $a) = @_;
    my $crop = $self->crop($a->{species}) or return { error => 'No public yield statistics are known for this crop.' };
    my ($lon, $lat) = ($a->{lon}, $a->{lat});
    return { error => 'No coordinates.' } if !defined $lon || !defined $lat;
    my $br = try { $self->brazil_unit($lon, $lat) } catch { return { error => "IBGE boundaries: $_" } };
    return $br if ref $br eq 'HASH' && $br->{error};
    if ($br) {
        my $r = try {
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
            my ($value, $basis) = _pick($res->{years}, $a->{year});
            return {
                source => 'IBGE PAM', level => $level, area => $res->{name}, area_code => $code + 0, crop => $crop->{name}, unit => 'kg/ha',
                value => $value, basis => $basis, years => $res->{years},
                url => "https://sidra.ibge.gov.br/tabela/1612",
                citation => 'IBGE - Producao Agricola Municipal (PAM), table 1612, average yield (kg/ha)',
            };
        } catch { +{ error => "IBGE SIDRA: $_" } };
        return $r;
    }
    my $country = lc($a->{country} // '');
    return { error => 'The country of this location is not known (set it in Manage > Locations).' } if !$country;
    my $file = $self->_cache('faostat_yield.json');
    if (!-e $file) {
        return { pending => 1, source => 'FAOSTAT', level => 'country', crop => $crop->{name} } if $a->{no_download};
        my $ok = try { $self->faostat_prepare(); 1 } catch { return { error => "FAOSTAT: $_" } };
        return $ok if ref $ok eq 'HASH';
    }
    my $data = try { open my $fh, '<', $file or die; local $/; decode_json(<$fh>) } || {};
    my $years = (($data->{$country} || {})->{ $crop->{fao} }) || {};
    return { error => "FAOSTAT has no $crop->{name} yield for $a->{country}." } if !%$years;
    my ($value, $basis) = _pick($years, $a->{year});
    return {
        source => 'FAOSTAT', level => 'country', area => $a->{country}, crop => $crop->{name}, unit => 'kg/ha',
        value => $value, basis => $basis, years => $years, url => 'https://www.fao.org/faostat/en/#data/QCL',
        citation => 'FAO. FAOSTAT: Production - Crops and livestock products, Yield (kg/ha)',
    };
}

1;
