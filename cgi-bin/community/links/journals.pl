use strict;
use CXGN::Page;
my $page=CXGN::Page->new('journals.html','html2pl converter');
$page->header('Online Journal Links');
print<<END_HEREDOC;

  <center>
    

    <table summary="" width="720" cellpadding="0" cellspacing="0"
    border="0">
      <tr>
        <td>
          <h4>Journals on the web</h4>

          Please note that some journals may require a subscription. Some Universities
          have licenses that allow access to certain journals from
          any computer on that University's domain.

          <p>If you'd like to see other journals listed, please
          email <a href=	
          "mailto:sgn-feedback\@sgn.cornell.edu">sgn-feedback\@sgn.cornell.edu</a>.</p>

          <ul>

            <li>Cornell University Library Gateway - 



<a href="http://encompass.library.cornell.edu/cgi-bin/fa.cgi?check=1">Find Electronic Resources</a></li>

            <li>Mann Library's <a href=
            "http://www.mannlib.cornell.edu/reference/shortcuts.html#index">Most Commonly Used Online Indexes</a></li>

            <li><a href=
            "http://www.cell.com">Cell</a></li>

            <li><a href=
            "http://www.molecule.org">Molecular Cell</a></li>

            <li><a href=
            "http://www.fasebj.org">The FASEB journal</a></li>

            <li><a href=
            "http://www.genetics.org/">Genetics</a></li>

            <li><a href=
            "http://nar.oxfordjournals.org">Nucleic Acids Research</a></li>

            <li><a href=
            "http://www.genome.org/">Genome Research</a></li>

            <li><a href=
            "http://www.sciencemag.org/">Science</a></li>

            <li><a href=
            "http://www.amjbot.org/">American Journal of Botany</a></li>

            <li><a href=
            "http://ajpcell.physiology.org/">American Journal of Physiology - Cell Physiology</a></li>

            <li><a href=
            "http://www.annualreviews.org/">Annual Reviews</a></li>

            <li><a href=
            "http://bmj.bmjjournals.com/">BMJ</a></li>

            <li><a href=
            "http://www.nature.com/emboj/index.html">The EMBO Journal</a></li>

            <li><a href=
            "http://www.genesdev.org/">Genes &amp; Development</a></li>

            <li><a href=
            "http://www.jbc.org/">The Journal of Biological Chemistry</a>/</li>

            <li><a href=
            "http://www.jcb.org/">The Journal of Cell Biology</a></li>

            <li><a href=
            "http://www.plantcell.org/">The Plant Cell</a></li>

            <li><a href=
            "http://www.plantphysiol.org/">Plant Physiology</a></li>

            <li><a href=
            "http://www.pnas.org/">Proceedings of the National Academy of Sciences (PNAS)</a></li>

            <li><a href=
            "http://www.elsevier.com/wps/find/journaldescription.cws_home/506090/description">Mechanisms of Development</a></li>

            <li><a href=
            "http://bioinformatics.oxfordjournals.org/">Bioinformatics</a></li>

            <li><a href=
            "http://www.socgenmicrobiol.org.uk/">Society for General Microbiology</a></li>

            <li><a href=
            "http://jvi.asm.org/">Journal of Virology</a></li>

            <li>There are a number of Biomedical and Life Sciences journals at <a href="http://www.springerlink.com/">SpringerLink</a>.<br /></li>

          </ul>

        </td>
      </tr>
    </table>
    
  </center>
END_HEREDOC
$page->footer();
