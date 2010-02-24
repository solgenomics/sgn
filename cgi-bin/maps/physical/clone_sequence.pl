use strict;
use CXGN::Genomic::Clone;
use CXGN::Tools::Text;
use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/page_title_html html_break_string/;
use CXGN::Genomic::Tools qw/clone_annotation_sequence/;

my $page = CXGN::Page->new( 'Clone Sequence', 'john' );
my ($clone_id) = $page->get_encoded_arguments('clone_id');
my $clone = CXGN::Genomic::Clone->retrieve($clone_id)
  or do{ $page->error_page("No clone found with ID '$clone_id'"); exit };

my @seqnames  = $clone->latest_sequence_name;
my @sequences = $clone->seq
  or $page->message_page( "No sequence information for clone "
      . $clone->clone_name
      . ".  If you think you reached this page in error, the database may be in the middle of an update.  Please try again later."
  );
@seqnames == @sequences
  or die 'differing number of seqnames and seqs: '
  . scalar(@seqnames)
  . ' names vs '
  . scalar(@sequences) . ' seqs';

$page->header;
print page_title_html( 'BAC Sequence &ndash; ' . $clone->clone_name );

foreach my $name (@seqnames) {
    my $sequence = shift @sequences;
    print(
        "<span class=\"sequence\">&gt;",
        $name, "<br />",
        html_break_string( $sequence, 100 ),
        "</span><br />",
    );
}
$page->footer;
