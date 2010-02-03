use strict;
use CXGN::Page;
my $page=CXGN::Page->new('chr7_split.html','html2pl converter');
$page->header('Chromosome 7');
print<<END_HEREDOC;

  <br />
  <br />

  <center>

  <h1>Chromosome 7</h1>

    <br />
    <p>(Click on one of the sidebars to view that region in detail)</p>

    <br />

    <img alt="" src="/documents/maps/tomato_arabidopsis/map_images/chr7_split.png" border="none"
    usemap="#chr7_map" /> <map name="chr7_map" id="chr7_map">
      <area alt="" coords="205,5,235,200" href="chr7a.pl" />
      <area alt="" coords="205,201,235,385" href="chr7b.pl" />
      <area alt="" coords="205,386,235,570" href="chr7c.pl" />
      <area alt="" coords="265,100,290,290" href="chr7d.pl" />
      <area alt="" coords="265,291,290,475" href="chr7e.pl" />
    </map>
  </center>
END_HEREDOC
$page->footer();