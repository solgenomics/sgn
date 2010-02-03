use strict;
use CXGN::Page;
my $page=CXGN::Page->new("chromosome10.html","html2pl converter");
$page->header("Mapping information for chromosome 10");
print<<END_HEREDOC;

  <center>

    <h1>Chromosome 10</h1>
<img alt="" src="/documents/maps/lpimp_ibl/IMAGES/lycopimp10.png" usemap="#synteny_map_chr10" /> 
<map name="synteny_map_chr10" id="synteny_map_chr10">

      <area alt="" coords="370,69,473,79" href=
      "/search/markers/markerinfo.pl?marker_id=152" />
      <area alt="" coords="370,305,472,316" href=
      "/search/markers/markerinfo.pl?marker_id=186" />
      <area alt="" coords="370,572,470,582" href=
      "/search/markers/markerinfo.pl?marker_id=142" />
      <area alt="" coords="370,667,485,677" href=
      "/search/markers/markerinfo.pl?marker_id=473" />
      <area alt="" coords="370,743,459,753" href=
      "/search/markers/markerinfo.pl?marker_id=3181" />
      <area alt="" coords="370,914,479,924" href=
      "/search/markers/markerinfo.pl?marker_id=72" />
      <area alt="" coords="370,970,469,981" href=
      "/search/markers/markerinfo.pl?marker_id=22" />
      <area alt="" coords="370,1047,473,1057" href=
      "/search/markers/markerinfo.pl?marker_id=88" />
    </map>
  </center>
END_HEREDOC
$page->footer();