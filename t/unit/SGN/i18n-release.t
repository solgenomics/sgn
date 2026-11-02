use strict;
use warnings;
use Test::More tests => 1;
# Standard-library/gettext release and operator regressions run in native CI.
# Parser-qualified extraction suites remain a release-builder check.
my $status = system('python3','-m','unittest','discover','-s','bin/i18n','-p','test_release.py');
is($status, 0, 'Frozen release compilation and transactional language-pack lifecycle');
