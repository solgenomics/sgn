package CXGN::DB::PhenoPopulation;

#####################################################################
#
#  Program : $Id: phenotype_db_tools.pm 1413 2005-05-31 15:53:05Z john $
#  Author  : $Author: john $
#  Date    : $Date: 2005-05-31 11:53:05 -0400 (Tue, 31 May 2005) $
#  Version : 2.0
#  CHECKOUT TAG: $Name:  $
#
#  This module provides facilitating methods for the phenotypic
#  images database developed by Jennifer Lee.  It operates on
#  the pheno_population database in pg, using web_usr to read from it
#  and phenotype_editor to write to it.
#
####################################################################

#Used in all scripts with images
#  get_generated_image_dir ()
#  get_original_image_dir ()

#Used in main_phenotype.pl
#  get_all_populations ()
#  get_pop_name_from_pop_id (pop_id)
#  get_all_gen_from_pop_id (pop_id)
#  get_all_prop_by_organ_from_pop_id (pop_id)

#Used in diplay_plants_from_property.pl
#  get_plant_info_by_loc_from_pop_and_prop (pop_id, prop_id)
#  get_prop_name_from_prop_id (prop_id)
#  get_loc_info_from_loc_id (loc_id)

#Used in display_plants_from_genotype.pl
#  get_gen_name_from_gen_id (gen_id)
#  get_all_plant_info_from_gen_id (gen_id)
#  get_all_prop_by_organ_from_plant_id (plant_id)

#Used in display_property_data_from_plant.pl
#  get_prop_name_from_prop_id (prop_id)
#    --> also used in display_plants_from_property.pl
#  get_gen_info_from_plant_id (plant_id)
#  get_dp_image_from_plant_and_prop (plant_id, prop_id)
#  get_dp_info_from_plant_and_prop (plant_id, prop_id)

#Used in display_samples_from_plant.pl
#  get_images_by_organ_from_plant_id (plant_id)

#Used in display_image_and_data.pl
#  get_dp_info_from_filepath (filepath)

#Used in various scripts to create and load db
#  get_organ_name (organ_id)
#  get_prop_name (prop_id)
#  get_plant_id (plant_name, loc_id)
#  create_samples_entry_for_flower (sample_name, sample_group, organ_id, plant_id)
#  get_sample_id (plant_id, sample_group, sample_name)
#  get_prop_id (prop_name, organ_id)
#  get_image_id (organ, plant_num, type, sample_num)

#Used in display_prop_list.pl
#  get_all_prop_images ()

use strict;
use CXGN::DB::Connection;
use CXGN::Tools::File;
use CXGN::DB::Connection;


#------------------------------------------------------
#used for all scripts with images----------------------
#------------------------------------------------------
use CatalystX::GlobalContext '$c';

sub get_generated_image_dir {
    $c->get_conf('static_datasets_url').'/phenotype_images/generated_images/';
}

sub get_original_image_dir {
    # This is for use by Apache.
    $c->get_conf('static_datasets_url').'/phenotype_images/plant_images/';
}

sub get_prop_image_dir {
    # This is for use within Apache.
    $c->get_conf('static_datasets_url').'/phenotype_images/prop_images/';
}

sub get_system_prop_image_dir {
    # This is for use by the system.
    File::Spec->catdir( $c->get_conf('static_datasets_path'),
                        'phenotype_images',
                        'prop_images',
                       );
}

 
#------------------------------------------------------
#display_prop_list.pl----------------------------------
#------------------------------------------------------
sub get_all_props_by_organ {
  my %all_prop_by_organ;

  my $dbh = CXGN::DB::Connection->new('pheno_population');
  
  my $stm = "SELECT properties.prop_name, properties.annotation, organs.organ_name,
                    properties.unit_name
             FROM properties, organs
             WHERE properties.organ_id = organs.organ_id";
  my $sth = $dbh->prepare($stm);
  $sth->execute or die "ERROR getting all properties by organ\n";

  while (my @row = $sth->fetchrow_array) {
    my $prop_name = $row[0];
    my $description = $row[1];
    my $organ_name = $row[2];
    my $unit_name = $row[3];

    if ($unit_name ne "none") {
      $prop_name = "$prop_name"." \($unit_name\)";
    }

    $all_prop_by_organ{$organ_name}{$prop_name} =  $description;
  }

  $sth->finish;
  

  return %all_prop_by_organ;
}

#------------------------------------------------------
sub get_all_prop_images_from_organ ($) {
  my ($organ) = @_;

  my $source_dir = &get_system_prop_image_dir;
  $source_dir =~ s|/$||; #remove a trailing dir separator
  my @all_files = CXGN::Tools::File::traverse_dir("$source_dir"."/");
  my @image_files = grep /(.*)($organ)(.*)(png|jpg|tiff|tif|gif)$/i, @all_files;

  my @image_names;
  foreach my $image (sort @image_files) {
    $image =~ /($source_dir)(.*)(\/)(.*)(\.)(png|jpg|tiff|tif|gif|psd)$/i;
    my $just_name = "$4"."$5"."$6";
    push @image_names, $just_name;
  }

  return @image_names;
}


#------------------------------------------------------
#main_phenotype.pl-------------------------------------
#------------------------------------------------------
sub get_all_populations () {
  my @populations;

  my $dbh = CXGN::DB::Connection->new('pheno_population');
  
  my $stm = "SELECT pop_id, pedigree
             FROM populations";
  my $sth = $dbh->prepare($stm);
  $sth->execute or die "ERROR getting all populations\n";

  my $index = 0;
  while (my @row = $sth->fetchrow_array) {
    push @ {$populations[$index]}, $row[0];
    push @ {$populations[$index]}, $row[1];
    $index++;
  }

  $sth->finish;
  

  return @populations;
}

#------------------------------------------------------
sub get_pop_name_from_pop_id ($) {
  my ($pop_id) = @_;

  my $dbh = CXGN::DB::Connection->new('pheno_population');
  my $stm = "SELECT pedigree
             FROM populations
             WHERE pop_id = $pop_id";
  my $sth = $dbh->prepare($stm);
  $sth->execute or die "ERROR getting population name\n";
  my @row = $sth->fetchrow_array;
  my $pop_name = $row[0];
  

  return $pop_name;
}

#------------------------------------------------------
sub get_all_gen_from_pop_id ($) {
  my ($pop_id) = @_;
  my @genotypes;

  my $dbh = CXGN::DB::Connection->new('pheno_population');
  my $stm = "SELECT gen_id, gen_name
             FROM genotypes
             WHERE pop_id = $pop_id";
  my $sth = $dbh->prepare($stm);
  $sth->execute or die "ERROR getting genotypes by population\n";

  my $index = 0;
  while (my @row = $sth->fetchrow_array) {
    push @ {$genotypes[$index]}, $row[0];
    push @ {$genotypes[$index]}, $row[1];
    $index++;
  }

  $sth->finish;
  

  return @genotypes;
}


#------------------------------------------------------
sub get_all_prop_info_by_organ_from_pop_id ($) {
  my ($pop_id)= @_;
  my @prop_info_by_organ;

  my $dbh = CXGN::DB::Connection->new('pheno_population');
  my $stm = "SELECT properties.prop_id, properties.prop_name, properties.organ_id, organs.organ_name
             FROM genotypes, plants, samples, data_points, properties, organs
             WHERE genotypes.pop_id = $pop_id AND
                   genotypes.gen_id = plants.gen_id AND
                   plants.plant_id = samples.plant_id AND
                   samples.sample_id = data_points.sample_id AND
                   data_points.prop_id = properties.prop_id AND
                   properties.organ_id = organs.organ_id";

  my $sth = $dbh->prepare($stm);
  $sth->execute or die "ERROR getting all properties";

  my @added;
  while (my @row = $sth->fetchrow_array) {
    my $prop_id = $row[0];
    my $prop_name = $row[1];
    my $organ_id = $row[2];
    my $organ_name = $row[3];

    if (!grep/^$prop_id$/, @added) {
      my @info;
      push @info, $prop_id;
      push @info, $prop_name;
      push @info, $organ_name;

      push @{$prop_info_by_organ[$organ_id]}, [@info];
      push @added, $prop_id;
    }
  }

  $sth->finish;
  

  return @prop_info_by_organ;
}


#-----------------------------------------------------
#display_plants_from_property.pl----------------------
#-----------------------------------------------------
#input: prop_id
#output: plants ordered by location
sub get_plant_info_by_loc_from_pop_and_prop ($$) {

  my ($pop_id, $prop_id) = @_;
  my @plant_info_by_location;

  my $dbh = CXGN::DB::Connection->new('pheno_population');
  my $stm = "SELECT plants.plant_id, plants.loc_id, plants.plant_name, data_points.image_id, images.filepath
             FROM genotypes, plants, samples, data_points, images
             WHERE genotypes.pop_id = $pop_id AND
                   genotypes.gen_id = plants.gen_id AND
                   plants.plant_id = samples.plant_id AND
                   samples.sample_id = data_points.sample_id AND
                   data_points.prop_id = $prop_id AND
                   data_points.image_id = images.image_id";
  my $sth = $dbh->prepare($stm);
  $sth->execute or die "ERROR getting plant info by pop and prop\n";

  my @added;
  while (my @row = $sth->fetchrow_array) {
    my $plant_id = $row[0];
    my $loc_id = $row[1];
    my $plant_name = $row[2];
    my $image_id = $row[3];
    my $filepath = $row[4];

    if (!grep /^$plant_id$/, @added) {
      my @plant_info;
      push @plant_info, $plant_id;
      push @plant_info, $plant_name;
      push @plant_info, $image_id;
      push @plant_info, $filepath;

      push @{$plant_info_by_location[$loc_id]}, [@plant_info];
      push @added, $plant_id;
    }
  }

  

  return @plant_info_by_location;
}


#------------------------------------------------------
sub get_prop_name_from_prop_id ($) {
 my ($prop_id) = @_;

  my $dbh = CXGN::DB::Connection->new('pheno_population');

  my $stm = "SELECT prop_name FROM properties WHERE prop_id = ?";
  my $sth = $dbh->prepare($stm);

  $sth->execute($prop_id) or die "ERROR getting property name from prop_id";
  my @row = $sth->fetchrow_array;
  my $prop_name = $row[0];

  $sth->finish;
  
  return $prop_name;
}

#-----------------------------------------------------
sub get_loc_info_from_loc_id ($) {
  my ($loc_id) = @_;
  my @loc_info;

  my $dbh = CXGN::DB::Connection->new('pheno_population');

  my $stm = "SELECT institution, environment, year
             FROM locations
             WHERE loc_id = $loc_id";

  my $sth = $dbh->prepare($stm);
  $sth->execute or die "ERROR getting loc info by loc_id\n";

  my @row = $sth->fetchrow_array;
  push @loc_info, $row[0];
  push @loc_info, $row[1];
  push @loc_info, $row[2];

  $sth->finish;
  

  return @loc_info;
}


#------------------------------------------------------
#display_plants_from_genotype.pl-----------------------
#------------------------------------------------------
sub get_gen_name_from_gen_id ($) {
  my ($gen_id) = @_;
  my $gen_name;

  my $dbh = CXGN::DB::Connection->new('pheno_population');

  my $stm = "SELECT gen_name
             FROM genotypes
             WHERE gen_id = $gen_id";
  my $sth = $dbh->prepare($stm);
  $sth->execute or die "ERROR getting genotype name\n";
  my @row = $sth->fetchrow_array;
  $gen_name = $row[0];
  

  return $gen_name;
}

#------------------------------------------------------
sub get_all_plant_info_from_gen_id ($) {
  my ($gen_id) = @_;
  my @plant_info_from_gen;

  my $dbh = CXGN::DB::Connection->new('pheno_population');

  my $stm = "SELECT plants.plant_id, plants.plant_name,
                    locations.institution, locations.environment, locations.year
             FROM plants, locations
             WHERE plants.gen_id = $gen_id AND
                   plants.loc_id = locations.loc_id";
  my $sth = $dbh->prepare($stm);
  $sth->execute or die "ERROR getting plant info by gen_id\n";

  my $index = 0;
  while (my @row = $sth->fetchrow_array) {
    my @plant_info;
    my $plant_id = $row[0];
    my $plant_name = $row[1];
    my $institution = $row[2];
    my $environment = $row[3];
    my $year = $row[4];

    push @plant_info, $plant_id;
    push @plant_info, $plant_name;
    push @plant_info, $institution;
    push @plant_info, $environment;
    push @plant_info, $year;

    push @ {$plant_info_from_gen[$index]}, [@plant_info];
    $index++;
  }

  $sth->finish;
  

  return @plant_info_from_gen;
}

#-----------------------------------------------------
sub get_all_prop_by_organ_from_plant_id ($) {
  my ($plant_id) = @_;
  my @prop_by_organ;

  my $dbh = CXGN::DB::Connection->new('pheno_population');
  my $stm = "SELECT properties.prop_id, properties.prop_name,
                    properties.organ_id, organs.organ_name
             FROM organs, properties, data_points, samples
             WHERE samples.plant_id = $plant_id AND
                   samples.sample_id = data_points.sample_id AND
                   data_points.prop_id = properties.prop_id AND
                   properties.organ_id = organs.organ_id";
  my $sth = $dbh->prepare($stm);
  $sth->execute or die "ERROR getting prop by organ from plant\n";

  my @added;
  while (my @row = $sth->fetchrow_array) {
    my $prop_id = $row[0];
    my $prop_name = $row[1];
    my $organ_id = $row[2];
    my $organ_name = $row[3];

    if (!grep /^$prop_id$/, @added){
      my @prop_info;
      push @prop_info, $prop_id;
      push @prop_info, $prop_name;
      push @prop_info, $organ_name;

      push @{$prop_by_organ[$organ_id]}, [@prop_info];
      push @added, $prop_id;
    }
  }

  $sth->finish;
  

  return @prop_by_organ;
}

#------------------------------------------------------
#display_property_data_from_plant.pl-------------------
#------------------------------------------------------
sub get_gen_info_from_plant_id ($) {
  my ($plant_id) = @_;
  my @gen_info;

  my $dbh = CXGN::DB::Connection->new('pheno_population');

  my $stm = "SELECT genotypes.gen_name, genotypes.gen_id
             FROM plants, genotypes
             WHERE plants.plant_id=$plant_id AND
                   genotypes.gen_id=plants.gen_id";
  my $sth = $dbh->prepare($stm);
  $sth->execute or die "ERROR getting genotype info by plant_id\n";

  my @row = $sth->fetchrow_array;
  my $gen_name = $row[0];
  my $gen_id = $row[1];
  push @gen_info, $gen_name;
  push @gen_info, $gen_id;
  

  return @gen_info;
}

#-----------------------------------------------------
sub get_unit_name_from_prop ($) {
  my ($prop_id) = @_;

  my $dbh = CXGN::DB::Connection->new('pheno_population');

  my $stm = "SELECT unit_name
             FROM properties
             WHERE prop_id = ?";
  my $sth = $dbh->prepare($stm);

  $sth->execute($prop_id) or die "ERROR getting unit_name";
  my @row = $sth->fetchrow_array;
  my $unit_name = $row[0];

  $sth->finish;
  

  return $unit_name;
}

#-----------------------------------------------------
sub get_unit_precision_from_prop ($) {
  my ($prop_id) = @_;
  my $dbh = CXGN::DB::Connection->new('pheno_population');

  my $stm = "SELECT unit_precision
             FROM properties
             WHERE prop_id = $prop_id";
  my $sth = $dbh->prepare($stm);

  $sth->execute or die "ERROR getting unit_precision";
  my @row = $sth->fetchrow_array;
  my $unit_precision = $row[0];

  $sth->finish;
  

  return $unit_precision;
}

#-----------------------------------------------------
#output: returns an array of arrays (sample_name, sample_group, data value, filepath)
sub get_dp_info_from_plant_and_prop ($$) {
  my ($plant_id, $prop_id) = @_;
  my %dp_value_by_key;

  my $dbh = CXGN::DB::Connection->new('pheno_population');

  my $stm = "SELECT samples.sample_id, samples.sample_name, samples.sample_group,
                    data_points.value, images.filepath,
                    properties.unit_name, properties.unit_precision
             FROM plants, samples, data_points, images, properties
             WHERE plants.plant_id=? AND
                   samples.plant_id=plants.plant_id AND
                   data_points.sample_id=samples.sample_id AND
                   data_points.prop_id=? AND
                   data_points.image_id=images.image_id AND
                   properties.prop_id=?";
  my $sth = $dbh->prepare($stm);
  $sth->execute($plant_id,$prop_id,$prop_id) or die "ERROR getting dp info for samples by plant and property\n";

  while (my @row = $sth->fetchrow_array) {
    my $sample_name = $row[1];
    my $sample_group = $row[2];
    my $dp_value = $row[3];
    my $filepath = $row[4];
    my $unit_name = $row[5];
    my $unit_precision = $row[6];

    my $sample_key;
    if ($sample_group eq $sample_name) {
      if ($sample_group eq "0") {
	$sample_key = "ALL"."hash_key"."$filepath";
      }
      else {
	$sample_key = "$sample_group"."hash_key"."$filepath";
      }
    }
    elsif ($sample_group eq "0") {
      $sample_key = "$sample_name"."hash_key"."$filepath";
    }
    elsif ($sample_name eq "0") {
	$sample_key = "$sample_group"."hash_key"."$filepath";
    }
    else {
      $sample_key = "$sample_group, "."$sample_name"."hash_key"."$filepath";
    }

    if (($unit_precision > 0) && ($dp_value) && ($dp_value =~ /(\d+)((\.\d+)*)/)) {
      $dp_value = sprintf("%10.${unit_precision}f", $dp_value);
    }

    push @{$dp_value_by_key{$sample_key}}, $dp_value;
  }
  

  return %dp_value_by_key;
}

#-----------------------------------------------------
#output: returns an array of arrays (sample_name, sample_group, data value, filepath)
sub get_dp_image_from_plant_and_prop ($$) {
  my ($plant_id, $prop_id) = @_;
  my %dp_info_by_image;

  my $dbh = CXGN::DB::Connection->new('pheno_population');

  my $stm = "SELECT samples.sample_id, samples.sample_name, samples.sample_group,
                    images.filepath
             FROM plants, samples, data_points, images
             WHERE plants.plant_id=$plant_id AND
                   samples.plant_id=plants.plant_id AND
                   data_points.sample_id=samples.sample_id AND
                   data_points.prop_id=$prop_id AND
                   data_points.image_id=images.image_id";
  my $sth = $dbh->prepare($stm);
  $sth->execute or die "ERROR getting dp images for samples by plant and property\n";

  my @added;
  while (my @row = $sth->fetchrow_array) {
    my $sample_id = $row[0];
    my $sample_name = $row[1];
    my $sample_group = $row[2];
    my $filepath = $row[3];

    if (!grep/^$sample_id$/, @added) {
      my $fullname;
      if ($sample_group eq $sample_name) {
	if ($sample_group eq "0") {
	  $fullname = "ALL";
	}
	else {
	  $fullname = "$sample_group";
	}
      }
      elsif ($sample_name eq "0") {
	$fullname = $sample_group;
      }
      elsif ($sample_group eq "0") {
	$fullname = $sample_name;
      }
      else {
	$fullname = "$sample_group, "."$sample_name";
      }

      push @ {$dp_info_by_image{$filepath}}, $fullname;
      push @added, $sample_id;
    }
  }
  

  return %dp_info_by_image;
}



#-----------------------------------------------------
#display_samples_from_plant.pl------------------------
#-----------------------------------------------------
#input: plant_id
#output: returns array of image info in a three dim array, where the first index refers to the organ_id and the second index stores the filepath,and the third is sample name
sub get_images_by_organ_from_plant_id ($) {
  my ($plant_id) = @_;
  my @image_info_by_organ;

  my $dbh = CXGN::DB::Connection->new('pheno_population');

  my $stm = "SELECT images.image_id, images.filepath,
                    samples.sample_group, samples.sample_name,
                    organs.organ_id, organs.organ_name
             FROM images, samples, data_points, organs
             WHERE samples.plant_id = $plant_id AND
                   samples.organ_id = organs.organ_id AND
                   samples.sample_id = data_points.sample_id AND
                   data_points.image_id = images.image_id";
  my $sth = $dbh->prepare($stm);
  $sth->execute or die "ERROR getting images by plant";

  my @added;
  while (my @row = $sth->fetchrow_array) {
    my $image_id = $row[0];
    my $filepath = $row[1];
    my $sample_group = $row[2];
    my $sample_name = $row[3];
    my $organ_id = $row[4];
    my $organ_name = $row[5];

    if (!grep /^$image_id$/, @added){
      my @info;
      push @info, $image_id;
      push @info, $filepath;
      push @info, $sample_group;
      push @info, $sample_name;
      push @info, $organ_name;

      push @ {$image_info_by_organ[$organ_id]}, [@info];
      push @added, $image_id;
    }
  }

  $sth->finish;
  

  return @image_info_by_organ;
}


#-----------------------------------------------------
#display_image_and_data.pl----------------------------
#-----------------------------------------------------
#return a hash of hash of arrays (property_name, dp_value)
sub get_dp_info_from_filepath ($) {
  my ($filepath) = @_;
  my %dp_value_by_prop_and_sample_name;

  my $dbh = CXGN::DB::Connection->new('pheno_population');

  my $stm = "SELECT data_points.dp_id, properties.prop_name, data_points.value,
                    samples.sample_name, samples.sample_group,
                    properties.unit_name, properties.unit_precision
             FROM data_points, properties, images, samples
             WHERE images.filepath=\'$filepath\' AND
                   images.image_id = data_points.image_id AND
                   data_points.prop_id=properties.prop_id AND
                   data_points.sample_id = samples.sample_id";
  my $sth = $dbh->prepare($stm);
  $sth->execute or die "ERROR getting dp info from filepath\n";

  while (my @row = $sth->fetchrow_array) {
    my $dp_id = $row[0];
    my $prop_name = $row[1];
    my $dp_value = $row[2];
    my $sample_name = $row[3];
    my $sample_group = $row[4];
    my $unit_name = $row[5];
    my $unit_precision = $row[6];

    my $fullname;
    if ($sample_name eq $sample_group) {
      if ($sample_group eq "0") {
	$fullname = "ALL";
      }
      else {
	$fullname = $sample_group;
      }
    }
    elsif ($sample_group eq "0") {
      $fullname = $sample_name;
    }
    elsif ($sample_name eq "0") {
      $fullname = $sample_group;
    }
    else {
      $fullname = "$sample_group, "."$sample_name";
    }

    my $hash_key;
    if ($unit_name ne "none") {
      $hash_key = "$prop_name \($unit_name\)"."hash_key"."$fullname";
    }
    else {
      $hash_key = "$prop_name"."hash_key"."$fullname";
    }

    if (($unit_precision > 0) && ($dp_value) && ($dp_value =~ /(\d+)((\.\d+)*)/)) {
      $dp_value = sprintf ("%10.${unit_precision}f", $dp_value);
    }

    push @ {$dp_value_by_prop_and_sample_name{$hash_key}}, $dp_value;
  }
  

  return %dp_value_by_prop_and_sample_name;
}


#------------------------------------------------------
#various scripts to create and load db-----------------
#------------------------------------------------------
sub get_organ_name ($) {
  my ($organ_id) = @_;

  my $dbh = CXGN::DB::Connection->new('pheno_population');

  my $stm = "SELECT organ_name
             FROM organs
             WHERE organ_id = $organ_id";
  my $sth = $dbh->prepare($stm);

  $sth->execute or die "ERROR getting organ name";
  my @row = $sth->fetchrow_array;
  my $organ_name = $row[0];

  $sth->finish;
  
  return $organ_name;
}

#------------------------------------------------------
sub get_prop_name ($) {
 my ($prop_id) = @_;

  my $dbh = CXGN::DB::Connection->new('pheno_population');

  my $stm = "SELECT prop_name
             FROM properties
             WHERE prop_id = $prop_id";
  my $sth = $dbh->prepare($stm);

  $sth->execute or die "ERROR getting property name";
  my @row = $sth->fetchrow_array;
  my $prop_name = $row[0];

  $sth->finish;
  
  return $prop_name;
}


#------------------------------------------------------
sub get_plant_id ($$) {
  my ($plant_name, $loc_id) = @_;
  #print "plant_name: $plant_name, loc_id: $loc_id\n";

  my $dbh = CXGN::DB::Connection->new('pheno_population');

  my $stm = "SELECT plant_id
             FROM plants
             WHERE plant_name = $plant_name AND
                   loc_id = $loc_id;";
  my $sth = $dbh->prepare($stm);

  $sth->execute or die "ERROR getting plant_id\nplant_name: $plant_name, loc_id: $loc_id\n";
  my @row = $sth->fetchrow_array;
  my $plant_id = $row[0];

  $sth->finish;
  

  if ($plant_id) {
    return $plant_id;
  }
  else {
    die "ERROR getting plant_id\nplant_name: $plant_name, loc_id: $loc_id\n";
  }
}

#------------------------------------------------------
sub create_samples_entry_for_flower ($$$$) {
  my ($sample_name, $sample_group, $organ_id, $plant_id) = @_;

  my $dbh = CXGN::DB::Connection->new('pheno_population');

  my $stm = "INSERT INTO samples
             VALUES(NULL, '$sample_name', '$sample_group', '$organ_id', '$plant_id', NULL);";
  my $sth = $dbh->prepare($stm);
  $sth->execute or die "ERROR creating samples entry";

  $stm = "SELECT sample_id
          FROM samples
          WHERE plant_id = $plant_id AND
                   sample_name = $sample_name AND
                   sample_group = $sample_group";
  $sth = $dbh->prepare($stm);
  $sth->execute or die "ERROR getting sample_id";
  my @row = $sth->fetchrow_array;
  my $new_sample_id = $row[0];

  $sth->finish;
  

  if ($new_sample_id) {
    return $new_sample_id;
  }
  else {
    die "\nphenotype_db_tools::create_samples_entry_for_flower problem making new entry for flower sample:\n$sample_name, $sample_group, $organ_id, $plant_id\n";
  }
}


#------------------------------------------------------
sub get_sample_id($$$$) {
  my ($plant_id, $organ_id, $sample_group, $sample_name) = @_;

  my $dbh = CXGN::DB::Connection->new('pheno_population');

  my $stm = "SELECT sample_id
             FROM samples
             WHERE plant_id = $plant_id AND
                   organ_id = $organ_id AND
                   sample_name = \"$sample_name\" AND
                   sample_group = \"$sample_group\"";
  my $sth = $dbh->prepare($stm);

  $sth->execute or die "ERROR getting sample_id";
  my @row = $sth->fetchrow_array;
  my $sample_id = $row[0];

  $sth->finish;
  

  if ($sample_id) {
    return $sample_id;
  }
  else {
    return $sample_id;
    #die "In get_sample_id...  plant_id: $plant_id, sample_name: $sample_name\nERROR getting sample_id";
  }
}


#------------------------------------------------------
sub get_prop_id ($$) {
  my ($property, $organ_id) = @_;
  #print "In get_prop_id... property: $property, organ_id: $organ_id\n";

  my $dbh = CXGN::DB::Connection->new('pheno_population');

  my $stm = "SELECT prop_id
             FROM properties
             WHERE (prop_name = \"$property\") AND
                   organ_id = $organ_id";
  my $sth = $dbh->prepare($stm);

  $sth->execute or die "ERROR getting prop_id";
  my @row = $sth->fetchrow_array;
  my $prop_id = $row[0];

  $sth->finish;
  

  if ($prop_id) {
    return $prop_id;
  }
  else {
    #print "In get_prop_id... property: $property, organ_id: $organ_id\n";
    die "ERROR getting prop_id\nIn get_prop_id... property: $property, organ_id: $organ_id\n";
  }
}

#------------------------------------------------------
sub get_image_id ($$$$) {
  my ($organ, $plant_num, $type, $sample_num) = @_;
  #print "organ: $organ, plant_num: $plant_num, type: $type, sample_num: $sample_num\n";

  #select the key file names
  my $file_part;
  if ($organ eq "flower") {
    $file_part = "%"."flower_"."$type"."_plant"."$plant_num"."_sample"."$sample_num"."\."."%";
  }
  elsif ($organ eq "fruit") {
    $file_part = "%"."fruit_"."plant"."$plant_num"."\."."%";
  }
  elsif ($organ eq "ovary") {
    $file_part = "%"."ovary_"."$type"."_plant"."$plant_num"."_sample"."$sample_num"."\."."%";
  }
  elsif ($organ eq "leaf") {
    $file_part = "%"."leaf_"."$type"."_plant"."$plant_num"."\."."%";
  }
  elsif ($organ eq "mhc_leaf") {
    $file_part = "%"."leaf_"."$type"."_plant"."$plant_num"."_"."$sample_num"."\.png";
  }
  else {
    die "ERROR:unknown organ while trying to find image_id\norgan: $organ, plant_num: $plant_num, type: $type, sample_num: $sample_num\n";
  }

  my $dbh = CXGN::DB::Connection->new('pheno_population');

  my $stm = "SELECT image_id
             FROM images
             WHERE filepath LIKE \"$file_part\"";

  my $sth = $dbh->prepare($stm);

  $sth->execute or die "ERROR getting image_id";
  my @row = $sth->fetchrow_array;
  my $image_id = $row[0];

  #CU LEAF IMAGES
  #if the leaf images are separated then parses sample name to select image
  if (!($image_id) && ($organ eq "leaf")) {
    #print "separated...\n";

    $sample_num =~ /(\w)(_)(.*)/;
    my $sample_name = $1;
    $file_part = "%"."leaf_"."$type"."_plant"."$plant_num"."_"."$sample_name"."\."."%";
    #print "$file_part\n";

    $stm = "SELECT image_id
            FROM images
            WHERE filepath LIKE \"$file_part\"";
    $sth = $dbh->prepare($stm);
    $sth->execute or die "ERROR getting leaf image_id\norgan: $organ, plant_num: $plant_num, type: $type, sample_num: $sample_num\n";
    @row = $sth->fetchrow_array;
    $image_id = $row[0];
  }

  #MHC LEAF IMAGES
  if (!($image_id) && ($organ eq "mhc_leaf")) {
    $file_part = "%"."leaf_"."$type"."_plant"."$plant_num"."_"."AB"."\.png";

    $stm = "SELECT image_id
            FROM images
            WHERE filepath LIKE \"$file_part\"";
    $sth = $dbh->prepare($stm);
    $sth->execute or die "ERROR getting leaf image_id\norgan: $organ, plant_num: $plant_num, type: $type, sample_num: $sample_num\n";
    @row = $sth->fetchrow_array;
    $image_id = $row[0];
  }

  #close
  $sth->finish;
  

  #this is just a mess... doesn't look good, huh?
  if ($image_id) {
    return $image_id;
  }
  elsif ($organ eq "flower") {
    #print "organ: $organ, plant_num: $plant_num, type: $type, sample_num: $sample_num\n";
    #die "\nERROR finding image_id...\n";
    return $image_id;
  }
  elsif ($organ eq "mhc_leaf") {
    return $image_id;
  }
  elsif ($organ eq "leaf") {
    #print "organ: $organ, plant_num: $plant_num, type: $type, sample_num: $sample_num\n";
    return $image_id;
  }
  elsif ($organ eq "ovary") {
    #print "organ: $organ, plant_num: $plant_num, type: $type, sample_num: $sample_num\n";
     return $image_id;
     #return "\\N";
  }
  else {
    #die "ERROR finding image_id\norgan: $organ, plant_num: $plant_num, type: $type, sample_num: $sample_num\n";
    return $image_id;
  }

}



#------------------------------------------------------
return 1;
