use strict;
use CXGN::Page;
my $page=CXGN::Page->new('index.html','html2pl converter');
$page->header('L. pennellii Introgression lines (ILs)');
print<<END_HEREDOC;

  <center>  

    <table summary="" width="720" cellpadding="0" cellspacing="0"
    border="0">
      <tr>
        <td>
          <h3 align="center"><em>L. pennellii</em> Introgression
          lines (ILs)</h3>

          <p>
          Congenic lines that differ in a single defined chromosome
          segment are useful for the study of complex phenotypes,
          as they allow isolation of the effect of a particular
          quantitative trait locus (QTL) from those of the entire
          genome. We developed a set of Lycopersicon
          pennellii-derived introgression lines (ILs) that together
          cover the entire genome in the background of L.
          esculentum Var. M82. This resource is very powerful for
          the study of genes affecting complex phenotypes.</p>

          <p>The second generation IL population is composed of 76
          ILs (the 50 original lines and 26 new ILs), each
          containing a single introgression from L. pennellii (LA
          716) in the genetic background of the processing tomato
          variety M82. The IL map was connected to the
          high-resolution F2 map composed of 1500 markers. This was
          achieved by probing all of the specific chromosome lines
          with the RFLP markers from the framework F2 map. A total
          of 614 markers were probed and the ends of the
          introgressions were mapped with the resolution of the F2
          map.</p>

          <p>The L. pennellii introgressed segments appear as solid
          bars in which the boundary edge of each segment is
          indicated by inclusive (+) and exclusive (-) RFLP
          markers. All ILs are homozygous for the introgressed
          segment except for part of IL8-1 (dashed line). Bins are
          designated by the chromosome number followed by a capital
          letter and indicate a unique area of IL overlap and
          singularity; it is important to note that some of the bin
          designations might change as more probing is done.
          Molecular and genetic markers are indicated to the right
          of each chromosome and the genetic distances (in cM)
          according to Tanksley et al. (1992) are indicated to the
          left.</p>

          <p>Seed of the second generation ILs is presently being
          increased by <a href=
          "http://tgrc.ucdavis.edu">The C.M. Rick Tomato Genetics Resource
          Center, University of California Davis</a>
          and the ILs were assigned accession numbers LA4028 -
          LA4103.</p>

          <ul>
            <li><a href="chr1.pl" target="_blank">Chromosome
            1</a></li>

            <li><a href="chr2.pl" target="_blank">Chromosome
            2</a></li>

            <li><a href="chr3.pl" target="_blank">Chromosome
            3</a></li>

            <li><a href="chr4.pl" target="_blank">Chromosome
            4</a></li>

            <li><a href="chr5.pl" target="_blank">Chromosome
            5</a></li>

            <li><a href="chr6.pl" target="_blank">Chromosome
            6</a></li>

            <li><a href="chr7.pl" target="_blank">Chromosome
            7</a></li>

            <li><a href="chr8.pl" target="_blank">Chromosome
            8</a></li>

            <li><a href="chr9.pl" target="_blank">Chromosome
            9</a></li>

            <li><a href="chr10.pl" target="_blank">Chromosome
            10</a></li>

            <li><a href="chr11.pl" target="_blank">Chromosome
            11</a></li>

            <li><a href="chr12.pl" target="_blank">Chromosome
            12</a></li>
          </ul>

          <p><u>IL References</u></p>

          <p>Eshed Y, M Abu-Abied, Y Saranga, D Zamir (1992)
          Lycopersicon esculentum lines containing small
          overlapping introgressions from L. pennellii. Theor Appl
          Genet 83:1027-1034</p>

          <p>Eshed Y and D. Zamir (1994) Introgressions from
          Lycopersicon pennellii can improve the soluble-solids
          yield of tomato hybrids. Theor Appl Genet 88:891-897.</p>

          <p>Eshed Y and D. Zamir (1994) A genomic library of
          Lycopersicon pennellii in L. esculentum: A tool for fine
          mapping of genes. Euphytica 79:175-179.</p>

          <p>Eshed Y and D Zamir (1995) An introgression line
          population of Lycopersicon pennellii in the cultivated
          tomato enables the identification and fine mapping of
          yield associated QTL. Genetics 141:1147-1162.</p>

          <p>Eshed Y and D Zamir (1996) Less than additive
          epistatic interactions of QTL in tomato. Genetics
          143:1807-1817.</p>

          <p>Eshed Y, G Gera and D Zamir (1996) A genome-wide
          search for wild-species alleles that increase
          horticultural yield of processing tomatoes Theor Appl
          Genet 93: 877-886.</p>

          <p>Zamir D and Y Eshed (1998) Tomato genetics and
          breeding using nearly isogenic introgression lines
          derived from wild species. in: Molecular Dissection of
          Complex Traits. ed. AH Paterson. CRC Press Inc. Fl.
          207-217.</p>

          <p>Qilin P, Yong-Sheng L, Budai-Hadrian O, Sela M,
          Carmel-Goren L, Zamir D and R Fluhr (2000) Comparative
          genetics of NBS-LRR resistance gene homologues in the
          genomes of two dicotyledons: tomato and Arabidopsis.
          Genetics 155: 309-322.</p>

          <p>Fridman E, Pleban T and D Zamir (2000) A recombination
          hotspot delimits a wild species QTL for tomato sugar
          content to 484-bp within an invertase gene. Proc Natl
          Acad Sci USA 97: 4718-4723.</p>
        </td>
      </tr>
    </table>
    
  </center>
END_HEREDOC
$page->footer();
