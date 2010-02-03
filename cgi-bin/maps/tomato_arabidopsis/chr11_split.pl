use strict;
use CXGN::Page;
my $page=CXGN::Page->new('chr11_split.html','html2pl converter');
$page->header('Chromosome 11');
print<<END_HEREDOC;

  <br />
  <br />

  <center>

  <h1>Chromosome 11</h1>

    <br />
    <p>(Click on one of the sidebars to view that region in detail)</p>

    <br />

    <img alt="" src="/documents/maps/tomato_arabidopsis/map_images/chr11_split.png" border="none"
    usemap="#chr11_map" /> <map name="chr11_map" id="chr11_map">
      <area alt="" coords="260,5,305,175" href="chr11a.pl" />
      <area alt="" coords="260,176,305,335" href="chr11b.pl" />
      <area alt="" coords="260,336,305,495" href="chr11c.pl" />
      <area alt="" coords="315,85,350,255" href="chr11d.pl" />
      <area alt="" coords="315,256,350,415" href="chr11e.pl" />
    </map>
  </center>
END_HEREDOC
$page->footer();