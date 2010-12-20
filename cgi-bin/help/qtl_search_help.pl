
#################
# a quick guide on how to search and browse for qtls.
# Isaak Y Tecle iyt2@cornell.edu

###############



use strict;
use CXGN::Page;
my $page=CXGN::Page->new('');
$page->header('SGN: QTL/Trait search help');
my $email = 'sgn-feedback@solgenomics.net';
print <<EOHTML;

<p>
The <a href="/search/direct_search.pl?search=qtl">QTL/Trait search</a> returns phenotypic traits that may have qtl data. QTL analysis is performed on the fly.
</p>


<h4>1. Search the database using a trait name. For example, 'fruit shape'.</h4>

<img src="/documents/help/screenshots/qtl_cvterm_searchform.png" alt="screenshot of qtl/trait search form" style="margin: auto; border: 1px solid black;" />

<h4>2. Follow the link for the trait of interest.</h4>

<p>
<img src="/documents/help/screenshots/qtl_cvterm_results.png" alt="screenshot of qtl/trait search results" style="margin: auto; border: 1px solid black;" />
</p>

<h4>3. After selecting the trait of interest, for example the trait 'fruit shape circular', you will be taken to the trait (cvterm) page, scroll down to the 'Phenotype data/QTL' subsection. Select the population of interest for which the trait was evaluated. For example, the population 'Howard German x LA1589'. </h4>
<p>
<img src="/documents/help/screenshots/qtl_cvterm_poplist.png" alt="screenshot of qtl/trait population list" style="margin: auto; border: 1px solid black;" />
</p>


<h4>4. Visually determine which linkage group contains a QTL, see the LOD threshold in the legend. For example, chromosome 7 has a QTL. Click the linkage group of interest and on the new window, follow the link "Go to the QTL page...".  </h4>
<p>

<img src="/documents/help/screenshots/qtl_genome.png" alt="screenshot of qtl plots" style="margin: auto; border: 1px solid black;" />
</p>

<h4>6. Clicking the "Go to the QTL page" generates the QTL detail page where among others the QTL confidence interval, links to the genome positions of the markers, marker detail pages, and SGN's Comparative Map Viewer are displayed.</h4>

<p>

<img src="/documents/help/screenshots/qtl_detail2.png" alt="screenshot of qtl detail page" style="margin: auto; border: 1px solid black;" />
</p>

<h4>7. The QTL detail page (shown above) presents cross-references from the QTL to other relevant genetic and genomic data and bioinformatic tools. Forexample, to view the genetic location of the QTL of a trait of interest and compare it to other genetic maps using the Comparative Map Viewer, click the linkage group link under the 'QTL markers' genetic positions and Comparative Map Viewer' subection.</h4>

<p> QTL genetic location:<br/>
<img src="/documents/help/screenshots/qtl_cvterm_qtl_chrloc.png" alt="screenshot of qtl plots" style="margin: auto; border: 1px solid black;" />
</p>
<p>
<b>To learn on how to perform comparative analysis with genetic maps and physical maps of the same or different Solanaceae species, please read this <a href="../help/cview.pl">help document.</a></b>  
</p>

<p><b>If you have questions, please contact us at: <a href="mailto:$email">$email</a></b></p>

EOHTML


$page->footer();
