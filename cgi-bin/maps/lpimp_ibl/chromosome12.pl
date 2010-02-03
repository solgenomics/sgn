use strict;
use CXGN::Page;
my $page=CXGN::Page->new("chromosome12.html","html2pl converter");
$page->header("Mapping information for chromosome 12");
print<<END_HEREDOC;

  <center>

    <h1>Chromosome
    12</h1><img alt="" src="/documents/maps/lpimp_ibl/IMAGES/lycopimp12.png" usemap=
    "#synteny_map_chr12" /> <map name="synteny_map_chr12" id=
    "synteny_map_chr12">
      <area alt="" coords="370,70,468,80" href=
      "/search/markers/markerinfo.pl?marker_id=166" />
      <area alt="" coords="370,126,473,136" href=
      "/search/markers/markerinfo.pl?marker_id=94" />
      <area alt="" coords="370,326,483,336" href=
      "/search/markers/markerinfo.pl?marker_id=2978" />
      <area alt="" coords="370,497,460,507" href=
      "/search/markers/markerinfo.pl?marker_id=558" />
      <area alt="" coords="370,562,481,573" href=
      "/search/markers/markerinfo.pl?marker_id=218" />
      <area alt="" coords="370,611,468,621" href=
      "/search/markers/markerinfo.pl?marker_id=182" />
      <area alt="" coords="370,942,486,953" href=
      "/search/markers/markerinfo.pl?marker_id=657" />
      <area alt="" coords="370,1066,472,1077" href=
      "/search/markers/markerinfo.pl?marker_id=2991" />
      </map>
  </center>
END_HEREDOC
$page->footer();