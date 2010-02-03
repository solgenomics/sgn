use strict;
use CXGN::Page;
my $page=CXGN::Page->new('codon_usage.html','html2pl converter');
$page->header('Comparative Codon Usage Analysis');
print<<END_HEREDOC;

<center>

<table summary="" width="720" cellpadding="0" cellspacing="0"
border="0">
<tr>
<td>
<h3>Codon usage for tomato (<em>L. esculentum</em>) and potato (<em>S.
tuberosum</em>) genes and comparison with codon usage in other
organisms.</h3>
An analysis of codon usage in <em>L. esculentum</em> and <em>S.
tuberosum</em> was performed based on a dataset of 150000 tomato EST
sequences and 40000 potato EST sequences. The following methodology
was used:
<p>For tomato:</p>
<ol>
<li>1500000 EST sequences were assembled into a unigene set,
resulting in 27000 unigenes.</li>
<li>Each unigene was translated in 6 frames, and the sequence was
selected if it had one frame containing no stop codons.</li>
<li>The resulting set of 5575 sequences was trimmed up to the first
"ATG" codon.</li>
<li>A codon usage table based on these sequences was
generated.</li>
</ol>
For potato:
<ol>
<li>400000 EST sequences were assembled into a unigene set,
resulting in 8000 unigenes.</li>
<li>Each unigene was translated in 6 frames, and the sequence was
selected if it had one frame containing no stop codons.</li>
<li>The resulting set of 2874 sequences was trimmed up to the first
"ATG" codon.</li>
<li>A codon usage table based on these sequences was
generated.</li>
</ol>
<p>The second step for each organism was done in order to identify
a subset of sequences with an obvious correct frame, and the third
step was used to eliminate the possibility of using 5' UTR while
building the codon usage tables.</p>
<p>The codon usage patterns in tomato and potato were compared with
each other, as well as <em>A. thaliana</em>, <em>Z. mays</em>, <em>O.
sativa</em>, <em>S. cerevisiae</em>, <em>C. elegans</em> and <em>H.
sapiens</em>. The published codon usage tables for these organisms
were retrieved from the <a href=
"http://www.kazusa.or.jp/codon/">Codon Usage Database</a>.</p>
<p>The link below will display a histogram of the frequency of each
codon in the organisms mentioned above, grouped by the aminoacid
for which they code. Clicking on the name of an organism in the
histogram legend will display the codon usage table for that
organism.</p>
<p><a href="codon_histogram.pl">Histogram comparison of codon
usage among organisms</a></p>
<p>You can also display idividual codon usage tables using the
links below:</p>
<ul>
<li><a href="/documents/misc/codon_usage/codon_usage_data/l_esculentum_codon_usage_table.txt"
target="_blank"><em>L. esculentum</em></a></li>
<li><a href="/documents/misc/codon_usage/codon_usage_data/s_tuberosum_codon_usage_table.txt"
target="_blank"><em>S. tuberosum</em></a></li>
<li><a href="/documents/misc/codon_usage/codon_usage_data/a_thaliana_codon_usage_table.txt"
target="_blank"><em>A. thaliana</em></a></li>
<li><a href="/documents/misc/codon_usage/codon_usage_data/o_sativa_codon_usage_table.txt"
target="_blank"><em>O. sativa</em></a></li>
<li><a href="/documents/misc/codon_usage/codon_usage_data/z_mays_codon_usage_table.txt" target=
"_blank"><em>Z. mays</em></a></li>
<li><a href="/documents/misc/codon_usage/codon_usage_data/s_cerevisiae_codon_usage_table.txt"
target="_blank"><em>S. cerevisiae</em></a></li>
<li><a href="/documents/misc/codon_usage/codon_usage_data/c_elegans_codon_usage_table.txt"
target="_blank"><em>C. elegans</em></a></li>
<li><a href="/documents/misc/codon_usage/codon_usage_data/h_sapiens_codon_usage_table.txt"
target="_blank"><em>H. sapiens</em></a></li>
</ul>
If you have any questions regarding this data, please send email to
<a href=
"mailto:sgn-feedback\@cornell.edu">sgn-feedback\@cornell.edu</a>.</td>
</tr>
</table>

</center>
END_HEREDOC
$page->footer();