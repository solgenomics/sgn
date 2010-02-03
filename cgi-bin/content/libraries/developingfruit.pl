use strict;
use CXGN::Page;
my $page=CXGN::Page->new('developingfruit.html','html2pl converter');
$page->header('Immature green fruit');
print<<END_HEREDOC;

  <center>


    <table summary="" width="720" cellpadding="0" cellspacing="0"
    border="0">
      <tr>
        <td>
          <center>
            <h2>Immature green fruit</h2>
          </center>

          <table summary="" width="100\%" cellspacing="5">
            <tr valign="top">
              <td width="20\%">Library:</td>

              <td>cLEM</td>
            </tr>

            <tr valign="top">
              <td>TIGR ID:</td>

              <td>TGF</td>
            </tr>

            <tr valign="top">
              <td>Authors:</td>

              <td>Alcala, Vrebalov, White, and Giovannoni</td>
            </tr>

            <tr valign="top">
              <td>Date made:</td>

              <td>08/99</td>
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

              <td>fruit</td>
            </tr>

            <tr valign="top">
              <td>Developmental stage:</td>

              <td>mixed fruit 5 dpa - 35 dpa (apx. 5 days prior to
              mature green)</td>
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

              <td>7.0 x 10<small><sup>5</sup></small></td>
            </tr>

            <tr valign="top">
              <td>Number mass excised:</td>

              <td>2.0 10<small><sup>5</sup></small></td>
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

              <td>Fruit were tagged at 5 dpa (0.5 cm) and harvested
              at 7 day intervals through 35 dpa. Equal masses of
              tissue from each stage were combined (including seeds
              and locules) prior to mRNA isolation.</td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
    
  </center>
END_HEREDOC
$page->footer();