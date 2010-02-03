use strict;
use CXGN::Page;
my $page=CXGN::Page->new('unigene-precluster.html','html2pl converter');
$page->header('Sol Genomics Network');
print<<END_HEREDOC;

  <center>

    <table summary="" width="720" cellpadding="0" cellspacing="0"
    border="0">
      <tr>
        <td>
          

          <h3>Preclustering</h3>

          <p>Preclustering is a technique used to partition the
          input data into groups small enough for the assembly
          program to process. Even on powerful computers, an
          assembler such as CAP3 or PHRAP can not effectively run
          with more than 20,000 input sequences. Either the memory
          requirements are too large or the runtime is unacceptably
          large.</p>

          <p>By preclustering, we reduce the input size into
          disjoint groups of sequences which are not at all similar
          to any of the sequences in other groups. This limits the
          work on the assembler by excluding sequences which are
          obviously not transcripts from the same gene. Thus, the
          assembly program is used to decide (and assembly into
          contigs) the number of unique transcripts in a "cluster"
          of similar ESTs, preclustering is used to partition the
          input set into disjoint clusters of similar sequences
          which are small enough to allow the assembler to run
          efficiently.</p>

          <h3>Transitive Closure Clustering</h3>

          <p>There are many general methods of clustering data. For
          purposes of partitioning data into disjoint sets for
          unigene assembly, we use a simple method which we call
          "transitive closure clustering." The same methodology has
          been described elsewhere as "single-linkage
          clustering."</p>

          <p>Pairwise scores are found for all pairs of sequences.
          If the score for a pair of sequences is higher than some
          given threshold, the pair is considered linked. If A is
          linked to B, and B is linked to C, then A, B, and C are
          clustered together, even if A is not considered linked
          with C. Hence, the linkage relationship is transitive,
          and a cluster is found by finding the transitive closure
          of the linkage relationship.</p>

          <p>In context of unigene assembly, this effectively
          yields disjoint clusters of sequences for which no
          sequence in a given cluster has a detectable coarse
          overlap with any sequence in any other cluster. Thus,
          there is no possibility for contig assembly of two
          sequences which are in different clusters, so the
          exclusion does not in theory alter the outcome of the
          assembly step. Since the preclustering pairwise
          comparisons are much more efficient coarse approximations
          than the assembler's full alignments, the overall runtime
          and resource consumption of the unigene build becomes
          manageable.</p>
        </td>
      </tr>
      
    </table>
  </center>
END_HEREDOC
$page->footer();
