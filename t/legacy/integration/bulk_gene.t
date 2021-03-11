use strict;
use warnings;
use Test::More tests => 61;
use Test::Differences;

use lib 't/lib';
use SGN::Test::WWW::Mechanize skip_cgi => 1;
use SGN::Test::Data qw/ create_test /;
use Catalyst::Test 'SGN';
use Digest::SHA qw/sha1_hex/;
use Data::Dumper;

my $mech = SGN::Test::WWW::Mechanize->new;

$mech->with_test_level( remote => sub {
    $mech->get('/tools/bulk/tabs/gene_tab');
    $mech->submit_form_ok({
        form_name => "bulk_gene",
        fields    => {
            ids       => "Solyc02g081670 BLARG",
            gene_type => 'cdna',
        },
    }, "submit bulk_gene with some invalid identifiers");
});

$mech->with_test_level( remote => sub {
    $mech->get('/tools/bulk/tabs/gene_tab');
    $mech->submit_form_ok({
        form_name => "bulk_gene",
        fields    => {
            ids       => "NYARLATHOTEP BLARG",
            gene_type => 'cdna',
        },
    }, "submit bulk_gene with all invalid identifiers");
    $mech->content_like(qr/did not contain any valid identifiers/);
});

$mech->with_test_level( remote => sub {
    $mech->get('/tools/bulk/tabs/gene_tab');
    $mech->submit_form_ok({
        form_name => "bulk_gene",
        fields    => {
            ids       => "Solyc02g081670",
            gene_type => '',
        },
    }, "submit bulk_gene with a single valid identifier but invalid gene_type");
    $mech->content_like(qr/Invalid data type chosen/);
});

$mech->with_test_level( remote => sub {
    $mech->get('/tools/bulk/tabs/gene_tab');
    $mech->submit_form_ok({
        form_name => "bulk_gene",
        fields    => {
            ids       => "Solyc02g081670",
            gene_type => 'not_valid',
        },
    }, "submit bulk_gene with a single valid identifier");
    $mech->content_like(qr/Invalid data type chosen/);
});

$mech->with_test_level( remote => sub {
    $mech->get('/tools/bulk/tabs/gene_tab');
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

$mech->with_test_level( remote => sub {
    my $id        = 'Solyc02g081670';
    my $gene_type = 'cds';
    $mech->get_ok('/tools/bulk/tabs/gene_tab');
    $mech->submit_form_ok({
        form_name => "bulk_gene",
        fields    => {
            ids       => $id,
            gene_type => $gene_type,
        },
    }, "submit bulk_gene with a single valid identifier for cdna");
    my $sha1 = sha1_hex("cds $id");
    $mech->content_unlike(qr/Caught exception/) or diag $mech->content;
    $mech->content_unlike(qr/Your query did not contain any valid identifiers/);
    $mech->content_unlike(qr/Invalid data type/);
    $mech->content_unlike(qr/At least one valid identifier must be given/);
    my @flinks = $mech->find_all_links( url_regex => qr{/gene/download/$sha1\.fasta} );
    cmp_ok(@flinks, '==', 1, "found one FASTA download link for $gene_type $id $sha1.fasta");
    $mech->links_ok( \@flinks );

# cds sequence for Solyc02g081670.1
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

$mech->with_test_level( remote => sub {
    my $id        = 'Solyc02g081670';
    my $gene_type = 'cdna';
    $mech->get_ok('/tools/bulk/tabs/gene_tab');
    $mech->submit_form_ok({
        form_name => "bulk_gene",
        fields    => {
            ids       => $id,
            gene_type => $gene_type,
        },
    }, "submit bulk_gene $id with a single valid identifier for cdna");
    my $sha1 = sha1_hex("cdna $id");
    $mech->content_unlike(qr/Caught exception/) or diag $mech->content;
    $mech->content_unlike(qr/Your query did not contain any valid identifiers/);
    $mech->content_unlike(qr/Invalid data type/);
    $mech->content_unlike(qr/At least one valid identifier must be given/);
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

$mech->with_test_level( remote => sub {
    $mech->get('/tools/bulk/tabs/gene_tab');
    my $gene_type = 'protein';
    my $id        = "Solyc02g081670";
    $mech->submit_form_ok({
        form_name => "bulk_gene",
        fields    => {
            ids       => $id,
            gene_type => $gene_type,
        },
    }, "submit bulk_gene $id with a single valid identifier for protein");
    my $sha1 = sha1_hex("protein $id");
    $mech->content_unlike(qr/Caught exception/) or diag $mech->content;
    $mech->content_unlike(qr/Your query did not contain any valid identifiers/);
    $mech->content_unlike(qr/At least one valid identifier must be given/);
    my @flinks = $mech->find_all_links( url_regex => qr{/bulk/gene/download/$sha1\.fasta} );
    cmp_ok(@flinks, '==', 1, "found one FASTA download link for $gene_type $id $sha1.fasta");
    $mech->links_ok( \@flinks );
    # TODO: Depends on live data.
my $expected_sequence =<<SEQ;
>Solyc02g081670.1.1 Fimbriata (Fragment) (AHRD V1 **-- Q6QVW9_MIMLE); contains Interpro domain(s)  IPR001810  Cyclin-like F-box 
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

$mech->with_test_level( remote => sub {
    $mech->get('/tools/bulk/tabs/gene_tab');
    my $gene_type = 'protein';
    my $id        = "Solyc02g092680";
    $mech->submit_form_ok({
        form_name => "bulk_gene",
        fields    => {
            ids       => $id,
            gene_type => $gene_type,
        },
    }, "submit bulk_gene $id with a single valid identifier for protein");
    my $sha1 = sha1_hex("protein $id");
    $mech->content_unlike(qr/Caught exception/) or diag $mech->content;
    $mech->content_unlike(qr/Your query did not contain any valid identifiers/);
    $mech->content_unlike(qr/At least one valid identifier must be given/);
    my @flinks = $mech->find_all_links( url_regex => qr{/bulk/gene/download/$sha1\.fasta} );
    cmp_ok(@flinks, '==', 1, "found one FASTA download link for $gene_type $id $sha1.fasta");
    $mech->links_ok( \@flinks );
    # TODO: Depends on live data.
my $expected_sequence = <<SEQ;
>Solyc02g092680.1.1 Subtilisin-like protease (AHRD V1 ***- A9XG40_TOBAC); contains Interpro domain(s)  IPR015500  Peptidase S8, subtilisin-related 
MSTYPLIVVVVVLVCLCHMSVAMEEKKTYIIHMAKSQMPATFDDHTHWYDASLKSVSESA
EMIYVYNNVIHGFAARLTAQEAESLKTQPGILSVLSEVIYQLHTTRTPLFLGLDNRPDVF
NDSDAMSNVIIGILDSGIWPERRSFDDTGLGPVPESWKGECESGINFSSAMCNRKLIGAR
YFSSGYEATLGPIDESKESKSPRDNEGHGTHTASTAAGSVVQGASLFGYASGTARGMAYR
ARVAVYKVCWLGKCFGPDILAGMDKAIDDNVNVLSLSLGGEHFDFYSDDVAIGAFAAMEK
GIMVSCSAGNAGPNQFSLANQAPWITTVGAGTVDRDFPAYVSLGNGKNFSGVSLYAGDPL
PSGMLPLVYAGNASNATNGNLCIMGTLIPEKVKGKIVLCDGGVNVRAEKGYVVKSAGGAG
MIFANTNGLGLLADAHLLPAAAVGQLDGDEIKKYITSDPNPTATILFGGTMVGVQPAPIL
AAFSSRGPNSITPEILKPDIIAPGVNILAGWSGAVGPTGLPEDDRRVEFNIISGTSMSCP
HVSGLAALLKGVHPEWSPAAIRSALMTTAYTTYRNGGALLDVATGKPSTPFGHGAGHVDP
VSAVNPGLVYDINADDYLNFLCALKYSPSQINIIARRNFTCDSSKIYSVTDLNYPSFSVA
FPADTGSNTIRYSRTLTNVGPSGTYKVAVTLPDSSVEIIVEPETVSFTQINEKISYSVSF
TAPSKPPSTNVFGKIEWSDGTHLVTSPVAISWS*
SEQ
    map {
        cmp_ok(length($mech->get($_->url)->content), '>', 0, $_->url . " length > 0 ");
        $mech->content_unlike(qr/Caught exception/) or diag $mech->content;
        $mech->content_unlike(qr/Unable to perform storage-dependent operations/);
        eq_or_diff($mech->content,$expected_sequence, $_->url . " looks like expected sequence");
    } @flinks;
});



$mech->with_test_level( remote => sub {
    $mech->get('/tools/bulk/tabs/gene_tab');
    my $gene_type = 'protein';
    my $id        = "Os01g0276000";
    $mech->submit_form_ok({
        form_name => "bulk_gene",
        fields    => {
            ids  => "01g0274500\r\n Os01g0274601\r\n Os01g0274800\r\n Os01g0274901\r\n Os01g0275200\r\n Os01g0275300\r\n Os01g0275500\r\n Os01g0275600\r\n Os01g0275800\r\n Os01g0275900\r\n Os01g0275950\r\n Os01g0276000\r\n Os01g0276100\r\n Os01g0276200\r\n Os01g0276300\r\n Os01g0276400\r\n Os01g0276500\r\n Os01g0276600\r\n Os01g0276700\r\n Os01g0276800\r\n Os01g0276900\r\n",
            gene_type => $gene_type,
        },
    }, "submit bulk_gene with a single valid identifier for protein");
    my $sha1 = sha1_hex("protein $id");
    $mech->content_unlike(qr/Caught exception/) or diag $mech->content;
    $mech->content_unlike(qr/Your query did not contain any valid identifiers/);
    $mech->content_unlike(qr/At least one valid identifier must be given/);
    my @flinks = $mech->find_all_links( url_regex => qr{/bulk/gene/download/[a-f\d]+\.fasta} );
    cmp_ok(@flinks, '==', 1, "found one FASTA download link for $gene_type $id $sha1.fasta");
    $mech->links_ok( \@flinks );

    for( @flinks ) {
        cmp_ok(length($mech->get($_->url)->content), '>', 0, $_->url . " length > 0 ");
        $mech->content_unlike(qr/Caught exception/) or diag $mech->content;
        $mech->content_unlike(qr/Unable to perform storage-dependent operations/);
    }
});


