

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

package CXGN::Pedigree::AddPedigrees;

use Moose;
use MooseX::FollowPBP;
use Moose::Util::TypeConstraints;
use Try::Tiny;
use Data::Dumper;
use Bio::GeneticRelationships::Pedigree;
use Bio::GeneticRelationships::Individual;
use CXGN::Stock::StockLookup;

#class_type 'Pedigree', { class => 'Bio::GeneticRelationships::Pedigree' };
has 'schema' => (
		 is       => 'rw',
		 isa      => 'DBIx::Class::Schema',
		 predicate => 'has_schema',
		 required => 1,
		);

=head2 get/set_pedigrees()

 Usage:         
 Desc:         provide a hash of accession_names as keys and pedigree objects as values
 Ret:
 Args:
 Side Effects:
 Example:

=cut

has 'pedigrees' => (isa =>'ArrayRef[Bio::GeneticRelationships::Pedigree]', is => 'rw', predicate => 'has_pedigrees');

sub add_pedigrees {
  my $self = shift;
  my $schema = $self->get_schema();
  my @pedigrees;

  if (!$self->has_pedigrees()){
    print STDERR "No pedigrees to add\n";
    return;
  }

  if (!$self->validate_pedigrees()) {
    print STDERR "Invalid pedigrees in array.  No pedigrees will be added\n";
    return;
  }

  @pedigrees = @{$self->get_pedigrees()};
  
  my @added_stock_ids;
  my $transaction_error = "";

  my $coderef = sub {

      print STDERR "Getting cvterms...\n";
      # get cvterms for parents and offspring
      my $female_parent_cvterm = $self->get_schema()->resultset("Cv::Cvterm")
	  ->create_with( { name   => 'female_parent',
			   cv     => 'stock relationship',
			   db     => 'null',
			   dbxref => 'female_parent',
			 });
      my $male_parent_cvterm = $self->get_schema()->resultset("Cv::Cvterm")
	  ->create_with({ name   => 'male_parent',
			  cv     => 'stock relationship',
			  db     => 'null',
			  dbxref => 'male_parent',
			});
      my $progeny_cvterm = $self->get_schema()->resultset("Cv::Cvterm")
	  ->create_with({ name   => 'offspring_of',
			  cv     => 'stock relationship',
			  db     => 'null',
			  dbxref => 'offspring_of',
			});
      
      # get cvterm for cross_name or create if not found
      my $cross_name_cvterm = $self->get_schema()->resultset("Cv::Cvterm")
	  ->find({
     	      name   => 'cross_name',
		 });
      if (!$cross_name_cvterm) {
	  $cross_name_cvterm = $self->get_schema()->resultset("Cv::Cvterm")
	      ->create_with( { name   => 'cross_name',
			       cv     => 'local',
			       db     => 'null',
			       dbxref => 'cross_name',
			     });
      }
      # get cvterm for cross_type or create if not found
      my $cross_type_cvterm = $self->get_schema()->resultset("Cv::Cvterm")
	  ->find({
     	      name   => 'cross_type',
		 });
      if (!$cross_type_cvterm) {
	  $cross_type_cvterm = $self->get_schema()->resultset("Cv::Cvterm")
	      ->create_with( { name   => 'cross_type',
			       cv     => 'local',
			       db     => 'null',
			       dbxref => 'cross_type',
			     });
      }
      
      
      foreach my $pedigree (@pedigrees) {

	  print STDERR Dumper($pedigree);
	  my $cross_stock;
	  my $organism_id;
	  my $female_parent_name;
	  my $male_parent_name;
	  my $female_parent;
	  my $male_parent;
	  my $cross_type = $pedigree->get_cross_type();

	  if ($pedigree->has_female_parent()) {
	      $female_parent_name = $pedigree->get_female_parent()->get_name();
	      $female_parent = $self->_get_accession($female_parent_name);
	  }
	  
	  if ($pedigree->has_male_parent()) {
	      $male_parent_name = $pedigree->get_male_parent()->get_name();
	      $male_parent = $self->_get_accession($male_parent_name);
	  }

	  my $cross_name = $female_parent_name ."/".$male_parent_name;

	  print STDERR "Creating pedigree $cross_type, $cross_name\n";

	  my $progeny_accession = $self->_get_accession($pedigree->get_name());

	  # organism of cross experiment will be the same as the female parent
	  if ($female_parent) {
	      $organism_id = $female_parent->organism_id();
	  } else {
	      $organism_id = $male_parent->organism_id();
	  }
	  
	  if ($female_parent) {
	      $progeny_accession
		  ->find_or_create_related('stock_relationship_objects', {
		      type_id => $female_parent_cvterm->cvterm_id(),
		      object_id => $progeny_accession->stock_id(),
		      subject_id => $female_parent->stock_id(),
		      value => $cross_type,
					   });
	  }
	  
	  #create relationship to male parent
	  if ($male_parent) {
	      $progeny_accession
		  ->find_or_create_related('stock_relationship_objects', {
		      type_id => $male_parent_cvterm->cvterm_id(),
		      object_id => $progeny_accession->stock_id(),
		      subject_id => $male_parent->stock_id(),
					   });
	  }
	  
	  
	  
	  
      }
      
  };
  
  # try to add all crosses in a transaction
  try {
      print STDERR "Performing database operations... ";
      $self->get_schema()->txn_do($coderef);
      print STDERR "Done.\n";
  } catch {
      $transaction_error =  $_;
  };
  
  if ($transaction_error) {
      die "Transaction error creating a cross: $transaction_error\n";
      return 0;
  }
  
  return 1;
}

sub validate_pedigrees {
    my $self = shift;
  my $schema = $self->get_schema();
  my @pedigrees;
  my $invalid_pedigree_count = 0;
  
  if (!$self->has_pedigrees()){
      print STDERR "No pedigrees to add\n";
    return;
  }
  
  if (!$self->has_pedigrees()) {
      return;
  }
  
  @pedigrees = @{$self->get_pedigrees()};
  
  foreach my $pedigree (@pedigrees) {
      my $validated_pedigree = $self->_validate_pedigree($pedigree);
    
    if (!$validated_pedigree) {
	$invalid_pedigree_count++;
	print STDERR "Invalid pedigree: ".Dumper($pedigree)."\n";
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
  
  if ($cross_type eq "biparental") {
      $female_parent_name = $pedigree->get_female_parent()->get_name();
      if ($pedigree->has_male_parent()) { $male_parent_name = $pedigree->get_male_parent()->get_name(); }
      $female_parent = $self->_get_accession($female_parent_name);
      $male_parent = $self->_get_accession($male_parent_name);
      
      if (!$female_parent || !$male_parent) {
	  print STDERR "Parent $female_parent_name or $male_parent in pedigree is not a stock\n";
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
  elsif ($cross_type eq "open" || $cross_type eq "unknown") { 
      $female_parent_name = $pedigree->get_female_parent()->get_name();
      
  }
  else {
      print STDERR "Cross type not detected... Skipping\n";
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
	print STDERR "Name in pedigree ($accession_name) is not a stock\n";
	return;
    }
    
    if ($stock->type_id() != $accession_cvterm->cvterm_id()) {
	print STDERR "Name in pedigree  ($accession_name) is not a stock of type accession\n";
	return;
    }
    
    return $stock;
}

#######
1;
#######
