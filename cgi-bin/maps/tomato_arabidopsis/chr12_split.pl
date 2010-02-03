use strict;
use CXGN::Page;
my $page=CXGN::Page->new('chr12_split.html','html2pl converter');
$page->header('Chromosome 12');
print<<END_HEREDOC;

  <br />
  <br />

  <center>

  <h1>Chromosome 12</h1>

    <br />
    <p>(Click on one of the sidebars to view that region in detail)</p>

    <br />

    <img alt="" src="/documents/maps/tomato_arabidopsis/map_images/chr12_split.png" border="none"
    usemap="#chr12_map" /> <map name="chr12_map" id="chr12_map">
      <area alt="" coords="290,15,330,155" href="chr12a.pl" />
      <area alt="" coords="290,156,330,290" href="chr12b.pl" />
      <area alt="" coords="290,291,330,425" href="chr12c.pl" />
      <area alt="" coords="345,80,380,220" href="chr12d.pl" />
      <area alt="" coords="345,221,380,355" href="chr12e.pl" />
    </map>
  </center>
END_HEREDOC
$page->footer();