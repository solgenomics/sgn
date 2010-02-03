use strict;
use CXGN::Page;
my $page=CXGN::Page->new("chromosome7.html","html2pl converter");
$page->header("Mapping information for chromosome 7");
print<<END_HEREDOC;

  <center>

    <h1>Chromosome 7</h1>

    <img alt="" src="/documents/maps/lpimp_ibl/IMAGES/lycopimp7.png" usemap="#synteny_map_chr7" /> 
    <map name="synteny_map_chr7" id="synteny_map_chr7">
      <area alt="" coords="370,72,472,83" href=
      "/search/markers/markerinfo.pl?marker_id=99" />
      <area alt="" coords="370,518,461,529" href=
      "/search/markers/markerinfo.pl?marker_id=59" />
      <area alt="" coords="370,537,484,548" href=
      "/search/markers/markerinfo.pl?marker_id=101" />
      <area alt="" coords="370,594,480,605" href=
      "/search/markers/markerinfo.pl?marker_id=3126" />
      <area alt="" coords="370,689,489,700" href=
      "/search/markers/markerinfo.pl?marker_id=138" />
      <area alt="" coords="370,718,469,728" href=
      "/search/markers/markerinfo.pl?marker_id=172" />
      <area alt="" coords="370,880,471,890" href=
      "/search/markers/markerinfo.pl?marker_id=203" />
      <area alt="" coords="370,1051,470,1061" href=
      "/search/markers/markerinfo.pl?marker_id=175" />
      <area alt="" coords="370,1135,482,1146" href=
      "/search/markers/markerinfo.pl?marker_id=224" />
      </map>
  </center>
END_HEREDOC
$page->footer();