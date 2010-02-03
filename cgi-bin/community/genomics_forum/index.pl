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
            "http://www.ars.usda.gov/Main/site_main.htm?modecode=19-10-05-00">USDA-ARS
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
              <td>Oct 7, 2005</td>

              <td>G16</td>

              <td>Noah Whitman</td>

              <td>Fast Mapping</td>
            </tr>

            <tr>
              <td>Oct 21, 2005</td>

              <td>Bradfield G16</td>

              <td>Daniel Ripoll</td>

              <td>Protein Structure Prediction</td>
            </tr>

            <tr>
              <td>Nov 4, 2005</td>

              <td>Bradfield G04 (computer room)</td>

              <td>Angela Baldo</td>

              <td>Bioinfo Linux Distros</td>
            </tr>

            <tr>
              <td>Nov 18</td>

              <td>Bradfield G-16, 2pm</td>

              <td>Qui Sun</td>

              <td>Protein Database</td>
            </tr>

            <tr>
              <td>Dec 02</td>

              <td>Bradfield G16</td>

              <td>Peter Bradbury</td>

              <td>Microarray Databases</td>
            </tr>

            <tr>
              <td>Dec 16, 2005</td>

              <td>Bradfield G16</td>

              <td>Naama Menda/Dave Matthews/Pankaj Jaiswal</td>

              <td>Phenotypic Databases: Tomato/rice/wheat</td>
            </tr>

            <tr>
              <td>Jan 27, 2006</td>

              <td>Bradfield G16</td>

              <td>John Binns / Dave Matthews / Amit</td>

              <td>GBrowse</td>
            </tr>

            <tr>
              <td>Feb 10</td>

              <td>TBA</td>

              <td>TBA</td>

              <td>TBA</td>
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
