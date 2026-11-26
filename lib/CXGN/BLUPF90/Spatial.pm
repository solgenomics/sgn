package CXGN::BLUPF90::Spatial;

=head1 NAME

CXGN::BLUPF90::Spatial - 2D P-spline field surface for BLUPF90+ (SpATS-like)

=head1 SYNOPSIS

  use CXGN::BLUPF90::Spatial qw(surface_covariance);
  my $s = surface_covariance({ row => \@row, col => \@col, file => "$dir/surface_trial1.txt" });
  # $s->{key}: position key of every record ("row:col", undef without both)
  # $s->{levels}: position keys in the order of the covariance file
  # $s->{n_basis}, $s->{nseg} = [col, row], $s->{rank}

=head1 DESCRIPTION

SpATS (Rodriguez-Alvarez et al. 2018) models the field trend with a
two-dimensional P-spline surface. Its anisotropic PSANOVA form gives rows and
columns their own smoothing variances, mixed inside one penalty, which
blupf90+ cannot express. This module builds the closest model blupf90+ can
fit: the mixed-model form of a tensor-product P-spline with one smoothing
variance.

=over

=item *

cubic B-spline bases on the row and the column numbers, with
ceiling(n/2) segments each (as the R engine's SpATS call);

=item *

second-order difference penalties P = Dr'Dr (x) I + I (x) Dc'Dc; its null
space (mean, row trend, column trend, row x column) is left to fixed
effects (rowN, colN, rcN in the model);

=item *

the penalised part is one random effect over the plot positions with
covariance K = B P+ B' (P+ the pseudo-inverse), scaled to a mean variance of
1 with a small ridge so that it can be inverted. The eigen decomposition
uses the Kronecker structure of P (only the 1D penalties are decomposed).

=back

The covariance is written for RANDOM_TYPE user_file_inv (blupf90+ inverts
it): "i j value" lines of the upper triangle.

=head1 AUTHOR

Chris Simoes <ccs263@cornell.edu>

=cut

use strict;
use warnings;
use POSIX qw(ceil);
use List::Util qw(min max sum);
use Exporter 'import';
our @EXPORT_OK = qw(surface_covariance bspline_basis sym_eigen);

our $RIDGE = 1e-3;    # added to the diagonal (relative to the mean variance)

# cubic B-spline basis of x on [lo, hi] with nseg equal segments (Eilers &
# Marx bbase): n x (nseg + 3) as an arrayref of rows
sub bspline_basis {
    my ($x, $lo, $hi, $nseg) = @_;
    my $deg = 3;
    my $dx = ($hi - $lo) / $nseg;
    my @knots = map { $lo + ($_ - $deg) * $dx } 0 .. $nseg + 2 * $deg;
    my $nb = $nseg + $deg;
    my @B;
    foreach my $v (@$x) {
        # degree 0
        my @b = map { ($v >= $knots[$_] && $v < $knots[$_ + 1]) ? 1 : 0 } 0 .. $#knots - 1;
        # the right end belongs to the last interval
        if ($v >= $hi) { @b = (0) x ($#knots); $b[ $deg + $nseg - 1 ] = 1; }
        for my $k (1 .. $deg) {
            my @n;
            for my $i (0 .. $#knots - 1 - $k) {
                my $a = $knots[$i + $k] - $knots[$i];
                my $c = $knots[$i + $k + 1] - $knots[$i + 1];
                $n[$i] = ($a > 0 ? ($v - $knots[$i]) / $a * $b[$i] : 0) + ($c > 0 ? ($knots[$i + $k + 1] - $v) / $c * $b[$i + 1] : 0);
            }
            @b = @n;
        }
        push @B, [ @b[0 .. $nb - 1] ];
    }
    return \@B;
}

# eigen decomposition of a small symmetric matrix (cyclic Jacobi):
# returns (eigenvalues, eigenvectors as columns: $V->[row][k])
sub sym_eigen {
    my $A = [ map { [@$_] } @{ $_[0] } ];
    my $n = @$A;
    my $V = [ map { my $i = $_; [ map { $_ == $i ? 1 : 0 } 0 .. $n - 1 ] } 0 .. $n - 1 ];
    for my $sweep (1 .. 100) {
        my $off = 0;
        for my $p (0 .. $n - 2) { $off += $A->[$p][$_]**2 for $p + 1 .. $n - 1; }
        last if $off < 1e-22;
        for my $p (0 .. $n - 2) {
            for my $q ($p + 1 .. $n - 1) {
                next if abs($A->[$p][$q]) < 1e-300;
                my $theta = ($A->[$q][$q] - $A->[$p][$p]) / (2 * $A->[$p][$q]);
                my $t = ($theta >= 0 ? 1 : -1) / (abs($theta) + sqrt($theta * $theta + 1));
                my $c = 1 / sqrt($t * $t + 1);
                my $s = $t * $c;
                for my $k (0 .. $n - 1) {
                    my ($akp, $akq) = ($A->[$k][$p], $A->[$k][$q]);
                    $A->[$k][$p] = $c * $akp - $s * $akq;
                    $A->[$k][$q] = $s * $akp + $c * $akq;
                }
                for my $k (0 .. $n - 1) {
                    my ($apk, $aqk) = ($A->[$p][$k], $A->[$q][$k]);
                    $A->[$p][$k] = $c * $apk - $s * $aqk;
                    $A->[$q][$k] = $s * $apk + $c * $aqk;
                }
                for my $k (0 .. $n - 1) {
                    my ($vkp, $vkq) = ($V->[$k][$p], $V->[$k][$q]);
                    $V->[$k][$p] = $c * $vkp - $s * $vkq;
                    $V->[$k][$q] = $s * $vkp + $c * $vkq;
                }
            }
        }
    }
    return ([ map { $A->[$_][$_] } 0 .. $n - 1 ], $V);
}

# D'D of the second-order difference matrix of size n
sub _penalty {
    my $n = shift;
    my @P = map { [ (0) x $n ] } 1 .. $n;
    for my $i (0 .. $n - 3) {
        my @d = (1, -2, 1);
        for my $a (0 .. 2) { for my $b (0 .. 2) { $P[$i + $a][$i + $b] += $d[$a] * $d[$b]; } }
    }
    return \@P;
}

# 1D part: values -> basis x eigenvectors of the penalty (F), eigenvalues (s)
sub _axis {
    my ($vals, $nseg) = @_;
    my ($lo, $hi) = (min(@$vals), max(@$vals));
    ($lo, $hi) = ($lo - 0.5, $hi + 0.5);
    my $B = bspline_basis($vals, $lo, $hi, $nseg);
    my $nb = @{ $B->[0] };
    my ($s, $U) = sym_eigen(_penalty($nb));
    my $scale = max(map { abs } @$s) || 1;
    my @s = map { abs($_) < 1e-9 * $scale ? 0 : $_ } @$s;
    my @F = map { my $b = $_; [ map { my $k = $_; my $v = 0; $v += $b->[$_] * $U->[$_][$k] for 0 .. $nb - 1; $v } 0 .. $nb - 1 ] } @$B;
    return { F => \@F, s => \@s, nb => $nb };
}

# Covariance of the P-spline surface over the plot positions of a trial,
# written to $args->{file}. Records without a row or a column number get no
# position (they take no part in the surface).
sub surface_covariance {
    my $args = shift;
    my ($row, $col) = ($args->{row}, $args->{col});
    my $n = @$row;
    my (@key, %seen, @pos);
    for my $i (0 .. $n - 1) {
        my ($r, $c) = ($row->[$i], $col->[$i]);
        if (!defined($r) || !defined($c) || $r eq '' || $c eq '') { push @key, undef; next; }
        my $k = ($r + 0) . ':' . ($c + 0);
        push @key, $k;
        push @pos, [ $k, $r + 0, $c + 0 ] if !$seen{$k}++;
    }
    die "no plot has both a row and a column number\n" if @pos < 4;
    my %ur = map { $_->[1] => 1 } @pos;
    my %uc = map { $_->[2] => 1 } @pos;
    my @rv = sort { $a <=> $b } keys %ur;
    my @cv = sort { $a <=> $b } keys %uc;
    die "the surface needs at least three rows and three columns\n" if @rv < 3 || @cv < 3;
    my @nseg = (max(1, ceil(@cv / 2)), max(1, ceil(@rv / 2)));    # (col, row), as SpATS
    my $AR = _axis(\@rv, $nseg[1]);
    my $AC = _axis(\@cv, $nseg[0]);
    my %ri = map { $rv[$_] => $_ } 0 .. $#rv;
    my %ci = map { $cv[$_] => $_ } 0 .. $#cv;

    # weights of the penalised directions: 1 / (s_row + s_col), 0 in the null space
    my ($nr, $nc) = ($AR->{nb}, $AC->{nb});
    my @W = map { my $i = $_; [ map { my $l = $AR->{s}->[$i] + $AC->{s}->[$_]; $l > 0 ? 1 / $l : 0 } 0 .. $nc - 1 ] } 0 .. $nr - 1;
    my $rank = 0; for my $i (0 .. $nr - 1) { $rank += grep { $_ > 0 } @{$W[$i]}; }

    # row-pair weights: M[ra][rb][j] = sum_i Fr[ra][i] Fr[rb][i] W[i][j]
    my $Fr = $AR->{F};
    my $Fc = $AC->{F};
    my %M;
    for my $a (0 .. $#rv) {
        for my $b ($a .. $#rv) {
            my @m = (0) x $nc;
            for my $i (0 .. $nr - 1) {
                my $f = $Fr->[$a][$i] * $Fr->[$b][$i];
                next if $f == 0;
                my $w = $W[$i];
                $m[$_] += $f * $w->[$_] for 0 .. $nc - 1;
            }
            $M{"$a,$b"} = \@m;
        }
    }
    my @P = map { [ $ri{ $_->[1] }, $ci{ $_->[2] } ] } @pos;
    my $np = @P;
    # K(p, q) = sum_j M[rp][rq][j] Fc[cp][j] Fc[cq][j]
    my @diag;
    my @rows_out;
    for my $p (0 .. $np - 1) {
        my ($rp, $cp) = @{ $P[$p] };
        my $fcp = $Fc->[$cp];
        for my $q ($p .. $np - 1) {
            my ($rq, $cq) = @{ $P[$q] };
            my $m = $rp <= $rq ? $M{"$rp,$rq"} : $M{"$rq,$rp"};
            my $fcq = $Fc->[$cq];
            my $v = 0;
            $v += $m->[$_] * $fcp->[$_] * $fcq->[$_] for 0 .. $nc - 1;
            push @rows_out, [ $p + 1, $q + 1, $v ];
            $diag[$p] = $v if $p == $q;
        }
    }
    my $md = (sum(@diag) / @diag) || 1;
    open(my $F, '>', $args->{file}) or die "Cannot write $args->{file}\n";
    foreach my $e (@rows_out) {
        my $v = $e->[2] / $md + ($e->[0] == $e->[1] ? $RIDGE : 0);
        next if $e->[0] != $e->[1] && abs($v) < 1e-12;
        printf $F "%d %d %.10g\n", $e->[0], $e->[1], $v;
    }
    close($F);
    return { key => \@key, levels => [ map { $_->[0] } @pos ], nseg => \@nseg, n_basis => $nr * $nc, rank => $rank, n_positions => $np };
}

1;
