
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

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );



=head2 add_cross

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub add_cross : Local : ActionClass('REST') { }

sub add_cross_GET :Args(0) { 
    my ($self, $c) = @_;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $cross_name = $c->req->param('cross_name');
    $c->stash->{cross_name} = $cross_name;
    my $trial_id = $c->req->param('trial_id');
    $c->stash->{trial_id} = $trial_id;
    #my $location = $c->req->param('location_id');
    my $maternal = $c->req->param('maternal_parent');
    my $paternal = $c->req->param('paternal_parent');
    my $prefix = $c->req->param('prefix');
    my $suffix = $c->req->param('suffix');
    my $progeny_number = $c->req->param('progeny_number');
    my $visible_to_role = $c->req->param('visible_to_role');

    if (!$c->user()) { 
	print STDERR "User not logged in... not adding a cross.\n";
	$c->stash->{rest} = {error => "You need to be logged in to add a cross." };
	return;
    }

#    if (!any { $_ eq "curator" || $_ eq "submitter" } ($c->user()->roles)  ) { 
#	print STDERR "User does not have sufficient privileges.\n";
#	$c->stash->{rest} = {error =>  "you have insufficient privileges to add a cross." };
#	return;
#    }


    #check that progeny number is an integer less than maximum allowed
    my $maximum_progeny_number = 1000;
    if ((! $progeny_number =~ m/^\d+$/) or ($progeny_number > $maximum_progeny_number)){
      $c->stash->{rest} = {error =>  "progeny number exceeds the maximum of $maximum_progeny_number." };
      return;
    }

    #check that parent names are not blank
    if ($maternal eq "" or $paternal eq "") {
      $c->stash->{rest} = {error =>  "parent names cannot be blank." };
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

    my $organism = $schema->resultset("Organism::Organism")->find_or_create(
    {
	genus   => 'Manihot',
	species => 'Manihot esculenta',
    } );
    my $organism_id = $organism->organism_id();

    my $accession_cvterm = $schema->resultset("Cv::Cvterm")->create_with(
      { name   => 'accession',
      cv     => 'stock type',
      db     => 'null',
      dbxref => 'accession',
    });

    #my $population_cvterm = $schema->resultset("Cv::Cvterm")->find(
    #  { name   => 'population',
    #});

    my $population_cvterm = $schema->resultset("Cv::Cvterm")->find(
      { name   => 'cross',
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
	$c->stash->{rest} = { error => "An error occurred: $@"};
    }

    $c->stash->{rest} = { error => '', };
									
}



1;
