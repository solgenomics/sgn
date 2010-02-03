use strict;
use CXGN::Page;
my $page=CXGN::Page->new('Spain - Tomato Chromosome 9','Lukas');
$page->header('About the Spanish Tomato Sequencing Project');
print<<END_HEREDOC;

  <center>

    <table summary="" width="720" cellpadding="10" cellspacing="5"
    border="0">
      <tr>
        <td><br />
        <img src="/documents/img/flags/Flag_of_Spain_small.png" border="0" alt=
        "Italian flag" /></td>

        <td>
          <h1>Tomato Sequencing Project: Chromosome 9</h1>
          
          <h1>Spain</h1>
          Euchromatin portion = 16 Mb<br />
          Projected \# of BACs 164<br /><br />
          <a href="tomato_sequencing.pl">Click here for an overview of all 12 chromosomes</a>
        </td>
      </tr>

      <tr>
        <td>&nbsp;</td>

        <td>
          <h4>Principal Investigators</h4>

    Antonio Granell, <a href="http://www.ibmcp.upv.es/">IBMCP, Valencia</a><br />
    Miguel A. Botella, <a href="http://www.uma.es">UMA, Malaga</a><br />

          <h4>Funding</h4>
          <p><a href="http://www.gen-es.org">Genoma Espana</a></p>

<h4>Participating Groups</h4>

<a href="http://www.ibmcp.upv.es/">IBMCP-Valencia, CSIC</a><br />
<a href="http://evolutionarygenomics.imim.es/research_lines.html">IMIM-Barcelona</a><br />
<a href="http://www.sistemasgenomicos.com/general/">Sistemas Genomicos</a><br />

        </td>
      </tr>
    </table>
  </center>
END_HEREDOC
$page->footer();
