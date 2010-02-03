use strict;
use CXGN::Page;
my $page=CXGN::Page->new('ovary.html','html2pl converter');
$page->header('Ovary Library');
print<<END_HEREDOC;

  <center>
    
    <table summary="" width="720" cellpadding="0" cellspacing="0"
    border="0">
      <tr>
        <td>
          <center>
            <h2>Ovary Library</h2>
          </center>

          <table summary="" width="100\%" cellspacing="5">
            <tr valign="top">
              <td width="20\%">Library:</td>

              <td>cLED</td>
            </tr>

            <tr valign="top">
              <td>TIGR ID:</td>

              <td>TOV</td>
            </tr>

            <tr valign="top">
              <td>Authors:</td>

              <td>Alcala, Vrebalov, White, and Giovannoni</td>
            </tr>

            <tr valign="top">
              <td>Date made:</td>

              <td>11/98</td>
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

              <td>carpel</td>
            </tr>

            <tr valign="top">
              <td>Developmental stage:</td>

              <td>5 days pre-anthesis to 5 days post-anthesis</td>
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

              <td>3.0 x 10<small><sup>5</sup></small></td>
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

              <td>ampicillin</td>
            </tr>

            <tr valign="top">
              <td>Primers:</td>

              <td>M13F and M13R</td>
            </tr>

            <tr valign="top">
              <td>Comments:</td>

              <td>Construction of an early carpel (pre-anthesis
              through 5 days post-anthesis) cDNA library has been
              completed. Approximately one millions unamplified
              clones were generated and 300,000 were used in mass
              excision. Forty 384-well plates (15,360 clones) were
              picked. On hundred random clones were miniprepped and
              PCR'd with an average insert size of 1.5 Kb (range
              0.8-2.5 Kb). XhoI and EcoRI digests of the same 100
              clones were performed. Only two clones were
              identified with internal XhoI and EcoRI sites, which
              may be indicative of chimeric ligation, though double
              digestion suggested they were not chimeras (the
              internal sites are both at least several hundred bp
              internal, but not adjacent). 48 of the clones were
              sequenced.Flowers were collected from about 25 TA496
              plants every two days for one month. Flowers were
              approximately 5 days pre-anthesis (based on tagging)
              through 5 days post-anthesis (based on tagging and
              appearance). At 5 dpa, the carpels were about 0.5 cm
              in diameter. Flowers were collected at five different
              stages: 1)5 days pre-anthesis, 2) anthesis (based on
              partial sepal separation and anther tube swelling, 3)
              5 dpa, 4) intermediate between 1 and 2, and 5)
              intermediate between 2 and 3. About 0.5 grams of
              tissue was collected from hundreds of flowers in the
              early stages, while about 10 grams of tissue was
              collected from about 10 stage-5 carpels. 0.5 to 1
              gram per stage was combined and used for RNA
              isolation. The carpels included ovules and embryos.
              The anthers from the first three stages and some of
              the fourth stage were collected for an anther
              library.</td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
    
  </center>
END_HEREDOC
$page->footer();