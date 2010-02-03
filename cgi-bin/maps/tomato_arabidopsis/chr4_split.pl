use strict;
use CXGN::Page;
my $page=CXGN::Page->new('chr4_split.html','html2pl converter');
$page->header('Chromosome 4');
print<<END_HEREDOC;

  <br />
  <br />

  <center>

  <h1>Chromosome 4</h1>

    <br />
    <p>(Click on one of the sidebars to view that region in detail)</p>

    <br />

    <img alt="" src="/documents/maps/tomato_arabidopsis/map_images/chr4_split.png" border="none"
    usemap="#chr4_map" /> <map name="chr4_map" id="chr4_map">
      <area alt="" coords="220,5,250,170" href="chr4a.pl" />
      <area alt="" coords="220,171,250,330" href="chr4b.pl" />
      <area alt="" coords="220,331,250,495" href="chr4c.pl" />
      <area alt="" coords="275,85,305,250" href="chr4d.pl" />
      <area alt="" coords="275,251,305,415" href="chr4e.pl" />
    </map>
  </center>
END_HEREDOC
$page->footer();