use strict;
use CXGN::Page;
my $page=CXGN::Page->new('chr9a.html','html2pl converter');
$page->header('Chromosome 9');
print<<END_HEREDOC;


  <br />
  <br />

<center>
  <h1><a href="chr9_split.pl">Chromosome 9</a></h1>
  <h3>- Section A -</h3>

    <br />
    <br />

<table summary="" width="50\%">
<tr><td align="center">    <b>NB -</b> In the image below, the marker (937) T1641 has
    historically been mistakenly labelled as <i>T1614</i>. This has now been
    corrected. Any previous references to T1614 stemming from this map should
    be taken as referring to T1641.</td></tr>
</table>

    <br />
    <br />

    <table summary="">
      <tr>
        <td align="right" valign="top"><img alt="" align="left"
        src="/documents/maps/tomato_arabidopsis/map_images/chr9a.png" border="none" /></td>

      </tr>
    </table>
  </center>
END_HEREDOC
$page->footer();