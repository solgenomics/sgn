#!/usr/bin/perl -w

#Display page by property

use strict;
use CXGN::Page;
use CXGN::DB::PhenoPopulation;
use CGI;

#get parameters from form on previous page
our $c;
my %params = %{$c->req->params};
my $pop_id = $params{pop_id};
my $pop_name = $params{pop_name};
my $prop_id = $params{prop_id};
my $gen_image_dir = CXGN::DB::PhenoPopulation::get_generated_image_dir;

my $page = CXGN::Page->new('phenotype', 'Adri');

print "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 transitional//EN\" \"http://www.w3.org/tr/xhtml1/DTD/xhtml1-transitional.dtd\">";

$page->header("Plants By Property");

print <<EOF

<table summary="" width="100%" cellpadding="0" cellspacing="10" border="0">

<tr><td>
<center><h3><u>Plants By Property</u></h3></center>
</td></tr>

EOF
;

if ($pop_id && $pop_name && $prop_id) {

my $prop_name;
  $prop_name = CXGN::DB::PhenoPopulation::get_prop_name_from_prop_id ($prop_id);
  my $param_list = "pop_id=$pop_id"."&amp;"."pop_name=$pop_name"."&amp;"."prop_id=$prop_id"."&amp;"."prop_name=$prop_name";
  my $prev_page = "property";
print "<tr><td>";
print "<b><u>Property Information</u></b>";
print "<ul>";
  print "<li>Population: <a href=\"population.pl?pop_id=$pop_id\"><b>$pop_name</b></a></li>";
  print "<li>Property Name: <b>$prop_name</b> (<a href=\"display_prop_list.pl?prev_page=$prev_page"."\&amp;"."$param_list\">Property Descriptions</a>)</li>";
print "</ul>";
print "</td></tr>\n";

  #plants with the specified property_id
  my @plant_info_by_location = CXGN::DB::PhenoPopulation::get_plant_info_by_loc_from_pop_and_prop ($pop_id, $prop_id);

  if (@plant_info_by_location) {

    print "<tr><td width=\"100%\">";
    print "<b><u>Plants with the Selected Property and Population</u></b>";
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
      print "<li style=\"list-style-type:none\">Location: $institution $environment $year</li>";
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
	print "<img src='" . $gen_image_dir . "thumbnails/" . $no_ext . "_thumbnail\.jpg'"." align=\"middle\" alt=\"N\.A\.\" /><br />Plant $plant_name</a>";
	
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
    print "Sorry, there are no plants currently available for this property.";
    print "</td></tr>";
  }

  print "</td></tr>";

}

#no property_id or pop_name  specified, something wrong with the form or somebody playing with the link?
else {
  print "<tr><td>";
  print "ERROR:  No property specified";
  print "</td></tr>";
}

print "</table>";

$page->footer();
