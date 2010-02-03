use strict;
use CXGN::Page;
my $page=CXGN::Page->new('chr3_split.html','html2pl converter');
$page->header('Chromosome 3');
print<<END_HEREDOC;

  <br />
  <br />

  <center>

  <h1>Chromosome 3</h1>

    <br />
    <p>(Click on one of the sidebars to view that region in detail)</p>

    <br />

    <img alt="" src="/documents/maps/tomato_arabidopsis/map_images/chr3_split.png" border="none"
    usemap="#chr3_map" /> <map name="chr3_map" id="chr3_map">
      <area alt="" coords="280,10,310,200" href="chr3a.pl" />
      <area alt="" coords="280,201,310,385" href="chr3b.pl" />
      <area alt="" coords="280,386,310,570" href="chr3c.pl" />
      <area alt="" coords="335,105,365,290" href="chr3d.pl" />
      <area alt="" coords="335,291,365,475" href="chr3e.pl" />
    </map>
  </center>
END_HEREDOC
$page->footer();