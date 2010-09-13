
use strict;
use warnings;

use IO::Scalar;
use File::Temp;
use File::Spec;
use CXGN::Debug;
use CXGN::BlastDB;
use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/page_title_html/;
use SGN::IntronFinder::Homology;

my $d = CXGN::Debug->new();

my $page = CXGN::Page->new( "Intron Finder Results", "Emil" );

my $temp_file_path = $page->path_to($page->tempfiles_subdir('intron_detection'));

$page->add_style( text => <<EOS );
a[href^="http:"] {
  padding-right: 0;
  background: none;
}
EOS

my ( $input, $blast_e_val ) = $page->get_arguments( "genes", "blast_e_value" );
$input =~ s/\r//g;    #remove weird line endings
$input =~ s/^\s+|\s+$//g; #< trim whitespace
$input = ">web_sequence\n$input" unless $input =~ /^>/;

$blast_e_val =~ s/(^\s*|\s*)//g;
if ( $blast_e_val !~ m/^\d+(e-\d+)?$/ ) {
    show_error(
        $page,
        'e_bad'          => 1,
        'seq_bad'        => 0,
        'seq_notindb'    => 0,
        'unfound_seq_id' => ''
    );
    return 1;
}

my $out_file = File::Temp->new(
    TEMPLATE => 'intron-finder-output-XXXXXX',
    DIR      => $temp_file_path,
);
$out_file->close;    #< can't use this filehandle

$page->header();
print page_title_html("Intron Finder Results");

$d->d("Runninge the intron finder command...\n");

my ($protein_db) = CXGN::BlastDB->search( file_base => 'ath1/ATH1_pep' ) or die "could not find ath1/ATH1_pep BLAST database";

my $gene_feature_file =
  ( $page->get_conf('intron_finder_database')
      || die 'no conf var intron_finder_database defined!' )
  . "/SV_gene_feature.data";

-f $gene_feature_file or die "gene feature file '$gene_feature_file' not found";

print '<pre>';
my $output;
open my $input_fh, '<', \$input or die $!;
open my $output_fh, '>', \$output or die $!;

SGN::IntronFinder::Homology::find_introns_txt
    ( $input_fh,
      $output_fh,
      $blast_e_val,
      $gene_feature_file,
      $temp_file_path,
      $protein_db->full_file_basename,
    );
print $output;
print '</pre>';
print qq|<a href="find_introns.pl">Return to search page</a><br /><br />|;

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
