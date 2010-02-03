use strict;
use CXGN::Page;
my $page=CXGN::Page->new('tomatoredripe.html','html2pl converter');
$page->header('cLEN/TRR - Tomato red ripe');
print<<END_HEREDOC;

  <center>
    
    <table summary="" width="720" cellpadding="0" cellspacing="0"
    border="0">
      <tr>
        <td>
          <center>
            <h2>cLEN/TRR - Tomato red ripe</h2>
          </center>

          <table summary="" width="100\%" cellspacing="5">
            <tr valign="top">
              <td width="20\%">Library:</td>
              <td>cLEN</td>
            </tr>

            <tr valign="top">
              <td>TIGR ID:</td>
              <td>TRR</td>
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
              <td>ripe/over-ripe</td>
            </tr>

            <tr valign="top">
              <td>Vector:</td>
              <td>pBluescript SK(-)</td>
            </tr>

            <tr valign="top">
              <td>Host:</td>
              <td>SOLR</td>
            </tr>

            <tr valign="top">
              <td>Primary pfu:</td>
              <td>1.5 x 106<small><sup>6</sup></small></td>
            </tr>

            <tr valign="top">
              <td>Number mass excised:</td>
              <td>2.0 x 105<small><sup>6</sup></small></td>
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
              <td>M13F-R</td>
            </tr>

            <tr valign="top">
              <td>Comments:</td>
              <td>Fruit were tagged at the "breaker" stage (first sign of lycopene accumulation  
              on the blossom end of the fruit) and harvested 7 days post-breaker (fully red-ripe), 
              10 days post breaker, and 20 days post-breaker (over-ripe).  20 day fruit which 
              showed external or internal signs of pathogenesis were discarded.   Fruit were cut 
              in half and the seeds and locules were discarded prior to freezing the pericarp.</td>
            </tr>

          </table>
        <br />
        <center><em>NOTE:   9/14/99 cLEN- 84 total sequences, 10 dupes, 88.1\% unique, with 40 unknowns.<br />
        No junk was found (chloroplast, mitochondria, or E. coli).</em></center>
        </td>
      </tr>
    </table>
    
  </center>
END_HEREDOC
$page->footer();
