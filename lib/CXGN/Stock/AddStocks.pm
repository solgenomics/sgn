package CXGN::Stock::AddStocks;;

=head1 NAME

CXGN::Stock::AddStocks - a module to add a list of stocks.

=head1 USAGE

 my $stock_add = CXGN::Stock::AddStock->new({ schema => $schema, stocks => \@stocks, species => $species_name} );
 my $validated = $stock_add->validate_accessions();
 $stock_add->add_accessions();

=head1 DESCRIPTION

Adds an array of stocks. The stock names must not already exist in the database, and the verify function does this check.   This module is intended to be used in independent loading scripts and interactive dialogs.  Stock types "accession" and "plot" are supported by the methods add_accessions() and add_plots().

=head1 AUTHORS

 Jeremy D. Edwards (jde22@cornell.edu)

=cut

use Moose;
use MooseX::FollowPBP;
use Moose::Util::TypeConstraints;
use Try::Tiny;

has 'schema' => (
		 is       => 'rw',
		 isa      => 'DBIx::Class::Schema',
		 lazy_build => 1,
		 predicate => 'has_schema',
		);
has 'stocks' => (isa => 'ArrayRef', is => 'rw', predicate => 'has_stocks');
has 'species' => (isa => 'Str', is => 'rw', predicate => 'has_species');

sub add_accessions {
  my $self = shift;
  my $added = $self->_add_stocks('accession');
  return $added;
}

sub add_plots {
  my $self = shift;
  my $added = $self->_add_stocks('plot');
  return $added;
}

sub _add_stocks {
  my $self = shift;
  my $stock_type = shift;
  if (!$self->verify_accessions()) {
    return;
  }
  my $schema = $self->get_schema();
  my $species = $self->get_species();
  my $stocks_rs = $self->get_stocks();
  my @stocks = @$stocks_rs;

  my $organism = $schema->resultset("Organism::Organism")
    ->find({
	    species => $species,
	   } );
  my $organism_id = $organism->organism_id();

  my $coderef = sub {


    my $stock_cvterm = $schema->resultset("Cv::Cvterm")
      ->create_with({
		     name   => $stock_type,
		     cv     => 'stock type',
		     db     => 'null',
		     dbxref => $stock_type,
		    });


    foreach my $stock_name (@stocks) {
      my $stock = $schema->resultset("Stock::Stock")
	->create({
		  organism_id => $organism_id,
		  name       => $stock_name,
		  uniquename => $stock_name,
		  type_id     => $stock_cvterm->cvterm_id,
		 } );
    }
  };

  my $transaction_error;
  try {
    $schema->txn_do($coderef);
  } catch {
    $transaction_error =  $_;
  };
  if ($transaction_error) {
    print STDERR "Transaction error storing stocks: $transaction_error\n";
    return;
  }
  else {
    return 1;
  }
}

sub verify_accessions {
  my $self = shift;
  if (!$self->has_schema() || !$self->has_species() || !$self->has_stocks()) {
    return;
  }
  my $schema = $self->get_schema();
  my $species = $self->get_species();
  my $stocks_rs = $self->get_stocks();
  my @stocks = @$stocks_rs;

  my $name_conflicts = 0;
  foreach my $stock_name (@stocks) {
    my $stock_search = $schema->resultset("Stock::Stock")
      ->search({
		uniquename => $stock_name,
	       } );
    if ($stock_search->first()) {
      $name_conflicts++;
      print STDERR "Stock name conflict for: $stock_name\n";
    }
  }

  if ($name_conflicts > 0) {
    print STDERR "There were $name_conflicts conflict(s)\n";
    return;
  }

  return 1;
}

#######
1;
#######
