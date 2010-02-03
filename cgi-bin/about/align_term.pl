use strict;
use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/  page_title_html
                                       blue_section_html  /;

my ($sum_content, $term_content, $ref_content);

##########################################
#Define the summary
$sum_content = "<tr><td><p>SGN Alignment Viewer displays, analyzes and provides the user with hint and opportunity to optimize the alignment (get maximal overlapping alignment sequences that can be subjected to gene tree analysis.</p></td></tr>";


#########################################
#Define the terms
$term_content = "<tr><th valign='top'>Cover Range</th><td>The position of the first to the last non-gap sequence.</td></tr>";

$term_content .= "<tr><th valign='top'>Bases</th><td>Number of \"real sequence characters\" (non gap) in the sequence.</td></tr>";

$term_content .= "<tr><th valign='top'>Gaps</th><td>Gaps in aligment</td></tr>"; 

$term_content .= "<tr><th valign='top'>Medium</th><td>The middle position of all non-gap characters of the alignment sequence</td></tr>";

$term_content .= "<tr><th valign='top'>Putative Splice Variant Pairs</th><td>Sequence pairs that are from the same species, that <b>1.</b> Share at least 60 bases if they are nucleotides or 20 bases if they are peptides.  <b>2. </b> Share at least 95% sequence similarity in the overlapping region. <b>3.</b>Have insertion/deletion of at least 4 amino acids or 12 nucleotides in their common region. </td></tr>"; 

$term_content .= "<tr><th valign='top'>Putative Allels</th><td>Sequence pairs that are from the same species, that <b>1.</b> Share at least 60 bases if they are nucleotides or 20 bases if they are peptides.  <b>2. </b> Share at least 95% sequence similarity in the overlapping region. <b>3.</b> Have insertion/deletion <b>not more than </b> 4 amino acids or 12 nucleotides in their common region.</td></tr>"; 

$term_content .= "<tr><th valign='top'>Overlap Score</th><td>An indication of how the sequence overlap with other members in the alignment.  If a character (non gap) of a sequence overlap with a character in another alignment sequence, it get a point.  Sometimes in an alignment, only a few sequences overlaps very little with others, significantly reduce the overall overlapping sequence of the alignment.  Usually (but not necessarily) these sequences are short and won't help with the understanding of overall alignment.  We suggest the user leaves out these sequence before further analysis with the aligment sequence. </td></tr>";



################################################
#Generate the page
our $page = CXGN::Page->new( "Gene Family Help Page", "Chenwei Lin");
$page->header();
print page_title_html("SGN Alignment Terms");


print blue_section_html('Summary','<table width="100%" summary="" cellpadding="3" cellspacing="0" border="0">'.$sum_content.'</table>');
print blue_section_html('Terms','<table width="100%" summary="" cellpadding="3" cellspacing="0" border="0">'.$term_content.'</table>');


$page->footer();
