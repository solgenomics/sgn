#!/usr/bin/perl -w

#Display page by property

use strict;
use CXGN::Page;
use CXGN::DB::PhenoPopulation;
our $c;

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

$page->header("Image and Data");

print <<EOF

<table summary="" width="100%" cellpadding="0" cellspacing="10" border="0">

<tr><td colspan="5">
<center><h3><u>Image and Data</u></h3></center>
</td></tr>

EOF
;


#if there is a property_id passed into this script
if ($filepath) {

#plant info
print "<tr><td>";
print "<b><u>Image Information</u></b>\n";
print "<ul>\n";
print "<li>Population: <a href=\"population.pl?pop_id=$pop_id\"><b>$pop_name</b></a></li>\n";
print "<li>Genotype Group: <a href=\"display_plants_from_genotype.pl?pop_id=$pop_id\&amp;pop_name=$pop_name\&amp;gen_id=$gen_id\"><b>$gen_name</b></a></li>\n";
print "<li>Plant Name: <a href=\"display_samples_from_plant.pl?pop_id=$pop_id\&amp;pop_name=$pop_name\&amp;gen_id=$gen_id\&amp;gen_name=$gen_name\&amp;plant_name=$plant_name\&amp;plant_id=$plant_id\&amp;institution=$institution\&amp;environment=$environment\&amp;year=$year\"><b>$plant_name</b></a></li>\n";
print "<li>Location: <b> $institution $environment $year</b></li>\n";
print "</ul>\n";
print "</td></tr>\n";

my $prev_page = "image";

print "<tr><td valign=\"top\">\n";

#table for other sections
print "<table summary=\"\" width=\"100%\" cellpadding=\"0\" cellspacing=\"0\" border=\"0\">\n";
print "<tr><td>\n";

#table for image
print "<table summary=\"\">\n";
print "<tr><td>\n<b><u>Display Image</u></b>\n</td></tr>\n";

  print "<tr><td>\n<br />";

  my $orig = $filepath;
  $filepath =~ /(.*)(\.)(png|jpg|tiff|tif|gif|psd)$/i;
  my $no_ext = $1;
  my $ext = $3;

  if ($ext eq "psd") {
    print "<img src=\"/documents/img/linux_penguin_display.jpg\" align=\"middle\" alt=\"UNAVAILABLE\" />";
  }
  elsif (!$filepath) {
    print "<img src=\"/documents/img/linux_penguin_display.jpg\" align=\"middle\" alt=\"=(\" />";
  }
  else {
    print "<img src=\"$gen_image_dir/displays/" . $no_ext . "_display.png\"" ." align=\"middle\" alt=\"=(\" />";
  }

  #zipped copy for download
  print "<br /><br />\n";
  print "<center><b>Note</b>: this is not the original image;<br />";
  if (system ("ls " . $gen_image_dir . "zips/" . $filepath . ".gz") == 0) {
    print "<a href=\"$gen_image_dir/zips/" .$filepath . ".gz\">";
    print "download";
    print "</a> the zipped copy for the orginal image.";
  }
  else {
    print "A downloadable copy is not available at this time.";
  }
  print "</center>\n";
  print "</td></tr>\n";

print "</table>\n";
print "</td>\n";

#table for graph
print <<EOF
<td valign="top">
<table summary="" width="100%" cellpadding="0" cellspacing="0" border="0">
<tr><td align="center"><b><u>All Data For Image</u></b></td></tr>

<tr><td>
<img src="/documents/img/dot_clear.gif" alt="" width="220" height="1" />
</td></tr>

<tr><td>

<table summary="" border="1" width="100%">
<tr>
<td width="33%"><center><b>PROPERTY</b></center></td>
<td width="33%"><center><b>SAMPLE</b></center></td>
<td width="33%"><center><b>VALUE</b></center></td>
</tr>
EOF
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
	print "<td><center>Not Available</center></td>\n";
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
  print "ERROR:  No image has been specified";
  print "</td></tr>";
}

print "</table>";

$page->footer();
