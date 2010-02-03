use strict;
use CXGN::Page;
my $page=CXGN::Page->new('chr9e.html','html2pl converter');
$page->header('Chromosome 9');
print<<END_HEREDOC;


  <br />
  <br />

<center>
  <h1><a href="chr9_split.pl">Chromosome 9</a></h1>
  <h3>- Section E -</h3>

    <br />
    <br />

    <table summary="">
      <tr>
        <td align="right" valign="top"><img alt="" align="left"
        src="/documents/maps/tomato_arabidopsis/map_images/chr9e.png" border="none" /></td>

      </tr>
    </table>
  </center>
END_HEREDOC
$page->footer();