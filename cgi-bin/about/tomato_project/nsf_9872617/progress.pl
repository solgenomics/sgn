use strict;
use CXGN::Page;
my $page=CXGN::Page->new('progress.html','html2pl converter');
$page->header('TOMATO EST PROGRESS REPORTS');
print<<END_HEREDOC;

  <h2>Progress Meetings</h2>

  <p>Figures as presented by the Tomato Genome Project group during
  the <a href="/documents/help/about/tomato_project/NSF.Figures.pdf">first
  progress meeting</a> for the Tomato Genome Project on March 6,
  2000 and the <a href=
  "/documents/help/about/tomato_project/NSF.genomics.II.pdf">second progress
  meeting</a> on June 5, 2000 are available as pdf files. These
  files summarize the progress both in development of microarray
  technologies for tomato and the discovery of synteny between
  Arabidopsis and tomato. To view these pdf files you will need
  <a href=
  "http://www.adobe.com/products/acrobat/readstep2.html">Adobe's
  Acrobat Reader</a>.</p>

  <hr />

  <h2>Progress of EST Sequencing</h2>

  <p>Last updated 06/19/00</p>

  <p>The following table outlines the cDNA libraries that have been
  sent to TIGR for sequencing and the number of successfully
  sequenced ESTs produced from each to date. Libraries with a
  sequencing status of "on hold" have been constructed, but
  sequencing has been detained for one of a number of reasons.
  "Completed" libraries have reached a predetermined target number
  of successful sequences, while "sequencing" libraries are
  currently working toward a predetermined goal.</p>

  <table summary="" align="center" border="1" width="90\%"
  cellpadding="5" cellspacing="2">
    <tr>
      <td align="center" valign="middle">
        <h3><strong>Library Tissue</strong></h3>
      </td>

      <td align="center" valign="middle">
        <h3><strong>Species</strong></h3>
      </td>

      <td align="center" valign="middle">
        <h3><strong>Cornell ID</strong></h3>
      </td>

      <td align="center" valign="middle">
        <h3><strong>TIGR ID</strong></h3>
      </td>

      <td align="center" valign="middle">
        <h3><strong>Number of Successfully Sequenced ESTs</strong></h3>
      </td>

      <td align="center" valign="middle">
        <h3><strong>Sequencing Status</strong></h3>
      </td>
    </tr>

    <tr>
      <td><a href="/content/libraries/shoot.pl">Shoot</a></td>

      <td>Lycopersicon esculentum</td>

      <td align="center">cLEB</td>

      <td align="center">TSH</td>

      <td align="center">1,348</td>

      <td align="center">On Hold</td>
    </tr>

    <tr>
      <td><a href="/content/libraries/callus.pl">Callus</a></td>

      <td>Lycopersicon esculentum</td>

      <td align="center">cLEC</td>

      <td align="center">TCA</td>

      <td align="center">10,072</td>

      <td align="center">Completed</td>
    </tr>

    <tr>
      <td><a href="/content/libraries/ovary.pl">Ovary</a></td>

      <td>Lycopersicon esculentum</td>

      <td align="center">cLED</td>

      <td align="center">TOV</td>

      <td align="center">10,222</td>

      <td align="center">Completed</td>
    </tr>

    <tr>
      <td><a href="/content/libraries/quiescentseed.pl">Quiescent seed</a></td>

      <td>Lycopersicon esculentum</td>

      <td align="center">cLEE</td>

      <td align="center">TSE</td>

      <td align="center">778</td>

      <td align="center">Completed</td>
    </tr>

    <tr>
      <td><a href=
      "/content/libraries/germinatingseed.pl">Germinating
      seed</a></td>

      <td>Lycopersicon esculentum</td>

      <td align="center">cLEI</td>

      <td align="center">TGS</td>

      <td align="center">4,262</td>

      <td align="center">Sequencing</td>
    </tr>

    <tr>
      <td><a href=
      "/content/libraries/developingfruit.pl">Immature green
      fruit</a></td>

      <td>Lycopersicon esculentum</td>

      <td align="center">cLEM</td>

      <td align="center">TOM</td>

      <td align="center">74</td>

      <td align="center">Sequencing</td>
    </tr>

    <tr>
      <td><a href="/content/libraries/maturegreenfruit.pl">Mature
      green fruit</a></td>

      <td>Lycopersicon esculentum</td>

      <td align="center">cLEF</td>

      <td align="center">TMG</td>

      <td align="center">5,582</td>

      <td align="center">Completed</td>
    </tr>

    <tr>
      <td><a href="/content/libraries/breakerfruit.pl">Breaker fruit</a></td>

      <td>Lycopersicon esculentum</td>

      <td align="center">cLEG-R</td>

      <td align="center">TBF</td>

      <td align="center">2,096</td>

      <td align="center">Sequencing</td>
    </tr>

    <tr>
      <td><a href="/content/libraries/tomatoredripe.pl">Red, ripe
      fruit</a></td>

      <td>Lycopersicon esculentum</td>

      <td align="center">cLEN</td>

      <td align="center">TRR</td>

      <td align="center">4,196</td>

      <td align="center">Completed</td>
    </tr>

    <tr>
      <td><a href=
      "/content/libraries/pseudomonasresponse.pl">Leaves from
      <em>Pseudomonas</em> resistant variety</a></td>

      <td>Lycopersicon esculentum</td>

      <td align="center">cLER</td>

      <td align="center">TPR</td>

      <td align="center">5,413</td>

      <td align="center">Completed</td>
    </tr>

    <tr>
      <td><a href=
      "/content/libraries/pseudomonasresponse_s.pl">Leaves from
      <em>Pseudomonas</em> susceptible variety</a></td>

      <td>Lycopersicon esculentum</td>

      <td align="center">cLES</td>

      <td align="center">TPS</td>

      <td align="center">5,966</td>

      <td align="center">Completed</td>
    </tr>

    <tr>
      <td><a href="/content/libraries/mixedelicitor.pl">Leaf
      tissue under mixed elicitor stress</a></td>

      <td>Lycopersicon esculentum</td>

      <td align="center">cLET</td>

      <td align="center">TME</td>

      <td align="center">11,912</td>

      <td align="center">Completed</td>
    </tr>

    <tr>
      <td><a href="/content/libraries/deficientroot.pl">Roots
      under mixed mineral deficiencies and stresses</a></td>

      <td>Lycopersicon esculentum</td>

      <td align="center">cLEW</td>

      <td align="center">TRD</td>

      <td align="center">2,151</td>

      <td align="center">Sequencing</td>
    </tr>

    <tr>
      <td><a href=
      "/content/libraries/rootsatvegetative.pl">Pre-anthesis
      roots</a></td>

      <td>Lycopersicon esculentum</td>

      <td align="center">cLEY</td>

      <td align="center">TRY</td>

      <td align="center">2,646</td>

      <td align="center">Completed</td>
    </tr>

    <tr>
      <td><a href=
      "/content/libraries/rootatfruitset.pl">Post-anthesis
      roots</a></td>

      <td>Lycopersicon esculentum</td>

      <td align="center">cLEX</td>

      <td align="center">TRX</td>

      <td align="center">3,312</td>

      <td align="center">Completed</td>
    </tr>

    <tr>
      <td><a href="/content/libraries/rootlibraries.pl">Roots
      from germinating seedlings</a></td>

      <td>Lycopersicon esculentum</td>

      <td align="center">cLEZ</td>

      <td align="center">TRZ</td>

      <td align="center">2,519</td>

      <td align="center">Completed</td>
    </tr>

    <tr>
      <td><a href=
      "/content/libraries/hirsutumtrichome.pl">Trichomes</a></td>

      <td>Lycopersicon hirsutum</td>

      <td align="center">cLHT</td>

      <td align="center">THT</td>

      <td align="center">2,627</td>

      <td align="center">Completed</td>
    </tr>

    <tr>
      <td><a href=
      "/content/libraries/pennelliitrichome.pl">Trichomes</a></td>

      <td>Lycopersicon pennellii</td>

      <td align="center">cLPT</td>

      <td align="center">TPT</td>

      <td align="center">3,009</td>

      <td align="center">Completed</td>
    </tr>

    <tr>
      <td><a href="/content/libraries/flowerbudctoa.pl">0-3mm
      flower buds</a></td>

      <td>Lycopersicon esculentum</td>

      <td align="center">cTOA</td>

      <td align="center">TFA</td>

      <td align="center">2,612</td>

      <td align="center">Completed</td>
    </tr>

    <tr>
      <td><a href="/content/libraries/flowerbudctob.pl">3-8mm
      flower buds</a></td>

      <td>Lycopersicon esculentum</td>

      <td align="center">cTOB</td>

      <td align="center">TFB</td>

      <td align="center">2,713</td>

      <td align="center">Completed</td>
    </tr>

    <tr>
      <td><a href="/content/libraries/flowerbudctoc.pl">8mm to
      pre-anthesis flower buds</a></td>

      <td>Lycopersicon esculentum</td>

      <td align="center">cTOC</td>

      <td align="center">TFC</td>

      <td align="center">2,761</td>

      <td align="center">Completed</td>
    </tr>

    <tr>
      <td><a href="/content/libraries/openflowerctod.pl">Open
      flowers</a></td>

      <td>Lycopersicon esculentum</td>

      <td align="center">cTOD</td>

      <td align="center">TFD</td>

      <td align="center">2,952</td>

      <td align="center">Completed</td>
    </tr>
  </table><br />

  <p>For more information on specific sequences please visit
  <a href="/">The Solanaceae Genome
  Network</a>.</p>

    

END_HEREDOC
$page->footer();
