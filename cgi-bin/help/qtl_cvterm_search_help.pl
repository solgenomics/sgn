
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
The <a href="/search/direct_search.pl?search=cvterm_name">QTL/Trait search</a> returns phenotypic traits that may have qtl data. QTL analysis is performed on the fly.
</p>


<h4>1. Search the database using a trait name. For example, 'fruit shape'.</h4>

<img src="/documents/help/screenshots/qtl_cvterm_searchform.png" alt="screenshot of qtl/trait search form" style="margin: auto; border: 1px solid black;" />

<h4>2. Follow the link for the trait of interest.</h4>

<p>
<img src="/documents/help/screenshots/qtl_cvterm_results.png" alt="screenshot of qtl/trait search results" style="margin: auto; border: 1px solid black;" />
</p>

<h4>3. On the trait (cvterm) page, scroll down to the 'Phenotype data/QTL' subsection. Select the population of interest for which the trait was evaluated. For example, population 'Howard German x LA1589'. </h4>
<p>
<img src="/documents/help/screenshots/qtl_cvterm_poplist.png" alt="screenshot of qtl/trait population list" style="margin: auto; border: 1px solid black;" />
</p>


<h4>4. Click the qtl plot of interest and on the new window, follow the link "view and compare...". For example, the qtl on chromosome 7. </h4>
<p>

<img src="/documents/help/screenshots/qtl_cvterm_qtl_graphs.png" alt="screenshot of qtl plots" style="margin: auto; border: 1px solid black;" />
</p>

<h4>6.Clicking the "Go to the QTL page" generates the QTL detail page where among others the QTL confidence interval, links to the genome positions of the markers, marker detail pages, and comparative map viewer are displayed.</h4>

<p>Example of data cross-referenced from the QTL detail page is:
<img src="/documents/help/screenshots/qtl_cvterm_qtl_chrloc.png" alt="screenshot of qtl plots" style="margin: auto; border: 1px solid black;" />
</p>
<p>
<b>Further comparative analysis with genetic maps and physical maps of the same or different solanaceae species can be done using the Comparative mapviewer. Please read this <a href="../help/cview.pl">help document</a> on how to use the Comparative mapviewer.</b>  
</p>

<p><b>If you have questions, please contact us at: <a href="mailto:$email">$email</a></b></p>

EOHTML


$page->footer();
