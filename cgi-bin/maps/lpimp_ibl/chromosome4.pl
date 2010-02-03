use strict;
use CXGN::Page;
my $page=CXGN::Page->new("chromosome4.html","html2pl converter");
$page->header("Mapping information for chromosome 4");
print<<END_HEREDOC;

  <center>

    <h1>Chromosome 4</h1>
<img alt="" src="/documents/maps/lpimp_ibl/IMAGES/lycopimp4.png" usemap="#synteny_map_chr4" /> 
<map name="synteny_map_chr4" id="synteny_map_chr4">
      <area alt="" coords="370,65,459,76" href=
      "/search/markers/markerinfo.pl?marker_id=147" />
      <area alt="" coords="370,216,469,227" href=
      "/search/markers/markerinfo.pl?marker_id=199" />
      <area alt="" coords="370,387,485,398" href=
      "/search/markers/markerinfo.pl?marker_id=165" />
      <area alt="" coords="370,549,472,560" href=
      "/search/markers/markerinfo.pl?marker_id=608" />
      <area alt="" coords="370,577,470,588" href=
      "/search/markers/markerinfo.pl?marker_id=210" />
      <area alt="" coords="370,644,469,655" href=
      "/search/markers/markerinfo.pl?marker_id=73" />
      <area alt="" coords="370,710,480,721" href=
      "/search/markers/markerinfo.pl?marker_id=9" />
      <area alt="" coords="370,862,483,873" href=
      "/search/markers/markerinfo.pl?marker_id=66" />
      <area alt="" coords="370,987,484,997" href=
      "/search/markers/markerinfo.pl?marker_id=118" />
      </map>
  </center>
END_HEREDOC
$page->footer();