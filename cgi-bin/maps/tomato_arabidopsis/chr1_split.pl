use strict;
use CXGN::Page;
my $page=CXGN::Page->new('chr1_split.html','html2pl converter');
$page->header('Chromosome 1');
print<<END_HEREDOC;

  <br />
  <br />

  <center>

  <h1>Chromosome 1</h1>

    <br />
    <p>(Click on one of the sidebars to view that region in detail)</p>

    <br />

    <img alt="" src="/documents/maps/tomato_arabidopsis/map_images/chr1_split.png" border="none"
    usemap="#chr1_map" /> <map name="chr1_map" id="chr1_map">
      <area alt="" coords="285,15,325,215" href="chr1a.pl" />
      <area alt="" coords="285,216,325,415" href="chr1b.pl" />
      <area alt="" coords="285,416,325,615" href="chr1c.pl" />
      <area alt="" coords="355,115,385,315" href="chr1d.pl" />
      <area alt="" coords="355,316,385,515" href="chr1e.pl" />
    </map>
  </center>
END_HEREDOC
$page->footer();