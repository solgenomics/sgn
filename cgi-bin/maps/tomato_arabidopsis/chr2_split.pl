use strict;
use CXGN::Page;
my $page=CXGN::Page->new('chr2_split.html','html2pl converter');
$page->header('Chromosome 2');
print<<END_HEREDOC;

  <br />
  <br />

  <center>

  <h1>Chromosome 2</h1>

    <br />
    <p>(Click on one of the sidebars to view that region in detail)</p>

    <br />

    <img alt="" src="/documents/maps/tomato_arabidopsis/map_images/chr2_split.png" border="none"
    usemap="#chr2_map" /> <map name="chr2_map" id="chr2_map">
      <area alt="" coords="230,30,255,220" href="chr2a.pl" />
      <area alt="" coords="230,221,255,410" href="chr2b.pl" />
      <area alt="" coords="230,411,255,595" href="chr2c.pl" />
      <area alt="" coords="285,120,310,310" href="chr2d.pl" />
      <area alt="" coords="285,311,310,500" href="chr2e.pl" />
    </map>
  </center>
END_HEREDOC
$page->footer();