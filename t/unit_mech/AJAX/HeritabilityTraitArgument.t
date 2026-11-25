
=head1 NAME

t/unit_mech/AJAX/HeritabilityTraitArgument.t - the trait from the request is one argument of the Rscript job, not shell text

=head1 DESCRIPTION

/ajax/heritability/generate_results puts the trait_id request parameter into
the command of an Rscript job, which the job backend runs with bash. Shell
text in trait_id must stay part of that one argument: a trait value that
would create a file when run by a shell must not create it. A normal request
still answers.

=cut

use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use URI::Escape qw(uri_escape);
use CXGN::Dataset;

my $f = SGN::Test::Fixture->new();
my $ds = CXGN::Dataset->new({ schema => $f->bcs_schema, people_schema => $f->people_schema });
$ds->trials([ 139, 141 ]);
$ds->store();
my $dataset_id = $ds->sp_dataset_id();
ok($dataset_id, 'test dataset stored');

# The controller turns spaces and slashes into dots, so the probe uses neither.
# Run by a shell, it would create the file "$HOME.<marker>" at once, while R still runs.
my $marker = 'h2argprobe' . $$;
my $probe_file = "$ENV{HOME}.$marker";
unlink($probe_file);
my $trait = 'x&id>${HOME}.' . $marker . '&echo';

my $mech = Test::WWW::Mechanize->new(timeout => 180, autocheck => 0);
$mech->get("http://localhost:3010/ajax/heritability/generate_results?dataset_id=$dataset_id&trait_id=" . uri_escape($trait));
ok($mech->status == 200 || $mech->status == 500, 'the request is answered');

my $waited = 0;
while (!-e $probe_file && $waited < 90) { sleep(2); $waited += 2; }
ok(!-e $probe_file, 'shell text in trait_id is not run');
unlink($probe_file);

done_testing();
