use strict;
use CXGN::Page;
my $page=CXGN::Page->new('openflowerctod.html','html2pl converter');
$page->header('Open Flower Library');
print<<END_HEREDOC;

  <center>
    
    <table summary="" width="720" cellpadding="0" cellspacing="0"
    border="0">
      <tr>
        <td>
          <center>
            <h2>Open Flower Library</h2>
          </center>

          <table summary="" width="100\%" cellspacing="5">
            <tr valign="top">
              <td width="20\%">Library:</td>

              <td>cTOD</td>
            </tr>

            <tr valign="top">
              <td>TIGR ID:</td>

              <td>TFD</td>
            </tr>

            <tr valign="top">
              <td>Authors:</td>

              <td>Rutger van der Hoeven, Julie Bezzerides, and
              Steve Tanksley</td>
            </tr>

            <tr valign="top">
              <td>Date made:</td>

              <td>09/99</td>
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

              <td>developing flower buds and/or flowers</td>
            </tr>

            <tr valign="top">
              <td>Developmental stage:</td>

              <td>anthesis-stage flowers from 4-8 week-old
              plants</td>
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

              <td>1.8 x 10<small><sup>7</sup></small></td>
            </tr>

            <tr valign="top">
              <td>Number mass excised:</td>

              <td>8.5 x 10<small><sup>5</sup></small></td>
            </tr>

            <tr valign="top">
              <td>Average insert length:</td>

              <td>2.3 Kb</td>
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

              <td>Flower buds and flowers were taken from
              greenhouse plants (4-8 weeks old, TA496). They were
              immediately frozen in liquid nitrogen and then
              size-separated while remaining frozen.</td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
    
  </center>
END_HEREDOC
$page->footer();