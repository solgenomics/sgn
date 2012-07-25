
use strict;
use CXGN::Page;
use CXGN::Page::FormattingHelpers qw / blue_section_html page_title_html /;

my $page=CXGN::Page->new("SGN SolCyc","Lukas");

$page->header();
	  
print page_title_html("<a href=\"http://solcyc.solgenomics.net/\">SolCyc</a> Biochemical Pathways");

print qq {

<img src="/documents/img/ptools.png" border="0" alt="" />
<div class="boxbgcolor1">
<p>
SolCyc is a collection of Pathway Genome Databases (PGDBs) for Solanaceae species generated using <a href="http://bioinformatics.ai.sri.com/ptools/">Pathway Tools</a> software from <a href="http://www.sri.com">SRI International</a>, the same software that is used in <a href="http://www.arabidopsis.org/tools/aracyc/">AraCyc</a> for <i>Arabidopsis thaliana</i> and <a href="http://www.ecocyc.org">EcoCyc</a> for <i>E. coli</i>. 
</p>
<p>
Currently, databases for tomato, potato, and pepper are available, generated from the annotated SGN unigene sequences. The initial automatic builds have received little or no human curation. The eggplant database is not longer supported or available.
</p>

<ul>
<li>LycoCyc (tomato): <a href="http://solcyc.solgenomics.net/LYCO/server.html">Query page</a> | <a href="http://solcyc.solgenomics.net/LYCO/NEW-IMAGE?type=OVERVIEW&amp;force=t">Pathway overview diagram</a></li>
<li>PotatoCyc (potato): <a href="http://solcyc.solgenomics.net/POTATO/server.html">Query page</a> | <a href="http://solcyc.solgenomics.net/POTATO/NEW-IMAGE?type=OVERVIEW&amp;force=t">Pathway overview diagram</a> </li>
<li>CapCyc (pepper): <a href="http://solcyc.solgenomics.net/CAP/server.html">Query page</a> | <a href="http://solcyc.solgenomics.net/CAP/NEW-IMAGE?type=OVERVIEW&amp;force=t">Pathway overview diagram</a></li>
<li>CoffeaCyc (coffee): <a href="http://solcyc.solgenomics.net/COFFEA/server.html?">Query page</a> | <a href="http://solcyc.solgenomics.net/COFFEA/NEW-IMAGE?type=OVERVIEW&amp;force=t">Pathway overview diagram</a></li>
<li>PetuniaCyc (petunia): <a href="http://solcyc.solgenomics.net/PET/server.html?">Query page</a> | <a href="http://solcyc.solgenomics.net/PET/NEW-IMAGE?type=OVERVIEW&amp;force=t">Pathway overview diagram</a></li>
<li>NicotianaCyc (tobacco): <a href="http://solcyc.solgenomics.net/TOBACCO/server.html?">Query page</a> | <a href="http://solcyc.solgenomics.net/TOBACCO/NEW-IMAGE?type=OVERVIEW&amp;force=t">Pathway overview diagram</a></li>
</ul>

<p>
More databases will be generated in the future, and the annotation will be improved by adding more Solanaceae specific pathways.
</p>
<p>
Note the availability of the <a href="http://solcyc.solgenomics.net/expression.html">Omics viewer</a>, which allows microarray, gene chip, proteomics, and metabolomic information to be overlaid over the pathway overview diagrams.
</p>
</div>

<p>
<img src="/documents/img/ptools.png" border="0" alt="" />
</p>

<b>Programmatic interfaces for Pathway Tools</b>:<br />
We currently maintain a Perl interface and a Java interface for Pathway Tools:
<a href="ftp://ftp.solgenomics.net/programs/javacyc/javacyc.tar.gz">JavaCyc</a> and <a href="ftp://ftp.solgenomics.net/programs/perlcyc/perlcyc.tar.gz">PerlCyc</a>. More information is available on the <a href="/downloads/">software downloads</a> page.

};

$page->footer();
