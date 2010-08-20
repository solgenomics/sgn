
use strict;
use English;

use lib '/home/tomfy/cxgn/cxgn-corelibs/lib';

use IO::Scalar;

use File::Temp;
use File::Spec;

use CXGN::Debug;

use CXGN::BlastDB;

use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/page_title_html/;

use stuff;
use MCMC;
use SecreTaryAnalyse;
use SecreTarySelect;
#use CXGN::Secretome::SecreTaryAnalyse;
#use SecreTaryAnalyse;
#use CXGN::Secretome::SecreTarySelect;

use CGI;
#my $q = CGI->new;

my $d = CXGN::Debug->new();

my $page = CXGN::Page->new( "SecreTary secretion prediction results", "TomFY" );

my $temp_file_path = $page->path_to( $page->tempfiles_subdir('secretary') );
print $temp_file_path, "\n";

$page->add_style( text => <<EOS );
a[href^="http:"] {
  padding-right: 0;
  background: none;
}
EOS

# parameters for SecreTary Selection:
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

my $STAarray    = ();
my $input       = $page->get_arguments("sequence");
print '<pre>', "input from form: [$input]", '</pre>';
my $id_seq_hash = process_input($input);
 print '<pre>', "ids: ", join("  ", keys %$id_seq_hash), "\n", '</pre>';

my $id_seq_pairs = '';
my $STAobj;

my $tmpred_out = "";

#my $wd = `pwd`;
my $tmpred_dir = '/home/tomfy/tmpred';   
#  $tmpred_out = `$tmpred_dir/tmpred -def-in=tmpred_temp.fasta -out=- -par=$tmpred_dir/matrix.tab -max=40 -min=17`;
if(0){
foreach my $id ( keys %$id_seq_hash ) {
    my $seq = $id_seq_hash->{$id};
    $id_seq_pairs .= $id . "  " . substr( $seq, 0, 30 ) . "\n";
    print "id: $id; sequence: $seq \n";
    $STAobj = SecreTaryAnalyse->new( $id, $seq );
    print( "ref STAobj; ", ref $STAobj, "\n" );

   
  #  print '<pre>', `pwd`, "  ", $tmpred_out, '</pre>';
    # my $STAobj = SecreTaryAnalyse->new1( $id );
   # push( @STAarray, $STAobj );
    my $TMpred_obj = $STAobj->get_TMpred();
    my $dkdkd = $TMpred_obj->get_solutions();
    print "tmpred solns: $dkdkd \n";

}
}
if(0){
my $STSobj = SecreTarySelect->new(@STSparams);
my @sta_array = ($STAobj);
#my ($ng1, $ng2, $nf) = $STSobj->Categorize( \@sta_array );
#print "counts: $count_g1, $count_g2, $count_fail \n";
my $prediction = $STSobj->Categorize1($STAobj);
my $output = $id_seq_pairs . "  " . $prediction . "\n"; # . $ng1 . " " . $ng2 . " " . $nf "\n";
}

my $out_file = File::Temp->new(
    TEMPLATE => 'secretary-output-XXXXXX',
    DIR      => $temp_file_path,
);
$out_file->close;    #< can't use this filehandle

$page->header();
print page_title_html("SecreTary secretion prediction results");
$d->d("Running SecreTary ... \n");

print '<pre>';
my $output = "SecreTary results will appear here:\n"; # . $output . "\n";
print $output;
print "[[[$tmpred_out]]]\n";
print join( "\n", @INC ), "\n";
print '</pre>';

print
qq|<a href="secretary_predictor.pl">Return to SecreTary input page</a><br /><br />|;

$page->footer();

# show there was an error and link back to the entry page
# possible arguments: e_bad => 0|1, seq_bad => 0|1, seq_notindb => 0|1,
# unfound_seq_id => seq_id
#
sub show_error {
    my ( $page, %errors ) = @_;

    $page->add_style( text => "p.error {font-weight: bold}" );
    $page->header();
    print page_title_html("Bad Input");
    if ( $errors{e_bad} ) {
        print
"<p class=\"error\">E-value for blast should be an integer or in xe-xx format.</p>";
    }
    if ( $errors{seq_bad} ) {
        print "<p class=\"error\">Please enter your query in FASTA format.</p>";
    }
    elsif ( $errors{seq_notindb} ) {
        print
"<p class=\"error\">EST identifier $errors{unfound_seq_id} could not be found in the database. Please enter a DNA sequence for it.</p>";
    }

    print "<p><a href=\"find_introns.pl\">Go back</a> and try again.</p>";
    $page->footer();
}

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

