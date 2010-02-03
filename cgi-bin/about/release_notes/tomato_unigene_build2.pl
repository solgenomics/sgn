use strict;

use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/info_section_html info_table_html/;

my $page=CXGN::Page->new('Tomato Unigene Build 2 Notes','Lukas');
$page->header('tomato unigene build release notes','About the tomato unigene build 2');

print<<END_HEREDOC;

<div class="indentedcontent">

May 2008<br /><br />
A new unigene build for tomato has been assembled from the following data:
<ul>
    <li>323,277 ESTs from the tomato species
    <ul>
      <li><i>Solanum lycopersicum</i> with 307,350 sequences</li>
      <li><i>Solanum habrochaites</i> with 8,255 sequences</li>
      <li><i>Solanum pennellii</i> with 7,812 sequences</li>
      <li><i>Solanum pimpinellifolium</i> with 8 sequences</li>
      <li><i>Solanum peruvianum</i> with 42 sequences</li>
      <li><i>Solanum cheesmaniae</i> with 4 sequences</li>
      <li><i>Solanum lycopersicoides</i> with 2 sequences</li>
    </ul>
    </li>

    <li>New EST sequences were obtained from:
      <ul>
        <li>GenBank database (dbEST and mRNA for nucleotide)</li>
      </ul>
    </li>

    <li>The new build contains 42,257 unigenes, of which 24,020 are
    contigs and 18,237 are singletons.</li>

    <li>Analyses performed on the unigenes:
    <ul>
      <li>ESTScan and Longest6frame.pl - to predict peptides (39,967 
      and 43,366 peptides predicted respectively)</li>
      <li>InterproScan on peptides - to predict protein domains and
      associate Gene Ontology codes (6,626 and 1,482 different domains 
      associated to the two different peptide datasets from the two different
      peptide prediction methods)</li>
      <li>BLAST against Genbank NR, Arabidopsis and Swissprot (30,791, 28,656 and 19,886 unigenes have
      any match with these protein datasets respectively)</li>
    </ul>
    </li>
    <li>The range of unigene ids for this build is: SGN-U562593 through SGN-U604849.</li>
    </ul>

Different ways to access to new tomato species unigene build in SGN:
<ul>
<li>Sequence homology search using <a href="http://sgn.cornell.edu/tools/blast/">SGN Blast</a>.</li>
<li>Bulk download for a unigene accession (or list of accessions) 
using SGN <a href="http://sgn.cornell.edu/bulk/input.pl?mode=unigene">Bulk download tool</a>.</li>
<li>Complete download of all the unigene sequences and annotations from 
the <a href="ftp://ftp.sgn.cornell.edu/unigene_builds">SGN ftp site</a>.</li> 

</div>

END_HEREDOC

$page->footer();
