use strict;
use CXGN::Page;
my $page=CXGN::Page->new('germinatingseed.html','html2pl converter');
$page->header('Germinating Seed Library');
print<<END_HEREDOC;

  <center>
    
    <table summary="" width="720" cellpadding="0" cellspacing="0"
    border="0">
      <tr>
        <td>
          <center>
            <h2>Germinating Seed Library</h2>
          </center>

          <table summary="" width="100\%" cellspacing="5">
            <tr valign="top">
              <td width="20\%">Library:</td>

              <td>cLEI</td>
            </tr>

            <tr valign="top">
              <td>TIGR ID:</td>

              <td>TGS</td>
            </tr>

            <tr valign="top">
              <td>Authors:</td>

              <td>Alcala, Vrebalov, White, and Giovannoni</td>
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

              <td>whole seedlings</td>
            </tr>

            <tr valign="top">
              <td>Developmental stage:</td>

              <td>early germinating seedlings/cotyledons</td>
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

              <td>3.5 x 10<small><sup>5</sup></small></td>
            </tr>

            <tr valign="top">
              <td>Number mass excised:</td>

              <td>2.0 10<small><sup>5</sup></small></td>
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

              <td>Seedlings were collected seven days
              post-imbibition on water-agar. Mixed-stage, whole,
              germinating seedlings from seed coat emergence up to
              two centimeters in length were chosen. Seeds not
              showing obvious signs of germination were discarded.
              Tissue consists of germinating seedlings at various
              stages from 2 days imbibition to emergence
              (approximately four days) to 1 cm (approximately six
              days) to 2 cm (approximately 8 days). Tissues were
              harvested based on stage, not day.</td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
    
  </center>
END_HEREDOC
$page->footer();