=head1 NAME

t/unit/SGN/I18NJavaScript.t - run the browser translator tests with Node

=head1 DESCRIPTION

Runs t/unit/SGN/i18n-runtime.test.cjs with C<node --test>, so the JavaScript
tests are part of the normal C<prove t/unit> run. Skipped when Node is missing.

=cut

use strict;
use warnings;

use Test::More;

my $node = `which node 2>/dev/null`;
chomp($node);
plan skip_all => 'node is not installed' unless $node;

my $output = `"$node" --test --test-reporter=tap t/unit/SGN/i18n-runtime.test.cjs 2>&1`;
my $status = $?;
is($status, 0, 'browser translator tests pass') or diag($output);
my ($passed) = $output =~ /^# pass (\d+)$/m;
ok($passed && $output =~ /^# fail 0$/m, "Node tests ran and passed: @{[ $passed // 0 ]}");

done_testing();
