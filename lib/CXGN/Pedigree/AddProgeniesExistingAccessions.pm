package CXGN::Pedigree::AddProgeniesExistingAccessions;

=head1 NAME

CXGN::Pedigree::AddProgeniesExistingAccessions - a module to create relationship between progenies and cross, as well as to create pedigree by using accessions already stored in database.

=head1 USAGE

 my $progeny_add = CXGN::Pedigree::AddProgeniesExistingAccessions->new({ chado_schema => $schema, cross_name => $cross_name, progeny_names => \@progeny_names} );
 $progeny_add->add_progenies_existing_accessions();

=head1 DESCRIPTION

Adds progenies to a cross by using existing accessions in the database. The cross must already exist in the database, and the verify function does this check.   This module is intended to be used in independent loading scripts and interactive dialogs.

=head1 AUTHORS

=cut

use Moose;
use MooseX::FollowPBP;
use Moose::Util::TypeConstraints;
use Try::Tiny;
use CXGN::Stock::StockLookup;
use SGN::Model::Cvterm;

has 'chado_schema' => (
		 is       => 'rw',
		 isa      => 'DBIx::Class::Schema',
		 predicate => 'has_chado_schema',
		 required => 1,
		);
has 'cross_name' => (isa =>'Str', is => 'rw', predicate => 'has_cross_name', required => 1,);
has 'progeny_names' => (isa =>'ArrayRef[Str]', is => 'rw', predicate => 'has_progeny_names', required => 1,);

sub add_progenies_existing_accessions {
    my $self = shift;
	my $overwrite_pedigrees = shift;
    my $chado_schema = $self->get_chado_schema();
    my @progeny_names = @{$self->get_progeny_names()};
    my $cross_stock;
    my $female_parent;
    my $male_parent;
    my $transaction_error;
	my %return;

    #add all progeny in a single transaction
    my $coderef = sub {

        my $female_parent_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'female_parent', 'stock_relationship');

        my $male_parent_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema,  'male_parent', 'stock_relationship');

        my $offspring_of_cvterm =  SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'offspring_of', 'stock_relationship');

        my $accession_cvterm =  SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'accession', 'stock_type');

        my $cross_name_cvterm =  SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'cross', 'stock_type');

       #Get stock of type cross matching cross name
        $cross_stock = $self->_get_cross($self->get_cross_name());
        if (!$cross_stock) {
            print STDERR "Cross could not be found\n";
            return;
        }

        $female_parent = $chado_schema->resultset("Stock::StockRelationship")
            ->find ({
                object_id => $cross_stock->stock_id(),
                type_id => $female_parent_cvterm->cvterm_id(),
            });

        $male_parent = $chado_schema->resultset("Stock::StockRelationship")
            ->find ({
                object_id => $cross_stock->stock_id(),
                type_id => $male_parent_cvterm->cvterm_id(),
            });

        foreach my $progeny_name (@progeny_names) {
            my $progeny_rs = $self->_get_progeny_name($progeny_name);
            if (!$progeny_rs) {
                print STDERR "Progeny name could not be found\n";
                return;
            }

            if ($female_parent) {
                if ($overwrite_pedigrees) {
				    my $previous_female_parent = $chado_schema->resultset('Stock::StockRelationship')->search({
				        type_id => $female_parent_cvterm->cvterm_id(),
				        object_id => $progeny_rs->stock_id(),
			        });
				    while(my $r = $previous_female_parent->next()){
					    print STDERR "Deleted female parent stock_relationship_id: ".$r->stock_relationship_id."\n";
					    $r->delete();
				    }
                }
		        $progeny_rs->find_or_create_related('stock_relationship_objects', {
                    type_id => $female_parent_cvterm->cvterm_id(),
                    object_id => $progeny_rs->stock_id(),
                    subject_id => $female_parent->subject_id(),
                    value => $female_parent->value(),
                });
            }

			if ($male_parent) {
                if ($overwrite_pedigrees) {
				    my $previous_male_parent = $chado_schema->resultset('Stock::StockRelationship')->search({
				        type_id => $male_parent_cvterm->cvterm_id(),
				        object_id => $progeny_rs->stock_id(),
			        });
				    while(my $r = $previous_male_parent->next()){
					    print STDERR "Deleted male parent stock_relationship_id: ".$r->stock_relationship_id."\n";
					    $r->delete();
				    }
                }
	       	    $progeny_rs->find_or_create_related('stock_relationship_objects', {
	                type_id => $male_parent_cvterm->cvterm_id(),
	                object_id => $progeny_rs->stock_id(),
	                subject_id => $male_parent->subject_id(),
	            });
            }

			#create relationship to cross
            $progeny_rs->find_or_create_related('stock_relationship_objects', {
                type_id => $offspring_of_cvterm->cvterm_id(),
                object_id => $cross_stock->stock_id(),
                subject_id => $progeny_rs->stock_id(),
            });
        }
    };

    #try to add all crosses in a transaction
    try {
        $chado_schema->txn_do($coderef);
    } catch {
        $transaction_error =  $_;
    };

    if ($transaction_error) {
		$return{error} = "Transaction error adding progenies: $transaction_error";
		return \%return;
    }

	return \%return;
}


sub _get_cross {
    my $self = shift;
    my $cross_name = shift;
    my $chado_schema = $self->get_chado_schema();
    my $stock_lookup = CXGN::Stock::StockLookup->new(schema => $chado_schema);
    my $stock;

    $stock_lookup->set_stock_name($cross_name);
    $stock = $stock_lookup->get_cross_exact();

    if (!$stock) {
        print STDERR "Cross name does not exist\n";
        return;
    }

    return $stock;
}


sub _get_progeny_name {
    my $self = shift;
    my $progeny_name = shift;
    my $chado_schema = $self->get_chado_schema();
    my $stock_lookup = CXGN::Stock::StockLookup->new(schema => $chado_schema);
    my $stock;

    $stock_lookup->set_stock_name($progeny_name);
    $stock = $stock_lookup->get_accession_exact();

    if (!$stock) {
        print STDERR "Progeny name does not exist\n";
        return;
    }

    return $stock;
}


#######
1;
#######
