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
        <img src="/documents/img/flags/Flag_of_Japan_small.png" border="1" alt=
        "flag of Japan" /></td>

        <td>
          <h1>Tomato Sequencing Project: Chromosome 8</h1>
          
          <h1>Japan</h1>
          Euchromatin portion = 17Mb<br />
          Projected \# of BACs: 175<br /><br />
          <a href="tomato_sequencing.pl">Click here for an overview of all 12 chromosomes</a>
        </td>
      </tr>

      <tr>
        <td>&nbsp;</td>

        <td>
          <h4>Principal Investigators</h4>
<ul>
<li><a href="http://www.kazusa.or.jp/eng/index.html">Daisuke Shibata, KDRI</a></li>
<li><a href="http://www.kazusa.or.jp/eng/index.html">Satoshi Tabata, KDRI</a></li>
</ul>
<h4>Funding</h4>
<ul>
<li>Chiba Prefecture</li>
<li>Kazusa DNA Research Institute Foundation</li>
<li>National Institute of Vegetable and Tea Science (NIVTS) Priority Research Programme</li>
</ul>

<h4>Participating Groups</h4>
<ul>
<li><a href="http://www.kazusa.or.jp/eng/index.html">Kazusa DNA Research Institute</a></li>
<li><a href="http://vegetea.naro.affrc.go.jp/index_en.html">National Institute of Vegetable and Tea Science</a></li>

        </td>
      </tr>
    </table>
  </center>
END_HEREDOC
$page->footer();
