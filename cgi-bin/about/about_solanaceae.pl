use strict;
use CXGN::Page;
my $page=CXGN::Page->new('about_solanaceae.html','html2pl converter');
$page->header('About The Solanaceae family');
print<<END_HEREDOC;

  <center>
      

    <table summary="" width="720" cellpadding="0" cellspacing="0"
    border="0">
      <tr>
        <td>
          <center>
            <h2>About the Solanaceae Family</h2>
          </center>
        </td>
      </tr>

      <tr>
        <td>
          <center>
            <img src="/documents/img/solanaceae-image-small.jpg" border="0"
            alt="types of solanaceae" />
          </center>

<p>The Solanaceae, also called nightshades,
          comprise more than 3000 species many of which evolved in
          the Andean/Amazonian regions of South America in habitats
          that vary dramatically and include rain forests that
          receive more than 3 meters of rainfall annually to
          deserts with virtually no rainfall and high mountains
          with regular snowfall and subfreezing temperatures.</p>

          <p>The center of diversity of the Solanaceae is near the
          equator and thus species were undisturbed by the ice ages
          and have had time to accumulate adaptive genetic
          variation for extreme ecological niches. The Solanaceae
          are also the third most important plant taxon
          economically and the most valuable in terms of vegetable
          crops, and are the most variable of crops species in
          terms of agricultural utility, as it includes the
          tuber-bearing potato, a number of fruit-bearing
          vegetables (tomato, eggplant, peppers), ornamental plants
          (petunias, Nicotiana), plants with edible leaves (Solanum
          aethiopicum, S. macrocarpon) and medicinal plants (eg.
          Datura, Capsicum).</p>

          <p>Solanaceaous crops have been subjected to intensive
          human selection, allowing their use as models to study
          the evolutionary interface between plants and people. The
          ancient mode of Solanaceae evolution, coupled with an
          exceptionally high level of conservation of genome
          organization at the macro and micro levels make the
          family a model to explore the basis of phenotypic
          diversity and adaptation to natural and agricultural
          environments.</p>

          <p>Some Solanaceae plants are important model systems for
          biology; these include tomato for fruit ripening and
          plant defense, tobacco for plant defense, and petunia for
          the biology of anthocyanin pigments.</p>

          <p>Recently, the phylogenetic classification of the
          Solanaceae has been <a href=
          "solanum_nomenclature.pl">revised</a>. The genus
          Lycopersicon was re-integrated into the Solanum genus, as
          had been the case in Linnaeus' classification.</p>

          <p>Today, the <a href=
          "/solanaceae-project/index.pl">International SOL project</a>
          attempts to study the basis of diversity and adaptation
          in the Solanaceae as a model for biology. One of the
          cornerstones of the SOL project is the sequencing of the
          complete euchromatic region of the tomato genome.</p>

          <h4>Solanaceae phylogenetic tree</h4>

<p>Below is an overview
          of the phylogeny of the Solanaceae (incl. coffee), kindly
          provided by Feinan Wu, based on Bohs and Olmstead,
          (1997).</p>

          <center>
            <img src="/documents/img/SOL_tree.png" alt=
            "phylogeny of the Solanaceae" />
          </center>

          <h4>Further documents</h4>

          <ul>
            <li><a href="solanum_nomenclature.pl">An overview of
            changes in the Solanum nomenclature</a>. Kindly
            provided by Prof Sandra Knapp of the Natural History
            Museum, London, UK.</li>
            <li>Links to other Solanaceae resources are provided on
            our <a href=
            "/community/links/related_sites.pl">Solanaceae
            links</a> page.</li>
	    <li>An analysis of <a href="/misc/codon_usage/codon_usage.pl">codon usage</a> for Tomato and potato including codon usuage tables.</li>
          </ul>

          <h4>References</h4>

<p>Bohs L., Olmstead R. G. (1997)
          Phylogenetic relationships in Solanum (Solanaceae) based
          on ndhF sequences. Syst. Bot. 22: 5-17.</p>

          
          </td>
      </tr>
    </table>
  </center>
END_HEREDOC
$page->footer();