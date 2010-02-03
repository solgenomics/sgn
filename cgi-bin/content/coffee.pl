use strict;
use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/ page_title_html blue_section_html /;

my $page=CXGN::Page->new('SGN coffee data','Lukas');
$page->header('Sol Genomics Network');

print page_title_html("Coffee data on SGN");

print<<END_HEREDOC;

<table summary=""><tr><td valign="middle">
<img src="/documents/img/coffee_small.jpg" alt="" />
    </td><td width="30">&nbsp;</td><td valign="top">
<p>
[Nov 7, 2005]. Cornell University and Nestle SA are releasing 47,000 coffee (<i>Coffea canephora</i> var robusta) EST sequences to the public on the Sol Genomics Network.
</p>
<h4>Abstract</h4>
<p>
An EST database has been generated for coffee based on sequences from approximately 47,000 cDNA clones derived from five different stages/tissues, with a special focus on developing seeds. When computationally assembled, these sequences correspond to 13,175 unigenes, which were analyzed with respect to functional annotation, expression profile and evolution. Compared with Arabidopsis, the coffee unigenes encode a higher proportion of proteins related to protein modification/turnover and metabolism-an observation that may explain the high diversity of metabolites found in coffee and related species. Several gene families were found to be either expanded or unique to coffee when compared with Arabidopsis. A high proportion of these families encode proteins assigned to functions related to disease resistance. Such families may have expanded and evolved rapidly under the intense pathogen pressure experienced by a tropical, perennial species like coffee. Finally, the coffee gene repertoire was compared with that of Arabidopsis and Solanaceous species (e.g. tomato). Unlike Arabidopsis, tomato has a nearly perfect gene-for-gene match with coffee. These results are consistent with the facts that coffee and tomato have a similar genome size, chromosome karyotype (tomato, n=12; coffee n=11) and chromosome architecture. Moreover, both belong to the Asterid I clade of dicot plant families. Thus, the biology of coffee (family Rubiacaeae) and tomato (family Solanaceae) may be united into one common network of shared discoveries, resources and information.
</p>
<p>
The dataset is described in detail in the following publication: </p>
<p class="boxcontent">
Coffee and tomato share common gene repertoires as revealed by deep sequencing of seed and cherry transcripts.
Lin C, Mueller LA, Carthy JM, Crouzillat D, Petiard V, Tanksley SD. 
Theor Appl Genet. 2005 Nov 5;:1-17.
</p>
<p>
    A pdf file of this article is available in <a href="http://www.plos.org/oa/index.html">Open Access format</a>, free of charge to anyone.
</p>


<h4>Data access</h4>

The coffee ESTs, computationally derived unigenes, protein sequences, protein domains and Gene Ontology annotations are immediately downloadable from the SGN <a href="ftp://ftp.sgn.cornell.edu/coffee/">ftp server</a>. The data will be added to the SGN database in the near future.

</td></tr></table>

END_HEREDOC


$page->footer();
