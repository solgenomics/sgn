#!/usr/bin/perl -w

#Display page by property

use strict;
use SGN::I18N ();
use HTML::Entities ();
use CXGN::Page;
use CXGN::DB::PhenoPopulation;
use CatalystX::GlobalContext qw( $c );
my SGN::I18N $ui_i18n = SGN::I18N::translate($c);

#get parameters from form on previous page
my %params = %{$c->req->params};
my $filepath = $params{filepath};
my $pop_id = $params{pop_id};
my $pop_name = $params{pop_name};
my $gen_name = $params{gen_name};
my $gen_id = $params{gen_id};
my $plant_name = $params{plant_name};
my $plant_id = $params{plant_id};
my $institution = $params{institution};
my $environment = $params{environment};
my $year = $params{year};
my $prop_name = $params{prop_name};
my $prop_id = $params{prop_id};
my $gen_image_dir = CXGN::DB::PhenoPopulation::get_generated_image_dir;

my $page = CXGN::Page->new('phenotype', 'Adri');

print "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 transitional//EN\" \"http://www.w3.org/tr/xhtml1/DTD/xhtml1-transitional.dtd\">";

$page->header(SGN::I18N::translate($ui_i18n, "phenotype.root.image_and_data", "Image and Data", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }));

print ("\n<table summary=\"\" width=\"100%\" cellpadding=\"0\" cellspacing=\"10\" border=\"0\">\n\n<tr><td colspan=\"5\">\n<center><h3><u>" . SGN::I18N::translate($ui_i18n, "phenotype.root.image_and_data", "Image and Data", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</u></h3></center>\n</td></tr>\n\n");
;


#if there is a property_id passed into this script
if ($filepath) {

#plant info
print "<tr><td>";
print ("<b><u>" . SGN::I18N::translate($ui_i18n, "phenotype.root.image_information", "Image Information", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</u></b>\n");
print "<ul>\n";
print ("<li>" . SGN::I18N::translate($ui_i18n, "phenotype.root.population.8943544", "Population: ", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "<a href=\"population.pl?pop_id=$pop_id\"><b>$pop_name</b></a></li>\n");
print ("<li>" . SGN::I18N::translate($ui_i18n, "phenotype.root.genotype_group", "Genotype Group: ", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "<a href=\"display_plants_from_genotype.pl?pop_id=$pop_id\&amp;pop_name=$pop_name\&amp;gen_id=$gen_id\"><b>$gen_name</b></a></li>\n");
print ("<li>" . SGN::I18N::translate($ui_i18n, "phenotype.root.plant_name", "Plant Name: ", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "<a href=\"display_samples_from_plant.pl?pop_id=$pop_id\&amp;pop_name=$pop_name\&amp;gen_id=$gen_id\&amp;gen_name=$gen_name\&amp;plant_name=$plant_name\&amp;plant_id=$plant_id\&amp;institution=$institution\&amp;environment=$environment\&amp;year=$year\"><b>$plant_name</b></a></li>\n");
print ("<li>" . SGN::I18N::translate($ui_i18n, "trial.details.location", "Location: ", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "<b> $institution $environment $year</b></li>\n");
print "</ul>\n";
print "</td></tr>\n";

my $prev_page = "image";

print "<tr><td valign=\"top\">\n";

#table for other sections
print "<table summary=\"\" width=\"100%\" cellpadding=\"0\" cellspacing=\"0\" border=\"0\">\n";
print "<tr><td>\n";

#table for image
print "<table summary=\"\">\n";
print ("<tr><td>\n<b><u>" . SGN::I18N::translate($ui_i18n, "phenotype.root.display_image", "Display Image", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</u></b>\n</td></tr>\n");

  print "<tr><td>\n<br />";

  my $orig = $filepath;
  $filepath =~ /(.*)(\.)(png|jpg|tiff|tif|gif|psd)$/i;
  my $no_ext = $1;
  my $ext = $3;

  if ($ext eq "psd") {
    print ("<img src=\"/documents/img/linux_penguin_display.jpg\" align=\"middle\" alt=\"" . SGN::I18N::translate($ui_i18n, "phenotype.root.unavailable", "UNAVAILABLE", undef, { entities => undef, decode => 1 }) . "\" />");
  }
  elsif (!$filepath) {
    print "<img src=\"/documents/img/linux_penguin_display.jpg\" align=\"middle\" alt=\"=(\" />";
  }
  else {
    print "<img src=\"$gen_image_dir/displays/" . $no_ext . "_display.png\"" ." align=\"middle\" alt=\"=(\" />";
  }

  #zipped copy for download
  print "<br /><br />\n";
  print ("<center><b>" . SGN::I18N::translate($ui_i18n, "phenotype.root.note", "Note", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</b>" . SGN::I18N::translate($ui_i18n, "phenotype.root.this_is_not_the_original_image", ": this is not the original image;", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "<br />");
  if (system ("ls " . $gen_image_dir . "zips/" . $filepath . ".gz") == 0) {
    print "<a href=\"$gen_image_dir/zips/" .$filepath . ".gz\">";
    print ("" . SGN::I18N::translate($ui_i18n, "phenotype.root.download", "download", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "");
    print ("</a>" . SGN::I18N::translate($ui_i18n, "phenotype.root.the_zipped_copy_for_the_orginal_image", " the zipped copy for the orginal image.", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "");
  }
  else {
    print ("" . SGN::I18N::translate($ui_i18n, "phenotype.root.a_downloadable_copy_is_not_available_at_this_time", "A downloadable copy is not available at this time.", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "");
  }
  print "</center>\n";
  print "</td></tr>\n";

print "</table>\n";
print "</td>\n";

#table for graph
print ("<td valign=\"top\">\n<table summary=\"\" width=\"100%\" cellpadding=\"0\" cellspacing=\"0\" border=\"0\">\n<tr><td align=\"center\"><b><u>" . SGN::I18N::translate($ui_i18n, "phenotype.root.all_data_for_image", "All Data For Image", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</u></b></td></tr>\n\n<tr><td>\n<img src=\"/documents/img/dot_clear.gif\" alt=\"\" width=\"220\" height=\"1\" />\n</td></tr>\n\n<tr><td>\n\n<table summary=\"\" border=\"1\" width=\"100%\">\n<tr>\n<td width=\"33%\"><center><b>" . SGN::I18N::translate($ui_i18n, "phenotype.root.property.f78dc8f", "PROPERTY", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</b></center></td>\n<td width=\"33%\"><center><b>" . SGN::I18N::translate($ui_i18n, "phenotype.root.sample.e3d75bd", "SAMPLE", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</b></center></td>\n<td width=\"33%\"><center><b>" . SGN::I18N::translate($ui_i18n, "phenotype.root.value.9e6f05d", "VALUE", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</b></center></td>\n</tr>\n");
;

# graph goes here #
my %dp_value_by_prop_and_sample_name = CXGN::DB::PhenoPopulation::get_dp_info_from_filepath ($filepath);

  foreach my $hash_key (sort keys %dp_value_by_prop_and_sample_name) {

    foreach my $dp_count (0 .. $#{$dp_value_by_prop_and_sample_name{$hash_key}}) {

      my $dp_value = $dp_value_by_prop_and_sample_name{$hash_key}[$dp_count];
      my $num = $#{$dp_value_by_prop_and_sample_name{$hash_key}} + 1;

      $hash_key =~ /(.*)(hash_key)(.*)/;
      my $prop_name = $1;
      my $fullname = $3;

      print "<tr>\n";
      if ($dp_count == 0) {
	print "<td rowspan=\"$num\"><center>";
	if ($prop_id) {
	  print "<a href=\"display_prop_list.pl?pop_id=$pop_id\&amp;pop_name=$pop_name\&amp;gen_name=$gen_name\&amp;gen_id=$gen_id\&amp;plant_name=$plant_name\&amp;plant_id=$plant_id\&amp;institution=$institution\&amp;environment=$environment\&amp;year=$year\&amp;filepath=$filepath\&amp;prop_name=$prop_name\&amp;prop_id=$prop_id&amp;prev_page=$prev_page\">$prop_name</a>";
	}
	else {
	  print "<a href=\"display_prop_list.pl?pop_id=$pop_id\&amp;pop_name=$pop_name\&amp;gen_name=$gen_name\&amp;gen_id=$gen_id\&amp;plant_name=$plant_name\&amp;plant_id=$plant_id\&amp;institution=$institution\&amp;environment=$environment\&amp;year=$year\&amp;filepath=$filepath\&amp;prev_page=$prev_page\">$prop_name</a>";
	}
	print "</center></td>\n";
	print "<td rowspan=\"$num\"><center>$fullname</center></td>\n";
      }

      if ($dp_value && ($dp_value ne "n/a") && ($dp_value ne "-") && ($dp_value ne "no data")) {
	print "<td><center>$dp_value</center></td>\n";
      }
      else {
	print ("<td><center>" . SGN::I18N::translate($ui_i18n, "phenotype.root.not_available", "Not Available", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</center></td>\n");
      }

      print "</tr>\n";

    }
  }

##

print <<EOF
</table>

</td></tr>
</table>

</td></tr>
</table>
</td></tr>
EOF
;
}

#no image_id specified, something wrong with the prev link or somebody playing with the link?
else {
  print "<tr><td>";
  print ("" . SGN::I18N::translate($ui_i18n, "phenotype.root.error_no_image_has_been_specified", "ERROR:  No image has been specified", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "");
  print "</td></tr>";
}

print "</table>";

$page->footer();
