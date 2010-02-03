use strict;
use CXGN::Page;
my $page=CXGN::Page->new('bac_annotation.html','html2pl converter');
$page->header('Sol Genomics Network - BAC Sequence Annotations');
print<<END_HEREDOC;

<center>

<table summary="" width="720" cellpadding="0" cellspacing="0"
border="0">
<tr>
<td>
<h2>Annotation of 6 tomato BAC sequences.</h2>
<br />
<p>The information on this web-page accompanies the paper:
Deductions about the number, organization and evolution of genes in
the tomato genome based on analysis of a large EST collection and
selective genomic sequencing (Plant Cell issue [forthcoming]).
Linked below are files that represent the data analysis and
annotation results of the six BACs mentioned in this paper. The
Artmenis files summarize the annotation of the BACs and are
viewable with the DNA sequence viewer <a href=
"http://www.sanger.ac.uk/Software/Artemis/">Artemis</a> [1]
available from the <a href="http://www.sanger.ac.uk/">Sanger
center</a>. <a href=
"http://www.sanger.ac.uk/Software/Artemis/v4/">[Download]</a> These
files may also be viewed as plain text. The BLAST files are BLAST
outputs of sequence similarity analyses against various databases
available at <a href="/">SGN</a>. [2]</p>
<br />
<br />
Artmenis Data<br />
<pre>
         <a href="/static_content/supplement/plantcell-14-1441/artmenis/gi_9858768.txt">gi_9858768</a>
         <a href="/static_content/supplement/plantcell-14-1441/artmenis/gi_15987769.txt">gi_15987769</a>
         <a href="/static_content/supplement/plantcell-14-1441/artmenis/gi_15987770.txt">gi_15987770</a>
         <a href="/static_content/supplement/plantcell-14-1441/artmenis/gi_15987771.txt">gi_15987771</a>
         <a href="/static_content/supplement/plantcell-14-1441/artmenis/gi_15987772.txt">gi_15987772</a>
         <a href="/static_content/supplement/plantcell-14-1441/artmenis/gi_15987773.txt">gi_15987773</a>
         <a href="/static_content/supplement/plantcell-14-1441/artmenis/gi_15987774.txt">gi_15987774</a>
</pre>
<p>BLASTX against GenPept<br /></p>
<pre>
         <a href="/static_content/supplement/plantcell-14-1441/GenPept/gi_9858768.txt">gi_9858768</a>
         <a href="/static_content/supplement/plantcell-14-1441/GenPept/gi_15987769.txt">gi_15987769</a>
         <a href=
"/static_content/supplement/plantcell-14-1441/GenPept/gi_15987770&amp;1.txt">gi_15987770 and gi_15987771</a>
         <a href="/static_content/supplement/plantcell-14-1441/GenPept/gi_15987772.txt">gi_15987772</a>
         <a href="/static_content/supplement/plantcell-14-1441/GenPept/gi_15987773.txt">gi_15987773</a>
         <a href="/static_content/supplement/plantcell-14-1441/GenPept/gi_15987774.txt">gi_15987774</a>
</pre>
<p>BLASTN against Lycopersicon Esculentum Contigs (Unigene Build
2)<br /></p>
<pre>
         <a href="/static_content/supplement/plantcell-14-1441/le_con_2/gi_9858768.txt">gi_9858768</a>
         <a href="/static_content/supplement/plantcell-14-1441/le_con_2/gi_15987769.txt">gi_15987769</a>
         <a href=
"/static_content/supplement/plantcell-14-1441/le_con_2/gi_15987770&amp;1.txt">gi_15987770 and gi_15987771</a>
         <a href="/static_content/supplement/plantcell-14-1441/le_con_2/gi_15987772.txt">gi_15987772</a>
         <a href="/static_content/supplement/plantcell-14-1441/le_con_2/gi_15987774.txt">gi_15987774</a>
</pre>
<p>TBLASTX against Arabidopsis Tiling Path (SGN)<br /></p>
<pre>
         <a href="/static_content/supplement/plantcell-14-1441/atpath/gi_9858768.txt">gi_9858768</a>
         <a href="/static_content/supplement/plantcell-14-1441/atpath/gi_15987769.txt">gi_15987769</a>
         <a href=
"/static_content/supplement/plantcell-14-1441/atpath/gi_15987770&amp;1.txt">gi_15987770 and gi_15987771</a>
         <a href="/static_content/supplement/plantcell-14-1441/atpath/gi_15987772.txt">gi_15987772</a>
         <a href="/static_content/supplement/plantcell-14-1441/atpath/gi_15987773.txt">gi_15987773</a>
         <a href="/static_content/supplement/plantcell-14-1441/atpath/gi_15987774.txt">gi_15987774</a>
</pre>
<p>BLASTN against SGN EST database<br /></p>
<pre>
         <a href="/static_content/supplement/plantcell-14-1441/sgn_estdb/gi_9858768.txt">gi_9858768</a>
         <a href="/static_content/supplement/plantcell-14-1441/sgn_estdb/gi_15987769.txt">gi_15987769</a>
         <a href=
"/static_content/supplement/plantcell-14-1441/sgn_estdb/gi_15987770&amp;1.txt">gi_15987770 and gi_15987771</a>
         <a href="/static_content/supplement/plantcell-14-1441/sgn_estdb/gi_15987772.txt">gi_15987772</a>
         <a href="/static_content/supplement/plantcell-14-1441/sgn_estdb/gi_15987773.txt">gi_15987773</a>
         <a href="/static_content/supplement/plantcell-14-1441/sgn_estdb/gi_15987774.txt">gi_15987774</a>
</pre>
<br />
<p>[1] K. Rutherford, J. Parkhill, J. Crook, T. Horsnell, P. Rice,
M-A. Rajandream and B. Barrell (2000) Artemis: sequence
visualization and annotation (Bioinformatics 16 (10) 944-945.
<a href=
"http://bioinformatics.oxfordjournals.org/cgi/content/abstract/16/10/944">
Abstract</a>)<br /></p>
<p>[2] Currently available SGN BLAST databases may have been
changed or updated since this work was published.</p>
</td>
</tr>
</table>

</center>
END_HEREDOC
$page->footer();
