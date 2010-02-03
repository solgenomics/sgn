use strict;
use CXGN::Page;
my $page=CXGN::Page->new('cosii_markers.html','html2pl converter');
$page->header('Conserved Ortholog Set II (COSII) markers');
print<<END_HEREDOC;

  <center>
    

    <table summary="" width="100\%" cellpadding="0" cellspacing="0"
    border="0">
      <tr>
        <td>
          <center>
            <h3>Conserved Ortholog Set II (COSII) markers</h3>
          </center>

          <p>COSII markers are PCR-based markers developed from a
          set of single-copy conserved orthologous genes (COSII
          genes) in Asterid species. Each COSII gene (representing
          a group of Asterid unigenes) matches only one single-copy
          Arabidopsis gene. In comparison with COS markers reported
          by Fulton et al. (2002), COSII markers/genes have the
          following new properties:</p>

          <ol>
            <li>Multiple EST-assembled unigene databases, tomato,
            potato, pepper and coffee, as well as the Arabidopsis
            CDS database, were screened computationally and the
            method for establishing orthology was more robust.</li>

            <li>Phylogenetic analyses support their classification
            as orthologs.</li>

            <li>They occur as single-copy genes in these
            species.</li>

            <li>Designed "Universal Primers" were able to amplify
            orthologous counterparts (exons and/or introns) from
            other related solanaceous species including those lack
            of sequence data.</li>
          </ol>

          <p>Therefore, this set of COSII genes as well as
          Universal Primers is a powerful tool for establishing a
          syntenic network between Solanaceae and Arabidopsis, and
          for elucidating phylogenies, genome evolution and genome
          organization of Solanaceae. Moreover, one can establish
          similar orthologs sets and Universal Primers for other
          plant families (especially dicots), and connect them with
          COSII genes by the common Arabidopsis orthologs.</p>

          <p>The computational screen for identifying COSII genes
          is described in <a href="/documents/img/cosii.png">this diagram</a>.</p>

          <p>In this section of SGN, you will find sequence
          information of each COSII gene as well as the mapping
          information of those mapped COSII genes (so called COSII
          markers). We\'ve mapped more than 300 COSII markers in
          tomato and will map more in the future, up to at least
          500, and in the meanwhile, these COSII markers will be
          mapped in major solanaceous species (e.g. eggplant,
          pepper, Nicotiana, etc.). All the information in this
          section will be updated as new data are generated, so
          please come back and check from time to time.</p>

          <h4>Universal Primers developed from COSII genes (iUPA
          and eUPA)</h4>

          <p><em>Universal Primers for Asterid species</em> (UPA)
          were designed on the consensus sequence of a COSII
          gene/group, which amplify both exonic and intronic
          regions in most, if not all, solanaceous species and
          related taxa in the Asterid I clade of dicot plant
          species, and which are therefore useful for comparative
          mapping and phylogenetics.</p>

          <p><em>Intronic UPA</em> (iUPA) amplify an intron with a
          short stretch of the flanking exons and hence are useful
          for genome/comparative mapping, and phylogenetics of
          closely related species. Many iUPAs have been tested in
          various solanaceous species as well as coffee, and primer
          sequences, PCR conditions and product sizes are
          available.</p>

          <p><em>Exonic UPA</em>S (eUPA) amplify at least 400bp exonic
          sequences with/without an intervening intron and hence
          are useful for phylogenetics of distantly related
          species. Some eUPAs have been tested in various
          solanaceous species as well as coffee, and primer
          sequences, PCR conditions and product sizes are
          available.</p>

          <h4>How to read COSII marker information pages</h4>

          <p>Arabidopsis CDS is not edited. The unigenes were
          edited based on their alignment with the CDS, by trimming
          the UTRs and correcting sequencing errors. Peptide
          sequence is translated from from edited sequence in frame
          1 (for unigenes) or downloaded from <a href=
          "http://www.arabidopsis.org">TAIR</a> (for Arabidopsis).
          Intron locations of unigenes were predicted from
          alignment with the Arabidopsis CDS, whose intron
          locations were downloaded from <a href=
          "http://www.arabidopsis.org">TAIR</a>. "=====" indicates
          introns from <a href=
          "http://www.arabidopsis.org">TAIR</a> (for Arabidopsis)
          or predicted intron location in the sequence (for
          unigenes).</p>

          <h4>Functional annotation of COSII genes</h4>

          <p>Each of the COSII genes was assigned a functional
          annotation based on the <a href=
          "http://www.arabidopsis.org/info/ontologies/go/">Gene
          Ontology (GO) annotation</a> of the matching Arabidopsis
          gene member.</p>

          <h4>Mapping PCR-based COSII markers in major solanaceous
          species</h4>

          <p>All mapped COSII markers can be found in these
          <a href="/search/markers/markersearch.pl?submit=search&amp;types=COSII&amp;mapped=on">
          marker search results</a>.</p>

          <h4>Complete listing of COSII genes</h4>

          <p>Complete listings of COSII genes and markers can be
          found in our <a href=
          "/search/markers/markersearch.pl?submit=search&amp;types=COSII">marker
          search results</a> or in this <a href="/documents/markers/cosii.xls">.xls
          spreadsheet</a>. The spreadsheet is sometimes more up-to-date than the search results.
          Sequence text files and other associated COSII data can be downloaded from our 
          <a href="ftp://ftp.sgn.cornell.edu/COSII/">FTP site</a>.</p>

          <ol>
            <li><span class="tinytype">Fulton T, van der Hoeven R,
            Eannetta N, Tanksley S (2002). Identification, Analysis
            and Utilization of a Conserved Ortholog Set (COS)
            Markers for Comparative Genomics in Higher Plants. The
            Plant Cell 14: 1457-1467</span></li>

            <li><span class="tinytype">Wu F, Mueller LA, Crouzillat D, Petiard V, Tanksley SD (2006).
Combining Bioinformatics and Phylogenetics to Identify Large Sets of
Single Copy, Orthologous Genes (COSII) for Comparative, Evolutinonary
and Systematics Studies: A Test Case in the Euasterid Plant Clade (2006).
Genetics, 2006 Nov;174(3):1407-20. <a href="http://www.genetics.org/cgi/content/abstract/genetics.106.062455v1">Genetics</a> | <a href="http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?db=PubMed&term=16951058">PubMed</a> | <a href="ftp://ftp.sgn.cornell.edu/COSII/COSII-Genetics-suppl/">[access supplement information on SGN FTP site]</a>
</span></li>
          </ol>
        </td>
      </tr>
    </table>
  </center>
END_HEREDOC
$page->footer();
