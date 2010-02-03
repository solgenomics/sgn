use strict;
use CXGN::Page;
my $page=CXGN::Page->new('quiescentseed.html','html2pl converter');
$page->header('Quiescent Seed Library');
print<<END_HEREDOC;

  <center>
    
    <table summary="" width="720" cellpadding="0" cellspacing="0"
    border="0">
      <tr>
        <td>
          <center>
            <h2>Quiescent Seed Library</h2>
          </center>

          <table summary="" width="100\%" cellspacing="5">
            <tr valign="top">
              <td width="20\%">Library:</td>

              <td>cLEE</td>
            </tr>

            <tr valign="top">
              <td>TIGR ID:</td>

              <td>TSE</td>
            </tr>

            <tr valign="top">
              <td>Authors:</td>

              <td>Alcala, Vrebalov, White, and Giovannoni</td>
            </tr>

            <tr valign="top">
              <td>Date made:</td>

              <td>12/99</td>
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

              <td>seeds</td>
            </tr>

            <tr valign="top">
              <td>Developmental stage:</td>

              <td>dissected five days post-anthesis to fruit
              over-ripe stage</td>
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

              <td>1.2 x 10<small><sup>4</sup></small></td>
            </tr>

            <tr valign="top">
              <td>Number mass excised:</td>

              <td>1.2 x 10<small><sup>4</sup></small></td>
            </tr>

            <tr valign="top">
              <td>Average insert length:</td>

              <td>1.0 Kb</td>
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

              <td>All of the primary library was mass excised.
              Tissue is from seed and maturing carpels. Fruit from
              5 dpa, 10 dpa, 20 dpa, mature green, breaker, firm,
              red-ripe, and very soft, red-ripe were collected.
              Seed was removed from all stages, though there was
              relatively little from the 5 dpa stage. 0.1 g of 5
              dpa seed was combined with 0.3 g of 10 dpa, 0.7 g of
              20 dpa, and 0.3 g from each of the mature green
              through late ripening stage seeds (1.2 g total for
              these 4) for RNA extraction.</td>
            </tr>
          </table>
        </td>
      </tr>
</table>
    
  </center>
END_HEREDOC
$page->footer();