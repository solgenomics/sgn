use strict;
use warnings;

use Test::More;
use File::Slurp qw/slurp/;

use lib 't/lib';
use SGN::Test::WWW::Mechanize;

my $fasta = slurp("t/data/caps_designer.fasta");

my $urlbase = "/tools/caps_designer/caps_input.pl";
my $mech = SGN::Test::WWW::Mechanize->new;

$mech->get("/tools/caps_designer/find_caps.pl");
is($mech->status, 400, "return code was 400 Bad Request");

$mech->get($urlbase);
#diag "submitting capsinput form with invalid clustalw data shouldn't blow up";
$mech->submit_form(
    form_name => 'capsinput',
    fields => {
        format   => 'clustalw',
        seq_data => 'FOO!',
        cheap    => 0,
        start    => 20,
        cutno    => 4,
    },
);
is($mech->status, 400, "return code was 400 Bad Request");
$mech->content_contains('Clustal alignment failed');

$mech->get($urlbase);
#diag "submitting capsinput form with only one FASTA shouldn't blow up";
$mech->submit_form(
    form_name => 'capsinput',
    fields => {
        format   => 'fasta',
        seq_data => ">FOO\nBAR",
        cheap    => 0,
        start    => 20,
        cutno    => 4,
    },
);

$mech->get($urlbase);
$mech->submit_form(
    form_name => 'capsinput',
    fields => {
        format   => 'fasta',
        seq_data => <<FASTA,
>s1
CCCCCCGAATTCAAAAAAAAA
>s2
CCCCCCGTATTCAAAAAAAAA
FASTA
        cheap    => 0,
        start    => 0,
        cutno    => 4,
    },
);
is($mech->status, 200, "return code was 200");
$mech->content_contains('CAPS Designer Result');
$mech->content_contains('Query Summary');

$mech->get($urlbase);
$mech->submit_form(
    form_name => 'capsinput',
    fields => {
        format   => 'fasta',
        seq_data => <<FASTA,
>s1
CCCCCCGAATTCAAAAAAAAA
>s2
ccccccgtattcaaaaaaaaa
FASTA
        cheap    => 0,
        start    => 0,
        cutno    => 4,
    },
);
is($mech->status, 200, "return code was 200");
$mech->content_contains('CAPS Designer Result');
$mech->content_contains('Query Summary');

for my $cheapness ( 0 .. 1 ) {
    $mech->get($urlbase);
    $mech->submit_form_ok({
        form_name => 'capsinput',
        fields => {
            format   => 'fasta',
            seq_data => $fasta,
            cheap    => $cheapness,
            start    => 20,
            cutno    => 4,
        },
    },"submit capsinput form with cheapness = $cheapness");

    $mech->content_unlike(qr/CLUSTAL 2\.0\.10 Multiple Sequence Alignments/);
    $mech->content_contains('CAPS Designer Result');
    $mech->content_contains('Query Summary');

    # Make sure the downloadable files were generated correctly
    my @links = $mech->find_all_links( url_regex => qr/tempfiles/ );

    for my $link (@links) {
        $mech->get_ok($link->url);
    }
}


done_testing;
