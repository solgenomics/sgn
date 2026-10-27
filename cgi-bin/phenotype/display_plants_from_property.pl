#!/usr/bin/perl -w

#Display page by property

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
my $pop_name = $params{pop_name};
my $prop_id = $params{prop_id};
my $gen_image_dir = CXGN::DB::PhenoPopulation::get_generated_image_dir;

my $page = CXGN::Page->new('phenotype', 'Adri');

print "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 transitional//EN\" \"http://www.w3.org/tr/xhtml1/DTD/xhtml1-transitional.dtd\">";

$page->header(SGN::I18N::translate($ui_i18n, "phenotype.root.plants_by_property", "Plants By Property", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }));

print ("\n<table summary=\"\" width=\"100%\" cellpadding=\"0\" cellspacing=\"10\" border=\"0\">\n\n<tr><td>\n<center><h3><u>" . SGN::I18N::translate($ui_i18n, "phenotype.root.plants_by_property", "Plants By Property", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</u></h3></center>\n</td></tr>\n\n");
;

if ($pop_id && $pop_name && $prop_id) {

my $prop_name;
  $prop_name = CXGN::DB::PhenoPopulation::get_prop_name_from_prop_id ($prop_id);
  my $param_list = "pop_id=$pop_id"."&amp;"."pop_name=$pop_name"."&amp;"."prop_id=$prop_id"."&amp;"."prop_name=$prop_name";
  my $prev_page = "property";
print "<tr><td>";
print ("<b><u>" . SGN::I18N::translate($ui_i18n, "phenotype.root.property_information", "Property Information", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</u></b>");
print "<ul>";
  print ("<li>" . SGN::I18N::translate($ui_i18n, "phenotype.root.population.8943544", "Population: ", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "<a href=\"population.pl?pop_id=$pop_id\"><b>$pop_name</b></a></li>");
  print(("<li>" . SGN::I18N::translate($ui_i18n, "phenotype.root.property_name", "Property Name: ", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "<b>$prop_name</b> (<a href=\"display_prop_list.pl?prev_page=$prev_page")."\&amp;".("$param_list\">" . SGN::I18N::translate($ui_i18n, "phenotype.root.property_descriptions", "Property Descriptions", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</a>)</li>"));
print "</ul>";
print "</td></tr>\n";

  #plants with the specified property_id
  my @plant_info_by_location = CXGN::DB::PhenoPopulation::get_plant_info_by_loc_from_pop_and_prop ($pop_id, $prop_id);

  if (@plant_info_by_location) {

    print "<tr><td width=\"100%\">";
    print ("<b><u>" . SGN::I18N::translate($ui_i18n, "phenotype.root.plants_with_the_selected_property_and_population", "Plants with the Selected Property and Population", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</u></b>");
    print "</td></tr>\n";

    for (my $i=1; $i<@plant_info_by_location; $i++) {

      #display location name if exists
      $plant_info_by_location[$i] or next;
      my @loc_info = CXGN::DB::PhenoPopulation::get_loc_info_from_loc_id($i);
      my $institution = $loc_info[0];
      my $environment = $loc_info[1];
      my $year = $loc_info[2];

      #display 8 images per row of the table of all images
      print "<tr><td><ul>";
      print ("<li style=\"list-style-type:none\">" . SGN::I18N::translate($ui_i18n, "trial.details.location", "Location: ", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "$institution" . " " . "$environment" . " " . "$year" . "" . "</li>");
      print "</ul></td></tr>\n";

      print "<tr><td>\n<center><table width=\"80%\" summary=\"\" cellspacing=\"7\">\n";

      #go through all plants for each location
      my $plant_count = 0;
      foreach my $plant_ref (sort {@{$a}[1] <=> @{$b}[1]} @{$plant_info_by_location[$i]}) {
	
	my $plant_id = @{$plant_ref}[0];
	my $plant_name = @{$plant_ref}[1];
	my $image_id = @{$plant_ref}[2];
	my $filepath = @{$plant_ref}[3];
	
	#display plant name and image to link to image and data page
	if (($plant_count%8) == 0) {
	  print "<tr>\n";
	}

	#display each image as a thumbnail
	my $orig = $filepath;
	$filepath =~ /(.*)(\.)(png|jpg|tiff|tif|gif|psd)$/i;
	my $no_ext = $1;
	my $ext = $3;

	print "<td><center>";
	print "<a href=\"/phenotype/display_property_data_from_plant.pl?pop_id=$pop_id\&amp;pop_name=$pop_name&amp;plant_id=$plant_id&amp;plant_name=$plant_name&amp;prop_id=$prop_id&amp;prop_name=$prop_name\&amp;institution=$institution\&amp;environment=$environment\&amp;year=$year\">";
	print "<img src='" . $gen_image_dir . "thumbnails/" . $no_ext . "_thumbnail\.jpg'".(" align=\"middle\" alt=\"N\.A\.\" /><br />" . SGN::I18N::translate($ui_i18n, "phenotype.root.plant", "Plant ", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "$plant_name" . "" . "</a>");
	
	print "</center></td>\n";

	if ((($plant_count%8) == 7) || ($plant_count == ((@{$plant_info_by_location[$i]})+1) ) ) {
	  print "</tr>\n";
	}

	$plant_count++;
      }

      print "</table></center>";
    }

  }

  #no plants with this property... somebody playing with the link?
  else {
    print "<tr><td>";
    print ("" . SGN::I18N::translate($ui_i18n, "phenotype.root.sorry_there_are_no_plants_currently_available_for_this_property", "Sorry, there are no plants currently available for this property.", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "");
    print "</td></tr>";
  }

  print "</td></tr>";

}

#no property_id or pop_name  specified, something wrong with the form or somebody playing with the link?
else {
  print "<tr><td>";
  print ("" . SGN::I18N::translate($ui_i18n, "phenotype.root.error_no_property_specified", "ERROR:  No property specified", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "");
  print "</td></tr>";
}

print "</table>";

$page->footer();
