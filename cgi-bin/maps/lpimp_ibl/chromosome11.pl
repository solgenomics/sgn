use strict;
use CXGN::Page;
my $page=CXGN::Page->new("chromosome11.html","html2pl converter");
$page->header("Mapping information for chromosome 11");
print<<END_HEREDOC;

  <center>

    <h1>Chromosome 11</h1>
<img alt="" src="/documents/maps/lpimp_ibl/IMAGES/lycopimp11.png" usemap="#synteny_map_chr11" /> 
<map name="synteny_map_chr11" id="synteny_map_chr11">
      <area alt="" coords="370,71,490,81" href=
      "/search/markers/markerinfo.pl?marker_id=355" />
      <area alt="" coords="370,231,491,242" href=
      "/search/markers/markerinfo.pl?marker_id=71" />
      <area alt="" coords="370,441,491,451" href=
      "/search/markers/markerinfo.pl?marker_id=212" />
      <area alt="" coords="370,592,469,603" href=
      "/search/markers/markerinfo.pl?marker_id=68" />
      <area alt="" coords="370,696,490,707" href=
      "/search/markers/markerinfo.pl?marker_id=125" />
      <area alt="" coords="370,886,472,897" href=
      "/search/markers/markerinfo.pl?marker_id=178" />
      <area alt="" coords="370,954,474,964" href=
      "/search/markers/markerinfo.pl?marker_id=24" />
      <area alt="" coords="370,992,430,1002" href=
      "/search/markers/markerinfo.pl?marker_id=3182" />
      <area alt="" coords="370,1087,472,1097" href=
      "/search/markers/markerinfo.pl?marker_id=151" />
      </map>
  </center>
END_HEREDOC
$page->footer();