use strict;
use CXGN::Page;
my $page=CXGN::Page->new("chromosome9.html","html2pl converter");
$page->header("Mapping information for chromosome 9");
print<<END_HEREDOC;

  <center>

<h1>Chromosome 9</h1>
<img alt="" src="/documents/maps/lpimp_ibl/IMAGES/lycopimp9.png" usemap="#synteny_map_chr9" /> 
<map name="synteny_map_chr9" id="synteny_map_chr9">
      <area alt="" coords="370,68,485,79" href=
      "/search/markers/markerinfo.pl?marker_id=168" />
      <area alt="" coords="370,286,472,297" href=
      "/search/markers/markerinfo.pl?marker_id=518" />
      <area alt="" coords="370,315,471,325" href=
      "/search/markers/markerinfo.pl?marker_id=665" />
      <area alt="" coords="370,572,488,582" href=
      "/search/markers/markerinfo.pl?marker_id=74" />
      <area alt="" coords="370,742,483,753" href=
      "/search/markers/markerinfo.pl?marker_id=193" />
      <area alt="" coords="370,799,458,810" href=
      "/search/markers/markerinfo.pl?marker_id=649" />
      <area alt="" coords="370,941,467,952" href=
      "/search/markers/markerinfo.pl?marker_id=21" />
      <area alt="" coords="370,1056,482,1066" href=
      "/search/markers/markerinfo.pl?marker_id=171" />
      </map>
  </center>
END_HEREDOC
$page->footer();