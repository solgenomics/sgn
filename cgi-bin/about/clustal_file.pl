use strict;
use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/  page_title_html
                                       blue_section_html  /;

my ($intro_content, $example_content, $ref_content);

##########################################
#Define the introdution
$intro_content = "<tr><td><p>Clustal alignment file is the result file from a alignment program, such as clustalw[1] and t_coffee[2].</p></td></tr>";

#########################################
#Define the exaple
$example_content = "<tr><td colspan=\"2\">CLUSTAL W (1.81) multiple sequence alignment<br /><br /></td></tr>";
$example_content .= "<tr><td><tt>seq_1<br />seq_2<br /><br /></tt></td><td><tt>ATAGATCTTAAATTTTATTATTTTTCTTGAGTTCATCATCAACAAAACAACCCAATACAA<br />ATAGATCTTA--TTTTATTATTTTTCTTGAGTTCATCATCAACAAAACAACCCAATACAA<br /><br /></tt></td></tr>";
$example_content .= "<tr><td><tt>seq_1<br />seq_2<br /><br /></tt></td><td><tt>TATATCACAGAGAAACAAATACAAAGGAAAAGAATAGAAATGGCTAAAACTATCATGGTT<br />TATATCACAGAGAAACAAATACAAAGGAAAAGAATAGAAATGGCTAAAACTATCATGGTT<br /><br /></tt></td></tr>";
$example_content .= "<tr><td><tt>seq_1<br />seq_2<br /><br /></tt></td><td><tt>AATTTAACAGGGAAAGATGGGAAGGTTGAGTACCAATGCAAGACATCTGAGGTTGTCGTT<br />AATTTAACAGGGAAAGATGGGAAGGTTGAGTACCAATGCAAGACATCTA----TGGCGAC<br /><br /></tt></td></tr>";
$example_content .= "<tr><td><tt>seq_1<br />seq_2</tt></td><td><tt>GCAAACATGAAAGAACACATTGAGACAGATGAATGTGTCGATGCTTGTGGCGTTGACAGA<br />TTGAGCATGAAAGAACACATTGAGACAGATGAATGTGTCGATGCTTGTGGCGTTGACAGA<br /><br /></tt></td></tr>";
$example_content .= "<tr><td><tt>seq_1<br />seq_2</tt></td><td><tt>TCCCCTGTTTCTTTCTAATTTATTCCCTA<br />TCCCCTGTTTCTTTCTAATTTATTCCCTA<br /><br /></tt></td></tr>";

#################################################
#Define references
$ref_content = "<tr><th valign='top'>[1] </th><td><a href=\"http://www.ebi.ac.uk/clustalw\">www.ebi.ac.uk/clustalw</a></td></tr>";

$ref_content .= "<tr><th valign='top'>[2] </th><td><a href=\"http://www.igs.cnrs-mrs.fr/Tcoffee/tcoffee_cgi/index.cgi\">www.igs.cnrs-mrs.fr/Tcoffee/tcoffee_cgi/index.cgi</a></td></tr>";


################################################
#Generate the page
our $page = CXGN::Page->new( "Clustal Alignment File", "Chenwei Lin");
$page->header();
print page_title_html("Clustal Alignment File");


print blue_section_html('Introduction','<table width="100%" summary="" cellpadding="3" cellspacing="0" border="0">'.$intro_content.'</table>');
print blue_section_html('Example','<table width="100%" summary="" cellpadding="3" cellspacing="0" border="0">'.$example_content.'</table>');
print blue_section_html('References','<table width="100%" summary="" cellpadding="3" cellspacing="0" border="0">'.$ref_content.'</table>');

$page->footer();
