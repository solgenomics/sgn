use strict;
use CXGN::Page;
my $page=CXGN::Page->new('deficientroot.html','html2pl converter');
$page->header('Roots under mixed mineral deficiencies and stresses');
print<<END_HEREDOC;

  <center>


    <table summary="" width="720" cellpadding="0" cellspacing="0"
    border="0">
      <tr>
        <td>
          <center>
            <h2>Roots under mixed mineral deficiencies and
            stresses</h2>
          </center>

          <table summary="" width="100\%" cellspacing="5">
            <tr valign="top">
              <td width="20\%">Library:</td>

              <td>cLEW</td>
            </tr>

            <tr valign="top">
              <td>TIGR ID:</td>

              <td>TRD</td>
            </tr>

            <tr valign="top">
              <td>Authors:</td>

              <td>Rutger van der Hoeven, Julie Bezzerides, Dave
              Garvin, Leon Kochian, and Steve Tanksley</td>
            </tr>

            <tr valign="top">
              <td>Date made:</td>

              <td>02/00</td>
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

              <td>mixed roots from plants grown under different
              nutrient and mineral deficiencies</td>
            </tr>

            <tr valign="top">
              <td>Developmental stage:</td>

              <td>roots from plants four to eight weeks old with
              mixed nutrient and mineral deficiencies</td>
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

              <td>1.3 x 10<small><sup>6</sup></small></td>
            </tr>

            <tr valign="top">
              <td>Number mass excised:</td>

              <td>7.0 x 10<small><sup>5</sup></small></td>
            </tr>

            <tr valign="top">
              <td>Average insert length:</td>

              <td>1.4 Kb</td>
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

              <td>Tissue supplied by Dave Garvin (USDA-ARS, Ithaca,
              NY, 14850) and Leon Kochian. Roots were harvested
              from plants grown under the following
              deficiencies/stresses: 10 mM Al, Zn, P, K, Fe, and N.
              mRNA was isolated from individual treatments.
              Proportional aliquots of mRNA of each treatment were
              mixed and used for library construction.</td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
    
  </center>
END_HEREDOC
$page->footer();