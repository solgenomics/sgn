use strict;
use warnings;
use CXGN::Page;

my $page=CXGN::Page->new('Secretom','john');
$page->header('Secretom');
print<<END_HTML;
<div style="width:100%; color:#303030; font-size: 1.1em; text-align:left;">

<center>
<img style="margin-bottom:10px" src="/documents/img/secretom/secretom_logo_smaller.jpg" alt="secretom logo" />
</center>

<span style="white-space:nowrap; display:block; padding:3px; background-color: #fff; text-align:center; color: #444; font-size:1.3em">
</span>
<br />
<p>The plant apoplast, comprising the cell wall, or extracellular matrix, middle lamella and intercellular spaces, represents a distinct metabolically active compartment, with dynamic and complex properties and a high degree of spatial and temporal heterogeneity. The cell wall/apoplast plays a fundamental role in many aspects of plant biology and research across the spectrum of plant science is resulting in an ever-growing list of developmental processes and environmental responses that are directly or indirectly influenced by wall-localized molecular interactions and signaling pathway. It is therefore not surprising that a substantial portion of the plant proteome resides in the cell wall/apoplast. However, while major initiatives are now underway to map the proteomes of most plant organelles, the proteome of the plant cell wall/apoplast is far less well characterized than those of other subcellular compartments.</p>
<br />
<center>
<img src="/documents/img/secretom/proteome.png" />
</center>
</div>

END_HTML

$page->footer();
