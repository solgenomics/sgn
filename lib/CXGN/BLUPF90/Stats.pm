package CXGN::BLUPF90::Stats;

=head1 NAME

CXGN::BLUPF90::Stats - small statistics toolbox of the BLUPF90+ analysis engine

=head1 SYNOPSIS

  use CXGN::BLUPF90::Stats qw(mean median quantile7 mad holm pnorm_upper pf_upper);

=head1 DESCRIPTION

Pure-Perl helpers used by L<CXGN::BLUPF90::Pipeline>: descriptive
statistics with the same definitions as R (sample variance, type 7
quantiles, MAD with constant 1.4826, Holm adjustment), the normal and F
upper tail probabilities, Pearson correlation, average-linkage
hierarchical clustering and least squares residuals of additive factor
models (backfitting). Every linear mixed model is solved by blupf90+
(L<CXGN::BLUPF90>), not here.

Missing values are undef and are skipped by the descriptive functions.

=head1 AUTHOR

Chris Simoes <ccs263@cornell.edu>

=cut

use strict;
use warnings;
# missing value (undef), returned by functions that are used in scalar and list context
use constant NA => undef;
use List::Util qw(sum min max);
use POSIX qw(floor);
use Exporter 'import';

our @EXPORT_OK = qw(defined_only mean var sd median quantile7 mad holm harmonic_mean
                    pnorm_upper pf_upper cor hclust_average cutree_height backfit n_levels uniq);

sub defined_only { return grep { defined($_) } @_; }

sub uniq {
    my %seen;
    return grep { defined($_) && !$seen{$_}++ } @_;
}

# number of distinct non-missing, non-empty values
sub n_levels {
    my %seen;
    $seen{$_} = 1 for grep { defined($_) && $_ ne '' } @_;
    return scalar(keys %seen);
}

sub mean {
    my @x = defined_only(@_);
    return NA if !@x;
    return sum(@x) / @x;
}

# sample variance (n - 1), as R var()
sub var {
    my @x = defined_only(@_);
    return NA if @x < 2;
    my $m = sum(@x) / @x;
    return sum(map { ($_ - $m)**2 } @x) / (@x - 1);
}

sub sd {
    my $v = var(@_);
    return defined($v) ? sqrt($v) : undef;
}

sub median {
    my @x = sort { $a <=> $b } defined_only(@_);
    return NA if !@x;
    my $n = @x;
    return $n % 2 ? $x[($n - 1) / 2] : ($x[$n / 2 - 1] + $x[$n / 2]) / 2;
}

# R quantile(type = 7)
sub quantile7 {
    my ($p, @x) = @_;
    @x = sort { $a <=> $b } defined_only(@x);
    return NA if !@x;
    my $h = (@x - 1) * $p;
    my $lo = floor($h);
    my $hi = $lo + 1 > $#x ? $#x : $lo + 1;
    return $x[$lo] + ($h - $lo) * ($x[$hi] - $x[$lo]);
}

# R mad(): 1.4826 * median absolute deviation from the median
sub mad {
    my @x = defined_only(@_);
    return NA if !@x;
    my $m = median(@x);
    return 1.4826 * median(map { abs($_ - $m) } @x);
}

sub harmonic_mean {
    my @x = grep { defined($_) && $_ > 0 } @_;
    return NA if !@x;
    return @x / sum(map { 1 / $_ } @x);
}

# Holm (step-down Bonferroni) adjusted p-values, as R p.adjust(method = "holm")
sub holm {
    my @p = @_;
    my $n = scalar(grep { defined } @p);
    my @o = sort { $p[$a] <=> $p[$b] } grep { defined $p[$_] } 0 .. $#p;
    my @adj = (undef) x @p;
    my $run = 0;
    for my $i (0 .. $#o) {
        my $v = ($n - $i) * $p[$o[$i]];
        $run = $v if $v > $run;
        $adj[$o[$i]] = $run > 1 ? 1 : $run;
    }
    return @adj;
}

# complementary error function (W. J. Cody's rational approximations,
# relative error < 1e-15 over the whole range)
sub _erfc {
    my $x = shift;
    my $ax = abs($x);
    my $r;
    if ($ax < 0.5) {
        my $t = $x * $x;
        my $top = (((0.185777706184603153 * $t + 3.16112374387056560) * $t + 113.864154151050156) * $t + 377.485237685302021) * $t + 3209.37758913846947;
        my $bot = (((1.0 * $t + 23.6012909523441209) * $t + 244.024637934444173) * $t + 1282.61652607737228) * $t + 2844.23683343917062;
        return 1 - $x * $top / $bot;
    }
    elsif ($ax < 4) {
        my @p = (2.15311535474403846e-8, 0.564188496988670089, 8.88314979438837594, 66.1191906371416295, 298.635138197400131,
                 881.952221241769090, 1712.04761263407058, 2051.07837782607147, 1230.33935479799725);
        my @q = (1.0, 15.7449261107098347, 117.693950891312499, 537.181101862009858, 1621.38957456669019,
                 3290.79923573345963, 4362.61909014324716, 3439.36767414372164, 1230.33935480374942);
        my ($top, $bot) = (0, 0);
        $top = $top * $ax + $_ for @p;
        $bot = $bot * $ax + $_ for @q;
        $r = exp(-$ax * $ax) * $top / $bot;
    }
    else {
        my $z = 1 / ($ax * $ax);
        my @p = (0.0163153871373020978, 0.305326634961232344, 0.360344899949804439, 0.125781726111229246, 0.0160837851487422766, 6.58749161529837803e-4);
        my @q = (1.0, 2.56852019228982242, 1.87295284992346725, 0.527905102951428412, 0.0605183413124413191, 0.00233520497626869185);
        my ($top, $bot) = (0, 0);
        $top = $top * $z + $_ for @p;
        $bot = $bot * $z + $_ for @q;
        $r = exp(-$ax * $ax) / $ax * (0.564189583547756287 - $z * $top / $bot);
    }
    return $x < 0 ? 2 - $r : $r;
}

# P(Z > z) for a standard normal Z
sub pnorm_upper {
    my $z = shift;
    return 0.5 * _erfc($z / sqrt(2));
}

sub _lgamma {
    my $x = shift;
    my @c = (76.18009172947146, -86.50532032941677, 24.01409824083091, -1.231739572450155, 0.1208650973866179e-2, -0.5395239384953e-5);
    my $y = $x;
    my $tmp = $x + 5.5;
    $tmp -= ($x + 0.5) * log($tmp);
    my $series = 1.000000000190015;
    $series += $_ / ++$y for @c;
    return -$tmp + log(2.5066282746310005 * $series / $x);
}

sub _betacf {
    my ($a, $b, $x) = @_;
    my ($qab, $qap, $qam) = ($a + $b, $a + 1, $a - 1);
    my $c = 1;
    my $d = 1 - $qab * $x / $qap;
    $d = 1e-300 if abs($d) < 1e-300;
    $d = 1 / $d;
    my $h = $d;
    for my $m (1 .. 1000) {
        my $m2 = 2 * $m;
        my $aa = $m * ($b - $m) * $x / (($qam + $m2) * ($a + $m2));
        $d = 1 + $aa * $d; $d = 1e-300 if abs($d) < 1e-300;
        $c = 1 + $aa / $c; $c = 1e-300 if abs($c) < 1e-300;
        $d = 1 / $d;
        $h *= $d * $c;
        $aa = -($a + $m) * ($qab + $m) * $x / (($a + $m2) * ($qap + $m2));
        $d = 1 + $aa * $d; $d = 1e-300 if abs($d) < 1e-300;
        $c = 1 + $aa / $c; $c = 1e-300 if abs($c) < 1e-300;
        $d = 1 / $d;
        my $del = $d * $c;
        $h *= $del;
        last if abs($del - 1) < 1e-14;
    }
    return $h;
}

# regularized incomplete beta function I_x(a, b)
sub _betai {
    my ($a, $b, $x) = @_;
    return 0 if $x <= 0;
    return 1 if $x >= 1;
    my $bt = exp(_lgamma($a + $b) - _lgamma($a) - _lgamma($b) + $a * log($x) + $b * log(1 - $x));
    return $x < ($a + 1) / ($a + $b + 2) ? $bt * _betacf($a, $b, $x) / $a : 1 - $bt * _betacf($b, $a, 1 - $x) / $b;
}

# P(F > f) for an F(d1, d2) distribution
sub pf_upper {
    my ($f, $d1, $d2) = @_;
    return NA if !defined($f) || $d1 <= 0 || $d2 <= 0;
    return 1 if $f <= 0;
    return _betai($d2 / 2, $d1 / 2, $d2 / ($d2 + $d1 * $f));
}

# Pearson correlation of two equally long lists (pairs with a missing value skipped)
sub cor {
    my ($x, $y) = @_;
    my @i = grep { defined($x->[$_]) && defined($y->[$_]) } 0 .. $#$x;
    return NA if @i < 2;
    my $mx = sum(map { $x->[$_] } @i) / @i;
    my $my = sum(map { $y->[$_] } @i) / @i;
    my ($sxy, $sxx, $syy) = (0, 0, 0);
    foreach (@i) {
        my ($dx, $dy) = ($x->[$_] - $mx, $y->[$_] - $my);
        $sxy += $dx * $dy; $sxx += $dx * $dx; $syy += $dy * $dy;
    }
    return NA if $sxx <= 0 || $syy <= 0;
    return $sxy / sqrt($sxx * $syy);
}

# Average-linkage (UPGMA) hierarchical clustering of a distance matrix
# (arrayref of arrayrefs). Returns { merges => [[a, b, height], ...] with
# clusters as arrayrefs of item indices, order => leaf order of the tree }.
sub hclust_average {
    my $d = shift;
    my $n = scalar(@$d);
    my %cl = map { $_ => { items => [$_], tree => [$_] } } 0 .. $n - 1;
    my %dist;
    for my $i (0 .. $n - 1) { for my $j ($i + 1 .. $n - 1) { $dist{"$i,$j"} = $d->[$i]->[$j]; } }
    my $next = $n;
    my @merges;
    while (keys(%cl) > 1) {
        my @ids = sort { $a <=> $b } keys %cl;
        my ($bi, $bj, $best);
        for my $x (0 .. $#ids) {
            for my $y ($x + 1 .. $#ids) {
                my $v = $dist{"$ids[$x],$ids[$y]"};
                if (!defined($best) || $v < $best - 1e-12) { ($best, $bi, $bj) = ($v, $ids[$x], $ids[$y]); }
            }
        }
        my ($A, $B) = ($cl{$bi}, $cl{$bj});
        my $new = { items => [ @{$A->{items}}, @{$B->{items}} ], tree => [ @{$A->{tree}}, @{$B->{tree}} ] };
        push @merges, [ $A->{items}, $B->{items}, $best ];
        delete $cl{$bi}; delete $cl{$bj};
        foreach my $k (keys %cl) {
            my ($p, $q) = sort { $a <=> $b } ($k, $bi);
            my ($r, $s) = sort { $a <=> $b } ($k, $bj);
            my $v = (@{$A->{items}} * $dist{"$p,$q"} + @{$B->{items}} * $dist{"$r,$s"}) / (@{$A->{items}} + @{$B->{items}});
            $dist{"$k,$next"} = $v;
        }
        $cl{$next++} = $new;
    }
    my ($root) = values %cl;
    return { merges => \@merges, order => $root ? $root->{tree} : [] };
}

# clusters of an hclust_average() tree cut at height h: [[indices], ...]
sub cutree_height {
    my ($n, $hc, $h) = @_;
    my @group = (0 .. $n - 1);
    foreach my $m (@{$hc->{merges}}) {
        next if $m->[2] > $h + 1e-12;
        my $g = $group[$m->[0]->[0]];
        $group[$_] = $g for @{$m->[1]};
        $group[$_] = $g for @{$m->[0]};
    }
    my (%by, @first);
    foreach my $i (0 .. $n - 1) {
        push @first, $group[$i] if !$by{$group[$i]};
        push @{$by{$group[$i]}}, $i;
    }
    return [ map { $by{$_} } @first ];
}

# Least squares fit of y on additive factors (each an arrayref of level
# codes, same length as y) by backfitting (Gauss-Seidel on the normal
# equations). Optional weights. Returns the residuals (undef where y is
# missing).
sub backfit {
    my ($y, $factors, $w) = @_;
    my @i = grep { defined $y->[$_] } 0 .. $#$y;
    my @r = (undef) x @$y;
    return \@r if !@i;
    my @wt = map { defined($w) ? $w->[$_] : 1 } 0 .. $#$y;
    my $sw = sum(map { $wt[$_] } @i);
    my $mu = sum(map { $wt[$_] * $y->[$_] } @i) / $sw;
    $r[$_] = $y->[$_] - $mu for @i;
    my @eff = map { {} } @$factors;
    for my $iter (1 .. 1000) {
        my $change = 0;
        for my $f (0 .. $#$factors) {
            my $codes = $factors->[$f];
            my (%s, %n);
            foreach (@i) { my $k = $codes->[$_]; $s{$k} += $wt[$_] * $r[$_]; $n{$k} += $wt[$_]; }
            foreach (@i) {
                my $k = $codes->[$_];
                my $m = $s{$k} / $n{$k};
                $r[$_] -= $m;
            }
            foreach my $k (keys %s) { my $m = $s{$k} / $n{$k}; $change = abs($m) if abs($m) > $change; }
        }
        last if $change < 1e-11;
    }
    return \@r;
}

1;
