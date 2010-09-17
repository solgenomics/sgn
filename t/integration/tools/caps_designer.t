use strict;
use warnings;

use Test::More;
use File::Slurp qw/slurp/;

use lib 't/lib';
use SGN::Test::WWW::Mechanize;

my $fasta = slurp("t/data/caps_designer.fasta");

my $urlbase = "$ENV{SGN_TEST_SERVER}/tools/caps_designer/caps_input.pl";
my $mech = SGN::Test::WWW::Mechanize->new;
$mech->get($urlbase);
$mech->submit_form_ok({
    form_name => 'capsinput',
    fields => {
        format   => 'fasta',
        seq_data => $fasta,
        cheap    => 0,
        start    => 20,
        cutno    => 4,
    },
});

$mech->content_unlike(qr/CLUSTAL 2\.0\.10 Multiple Sequence Alignments/);

$mech->content_contains('CAPS Designer Result');
$mech->content_contains('Query Summary');

# Make sure the downloadable files were generated correctly
my @links = $mech->find_all_links( url_regex => qr/tempfiles/ );

for my $link (@links) {
    $mech->get_ok($link->url);
}

done_testing;
