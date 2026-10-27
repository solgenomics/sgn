#!/usr/bin/perl -w

#Main Page for Phenotypic Database

use strict;
use SGN::I18N ();
use HTML::Entities ();
use CXGN::Page;
use CXGN::DB::PhenoPopulation;
use CGI;

#get parameters from form on previous page
use CatalystX::GlobalContext qw( $c );
my SGN::I18N $ui_i18n = SGN::I18N::translate($c);
my %params = %{$c->req->params};
my $pop_id = $params{pop_id};

my $page = CXGN::Page->new('phenotype', 'Adri');

print "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 transitional//EN\" \"http://www.w3.org/tr/xhtml1/DTD/xhtml1-transitional.dtd\">";

$page->header(SGN::I18N::translate($ui_i18n, "phenotype.root.search_the_phenotype_database", "Search the Phenotype Database", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }));

#-------------------------------------------------
my @populations = CXGN::DB::PhenoPopulation::get_all_populations;
my $current_pop_id;
my $current_pop_name;

#population selected
if ($pop_id) {
  $current_pop_id = $pop_id;
  $current_pop_name = CXGN::DB::PhenoPopulation::get_pop_name_from_pop_id($pop_id);
}

#no population selected, first one in DB is used as default
else {
  $current_pop_id = $populations[0][0];
  $current_pop_name = $populations[0][1];
}

my @genotypes = CXGN::DB::PhenoPopulation::get_all_gen_from_pop_id($current_pop_id);
my @gen_ids;
for my $i (0..$#genotypes) {
  push @gen_ids, $genotypes[$i][0];
}
my @prop_info_by_organ = CXGN::DB::PhenoPopulation::get_all_prop_info_by_organ_from_pop_id($current_pop_id);

print ("\n<table summary=\"\" width=\"100%\" cellpadding=\"0\" cellspacing=\"10\" border=\"0\">\n\n<tr><td valign=\"top\">\n<table summary=\"\" width=\"100%\" cellpadding=\"0\" cellspacing=\"0\" border=\"0\">\n\n<tr><td>\n<center>\n<h3><u>" . SGN::I18N::translate($ui_i18n, "phenotype.root.welcome_to_the_phenotype_database", "Welcome to the Phenotype Database", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</u></h3>\n<p>" . SGN::I18N::translate($ui_i18n, "phenotype.root.from_this_page_you_can_search_the_phenotype_databse_for", "From this page, you can search the phenotype databse for data and images of all plants from all populations.", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</p>\n<p>" . SGN::I18N::translate($ui_i18n, "phenotype.root.there_are_two_ways_to_find_specific_data_and_images", "There are two ways to find specific data and images: searching by genotype and phenotype.", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</p>\n</center>\n</td></tr>\n\n<tr><td><img src=\"/documents/img/dot_clear.gif\" width=\"1\" alt=\"\" height=\"10\" /></td></tr>\n<tr><td colspan=\"1\" bgcolor=\"#cccccc\"><img src=\"/documents/img/dot_clear.gif\" alt=\"\" width=\"1\" height=\"1\" /></td></tr>\n<tr><td><img src=\"/documents/img/dot_clear.gif\" width=\"1\" height=\"10\" alt=\"\" /></td></tr>\n\n<tr><td>\n<center><h3><u>" . SGN::I18N::translate($ui_i18n, "phenotype.root.search_the_phenotype_database", "Search the Phenotype Database", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</u></h3></center>\n\n<center>\n<table summary=\"\" width=\"100%\" cellpadding=\"0\" cellspacing=\"0\" border=\"0\">\n\n<tr><td>\n<!--populations-->\n<form action=\"#\" method=\"get\">\n<table summary=\"\">\n<tr><td valign=\"top\">\n\n");
;

print ("<b><u>" . SGN::I18N::translate($ui_i18n, "phenotype.root.selected_population", "selected POPULATION:", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</u> $current_pop_name</b>");

print ("</td></tr>\n<tr><td><p>" . SGN::I18N::translate($ui_i18n, "phenotype.root.below_is_the_list_of_population_s_currently_in_the.df28d60", "Below is the list of population(s) currently in the database. Select a population and click the button to search images and data in another population.", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</p></td></tr>\n<tr><td valign=\"top\" align=\"left\">" . SGN::I18N::translate($ui_i18n, "phenotype.root.all_populations.2ddb165", "\nAll Populations:\n", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "<select name=\"pop_id\">\n");
;

for (0..$#populations) {
  print "<option value = \"$populations[$_][0]\">$populations[$_][1]</option>";
}

print ("</select>\n</td>\n<td valign=\"top\" align=\"right\">\n<input type=\"submit\" value=\"" . SGN::I18N::translate($ui_i18n, "phenotype.root.change_population", "Change Population", undef, { entities => undef, decode => 1 }) . "\" />\n</td></tr>\n</table>\n</form>\n</td></tr>\n\n<!--genotypes-->\n\n<tr><td>\n<form action=\"/phenotype/display_plants_from_genotype.pl\" method=\"get\">\n<table summary=\"\">\n<tr><td>\n<b><u>" . SGN::I18N::translate($ui_i18n, "phenotype.root.search_by_genotypes", "Search By GENOTYPES", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</u></b>\n</td></tr>\n<tr><td><p>" . SGN::I18N::translate($ui_i18n, "phenotype.root.below_is_a_list_of_all.d637367", "Below is a list of all ", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "<b>" . SGN::I18N::translate($ui_i18n, "phenotype.root.genotypes", "genotypes", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</b>" . SGN::I18N::translate($ui_i18n, "phenotype.root.in_the_selected_population_above_selecting_a_genotype_will_take.4c0f5f1", " in the selected population above -  \nselecting a genotype will take you to a page of plants with the selected genotype.  This new page will have links to all images and data of these plants:", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</p></td></tr>\n<tr><td valign=\"top\" align=\"left\">\n\n");
;

print ("" . SGN::I18N::translate($ui_i18n, "phenotype.root.genotypes_in.7138ec5", "Genotypes in ", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "<b>$current_pop_name</b>:");
print "<select name=\"gen_id\">";
for my $i (0..$#genotypes) {
  print "<option value = \"$genotypes[$i][0]\"> $genotypes[$i][1]</option>";
}
print "</select>";
print "<input type=\"hidden\" name=\"pop_id\" value=\"$current_pop_id\" />";
print "<input type=\"hidden\" name=\"pop_name\" value=\"$current_pop_name\" />";

print ("</td>\n<td valign=\"top\" align=\"right\">\n<input type=\"submit\" value=\"" . SGN::I18N::translate($ui_i18n, "phenotype.root.get_plants_by_genotype", "get Plants by Genotype", undef, { entities => undef, decode => 1 }) . "\" />\n</td></tr>\n</table>\n</form>\n</td></tr>\n\n<!--properties-->\n<tr><td>\n<form action=\"/phenotype/display_plants_from_property.pl\" method=\"get\">\n<table summary=\"\"><tr><td>\n<b><u>" . SGN::I18N::translate($ui_i18n, "phenotype.root.search_by_properties", "Search By PROPERTIES", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</u></b> (<a href=\"display_prop_list.pl\">" . SGN::I18N::translate($ui_i18n, "phenotype.root.property_descriptions", "Property Descriptions", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</a>)\n</td></tr>\n<tr><td>\n");
;

print ("<p>" . SGN::I18N::translate($ui_i18n, "phenotype.root.below_is_a_list_of_all.d637367", "Below is a list of all ", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "<b>" . SGN::I18N::translate($ui_i18n, "accessions.column.properties", "properties", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</b>" . SGN::I18N::translate($ui_i18n, "phenotype.root.measured_in_the_selected_population_above_selecting_a_property_will.76fb8e9", " measured in the selected population above - \nselecting a property will take you to a page of plants with the selected property measured.  This new page will have links to each plant's sample data and images:", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</p>");

print "</td></tr>";
print "<tr><td width=\"100%\" valign=\"top\" align=\"left\">";

print ("" . SGN::I18N::translate($ui_i18n, "phenotype.root.properties_in", "Properties in ", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "<b>$current_pop_name</b>:");
print "<select name=\"prop_id\">";

for (0..$#prop_info_by_organ) {
  my $i = $_;
  $prop_info_by_organ[$i] or next;
  my $organ_name = $prop_info_by_organ[$i][0][2];
  print "<optgroup label=\"$organ_name\">";
  for (0..$#{$prop_info_by_organ[$i]}) {
    my $j = $_;
    my $prop_id = $prop_info_by_organ[$i][$j][0];
    my $prop_name = $prop_info_by_organ[$i][$j][1];
    print "<option value = \"$prop_id\">$prop_name</option>\n";
  }
  print "</optgroup>";
}

print "</select>";
print "<input type=\"hidden\" name=\"pop_id\" value=\"$current_pop_id\" />";
print "<input type=\"hidden\" name=\"pop_name\" value=\"$current_pop_name\" />";

print ("\n</td>\n<td width=\"100%\" valign=\"top\" align=\"right\">\n<input type=\"submit\" value=\"" . SGN::I18N::translate($ui_i18n, "phenotype.root.get_plants_by_property", "get Plants by Property", undef, { entities => undef, decode => 1 }) . "\" />\n</td></tr></table>\n</form>\n</td></tr>\n\n</table>\n</center>\n</td>\n</tr>\n\n</table>\n</td></tr>\n\n<tr><td><img src=\"/documents/img/dot_clear.gif\" width=\"1\" height=\"10\" alt=\"\" /></td></tr>\n<tr><td bgcolor=\"#cccccc\"><img src=\"/documents/img/dot_clear.gif\" width=\"1\" height=\"1\" alt=\"\" /></td></tr>\n<tr><td><img src=\"/documents/img/dot_clear.gif\" width=\"1\" height=\"10\" alt=\"\" /></td></tr>\n\n<!--terminology-->\n<tr><td>\n<center><h3><u>" . SGN::I18N::translate($ui_i18n, "phenotype.root.terminology", "Terminology", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</u></h3></center>\n\n<table summary=\"\" width=\"100%\" cellpadding=\"0\" cellspacing=\"0\" border=\"0\">\n<tr><td>\n\n<dl>\n<dt><b>" . SGN::I18N::translate($ui_i18n, "phenotype.root.population.fe530b3", "Population", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</b></dt>\n<dd>" . SGN::I18N::translate($ui_i18n, "phenotype.root.all_the_organisms_that_constitute_a_specific_group_or_occur.09923ea", "all the organisms that constitute a specific group or occur in a specified location.", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</dd>\n<dt><br /><b>" . SGN::I18N::translate($ui_i18n, "phenotype.root.genotype", "Genotype", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</b></dt>\n<dd>" . SGN::I18N::translate($ui_i18n, "phenotype.root.a_group_of_organisms_sharing_a_specific_genetic_constitution.dea3660", "a group of organisms sharing a specific genetic constitution.", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</dd>\n<dt><br /><b>" . SGN::I18N::translate($ui_i18n, "phenotype.root.property_phenotype", "Property/Phenotype", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</b></dt>\n<dd>" . SGN::I18N::translate($ui_i18n, "phenotype.root.the_observable_physical_or_biochemical_characteristics_of_an_organism_as.1ff8b48", "the observable physical or biochemical characteristics of an organism, as determined by both genetic makeup and environmental influences.", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</dd>\n</dl>\n\n</td></tr>\n</table>\n\n</td></tr>\n\n</table>\n");
;

#--------------------------
$page->footer();
