use strict;
use CXGN::Page;
my $page=CXGN::Page->new('genefinding.html','html2pl converter');
$page->header('Gene Finding Links');
print<<END_HEREDOC;

  <center>
    

    <table summary="" width="720" cellpadding="0" cellspacing="0"
    border="0">
      <tr>
        <td>
          <h4>Genefinding tools</h4>

          <ul>
            <li><a href=
            "http://www.ncbi.nlm.nih.gov/gorf/gorf.html">NCBI ORF Finder</a></li>

            <li><a href=
            "http://watson.nih.go.jp/~jun/cgi-bin/frameplot.pl">Frameplot</a></li>

            <li><a href=
            "http://rulai.cshl.org/tools/genefinder/">Genefinder</a></li>

            <li><a href=
            "http://www.cs.jhu.edu/~salzberg/announce-oc1.html">Oblique Classifier 1 (OC1)</a></li>

            <li><a href=
            "http://www.bioinformatics.org/JaMBW/3/1/5/index.html">ORFseeker</a></li>

            <li><a href=
            "http://www-hto.usc.edu/software/procrustes/wwwserv.html">
            PROCRUSTES</a></li>

            <li><a href=
            "http://www.itb.cnr.it/sun/webgene/">WebGene</a></li>
          </ul>

          <h4>Primer Design</h4>

          <ul>
            <li><a href="http://frodo.wi.mit.edu/">
            Primer3</a></li>

	    <li><a href="http://bibiserv.techfak.uni-bielefeld.de/genefisher/">GeneFisher</a></li>

	    <li><a href="http://www.cybergene.se/primerdesign/">GeneWalker</a></li>

	    <li><a href="http://seq.yeastgenome.org/cgi-bin/web-primer">Web Primer</a></li>




	    <li><a href="http://blocks.fhcrc.org/blocks/codehop.html">CODEHOP</a></li>

	    <li><a href="http://www.premierbiosoft.com/netprimer/netprlaunch/netprlaunch.html">NetPrimer</a></li>

	    <li><a href="http://ihg.gsf.de/ihg/ExonPrimer.html">ExonPrimer</a></li>

	    <li><a href="http://bioinformatics.org/primerx/">PrimerX</a></li>

	    <li><a href="http://www.cbs.dtu.dk/services/RevTrans/">RevTrans</a></li>

	    <li><a href="http://www.autoprime.de/">AutoPrime</a></li>

	    <li><a href="http://www.snpbox.org/">SNPbox</a></li>

	    <li><a href="http://www.umsl.edu/services/kellogg/primaclade.html">Primaclade</a></li>

	    <li><a href="http://cancer-seqbase.uchicago.edu/primers.html">Choosing Primers for sequencing</a></li>

	    <li><a href="http://seqcore.brcf.med.umich.edu/doc/dnaseq/primers.html">Design of Primers for Automated 
            Sequencing</a></li>

	    <li><a href="http://www.primerdesign.co.uk/"> Primer Design Workshop</a></li>
          </ul>

          <h4>Promoter Predictions</h4>


          <ul>
            <li><a href=
            "http://thr.cit.nih.gov/molbio/proscan/">Proscan</a></li>
          </ul>
        </td>
      </tr>
    </table>
    
  </center>
END_HEREDOC
$page->footer();
