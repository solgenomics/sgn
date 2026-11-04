use strict;
use SGN::I18N ();
use CatalystX::GlobalContext qw( $c );
my SGN::I18N $ui_i18n = SGN::I18N::translate($c);
use CXGN::Page;
my $page=CXGN::Page->new('cos_markers.html','html2pl converter');
$page->header(SGN::I18N::translate($ui_i18n, "genotype.marker.conserved_ortholog_set_cos_markers", "Conserved Ortholog Set (COS) markers", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}));
print(qq~
  <center>
    

    <table summary="" width="720" cellpadding="0" cellspacing="0"
    border="0">
      <tr>
        <td>
          <center>
            <h3>~ . SGN::I18N::translate($ui_i18n, "genotype.marker.conserved_ortholog_set_cos_markers", "Conserved Ortholog Set (COS) markers", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~</h3>
          </center>

          <p>~ . SGN::I18N::translate($ui_i18n, "genotype.marker.we_have_used_a_computational_method_to_screen_the_tomato_est_database", "We have used a computational method to screen the\n          tomato EST database against the arabidopsis genome\n          sequence in order to find a set of highly conserved,\n          single copy genes which can be used as markers for\n          comparative mapping between the tomato and arabidopsis\n          genomes. Currently we have identified approximately 1000\n          of these Conserved Ortholog Set (COS) markers.", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~<br /></p>

          <p>~ . SGN::I18N::translate($ui_i18n, "genotype.marker.in_this_section_of_sgn_you_will_find_sequence_and_clone_information", "In this section of SGN, you will find sequence and\n          clone information for each of these COS markers as well\n          as their matching counterpart in the arabidopsis genome.\n          We have surveyed these COS markers and mapped some of\n          these COS markers on the tomato genome to provide a\n          tomato: arabidopsis comparative map. This mapping\n          information is available on SGN now.", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~<br /></p>

          <p>~ . SGN::I18N::translate($ui_i18n, "genotype.marker.because_these_cos_markers_are_so_highly_conserved_they_may_also_be", "Because these COS markers are so highly conserved,\n          they may also be useful for comparative mapping in other\n          dicot species. The computational screen by how COS\n          markers were identified is described below:", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~</p>

          <ul>
            <li>~ . SGN::I18N::translate($ui_i18n, "genotype.marker.tblastx_tomato_ests_against_the_arabidopsis_genome_specifically_the_bac_tiling_path", "TBLASTX tomato ESTs against the arabidopsis genome\n            (specifically, the BAC tiling path from TAIR)", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~</li>

            <li>~ . SGN::I18N::translate($ui_i18n, "genotype.marker.identify_single_best_matches", "Identify single best matches (", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~&lt; e -15~ . SGN::I18N::translate($ui_i18n, "genotype.marker.between_a_single_tomato_est_or_associated_contig_and_a_single_bac", ") between a\n            single tomato EST (or associated contig) and a single\n            BAC in Arabidopsis. Each tomato EST must pass the\n            following criteria:", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~

              <ul>
                <li>~ . SGN::I18N::translate($ui_i18n, "genotype.marker.it_hits_an_arabidopsis_sequence_at_a_significance_level_of", "it hits an arabidopsis sequence at a\n                significance level of", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~ &lt; e -15</li>

                <li>~ . SGN::I18N::translate($ui_i18n, "genotype.marker.it_is_determined_to_be_not_part_of_a_domain_where_several", "it is determined to be NOT part of a domain\n                (where several solanaceous sequences hit the same\n                arabidopsis region)", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~</li>

                <li>~ . SGN::I18N::translate($ui_i18n, "genotype.marker.the_next_best_arabidopsis_hit_must_be_of_lower_significance_delta_e", "the next best Arabidopsis hit must be of lower\n                significance (delta e", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~ &gt; 10)</li>
              </ul>
            </li>

            <li>~ . SGN::I18N::translate($ui_i18n, "genotype.marker.ests_that_pass_all_these_criteria_are_classified_as_conserved_orthologs_all", "ESTs that pass all these criteria are classified as\n            conserved orthologs, all others are considered\n            potentially paralogous and eliminated.", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~</li>
          </ul><br />

          <h4>~ . SGN::I18N::translate($ui_i18n, "genotype.marker.functional_annotation_of_cos_markers", "Functional annotation of COS markers", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~</h4>

          <p>~ . SGN::I18N::translate($ui_i18n, "genotype.marker.cos_markers_were_functionally_annotated_using_the_mips_role_categories_as_they", "COS-markers were functionally annotated using the MIPS\n          role categories as they were defined at the time of the\n          analysis. As the functional role descriptions are subject\n          to continued changes, a copy of the role categories and\n          the COS-marker annotations as used in the analysis can be\n          found below:", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~<br /></p>

          <p><a href="/documents/markers/role_categories.txt">~ . SGN::I18N::translate($ui_i18n, "genotype.marker.mips_role_categories_at_time_of_cos_marker_annotation", "MIPS role categories at\n          time of COS marker annotation", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~</a></p>

          <h4>~ . SGN::I18N::translate($ui_i18n, "genotype.marker.the_list_of_cos_markers_is_available_in_both_online_and_plain", "The list of COS markers is available in both online\n          and plain text format", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~</h4>

          <p><a href="/search/markers/cos_list.pl">~ . SGN::I18N::translate($ui_i18n, "genotype.marker.cos_list_online", "COS list\n          online", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~</a> ~ . SGN::I18N::translate($ui_i18n, "genotype.marker.online_format_with_links_to_sequences_and_tiling_path", "- online format with links to sequences and\n          tiling path.", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~<br />
          <a href="/documents/markers/cos_list-old.txt">~ . SGN::I18N::translate($ui_i18n, "genotype.marker.old_plain_text_download", "Old plain text download", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~</a> ~ . SGN::I18N::translate($ui_i18n, "genotype.marker.plain_text_format_for_download", "- plain\n          text format for download.", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~ <br />
          <a href="/documents/markers/cos_list.txt">~ . SGN::I18N::translate($ui_i18n, "genotype.marker.old_plain_text_download_2", "Old plain text download 2", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~</a> ~ . SGN::I18N::translate($ui_i18n, "genotype.marker.plain_text_format_for_download", "- plain\n          text format for download.", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~\x20
          </p>

          <p><strong>~ . SGN::I18N::translate($ui_i18n, "global.bulk.input.note_label", "Note:", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~</strong> ~ . SGN::I18N::translate($ui_i18n, "genotype.marker.for_the_tomato_map_position_in_the_table_linked_above", "for the tomato map position in\n          the table linked above:", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~</p>

          <ul>
            <li>~ . SGN::I18N::translate($ui_i18n, "genotype.marker.copy_no_is_how_many_copies_the_cos_marker_shows_on_a", "Copy No is how many copies the COS marker shows on\n            a southern blot survey- S(single) is 1-2 copy, L(low)\n            is 3-4 copy, M(multiple) means more than 4 copy.", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~</li>

            <li>~ . SGN::I18N::translate($ui_i18n, "genotype.marker.map_position_is_where_the_cos_marker_mapped_on_the_tomato_arabidopsis", "Map position is where the COS marker mapped on the\n            tomato: arabidopsis systeny map. For example, T1675 map\n            position is 01.005, meaning Chromosome 1, 5 cM down\n            from the top. Most of the COS markers have only one map\n            position, if the COS marker has a second or third map\n            position, then there were two or three alleles that\n            could be mapped.", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~</li>
          </ul><br />
          <br />
        </td>
      </tr>
    </table>
    
  </center>
~);
$page->footer();
