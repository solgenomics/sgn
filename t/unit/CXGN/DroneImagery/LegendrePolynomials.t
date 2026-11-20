use strict;
use warnings;

use Test::More;
use Test::Exception;
use Data::Dumper;

BEGIN{use_ok("CXGN::DroneImagery::LegendrePolynomials");}

# test that the sums work and that coefficients above 6 do not give a result. 

my $below_zero =    CXGN::DroneImagery::LegendrePolynomials::legendre_polynomial_sum([-1..3], 2);
my $zero_to_three = CXGN::DroneImagery::LegendrePolynomials::legendre_polynomial_sum([0..3], 2);

print STDERR "\n$below_zero vs $zero_to_three\n";

ok($below_zero == $zero_to_three, "Test coefficients below 0 are dropped");

my $above_six = CXGN::DroneImagery::LegendrePolynomials::legendre_polynomial_sum([0..7], 2);
my $zero_to_six = CXGN::DroneImagery::LegendrePolynomials::legendre_polynomial_sum([0..6], 2);

print STDERR "\n$above_six vs $zero_to_six\n";

ok($above_six == $zero_to_six, "Test coefficients above 6 are dropped");

my $rand_time = int(1 + rand(10)); # random integer for time in [1,10]

my $manual_calc = 
    0 + #P0
    $rand_time * 1 + #P1
    (1/2 * (3 * $rand_time**2 - 1) * 2) + #P2
    (1/2 * (5 * $rand_time**3 - 3 * $rand_time) * 3) ; #P3

ok(CXGN::DroneImagery::LegendrePolynomials::legendre_polynomial_sum([0..3], $rand_time) == $manual_calc, "Test functions work as expected");

done_testing();