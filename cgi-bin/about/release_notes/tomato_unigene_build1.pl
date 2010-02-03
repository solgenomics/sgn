use strict;

use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/info_section_html info_table_html/;

my $page=CXGN::Page->new('Tomato Unigene Build 1 Notes','Lukas');
$page->header('tomato unigene build release notes','About the tomato unigene build 1');

print<<END_HEREDOC;

<div class="indentedcontent">

September 2006<br /><br />
A new unigene build for tomato has been assembled from the following data:
<ul>
    <li>235836 ESTs from the tomato species
    <ul>
      <li><i>Solanum lycopersicum</i></li>
      <li><i>Solanum habrochaites</i></li>
      <li><i>Solanum pennellii</i></li>
      <li><i>Microtom.</i></li>
    </ul>
    We also included 3336 mRNA sequences from Genbank for the
    following tomato species:
    <ul>
      <li><i>Solanum lycopersicum</i></li>
      <li><i>Solanum habrochaites</i></li>
      <li><i>Solanum pennellii</i></li>
      <li><i>Solanum pimpinellifolium</i></li>
      <li><i>Solanum peruvianum</i></li>
      <li><i>Solanum cheesmaniae</i></li>
      <li><i>Solanum habrochaites</i></li>
      <li><i>Solanum lycopersicoides</i></li>
    </ul>
    </li>

    <li>New EST sequences were obtained from
      <ul>
        <li>Prof Shibata, Kazusa Institute.</li>
        <li>Dr. Eyal Fridman, University of Michigan</li>
      </ul>
    </li>

    <li>The new build contains 34829 unigenes, of which 21153 are
    contigs and 13676 are singletons.</li>

    <li>Analyses performed on the unigenes:
    <ul>
      <li>ESTScan - to predict peptides</li>
      <li>InterproScan on peptides - to predict protein domains and
      associate Gene Ontology codes</li>
      <li>BLAST against Arabidopsis and Genbank NR</li>
    </ul>
    </li>
    <li>The range of unigene ids for this build is: 312296 through 347124.</li>
    </ul>
SGN Links:
<ul>
<li><a href="http://sgn-devel.sgn.cornell.edu/search/direct_search.pl?search=unigene">SGN Unigene Search</a></li>
<li><a href="ftp://ftp.sgn.cornell.edu/unigene_builds">SGN FTP server</a></li>
</ul>

External Links:
<ul>
<li><a href="http://www.kazusa.or.jp/jsol/microtom/index.html" class="external">Micro-Tom Database Kazusa, Japan</a></li>
</ul>
</div>

END_HEREDOC

$page->footer();
