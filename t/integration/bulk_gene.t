use strict;
use warnings;
use Test::More tests => 39;
use Test::Differences;

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
            ids       => "Solyc02g081670 BLARG",
            gene_type => 'cdna',
        },
    }, "submit bulk_gene with some invalid identifiers");
});
$mech->with_test_level( local => sub {
    $mech->get('/bulk/gene');
    $mech->submit_form_ok({
        form_name => "bulk_gene",
        fields    => {
            ids       => "NYARLATHOTEP BLARG",
            gene_type => 'cdna',
        },
    }, "submit bulk_gene with all invalid identifiers");
});

$mech->with_test_level( local => sub {
    $mech->get('/bulk/gene');
    $mech->submit_form_ok({
        form_name => "bulk_gene",
        fields    => {
            ids       => "Solyc02g081670",
            gene_type => '',
        },
    }, "submit bulk_gene with a single valid identifier but invalid gene_type");
    $mech->content_like(qr/Invalid data type chosen/);
});

$mech->with_test_level( local => sub {
    $mech->get('/bulk/gene');
    $mech->submit_form_ok({
        form_name => "bulk_gene",
        fields    => {
            ids       => "Solyc02g081670",
            gene_type => 'not_valid',
        },
    }, "submit bulk_gene with a single valid identifier");
    $mech->content_like(qr/Invalid data type chosen/);
});
$mech->with_test_level( local => sub {
    $mech->get('/bulk/gene');
    $mech->submit_form_ok({
        form_name => "bulk_gene",
        fields    => {
            ids       => "Solyc02g081670",
            gene_type => "cds",
        },
    }, "submit bulk_gene with a single valid identifier for cds");
    $mech->content_unlike(qr/Caught exception/);
    $mech->content_unlike(qr/Your query did not contain any valid identifiers/);
});
$mech->with_test_level( local => sub {
    my $id        = 'Solyc02g081670';
    my $gene_type = 'cds';
    $mech->get_ok('/bulk/gene');
    $mech->submit_form_ok({
        form_name => "bulk_gene",
        fields    => {
            ids       => $id,
            gene_type => $gene_type,
        },
    }, "submit bulk_gene with a single valid identifier for cdna");
    my $sha1 = sha1_hex("cds Solyc02g081670");
    $mech->content_unlike(qr/Caught exception/) or diag $mech->content;
    $mech->content_unlike(qr/Your query did not contain any valid identifiers/);
    $mech->content_unlike(qr/Invalid data type/);
    my @flinks = $mech->find_all_links( url_regex => qr{/bulk/gene/download/$sha1\.fasta} );
    cmp_ok(@flinks, '==', 1, "found one FASTA download link for $gene_type $id $sha1.fasta");
    $mech->links_ok( \@flinks );

# cds sequence for Solyc02g081670.1
my $expected_sequence =<<SEQ;
FOOBAR
SEQ

    map {
        cmp_ok(length($mech->get($_->url)->content), '>', 0, $_->url . " length > 0 ");
        $mech->content_unlike(qr/Caught exception/) or diag $mech->content;
        eq_or_diff($mech->content,$expected_sequence, $_->url . " looks like expected sequence");
    } @flinks;

});

$mech->with_test_level( local => sub {
    my $id        = 'Solyc02g081670';
    my $gene_type = 'cdna';
    $mech->get_ok('/bulk/gene');
    $mech->submit_form_ok({
        form_name => "bulk_gene",
        fields    => {
            ids       => $id,
            gene_type => $gene_type,
        },
    }, "submit bulk_gene with a single valid identifier for cdna");
    my $sha1 = sha1_hex("cdna Solyc02g081670");
    $mech->content_unlike(qr/Caught exception/) or diag $mech->content;
    $mech->content_unlike(qr/Your query did not contain any valid identifiers/);
    $mech->content_unlike(qr/Invalid data type/);
    my @flinks = $mech->find_all_links( url_regex => qr{/bulk/gene/download/$sha1\.fasta} );
    cmp_ok(@flinks, '==', 1, "found one FASTA download link for $gene_type $id $sha1.fasta");
    $mech->links_ok( \@flinks );

    # TODO: Depends on live data.

# cDNA sequence for Solyc02g081670.1
my $expected_sequence =<<SEQ;
>Solyc02g081670.1.1 Fimbriata (Fragment) (AHRD V1 **-- Q6QVW9_MIMLE); contains Interpro domain(s)  IPR001810  Cyclin-like F-box 
ATGGAAGCTTTTCATCATCCCCCTATTAGCTTTCACTTTCCCTATGCTTTTCCTATCCCA
ACACCAACAACCAATTTTCTTGGAACTCCAAATTCATCATCAGTTAATGGAATGATCATC
AACACTTGGATGGATAGTAGAATTTGGAGTAGACTTCCACATAGGCTTATTGATAGAATC
ATTGCTTTTCTACCACCACCTGCTTTCTTTAGAGCTAGAGTTGTGTGTAAGAGATTCTAT
GGACTTATTTACTCTACACATTTTCTTGAATTGTACTTGCAAGTTTCACCTAAGAGGAAC
TGGTTCATTTTCTTTAAACAAAAAGTACCAAGAAACAACATTTACAAGAACGTGATGAAT
AGTAGTAACTCAGGAGTTTGTTCTGTTGAAGGTTACTTGTTTGATCCTGATAATCTTTGT
TGGTATAGGCTTTCTTTTGCTTTAATCCCACAAGGGTTTTCTCCTGTTTCATCTTCTGGT
GGATTAATTTGCTTTGTTTCTGATGAATCTGGATCAAAAAACATTCTTTTATGTAATCCA
CTTGTAGGATCCATAATTCCCCTGCCTCCAACTTTAAGGCCTAGGCTTTTTCCTTCTATT
GGTTTAACTATAACCAACACATCTATTGATATAGCTGTAGCTGGAGATGACTTGATATCA
CCTTATGCTGTTAAAAACTTAACTACAGAGTCATTTCATATTGATGGTAATGGATTTTAC
TCAATATGGGGTACAACTTCTACACTTCCAAGATTATGCAGTTTTGAATCAGGCAAAATG
GTGCATGTACAGGGGAGATTTTATTGCATGAATTTTAGTCCTTTTAGTGTGCTTTCTTAT
GATATAGGGACTAATAACTGGTGCAAGATTCAAGCCCCGATGCGACGATTCCTACGTTCA
CCGAGCCTTGTTGAAGGGAATGGTAAGGTTGTTTTAGTTGCAGCAGTTGAAAAGAGTAAA
CTGAATGTGCCAAGAAGTTTGAGGCTTTGGGCATTGCAAGATTGTGGTACAATGTGGTTG
GAAATAGAAAGAATGCCACAACAATTGTATGTGCAGTTTGCTGAAGTGGAGAATGGACAA
GGGTTTAGTTGTGTTGGACATGGTGAATATGTGGTGATAATGATTAAGAATAATTCAGAT
AAGGCATTGTTGTTTGATTTCTGTAAGAAGAGATGGATTTGGATACCTCCTTGTCCATTT
TTGGGAAATAATTTAGACTATGGTGGTGTTGGTAGTAGTAATAATTATTGTGGAGAATTT
GGAGTTGGAGGGGGAGAGTTGCATGGATTTGGTTATGACCCTAGACTTGCTGCACCTATT
GGTGCACTTCTTGATCAGTTGACATTGCCCTTTCAGTCATTCAACTGA
SEQ

    map {
        cmp_ok(length($mech->get($_->url)->content), '>', 0, $_->url . " length > 0 ");
        $mech->content_unlike(qr/Caught exception/) or diag $mech->content;
        eq_or_diff($mech->content,$expected_sequence, $_->url . " looks like expected sequence");
    } @flinks;

});

$mech->with_test_level( local => sub {
    $mech->get('/bulk/gene');
    my $gene_type = 'protein';
    my $id        = "Solyc02g081670";
    $mech->submit_form_ok({
        form_name => "bulk_gene",
        fields    => {
            ids       => $id,
            gene_type => $gene_type,
        },
    }, "submit bulk_gene with a single valid identifier for protein");
    my $sha1 = sha1_hex("protein Solyc02g081670");
    $mech->content_unlike(qr/Caught exception/) or diag $mech->content;
    $mech->content_unlike(qr/Your query did not contain any valid identifiers/);
    my @flinks = $mech->find_all_links( url_regex => qr{/bulk/gene/download/$sha1\.fasta} );
    cmp_ok(@flinks, '==', 1, "found one FASTA download link for $gene_type $id $sha1.fasta");
    $mech->links_ok( \@flinks );
    # TODO: Depends on live data.
my $expected_sequence =<<SEQ;
>Solyc02g081670.1.1 protein sequence
MEAFHHPPISFHFPYAFPIPTPTTNFLGTPNSSSVNGMIINTWMDSRIWSRLPHRLIDRI
IAFLPPPAFFRARVVCKRFYGLIYSTHFLELYLQVSPKRNWFIFFKQKVPRNNIYKNVMN
SSNSGVCSVEGYLFDPDNLCWYRLSFALIPQGFSPVSSSGGLICFVSDESGSKNILLCNP
LVGSIIPLPPTLRPRLFPSIGLTITNTSIDIAVAGDDLISPYAVKNLTTESFHIDGNGFY
SIWGTTSTLPRLCSFESGKMVHVQGRFYCMNFSPFSVLSYDIGTNNWCKIQAPMRRFLRS
PSLVEGNGKVVLVAAVEKSKLNVPRSLRLWALQDCGTMWLEIERMPQQLYVQFAEVENGQ
GFSCVGHGEYVVIMIKNNSDKALLFDFCKKRWIWIPPCPFLGNNLDYGGVGSSNNYCGEF
GVGGGELHGFGYDPRLAAPIGALLDQLTLPFQSFN*
SEQ
    map {
        cmp_ok(length($mech->get($_->url)->content), '>', 0, $_->url . " length > 0 ");
        $mech->content_unlike(qr/Caught exception/) or diag $mech->content;
        $mech->content_unlike(qr/Unable to perform storage-dependent operations/);
        eq_or_diff($mech->content,$expected_sequence, $_->url . " looks like expected sequence");
    } @flinks;
});
