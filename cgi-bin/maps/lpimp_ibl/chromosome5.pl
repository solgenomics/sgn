use strict;
use CXGN::Page;
my $page=CXGN::Page->new("chromosome5.html","html2pl converter");
$page->header("Mapping information for chromosome 5");
print<<END_HEREDOC;

  <center>

    <h1>Chromosome 5</h1>
<img alt="" src="/documents/maps/lpimp_ibl/IMAGES/lycopimp5.png" usemap="#synteny_map_chr5" /> 
<map name="synteny_map_chr5" id="synteny_map_chr5">
      <area alt="" coords="370,71,482,81" href=
      "/search/markers/markerinfo.pl?marker_id=384" />
      <area alt="" coords="370,183,487,194" href=
      "/search/markers/markerinfo.pl?marker_id=102" />
      <area alt="" coords="370,259,469,270" href=
      "/search/markers/markerinfo.pl?marker_id=188" />
      <area alt="" coords="370,422,473,432" href=
      "/search/markers/markerinfo.pl?marker_id=159" />
      <area alt="" coords="370,517,458,527" href=
      "/search/markers/markerinfo.pl?marker_id=158" />
      <area alt="" coords="370,849,491,859" href=
      "/search/markers/markerinfo.pl?marker_id=3084" />
      <area alt="" coords="370,877,484,888" href=
      "/search/markers/markerinfo.pl?marker_id=127" />
      <area alt="" coords="370,962,489,973" href=
      "/search/markers/markerinfo.pl?marker_id=173" />
      <area alt="" coords="370,1086,490,1097" href=
      "/search/markers/markerinfo.pl?marker_id=176" />
      </map>
  </center>
END_HEREDOC
$page->footer();