use strict;
use CXGN::Page;
my $page=CXGN::Page->new("chromosome8.html","html2pl converter");
$page->header("Mapping information for chromosome 8");
print<<END_HEREDOC;

  <center>

    <h1>Chromosome
    8</h1><img alt="" src="/documents/maps/lpimp_ibl/IMAGES/lycopimp8.png" usemap=
    "#synteny_map_chr8" /> <map name="synteny_map_chr8" id=
    "synteny_map_chr8">
      <area alt="" coords="370,59,490,70" href=
      "/search/markers/markerinfo.pl?marker_id=139" />
      <area alt="" coords="370,248,458,259" href=
      "/search/markers/markerinfo.pl?marker_id=3142" />
      <area alt="" coords="370,400,483,411" href=
      "/search/markers/markerinfo.pl?marker_id=214" />
      <area alt="" coords="370,506,484,516" href=
      "/search/markers/markerinfo.pl?marker_id=111" />
      <area alt="" coords="370,562,471,573" href=
      "/search/markers/markerinfo.pl?marker_id=69" />
      <area alt="" coords="370,648,491,658" href=
      "/search/markers/markerinfo.pl?marker_id=3189" />
      <area alt="" coords="370,790,472,801" href=
      "/search/markers/markerinfo.pl?marker_id=673" />
      <area alt="" coords="370,876,470,886" href=
      "/search/markers/markerinfo.pl?marker_id=44" />
    </map>
  </center>
END_HEREDOC
$page->footer();