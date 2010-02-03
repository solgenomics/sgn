use strict;
use CXGN::Page;
my $page=CXGN::Page->new('rootsatvegetative.html','html2pl converter');
$page->header('Pre-anthesis Root Library');
print<<END_HEREDOC;

  <center>
    
    <table summary="" width="720" cellpadding="0" cellspacing="0"
    border="0">
      <tr>
        <td>
          <center>
            <h2>Pre-anthesis Root Library</h2>
          </center>

          <table summary="" width="100\%" cellspacing="5">
            <tr valign="top">
              <td width="20\%">Library:</td>
              <td>cLEY</td>
            </tr>

            <tr valign="top">
              <td>TIGR ID:</td>
              <td>TRY</td>
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

              <td>root</td>
            </tr>

            <tr valign="top">
              <td>Developmental stage:</td>

              <td>roots from pre-anthesis plants/pre-fruit loading
              roots</td>
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

              <td>4.3 x 10<small><sup>6</sup></small></td>
            </tr>

            <tr valign="top">
              <td>Number mass excised:</td>

              <td>2.0 x 10<small><sup>6</sup></small></td>
            </tr>

            <tr valign="top">
              <td>Average insert length:</td>

              <td>1.5 Kb</td>
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
              NY, 14850) and Leon Kochian.</td>
            </tr>
          </table>
        </td>
      </tr>
</table>
    
  </center>
END_HEREDOC
$page->footer();