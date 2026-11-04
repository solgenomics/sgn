#!/usr/bin/perl -w

#Display property list page

use strict;
use SGN::I18N ();
use HTML::Entities ();
use CXGN::Page;
use CXGN::DB::PhenoPopulation;
use CGI;
use HTML::Entities;

#get parameters from form on previous page
use CatalystX::GlobalContext qw( $c );
my SGN::I18N $ui_i18n = SGN::I18N::translate($c);
my %params = %{$c->req->params};
my $prev_page = $params{prev_page};
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
my $prop_image_dir = CXGN::DB::PhenoPopulation::get_prop_image_dir;

my $page = CXGN::Page->new('phenotype', 'Adri');

print "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 transitional//EN\" \"http://www.w3.org/tr/xhtml1/DTD/xhtml1-transitional.dtd\">";

$page->header(SGN::I18N::translate($ui_i18n, "phenotype.root.property_list_page", "Property List Page", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }));

print ("\n<table summary=\"\" width=\"100%\" cellpadding=\"0\" cellspacing=\"10\" border=\"0\">\n\n<tr><td colspan=\"5\">\n<center><h3><u>" . SGN::I18N::translate($ui_i18n, "phenotype.root.property_list_page", "Property List Page", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</u></h3></center>\n<br />\n</td></tr>\n\n<tr><td>\n<ul>\n<li><a href=\"#flower\"><i>flower</i>" . SGN::I18N::translate($ui_i18n, "phenotype.root.properties", " Properties", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</a></li>\n<li><a href=\"#fruit\"><i>fruit</i>" . SGN::I18N::translate($ui_i18n, "phenotype.root.properties", " Properties", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</a></li>\n<li><a href=\"#leaf\"><i>leaf</i>" . SGN::I18N::translate($ui_i18n, "phenotype.root.properties", " Properties", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</a></li>\n<li><a href=\"#ovary\"><i>ovary</i>" . SGN::I18N::translate($ui_i18n, "phenotype.root.properties", " Properties", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</a></li>\n<li style=\"list-style-type:none\">&nbsp;</li>\n");
;

#link back to referring page
if ($prev_page) {
  $filepath =~ s/ /&nbsp;/;
  if ($prev_page eq "genotype") {
    print ("<li><a href=\"display_plants_from_genotype.pl?pop_id=$pop_id&amp;pop_name=$pop_name&amp;gen_id=$gen_id\">" . SGN::I18N::translate($ui_i18n, "phenotype.root.back_to_plants_from_genotype", "Back to Plants from Genotype ", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "<b>$gen_name</b>" . SGN::I18N::translate($ui_i18n, "phenotype.root.page", " Page", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</a></li>");
  }
  elsif ($prev_page eq "image") {
    if ($prop_name && $prop_id) {
      print ("<li><a href=\"display_image_and_data.pl?pop_id=$pop_id&amp;pop_name=$pop_name&amp;gen_name=$gen_name&amp;gen_id=$gen_id&amp;plant_name=$plant_name&amp;plant_id=$plant_id&amp;institution=$institution&amp;environment=$environment&amp;year=$year&amp;filepath=$filepath&amp;prop_name=$prop_name&amp;prop_id=$prop_id\">" . SGN::I18N::translate($ui_i18n, "phenotype.root.back_to_image_and_data_page", "Back to Image and Data Page", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</a></li>");
    }
    else {
      print ("<li><a href=\"display_image_and_data.pl?pop_id=$pop_id&amp;pop_name=$pop_name&amp;gen_name=$gen_name&amp;gen_id=$gen_id&amp;plant_name=$plant_name&amp;plant_id=$plant_id&amp;institution=$institution&amp;environment=$environment&amp;year=$year&amp;filepath=$filepath\">" . SGN::I18N::translate($ui_i18n, "phenotype.root.back_to_image_and_data_page", "Back to Image and Data Page", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</a></li>");
    }
  }
  elsif ($prev_page eq "prop_data") {
    print ("<li><a href=\"/phenotype/display_property_data_from_plant.pl?pop_id=$pop_id\&amp;pop_name=$pop_name&amp;plant_id=$plant_id&amp;plant_name=$plant_name&amp;prop_id=$prop_id&amp;prop_name=$prop_name&amp;institution=$institution&amp;environment=$environment&amp;year=$year\">" . SGN::I18N::translate($ui_i18n, "phenotype.root.back_to", "Back to ", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "<b>$prop_name</b>" . SGN::I18N::translate($ui_i18n, "phenotype.root.data_page", " Data Page", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</a></li>");
  }
  elsif ($prev_page eq "property") {
    print ("<li><a href=\"display_plants_from_property.pl?pop_id=$pop_id&amp;pop_name=$pop_name&amp;prop_id=$prop_id\">" . SGN::I18N::translate($ui_i18n, "phenotype.root.back_to_plants_from", "Back to Plants from ", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "<b>$prop_name</b>" . SGN::I18N::translate($ui_i18n, "phenotype.root.page", " Page", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</a></li>");
  }
  else {
    #do nothing
  }

}

#link to population page
if (!$pop_name) {
  $pop_name="F2 2000 99T748";
}
print ("<li><a href=\"population.pl?pop_id=$pop_id\">" . "" . "$pop_name" . SGN::I18N::translate($ui_i18n, "phenotype.root.population.788be6b", " Population", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</a></li>\n</ul>\n</td></tr>\n\n");
;

#PROPERTIES BY ORGAN
my %all_prop_by_organ = CXGN::DB::PhenoPopulation::get_all_props_by_organ();
foreach my $organ (sort keys %all_prop_by_organ) {

  #line
  print "<tr><td><img src=\"/documents/img/dot_clear.gif\" width=\"1\" height=\"5\" alt=\"\" /></td></tr>";
  print "<tr><td bgcolor=\"#cccccc\"><img src=\"/documents/img/dot_clear.gif\" width=\"1\" height=\"1\" alt=\"\" /></td></tr>";
  print "<tr><td><img src=\"/documents/img/dot_clear.gif\" width=\"1\" height=\"5\" alt=\"\" /></td></tr>";

  print "<tr><td><table summary=\"\">";
  print <<EOF
<!-- set column widths in -->
  <tr>
  <td><img src="/documents/img/dot_clear.gif" alt="" width="400" height="1" /></td>
  <td><img src="/documents/img/dot_clear.gif" alt="" width="10" height="1" /></td>
  <td><img src="/documents/img/dot_clear.gif" alt="" width="1" height="1" /></td>
  <td><img src="/documents/img/dot_clear.gif" alt="" width="10" height="1" /></td>
  <td><img src="/documents/img/dot_clear.gif" alt="" width="300" height="1" /></td>
  </tr>
<!-- set column widths out -->
EOF
;

#PROPERTIES
print ("<tr><td><center><h3><u><em><a name=\"$organ\" id=\"$organ\">$organ</a></em>" . SGN::I18N::translate($ui_i18n, "phenotype.root.properties", " Properties", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</u></h3></center></td></tr>\n\n<tr><td>\n<table summary=\"\" border=\"1\" width=\"100%\" cellpadding=\"1\" cellspacing=\"1\">\n\n<tr>\n<td width=\"25%\"><center><b>" . SGN::I18N::translate($ui_i18n, "phenotype.root.property.f78dc8f", "PROPERTY", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</b></center></td>\n<td width=\"60%\"><center><b>" . SGN::I18N::translate($ui_i18n, "phenotype.root.description", "DESCRIPTION", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</b></center></td>\n</tr>\n\n");
;
  foreach my $prop (sort keys %{$all_prop_by_organ{$organ}}) {

    my $description = $all_prop_by_organ{$organ}{$prop};
    HTML::Entities::encode_entities($description);
    print "<tr>";
    print "<td><center>$prop</center></td>";

    if ($description) {
      print "<td><center>$description</center></td>";
    }
    else {
      print ("<td><center>" . SGN::I18N::translate($ui_i18n, "phenotype.root.not_available", "Not Available", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</center></td>");
    }

    print "</tr>";

  }
  print "</table></td>";

#SPACE & DIVIDERS------------------------------------------
print <<EOF
<td></td>
<td bgcolor="#cccccc"><img src="/documents/img/dot_clear.gif" width="1" height="1" alt="" /></td>
<td></td>
EOF
;

#IMAGES
  my @image_files = CXGN::DB::PhenoPopulation::get_all_prop_images_from_organ($organ);
  print "<td valign=\"top\"><table summary=\"\">";
  print ("<tr><td><center><h3><u>" . SGN::I18N::translate($ui_i18n, "phenotype.root.example", "Example ", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "<em>$organ</em>" . SGN::I18N::translate($ui_i18n, "phenotype.root.images.b53a69f", " Images", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</u></h3></center></td></tr>");
  if (@image_files) {
    foreach my $index (@image_files) {
      print "<tr><td>";
      print "<img src=\"" . "$prop_image_dir/$index" . ("\" align=\"middle\" alt=\"" . SGN::I18N::translate($ui_i18n, "phenotype.root.unavailable", "UNAVAILABLE", undef, { entities => undef, decode => 1 }) . "\" />");
      print "</td></tr>";
    }
  }
  else {
    print ("<tr><td>" . SGN::I18N::translate($ui_i18n, "phenotype.root.none_available", "None Available", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</td></tr>");
  }
  print "</table></td>";
  
  print "</tr></table></td></tr>";
}

print "</table>";

$page->footer();
