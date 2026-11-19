
# The check that date-format trait values are ISO 8601 calendar dates.

use strict;
use warnings;

use Test::More;
use Test::MockObject;
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
ok($is_iso_date->('2026-03-24 23:59:59'), 'the last second of a day is accepted');
ok($is_iso_date->('2026-03-24 14:30:05.123'), 'a time with a fraction of a second is accepted');
ok(!$is_iso_date->('2026-03-24 99:99:99'), 'a time with impossible fields is refused');
ok(!$is_iso_date->('2026-03-24 24:00'), 'hour 24 is refused');
ok(!$is_iso_date->('2026-03-24T14:60'), 'minute 60 is refused');
ok(!$is_iso_date->('2026-03-24 14:30:60'), 'second 60 is refused');
ok(!$is_iso_date->('3/24/2026'), 'a month/day/year date is refused');
ok(!$is_iso_date->('24-Mar-26'), 'a day-month-year date is refused');
ok(!$is_iso_date->(''), 'an empty value is refused');
ok(!$is_iso_date->(undef), 'an undefined value is refused');

my $equal = \&CXGN::Phenotypes::StorePhenotypes::_trait_values_equal;
ok($equal->('3/24/2026', '2026-03-24', 'date'), 'US and ISO dates compare equal');
ok(!$equal->('3/24/2026', '2026-03-25', 'date'), 'different dates compare different');
ok($equal->('03/24/2026', '2026-03-24', 'Date'), 'a padded month/day/year date and a mixed case date format compare equal');
ok($equal->('24/3/2026', '2026-03-24', 'date'), 'a day/month/year date with a day above 12 compares equal');
ok($equal->('24/3/2026', '3/24/2026', 'date'), 'the two slash orders of one unambiguous date compare equal');
ok($equal->('3/3/2026', '2026-03-03', 'date'), 'a slash date whose day and month are equal compares equal');
ok(!$equal->('3/4/2026', '2026-03-04', 'date'), 'a slash date that could be March 4 or April 3 is not read as March 4');
ok(!$equal->('3/4/2026', '2026-04-03', 'date'), 'a slash date that could be March 4 or April 3 is not read as April 3');
ok($equal->('3/4/2026', '3/4/2026', 'date'), 'identical ambiguous slash dates compare equal as text');
ok($equal->('2/29/2024', '2024-02-29', 'date'), 'a valid leap date compares equal');
ok(!$equal->('2/29/2026', '2026-02-29', 'date'), 'invalid dates fall back to text comparison');
ok($equal->('unknown', 'unknown', 'date'), 'identical unparsable values compare equal');
ok(!$equal->('unknown', '2026-03-24', 'date'), 'unparsable stored text does not equal a date');
ok(!$equal->('3/24/2026', '2026-03-24', 'text'), 'other trait formats still compare as text');
ok(!$equal->('3/24/2026', '2026-03-24', undef), 'an absent trait format still compares as text');
ok(!$equal->(undef, '2026-03-24', 'date'), 'an absent stored value does not equal a date');
ok(!$equal->('2026-03-24 14:30:05', '2026-03-24 15:30:05', 'date'), 'different times are not collapsed to the same day');
ok($equal->('3/24/2026 14:30:05', '2026-03-24 14:30:05', 'date'), 'a slash date and time equals the same ISO date and time');
ok($equal->('2026-03-24T14:30', '2026-03-24 14:30:00', 'date'), 'a time without seconds equals the same time with zero seconds');
ok($equal->('3/24/2026 2:30 PM', '2026-03-24 14:30:00', 'date'), 'a twelve-hour time equals the same 24-hour time');
ok($equal->('2026-03-24 14:30:05.000', '2026-03-24 14:30:05', 'date'), 'a zero fraction of a second is ignored');
ok($equal->('2026-03-24 14:30:05.123', '2026-03-24 14:30:05', 'date'), 'a nonzero fraction of a second is ignored');
ok($equal->('2026-03-24 14:30:05.123', '2026-03-24 14:30:05.987', 'date'), 'two fractions within one second compare equal');
ok($equal->('2026-03-24', '2026-03-24 00:00', 'date'), 'a date equals the same date at midnight');
ok(!$equal->('2026-03-24 99:99', '2026-03-24 99:99:00', 'date'), 'values with impossible times compare as text');

# Exercise each warning branch without a database by supplying existing-value lookups.
for my $repeat_type ('single', 'multiple', 'time_series') {
    for my $with_timestamp ($repeat_type eq 'single' ? (0, 1) : (1)) {
        for my $day (24, 25) {
            my $timestamp = $with_timestamp ? '2026-04-01 12:00:00' : '';
            my $stock = Test::MockObject->new();
            $stock->mock(stock_id => sub { 2 });
            my $schema = Test::MockObject->new();
            $schema->mock(resultset => sub { $schema });
            $schema->mock(find => sub { $stock });
            my $trait = Test::MockObject->new();
            $trait->mock(cvterm_id => sub { 1 });
            my (%by_stock, %by_timestamp);
            if ($with_timestamp) {
                $by_timestamp{1, 2, $timestamp} = '3/24/2026';
            }
            else {
                $by_stock{1, 2} = '3/24/2026';
            }
            my %attributes = (
                bcs_schema => $schema,
                trait_objs => {date_trait => $trait},
                check_trait_format => {1 => 'date'},
                check_trait_category => {1 => ''},
                check_trait_repeat_type => {1 => $repeat_type},
                unique_value_trait_stock => {},
                unique_value_trait_stock_timestamp => {},
                unique_trait_stock => \%by_stock,
                unique_trait_stock_timestamp => \%by_timestamp,
                check_file_stock_trait_duplicates => {},
                overwrite_values => 0,
                metadata_hash => {operator => 'test', date => '2026-04-01'},
            );
            my $store = Test::MockObject->new();
            for my $name (keys %attributes) {
                my $value = $attributes{$name};
                $store->mock($name => sub { $value });
            }
            my $same_value_count = 0;
            $store->mock(same_value_count => sub {
                $same_value_count = $_[1] if @_ > 1;
                return $same_value_count;
            });
            my ($warning, $error) = CXGN::Phenotypes::StorePhenotypes::check_measurement(
                $store, 'plot1', 'date_trait', ["2026-03-$day", $timestamp], 0
            );
            my $label = "$repeat_type, timestamp=$with_timestamp, day=$day";
            is($error, '', "the ISO date validates ($label)");
            is($same_value_count, $day == 24 ? 1 : 0, ($day == 24 ? "equivalent dates count as the same value" : "different dates do not count as the same value") . " ($label)");
            if ($day == 24) {
                is($warning, '', "equivalent dates produce no warning ($label)");
            }
            else {
                like($warning, qr/different value/, "different dates produce a warning ($label)");
            }
        }
    }
}

done_testing();
