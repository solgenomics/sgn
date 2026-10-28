package main;
use strict;
use warnings;
use Test::More;
use File::Spec;
use File::Temp qw(tempfile);
use FindBin;

# SGN's CI installs the application JavaScript dependencies under js/.
# Execute source/DOM regressions through the normal native unit-test entry point.
my $root = File::Spec->rel2abs(File::Spec->catdir($FindBin::Bin, '..', '..', '..'));
local $ENV{NODE_PATH} = join(':', File::Spec->catdir($root, 'js', 'node_modules'), $ENV{NODE_PATH} || ());
my @suites = qw(i18n-cross-properties i18n-image-run i18n-list-copy
    i18n-list-validation-warning i18n-location-requests i18n-population-members
    i18n-runtime seedlot-iframe-json seedlot-maintenance-main-source
    seedlot-maintenance-record-source seedlot-overdue-source seedlot-split-source);
for my $suite (@suites) {
    subtest $suite => sub {
        my ($out, $path) = tempfile(UNLINK => 1);
        my $pid = fork();
        die "Cannot fork Node test: $!" unless defined $pid;
        if (!$pid) {
            open STDOUT, '>&', $out or die $!;
            open STDERR, '>&', $out or die $!;
            exec 'node', '--test', File::Spec->catfile($FindBin::Bin, "$suite.test.cjs");
            die "Cannot start Node: $!";
        }
        waitpid($pid, 0);
        my $status = $?;
        close $out;
        is($status, 0, 'Real source/DOM regression suite completes');
        if ($status) {
            open my $in, '<', $path or die $!;
            local $/;
            diag(<$in>);
            close $in;
        }
        done_testing;
    };
}
done_testing;
