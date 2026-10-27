use strict;
use SGN::I18N ();
use CatalystX::GlobalContext qw( $c );
my SGN::I18N $ui_i18n = SGN::I18N::translate($c);
use CXGN::Page;
my $page=CXGN::Page->new('cosii_markers.html','html2pl converter');
$page->header(SGN::I18N::translate($ui_i18n, "genotype.marker.conserved_ortholog_set_ii_cosii_markers", "Conserved Ortholog Set II (COSII) markers", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}));
print(qq~
  <center>
    

    <table summary="" width="100\%" cellpadding="0" cellspacing="0"
    border="0">
      <tr>
        <td>
          <center>
            <h3>~ . SGN::I18N::translate($ui_i18n, "genotype.marker.conserved_ortholog_set_ii_cosii_markers", "Conserved Ortholog Set II (COSII) markers", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~</h3>
          </center>

          <p>~ . SGN::I18N::translate($ui_i18n, "genotype.marker.cosii_markers_are_pcr_based_markers_developed_from_a_set_of_single", "COSII markers are PCR-based markers developed from a\n          set of single-copy conserved orthologous genes (COSII\n          genes) in Asterid species. Each COSII gene (representing\n          a group of Asterid unigenes) matches only one single-copy\n          Arabidopsis gene. In comparison with COS markers reported\n          by Fulton et al. (2002), COSII markers/genes have the\n          following new properties:", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~</p>

          <ol>
            <li>~ . SGN::I18N::translate($ui_i18n, "genotype.marker.multiple_est_assembled_unigene_databases_tomato_potato_pepper_and_coffee_as_well", "Multiple EST-assembled unigene databases, tomato,\n            potato, pepper and coffee, as well as the Arabidopsis\n            CDS database, were screened computationally and the\n            method for establishing orthology was more robust.", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~</li>

            <li>~ . SGN::I18N::translate($ui_i18n, "genotype.marker.phylogenetic_analyses_support_their_classification_as_orthologs", "Phylogenetic analyses support their classification\n            as orthologs.", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~</li>

            <li>~ . SGN::I18N::translate($ui_i18n, "genotype.marker.they_occur_as_single_copy_genes_in_these_species", "They occur as single-copy genes in these\n            species.", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~</li>

            <li>~ . SGN::I18N::translate($ui_i18n, "genotype.marker.designed_universal_primers_were_able_to_amplify_orthologous_counterparts_exons_and_or", "Designed \"Universal Primers\" were able to amplify\n            orthologous counterparts (exons and/or introns) from\n            other related solanaceous species including those lack\n            of sequence data.", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~</li>
          </ol>

          <p>~ . SGN::I18N::translate($ui_i18n, "genotype.marker.therefore_this_set_of_cosii_genes_as_well_as_universal_primers_is", "Therefore, this set of COSII genes as well as\n          Universal Primers is a powerful tool for establishing a\n          syntenic network between Solanaceae and Arabidopsis, and\n          for elucidating phylogenies, genome evolution and genome\n          organization of Solanaceae. Moreover, one can establish\n          similar orthologs sets and Universal Primers for other\n          plant families (especially dicots), and connect them with\n          COSII genes by the common Arabidopsis orthologs.", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~</p>

          <p>~ . SGN::I18N::translate($ui_i18n, "genotype.marker.the_computational_screen_for_identifying_cosii_genes_is_described_in", "The computational screen for identifying COSII genes\n          is described in", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~ <a href="/documents/img/cosii.png">~ . SGN::I18N::translate($ui_i18n, "genotype.marker.this_diagram", "this diagram", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~</a>.</p>

          <p>~ . SGN::I18N::translate($ui_i18n, "genotype.marker.in_this_section_of_sgn_you_will_find_sequence_information_of_each", "In this section of SGN, you will find sequence\n          information of each COSII gene as well as the mapping\n          information of those mapped COSII genes (so called COSII\n          markers). We've mapped more than 300 COSII markers in\n          tomato and will map more in the future, up to at least\n          500, and in the meanwhile, these COSII markers will be\n          mapped in major solanaceous species (e.g. eggplant,\n          pepper, Nicotiana, etc.). All the information in this\n          section will be updated as new data are generated, so\n          please come back and check from time to time.", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~</p>

          <h4>~ . SGN::I18N::translate($ui_i18n, "genotype.marker.universal_primers_developed_from_cosii_genes_iupa_and_eupa", "Universal Primers developed from COSII genes (iUPA\n          and eUPA)", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~</h4>

          <p><em>~ . SGN::I18N::translate($ui_i18n, "genotype.marker.universal_primers_for_asterid_species", "Universal Primers for Asterid species", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~</em> ~ . SGN::I18N::translate($ui_i18n, "genotype.marker.upa_were_designed_on_the_consensus_sequence_of_a_cosii_gene_group", "(UPA)\n          were designed on the consensus sequence of a COSII\n          gene/group, which amplify both exonic and intronic\n          regions in most, if not all, solanaceous species and\n          related taxa in the Asterid I clade of dicot plant\n          species, and which are therefore useful for comparative\n          mapping and phylogenetics.", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~</p>

          <p><em>~ . SGN::I18N::translate($ui_i18n, "marker.detail.cosii.intronic_upa", "Intronic UPA", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~</em> ~ . SGN::I18N::translate($ui_i18n, "genotype.marker.iupa_amplify_an_intron_with_a_short_stretch_of_the_flanking_exons", "(iUPA) amplify an intron with a\n          short stretch of the flanking exons and hence are useful\n          for genome/comparative mapping, and phylogenetics of\n          closely related species. Many iUPAs have been tested in\n          various solanaceous species as well as coffee, and primer\n          sequences, PCR conditions and product sizes are\n          available.", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~</p>

          <p><em>~ . SGN::I18N::translate($ui_i18n, "marker.detail.cosii.exonic_upa", "Exonic UPA", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~</em>~ . SGN::I18N::translate($ui_i18n, "genotype.marker.s_eupa_amplify_at_least_400bp_exonic_sequences_with_without_an_intervening", "S (eUPA) amplify at least 400bp exonic\n          sequences with/without an intervening intron and hence\n          are useful for phylogenetics of distantly related\n          species. Some eUPAs have been tested in various\n          solanaceous species as well as coffee, and primer\n          sequences, PCR conditions and product sizes are\n          available.", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~</p>

          <h4>~ . SGN::I18N::translate($ui_i18n, "genotype.marker.how_to_read_cosii_marker_information_pages", "How to read COSII marker information pages", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~</h4>

          <p>~ . SGN::I18N::translate($ui_i18n, "genotype.marker.arabidopsis_cds_is_not_edited_the_unigenes_were_edited_based_on_their", "Arabidopsis CDS is not edited. The unigenes were\n          edited based on their alignment with the CDS, by trimming\n          the UTRs and correcting sequencing errors. Peptide\n          sequence is translated from from edited sequence in frame\n          1 (for unigenes) or downloaded from", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~ <a href=
          "http://www.arabidopsis.org">TAIR</a> ~ . SGN::I18N::translate($ui_i18n, "genotype.marker.for_arabidopsis_intron_locations_of_unigenes_were_predicted_from_alignment_with_the", "(for Arabidopsis).\n          Intron locations of unigenes were predicted from\n          alignment with the Arabidopsis CDS, whose intron\n          locations were downloaded from", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~ <a href=
          "http://www.arabidopsis.org">TAIR</a>. "=====" ~ . SGN::I18N::translate($ui_i18n, "genotype.marker.indicates_introns_from", "indicates\n          introns from", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~ <a href=
          "http://www.arabidopsis.org">TAIR</a> ~ . SGN::I18N::translate($ui_i18n, "genotype.marker.for_arabidopsis_or_predicted_intron_location_in_the_sequence_for_unigenes", "(for Arabidopsis)\n          or predicted intron location in the sequence (for\n          unigenes).", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~</p>

          <h4>~ . SGN::I18N::translate($ui_i18n, "genotype.marker.functional_annotation_of_cosii_genes", "Functional annotation of COSII genes", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~</h4>

          <p>~ . SGN::I18N::translate($ui_i18n, "genotype.marker.each_of_the_cosii_genes_was_assigned_a_functional_annotation_based_on", "Each of the COSII genes was assigned a functional\n          annotation based on the", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~ <a href=
          "http://www.arabidopsis.org/info/ontologies/go/">~ . SGN::I18N::translate($ui_i18n, "genotype.marker.gene_ontology_go_annotation", "Gene\n          Ontology (GO) annotation", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~</a> ~ . SGN::I18N::translate($ui_i18n, "genotype.marker.of_the_matching_arabidopsis_gene_member", "of the matching Arabidopsis\n          gene member.", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~</p>

          <h4>~ . SGN::I18N::translate($ui_i18n, "genotype.marker.mapping_pcr_based_cosii_markers_in_major_solanaceous_species", "Mapping PCR-based COSII markers in major solanaceous\n          species", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~</h4>

          <p>~ . SGN::I18N::translate($ui_i18n, "genotype.marker.all_mapped_cosii_markers_can_be_found_in_these", "All mapped COSII markers can be found in these", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~
          <a href="/search/markers/markersearch.pl?submit=search&amp;types=COSII&amp;mapped=on">
          ~ . SGN::I18N::translate($ui_i18n, "genotype.marker.marker_search_results_5e6933", "marker search results", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~</a>.</p>

          <h4>~ . SGN::I18N::translate($ui_i18n, "genotype.marker.complete_listing_of_cosii_genes", "Complete listing of COSII genes", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~</h4>

          <p>~ . SGN::I18N::translate($ui_i18n, "genotype.marker.complete_listings_of_cosii_genes_and_markers_can_be_found_in_our", "Complete listings of COSII genes and markers can be\n          found in our", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~ <a href=
          "/search/markers/markersearch.pl?submit=search&amp;types=COSII">~ . SGN::I18N::translate($ui_i18n, "genotype.marker.marker_search_results_00f96d", "marker\n          search results", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~</a> ~ . SGN::I18N::translate($ui_i18n, "genotype.marker.or_in_this", "or in this", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~ <a href="/documents/markers/cosii.xls">~ . SGN::I18N::translate($ui_i18n, "genotype.marker.xls_spreadsheet", ".xls\n          spreadsheet", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~</a>~ . SGN::I18N::translate($ui_i18n, "genotype.marker.the_spreadsheet_is_sometimes_more_up_to_date_than_the_search_results", ". The spreadsheet is sometimes more up-to-date than the search results.\n          Sequence text files and other associated COSII data can be downloaded from our", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~\x20
          <a href="ftp://ftp.sgn.cornell.edu/COSII/">~ . SGN::I18N::translate($ui_i18n, "genotype.marker.ftp_site", "FTP site", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~</a>.</p>

          <ol>
            <li><span class="tinytype">~ . SGN::I18N::translate($ui_i18n, "genotype.marker.fulton_t_van_der_hoeven_r_eannetta_n_tanksley_s_2002_identification", "Fulton T, van der Hoeven R,\n            Eannetta N, Tanksley S (2002). Identification, Analysis\n            and Utilization of a Conserved Ortholog Set (COS)\n            Markers for Comparative Genomics in Higher Plants. The\n            Plant Cell 14: 1457-1467", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~</span></li>

            <li><span class="tinytype">~ . SGN::I18N::translate($ui_i18n, "genotype.marker.wu_f_mueller_la_crouzillat_d_petiard_v_tanksley_sd_2006_combining", "Wu F, Mueller LA, Crouzillat D, Petiard V, Tanksley SD (2006).\nCombining Bioinformatics and Phylogenetics to Identify Large Sets of\nSingle Copy, Orthologous Genes (COSII) for Comparative, Evolutinonary\nand Systematics Studies: A Test Case in the Euasterid Plant Clade (2006).\nGenetics, 2006 Nov;174(3):1407-20.", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~ <a href="http://www.genetics.org/cgi/content/abstract/genetics.106.062455v1">~ . SGN::I18N::translate($ui_i18n, "genotype.marker.genetics", "Genetics", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~</a> | <a href="http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?db=PubMed&term=16951058">~ . SGN::I18N::translate($ui_i18n, "genotype.marker.pubmed", "PubMed", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~</a> | <a href="ftp://ftp.sgn.cornell.edu/COSII/COSII-Genetics-suppl/">~ . SGN::I18N::translate($ui_i18n, "genotype.marker.access_supplement_information_on_sgn_ftp_site", "[access supplement information on SGN FTP site]", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~</a>
</span></li>
          </ol>
        </td>
      </tr>
    </table>
  </center>
~);
$page->footer();
