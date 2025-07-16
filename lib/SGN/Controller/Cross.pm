
=head1 NAME

SGN::Controller::AJAX::Cross - a REST controller class to provide the
backend for objects linked with new cross

=head1 DESCRIPTION

Add submit new cross, etc...

=head1 AUTHOR

Jeremy Edwards <jde22@cornell.edu>
Lukas Mueller <lam87@cornell.edu>


=cut

package SGN::Controller::Cross;

use Moose;

use List::MoreUtils qw /any /;
use Try::Tiny;
use CXGN::Phenome::Schema;
use CXGN::Phenome::Allele;
use CXGN::Chado::Stock;
use CXGN::Page::FormattingHelpers qw/ columnar_table_html info_table_html html_alternate_show /;
use CXGN::Pedigree::AddProgeny;
use Scalar::Util qw(looks_like_number);
use File::Slurp;
use SGN::Model::Cvterm;
use File::Temp;
use File::Basename qw | basename dirname|;
use File::Spec::Functions;

BEGIN { extends 'Catalyst::Controller'; }

has 'schema' => (
		 is       => 'rw',
		 isa      => 'DBIx::Class::Schema',
		 lazy_build => 1,
		);
sub _build_schema {
  shift->_app->dbic_schema( 'Bio::Chado::Schema', 'sgn_chado' )
}

sub upload_cross :  Path('/cross/upload_cross')  Args(0) {
   my ($self, $c) = @_;
   my $upload = $c->req->upload('upload_file');
   my $visible_to_role = $c->req->param('visible_to_role');
   my $format_type = $c->req->param('format_type');
   my $basename = $upload->basename;
   my $tempfile = $upload->tempname;
   my $header_error;
   my %line_errors;
   my %upload_data;
   my $file_error = 0;
   my @contents = split /\n/, $upload->slurp;
   print STDERR "loading cross file: $tempfile Basename: $basename $format_type $visible_to_role\n";
   $c->stash->{tempfile} = $tempfile;
   if ($format_type eq "spreadsheet") {
     print STDERR "is spreadsheet \n";

     if (!$c->user()) {
       print STDERR "User not logged in... not adding crosses.\n";
       $c->stash->{rest} = {error => "You need to be logged in to add a cross." };
       return;
     }

    if (!any { $_ eq "curator" || $_ eq "submitter" } ($c->user()->roles)  ) {
	print STDERR "User does not have sufficient privileges.\n";
	$c->stash->{rest} = {error =>  "you have insufficient privileges to add a cross." };
	return;
    }

     my $first_line = shift(@contents);
     my @first_row = split /\t/, $first_line;
     if ($first_row[0] ne 'cross_name' ||
	 $first_row[1] ne 'cross_type' ||
	 $first_row[2] ne 'maternal_parent' ||
	 $first_row[3] ne 'paternal_parent' ||
	 $first_row[4] ne 'trial' ||
	 $first_row[5] ne 'location' ||
	 $first_row[6] ne 'number_of_progeny' ||
	 $first_row[7] ne 'prefix' ||
	 $first_row[8] ne 'suffix' ||
	 $first_row[9] ne 'number_of_flowers' ||
	 $first_row[10] ne 'number_of_seeds') {
       $header_error = "<b>Error in header:</b><br>Header should contain the following tab-delimited fields:<br>cross_name<br>cross_type<br>maternal_parent<br>paternal_parent<br>trial<br>location<br>number_of_progeny<br>prefix<br>suffix<br>number_of_flowers<br>number_of_seeds<br>";
       print STDERR "$header_error\n";
     }
     else {
       my $line_number = 0;
       foreach my $line (@contents) {
	 $line_number++;
	 my @row = split /\t/, $line;
	 if (scalar(@row) < 6) {
	   $line_errors{$line_number} = "Line $line_number has too few columns\n";
	 }
	 elsif (!$row[0] || !$row[1] || !$row[2] || !$row[3] || !$row[4] || !$row[5]) {
	   $line_errors{$line_number} = "Line $line_number is missing a required field\n";
	 }
	 else {
	   my %cross;
	   $cross{'cross_name'} = $row[0];
	   $cross{'cross_type'} = $row[1];
	   $cross{'maternal_parent'} = $row[2];
	   $cross{'paternal_parent'} = $row[3];
	   $cross{'cross_trial'} = $row[4];
	   $cross{'cross_location'} = $row[5];
	   if ($row[5]) {$cross{'number_of_progeny'} = $row[6];}
	   if ($row[6]) {$cross{'prefix'} = $row[7];}
	   if ($row[7]) {$cross{'suffix'} = $row[8];}
	   if ($row[8]) {$cross{'number_of_flowers'} = $row[9];}
	   if ($row[9]) {$cross{'number_of_seeds'} = $row[10];}
	   my $line_verification = _verify_cross($c,\%cross, \%line_errors, $line_number);
	   if ($line_verification) {
	     print STDERR "Verified\n";
	     $upload_data{$line_number}=\%cross;
	   }
	   else {
	     print STDERR "Not verified\n";
	   }
	 }
       }
     }

#     $c->stash(
#	       tempfile => $tempfile,
#	       template => '/breeders_toolbox/cross/upload_crosses_confirm_spreadsheet.mas',
#	      );
   } elsif ($format_type eq "barcode") {
#     $c->stash(
#	       tempfile => $tempfile,
#	       template => '/breeders_toolbox/cross/upload_crosses_confirm_barcode.mas',
#	      );
   }
   else {
     print STDERR "Upload file format type $format_type not recognized\n";
   }

   if (%line_errors || $header_error) {


     $c->stash(
	       file_name => $basename,
	       header_error => $header_error,
	       line_errors_ref => \%line_errors,
	       template => '/breeders_toolbox/cross/upload_crosses_file_error.mas',
	       );
     #print STDERR "there are errors in the upload file\n$line_errors_string";
   }
   else {#file is valid
     my $number_of_crosses_added = 0;
     my $number_of_unique_parents = 0;
     my %unique_parents;
     foreach my $line (@contents) {
       my %cross;
       my @row = split /\t/, $line;
       $cross{'cross_name'} = $row[0];
       $cross{'cross_type'} = $row[1];
       $cross{'maternal_parent'} = $row[2];
       $cross{'paternal_parent'} = $row[3];
       $cross{'cross_trial'} = $row[4];
       $cross{'cross_location'} = $row[5];
       if ($row[6]) {
	 $cross{'number_of_progeny'} = $row[6];
       }
       if ($row[7]) {
	 $cross{'prefix'} = $row[7];
       }
       if ($row[8]) {
	 $cross{'suffix'} = $row[8];
       }
       if ($row[9]) {
	 $cross{'number_of_flowers'} = $row[9];
       }
       if ($row[10]) {
	 $cross{'number_of_seeds'} = $row[10];
       }
       $cross{'visible_to_role'} = $visible_to_role;
       _add_cross($c,\%cross);
       $number_of_crosses_added++;
       $unique_parents{$cross{'maternal_parent'}} = 1;
       $unique_parents{$cross{'paternal_parent'}} = 1;
     }

     foreach my $parent (keys %unique_parents) {
       $number_of_unique_parents++;
     }
     $c->stash(
	       number_of_crosses_added => $number_of_crosses_added,
	       number_of_unique_parents => $number_of_unique_parents,
	       upload_data_ref => \%upload_data,
	       template => '/breeders_toolbox/cross/upload_crosses_confirm_spreadsheet.mas',
	      );
   }

}

sub _verify_cross {
  my $c = shift;
  my $cross_ref = shift;
  my $error_ref = shift;
  my $line_number = shift;
  my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
  my $is_verified = 0;
  my $cross_name = $cross_ref->{'cross_name'};
  my $cross_type = $cross_ref->{'cross_type'};
  my $maternal_parent = $cross_ref->{'maternal_parent'};
  my $paternal_parent = $cross_ref->{'paternal_parent'};
  my $cross_trial = $cross_ref->{'cross_trial'};
  my $cross_location = $cross_ref->{'cross_location'};
  my $max_progeny = 20000;
  my $max_flowers = 10000;
  my $max_seeds = 10000;
  #print STDERR "name: ".$cross_ref->{'cross_name'}."\n";
  if (! $schema->resultset("Stock::Stock")->find({name=>$maternal_parent,})){
    $error_ref->{$line_number} .= "Line number $line_number, Maternal parent $maternal_parent does not exist in database\n <br>";
    }
  if ($cross_type ne "biparental" && $cross_type ne "self" && $cross_type ne "open" && $cross_type ne "bulk" && $cross_type ne "bulk_self" && $cross_type ne "bulk_open" && $cross_type ne "doubled_haploid" && $cross_type ne "dihaploid_induction") {
    $error_ref->{$line_number} .= "Line number $line_number, Cross type $cross_type is not valid\n <br>";
  }
  if ($cross_type eq "self" || $cross_type eq "bulk_self" || $cross_type eq "doubled_haploid" || $cross_type eq "dihaploid_induction") {
    if ($maternal_parent ne $paternal_parent) {
      $error_ref->{$line_number} .= "Line number $line_number, maternal and paternal parents must match for cross type $cross_type\n <br>";
    }
  }
  if (! $schema->resultset("Stock::Stock")->find({name=>$paternal_parent,})){
    $error_ref->{$line_number} .= "Line number $line_number, Paternal parent $paternal_parent does not exist in database\n <br>";
    }
  if (! $schema->resultset("Project::Project")->find({name=>$cross_trial,})){
    $error_ref->{$line_number} .= "Line number $line_number, Trial $cross_trial does not exist in database\n <br>";
    }
  if (! $schema->resultset("NaturalDiversity::NdGeolocation")->find({description=>$cross_location,})){
    $error_ref->{$line_number} .= "Line number $line_number, Location $cross_location does not exist in database\n <br>";
    }
  #check that cross name does not already exist
  if ($schema->resultset("Stock::Stock")->find({name=>$cross_name})){
    $error_ref->{$line_number} .= "Line number $line_number, Cross $cross_name already exists in database\n <br>";
  }
  if ($cross_ref->{'number_of_progeny'}) {
    if ($cross_ref->{'number_of_progeny'}  =~ /^[0-9]+$/) { #is an integer
      if ($cross_ref->{'number_of_progeny'} > $max_progeny || $cross_ref->{'number_of_progeny'} < 1) {
	$error_ref->{$line_number} .= "Line number $line_number, Number of progeny ". $cross_ref->{'number_of_progeny'}." exceeds the maximum of $max_progeny or is invalid\n <br>";
      }
    } else {
      $error_ref->{$line_number} .= "Line number $line_number, Number of progeny ". $cross_ref->{'number_of_progeny'}." is not an integer\n <br>";
    }
  }
  if ($cross_ref->{'number_of_flowers'}) {
    if ($cross_ref->{'number_of_flowers'}  =~ /^[0-9]+$/) { #is an integer
      if ($cross_ref->{'number_of_flowers'} > $max_flowers || $cross_ref->{'number_of_flowers'} < 1) {
	$error_ref->{$line_number} .= "Line number $line_number, Number of flowers ". $cross_ref->{'number_of_flowers'}." exceeds the maximum of $max_flowers or is invalid\n <br>";
      }
    } else {
      $error_ref->{$line_number} .= "Line number $line_number, Number of flowers ". $cross_ref->{'number_of_flowers'}." is not an integer\n <br>";
    }
  }
  if ($cross_ref->{'number_of_seeds'}) {
    if ($cross_ref->{'number_of_seeds'}  =~ /^[0-9]+$/) { #is an integer
      if ($cross_ref->{'number_of_seeds'} > $max_seeds || $cross_ref->{'number_of_seeds'} < 1) {
	$error_ref->{$line_number} .= "Line number $line_number, Number of seeds ". $cross_ref->{'number_of_seeds'}." exceeds the maximum of $max_seeds or is invalid\n <br>";
      }
    } else {
      $error_ref->{$line_number} .= "Line number $line_number, Number of seeds ". $cross_ref->{'number_of_seeds'}." is not an integer\n <br>";
    }
  }
  if ($cross_ref->{'prefix'} =~ m/\-/) {
	$error_ref->{$line_number} .= "Line number $line_number, Prefix ". $cross_ref->{'prefix'}." contains an illegal character: -\n <br>";
  }
  if ($cross_ref->{'suffix'} =~ m/\-/) {
	$error_ref->{$line_number} .= "Line number $line_number, Suffix ". $cross_ref->{'suffix'}." contains an illegal character: -\n <br>";
  }
  if ($error_ref->{$line_number}) {print $error_ref->{$line_number}."\n";return;} else {return 1;}
}

sub _add_cross {
  my $c = shift;
  my $cross_ref = shift;
  my %cross = %{$cross_ref};
  my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
  my $cross_name = $cross{'cross_name'};
  my $cross_type =  $cross{'cross_type'};
  my $maternal_parent =  $cross{'maternal_parent'};
  my $paternal_parent =  $cross{'paternal_parent'};
  my $trial =  $cross{'cross_trial'};
  my $location =  $cross{'cross_location'};
  my $number_of_progeny = $cross{'number_of_progeny'};#check if exists
  my $prefix = $cross{'prefix'};#check if exists
  my $suffix = $cross{'suffix'};#check if exists
  my $number_of_flowers = $cross{'number_of_flowers'};#check if exists
  my $number_of_seeds = $cross{'number_of_seeds'};#check if exists
  my $visible_to_role = $cross{'visible_to_role'};
  my $geolocation = $schema->resultset("NaturalDiversity::NdGeolocation")->find({description=>$location,});
  my $project = $schema->resultset("Project::Project")->find({name=>$trial,});
  my $accession_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type');

  my $population_cvterm = $schema->resultset("Cv::Cvterm")->find(
      { name   => 'cross',
      });

  my $cross_type_cvterm =  SGN::Model::Cvterm->get_cvterm_row($schema, 'cross_type', 'nd_experiment_property');

  my $female_parent_stock = $schema->resultset("Stock::Stock")->find(
								     { name       => $maternal_parent,
								     } );
  my $organism_id = $female_parent_stock->organism_id();

  my $male_parent_stock = $schema->resultset("Stock::Stock")->find(
								   { name       => $paternal_parent,
								   } );
  my $population_stock = $schema->resultset("Stock::Stock")->find_or_create(
      { organism_id => $organism_id,
	name       => $cross_name,
	uniquename => $cross_name,
	type_id => $population_cvterm->cvterm_id,
      } );
  my $female_parent =  SGN::Model::Cvterm->get_cvterm_row($schema, 'female_parent', 'stock_relationship');

  my $male_parent =  SGN::Model::Cvterm->get_cvterm_row($schema, 'male_parent', 'stock_relationship');

  ## change 'cross_name' to a more explicit term

  my $population_members =  SGN::Model::Cvterm->get_cvterm_row($schema, 'cross_relationship', 'stock_relationship');

  my $visible_to_role_cvterm =  SGN::Model::Cvterm->get_cvterm_row($schema, 'visible_to_role', 'local');

  my $number_of_flowers_cvterm =  SGN::Model::Cvterm->get_cvterm_row($schema, 'number_of_flowers', 'nd_experiment_property');

  my $number_of_seeds_cvterm =  SGN::Model::Cvterm->get_cvterm_row($schema,'number_of_seeds','nd_experiment_property');

  my $experiment = $schema->resultset('NaturalDiversity::NdExperiment')->create(
      {
	  nd_geolocation_id => $geolocation->nd_geolocation_id(),
	  type_id => $population_cvterm->cvterm_id(),
      } );
  #link to the project
  $experiment->find_or_create_related('nd_experiment_projects', {
      project_id => $project->project_id()
				      } );
  #link the experiment to the stock
  $experiment->find_or_create_related('nd_experiment_stocks' , {
      stock_id => $population_stock->stock_id(),
      type_id  =>  $population_cvterm->cvterm_id(),
				      });
  if ($number_of_flowers) {
      #set flower number in experimentprop
      $experiment->find_or_create_related('nd_experimentprops' , {
	  nd_experiment_id => $experiment->nd_experiment_id(),
	  type_id  =>  $number_of_flowers_cvterm->cvterm_id(),
	  value  =>  $number_of_flowers,
					  });
  }
  if ($number_of_seeds) {
      #set seed number in experimentprop
      $experiment->find_or_create_related('nd_experimentprops' , {
	  nd_experiment_id => $experiment->nd_experiment_id(),
	  type_id  =>  $number_of_seeds_cvterm->cvterm_id(),
	  value  =>  $number_of_seeds,
					  });
  }

  if ($cross_type) {
      $experiment->find_or_create_related('nd_experimentprops' , {
	  nd_experiment_id => $experiment->nd_experiment_id(),
	  type_id  =>  $cross_type_cvterm->cvterm_id(),
	  value  =>  $cross_type,
					  });
  }

  ############
  #if progeny number exists
  my $increment = 1;
  while ($increment < $number_of_progeny + 1) {
      $increment = sprintf "%03d", $increment;
    my $stock_name = $prefix.$cross_name."_".$increment.$suffix;
    my $accession_stock = $schema->resultset("Stock::Stock")->create(
	{ organism_id => $organism_id,
	  name       => $stock_name,
	  uniquename => $stock_name,
	  type_id     => $accession_cvterm->cvterm_id,
	} );
      $accession_stock->find_or_create_related('stock_relationship_objects', {
	  type_id => $female_parent->cvterm_id(),
	  object_id => $accession_stock->stock_id(),
	  subject_id => $female_parent_stock->stock_id(),
					       } );
      $accession_stock->find_or_create_related('stock_relationship_objects', {
	  type_id => $male_parent->cvterm_id(),
	  object_id => $accession_stock->stock_id(),
	  subject_id => $male_parent_stock->stock_id(),
					       } );
      $accession_stock->find_or_create_related('stock_relationship_objects', {
	  type_id => $population_members->cvterm_id(),
	  object_id => $accession_stock->stock_id(),
	  subject_id => $population_stock->stock_id(),
					       } );
      #######################
      #link the experiment to the progeny


    if ($visible_to_role) {
	my $accession_stock_prop = $schema->resultset("Stock::Stockprop")->find_or_create(
	    { type_id =>$visible_to_role_cvterm->cvterm_id(),
	      value => $visible_to_role,
	      stock_id => $accession_stock->stock_id()
	    });
    }
      $increment++;

  }

  if ($@) {
      $c->stash->{rest} = { error => "An error occurred: $@"};
  }

  $c->stash->{rest} = { error => '', };


}

sub make_cross_form :Path("/stock/cross/new") :Args(0) {
    my ($self, $c) = @_;
    $c->stash->{template} = '/breeders_toolbox/new_cross.mas';
    if ($c->user()) {
      my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
      # get projects
      my @rows = $schema->resultset('Project::Project')->all();
      my @projects = ();
      foreach my $row (@rows) {
	push @projects, [ $row->project_id, $row->name, $row->description ];
      }
      $c->stash->{project_list} = \@projects;
      @rows = $schema->resultset('NaturalDiversity::NdGeolocation')->all();
      my @locations = ();
      foreach my $row (@rows) {
	push @locations,  [ $row->nd_geolocation_id,$row->description ];
      }
      $c->stash->{locations} = \@locations;


    }
    else {
      $c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
      return;
    }
}


sub make_cross :Path("/stock/cross/generate") :Args(0) {
    my ($self, $c) = @_;
    $c->stash->{template} = '/breeders_toolbox/progeny_from_crosses.mas';
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $cross_name = $c->req->param('cross_name');
    $c->stash->{cross_name} = $cross_name;
    my $trial_id = $c->req->param('trial_id');
    $c->stash->{trial_id} = $trial_id;
    #my $location = $c->req->param('location_id');
    my $maternal = $c->req->param('maternal');
    my $paternal = $c->req->param('paternal');
    my $prefix = $c->req->param('prefix');
    my $suffix = $c->req->param('suffix');
    my $progeny_number = $c->req->param('progeny_number');
    my $visible_to_role = $c->req->param('visible_to_role');

    if (! $c->user()) { # redirect
	$c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
	return;
    }


    #check that progeny number is an integer less than maximum allowed
    my $maximum_progeny_number = 1000;
    if ((! $progeny_number =~ m/^\d+$/) or ($progeny_number > $maximum_progeny_number)){
      #redirect to error page?
      return;
    }

    #check that parent names are not blank
    if ($maternal eq "" or $paternal eq "") {
      return;
    }

    #check that parents exist in the database
    if (! $schema->resultset("Stock::Stock")->find({name=>$maternal,})){
      return;
    }
    if (! $schema->resultset("Stock::Stock")->find({name=>$paternal,})){
      return;
    }

    #check that cross name does not already exist
    if ($schema->resultset("Stock::Stock")->find({name=>$cross_name})){
      return;
    }

    #check that progeny do not already exist
    if ($schema->resultset("Stock::Stock")->find({name=>$prefix.$cross_name.$suffix."-1",})){
      return;
    }

    my $organism = $schema->resultset("Organism::Organism")->find_or_create(
    {
	genus   => 'Manihot',
	species => 'Manihot esculenta',
    } );
    my $organism_id = $organism->organism_id();

    my $accession_cvterm =  SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type');


    my $population_cvterm = $schema->resultset("Cv::Cvterm")->find(
      { name   => 'population',
    });


    my $female_parent_stock = $schema->resultset("Stock::Stock")->find(
	{ name       => $maternal,
	} );

    my $male_parent_stock = $schema->resultset("Stock::Stock")->find(
            { name       => $paternal,
            } );

    my $population_stock = $schema->resultset("Stock::Stock")->find_or_create(
            { organism_id => $organism_id,
	      name       => $cross_name,
	      uniquename => $cross_name,
	      type_id => $population_cvterm->cvterm_id,
            } );
      my $female_parent =  SGN::Model::Cvterm->get_cvterm_row($schema, 'female_parent', 'stock_relationship');

      my $male_parent =  SGN::Model::Cvterm->get_cvterm_row($schema, 'male_parent', 'stock_relationship');

      my $population_members =  SGN::Model::Cvterm->get_cvterm_row($schema, 'cross_name', 'stock_relationship');

      my $visible_to_role_cvterm =  SGN::Model::Cvterm->get_cvterm_row($schema,  'visible_to_role', 'local');

    my $increment = 1;
    while ($increment < $progeny_number + 1) {
	my $stock_name = $prefix.$cross_name."-".$increment.$suffix;
      my $accession_stock = $schema->resultset("Stock::Stock")->create(
            { organism_id => $organism_id,
              name       => $stock_name,
              uniquename => $stock_name,
              type_id     => $accession_cvterm->cvterm_id,
            } );
      $accession_stock->find_or_create_related('stock_relationship_objects', {
		type_id => $female_parent->cvterm_id(),
		object_id => $accession_stock->stock_id(),
		subject_id => $female_parent_stock->stock_id(),
	 					  } );
      $accession_stock->find_or_create_related('stock_relationship_objects', {
		type_id => $male_parent->cvterm_id(),
		object_id => $accession_stock->stock_id(),
		subject_id => $male_parent_stock->stock_id(),
	 					  } );
      $accession_stock->find_or_create_related('stock_relationship_objects', {
		type_id => $population_members->cvterm_id(),
		object_id => $accession_stock->stock_id(),
		subject_id => $population_stock->stock_id(),
	 					  } );
      if ($visible_to_role ne "") {
	my $accession_stock_prop = $schema->resultset("Stock::Stockprop")->find_or_create(
	       { type_id =>$visible_to_role_cvterm->cvterm_id(),
		 value => $visible_to_role,
		 stock_id => $accession_stock->stock_id()
		 });
      }
      $increment++;

    }
    if ($@) {
    }
}

sub cross_detail : Path('/cross') Args(1) {
    my $self = shift;
    my $c = shift;
    my $id = shift;
    my $cross_type_id = SGN::Model::Cvterm->get_cvterm_row($c->dbic_schema("Bio::Chado::Schema"), 'cross', 'stock_type')->cvterm_id();

    #get cross from stock id
    my $cross = $c->dbic_schema("Bio::Chado::Schema")->resultset("Stock::Stock")->search( { stock_id => $id, type_id => $cross_type_id } )->first();

    if (!$cross) { #or from project id
        $cross = $c->dbic_schema("Bio::Chado::Schema")->resultset("Project::Project")->search({ 'me.project_id' => $id })->search_related('nd_experiment_projects')->search_related('nd_experiment')->search_related('nd_experiment_stocks')->search_related('stock', {'stock.type_id'=>$cross_type_id})->first();
    }

    my $cross_id;

    if (!$cross) {
    	$c->stash->{template} = '/generic_message.mas';
    	$c->stash->{message} = 'The requested cross does not exist.';
    	return;
    } else {
        $cross_id = $cross->stock_id();
    }

    #print STDERR "Cross stock_id is $cross_id\n";

    my $progeny = $c->dbic_schema("Bio::Chado::Schema")->resultset("Stock::StockRelationship") -> search( { object_id => $cross_id, 'type.name' => 'offspring_of'  }, { join =>  'type' } );

    my $progeny_count = $progeny->count();

    $c->stash->{cross_name} = $cross->uniquename();
    $c->stash->{user_id} = $c->user ? $c->user->get_object()->get_sp_person_id() : undef;
    $c->stash->{cross_id} = $cross_id;
    $c->stash->{progeny_count} = $progeny_count;
    $c->stash->{template} = '/breeders_toolbox/cross/index.mas';

}

sub cross_wishlist_download : Path('/cross_wishlist/file_download/') Args(1) {
    my $self  =shift;
    my $c = shift;
    my $file_id = shift;
    my $metadata_schema = $c->dbic_schema('CXGN::Metadata::Schema');
    my $file_row = $metadata_schema->resultset("MdFiles")->find({file_id => $file_id});
    my $file_destination =  catfile($file_row->dirname, $file_row->basename);
    my $contents = read_file($file_destination);
    my $file_name = $file_row->basename;
    $c->res->content_type('Application/xls');
    $c->res->header('Content-Disposition', qq[attachment; filename="$file_name"]);
    $c->res->body($contents);
}


sub family_name_detail : Path('/family') Args(1) {
    my $self = shift;
    my $c = shift;
    my $id = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $family_stock_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'family_name', 'stock_type')->cvterm_id();
    my $family_type_id = SGN::Model::Cvterm->get_cvterm_row($schema,  'family_type', 'stock_property')->cvterm_id();

    #get family_name from stock id
    my $family = $schema->resultset("Stock::Stock")->find( { stock_id => $id, type_id => $family_stock_type_id } );

    my $family_id;
    my $family_name;
    my $family_type;
    my $family_type_string;
	if (!$family) {
    	$c->stash->{template} = '/generic_message.mas';
    	$c->stash->{message} = 'The requested family name does not exist.';
    	return;
    } else {
        $family_id = $family->stock_id();
        $family_name = $family->uniquename();
        my $family_prop = $schema->resultset("Stock::Stockprop")->find({ stock_id => $family_id, type_id => $family_type_id});

        if ($family_prop){
            $family_type = $family_prop->value();
            if ($family_type eq 'same_parents'){
                $family_type_string = 'This family includes only crosses having the same female parent and the same male parent';
            } elsif ($family_type eq 'reciprocal_parents'){
                $family_type_string = 'This family includes reciprocal crosses';
            }
        }
    }

    $c->stash->{family_name} = $family_name;
    $c->stash->{user_id} = $c->user ? $c->user->get_object()->get_sp_person_id() : undef;
    $c->stash->{family_id} = $family_id;
    $c->stash->{family_type} = $family_type;
    $c->stash->{family_type_string} = $family_type_string;
    $c->stash->{template} = '/breeders_toolbox/cross/family.mas';

}


1;
