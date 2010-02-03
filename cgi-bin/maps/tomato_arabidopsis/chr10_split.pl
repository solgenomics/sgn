use strict;
use CXGN::Page;
my $page=CXGN::Page->new('chr10_split.html','html2pl converter');
$page->header('Chromosome 10');
print<<END_HEREDOC;

  <br />
  <br />

  <center>

  <h1>Chromosome 10</h1>

    <br />
    <p>(Click on one of the sidebars to view that region in detail)</p>

    <br />

    <img alt="" src="/documents/maps/tomato_arabidopsis/map_images/chr10_split.png" border="none"
    usemap="#chr10_map" /> <map name="chr10_map" id="chr10_map">
      <area alt="" coords="215,25,250,185" href="chr10a.pl" />
      <area alt="" coords="215,186,250,345" href="chr10b.pl" />
      <area alt="" coords="215,346,250,510" href="chr10c.pl" />
      <area alt="" coords="270,105,305,265" href="chr10d.pl" />
      <area alt="" coords="270,266,305,425" href="chr10e.pl" />
    </map>
  </center>
END_HEREDOC
$page->footer();