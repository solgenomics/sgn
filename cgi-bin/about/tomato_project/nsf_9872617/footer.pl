use strict;
use CXGN::Page;
my $page=CXGN::Page->new('footer.html','html2pl converter');
$page->header('Sol Genomics Network');
print<<END_HEREDOC;
<br />

<hr width="50\%" />

  <table summary="" align="center" cellspacing="5" cellpadding="5">
    <tr>
      <td align="center"><a href="index.pl">Home</a></td>
      <td align="center"><a href="progress.pl">Progress Reports</a></td>
      <td align="center"><a href=
      "/maps/tomato_arabidopsis/index.pl">Tomato-Arabidopsis Synteny</a></td>
      <td align="center"><a href="http://ted.bti.cornell.edu/">Database</a></td>
    </tr>
  </table>

  <table summary="" align="center" cellspacing="5" cellpadding="5">
    <tr>
      <td align="center"><a href="members.pl">Members of Adivsory Group</a></td>

      <td align="center"><a href="websites.pl">Links to Related Websites</a></td>
      <td align="center"><a href="project.pl">Project</a></td>
      <td align="center"><a href="publications.pl">Publications</a></td>


    </tr>
  </table>
END_HEREDOC
$page->footer();