
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
use Scalar::Util qw(looks_like_number);
use File::Slurp;

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
	 $first_row[1] ne 'maternal_parent' ||
	 $first_row[2] ne 'paternal_parent' ||
	 $first_row[3] ne 'trial' ||
	 $first_row[4] ne 'location' ||
	 $first_row[5] ne 'number_of_progeny' ||
	 $first_row[6] ne 'prefix' ||
	 $first_row[7] ne 'suffix' ||
	 $first_row[8] ne 'number_of_flowers') {
       $header_error = "<b>Error in header:</b><br>Header should contain the following tab-delimited fields:<br>cross_name<br>maternal_parent<br>paternal_parent<br>trial<br>location<br>number_of_progeny<br>prefix<br>suffix<br>number_of_flowers<br>";
       print STDERR "$header_error\n";
     }
     else {
       my $line_number = 0;
       foreach my $line (@contents) {
	 $line_number++;
	 my @row = split /\t/, $line;
	 if (scalar(@row) < 5) {
	   $line_errors{$line_number} = "Line $line_number has too few columns\n";
	 }
	 elsif (!$row[0] || !$row[1] || !$row[2] || !$row[3] || !$row[4]) {
	   $line_errors{$line_number} = "Line $line_number is missing a required field\n";
	 }
	 else {
	   my %cross;
	   $cross{'cross_name'} = $row[0];
	   $cross{'maternal_parent'} = $row[1];
	   $cross{'paternal_parent'} = $row[2];
	   $cross{'cross_trial'} = $row[3];
	   $cross{'cross_location'} = $row[4];
	   if ($row[5]) {$cross{'number_of_progeny'} = $row[5];}
	   if ($row[6]) {$cross{'prefix'} = $row[6];}
	   if ($row[7]) {$cross{'suffix'} = $row[7];}
	   if ($row[8]) {$cross{'number_of_flowers'} = $row[8];}
	   my $line_verification = _verify_cross($c,\%cross, \%line_errors, $line_number);
	   if ($line_verification) {
	     print STDERR "Verified\n";
	   }
	   else {
	     print STDERR "Not verified\n";
	   }
	 }
       }
     }

#     $c->stash(
#	       tempfile => $tempfile,
#	       template => '/breeders_toolbox/upload_crosses_confirm_spreadsheet.mas',
#	      );
   } elsif ($format_type eq "barcode") {
#     $c->stash(
#	       tempfile => $tempfile,
#	       template => '/breeders_toolbox/upload_crosses_confirm_barcode.mas',
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
	       template => '/breeders_toolbox/upload_crosses_file_error.mas',
	       );
     #print STDERR "there are errors in the upload file\n$line_errors_string";
   }
   else {#file is valid
     foreach my $line (@contents) {
       my %cross;
       my @row = split /\t/, $line;
       $cross{'cross_name'} = $row[0];
       $cross{'maternal_parent'} = $row[1];
       $cross{'paternal_parent'} = $row[2];
       $cross{'cross_trial'} = $row[3];
       $cross{'cross_location'} = $row[4];
       if ($row[5]) {
	 $cross{'number_of_progeny'} = $row[5];
       }
       if ($row[6]) {
	 $cross{'prefix'} = $row[6];
       }
       if ($row[7]) {
	 $cross{'suffix'} = $row[7];
       }
       if ($row[8]) {
	 $cross{'number_of_flowers'} = $row[8];
       }
       $cross{'visible_to_role'} = $visible_to_role;
       _add_cross($c,\%cross);
     }
     #get results from this function;
     $c->stash(
	       template => '/breeders_toolbox/upload_crosses_confirm_spreadsheet.mas',
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
  my $maternal_parent = $cross_ref->{'maternal_parent'};
  my $paternal_parent = $cross_ref->{'paternal_parent'};
  my $cross_trial = $cross_ref->{'cross_trial'};
  my $cross_location = $cross_ref->{'cross_location'};
  my $max_progeny = 20000;
  my $max_flowers = 10000;
  #print STDERR "name: ".$cross_ref->{'cross_name'}."\n";
  if (! $schema->resultset("Stock::Stock")->find({name=>$maternal_parent,})){
    $error_ref->{$line_number} .= "Line number $line_number, Maternal parent $maternal_parent does not exist in database\n <br>";
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
  my $maternal_parent =  $cross{'maternal_parent'};
  my $paternal_parent =  $cross{'paternal_parent'};
  my $trial =  $cross{'cross_trial'};
  my $location =  $cross{'cross_location'};
  my $number_of_progeny = $cross{'number_of_progeny'};#check if exists
  my $prefix = $cross{'prefix'};#check if exists
  my $suffix = $cross{'suffix'};#check if exists
  my $number_of_flowers = $cross{'number_of_flowers'};#check if exists
  my $visible_to_role = $cross{'visible_to_role'};
######################################################
  ###get organism from $c instead
  my $organism = $schema->resultset("Organism::Organism")->find_or_create(
									  {
									   genus   => 'Manihot',
									   species => 'Manihot esculenta',
									  } );
  my $organism_id = $organism->organism_id();
  my $geolocation = $schema->resultset("NaturalDiversity::NdGeolocation")->find({description=>$location,});
  my $project = $schema->resultset("Project::Project")->find({name=>$trial,});
  my $accession_cvterm = $schema->resultset("Cv::Cvterm")->create_with(
								       { name   => 'accession',
									 cv     => 'stock type',
									 db     => 'null',
									 dbxref => 'accession',
								       });
  my $population_cvterm = $schema->resultset("Cv::Cvterm")->find(
								 { name   => 'cross',
								 });

  my $female_parent_stock = $schema->resultset("Stock::Stock")->find(
								     { name       => $maternal_parent,
								     } );
  my $male_parent_stock = $schema->resultset("Stock::Stock")->find(
								   { name       => $paternal_parent,
								   } );
  my $population_stock = $schema->resultset("Stock::Stock")->find_or_create(
									    { organism_id => $organism_id,
									      name       => $cross_name,
									      uniquename => $cross_name,
									      type_id => $population_cvterm->cvterm_id,
									    } );
  my $female_parent = $schema->resultset("Cv::Cvterm")->create_with(
								    { name   => 'female_parent',
								      cv     => 'stock relationship',
								      db     => 'null',
								      dbxref => 'female_parent',
								    });
  my $male_parent = $schema->resultset("Cv::Cvterm")->create_with(
								  { name   => 'male_parent',
								    cv     => 'stock relationship',
								    db     => 'null',
								    dbxref => 'male_parent',
								  });
  my $population_members = $schema->resultset("Cv::Cvterm")->create_with(
									 { name   => 'cross_name',
									   cv     => 'stock relationship',
									   db     => 'null',
									   dbxref => 'cross_name',
									 });
  my $visible_to_role_cvterm = $schema->resultset("Cv::Cvterm")->create_with(
									     { name   => 'visible_to_role',
									       cv => 'local',
									       db => 'null',
									     });
  my $number_of_flowers_cvterm = $schema->resultset("Cv::Cvterm")->create_with(
									   { name   => 'number_of_flowers',
									     cv     => 'local',
									     db     => 'null',
									     dbxref => 'number_of_flowers',
									   });
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
  ############
  #if progeny number exists
  my $increment = 1;
  while ($increment < $number_of_progeny + 1) {
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


1;
