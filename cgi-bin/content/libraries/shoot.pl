use strict;
use CXGN::Page;
my $page=CXGN::Page->new('shoot.html','html2pl converter');
$page->header('Shoot Library');
print<<END_HEREDOC;

  <center>
    
    <table summary="" width="720" cellpadding="0" cellspacing="0"
    border="0">
      <tr>
        <td>
          <center>
            <h2>Shoot Library</h2>
          </center>

          <table summary="" width="100\%" cellspacing="5">
            <tr valign="top">
              <td width="20\%">Library:</td>

              <td>cLEB</td>
            </tr>

            <tr valign="top">
              <td>TIGR ID:</td>

              <td>TSH</td>
            </tr>

            <tr valign="top">
              <td>Cer ID:</td>

              <td>cC-esle</td>
            </tr>

            <tr valign="top">
              <td>Authors:</td>

              <td>Rutger van der Hoeven and S. D. Tanksley</td>
            </tr>

            <tr valign="top">
              <td>Date made:</td>

              <td>02/98</td>
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

              <td>vegetative shoots including meristems and small
              expanding leaves</td>
            </tr>

            <tr valign="top">
              <td>Developmental stage:</td>

              <td>8 week-old plants</td>
            </tr>

            <tr valign="top">
              <td>Vector:</td>

              <td>pBK_CMV</td>
            </tr>

            <tr valign="top">
              <td>Host:</td>

              <td>XLOLR</td>
            </tr>

            <tr valign="top">
              <td>Primary pfu:</td>

              <td>1.4 x 10<small><sup>6</sup></small></td>
            </tr>

            <tr valign="top">
              <td>Number mass excised:</td>

              <td>1.4 x 10<small><sup>6</sup></small></td>
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

              <td>kanamycin</td>
            </tr>

            <tr valign="top">
              <td>Primers:</td>

              <td>T3 and T7</td>
            </tr>

            <tr valign="top">
              <td>Comments:</td>

              <td>This oligo-dT primed cDNA library was made from
              tomato vegetative shoots including meristems and
              small expanding leaves of 8 week-old plants. The
              plants were grown with and 18 hour photoperiod under
              400 W sodium lights and a temperature regime of 18C
              at night and 28C during the day. Plants were freely
              watered and fertilized.<br />
              The library consists of 1.4 x
              10<small><sup>6</sup></small> independent
              clones.<br />
              The first three plates were screened for CAB/rbcL in
              the Tanksley lab.<br />
              Plates 4-6 were sequenced bidirectionally by
              Cer.<br />
              Plates 1-6 were sequenced by Novartis.<br />
              Plates 1-26 were sent to TIGR.</td>
            </tr>
          </table>
        </td>
      </tr>
</table>
    
  </center>
END_HEREDOC
$page->footer();