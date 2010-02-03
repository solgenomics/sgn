use strict;
use CXGN::Page;
my $page=CXGN::Page->new('chr7a.html','html2pl converter');
$page->header('Chromosome 7');
print<<END_HEREDOC;


  <br />
  <br />

<center>
  <h1><a href="chr7_split.pl">Chromosome 7</a></h1>
  <h3>- Section A -</h3>

    <br />
    <br />

    <table summary="">
      <tr>
        <td align="right" valign="top"><img alt="" align="left"
        src="/documents/maps/tomato_arabidopsis/map_images/chr7a.png" border="none" /></td>

      </tr>
    </table>
  </center>
END_HEREDOC
$page->footer();