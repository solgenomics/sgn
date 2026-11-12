package CXGN::DroneImagery::LegendrePolynomials;

=head1 NAME

CXGN::DroneImagery::LegendrePolynomials - evaluate Legendre polynomial random regression coefficients

=head1 USAGE

my $value = CXGN::DroneImagery::LegendrePolynomials::legendre_polynomial_sum($coeffs, $time);

=head1 DESCRIPTION

The random regression models in the drone imagery analytics fit one coefficient per
Legendre polynomial order. This module evaluates a fitted set of those coefficients at
a given (scaled) time point, returning the summed value.

Orders P0 through P6 are supported. Coefficients beyond P6 are skipped with a message
on STDERR.

=head1 AUTHORS

=cut

use strict;
use warnings;

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
        next if $b < 0;
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

1;
