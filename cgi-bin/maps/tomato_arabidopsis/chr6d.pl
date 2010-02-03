use strict;
use CXGN::Page;
my $page=CXGN::Page->new('chr6d.html','html2pl converter');
$page->header('Chromosome 6');
print<<END_HEREDOC;


  <br />
  <br />

<center>
  <h1><a href="chr6_split.pl">Chromosome 6</a></h1>
  <h3>- Section D -</h3>

    <br />
    <br />


    <table summary="">
      <tr>
        <td align="right" valign="top"><img alt="" align="left"
        src="/documents/maps/tomato_arabidopsis/map_images/chr6d.png" border="none" /></td>
      </tr>
    </table>
  </center>
END_HEREDOC
$page->footer();