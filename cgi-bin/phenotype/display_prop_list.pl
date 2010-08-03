#!/usr/bin/perl -w

#Display property list page

use strict;
use CXGN::Page;
use CXGN::DB::PhenoPopulation;
use CGI;
use HTML::Entities;

#get parameters from form on previous page
our $c;
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

$page->header("Property List Page");

print <<EOF

<table summary="" width="100%" cellpadding="0" cellspacing="10" border="0">

<tr><td colspan="5">
<center><h3><u>Property List Page</u></h3></center>
<br />
</td></tr>

<tr><td>
<ul>
<li><a href="#flower"><i>flower</i> Properties</a></li>
<li><a href="#fruit"><i>fruit</i> Properties</a></li>
<li><a href="#leaf"><i>leaf</i> Properties</a></li>
<li><a href="#ovary"><i>ovary</i> Properties</a></li>
<li style="list-style-type:none">&nbsp;</li>
EOF
;

#link back to referring page
if ($prev_page) {
  $filepath =~ s/ /&nbsp;/;
  if ($prev_page eq "genotype") {
    print "<li><a href=\"display_plants_from_genotype.pl?pop_id=$pop_id&amp;pop_name=$pop_name&amp;gen_id=$gen_id\">Back to Plants from Genotype <b>$gen_name</b> Page</a></li>";
  }
  elsif ($prev_page eq "image") {
    if ($prop_name && $prop_id) {
      print "<li><a href=\"display_image_and_data.pl?pop_id=$pop_id&amp;pop_name=$pop_name&amp;gen_name=$gen_name&amp;gen_id=$gen_id&amp;plant_name=$plant_name&amp;plant_id=$plant_id&amp;institution=$institution&amp;environment=$environment&amp;year=$year&amp;filepath=$filepath&amp;prop_name=$prop_name&amp;prop_id=$prop_id\">Back to Image and Data Page</a></li>";
    }
    else {
      print "<li><a href=\"display_image_and_data.pl?pop_id=$pop_id&amp;pop_name=$pop_name&amp;gen_name=$gen_name&amp;gen_id=$gen_id&amp;plant_name=$plant_name&amp;plant_id=$plant_id&amp;institution=$institution&amp;environment=$environment&amp;year=$year&amp;filepath=$filepath\">Back to Image and Data Page</a></li>";
    }
  }
  elsif ($prev_page eq "prop_data") {
    print "<li><a href=\"/phenotype/display_property_data_from_plant.pl?pop_id=$pop_id\&amp;pop_name=$pop_name&amp;plant_id=$plant_id&amp;plant_name=$plant_name&amp;prop_id=$prop_id&amp;prop_name=$prop_name&amp;institution=$institution&amp;environment=$environment&amp;year=$year\">Back to <b>$prop_name</b> Data Page</a></li>";
  }
  elsif ($prev_page eq "property") {
    print "<li><a href=\"display_plants_from_property.pl?pop_id=$pop_id&amp;pop_name=$pop_name&amp;prop_id=$prop_id\">Back to Plants from <b>$prop_name</b> Page</a></li>";
  }
  else {
    #do nothing
  }

}

#link to population page
if (!$pop_name) {
  $pop_name="F2 2000 99T748";
}
print <<EOF
<li><a href="population.pl?pop_id=$pop_id">$pop_name Population</a></li>
</ul>
</td></tr>

EOF
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
print <<EOF
<tr><td><center><h3><u><em><a name="$organ" id="$organ">$organ</a></em> Properties</u></h3></center></td></tr>

<tr><td>
<table summary="" border="1" width="100%" cellpadding="1" cellspacing="1">

<tr>
<td width="25%"><center><b>PROPERTY</b></center></td>
<td width="60%"><center><b>DESCRIPTION</b></center></td>
</tr>

EOF
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
      print "<td><center>Not Available</center></td>";
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
  print "<tr><td><center><h3><u>Example <em>$organ</em> Images</u></h3></center></td></tr>";
  if (@image_files) {
    foreach my $index (@image_files) {
      print "<tr><td>";
      print "<img src=\"" . "$prop_image_dir/$index" . "\" align=\"middle\" alt=\"UNAVAILABLE\" />";
      print "</td></tr>";
    }
  }
  else {
    print "<tr><td>None Available</td></tr>";
  }
  print "</table></td>";
  
  print "</tr></table></td></tr>";
}

print "</table>";

$page->footer();
