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

$page->header($current_pop_name.SGN::I18N::translate($ui_i18n, "phenotype.root.population.788be6b", " Population", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }));

print ("\n<table summary=\"\" width=\"100%\" cellpadding=\"0\" cellspacing=\"10\" border=\"0\">\n\n<tr><td valign=\"top\">\n<center><h2><b><u>" . "" . "$current_pop_name" . SGN::I18N::translate($ui_i18n, "phenotype.root.population.788be6b", " Population", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</u></b></h2></center>\n</td></tr>\n");
;

#select box for populations
if ($#populations > 0) {
  print "<tr><td valign=\"top\">";
  print "<table summary=\"\"><tr><td colspan=\"2\">";
  print "<form action=\"/phenotype/main_phenotype.pl\" method=\"get\">";
  print "<br />";
  print ("<b><u>" . SGN::I18N::translate($ui_i18n, "phenotype.root.change_population", "Change Population", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</u></b>\n<br />");
  print ("" . SGN::I18N::translate($ui_i18n, "phenotype.root.below_is_the_list_of_population_s_currently_in_the.948ced2", "Below is the list of population(s) currently in the database.  Select a population and click the button to search images and data in another population.", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "");
  print "</td></tr>";
  print "<tr><td valign=\"top\" align=\"left\">";
  print ("" . SGN::I18N::translate($ui_i18n, "phenotype.root.all_populations.af2f753", "All Populations:  ", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "");
  print "<select name=\"pop_id\">\n";
  for my $i (0..$#populations) {
    print "<option value=\"$populations[$i][0]\"> $populations[$i][1]</option>";
  }
  print "</select>";
  print "</td>";
  print "<td valign=\"top\" align=\"right\">";
  print ("<input type=\"submit\" value=\"" . SGN::I18N::translate($ui_i18n, "phenotype.root.change_population", "Change Population", undef, { entities => undef, decode => 1 }) . "\" />");
  print "<br />";
  print "</form>";
  print "</td></tr></table>";
  print "</td></tr>";

  #line
  print "<tr><td><img src=\"/documents/img/dot_clear.gif\" width=\"1\" height=\"10\" alt=\"\" /></td></tr>";
  print "<tr><td colspan=\"1\" bgcolor=\"#cccccc\"><img src=\"/documents/img/dot_clear.gif\" width=\"1\" height=\"1\" alt=\"\" /></td></tr>";
  print "<tr><td><img src=\"/documents/img/dot_clear.gif\" width=\"1\" height=\"10\" alt=\"\" /></td></tr>";
}

print ("<tr><td valign=\"top\">\n\n<table summary=\"\" width=\"100%\" cellpadding=\"0\" cellspacing=\"0\" border=\"0\">\n\n<!--genotypes-->\n<tr><td colspan=\"2\">\n<form action=\"/phenotype/display_plants_from_genotype.pl\" method=\"get\">\n<table summary=\"\" width=\"100%\" cellpadding=\"0\" cellspacing=\"0\" border=\"0\">\n<tr><td>\n<b><u>" . SGN::I18N::translate($ui_i18n, "phenotype.root.search_by_genotypes", "Search By GENOTYPES", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</u></b>\n</td></tr>\n<tr><td>" . SGN::I18N::translate($ui_i18n, "phenotype.root.below_is_a_list_of_all.83ce014", "\nBelow is a list of all ", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "<b>" . SGN::I18N::translate($ui_i18n, "phenotype.root.genotypes", "genotypes", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</b>" . SGN::I18N::translate($ui_i18n, "phenotype.root.in_the_selected_population_above_selecting_a_genotype_will_take.a241ffb", " in the selected population above - selecting a genotype will take you to a page of plants with the selected genotype.  This new page will have links to all images and data of these plants:\n", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</td></tr>\n<tr><td valign=\"top\" align=\"left\">" . SGN::I18N::translate($ui_i18n, "phenotype.root.genotypes_in.0ad1fb7", "\nGenotypes in ", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "<b>$current_pop_name</b>:\n<select name=\"gen_id\">\n\n");
;

for my $i (0..$#genotypes) {
  print "<option value = \"$genotypes[$i][0]\"> $genotypes[$i][1]</option>";
}

print ("</select>\n<input type=\"hidden\" name=\"pop_id\" value=\"$current_pop_id\" />\n<input type=\"hidden\" name=\"pop_name\" value=\"$current_pop_name\" />\n</td>\n<td valign=\"top\" align=\"right\">\n<input type=\"submit\" value=\"" . SGN::I18N::translate($ui_i18n, "phenotype.root.get_plants_by_genotype", "get Plants by Genotype", undef, { entities => undef, decode => 1 }) . "\" />\n</td></tr>\n</table>\n</form>\n</td></tr>\n");
    ;

my $current_pop_name_2 = $current_pop_name;
$current_pop_name_2 =~ s/\s/%20/g;

print ("\n<!--properties-->\n<tr><td colspan=\"2\">\n<form action=\"/phenotype/display_plants_from_property.pl\" method=\"get\">\n<table summary=\"\">\n<tr><td>\n<b><u>" . SGN::I18N::translate($ui_i18n, "phenotype.root.search_by_properties", "Search By PROPERTIES", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</u></b> (<a href=\"display_prop_list.pl?pop_id=$current_pop_id&amp;pop_name=$current_pop_name_2\">" . SGN::I18N::translate($ui_i18n, "phenotype.root.property_descriptions", "Property Descriptions", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</a>)\n</td></tr>\n\n");
;

print ("<tr><td>" . SGN::I18N::translate($ui_i18n, "phenotype.root.below_is_a_list_of_all.d637367", "Below is a list of all ", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "<b>" . SGN::I18N::translate($ui_i18n, "accessions.column.properties", "properties", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</b>" . SGN::I18N::translate($ui_i18n, "phenotype.root.measured_in_the_selected_population_above_selecting_a_property_will.0db0cfb", " measured in the selected population above - selecting a property will take you to a page of plants with the selected property measured.  This new page will have links to each plant's sample data and images:", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</td></tr>");

print "<tr><td width=\"100%\" valign=\"top\" align=\"left\">";
print ("" . SGN::I18N::translate($ui_i18n, "phenotype.root.properties_in", "Properties in ", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "<b>$current_pop_name</b>:");
print "<select name=\"prop_id\">";

for my $i (0..$#prop_info_by_organ) {
  $prop_info_by_organ[$i] or next;

  my $organ_name = $prop_info_by_organ[$i][0][2];
  print "<optgroup label=\"$organ_name\">";
  for my $j (0..$#{$prop_info_by_organ[$i]}) {
    my $prop_id = $prop_info_by_organ[$i][$j][0];
    my $prop_name = $prop_info_by_organ[$i][$j][1];
    print "<option value=\"$prop_id\"> $prop_name</option>";
  }
  print "</optgroup>";
}

print ("</select>\n<input type=\"hidden\" name=\"pop_id\" value=\"$current_pop_id\" />\n<input type=\"hidden\" name=\"pop_name\" value=\"$current_pop_name\" />\n</td>\n<td width=\"100%\" valign=\"top\" align=\"right\">\n<input type=\"submit\" value=\"" . SGN::I18N::translate($ui_i18n, "phenotype.root.get_plants_by_property", "get Plants by Property", undef, { entities => undef, decode => 1 }) . "\" />\n</td></tr>\n</table>\n</form>\n</td></tr>\n\n<tr><td><img src=\"/documents/img/dot_clear.gif\" width=\"1\" height=\"10\" alt=\"\" /></td></tr>\n<tr><td colspan=\"1\" bgcolor=\"#cccccc\"><img src=\"/documents/img/dot_clear.gif\" width=\"1\" height=\"1\" alt=\"\" /></td></tr>\n<tr><td><img src=\"/documents/img/dot_clear.gif\" width=\"1\" height=\"10\" alt=\"\" /></td></tr>\n\n<tr><td>\n<center><h3><u>" . SGN::I18N::translate($ui_i18n, "phenotype.root.terminology", "Terminology", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</u></h3></center>\n</td></tr>\n<tr><td>\n  <dl>\n  <dt><b>" . SGN::I18N::translate($ui_i18n, "phenotype.root.population.fe530b3", "Population", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</b></dt>\n  <dd>" . SGN::I18N::translate($ui_i18n, "phenotype.root.all_the_organisms_that_constitute_a_specific_group_or_occur.bde5a5b", "all the organisms that constitute a specific group or occur in a specified location", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</dd>\n  <dt><br /><b>" . SGN::I18N::translate($ui_i18n, "phenotype.root.genotype", "Genotype", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</b></dt>\n  <dd>" . SGN::I18N::translate($ui_i18n, "phenotype.root.a_group_of_organisms_sharing_a_specific_genetic_constitution.b9c527b", "a group of organisms sharing a specific genetic constitution", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</dd>\n  <dt><br /><b>" . SGN::I18N::translate($ui_i18n, "phenotype.root.property_phenotype", "Property/Phenotype", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</b></dt>\n  <dd>" . SGN::I18N::translate($ui_i18n, "phenotype.root.the_observable_physical_or_biochemical_characteristics_of_an_organism_as.313b92e", "the observable physical or biochemical characteristics of an organism, as determined by both genetic makeup and environmental influences", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</dd>\n  </dl>\n\n</td></tr>\n</table>\n</td></tr>\n</table>\n\n");
;

$page->footer();
