use strict;
use CXGN::Page;
my $page=CXGN::Page->new('unigene-process-2.html','html2pl converter');
$page->header('SGN Assembly Process Version 2');
print<<END_HEREDOC;

  <center>

    <table summary="" width="720" cellpadding="0" cellspacing="0"
    border="0">
      <tr>
        <td>
          

          <h3>SGN Assembly Process Version 2</h3>

          <p>ESTs are preclustered using a custom developed tool to
          coarsely identify strong sequence overlaps. (<a href=
          "unigene-precluster.pl">Why precluster?</a>) This
          produces a set of pairwise scores to be used in <a href=
          "unigene-precluster.pl">transitive closure
          clustering</a>, implemented as a graph algorithm using
          depth-first search.</p>

          <p>In graph theoretic terms, the sequences are considered
          nodes of a graph. Undirected edges between nodes indicate
          a detected overlap between the sequences represented by
          the nodes. Edges may be weighted, indicating the strength
          of the overlap. The connected components of the graph are
          discovered by depth first search, yielding a depth first
          "forest" of sequence clusters.</p>

          <p>Articulation points in the graph are discovered by
          analyzing the "tree edge" and "back edge" classification
          of edges from depth first search. Nodes identified as
          articulation points are potentially chimeric sequences
          and their overlaps are analyzed further for adjacent but
          distinct homology regions. Sequences with adjacent but
          distinct homology regions are considered likely to be
          chimeric and are discarded. Since the sequence is an
          articulation point, this will break the cluster into two
          separate clusters, as expected.</p>

          <p>The resulting clusters are supplied as input, with
          base calling quality scores, to the <a href=
          "http://genome.cs.mtu.edu/cap/cap3.html">CAP3 assembly
          program</a>. We have used the following parameters (for
          Lycopersicon combined build):</p>

          <table summary="" border="1">
            <tr>
              <td>CAP3 option</td>
              <td>default value</td>
              <td>value used</td>
              <td>description</td>
            </tr>

            <tr>
              <td>-e</td>
              <td>30</td>
              <td>5000</td>
              <td>"extra" number of observed differences</td>
            </tr>

            <tr>
              <td>-s</td>
              <td>900</td>
              <td>401</td>
              <td>minimum similarity score for an overlap</td>
            </tr>

            <tr>
              <td>-p</td>
              <td>75</td>
              <td>90</td>
              <td>percent identity required for overlap</td>
            </tr>

            <tr>
              <td>-d</td>
              <td>200</td>
              <td>10000</td>
              <td>maximum allowed sum of quality scores of
              mismatched bases in overlaps</td>
            </tr>

            <tr>
              <td>-b</td>
              <td>20</td>
              <td>60</td>
              <td>quality score threshold for scoring a base
              mismatch</td>
            </tr>
          </table>

          <p>Please see the documentation for CAP3 for further
          information on other parameters (which are left to
          default values) and complete descriptions of the
          above.</p>

          <p>The point here is to restrict or eliminate the effect
          of the "-e, -s, -d, and -b" options, leaving "-p" in the
          driver's seat. This makes the decisions to assemble or
          not assemble easily interpretable. The other parameters
          are attempts to introduce more sensitive discriminations
          than just percent identity of a detected overlap.
          However, our experience has shown the effects of these
          parameters (at default or similar settings) yield
          arbitrary assemblies that dominate over the most
          intuitive measure, the percent identity in an overlap.
          Preliminary experiments indicate that "-p" is the most
          useful option for controlling CAP3's behavior, but its
          effects are only noticeable when the other overlap
          assessment features (options) are effectively
          disabled.</p>
        </td>
      </tr>
      
    </table>
  </center>
END_HEREDOC
$page->footer();
