package CXGN::Pedigree::AddCrosses;

=head1 NAME

CXGN::Pedigree::AddCrosses - a module to add cross experiments.

=head1 USAGE

 my $cross_add = CXGN::Stock::AddCrosses->new({ schema => $schema, location => $location_name, project => $project_name, crosses =>  \@parents_and_cross_types} );
 my $validated = $cross_add->validate_crosses(); #is true when all of the crosses are valid and the accessions they point to exist in the database.
 $cross_add->add_crosses();

=head1 DESCRIPTION

Adds an array of crosses. The stock names used in the cross must already exist in the database, and the verify function does this check.   This module is intended to be used in independent loading scripts and interactive dialogs.

=head1 AUTHORS

 Jeremy D. Edwards (jde22@cornell.edu)

=cut

use Moose;
use MooseX::FollowPBP;
use Moose::Util::TypeConstraints;
use Try::Tiny;
use Bio::GeneticRelationships::Pedigree;
use Bio::GeneticRelationships::Individual;
use CXGN::Stock::StockLookup;

class_type 'Pedigree', { class => 'Bio::GeneticRelationships::Pedigree' };
has 'schema' => (
		 is       => 'rw',
		 isa      => 'DBIx::Class::Schema',
		 predicate => 'has_schema',
		 required => 1,
		);
has 'pedigrees' => (isa =>'ArrayRef[Pedigree]', is => 'rw', predicate => 'has_pedigrees');

sub add_crosses {
  my $self = shift;
  my $schema = $self->get_schema();
  my @crosses;

  if (!$self->has_crosses()){
    print STDERR "No crosses to add\n";
    return;
  }

  if (!$self->validate_pedigrees()) {
    print STDERR "Invalid pedigrees in array.  No pedigrees will be added\n";
    return;
  }

  @crosses = @{$self->get_crosses()};

  foreach my $cross (@crosses) {
    my $female_parent_name;
    my $male_parent_name;
    my $female_parent;
    my $male_parent;
    my $cross_type = $pedigree->get_cross_type();
    my $accession_name = $pedigree->get_name();
    my $accession = $self->_get_accession($accession_name);

    if ($pedigree->has_female_parent()) {
      $female_parent_name = $pedigree->get_female_parent()->get_name();
      $female_parent = $self->_get_accession($female_parent_name);
    }

    if ($pedigree->has_male_parent()) {
      $male_parent_name = $pedigree->get_male_parent()->get_name();
      $male_parent = $self->_get_accession($male_parent_name)
    }



  }

  return 1;
}

sub validate_pedigrees {
  my $self = shift;
  my $schema = $self->get_schema();
  my @crosses;
  my $invalid_cross_count = 0;

  if (!$self->has_crosses()){
    print STDERR "No crosses to add\n";
    return;
  }

  if (!$self->has_pedigrees()) {
    return;
  }

  @pedigrees = @{$self->get_pedigrees()};

  foreach my $cross (@crosses) {
    my $validated_crosses = $self->_validate_crosses($crosses);

    if (!$validated_crosses) {
      $invalid_cross_count++;
    }

  }

  if ($invalid_cross_count > 0) {
    print STDERR "There were $invalid_cross_count invalid crosses\n";
    return;
  }

  return 1;
}

sub _validate_cross {
  my $self = shift;
  my $pedigree = shift;
  my $schema = $self->get_schema();
  my $name = $pedigree->get_name();
  my $cross_type = $pedigree->get_cross_type();
  my $female_parent_name;
  my $male_parent_name;
  my $female_parent;
  my $male_parent;
  my $accession = $self->_get_accession($name);

  if (!$accession) {
    print STDERR "Accession name is not a stock\n";
    return;
  }

  if ($cross_type eq "biparental") {
    $female_parent_name = $pedigree->get_female_parent()->get_name();
    $male_parent_name = $pedigree->get_male_parent()->get_name();
    $female_parent = $self->_get_accession($female_parent_name);
    $male_parent = $self->_get_accession($male_parent_name);

    if (!$female_parent || !$male_parent) {
      print STDERR "Parent $female_parent_name or $male_parent_name in pedigree is not a stock\n";
      return;
    }

  } elsif ($cross_type eq "self") {
    $female_parent_name = $pedigree->get_female_parent()->get_name();
    $female_parent = $self->_get_accession($female_parent_name);

    if (!$female_parent) {
      print STDERR "Parent $female_parent_name in pedigree is not a stock\n";
      return;
    }

  }

  else {
    return;
  }

  return 1;
}

sub _get_accession {
  my $self = shift;
  my $accession_name = shift;
  my $schema = $self->get_schema();
  my $stock_lookup = CXGN::Stock::StockLookup->new(schema => $schema);
  my $stock;
  my $accession_cvterm = $schema->resultset("Cv::Cvterm")
    ->create_with({
		   name   => 'accession',
		   cv     => 'stock type',
		   db     => 'null',
		   dbxref => 'accession',
		  });
  $stock_lookup->set_stock_name($accession_name);
  $stock = $stock_lookup->get_stock_exact();

  if (!$stock) {
    print STDERR "Name in pedigree is not a stock\n";
    return;
  }

  if ($stock->type_id() != $accession_cvterm->cvterm_id()) {
    print STDERR "Name in pedigree is not a stock of type accession\n";
    return;
  }

  return $stock;
}

#######
1;
#######
