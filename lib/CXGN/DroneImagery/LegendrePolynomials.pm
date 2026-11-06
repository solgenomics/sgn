package CXGN::DroneImagery::LegendrePolynomials;

=head1 NAME

CXGN::DroneImagery::LegendrePolynomials - evaluate Legendre polynomial random regression coefficients

=head1 USAGE

my $value = CXGN::DroneImagery::LegendrePolynomials::legendre_polynomial_sum($coeffs, $time);

=head1 DESCRIPTION

The random regression models in the drone imagery analytics fit one coefficient per
Legendre polynomial order. This module evaluates a fitted set of those coefficients at
a given (scaled) time point, returning the summed value.

The raw-polynomial utility supports P0 through P6. Drone model readback uses
normalized_legendre_polynomial_sum(), matching the supplied R leg() basis and
retaining the signs of all fitted coefficients.

=head1 AUTHORS

=cut

use strict;
use warnings;
use Scalar::Util qw(looks_like_number);
use POSIX qw(isfinite);

# The Legendre polynomials P0..P6, in order, each scaled by its random regression
# coefficient. Every entry takes ($b, $time) and returns that term's contribution.
my @legendre_coeff_subs = (
    sub { my ($b, $time) = @_; return 1 * $b; },
    sub { my ($b, $time) = @_; return $time * $b; },
    sub { my ($b, $time) = @_; return (1/2*(3*$time**2 - 1)*$b); },
    sub { my ($b, $time) = @_; return 1/2*(5*$time**3 - 3*$time)*$b; },
    sub { my ($b, $time) = @_; return 1/8*(35*$time**4 - 30*$time**2 + 3)*$b; },
    sub { my ($b, $time) = @_; return 1/8*(63*$time**5 - 70*$time**3 + 15*$time)*$b; },
    sub { my ($b, $time) = @_; return 1/16*(231*$time**6 - 315*$time**4 + 105*$time**2 - 5)*$b; }
);

=head2 legendre_polynomial_sum

 Usage:        my $value = legendre_polynomial_sum($coeffs, $time)
 Desc:         Sums the Legendre polynomial terms for a set of random regression
               coefficients evaluated at a single time point.
 Args:         $coeffs - arrayref of coefficients, ordered from P0 upwards
               $time - the scaled time point to evaluate at
 Ret:          The summed value

=cut

sub legendre_polynomial_sum {
    my $coeffs = shift;
    my $time = shift;

    my $value = 0;
    my $coeff_counter = 0;
    foreach my $b (@$coeffs) {
        my $legendre_term = $legendre_coeff_subs[$coeff_counter];
        if (!$legendre_term) {
            print STDERR "No Legendre polynomial defined for coefficient number $coeff_counter. Skipping it.\n";
        }
        else {
            $value += $legendre_term->($b, $time);
        }
        $coeff_counter++;
    }
    return $value;
}

=head2 normalized_legendre_polynomial_sum($coefficients, $scaled_time, $intercept_one)

Evaluate the normalized Legendre basis used by enhancer::leg() and the Drone
Sommer/F90 builders. Time is scaled from the fitted range to [0,1], then mapped
to [-1,1]. Order n has normalization sqrt((2*n+1)/2). Optional intercept_one
multiplies the entire basis by sqrt(2), exactly as R leg(intercept1=TRUE).
Signed coefficients remain at their original polynomial orders.

=cut

sub normalized_legendre_polynomial_sum {
    my ($coefficients, $scaled_time, $intercept_one) = @_;
    die "Legendre coefficients must be an array.\n" unless ref($coefficients) eq 'ARRAY';
    die "Legendre time must be finite and numeric.\n" unless defined($scaled_time) && looks_like_number($scaled_time) && isfinite($scaled_time);
    my $x = 2*$scaled_time - 1;
    my ($previous, $current) = (1, $x);
    my $value = 0;
    for my $order (0..$#$coefficients) {
        my $coefficient = $coefficients->[$order];
        die "Legendre coefficients must be finite and numeric.\n" unless defined($coefficient) && looks_like_number($coefficient) && isfinite($coefficient);
        my $polynomial;
        if ($order == 0) { $polynomial = 1; }
        elsif ($order == 1) { $polynomial = $x; }
        else {
            $polynomial = ((2*$order-1)*$x*$current - ($order-1)*$previous)/$order;
            ($previous, $current) = ($current, $polynomial);
        }
        $value += $coefficient * sqrt((2*$order+1)/2) * $polynomial;
    }
    return $intercept_one ? $value*sqrt(2) : $value;
}

1;
