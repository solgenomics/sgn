use strict;
use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/  page_title_html
                                       blue_section_html  /;

my ($intro_content, $ref_content);

##########################################
#Define the summary
$intro_content = "<tr><td><p>The maximum likelihood (ML) method was used to reconstruct gene trees for SGN gene families.  The software for tree construction was PAUP*4.0 [1]. Trees were reconstructed based strictly on the overlapping region of sequence shared by all members in the gene family multiple species alignments. </p> <p>Due to unknown evolutionary dynamics of these gene families, the program package MODELTEST [2] was used to choose the most suitable DNA substitution model out of a set of 56 pre-defined models.  The selected model was subsequently used to reconstruct a ML tree of a SGN gene family.[3]</p> <p>To increase the probability of identifying the most accurate tree, all possible tree topologies were searched and compared by branch and bound algorithm embedded in PAUP*4.0. The tree with the highest likelihood is referred to as the ML tree and displayed in the family alignment page.</p><p>Please note that all the SGN family gene trees are un-rooted.</p></td></tr>";


#################################################
#Define references
$ref_content = "<tr><th valign='top'>[1] </th><td>SWOFFORD, D. L., 2003 PAUP*. Phylogenetic Analysis Using Parsimony (*and Other Methods). Version 4. Sinauer Associates, Sunderland, Massachusetts.</td></tr>";

$ref_content .= "<tr><th valign='top'>[2] </th><td>POSADA, D., and K. A. CRANDALL, 1998 MODELTEST: testing the model of DNA substitution, pp. 817-818 in Bioinformatics.</td></tr>";

$ref_content .= "<tr><th valign='top'>[3] </th><td>Wu F. et al, Combining Bioinformatics and Phylogenetics to Identify Large Sets of Single Copy, Orthologous Genes (COSII) for Comparative, Evolutionary and Systematic Studies: A Test Case in Euasterid Plant Species. submitted to Genetics. </td></tr>";


################################################
#Generate the page
our $page = CXGN::Page->new( "Gene Family Tree Help Page", "Chenwei Lin");
$page->header();
print page_title_html("SGN Gene Family Tree");


print blue_section_html('Introduction','<table width="100%" summary="" cellpadding="3" cellspacing="0" border="0">'.$intro_content.'</table>');

print blue_section_html('References','<table width="100%" summary="" cellpadding="3" cellspacing="0" border="0">'.$ref_content.'</table>');





$page->footer();
