use strict;
use CXGN::Page;
my $page=CXGN::Page->new("chromosome6.html","html2pl converter");
$page->header("Mapping information for chromosome 6");
print<<END_HEREDOC;

  <center>

    <h1>Chromosome 6</h1>
<img alt="" src="/documents/maps/lpimp_ibl/IMAGES/lycopimp6.png" usemap="#synteny_map_chr6" /> 
<map name="synteny_map_chr6" id="synteny_map_chr6">
      <area alt="" coords="370,62,492,72" href=
      "/search/markers/markerinfo.pl?marker_id=516" />
      <area alt="" coords="370,165,484,176" href=
      "/search/markers/markerinfo.pl?marker_id=106" />
      <area alt="" coords="370,289,473,299" href=
      "/search/markers/markerinfo.pl?marker_id=509" />
      <area alt="" coords="370,478,473,489" href=
      "/search/markers/markerinfo.pl?marker_id=53" />
      <area alt="" coords="370,592,491,603" href=
      "/search/markers/markerinfo.pl?marker_id=76" />
      <area alt="" coords="370,754,483,765" href=
      "/search/markers/markerinfo.pl?marker_id=216" />
      <area alt="" coords="370,812,468,822" href=
      "/search/markers/markerinfo.pl?marker_id=3187" />
      <area alt="" coords="370,869,472,879" href=
      "/search/markers/markerinfo.pl?marker_id=3113" />
      <area alt="" coords="370,906,484,917" href=
      "/search/markers/markerinfo.pl?marker_id=130" />
      </map>
  </center>
END_HEREDOC
$page->footer();