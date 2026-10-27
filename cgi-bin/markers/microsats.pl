use strict;
use SGN::I18N ();
use CatalystX::GlobalContext qw( $c );
my SGN::I18N $ui_i18n = SGN::I18N::translate($c);
use CXGN::Page;
my $page=CXGN::Page->new('microsats.html','html2pl converter');
$page->header(SGN::I18N::translate($ui_i18n, "genotype.marker.microsatellites_ssrs", "Microsatellites (SSRs)", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}));
print(qq~
  <center>
    
    <br />

    <h3 align="center">~ . SGN::I18N::translate($ui_i18n, "genotype.marker.microsatellites_ssrs", "Microsatellites (SSRs)", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~</h3>

    <p>~ . SGN::I18N::translate($ui_i18n, "genotype.marker.while_microsatellites_or_simple_sequence_repeats_ssrs_normally_occur_in_non_coding_335baa", "While microsatellites or simple sequence repeats (SSRs)\n    normally occur in non-coding regions of the genome, they can\n    also occur in either 3' or 5' UTRs of ESTs or even in coding\n    regions (usually triplet repeats). For this reason, the tomato\n    and potato EST sequences contained in SGN were screened for\n    microsatellite sequence motifs in May 2001 using analytical\n    tools developed by Genomics Edge Technologies, Inc; St. Louis,\n    Missouri. The purpose was to identify SSRs that might be useful\n    a polymorphic molecular markers genetic and breeding studies in\n    tomato. The search parameters were for all possible repeat\n    motifs 2 bp to 6 bp with repeat blocks", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~ &gt; ~ . SGN::I18N::translate($ui_i18n, "genotype.marker.20_bp_the_search_algorithms_allowed_for_imperfect_repeats_as_well_as", "20 bp. The search\n    algorithms allowed for imperfect repeats as well as complex\n    repeats.", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~</p>

    <p>~ . SGN::I18N::translate($ui_i18n, "genotype.marker.for_those_wishing_to_test_ssrs_for_mapping_polymorphism_studies_it_is", "For those wishing to test SSRs for mapping/polymorphism\n    studies, it is recommended (based on empirical testing) to start\n    with:", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~<br /></p>

    <ul>
      <li>~ . SGN::I18N::translate($ui_i18n, "genotype.marker.dinucleotides", "dinucleotides", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~ &gt; ~ . SGN::I18N::translate($ui_i18n, "genotype.marker.12_repeats", "12 repeats", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~</li>

      <li>~ . SGN::I18N::translate($ui_i18n, "genotype.marker.trinucleotide", "trinucleotide", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~ &gt; ~ . SGN::I18N::translate($ui_i18n, "genotype.marker.8_repeats", "8 repeats", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~</li>

      <li>~ . SGN::I18N::translate($ui_i18n, "genotype.marker.tetra_to_hexonuclotides", "tetra to hexonuclotides", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~ &gt; ~ . SGN::I18N::translate($ui_i18n, "genotype.marker.6_repeats", "6 repeats", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~</li>
    </ul>
    <p>
    <a href="/search/markers/markersearch.pl?searchtype=startswith&amp;name=&amp;submit=search&amp;mapped=on&amp;confidence=0&amp;offsetstart=&amp;offsetend=&amp;chromosomes=all&amp;species=all&amp;maps=all&amp;types=SSR&amp;techniques=all">~ . SGN::I18N::translate($ui_i18n, "genotype.marker.see_all_ssr_markers_in_marker_search_results", "See all SSR markers in marker search results", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~</a><br />
    <a href="/documents/markers/microsat_list.txt">~ . SGN::I18N::translate($ui_i18n, "genotype.marker.old_text_version_ssr_list", "Old text version SSR list", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~</a>
    </p>
    
  </center>
~);
$page->footer();
