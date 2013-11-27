package CXGN::Pedigree::AddPedigrees;

=head1 NAME

CXGN::Pedigree::AddPedigrees - a module to add pedigrees to accessions.

=head1 USAGE

 my $pedigree_add = CXGN::Stock::AddPedigrees->new({ schema => $schema, pedigrees => \@pedigrees} );
 my $validated = $pedigree_add->validate_pedigrees(); #is true when all of the pedigrees are valid and the accessions they point to exist in the database.
 $pedigree_add->add_pedigrees();

=head1 DESCRIPTION

Adds an array of pedigrees. The stock names used in the pedigree must already exist in the database, and the verify function does this check.   This module is intended to be used in independent loading scripts and interactive dialogs.

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

sub add_pedigrees {
  my $self = shift;
  my $schema = $self->get_schema();
  if (!$self->validate_pedigrees()) {
    print STDERR "Invalid pedigrees in array.  No pedigrees will be added\n";
    return;
  }
  return 1;
}

sub validate_pedigrees {
  my $self = shift;
  my $schema = $self->get_schema();
  my @pedigrees;
  my $invalid_pedigree_count = 0;
  if (!$self->has_pedigrees()) {
    return;
  }
  @pedigrees = $self->get_pedigrees();
  foreach my $pedigree (@pedigrees) {
    my $validated_pedigree = $self->_validate_pedigree($pedigree);
    if (!$validated_pedigree) {
      $invalid_pedigree_count++;
    }
  }
  if ($invalid_pedigree_count > 0) {
    print STDERR "There were $invalid_pedigree_count invalid pedigrees\n";
    return;
  }
  return 1;
}

sub _validate_pedigree {
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
