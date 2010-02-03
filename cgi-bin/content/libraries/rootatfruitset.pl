use strict;
use CXGN::Page;
my $page=CXGN::Page->new('rootatfruitset.html','html2pl converter');
$page->header('Post-anthesis Root Library');
print<<END_HEREDOC;

  <center>
    
    <table summary="" width="720" cellpadding="0" cellspacing="0"
    border="0">
      <tr>
        <td>
          <center>
            <h2>Post-anthesis Root Library</h2>
          </center>

          <table summary="" width="100\%" cellspacing="5">
            <tr valign="top">
              <td width="20\%">Library:</td>

              <td>cLEX</td>
            </tr>

            <tr valign="top">
              <td>TIGR ID:</td>

              <td>TRX</td>
            </tr>

            <tr valign="top">
              <td>Authors:</td>

              <td>Rutger van der Hoeven, Dave Garvin, Leon Kochian,
              and Steve Tanksley</td>
            </tr>

            <tr valign="top">
              <td>Date made:</td>

              <td>07/99</td>
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

              <td>roots from plants at fruit-set stage/post-fruit
              loading roots</td>
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

              <td>1.0 x 10<small><sup>7</sup></small></td>
            </tr>

            <tr valign="top">
              <td>Number mass excised:</td>

              <td>1.5 x 10<small><sup>6</sup></small></td>
            </tr>

            <tr valign="top">
              <td>Average insert length:</td>

              <td>0.9 Kb</td>
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