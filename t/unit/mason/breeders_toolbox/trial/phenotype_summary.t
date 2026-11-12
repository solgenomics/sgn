=head1 NAME

t/unit/mason/breeders_toolbox/trial/phenotype_summary.t - date filters of the trial phenotype summary

=head1 DESCRIPTION

Runs the page script of mason/breeders_toolbox/trial/phenotype_summary.mas in
node, with a minimal jQuery stand-in, under several browser time zones. The
date filters must show the calendar days of the trial collect dates, whatever
the time zone of the browser.

=cut

use strict;
use warnings;

use Test::More;
use File::Temp qw | tempfile |;
use JSON;

my $node = `which node 2>/dev/null`;
chomp($node);
plan skip_all => 'node is not installed' if !$node;

my $mason_file = 'mason/breeders_toolbox/trial/phenotype_summary.mas';

my ($fh, $harness) = tempfile(SUFFIX => '.js', UNLINK => 1);
print $fh do { local $/; <DATA> };
close($fh);

sub run_page {
    my $tz = shift;
    my $collect_date_range = shift;

    local $ENV{TZ} = $tz;
    open(my $out, '-|', $node, $harness, $mason_file, encode_json($collect_date_range)) or die "Can't run node: $!";
    my $result = do { local $/; <$out> };
    close($out);
    return eval { decode_json($result) } || {};
}

foreach my $tz ('UTC', 'Europe/Kyiv', 'America/Los_Angeles', 'Pacific/Kiritimati', 'Pacific/Pago_Pago') {
    my $r = run_page($tz, { trial_id => 1, start_date => '2030-08-16 00:00:00', end_date => '2030-08-20 23:30:00' });

    is_deeply($r->{initial_dates}, ['2030-08-16', '2030-08-20'], "$tz: date filters start at the collect date range");
    is_deeply($r->{dates_after_slide}, ['2030-08-17', '2030-08-18'], "$tz: end date picked from the calendar is kept when the slider moves");
    like($r->{summary_table_url}, qr/&start_date=2030-08-17&end_date=2030-08-18&/, "$tz: summary table is requested for the selected days");
}

my $r = run_page('Europe/Kyiv', { trial_id => 1, start_date => undef, end_date => undef });
is_deeply($r->{initial_dates}, ['', ''], 'no date filters for a trial without collect dates');

done_testing();

__DATA__
// Runs the phenotype summary page script with a minimal jQuery stand-in.
// usage: node harness.js <mason file> <collect_date_range response as JSON>
const fs = require('fs');
const vm = require('vm');

const mason_file = process.argv[2];
const collect_date_range = JSON.parse(process.argv[3]);

const source = fs.readFileSync(mason_file, 'utf8');
const script = source.slice(source.indexOf('<script>') + '<script>'.length, source.lastIndexOf('</script>'))
    .split('\n').filter(line => !line.startsWith('%')).join('\n')
    .replace(/<%\s*\$trial_stock_type\s*%>/g, '')
    .replace(/<%\s*\$trial_id\s*%>/g, collect_date_range.trial_id);

const elements = {};
const ajax_calls = [];
const summary_table_urls = [];
let ready;

function Element() {
    this.value = '';
    this.handlers = {};
    this.picker = null;
    this.slider_options = null;
    this.slider_values = null;
}
Element.prototype.val = function (value) {
    if (arguments.length) { this.value = value; return this; }
    return this.value;
};
Element.prototype.on = function (event) {
    const handler = arguments[arguments.length - 1];
    (this.handlers[event] = this.handlers[event] || []).push(handler);
    return this;
};
Element.prototype.prop = function (name, value) { return arguments.length > 1 ? this : undefined; };
Element.prototype.change = function (handler) { return handler ? this.on('change', handler) : this.trigger('change'); };
Element.prototype.click = function (handler) { return handler ? this.on('click', handler) : this.trigger('click'); };
Element.prototype.trigger = function (event) {
    (this.handlers[event] || []).forEach(handler => handler.call(this, {}));
    return this;
};
Element.prototype.daterangepicker = function (options, callback) {
    this.picker = { options: options, callback: callback };
    return this;
};
Element.prototype.slider = function (options, values) {
    if (typeof options === 'object') {
        this.slider_options = options;
        this.slider_values = options.values.slice();
    }
    else if (options === 'values') {
        // like jQuery UI, keep the values inside the slider range
        this.slider_values = values.map(v => Math.min(Math.max(v, this.slider_options.min), this.slider_options.max));
    }
    return this;
};
Element.prototype.DataTable = function (options) {
    summary_table_urls.push(options.ajax);
    return this;
};

// any other jQuery method is a chainable no-op
function wrap(element) {
    const proxy = new Proxy(element, {
        get: (target, name) => name in target ? target[name] : function () { return proxy; },
    });
    return proxy;
}

function jQuery(selector) {
    if (selector === document) { return { ready: function (handler) { ready = handler; } }; }
    if (typeof selector !== 'string') { return selector; }
    const title = selector.match(/^input\[title="(\w+)"\]$/);
    if (title) { selector = '#' + title[1]; }
    if (!elements[selector]) { elements[selector] = wrap(new Element()); }
    return elements[selector];
}
jQuery.ajax = function (options) {
    const request = {
        url: options.url,
        done: function (handler) { request.done_handler = handler; return request; },
        fail: function () { return request; },
        then: function () { return request; },
    };
    ajax_calls.push(request);
    return request;
};

// a moment at the start of a calendar day in the browser time zone, as daterangepicker returns
function moment(day) {
    const [year, month, date] = day.split('-').map(Number);
    return {
        format: function () { return day; },
        valueOf: function () { return new Date(year, month - 1, date).getTime(); },
    };
}

const document = {};
// other components of the trial page define trial_id as a global
vm.runInNewContext(script, {
    trial_id: collect_date_range.trial_id,
    jQuery: jQuery, document: document, d3v4: {}, stackedObservationPhenotypeHistogram: {},
    addToListMenu: function () {}, alert: function () {}, console: console,
});

ready();
ajax_calls.find(request => /\/collect_date_range$/.test(request.url)).done_handler(collect_date_range);

const start_date = jQuery('#summary_start_date');
const end_date = jQuery('#summary_end_date');
const slider = jQuery('#summary_phenotype_slider_range');
const result = { initial_dates: [start_date.val(), end_date.val()] };

if (slider.slider_options) {
    // pick 2030-08-18 in the end date calendar
    end_date.trigger('focus');
    end_date.picker.callback(moment('2030-08-18'), moment('2030-08-18'));
    end_date.val('2030-08-18').trigger('change');

    // then move the start handle of the slider to 2030-08-17
    slider.slider_options.slide({}, { values: [Date.parse('2030-08-17T12:00:00Z'), slider.slider_values[1]] });

    result.dates_after_slide = [start_date.val(), end_date.val()];
    result.summary_table_url = summary_table_urls[summary_table_urls.length - 1];
}

console.log(JSON.stringify(result));
