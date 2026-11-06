use strict;
use warnings;
use Test::More;
use CXGN::TimeUtils;
use CXGN::BrAPI::JSONResponse;

is(CXGN::TimeUtils::normalize_db_timestamp('2026-11-02T12:00:00+02:00'), '2026-11-02 10:00:00', 'offset preserves the UTC instant');
is(CXGN::TimeUtils::normalize_db_timestamp('2026-11-02 12:00:00+0200'), '2026-11-02 10:00:00', 'legacy offset is converted, not removed');
is(CXGN::TimeUtils::normalize_db_timestamp('2026-11-02 10:00:00'), '2026-11-02 10:00:00', 'naive database timestamps remain UTC');
is(CXGN::TimeUtils::normalize_db_timestamp('2026-11-02'), '2026-11-02 00:00:00', 'date-only boundary is midnight');
is(CXGN::TimeUtils::normalize_db_timestamp('2026-11-02T10:00:00.123456Z'), '2026-11-02 10:00:00.123456', 'fractional seconds preserved');
is(CXGN::TimeUtils::normalize_db_timestamp(''), undef, 'empty timestamp remains absent');
is(CXGN::TimeUtils::db_time_to_iso('2026-11-02T10:00:00Z'), '2026-11-02T10:00:00Z', 'already ISO never receives another Z');
is(CXGN::TimeUtils::db_time_to_iso('2026-11-02 12:00:00+02:00'), '2026-11-02T10:00:00Z', 'read and write use the same instant');
is(CXGN::TimeUtils::db_time_to_iso('20261102'), '2026-11-02T00:00:00Z', 'legacy upload metadata date remains readable');
is(CXGN::TimeUtils::db_time_to_iso('2026-11-02_10:00:00'), '2026-11-02T10:00:00Z', 'legacy archived metadata separator remains readable');
is(CXGN::TimeUtils::normalize_db_timestamp('2026-11-02T10:00:00.123456000Z'),'2026-11-02 10:00:00.123456','extra zero precision does not lose an instant');
is(CXGN::TimeUtils::normalize_db_timestamp('2026-11-02T10:00:00.1234560000000000000Z'),'2026-11-02 10:00:00.123456','long all-zero trailing precision remains exact');
for my $bad ('2026-11-02T10:00:00.1234560000000000001Z','2026-11-02T10:00:00.9999990000000000001Z','2026-11-02T10:00:00.1234561Z',0, '2026', 'not a time', '2026-02-30T10:00:00Z', {}, []) {
    my $ok = eval {CXGN::TimeUtils::normalize_db_timestamp($bad); 1};
    ok(!$ok, 'invalid timestamps refused');
}
is(CXGN::BrAPI::JSONResponse->return_error([], 'Invalid request')->{http_code}, 400, 'an error without an explicit code is not HTTP200');
is(CXGN::BrAPI::JSONResponse->return_error([], 'Missing',404)->{http_code},404,'explicit not-found code preserved');
is(CXGN::BrAPI::JSONResponse->return_error([{403 => 'Denied'}], 'Denied')->{http_code},403,'legacy numeric permission status preserved');
done_testing;
