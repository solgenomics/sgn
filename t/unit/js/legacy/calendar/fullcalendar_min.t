=head1 NAME

t/unit/js/legacy/calendar/fullcalendar_min.t - FullCalendar 2.4 with jQuery 3

=head1 DESCRIPTION

Runs js/source/legacy/calendar/fullcalendar_min.js with the bundled jQuery and
moment in jsdom, the way the personal calendar uses it: created inside a hidden
modal and rendered when the modal is shown. jQuery 3 runs Deferred callbacks
asynchronously, so the view dates and title are only known once the view's
display promise is resolved. Opening the calendar must not throw, and the title
and event requests must follow the date shown.

Needs node and js/node_modules (npm install in js/); skipped otherwise.

=cut

use strict;
use warnings;

use Test::More;
use File::Temp qw | tempfile |;
use JSON;

my $node = `which node 2>/dev/null`;
chomp($node);
plan skip_all => 'node is not installed' if !$node;
plan skip_all => 'jsdom is not installed (run npm install in js/)' if !-d 'js/node_modules/jsdom';

my ($fh, $harness) = tempfile(SUFFIX => '.js', UNLINK => 1);
print $fh do { local $/; <DATA> };
close($fh);

open(my $out, '-|', $node, $harness, 'js') or die "Can't run node: $!";
my $output = do { local $/; <$out> };
close($out);
my $r = eval { decode_json($output) } || {};

is($r->{jquery}, '3', 'the bundled jQuery is version 3');
is($r->{hidden_fetches}, 0, 'a calendar created in a hidden modal does not request events yet');

is($r->{open}->{error}, '', 'showing the calendar does not throw');
is($r->{open}->{title}, 'Oct 2026', 'month title after showing the calendar');
is_deeply($r->{open}->{fetch}, ['2026-09-27', '2026-11-08'], 'events are requested for the month shown');

is($r->{next}->{error}, '', 'going to the next month does not throw');
is($r->{next}->{title}, 'Nov 2026', 'month title after going to the next month');
is_deeply($r->{next}->{fetch}, ['2026-11-01', '2026-12-13'], 'events are requested for the next month');

is($r->{week}->{error}, '', 'switching to the week view does not throw');
is($r->{week}->{title}, "Nov 1 \x{2014} 7 2026", 'week title after switching to the week view');
is_deeply($r->{week}->{fetch}, ['2026-11-01', '2026-11-08'], 'events are requested for the week shown');

done_testing();

__DATA__
// Creates a FullCalendar in a hidden container, shows it, then moves to the
// next month and to the week view. Prints what the page shows after each step.
// usage: node harness.js <sgn js directory>
const path = require('path');
const fs = require('fs');

const js_dir = path.resolve(process.argv[2]);
const { JSDOM } = require(path.join(js_dir, 'node_modules', 'jsdom'));

const dom = new JSDOM('<div id="modal" hidden><div id="calendar"></div></div>', { runScripts: 'outside-only', pretendToBeVisual: true });
const window = dom.window;
for (const file of ['jquery.js', 'calendar/moment_min.js', 'calendar/fullcalendar_min.js']) {
    window.eval(fs.readFileSync(path.join(js_dir, 'source', 'legacy', file), 'utf8'));
}
const $ = window.jQuery;

// jsdom has no layout, so jQuery's :visible is always false there. Treat
// everything outside the hidden modal as visible.
$.expr.pseudos.visible = (element) => !element.closest('[hidden]');

const fetches = [];
$.fullCalendar.sourceFetchers.unshift(function (source, start, end, timezone, callback) {
    fetches.push([start.format('YYYY-MM-DD'), end.format('YYYY-MM-DD')]);
    callback([]);
    return true;
});

const calendar = $('#calendar');
const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

// Wait until the view has finished displaying its dates, then a little more
// for callbacks chained after that.
async function settle() {
    for (let i = 0; i < 300; i++) {
        await wait(10);
        const view = calendar.fullCalendar('getView');
        if (view && view.displaying && view.displaying.state() === 'resolved') {
            break;
        }
    }
    await wait(100);
}

async function step(action) {
    const fetches_before = fetches.length;
    let error = '';
    try {
        action();
    } catch (e) {
        error = String(e && e.message || e);
    }
    await settle();
    return {
        error: error,
        title: calendar.find('.fc-toolbar h2').text(),
        fetch: fetches.length > fetches_before ? fetches[fetches.length - 1] : null,
    };
}

(async () => {
    const result = { jquery: $.fn.jquery.split('.')[0] };

    calendar.fullCalendar({
        defaultDate: '2026-10-04',
        defaultView: 'month',
        lazyFetching: false,
        header: { left: 'title', center: 'month,agendaWeek', right: 'prev,next' },
        views: { month: { titleFormat: 'MMM YYYY' }, agendaWeek: { titleFormat: 'MMM D YYYY' } },
        eventSources: [{ events: [] }],
    });
    await wait(100);
    result.hidden_fetches = fetches.length;

    // what the page does on 'shown.bs.modal'
    window.document.getElementById('modal').hidden = false;
    result.open = await step(() => calendar.fullCalendar('render'));
    result.next = await step(() => calendar.fullCalendar('next'));
    result.week = await step(() => calendar.fullCalendar('changeView', 'agendaWeek'));

    console.log(JSON.stringify(result));
    window.close();
})();
