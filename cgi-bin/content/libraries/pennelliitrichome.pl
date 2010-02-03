use strict;
use CXGN::Page;
my $page=CXGN::Page->new('pennelliitrichome.html','html2pl converter');
$page->header('_Lycopersicon pennellii_ Trichome Library');
print<<END_HEREDOC;

  <center>
    
    <table summary="" width="720" cellpadding="0" cellspacing="0"
    border="0">
      <tr>
        <td>
          <center>
            <h2><em>Lycopersicon pennellii</em> Trichome Library</h2>
          </center>

          <table summary="" width="100\%" cellspacing="5">
            <tr valign="top">
              <td width="20\%">Library:</td>

              <td>cLPT</td>
            </tr>

            <tr valign="top">
              <td>TIGR ID:</td>

              <td>TPT</td>
            </tr>

            <tr valign="top">
              <td>Authors:</td>

              <td>Rutger van der Hoeven and Steve Tanksley</td>
            </tr>

            <tr valign="top">
              <td>Date made:</td>

              <td>06/99</td>
            </tr>

            <tr valign="top">
              <td>Species:</td>

              <td><em>Lycopersicon pennellii</em></td>
            </tr>

            <tr valign="top">
              <td>Accession:</td>

              <td>LA716</td>
            </tr>

            <tr valign="top">
              <td>Tissue:</td>

              <td>general collection of all trichome types</td>
            </tr>

            <tr valign="top">
              <td>Developmental stage:</td>

              <td>trichomes from leaves of 4-8 week old plants</td>
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

              <td>2.5 x 10<small><sup>7</sup></small></td>
            </tr>

            <tr valign="top">
              <td>Number mass excised:</td>

              <td>1.5 x 10<small><sup>6</sup></small></td>
            </tr>

            <tr valign="top">
              <td>Average insert length:</td>

              <td>1.2 Kb</td>
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

              <td>Leaves of various stages were shaken in liquid
              nitrogen, shearing off trichomes. this procedure
              yielded a mixture of cells which is highly enriched
              in trichome. Note that it likely will contain minor
              contaminations of other types of leaf cells.</td>
            </tr>
          </table>
        </td>
      </tr>
</table>
    
  </center>
END_HEREDOC
$page->footer();