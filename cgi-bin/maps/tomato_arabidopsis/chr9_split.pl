use strict;
use CXGN::Page;
my $page=CXGN::Page->new('chr9_split.html','html2pl converter');
$page->header('Chromosome 9');
print<<END_HEREDOC;

  <br />
  <br />

  <center>

  <h1>Chromosome 9</h1>

    <br />
    <p>(Click on one of the sidebars to view that region in detail)</p>

    <br />

    <img alt="" src="/documents/maps/tomato_arabidopsis/map_images/chr9_split.png" border="none"
    usemap="#chr9_map" /> <map name="chr9_map" id="chr9_map">
      <area alt="" coords="230,5,265,195" href="chr9a.pl" />
      <area alt="" coords="230,196,265,385" href="chr9b.pl" />
      <area alt="" coords="230,386,265,575" href="chr9c.pl" />
      <area alt="" coords="295,100,320,290" href="chr9d.pl" />
      <area alt="" coords="295,291,320,475" href="chr9e.pl" />
    </map>
  </center>
END_HEREDOC
$page->footer();