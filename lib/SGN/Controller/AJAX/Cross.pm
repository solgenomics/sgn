
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
use CXGN::Pedigree::AddProgeny;
use CXGN::Pedigree::AddCrossInfo;
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
    #$c->stash->{cross_name} = $cross_name;
    my $program = $c->req->param('program');
    #$c->stash->{program} = $program;
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
    my $progeny_add;
    my @progeny_names;
    my @array_of_pedigree_objects;
    my $progeny_increment = 1;
    my $paternal_parent_not_required;
    my $number_of_flowers_cvterm;
    my $number_of_seeds_cvterm;


    if ($cross_type eq "open" || $cross_type eq "bulk_open") {
      $paternal_parent_not_required = 1;
    }

    print STDERR "Adding Cross... Maternal: $maternal Paternal: $paternal Cross Type: $cross_type\n";

    if (!$c->user()) { 
	print STDERR "User not logged in... not adding a cross.\n";
	$c->stash->{rest} = {error => "You need to be logged in to add a cross." };
	return;
    }

    if (!any { $_ eq "curator" || $_ eq "submitter" } ($c->user()->roles)  ) {
        print STDERR "User's roles: ".Dumper($c->user()->roles)."\n";
	print STDERR "User does not have sufficient privileges.\n";
	$c->stash->{rest} = {error =>  "you have insufficient privileges to add a cross." };
	return;
    }

    #check that progeny number is an integer less than maximum allowed
    my $maximum_progeny_number = 999; #higher numbers break cross name convention
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

    #objects to store cross information
    my $cross_to_add = Bio::GeneticRelationships::Pedigree->new(name => $cross_name, cross_type => $cross_type);
    my $female_individual = Bio::GeneticRelationships::Individual->new(name => $maternal);
    my $male_individual = Bio::GeneticRelationships::Individual->new(name => $paternal);
    $cross_to_add->set_female_parent($female_individual);
    $cross_to_add->set_male_parent($male_individual);
    $cross_to_add->set_cross_type($cross_type);
    $cross_to_add->set_name($cross_name);

    #create array of pedigree objects to add, in this case just one pedigree
    @array_of_pedigree_objects = ($cross_to_add);
    $cross_add = CXGN::Pedigree::AddCrosses->new({
					       schema => $schema,
					       location => $location,
					       program => $program,
					       crosses =>  \@array_of_pedigree_objects},
						);

    #add the crosses
    $cross_add->add_crosses();

    #create progeny if specified
    if ($progeny_number) {

      #create array of progeny names to add for this cross
      while ($progeny_increment < $progeny_number + 1) {
	$progeny_increment = sprintf "%03d", $progeny_increment;
	my $stock_name = $cross_name.$prefix.$progeny_increment.$suffix;
	push @progeny_names, $stock_name;
	$progeny_increment++;
      }

      #add array of progeny to the cross
      $progeny_add = CXGN::Pedigree::AddProgeny
	->new({
	       schema => $schema,
	       cross_name => $cross_name,
	       progeny_names => \@progeny_names,
	      });
      $progeny_add->add_progeny();

    }

    #add number of flowers as an experimentprop if specified
    if ($number_of_flowers) {
      my $cross_add_info = CXGN::Pedigree::AddCrossInfo->new({ schema => $schema, cross_name => $cross_name} );
      $cross_add_info->set_number_of_flowers($number_of_flowers);
      $cross_add_info->add_info();
    }

    #add number of seeds as an experimentprop if specified
    if ($number_of_seeds) {
      my $cross_add_info = CXGN::Pedigree::AddCrossInfo->new({ schema => $schema, cross_name => $cross_name} );
      $cross_add_info->set_number_of_seeds($number_of_seeds);
      $cross_add_info->add_info();
    }

    if ($@) {
	$c->stash->{rest} = { error => "An error occurred: $@"};
    }

    $c->stash->{rest} = { error => '', };
  }

###
1;#
###
