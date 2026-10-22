# Tests _plot_name_for_new_stock(), which Change Accessions (replace_stock)
# uses to rename the plots of the replaced accession: the old name is only
# replaced where it is a whole part of the plot name, and a name that
# contains it that way more than once is left alone.

use strict;
use warnings;

use Test::More;

use SGN::Controller::AJAX::TrialMetadata;

my $rename = \&SGN::Controller::AJAX::TrialMetadata::_plot_name_for_new_stock;

# generated names
is($rename->('trial1-rep1-A1_1', 'A1', 'B2'), 'trial1-rep1-B2_1', 'rep layout name');
is($rename->('trial1-plotno5-block1-A1_5', 'A1', 'B2'), 'trial1-plotno5-block1-B2_5', 'block layout name');
is($rename->('trial1_A1_5', 'A1', 'B2'), 'trial1_B2_5', 'plain layout name');
is($rename->('A1', 'A1', 'B2'), 'B2', 'the whole name');
is($rename->('trial1-A1', 'A1', 'B2'), 'trial1-B2', 'at the end');

# the old name inside another part of the plot name is not touched
is($rename->('TA1X-rep1-A1_1', 'A1', 'B2'), 'TA1X-rep1-B2_1', 'trial name containing the accession name');
is($rename->('trial1-rep1-A10_1', 'A1', 'B2'), 'trial1-rep1-A10_1', 'a longer accession name');
is($rename->('trial1-rep1-XA1_1', 'A1', 'B2'), 'trial1-rep1-XA1_1', 'a name ending in the accession name');
is($rename->('test_trial210', 'test_accession3', 'B2'), 'test_trial210', 'a name without the accession name');

# more than once: left alone, the caller reports it
is($rename->('2021-A1-rep1-A1_1', 'A1', 'B2'), undef, 'trial name with the accession name as a part');
is($rename->('A1_A1', 'A1', 'B2'), undef, 'twice');

# regex characters in the names are plain text
is($rename->('trial1-rep1-A(1)_1', 'A(1)', 'B.2'), 'trial1-rep1-B.2_1', 'regex characters in the old name');
is($rename->('trial1-rep1-AX1_1', 'A.1', 'B2'), 'trial1-rep1-AX1_1', 'a dot in the old name matches only a dot');
is($rename->('trial1-rep1-A1_1', 'A1', 'B$2\\1'), 'trial1-rep1-B$2\\1_1', 'special characters in the new name');

done_testing();
