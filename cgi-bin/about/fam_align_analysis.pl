use strict;
use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/  page_title_html
                                       blue_section_html  /;

my ($intro_content, $ref_content);

##########################################
#Define the summary
$intro_content = "<tr><td><p>SGN gene family multiple sequence alignment used protein sequence of Arabidopsis and ESTScan-predicted peptide sequences of SGN unigenes[1].  The multiple sequence alignment software was t_coffee [2].</p><p>Following alignment, the nucleotide coding sequences of Arabidopsis proteins and predicted cosing sequences of SGN unigenes were attached to the peptide aignment, keeping the gaps and resulting in \"peptide guided nucleotide alignment\".  This procedure maintains the bound between nucleotide and protein at the same time eliminates the complexity of alignment using nucleotide sequences directly. </p></td></tr>";


#################################################
#Define references
$ref_content = "<tr><th valign='top'>[1] </th><td>Iseli C. et al (1999), ESTScan: a Program for Detectingm Evaluating and Reconstructing Potential Coding Regions in EST Sequences, American Association of Artificial Intellegence.</td></tr>";

$ref_content .= "<tr><th valign='top'>[2] </th><td>Notredame C. et al, T_Coffee: A NOvel Method for Fast and Accurate Multiple Sequence Alignment, J. Mol. Biol., 302:205-217.</td></tr>";


################################################
#Generate the page
our $page = CXGN::Page->new( "Alignment Help Page", "Chenwei Lin");
$page->header();
print page_title_html("SGN Gene Family Alignment");


print blue_section_html('Summary','<table width="100%" summary="" cellpadding="3" cellspacing="0" border="0">'.$intro_content.'</table>');
print blue_section_html('References','<table width="100%" summary="" cellpadding="3" cellspacing="0" border="0">'.$ref_content.'</table>');


$page->footer();
