use strict;
use CXGN::Page;
my $page=CXGN::Page->new('breakerfruit.html','html2pl converter');
$page->header('Breaker Fruit Library');
print<<END_HEREDOC;

  <center>
    

    <table summary="" width="720" cellpadding="0" cellspacing="0"
    border="0">
      <tr>
        <td>
          <center>
            <h2>Breaker fruit</h2>
          </center>

          <table summary="" width="100\%" cellspacing="5">
            <tr valign="top">
              <td width="20\%">Library:</td>

              <td>cLEG-R</td>
            </tr>

            <tr valign="top">
              <td>TIGR ID:</td>

              <td>TBF</td>
            </tr>

            <tr valign="top">
              <td>Authors:</td>

              <td>Alcala, White, and Giovannoni</td>
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

              <td>fruit pericarp</td>
            </tr>

            <tr valign="top">
              <td>Developmental stage:</td>

              <td>breaker</td>
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

              <td>6.6 x 10<small><sup>5</sup></small></td>
            </tr>

            <tr valign="top">
              <td>Number mass excised:</td>

              <td>3.0 10<small><sup>5</sup></small></td>
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

              <td>Fruit were harvested at the "breaker" stage
              (first sign of lycopene accumulation on the blossom
              end of the fruit). Fruit were cut in half and the
              seeds and locules were discarded prior to freezing
              the pericarp.</td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
    
  </center>
END_HEREDOC
$page->footer();