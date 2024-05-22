
package CXGN::Population;

use Moose;
use SGN::Model::Cvterm;
use Data::Dumper;
use JSON;

extends 'CXGN::Stock';

has 'population_stock_id' => (isa => 'Maybe[Int]',
    is => 'rw',
);

has 'population_name' => (isa => 'Maybe[Str]',
    is => 'rw',
);

has 'accession_members' => (isa => 'ArrayRef',
    is => 'rw',
);

has 'stock_relationship_id' => (isa => 'Maybe[Int]',
    is => 'rw',
);



sub BUILD {
    my $self = shift;
    my $args = shift;

    my $schema = $args->{schema};
    my $population_id = $args->{population_stock_id};

    $self->stock_id($population_id);

    my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $population_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'population', 'stock_type')->cvterm_id();
    my $member_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'member_of', 'stock_relationship')->cvterm_id();

    my $row = $schema->resultset("Stock::Stock")->find( { stock_id => $population_id, type_id => $population_cvterm_id });

    if ($row) {
        my $name = $row->uniquename();
        $self->population_name($name);
        $self->population_stock_id($population_id);

    }

    my $accession_members = $self->get_accession_members();
    print STDERR Dumper($accession_members);

    if ($accession_members) {
        $self->accession_members($accession_members);
    }

}


sub get_accession_members {
    my $self = shift;
    my $schema = $self->schema;
    my $population_id = $self->population_stock_id;

    my $member_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "member_of", "stock_relationship")->cvterm_id();
    my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "accession", "stock_type")->cvterm_id();

    my $q = "SELECT member.stock_id, member.uniquename
        FROM stock
        JOIN stock_relationship ON (stock_relationship.object_id = stock.stock_id) AND stock_relationship.type_id = ?
        JOIN stock AS member ON (stock_relationship.subject_id = member.stock_id) AND member.type_id = ?
        WHERE stock.stock_id = ?";

     my $h = $schema->storage->dbh()->prepare($q);
     $h->execute($member_of_type_id, $accession_type_id, $population_id);
     my @accession_members = ();
     while (my ($stock_id, $stock_name) = $h->fetchrow_array()){
         push @accession_members, [$stock_id, $stock_name]
     }

     return \@accession_members;
}


sub delete_population {
    my $self = shift;
    my $dbh = $self->schema()->storage()->dbh();
    my $schema = $self->schema();
    my $population_id = $self->population_stock_id();

    eval {
        $dbh->begin_work();

        my $population_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "population", "stock_type")->cvterm_id();
        my $male_parent_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "male_parent", "stock_relationship")->cvterm_id();

        my $male_parent_rs = $schema->resultset("Stock::StockRelationship")->search({subject_id => $population_id, type_id => $male_parent_type_id});
        if ($male_parent_rs->count > 0){
            print STDERR "Population has associated cross or pedigree. Cannot delete.\n";
            die "Population has associated cross or pedigree: Cannot delete.\n";
        }

        #checking if the stock id has population stock type
        my $population_rs = $schema->resultset("Stock::Stock")->find ({stock_id => $population_id, type_id => $population_type_id});
        if (!$population_rs) {
            print STDERR "This stock id is not a population. Cannot delete.\n";
	        die "This stock id is not a population. Cannot delete.\n";
        }

        my $q = "delete from phenome.stock_owner where stock_id = ?";
	    my $h = $dbh->prepare($q);
	    $h->execute($population_id);

	    my $q2 = "delete from stock where stock.stock_id = ? and stock.type_id = ?";
	    my $h2 = $dbh->prepare($q2);
	    $h2->execute($population_id, $population_type_id);
    };


    if ($@) {
	    print STDERR "An error occurred while deleting population id ".$population_id."$@\n";
	    $dbh->rollback();
	    return $@;
    } else {
	    $dbh->commit();
	    return 0;
    }
}


sub delete_population_member {
    my $self = shift;
    my $dbh = $self->schema()->storage()->dbh();
    my $schema = $self->schema();
    my $stock_relationship_id = $self->stock_relationship_id();

    eval {
        $dbh->begin_work();

        my $population_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "population", "stock_type")->cvterm_id();
        my $male_parent_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "male_parent", "stock_relationship")->cvterm_id();
        my $member_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "member_of", "stock_relationship")->cvterm_id();

        my $population_id;
        my $population_member_rs = $schema->resultset("Stock::StockRelationship")->find({stock_relationship_id => $stock_relationship_id, type_id => $member_of_type_id});
        if (!$population_member_rs) {
            print STDERR "This accession is not a population member. Cannot delete.\n";
	        die "This accession is not a population memeber. Cannot delete.\n";
        } else {
            $population_id = $population_member_rs->object_id();
            my $population_rs = $schema->resultset("Stock::Stock")->find ({stock_id => $population_id, type_id => $population_type_id});
            if (!$population_rs) {
                print STDERR "This stock id is not a population. Cannot delete.\n";
    	        die "This stock is not a population. Cannot delete.\n";
            } else {
                my $male_parent_rs = $schema->resultset("Stock::StockRelationship")->search({subject_id => $population_id, type_id => $male_parent_type_id});
                if ($male_parent_rs->count > 0){
                    print STDERR "Population has associated cross or pedigree. Cannot delete population member.\n";
                    die "Population has associated cross or pedigree: Cannot delete population member.\n";
                }
            }
        }

        $population_member_rs->delete;
    };

    if ($@) {
	    print STDERR "An error occurred while deleting accession member "."$@\n";
	    $dbh->rollback();
	    return $@;
    } else {
	    $dbh->commit();
	    return 0;
    }
}




1;
