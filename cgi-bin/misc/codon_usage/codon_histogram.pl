use strict;
use CXGN::Page;
my $page=CXGN::Page->new('codon_histogram.html','html2pl converter');
$page->header('Codon Usage Histogram');
print<<END_HEREDOC;

<img src="/documents/misc/codon_usage/codon_histogram.png" border="none" usemap=
"#codon_histogram" alt="histogram" /> <map name="codon_histogram"
id="codon_histogram">
<area coords="10,70,442,83" target="_blank" href=
"/documents/misc/codon_usage/codon_usage_data/l_esculentum_codon_usage_table.txt" alt="" />
<area coords="10,60,430,73" target="_blank" href=
"/documents/misc/codon_usage/codon_usage_data/o_sativa_codon_usage_table.txt" alt="" />
<area coords="10,10,478,23" target="_blank" href=
"/documents/misc/codon_usage/codon_usage_data/s_cerevisiae_codon_usage_table.txt" alt="" />
<area coords="10,20,424,33" target="_blank" href=
"/documents/misc/codon_usage/codon_usage_data/h_sapiens_codon_usage_table.txt" alt="" />
<area coords="10,30,430,43" target="_blank" href=
"/documents/misc/codon_usage/codon_usage_data/c_elegans_codon_usage_table.txt" alt="" />
<area coords="10,80,436,93" target="_blank" href=
"/documents/misc/codon_usage/codon_usage_data/s_tuberosum_codon_usage_table.txt" alt="" />
<area coords="10,50,442,63" target="_blank" href=
"/documents/misc/codon_usage/codon_usage_data/a_thaliana_codon_usage_table.txt" alt="" />
<area coords="10,40,442,53" target="_blank" href=
"/documents/misc/codon_usage/codon_usage_data/z_mays_codon_usage_table.txt" alt="" /></map>
END_HEREDOC
$page->footer();