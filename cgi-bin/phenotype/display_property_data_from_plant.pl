#!/usr/bin/perl -w

#Display all data values for a specified property and plant

use strict;
use CXGN::Page;
use CXGN::DB::PhenoPopulation;
use CGI;

#get parameters from form on previous page
use CatalystX::GlobalContext qw( $c );
my %params = %{$c->req->params};
my $pop_id = $params{pop_id};
my $pop_name = $params{pop_name};
my $plant_id = $params{plant_id};
my $plant_name = $params{plant_name};
my $gen_name = $params{gen_name};
my $gen_id = $params{gen_id};
my $prop_id = $params{prop_id};
my $prop_name = $params{prop_name};
if (!$prop_name) {
  $prop_name = CXGN::DB::PhenoPopulation::get_prop_name_from_prop_id($prop_id);
}
my $institution = $params{institution};
my $environment = $params{environment};
my $year = $params{year};
my $gen_image_dir = CXGN::DB::PhenoPopulation::get_generated_image_dir;

my $page = CXGN::Page->new('phenotype', 'Adri');

print "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 transitional//EN\" \"http://www.w3.org/tr/xhtml1/DTD/xhtml1-transitional.dtd\">";

$page->header("Property Data From Plant");

print <<EOF

<table summary="" width="100%" cellpadding="0" cellspacing="10" border="0">

<tr><td colspan="5">
<center><h3><u>Property Data From Plant</u></h3></center>
</td></tr>

EOF
;

#if there is a property_id passed into this script
if ($plant_id && $prop_id && $prop_name) {
  #get plant information
  my @gen_info = CXGN::DB::PhenoPopulation::get_gen_info_from_plant_id($plant_id);
  $gen_name= $gen_info[0];
  $gen_id = $gen_info[1];

  #plant information
  print "<tr><td>\n";
  print "<b><u>Plant Information</u></b>\n";
  print "<ul>\n";
  print "<li>Population: <a href=\"http://localhost/phenotype/population.pl?pop_id=1\"><b>$pop_name</b></a></li>\n";
  print "<li>Genotype Group: <a href =\"display_plants_from_genotype.pl?pop_id=$pop_id\&amp;pop_name=$pop_name\&amp;gen_id=$gen_id\"><b>$gen_name</b></a></li>\n";
  print "<li>Plant Name: <b>$plant_name</b></li>\n";
  print "<li>Location: <b> $institution $environment $year</b></li>\n";
  print "<li>Property: <a href =\"display_plants_from_property.pl?pop_id=$pop_id\&amp;pop_name=$pop_name\&amp;prop_id=$prop_id\"><b>$prop_name</b></a> (<a href=\"http://localhost/phenotype/display_prop_list.pl\">Property Descriptions</a>)</li>\n";
  print "</ul>\n";
  print "</td></tr>\n";

  print "<tr><td valign=\"top\">\n";

  #table for other sections
  print "<table summary=\"\" width=\"100%\" cellpadding=\"0\" cellspacing=\"0\" border=\"0\">\n";
  print "<tr><td>\n";

  # table for thumbnails
  print "<table summary=\"\">\n";
  print "<tr><td><b><u>Thumbnail Images of Samples with the Selected Property Measured</u></b></td></tr>\n";

  my %dp_info_by_image = CXGN::DB::PhenoPopulation::get_dp_image_from_plant_and_prop($plant_id, $prop_id);
  if (%dp_info_by_image) {
    print "<tr><td>\n";
    print "<center><table summary=\"\" cellspacing=\"7\">\n";

    my $image_count = 0;
    my $last_table_row_ended; #make sure we close all <tr> tags
    foreach my $filepath_key (sort keys %dp_info_by_image) {

      #display plant name and image to link to image and data page
      if (($image_count%4) == 0) {
	print "<tr>\n";
      }
      print "<td><center>";

      my $filepath = $filepath_key;
      $filepath =~ /(.*)(\.)(png|jpg|tiff|tif|gif|psd)$/i;
      my $no_ext = $1;
      my $ext = $3;

      #link to image and datapage
      print "<a href=\"/phenotype/display_image_and_data.pl?pop_id=$pop_id\&amp;pop_name=$pop_name\&amp;gen_name=$gen_name\&amp;gen_id=$gen_id\&amp;plant_name=$plant_name\&amp;plant_id=$plant_id\&amp;institution=$institution\&amp;environment=$environment\&amp;year=$year\&amp;filepath=$filepath\&amp;prop_name=$prop_name\&amp;prop_id=$prop_id\">";

      #display image
      print "<img src='" . $gen_image_dir . "thumbnails/" . $no_ext . "_thumbnail\.jpg' align=\"middle\" alt=\"N/A\" />";

      my @dp_info = @{$dp_info_by_image{$filepath_key}};
      @dp_info = sort {$a cmp $b} @dp_info;

      foreach my $dp_count (0 .. $#dp_info) {
	if ($dp_count != 0) {
	  print "; ";
	}
	else {
	  print "<br />";
	}

	#print sample group and sample name
	my $fullname = $dp_info[$dp_count];
	if ($fullname eq "ALL") {
	  print "ALL";
	}
	else {
	  print "Sample $fullname";
	}

      }

      print "</a>";
      print "</center></td>\n";
      if (($image_count%4) == 3) {
	print "</tr>";
	$last_table_row_ended = 1;
      }
      else
      {
      	$last_table_row_ended = 0;
      }

      $image_count++;
    }
    if($last_table_row_ended == 0)
    {
    	print "</tr>";
    }
    print "</table>";
    print "</center></td></tr>";

  }#end of IF for existing images for this property and plant
  print "</table></td>";
  
  print "<td valign=\"top\">";

  #table for graph
  print "<table summary=\"\" width=\"100%\" cellpadding=\"0\" cellspacing=\"0\" border=\"0\">";
  print "<tr><td align=\"center\"><b><u>Data</u></b></td></tr>";
  
  print "<tr><td>";
  print "<img src=\"/documents/img/dot_clear.gif\" alt=\"\" width=\"220\" height=\"1\" />";
  print "</td></tr>";
  
  print "<tr><td>";
  print "<table summary=\"\" border=\"1\" width=\"100%\">";
  print "<tr>";
  print "<td width=\"50%\"><center><b>Samples</b></center></td>";
  print "<td width=\"50%\"><center><b>";

  my $prev_page = "prop_data";
  print "<a href=\"/phenotype/display_prop_list.pl?pop_id=$pop_id\&amp;pop_name=$pop_name&amp;plant_id=$plant_id&amp;plant_name=$plant_name&amp;prop_id=$prop_id&amp;prop_name=$prop_name\&amp;institution=$institution\&amp;environment=$environment\&amp;year=$year&amp;prev_page=$prev_page\">";
  my $unit_name = CXGN::DB::PhenoPopulation::get_unit_name_from_prop($prop_id);
  if ($unit_name ne "none") {
    print "$prop_name \($unit_name\)";
  }
  else {
    print "$prop_name";
  }
  print "</a>";
  
  print "</b></center></td>\n\n";
  print "</tr>\n";

  #display data values for each sample
  my %dp_value_by_key = CXGN::DB::PhenoPopulation::get_dp_info_from_plant_and_prop($plant_id,$prop_id);

  my $dp_num = 0;
  my $dp_sum = 0;

  foreach my $hash_key (sort keys %dp_value_by_key) {
  
    foreach my $dp_count (0 .. $#{ $dp_value_by_key{$hash_key} } ) {

      my $dp_value = $dp_value_by_key{$hash_key}[$dp_count];
      if (!$dp_value || ($dp_value eq "n/a") || ($dp_value eq "-") || ($dp_value eq "no data")) {
        $dp_value = "Not Available";
      }
      if ($dp_value =~ /(\d+)((\.\d+)*)/) {
	$dp_num++;
	$dp_sum = $dp_sum + $dp_value;
      }
      my $num = $#{ $dp_value_by_key{$hash_key} } + 1;

      $hash_key =~ /(.*)(hash_key)(.*)/;
      my $fullname = $1;
      my $filepath = $3;
	
      print "<tr>";
      if ($dp_count == 0) {
	print "<td rowspan=\"$num\"><center>";
	print "<a href=\"/phenotype/display_image_and_data.pl?pop_id=$pop_id\&amp;pop_name=$pop_name\&amp;gen_name=$gen_name\&amp;gen_id=$gen_id\&amp;plant_name=$plant_name\&amp;plant_id=$plant_id\&amp;institution=$institution\&amp;environment=$environment\&amp;year=$year\&amp;filepath=$filepath\&amp;prop_name=$prop_name\&amp;prop_id=$prop_id\">";	
	print "$fullname</a></center></td>";
      }
      print "<td><center>";
      print "$dp_value</center></td>";
      print "</tr>\n";

    }#end of FOR LOOP through all data values

  }#end of FOR LOOP through all samples

  if ($dp_num > 0) {
    my $avg = $dp_sum / $dp_num;
    my $precision = CXGN::DB::PhenoPopulation::get_unit_precision_from_prop($prop_id);
    if ($precision > 0) {
      $avg = sprintf ("%10.${precision}f", $avg);
    }
    elsif ($avg =~ /(\d+)((\.\d+)*)/) {
      $avg = sprintf ("%10.2f", $avg);
    }
    print "<tr>";
    print "<td><center>Average of All Values</center></td>";
    print "<td><center>$avg</center></td>";
    print "</tr>";
  }
  print "</table>";
  print "</td></tr></table>";
  print "</td></tr>";
  print "</table></td></tr>";
}  


#no specified, something wrong with the prev link or somebody playing with the link?
else {
  print "<tr><td>";
  print "ERROR:  plant and property has not yet been specified";
  print "</td></tr>";
}



print "</table>";

$page->footer();
