use strict;
use SGN::I18N ();
use CatalystX::GlobalContext qw( $c );
my SGN::I18N $ui_i18n = SGN::I18N::translate($c);
use CXGN::Page;
my $page=CXGN::Page->new('index.html','html2pl converter');
$page->header('Sol Genomics Network');
print(qq~
  
     

     <br />
     <center>
     <table summary="" class="boxbgcolor2" width="100\%">
     <tr>
     <td width="25\%">&nbsp;</td>
     <td width="50\%" class="left">
	  <div class="boxcontent">
	  <br />
	    
	    <div class="subheading">
	    <u>~ . SGN::I18N::translate($ui_i18n, "genotype.marker.sgn_markers", "SGN Markers", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~</u>\x20
	    </div>
	    <div class="boxsubcontent">
            <a href="/markers/cos_markers.pl">~ . SGN::I18N::translate($ui_i18n, "genotype.marker.conserved_ortholog_set_cos_markers_16fae9", "Conserved Ortholog Set (COS) Markers", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~</a> ~ . SGN::I18N::translate($ui_i18n, "genotype.marker.in_this_section_of_sgn_you_will_find_sequence_and_clone_information_d959d3", "- In this section of SGN, you will find sequence and clone information for each of these COS markers as well as their matching counterpart in the arabidopsis genome. We have surveyed these COS markers and mapped some of these COS markers on the tomato genome to provide a tomato: arabidopsis comparative map. This mapping information is available on SGN now.", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~
	    </div>
	    <div class="boxsubcontent">
	    <a href="/markers/cosii_markers.pl">~ . SGN::I18N::translate($ui_i18n, "genotype.marker.conserved_ortholog_set_ii_cosii_markers_76662c", "Conserved Ortholog Set II (CosII) Markers", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~</a> ~ . SGN::I18N::translate($ui_i18n, "genotype.marker.in_this_section_of_sgn_you_will_find_sequence_information_of_each_5903d0", "- In this section of SGN, you will find sequence information of each COSII gene as well as the mapping information of those mapped COSII genes (so called COSII markers). We've mapped more than 100 COSII markers in tomato and will map more in the future, up to at least 500, and in the meanwhile, these COSII markers will be mapped in major solanaceous species (e.g. eggplant, pepper, Nicotiana, etc.). All the information in this section will be updated as new data are generated, so please come back and check from time to time.", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~
	    </div>
	    <div class="boxsubcontent">
	    <a href="/markers/microsats.pl">~ . SGN::I18N::translate($ui_i18n, "genotype.marker.microsatellites_ssrs", "Microsatellites (SSRs)", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~</a> ~ . SGN::I18N::translate($ui_i18n, "genotype.marker.while_microsatellites_or_simple_sequence_repeats_ssrs_normally_occur_in_non_coding", "- While microsatellites or simple sequence repeats (SSRs) normally occur in non-coding regions of the genome, they can also occur in either 3' or 5' UTRs of ESTs or even in coding regions (usually triplet repeats). See this page for more information.", undef, {entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '')}) . qq~
	    </div> 
              
          </div>
</td>
<td width="25\%">&nbsp;</td>
</tr>
</table>
</center>

~);
$page->footer();