use strict;
use CXGN::Page;
my $page=CXGN::Page->new('unigene-validation.html','html2pl converter');
$page->header('Assembly Process Validation');
print<<END_HEREDOC;

  <center>

    <table summary="" width="720" cellpadding="0" cellspacing="0"
    border="0">
      <tr>
        <td>
          

          <h3>Assembly Process Validation</h3>

          <p>In an effort to validate SGN's unigene assembly
          process, we have attempted to compare our combined
          Lycopersicon build with <a href=
          "http://www.tigr.org/tdb/tgi/">TIGR's tomato gene
          index</a>. These comparisons are based on the latest TIGR
          tomato gene index available at the time, published on
          June 1, 2002. It is noted here that neither SGN's unigene
          nor TIGR's gene index builds are supported by
          experimental evidence, and thus both remain
          approximations of the true nature of the genomes
          represented.</p>

          <p>Due to differences in input data, such as EST
          sequences not common to both builds, and differences in
          chromatogram processing, direct comparison of the two
          builds exposes mostly "noisy" differences that lead to
          inconclusive results in attempts to characterize or
          manually curate the observed differences.</p>

          <p>Thus, the data presented below serves to indicate the
          observed similarity between builds and demonstrate that
          neither build differs significantly from the other
          indicating a suspicious assembly process. See <a href=
          "unigene-methods.pl">this page</a> for a discussion on
          the assembly process.</p>

          <table summary="" border="1">
            <tr>
              <td></td>
              <td>SGN Lycopersicon combined build #1</td>
              <td>TIGR Tomato Gene Index</td>
            </tr>

            <tr>
              <td>Total # of output sequences</td>
              <td>31278</td>
              <td>31102</td>
            </tr>

            <tr>
              <td>Contigs (TCs)</td>
              <td>16200</td>
              <td>15211</td>
            </tr>

            <tr>
              <td>Singlets</td>
              <td>15078</td>
              <td>15891</td>
            </tr>

            <tr>
              <td>Censored inputs</td>
              <td>14310</td>
              <td>11054</td>
            </tr>

            <tr>
              <td>Exclusive Contigs</td>
              <td>0</td>
              <td>0</td>
            </tr>

            <tr>
              <td>Exclusive Singlets</td>
              <td>2044</td>
              <td>707</td>
            </tr>
          </table>

          <p><strong>Contigs</strong> are unigenes or gene index
          sequences which are composed of the consensus of an
          alignment of two or more EST sequences.
          <strong>Singlets</strong> are sequences which have been
          determined not to overlap sufficiently with any other
          sequence in the input data set. <strong>Censored
          inputs</strong> are input sequences which are not common
          to both sets. <strong>Exclusive contigs</strong> are
          contigs composed entirely of input sequences which are
          not common to both builds. <strong>Exclusive
          singlets</strong> are singlets found only in the
          indicated build. Since no exclusive contigs were found,
          this indicates that every contig in SGN's build, and
          every TC in TIGR's tomato gene index is represented by at
          least one common input sequence for both
          builds.</p>

          <p>After normalizing the unigene membership data to
          compare solely in terms of input sequences common to both
          builds, we find:</p>

          <table summary="" border="1">
            <tr>
              <td></td>
              <td>SGN</td>
              <td>TIGR</td>
            </tr>

            <tr>
              <td>Total # of output sequences</td>
              <td>29234</td>
              <td>30395</td>
            </tr>

            <tr>
              <td>Contigs (TCs)</td>
              <td>15034</td>
              <td>14432</td>
            </tr>

            <tr>
              <td>Singlets</td>
              <td>14200</td>
              <td>15963</td>
            </tr>
          </table><br />

          <p>Since the input sequences have been normalized to a
          common set at this point, and output sequences which are
          resultant of exclusively non-common sequences are removed
          from consideration, this data suggests that SGN's
          assembly process is slightly more lenient, allowing the
          assembly of more sequences in to contigs. We find here
          that 74.5\% of SGN unigene build is identical to TIGR's
          gene index. Most of the remaining differences turn out to
          be cases where a contig in SGN is represented in TIGR as
          one contig and one or more singlets, or vice versa.
          Investigation of these cases is consistent with the claim
          above, that SGN's build is biased slightly toward
          inclusion of sequences into contigs. Although above it
          indicates that 2044 singlets are exclusive to SGN, the
          number of singlets has not dropped by 2044 becuase some
          contigs have become singlets after censoring non-common
          input sequences from consideration. The same is true for
          TIGR's build.</p>

          <p>Since the Lycopersicon combined build and TIGR's
          tomato gene index contain data from 3 different
          Lycopersicon species, its useful to look at the number of
          unigenes specific to <em>Lycopersicon hirsutum</em> and
          <em>Lycopersicon pennellii</em>, which ought to show
          substantial allelic variation with the species dominantly
          represented in the input data, <em>Lycopersicon
          esculentum</em>.</p>

          <table summary="" border="1">
            <tr>
              <td></td>
              <td>SGN</td>
              <td>TIGR</td>
            </tr>

            <tr>
              <td><em>hirsutum</em> specific contigs</td>
              <td>94</td>
              <td>157</td>
            </tr>

            <tr>
              <td><em>pennellii</em> specific contigs</td>
              <td>147</td>
              <td>113</td>
            </tr>

            <tr>
              <td><em>hirsutum/esculentum</em> mixed contigs</td>
              <td>1908</td>
              <td>1863</td>
            </tr>

            <tr>
              <td><em>pennellii/esculentum</em> mixed contigs</td>
              <td>6552</td>
              <td>6624</td>
            </tr>
          </table>

          <p>From this data, both TIGR and SGN's assembly processes
          are allowing the contig assembly of sequences which
          contain small evolutionary divergence as well as
          sequencing errors. It is not clear from this data whether
          or not orthologs are specifically isolated in the
          assembly. Neither assembly process at this time contains
          specific steps for isolating orthologs from paralogs in
          cross-species assemblies. This question can not be
          completely settled <em>in silico</em>.</p>

          <p>In conclusion, we find that the insight gained from
          comparing TIGR's gene index with SGN's Lycopersicon
          combined unigene build indicates that each procedure
          confirms the predictions of the other in most cases.
          Differences are observed, but most are attributable to
          differences in inputs to the processes. The reader is
          reminded that the above data attempts to characterize the
          differences in outputs of two separate processes, while
          <strong>not</strong> being able to control the
          differences in inputs. Thus, the conclusive power of the
          analysis is limited.</p>
        </td>
      </tr>
      
    </table>
  </center>
END_HEREDOC
$page->footer();