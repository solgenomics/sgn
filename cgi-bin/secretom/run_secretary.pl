
use strict;
use English;
use IO::Scalar;
use File::Temp;
use File::Spec;
use CXGN::Debug;
use CXGN::BlastDB;
use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/page_title_html/;
use SecreTaryAnalyse;
use SecreTarySelect;
use CGI;

my $page = CXGN::Page->new( "SecreTary secretion prediction results", "TomFY" );
my $input = $page->get_arguments("sequence");

my $temp_file_path = $page->path_to( $page->tempfiles_subdir('secretary') );

$page->header();
$page->add_style( text => <<EOS );
a[href^="http:"] {
  padding-right: 0;
  background: none;
}
EOS
my $q = CGI->new();

my @STAarray = ();
my $trunc_length = 100;
my $id_seqs = process_input($input);

#Calculate the necessary quantities for each sequence:
foreach my $id ( keys %$id_seqs ) {
    my $sequence = $id_seqs->{$id};
    my $STAobj =
      SecreTaryAnalyse->new( $id, substr( $sequence, 0, $trunc_length ) );
    push @STAarray, $STAobj;
}

my $min_tmpred_score1 = 1500;
my $min_tmh_length1   = 17;
my $max_tmh_length1   = 33;
my $max_tmh_beg1      = 30;

my $min_tmpred_score2 = 900;
my $min_tmh_length2   = 17;
my $max_tmh_length2   = 33;
my $max_tmh_beg2      = 17;

my $min_AI22        = 71.304;
my $min_Gravy22     = 0.2636;
my $max_nDRQPEN22   = 8;
my $max_nNitrogen22 = 34;
my $max_nOxygen22   = 32;
my @STSparams       = (
    $min_tmpred_score1, $min_tmh_length1,   $max_tmh_length1,
    $max_tmh_beg1,      $min_tmpred_score2, $min_tmh_length2,
    $max_tmh_length2,   $max_tmh_beg2,      $min_AI22,
    $min_Gravy22,       $max_nDRQPEN22,     $max_nNitrogen22,
    $max_nOxygen22
);
my $STSobj   = SecreTarySelect->new(@STSparams);
my $STApreds = $STSobj->Categorize( \@STAarray );

my $result_string   = "";
my $count_pass      = 0;
my $show_max_length = 60;
foreach (reverse @$STApreds) {
    my $STA = $_->[0];
    my $prediction = substr( $_->[1] . "   ", 0, 3 );
    $count_pass++ if ( $prediction eq "YES" );
    my $id = substr( $STA->get_sequence_id() . "                    ", 0, 20 );
    my $sequence = $STA->get_sequence();
    if ( length $sequence > $show_max_length ) {
        $sequence = substr( $sequence, 0, $show_max_length ) . "...";
    }
    else {
        $sequence .= "                                                              ";    #pad
        $sequence = substr( $sequence, 0, $show_max_length + 3 );
    }
    $result_string .= "$prediction   $id   $sequence\n";
}
print '<pre>', "SecreTary predictions:\n\n";
print $result_string;
print "\n$count_pass secreted sequences predicted out of ", scalar @$STApreds,
  ".\n";
print '</pre>';

print qq|<a href="T1.pl">Return to SecreTary input page</a><br /><br />|;

$page->footer();

sub process_input {

# process fasta input to get hash with ids for keys, sequences for values.
# split on >. Then for each element of result,
# 1) if empty string, skip, 2) get id from 1st line; if looks like seq, not id,
# then id is "web_sequence", 3) look at rest of lines and append any that look
# like sequence (i.e. alphabetic characters only plus possible whitespace at ends)
    my $input            = shift;
    my %id_sequence_hash = ();
    my $wscount          = 0;
    $input =~ s/\r//g;    #remove weird line endings.
         #    $input =~ s/\A(.*)?>//; # remove everything before first '>'.
    $input =~ s/\A\s+|\s+\Z//g;    #< trim whitespace from ends.
    $input =~ s/\*\Z//;            # trim asterisk from end if present.
    my @fastas = split( ">", $input );

    #    print "number of fastas: ", scalar @fastas, "\n";
    foreach my $fasta (@fastas) {
        next if ( $fasta =~ /^$/ );

        #	print "fasta $wscount: [", $fasta, "]\n";
        $fasta =~ s/\A\s+|\s+\Z//g;    #< trim whitespace from ends.
        $fasta =~ s/\*\Z//;
        my @lines = split( "\n", $fasta );
        my $id = shift @lines;
        if ( $id =~ /^\s*([a-zA-Z]+)\s*$/ ) {  # see if line looks like sequence
            unshift @lines, $1;
            $id = "web_sequence" . $wscount;
            $wscount++;
        }
        else {
            if ( $id =~ /^\s*(\S+)/ ) {
                $id = $1;
            }
            else {
                $id = "web_sequence" . $wscount;
                $wscount++;
            }
        }
        my $sequence;
        foreach (@lines) {
            s/\A\s+|\s+\Z//g;    #< trim whitespace from ends.
            if (/^[a-zA-Z]+$/) {
                $sequence .= $_;    # append the line
            }
        }
        $id_sequence_hash{$id} = $sequence;
    }

    return \%id_sequence_hash;
}
