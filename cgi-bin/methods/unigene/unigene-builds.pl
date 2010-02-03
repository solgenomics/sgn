use strict;
use CXGN::Page;
my $page=CXGN::Page->new('unigene-builds.html','html2pl converter');
$page->header('SGN Unigene Builds');
print<<END_HEREDOC;

  <center>

    <table summary="" width="720" cellpadding="0" cellspacing="0"
    border="0">
      <tr>
        <td>
          

          <h3>SGN Unigene Builds</h3>

          <p>The Sol Genomics Network unigene builds represent
          "minimally redundant" collections of expressed genes in
          Solanaceous species, constructed from EST/cDNA sequence
          data present in SGN's databases. The unigene set is
          "built" from EST data by assembling together, in contigs,
          EST sequences which are ostensibly fragments of the same
          gene, modulo sequencing errors and allelic variation. In
          builds containing ESTs from more than one species, larger
          variation is allowed to account for anticipated
          evolutionary divergence of orthologus genes.</p>

          <p>SGN's unigene assembly strategy, as well as sequence
          recovery and trimming, is under active research and
          continually refined. New builds are posted when advances
          in the assembly process are made or new input data is
          available.</p>

          <p>The latest builds are posted below. For more
          information on <a href=
          "unigene-methods.pl">methods</a>, click the links below
          next the the build of interest. Please also see our notes
          on <a href="unigene-validation.pl">validation</a> of
          SGN's assembly process and comparison with <a href=
          "http://www.tigr.org/tdb/tgi/">TIGR's tomato gene
          index</a>.</p>
        </td>
      </tr>
      
    </table>
  </center>
END_HEREDOC
$page->footer();