use strict;
use CXGN::Page;
my $page=CXGN::Page->new('mutants_main.html','html2pl converter');
$page->header('Mutants');
print<<END_HEREDOC;


<table summary="" width="720" cellpadding="0" cellspacing="0"
border="0">
<tr>
<td>
<ul>
<li><a href="http://zamir.sgn.cornell.edu/mutants/">Genes that make
Tomatoes</a>
<blockquote>"The Genes That Make Tomatoes." This database is hosted
by SGN in collaboration with the Zamir Lab at the Hebrew University
of Jerusalem. All data was collected from a mutagenesis project, in
which over 150,000 m2 plants were screened iin the field for mutant
phenotypes at defined developmental stages (summer 2001, 2002 and
2003). In the web site there is a description of the project and
the mutant population as well as a new search engine. The
collection of 3500 monogenic mutants is amenable for searching
according to a detailed phenotypic catalog and combinations of
traits.</blockquote>
</li>
<li><a href="http://zamir.sgn.cornell.edu/Qtl/Html/home.htm">Real
Time QTL</a>
<blockquote>The objective of Real Time QTL (RTQ) is to present
<em>in silico</em> the range of statistical outputs that describe
the components of genetic variastion using tomato as a model
organism.</blockquote>
</li>
<li><a href="http://tgrc.ucdavis.edu/">TGRC</a> [external link]
<blockquote>The C.M. Rick Tomato Genetics Resource Center (TGRC) is
a genebank of wild relatives, monogenic mutants and miscellaneous
genetic stocks of tomato. The Center is named for Dr. Charles M.
Rick, Prof. Emer. who established much of the collection through
his research and plant collecting activities. Located in the Dept.
of Vegetable Crops, University of California at Davis, the TGRC is
also integrated with the National Plant Germplasm System (NPGS).
The TGRC facilitates research on tomato by providing seed samples
of its accessions to interested scientists worldwide.</blockquote>
</li>
</ul>
</td>
</tr>
</table>
 
END_HEREDOC
$page->footer();
