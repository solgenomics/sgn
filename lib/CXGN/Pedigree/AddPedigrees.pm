

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
                $female_parent = $self->_get_accession($female_parent_name);
                if (!$female_parent){
                    push @{$return{error}}, ""
                }
            }

            if ($pedigree->has_male_parent()) {
                $male_parent_name = $pedigree->get_male_parent()->get_name();
                $male_parent = $self->_get_accession($male_parent_name);
            }

            my $cross_name = $pedigree->get_name();

            print STDERR "Creating pedigree $cross_type, $cross_name\n";

            my $progeny_accession = $self->_get_accession($pedigree->get_name());

            # organism of cross experiment will be the same as the female parent
            if ($female_parent) {
                $organism_id = $female_parent->organism_id();
            } else {
                $organism_id = $male_parent->organism_id();
            }

            if ($female_parent) {
                if ($overwrite_pedigrees){
                    my $previous_female_parent = $self->get_schema->resultset('Stock::StockRelationship')->search({
                        type_id => $female_parent_cvterm->cvterm_id(),
                        object_id => $progeny_accession->stock_id(),
                    });
                    while(my $r = $previous_female_parent->next()){
                        print STDERR "Deleted female parent stock_relationship_id: ".$r->stock_relationship_id."\n";
                        $r->delete();
                    }
                }
                $progeny_accession->create_related('stock_relationship_objects', {
                    type_id => $female_parent_cvterm->cvterm_id(),
                    object_id => $progeny_accession->stock_id(),
                    subject_id => $female_parent->stock_id(),
                    value => $cross_type,
                });
            }

            #create relationship to male parent
            if ($male_parent) {
                if ($overwrite_pedigrees){
                    my $previous_male_parent = $self->get_schema->resultset('Stock::StockRelationship')->search({
                        type_id => $male_parent_cvterm->cvterm_id(),
                        object_id => $progeny_accession->stock_id(),
                    });
                    while(my $r = $previous_male_parent->next()){
                        print STDERR "Deleted male parent stock_relationship_id: ".$r->stock_relationship_id."\n";
                        $r->delete();
                    }
                }
                $progeny_accession->create_related('stock_relationship_objects', {
                    type_id => $male_parent_cvterm->cvterm_id(),
                    object_id => $progeny_accession->stock_id(),
                    subject_id => $male_parent->stock_id(),
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
    my $schema = $self->get_schema();
    my %return;

    if (!$self->has_pedigrees()){
        $return{error} = "No pedigrees to add";
        return \%return;
    }

    my $female_parent_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->get_schema(), 'female_parent', 'stock_relationship')->cvterm_id;
    my $male_parent_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->get_schema(), 'male_parent', 'stock_relationship')->cvterm_id;

    my @pedigrees = @{$self->get_pedigrees()};
    foreach my $pedigree (@pedigrees) {
        my $error = $self->_validate_pedigree($pedigree, $female_parent_cvterm_id, $male_parent_cvterm_id);
        if ($error) {
            push @{$return{error}}, $error;
        }
    }

    return \%return;
}

sub _validate_pedigree {
    my $self = shift;
    my $pedigree = shift;
    my $female_parent_cvterm_id = shift;
    my $male_parent_cvterm_id = shift;
    my $schema = $self->get_schema();
    my $progeny_name = $pedigree->get_name();
    my $cross_type = $pedigree->get_cross_type();
    my $female_parent_name;
    my $male_parent_name;
    my $female_parent;
    my $male_parent;
    my %return;

    my $progeny = $self->_get_accession($progeny_name);
    if (!$progeny){
        return "Pedigree name missing or not found as an accession in database.";
    }

    if (!$pedigree->get_female_parent()){
        return "Pedigree not structured correctly";
    }

    $female_parent_name = $pedigree->get_female_parent()->get_name();
    if (!$female_parent_name) {
        return "Female parent not provided for $progeny_name.";
    }
    $female_parent = $self->_get_accession($female_parent_name);
    if (!$female_parent) {
        return "Female parent not found for $progeny_name.";
    }

    my $progeny_female_parent_search = $schema->resultset('Stock::StockRelationship')->search({
        type_id => $female_parent_cvterm_id,
        object_id => $progeny->stock_id(),
    });
    if ($progeny_female_parent_search->count == 1) {
        return "$progeny_name already has female parent stockID ".$progeny_female_parent_search->first->subject_id." saved with cross type ".$progeny_female_parent_search->first->value;
    }
    elsif ($progeny_female_parent_search->count > 1){
        return "$progeny_name already has MULTIPLE female parents saved.";
    }

    if (($cross_type eq "biparental") || ($cross_type eq "self")) {
        if (!$pedigree->get_male_parent){
            return "Male parent not provided for $progeny_name and cross type is $cross_type.";
        }
        $male_parent_name = $pedigree->get_male_parent()->get_name();
        if (!$male_parent_name) {
            return "Male parent not provided for $progeny_name and cross type is $cross_type.";
        }
        $male_parent = $self->_get_accession($male_parent_name);
        if (!$male_parent) {
            return "Male parent not found for $progeny_name.";
        }

        my $progeny_male_parent_search = $schema->resultset('Stock::StockRelationship')->search({
            type_id => $male_parent_cvterm_id,
            object_id => $progeny->stock_id(),
        });
        if ($progeny_male_parent_search->count == 1) {
            return "$progeny_name already has male parent stockID ".$progeny_male_parent_search->first->subject_id;
        }
        elsif ($progeny_male_parent_search->count > 1){
            return "$progeny_name already has MULTIPLE male parents saved.";
        }
    }
    elsif ($cross_type eq "open") {
        if ($pedigree->get_male_parent){
            if ($pedigree->get_male_parent()->get_name()){
                $male_parent_name = $pedigree->get_male_parent()->get_name();
                $male_parent = $self->_get_accession($male_parent_name);
                if (!$male_parent) {
                    return "Male parent not found for $progeny_name.";
                }

                my $progeny_male_parent_search = $schema->resultset('Stock::StockRelationship')->search({
                    type_id => $male_parent_cvterm_id,
                    object_id => $progeny->stock_id(),
                });
                if ($progeny_male_parent_search->count == 1) {
                    return "$progeny_name already has male parent stockID ".$progeny_male_parent_search->first->subject_id;
                }
                elsif ($progeny_male_parent_search->count > 1){
                    return "$progeny_name already has MULTIPLE male parents saved.";
                }
            }
        }
    }
    else {
        return "Cross type not detected.";
    }

    return;
}

sub _get_accession {
    my $self = shift;
    my $accession_name = shift;
    my $schema = $self->get_schema();
    my $accession_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $population_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'population', 'stock_type')->cvterm_id();
    my $stock = $schema->resultset('Stock::Stock')->search(
        {
            'me.is_obsolete' => { '!=' => 't' },
            'me.type_id' => [$accession_cvterm, $population_cvterm],
            -or => [
                'lower(me.uniquename)' => lc($accession_name),
                -and => [
                    'lower(type.name)' => { like => '%synonym%' },
                    'lower(stockprops.value)' => lc($accession_name),
                ],
            ],
        },
        {
            join => {'stockprops' => 'type'},
            distinct => 1
        }
    );

    if (!$stock) {
        print STDERR "Name in pedigree ($accession_name) is not a stock or population\n";
        return;
    }
    if ($stock->count != 1){
        print STDERR "Accession name ($accession_name) is not a unique stock unqiuename or synonym\n";
        return;
    }

    return $stock->first();
}

#######
1;
#######
