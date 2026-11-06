use strict;
use warnings;

use Test::More;
use Test::Exception;
use Data::Dumper;

BEGIN{use_ok("CXGN::DroneImagery::LegendrePolynomials");}

# test that the sums work and that coefficients above 6 do not give a result. 

is(CXGN::DroneImagery::LegendrePolynomials::legendre_polynomial_sum([-2,3],.25),-2+3*.25,'negative coefficients retain their polynomial positions');

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

sub close_to {
    my ($actual,$expected,$label)=@_;
    ok(abs($actual-$expected)<1e-10,$label);
}
close_to(CXGN::DroneImagery::LegendrePolynomials::normalized_legendre_polynomial_sum([-2,3],0),-2/sqrt(2)-3*sqrt(3/2),'normalized signed coefficients match the supplied R basis at the fitted minimum');
close_to(CXGN::DroneImagery::LegendrePolynomials::normalized_legendre_polynomial_sum([-2,3],.5),-2/sqrt(2),'normalized midpoint retains the signed intercept');
close_to(CXGN::DroneImagery::LegendrePolynomials::normalized_legendre_polynomial_sum([-2,3],1),-2/sqrt(2)+3*sqrt(3/2),'normalized signed coefficients match the supplied R basis at the fitted maximum');
close_to(CXGN::DroneImagery::LegendrePolynomials::normalized_legendre_polynomial_sum([0,0,1],.25),sqrt(5/2)*.5*(3*(-.5)**2-1),'normalized quadratic uses the fitted [-1,1] time range');
close_to(CXGN::DroneImagery::LegendrePolynomials::normalized_legendre_polynomial_sum([-2,3],0,1),-2-3*sqrt(3),'intercept1 scales the entire standard basis by sqrt(2)');
close_to(CXGN::DroneImagery::LegendrePolynomials::normalized_legendre_polynomial_sum([0,0,0,0,0,0,0,1],.75),sqrt(15/2)*(429*.5**7-693*.5**5+315*.5**3-35*.5)/16,'higher fitted orders use the standard Legendre recurrence');

done_testing();