
use strict;

use lib 't/lib';

use Test::More;
use Data::Dumper;
use SGN::Test::Fixture;
use CXGN::Trial::TrialLayout;

my $f = SGN::Test::Fixture->new();

my $trial_id = 139;

my $tl = CXGN::Trial::TrialLayout->new({ schema => $f->bcs_schema(), trial_id => $trial_id, experiment_type => 'field_layout' });

my $d = $tl->get_design();

#print STDERR Dumper($d);

# '35700' => {
#                        'rep_number' => '1',
#                        'plot_number' => '35700',
#                        'block_number' => '6',
#                        'accession_name' => 'UG120109',
#                        'plot_name' => 'KASESE_TP2013_699',
#                        'plot_id' => 39893
#                      },



is($d->{35700}->{block_number}, 6, "block number");
is($d->{35700}->{accession_name}, 'UG120109', "accession name");
is($d->{35700}->{plot_id}, 39893, "plot_id");


done_testing();



