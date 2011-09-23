use strict;
use warnings;
use Test::More tests => 21;

use lib 't/lib';
use SGN::Test::Data qw/ create_test /;
use Catalyst::Test 'SGN';
use Digest::SHA1 qw/sha1_hex/;
use Data::Dumper;

use_ok 'SGN::Controller::Bulk';
use aliased 'SGN::Test::WWW::Mechanize' => 'Mech';

my $mech = Mech->new;

$mech->with_test_level( local => sub {
    $mech->get('/bulk/gene');
    $mech->submit_form_ok({
        form_name => "bulk_gene",
        fields    => {
            ids       => "Solyc02g081670.1",
            gene_type => '',
        },
    }, "submit bulk_gene with a single valid identifier");
    $mech->content_like(qr/Invalid data type chosen/) or diag $mech->content;
});

$mech->with_test_level( local => sub {
    $mech->get('/bulk/gene');
    $mech->submit_form_ok({
        form_name => "bulk_gene",
        fields    => {
            ids       => "Solyc02g081670.1",
            gene_type => 'not_valid',
        },
    }, "submit bulk_gene with a single valid identifier");
    $mech->content_like(qr/Invalid data type chosen/) or diag $mech->content;
});

$mech->with_test_level( local => sub {
    $mech->get('/bulk/gene');
    $mech->submit_form_ok({
        form_name => "bulk_gene",
        fields    => {
            ids       => "Solyc02g081670.1",
            gene_type => "cdna",
        },
    }, "submit bulk_gene with a single valid identifier for cdna");
    my $sha1 = sha1_hex("cdna Solyc02g081670.1");
    $mech->content_unlike(qr/Caught exception/) or diag $mech->content;
    $mech->content_unlike(qr/Your query did not contain any valid identifiers/) or diag $mech->content;
    my @flinks = $mech->find_all_links( url_regex => qr{/bulk/gene/download/$sha1\.fasta} );
    cmp_ok(@flinks, '==', 1, "found one FASTA download link for $sha1.fasta");
    $mech->links_ok( \@flinks );

    # TODO: Depends on live data.

# cDNA sequence for Solyc02g081670.1
chomp(my $expected_sequence =<<SEQ);
ATGGAAGCTTTTCATCATCCCCCTATTAGCTTTCACTTTCCCTATGCTTTTCCTATCCCAACACCAACAACCAATTTTCTTGGAACTCCAAATTCATCATCAGTTAATGGAATGATCATCAACACTTGGATGGATAGTAGAATTTGGAGTAGACTTCCACATAGGCTTATTGATAGAATCATTGCTTTTCTACCACCACCTGCTTTCTTTAGAGCTAGAGTTGTGTGTAAGAGATTCTATGGACTTATTTACTCTACACATTTTCTTGAATTGTACTTGCAAGTTTCACCTAAGAGGAACTGGTTCATTTTCTTTAAACAAAAAGTACCAAGAAACAACATTTACAAGAACGTGATGAATAGTAGTAACTCAGGAGTTTGTTCTGTTGAAGGTTACTTGTTTGATCCTGATAATCTTTGTTGGTATAGGCTTTCTTTTGCTTTAATCCCACAAGGGTTTTCTCCTGTTTCATCTTCTGGTGGATTAATTTGCTTTGTTTCTGATGAATCTGGATCAAAAAACATTCTTTTATGTAATCCACTTGTAGGATCCATAATTCCCCTGCCTCCAACTTTAAGGCCTAGGCTTTTTCCTTCTATTGGTTTAACTATAACCAACACATCTATTGATATAGCTGTAGCTGGAGATGACTTGATATCACCTTATGCTGTTAAAAACTTAACTACAGAGTCATTTCATATTGATGGTAATGGATTTTACTCAATATGGGGTACAACTTCTACACTTCCAAGATTATGCAGTTTTGAATCAGGCAAAATGGTGCATGTACAGGGGAGATTTTATTGCATGAATTTTAGTCCTTTTAGTGTGCTTTCTTATGATATAGGGACTAATAACTGGTGCAAGATTCAAGCCCCGATGCGACGATTCCTACGTTCACCGAGCCTTGTTGAAGGGAATGGTAAGGTTGTTTTAGTTGCAGCAGTTGAAAAGAGTAAACTGAATGTGCCAAGAAGTTTGAGGCTTTGGGCATTGCAAGATTGTGGTACAATGTGGTTGGAAATAGAAAGAATGCCACAACAATTGTATGTGCAGTTTGCTGAAGTGGAGAATGGACAAGGGTTTAGTTGTGTTGGACATGGTGAATATGTGGTGATAATGATTAAGAATAATTCAGATAAGGCATTGTTGTTTGATTTCTGTAAGAAGAGATGGATTTGGATACCTCCTTGTCCATTTTTGGGAAATAATTTAGACTATGGTGGTGTTGGTAGTAGTAATAATTATTGTGGAGAATTTGGAGTTGGAGGGGGAGAGTTGCATGGATTTGGTTATGACCCTAGACTTGCTGCACCTATTGGTGCACTTCTTGATCAGTTGACATTGCCCTTTCAGTCATTCAACTGA
SEQ

    map {
        cmp_ok(length($mech->get($_->url)->content), '>', 0, $_->url . " length > 0 ");
        $mech->content_unlike(qr/Caught exception/) or diag $mech->content;
        $mech->content_like(qr/$expected_sequence/, $_->url . " looks like expected sequence") or diag $mech->content;
    } @flinks;

});

$mech->with_test_level( local => sub {
    $mech->get('/bulk/gene');
    $mech->submit_form_ok({
        form_name => "bulk_gene",
        fields    => {
            ids       => "Solyc02g081670.1",
            gene_type => "protein",
        },
    }, "submit bulk_gene with a single valid identifier for protein");
    my $sha1 = sha1_hex("protein Solyc02g081670.1");
    $mech->content_unlike(qr/Caught exception/) or diag $mech->content;
    $mech->content_unlike(qr/Your query did not contain any valid identifiers/) or diag $mech->content;
    my @flinks = $mech->find_all_links( url_regex => qr{/bulk/gene/download/$sha1\.fasta} );
    cmp_ok(@flinks, '==', 1, "found one FASTA download link for $sha1.fasta");
    $mech->links_ok( \@flinks );
    # TODO: Depends on live data.
chomp(my $expected_sequence =<<SEQ);
MEAFHHPPISFHFPYAFPIPTPTTNFLGTPNSSSVNGMIINTWMDSRIWSRLPHRLIDRIIAFLPPPAFFRARVVCKRFYGLIYSTHFLELYLQVSPKRNWFIFFKQKVPRNNIYKNVMNSSNSGVCSVEGYLFDPDNLCWYRLSFALIPQGFSPVSSSGGLICFVSDESGSKNILLCNPLVGSIIPLPPTLRPRLFPSIGLTITNTSIDIAVAGDDLISPYAVKNLTTESFHIDGNGFYSIWGTTSTLPRLCSFESGKMVHVQGRFYCMNFSPFSVLSYDIGTNNWCKIQAPMRRFLRSPSLVEGNGKVVLVAAVEKSKLNVPRSLRLWALQDCGTMWLEIERMPQQLYVQFAEVENGQGFSCVGHGEYVVIMIKNNSDKALLFDFCKKRWIWIPPCPFLGNNLDYGGVGSSNNYCGEFGVGGGELHGFGYDPRLAAPIGALLDQLTLPFQSFN*
SEQ
    map {
        cmp_ok(length($mech->get($_->url)->content), '>', 0, $_->url . " length > 0 ");
        $mech->content_unlike(qr/Caught exception/) or diag $mech->content;
        $mech->content_like(qr/$expected_sequence/, $_->url . " looks like expected sequence") or diag $mech->content;
    } @flinks;
});
