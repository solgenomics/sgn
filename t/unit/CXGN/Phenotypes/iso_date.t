
# The check that date-format trait values are ISO 8601 calendar dates.

use strict;
use warnings;

use Test::More;
use CXGN::Phenotypes::StorePhenotypes;

my $is_iso_date = \&CXGN::Phenotypes::StorePhenotypes::_is_iso_date;

ok($is_iso_date->('2026-03-24'), 'a plain ISO date is accepted');
ok($is_iso_date->('2026-03-24 14:30:05'), 'an ISO date with a time of day is accepted');
ok($is_iso_date->('2026-03-24T14:30'), 'an ISO date with a T and a time without seconds is accepted');
ok($is_iso_date->('2024-02-29'), 'February 29 in a leap year is accepted');
ok($is_iso_date->('2000-02-29'), 'February 29 in a leap century is accepted');

ok(!$is_iso_date->('2026-02-29'), 'February 29 outside a leap year is refused');
ok(!$is_iso_date->('1900-02-29'), 'February 29 in a century that is not a leap year is refused');
ok(!$is_iso_date->('2026-02-30'), 'a day past the end of its month is refused');
ok(!$is_iso_date->('2026-13-01'), 'a thirteenth month is refused');
ok(!$is_iso_date->('2026-00-10'), 'month zero is refused');
ok(!$is_iso_date->('3/24/2026'), 'a month/day/year date is refused');
ok(!$is_iso_date->('24-Mar-26'), 'a day-month-year date is refused');
ok(!$is_iso_date->(''), 'an empty value is refused');
ok(!$is_iso_date->(undef), 'an undefined value is refused');

done_testing();
