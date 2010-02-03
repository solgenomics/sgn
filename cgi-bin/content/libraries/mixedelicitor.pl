use strict;
use CXGN::Page;
my $page=CXGN::Page->new('mixedelicitor.html','html2pl converter');
$page->header('Library of Leaf Tissue Under Mixed Elicitor
            Stress');
print<<END_HEREDOC;

  <center>
    
    <table summary="" width="720" cellpadding="0" cellspacing="0"
    border="0">
      <tr>
        <td>
          <center>
            <h2>Library of Leaf Tissue Under Mixed Elicitor
            Stress</h2>
          </center>

          <table summary="" width="100\%" cellspacing="5">
            <tr valign="top">
              <td width="20\%">Library:</td>

              <td>cLET</td>
            </tr>

            <tr valign="top">
              <td>TIGR ID:</td>

              <td>TME</td>
            </tr>

            <tr valign="top">
              <td>Authors:</td>

              <td>Tishina Subrahmanyam and Gregory Martin</td>
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

              <td>Rio Grande PtoR</td>
            </tr>

            <tr valign="top">
              <td>Tissue:</td>

              <td>leaf</td>
            </tr>

            <tr valign="top">
              <td>Developmental stage:</td>

              <td>4-6 week old plants</td>
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

              <td>1.0 x 10<small><sup>6</sup></small></td>
            </tr>

            <tr valign="top">
              <td>Number mass excised:</td>

              <td>1.0 x 10<small><sup>8</sup></small></td>
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

              <td>The EcoRI site was destroyed during cloning. Use
              any enzyme to the left of it along with XhoI to cut
              out the insert. Also note that the library was
              amplified prior to mass excision. 11,520 clones were
              picked into 30 384-well plates. In the following
              table, BTH stands for the chemical benzothiadiazole,
              which induces SAR in many dicot species. EIX is
              ethylene inducing xylanase from the fungus
              <em>Trichoderma</em>. JA is jasmonic acid.</td>
            </tr>
          </table>

          <table summary="" width="100\%" border="1" cellspacing="5"
          cellpadding="5">
            <tr>
              <td><strong>Biotic/abiotic elicitor</strong></td>
              <td><strong>Method of treatment</strong></td>
              <td><strong>Concentration</strong></td>
              <td><strong>Time points (hours)</strong></td>
              <td><strong>Has the treatment worked?</strong></td>
            </tr>

            <tr>
              <td>INA (2,6 dichloroisonicotinic acid)</td>
              <td>(1)foliar spray application (2)Petiole immersion
              - treat in solution for 30 minutes, then transfer to
              water</td>
              <td>0.5 mM</td>
              <td>4, 24</td>
              <td>RNA gel blot analysis - probe with osmotin</td>
            </tr>

            <tr>
              <td>BTH</td>

              <td>(1)foliar spray application (2)Petiole immersion
              - treat in solution for 30 minutes, then transfer to
              water</td>

              <td>1.5 mM</td>

              <td>4, 24</td>

              <td>RNA gel blot analysis - probe with basic
              glucanase</td>
            </tr>

            <tr>
              <td>JA</td>

              <td>petiole immersion in closed chamber
              incubation</td>

              <td>100 uM</td>

              <td>4, 12</td>

              <td>RNA gel blot analysis - probe with pin gene</td>
            </tr>

            <tr>
              <td>ethylene</td>

              <td>closed chamber incubation</td>

              <td>50 ppm of gas injected into chamber</td>

              <td>2, 12</td>

              <td>plants showed epinasty - leaf curl and bending
              downwards</td>
            </tr>

            <tr>
              <td>fenthion</td>

              <td>vacuum infiltration</td>

              <td>0.001\% Silwet</td>

              <td>4, 12</td>

              <td>fenthion cell death observed 11 hours after
              infiltration</td>
            </tr>

            <tr>
              <td>EIX</td>

              <td>vacuum infiltration</td>

              <td>1 ug/ml solution</td>

              <td>8, 48</td>

              <td>small lesions visible 48 hours after
              infiltration</td>
            </tr>

            <tr>
              <td>okadaic acid</td>

              <td>transpiration stream for 45 minutes, then
              transfer to dd water</td>

              <td>1 uM</td>

              <td>4, 12</td>

              <td>wilting</td>
            </tr>

            <tr>
              <td>systemin</td>

              <td>petiole immersion, then transfer to dd water</td>

              <td>90 ul of 1 nM solution in sodium phosphate
              buffer</td>

              <td>4, 12</td>

              <td>RNA gel blot analysis - probe with pin gene</td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
    
  </center>
END_HEREDOC
$page->footer();