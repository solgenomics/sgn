use strict;
use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/  page_title_html
                                       blue_section_html  /;

my ($sum_content, $process_content, $term_content, $ref_content);

##########################################
#Define the summary
$sum_content = "<tr><td><p>SGN gene family analysis groups proteins based on their sequence similarity.  It incoporates the Arabidopsis proteome and peptides predicted from  SGN unigenes (currently from Lycopersicon combined, Solanum tuberosum, Solanum melongena, Capsicum annuum and Petunia hybrida) and coffee unigenes.</p></td></tr>";

##########################################
#Define the process
$process_content = "<tr><th valign=\"top\">1. </th><td>SGN and coffee unigenes are subjected to ESTScan, an HMM-based program to predict coding regions and the corresponding peptide from EST sequences[1].</td></tr>";

$process_content .= "<tr><th valign=\"top\">2. </th><td>Predicted SGN and coffee peptides are combined with Arabidopsis predicted proteins.  A self blastp is performed in the combined protein data set[2].</td></tr>";

$process_content .= "<tr><th valign=\"top\">3. </th><td>TRIBE-MCL program is applied to the blastp result for clustering protein sequences into families[3].  This program first translates blastp result into a similarity matrix.  Based on the matrix , the program  then groups the proteins using Marcov cluster (MCL) algorithm.</td></tr>";


#########################################
#Define the terms
$term_content = "<tr><th valign=\"top\">Data Set</th><td>A combination of Arabidopsis predicted proteins and predicted peptide from current SGN and coffee unigene builds.  If any of the above data set member is updated, for example,  a new unigene build of Solanum tuberosum is built, a new data set is then generated and family analysis is performed in the data set.</td></tr>";

$term_content .= "<tr><th valign=\"top\">i Value</th><td>Clustering of proteins by TRIBE-MCL is carried out by alteration of two operators called expansion and inflation.  While inflation groups genes into clusters, expansion dissipates clusters.  I value controlls the strigency of inflation.  The higher the i value, the more strigent for inflation operator to group genes together.</td></tr>";

$term_content .= "<tr><th valign=\"top\">Family Build</th><td>A family build is uniquely defined by the Data Set and strigency (i Value).  For each SGN Data Set, we do TRIBE-MCL analysis with 3 i Values: 1.2, 2 and 5 and obtain 3 Family Builds.</td></tr>"; 

$term_content .= "<tr><th valign=\"top\">Gene Family of a Species</th><td>A gene family with at least 1 member gene from the species.</td></tr>";

$term_content .= "<tr><th valign=\"top\">Unique Gene Family of a Species</th><td> A gene family whose member genes are from a species exclusively.</td></tr>";


#################################################
#Define references
$ref_content = "<tr><th valign=\"top\">[1] </th><td>Iseli C. et al (1999), ESTScan: a Program for Detectingm Evaluating and Reconstructing Potential Coding Regions in EST Sequences, American Association of Artificial Intellegence.</td></tr>";

$ref_content .= "<tr><th valign=\"top\">[2] </th><td>Altschul S.F. et al (1997), Gapped BLAST and PSI-BLAST: a New Generation of Protein Database Search Programs.  NUcleic Acids Research 25, 3389-3402.</td></tr>";

$ref_content .= "<tr><th valign=\"top\">[3] </th><td>Enright A.J. et al (2002), An Efficient Algorithm for Large-Scale Detection of Protein Families.  NUcleic Acids Research 30, 1575-1584.</td></tr>";




################################################
#Generate the page
our $page = CXGN::Page->new( "Gene Family Help Page", "Chenwei Lin");
$page->header();
print page_title_html("SGN Gene Family Analysis");


print blue_section_html('Summary','<table width="100%" summary="" cellpadding="3" cellspacing="0" border="0">'.$sum_content.'</table>');
print blue_section_html('Procedure','<table width="100%" summary="" cellpadding="3" cellspacing="0" border="0">'.$process_content.'</table>');
print blue_section_html('Terms','<table width="100%" summary="" cellpadding="3" cellspacing="0" border="0">'.$term_content.'</table>');
print blue_section_html('References','<table width="100%" summary="" cellpadding="3" cellspacing="0" border="0">'.$ref_content.'</table>');


$page->footer();
