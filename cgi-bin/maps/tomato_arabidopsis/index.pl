use strict;
use CXGN::Page;
my $page=CXGN::Page->new('index.html','html2pl converter');
$page->header('Tomato-Arabidopsis Synteny Map');
print<<END_HEREDOC;

  <center>
    

    <table summary="" width="720" cellpadding="0" cellspacing="0"
    border="0">
      <tr>
        <td>
          <h3 align="center">Tomato-Arabidopsis Synteny Map</h3>

          <p>
          The following links display the molecular marker linkage
          maps of the tomato genome. When you click on any
          chromosome, you will see two maps of each chromosome. The
          first map (left side of image) is the high density
          molecular marker map published by Tanksley et al. (1992).
          On the right is a new map (Fulton et al, in prep) based
          on <a href="/markers/cos_markers.pl">COS markers</a>.
          Connecting the two maps (dashed lines) are common markers
          on both maps. Because of the large number of markers on
          each chromosome, it will not be possible to read the
          individual marker names. To see an enlarged region of
          each chromosome, click on the individual BINS which will
          be highlighted at the right most part of the screen. This
          will take you to an enlarged map of that section of the
          chromosome in which the marker names will be readable. To
          link to the sequence for any marker, click on the
          corresponding marker name in the list to the right of the
          map.</p>

          <p>Both maps (high density RFLP map and COS marker map)
          are based on F2 populations from the interspecific cross
          L. esculentum x L. pennellii. Details of the high density
          RLFP mapping population can be found in Tanksley et al.
          (1992). The COS marker map is based on 80 F2 individuals.
          Markers to the right of solid hash marks were ordered at
          a LOD &gt; 3; markers next to dashed hash marks are
          ordered at a LOD &gt; 2 but &lt; 3; remaining markers are
          given in the most likely interval (&lt; LOD 3). Markers
          next to a vertical bar cosegregate. The COS marker map
          development is part of an ongoing project for determining
          the syntenic relationship between the Arabidopsis and
          tomato genomes. The map will be updated periodically as
          new markers are added and new interactive features added
          for making syntenic comparisons. Potato and eggplant
          comparative maps will also be added soon.</p>

          <p>If you have any questions regarding the maps, please
          email us at <a href=
          "mailto:sgn-feedback\@sgn.cornell.edu">sgn-feedback\@sgn.cornell.edu</a>.</p>

          <p>Tanksley et al. 1992. High density molecular linkage
          maps of the tomato and potato genomes. Genetics
          132:1141-1160.</p>

          <ul>
            <li><a href="chr1_split.pl" target=
            "_blank">Chromosome 1</a></li>

            <li><a href="chr2_split.pl" target=
            "_blank">Chromosome 2</a></li>

            <li><a href="chr3_split.pl" target=
            "_blank">Chromosome 3</a></li>

            <li><a href="chr4_split.pl" target=
            "_blank">Chromosome 4</a></li>

            <li><a href="chr5_split.pl" target=
            "_blank">Chromosome 5</a></li>

            <li><a href="chr6_split.pl" target=
            "_blank">Chromosome 6</a></li>

            <li><a href="chr7_split.pl" target=
            "_blank">Chromosome 7</a></li>

            <li><a href="chr8_split.pl" target=
            "_blank">Chromosome 8</a></li>

            <li><a href="chr9_split.pl" target=
            "_blank">Chromosome 9</a></li>

            <li><a href="chr10_split.pl" target=
            "_blank">Chromosome 10</a></li>

            <li><a href="chr11_split.pl" target=
            "_blank">Chromosome 11</a></li>

            <li><a href="chr12_split.pl" target=
            "_blank">Chromosome 12</a></li>
          </ul>
        </td>
      </tr>
    </table>
    
  </center>
END_HEREDOC
$page->footer();