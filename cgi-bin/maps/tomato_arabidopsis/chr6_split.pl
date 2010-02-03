use strict;
use CXGN::Page;
my $page=CXGN::Page->new('chr6_split.html','html2pl converter');
$page->header('Chromosome 6');
print<<END_HEREDOC;

  <br />
  <br />

  <center>

  <h1>Chromosome 6</h1>

    <br />
    <p>(Click on one of the sidebars to view that region in detail)</p>

    <br />

    <img alt="" src="/documents/maps/tomato_arabidopsis/map_images/chr6_split.png" border="none"
    usemap="#chr6_map" /> <map name="chr6_map" id="chr6_map">
      <area alt="" coords="290,5,320,175" href="chr6a.pl" />
      <area alt="" coords="290,176,320,340" href="chr6b.pl" />
      <area alt="" coords="290,341,320,505" href="chr6c.pl" />
      <area alt="" coords="345,85,375,255" href="chr6d.pl" />
      <area alt="" coords="345,256,375,360" href="chr6e.pl" />
    </map>
  </center>
END_HEREDOC
$page->footer();