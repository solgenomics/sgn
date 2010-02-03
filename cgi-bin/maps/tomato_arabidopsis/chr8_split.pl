use strict;
use CXGN::Page;
my $page=CXGN::Page->new('chr8_split.html','html2pl converter');
$page->header('Chromosome 8');
print<<END_HEREDOC;

  <br />
  <br />

  <center>

  <h1>Chromosome 8</h1>

    <br />
    <p>(Click on one of the sidebars to view that region in detail)</p>

    <br />


    <img alt="" src="/documents/maps/tomato_arabidopsis/map_images/chr8_split.png" border="none"
    usemap="#chr8_map" /> <map name="chr8_map" id="chr8_map">
      <area alt="" coords="240,15,275,195" href="chr8a.pl" />
      <area alt="" coords="240,196,275,375" href="chr8b.pl" />
      <area alt="" coords="240,376,275,550" href="chr8c.pl" />
      <area alt="" coords="295,100,330,280" href="chr8d.pl" />
      <area alt="" coords="295,281,330,460" href="chr8e.pl" />
    </map>
  </center>
END_HEREDOC
$page->footer();