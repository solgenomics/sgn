use strict;
use CXGN::Page;
my $page=CXGN::Page->new('unigene-methods.html','html2pl converter');
$page->header('Unigene Assembly Process Overview');
print<<END_HEREDOC;

  <center>

    <table summary="" width="720" cellpadding="0" cellspacing="0"
    border="0">
      <tr>
        <td>
          

          <h3>Unigene Assembly Process Overview</h3>

          <p>The "unigene problem" consists of two fundamental
          questions:</p>

          <ol>
            <li>Are these two sequences from the same
            gene/transcript?</li>

            <li>Where are the sequencing errors in this
            sequence?</li>
          </ol>

          <p>The ability to answer either question correctly and
          consistently enables an algorithm for precise assembly of
          a unigene build from EST sequences. It is plain to see
          that if (1) is yes, then answers for (2) are known
          (errors are where the sequence differs, barring allelic
          variation). As well, if (2) were determined, then (1) is
          easily settled by examining an alignment of the sequences
          for true differences in the overlapping region.</p>

          <p>Constructing a unigene build must attempt to solve
          both questions simultaneously. This is different from
          genomic DNA assembly, for the following important
          reasons:</p>

          <ol>
            <li><p>EST sequencing methodology does not yield an
            expectation of stochastic oversampling of each DNA
            base. In genomic sequencing, with 8X expected coverage
            for example, answering (2) above becomes easier as
            there are several observations for each base once
            proper alignment is determined.</p></li>

            <li><p>The optimal outcome of assembling a BAC is exactly
            one contig. The implied answer to question (1) above is
            then always yes: all subclones belong in the same
            contig.</p></li>
          </ol>

          <p>There are no widely used, freely available assemblers
          for EST data, so we do the next best thing: use a genomic
          assembler such as <a href=
          "http://www.phrap.org/">phrap</a> (P. Green) or <a href=
          "http://genome.cs.mtu.edu/cap/cap3.html">CAP3</a> (X.
          Huang [1]). CAP3 is typically preferred
          for EST assembly (see [2] for a
          discussion), being less aggressive at splitting apart
          contigs.</p>

          <p>In general deciding whether or not to assemble two
          sequences together is a very easy question as long as the
          observed differences between the sequences are
          significant. When the observed differences in two
          sequences approaches the rate of sequencing error,
          determining whether or not two different genes are
          represented by the sequences becomes theoretically
          impossible without collecting more data. Since error
          rates in a collection of sequences appear as a
          distribution, the result is a range of observed
          differences where actual differences and sequencing
          errors make assembly decisions arbitrary.</p>

          <p>The likely result is the over-representation or
          under-representation of gene families which contain
          recently diverged paralogs. Additionally, if the organism
          sequenced is heterozygous at many loci with significant
          allelic variation, similar results may occur.</p>

          <p>This may be controlled by selection of threshold
          parameters governing the assembly process, but there is
          no "one size fits all" threshold that accurately decides
          all cases. Particular choices of thresholds may either
          (a) promote false detection of distinct but similar genes
          (b) promote false detection of alleles (by assembling
          close paralogs together) or (c) do both (neutral choice
          of parameters). For SGN's assembly, we have decided to
          proceed with option (b), to attempt to minimize the
          number of false isolations of unique
          transcripts.</p>

          <p>Future versions of SGN's unigene build process will
          include the option for the user to inspect an assembly's
          multiple sequence alignment (MSA) as well as view the
          major alternatives incorporated in any given
          assembly.</p>
          <hr />

          <p>References:</p>

          <ol>
            <li>Huang, X. and Madan, A. (1999) CAP3: A DNA Sequence
            Assembly Program. Genome Research, 9:
            868-877</li>

            <li>Liang Feng, et. al. (2000) <a href="http://www.tigr.org/tdb/tgi/publications/NAR_Assembly.pdf">An optimized
            protocol for analysis of EST sequences</a> Nucleic
            Acids Research 28, 3657-3665</li>
          </ol>
        </td>
      </tr>
      
    </table>
  </center>
END_HEREDOC
$page->footer();
