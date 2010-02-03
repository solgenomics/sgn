use strict;
use CXGN::Page;
my $page=CXGN::Page->new('italy.html','html2pl converter');
$page->header('About the Italian Sequencing Project');
print<<END_HEREDOC;

  <center>

    <table summary="" width="720" cellpadding="10" cellspacing="10"
    border="0">
      <tr>
        <td><br />
        <img src="/documents/img/flags/italy_big.gif" border="0" alt=
        "Italian flag" /></td>

        <td>
          <h1>Tomato Sequencing Project:</h1>
          <br />
          <h1>Chromosome 12</h1>
          <p>Euchromatin portion = 11Mb<br />
          Projected # of BACs 113<br />
          <a href=
          "tomato_sequencing.pl">
          Overview of all 12 chromosomes.</a></p>
        </td>
      </tr>

      <tr>
        <td>&nbsp;</td>

        <td>
          <h4>Principal Investigators</h4>
          <p>Prof. Luigi Frusciante,
          University of Naples<br />
          Dr. Giovanni Giuliano, ENEA</p>

          <h4>Funding</h4>
          <p><a href=
          "http://agronanotech.unina.it/index.php?id=35">Agronanotech
          project</a> (Italian Ministry of Agriculture)<br />
          <a href="http://www.enea.it">ENEA</a> (Italian Agency for
          New technologies, Energy and the Environment)</p>

          <h4>Collaborators</h4>
          <p>Dr. Silvana Grandillo, Italian
          Research Council<br />
          Prof. Giorgio Valle, University of Padua</p>
        </td>
      </tr>
    </table>
  </center>
END_HEREDOC
$page->footer();