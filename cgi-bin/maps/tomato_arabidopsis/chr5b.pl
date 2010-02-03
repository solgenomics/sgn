use strict;
use CXGN::Page;
my $page=CXGN::Page->new('chr5b.html','html2pl converter');
$page->header('Chromosome 5');
print<<END_HEREDOC;


  <br />
  <br />

<center>
  <h1><a href="chr5_split.pl">Chromosome 5</a></h1>
  <h3>- Section B -</h3>

    <br />
    <br />

    <table summary="">
      <tr>
        <td align="right" valign="top"><img alt="" align="left"
        src="/documents/maps/tomato_arabidopsis/map_images/chr5b.png" border="none" /></td>

      </tr>
    </table>
  </center>
END_HEREDOC
$page->footer();