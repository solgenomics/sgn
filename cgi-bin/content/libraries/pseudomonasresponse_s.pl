use strict;
use CXGN::Page;
my $page=CXGN::Page->new('pseudomonasresponse_s.html','html2pl converter');
$page->header('Library of Leaves From _Pseudomonas_
            Susceptible Variety');
print<<END_HEREDOC;

  <center>
    
    <table summary="" width="720" cellpadding="0" cellspacing="0"
    border="0">
      <tr>
        <td>
          <center>
            <h2>Library of Leaves From <em>Pseudomonas</em>
            Susceptible Variety</h2>
          </center>

          <table summary="" width="100\%" cellspacing="5">
            <tr valign="top">
              <td width="20\%">Library:</td>

              <td>cLES</td>
            </tr>

            <tr valign="top">
              <td>TIGR ID:</td>

              <td>TPS</td>
            </tr>

            <tr valign="top">
              <td>Authors:</td>

              <td>Xiaohua He, Mark D'Ascenzo, Jamie Lyman, and Greg
              Martin</td>
            </tr>

            <tr valign="top">
              <td>Date made:</td>

              <td>01/99</td>
            </tr>

            <tr valign="top">
              <td>Species:</td>

              <td><em>Lycopersicon esculentum</em></td>
            </tr>

            <tr valign="top">
              <td>Accession:</td>

              <td>tomato line R11-13 (Rio Grande x Money
              Maker)</td>
            </tr>

            <tr valign="top">
              <td>Resistance:</td>

              <td>tomato line is susceptible to <em>Pseudomonas
              syringae</em> pv. tomato strain T1 that expresses the
              avrPto gene</td>
            </tr>

            <tr valign="top">
              <td>Tissue:</td>

              <td>leaf</td>
            </tr>

            <tr valign="top">
              <td>Developmental stage:</td>

              <td>4 week old plants</td>
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

              <td>1.0 x 10<small><sup>7</sup></small></td>
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

              <td>For this library four-week-old plants were
              inoculated with the Pst(avrPto) strain and the leaves
              were harvested. Two plants were used for each
              time-point as follows. High inoculation level:
              10<small><sup>8</sup></small> cfumL of Pst(avrPto).
              Equal amounts of leaves were harvested at 0, 2, 4, 6,
              and 8 hours after inoculation. Low inoculation level:
              10<small><sup>5</sup></small> cfumL of Pst(avrPto).
              Equal amounts of leaves were harvested at 0, 12, 24,
              36, and 48 hours after inoculation. High bacterial
              titre gives no HR on R11-12, but results in disease
              symptoms beginning at about 48 hours after
              inoculation. Low bacterial titre gives no HR on
              R11-12, but results in disease symptoms beginning at
              about 48 hours after inoculation. Keeping leaves from
              each line separate, equal amounts of leaves from each
              time-point were pooled and used to extract polyA RNA
              using Promega's polyATract mRNA isolation system.
              Stratagene's Zap-cDNA synthesis kit was used to
              prepare cDNA. The cDNA was cloned into Uni-ZAP XR
              vector using the EcoRI site at the 5' end and the
              XhoI site at the 3' end. When a sample of each
              library was plated on NZY agar plates containing IPTG
              and X-gal, the white:blue colony ratio was about
              100:1. After mass excision, twenty-five clones from
              each library were picked randomly and characterized.
              All 50 clones contained inserts with sizes ranging
              from 0.5 Kb to more than 3 Kb (avg=1 Kb). The 5' ends
              of 14 random clones were sequenced (7 from each
              library). The EcoRI site was altered/missing in 11 of
              the clones. We expect the R11-12 library will contain
              cDNAs corresponding to genes that are induced by the
              hypersensitive response and during "field"
              resistance. The R11-13 library is expected to contain
              cDNAs corresponding to genes that are induced during
              the disease susceptibility response. NOTE: 09/99 10\%
              of clones in the cLES sequences are found to have a
              reversed orientation (3' EcoRI).</td>
            </tr>
          </table>
        </td>
      </tr>
</table>
    
  </center>
END_HEREDOC
$page->footer();