package main;
use strict;
use warnings;
use Test::More;

# Keep the editor/release workflow in SGN's normal native CI entry point.
my $status = system('python3', '-m', 'unittest', 'discover', '-s', 'bin/i18n', '-p', 'test_workflow.py');
is($status, 0, 'Frozen workspaces and ready-package workflows pass');
done_testing;
