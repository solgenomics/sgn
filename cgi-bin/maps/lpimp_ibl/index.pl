use strict;
use CXGN::Page;
my $page=CXGN::Page->new("index.html","html2pl converter");
$page->header("Lycopersicon Pimpinellifolium Inbred Backcross
  Lines.");
print<<END_HEREDOC;

  <center>
    

    <table summary="" width="720" cellpadding="0" cellspacing="0"
    border="0">
      <tr>
        <td>
          <center>
            <h2>Lycopersicon pimpinellifolium Inbred Backcross
            Lines (IBLs)</h2>
          </center>

          <p>A set of 196 inbred-backcross lines (IBLs) (BC2F6) was
          generated from a population which had been developed as
          part of an AB-QTL strategy to identify useful alleles
          from a small red fruited wild relative of tomato,
          Lycopersicon pimpinellifolium LA1589 (Grandillo and
          Tanksley, 1996; Tanksley et al. 1996). The population has
          been mapped with 127 markers covering the tomato genome
          (Doganlar et al 2002). Each of the IBL contains more than
          one introgressed region from L. pimpinellifolium in the
          L. esculentum cv. E6203 background. The IBLs are a
          permanent mapping resource that can be used by tomato
          geneticists and breeders for mapping, gene discovery and
          breeding.</p>

          <p>A consensus map was constructed from the three studies
          that used populations derived from the original L.
          esculentum cv. E6203 x L. pimpinellifolium LA1589 cross
          Grandillo and Tanksley, 1996; Tanksley et al. 1996,
          Doganlar et al. 2002). The map contains 151 markers
          covering the entire tomato genome, cM values are based on
          the map of Tanksley et al. (1996).</p>

          <p>To improve the utility of the IBL population, a subset
          of 100 lines giving the most uniform genome coverage and
          map resolution was selected using a randomized greedy
          algorithm as implemented in the software package MapPop
          (Vision et al. 2001). The seed for the selected subset of
          100 IBLs will be available through the <a href=
          "http://tgrc.ucdavis.edu">Tomato Genetics
          Resource Center</a>,
          TGRC, Davis, CA).</p>

          <h2>Map of Lycopersicon Pimpinellifolium LA1589</h2>

          <p>The following links display the individual chromosomes
          of this map.<br />
          Click on the names of individual markers to connect to
          that marker's entry in the SGN database.</p>

          <ul>
            <li><a href="chromosome1.pl">Chromosome1</a></li>

            <li><a href="chromosome2.pl">Chromosome2</a></li>

            <li><a href="chromosome3.pl">Chromosome3</a></li>

            <li><a href="chromosome4.pl">Chromosome4</a></li>

            <li><a href="chromosome5.pl">Chromosome5</a></li>

            <li><a href="chromosome6.pl">Chromosome6</a></li>

            <li><a href="chromosome7.pl">Chromosome7</a></li>

            <li><a href="chromosome8.pl">Chromosome8</a></li>

            <li><a href="chromosome9.pl">Chromosome9</a></li>

            <li><a href="chromosome10.pl">Chromosome10</a></li>

            <li><a href="chromosome11.pl">Chromosome11</a></li>

            <li><a href="chromosome12.pl">Chromosome12</a></li>
          </ul>

          <h3>IBL References</h3>

          <p>Doganlar S, Frary A, Ku HM and Tanksley SD (submitted)
          <em>Mapping Quantitative Trait Loci in Inbred Backcross
          Lines of Lycopersicon pimpinellifolium (LA1589).</em></p>

          <p>Tanksley SD, Grandillo S, Fulton TM, Zamir D, Eshed Y,
          Petiard V, Lopez J and Beck-Bunn T (1996) <em>Advanced
          backcross QTL analysis in a cross between an elite
          processing line of tomato and its wild relative L.
          pimpinellifolium.</em> Theor Appl Genet 92: 213-224.</p>

          <p>Grandillo S and Tanksley SD (1996) <em>QTL analysis of
          horticultural traits differentiating the cultivated
          tomato from the closely related species Lycopersicon
          pimpinellifolium.</em> Theor Appl Genet 92: 935-951.</p>

          <p>Vision TJ, Brown DG, Shmoys DB, Durret, R.T and
          Tanksley SD (2000) <em>Selective mapping: A strategy for
          optimizing the costruction of high-density linkage
          maps.</em> Genetics 155: 407-420.</p>
        </td>
      </tr>
    </table>
    
  </center>
END_HEREDOC
$page->footer();
