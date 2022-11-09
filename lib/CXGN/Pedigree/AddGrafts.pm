

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

package CXGN::Pedigree::AddGrafts;

use Moose;

use Try::Tiny;
use Data::Dumper;
use CXGN::Stock::StockLookup;
use SGN::Model::Cvterm;

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

has 'scion' => (isa => 'Str', is => 'rw');
has 'rootstock' => (isa => 'Str', is => 'rw');

sub add_grafts {
    my $self = shift;
    my $separator_string = shift || "+";
    my $schema = $self->schema();
    my %return_errors;

    my $transaction_error = "";
    my $graft;
    my $coderef = sub {
        #print STDERR "Getting cvterms...\n";
        # get cvterms for scion and rootstock
        my $scion_of_cvterm = SGN::Model::Cvterm->get_cvterm_row($self->schema(), 'scion_of', 'stock_relationship');
        my $rootstock_of_cvterm = SGN::Model::Cvterm->get_cvterm_row($self->schema(), 'rootstock_of', 'stock_relationship');
	my $accession_cvterm = SGN::Model::Cvterm->get_cvterm_row($self->schema(), 'accession', 'stock_type');
	
	my $scion_row = $schema->resultset('Stock::Stock')->find( { uniquename => $self->scion });

	my $rootstock_row = $schema->resultset('Stock::Stock')->find( { uniquename => $self->rootstock() });

	my @errors;

	
	if ($scion_row && $rootstock_row) {
	    $graft = join("", $self->scion(), $separator_string, $self->rootstock());

	    my $graft_row = $schema->resultset('Stock::Stock')->find( { uniquename => $graft });

	    if ($graft_row) {
		push @errors, "The name for the graft $graft already exists in the database, not storing.\n";
	    }
	    else {
	        $graft_row = $self->schema->resultset('Stock::Stock')->create(
		    {
			name => $graft,
			uniquename => $graft,
			type_id => $accession_cvterm->cvterm_id()
		    });
	    }

	    my $sr = $self->schema()->resultset('Stock::StockRelationship')->find_or_create(
		{
		    type_id => $scion_of_cvterm->cvterm_id(),
		    object_id => $graft_row->stock_id(),
		    subject_id => $scion_row->stock_id(),
		});

	    my $sr2 = $self->schema()->resultset('Stock::StockRelationship')->find_or_create(
		{
		    type_id => $rootstock_of_cvterm->cvterm_id(),
		    object_id => $graft_row->stock_id(),
		    subject_id => $rootstock_row->stock_id(),
		});
	}
	else {
	    if (!$scion_row) {
		die "The scion ".$self->scion()." does not exist in the database.";
	    }
	    if (!$rootstock_row) {
		die "The rootstock ".$self->rootstock()." does not exist in the database.";
	    }
	}

	## TO DO: Need to add an attribute that this is a graft
    };

    # try to add all crosses in a transaction
    try {
        print STDERR "Performing database operations... \n";
        $self->schema()->txn_do($coderef);
        print STDERR "Done.\n";
    } catch {
        $transaction_error =  $_;
    };

    if ($transaction_error) {
        $return_errors{error} = "Transaction error creating pedigrees: $transaction_error";
        print STDERR "Transaction error creating pedigrees: $transaction_error\n";
        return { errors => \%return_errors };
    }
    print STDERR "Returning new graft $graft\n";
    return { errors => \%return_errors, graft => $graft };
}

sub validate_grafts {
    my $self = shift;
    my $separator_string = shift || '+';
    
    my $schema = $self->schema();
    my %return_errors;

    my $scion_row = $schema->resultset('Stock::Stock')->find( { uniquename => $self->scion() });
    
    my $rootstock_row = $schema->resultset('Stock::Stock')->find( { uniquename => $self->rootstock() });
    
    my @errors;
    my @messages;
    
    if ($scion_row && $rootstock_row) {
	my $graft = join("", $self->scion, $separator_string, $self->rootstock);
	
	my $graft_row = $schema->resultset('Stock::Stock')->find( { uniquename => $graft });
	
	if ($graft_row) {
	    push @messages, "The name for the graft $graft already exists in the database, not storing.\n";
	}

	if (!$scion_row) {
	    push @errors,  "The scion ". $self->scion()." does not exist in the database.";
	}
	if (!$rootstock_row) {
	    push @errors, "The rootstock ".$self->rootstock()." does not exist in the database.";
	}

	$return_errors{error} = join(", ", @errors);
	
	return { errors => \%return_errors, messages => \@messages };
    }
}



#######
1;
#######
