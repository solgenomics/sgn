use strict;
use warnings;

use Test::More;

use CXGN::BlastDB;
use Test::WWW::Mechanize;
use HTML::Entities;

my ( $test_blast_db ) =
    sort { $a->sequences_count <=> $b->sequences_count }
    grep $_->file_modtime,
    CXGN::BlastDB->retrieve_all;

my $urlbase = "$ENV{SGN_TEST_SERVER}/tools/blast/";
my $simple_input = "$urlbase/index.pl";
my $advanced_input = "$urlbase/index.pl?interface_type=1";

my @good_seqs = (
    'TTCGAGGGAATAGATAATGTGGCAAACCCGACGTTCCATTGAAGCTCTGCTTTGAGAAATTAGAACAAGTTTGCTCTTACAAGTTTATCCATCCATGGCCGCTGCAAAGGCCTCCCTCTTCTTCTCTCCCTCGGAGTGCTTTCTCACAACTCGTCTCTGCAAACTCTTCTCCACTACTCAAAAACCCTCTTTTCCCTCTCCCTCCTCCTCTTCTATTACCTTAACCAATGTCCTCAATGCCGATGCTGTACATACCAAATTGCCTCCCCGACTACGGAATGCAAGACAGGAGCAAGAGCGAGACGCCATTTCTCTACTCAACGAGCGAATTCGCCGGGAGCATGCTAAGAGAGATCACTCCCCTCTTAGACCGGCCATGGATTCCGAGGAGGCTGATAAGTACATTCAGCTCGTGAAAGAGCAGCAGCAAAGGGGCCTTCAGAAGCTCAAAAGCGACAGAGCCAGACAAGGTGCTCCACATGATGCAGCTCAACCTACCTTTAGTTACAAGGTGGACCCTTACACTCTCCGTTCCGGCGATTA', #< this is a piece of the marker C2_At3g02060
    "> with_strange_identifier   and a defline man!\nACCCGACGTTCCATTGAAGCTCTGCTTTGAGAAATTAGAACAAGTTTGCTCTTACAAGTTTATCCATCCATGGCCGCTGCAAAGGCCTCCCTCTTCTTCTCTCCCTCGGAGTGCTTTCTCACAACTCGTCTCTGCAAACTCTTCTCCACTACTCAAAAACCCTCTTTTCCCTCTCCCTCCTCCTCTTCTATTACCTTAACCAATGTCCTCAATG",
    "\n\n > initial_whitespace\nGAGCAAGAGCGAGACGCCATTTCTCTACTCAACGAGCGAATTCGCCGGGAGCATGCTAAGAGAGATCACTCCCCTCTTAGACCGGCCA\n",
);


for my $seq (@good_seqs) {
    for my $input_page ( $simple_input, $advanced_input ) {
        my $mech = Test::WWW::Mechanize->new;
        $mech->get_ok( $input_page );

        $mech->content_contains('NCBI BLAST');
        $mech->content_contains('Cite SGN using'); # in footer.  full page displayed

        $mech->submit_form_ok({ form_name => 'blastform',
                                fields    => {
                                    database => $test_blast_db->blast_db_id,
                                    sequence => $seq,
                                },
                            },
                              'blast a single sequence'
                             );
        $mech->content_contains('Graphics');
        $mech->content_contains('BLAST Report');
        $mech->content_contains('View / download raw report');
    }
}

# test that an empty seq results in an input error message
{

  my $mech = Test::WWW::Mechanize->new;
  $mech->get_ok( $advanced_input );

  $mech->submit_form_ok({ form_name => 'blastform',
                          fields    => {
                              database => $test_blast_db->blast_db_id,
                              sequence => ">foo\n",
                             },
                        },
                        'blast an empty sequence'
                       );

  $mech->content_contains( encode_entities('Sequence "foo" is empty') );
}

done_testing;
