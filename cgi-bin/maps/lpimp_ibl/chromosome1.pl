use strict;
use CXGN::Page;
my $page=CXGN::Page->new("chromosome1.html","html2pl converter");
$page->header("Mapping information for chromosome 1");
print<<END_HEREDOC;

  <center>


    <h1>Chromosome 1</h1>
<img alt="" src="/documents/maps/lpimp_ibl/IMAGES/lycopimp1.png" usemap="#synteny_map_chr1" /> 
<map name="synteny_map_chr1" id="synteny_map_chr1">

      <area alt="" coords="370,92,487,102" href=
      "/search/markers/markerinfo.pl?marker_id=185" />
      <area alt="" coords="370,139,481,149" href=
      "/search/markers/markerinfo.pl?marker_id=109" />
      <area alt="" coords="370,318,478,329" href=
      "/search/markers/markerinfo.pl?marker_id=93" />
      <area alt="" coords="370,527,485,538" href=
      "/search/markers/markerinfo.pl?marker_id=202" />
      <area alt="" coords="370,641,457,652" href=
      "/search/markers/markerinfo.pl?marker_id=107" />
      <area alt="" coords="370,774,490,785" href=
      "/search/markers/markerinfo.pl?marker_id=529" />
      <area alt="" coords="370,974,485,985" href=
      "/search/markers/markerinfo.pl?marker_id=207" />
      <area alt="" coords="370,1012,473,1023" href=
      "/search/markers/markerinfo.pl?marker_id=62" />
      <area alt="" coords="370,1032,483,1043" href=
      "/search/markers/markerinfo.pl?marker_id=140" />
      <area alt="" coords="370,1108,481,1118" href=
      "/search/markers/markerinfo.pl?marker_id=3180" />
      <area alt="" coords="370,1249,471,1260" href=
      "/search/markers/markerinfo.pl?marker_id=150" />
      <area alt="" coords="370,1306,485,1317" href=
      "/search/markers/markerinfo.pl?marker_id=135" />
      <area alt="" coords="370,1449,473,1460" href=
      "/search/markers/markerinfo.pl?marker_id=170" />
      <area alt="" coords="370,1515,483,1526" href=
      "/search/markers/markerinfo.pl?marker_id=80" />
      </map>
  </center>
END_HEREDOC
$page->footer();
