use strict;
use warnings;

use Test::More;
use File::Slurp qw/slurp/;

use lib 't/lib';
use SGN::Test::WWW::Mechanize;

my $ests = slurp("t/data/ests.seq");

my $data_exists = -e '/data/prod/public/intron_finder_database/SV_gene_feature.data';

local $TODO = "needed live data not present" unless $data_exists;

my $urlbase = "/tools/intron_detection/find_introns.pl";
my $mech = SGN::Test::WWW::Mechanize->new;
$mech->get($urlbase);
$mech->submit_form_ok({
    form_name => 'findintrons',
    fields => {
        genes => $ests,
        blast_e_value => '1e-50',
    },
});

done_testing;
