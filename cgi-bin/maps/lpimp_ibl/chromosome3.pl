use strict;
use CXGN::Page;
my $page=CXGN::Page->new("chromosome3.html","html2pl converter");
$page->header("Mapping information for chromosome 3");
print<<END_HEREDOC;

  <center>

    <h1>Chromosome
    3</h1><img alt="" src="/documents/maps/lpimp_ibl/IMAGES/lycopimp3.png" usemap=
    "#synteny_map_chr3" /> <map name="synteny_map_chr3" id=
    "synteny_map_chr3">
      <area alt="" coords="370,75,489,86" href=
      "/search/markers/markerinfo.pl?marker_id=183" />
      <area alt="" coords="370,217,473,228" href=
      "/search/markers/markerinfo.pl?marker_id=123" />
      <area alt="" coords="370,264,468,275" href=
      "/search/markers/markerinfo.pl?marker_id=3185" />
      <area alt="" coords="370,341,479,351" href=
      "/search/markers/markerinfo.pl?marker_id=92" />
      <area alt="" coords="370,531,470,541" href=
      "/search/markers/markerinfo.pl?marker_id=128" />
      <area alt="" coords="370,655,474,665" href=
      "/search/markers/markerinfo.pl?marker_id=505" />
      <area alt="" coords="370,720,478,731" href=
      "/search/markers/markerinfo.pl?marker_id=162" />
      <area alt="" coords="370,807,490,817" href=
      "/search/markers/markerinfo.pl?marker_id=191" />
      <area alt="" coords="370,863,485,874" href=
      "/search/markers/markerinfo.pl?marker_id=136" />
      <area alt="" coords="370,996,474,1007" href=
      "/search/markers/markerinfo.pl?marker_id=653" />
      <area alt="" coords="370,1015,485,1026" href=
      "/search/markers/markerinfo.pl?marker_id=237" />
      <area alt="" coords="370,1035,471,1046" href=
      "/search/markers/markerinfo.pl?marker_id=132" />
      <area alt="" coords="370,1186,490,1197" href=
      "/search/markers/markerinfo.pl?marker_id=55" />
      </map>
  </center>
END_HEREDOC
$page->footer();