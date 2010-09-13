#!/usr/bin/perl
use strict;
use warnings;
use English;

use Test::More tests => 11;

use lib 't/lib';
use SGN::Test::WWW::Mechanize;

my @invalid_seqs =
    ( [ 'SGN-U409494-translated',
        'MGRMNGNPSARKSKGGEYLYDLCFLPFDSADQIGGIILYCCVGLSSFLASSLSASSSSRMSFENAPGFAFIQFCRATKGWTQSEPXKRVD
TIRALFFCRAFEETEESTRELSTTGAVPQMSNARAVQGFLSLPSRDSFSSSAPYAAASAIKESREGCGEGDWGVGAVAVAAAVDEFDPPR
RHLPSRSGSALDP*'
      ],
      [ 'SGN-U442055-translated',
        'TPHAAAEDILFFAQHSAGTENAAVIKQRLGSLRKKSGHETANXAAVKIIVAIIPNLXAAWAYYQVNDLLQFQSKRWLSKLNFVRDKQNVF
LHWIMQRKVNHLSLLIVNLMGNDHGCVIFISVLAFEVVYASLNPVMTNYSEIELDEPIRRPNIVDEAAKTAASQHLTPPISDRKSWGQPK
YFTCWSIENSLSTDTVGVRFAYYLSFPHPX ',
      ],
    );

my @no_hits_seqs =
    (['SGN-U569791','VIRQFILSVLRTYTFFSFSLSECGQIMSLKNRERPTESIILNKETEGSCINTSENSSEI'],
    );

my $input_page = "/tools/sigpep_finder/input.pl";

my $mech = SGN::Test::WWW::Mechanize->new;

# single sequence submission, no ending newline
{
    $mech->get_ok( $input_page );

    # a few checks on the title
    $mech->title_like( qr/Signal peptide finder/i, "Make sure we're on sigpep input page" );

    # a few checks on the content
    $mech->content_contains( "HMMER", "mentions HMMER" );

    $mech->submit_form_ok({ form_name => 'sigseq_form',
                            fields =>
                            {
                             sequences => ">$invalid_seqs[0]->[0]\n$invalid_seqs[0]->[1]",
                             display_opt => 'filter',
#                              use_eval_cutoff => 1,
#                                eval_cutoff => 2,
#                              use_bval_cutoff => 1,
#                                bval_cutoff => 0,
                            },
                          },
                          'submit a single sequence',
                         );

    $mech->content_like( qr/illegal character/i, "mentions illegal characters" );
    $mech->content_like( qr/re-enter input/i, "says to re-enter input" );


    #submit a valid sequence
    $mech->get_ok( $input_page );
    $mech->submit_form_ok({ form_name => 'sigseq_form',
                            fields =>
                            {
                             sequences => ">$no_hits_seqs[0]->[0]\n$no_hits_seqs[0]->[1]\n\n",
                             display_opt => 'filter',
#                              use_eval_cutoff => 1,
#                                eval_cutoff => 2,
#                              use_bval_cutoff => 1,
#                                bval_cutoff => 0,
                            },
                          },
                          'submit a single sequence',
                         );

    $mech->content_like( qr/no hits/i, "mentions no hits" );
    $mech->content_like( qr/Results/i, "mentions results" );
    $mech->content_like( qr/histogram/i, "mentions histogram" );
}



