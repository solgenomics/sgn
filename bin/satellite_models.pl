#!/usr/bin/env perl

=head1 NAME

satellite_models.pl - background job of the Satellite page models (step 5)

=head1 SYNOPSIS

  perl -Ilib bin/satellite_models.pl <run base>

=head1 DESCRIPTION

Reads <run base>.request.json (written by SGN::Controller::AJAX::Satellite
run), searches the Sentinel-2 scenes of every site (its square, the analysis
dates) and of every calibration field (its own season) with CXGN::Satellite,
writes <run base>.input.json and runs R/satellite/satellite_models.R, which
writes <run base>.results.json. Calibration fields with the same season that
lie within 3 km of each other get one search and the same scenes, so the R
script reads them together. Progress lines start with "[satellite]". The exit
status of R is written to <run base>.exit.

=head1 AUTHOR

Chris Simoes

=cut

use strict;
use warnings;
use JSON;
use File::Basename qw(dirname);
use File::Spec;
use CXGN::Satellite;
use CXGN::Satellite::Reference;

my $base = shift or die "usage: satellite_models.pl <run base>\n";
$| = 1;
sub say_progress { print "[satellite] ", @_, "\n" }

my $req = decode_json(do { local $/; open my $fh, '<', "$base.request.json" or die "Cannot read $base.request.json: $!\n"; <$fh> });
my %args;
$args{stac_url} = $req->{stac_url} if $req->{stac_url};
$args{max_days} = $req->{max_days} if $req->{max_days};
my $sat = CXGN::Satellite->new(\%args);

my %cache;
sub sentinel2 {
    my ($bbox, $start, $end) = @_;
    my $key = join(',', (map { sprintf('%.5f', $_) } @$bbox), $start, $end);
    return $cache{$key} if $cache{$key};
    my $r = $sat->scenes({ bbox => $bbox, start => $start, end => $end, sources => [ 'sentinel2' ] });
    die "Sentinel-2 search failed: $r->{error}\n" if $r->{error};
    my @sc = map { my %s = %$_; delete @s{qw(visual tile_cloud covers platform datetime)}; \%s } grep { ($_->{source} // '') eq 'sentinel2' } @{ $r->{scenes} };
    return $cache{$key} = \@sc;
}

sub ring_box {
    my @pts = map { @$_ } @_;
    my @lon = sort { $a <=> $b } map { $_->[0] } @pts;
    my @lat = sort { $a <=> $b } map { $_->[1] } @pts;
    return [ $lon[0], $lat[0], $lon[-1], $lat[-1] ];
}

sub span_m {
    my $b = shift;
    my $lat = ($b->[1] + $b->[3]) / 2;
    my $x = ($b->[2] - $b->[0]) * 111320 * cos($lat * 3.14159265358979 / 180);
    my $y = ($b->[3] - $b->[1]) * 110574;
    return $x > $y ? $x : $y;
}

sub pad {
    my ($b, $m) = @_;
    my $lat = ($b->[1] + $b->[3]) / 2;
    my $dx = $m / (111320 * cos($lat * 3.14159265358979 / 180));
    my $dy = $m / 110574;
    return [ $b->[0] - $dx, $b->[1] - $dy, $b->[2] + $dx, $b->[3] + $dy ];
}

my $ok = eval {
    my $sites = $req->{sites} || [];
    my $i = 0;
    foreach my $s (@$sites) {
        $i++;
        say_progress("searching the Sentinel-2 images of $s->{name} ($i/" . scalar(@$sites) . ")");
        my %hidden = map { $_ => 1 } @{ $s->{exclude_scenes} || [] };
        my @all = @{ sentinel2($s->{bbox}, $req->{dates}{start}, $req->{dates}{end}) };
        $s->{scenes} = [ grep { !$hidden{ $_->{id} } } @all ];
        $s->{hidden} = @all - @{ $s->{scenes} };
        delete $s->{exclude_scenes};
        say_progress(scalar(@{ $s->{scenes} }) . " dates for $s->{name}" . ($s->{hidden} ? " ($s->{hidden} hidden by you left out)" : ''));
    }
    # yield index turned into approximate kg/ha: the public average yield around each location
    if (($req->{yield}{mode} // '') eq 'index' && $req->{yield}{reference}) {
        my $refs = CXGN::Satellite::Reference->new({ cache_dir => dirname($base) });
        my ($year) = ($req->{yield}{season}{end} // '') =~ /^(\d{4})/;
        foreach my $s (@$sites) {
            say_progress("regional average yield for $s->{name}");
            my $r = eval { $refs->lookup({ lon => $s->{center}[0], lat => $s->{center}[1], species => $req->{crop}, country => $s->{country}, year => $year }) } || { error => "$@" };
            $s->{reference} = $r;
            say_progress($r->{error} ? "no regional reference for $s->{name}: $r->{error}" : "reference for $s->{name}: $r->{source} $r->{area} $r->{value} kg/ha ($r->{basis})");
        }
    }
    my $calib = $req->{calibration} || [];
    if (@$calib) {
        # group: same season, within 3 km (as the R script)
        my %by_season;
        push @{ $by_season{"$_->{start}|$_->{end}"} }, $_ for @$calib;
        my @groups;
        foreach my $k (sort keys %by_season) {
            my @pending = @{ $by_season{$k} };
            while (@pending) {
                my @g = (shift @pending);
                my $box = ring_box($g[0]{ring});
                my @rest;
                foreach my $cf (@pending) {
                    my $cand = ring_box([ [ $box->[0], $box->[1] ], [ $box->[2], $box->[3] ] ], $cf->{ring});
                    if (span_m($cand) <= 3000) { push @g, $cf; $box = $cand } else { push @rest, $cf }
                }
                @pending = @rest;
                push @groups, [ $box, @g ];
            }
        }
        my $n = 0;
        foreach my $g (@groups) {
            my ($box, @fields) = @$g;
            $n++;
            say_progress("searching the images of calibration group $n/" . scalar(@groups) . " (" . join(', ', map { $_->{name} } @fields) . ")");
            my $sc = sentinel2(pad($box, 100), $fields[0]{start}, $fields[0]{end});
            $_->{scenes} = $sc for @fields;
        }
    }
    my $input = { %$req };
    delete @{$input}{qw(stac_url max_days)};
    open my $out, '>', "$base.input.json" or die "Cannot write $base.input.json: $!\n";
    print $out encode_json($input);
    close $out;
    1;
};
if (!$ok) {
    print "Error: $@";
    open my $fh, '>', "$base.exit"; print $fh "1\n"; close $fh;
    exit 1;
}

my $script = File::Spec->catfile(dirname(__FILE__), '..', 'R', 'satellite', 'satellite_models.R');
my $rc = system('Rscript', $script, "$base.input.json", $base);
my $code = $rc == -1 ? 127 : ($rc & 127) ? 128 + ($rc & 127) : $rc >> 8;
open my $fh, '>', "$base.exit"; print $fh "$code\n"; close $fh;
exit $code;
