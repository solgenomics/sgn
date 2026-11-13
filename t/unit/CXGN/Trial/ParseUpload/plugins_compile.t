use strict;
use warnings;

use Test::More;
use File::Basename qw(basename);

# Every parser plugin must compile. A plugin that does not (for example one
# using an undeclared variable) makes every upload that loads it fail.

my @files = sort glob('lib/CXGN/Trial/ParseUpload/Plugin/*.pm');
ok(scalar(@files) > 0, 'found parse upload plugins');

foreach my $file (@files) {
    my $name = basename($file, '.pm');
    use_ok("CXGN::Trial::ParseUpload::Plugin::$name");
}

done_testing();
