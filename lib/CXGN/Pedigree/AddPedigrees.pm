

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
use Bio::GeneticRelationships::Population;
use CXGN::Stock::StockLookup;
use SGN::Model::Cvterm;
use CXGN::Genotype::PedigreeCheck;


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
    my $overwrite_pedigrees = shift;
    my $schema = $self->get_schema();
    my @pedigrees;
    my %return;

		print STDERR "adding pedigrees\n";
    @pedigrees = @{$self->get_pedigrees()};
    #print STDERR Dumper \@pedigrees;

    my @added_stock_ids;
    my $transaction_error = "";

    my $coderef = sub {
        #print STDERR "Getting cvterms...\n";
        # get cvterms for parents and offspring
        my $female_parent_cvterm = SGN::Model::Cvterm->get_cvterm_row($self->get_schema(), 'female_parent', 'stock_relationship');
        my $male_parent_cvterm = SGN::Model::Cvterm->get_cvterm_row($self->get_schema(), 'male_parent', 'stock_relationship');

      ####These are probably not necessary:
      #######################
      #my $progeny_cvterm = SGN::Model::Cvterm->get_cvterm_row($self->get_schema(), 'offspring_of', 'stock_relationship');

      # get cvterm for cross_relationship
      #my $cross_relationship_cvterm = SGN::Model::Cvterm->get_cvterm_row($self->get_schema(), 'cross_relationship', 'stock_relationship');

      # get cvterm for cross_type
      #my $cross_type_cvterm = SGN::Model::Cvterm->get_cvterm_row($self->get_schema(), 'cross_type', 'nd_experiment_property');
      ##########################

        my ($accessions_hash_ref, $accessions_and_populations_hash_ref) = $self->_get_available_stocks();
        my %accessions_hash = %{$accessions_hash_ref};
        my %accessions_and_populations_hash = %{$accessions_and_populations_hash_ref};
 
        foreach my $pedigree (@pedigrees) {

            #print STDERR Dumper($pedigree);
            my $cross_stock;
            my $organism_id;
            my $female_parent_name;
            my $male_parent_name;
            my $female_parent;
            my $male_parent;
            my $cross_type = $pedigree->get_cross_type();

            if ($pedigree->has_female_parent()) {
                $female_parent_name = $pedigree->get_female_parent()->get_name();
                $female_parent = $accessions_hash{$female_parent_name};
                if (!$female_parent){
                    push @{$return{error}}, ""
                }
            }

            if ($pedigree->has_male_parent()) {
                $male_parent_name = $pedigree->get_male_parent()->get_name();
                $male_parent = $accessions_and_populations_hash{$male_parent_name};
            }

            my $cross_name = $pedigree->get_name();

            print STDERR "Creating pedigree $cross_type, $cross_name\n";

            my $progeny_accession = $accessions_hash{$pedigree->get_name()};

            # organism of cross experiment will be the same as the female parent
            if ($female_parent) {
                $organism_id = $female_parent->[1];
            } else {
                $organism_id = $male_parent->[1];
            }

            if ($female_parent) {
                if ($overwrite_pedigrees){
                    my $previous_female_parent = $self->get_schema->resultset('Stock::StockRelationship')->search({
                        type_id => $female_parent_cvterm->cvterm_id(),
                        object_id => $progeny_accession->[0],
                    });
                    while(my $r = $previous_female_parent->next()){
                        print STDERR "Deleted female parent stock_relationship_id: ".$r->stock_relationship_id."\n";
                        $r->delete();
                    }
                }
                $self->get_schema->resultset('Stock::StockRelationship')->create({
                    type_id => $female_parent_cvterm->cvterm_id(),
                    object_id => $progeny_accession->[0],
                    subject_id => $female_parent->[0],
                    value => $cross_type,
                });
            }

            #create relationship to male parent
            if ($male_parent) {
                if ($overwrite_pedigrees){
                    my $previous_male_parent = $self->get_schema->resultset('Stock::StockRelationship')->search({
                        type_id => $male_parent_cvterm->cvterm_id(),
                        object_id => $progeny_accession->[0],
                    });
                    while(my $r = $previous_male_parent->next()){
                        print STDERR "Deleted male parent stock_relationship_id: ".$r->stock_relationship_id."\n";
                        $r->delete();
                    }
                }
                $self->get_schema->resultset('Stock::StockRelationship')->create({
                    type_id => $male_parent_cvterm->cvterm_id(),
                    object_id => $progeny_accession->[0],
                    subject_id => $male_parent->[0],
                });
            }

            print STDERR "Successfully added pedigree ".$pedigree->get_name()."\n";
        }
    };

    # try to add all crosses in a transaction
    try {
        print STDERR "Performing database operations... \n";
        $self->get_schema()->txn_do($coderef);
        print STDERR "Done.\n";
    } catch {
        $transaction_error =  $_;
    };

    if ($transaction_error) {
        $return{error} = "Transaction error creating a cross: $transaction_error";
        print STDERR "Transaction error creating a cross: $transaction_error\n";
        return \%return;
    }

    return \%return;
}

sub validate_pedigrees {
    my $self = shift;
		my $protocol_id = shift;
		print STDERR "my protocol id is $protocol_id\n";

		my $schema = $self->get_schema();
    my %return;

    if (!$self->has_pedigrees()){
        $return{error} = "No pedigrees to add";
        return \%return;
    }

    my ($accessions_hash_ref, $accessions_and_populations_hash_ref) = $self->_get_available_stocks();
    my %accessions_hash = %{$accessions_hash_ref};
    my %accessions_and_populations_hash = %{$accessions_and_populations_hash_ref};

    my $female_parent_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->get_schema(), 'female_parent', 'stock_relationship')->cvterm_id;
    my $male_parent_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->get_schema(), 'male_parent', 'stock_relationship')->cvterm_id;

		print STDERR "getting pedigrees\n";
    my @pedigrees = @{$self->get_pedigrees()};

    my @progeny_stock_ids;
    my %progeny_stock_ids_hash;
    foreach my $pedigree (@pedigrees) {
        my $progeny_name = $pedigree->get_name();
        my $cross_type = $pedigree->get_cross_type();
        my $progeny = $accessions_hash{$progeny_name};
        if (!$progeny){
            push @{$return{error}}, "Progeny name $progeny_name missing or not found as an accession in database.";
        } else {
            push @progeny_stock_ids, $progeny->[0];
            $progeny_stock_ids_hash{$progeny->[0]} = $progeny_name;
        }

        if (!$pedigree->get_female_parent()){
            push @{$return{error}}, "Pedigree not structured correctly";
        }

        my $female_parent_name = $pedigree->get_female_parent()->get_name();
        if (!$female_parent_name) {
            push @{$return{error}}, "Female parent not provided for $progeny_name.";
        }
        my $female_parent = $accessions_hash{$female_parent_name};
        if (!$female_parent) {
            push @{$return{error}}, "Female parent not found for $progeny_name.";
        }

        if ($cross_type ne 'biparental' && $cross_type ne 'self' && $cross_type ne 'open'){
            push @{$return{error}}, "cross_type must be either biparental, self, or open for progeny $progeny_name.";
        }
        if ($cross_type eq 'biparental' || $cross_type eq 'self'){
            if (!$pedigree->get_male_parent){
                push @{$return{error}}, "Male parent not provided for $progeny_name and cross type is $cross_type.";
            }
            my $male_parent_name = $pedigree->get_male_parent()->get_name();
            if (!$male_parent_name) {
                push @{$return{error}}, "Male parent not provided for $progeny_name and cross type is $cross_type.";
            }
            my $male_parent = $accessions_and_populations_hash{$male_parent_name};
            if (!$male_parent) {
                push @{$return{error}}, "Male parent not found for $progeny_name.";
            }
        }
        if ($cross_type eq 'open'){
            if ($pedigree->get_male_parent){
                if ($pedigree->get_male_parent()->get_name()){
                    my $male_parent_name = $pedigree->get_male_parent()->get_name();
                    my $male_parent = $accessions_and_populations_hash{$male_parent_name};
                    if (!$male_parent) {
                        push @{$return{error}}, "Male parent not found for $progeny_name.";
                    }
                }
            }
        }
    }

    my $progeny_female_parent_search = $schema->resultset('Stock::StockRelationship')->search({
        type_id => $female_parent_cvterm_id,
        object_id => { '-in'=>\@progeny_stock_ids },
    });
    my %progeny_with_female_parent_already;
    while (my $r=$progeny_female_parent_search->next){
        $progeny_with_female_parent_already{$r->object_id} = [$r->subject_id, $r->value];
    }
    my $progeny_male_parent_search = $schema->resultset('Stock::StockRelationship')->search({
        type_id => $male_parent_cvterm_id,
        object_id => { '-in'=>\@progeny_stock_ids },
    });
    my %progeny_with_male_parent_already;
    while (my $r=$progeny_male_parent_search->next){
        $progeny_with_male_parent_already{$r->object_id} = $r->subject_id;
    }
    foreach (@progeny_stock_ids){
        if (exists($progeny_with_female_parent_already{$_})){
            push @{$return{error}}, $progeny_stock_ids_hash{$_}." already has female parent stockID ".$progeny_with_female_parent_already{$_}->[0]." saved with cross type ".$progeny_with_female_parent_already{$_}->[1];
        }
        if (exists($progeny_with_male_parent_already{$_})){
            push @{$return{error}}, $progeny_stock_ids_hash{$_}." already has male parent stockID ".$progeny_with_male_parent_already{$_};
        }
    }

		my $mother_lookup = CXGN::Stock::StockLookup->new(schema => $schema);
		$mother_lookup->set_stock_name($female_parent_name);
		my $mother_lookup_result = $mother_lookup->get_stock_exact();
		my $mother_id = $mother_lookup_result->stock_id();

		my $father_lookup = CXGN::Stock::StockLookup->new(schema => $schema);
		$father_lookup->set_stock_name($male_parent_name);
		my $father_lookup_result = $father_lookup->get_stock_exact();
		my $father_id = $father_lookup_result->stock_id();

		print STDERR "progeny name is $progeny_name\n";

		my $conflict_object = CXGN::Genotype::PedigreeCheck->new({schema=>$schema, accession_name => $progeny_name, mother_id => $mother_id, father_id => $father_id, protocol_id => $protocol_id});
		my $conflict_return = $conflict_object->pedigree_check();
		my $conflict_score = $conflict_return->{'score'};

		if ($conflict_score >= .03){
			push @{$return{error}}, "$conflict_score% of markers are in conflict indiciating that at least one parent of $progeny_name may be incorrect.";
		}
		else{
			push @{$return{message}}, "$conflict_score% of markers are in conflict indiciating that the pedigree of $progeny_name is likely correct.";
		}
    return \%return;
}

sub _get_available_stocks {
    my $self = shift;
    my $schema = $self->get_schema();
    my $accession_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $population_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'population', 'stock_type')->cvterm_id();
    my $synonym_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stock_synonym', 'stock_property')->cvterm_id();

    my %accessions_hash;
    my %accessions_and_populations_hash;
    my $q = "SELECT stock.uniquename, stock.type_id, stock.stock_id, stock.organism_id, stockprop.value, stockprop.type_id FROM stock LEFT JOIN stockprop USING(stock_id) WHERE stock.type_id=$accession_cvterm OR stock.type_id=$population_cvterm";
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute();
    while (my ($uniquename, $stock_type_id, $stock_id, $organism_id, $synonym, $type_id) = $h->fetchrow_array()) {
        if ($stock_type_id == $accession_cvterm){
            $accessions_hash{$uniquename} = [$stock_id, $organism_id];
        }
        $accessions_and_populations_hash{$uniquename} = [$stock_id, $organism_id];
        if ($type_id){
            if ($type_id == $synonym_type_id){
                $accessions_hash{$synonym} = [$stock_id, $organism_id];
                $accessions_and_populations_hash{$synonym} = [$stock_id, $organism_id];
            }
        }
    }
    return (\%accessions_hash, \%accessions_and_populations_hash);
}

#######
1;
#######
