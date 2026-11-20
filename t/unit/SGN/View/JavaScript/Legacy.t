=head1 NAME

t/unit/SGN/View/JavaScript/Legacy.t - non-ASCII characters in legacy JavaScript

=head1 DESCRIPTION

Serves a legacy JavaScript file that contains non-ASCII characters through
the /js/legacy action of SGN::Controller::JavaScript and
SGN::View::JavaScript::Legacy, in a minimal Catalyst application (no
database). The characters must reach the browser unchanged, encoded in UTF-8
once, as the Content-Type says.

=cut

use strict;
use warnings;

package main;  # the mock classes below are declared inside this test

use Test::More;
use File::Temp qw | tempdir |;
use Encode qw | decode |;

our $dir;

BEGIN {
    # The SGN components read their default config from SGN->path_to() when
    # they are loaded. Provide that here, so the test does not need to start
    # the whole application.
    package SGN;
    sub path_to { shift; return join('/', '.', @_); }
}

BEGIN {
    $dir = tempdir(CLEANUP => 1);
    open(my $fh, '>:encoding(UTF-8)', "$dir/non_ascii.js") or die "Can't write $dir/non_ascii.js: $!";
    # an em dash as in the FullCalendar week title, and currency symbols as in
    # the DataTables number detection
    print $fh "var title = \"Oct 4 \x{2014} 10 2026\";\nvar currency = /[\x{a3}\x{20ac}\x{a5}]/;\n";
    close($fh);
}

BEGIN {
    package Test::LegacyJS;
    use Catalyst;
    __PACKAGE__->config(
        name => 'Test::LegacyJS',
        home => $main::dir,
        root => $main::dir,
        'Controller::JavaScript' => {
            js_path => $main::dir,
            js_legacy_path => $main::dir,
            dependency_json_path => "$main::dir/mapping.json",
        },
        'View::JavaScript::Legacy' => { js_dir => $main::dir },
        inject_components => {
            'Controller::JavaScript' => { from_component => 'SGN::Controller::JavaScript' },
            'View::JavaScript::Legacy' => { from_component => 'SGN::View::JavaScript::Legacy' },
        },
    );
    __PACKAGE__->setup();
}

use Catalyst::Test 'Test::LegacyJS';

my $res = request('/js/legacy/non_ascii.js');
is($res->code, 200, 'legacy file is served');
like($res->header('Content-Type'), qr{^text/javascript; charset=utf-8$}i, 'served as UTF-8 JavaScript');

my $text = decode('UTF-8', $res->content);
like($text, qr/"Oct 4 \x{2014} 10 2026"/, 'em dash is served unchanged');
like($text, qr/\[\x{a3}\x{20ac}\x{a5}\]/, 'currency symbols are served unchanged');

done_testing();
