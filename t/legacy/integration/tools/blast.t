use strict;
use warnings;

use Test::More;

use CXGN::BlastDB;
use lib 't/lib';
use SGN::Test::WWW::Mechanize;
use HTML::Entities;
use IPC::Cmd qw/ can_run /;

unless ( can_run('qsub') ) {
    plan skip_all => 'qsub not found in path';
}

my $tests = 0;

my ( $test_blast_db ) =
    sort { $a->sequences_count <=> $b->sequences_count }
    grep $_->file_modtime,
    CXGN::BlastDB->retrieve_all;

unless ( $test_blast_db ) {
    plan skip_all => 'no test BLAST db';
}

my $urlbase = "/tools/blast/";
my $simple_input = "$urlbase/index.pl";
my $advanced_input = "$urlbase/index.pl?interface_type=1";

my @good_seqs = (
    "\n\n > initial_whitespace  and a defline man!\nGAGCAAGAGCGAGACGCCATTTCTCTACTCAACGAGCGAATTCGCCGGGAGCATGCTAAGAGAGATCACTCCCCTCTTAGACCGGCCA\n",
);


for my $seq (@good_seqs) {
    for my $input_page ( $simple_input, $advanced_input ) {
        my $mech = SGN::Test::WWW::Mechanize->new;
        $mech->get_ok( $input_page );
	$tests++;
        $mech->content_contains('NCBI BLAST');
	$tests++;
        $mech->content_contains('Cite SGN using'); # in footer.  full page displayed
	$tests++;
        $mech->submit_form_ok({ form_name => 'blastform',
                                fields    => {
                                    database => $test_blast_db->blast_db_id,
                                    sequence => $seq,
                                },
                            },
                              "blast a single sequence: '$seq'",
                             );
	$tests++;
        while( $mech->content =~ qr/job running/i ) {
            sleep 1;
            $mech->get( $mech->base );
        }

        $mech->content_contains('Graphics'); $tests++;
        $mech->content_contains('BLAST Report'); $tests++;
        $mech->content_contains('View / download raw report'); $tests++;

        # try to extract some show_match_seq.pl URLs from the document
        # (might be in the JS)
        for my $show_match_seq_url ( $mech->content =~ /['"](show_match_seq\.pl\?[^'"]+)/g ) {
            $mech->get_ok( $show_match_seq_url ); $tests++;
            $mech->content_contains( $test_blast_db->title, 'show_match_seq has the blast db title' ); $tests++;
        }
    }
}

# test that an empty seq results in an input error message
my %errors  = (
    ">foo\n" => encode_entities('Sequence "foo" is empty'),
    ">foo\nZZZZZZZ.Z" => 'contains invalid',
);

while( my ($input,$error) = each %errors ) {

  my $mech = SGN::Test::WWW::Mechanize->new;
  $mech->get_ok( $advanced_input ); $tests++;

  $mech->submit_form_ok({ form_name => 'blastform',
                          fields    => {
                              database => $test_blast_db->blast_db_id,
                              sequence => $input,
                             },
                        },
                        'blast an empty sequence'
                       );
  $tests++;
  $mech->content_contains( $error, "got right error message for input '$input'" );$tests++;
}

done_testing($tests);
