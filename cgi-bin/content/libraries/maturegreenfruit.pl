use strict;
use CXGN::Page;
my $page=CXGN::Page->new('maturegreenfruit.html','html2pl converter');
$page->header('Mature Green Fruit Library');
print<<END_HEREDOC;

  <center>
    
    <table summary="" width="720" cellpadding="0" cellspacing="0"
    border="0">
      <tr>
        <td>
          <center>
            <h2>Mature Green Fruit Library</h2>
          </center>

          <table summary="" width="100\%" cellspacing="5">
            <tr valign="top">
              <td width="20\%">Library:</td>

              <td>cLEF</td>
            </tr>

            <tr valign="top">
              <td>TIGR ID:</td>

              <td>TMG</td>
            </tr>

            <tr valign="top">
              <td>Authors:</td>

              <td>Alcala, Vrebalov, White, and Giovannoni</td>
            </tr>

            <tr valign="top">
              <td>Date made:</td>

              <td>06/99</td>
            </tr>

            <tr valign="top">
              <td>Species:</td>

              <td><em>Lycopersicon esculentum</em></td>
            </tr>

            <tr valign="top">
              <td>Accession:</td>

              <td>TA496</td>
            </tr>

            <tr valign="top">
              <td>Tissue:</td>

              <td>fruit pericarp</td>
            </tr>

            <tr valign="top">
              <td>Developmental stage:</td>

              <td>mature green</td>
            </tr>

            <tr valign="top">
              <td>Vector:</td>

              <td>pBluescript SK(+/-)</td>
            </tr>

            <tr valign="top">
              <td>Host:</td>

              <td>SOLR</td>
            </tr>

            <tr valign="top">
              <td>Primary pfu:</td>

              <td>1.37 x 10<small><sup>6</sup></small></td>
            </tr>

            <tr valign="top">
              <td>Number mass excised:</td>

              <td>2.0 x 10<small><sup>5</sup></small></td>
            </tr>

            <tr valign="top">
              <td>Average insert length:</td>

              <td>1.6 Kb</td>
            </tr>

            <tr valign="top">
              <td>Cloning sites:</td>

              <td>5' EcoRI, 3' XhoI</td>
            </tr>

            <tr valign="top">
              <td>Antibiotic:</td>

              <td>ampicillin</td>
            </tr>

            <tr valign="top">
              <td>Primers:</td>

              <td>M13F and M13R</td>
            </tr>

            <tr valign="top">
              <td>Comments:</td>

              <td>Fruit were tagged at the 1 cm stage and harvested
              3-5 days prior to ripening. Fruit were cut in half to
              verify the seeds were indeed "mature". The seeds and
              locules were discarded prior to freezing the
              pericarp. 09/14/99 cLEF - 83 total sequences,
              11dupes, 86.7\% unique with 32 unknowns. No junk found
              (chloroplast, mitochondria, or <em>E. coli</em>).</td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
    
  </center>
END_HEREDOC
$page->footer();