use strict;
use CXGN::Page;
my $page=CXGN::Page->new("chromosome2.html","html2pl converter");
$page->header("Mapping information for chromosome 2");
print<<END_HEREDOC;

  <center>

    <h1>Chromosome
    2</h1><img alt="" src="/documents/maps/lpimp_ibl/IMAGES/lycopimp2.png" usemap=
    "#synteny_map_chr2" /> <map name="synteny_map_chr2" id=
    "synteny_map_chr2">
      <area alt="" coords="370,66,469,76" href=
      "/search/markers/markerinfo.pl?marker_id=144" />
      <area alt="" coords="370,197,471,208" href=
      "/search/markers/markerinfo.pl?marker_id=110" />
      <area alt="" coords="370,254,472,265" href=
      "/search/markers/markerinfo.pl?marker_id=603" />
      <area alt="" coords="370,311,490,322" href=
      "/search/markers/markerinfo.pl?marker_id=120" />
      <area alt="" coords="370,511,472,522" href=
      "/search/markers/markerinfo.pl?marker_id=145" />
      <area alt="" coords="370,578,484,588" href=
      "/search/markers/markerinfo.pl?marker_id=28" />
      <area alt="" coords="370,720,469,731" href=
      "/search/markers/markerinfo.pl?marker_id=3183" />
      <area alt="" coords="370,796,471,807" href=
      "/search/markers/markerinfo.pl?marker_id=190" />
      <area alt="" coords="370,853,470,864" href=
      "/search/markers/markerinfo.pl?marker_id=219" />
      <area alt="" coords="370,948,467,959" href=
      "/search/markers/markerinfo.pl?marker_id=97" />
      <area alt="" coords="370,995,490,1006" href=
      "/search/markers/markerinfo.pl?marker_id=100" />
      </map>
  </center>
END_HEREDOC
$page->footer();