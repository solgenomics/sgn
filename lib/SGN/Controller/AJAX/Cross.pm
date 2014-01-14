
=head1 NAME

SGN::Controller::AJAX::Cross - a REST controller class to provide the
backend for objects linked with new cross

=head1 DESCRIPTION

Add submit new cross, etc...

=head1 AUTHOR

Jeremy Edwards <jde22@cornell.edu>
Lukas Mueller <lam87@cornell.edu>


=cut

package SGN::Controller::AJAX::Cross;

use Moose;

use List::MoreUtils qw /any /;
use Try::Tiny;
use CXGN::Phenome::Schema;
use CXGN::Phenome::Allele;
use CXGN::Chado::Stock;
use CXGN::Page::FormattingHelpers qw/ columnar_table_html info_table_html html_alternate_show /;
use Scalar::Util qw(looks_like_number);
use Data::Dumper;
use CXGN::UploadFile;
use Spreadsheet::WriteExcel;
use CXGN::Pedigree::AddCrosses;
use Bio::GeneticRelationships::Pedigree;
use Bio::GeneticRelationships::Individual;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );





sub upload_cross_file : Path('/ajax/cross/upload_crosses_file') : ActionClass('REST') { }

sub upload_cross_file_POST : Args(0) {
  my ($self, $c) = @_;
  my $uploader = CXGN::UploadFile->new();
  my $parser = CXGN::Phenotypes::ParseUpload->new();
}


sub add_cross : Local : ActionClass('REST') { }

sub add_cross_POST :Args(0) { 
    my ($self, $c) = @_;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $cross_name = $c->req->param('cross_name');
    my $cross_type = $c->req->param('cross_type');
    $c->stash->{cross_name} = $cross_name;
    my $program = $c->req->param('program');
    $c->stash->{program} = $program;
    my $location = $c->req->param('location');
    my $maternal = $c->req->param('maternal_parent');
    my $paternal = $c->req->param('paternal_parent');
    my $prefix = $c->req->param('prefix');
    my $suffix = $c->req->param('suffix');
    my $progeny_number = $c->req->param('progeny_number');
    my $number_of_flowers = $c->req->param('number_of_flowers');
    my $number_of_seeds = $c->req->param('number_of_seeds');
    my $visible_to_role = $c->req->param('visible_to_role');
    my $cross_add;
    my @array_of_pedigree_objects;

    my $paternal_parent_not_required;
    if ($cross_type eq "open" || $cross_type eq "bulk_open") {
      $paternal_parent_not_required = 1;
    }

    if (!$c->user()) { 
	print STDERR "User not logged in... not adding a cross.\n";
	$c->stash->{rest} = {error => "You need to be logged in to add a cross." };
	return;
    }

    if (!any { $_ eq "curator" || $_ eq "submitter" } ($c->user()->roles)  ) {
	print STDERR "User does not have sufficient privileges.\n";
	$c->stash->{rest} = {error =>  "you have insufficient privileges to add a cross." };
	return;
    }

    #check that progeny number is an integer less than maximum allowed
    my $maximum_progeny_number = 999; #higher numbers break cross name conventionn
    if ($progeny_number) {
      if ((! $progeny_number =~ m/^\d+$/) or ($progeny_number > $maximum_progeny_number) or ($progeny_number < 1)) {
	$c->stash->{rest} = {error =>  "progeny number exceeds the maximum of $maximum_progeny_number or is invalid." };
	return;
      }
    }

    #check that maternal name is not blank
    if ($maternal eq "") {
      $c->stash->{rest} = {error =>  "maternal parent name cannot be blank." };
      return;
    }

    #if required, check that paternal parent name is not blank;
    if ($paternal eq "" && !$paternal_parent_not_required) {
      $c->stash->{rest} = {error =>  "paternal parent name cannot be blank." };
      return;
    }

    #check that parents exist in the database
    if (! $schema->resultset("Stock::Stock")->find({name=>$maternal,})){
      $c->stash->{rest} = {error =>  "maternal parent does not exist." };
      return;
    }

    if (! $schema->resultset("Stock::Stock")->find({name=>$paternal,})){
      $c->stash->{rest} = {error =>  "paternal parent does not exist." };
      return;
    }

    #check that cross name does not already exist
    if ($schema->resultset("Stock::Stock")->find({name=>$cross_name})){
      $c->stash->{rest} = {error =>  "cross name already exists." };
      return;
    }

    #check that progeny do not already exist
    if ($schema->resultset("Stock::Stock")->find({name=>$prefix.$cross_name.$suffix."-1",})){
      $c->stash->{rest} = {error =>  "progeny already exist." };
      return;
    }


    my $cross_to_add = Bio::GeneticRelationships::Pedigree->new(name => $cross_name, cross_type => $cross_type);
    my $female_individual = Bio::GeneticRelationships::Individual->new(name => $maternal);
    my $male_individual = Bio::GeneticRelationships::Individual->new(name => $paternal);
    $cross_to_add->set_female_parent($female_individual);
    $cross_to_add->set_male_parent($male_individual);
    $cross_to_add->set_cross_type($cross_type);
    $cross_to_add->set_name($cross_name);

    @array_of_pedigree_objects = ($cross_to_add);
    $cross_add = CXGN::Pedigree::AddCrosses->new({
					       schema => $schema,
					       location => $location,
					       program => $program,
					       crosses =>  \@array_of_pedigree_objects} );
    $cross_add->add_crosses();




   #  my $geolocation = $schema->resultset("NaturalDiversity::NdGeolocation")->find_or_create(
   #         {
   #              nd_geolocation_id => $location_id,
   #         } ) ;

   #  my $project;

   #  if ($program_id && $program_id ne 'null') {
   # 	$project = $schema->resultset("Project::Project")
   # 	    ->find_or_create(
   # 			     {
   # 			      project_id => $program_id,
   # 			     } ) ;
   #  }


   #   my $accession_cvterm = $schema->resultset("Cv::Cvterm")->create_with(
   #     { name   => 'accession',
   #     cv     => 'stock type',
   #     db     => 'null',
   #     dbxref => 'accession',
   #   });

   #   #my $population_cvterm = $schema->resultset("Cv::Cvterm")->find(
   #   #  { name   => 'population',
   #   #});

   #  my $population_cvterm = $schema->resultset("Cv::Cvterm")->find(
   #    { name   => 'cross',
   #  });


   #  my $female_parent_stock = $schema->resultset("Stock::Stock")->find(
   #          { name       => $maternal,
   #          } );

   #  my $organism_id = $female_parent_stock->organism_id();

   #  my $male_parent_stock = $schema->resultset("Stock::Stock")->find(
   #          { name       => $paternal,
   #          } );

   #  my $population_stock = $schema->resultset("Stock::Stock")->find_or_create(
   #          { organism_id => $organism_id,
   # 	      name       => $cross_name,
   # 	      uniquename => $cross_name,
   # 	      type_id => $population_cvterm->cvterm_id,
   #          } );

   #    my $female_parent = $schema->resultset("Cv::Cvterm")->create_with(
   #  { name   => 'female_parent',
   #    cv     => 'stock relationship',
   #    db     => 'null',
   #    dbxref => 'female_parent',
   #  });

   #    my $male_parent = $schema->resultset("Cv::Cvterm")->create_with(
   #  { name   => 'male_parent',
   #    cv     => 'stock relationship',
   #    db     => 'null',
   #    dbxref => 'male_parent',
   #  });

   #    my $population_members = $schema->resultset("Cv::Cvterm")->create_with(
   #  { name   => 'cross_name',
   #    cv     => 'stock relationship',
   #    db     => 'null',
   #    dbxref => 'cross_name',
   #  });

   #    my $visible_to_role_cvterm = $schema->resultset("Cv::Cvterm")->create_with(
   #  { name   => 'visible_to_role',
   #    cv => 'local',
   #    db => 'null',
   #  });

   # my $number_of_flowers_cvterm = $schema->resultset("Cv::Cvterm")->create_with(
   #    { name   => 'number_of_flowers',
   # 	cv     => 'local',
   # 	db     => 'null',
   # 	dbxref => 'number_of_flowers',
   #  });

   # my $number_of_seeds_cvterm = $schema->resultset("Cv::Cvterm")->create_with(
   #    { name   => 'number_of_seeds',
   # 	cv     => 'local',
   # 	db     => 'null',
   # 	dbxref => 'number_of_seeds',
   #  });

   # my $cross_type_cvterm = $schema->resultset("Cv::Cvterm")->create_with(
   #    { name   => 'cross_type',
   # 	cv     => 'local',
   # 	db     => 'null',
   # 	dbxref => 'cross_type',
   #  });


   #  my $experiment = $schema->resultset('NaturalDiversity::NdExperiment')->create(
   #          {
   #              nd_geolocation_id => $geolocation->nd_geolocation_id(),
   #              type_id => $population_cvterm->cvterm_id(),
   #          } );

   #  if ($project) {
   # 	#link to the project
   # 	$experiment->find_or_create_related('nd_experiment_projects', {
   # 								       project_id => $project->project_id()
   # 								      } );
   #  }

   #  #link the experiment to the stock
   #  $experiment->find_or_create_related('nd_experiment_stocks' , {
   # 	    stock_id => $population_stock->stock_id(),
   # 	    type_id  =>  $population_cvterm->cvterm_id(),
   #                                         });

   #  if ($cross_type) {
   #    $experiment->find_or_create_related('nd_experimentprops' , {
   # 								  nd_experiment_id => $experiment->nd_experiment_id(),
   # 								  type_id  =>  $cross_type_cvterm->cvterm_id(),
   # 								  value  =>  $cross_type,
   # 								 });
   #  }

   #  if ($number_of_flowers) {
   #    #set flower number in experimentprop
   #    $experiment->find_or_create_related('nd_experimentprops' , {
   # 								  nd_experiment_id => $experiment->nd_experiment_id(),
   # 								  type_id  =>  $number_of_flowers_cvterm->cvterm_id(),
   # 								  value  =>  $number_of_flowers,
   # 								 });
   #  }

   #  if ($number_of_seeds) {
   #    $experiment->find_or_create_related('nd_experimentprops' , {
   # 								  nd_experiment_id => $experiment->nd_experiment_id(),
   # 								  type_id  =>  $number_of_seeds_cvterm->cvterm_id(),
   # 								  value  =>  $number_of_seeds,
   # 								 });
   #  }

   #  my $increment = 1;
   #  if ($progeny_number) {
   #    while ($increment < $progeny_number + 1) {
   # 	  $increment = sprintf "%03d", $increment;
   # 	my $stock_name = $prefix.$cross_name."_".$increment.$suffix;
   # 	my $accession_stock = $schema->resultset("Stock::Stock")->create(
   # 									 { organism_id => $organism_id,
   # 									   name       => $stock_name,
   # 									   uniquename => $stock_name,
   # 									   type_id     => $accession_cvterm->cvterm_id,
   # 									 } );
   # 	$accession_stock->find_or_create_related('stock_relationship_objects', {
   # 										type_id => $female_parent->cvterm_id(),
   # 										object_id => $accession_stock->stock_id(),
   # 										subject_id => $female_parent_stock->stock_id(),
   # 									       } );
   # 	$accession_stock->find_or_create_related('stock_relationship_objects', {
   # 										type_id => $male_parent->cvterm_id(),
   # 										object_id => $accession_stock->stock_id(),
   # 										subject_id => $male_parent_stock->stock_id(),
   # 									       } );
   # 	$accession_stock->find_or_create_related('stock_relationship_objects', {
   # 										type_id => $population_members->cvterm_id(),
   # 										object_id => $accession_stock->stock_id(),
   # 										subject_id => $population_stock->stock_id(),
   # 									       } );
   # 	if ($visible_to_role) {
   # 	  my $accession_stock_prop = $schema->resultset("Stock::Stockprop")->find_or_create(
   # 											    { type_id =>$visible_to_role_cvterm->cvterm_id(),
   # 											      value => $visible_to_role,
   # 											      stock_id => $accession_stock->stock_id()
   # 											    });
   # 	}
   # 	$increment++;

   #    }
   #  }


    if ($@) {
	$c->stash->{rest} = { error => "An error occurred: $@"};
    }

    $c->stash->{rest} = { error => '', };
}


1;
