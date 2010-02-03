use strict;
use CXGN::Page;
my $page=CXGN::Page->new('chr2b.html','html2pl converter');
$page->header('Chromosome 2');
print<<END_HEREDOC;

  <br />
  <br />

  <center>
<h1><a href="chr2_split.pl">Chromosome 2</a></h1>
  <h3>- Section B -</h3>

    <br />
    <br />

    <table summary="">
      <tr>
        <td align="right" valign="top"><img alt="" align="left"
        src="/documents/maps/tomato_arabidopsis/map_images/chr2b.png" border="none" /></td>

      </tr>
    </table>
  </center>
END_HEREDOC
$page->footer();