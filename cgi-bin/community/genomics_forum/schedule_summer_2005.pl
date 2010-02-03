use strict;
use CXGN::Page;
my $page=CXGN::Page->new('index.html','html2pl converter');
$page->header('Cornell Genomics Discussion Group');
print<<END_HEREDOC;

  <center>
   
    <table summary="" width="800">
      <tr>
        <td>
          <a href="http://www.cornell.edu/"><img src=
          "/documents/img/logo_cu_65.png" alt="Cornell University" width="65"
          height="65" border="0" /></a>

          <h3>Cornell Genomics Forum</h3>The Cornell Genomics Forum
          is an open forum for issues in computational biology,
          bioinformatics, biological databases and genomics at
          Cornell. It is currently formed by members of the
          following units, but is open to everybody:

          <ul>
            <li><a href="http://cbsu.tc.cornell.edu/">Computational
            Biology Service Unit</a></li>

            <li><a href="http://www.Gramene.org">Gramene</a></li>

            <li><a href="http://www.cs.cornell.edu/golan/">Dept.
            Computer Sciences</a></li>

            <li><a href="http://www.sgn.cornell.edu">SGN</a></li>

            <li><a href=
            "http://www.GrainGenes.org">GrainGenes</a></li>

            <li><a href=
            "http://www.ars-grin.gov/gen/bioinformaticshome2.html">USDA-ARS
            Plant Genetic Resources Unit</a></li>
          </ul>

          <h3>Mailing List</h3>If you would like to subscribe to
          the mailing list, please go to the <a href=
          "http://rubisco.sgn.cornell.edu/mailman/listinfo/cornell-genomics-forum/">
          list subscription form</a>.

          <h3>Meeting Schedule</h3>Meetings are usually at 2pm
          unless otherwise noted.<br />
          <br />

          <table summary="" border="1" cellpadding="5">
            <tr>
              <td><i>Date</i></td>

              <td><i>Location</i></td>

              <td><i>Speaker</i></td>

              <td><i>Topic</i></td>
            </tr>

            <tr>
              <td>Dec 3</td>

              <td>Mann Lib</td>

              <td>Medha Devare</td>

              <td>Genomics Miner</td>
            </tr>

            <tr>
              <td>Dec 17</td>

              <td>Bradfield G16</td>

              <td>Robert Buels</td>

              <td>LaTex and Reference Managers</td>
            </tr>

            <tr>
              <td>Jan 7</td>

              <td>Biotech</td>

              <td>Dallas Kroon, Peter Bradbury, Ed Buckler</td>

              <td>Assocation Analysis</td>
            </tr>

            <tr>
              <td>Jan 28</td>

              <td>Bradfield G-16, 2pm</td>

              <td>Immanuel Yap</td>

              <td>Consensus Maps</td>
            </tr>

            <tr>
              <td>Feb 11</td>

              <td>Bradfield G16</td>

              <td>Dave Matthews</td>

              <td>Genome Browser [<a href=
              "/static_content/community/genomics_forum/slides/GenomeBrowsers.ppt">ppt</a>]</td>
            </tr>

            <tr>
              <td>Feb 18</td>

              <td>Bradfield G16</td>

              <td>Qi Sun</td>

              <td>Gene Finders and introduction to HMMs</td>
            </tr>

            <tr>
              <td>Mar 4</td>

              <td>TBA</td>

              <td>Lukas Mueller</td>

              <td>MOBY</td>
            </tr>

            <tr>
              <td>Mar 18</td>

              <td>TBA</td>

              <td>Beth Skwarecki</td>

              <td><a href=
              "/static_content/community/genomics_forum/slides/repeat_analysis.pdf">
              Repeat Finding</a></td>
            </tr>

            <tr>
              <td>Mar 23</td>

              <td>&nbsp;</td>

              <td>Travis Banks</td>

              <td>Wheat Bioinformatics in Agriculture Agrifood
              Canada</td>
            </tr>

            <tr>
              <td></td>

              <td>TBA</td>

              <td>Saleh Elmohamed</td>

              <td>Biochemical Pathways</td>
            </tr>

            <tr>
              <td>Apr 15</td>

              <td>TBA</td>

              <td>TBA</td>

              <td>BioPerl</td>
            </tr>

            <tr>
              <td></td>

              <td>TBA</td>

              <td>Pankaj Jaiswal</td>

              <td>Ontologies</td>
            </tr>

            <tr>
              <td>May 13</td>

              <td>USDA Geneva, PGRU conference room</td>

              <td>Angela Baldo</td>

              <td>Phylogenetics</td>
            </tr>

            <tr>
              <td>May 27</td>

              <td>TBA</td>

              <td>Joss Rose</td>

              <td>Proteomics</td>
            </tr>

            <tr>
              <td></td>

              <td>TBA</td>

              <td></td>

              <td>NCBI Tools/toolkit</td>
            </tr>

            <tr>
              <td></td>

              <td>TBA</td>

              <td></td>

              <td>Overview of Bioinfo Journals</td>
            </tr>
          </table><br />
          <br />
          <hr />
          Please contact <a href=
          "mailto:lam87\@cornell.edu">Lukas Mueller</a> for comments and
          corrections.
        </td>
      </tr>
    </table>

    
  </center>
END_HEREDOC
$page->footer();
