#!/usr/bin/perl -w

#Display page by genotype

use strict;
use CXGN::Page;
use CXGN::DB::PhenoPopulation;
use CGI;

#get parameters from form on previous page
my $r = Apache2::RequestUtil->request;
$r->content_type("text/html");
my %params = $r->method eq 'POST' ? $r->content :$r->args;
my $pop_id = $params{pop_id};
my $pop_name = $params{pop_name};
my $gen_id = $params{gen_id};

my $page = CXGN::Page->new('phenotype', 'Adri');

print "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 transitional//EN\" \"http://www.w3.org/tr/xhtml1/DTD/xhtml1-transitional.dtd\">";

$page->header("Plants By Genotype");

print <<EOF

<table summary="" width="100%" cellpadding="0" cellspacing="10" border="0">

<tr><td>
<center><h3><u>Plants By Genotype</u></h3></center>
</td></tr>

EOF
;

if ($pop_name && $gen_id) {

my $gen_name;
my $param_list = "pop_id=$pop_id"."&"."pop_name=$pop_name"."&"."gen_id=$gen_id"."&"."gen_name=$gen_name";
my $prev_page = "genotype";

print "<tr><td>\n";
print "<b><u>Genotype Information</u></b>\n";
print "<ul>\n";
print "<li>Population: <a href =\"population.pl?pop_id=$pop_id\"><b>$pop_name</b></a></li>\n";
$gen_name = CXGN::DB::PhenoPopulation::get_gen_name_from_gen_id ($gen_id);
print "<li>Genotype Group: <b> $gen_name</b></li>\n";
print "</ul>\n";
print "</td></tr>\n";

    #display all plants from this genotype
    my @plant_info_from_gen = CXGN::DB::PhenoPopulation::get_all_plant_info_from_gen_id ($gen_id);

    #display each plant's info from selected genotype
    if (@plant_info_from_gen) {

      print "<tr><td>";
      print "<b><u>Plants with the Selected Genotype and Population</u></b>";
      print "</td></tr>\n";

      #plant name, location; link to page of all images by plant; list available properties
      for my $i (0..$#plant_info_from_gen) {
	$plant_info_from_gen[$i] or next;

	#display name and location
	my $plant_id = $plant_info_from_gen[$i][0][0];
	my $plant_name = $plant_info_from_gen[$i][0][1];
	my $institution = $plant_info_from_gen[$i][0][2];
	my $environment = $plant_info_from_gen[$i][0][3];
	my $year = $plant_info_from_gen[$i][0][4];

        print "<tr><td>";
        print "<ul><li style=\"list-style-type:none\"><b>Plant $plant_name</b> grown in <b>$institution $environment $year</b></li></ul>";
        print "</td></tr>\n";


        print "<tr><td>\n";
        print "<ul style=\"list-style-type:none\"><li><ul style=\"list-style-type:none\">\n"; 
        print "<li><a href=\"/phenotype/display_samples_from_plant.pl?pop_id=$pop_id\&amp;pop_name=$pop_name\&amp;gen_id=$gen_id\&amp;gen_name=$gen_name\&amp;plant_name=$plant_name\&amp;plant_id=$plant_id\&amp;institution=$institution\&amp;environment=$environment\&amp;year=$year\">View all images for this plant</a></li>\n";
        print "<li>&nbsp;</li>\n";

	#display existing properties for this plant in a drop box
	my @prop_by_organ = CXGN::DB::PhenoPopulation::get_all_prop_by_organ_from_plant_id ($plant_id);
	if (@prop_by_organ) {

          print "<li>\n<form action=\"/phenotype/display_property_data_from_plant.pl\" method=\"get\">\n";
          print "<table summary=\"\" width=\"80%\">\n<tr><td align=\"left\">\n";
          print "Property: <select name=\"prop_id\">\n";

	  #go through each organ
	  for my $j (0..$#prop_by_organ) {
	    $prop_by_organ[$j][0] or next;

	    my $organ_name = $prop_by_organ[$j][0][2];
	    print "<optgroup label=\"$organ_name\">\n";

	    #go through each property for this organ
	    foreach my $prop_ref (sort {@{$a}[1] cmp @{$b}[1]} @{$prop_by_organ[$j]}) {
	      my $prop_id = @{$prop_ref}[0];
	      my $prop_name = @{$prop_ref}[1];
	      print "<option value = \"$prop_id\"> $prop_name</option>\n";
	    }
            print "</optgroup>\n";

	  }

          print "</select>\n";
          print "</td>\n<td align=\"right\">\n";
          print "<input type=\"hidden\" name=\"pop_id\" value=\"$pop_id\" />\n";
          print "<input type=\"hidden\" name=\"pop_name\" value=\"$pop_name\" />\n";
          print "<input type=\"hidden\" name=\"gen_id\" value=\"$gen_id\" />\n";
          print "<input type=\"hidden\" name=\"gen_name\" value=\"$gen_name\" />\n";
          print "<input type=\"hidden\" name=\"plant_name\" value=\"$plant_name\" />\n";
          print "<input type=\"hidden\" name=\"plant_id\" value=\"$plant_id\" />\n";
          print "<input type=\"hidden\" name=\"institution\" value=\"$institution\" />\n";
          print "<input type=\"hidden\" name=\"environment\" value=\"$environment\" />\n";
          print "<input type=\"hidden\" name=\"year\" value=\"$year\" />\n";
          print "<input type=\"submit\" value=\"Get Data by Property\" />\n";	
          print "</td></tr>\n</table>\n";
          print "</form>\n";
          print "</li>\n";
          print "</ul></li></ul>\n";
          print "</td>";
          print "</tr>\n";
        }      
      }

    }

    #no plants for this genotype
    else {
      print "<tr><td>";
      print "Sorry, there are no plants currently available for this genotype.";
      print "</td></tr>";
    }
}

else {
  print "<tr><td>";
  print "ERROR:  No genotype has been specified";
  print "</td></tr>";
}

print "</table>";

$page->footer();
