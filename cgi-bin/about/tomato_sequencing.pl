use strict;

use SGN::Context;

my $c = SGN::Context->new();
$c->forward_to_mason_view('/tomato_genome/bac_by_bac_progress.mas');

