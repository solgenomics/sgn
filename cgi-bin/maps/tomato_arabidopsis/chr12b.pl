use strict;
use CXGN::Page;
my $page=CXGN::Page->new('chr12b.html','html2pl converter');
$page->header('Chromosome 12');
print<<END_HEREDOC;

  <br />
  <br />

  <center>
<h1><a href="chr12_split.pl">Chromosome 12</a></h1>
  <h3>- Section B -</h3>

    <br />
    <br />

    <table summary="">
      <tr>
        <td align="right" valign="top"><img alt="" align="left"
        src="/documents/maps/tomato_arabidopsis/map_images/chr12b.png" border="none" /></td>

      </tr>
    </table>
  </center>
END_HEREDOC
$page->footer();