use strict;
use CXGN::Page;
my $page=CXGN::Page->new('chr5_split.html','html2pl converter');
$page->header('Chromosome 5');
print<<END_HEREDOC;

  <br />
  <br />

  <center>

  <h1>Chromosome 5</h1>

    <br />
    <p>(Click on one of the sidebars to view that region in detail)</p>

    <br />

    <img alt="" src="/documents/maps/tomato_arabidopsis/map_images/chr5_split.png" border="none"
    usemap="#chr5_map" /> <map name="chr5_map" id="chr5_map">
      <area alt="" coords="235,15,275,195" href="chr5a.pl" />
      <area alt="" coords="235,196,275,365" href="chr5b.pl" />
      <area alt="" coords="235,366,275,545" href="chr5c.pl" />
      <area alt="" coords="295,100,325,280" href="chr5d.pl" />
      <area alt="" coords="295,281,325,455" href="chr5e.pl" />
    </map>
  </center>
END_HEREDOC
$page->footer();