#!/usr/bin/perl -w

#Display thumbnails of all images of a given plant

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
my $gen_name = $params{gen_name};
my $gen_id = $params{gen_id};
my $plant_name = $params{plant_name};
my $plant_id = $params{plant_id};
my $institution = $params{institution};
my $environment = $params{environment};
my $year = $params{year};
my $gen_image_dir = CXGN::DB::PhenoPopulation::get_generated_image_dir;

my $page = CXGN::Page->new('phenotype', 'Adri');

print "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 transitional//EN\" \"http://www.w3.org/tr/xhtml1/DTD/xhtml1-transitional.dtd\">";

$page->header(SGN::I18N::translate($ui_i18n, "phenotype.root.samples_from_plant", "Samples From Plant", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }));

print ("\n<table summary=\"\" width=\"100%\" cellpadding=\"0\" cellspacing=\"10\" border=\"0\">\n\n<tr><td>\n<center><h3><u>" . SGN::I18N::translate($ui_i18n, "phenotype.root.samples_from_plant", "Samples From Plant", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</u></h3></center>\n</td></tr>\n");
;

if ($pop_name && $gen_name && $plant_name) {

#display plant information & link
print "<tr><td>";
print ("<b><u>" . SGN::I18N::translate($ui_i18n, "phenotype.root.plant_information", "Plant Information", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</u></b>");
print "<ul>";
  print ("<li>" . SGN::I18N::translate($ui_i18n, "phenotype.root.population.8943544", "Population: ", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "<a href=\"population.pl?pop_id=$pop_id\"><b>$pop_name</b></a></li>");
  print ("<li>" . SGN::I18N::translate($ui_i18n, "phenotype.root.genotype_group", "Genotype Group: ", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "<b> $gen_name</b></li>");
  print ("<li>" . SGN::I18N::translate($ui_i18n, "phenotype.root.plant_name", "Plant Name: ", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "<b> $plant_name</b></li>");
  print ("<li>" . SGN::I18N::translate($ui_i18n, "phenotype.root.location_grown", "Location Grown: ", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "<b> $institution $environment $year</b></li>");
print "</ul>";
print "</td></tr>";

  #display all images for plant_id passed into this script
  if ($plant_id) {

    my @image_info_by_organ = CXGN::DB::PhenoPopulation::get_images_by_organ_from_plant_id($plant_id);

    #display thumbnail images by organ and then sample
    if (@image_info_by_organ) {
      print "<tr><td>";
      print ("<b><u>" . SGN::I18N::translate($ui_i18n, "phenotype.root.all_images_for_the_selected_plant", "All Images for the Selected Plant", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</u></b>");

      my $i;
      for my $i (0..$#image_info_by_organ) {
	$image_info_by_organ[$i] or next;

	#display organ name
	my $organ_name = $image_info_by_organ[$i][0][4];
	print "<ul>";
	print ("<li style=\"list-style-type:none\">" . "" . "$organ_name" . SGN::I18N::translate($ui_i18n, "phenotype.root.images.4ac4b6a", " images", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "</li>");
	print "</ul>";

	print "<center><table summary=\"\" cellspacing=\"7\">";

	my $image_count = 0;
	my $last_table_row_ended; #make sure all <tr>s are closed for correct xhtml
	foreach my $image_ref (sort {"@{$a}[2]"."@{$a}[3]" cmp "@{$b}[2]"."@{$a}[3]"} @{$image_info_by_organ[$i]}) {

	  #my $image_id = @{$image_ref}[0];
	  my $filepath = @{$image_ref}[1];
	  my $sample_group = @{$image_ref}[2];
	  my $sample_name = @{$image_ref}[3];
	  #my $organ_name = @{$image_ref}[4];

	  #display plant name, sample name, and image to link to image and data page
	  if (($image_count%8) == 0) {
	    print "<tr>";
	  }

	  #display each image in a 1/3 of the column
	  print "<td height=\"70\" align=\"center\">\n";
	  $filepath =~ /(.*)(\.)(png|jpg|tiff|tif|gif|psd)$/i;
	  my $no_ext = $1;
	  my $ext = $3;
	  print "<a href=\"display_image_and_data.pl?pop_id=$pop_id\&amp;pop_name=$pop_name\&amp;gen_id=$gen_id\&amp;gen_name=$gen_name\&amp;plant_name=$plant_name\&amp;plant_id=$plant_id\&amp;institution=$institution\&amp;environment=$environment\&amp;year=$year\&amp;filepath=$filepath\">";


	   if ($sample_group eq $sample_name) {
	     print "<img src=\"" . $gen_image_dir . "thumbnails/" .$no_ext ."_thumbnail\.jpg\"".(" align=\"middle\" alt=\"N/A\" /><br />" . SGN::I18N::translate($ui_i18n, "phenotype.root.sample.4c09be2", "Sample ", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "$sample_name" . "" . "</a>\n");
	   }
	  elsif ($sample_group eq "0") {
	    print "<img src=\"" . $gen_image_dir . "thumbnails/" . $no_ext . "_thumbnail\.jpg\"".(" align=\"middle\" alt=\"N/A\" /><br />" . SGN::I18N::translate($ui_i18n, "phenotype.root.sample.4c09be2", "Sample ", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "$sample_name" . "" . "</a>\n");
	  }
	  else {
	    print "<img src=\"" . $gen_image_dir . "thumbnails/" . $no_ext . "_thumbnail\.jpg\"".(" align=\"middle\" alt=\"N/A\" /><br />" . SGN::I18N::translate($ui_i18n, "phenotype.root.sample.4c09be2", "Sample ", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "$sample_group" . "" . "</a>\n");
	  }

	  print "</td>\n";

	  if ((($image_count%8) == 7) || ($image_count == ((@{$image_info_by_organ[$i]})+1) ) ) {
	    print "</tr>";
	    $last_table_row_ended = 1;
	  }
	  else
	  {
	  	$last_table_row_ended = 0;
	  }

	  $image_count++;

	}#end FOR LOOP of all images for each organ

	if($last_table_row_ended == 0)
	{
		print "</tr>";
	}
	print "</table></center>";

      }#end of IF of whether images exist for this plant

    }

    #no images found...
      else {
      print "<tr><td>";
      print ("" . SGN::I18N::translate($ui_i18n, "phenotype.root.sorry_there_are_no_images_currently_available_for_this_plant", "Sorry, there are no images currently available for this plant.", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "");
      print "</td></tr>";
    }

  }

  #no plant_id passed into this page... somebody playing with the link?
  else {
    print "<tr><td>";
    print ("" . SGN::I18N::translate($ui_i18n, "phenotype.root.error_no_plant_has_been_specified", "ERROR:  No plant has been specified", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "");
    print "</td></tr>";
  }

  print "</td></tr>";

}

else {
  print "<tr><td>";
  print ("" . SGN::I18N::translate($ui_i18n, "phenotype.root.error_no_population_genotype_and_or_plant_has_been_specified", "ERROR:  No population, genotype, and/or plant has been specified", undef, { entities => ($ui_i18n && $ui_i18n->locale ne 'en' ? '<>&\x80-\x{10FFFF}' : '<>&'), decode => 1 }) . "");
  print "</td></tr>";
}

print "</table>";


#--------------------------
$page->footer();
