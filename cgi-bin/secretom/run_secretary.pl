
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

print<<END_STLOGO;
<div style="width:100%; color:#303030; font-size: 1.1em; text-align:left;">
<center>
<img style="margin-bottom:10px" src="/documents/img/secretom/secretom_logo_smaller.jpg" alt="secretom logo" />
</center>
END_STLOGO

print<<SECRETARY_TITLE;
<center>
<font size="+3"><b>SecreTary</b></font> 
</center>
SECRETARY_TITLE


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
my $show_max_length = 62;
foreach (reverse @$STApreds) {
    my $STA = $_->[0];
    my $prediction = $_->[1];
    $prediction =~ /\((.*)\)\((.*)\)/;
    my ($soln1, $soln2) = ($1, $2);
    my $prediction = substr($prediction, 0, 3 );
    $count_pass++ if ( $prediction eq "YES" );

    my $id = substr( $STA->get_sequence_id() . "                    ", 0, 15 );
    my $sequence = $STA->get_sequence();
    my $orig_length = length $sequence;
    $sequence = padtrunc($sequence, $show_max_length);
    my ($hl_sequence, $solution) = highlight_region($sequence, $soln1, $soln2);
  #  print "solution: $solution \n";
    my ($score, $start, $end) = ('        ','      ','      ');
 my $tmh_l = '    ';
    if($solution =~ /^(.*),(.*),(.*)/){
	($score, $start, $end) = ($1, $2, $3);
 $score = padtrunc($score, 8);
 $start = padtrunc($start, 6);
 $tmh_l = padtrunc($end-$start+1, 4);
    }
    $hl_sequence .= ($orig_length > length $sequence)? '...': '   ';
 
  #  print "score: $score \n padtrunc score [", padtrunc($score, 5), "]\n";
   
   
   
# $result_string .= "$id   $prediction   $soln1   $sequence\n";
    $result_string .= "$id  $prediction    $score $start $tmh_l  $hl_sequence\n";
  #  print '<FONT style="BACKGROUND-COLOR: yellow">next </FONT>week.';

}
print<<XX;
<font size="+1">SecreTary SP Predictions</font></br>
XX

print '<pre>', "Identifier       SP     Score  Start  Length  Sequence 10        20        30        40        50        60\n";
print "                                                       |         |         |         |         |         |\n";
print $result_string;
print "\n$count_pass secreted sequences predicted out of ", scalar @$STApreds,
  ".\n";
print '</pre>';

print qq|<a href="secretary_predictor.pl">Return to SecreTary input page</a><br /><br />|;

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

sub padtrunc{ #return a string of length $length, truncating or
# padding with spaces as necessary
    my $str = shift;
    my $length = shift;
    while(length $str < $length){ $str .= "                    "; }
    return substr($str, 0, $length);
}

sub highlight_region{ # generate html for a string with a region of it highlighted
    my $seq = shift;
    my $soln1 = shift;
    my $soln2 = shift;
    my $soln = $soln1;
    my $color = "yellow";
    my @x = split(",", $soln1);
    if($x[0] < $min_tmpred_score1){
	$color = "yellow";
	$soln = $soln2;
    }    $soln =~ /(.*),(.*),(.*)/;
 #   print "soln:[$soln]\n";
    my $score = $1;
    my $hl_first = $2; # 1 based
    my $hl_last = $3;
    my $len = length $seq;
 #   print "soln: $score,$hl_first,$hl_last \n";
# pre tmh 1 to $hl_first-1, or, 0 to $hl_first-2;  length = $hl_first-1
# tmh   $hl_first to $hl_last, or $hl_first-1 to $hl_last-1; L = $hl_last-$hl_first+1
# post tmh $hl_last+1 to $len, or $hl_last to $len-1; L = $len - $hl_last
    return $seq if($score < $min_tmpred_score2);
    return $seq if($score eq '-1');
    my $html_str = substr($seq, 0, $hl_first - 1);
    if(length($seq) >= $hl_first){
    $html_str .= '<FONT style="BACKGROUND-COLOR: ' . "$color" . '">' . substr($seq, $hl_first-1, $hl_last-$hl_first+1) . '</FONT>';
}
if($len > $hl_last){
    $html_str .= substr($seq, $hl_last, $len - $hl_last);
}
    return ($html_str, $soln);
}
